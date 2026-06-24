import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/database.dart';

void main() {
  group('backup encode/decode', () {
    final tanks = [
      Tank(
        id: 1,
        name: 'Reef',
        setupType: 'mixed',
        volumeLiters: 200.5,
        startDate: DateTime.fromMillisecondsSinceEpoch(1000000000000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ),
      Tank(
        id: 2,
        name: 'Nano',
        setupType: 'soft',
        volumeLiters: null,
        startDate: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000111000),
      ),
    ];
    final params = [
      TrackedParameter(
        id: 5,
        tankId: 1,
        paramKey: 'alk',
        unit: 'dKH',
        enabled: true,
        displayOrder: 0,
        amberLow: 7.0,
        greenLow: 7.5,
        greenHigh: 9.0,
        amberHigh: 9.5,
      ),
      TrackedParameter(
        id: 6,
        tankId: 1,
        paramKey: 'ph',
        unit: '',
        enabled: false,
        displayOrder: 1,
        amberLow: null,
        greenLow: null,
        greenHigh: null,
        amberHigh: null,
      ),
    ];
    final readings = [
      Reading(
        id: 10,
        tankId: 1,
        paramKey: 'alk',
        value: 8.2,
        takenAt: DateTime.fromMillisecondsSinceEpoch(1700001000000),
        note: 'after dosing',
      ),
      Reading(
        id: 11,
        tankId: 2,
        paramKey: 'ph',
        value: 8.1,
        takenAt: DateTime.fromMillisecondsSinceEpoch(1700002000000),
        note: null,
      ),
    ];
    final waterChanges = [
      WaterChange(
        id: 20,
        tankId: 1,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700003000000),
        amountLiters: 25.0,
        note: 'Tropic Marin salt',
      ),
      WaterChange(
        id: 21,
        tankId: 2,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700004000000),
        amountLiters: null,
        note: null,
      ),
    ];
    final carbonChanges = [
      CarbonChange(
        id: 30,
        tankId: 1,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700005000000),
        grams: 200.0,
        note: 'ROWAphos',
      ),
      CarbonChange(
        id: 31,
        tankId: 2,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700006000000),
        grams: null,
        note: null,
      ),
    ];
    final settings = [
      const Setting(key: 'temp_unit', value: 'fahrenheit'),
      const Setting(key: 'active_tank_id', value: '1'),
      const Setting(key: 'locale', value: null),
    ];

    test('round-trips every table preserving ids and values', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        settings: settings,
      );
      final data = decodeBackup(json);

      expect(data.tanks.length, 2);
      final t0 = data.tanks[0];
      expect(t0.id.value, 1);
      expect(t0.name.value, 'Reef');
      expect(t0.setupType.value, 'mixed');
      expect(t0.volumeLiters.value, 200.5);
      expect(t0.startDate.value, tanks[0].startDate);
      expect(t0.createdAt.value, tanks[0].createdAt);
      expect(data.tanks[1].volumeLiters.value, isNull);
      expect(data.tanks[1].startDate.value, isNull);

      final p0 = data.params[0];
      expect(p0.id.value, 5);
      expect(p0.tankId.value, 1);
      expect(p0.enabled.value, true);
      expect(p0.amberHigh.value, 9.5);
      expect(data.params[1].enabled.value, false);
      expect(data.params[1].greenLow.value, isNull);

      final r0 = data.readings[0];
      expect(r0.id.value, 10);
      expect(r0.value.value, 8.2);
      expect(r0.takenAt.value, readings[0].takenAt);
      expect(r0.note.value, 'after dosing');
      expect(data.readings[1].note.value, isNull);

      final w0 = data.waterChanges[0];
      expect(w0.id.value, 20);
      expect(w0.tankId.value, 1);
      expect(w0.changedAt.value, waterChanges[0].changedAt);
      expect(w0.amountLiters.value, 25.0);
      expect(w0.note.value, 'Tropic Marin salt');
      expect(data.waterChanges[1].amountLiters.value, isNull);
      expect(data.waterChanges[1].note.value, isNull);

      final c0 = data.carbonChanges[0];
      expect(c0.id.value, 30);
      expect(c0.tankId.value, 1);
      expect(c0.changedAt.value, carbonChanges[0].changedAt);
      expect(c0.grams.value, 200.0);
      expect(c0.note.value, 'ROWAphos');
      expect(data.carbonChanges[1].grams.value, isNull);
      expect(data.carbonChanges[1].note.value, isNull);

      expect(data.settings.length, 3);
      expect(data.settings[0].key.value, 'temp_unit');
      expect(data.settings[0].value.value, 'fahrenheit');
      expect(data.settings[2].value.value, isNull);
    });

    test('tolerates older backups without water/carbon-change sections', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        settings: settings,
      )
          .replaceFirst(
              RegExp(r',\s*"waterChanges": \[.*?\]', dotAll: true), '')
          .replaceFirst(
              RegExp(r',\s*"carbonChanges": \[.*?\]', dotAll: true), '');
      final data = decodeBackup(json);
      expect(data.waterChanges, isEmpty);
      expect(data.carbonChanges, isEmpty);
      expect(data.readings.length, 2);
    });

    test('rejects files that are not ReefTracker backups', () {
      expect(() => decodeBackup('not json'),
          throwsA(isA<InvalidBackupException>()));
      expect(() => decodeBackup('{"format":"something-else"}'),
          throwsA(isA<InvalidBackupException>()));
      expect(() => decodeBackup('[]'),
          throwsA(isA<InvalidBackupException>()));
    });

    test('rejects backups from a newer document version', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: const [],
        params: const [],
        readings: const [],
        waterChanges: const [],
        carbonChanges: const [],
        settings: const [],
      ).replaceFirst('"version": 1', '"version": 999');
      expect(
          () => decodeBackup(json), throwsA(isA<InvalidBackupException>()));
    });
  });
}
