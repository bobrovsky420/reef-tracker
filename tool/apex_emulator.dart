// A fake Neptune Apex controller, for developing and testing the U40
// integration without owning one.
//
// It serves the same HTTP surface a real Apex does — both firmware families —
// with slowly drifting probe values, a realistic outlet set and a feed cycle
// that actually counts down, so the dashboard has something live to show.
//
//     dart run tool/apex_emulator.dart                    # AOS 5.x on :80
//     dart run tool/apex_emulator.dart --firmware classic # /cgi-bin/status.json
//     dart run tool/apex_emulator.dart --port 8080 --unit f
//
// ## Reaching it from the Android emulator
//
// The Android emulator sees the host machine as **10.0.2.2**. Start this on
// Windows, then in the app's "Add controller" sheet enter:
//
//     10.0.2.2         (when this runs on the default port 80)
//     10.0.2.2:8080    (when started with --port 8080)
//
// Port 80 is what a real Apex uses and needs no extra typing, but IIS or
// another service may already hold it — if binding fails, use --port 8080.
// Windows does not reserve low ports for administrators, so port 80 normally
// binds fine from an ordinary shell.
//
// Two controllers at once (to exercise multi-card ordering and Save-all) is
// just two processes on two ports with two serials:
//
//     dart run tool/apex_emulator.dart --port 8080 --serial AC5:11111
//     dart run tool/apex_emulator.dart --port 8081 --serial AJ:22222 --firmware classic
//
// ## Control endpoints (emulator-only, not part of the Apex API)
//
//     GET /emu                      a plain-text summary of the current state
//     GET /emu/feed?cycle=A         start a feed cycle (A-D), 300 s
//     GET /emu/feed?cycle=off       cancel it
//     GET /emu/outlet?name=Return&state=OFF   force an outlet state
//     GET /emu/probe?name=Tmp&value=31.5      pin a probe (clear with ?value=)
//
// The server class is deliberately importable: ap_emulator_test.dart drives a
// real ApHttpLink against it, so the transport, the login handshake and both
// parsers are covered end to end rather than only against hand-written JSON.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Which API family the emulator presents.
enum EmuFirmware { aos5, classic }

/// The temperature unit the fake controller is configured in — the one thing
/// an Apex's status document never states.
enum EmuTempUnit { celsius, fahrenheit }

/// One simulated probe. [base] is in °C for temperatures and in the probe's
/// own unit otherwise; the °F conversion happens on the way out, exactly as a
/// real controller's would.
class _Probe {
  _Probe(this.did, this.name, this.type, this.base, this.swing);

  final String did;
  final String name;
  final String type;
  final double base;

  /// Peak deviation of the slow sine that makes the value move.
  final double swing;

  /// Set by `/emu/probe` to freeze a value (for reproducing a bug).
  double? pinned;
}

class _Outlet {
  _Outlet(this.did, this.name, this.type, this.state);
  final String did;
  final String name;
  final String type;
  String state;
}

/// A fake Apex serving one controller.
class ApexEmulator {
  ApexEmulator({
    this.firmware = EmuFirmware.aos5,
    this.tempUnit = EmuTempUnit.celsius,
    this.serial = 'AC5:12345',
    this.hostname = 'apex',
    this.username = 'admin',
    this.password = '1234',
    this.trident = true,
    this.rejectSessionLogin = false,
    this.verbose = true,
    Random? random,
  }) : _random = random ?? Random(serial.hashCode);

  final EmuFirmware firmware;
  final EmuTempUnit tempUnit;
  final String serial;
  final String hostname;
  final String username;
  final String password;

  /// Whether to include a Trident's alk/Ca/Mg inputs — they ride the same
  /// input list as the analog probes on a real controller.
  final bool trident;

  /// Answer `POST /rest/login` with **401** even for the right credentials —
  /// the third rung of the app's auth ladder. Builds exist that route the
  /// `/rest` tree but refuse a *session* login while still honouring HTTP Basic
  /// auth on the legacy path, and a 401 there must therefore mean "try Basic",
  /// not "wrong password". Only meaningful with [EmuFirmware.aos5] (a Classic
  /// controller 404s that route instead).
  final bool rejectSessionLogin;

  final bool verbose;
  final Random _random;

  HttpServer? _server;
  final _started = DateTime.now();

