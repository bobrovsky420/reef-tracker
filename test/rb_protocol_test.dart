import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rb_protocol.dart';

/// Golden vector: a live RSDOSE4's `GET /device-info` (2026-07-24).
const _deviceInfoJson = '''
{
  "hw_type": "reef-dosing",
  "hw_model": "RSDOSE4",
  "name": "RSDOSE4-1752835676",
  "status": "unpaired",
  "hwid": "cc7b5c267a68"
}
''';

/// Golden vector: the same pump's `GET /dashboard` (abridged to two heads —
/// heads 1 and 4 of the capture; the full payload has four identical shapes).
const _dashboardJson = '''
{
  "restore_settings": true,
  "is_active": false,
  "battery_level": "high",
  "time_error": false,
  "bundled_heads": false,
  "heads": {
    "1": {
      "supplement": "Balling light KH",
      "state": "on",
      "auto_dosed_today": 26.7,
      "manual_dosed_today": 0,
      "doses_today": 4,
      "daily_dose": 40,
      "remaining_days": 117,
      "stock_level": "high",
      "recalibration_required": false,
      "missed_dose": {
        "missed_volume": 0,
        "total_volume": 0
      },
      "is_food_head": false,
      "shortcut_code": "no_shortcut",
      "daily_doses": 6
    },
    "4": {
      "supplement": "NO3PO4-X",
      "state": "on",
      "auto_dosed_today": 6,
      "manual_dosed_today": 0,
      "doses_today": 1,
      "daily_dose": 6,
      "remaining_days": 48,
      "stock_level": "high",
      "recalibration_required": false,
      "missed_dose": {
        "missed_volume": 0,
        "total_volume": 0
      },
      "is_food_head": false,
      "shortcut_code": "no_shortcut",
      "daily_doses": 1
    }
  }
}
''';

/// Golden vector: a live RSATO+'s `GET /device-info` (2026-07-24).
const _atoDeviceInfoJson = '''
{
  "name": "RSATO+3625739455",
  "hw_type": "reef-ato",
  "hw_model": "RSATO+",
  "hw_revision": "V1.2A_24C",
  "hwid": "8813bf641cd8",
  "success": true,
  "message": "get device info successfully"
}
''';

/// Golden vector: the same unit's `GET /dashboard` (2026-07-24, abridged to
/// the fields the parser reads plus a few it must ignore).
const _atoDashboardJson = '''
{
  "mode": "auto",
  "is_internet_connected": true,
  "water_level": "desired_level_2",
  "pump_state": "off",
  "is_pump_on": false,
  "pump_speed": 58,
  "flow_rate": 1650,
  "today_fills": 4,
  "today_volume_usage": 1630,
  "total_volume_usage": 18533,
  "total_fills": 1734,
  "daily_fills_average": 4.5,
  "daily_volume_average": 2969,
  "volume_left": 3467,
  "days_till_empty": 1,
  "leak_sensor": {
    "connected": true,
    "enabled": true,
    "buzzer_enabled": true,
    "buzzer_on": false,
    "current_read": 0,
    "status": "dry"
  },
  "ato_sensor": {
    "is_sensor_error": false,
    "is_temp_enabled": true,
    "connected": true,
    "current_level": "desired",
    "is_calibrated": true,
    "current_read": 24.964999675750732,
    "temperature_probe_status": "connected"
  }
}
''';

/// Golden vector: the same RSATO+'s `GET /dashboard` while its leak sensor
/// was standing in RO/DI water (2026-08-01) — the unit switches `mode` to
/// "leak", stops the pump and sounds the buzzer.
const _atoLeakDashboardJson = '''
{
  "mode": "leak",
  "active_shortcut": "no_shortcut",
  "is_internet_connected": true,
  "check_sensor": false,
  "s1_average": 450,
  "s2_average": 386,
  "water_level": "desired_level_2",
  "pump_state": "off",
  "prev_pump_state": "pump_on",
  "is_pump_on": false,
  "last_pump_on_cause": "ec_sensor_s1",
  "pump_consumption": 0,
  "pump_speed": 58,
  "flow_rate": 1700,
  "pump_soft_blockage_threshold": 0,
  "pump_blockage_threshold": 1167.60009765625,
  "pump_empty_threshold": 729.75,
  "last_fill_date": 1785555430,
  "today_fills": 3,
  "today_volume_usage": 1217,
  "total_volume_usage": 0,
  "total_fills": 1783,
  "daily_fills_average": null,
  "daily_volume_average": null,
  "volume_left": 26000,
  "days_till_empty": null,
  "leak_sensor": {
    "connected": true,
    "enabled": true,
    "buzzer_enabled": true,
    "buzzer_on": true,
    "current_read": 5,
    "status": "rodi_water_leak"
  },
  "ato_sensor": {
    "is_sensor_error": false,
    "is_temp_enabled": true,
    "temperature_log_enabled": true,
    "connected": true,
    "last_installation_date": 1750146309,
    "current_level": "desired",
    "code": "509",
    "is_calibrated": true,
    "last_adjustment_date": null,
    "current_read": 25.7149996757507,
    "temperature_probe_status": "connected"
  }
}
''';

/// Golden vector: a live RSMAT250's `GET /device-info` (2026-07-25). Mats
/// report only "RSMAT" as the model — the width lives in `/configuration`,
/// which the app doesn't read.
const _matDeviceInfoJson = '''
{
  "name": "RSMAT-4099969749",
  "hw_type": "reef-mat",
  "hw_model": "RSMAT",
  "hw_revision": "v1.0_24A",
  "hwid": "c4d8d59260f4",
  "success": true,
  "message": "get device info successfully"
}
''';

