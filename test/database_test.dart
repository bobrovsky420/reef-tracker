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
      final keys = (await db.getTrackedParameters(id)).map((p) => p.paramKey);
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

      await db.softDeleteTank(id);
      await db.hardDeleteTank(id);

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

        await db.softDeleteTank(b);
        expect(await db.getActiveTankId(), a);

        await db.softDeleteTank(a);
        expect(await db.getActiveTankId(), isNull);
      },
    );
  });

  group('tank soft delete (U10)', () {
    test('softDeleteTank hides the tank; restoreTank brings it back', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);

      await db.softDeleteTank(a);
      expect((await db.getTanks()).map((t) => t.id), [b]);
      expect((await db.watchTanks().first).map((t) => t.id), [b]);
      // The rows survive the window: the full dump still sees the tank.
      expect((await db.getAllTanks()).length, 2);

      expect(await db.restoreTank(a), isTrue);
      expect((await db.getTanks()).map((t) => t.id), [a, b]);
      final restored = (await db.getTanks()).first;
      expect(restored.deletedAt, isNull);
    });

    test('restoreTank returns false once the row is gone', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.softDeleteTank(a);
      await db.hardDeleteTank(a);
      expect(await db.restoreTank(a), isFalse);
    });

    test('hardDeleteTank only removes soft-deleted rows', () async {
      // A stale undo-window callback must never remove a live tank that
      // reused the id (e.g. re-inserted by a backup restore).
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.hardDeleteTank(a);
      expect((await db.getTanks()).map((t) => t.id), [a]);
    });

    test('purgeDeletedTanks sweeps every soft-deleted tank', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
      final c = await db.createTankWithPreset(name: 'C', type: SetupType.mixed);
      await db.insertReading(
        tankId: a,
        paramKey: 'ph',
        value: 8.1,
        takenAt: DateTime(2026, 1, 1),
      );
      await db.softDeleteTank(a);
      await db.softDeleteTank(c);

      await db.purgeDeletedTanks();
      expect((await db.getAllTanks()).map((t) => t.id), [b]);
      // Children cascaded with the purge.
      expect(await db.getAllReadings(), isEmpty);
    });
  });

  group('dosing stop undo (U10)', () {
    test('restoreDosingEntry writes the pre-stop row back verbatim', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(id),
          product: const Value('All-For-Reef'),
        ),
      );
      final before = (await db.watchDosingEntries(id).first).single;
      expect(before.endedAt, isNull);

      await db.stopDosingEntry(before.id);
      expect(await db.watchDosingEntries(id).first, isEmpty);

      await db.restoreDosingEntry(before);
      final after = (await db.watchDosingEntries(id).first).single;
      expect(after, before); // state and the null endedAt restored exactly
    });
  });

  group('reading templates (test sets, U9)', () {
    test('insert assigns max(displayOrder)+1 and returns the id', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final a = await db.insertReadingTemplate(
        tankId: id,
        name: 'Daily Alk',
        paramKeys: ['alkalinity'],
      );
      final b = await db.insertReadingTemplate(
        tankId: id,
        name: 'Weekly',
        paramKeys: ['calcium', 'magnesium'],
      );
      final c = await db.insertReadingTemplate(
        tankId: id,
        name: 'Nutrients',
        paramKeys: ['nitrate', 'phosphate'],
      );
      var rows = await db.watchReadingTemplates(id).first;
      expect(rows.map((t) => t.id), [a, b, c]);
      expect(rows.map((t) => t.displayOrder), [0, 1, 2]);

      // Removing a middle template must not let a new one collide (#9 class).
      await db.deleteReadingTemplate(b);
      final d = await db.insertReadingTemplate(
        tankId: id,
        name: 'ICP prep',
        paramKeys: ['iodine'],
      );
      rows = await db.watchReadingTemplates(id).first;
      expect(rows.map((t) => t.id), [a, c, d]);
      expect(rows.last.displayOrder, 3); // max+1, not the row count (2)
    });

    test(
      'update replaces name and keys; reorder persists chip order',
      () async {
        final id = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final a = await db.insertReadingTemplate(
          tankId: id,
          name: 'Daily',
          paramKeys: ['alkalinity'],
        );
        final b = await db.insertReadingTemplate(
          tankId: id,
          name: 'Weekly',
          paramKeys: ['calcium'],
        );

        await db.updateReadingTemplate(
          a,
          name: 'Daily Alk+Ca',
          paramKeys: ['alkalinity', 'calcium'],
        );
        var rows = await db.watchReadingTemplates(id).first;
        expect(rows.first.name, 'Daily Alk+Ca');
        expect(rows.first.keys, ['alkalinity', 'calcium']);

        await db.reorderReadingTemplates([b, a]);
        rows = await db.watchReadingTemplates(id).first;
        expect(rows.map((t) => t.id), [b, a]);
      },
    );

    test('deleting a tank cascades to its templates', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.insertReadingTemplate(
        tankId: id,
        name: 'Weekly',
        paramKeys: ['calcium'],
      );
      await db.softDeleteTank(id);
      await db.hardDeleteTank(id);
      expect(await db.getAllReadingTemplates(), isEmpty);
    });

    test('paramKeys codec round-trips and tolerates garbage', () {
      expect(
        decodeTemplateParamKeys(encodeTemplateParamKeys(['alkalinity', 'ph'])),
        ['alkalinity', 'ph'],
      );
      expect(decodeTemplateParamKeys(encodeTemplateParamKeys([])), isEmpty);
      // Malformed stored values decode to an empty set, never throw.
      expect(decodeTemplateParamKeys('not json'), isEmpty);
      expect(decodeTemplateParamKeys('{"a":1}'), isEmpty);
      // Non-string elements are skipped, not crashed on.
      expect(decodeTemplateParamKeys('["ph", 3, null]'), ['ph']);
    });
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

  group('watchRecentReadingsPerParam (T1)', () {
    test('caps each parameter at the limit, newest first, and excludes '
        'other tanks', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
      for (var i = 0; i < 12; i++) {
        await db.insertReading(
          tankId: a,
          paramKey: 'alkalinity',
          value: 8.0 + i * 0.01,
          takenAt: DateTime(2026, 1, 1 + i),
        );
      }
      for (var i = 0; i < 3; i++) {
        await db.insertReading(
          tankId: a,
          paramKey: 'calcium',
          value: 400.0 + i,
          takenAt: DateTime(2026, 1, 1 + i),
        );
      }
      await db.insertReading(
        tankId: b,
        paramKey: 'alkalinity',
        value: 7.0,
        takenAt: DateTime(2026, 2, 1),
      );

      final rows = await db.watchRecentReadingsPerParam(a, 10).first;

      expect(rows.every((r) => r.tankId == a), isTrue);
      final alk = rows.where((r) => r.paramKey == 'alkalinity').toList();
      final ca = rows.where((r) => r.paramKey == 'calcium').toList();
      // Over-cap parameter is truncated to its *newest* rows, newest first.
      expect(alk, hasLength(10));
      expect(alk.first.takenAt, DateTime(2026, 1, 12));
      expect(alk.last.takenAt, DateTime(2026, 1, 3));
      // Under-cap parameter is returned whole.
      expect(ca, hasLength(3));
      // Newest-first within each parameter — the order consumers group on.
      for (final list in [alk, ca]) {
        for (var i = 1; i < list.length; i++) {
          expect(list[i].takenAt.isAfter(list[i - 1].takenAt), isFalse);
        }
      }
    });

    test(
      'same-second readings break ties by id without dropping rows',
      () async {
        final a = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final t = DateTime(2026, 1, 1, 12);
        await db.insertReading(
          tankId: a,
          paramKey: 'ph',
          value: 8.0,
          takenAt: t,
        );
        await db.insertReading(
          tankId: a,
          paramKey: 'ph',
          value: 8.2,
          takenAt: t,
        );

        final head = await db.watchRecentReadingsPerParam(a, 1).first;
        // The later insert (higher id) counts as newest.
        expect(head.single.value, 8.2);
        final both = await db.watchRecentReadingsPerParam(a, 2).first;
        expect(both.map((r) => r.value).toList(), [8.2, 8.0]);
      },
    );

    test('re-emits with the new head when a newer reading arrives', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.insertReading(
        tankId: a,
        paramKey: 'ph',
        value: 8.0,
        takenAt: DateTime(2026, 1, 1),
      );
      final headValues = db
          .watchRecentReadingsPerParam(a, 1)
          .map((rows) => rows.single.value);
      final sawUpdate = expectLater(headValues, emitsThrough(8.3));
      await db.insertReading(
        tankId: a,
        paramKey: 'ph',
        value: 8.3,
        takenAt: DateTime(2026, 1, 2),
      );
      await sawUpdate;
    });
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
