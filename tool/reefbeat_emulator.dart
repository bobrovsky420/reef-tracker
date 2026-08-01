// A fake Red Sea ReefBeat device, for developing and testing the U38
// integration without owning the hardware.
//
// One process serves one device: a ReefATO+ or a ReefRun controller — the two
// families with alarm states worth forcing (a leak, a full skimmer cup) that
// real hardware only shows when something is actually wrong. The payloads are
// the golden vectors captured from live devices (rb_protocol_test.dart), so
// the parsers see exactly the shapes real firmware serves.
//
//     dart run tool/reefbeat_emulator.dart                  # ATO on :8090
//     dart run tool/reefbeat_emulator.dart --type run --port 8091
//
// ## Reaching it from the Android emulator
//
// The Android emulator sees the host machine as **10.0.2.2**. Start this on
// Windows, then add the device with the address:
//
//     10.0.2.2:8090
//
// Two devices at once is two processes on two ports (each gets a distinct
// hwid from its port, so the app registers two cards).
//
// ## Control endpoints (emulator-only, not part of the ReefBeat API)
//
//     GET /emu                            plain-text summary of current state
//     GET /emu/leak?status=rodi_water_leak    ATO: raise the leak alarm
//     GET /emu/leak?status=dry                ATO: clear it
//     GET /emu/pump?n=2&state=full_cup        RUN: pause the skimmer, cup full
//     GET /emu/pump?n=2&state=operational     RUN: back to normal
//
// The server class is deliberately importable: rb_emulator_test.dart drives a
// real RbHttpLink against it, so the transport and the parsers are covered end
// to end rather than only against hand-written fixtures.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Which device family the emulator presents.
enum EmuRbType { ato, run }

/// A fake ReefBeat device serving `/device-info` + `/dashboard`.
class ReefBeatEmulator {
  ReefBeatEmulator({this.type = EmuRbType.ato});

  final EmuRbType type;

  /// ATO: the leak sensor's status string ("dry" alarms nothing).
  String leakStatus = 'dry';

  /// RUN: firmware state per pump socket ("operational" / "full_cup" / …).
  final Map<int, String> pumpStates = {1: 'operational', 2: 'operational'};

  HttpServer? _server;

  /// The bound port — meaningful once [start] returned (tests bind port 0).
  int get port => _server?.port ?? 0;

  /// MAC-style hwid derived from the port, so two instances register as two
  /// devices.
  String get hwid => 'emu${port.toRadixString(16).padLeft(9, '0')}';

