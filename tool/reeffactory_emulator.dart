// A fake ReefFactory meter, for developing and testing the ReefFactory
// integration without owning one (T18 — the CLAUDE.md hardware rule).
//
// It serves the same WebSocket surface a real meter does — `ws://<ip>/controler`,
// subprotocol `arduino`, binary NUL-delimited frames — for all three supported
// models, with slowly drifting values so the Devices page has something live
// to show:
//
//     dart run tool/reeffactory_emulator.dart                        # RFSG01 on :80
//     dart run tool/reeffactory_emulator.dart --model ph --port 8081
//     dart run tool/reeffactory_emulator.dart --model temperature --port 8082
//
// ## Reaching it from the Android emulator
//
// The Android emulator sees the host machine as **10.0.2.2**. Start this on
// Windows, then in the app's "Add device" sheet (or via Scan network) enter:
//
//     10.0.2.2         (when this runs on the default port 80)
//     10.0.2.2:8081    (when started with --port 8081)
//
// ## Control endpoints (emulator-only, not part of the device protocol)
//
//     GET /emu                          a plain-text summary of the current state
//     GET /emu/set?conductivity=51.2    pin the salinity meter's conductivity (mS/cm)
//     GET /emu/set?temperature=26.1     pin the temperature (°C; SG and TC)
//     GET /emu/set?ph=7.9               pin the pH monitor's value
//     GET /emu/set?clear=1              clear every pin (drift resumes)
//
// The server class is deliberately importable: rf_device_link_test.dart drives
// a real RfWebSocketLink against it, so the connect/join handshake state
// machine, the error mapping and the teardown are covered end to end rather
// than only by frame-level unit tests. The framing here is hand-rolled (not
// imported from rf_protocol.dart) on purpose — the fake is an independent
// speaker of the wire format, so a codec regression cannot hide by breaking
// both sides identically.
//
// HONESTY NOTE: this emulator is written from the recorded frames and the
// firmware transcriptions in rf_protocol.dart; the suite has still never run
// against real ReefFactory hardware.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Which meter the emulator presents.
enum RfEmuModel { salinity, ph, temperature }

class ReefFactoryEmulator {
  ReefFactoryEmulator({
    this.model = RfEmuModel.salinity,
    String? serial,
    this.port = 0,
  }) : serial = serial ?? _defaultSerial(model);

  /// Requested port; 0 binds an ephemeral one (see [boundPort]).
  final int port;
  final RfEmuModel model;

  /// 16-char device serial; its first 6 characters are the model prefix the
  /// app dispatches on (RFSG01/RFPM01/RFTC01). Override with an unknown
  /// prefix to play a found-but-unsupported device.
  final String serial;

  // --- Test knobs (set before the client connects) --------------------------

  /// Accept the WebSocket upgrade, then close immediately — the
  /// "closed early" protocol-error path.
  bool closeAfterUpgrade = false;

  /// Accept the upgrade and never answer anything — the timeout path.
  bool silent = false;

  /// Answer `get/config` but never the join — timeout after a good identify.
  bool ignoreJoin = false;

  /// Send a stray TEXT frame before the config reply — must be ignored by
  /// the binary-only listener.
  bool textFrameBeforeConfig = false;

  /// Reply to the join with an empty `settings` payload — the parser returns
  /// no readings and the link must surface a protocol error, not a snapshot.
  bool emptySettingsPayload = false;

  // --- Simulated measurements ----------------------------------------------

  /// In-situ conductivity in mS/cm (salinity model). ~53 mS/cm ≈ 35 ppt at
  /// 25 °C.
  double conductivity = 53.0;
  double temperatureC = 25.0;
  double ph = 8.2;

  /// Pinned via `/emu/set` (or directly from a test); null = drift.
  double? pinnedConductivity;
  double? pinnedTemperature;
  double? pinnedPh;

  HttpServer? _server;
  final _sockets = <WebSocket>[];
  final _started = DateTime.now().millisecondsSinceEpoch;

