// Coverage of the ReefBeat transport (U38) — the first test of its own for
// `RbHttpLink`; `rb_protocol_test.dart` covers only the parsers, against
// hand-written JSON.
//
// The server here is deliberately not a ReefBeat emulator. It serves the golden
// `/device-info` and `/dashboard` payloads well enough to prove the happy path
// still works, and is otherwise built to behave like the things LAN discovery
// actually points this link at: a host that answers with megabytes, one that
// lies about its Content-Length, one that gzips a bomb, one that serves HTML.
// That is what the #72 cap exists for.
//
// Every server binds port 0, so the suite never collides with anything running.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/device_http.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';

/// A live RSATO+'s identity, as `rb_protocol_test.dart` captured it.
const _deviceInfo = {
  'name': 'RSATO+3625739455',
  'hw_type': 'reef-ato',
  'hw_model': 'RSATO+',
  'hwid': '8813bf641cd8',
};

/// A live RSDOSE4's identity (the golden vector of `rb_protocol_test.dart`).
const _doseDeviceInfo = {
  'hw_type': 'reef-dosing',
  'hw_model': 'RSDOSE4',
  'name': 'RSDOSE4-1752835676',
  'status': 'unpaired',
  'hwid': 'cc7b5c267a68',
};

/// The ReefControl Pro discovered at 192.168.1.183 (2026-08-13).
const _controlDeviceInfo = {
  'name': 'RSCONTROLPRO-674461898',
  'hw_type': 'reef-control',
  'hw_model': 'RSCONTROLPRO',
  'hw_revision': 'v1.3_26A',
  'hwid': '704bca783328',
};

const _controlDashboard = {
  'mode': 'auto',
  'is_internet_connected': true,
  'cable_connected': false,
  'probes': [
    {
      'type': 'ec',
      'uid': '0x005AA',
      'measurement_unit': 'ppt',
      'value': 35.8,
      'name': 'Salinity 5AA',
      'status': 'auto',
      'ec': 54.2,
      'ppt': 35.8,
      'sg': 1.027,
      'level': 'acceptable',
      'temp_value': 25.6,
      'temp_level': 'desired',
    },
    {
      'type': 'orp',
      'uid': '0x0007C',
      'name': 'ORP 7C',
      'status': 'auto',
      'value': 81,
      'level': 'danger',
    },
    {
      'type': 'ph',
      'uid': '0x00579',
      'name': 'pH 579',
      'status': 'auto',
      'value': 8.06,
      'level': 'desired',
      'temp_value': 25.8,
      'temp_level': 'desired',
    },
  ],
};

/// The same pump's `/dashboard`, abridged to two of its four heads — enough to
/// prove the settings fan-out visits each head that was reported, and only
/// those. Head numbers 1 and 4 on purpose: the loop must follow the reported
/// numbers, not a 1..n count.
const _doseDashboard = {
  'battery_level': 'high',
  'time_error': false,
  'heads': {
    '1': {
      'supplement': 'Balling light KH',
      'state': 'on',
      'auto_dosed_today': 26.7,
      'manual_dosed_today': 0,
      'doses_today': 4,
      'daily_dose': 40,
      'remaining_days': 117,
      'stock_level': 'high',
      'daily_doses': 6,
    },
    '4': {
      'supplement': 'NO3PO4-X',
      'state': 'on',
      'auto_dosed_today': 6,
      'manual_dosed_today': 0,
      'doses_today': 1,
      'daily_dose': 6,
      'remaining_days': 48,
      'stock_level': 'high',
      'daily_doses': 1,
    },
  },
};

/// `GET /head/<n>/settings` — the only endpoint carrying a head's supplement
/// *abbreviation*, which is the sole link between a queued dose and a head.
Map<String, Object?> _headSettings(int head) => {
  'state': 'on',
  'container_volume': 4654.109,
  'vps': 0.059848,
  'supplement': {
    'uid': '19c1c766-407f-47e3-a4ea-71cecd4c0d31',
    'name': head == 1 ? 'Balling light KH' : 'NO3PO4-X',
    'display_name': head == 1 ? 'KH' : 'NPX',
    'short_name': head == 1 ? 'KH' : 'NPX',
    'brand_name': 'Fauna Marine',
  },
  'schedule': {
    'type': 'custom',
    'dd': 40,
    'days': [1, 2, 3, 4, 5, 6, 7],
  },
};

/// A live RSWAVE25's identity. The wave is the one family that serves **no**
/// `/dashboard` at all.
const _waveDeviceInfo = {
  'name': 'RSWAVE25-1234567890',
  'hw_type': 'reef-wave',
  'hw_model': 'RSWAVE25',
  'hwid': 'e868e7eb7a28',
};

