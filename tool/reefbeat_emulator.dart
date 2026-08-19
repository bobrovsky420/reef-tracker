// A fake Red Sea ReefBeat device, for developing and testing the U38
// integration without owning the hardware.
//
// One process serves one device from any supported ReefBeat family. The
// forceable ATO, Run, Dose and Control payloads preserve their captured live
// vectors; Mat, Light and Wave provide stable protocol-valid development
// fixtures so every sealed family can be exercised end to end.
//
//     dart run tool/reefbeat_emulator.dart                  # ATO on :8090
//     dart run tool/reefbeat_emulator.dart --type run --port 8091
//     dart run tool/reefbeat_emulator.dart --type dose --port 8092
//     dart run tool/reefbeat_emulator.dart --type control --port 8093
//     dart run tool/reefbeat_emulator.dart --type mat --port 8094
//     dart run tool/reefbeat_emulator.dart --type light --port 8095
//     dart run tool/reefbeat_emulator.dart --type wave --port 8096
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
//     GET /emu/leak?status=rodi_water_leak    ATO/CONTROL: raise leak alarm
//     GET /emu/leak?status=aquarium_water_leak
//                                             ATO/CONTROL: saltwater alarm
//     GET /emu/leak?connected=false           ATO: unplug the leak sensor
//     GET /emu/leak?connected=true&enabled=false
//                                             ATO: attach but disable it
//     GET /emu/leak?status=dry&enabled=true   ATO/CONTROL: clear/enable it
//     GET /emu/pump?n=2&state=full_cup        RUN: pause the skimmer, cup full
//     GET /emu/pump?n=2&state=over-skimming   RUN: pause it, over-skimming
//     GET /emu/pump?n=2&state=operational     RUN: back to normal
//     GET /emu/dose?head=4&days=5             DOSE: force a head's stock to
//                                             5 days left (≤7 red, ≤14 amber)
//     GET /emu/ato?level=below&days=5         ATO: force the water level
//                                             (ok/below/above — the firmware
//                                             vocabulary) and the reservoir
//                                             estimate (<7 red, <14 amber)
//     GET /emu/probes?salinity=36.1&ph=7.7&orp=320
//                                             CONTROL: force primary readings
//
// The server class is deliberately importable: rb_emulator_test.dart drives a
// real RbHttpLink against it, so the transport and the parsers are covered end
// to end rather than only against hand-written fixtures.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Which device family the emulator presents.
enum EmuRbType { ato, run, dose, control, mat, light, wave }

/// A fake ReefBeat device serving `/device-info` + `/dashboard`.
class ReefBeatEmulator {
  ReefBeatEmulator({this.type = EmuRbType.ato});

  final EmuRbType type;

  /// ATO/CONTROL: the leak sensor's status string ("dry" alarms nothing).
  String leakStatus = 'dry';

  /// ATO: connection and configuration facts exposed by `leak_sensor`.
  bool leakSensorConnected = true;
  bool leakSensorEnabled = true;

  /// ATO: the firmware water-level string and the reservoir's days-till-empty
  /// estimate, forceable via /emu/ato.
  String atoWaterLevel = 'desired_level_2';
  int atoDaysTillEmpty = 8;

  /// RUN: firmware state per pump socket ("operational" / "full_cup" / …).
  final Map<int, String> pumpStates = {1: 'operational', 2: 'operational'};

  /// DOSE: days of supplement left per head, forceable via /emu/dose.
  final Map<int, int> doseRemainingDays = {1: 117, 2: 96, 3: 210, 4: 48};

