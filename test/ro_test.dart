import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/ro.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('RoStageType.fromName', () {
    test('resolves every stage type by name', () {
      for (final t in RoStageType.values) {
        expect(RoStageType.fromName(t.name), t);
      }
    });

    test('returns null for garbage and null (never a guess)', () {
      expect(RoStageType.fromName('sedimint'), isNull);
      expect(RoStageType.fromName(''), isNull);
      expect(RoStageType.fromName(null), isNull);
    });
  });

  group('roStageDue', () {
    final now = DateTime(2026, 7, 6, 10);

    test('is elastic: last replacement + lifespan', () {
      expect(
        roStageDue(
          lastReplacedAt: DateTime(2026, 6, 1, 9, 30),
          lifespanDays: 90,
          now: now,
        ),
        DateTime(2026, 8, 30, 9, 30),
      );
    });

    test('a stage never replaced is never due — unknown age, no guess', () {
      expect(roStageDue(lifespanDays: 90, now: now), isNull);
    });

    test('an invalid stored lifespan yields no due date (#8)', () {
      expect(
        roStageDue(
          lastReplacedAt: DateTime(2026, 6, 1),
          lifespanDays: 0,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('roAmberWindowDays', () {
    test('floors short lifespans at $kRoAmberMinDays days', () {
      expect(roAmberWindowDays(90), 14); // 10% = 9 < the 14-day floor
      expect(roAmberWindowDays(120), 14);
    });

    test('scales with long lifespans', () {
      expect(roAmberWindowDays(720), 72); // 10%
    });

    test('caps at half the lifespan so short stages can read green', () {
      expect(roAmberWindowDays(10), 5);
      expect(roAmberWindowDays(20), 10);
    });
  });

  group('roRemainingFraction', () {
    test('clamps to 0..1', () {
      expect(roRemainingFraction(daysLeft: -5, lifespanDays: 90), 0);
      expect(roRemainingFraction(daysLeft: 90, lifespanDays: 90), 1);
      expect(roRemainingFraction(daysLeft: 200, lifespanDays: 90), 1);
    });

    test('is the linear share of lifespan left', () {
      expect(roRemainingFraction(daysLeft: 45, lifespanDays: 90), 0.5);
    });

    test('an invalid lifespan reads as fully drained, not a crash', () {
      expect(roRemainingFraction(daysLeft: 10, lifespanDays: 0), 0);
    });
  });

  group('roStageZone', () {
    test('red once overdue', () {
      expect(roStageZone(daysLeft: -1, lifespanDays: 90), Zone.red);
    });

    test('amber inside the warning window (inclusive)', () {
      expect(roStageZone(daysLeft: 14, lifespanDays: 90), Zone.amber);
      expect(roStageZone(daysLeft: 0, lifespanDays: 90), Zone.amber);
      expect(roStageZone(daysLeft: 72, lifespanDays: 720), Zone.amber);
    });

    test('green outside it', () {
      expect(roStageZone(daysLeft: 15, lifespanDays: 90), Zone.green);
      expect(roStageZone(daysLeft: 73, lifespanDays: 720), Zone.green);
      // Short lifespan: fresh must still be green despite the 14-day floor
      // (the window caps at half the lifespan — 10 of 20 days is amber,
      // anything above is green).
      expect(roStageZone(daysLeft: 11, lifespanDays: 20), Zone.green);
      expect(roStageZone(daysLeft: 20, lifespanDays: 20), Zone.green);
    });

    test('unknown for an invalid lifespan (#8)', () {
      expect(roStageZone(daysLeft: 5, lifespanDays: 0), Zone.unknown);
    });
  });

  group('RO stage store (U16)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('latestRoReplacementTimes takes the MAX per stage, whatever order '
        'the log was written in', () async {
      final sediment = await db.insertRoStage(
        stageType: RoStageType.sediment.name,
        lifespanDays: 90,
      );
      final membrane = await db.insertRoStage(
        stageType: RoStageType.membrane.name,
        lifespanDays: 720,
      );
      final di = await db.insertRoStage(
        stageType: RoStageType.diResin.name,
        lifespanDays: 180,
      );

      // Newest first, then an older backfill: MIN, FIRST or a missing groupBy
      // would all anchor the reminder on the wrong date.
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2026, 6, 1, 9),
      );
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2026, 1, 15, 8),
      );
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2026, 3, 20, 17),
      );
      await db.insertRoReplacement(
        stageId: membrane,
        replacedAt: DateTime(2025, 11, 2, 12),
      );

      expect(await db.latestRoReplacementTimes(), {
        sediment: DateTime(2026, 6, 1, 9),
        membrane: DateTime(2025, 11, 2, 12),
      });
      // A stage that was never replaced carries no anchor at all — it must not
      // appear with a null or an epoch date (a "never due" stage, per
      // roStageDue).
      expect((await db.latestRoReplacementTimes()).containsKey(di), isFalse);
    });

    test('an undone replacement re-anchors on the previous one', () async {
      final stage = await db.insertRoStage(
        stageType: RoStageType.carbonBlock.name,
        lifespanDays: 180,
      );
      await db.insertRoReplacement(
        stageId: stage,
        replacedAt: DateTime(2026, 2, 1),
      );
      final undoable = await db.insertRoReplacement(
        stageId: stage,
        replacedAt: DateTime(2026, 7, 1),
      );
      expect(await db.latestRoReplacementTimes(), {
        stage: DateTime(2026, 7, 1),
      });

      await db.deleteRoReplacement(undoable);
      expect(await db.latestRoReplacementTimes(), {
        stage: DateTime(2026, 2, 1),
      });
    });

    test(
      'deleteRoStage cascades its replacement log, and only its own',
      () async {
        final a = await db.insertRoStage(
          stageType: RoStageType.sediment.name,
          lifespanDays: 90,
        );
        final b = await db.insertRoStage(
          stageType: RoStageType.membrane.name,
          lifespanDays: 720,
        );
        await db.insertRoReplacement(
          stageId: a,
          replacedAt: DateTime(2026, 5, 1),
        );
        await db.insertRoReplacement(
          stageId: a,
          replacedAt: DateTime(2026, 6, 1),
        );
        await db.insertRoReplacement(
          stageId: b,
          replacedAt: DateTime(2026, 4, 1),
        );
        expect(await db.watchRoReplacements().first, hasLength(3));

        await db.deleteRoStage(a);

        expect((await db.getRoStages()).map((s) => s.id), [b]);
        final log = await db.watchRoReplacements().first;
        expect(log.map((r) => r.stageId), [b]);
        expect(await db.latestRoReplacementTimes(), {b: DateTime(2026, 4, 1)});
      },
    );
  });

  test('default stage set covers the typical 4-stage unit, in water order', () {
    expect(kRoDefaultStageOrder, [
      RoStageType.sediment,
      RoStageType.carbonBlock,
      RoStageType.membrane,
      RoStageType.diResin,
    ]);
    for (final level in RoUsageLevel.values) {
      for (final t in kRoDefaultStageOrder) {
        expect(roLifespansFor(level)[t], greaterThanOrEqualTo(1));
      }
    }
  });

  group('RoUsageLevel', () {
    test('resolves every level by name, defaults to moderate otherwise', () {
      for (final level in RoUsageLevel.values) {
        expect(RoUsageLevel.fromName(level.name), level);
      }
      expect(RoUsageLevel.fromName('extreme'), RoUsageLevel.moderate);
      expect(RoUsageLevel.fromName(null), RoUsageLevel.moderate);
    });

    test('heavier usage never gets a longer lifespan than lighter', () {
      for (final t in kRoDefaultStageOrder) {
        final light = roLifespansFor(RoUsageLevel.light)[t]!;
        final moderate = roLifespansFor(RoUsageLevel.moderate)[t]!;
        final heavy = roLifespansFor(RoUsageLevel.heavy)[t]!;
        expect(heavy, lessThanOrEqualTo(moderate), reason: t.name);
        expect(moderate, lessThanOrEqualTo(light), reason: t.name);
      }
    });
  });

  group('RO usage level store', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('setRoUsageLevel stores the level and rewrites standard stages, '
        'leaving custom stages alone', () async {
      await db.seedDefaultRoStages();
      final custom = await db.insertRoStage(
        stageType: RoStageType.custom.name,
        title: 'Second DI',
        lifespanDays: 77,
      );
      // Hand-tuned lifespan: an explicit pick overwrites it by design.
      final stages = await db.getRoStages();
      final sediment = stages.firstWhere(
        (s) => s.stageType == RoStageType.sediment.name,
      );
      await db.updateRoStage(sediment.copyWith(lifespanDays: 33));

      await db.setRoUsageLevel(RoUsageLevel.heavy);

      expect(await db.getSetting(kRoUsageLevelKey), 'heavy');
      final after = await db.getRoStages();
      final heavy = roLifespansFor(RoUsageLevel.heavy);
      for (final s in after) {
        final type = RoStageType.fromName(s.stageType)!;
        if (type == RoStageType.custom) continue;
        expect(s.lifespanDays, heavy[type], reason: s.stageType);
      }
      expect(
        after.firstWhere((s) => s.id == custom).lifespanDays,
        77,
        reason: 'no preset exists for a part the app does not know',
      );
    });

    test('setRoUsageLevel also updates disabled standard stages — they are '
        'still parts of the unit', () async {
      await db.seedDefaultRoStages();
      final di = (await db.getRoStages()).firstWhere(
        (s) => s.stageType == RoStageType.diResin.name,
      );
      await db.setRoStageEnabled(di.id, false);

      await db.setRoUsageLevel(RoUsageLevel.light);

      final after = (await db.getRoStages()).firstWhere(
        (s) => s.id == di.id,
      );
      expect(after.enabled, isFalse);
      expect(after.lifespanDays, roLifespansFor(RoUsageLevel.light)[RoStageType.diResin]);
    });

    test('seeding uses the stored usage level — a restore can bring the '
        'level without the seed flag', () async {
      await db.setSetting(kRoUsageLevelKey, RoUsageLevel.heavy.name);

      await db.seedDefaultRoStages();

      final heavy = roLifespansFor(RoUsageLevel.heavy);
      for (final s in await db.getRoStages()) {
        final type = RoStageType.fromName(s.stageType)!;
        expect(s.lifespanDays, heavy[type], reason: s.stageType);
      }
    });
  });
}