  /// The actually bound port (differs from [port] when it was 0).
  int get boundPort => _server!.port;

  static String _defaultSerial(RfEmuModel model) => switch (model) {
    RfEmuModel.salinity => 'RFSG01EMU0000001',
    RfEmuModel.ph => 'RFPM01EMU0000001',
    RfEmuModel.temperature => 'RFTC01EMU0000001',
  };

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  Future<void> stop() async {
    for (final s in _sockets) {
      await s.close();
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void _handle(HttpRequest request) {
    if (request.uri.path == '/controler' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      unawaited(
        WebSocketTransformer.upgrade(
          request,
          protocolSelector: (protocols) => 'arduino',
        ).then(_serve, onError: (Object _) {}),
      );
      return;
    }
    if (request.uri.path.startsWith('/emu')) {
      _handleEmu(request);
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    unawaited(request.response.close());
  }

  void _serve(WebSocket socket) {
    _sockets.add(socket);
    if (closeAfterUpgrade) {
      unawaited(socket.close());
      return;
    }
    if (silent) return;
    socket.listen(
      (data) {
        if (data is! List<int>) return;
        final fields = _decodeFields(data);
        if (fields.length < 3) return;
        final command = fields[1];
        final subcommand = fields[2];
        if (command == 'get' && subcommand == 'config') {
          if (textFrameBeforeConfig) {
            socket.add('midi connected'); // a TEXT frame, like a chatty host
          }
          // refresh/config: payload is the NUL-terminated serial.
          socket.add(
            _encodeFrame(
              serial: serial,
              command: 'refresh',
              subcommand: 'config',
              payload: [...serial.codeUnits, 0],
            ),
          );
        } else if (command == _connectCommand && subcommand == 'join') {
          if (ignoreJoin) return;
          socket.add(
            _encodeFrame(
              serial: serial,
              command: _refreshCommand,
              subcommand: 'settings',
              payload: emptySettingsPayload ? const [] : _settingsPayload(),
            ),
          );
        }
      },
      onError: (Object _) {},
      cancelOnError: true,
    );
  }

  String get _connectCommand => switch (model) {
    RfEmuModel.salinity => 'sgConnect',
    RfEmuModel.ph => 'pmConnect',
    RfEmuModel.temperature => 'tcConnect',
  };

  String get _refreshCommand => switch (model) {
    RfEmuModel.salinity => 'sgRefresh',
    RfEmuModel.ph => 'pmRefresh',
    RfEmuModel.temperature => 'tcRefresh',
  };

  /// A slow sine so values move on the live dashboard; pinned values win.
  double _drift(double base, double swing, [double phase = 0]) {
    final t = (DateTime.now().millisecondsSinceEpoch - _started) / 1000.0;
    return base + swing * sin(t / 60 * 2 * pi + phase);
  }

  double get _conductivityNow =>
      pinnedConductivity ?? _drift(conductivity, 0.4);
  double get _temperatureNow =>
      pinnedTemperature ?? _drift(temperatureC, 0.2, 1);
  double get _phNow => pinnedPh ?? _drift(ph, 0.05, 2);

  List<int> _settingsPayload() {
    switch (model) {
      case RfEmuModel.salinity:
        // 43 bytes: conductivity ×10000 int32 BE at 0, temperature ×10000
        // int32 BE at 39, the rest opaque config the parser skips.
        final p = Uint8List(43);
        final bd = ByteData.sublistView(p);
        bd.setInt32(0, (_conductivityNow * 10000).round(), Endian.big);
        bd.setInt32(39, (_temperatureNow * 10000).round(), Endian.big);
        return p;
      case RfEmuModel.ph:
        // 13 bytes: pH ×10000 int32 BE at 0, then unit byte + alarm bounds.
        final p = Uint8List(13);
        final bd = ByteData.sublistView(p);
        bd.setInt32(0, (_phNow * 10000).round(), Endian.big);
        bd.setInt32(5, 70000, Endian.big); // alarm low 7.0
        bd.setInt32(9, 90000, Endian.big); // alarm high 9.0
        return p;
      case RfEmuModel.temperature:
        // 25 bytes per the RfTc01Main layout (×1000, unit byte 0 = °C).
        final p = Uint8List(25);
        final bd = ByteData.sublistView(p);
        bd.setInt32(0, (_temperatureNow * 1000).round(), Endian.big);
        p[4] = 0; // °C
        bd.setInt32(5, 23000, Endian.big); // alarm low
        bd.setInt32(9, 25000, Endian.big); // heating setpoint
        p[13] = _temperatureNow < 25.0 ? 1 : 0; // heating output
        bd.setInt32(14, 28000, Endian.big); // alarm high
        bd.setInt32(18, 27000, Endian.big); // cooling setpoint
        p[22] = _temperatureNow > 27.0 ? 1 : 0; // cooling output
        p[24] = 0x11; // sound + light on
        return p;
    }
  }

  // --- Wire format (hand-rolled on purpose, see the header note) ------------

  /// `serial\0 command\0 subcommand\0 msgId\0 payload\0`.
  static Uint8List _encodeFrame({
    required String serial,
    required String command,
    required String subcommand,
    String msgId = '',
    List<int> payload = const [],
  }) {
    final b = BytesBuilder();
    for (final field in [serial, command, subcommand, msgId]) {
      b
        ..add(field.codeUnits)
        ..addByte(0);
    }
    b
      ..add(payload)
      ..addByte(0);
    return b.toBytes();
  }

  /// Splits the leading NUL-delimited string fields (serial, command,
  /// subcommand, msgId); the payload after them is not needed server-side.
  static List<String> _decodeFields(List<int> data) {
    final fields = <String>[];
    var start = 0;
    for (var i = 0; i < data.length && fields.length < 4; i++) {
      if (data[i] == 0) {
        fields.add(String.fromCharCodes(data, start, i));
        start = i + 1;
      }
    }
    return fields;
  }

  void _handleEmu(HttpRequest request) {
    final q = request.uri.queryParameters;
    if (request.uri.path == '/emu/set') {
      if (q['clear'] != null) {
        pinnedConductivity = null;
        pinnedTemperature = null;
        pinnedPh = null;
      }
      final c = double.tryParse(q['conductivity'] ?? '');
      if (c != null) pinnedConductivity = c;
      final t = double.tryParse(q['temperature'] ?? '');
      if (t != null) pinnedTemperature = t;
      final p = double.tryParse(q['ph'] ?? '');
      if (p != null) pinnedPh = p;
    }
    request.response
      ..headers.contentType = ContentType.text
      ..write(
        'ReefFactory emulator — model: ${model.name}, serial: $serial\n'
        'conductivity: ${_conductivityNow.toStringAsFixed(2)} mS/cm'
        '${pinnedConductivity != null ? ' (pinned)' : ''}\n'
        'temperature: ${_temperatureNow.toStringAsFixed(2)} °C'
        '${pinnedTemperature != null ? ' (pinned)' : ''}\n'
        'pH: ${_phNow.toStringAsFixed(2)}'
        '${pinnedPh != null ? ' (pinned)' : ''}\n',
      );
    unawaited(request.response.close());
  }
}

Future<void> main(List<String> args) async {
  var port = 80;
  var model = RfEmuModel.salinity;
  String? serial;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--model':
        model = RfEmuModel.values.byName(args[++i]);
      case '--serial':
        serial = args[++i];
    }
  }
  final emu = ReefFactoryEmulator(model: model, serial: serial, port: port);
  await emu.start();
  stdout.writeln(
    'ReefFactory ${model.name} emulator (${emu.serial}) on '
    'ws://localhost:${emu.boundPort}/controler — from the Android emulator: '
    '10.0.2.2:${emu.boundPort}',
  );
}
