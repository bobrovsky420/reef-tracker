import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/notifications.dart';
import 'package:reeftracker/data/reminder_scheduler.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/reminders.dart';
import 'package:reeftracker/domain/setup_type.dart';

class _FakeSink implements ReminderSink {
  final List<List<PlannedNotification>> syncs = [];
  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {
    syncs.add(planned);
  }
}

void main() {
  late AppDatabase db;
  late AppSettings settings;
  late _FakeSink sink;
  late ReminderScheduler scheduler;

  // Mid-morning, after the default 09:00 reminder time, on a Wednesday.
  final now = DateTime(2026, 7, 15, 10, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettings(db);
    sink = _FakeSink();
    scheduler = ReminderScheduler(db, sink);
  });
  tearDown(() async {
    scheduler.dispose();
    await db.close();
  });

  Future<int> tank(String name) async =>
      db.createTankWithPreset(name: name, type: SetupType.mixed);

  test('all master switches off plans nothing', () async {
    await tank('Reef');
    expect(await scheduler.plan(now: now), isEmpty);
  });

  group('testing reminders (U1)', () {
    test('plans on the due day at the reminder time, localized', () async {
      final t = await tank('Reef');
      await settings.setRemindersTesting(true);
      final alk = (await db.getTrackedParameters(
        t,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      await db.setTestCadence(alk.id, 7);
      await db.insertReading(
        tankId: t,
        paramKey: 'alkalinity',
        value: 8.2,
        takenAt: DateTime(2026, 7, 10, 18),
      );

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      final n = planned.single;
      expect(n.kind, ReminderKind.testing);
      // Due 17 Jul (10 Jul + 7 d), fired at the default 09:00.
      expect(n.fireAtLocal, DateTime(2026, 7, 17, 9));
      expect(n.title, 'Time to test'); // single tank: no tank suffix
      expect(n.body, 'Alkalinity');
      expect(n.payload, contains('/add-reading'));
    });

    test('never-tested parameters with a cadence are due today — which is '
        'already past the reminder time, so nothing is planned', () async {
      final t = await tank('Reef');
      await settings.setRemindersTesting(true);
      final alk = (await db.getTrackedParameters(
        t,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      await db.setTestCadence(alk.id, 7);
      // No reading at all: due "now" (10:30), fire moment 09:00 today already
      // passed → the due chip carries it, no post-hoc notification.
      expect(await scheduler.plan(now: now), isEmpty);
    });

    test('parameters without a cadence, or disabled, are skipped', () async {
      final t = await tank('Reef');
      await settings.setRemindersTesting(true);
      final params = await db.getTrackedParameters(t);
      final alk = params.firstWhere((p) => p.paramKey == 'alkalinity');
      final ca = params.firstWhere((p) => p.paramKey == 'calcium');
      await db.setTestCadence(ca.id, 7);
      await db.updateTrackedParameter(ca.copyWith(enabled: false));
      await db.insertReading(
        tankId: t,
        paramKey: 'calcium',
        value: 420,
        takenAt: DateTime(2026, 7, 12),
      );
      // alk has a reading but no cadence.
      await db.insertReading(
        tankId: t,
        paramKey: 'alkalinity',
        value: 8,
        takenAt: DateTime(2026, 7, 12),
      );
      expect(alk.testCadenceDays, isNull);
      expect(await scheduler.plan(now: now), isEmpty);
    });

    test('same-day dues coalesce into one notification', () async {
      final t = await tank('Reef');
      await settings.setRemindersTesting(true);
      final params = await db.getTrackedParameters(t);
      for (final key in ['alkalinity', 'calcium']) {
        final p = params.firstWhere((x) => x.paramKey == key);
        await db.setTestCadence(p.id, 7);
        await db.insertReading(
          tankId: t,
          paramKey: key,
          value: 1,
          takenAt: DateTime(2026, 7, 10, 18),
        );
      }
      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      expect(planned.single.body, 'Alkalinity, Calcium (Ca)');
    });
  });

  group('dosing reminders (U2)', () {
    Future<int> entry(
      int tankId, {
      bool remind = true,
      String? doseTime = '21:00',
      String state = 'active',
    }) => db.insertDosingEntry(
      DosingEntriesCompanion.insert(
        tankId: tankId,
        product: 'Reef Foundation B',
        frequency: const Value('daily'),
        doseTime: Value(doseTime),
        remindEnabled: Value(remind),
        startedAt: Value(DateTime(2026, 7, 1)),
        state: Value(state),
      ),
    );

    test('plans daily occurrences at the entry dose time', () async {
      final t = await tank('Reef');
      await settings.setRemindersDosing(true);
      await entry(t);

      final planned = await scheduler.plan(now: now);
      // One per day for the 14-day horizon: today's 21:00 is still ahead, the
      // 14th day's 21:00 falls beyond `now + 14 d` (10:30) — so 14 in total.
      expect(planned, hasLength(14));
      expect(planned.first.kind, ReminderKind.dosing);
      expect(planned.first.fireAtLocal, DateTime(2026, 7, 15, 21));
      expect(planned.first.title, 'Dosing due');
      expect(planned.first.body, 'Reef Foundation B');
      expect(planned.first.payload, contains('tab=dosing'));
    });

    test('opt-out, missing dose time, and ended entries are silent', () async {
      final t = await tank('Reef');
      await settings.setRemindersDosing(true);
      await entry(t, remind: false);
      await entry(t, doseTime: null);
      await entry(t, state: 'ended');
      expect(await scheduler.plan(now: now), isEmpty);
    });
  });

  group('maintenance reminders (U12)', () {
    test('typed plans anchor on the action log', () async {
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 8));

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      expect(planned.single.kind, ReminderKind.maintenance);
      // Due 22 Jul (8 Jul + 14 d) at the default 09:00.
      expect(planned.single.fireAtLocal, DateTime(2026, 7, 22, 9));
      expect(planned.single.title, 'Maintenance due');
      expect(planned.single.body, 'Water change');
      expect(planned.single.payload, contains('tab=actions'));
    });

    test('custom tasks anchor on their own lastDoneAt; one-offs on their '
        'planned date', () async {
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      final custom = await db.insertMaintenanceSchedule(
        tankId: t,
        title: 'Clean skimmer',
        cadenceDays: 7,
      );
      await db.markMaintenanceDone(custom, DateTime(2026, 7, 12, 8));
      await db.insertMaintenanceSchedule(
        tankId: t,
        title: 'Replace RO membrane',
        scheduledAt: DateTime(2026, 7, 20),
      );

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(2));
      expect(planned[0].fireAtLocal, DateTime(2026, 7, 19, 9));
      expect(planned[0].body, 'Clean skimmer');
      expect(planned[1].fireAtLocal, DateTime(2026, 7, 20, 9));
      expect(planned[1].body, 'Replace RO membrane');
    });

    test('per-plan opt-out is honored', () async {
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
        remindEnabled: false,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 8));
      expect(await scheduler.plan(now: now), isEmpty);
    });

    test('the configured reminder time is used', () async {
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await settings.setReminderTime(19, 30);
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 8));
      final planned = await scheduler.plan(now: now);
      expect(planned.single.fireAtLocal, DateTime(2026, 7, 22, 19, 30));
    });
  });

  test('multi-tank titles carry the tank name; soft-deleted tanks are '
      'excluded', () async {
    final a = await tank('Reef A');
    final b = await tank('Reef B');
    await settings.setRemindersMaintenance(true);
    for (final t in [a, b]) {
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 8));
    }

    var planned = await scheduler.plan(now: now);
    expect(planned, hasLength(2));
    expect(planned.map((n) => n.title), [
      'Maintenance due — Reef A',
      'Maintenance due — Reef B',
    ]);

    await db.softDeleteTank(b);
    planned = await scheduler.plan(now: now);
    expect(planned, hasLength(1));
    // Back to a single visible tank: no suffix needed.
    expect(planned.single.title, 'Maintenance due');
  });

  test('resync pushes the plan to the sink and single-flights', () async {
    // resync() plans against the real wall clock, so seed relative to it.
    final t = await tank('Reef');
    await settings.setRemindersMaintenance(true);
    await db.insertMaintenanceSchedule(
      tankId: t,
      actionType: 'waterChange',
      cadenceDays: 7,
    );
    await db.insertWaterChange(
      tankId: t,
      changedAt: DateTime.now().subtract(const Duration(days: 4)),
    );

    await Future.wait([scheduler.resync(), scheduler.resync()]);
    // The second call rode the first as a dirty re-loop (2 syncs), never a
    // concurrent overlap; at minimum one sync happened.
    expect(sink.syncs, isNotEmpty);
    expect(sink.syncs.last, hasLength(1));
  });

  test('a relevant write triggers a debounced auto-resync', () async {
    // The auto-resync plans against the real wall clock — seed relative to it.
    final t = await tank('Reef');
    await settings.setRemindersMaintenance(true);
    scheduler.start();
    await db.insertMaintenanceSchedule(
      tankId: t,
      actionType: 'waterChange',
      cadenceDays: 7,
    );
    await db.insertWaterChange(
      tankId: t,
      changedAt: DateTime.now().subtract(const Duration(days: 4)),
    );
    // Debounce is 2 s of real time.
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    expect(sink.syncs, isNotEmpty);
    expect(sink.syncs.last.single.body, 'Water change');
  });

  test('handleReminderPayload activates the tank and navigates', () async {
    final a = await tank('Reef A');
    final b = await tank('Reef B');
    expect(await db.getActiveTankId(), b); // last created is active

    String? navigated;
    await handleReminderPayload(
      db,
      '{"tankId":$a,"route":"/add-reading"}',
      (route) => navigated = route,
    );
    expect(await db.getActiveTankId(), a);
    expect(navigated, '/add-reading');

    // Malformed payloads and unknown tanks are ignored (no navigation for
    // garbage; a dead tank id still navigates but never activates).
    navigated = null;
    await handleReminderPayload(db, 'not json', (route) => navigated = route);
    expect(navigated, isNull);

    await handleReminderPayload(
      db,
      '{"tankId":999,"route":"/?tab=actions"}',
      (route) => navigated = route,
    );
    expect(await db.getActiveTankId(), a);
    expect(navigated, '/?tab=actions');
  });
}
