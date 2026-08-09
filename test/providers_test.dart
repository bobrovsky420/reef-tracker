import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/health_score.dart';
import 'package:reeftracker/domain/micro.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/reminders.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';

/// Pumps the event loop until [cond] holds (or fails the test after ~1 s).
Future<void> pumpUntil(bool Function() cond) async {
  for (var i = 0; i < 200 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(cond(), isTrue, reason: 'condition not reached within the timeout');
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('switching the active tank never exposes the previous tank\'s '
      'readings (#20)', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
    await db.insertReading(
      tankId: a,
      paramKey: 'ph',
      value: 8.1,
      takenAt: DateTime(2026, 1, 1),
    );
    await db.setActiveTank(a);

    // Record every data emission together with the tank that was active when
    // it arrived — the bug was tank A's rows rendering under tank B's name.
    final emissions = <({int? tankId, List<Reading> rows})>[];
    final sub = container.listen(tankReadingsProvider, (_, next) {
      final rows = next.value;
      if (rows != null) {
        emissions.add((
          tankId: container.read(activeTankProvider)?.id,
          rows: rows,
        ));
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    await pumpUntil(
      () => emissions.any((e) => e.tankId == a && e.rows.isNotEmpty),
    );

    await db.setActiveTank(b);
    // Wait until tank B's (empty) readings have settled.
    await pumpUntil(
      () =>
          container.read(activeTankProvider)?.id == b &&
          container.read(tankReadingsProvider).hasValue &&
          container.read(tankReadingsProvider).value!.isEmpty,
    );

    for (final e in emissions.where((e) => e.tankId == b)) {
      expect(
        e.rows.where((r) => r.tankId == a),
        isEmpty,
        reason: "tank A's readings must never surface while B is active",
      );
    }
    // And the settled state is B's own (empty) list, not a stale copy.
    expect(container.read(tankReadingsProvider).value, isEmpty);
  });

  test('a write for another tank does not re-notify the active tank\'s '
      'providers (T2)', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
    // Recent timestamps: the health score only counts readings fresher than
    // kHealthFreshnessDays, and the settle below waits for hasData.
    final now = DateTime.now();
    await db.insertReading(
      tankId: a,
      paramKey: 'ph',
      value: 8.1,
      takenAt: now.subtract(const Duration(days: 2)),
    );
    await db.setActiveTank(a);

    var readingsNotifies = 0;
    var healthNotifies = 0;
    final readingsSub = container.listen(
      tankReadingsProvider,
      (_, _) => readingsNotifies++,
      fireImmediately: true,
    );
    final healthSub = container.listen(
      tankHealthProvider,
      (_, _) => healthNotifies++,
      fireImmediately: true,
    );
    addTearDown(readingsSub.close);
    addTearDown(healthSub.close);

    // Settle on the derived provider too: its rebuild lands an event-loop
    // turn after the readings notify, so sample the baselines only once the
    // whole chain is quiet.
    await pumpUntil(
      () =>
          (container.read(tankReadingsProvider).value ?? const []).isNotEmpty &&
          container.read(tankHealthProvider).hasData,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final settledReadings = readingsNotifies;
    final settledHealth = healthNotifies;

    // Invalidates the readings table, but tank A's result set is unchanged —
    // drift re-emits an identical list, which the dedup must swallow before
    // it reaches any listener.
    await db.insertReading(
      tankId: b,
      paramKey: 'ph',
      value: 7.9,
      takenAt: now.subtract(const Duration(days: 1)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(
      readingsNotifies,
      settledReadings,
      reason: "another tank's write must not re-notify readings watchers",
    );
    expect(
      healthNotifies,
      settledHealth,
      reason: "another tank's write must not re-notify health watchers",
    );
    // And a genuine write for tank A still comes through.
    await db.insertReading(tankId: a, paramKey: 'ph', value: 8.2, takenAt: now);
    await pumpUntil(() => readingsNotifies > settledReadings);
  });

  test('trends and health run off the capped recent-readings feed and match '
      'the full history (T1)', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    await db.setActiveTank(a);
    // More readings than the kRecentReadingsPerParam cap, four a day, all
    // fresh (health only counts readings newer than kHealthFreshnessDays).
    // At this density the trend window widens to kTrendMinSpanDays — which
    // must still fit inside the capped feed for parity to hold.
    final now = DateTime.now();
    const total = 45;
    for (var i = total; i >= 1; i--) {
      await db.insertReading(
        tankId: a,
        paramKey: 'ph',
        value: 8.0 + (total - i) * 0.01,
        takenAt: now.subtract(Duration(hours: i * 6)),
      );
    }

    final recentSub = container.listen(recentReadingsProvider, (_, _) {});
    final trendsSub = container.listen(tankTrendsProvider, (_, _) {});
    final healthSub = container.listen(tankHealthProvider, (_, _) {});
    addTearDown(recentSub.close);
    addTearDown(trendsSub.close);
    addTearDown(healthSub.close);

    await pumpUntil(
      () =>
          (container.read(recentReadingsProvider).value ?? const [])
              .isNotEmpty &&
          container.read(tankTrendsProvider).containsKey('ph'),
    );

    final recent = container
        .read(recentReadingsProvider)
        .value!
        .where((r) => r.paramKey == 'ph')
        .toList();
    // Capped to the newest kRecentReadingsPerParam rows, newest first.
    expect(recent, hasLength(kRecentReadingsPerParam));
    expect(recent.first.value, 8.0 + (total - 1) * 0.01);

    // Trend parity: the capped feed must yield exactly the trend the full
    // history yields (computeTrend never looks past its window).
    // Resolve like the provider does: the rows carry no bounds of their own.
    final tracked = resolveParameters(
      await db.getTrackedParameters(a),
      SetupType.mixed,
      await db.getParameterOverrides(a),
    );
    final ph = tracked.firstWhere((p) => p.paramKey == 'ph');
    final full = await db.watchReadingsForTank(a).first;
    final points = <DosePoint>[
      for (final r in full.reversed) (t: r.takenAt, value: r.value),
    ];
    final expectedTrend = computeTrend(
      points: points,
      bounds: ph.bounds,
      window: kTrendDefaultWindow,
    );
    expect(container.read(tankTrendsProvider)['ph'], expectedTrend);

    // Health parity: the score built from the capped feed equals one built
    // from each parameter's true latest reading.
    final latest = recent.first;
    final expectedHealth = computeTankHealth([
      for (final p in tracked.where((t) => t.enabled))
        (
          paramKey: p.paramKey,
          bounds: p.bounds,
          latest: p.paramKey == 'ph' ? latest.value : null,
          takenAt: p.paramKey == 'ph' ? latest.takenAt : null,
        ),
    ]);
    expect(container.read(tankHealthProvider), expectedHealth);
  });

  test(
    'a settings write notifies only that setting\'s watchers (T4)',
    () async {
      final settings = AppSettings(db);

      var tempNotifies = 0;
      var windowNotifies = 0;
      final tempSub = container.listen(
        tempUnitProvider,
        (_, _) => tempNotifies++,
        fireImmediately: true,
      );
      final windowSub = container.listen(
        trendWindowProvider,
        (_, _) => windowNotifies++,
        fireImmediately: true,
      );
      addTearDown(tempSub.close);
      addTearDown(windowSub.close);

      await pumpUntil(
        () =>
            container.read(tempUnitProvider).hasValue &&
            container.read(trendWindowProvider).hasValue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final settledTemp = tempNotifies;
      final settledWindow = windowNotifies;

      // A write to an unrelated key re-runs the single settings-map query, but
      // the per-key selects must swallow it before any watcher fires.
      await settings.setLastBackupAt(DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        tempNotifies,
        settledTemp,
        reason: 'an unrelated settings write must not re-notify tempUnit',
      );
      expect(
        windowNotifies,
        settledWindow,
        reason: 'an unrelated settings write must not re-notify trendWindow',
      );

      // A genuine change to a watched key still comes through, alone.
      await settings.setTempUnit(TempUnit.fahrenheit);
      await pumpUntil(() => tempNotifies > settledTemp);
      expect(container.read(tempUnitProvider).value, TempUnit.fahrenheit);
      expect(
        windowNotifies,
        settledWindow,
        reason: 'a tempUnit write must not re-notify trendWindow',
      );
    },
  );

  test('switching back to a tank reloads its data', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
    await db.insertReading(
      tankId: a,
      paramKey: 'ph',
      value: 8.1,
      takenAt: DateTime(2026, 1, 1),
    );

    final sub = container.listen(tankReadingsProvider, (_, _) {});
    addTearDown(sub.close);

    await db.setActiveTank(a);
    await pumpUntil(
      () => (container.read(tankReadingsProvider).value ?? const []).isNotEmpty,
    );

    await db.setActiveTank(b);
    await pumpUntil(
      () =>
          container.read(activeTankProvider)?.id == b &&
          (container.read(tankReadingsProvider).value?.isEmpty ?? false),
    );

    // The previous tank's family instance was disposed; switching back must
    // freshly load A's rows rather than hold a dead stream.
    await db.setActiveTank(a);
    await pumpUntil(
      () =>
          container.read(activeTankProvider)?.id == a &&
          (container.read(tankReadingsProvider).value ?? const []).isNotEmpty,
    );
    expect(container.read(tankReadingsProvider).value!.single.value, 8.1);
  });

  group('dosingElementZonesProvider (REDESIGN #13)', () {
    Future<int> seedTank() async {
      final tankId = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.setActiveTank(tankId);
      return tankId;
    }

    Future<void> addEntry(int tankId, String product, String? element) =>
        db.insertDosingEntry(
          DosingEntriesCompanion(
            tankId: Value(tankId),
            product: Value(product),
            elementKey: Value(element),
          ),
        );

    test('fresh in-range reading colors the element; entries without a '
        'reading or element stay absent (neutral tag)', () async {
      final tankId = await seedTank();
      await addEntry(tankId, 'Alk Mix', 'alkalinity');
      await addEntry(tankId, 'Mg Mix', 'magnesium'); // no reading
      await addEntry(tankId, 'Nutrient reducer', null); // no element

      final alk = (await db.getTrackedParameters(
        tankId,
      )).firstWhere((t) => t.paramKey == 'alkalinity');
      final bounds = defaultBoundsFor(SetupType.mixed, alk.paramKey);
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: (bounds.greenLow! + bounds.greenHigh!) / 2,
        takenAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final sub = container.listen(dosingElementZonesProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpUntil(
        () => container.read(dosingElementZonesProvider)['alkalinity'] != null,
      );
      final zones = container.read(dosingElementZonesProvider);
      expect(zones['alkalinity'], Zone.green);
      expect(zones.keys, ['alkalinity']);
    });

    test(
      'a reading older than the health freshness window maps to no zone',
      () async {
        final tankId = await seedTank();
        await addEntry(tankId, 'Alk Mix', 'alkalinity');
        final alk = (await db.getTrackedParameters(
          tankId,
        )).firstWhere((t) => t.paramKey == 'alkalinity');
        final bounds = defaultBoundsFor(SetupType.mixed, alk.paramKey);
        await db.insertReading(
          tankId: tankId,
          paramKey: 'alkalinity',
          value: (bounds.greenLow! + bounds.greenHigh!) / 2,
          takenAt: DateTime.now().subtract(
            const Duration(days: kHealthFreshnessDays + 2),
          ),
        );

        final sub = container.listen(dosingElementZonesProvider, (_, _) {});
        addTearDown(sub.close);
        await pumpUntil(
          () =>
              (container.read(dosingEntriesProvider).value?.isNotEmpty ??
                  false) &&
              (container.read(recentReadingsProvider).value?.isNotEmpty ??
                  false),
        );
        expect(container.read(dosingElementZonesProvider), isEmpty);
      },
    );

    test(
      'an untracked microelement falls back to the catalog default bounds',
      () async {
        final tankId = await seedTank();
        await addEntry(tankId, 'Iodine supplement', 'iodine');
        // No tracked row exists for iodine (micro rows are created lazily);
        // beyond the default amber ceiling → red.
        final bounds = microDefaultBounds('iodine');
        await db.insertReading(
          tankId: tankId,
          paramKey: 'iodine',
          value: bounds.amberHigh! * 2,
          takenAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        final sub = container.listen(dosingElementZonesProvider, (_, _) {});
        addTearDown(sub.close);
        await pumpUntil(
          () => container.read(dosingElementZonesProvider)['iodine'] != null,
        );
        expect(container.read(dosingElementZonesProvider)['iodine'], Zone.red);
      },
    );
  });

  group('microStatusProvider view resolution (U17)', () {
    /// A tank with one out-of-range microelement measured yesterday. Iodine is
    /// deliberately *untracked* (micro rows are created lazily), so the panel
    /// resolves it from the catalog defaults.
    Future<int> seedOutOfRangeIodine() async {
      final tankId = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.setActiveTank(tankId);
      await db.insertReading(
        tankId: tankId,
        paramKey: 'iodine',
        value: microDefaultBounds('iodine').amberHigh! * 2,
        takenAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      return tankId;
    }

    test('a dangling view token widens to the full panel, never to an empty '
        'subset', () async {
      final tankId = await seedOutOfRangeIodine();
      final settings = AppSettings(db);

      final sub = container.listen(microStatusProvider, (_, _) {});
      addTearDown(sub.close);

      // Baseline: no stored token at all → the full panel sees the problem.
      await pumpUntil(() => container.read(microStatusProvider).measured == 1);
      expect(container.read(microStatusProvider).outOfRange, 1);
      expect(container.read(microStatusProvider).statusZone, Zone.red);

      // A *live* custom view that excludes iodine legitimately narrows it —
      // hiding an element is the user's explicit choice.
      final viewId = await db.insertMicroView(
        tankId: tankId,
        name: 'Boron only',
        paramKeys: ['boron'],
      );
      await settings.setMicroView(tankId, '$kMicroViewCustomPrefix$viewId');
      await pumpUntil(() => container.read(microStatusProvider).measured == 0);
      expect(container.read(microStatusProvider).outOfRange, 0);

      // Deleting the view leaves the stored token dangling (it also rides
      // backups, where ids are renumbered). `keys: {}` here would report
      // "0 measured, nothing out of range" on a tank with a red element.
      await db.deleteMicroView(viewId);
      await pumpUntil(() => container.read(microStatusProvider).measured == 1);
      expect(container.read(microStatusProvider).outOfRange, 1);
      expect(container.read(microStatusProvider).statusZone, Zone.red);
      expect(
        container.read(microViewSelectionProvider).keys,
        isNull,
        reason: 'the resolved selection must be the unfiltered full list',
      );
      expect(
        container.read(microViewSelectionProvider).token,
        kMicroViewFullToken,
      );

      // An unknown preset token, and a custom-view id that never existed,
      // behave the same way.
      for (final token in ['preset:nope', 'view:99999', 'garbage']) {
        await settings.setMicroView(tankId, token);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          container.read(microStatusProvider).measured,
          1,
          reason: '"$token" must widen to the full panel',
        );
        expect(container.read(microStatusProvider).outOfRange, 1);
        expect(container.read(microViewSelectionProvider).keys, isNull);
      }
    });
  });

  // --- Time-dependent providers (seam S3: [nowProvider]) ---------------------
  //
  // These two derive a *due date* from stored rows and the wall clock, so
  // every interesting assertion sits on a calendar boundary ("due today",
  // "10 days overdue"). With a bare `DateTime.now()` those boundaries could
  // only be asserted loosely; pinning the clock through [nowProvider] makes
  // them exact.

  /// A container whose clock is frozen at [now]. Same db override as the
  /// shared one; the outer [container] is simply unused by these tests.
  ProviderContainer clockContainer(DateTime now) {
    final c = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('maintenanceDueProvider (U12)', () {
    /// 2026-03-01 is deliberately just past a 28-day February: two of the
    /// expected due dates below are computed *through* the month boundary.
    final now = DateTime(2026, 3, 1, 12);

    test('each typed plan anchors on its own action log, and logging one '
        'action moves only that plan', () async {
      final tankId = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      await db.setActiveTank(tankId);

      final waterPlan = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: MaintenanceActionType.waterChange.name,
        cadenceDays: 7,
      );
      final carbonPlan = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: MaintenanceActionType.carbonChange.name,
        cadenceDays: 30,
      );
      final equipmentPlan = await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: MaintenanceActionType.equipmentCleaning.name,
        cadenceDays: 14,
      );
      // A custom (untyped) plan: anchored on its own `lastDoneAt` column, so
      // it must be blind to all three logs.
      final customPlan = await db.insertMaintenanceSchedule(
        tankId: tankId,
        title: 'Skimmer neck',
        cadenceDays: 10,
      );
      await db.markMaintenanceDone(customPlan, DateTime(2026, 2, 25, 7));

      // One log entry per type, each at a different distance from `now`, so a
      // plan reading the wrong log lands on a visibly wrong date. Every log
      // also carries an *older* second row: the anchor is the newest, not the
      // first or last row the query happens to return.
      await db.insertWaterChange(
        tankId: tankId,
        changedAt: DateTime(2026, 2, 27, 9, 30),
      );
      await db.insertWaterChange(
        tankId: tankId,
        changedAt: DateTime(2026, 1, 3, 9, 30),
      );
      await db.insertCarbonChange(
        tankId: tankId,
        changedAt: DateTime(2026, 1, 20, 8),
      );
      await db.insertCarbonChange(
        tankId: tankId,
        changedAt: DateTime(2025, 11, 2, 8),
      );
      await db.insertEquipmentCleaning(
        tankId: tankId,
        cleanedAt: DateTime(2026, 2, 15, 18),
      );
      await db.insertEquipmentCleaning(
        tankId: tankId,
        cleanedAt: DateTime(2025, 12, 30, 18),
      );

      final c = clockContainer(now);
      final sub = c.listen(maintenanceDueProvider, (_, _) {});
      addTearDown(sub.close);

      Map<int, DueStatus> dueById() => {
        for (final row in c.read(maintenanceDueProvider))
          row.schedule.id: row.due,
      };

      await pumpUntil(
        () =>
            (c.read(maintenanceSchedulesProvider).value ?? const []).length ==
                4 &&
            (c.read(waterChangesProvider).value ?? const []).length == 2 &&
            (c.read(carbonChangesProvider).value ?? const []).length == 2 &&
            (c.read(equipmentCleaningsProvider).value ?? const []).length == 2,
      );

      var due = dueById();
      expect(due, hasLength(4));
      // Water change: 2026-02-27 09:30 + 7 d.
      expect(due[waterPlan]!.dueAt, DateTime(2026, 3, 6, 9, 30));
      expect(due[waterPlan]!.daysLeft, 5);
      // Carbon: 2026-01-20 08:00 + 30 d = 2026-02-19, i.e. 10 days overdue.
      expect(due[carbonPlan]!.dueAt, DateTime(2026, 2, 19, 8));
      expect(due[carbonPlan]!.daysLeft, -10);
      // Equipment: 2026-02-15 18:00 + 14 d falls on 2026-03-01 — due *today*,
      // even though the stamp is six hours in this frozen clock's future.
      expect(due[equipmentPlan]!.dueAt, DateTime(2026, 3, 1, 18));
      expect(due[equipmentPlan]!.daysLeft, 0);
      // Custom: its own lastDoneAt + 10 d, untouched by any log.
      expect(due[customPlan]!.dueAt, DateTime(2026, 3, 7, 7));
      expect(due[customPlan]!.daysLeft, 6);

      // The copy-paste slip this is really about: a water change must not
      // reset the carbon or equipment reminder.
      await db.insertWaterChange(
        tankId: tankId,
        changedAt: DateTime(2026, 3, 1, 6),
      );
      await pumpUntil(
        () => dueById()[waterPlan]!.dueAt == DateTime(2026, 3, 8, 6),
      );
      due = dueById();
      expect(due[waterPlan]!.daysLeft, 7);
      expect(
        due[carbonPlan]!.dueAt,
        DateTime(2026, 2, 19, 8),
        reason: 'a water change must not re-anchor the carbon plan',
      );
      expect(
        due[equipmentPlan]!.dueAt,
        DateTime(2026, 3, 1, 18),
        reason: 'a water change must not re-anchor the equipment plan',
      );
      expect(
        due[customPlan]!.dueAt,
        DateTime(2026, 3, 7, 7),
        reason: 'a custom plan anchors on its own lastDoneAt only',
      );
    });

    test(
      'a finished one-off drops out of the list; an unfinished one stays',
      () async {
        final tankId = await db.createTankWithPreset(
          name: 'A',
          type: SetupType.mixed,
        );
        await db.setActiveTank(tankId);

        // Two one-offs (no cadence): one custom, one typed. Both are overdue
        // and must be listed until they are actually completed.
        final customOneOff = await db.insertMaintenanceSchedule(
          tankId: tankId,
          title: 'Swap airline',
          scheduledAt: DateTime(2026, 2, 26, 9),
        );
        final typedOneOff = await db.insertMaintenanceSchedule(
          tankId: tankId,
          actionType: MaintenanceActionType.waterChange.name,
          scheduledAt: DateTime(2026, 2, 20, 9),
        );

        final c = clockContainer(now);
        final sub = c.listen(maintenanceDueProvider, (_, _) {});
        addTearDown(sub.close);

        Map<int, DueStatus> dueById() => {
          for (final row in c.read(maintenanceDueProvider))
            row.schedule.id: row.due,
        };

        await pumpUntil(() => dueById().length == 2);
        expect(dueById()[customOneOff]!.daysLeft, -3);
        expect(dueById()[typedOneOff]!.daysLeft, -9);

        // The typed one-off retires on its *action log*, not on a lastDoneAt
        // stamp — logging the water change is what completes it.
        await db.insertWaterChange(
          tankId: tankId,
          changedAt: DateTime(2026, 2, 27, 16),
        );
        await pumpUntil(() => !dueById().containsKey(typedOneOff));
        expect(dueById().keys, [
          customOneOff,
        ], reason: 'only the completed one-off leaves the list');

        // And the custom one retires on its own stamp.
        await db.markMaintenanceDone(customOneOff, DateTime(2026, 3, 1, 10));
        await pumpUntil(() => dueById().isEmpty);
      },
    );
  });

  group('roStageStatusProvider (U16)', () {
    final now = DateTime(2026, 3, 1, 12);

    test('each stage takes its newest replacement, whatever order the rows '
        'were logged in; disabled stages stay in the list', () async {
      final sediment = await db.insertRoStage(
        stageType: 'sediment',
        lifespanDays: 180,
      );
      // No replacement ever logged: filter age is unknown and must never be
      // guessed at.
      final membrane = await db.insertRoStage(
        stageType: 'membrane',
        lifespanDays: 730,
      );
      final retired = await db.insertRoStage(
        stageType: 'custom',
        title: 'Second DI',
        lifespanDays: 30,
        enabled: false,
      );

      // Newest first, then an OLDER row — so row id order contradicts time
      // order and "the latest" can no longer be the first row by accident.
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2025, 12, 1, 9),
      );
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2025, 6, 1, 9),
      );
      await db.insertRoReplacement(
        stageId: retired,
        replacedAt: DateTime(2026, 2, 1, 10),
      );

      final c = clockContainer(now);
      final sub = c.listen(roStageStatusProvider, (_, _) {});
      addTearDown(sub.close);

      await pumpUntil(
        () =>
            (c.read(roStagesProvider).value ?? const []).length == 3 &&
            (c.read(roReplacementsProvider).value ?? const []).length == 3,
      );

      final byStage = {
        for (final row in c.read(roStageStatusProvider)) row.stage.id: row,
      };
      expect(
        byStage.keys,
        containsAll([sediment, membrane, retired]),
        reason:
            'a disabled stage keeps its row — the overview hides it, the '
            'provider does not',
      );
      expect(byStage[retired]!.stage.enabled, isFalse);

      // The June row would have read as 90 days overdue; the December one is
      // 90 days out. Nothing but "newest wins" lands on this date.
      expect(byStage[sediment]!.lastReplacedAt, DateTime(2025, 12, 1, 9));
      expect(byStage[sediment]!.due!.dueAt, DateTime(2026, 5, 30, 9));
      expect(byStage[sediment]!.due!.daysLeft, 90);

      // Never replaced → no anchor → no due date (never "due now").
      expect(byStage[membrane]!.lastReplacedAt, isNull);
      expect(byStage[membrane]!.due, isNull);

      // Disabled, but still scored: 2026-02-01 + 30 d, across February.
      expect(byStage[retired]!.due!.dueAt, DateTime(2026, 3, 3, 10));
      expect(byStage[retired]!.due!.daysLeft, 2);

      // A newer replacement re-anchors; an older one logged afterwards (a
      // backdated correction) must not drag the stage back.
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2026, 2, 10, 9),
      );
      await pumpUntil(
        () =>
            c
                .read(roStageStatusProvider)
                .firstWhere((r) => r.stage.id == sediment)
                .lastReplacedAt ==
            DateTime(2026, 2, 10, 9),
      );
      await db.insertRoReplacement(
        stageId: sediment,
        replacedAt: DateTime(2025, 1, 15, 9),
      );
      await pumpUntil(
        () => (c.read(roReplacementsProvider).value ?? const []).length == 5,
      );
      expect(
        c
            .read(roStageStatusProvider)
            .firstWhere((r) => r.stage.id == sediment)
            .lastReplacedAt,
        DateTime(2026, 2, 10, 9),
      );
    });
  });

  test('trackedParametersProvider never emits catalog defaults over a tank\'s '
      'own overrides', () async {
    final tankId = await db.createTankWithPreset(
      name: 'Low nutrient',
      type: SetupType.mixed,
    );
    // Bounds a keeper would actually tune to, and which must differ from the
    // preset's or the test would pass vacuously.
    const tuned = ZoneBounds(
      amberLow: 6.0,
      greenLow: 6.4,
      greenHigh: 7.2,
      amberHigh: 7.6,
    );
    final defaults = defaultBoundsFor(SetupType.mixed, 'alkalinity');
    expect(tuned, isNot(defaults));
    await db.setParameterOverride(tankId, 'alkalinity', tuned, target: 6.8);
    await db.setActiveTank(tankId);

    // Every *data* emission, in order — the bug is a cold-start frame in
    // which the rows have landed but the overrides have not, repainting a
    // tuned tank against the catalog defaults.
    final seen = <ZoneBounds>[];
    final sub = container.listen(trackedParametersProvider, (_, next) {
      final rows = next.value;
      if (rows == null || rows.isEmpty) return;
      seen.add(rows.firstWhere((p) => p.paramKey == 'alkalinity').bounds);
    }, fireImmediately: true);
    addTearDown(sub.close);

    await pumpUntil(() => seen.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      seen,
      everyElement(tuned),
      reason: 'the defaults must never flash over a stored override',
    );

    // Not vacuous: the listener really does observe bound changes, so an
    // intermediate defaults emission would have been recorded.
    await db.clearParameterOverride(tankId, 'alkalinity');
    await pumpUntil(() => seen.last == defaults);
  });
}