/// Its `GET /mode` and `GET /auto` (the 2026-07-25 golden vectors).
const _waveMode = {'mode': 'auto'};
const _waveAuto = {
  'uid': '587543e6-1c55-499d-8839-6f0084154aaa',
  'intervals': [
    {
      'wave_uid': '0f0bdf17-92d2-4e38-bbb0-4eb7f640a57d',
      'type': 're',
      'name': 'Regular Night',
      'frt': 10,
      'rrt': 2,
      'fti': 30,
      'rti': 60,
      'st': 0,
      'direction': 'alt',
    },
    {
      'wave_uid': '01bff951-dc93-4655-8349-405b82e20025',
      'type': 'ra',
      'name': 'Random Day',
      'frt': 10,
      'rrt': 2,
      'fti': 80,
      'rti': 60,
      'st': 360,
      'direction': 'alt',
    },
    {
      'wave_uid': '0f0bdf17-92d2-4e38-bbb0-4eb7f640a57d',
      'type': 're',
      'name': 'Regular Night',
      'frt': 10,
      'rrt': 2,
      'fti': 30,
      'rti': 60,
      'st': 1320,
      'direction': 'alt',
    },
  ],
};

/// The same unit's `/dashboard`, abridged to the fields the card reads.
const _dashboard = {
  'mode': 'auto',
  'water_level': 'desired_level_2',
  'is_pump_on': false,
  'today_fills': 4,
  'today_volume_usage': 1630,
  'daily_volume_average': 2969,
  'volume_left': 3467,
  'days_till_empty': 1,
  'leak_sensor': {'connected': true, 'enabled': true, 'status': 'dry'},
  'ato_sensor': {
    'is_sensor_error': false,
    'is_temp_enabled': true,
    'connected': true,
    'current_read': 24.96,
  },
};