  /// Issued sessions. A real Apex expires these; nothing here needs to, and
  /// the app logs in per read anyway.
  final _sessions = <String>{};

  /// When the running feed cycle ends, and which one (1–4).
  DateTime? _feedEndsAt;
  int _feedCycle = 0;

  late final List<_Probe> _probes = [
    _Probe('base_Temp', 'Tmp', 'Temp', 25.4, 0.25),
    _Probe('base_pH', 'pH', 'pH', 8.14, 0.10),
    _Probe('base_ORP', 'ORP', 'ORP', 345, 18),
    // Conductivity probes report ppt on an Apex, which is why the app converts
    // to specific gravity on save.
    _Probe('base_Cond', 'Salt', 'Cond', 35.0, 0.2),
    // Unmapped inputs: present on every real controller, deliberately not
    // savable by the app. Their job here is to prove the parser ignores them.
    _Probe('base_Amps', 'RETURN_2_1A', 'Amps', 0.42, 0.05),
    _Probe('base_pwr', 'RETURN_2_1W', 'pwr', 48, 4),
    _Probe('base_volts', 'Volt_2', 'volts', 232, 2),
    if (trident) ...[
      _Probe('Trident_alk', 'Alk', 'alk', 8.4, 0.15),
      _Probe('Trident_ca', 'Ca', 'ca', 428, 6),
      _Probe('Trident_mg', 'Mg', 'mg', 1385, 12),
    ],
  ];

  late final List<_Outlet> _outlets = [
    _Outlet('2_1', 'Return', 'outlet', 'AON'),
    _Outlet('2_2', 'Skimmer', 'outlet', 'AON'),
    _Outlet('2_3', 'Heater', 'outlet', 'AOF'),
    _Outlet('2_4', 'ATO_Pump', 'outlet', 'AOF'),
    // A human left this one off after a water change — the case the
    // dashboard's "overridden" chip exists for.
    _Outlet('2_5', 'Wavemaker', 'outlet', 'OFF'),
    _Outlet('2_6', 'Fuge_Light', 'outlet', 'AON'),
    _Outlet('2_7', 'UV', 'outlet', 'AOF'),
    _Outlet('2_8', 'Cooling_Fan', 'outlet', 'AOF'),
    _Outlet('3_1', 'Vortech_L', 'vortech', 'TBL'),
    _Outlet('3_2', 'Vortech_R', 'vortech', 'TBL'),
    _Outlet('4_1', 'LED_Dim', 'variable', 'PF1'),
    _Outlet('base_Alarm', 'EmailAlm_I5', 'alert', 'AOF'),
    _Outlet('Cntl_A2', 'LEAK', 'virtual', 'AOF'),
  ];

  /// The port actually bound (useful when started on port 0).
  int get port => _server?.port ?? 0;