  Future<void> start({String host = '0.0.0.0', int port = 8090}) async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    final Object? body = switch (path) {
      '/device-info' => _deviceInfo(),
      '/dashboard' => _dashboard(),
      '/emu' => null, // handled below (plain text)
      '/emu/leak' => _forceLeak(request.uri.queryParameters['status']),
      '/emu/pump' => _forcePump(request.uri.queryParameters),
      _ => null,
    };
    final response = request.response;
    if (path == '/emu') {
      response.headers.contentType = ContentType.text;
      response.write(
        'reefbeat emulator: type=${type.name} hwid=$hwid '
        'leak=$leakStatus pumps=$pumpStates\n',
      );
    } else if (body == null) {
      response.statusCode = HttpStatus.notFound;
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }
    unawaited(response.close());
  }

  Map<String, Object?> _forceLeak(String? status) {
    if (status != null && status.isNotEmpty) leakStatus = status;
    return {'leak_status': leakStatus};
  }

  Map<String, Object?> _forcePump(Map<String, String> query) {
    final n = int.tryParse(query['n'] ?? '');
    final state = query['state'];
    if (n != null && state != null && state.isNotEmpty) pumpStates[n] = state;
    return {'pump_states': pumpStates.map((k, v) => MapEntry('$k', v))};
  }

  Map<String, Object?> _deviceInfo() => switch (type) {
    EmuRbType.ato => {
      'name': 'RSATO+$port',
      'hw_type': 'reef-ato',
      'hw_model': 'RSATO+',
      'hw_revision': 'V1.2A_24C',
      'hwid': hwid,
      'success': true,
      'message': 'get device info successfully',
    },
    EmuRbType.run => {
      'name': 'RSRUN-$port',
      'hw_type': 'reef-run',
      'hw_model': 'RSRUN',
      'hwid': hwid,
    },
  };

  Map<String, Object?> _dashboard() => switch (type) {
    EmuRbType.ato => _atoDashboard(),
    EmuRbType.run => _runDashboard(),
  };

  /// The 2026-08-01 leak-mode capture from a live RSATO+ (the leak_sensor and
  /// ato_sensor blocks verbatim), with the leak status swappable via /emu.
  Map<String, Object?> _atoDashboard() {
    final leaking = leakStatus != 'dry';
    return {
      'mode': leaking ? 'leak' : 'auto',
      'active_shortcut': 'no_shortcut',
      'is_internet_connected': true,
      'check_sensor': false,
      's1_average': 450,
      's2_average': 386,
      'water_level': 'desired_level_2',
      'pump_state': 'off',
      'prev_pump_state': leaking ? 'pump_on' : 'off',
      'is_pump_on': false,
      'last_pump_on_cause': 'ec_sensor_s1',
      'pump_consumption': 0,
      'pump_speed': 58,
      'flow_rate': 1700,
      'today_fills': 3,
      'today_volume_usage': 1217,
      'total_volume_usage': 0,
      'total_fills': 1783,
      'daily_fills_average': 4.5,
      'daily_volume_average': 2969,
      'volume_left': 26000,
      'days_till_empty': 8,
      'leak_sensor': {
        'connected': true,
        'enabled': true,
        'buzzer_enabled': true,
        'buzzer_on': leaking,
        'current_read': leaking ? 5 : 0,
        'status': leakStatus,
      },
      'ato_sensor': {
        'is_sensor_error': false,
        'is_temp_enabled': true,
        'temperature_log_enabled': true,
        'connected': true,
        'last_installation_date': 1750146309,
        'current_level': 'desired',
        'code': '509',
        'is_calibrated': true,
        'last_adjustment_date': null,
        'current_read': 25.7149996757507,
        'temperature_probe_status': 'connected',
      },
    };
  }

  Map<String, Object?> _runDashboard() => {
    'mode': 'auto',
    'is_internet_connected': true,
    'battery_level': 'high',
    'time_error': false,
    'linked': false,
    'synced': true,
    'ec_sensor_connected': true,
    'pump_1': {
      'name': 'Return pump',
      'type': 'return',
      'model': 'return-6',
      'state': pumpStates[1],
      'sensor_controlled': false,
      'missing_pump': false,
      'missing_sensor': false,
      'schedule_enabled': true,
      'intensity': 80,
      'pulse': 0,
      'temperature': 28.292682647705078,
    },
    'pump_2': {
      'name': 'Skimmer',
      'type': 'skimmer',
      'model': 'rsk-300',
      'state': pumpStates[2],
      'sensor_controlled': true,
      'missing_pump': false,
      'missing_sensor': false,
      'schedule_enabled': true,
      // A paused skimmer isn't pushing water — the gauge should show it.
      'intensity': pumpStates[2] == 'operational' ? 70 : 0,
      'pulse': 0,
      'temperature': 40.243900299072266,
    },
  };
}

Future<void> main(List<String> args) async {
  var type = EmuRbType.ato;
  var port = 8090;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--type':
        final name = args[++i];
        type = EmuRbType.values.firstWhere(
          (t) => t.name == name,
          orElse: () => throw ArgumentError('unknown --type $name'),
        );
      case '--port':
        port = int.parse(args[++i]);
      default:
        throw ArgumentError('unknown argument ${args[i]}');
    }
  }
  final emulator = ReefBeatEmulator(type: type);
  await emulator.start(port: port);
  stdout.writeln(
    'ReefBeat ${type.name} emulator on port ${emulator.port} '
    '(Android emulator: 10.0.2.2:${emulator.port}) — GET /emu for state',
  );
}