/// Golden vector: the RSDOSE4's `GET /head/1/settings` (2026-07-26), trimmed
/// to the block that matters — `supplement.short_name` is the abbreviation the
/// dosing queue labels a dose with, and `/dashboard` reports only the full
/// `name`.
const _headSettingsJson = '''
{
  "state": "on",
  "container_volume": 4654.109,
  "vps": 0.059848,
  "supplement": {
    "uid": "19c1c766-407f-47e3-a4ea-71cecd4c0d31",
    "name": "Balling light KH",
    "display_name": "KH",
    "short_name": "KH",
    "brand_name": "Fauna Marine"
  },
  "schedule": {"type": "custom", "dd": 40, "days": [1,2,3,4,5,6,7]}
}
''';

/// Golden vector: the RSDOSE4's `GET /dosing-queue` (2026-07-26, 08:10 local)
/// — a JSON *array* of the doses still due today. The KH head runs 6 doses a
/// day and had delivered one, so five remain; the three heads that dose once a
/// day had already run and are absent entirely.
const _dosingQueueJson = '''
[
  {"head":"KH","time":37200,"volume":6.666667,"dose_type":"Auto"},
  {"head":"KH","time":45600,"volume":6.666667,"dose_type":"Auto"},
  {"head":"KH","time":54000,"volume":6.666667,"dose_type":"Auto"},
  {"head":"KH","time":62400,"volume":6.666667,"dose_type":"Auto"},
  {"head":"KH","time":70800,"volume":6.666667,"dose_type":"Auto"}
]
''';

/// Golden vector: the same mat's `GET /dashboard` (2026-07-25) — a *running*
/// mat that already reports `remaining_length: 0`, which is why neither that
/// nor `roll_level` may be read as "the roll is spent".
const _matDashboardJson = '''
{
  "mode": "auto",
  "is_internet_connected": true,
  "is_ec_sensor_connected": true,
  "unclean_sensor": false,
  "auto_advance": true,
  "is_advancing": false,
  "last_advance_cause": "ec_sensor",
  "roll_level": "running_low",
  "days_till_end_of_roll": 0,
  "internal_ec_average": 0,
  "external_ec_average": 0,
  "setup_date": "2026-06-06T11:40:55Z",
  "cumulative_steps": 12630,
  "device_setup_date": 1766490401,
  "lifetime_steps": 71843,
  "today_usage": 41,
  "daily_average_usage": 84.1,
  "total_usage": 3250.2,
  "remaining_length": 0,
  "material": {
    "name": "32 Meter",
    "external_diameter": 10.6,
    "thickness": 0.023,
    "is_partial": false
  }
}
''';

/// Golden vector: the same mat's `GET /dashboard` (2026-07-26) once the roll
/// had genuinely run out and the mat had stopped — `mode` is the only field
/// that changed meaningfully from [_matDashboardJson].
const _matEndOfRollDashboardJson = '''
{
  "mode": "end_of_roll",
  "is_internet_connected": true,
  "is_ec_sensor_connected": true,
  "unclean_sensor": false,
  "auto_advance": true,
  "is_advancing": false,
  "last_advance_cause": "button",
  "roll_level": "empty",
  "days_till_end_of_roll": 0,
  "internal_ec_average": 0,
  "external_ec_average": 0,
  "setup_date": "2026-06-06T11:40:55Z",
  "cumulative_steps": 12917,
  "device_setup_date": 1766490401,
  "lifetime_steps": 72130,
  "today_usage": 12.4,
  "daily_average_usage": 85.6,
  "total_usage": 3291,
  "remaining_length": 0,
  "material": {
    "name": "32 Meter",
    "external_diameter": 10.6,
    "thickness": 0.023,
    "is_partial": false
  }
}
''';

Map<String, Object?> _decode(String s) => jsonDecode(s) as Map<String, Object?>;

