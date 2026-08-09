import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/micro.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/reminders.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';

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
        // Bounds are NOT copied: a seeded tank carries no overrides and
        // resolves the preset on read instead (v28).
        expect(await db.getParameterOverrides(id), isEmpty);
        final alk = params.firstWhere((p) => p.paramKey == 'alkalinity');
        expect(
          ResolvedParameter.resolve(alk, SetupType.sps, null).bounds,
          presetBounds(SetupType.sps, 'alkalinity'),
        );
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

    test('resolves the correction target where the preset defines one, '
        'without storing it', () async {
      final id = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.sps,
      );
      expect(await db.getParameterOverrides(id), isEmpty);
      final params = await db.getTrackedParameters(id);
      final alk = params.firstWhere((p) => p.paramKey == 'alkalinity');
      final resolvedAlk = ResolvedParameter.resolve(alk, SetupType.sps, null);
      expect(resolvedAlk.target, presetTarget(SetupType.sps, 'alkalinity'));
      expect(resolvedAlk.target, isNotNull);
      // No preset target -> null (correction falls back to the green mid).
      final ca = params.firstWhere((p) => p.paramKey == 'calcium');
      expect(ResolvedParameter.resolve(ca, SetupType.sps, null).target, isNull);
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
      await db.addTrackedParameter(id, 'iodine');
      final keys = (await db.getTrackedParameters(id)).map((p) => p.paramKey);
      expect(keys, contains('iodine'));
      expect((await db.getTrackedParameters(id)).length, before + 1);

      // Adding it again does nothing.
      await db.addTrackedParameter(id, 'iodine');
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

      await db.addTrackedParameter(id, 'iodine');
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

    test('restoreTrackedParameter re-inserts the captured row verbatim, and '
        'untracking never touches readings (U11)', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.insertReading(
        tankId: id,
        paramKey: 'alkalinity',
        value: 8.2,
        takenAt: DateTime(2026, 8, 1),
      );
      final row = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      // Give the row per-row state that only the verbatim restore preserves.
      await db.setTestCadence(row.id, 7);
      final captured = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');

      await db.removeTrackedParameter(captured.id);
      expect(
        (await db.getTrackedParameters(id)).map((p) => p.paramKey),
        isNot(contains('alkalinity')),
      );
      // The reading is untouched — readings have no FK to tracked rows.
      expect(await db.select(db.readings).get(), hasLength(1));

      await db.restoreTrackedParameter(captured);
      final restored = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      // Full row equality: id, displayOrder, unit and testCadenceDays all
      // come back — an addTrackedParameter re-add would reset them.
      expect(restored, captured);
    });

    test('restoreTrackedParameter is a no-op when the parameter was re-added '
        'meanwhile (no UNIQUE index to stop a duplicate, #10)', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final captured = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      await db.removeTrackedParameter(captured.id);
      await db.addTrackedParameter(id, 'alkalinity');

      await db.restoreTrackedParameter(captured);
      expect(
        (await db.getTrackedParameters(
          id,
        )).where((p) => p.paramKey == 'alkalinity'),
        hasLength(1),
      );
    });
  });

  group('parameter overrides (v28)', () {
    test('with no override a parameter follows the setup-type preset, and '
        'changing the tank type re-resolves it', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.soft);
      final alk = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');

      expect(
        ResolvedParameter.resolve(alk, SetupType.soft, null).bounds,
        presetBounds(SetupType.soft, 'alkalinity'),
      );
      // The whole point of resolving on read: nothing was rewritten, yet the
      // same row now answers with the SPS band.
      expect(
        ResolvedParameter.resolve(alk, SetupType.sps, null).bounds,
        presetBounds(SetupType.sps, 'alkalinity'),
      );
    });

    test(
      'a microelement with no override follows the catalog default',
      () async {
        final id = await db.createTankWithPreset(
          name: 'M',
          type: SetupType.sps,
        );
        await db.addTrackedParameter(id, 'potassium');
        final k = (await db.getTrackedParameters(
          id,
        )).firstWhere((p) => p.paramKey == 'potassium');
        expect(
          ResolvedParameter.resolve(k, SetupType.sps, null).bounds,
          microDefaultBounds('potassium'),
        );
      },
    );

    test('an override wins over the default, and nulls inside it stay '
        'meaningful', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.sps);
      // Only a ceiling: the low side is deliberately unbounded.
      await db.setParameterOverride(
        id,
        'alkalinity',
        const ZoneBounds(greenHigh: 9, amberHigh: 11),
      );
      final o = (await db.getParameterOverrides(id)).single;
      final alk = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      final r = ResolvedParameter.resolve(alk, SetupType.sps, o);
      expect(r.isCustomised, isTrue);
      expect(r.bounds, const ZoneBounds(greenHigh: 9, amberHigh: 11));
      expect(r.bounds.amberLow, isNull);
    });

    test('an all-null override is still an override: "no zones at all", not '
        '"use the defaults"', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.sps);
      await db.setParameterOverride(id, 'alkalinity', const ZoneBounds());
      final o = (await db.getParameterOverrides(id)).single;
      final alk = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      final r = ResolvedParameter.resolve(alk, SetupType.sps, o);
      expect(r.isCustomised, isTrue);
      expect(r.bounds.isEmpty, isTrue);
    });

    test('setParameterOverride upserts on (tank, param)', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.sps);
      await db.setParameterOverride(
        id,
        'calcium',
        const ZoneBounds(greenLow: 400, greenHigh: 450),
      );
      await db.setParameterOverride(
        id,
        'calcium',
        const ZoneBounds(greenLow: 410, greenHigh: 440),
        target: 425,
      );
      final all = await db.getParameterOverrides(id);
      expect(all, hasLength(1));
      expect(all.single.greenLow, 410);
      expect(all.single.targetValue, 425);
    });

    test(
      'clearParameterOverride drops one parameter back to the defaults',
      () async {
        final id = await db.createTankWithPreset(
          name: 'M',
          type: SetupType.sps,
        );
        await db.setParameterOverride(
          id,
          'calcium',
          const ZoneBounds(greenLow: 1, greenHigh: 2),
        );
        await db.setParameterOverride(
          id,
          'alkalinity',
          const ZoneBounds(greenLow: 3, greenHigh: 4),
        );
        await db.clearParameterOverride(id, 'calcium');
        expect((await db.getParameterOverrides(id)).map((o) => o.paramKey), [
          'alkalinity',
        ]);
      },
    );

    test(
      'resetParameterDefaults drops every override of that tank only',
      () async {
        final a = await db.createTankWithPreset(name: 'A', type: SetupType.sps);
        final b = await db.createTankWithPreset(name: 'B', type: SetupType.sps);
        await db.setParameterOverride(
          a,
          'calcium',
          const ZoneBounds(greenLow: 1, greenHigh: 2),
        );
        await db.setParameterOverride(
          b,
          'calcium',
          const ZoneBounds(greenLow: 1, greenHigh: 2),
        );

        await db.resetParameterDefaults(a);

        expect(await db.getParameterOverrides(a), isEmpty);
        expect(await db.getParameterOverrides(b), hasLength(1));
      },
    );

    test('an override outlives untracking its parameter, so re-adding it '
        'restores the bounds the user set', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.sps);
      await db.addTrackedParameter(id, 'potassium');
      await db.setParameterOverride(
        id,
        'potassium',
        const ZoneBounds(greenLow: 390, greenHigh: 410),
      );
      final row = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'potassium');

      await db.removeTrackedParameter(row.id);
      expect(await db.getParameterOverrides(id), hasLength(1));

      await db.addTrackedParameter(id, 'potassium');
      final o = (await db.getParameterOverrides(id)).single;
      expect(o.greenLow, 390);
      expect(o.greenHigh, 410);
    });

    test('deleting a tank cascades to its overrides', () async {
      final id = await db.createTankWithPreset(name: 'M', type: SetupType.sps);
      await db.setParameterOverride(
        id,
        'calcium',
        const ZoneBounds(greenLow: 400, greenHigh: 450),
      );
      await db.softDeleteTank(id);
      await db.hardDeleteTank(id);
      expect(await db.getParameterOverrides(id), isEmpty);
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
      'a reading without groupId is standalone — never grouped by time (#15)',
      () async {
        final id = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final t = DateTime(2026, 3, 1, 9, 30);
        // Ungrouped rows on the same second (only creatable outside the app
        // flows — the v19 migration/restore backfills stored legacy rows).
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

        final ungrouped = (await db.getAllReadings()).firstWhere(
          (r) => r.paramKey == 'ph',
        );
        expect(ungrouped.groupId, isNull);
        final group = await db.readingGroup(ungrouped);
        expect(
          group.map((r) => r.paramKey),
          ['ph'],
          reason: 'null groupId must match only the reading itself',
        );
        expect(await db.deleteReadingGroup(ungrouped), 1);
        expect((await db.getAllReadings()).map((r) => r.paramKey), [
          'alkalinity',
        ]);
      },
    );
  });

  group('watchReadingsSince (U26)', () {
    test('returns only readings on/after the cutoff, newest first, '
        'excluding other tanks', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
      for (var i = 0; i < 5; i++) {
        await db.insertReading(
          tankId: a,
          paramKey: 'alkalinity',
          value: 8.0 + i * 0.1,
          takenAt: DateTime(2026, 1, 1 + i * 10), // Jan 1/11/21/31, Feb 10
        );
      }
      await db.insertReading(
        tankId: b,
        paramKey: 'alkalinity',
        value: 7,
        takenAt: DateTime(2026, 1, 25),
      );

      final rows = await db.watchReadingsSince(a, DateTime(2026, 1, 11)).first;

      expect(rows.every((r) => r.tankId == a), isTrue);
      // Cutoff is inclusive (Jan 11 in, Jan 1 out); newest first.
      expect(rows.map((r) => r.takenAt), [
        DateTime(2026, 2, 10),
        DateTime(2026, 1, 31),
        DateTime(2026, 1, 21),
        DateTime(2026, 1, 11),
      ]);
    });
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

  group('watchLatestReadingPerParamAllTanks (U7)', () {
    test('is the newest row of every (tank, parameter) pair — never another '
        "tank's", () async {
      final nano = await db.createTankWithPreset(
        name: 'Nano',
        type: SetupType.mixed,
      );
      final display = await db.createTankWithPreset(
        name: 'Display',
        type: SetupType.sps,
      );
      // Same parameter in both tanks, and the *older* nano value is the one a
      // tank-blind partition would hide behind the display tank's newer row.
      await db.insertReading(
        tankId: nano,
        paramKey: 'alkalinity',
        value: 7.4,
        takenAt: DateTime(2026, 1, 5),
      );
      await db.insertReading(
        tankId: nano,
        paramKey: 'alkalinity',
        value: 7.6,
        takenAt: DateTime(2026, 1, 10),
      );
      await db.insertReading(
        tankId: display,
        paramKey: 'alkalinity',
        value: 8.9,
        takenAt: DateTime(2026, 2, 1),
      );
      await db.insertReading(
        tankId: nano,
        paramKey: 'calcium',
        value: 415,
        takenAt: DateTime(2026, 1, 9),
      );

      final rows = await db.watchLatestReadingPerParamAllTanks().first;

      expect(
        rows.map((r) => (r.tankId, r.paramKey, r.value)),
        [
          (nano, 'alkalinity', 7.6),
          (nano, 'calcium', 415.0),
          (display, 'alkalinity', 8.9),
        ],
        reason: 'one head per (tank, param); the nano keeps its own alkalinity',
      );
    });

    test('breaks a same-second tie by id, per tank', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
      final t = DateTime(2026, 3, 1, 9, 30);
      for (final tank in [a, b]) {
        await db.insertReading(
          tankId: tank,
          paramKey: 'ph',
          value: 8.0,
          takenAt: t,
        );
        await db.insertReading(
          tankId: tank,
          paramKey: 'ph',
          value: 8.3,
          takenAt: t,
        );
      }

      final rows = await db.watchLatestReadingPerParamAllTanks().first;
      expect(rows, hasLength(2));
      // The later insert (higher id) wins in each tank — deterministic, not
      // whichever row the scan happens to reach first.
      expect(rows.every((r) => r.value == 8.3), isTrue);
      expect(rows.map((r) => r.tankId), [a, b]);
    });

    test('soft-deleted tanks ride along (the caller drops them)', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.insertReading(
        tankId: a,
        paramKey: 'ph',
        value: 8.1,
        takenAt: DateTime(2026, 1, 1),
      );
      await db.softDeleteTank(a);
      expect(await db.watchLatestReadingPerParamAllTanks().first, hasLength(1));
    });
  });

  group('dashboard order (measurements + ratio cards share one space)', () {
    test('applyDashboardOrder updates tracked parameters and both ratio '
        'branches (insert + update)', () async {
      final tank = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.sps,
      );
      final params = await db.getTrackedParameters(tank);
      // caalk already has a row (the user hid it); mgca has none yet, so it
      // takes the insert branch.
      await db.setRatioVisible(tank, 'caalk', false);

      await db.applyDashboardOrder(
        tank,
        paramOrders: [
          (id: params[1].id, order: 0),
          (id: params[0].id, order: 1),
        ],
        ratioOrders: [(key: 'caalk', order: 2), (key: 'mgca', order: 3)],
      );

      final after = await db.getTrackedParameters(tank);
      expect(after.first.id, params[1].id);
      expect(after.first.displayOrder, 0);
      expect(after[1].displayOrder, 1);
      // Parameters not listed keep their seeded positions.
      expect(
        after.firstWhere((p) => p.id == params[2].id).displayOrder,
        params[2].displayOrder,
      );

      final ratios = {
        for (final r in await db.watchRatioVisibilities(tank).first)
          r.ratioKey: r,
      };
      expect(ratios.keys, unorderedEquals(['caalk', 'mgca']));
      expect(ratios['caalk']!.displayOrder, 2);
      expect(
        ratios['caalk']!.visible,
        isFalse,
        reason: 'the update branch writes only displayOrder',
      );
      expect(ratios['mgca']!.displayOrder, 3);
      expect(
        ratios['mgca']!.visible,
        isTrue,
        reason: 'a row created by the insert branch starts visible',
      );
    });

    test('is idempotent and tank-scoped', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.sps);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.sps);
      await db.setRatioVisible(b, 'caalk', false);
      final bBefore = (await db.watchRatioVisibilities(b).first).single;

      final paramA = (await db.getTrackedParameters(a)).first;
      for (var i = 0; i < 2; i++) {
        await db.applyDashboardOrder(
          a,
          paramOrders: [(id: paramA.id, order: 5)],
          ratioOrders: [(key: 'caalk', order: 6)],
        );
      }

      // Running it twice must not duplicate the ratio row or drift the order.
      final rowsA = await db.watchRatioVisibilities(a).first;
      expect(rowsA, hasLength(1));
      expect(rowsA.single.displayOrder, 6);
      expect(
        (await db.getTrackedParameters(
          a,
        )).firstWhere((p) => p.id == paramA.id).displayOrder,
        5,
      );
      // The other tank's row with the same key is untouched.
      expect((await db.watchRatioVisibilities(b).first).single, bBefore);
    });

    test('a reorder never clobbers hidden state or hand-set ratio bounds, '
        'and neither setter clobbers the other (#10)', () async {
      final tank = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.sps,
      );
      await db.setRatioVisible(tank, 'caalk', false);
      await db.setRatioBounds(
        tank,
        'caalk',
        amberLow: 15,
        greenLow: 18,
        greenHigh: 22,
        amberHigh: 25,
      );
      // Bounds are a partial companion: visibility survives them.
      var row = (await db.watchRatioVisibilities(tank).first).single;
      expect(row.visible, isFalse);
      expect(row.greenLow, 18);

      await db.applyDashboardOrder(
        tank,
        paramOrders: const [],
        ratioOrders: [(key: 'caalk', order: 4)],
      );

      row = (await db.watchRatioVisibilities(tank).first).single;
      expect(row.displayOrder, 4);
      expect(
        row.visible,
        isFalse,
        reason: 'drag-to-reorder must not un-hide a card',
      );
      expect(
        (row.amberLow, row.greenLow, row.greenHigh, row.amberHigh),
        (15.0, 18.0, 22.0, 25.0),
        reason: 'nor reset the bands the user typed',
      );

      // And the visibility toggle keeps the bounds and the new order.
      await db.setRatioVisible(tank, 'caalk', true);
      row = (await db.watchRatioVisibilities(tank).first).single;
      expect(row.visible, isTrue);
      expect(row.greenLow, 18);
      expect(row.displayOrder, 4);

      // Clearing back to the defaults writes nulls without disturbing them.
      await db.setRatioBounds(
        tank,
        'caalk',
        amberLow: null,
        greenLow: null,
        greenHigh: null,
        amberHigh: null,
      );
      row = (await db.watchRatioVisibilities(tank).first).single;
      expect(row.greenLow, isNull);
      expect(row.visible, isTrue);
      expect(row.displayOrder, 4);
    });
  });

  group('microelement views (U17)', () {
    test(
      'insert assigns max(displayOrder)+1 after a middle delete (#9/#21)',
      () async {
        final tank = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        final a = await db.insertMicroView(
          tankId: tank,
          name: 'Trace',
          paramKeys: ['iodine'],
        );
        final b = await db.insertMicroView(
          tankId: tank,
          name: 'Metals',
          paramKeys: ['iron', 'manganese'],
        );
        final c = await db.insertMicroView(
          tankId: tank,
          name: 'Contaminants',
          paramKeys: ['copper'],
        );
        var rows = await db.watchMicroViews(tank).first;
        expect(rows.map((v) => v.id), [a, b, c]);
        expect(rows.map((v) => v.displayOrder), [0, 1, 2]);

        await db.deleteMicroView(b);
        final d = await db.insertMicroView(
          tankId: tank,
          name: 'Halogens',
          paramKeys: ['bromine'],
        );
        rows = await db.watchMicroViews(tank).first;
        expect(rows.map((v) => v.id), [a, c, d]);
        expect(
          rows.last.displayOrder,
          3,
          reason:
              'max+1, not the row count (2) — a collision would let the '
              'chip row reorder itself on the next launch',
        );
        expect(
          rows.map((v) => v.displayOrder).toSet(),
          hasLength(3),
          reason: 'orders stay unique',
        );
      },
    );

    test('the order sequence is per tank', () async {
      final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
      await db.insertMicroView(tankId: a, name: 'X', paramKeys: ['iodine']);
      await db.insertMicroView(tankId: a, name: 'Y', paramKeys: ['iron']);
      await db.insertMicroView(tankId: b, name: 'Z', paramKeys: ['copper']);
      expect((await db.watchMicroViews(b).first).single.displayOrder, 0);
    });

    test('update replaces the name and the whole key set', () async {
      final tank = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final id = await db.insertMicroView(
        tankId: tank,
        name: 'Trace',
        paramKeys: ['iodine', 'iron'],
      );
      await db.updateMicroView(
        id,
        name: 'Trace v2',
        paramKeys: ['copper', 'zinc', 'nickel'],
      );
      final row = (await db.watchMicroViews(tank).first).single;
      expect(row.name, 'Trace v2');
      expect(row.keys, [
        'copper',
        'zinc',
        'nickel',
      ], reason: 'keys are replaced wholesale, not merged');
      expect(row.displayOrder, 0, reason: 'the chip keeps its position');
    });

    test('deleting a tank cascades to its views', () async {
      final tank = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final other = await db.createTankWithPreset(
        name: 'B',
        type: SetupType.mixed,
      );
      await db.insertMicroView(tankId: tank, name: 'X', paramKeys: ['iodine']);
      await db.insertMicroView(tankId: other, name: 'Y', paramKeys: ['iron']);

      await db.softDeleteTank(tank);
      await db.hardDeleteTank(tank);

      expect(await db.watchMicroViews(tank).first, isEmpty);
      expect(await db.watchMicroViews(other).first, hasLength(1));
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
    test('boundsOfOverride mirrors a stored override row', () async {
      final id = await db.createTankWithPreset(name: 'A', type: SetupType.sps);
      const custom = ZoneBounds(
        amberLow: 6,
        greenLow: 7,
        greenHigh: 9,
        amberHigh: 11,
      );
      await db.setParameterOverride(id, 'alkalinity', custom);
      final o = (await db.getParameterOverrides(id)).single;
      expect(boundsOfOverride(o), custom);
    });

    test('presentationOf converts temperature to the preferred unit', () async {
      final id = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      final temp = (await db.getTrackedParameters(
        id,
      )).firstWhere((p) => p.paramKey == 'temperature');
      final pres = presentationOfRow(
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

  group('maintenance schedules (U12)', () {
    late int tankId;
    setUp(() async {
      tankId = await db.createTankWithPreset(name: 'R', type: SetupType.mixed);
    });

    test('insert assigns max(displayOrder)+1, not the row count', () async {
      final a = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      final b = await db.insertMaintenanceSchedule(
        tankId: tankId,
        title: 'Clean skimmer',
        cadenceDays: 7,
      );
      await db.deleteMaintenanceSchedule(a);
      final c = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'carbonChange',
        cadenceDays: 30,
      );
      final rows = await db.getMaintenanceSchedules(tankId);
      expect(rows.map((s) => s.id), [b, c]);
      // b kept order 1; c must be 2 (max+1), not 1 (the row count).
      expect(rows.map((s) => s.displayOrder), [1, 2]);
    });

    test(
      'markMaintenanceDone stamps lastDoneAt; restore undoes verbatim',
      () async {
        final id = await db.insertMaintenanceSchedule(
          tankId: tankId,
          title: 'Replace RO membrane',
        );
        final before = (await db.getMaintenanceSchedules(tankId)).single;
        expect(before.lastDoneAt, isNull);

        final at = DateTime(2026, 7, 5, 12);
        await db.markMaintenanceDone(id, at);
        expect(
          (await db.getMaintenanceSchedules(tankId)).single.lastDoneAt,
          at,
        );

        await db.restoreMaintenanceSchedule(before);
        expect(
          (await db.getMaintenanceSchedules(tankId)).single.lastDoneAt,
          isNull,
        );
      },
    );

    test('restore after delete brings the identical row back', () async {
      final id = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'equipmentCleaning',
        cadenceDays: 21,
        note: 'skimmer cup',
      );
      final row = (await db.getMaintenanceSchedules(tankId)).single;
      await db.deleteMaintenanceSchedule(id);
      expect(await db.getMaintenanceSchedules(tankId), isEmpty);
      await db.restoreMaintenanceSchedule(row);
      expect((await db.getMaintenanceSchedules(tankId)).single, row);
    });

    test('reorder persists the given id order', () async {
      final a = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'waterChange',
      );
      final b = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'carbonChange',
      );
      await db.reorderMaintenanceSchedules([b, a]);
      expect((await db.getMaintenanceSchedules(tankId)).map((s) => s.id), [
        b,
        a,
      ]);
    });

    test('tank delete cascades its schedules', () async {
      await db.insertMaintenanceSchedule(tankId: tankId, title: 'X');
      await db.softDeleteTank(tankId);
      await db.hardDeleteTank(tankId);
      expect(await db.getAllMaintenanceSchedules(), isEmpty);
    });
  });

  group('reminder-scheduler reads (U1/U12)', () {
    late int tankId;
    setUp(() async {
      tankId = await db.createTankWithPreset(name: 'R', type: SetupType.mixed);
    });

    test('latestReadingTimesPerParam returns MAX(takenAt) per key', () async {
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: 8,
        takenAt: DateTime(2026, 7, 1, 9),
      );
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: 8.2,
        takenAt: DateTime(2026, 7, 3, 9),
      );
      await db.insertReading(
        tankId: tankId,
        paramKey: 'calcium',
        value: 420,
        takenAt: DateTime(2026, 6, 20, 10),
      );
      final times = await db.latestReadingTimesPerParam(tankId);
      expect(times, {
        'alkalinity': DateTime(2026, 7, 3, 9),
        'calcium': DateTime(2026, 6, 20, 10),
      });
    });

    test('latestReadingTimesPerParam is tank-scoped and empty-safe', () async {
      final other = await db.createTankWithPreset(
        name: 'Other',
        type: SetupType.mixed,
      );
      await db.insertReading(
        tankId: other,
        paramKey: 'alkalinity',
        value: 7,
        takenAt: DateTime(2026, 7, 1),
      );
      expect(await db.latestReadingTimesPerParam(tankId), isEmpty);
    });

    test('latestActionTimes returns the newest per action type', () async {
      await db.insertWaterChange(
        tankId: tankId,
        changedAt: DateTime(2026, 6, 20),
      );
      await db.insertWaterChange(
        tankId: tankId,
        changedAt: DateTime(2026, 7, 1),
      );
      await db.insertCarbonChange(
        tankId: tankId,
        changedAt: DateTime(2026, 6, 25),
      );
      final times = await db.latestActionTimes(tankId);
      expect(times, {
        MaintenanceActionType.waterChange: DateTime(2026, 7, 1),
        MaintenanceActionType.carbonChange: DateTime(2026, 6, 25),
      });
      expect(
        times.containsKey(MaintenanceActionType.equipmentCleaning),
        isFalse,
      );
    });
  });

  group('setTestCadence (U1)', () {
    test('sets and clears the cadence', () async {
      final tankId = await db.createTankWithPreset(
        name: 'R',
        type: SetupType.mixed,
      );
      final param = (await db.getTrackedParameters(tankId)).first;
      expect(param.testCadenceDays, isNull);
      await db.setTestCadence(param.id, 7);
      expect((await db.getTrackedParameters(tankId)).first.testCadenceDays, 7);
      await db.setTestCadence(param.id, null);
      expect(
        (await db.getTrackedParameters(tankId)).first.testCadenceDays,
        isNull,
      );
    });
  });
}
