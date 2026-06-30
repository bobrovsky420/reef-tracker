import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Routes path_provider (used by [importBackup]'s rehearsal restore) to a temp
/// folder so it works under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

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
    final equipmentCleanings = [
      EquipmentCleaning(
        id: 40,
        tankId: 1,
        cleanedAt: DateTime.fromMillisecondsSinceEpoch(1700007000000),
        note: 'Cleaned skimmer',
      ),
      EquipmentCleaning(
        id: 41,
        tankId: 2,
        cleanedAt: DateTime.fromMillisecondsSinceEpoch(1700008000000),
        note: null,
      ),
    ];
    final ratioVisibilities = [
      const RatioVisibility(
        tankId: 1,
        ratioKey: 'mgca',
        visible: false,
        displayOrder: 3,
        amberLow: 2.6,
        greenLow: 2.9,
        greenHigh: 3.3,
        amberHigh: 3.6,
      ),
      const RatioVisibility(
          tankId: 2, ratioKey: 'po4no3', visible: true, displayOrder: 1000),
    ];
    final dosingEntries = [
      DosingEntry(
        id: 50,
        tankId: 1,
        productKey: 'redsea.foundation_b',
        vendor: 'Red Sea',
        program: 'Reef Care Program',
        product: 'Reef Foundation B (KH/Alk)',
        elementKey: 'alkalinity',
        amount: 5.0,
        amountUnit: 'ml',
        basis: 'perDay',
        frequency: 'daily',
        doseTime: '21:00',
        note: 'Auto-doser line 2',
        displayOrder: 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700004000000),
      ),
      DosingEntry(
        id: 51,
        tankId: 1,
        product: 'Custom kalk mix',
        displayOrder: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700005000000),
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
        equipmentCleanings: equipmentCleanings,
        ratioVisibilities: ratioVisibilities,
        dosingEntries: dosingEntries,
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

      final e0 = data.equipmentCleanings[0];
      expect(e0.id.value, 40);
      expect(e0.tankId.value, 1);
      expect(e0.cleanedAt.value, equipmentCleanings[0].cleanedAt);
      expect(e0.note.value, 'Cleaned skimmer');
      expect(data.equipmentCleanings[1].note.value, isNull);

      final rv0 = data.ratioVisibilities[0];
      expect(rv0.tankId.value, 1);
      expect(rv0.ratioKey.value, 'mgca');
      expect(rv0.visible.value, false);
      expect(rv0.displayOrder.value, 3);
      expect(rv0.greenLow.value, 2.9);
      expect(rv0.amberHigh.value, 3.6);
      expect(data.ratioVisibilities[1].ratioKey.value, 'po4no3');
      expect(data.ratioVisibilities[1].visible.value, true);
      expect(data.ratioVisibilities[1].displayOrder.value, 1000);
      expect(data.ratioVisibilities[1].greenLow.value, isNull);

      final d0 = data.dosingEntries[0];
      expect(d0.id.value, 50);
      expect(d0.tankId.value, 1);
      expect(d0.productKey.value, 'redsea.foundation_b');
      expect(d0.product.value, 'Reef Foundation B (KH/Alk)');
      expect(d0.elementKey.value, 'alkalinity');
      expect(d0.amount.value, 5.0);
      expect(d0.amountUnit.value, 'ml');
      expect(d0.basis.value, 'perDay');
      expect(d0.frequency.value, 'daily');
      expect(d0.doseTime.value, '21:00');
      expect(d0.createdAt.value, dosingEntries[0].createdAt);
      final d1 = data.dosingEntries[1];
      expect(d1.productKey.value, isNull);
      expect(d1.elementKey.value, isNull);
      expect(d1.amount.value, isNull);

      expect(data.settings.length, 3);
      expect(data.settings[0].key.value, 'temp_unit');
      expect(data.settings[0].value.value, 'fahrenheit');
      expect(data.settings[2].value.value, isNull);
    });

    test('tolerates older backups without later action sections', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        equipmentCleanings: equipmentCleanings,
        ratioVisibilities: ratioVisibilities,
        dosingEntries: dosingEntries,
        settings: settings,
      )
          .replaceFirst(
              RegExp(r',\s*"waterChanges": \[.*?\]', dotAll: true), '')
          .replaceFirst(
              RegExp(r',\s*"carbonChanges": \[.*?\]', dotAll: true), '')
          .replaceFirst(
              RegExp(r',\s*"equipmentCleanings": \[.*?\]', dotAll: true), '')
          .replaceFirst(
              RegExp(r',\s*"ratioVisibilities": \[.*?\]', dotAll: true), '')
          .replaceFirst(
              RegExp(r',\s*"dosingEntries": \[.*?\]', dotAll: true), '');
      final data = decodeBackup(json);
      expect(data.waterChanges, isEmpty);
      expect(data.carbonChanges, isEmpty);
      expect(data.equipmentCleanings, isEmpty);
      expect(data.ratioVisibilities, isEmpty);
      expect(data.dosingEntries, isEmpty);
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
        equipmentCleanings: const [],
        ratioVisibilities: const [],
        dosingEntries: const [],
        settings: const [],
      ).replaceFirst('"version": 1', '"version": 999');
      expect(
          () => decodeBackup(json), throwsA(isA<InvalidBackupException>()));
    });
  });

  group('validateBackup', () {
    BackupData dataWith({
      List<TanksCompanion> tanks = const [],
      List<ReadingsCompanion> readings = const [],
      int schemaVersion = 1,
    }) =>
        BackupData(
          schemaVersion: schemaVersion,
          tanks: tanks,
          params: const [],
          readings: readings,
          waterChanges: const [],
          carbonChanges: const [],
          equipmentCleanings: const [],
          ratioVisibilities: const [],
          dosingEntries: const [],
          settings: const [],
        );

    TanksCompanion tank(int id) => TanksCompanion(
          id: Value(id),
          name: Value('Tank $id'),
          setupType: const Value('mixed'),
          createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
        );

    ReadingsCompanion reading(int id, int tankId) => ReadingsCompanion(
          id: Value(id),
          tankId: Value(tankId),
          paramKey: const Value('alk'),
          value: const Value(8.2),
          takenAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
        );

    Matcher rejectedWith(BackupRejection reason) =>
        throwsA(isA<InvalidBackupException>()
            .having((e) => e.reason, 'reason', reason));

    test('accepts a consistent data set', () {
      final d = dataWith(tanks: [tank(1)], readings: [reading(10, 1)]);
      expect(() => validateBackup(d, appSchemaVersion: 10), returnsNormally);
    });

    test('accepts an older schema version', () {
      final d = dataWith(tanks: [tank(1)], schemaVersion: 1);
      expect(() => validateBackup(d, appSchemaVersion: 10), returnsNormally);
    });

    test('rejects a newer schema version', () {
      final d = dataWith(tanks: [tank(1)], schemaVersion: 11);
      expect(() => validateBackup(d, appSchemaVersion: 10),
          rejectedWith(BackupRejection.newerVersion));
    });

    test('rejects a reading referencing a missing aquarium', () {
      final d = dataWith(tanks: [tank(1)], readings: [reading(10, 99)]);
      expect(() => validateBackup(d, appSchemaVersion: 10),
          rejectedWith(BackupRejection.inconsistent));
    });

    test('rejects duplicate aquarium ids', () {
      final d = dataWith(tanks: [tank(1), tank(1)]);
      expect(() => validateBackup(d, appSchemaVersion: 10),
          rejectedWith(BackupRejection.inconsistent));
    });
  });

  group('full database round-trip', () {
    late Directory tempDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('reeftracker-bk-');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

    /// Seeds a database with a representative spread of data across tables.
    Future<int> seed(AppDatabase db) async {
      final id =
          await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      await db.insertReadingGroup(
        tankId: id,
        takenAt: DateTime(2026, 1, 1, 8),
        note: 'morning',
        values: const [
          (paramKey: 'ph', value: 8.1),
          (paramKey: 'alkalinity', value: 8.5),
        ],
      );
      await db.insertWaterChange(
          tankId: id, changedAt: DateTime(2026, 1, 2), amountLiters: 25);
      await db.insertCarbonChange(
          tankId: id, changedAt: DateTime(2026, 1, 3), grams: 200);
      await db.insertEquipmentCleaning(
          tankId: id, cleanedAt: DateTime(2026, 1, 4), note: 'skimmer');
      await db.setRatioBounds(id, 'mgca',
          amberLow: 2.6, greenLow: 2.9, greenHigh: 3.3, amberHigh: 3.6);
      await db.setSetting('temp_unit', 'fahrenheit');
      return id;
    }

    test('encode from DB -> decode -> import reproduces every table', () async {
      final src = newDb();
      addTearDown(src.close);
      final id = await seed(src);

      final json = await encodeBackupFromDb(src);
      final data = decodeBackup(json);

      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);

      // Tank identity and ids preserved.
      final tanks = await dst.getAllTanks();
      expect(tanks.length, 1);
      expect(tanks.single.id, id);
      expect(tanks.single.name, 'Reef');

      // Counts match the source across the data tables.
      expect((await dst.getAllReadings()).length,
          (await src.getAllReadings()).length);
      expect((await dst.getAllWaterChanges()).length, 1);
      expect((await dst.getAllCarbonChanges()).length, 1);
      expect((await dst.getAllEquipmentCleanings()).length, 1);
      expect((await dst.getAllRatioVisibilities()).length, 1);
      expect((await dst.getAllTrackedParameters()).length,
          (await src.getAllTrackedParameters()).length);
      expect(await dst.getSetting('temp_unit'), 'fahrenheit');
    });

    test('import replaces existing data rather than appending', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src);
      final data = decodeBackup(await encodeBackupFromDb(src));

      final dst = newDb();
      addTearDown(dst.close);
      // Pre-existing tank that must be wiped by the restore.
      await dst.createTankWithPreset(name: 'Old', type: SetupType.sps);

      await importBackup(dst, data);

      final tanks = await dst.getAllTanks();
      expect(tanks.length, 1);
      expect(tanks.single.name, 'Reef');
    });

    test('imports an older backup missing later sections', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src);
      // Drop a table that older app versions did not export.
      final json = (await encodeBackupFromDb(src)).replaceFirst(
          RegExp(r',\s*"dosingEntries": \[.*?\]', dotAll: true), '');
      final data = decodeBackup(json);

      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);

      expect(await dst.getAllDosingEntries(), isEmpty);
      expect((await dst.getAllTanks()).length, 1);
    });

    test('rejects a backup whose child rows reference a missing tank',
        () async {
      final data = BackupData(
        schemaVersion: 1,
        tanks: const [],
        params: [
          TrackedParametersCompanion.insert(
              tankId: 99, paramKey: 'ph', unit: 'pH'),
        ],
        readings: const [],
        waterChanges: const [],
        carbonChanges: const [],
        equipmentCleanings: const [],
        ratioVisibilities: const [],
        dosingEntries: const [],
        settings: const [],
      );
      final dst = newDb();
      addTearDown(dst.close);
      await expectLater(
          importBackup(dst, data), throwsA(isA<InvalidBackupException>()));
    });
  });
}
