import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/units.dart';

/// Routes path_provider to a temp folder so the real file-backed open path
/// (`AppDatabase()` → `_open()`) works under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('createTankWithPreset', () {
    test(
      'seeds the preset parameters in catalog order with preset bounds',
      () async {
        final id = await db.createTankWithPreset(
          name: 'Reef',
          type: SetupType.sps,
        );
        final params = await db.getTrackedParameters(id);

        expect(
          params.map((p) => p.paramKey).toList(),
          defaultTrackedKeys(SetupType.sps),
        );
        // displayOrder is monotonically assigned in catalog order.
        for (var i = 0; i < params.length; i++) {
          expect(params[i].displayOrder, i);
        }
        // Bounds copied from the preset for a known parameter.
        final alk = params.firstWhere((p) => p.paramKey == 'alkalinity');
        final preset = presetBounds(SetupType.sps, 'alkalinity');
        expect(alk.amberLow, preset.amberLow);
        expect(alk.greenLow, preset.greenLow);
        expect(alk.greenHigh, preset.greenHigh);
        expect(alk.amberHigh, preset.amberHigh);
      },
    );

    test('every setup type seeds exactly its preset keys', () async {
      for (final type in SetupType.values) {
        final id = await db.createTankWithPreset(name: type.name, type: type);
        final keys = (await db.getTrackedParameters(id)).map((p) => p.paramKey);
        expect(
          keys,
          unorderedEquals(defaultTrackedKeys(type)),
          reason: 'mismatch for $type',
        );
      }
    });

    test('makes the new tank the active tank', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      expect(await db.getActiveTankId(), id);
    });
  });

  group('addTrackedParameter', () {
    test('adds a missing parameter and is idempotent', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.fishOnly,
      );
      final before = (await db.getTrackedParameters(id)).length;

      // 'iodine' is not in the fish-only preset.
      await db.addTrackedParameter(id, 'iodine', SetupType.fishOnly);
      var keys = (await db.getTrackedParameters(id)).map((p) => p.paramKey);
      expect(keys, contains('iodine'));
      expect((await db.getTrackedParameters(id)).length, before + 1);

      // Adding it again does nothing.
      await db.addTrackedParameter(id, 'iodine', SetupType.fishOnly);
      expect((await db.getTrackedParameters(id)).length, before + 1);
    });

    test('after removing a middle parameter a new one gets a unique '
        'displayOrder (#9)', () async {
      // Regression test for #9: the new order is max(displayOrder)+1, not the
      // row count, so it cannot collide with a surviving row after a middle
      // row was removed (mirrors the insertDosingEntry fix).
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.fishOnly,
      );
      final params = await db.getTrackedParameters(id);
      expect(
        params.length,
        greaterThanOrEqualTo(3),
        reason: 'need a removable middle row',
      );
      await db.removeTrackedParameter(params[1].id);

      await db.addTrackedParameter(id, 'iodine', SetupType.fishOnly);
      final after = await db.getTrackedParameters(id);
      final added = after.firstWhere((p) => p.paramKey == 'iodine');
      expect(
        added.displayOrder,
        params.last.displayOrder + 1,
        reason: 'max+1 of the surviving parameters',
      );
      // All orders stay unique.
      final orders = after.map((p) => p.displayOrder).toList();
      expect(orders.toSet().length, orders.length);
    });
  });

  group('foreign-key cascade', () {
    test('deleting a tank removes its readings and actions', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.insertReading(
        tankId: id,
        paramKey: 'ph',
        value: 8.1,
        takenAt: DateTime(2026, 1, 1),
      );
      await db.insertWaterChange(
        tankId: id,
        changedAt: DateTime(2026, 1, 2),
        amountLiters: 20,
      );

      await db.deleteTank(id);

      expect(await db.getAllReadings(), isEmpty);
      expect(await db.getAllWaterChanges(), isEmpty);
      expect(await db.getAllTrackedParameters(), isEmpty);
    });

    test(
      'deleting the active tank reassigns active to a remaining tank',
      () async {
        final a = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final b = await db.createTankWithPreset(
          name: 'B',
          type: SetupType.mixed,
        );
        expect(await db.getActiveTankId(), b); // last created is active

        await db.deleteTank(b);
        expect(await db.getActiveTankId(), a);

        await db.deleteTank(a);
        expect(await db.getActiveTankId(), isNull);
      },
    );
  });

  group('reading groups', () {
    test(
      'insertReadingGroup stores all rows at one timestamp with one groupId',
      () async {
        final id = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final t = DateTime(2026, 3, 1, 9, 30);
        await db.insertReadingGroup(
          tankId: id,
          takenAt: t,
          note: 'morning test',
          values: const [
            (paramKey: 'ph', value: 8.1),
            (paramKey: 'alkalinity', value: 8.5),
            (paramKey: 'calcium', value: 420),
          ],
        );

        final all = await db.getAllReadings();
        expect(all.length, 3);
        final group = await db.readingGroup(all.first);
        expect(group.length, 3);
        expect(
          group.map((r) => r.paramKey),
          containsAll(['ph', 'alkalinity', 'calcium']),
        );
        expect(group.every((r) => r.note == 'morning test'), isTrue);
        expect(group.every((r) => r.groupId == all.first.groupId), isTrue);
        expect(all.first.groupId, isNotNull);
      },
    );

    test('updateReadingGroupTime moves a whole group', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final from = DateTime(2026, 3, 1, 9, 30);
      final to = DateTime(2026, 3, 1, 10, 0);
      await db.insertReadingGroup(
        tankId: id,
        takenAt: from,
        values: const [
          (paramKey: 'ph', value: 8.1),
          (paramKey: 'alkalinity', value: 8.5),
        ],
      );

      final r = (await db.getAllReadings()).first;
      final moved = await db.updateReadingGroupTime(r, to);
      expect(moved, 2);
      final all = await db.getAllReadings();
      expect(all.every((x) => x.takenAt.isAtSameMomentAs(to)), isTrue);
    });

    test('two groups saved at the same second stay distinct (#15)', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final t = DateTime(2026, 3, 1, 9, 30);
      await db.insertReadingGroup(
        tankId: id,
        takenAt: t,
        values: const [
          (paramKey: 'ph', value: 8.1),
          (paramKey: 'alkalinity', value: 8.5),
        ],
      );
      await db.insertReadingGroup(
        tankId: id,
        takenAt: t,
        values: const [
          (paramKey: 'calcium', value: 420),
          (paramKey: 'magnesium', value: 1300),
        ],
      );

      final all = await db.getAllReadings();
      final ph = all.firstWhere((r) => r.paramKey == 'ph');
      final group = await db.readingGroup(ph);
      expect(
        group.length,
        2,
        reason: 'the same-second batch must not merge in',
      );
      expect(
        group.map((r) => r.paramKey),
        unorderedEquals(['ph', 'alkalinity']),
      );

      // Deleting one group leaves the other untouched.
      expect(await db.deleteReadingGroup(ph), 2);
      final remaining = await db.getAllReadings();
      expect(
        remaining.map((r) => r.paramKey),
        unorderedEquals(['calcium', 'magnesium']),
      );
    });

    test(
      'legacy rows without groupId fall back to timestamp grouping (#15)',
      () async {
        final id = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final t = DateTime(2026, 3, 1, 9, 30);
        // Pre-v13 rows: inserted individually, no group id.
        await db.insertReading(
          tankId: id,
          paramKey: 'ph',
          value: 8.1,
          takenAt: t,
        );
        await db.insertReading(
          tankId: id,
          paramKey: 'alkalinity',
          value: 8.5,
          takenAt: t,
        );
        // A new grouped batch on the very same second.
        await db.insertReadingGroup(
          tankId: id,
          takenAt: t,
          values: const [(paramKey: 'calcium', value: 420)],
        );

        final legacy = (await db.getAllReadings()).firstWhere(
          (r) => r.paramKey == 'ph',
        );
        expect(legacy.groupId, isNull);
        final group = await db.readingGroup(legacy);
        expect(
          group.map((r) => r.paramKey),
          unorderedEquals(['ph', 'alkalinity']),
          reason: 'legacy grouping must not swallow the new grouped batch',
        );
      },
    );
  });

  group('settings', () {
    test('round-trips values and reports null for unset keys', () async {
      expect(await db.getSetting('locale'), isNull);
      await db.setSetting('locale', 'cs');
      expect(await db.getSetting('locale'), 'cs');
      // insertOnConflictUpdate overwrites in place.
      await db.setSetting('locale', 'de');
      expect(await db.getSetting('locale'), 'de');
    });
  });

  group('row -> domain bridges', () {
    test('boundsOf mirrors the stored zone bounds', () async {
      final id = await db.createTankWithPreset(name: 'A', type: SetupType.sps);
      final alk = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      final bounds = boundsOf(alk);
      expect(bounds.amberLow, alk.amberLow);
      expect(bounds.greenLow, alk.greenLow);
      expect(bounds.greenHigh, alk.greenHigh);
      expect(bounds.amberHigh, alk.amberHigh);
    });

    test('presentationOf converts temperature to the preferred unit', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final temp = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'temperature');
      final pres = presentationOf(
        temp,
        const UnitPrefs(temp: TempUnit.fahrenheit),
      );
      expect(pres.unitLabel, '°F');
      expect(pres.toDisplay(25), closeTo(77, 1e-9));
      expect(pres.toCanonical(77), closeTo(25, 1e-9));
    });
  });

  group('journal mode (T6)', () {
    test('the real file-backed open runs in WAL mode', () async {
      final dir = await Directory.systemTemp.createTemp('reeftracker-wal');
      final prev = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(dir.path);
      final fileDb = AppDatabase();
      try {
        final row = await fileDb
            .customSelect('pragma journal_mode;')
            .getSingle();
        expect(row.read<String>('journal_mode'), 'wal');
      } finally {
        await fileDb.close();
        PathProviderPlatform.instance = prev;
        await dir.delete(recursive: true);
      }
    });
  });
}
