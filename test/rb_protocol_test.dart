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
      expect(rbModelDisplayName('RSWAVE'), 'RSWAVE');
    });
  });
}