void main() {
  late HttpServer server;
  late String host;

  /// What this test's device answers `/device-info` and `/dashboard` with —
  /// set in the test body to play a different family. Defaults to the RSATO+.
  late Map<String, Object?> deviceInfo;
  late Map<String, Object?> dashboard;

  /// Paths this device does **not** serve (404) — a firmware that lacks an
  /// endpoint, or a head that will not answer.
  late Set<String> missing;

  /// Every path the link asked for, in order. The point of several tests below
  /// is the request set itself, not the decoded snapshot.
  late List<String> requested;

  /// Serves the real endpoints; `/flood` and friends stand in for whatever
  /// else answers on port 80 across a household LAN.
  Future<void> start() async {
    deviceInfo = Map.of(_deviceInfo);
    dashboard = Map.of(_dashboard);
    missing = <String>{};
    requested = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    host = '127.0.0.1:${server.port}';
    server.listen((request) async {
      final response = request.response;
      requested.add(request.uri.path);
      // Match the *first* segment: the link builds its own paths, so a hostile
      // route is reached by passing `127.0.0.1:port/flood` as the host and
      // letting it append `/dosing-queue`.
      final segments = request.uri.pathSegments;
      final route = segments.isEmpty ? '' : '/${segments.first}';
      if (missing.contains(request.uri.path)) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      switch (route) {
        case '/device-info':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(deviceInfo));
        case '/dashboard':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(dashboard));
        case '/mode':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(_waveMode));
        case '/auto':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(_waveAuto));
        case '/head':
          // `/head/<n>/settings`
          final n = segments.length == 3 && segments.last == 'settings'
              ? int.tryParse(segments[1])
              : null;
          if (n == null) {
            response.statusCode = HttpStatus.notFound;
          } else {
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode(_headSettings(n)));
          }
        case '/flood':
          // Chunked (no Content-Length, so the up-front check can't fire):
          // 4 MB in 64 KB pieces, the shape of a media server streaming a file.
          final chunk = List.filled(64 * 1024, 0x41);
          for (var i = 0; i < 64; i++) {
            response.add(chunk);
          }
        case '/declared':
          // Honest about a size that is over the ceiling — the fast path.
          final body = utf8.encode('x' * (300 * 1024));
          response.headers.contentLength = body.length;
          response.add(body);
        case '/gzipbomb':
          // 8 MB of zeros, gzipped to a few KB. `Content-Length` therefore
          // *declares* a small body, and `autoUncompress` expands it on the
          // way in: only a counter on the drain catches this.
          final bomb = gzip.encode(List.filled(8 * 1024 * 1024, 0));
          response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          response.headers.contentLength = bomb.length;
          response.add(bomb);
        case '/router':
          response.headers.contentType = ContentType.html;
          response.write('<html><body>Login</body></html>');
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
  }

  setUp(start);
  tearDown(() => server.close(force: true));

  test('reads a real device with the production ceiling in place', () async {
    final link = RbHttpLink(timeout: const Duration(seconds: 5));
    final snapshot = await link.readOnce(host);
    expect(snapshot.info.hwid, '8813bf641cd8');
    expect(snapshot.info.hwModel, 'RSATO+');
    expect(snapshot.ato, isNotNull);
  });

  test('the probe ceiling is far above a real identity payload', () async {
    // The point of the number: /device-info is a few hundred bytes, so the
    // discovery instance's 64 KB is headroom, not a limit anyone can hit.
    expect(
      jsonEncode(_deviceInfo).length,
      lessThan(kDeviceProbeMaxBytes ~/ 50),
    );
    final link = RbHttpLink(
      timeout: const Duration(seconds: 5),
      maxResponseBytes: kDeviceProbeMaxBytes,
    );
    expect((await link.identify(host)).hwid, '8813bf641cd8');
  });

  test('reads ReefControl probes from one dashboard request', () async {
    deviceInfo = Map.of(_controlDeviceInfo);
    dashboard = Map.of(_controlDashboard);

    final snapshot = await RbHttpLink(
      timeout: const Duration(seconds: 5),
    ).readOnce(host);

    expect(requested, ['/device-info', '/dashboard']);
    expect(snapshot.modelDisplayName, 'ReefControl Pro');
    expect(snapshot.control?.probes, hasLength(3));
    expect(snapshot.control?.probeOf('ec')?.salinityPpt, 35.8);
    expect(snapshot.control?.probeOf('ph')?.value, 8.06);
    expect(snapshot.control?.probeOf('orp')?.value, 81);
    expect(snapshot.dose, isNull);
    expect(snapshot.ato, isNull);
    expect(snapshot.wave, isNull);
  });

  group('ReefWave', () {
    // The one family with no `/dashboard` and a two-endpoint read. Its wiring
    // in `readOnce` shares no path with the five families the rest of the suite
    // covers, so nothing else would notice if it were pointed at the wrong
    // endpoints.
    setUp(() => deviceInfo = Map.of(_waveDeviceInfo));

    RbHttpLink link() => RbHttpLink(timeout: const Duration(seconds: 5));

    test(
      'is read from /mode and /auto, and never asks for /dashboard',
      () async {
        final snapshot = await link().readOnce(host);

        expect(requested, ['/device-info', '/mode', '/auto']);
        expect(requested, isNot(contains('/dashboard')));
        final wave = snapshot.wave;
        expect(wave, isNotNull);
        expect(snapshot.dose, isNull);
        expect(snapshot.ato, isNull);
        expect(wave!.mode, 'auto');
        expect(wave.scheduleApplies, isTrue);
        // The schedule is the only place a wave pump's output appears at all.
        expect(wave.intervals, hasLength(3));
        expect(wave.forwardPercentAt(12 * 60), 80);
        expect(snapshot.modelDisplayName, 'ReefWave 25');
      },
    );

    test('/mode is required: without it there is no snapshot', () async {
      missing.add('/mode');
      await expectLater(
        link().readOnce(host),
        throwsA(
          isA<RbLinkException>().having(
            (e) => e.error,
            'error',
            RbLinkError.protocol,
          ),
        ),
      );
      // And it gives up there — no /auto, and still no attempt at /dashboard.
      expect(requested, ['/device-info', '/mode']);
    });

    test('/auto is optional: a pump that will not serve it still reads, '
        'just without a schedule', () async {
      missing.add('/auto');
      final snapshot = await link().readOnce(host);

      expect(requested, ['/device-info', '/mode', '/auto']);
      expect(snapshot.wave!.mode, 'auto');
      expect(snapshot.wave!.intervals, isEmpty);
      expect(snapshot.wave!.forwardPercentAt(12 * 60), isNull);
    });
  });

  group('ReefDose', () {
    // The transport half only — `rb_protocol_test.dart` already pins what the
    // parser does with the payloads.
    setUp(() {
      deviceInfo = Map.of(_doseDeviceInfo);
      dashboard = Map.of(_doseDashboard);
    });

    RbHttpLink link() => RbHttpLink(timeout: const Duration(seconds: 5));

    test('asks for the dashboard and then each reported head\'s settings, at '
        'exactly those paths', () async {
      final snapshot = await link().readOnce(host);

      // The paths are load-bearing: a typo in `/head/${n}/settings` nulls every
      // abbreviation without failing anything, because `_tryGetJson` swallows
      // the 404 by design.
      expect(requested, [
        '/device-info',
        '/dashboard',
        '/head/1/settings',
        '/head/4/settings',
      ]);
      // A refresh never touches the queue — that is a separate, on-demand read.
      expect(requested, isNot(contains('/dosing-queue')));

      final heads = snapshot.dose!.heads;
      expect(heads.map((h) => h.number), [1, 4]);
      expect(heads.map((h) => h.shortName), ['KH', 'NPX']);
      // What the abbreviations are *for*: mapping a queued dose to a head.
      expect(snapshot.dose!.headForShortName('NPX')?.supplement, 'NO3PO4-X');
    });

    test('a head whose settings do not answer costs that head its '
        'abbreviation, not the refresh', () async {
      missing.add('/head/4/settings');
      final snapshot = await link().readOnce(host);

      expect(requested, [
        '/device-info',
        '/dashboard',
        '/head/1/settings',
        '/head/4/settings',
      ]);
      final heads = snapshot.dose!.heads;
      // Both heads still have a full row from `/dashboard`…
      expect(heads.map((h) => h.number), [1, 4]);
      expect(heads.last.supplement, 'NO3PO4-X');
      expect(heads.last.dailyDose, 6);
      // …and only the queue mapping is lost, which is the whole visible cost.
      expect(heads.map((h) => h.shortName), ['KH', null]);
      expect(snapshot.dose!.headForShortName('NPX'), isNull);
      expect(snapshot.dose!.headForShortName('KH')?.number, 1);
    });

    test('the cap is above anything Red Sea ships, so a real pump fans out '
        'in full', () async {
      // The point of the number: the biggest ReefDose has 4 heads, so the
      // bound below can only ever fire on a payload no pump produced.
      expect(
        (_doseDashboard['heads']! as Map).length,
        lessThan(kRbMaxDoseHeads),
      );
      await link().readOnce(host);
      expect(requested.where((p) => p.startsWith('/head/')), hasLength(2));
    });

    test('a dashboard advertising hundreds of heads is capped at '
        'kRbMaxDoseHeads settings requests', () async {
      // The hostile case the bound exists for: an unauthenticated LAN host (or
      // a re-used DHCP address) answering on the pump's IP. Unbounded, this is
      // 300 sequential GETs, each with a 6 s timeout, behind a spinner that
      // cannot be cancelled. Numbered high-to-low so the test also proves the
      // cap keeps the *lowest* heads (the sorted ones a real pump reports),
      // not whichever the firmware happened to serialize first.
      dashboard = {
        'battery_level': 'high',
        'time_error': false,
        'heads': {
          for (var n = 300; n >= 1; n--)
            '$n': (_doseDashboard['heads']! as Map)['1'],
        },
      };

      final snapshot = await link().readOnce(host);

      final headRequests = requested
          .where((p) => p.startsWith('/head/'))
          .toList();
      expect(headRequests, hasLength(kRbMaxDoseHeads));
      expect(requested, hasLength(2 + kRbMaxDoseHeads));
      expect(headRequests, [
        for (var n = 1; n <= kRbMaxDoseHeads; n++) '/head/$n/settings',
      ]);

      // The parse is unaffected — only the fan-out is bounded — so the heads
      // past the cap still get their `/dashboard` row, just no abbreviation.
      final heads = snapshot.dose!.heads;
      expect(heads, hasLength(300));
      expect(heads.first.number, 1);
      expect(heads.first.shortName, 'KH');
      expect(heads[kRbMaxDoseHeads].shortName, isNull);
      expect(heads.last.shortName, isNull);
    });
  });

  group('the #72 cap', () {
    Future<void> expectRefused(String path, {int max = 128 * 1024}) async {
      final link = RbHttpLink(
        timeout: const Duration(seconds: 10),
        maxResponseBytes: max,
      );
      await expectLater(
        link.readDosingQueue('$host$path'),
        throwsA(
          isA<RbLinkException>()
              .having((e) => e.error, 'error', RbLinkError.protocol)
              .having((e) => e.detail, 'detail', contains('cap')),
        ),
      );
    }

    test('a chunked flood is refused instead of buffered', () async {
      // 4 MB served, 128 KB allowed. Without the cap this is a String the size
      // of whatever the host feels like sending.
      await expectRefused('/flood');
    });

    test('a declared over-size length is refused up front', () async {
      await expectRefused('/declared');
    });

    test('a gzip bomb is caught on the drain, not by Content-Length', () async {
      // The declared length is a few KB — under the ceiling — so this can only
      // be caught by counting decompressed bytes.
      await expectRefused('/gzipbomb');
    });

    test('the cap does not change what a non-device host reports', () async {
      // A router admin page was a protocol error before the cap and still is:
      // the ceiling must not turn "not a reef device" into something else.
      final link = RbHttpLink(
        timeout: const Duration(seconds: 5),
        maxResponseBytes: kDeviceProbeMaxBytes,
      );
      await expectLater(
        link.identify('$host/router'),
        throwsA(
          isA<RbLinkException>().having(
            (e) => e.error,
            'error',
            RbLinkError.protocol,
          ),
        ),
      );
    });
  });
}