void main() {
  group('RbDeviceInfo.fromJson', () {
    test('parses the RSDOSE4 golden vector', () {
      final info = RbDeviceInfo.fromJson(_decode(_deviceInfoJson))!;
      expect(info.hwType, 'reef-dosing');
      expect(info.hwType, kRbDosingHwType);
      expect(info.hwModel, 'RSDOSE4');
      expect(info.hwid, 'cc7b5c267a68');
      expect(info.name, 'RSDOSE4-1752835676');
      expect(info.status, 'unpaired');
    });

    test('returns null without the identity fields', () {
      // A non-ReefBeat host answering 200 with some other JSON must not be
      // mistaken for a device.
      expect(RbDeviceInfo.fromJson(const {}), isNull);
      expect(RbDeviceInfo.fromJson(const {'hw_type': 'reef-dosing'}), isNull);
      expect(
        RbDeviceInfo.fromJson(const {
          'hw_type': 'reef-dosing',
          'hw_model': 42, // wrong type
          'hwid': 'abc',
        }),
        isNull,
      );
    });
  });

  group('RbDoseStatus.fromJson', () {
    test('parses the RSDOSE4 golden vector', () {
      final status = RbDoseStatus.fromJson(_decode(_dashboardJson));
      expect(status.batteryLevel, 'high');
      expect(status.batteryWarning, isFalse);
      expect(status.timeError, isFalse);
      expect(status.heads, hasLength(2));

      final kh = status.heads[0];
      expect(kh.number, 1);
      expect(kh.supplement, 'Balling light KH');
      expect(kh.enabled, isTrue);
      expect(kh.autoDosedToday, 26.7);
      expect(kh.manualDosedToday, 0);
      expect(kh.dosedToday, 26.7);
      expect(kh.dailyDose, 40);
      expect(kh.dosesToday, 4);
      expect(kh.dailyDoses, 6);
      expect(kh.remainingDays, 117);
      expect(kh.stockLevel, 'high');
      expect(kh.recalibrationRequired, isFalse);
      expect(kh.missedVolume, 0);
      expect(kh.isFoodHead, isFalse);

      // Heads are sorted by number even when the map isn't.
      expect(status.heads[1].number, 4);
      expect(status.heads[1].supplement, 'NO3PO4-X');
    });

    test('a 2-head pump (RSDOSE2) parses the same way', () {
      final status = RbDoseStatus.fromJson({
        'battery_level': 'low',
        'time_error': true,
        'heads': {
          '2': {'supplement': 'B', 'daily_dose': 10},
          '1': {'supplement': 'A', 'daily_dose': 5},
        },
      });
      expect(status.batteryWarning, isTrue);
      expect(status.timeError, isTrue);
      expect(
        [for (final h in status.heads) (h.number, h.supplement)],
        [(1, 'A'), (2, 'B')],
      );
    });

    test('tolerates missing and malformed fields (firmware drift)', () {
      final status = RbDoseStatus.fromJson({
        'heads': {
          '1': <String, Object?>{}, // everything absent
          '2': {
            'state': 'off',
            'missed_dose': {'missed_volume': 3.5},
            'recalibration_required': true,
          },
          'x': {'supplement': 'bad key'}, // non-numeric head key → skipped
          '3': 'not an object', // → skipped
        },
      });
      expect(status.heads, hasLength(2));
      final bare = status.heads[0];
      expect(bare.supplement, isNull);
      expect(bare.enabled, isTrue);
      expect(bare.dosedToday, 0);
      expect(bare.dailyDose, isNull);
      expect(bare.remainingDays, isNull);
      final off = status.heads[1];
      expect(off.enabled, isFalse);
      expect(off.missedVolume, 3.5);
      expect(off.recalibrationRequired, isTrue);
    });

    test('schedule progress ignores manual dosing', () {
      // Live capture 2026-07-28: head 1 had finished its 44 ml plan and then
      // received 30 ml by hand. The total is 74 ml, but the plan is done and
      // nothing is due — the gauge must not read 74 of 44.
      final head = RbDoseHead.fromJson(1, {
        'auto_dosed_today': 44,
        'manual_dosed_today': 30,
        'daily_dose': 44,
        'doses_today': 6,
        'daily_doses': 6,
      });
      expect(head.dosedToday, 74);
      expect(head.scheduledRemaining, 0);
      expect(head.planComplete, isTrue);
    });

    test('scheduled volume still due is what the plan has left', () {
      final head = RbDoseHead.fromJson(1, {
        'auto_dosed_today': 26.7,
        'manual_dosed_today': 12,
        'daily_dose': 40,
      });
      expect(head.scheduledRemaining, closeTo(13.3, 1e-9));
      expect(head.planComplete, isFalse);
    });

    test('over-delivery counts as a finished plan, never a negative debt', () {
      // Missed-dose recovery can push the day past its scheduled total.
      final head = RbDoseHead.fromJson(1, {
        'auto_dosed_today': 48,
        'daily_dose': 44,
      });
      expect(head.scheduledRemaining, 0);
      expect(head.planComplete, isTrue);
    });

    test('a head with no schedule has nothing due and nothing to complete', () {
      for (final daily in [null, 0]) {
        final head = RbDoseHead.fromJson(1, {
          'auto_dosed_today': 0,
          'manual_dosed_today': 30,
          'daily_dose': ?daily,
        });
        expect(head.scheduledRemaining, isNull, reason: 'daily_dose=$daily');
        expect(head.planComplete, isFalse, reason: 'daily_dose=$daily');
        expect(head.dosedToday, 30, reason: 'daily_dose=$daily');
      }
    });

    test('head settings add the supplement abbreviation', () {
      final status = RbDoseStatus.fromJson(
        {
          'heads': {
            '1': {'supplement': 'Balling light KH'},
            '2': {'supplement': 'Zinc'},
            '3': {'supplement': 'Nickel'},
          },
        },
        headSettings: {
          1: _decode(_headSettingsJson),
          // Malformed / partial settings must not cost the head its row.
          2: const {'supplement': 'not an object'},
          // Head 3 wasn't readable at all.
        },
      );
      expect([for (final h in status.heads) h.shortName], ['KH', null, null]);
    });

    test('a queued abbreviation resolves to its head', () {
      final status = RbDoseStatus.fromJson(
        {
          'heads': {
            '1': {'supplement': 'Balling light KH'},
            '2': {'supplement': 'Zinc'},
          },
        },
        headSettings: {
          1: const {
            'supplement': {'short_name': 'KH'},
          },
          2: const {
            'supplement': {'short_name': 'Zin'},
          },
        },
      );
      expect(status.headForShortName('Zin')?.supplement, 'Zinc');
      // The queue's casing/padding must not decide whether a head is found.
      expect(status.headForShortName(' zin ')?.number, 2);
      expect(status.headForShortName('KH')?.number, 1);
      // Reassigned since the last refresh, or never read → no match.
      expect(status.headForShortName('Mg'), isNull);
      expect(status.headForShortName(''), isNull);
      expect(status.headForShortName(null), isNull);
    });

    test('an empty or heads-less payload yields no heads', () {
      expect(RbDoseStatus.fromJson(const {}).heads, isEmpty);
      expect(RbDoseStatus.fromJson(const {'heads': 7}).heads, isEmpty);
    });

    test('daily_doses: 0 marks a head switched off even with state "on"', () {
      final status = RbDoseStatus.fromJson({
        'heads': {
          '1': {'state': 'on', 'daily_doses': 0},
          '2': {'state': 'on', 'daily_doses': 3},
          '3': {'state': 'off', 'daily_doses': 3},
          '4': {'state': 'on'}, // daily_doses absent → tolerant, NOT off
        },
      });
      expect(
        [for (final h in status.heads) h.switchedOff],
        [true, false, true, false],
      );
    });
  });

  group('RbDoseQueueEntry.listFromJson', () {
    test('parses the RSDOSE4 golden vector', () {
      final queue = RbDoseQueueEntry.listFromJson(
        jsonDecode(_dosingQueueJson) as List<Object?>,
      );
      expect(queue, hasLength(5));
      expect(queue.first.head, 'KH');
      expect(queue.first.secondsFromMidnight, 37200);
      expect(queue.first.hour, 10);
      expect(queue.first.minute, 20);
      expect(queue.first.volumeMl, closeTo(6.666667, 0.000001));
      expect(queue.first.doseType, 'Auto');
      expect(queue.last.hour, 19);
      expect(queue.last.minute, 40);
    });

    test('orders by time and drops entries without a usable one', () {
      final queue = RbDoseQueueEntry.listFromJson(const [
        {'head': 'Ca', 'time': 45600},
        {'head': 'KH', 'time': 3600},
        {'head': 'Mg'}, // no time at all
        {'head': 'NO3', 'time': 'noon'}, // unparseable
        {'head': 'PO4', 'time': -1}, // before midnight
        {'head': 'Fe', 'time': 86400}, // a whole day out
        'not an object',
      ]);
      expect([for (final e in queue) e.head], ['KH', 'Ca']);
    });

    test('an empty queue is a finished day, not a failure', () {
      expect(RbDoseQueueEntry.listFromJson(const []), isEmpty);
    });
  });

  group('RbAtoStatus.fromJson', () {
    test('parses the RSATO+ golden vector', () {
      final info = RbDeviceInfo.fromJson(_decode(_atoDeviceInfoJson))!;
      expect(info.hwType, kRbAtoHwType);
      expect(info.hwModel, 'RSATO+');
      expect(info.hwid, '8813bf641cd8');

      final status = RbAtoStatus.fromJson(_decode(_atoDashboardJson));
      expect(status.waterLevelRaw, 'desired_level_2');
      expect(status.waterLevel, RbAtoWaterLevel.ok);
      expect(status.isPumpOn, isFalse);
      expect(status.todayFills, 4);
      expect(status.todayVolumeMl, 1630);
      expect(status.dailyVolumeAvgMl, 2969);
      expect(status.volumeLeftMl, 3467);
      expect(status.daysTillEmpty, 1);
      expect(status.leakAlarm, isFalse);
      // The sensor is attached and switched on, standing dry — that is what
      // earns the card its quiet "Leak sensor: Dry" row.
      expect(status.leakSensorActive, isTrue);
      expect(status.leakStatusRaw, 'dry');
      expect(status.sensorWarning, isFalse);
      expect(status.temperatureC, closeTo(24.965, 0.001));
    });

    test('parses the leak-mode golden vector', () {
      final status = RbAtoStatus.fromJson(_decode(_atoLeakDashboardJson));
      expect(status.leakAlarm, isTrue);
      expect(status.leakSensorActive, isTrue);
      expect(status.leakStatusRaw, 'rodi_water_leak');
      // The rest of the dashboard stays readable through the alarm — the
      // nulled averages must degrade to absent, not crash the parse.
      expect(status.waterLevel, RbAtoWaterLevel.ok);
      expect(status.todayFills, 3);
      expect(status.dailyVolumeAvgMl, isNull);
      expect(status.daysTillEmpty, isNull);
      expect(status.volumeLeftMl, 26000);
      expect(status.temperatureC, closeTo(25.715, 0.001));
    });

    test('water-level strings map to coarse levels', () {
      RbAtoWaterLevel of(String? raw) =>
          RbAtoStatus(waterLevelRaw: raw).waterLevel;
      expect(of('desired_level_2'), RbAtoWaterLevel.ok);
      expect(of('desired'), RbAtoWaterLevel.ok);
      expect(of('low_level'), RbAtoWaterLevel.low);
      expect(of('too_high'), RbAtoWaterLevel.high);
      expect(of('something_else'), RbAtoWaterLevel.unknown);
      expect(of(null), RbAtoWaterLevel.unknown);
    });

    test('leak alarms only from an active connected sensor', () {
      bool alarm(Map<String, Object?> leak) =>
          RbAtoStatus.fromJson({'leak_sensor': leak}).leakAlarm;
      expect(
        alarm({'connected': true, 'enabled': true, 'status': 'wet'}),
        isTrue,
      );
      expect(
        alarm({'connected': true, 'enabled': true, 'status': 'dry'}),
        isFalse,
      );
      expect(
        alarm({'connected': true, 'enabled': false, 'status': 'wet'}),
        isFalse,
      );
      expect(
        alarm({'connected': false, 'enabled': true, 'status': 'wet'}),
        isFalse,
      );
      // Enabled flag absent stays tolerant — a connected wet sensor alarms.
      expect(alarm({'connected': true, 'status': 'wet'}), isTrue);
    });

    test('the leak-sensor row only exists for an attached, enabled sensor', () {
      bool active(Object? leak) =>
          RbAtoStatus.fromJson({'leak_sensor': leak}).leakSensorActive;
      expect(
        active({'connected': true, 'enabled': true, 'status': 'dry'}),
        isTrue,
      );
      expect(active({'connected': true, 'status': 'dry'}), isTrue);
      expect(active({'connected': false, 'enabled': true}), isFalse);
      expect(active({'connected': true, 'enabled': false}), isFalse);
      expect(active(null), isFalse);
      expect(active('nope'), isFalse);
    });

    test('sensor warning on error or disconnect; temperature suppressed when '
        'disabled or unplugged', () {
      final err = RbAtoStatus.fromJson({
        'ato_sensor': {'is_sensor_error': true, 'current_read': 25.0},
      });
      expect(err.sensorWarning, isTrue);
      expect(err.temperatureC, 25.0);

      final gone = RbAtoStatus.fromJson({
        'ato_sensor': {'connected': false},
      });
      expect(gone.sensorWarning, isTrue);

      final tempOff = RbAtoStatus.fromJson({
        'ato_sensor': {'is_temp_enabled': false, 'current_read': 25.0},
      });
      expect(tempOff.temperatureC, isNull);

      final probeGone = RbAtoStatus.fromJson({
        'ato_sensor': {
          'temperature_probe_status': 'disconnected',
          'current_read': 25.0,
        },
      });
      expect(probeGone.temperatureC, isNull);
    });

    test('tolerates an empty or malformed payload (firmware drift)', () {
      final status = RbAtoStatus.fromJson(const {
        'leak_sensor': 'nope',
        'ato_sensor': 7,
        'today_fills': 'four',
      });
      expect(status.waterLevel, RbAtoWaterLevel.unknown);
      expect(status.isPumpOn, isFalse);
      expect(status.todayFills, isNull);
      expect(status.todayVolumeMl, isNull);
      expect(status.volumeLeftMl, isNull);
      expect(status.daysTillEmpty, isNull);
      expect(status.leakAlarm, isFalse);
      expect(status.sensorWarning, isFalse);
      expect(status.temperatureC, isNull);
    });
  });

  group('RbMatStatus.fromJson', () {
    test('parses the RSMAT identity golden vector', () {
      final info = RbDeviceInfo.fromJson(_decode(_matDeviceInfoJson))!;
      expect(info.hwType, kRbMatHwType);
      expect(info.hwModel, 'RSMAT');
      expect(info.hwid, 'c4d8d59260f4');
    });

    test('parses the RSMAT250 golden vector', () {
      final status = RbMatStatus.fromJson(_decode(_matDashboardJson));
      expect(status.modeRaw, 'auto');
      expect(status.rollLevelRaw, 'running_low');
      expect(status.rollLevel, RbRollLevel.low);
      expect(status.daysTillEndOfRoll, 0);
      expect(status.remainingLengthCm, 0);
      expect(status.materialName, '32 Meter');
      expect(status.rollLengthCm, 3200);
      expect(status.usedTodayCm, 41);
      expect(status.dailyAverageCm, 84.1);
      expect(status.autoAdvance, isTrue);
      expect(status.isAdvancing, isFalse);
      expect(status.uncleanSensor, isFalse);
      expect(
        status.rollInstalledAt,
        DateTime.utc(2026, 6, 6, 11, 40, 55).toLocal(),
      );
      // Still running: `remaining_length: 0` is not the end of the roll, so no
      // end-of-roll warning — only the urgency the day count earns.
      expect(status.rollSpent, isFalse);
      expect(status.rollSeverity, RbStockSeverity.critical);
    });

    test('parses the end-of-roll golden vector', () {
      final status = RbMatStatus.fromJson(_decode(_matEndOfRollDashboardJson));
      expect(status.modeRaw, 'end_of_roll');
      expect(status.rollSpent, isTrue);
      expect(status.rollSeverity, RbStockSeverity.critical);
      expect(status.usedTodayCm, 12.4);
      expect(status.dailyAverageCm, 85.6);
    });

    test('only the end_of_roll mode marks the roll spent', () {
      bool spent({String? mode, String? level, double? remaining}) =>
          RbMatStatus(
            modeRaw: mode,
            rollLevelRaw: level,
            remainingLengthCm: remaining,
          ).rollSpent;
      expect(spent(mode: 'end_of_roll'), isTrue);
      expect(spent(mode: 'END_OF_ROLL'), isTrue);
      // Everything the firmware reports short of that mode is still running.
      expect(spent(mode: 'auto', level: 'empty', remaining: 0), isFalse);
      expect(spent(level: 'end_of_roll'), isFalse);
      expect(spent(remaining: 0), isFalse);
      expect(spent(), isFalse);
    });

    test('roll level coarsens the firmware strings', () {
      RbRollLevel level(String? raw) =>
          RbMatStatus(rollLevelRaw: raw).rollLevel;
      expect(level('high'), RbRollLevel.ok);
      expect(level('normal'), RbRollLevel.ok);
      expect(level('running_low'), RbRollLevel.low);
      expect(level('low'), RbRollLevel.low);
      expect(level('empty'), RbRollLevel.empty);
      // "end of roll" wins over the "low" it may be reported alongside.
      expect(level('end_of_roll'), RbRollLevel.empty);
      expect(level('something_new'), RbRollLevel.unknown);
      expect(level(''), RbRollLevel.unknown);
      expect(level(null), RbRollLevel.unknown);
    });

    test('severity prefers the reported days, then the coarse level', () {
      RbStockSeverity? sev({
        int? days,
        String? level,
        double? remaining,
        String? mode,
      }) => RbMatStatus(
        modeRaw: mode,
        daysTillEndOfRoll: days,
        rollLevelRaw: level,
        remainingLengthCm: remaining,
      ).rollSeverity;
      expect(sev(days: 30, level: 'high'), RbStockSeverity.healthy);
      expect(sev(days: 10, level: 'high'), RbStockSeverity.caution);
      expect(sev(days: 3, level: 'high'), RbStockSeverity.critical);
      // A generous day count can't outrank a mat that has stopped.
      expect(sev(days: 30, mode: 'end_of_roll'), RbStockSeverity.critical);
      // No days reported → fall back to the level.
      expect(sev(level: 'high'), RbStockSeverity.healthy);
      expect(sev(level: 'running_low'), RbStockSeverity.caution);
      expect(sev(level: 'empty'), RbStockSeverity.critical);
      // Nothing to go on → nothing to color.
      expect(sev(), isNull);
    });

    test('roll length comes from the material name', () {
      expect(RbMatStatus.parseRollLengthCm('32 Meter'), 3200);
      expect(RbMatStatus.parseRollLengthCm('12 Meter'), 1200);
      expect(RbMatStatus.parseRollLengthCm('7.5 Meter'), 750);
      expect(RbMatStatus.parseRollLengthCm('7,5 Meter'), 750);
      expect(RbMatStatus.parseRollLengthCm('Custom roll'), isNull);
      expect(RbMatStatus.parseRollLengthCm('0 Meter'), isNull);
      expect(RbMatStatus.parseRollLengthCm(null), isNull);
    });

    test('tolerates an empty or malformed payload (firmware drift)', () {
      final status = RbMatStatus.fromJson(const {
        'material': 'nope',
        'today_usage': 'lots',
        'setup_date': 42,
        'mode': 7,
      });
      expect(status.modeRaw, isNull);
      expect(status.rollLevel, RbRollLevel.unknown);
      expect(status.daysTillEndOfRoll, isNull);
      expect(status.remainingLengthCm, isNull);
      expect(status.rollLengthCm, isNull);
      expect(status.usedTodayCm, isNull);
      expect(status.dailyAverageCm, isNull);
      expect(status.rollInstalledAt, isNull);
      expect(status.rollSpent, isFalse);
      expect(status.rollSeverity, isNull);
      // Absent flags must not raise warning chips out of nowhere.
      expect(status.autoAdvance, isTrue);
      expect(status.isAdvancing, isFalse);
      expect(status.uncleanSensor, isFalse);
    });

    test('flags the states the card warns about', () {
      final status = RbMatStatus.fromJson(const {
        'auto_advance': false,
        'is_advancing': true,
        'unclean_sensor': true,
      });
      expect(status.autoAdvance, isFalse);
      expect(status.isAdvancing, isTrue);
      expect(status.uncleanSensor, isTrue);
    });
  });

  group('rbStockSeverity', () {
    test('thresholds: red below $kRbStockCriticalDays days, amber below '
        '$kRbStockCautionDays', () {
      expect(rbStockSeverity(0), RbStockSeverity.critical);
      expect(
        rbStockSeverity(kRbStockCriticalDays - 1),
        RbStockSeverity.critical,
      );
      expect(rbStockSeverity(kRbStockCriticalDays), RbStockSeverity.caution);
      expect(rbStockSeverity(kRbStockCautionDays - 1), RbStockSeverity.caution);
      expect(rbStockSeverity(kRbStockCautionDays), RbStockSeverity.healthy);
      expect(rbStockSeverity(117), RbStockSeverity.healthy);
    });
  });

  group('rbModelDisplayName', () {
    test('maps known models and falls back to the raw code', () {
      expect(rbModelDisplayName('RSDOSE4'), 'ReefDose 4');
      expect(rbModelDisplayName('RSDOSE2'), 'ReefDose 2');
      expect(rbModelDisplayName('RSATO+'), 'ReefATO+');
      expect(rbModelDisplayName('RSMAT'), 'ReefMat');
      expect(rbModelDisplayName('RSMAT250'), 'ReefMat 250');
      expect(rbModelDisplayName('RSRUN'), 'ReefRun');
      expect(rbModelDisplayName('RSLED90'), 'ReefLED 90');
      expect(rbModelDisplayName('RSWAVE25'), 'ReefWave 25');
      expect(rbModelDisplayName('RSWAVE'), 'RSWAVE');
    });
  });

  group('rbIsWaveModel', () {
    test('recognises a wave from the stored model alone', () {
      // The dashboard groups wave pumps before any device has been read, so
      // this must work off `Devices.model` with no `hw_type` available.
      expect(rbIsWaveModel('RSWAVE25'), isTrue);
      expect(rbIsWaveModel('RSWAVE45'), isTrue);
      // Prefix-matched, so an unreleased variant still groups.
      expect(rbIsWaveModel('RSWAVE99X'), isTrue);
      expect(rbIsWaveModel('rswave25'), isTrue);

      expect(rbIsWaveModel('RSDOSE4'), isFalse);
      expect(rbIsWaveModel('RSATO+'), isFalse);
      expect(rbIsWaveModel('RSMAT250'), isFalse);
      expect(rbIsWaveModel('RSRUN'), isFalse);
      expect(rbIsWaveModel('RSLED90'), isFalse);
      expect(rbIsWaveModel(null), isFalse);
      expect(rbIsWaveModel(''), isFalse);
    });
  });

  group('RbMatStatus model code', () {
    test('takes the sized model from /configuration', () {
      // `/device-info` reports a bare "RSMAT"; only the configuration knows the
      // width. Golden vector: a live RSMAT250 (2026-07-25).
      final status = RbMatStatus.fromJson(
        jsonDecode('{"roll_level": "running_low"}') as Map<String, Object?>,
        configuration:
            jsonDecode('{"auto_advance": true, "model": "RSMAT250"}')
                as Map<String, Object?>,
      );
      expect(status.modelCode, 'RSMAT250');
      expect(rbModelDisplayName(status.modelCode!), 'ReefMat 250');
    });

    test('stays null when the configuration is unreadable', () {
      final status = RbMatStatus.fromJson(
        jsonDecode('{"roll_level": "running_low"}') as Map<String, Object?>,
      );
      expect(status.modelCode, isNull);
    });
  });

  group('RbRunStatus', () {
    /// Golden vector: a live RSRUN's `GET /dashboard` (2026-07-25).
    const runDashboardJson = '''
{
  "mode": "auto",
  "is_internet_connected": true,
  "battery_level": "high",
  "time_error": false,
  "linked": false,
  "synced": true,
  "ec_sensor_connected": true,
  "pump_1": {
    "name": "Return pump",
    "type": "return",
    "model": "return-6",
    "state": "operational",
    "sensor_controlled": false,
    "missing_pump": false,
    "missing_sensor": false,
    "schedule_enabled": true,
    "intensity": 80,
    "pulse": 0,
    "temperature": 28.292682647705078
  },
  "pump_2": {
    "name": "Skimmer",
    "type": "skimmer",
    "model": "rsk-300",
    "state": "operational",
    "sensor_controlled": true,
    "missing_pump": false,
    "missing_sensor": false,
    "schedule_enabled": true,
    "intensity": 70,
    "pulse": 0,
    "temperature": 40.243900299072266
  }
}
''';

    test('decodes both pump sockets in order', () {
      final status = RbRunStatus.fromJson(
        jsonDecode(runDashboardJson) as Map<String, Object?>,
      );
      expect(status.pumps, hasLength(2));
      expect(status.batteryWarning, isFalse);
      expect(status.timeError, isFalse);

      final returnPump = status.pumps.first;
      expect(returnPump.number, 1);
      expect(returnPump.name, 'Return pump');
      expect(returnPump.type, 'return');
      expect(returnPump.intensity, 80);
      expect(returnPump.temperatureC, closeTo(28.3, 0.05));
      expect(returnPump.faulted, isFalse);
      expect(returnPump.sensorControlled, isFalse);

      expect(status.pumps[1].name, 'Skimmer');
      expect(status.pumps[1].intensity, 70);
      expect(status.pumps[1].sensorControlled, isTrue);
    });

    test('a lost EC sensor only warns when a pump actually follows it', () {
      Map<String, Object?> withSensor({required bool controlled}) => {
        'ec_sensor_connected': false,
        'pump_1': {'name': 'Skimmer', 'sensor_controlled': controlled},
      };
      expect(
        RbRunStatus.fromJson(withSensor(controlled: true)).sensorWarning,
        isTrue,
      );
      expect(
        RbRunStatus.fromJson(withSensor(controlled: false)).sensorWarning,
        isFalse,
      );
    });

    test('a non-operational state is a fault, an absent one is not', () {
      expect(RbRunPump.fromJson(1, {'state': 'blocked'}).faulted, isTrue);
      expect(RbRunPump.fromJson(1, {'state': 'operational'}).faulted, isFalse);
      expect(RbRunPump.fromJson(1, const {}).faulted, isFalse);
    });

    test('a full skimmer cup is recognized among the fault states', () {
      final full = RbRunPump.fromJson(2, {'state': 'full_cup'});
      expect(full.fullCup, isTrue);
      // Still a fault — the pump has paused itself — but the card labels it
      // "Full cup" instead of echoing the raw state.
      expect(full.faulted, isTrue);
      expect(RbRunPump.fromJson(2, {'state': 'blocked'}).fullCup, isFalse);
      expect(RbRunPump.fromJson(2, const {}).fullCup, isFalse);
    });

    test('skips keys that are not pump sockets', () {
      final status = RbRunStatus.fromJson({
        'pump_1': {'intensity': 50},
        'pump_state': 'nonsense',
        'mode': 'auto',
      });
      expect(status.pumps, hasLength(1));
    });
  });

  group('RbLightStatus', () {
    /// Golden vector: a live RSLED90's `GET /dashboard` (2026-07-25).
    const lightDashboardJson = '''
{
  "mode": "auto",
  "battery_level": "high",
  "time_error": false,
  "tilt_switch": false,
  "acclimation": {
    "enabled": false,
    "duration": 50,
    "remaining_days": 0,
    "start_intensity_factor": 70,
    "current_intensity_factor": 100
  },
  "moon_phase": {
    "enabled": false,
    "name": "Waning Crescent",
    "intensity": 100,
    "todays_moon_day": 24
  },
  "manual": {
    "white": 20,
    "white_pwm": 1832,
    "blue": 80,
    "blue_pwm": 3889,
    "moon": 0,
    "fan": 100,
    "temperature": 60.11334228515625
  },
  "current_program": {
    "active_preset": 7,
    "name": "Winter Time-1769330261387"
  }
}
''';

    test('decodes channels, heatsink temperature and program', () {
      final status = RbLightStatus.fromJson(
        jsonDecode(lightDashboardJson) as Map<String, Object?>,
      );
      expect(status.mode, 'auto');
      expect(status.whitePercent, 20);
      expect(status.bluePercent, 80);
      expect(status.moonPercent, 0);
      expect(status.fanPercent, 100);
      expect(status.temperatureC, closeTo(60.1, 0.05));
      expect(status.tiltSwitch, isFalse);
      expect(status.acclimationEnabled, isFalse);
      expect(status.moonPhaseEnabled, isFalse);
      expect(status.moonPhaseName, 'Waning Crescent');
      expect(status.moonDay, 24);
    });

    test(
      'strips the epoch suffix the ReefBeat app appends to program names',
      () {
        expect(
          RbLightStatus.cleanProgramName('Winter Time-1769330261387'),
          'Winter Time',
        );
        // A program legitimately ending in a short number must survive.
        expect(RbLightStatus.cleanProgramName('Blue-2'), 'Blue-2');
        expect(RbLightStatus.cleanProgramName('Ramp-2024'), 'Ramp-2024');
        expect(RbLightStatus.cleanProgramName(null), isNull);
      },
    );

    test('a payload missing every optional block still decodes', () {
      final status = RbLightStatus.fromJson(const {'mode': 'manual'});
      expect(status.mode, 'manual');
      expect(status.whitePercent, isNull);
      expect(status.programName, isNull);
      expect(status.acclimationEnabled, isFalse);
    });
  });

  group('RbWaveStatus', () {
    /// Golden vectors: a live RSWAVE25's `GET /mode` and `GET /wifi`
    /// (2026-07-25). It serves no `/dashboard` at all.
    const waveModeJson = '{"mode": "auto"}';

    test('decodes the mode on its own', () {
      final status = RbWaveStatus.fromJson(
        jsonDecode(waveModeJson) as Map<String, Object?>,
      );
      expect(status.mode, 'auto');
      expect(status.intervals, isEmpty);
    });

    /// Golden vector: a live RSWAVE25's `GET /auto` (2026-07-25) — the day's
    /// wave schedule, the only place the pump's output appears.
    const waveAutoJson = '''
{
  "uid": "587543e6-1c55-499d-8839-6f0084154aaa",
  "intervals": [
    {
      "wave_uid": "0f0bdf17-92d2-4e38-bbb0-4eb7f640a57d",
      "type": "re", "name": "Regular Night",
      "frt": 10, "rrt": 2, "fti": 30, "rti": 60,
      "st": 0, "direction": "alt"
    },
    {
      "wave_uid": "01bff951-dc93-4655-8349-405b82e20025",
      "type": "ra", "name": "Random Day",
      "frt": 10, "rrt": 2, "fti": 80, "rti": 60,
      "st": 360, "direction": "alt"
    },
    {
      "wave_uid": "0f0bdf17-92d2-4e38-bbb0-4eb7f640a57d",
      "type": "re", "name": "Regular Night",
      "frt": 10, "rrt": 2, "fti": 30, "rti": 60,
      "st": 1320, "direction": "alt"
    }
  ]
}
''';

    RbWaveStatus withSchedule({String mode = 'auto', String? auto}) =>
        RbWaveStatus.fromJson({
          'mode': mode,
        }, auto: jsonDecode(auto ?? waveAutoJson) as Map<String, Object?>);

    test('decodes the wave schedule', () {
      final status = withSchedule();
      expect(status.intervals, hasLength(3));
      final day = status.intervals[1];
      expect(day.startMinute, 360);
      expect(day.forwardPercent, 80);
      expect(day.reversePercent, 60);
      expect(day.forwardMinutes, 10);
      expect(day.reverseMinutes, 2);
      expect(day.name, 'Random Day');
      expect(day.type, 'ra');
      expect(day.direction, 'alt');
    });

    test('resolves the forward output for the time of day', () {
      final status = withSchedule();
      int? at(int h, int m) => status.forwardPercentAt(h * 60 + m);
      expect(at(0, 0), 30); // exactly on the first boundary
      expect(at(3, 0), 30); // night
      expect(at(5, 59), 30); // one minute before the day interval
      expect(at(6, 0), 80); // exactly on the boundary → the new interval
      expect(at(16, 50), 80); // the live check that matched the pump
      expect(at(21, 59), 80);
      expect(at(22, 0), 30); // back to night
      expect(at(23, 59), 30);
    });

    test('before the first interval the previous day is still running', () {
      // A schedule that starts at 06:00 has nothing "current" at 02:00 unless
      // the day is treated as wrapping — the pump is running the last interval.
      final status = withSchedule(
        auto:
            '{"intervals":['
            '{"st":360,"fti":80},'
            '{"st":1320,"fti":25}]}',
      );
      expect(status.forwardPercentAt(2 * 60), 25);
      expect(status.intervalAt(2 * 60)?.startMinute, 1320);
    });

    test('an out-of-order or partial schedule still resolves', () {
      final status = withSchedule(
        auto:
            '{"intervals":['
            '{"st":1320,"fti":30},'
            '{"st":0,"fti":10},'
            '{"name":"broken, no st or fti"},'
            '{"st":360,"fti":80}]}',
      );
      expect(status.intervals, hasLength(3)); // the broken entry is dropped
      expect(status.intervals.first.startMinute, 0); // sorted
      expect(status.forwardPercentAt(12 * 60), 80);
    });

    test('no schedule at all yields no percentage', () {
      final status = RbWaveStatus.fromJson(const {'mode': 'auto'});
      expect(status.intervals, isEmpty);
      expect(status.forwardPercentAt(600), isNull);
      expect(status.intervalAt(600), isNull);
    });

    test('the schedule only describes the pump while it is in auto', () {
      expect(withSchedule().scheduleApplies, isTrue);
      expect(withSchedule(mode: 'manual').scheduleApplies, isFalse);
      // An absent mode stays optimistic rather than caveating out of nowhere.
      expect(const RbWaveStatus().scheduleApplies, isTrue);
    });
  });

  group('kRbSupportedHwTypes', () {
    test('covers every family with a parser, and nothing else', () {
      expect(kRbSupportedHwTypes, {
        kRbDosingHwType,
        kRbAtoHwType,
        kRbMatHwType,
        kRbRunHwType,
        kRbLightsHwType,
        kRbWaveHwType,
      });
      expect(kRbSupportedHwTypes.contains('reef-something-new'), isFalse);
    });
  });

  group('wrong-typed fields (#84)', () {
    // The tolerance contract, exercised where it used to break: a firmware
    // update serving a number where a string used to be must degrade the
    // field to null, never crash the refresh as a TypeError.
    test('every string slot tolerates a number', () {
      final info = RbDeviceInfo.fromJson(const {
        'hw_type': 'reef-dosing',
        'hw_model': 'RSDOSE4',
        'hwid': 'cc7b5c267a68',
        'name': 42,
        'status': 1,
      })!;
      expect(info.name, isNull);
      expect(info.status, isNull);

      final dose = RbDoseStatus.fromJson(const {
        'battery_level': 3,
        'heads': {
          '1': {'supplement': 7, 'stock_level': 2, 'state': 'on'},
        },
      });
      expect(dose.batteryLevel, isNull);
      expect(dose.heads.single.supplement, isNull);
      expect(dose.heads.single.stockLevel, isNull);

      final queue = RbDoseQueueEntry.fromJson(const {
        'time': 37200,
        'head': 4,
        'dose_type': 1,
      })!;
      expect(queue.head, isNull);
      expect(queue.doseType, isNull);

      expect(
        RbAtoStatus.fromJson(const {'water_level': 2}).waterLevelRaw,
        isNull,
      );

      final mat = RbMatStatus.fromJson(const {
        'mode': 1,
        'roll_level': 0,
        'material': {'name': 32},
      });
      expect(mat.modeRaw, isNull);
      expect(mat.rollLevelRaw, isNull);
      expect(mat.materialName, isNull);

      final run = RbRunStatus.fromJson(const {
        'battery_level': 9,
        'pump_1': {'name': 1, 'type': 2, 'model': 3, 'state': 4},
      });
      expect(run.batteryLevel, isNull);
      expect(run.pumps.single.name, isNull);
      expect(run.pumps.single.state, isNull);
      // An unreadable state must stay optimistic, not read as a fault.
      expect(run.pumps.single.faulted, isFalse);

      final light = RbLightStatus.fromJson(const {
        'mode': 1,
        'battery_level': 0,
        'current_program': {'name': 5},
        'moon_phase': {'enabled': true, 'name': 3},
      });
      expect(light.mode, isNull);
      expect(light.programName, isNull);
      expect(light.moonPhaseName, isNull);

      final wave = RbWaveStatus.fromJson(
        const {'mode': 1},
        auto: const {
          'intervals': [
            {'st': 0, 'fti': 60, 'name': 2, 'type': 3, 'direction': 4},
          ],
        },
      );
      expect(wave.mode, isNull);
      expect(wave.intervals.single.name, isNull);
      // An unreadable mode stays optimistic, like an absent one.
      expect(wave.scheduleApplies, isTrue);
    });
  });
}