  Future<void> start({String host = '0.0.0.0', int port = 80}) async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    if (verbose) {
      stdout.writeln(
        'Apex emulator ($serial, ${firmware.name}, '
        '${tempUnit == EmuTempUnit.celsius ? '°C' : '°F'}) '
        'listening on http://$host:${server.port}',
      );
      stdout.writeln('  login: $username / $password');
      stdout.writeln(
        '  from the Android emulator use 10.0.2.2'
        '${server.port == 80 ? '' : ':${server.port}'}',
      );
    }
    unawaited(server.forEach(_handle));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // --- request routing -----------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (path.startsWith('/emu')) return await _handleControl(request);
      if (path == '/rest/login') return await _handleLogin(request);
      if (path == '/rest/status') return await _handleRestStatus(request);
      if (path == '/rest/config') return await _handleRestConfig(request);
      if (path == '/cgi-bin/status.json') {
        return await _handleLegacyStatus(request);
      }
      if (path == '/') return await _handleRoot(request);
      await _send(request, HttpStatus.notFound, 'not found');
    } catch (e) {
      await _send(request, HttpStatus.internalServerError, '$e');
    }
  }

  /// `POST /rest/login`. A Classic controller has no `/rest` tree at all, so
  /// in that mode this 404s — which is precisely the signal the app uses to
  /// fall back to the legacy path.
  Future<void> _handleLogin(HttpRequest request) async {
    if (firmware == EmuFirmware.classic) {
      return _send(request, HttpStatus.notFound, 'not found');
    }
    if (rejectSessionLogin) {
      // Drained first: the client is still writing the body, and a response
      // sent before the request is read can reset the connection.
      await utf8.decoder.bind(request).join();
      return _sendJson(request, {
        'error': 'Unauthorized',
      }, status: HttpStatus.unauthorized);
    }
    final body = await utf8.decoder.bind(request).join();
    Map<String, Object?> decoded;
    try {
      decoded = (jsonDecode(body) as Map).cast<String, Object?>();
    } catch (_) {
      return _send(request, HttpStatus.badRequest, 'bad json');
    }
    if (decoded['login'] != username || decoded['password'] != password) {
      return _sendJson(request, {
        'error': 'Invalid login',
      }, status: HttpStatus.unauthorized);
    }
    final sid = 's${_random.nextInt(1 << 32).toRadixString(16)}';
    _sessions.add(sid);
    await _sendJson(request, {'connect.sid': sid});
  }

  Future<void> _handleRestStatus(HttpRequest request) async {
    if (firmware == EmuFirmware.classic) {
      return _send(request, HttpStatus.notFound, 'not found');
    }
    if (!_hasSession(request)) {
      return _sendJson(request, {
        'error': 'unauthorized',
      }, status: HttpStatus.unauthorized);
    }
    await _sendJson(request, {
      'system': {
        'hostname': hostname,
        'serial': serial,
        'timezone': 1.0,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'software': '5.12_8C24',
        'hardware': '1.0',
        'type': 'controller',
      },
      'inputs': [
        for (final p in _probes)
          {
            'did': p.did,
            'type': p.type,
            'name': p.name,
            'value': _valueOf(p),
          },
      ],
      'outputs': [
        for (final o in _outlets)
          {
            'did': o.did,
            'type': o.type,
            'name': o.name,
            'status': [o.state, '', 'OK', ''],
            'ID': _outlets.indexOf(o),
          },
      ],
      'feed': _feedJson(),
    });
  }

  /// `GET /rest/config`. Only the fields the app actually reads are modelled —
  /// the real document is enormous. `iconf[].extra.range` is the authoritative
  /// statement of the controller's temperature unit, and Neptune's own
  /// spelling of it really is "Celcius".
  ///
  /// `oconf[].prog` carries each output's **program text**, which nothing in
  /// the app reads but which is what makes this — not `/rest/status` — the
  /// largest document an Apex serves. It is reproduced (in miniature: a real
  /// controller's programs run to pages) so that the size ordering the response
  /// ceiling meets in the field is the one the fake presents.
  Future<void> _handleRestConfig(HttpRequest request) async {
    if (firmware == EmuFirmware.classic) {
      return _send(request, HttpStatus.notFound, 'not found');
    }
    if (!_hasSession(request)) {
      return _sendJson(request, {
        'error': 'unauthorized',
      }, status: HttpStatus.unauthorized);
    }
    await _sendJson(request, {
      'iconf': [
        for (final p in _probes)
          {
            'did': p.did,
            'name': p.name,
            'extra': {
              if (p.type == 'Temp')
                'range': tempUnit == EmuTempUnit.celsius ? 'Celcius' : 'Faren',
            },
          },
      ],
      'oconf': [
        for (final o in _outlets)
          {
            'did': o.did,
            'name': o.name,
            'ctype': 'Advanced',
            'prog': _program(o),
          },
      ],
    });
  }

  /// A plausible Apex program for [o] — the statement soup a keeper actually
  /// writes, in the multi-line form the controller stores it in.
  static String _program(_Outlet o) => [
    'Fallback OFF',
    'Set ${o.state.endsWith('N') ? 'ON' : 'OFF'}',
    'If Tmp > 26.4 Then OFF',
    'If Tmp < 25.2 Then ON',
    'If FeedA 000 Then OFF',
    'If FeedB 000 Then OFF',
    'If Power Apex Off 000 Then OFF',
    'Defer 001:00 Then ON',
    'Min Time 010:00 Then ON',
    '// ${o.name} — edited from Fusion',
  ].join('\n');

  /// `GET /cgi-bin/status.json` behind Basic auth — the Classic path. Note the
  /// `istat` wrapper and the identity fields sitting at that level rather than
  /// in a `system` object.
  Future<void> _handleLegacyStatus(HttpRequest request) async {
    if (!_hasBasicAuth(request)) {
      request.response.headers.set(
        HttpHeaders.wwwAuthenticateHeader,
        'Basic realm="Apex"',
      );
      return _send(request, HttpStatus.unauthorized, 'unauthorized');
    }
    await _sendJson(request, {
      'istat': {
        'hostname': hostname,
        'serial': serial,
        'software': '5.04_7A18',
        'hardware': '1.0',
        'timezone': 1.0,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'inputs': [
          for (final p in _probes)
            {
              'did': p.did,
              'type': p.type,
              'name': p.name,
              // Classic firmware pads its numbers into fixed-width strings —
              // the exact shape the parser's tolerant number reader exists for.
              'value': '${_valueOf(p)} ',
            },
        ],
        'outputs': [
          for (final o in _outlets)
            {
              'did': o.did,
              'type': o.type,
              'name': o.name,
              'status': [o.state, '', 'OK', ''],
              'ID': _outlets.indexOf(o),
            },
        ],
        'feed': _feedJson(legacy: true),
        'power': {
          'failed': '12/14/2026 11:00:00',
          'restored': '12/14/2026 16:31:15',
        },
      },
    });
  }

  Future<void> _handleRoot(HttpRequest request) async {
    await _send(
      request,
      HttpStatus.ok,
      'Apex emulator — $serial (${firmware.name}). '
      'See /emu for state, or point ReefTracker at this address.',
    );
  }

  // --- emulator control ----------------------------------------------------

  Future<void> _handleControl(HttpRequest request) async {
    final q = request.uri.queryParameters;
    switch (request.uri.path) {
      case '/emu/feed':
        final cycle = (q['cycle'] ?? '').toUpperCase();
        if (cycle == 'OFF' || cycle.isEmpty) {
          _feedCycle = 0;
          _feedEndsAt = null;
        } else {
          _feedCycle = cycle.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1;
          final seconds = int.tryParse(q['seconds'] ?? '') ?? 300;
          _feedEndsAt = DateTime.now().add(Duration(seconds: seconds));
        }
      case '/emu/outlet':
        for (final o in _outlets) {
          if (o.name == q['name'] || o.did == q['name']) {
            o.state = (q['state'] ?? o.state).toUpperCase();
          }
        }
      case '/emu/probe':
        for (final p in _probes) {
          if (p.name == q['name'] || p.did == q['name']) {
            final raw = q['value'];
            p.pinned = (raw == null || raw.isEmpty)
                ? null
                : double.tryParse(raw);
          }
        }
    }
    await _send(request, HttpStatus.ok, _summary());
  }

  String _summary() {
    final feed = _feedSecondsLeft();
    return [
      'serial      $serial',
      'firmware    ${firmware.name}',
      'unit        ${tempUnit == EmuTempUnit.celsius ? 'C' : 'F'}',
      'uptime      ${DateTime.now().difference(_started).inSeconds}s',
      'feed        ${feed == null ? 'idle' : 'cycle $_feedCycle, ${feed}s left'}',
      '',
      'probes',
      for (final p in _probes)
        '  ${p.name.padRight(12)} ${p.type.padRight(6)} ${_valueOf(p)}'
            '${p.pinned == null ? '' : '  (pinned)'}',
      '',
      'outlets',
      for (final o in _outlets) '  ${o.name.padRight(14)} ${o.state}',
    ].join('\n');
  }

  // --- simulation ----------------------------------------------------------

  /// The current value of [p]: a slow sine around its base plus a little
  /// noise, so consecutive refreshes differ the way a real probe's do without
  /// wandering out of a plausible range. Temperatures are converted to the
  /// controller's configured unit last, and everything is rounded to the
  /// number of decimals an Apex actually reports for that probe type.
  num _valueOf(_Probe p) {
    final pinned = p.pinned;
    var v = pinned ?? 0;
    if (pinned == null) {
      final t = DateTime.now().difference(_started).inMilliseconds / 1000;
      // Two periods (~7 min and ~50 s) so the trace never looks like a clean
      // sine on a chart.
      v =
          p.base +
          p.swing * sin(t / 67) +
          p.swing * 0.25 * sin(t / 8) +
          (_random.nextDouble() - 0.5) * p.swing * 0.06;
    }
    if (p.type == 'Temp' && tempUnit == EmuTempUnit.fahrenheit) {
      v = v * 9 / 5 + 32;
    }
    return switch (p.type) {
      'pH' => double.parse(v.toStringAsFixed(2)),
      'Temp' || 'Cond' || 'alk' => double.parse(v.toStringAsFixed(1)),
      'Amps' => double.parse(v.toStringAsFixed(2)),
      _ => v.round(),
    };
  }

  int? _feedSecondsLeft() {
    final end = _feedEndsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _feedEndsAt = null;
      _feedCycle = 0;
      return null;
    }
    return left;
  }

  /// Both firmwares park an *idle* feed timer at a sentinel rather than zero,
  /// and they use different ones — AOS 5 a large number, Classic the cycle
  /// name 6. Reproducing both is the point of this method.
  Map<String, Object?> _feedJson({bool legacy = false}) {
    final left = _feedSecondsLeft();
    if (left == null) {
      return legacy
          ? {'name': 6, 'active': 0}
          : {'name': 0, 'active': 65535, 'errorCode': 0, 'errorMessage': ''};
    }
    return legacy
        ? {'name': _feedCycle, 'active': left}
        : {
            'name': _feedCycle,
            'active': left,
            'errorCode': 0,
            'errorMessage': '',
          };
  }

  // --- plumbing ------------------------------------------------------------

  bool _hasSession(HttpRequest request) {
    for (final cookie in request.cookies) {
      if (cookie.name == 'connect.sid' && _sessions.contains(cookie.value)) {
        return true;
      }
    }
    // The app sets the cookie as a raw header rather than through the cookie
    // API; accept either.
    final raw = request.headers.value(HttpHeaders.cookieHeader) ?? '';
    for (final part in raw.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2 &&
          kv[0] == 'connect.sid' &&
          _sessions.contains(kv[1])) {
        return true;
      }
    }
    return false;
  }

  bool _hasBasicAuth(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Basic ')) return false;
    try {
      final decoded = utf8.decode(base64.decode(header.substring(6)));
      return decoded == '$username:$password';
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendJson(
    HttpRequest request,
    Map<String, Object?> body, {
    int status = HttpStatus.ok,
  }) async {
    if (verbose) {
      stdout.writeln('  ${request.method} ${request.uri.path} -> $status');
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _send(HttpRequest request, int status, String body) async {
    if (verbose) {
      stdout.writeln('  ${request.method} ${request.uri.path} -> $status');
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.text
      ..write(body);
    await request.response.close();
  }
}

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'Fake Neptune Apex controller.\n\n'
      'Options:\n'
      '  --port <n>            TCP port (default 80; use 8080 if 80 is taken)\n'
      '  --host <addr>         bind address (default 0.0.0.0)\n'
      '  --firmware aos5|classic   which API family to serve (default aos5)\n'
      '  --unit c|f            controller temperature unit (default c)\n'
      '  --serial <s>          controller serial (default AC5:12345)\n'
      '  --user <s>            login (default admin)\n'
      '  --password <s>        password (default 1234)\n'
      '  --no-trident          omit the Trident alk/Ca/Mg inputs\n'
      '  --quiet               do not log requests\n\n'
      'From the Android emulator the host machine is 10.0.2.2 — enter that\n'
      '(plus ":<port>" if not on 80) as the controller address in the app.',
    );
    return;
  }

  final emulator = ApexEmulator(
    firmware: opt('firmware') == 'classic'
        ? EmuFirmware.classic
        : EmuFirmware.aos5,
    tempUnit: (opt('unit') ?? 'c').toLowerCase().startsWith('f')
        ? EmuTempUnit.fahrenheit
        : EmuTempUnit.celsius,
    serial: opt('serial') ?? 'AC5:12345',
    username: opt('user') ?? 'admin',
    password: opt('password') ?? '1234',
    trident: !args.contains('--no-trident'),
    verbose: !args.contains('--quiet'),
  );

  final port = int.tryParse(opt('port') ?? '') ?? 80;
  try {
    await emulator.start(host: opt('host') ?? '0.0.0.0', port: port);
  } on SocketException catch (e) {
    stderr.writeln(
      'Could not bind port $port: ${e.osError?.message ?? e.message}\n'
      'Something else is probably holding it — try: '
      'dart run tool/apex_emulator.dart --port 8080',
    );
    exitCode = 1;
  }
}
