import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';

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

  test(
      'switching the active tank never exposes the previous tank\'s '
      'readings (#20)', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
    await db.insertReading(
        tankId: a, paramKey: 'ph', value: 8.1, takenAt: DateTime(2026, 1, 1));
    await db.setActiveTank(a);

    // Record every data emission together with the tank that was active when
    // it arrived — the bug was tank A's rows rendering under tank B's name.
    final emissions = <({int? tankId, List<Reading> rows})>[];
    final sub = container.listen(tankReadingsProvider, (_, next) {
      final rows = next.value;
      if (rows != null) {
        emissions.add(
            (tankId: container.read(activeTankProvider)?.id, rows: rows));
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    await pumpUntil(() =>
        emissions.any((e) => e.tankId == a && e.rows.isNotEmpty));

    await db.setActiveTank(b);
    // Wait until tank B's (empty) readings have settled.
    await pumpUntil(() =>
        container.read(activeTankProvider)?.id == b &&
        container.read(tankReadingsProvider).hasValue &&
        container.read(tankReadingsProvider).value!.isEmpty);

    for (final e in emissions.where((e) => e.tankId == b)) {
      expect(e.rows.where((r) => r.tankId == a), isEmpty,
          reason: "tank A's readings must never surface while B is active");
    }
    // And the settled state is B's own (empty) list, not a stale copy.
    expect(container.read(tankReadingsProvider).value, isEmpty);
  });

  test(
      'a write for another tank does not re-notify the active tank\'s '
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
        takenAt: now.subtract(const Duration(days: 2)));
    await db.setActiveTank(a);

    var readingsNotifies = 0;
    var healthNotifies = 0;
    final readingsSub = container.listen(
        tankReadingsProvider, (_, _) => readingsNotifies++,
        fireImmediately: true);
    final healthSub = container.listen(
        tankHealthProvider, (_, _) => healthNotifies++,
        fireImmediately: true);
    addTearDown(readingsSub.close);
    addTearDown(healthSub.close);

    // Settle on the derived provider too: its rebuild lands an event-loop
    // turn after the readings notify, so sample the baselines only once the
    // whole chain is quiet.
    await pumpUntil(() =>
        (container.read(tankReadingsProvider).value ?? const []).isNotEmpty &&
        container.read(tankHealthProvider).hasData);
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
        takenAt: now.subtract(const Duration(days: 1)));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(readingsNotifies, settledReadings,
        reason: "another tank's write must not re-notify readings watchers");
    expect(healthNotifies, settledHealth,
        reason: "another tank's write must not re-notify health watchers");
    // And a genuine write for tank A still comes through.
    await db.insertReading(
        tankId: a, paramKey: 'ph', value: 8.2, takenAt: now);
    await pumpUntil(() => readingsNotifies > settledReadings);
  });

  test('switching back to a tank reloads its data', () async {
    final a = await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final b = await db.createTankWithPreset(name: 'B', type: SetupType.mixed);
    await db.insertReading(
        tankId: a, paramKey: 'ph', value: 8.1, takenAt: DateTime(2026, 1, 1));

    final sub = container.listen(tankReadingsProvider, (_, _) {});
    addTearDown(sub.close);

    await db.setActiveTank(a);
    await pumpUntil(() =>
        (container.read(tankReadingsProvider).value ?? const []).isNotEmpty);

    await db.setActiveTank(b);
    await pumpUntil(() =>
        container.read(activeTankProvider)?.id == b &&
        (container.read(tankReadingsProvider).value?.isEmpty ?? false));

    // The previous tank's family instance was disposed; switching back must
    // freshly load A's rows rather than hold a dead stream.
    await db.setActiveTank(a);
    await pumpUntil(() =>
        container.read(activeTankProvider)?.id == a &&
        (container.read(tankReadingsProvider).value ?? const []).isNotEmpty);
    expect(container.read(tankReadingsProvider).value!.single.value, 8.1);
  });
}
