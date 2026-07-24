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

Map<String, Object?> _decode(String s) =>
    jsonDecode(s) as Map<String, Object?>;

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
      expect(status.sensorWarning, isFalse);
      expect(status.temperatureC, closeTo(24.965, 0.001));
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

  group('rbStockSeverity', () {
    test('thresholds: red below $kRbStockCriticalDays days, amber below '
        '$kRbStockCautionDays', () {
      expect(rbStockSeverity(0), RbStockSeverity.critical);
      expect(rbStockSeverity(kRbStockCriticalDays - 1), RbStockSeverity.critical);
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
      expect(rbModelDisplayName('RSWAVE'), 'RSWAVE');
    });
  });
}