  /// CONTROL: the three primary probe readings, forceable via /emu/probes.
  double controlSalinityPpt = 35.8;
  double controlPh = 8.06;
  double controlOrpMv = 81;

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
    final headSettings = _headSettingsPattern.firstMatch(path);
    final Object? body = switch (path) {
      '/device-info' => _deviceInfo(),
      '/dashboard' => _dashboard(),
      '/configuration' when type == EmuRbType.mat => const {
        'auto_advance': true,
        'model': 'RSMAT250',
      },
      '/mode' when type == EmuRbType.wave => const {'mode': 'auto'},
      '/auto' when type == EmuRbType.wave => _waveSchedule(),
      '/dosing-queue' when type == EmuRbType.dose => _dosingQueue(),
      _ when headSettings != null && type == EmuRbType.dose => _headSettings(
        int.parse(headSettings[1]!),
      ),
      '/emu' => null, // handled below (plain text)
      '/emu/leak' => _forceLeak(request.uri.queryParameters),
      '/emu/pump' => _forcePump(request.uri.queryParameters),
      '/emu/dose' => _forceDose(request.uri.queryParameters),
      '/emu/ato' => _forceAto(request.uri.queryParameters),
      '/emu/probes' => _forceProbes(request.uri.queryParameters),
      _ => null,
    };
    final response = request.response;
    if (path == '/emu') {
      response.headers.contentType = ContentType.text;
      response.write(
        'reefbeat emulator: type=${type.name} hwid=$hwid '
        'leak=$leakStatus leakConnected=$leakSensorConnected '
        'leakEnabled=$leakSensorEnabled level=$atoWaterLevel '
        'atoDays=$atoDaysTillEmpty '
        'pumps=$pumpStates doseDays=$doseRemainingDays\n'
        'probes=$controlSalinityPpt/$controlPh/$controlOrpMv\n',
      );
    } else if (body == null) {
      response.statusCode = HttpStatus.notFound;
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }
    unawaited(response.close());
  }

  static final _headSettingsPattern = RegExp(r'^/head/(\d+)/settings$');

  Map<String, Object?> _forceLeak(Map<String, String> query) {
    final status = query['status'];
    if (status != null && status.isNotEmpty) leakStatus = status;
    if (query['connected'] case final connected?) {
      leakSensorConnected = connected.toLowerCase() == 'true';
    }
    if (query['enabled'] case final enabled?) {
      leakSensorEnabled = enabled.toLowerCase() == 'true';
    }
    return {
      'leak_status': leakStatus,
      'connected': leakSensorConnected,
      'enabled': leakSensorEnabled,
    };
  }

  Map<String, Object?> _forcePump(Map<String, String> query) {
    final n = int.tryParse(query['n'] ?? '');
    final state = query['state'];
    if (n != null && state != null && state.isNotEmpty) pumpStates[n] = state;
    return {'pump_states': pumpStates.map((k, v) => MapEntry('$k', v))};
  }

  Map<String, Object?> _forceAto(Map<String, String> query) {
    // "ok" maps to a desired-level string; "below"/"above" ARE the firmware
    // strings and pass through verbatim.
    final level = query['level'];
    if (level != null && level.isNotEmpty) {
      atoWaterLevel = level == 'ok' ? 'desired_level_2' : level;
    }
    final days = int.tryParse(query['days'] ?? '');
    if (days != null) atoDaysTillEmpty = days;
    return {'water_level': atoWaterLevel, 'days_till_empty': atoDaysTillEmpty};
  }

  Map<String, Object?> _forceDose(Map<String, String> query) {
    final head = int.tryParse(query['head'] ?? '');
    final days = int.tryParse(query['days'] ?? '');
    if (head != null && days != null && doseRemainingDays.containsKey(head)) {
      doseRemainingDays[head] = days;
    }
    return {
      'remaining_days': doseRemainingDays.map((k, v) => MapEntry('$k', v)),
    };
  }

  Map<String, Object?> _forceProbes(Map<String, String> query) {
    controlSalinityPpt =
        double.tryParse(query['salinity'] ?? '') ?? controlSalinityPpt;
    controlPh = double.tryParse(query['ph'] ?? '') ?? controlPh;
    controlOrpMv = double.tryParse(query['orp'] ?? '') ?? controlOrpMv;
    return {
      'salinity': controlSalinityPpt,
      'ph': controlPh,
      'orp': controlOrpMv,
    };
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
    EmuRbType.dose => {
      'name': 'RSDOSE4-$port',
      'hw_type': 'reef-dosing',
      'hw_model': 'RSDOSE4',
      'status': 'unpaired',
      'hwid': hwid,
    },
    EmuRbType.control => {
      'name': 'RSCONTROLPRO-$port',
      'hw_type': 'reef-control',
      'hw_model': 'RSCONTROLPRO',
      'hw_revision': 'v1.3_26A',
      'hwid': hwid,
      'success': true,
      'message': 'get device info successfully',
    },
    EmuRbType.mat => {
      'name': 'RSMAT-$port',
      'hw_type': 'reef-mat',
      'hw_model': 'RSMAT',
      'hwid': hwid,
    },
    EmuRbType.light => {
      'name': 'RSLED90-$port',
      'hw_type': 'reef-lights',
      'hw_model': 'RSLED90',
      'hwid': hwid,
    },
    EmuRbType.wave => {
      'name': 'RSWAVE25-$port',
      'hw_type': 'reef-wave',
      'hw_model': 'RSWAVE25',
      'hwid': hwid,
    },
  };

  Map<String, Object?>? _dashboard() => switch (type) {
    EmuRbType.ato => _atoDashboard(),
    EmuRbType.run => _runDashboard(),
    EmuRbType.dose => _doseDashboard(),
    EmuRbType.control => _controlDashboard(),
    EmuRbType.mat => _matDashboard(),
    EmuRbType.light => _lightDashboard(),
    EmuRbType.wave => null,
  };

  Map<String, Object?> _matDashboard() => {
    'mode': 'auto',
    'roll_level': 'running_low',
    'days_till_end_of_roll': 6,
    'remaining_length': 480,
    'material': {'name': '32 Meter'},
    'today_usage': 41,
    'daily_average_usage': 84.1,
    'auto_advance': true,
    'is_advancing': false,
    'unclean_sensor': false,
    'setup_date': 1780746055,
  };

  Map<String, Object?> _lightDashboard() => {
    'mode': 'auto',
    'battery_level': 'high',
    'time_error': false,
    'tilt_switch': false,
    'manual': {
      'white': 20,
      'blue': 80,
      'moon': 0,
      'fan': 100,
      'temperature': 60.1,
    },
    'current_program': {'name': 'Reef Day-1769330261387'},
  };

  Map<String, Object?> _waveSchedule() => {
    'intervals': [
      {'st': 0, 'fti': 25, 'rti': 10, 'name': 'Night'},
      {'st': 360, 'fti': 80, 'rti': 60, 'name': 'Day'},
      {'st': 1320, 'fti': 10, 'rti': 2, 'name': 'Late'},
    ],
  };

  /// The shape captured from a live ReefControl Pro on 2026-08-13. Its two
  /// combined probes each report a compensation temperature in addition to
  /// the primary salinity/pH value, and its leak probe reports a boolean.
  Map<String, Object?> _controlDashboard() => {
    'mode': 'auto',
    'is_internet_connected': true,
    'cable_connected': false,
    'connected_device': null,
    'probes': [
      {
        'type': 'ec',
        'uid': '0x005AA',
        'measurement_unit': 'ppt',
        'value': controlSalinityPpt,
        'name': 'Salinity 5AA',
        'status': 'auto',
        'ec': 54.2,
        'ppt': controlSalinityPpt,
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
        'value': controlOrpMv,
        'level': controlOrpMv < 150 ? 'danger' : 'desired',
      },
      {
        'type': 'ph',
        'uid': '0x00579',
        'name': 'pH 579',
        'status': 'auto',
        'value': controlPh,
        'level': controlPh < 7.8 || controlPh > 8.6 ? 'danger' : 'desired',
        'temp_value': 25.8,
        'temp_level': 'desired',
      },
      {
        'type': 'leak',
        'uid': '0x0039E',
        'name': 'Leak 39E',
        'status': 'auto',
        'detected': leakStatus != 'dry',
      },
    ],
    'ports': [
      {
        'number': 0,
        'name': 'S1',
        'mode': 'setup',
        'type': 'unknown',
        'state': 'unknown',
        'user_config_mode': 'setup',
        'consumption': 0,
      },
      {
        'number': 1,
        'name': 'S2',
        'mode': 'setup',
        'type': 'unknown',
        'state': 'unknown',
        'user_config_mode': 'setup',
        'consumption': 0,
      },
    ],
    'buzzer': {'active': false, 'cause': 'none', 'dismissed': false},
    'leak_detector': true,
  };

  /// The 2026-08-01 leak-mode capture from a live RSATO+ (the leak_sensor and
  /// ato_sensor blocks verbatim), with the leak status swappable via /emu.
  Map<String, Object?> _atoDashboard() {
    final leaking =
        leakSensorConnected && leakSensorEnabled && leakStatus != 'dry';
    return {
      'mode': leaking ? 'leak' : 'auto',
      'active_shortcut': 'no_shortcut',
      'is_internet_connected': true,
      'check_sensor': false,
      's1_average': 450,
      's2_average': 386,
      'water_level': atoWaterLevel,
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
      'days_till_empty': atoDaysTillEmpty,
      'leak_sensor': {
        'connected': leakSensorConnected,
        'enabled': leakSensorEnabled,
        'buzzer_enabled': true,
        'buzzer_on': leaking,
        'current_read': switch (leakStatus) {
          'aquarium_water_leak' => 65535,
          'rodi_water_leak' => 5,
          _ => 0,
        },
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

  /// A four-head Balling setup in the shape of the 2026-07-24 RSDOSE4
  /// capture: supplement, abbreviation, ml delivered today by schedule,
  /// today's scheduled total, doses delivered and doses planned.
  static const _doseHeads = [
    (
      n: 1,
      name: 'Balling light KH',
      short: 'KH',
      dosed: 26.7,
      daily: 40.0,
      done: 4,
      plan: 6,
    ),
    (
      n: 2,
      name: 'Balling light Ca',
      short: 'Ca',
      dosed: 23.3,
      daily: 35.0,
      done: 4,
      plan: 6,
    ),
    (
      n: 3,
      name: 'Balling light Mg',
      short: 'Mg',
      dosed: 8.0,
      daily: 12.0,
      done: 2,
      plan: 3,
    ),
    (
      n: 4,
      name: 'NO3PO4-X',
      short: 'NPX',
      dosed: 6.0,
      daily: 6.0,
      done: 1,
      plan: 1,
    ),
  ];

  Map<String, Object?> _doseDashboard() => {
    'restore_settings': true,
    'is_active': false,
    'battery_level': 'high',
    'time_error': false,
    'bundled_heads': false,
    'heads': {
      for (final h in _doseHeads)
        '${h.n}': {
          'supplement': h.name,
          'state': 'on',
          'auto_dosed_today': h.dosed,
          'manual_dosed_today': 0,
          'doses_today': h.done,
          'daily_dose': h.daily,
          'remaining_days': doseRemainingDays[h.n],
          'stock_level': (doseRemainingDays[h.n] ?? 0) < 14 ? 'low' : 'high',
          'recalibration_required': false,
          'missed_dose': {'missed_volume': 0, 'total_volume': 0},
          'is_food_head': false,
          'shortcut_code': 'no_shortcut',
          'daily_doses': h.plan,
        },
    },
  };

  /// `GET /head/<n>/settings` — the only endpoint carrying the supplement's
  /// abbreviation (the label the dosing queue identifies a head by).
  Map<String, Object?>? _headSettings(int n) {
    for (final h in _doseHeads) {
      if (h.n != n) continue;
      return {
        'state': 'on',
        'container_volume': 4654.109,
        'vps': 0.059848,
        'supplement': {
          'uid': 'emu-supplement-${h.n}',
          'name': h.name,
          'display_name': h.short,
          'short_name': h.short,
          'brand_name': 'Fauna Marine',
        },
        'schedule': {
          'type': 'custom',
          'dd': h.daily,
          'days': [1, 2, 3, 4, 5, 6, 7],
        },
      };
    }
    return null;
  }

  /// `GET /dosing-queue` — what is left of today's schedule, a JSON array.
  /// Undelivered doses are spread over the next few hours; anything that
  /// would land past midnight is dropped, exactly as a real pump's shrinking
  /// end-of-day queue behaves.
  List<Object?> _dosingQueue() {
    final now = DateTime.now();
    var seconds = now.hour * 3600 + now.minute * 60;
    final queue = <Object?>[];
    for (final h in _doseHeads) {
      for (var dose = h.done + 1; dose <= h.plan; dose++) {
        seconds += 45 * 60;
        if (seconds >= 24 * 3600) break;
        queue.add({
          'time': seconds,
          'head': h.short,
          'volume': h.daily / h.plan,
          'dose_type': 'Auto',
        });
      }
    }
    return queue;
  }
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
