import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
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

/// Fails the first sync only — the shape of a transient platform hiccup.
class _FlakySink implements ReminderSink {
  bool throwNext = false;
  final List<List<PlannedNotification>> syncs = [];
  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {
    if (throwNext) {
      throwNext = false;
      throw StateError('notification plugin unavailable');
    }
    syncs.add(planned);
  }
}

/// Holds the first sync open until [release] completes, so a write (and the
/// resync it triggers) can land while a pass is genuinely in flight. Records
/// how many passes ever overlapped.
class _GatedSink implements ReminderSink {
  final List<List<PlannedNotification>> syncs = [];
  final Completer<void> firstEntered = Completer<void>();
  final Completer<void> release = Completer<void>();
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    syncs.add(planned);
    if (!firstEntered.isCompleted) {
      firstEntered.complete();
      await release.future;
    }
    inFlight--;
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

    test('the microelements switch silences micro test reminders but not '
        'core ones (U17)', () async {
      final t = await tank('Reef');
      await settings.setRemindersTesting(true);
      // One core and one micro parameter, both with a cadence and a reading
      // on the same day → both due 17 Jul.
      final alk = (await db.getTrackedParameters(
        t,
      )).firstWhere((p) => p.paramKey == 'alkalinity');
      await db.setTestCadence(alk.id, 7);
      await db.addTrackedParameter(t, 'iodine');
      final iodine = (await db.getTrackedParameters(
        t,
      )).firstWhere((p) => p.paramKey == 'iodine');
      await db.setTestCadence(iodine.id, 7);
      for (final key in ['alkalinity', 'iodine']) {
        await db.insertReading(
          tankId: t,
          paramKey: key,
          value: 1,
          takenAt: DateTime(2026, 7, 10, 18),
        );
      }
      // Both due → coalesced into one notification naming both.
      expect((await scheduler.plan(now: now)).single.body, contains('Iodine'));

      await settings.setMicroEnabled(false);
      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      expect(planned.single.body, 'Alkalinity');
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

  group('RO unit reminders (U16)', () {
    test('enabled stages fire on the maintenance channel with the RO title, '
        'never a tank name', () async {
      // Two tanks: tank-scoped maintenance would carry a tank suffix, the
      // device-scoped RO notification must not.
      await tank('Reef A');
      await tank('Reef B');
      await settings.setRemindersMaintenance(true);
      await db.seedDefaultRoStages();
      final sediment = (await db.getRoStages()).firstWhere(
        (s) => s.stageType == 'sediment',
      );
      // Last replaced 84 days ago on a 90-day lifespan → due 21 Jul.
      await db.insertRoReplacement(
        stageId: sediment.id,
        replacedAt: DateTime(2026, 4, 22, 12),
      );

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      final n = planned.single;
      expect(n.kind, ReminderKind.maintenance);
      expect(n.fireAtLocal, DateTime(2026, 7, 21, 9));
      expect(n.title, 'Replace RO filters');
      expect(n.body, 'Sediment filter');
      expect(n.payload, contains('/ro'));
      expect(n.payload, contains('"tankId":null'));
    });

    test('the Settings feature switch silences all RO reminders', () async {
      await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.seedDefaultRoStages();
      final sediment = (await db.getRoStages()).firstWhere(
        (s) => s.stageType == 'sediment',
      );
      await db.insertRoReplacement(
        stageId: sediment.id,
        replacedAt: DateTime(2026, 4, 22, 12),
      );
      expect(await scheduler.plan(now: now), hasLength(1));

      await settings.setRoUnitEnabled(false);
      expect(await scheduler.plan(now: now), isEmpty);
    });

    test('disabled and opted-out stages, and stages with no logged '
        'replacement, are silent', () async {
      await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.seedDefaultRoStages();
      final stages = await db.getRoStages();
      final sediment = stages.firstWhere((s) => s.stageType == 'sediment');
      final carbon = stages.firstWhere((s) => s.stageType == 'carbonBlock');
      // Anchored but disabled.
      await db.insertRoReplacement(
        stageId: sediment.id,
        replacedAt: DateTime(2026, 4, 22, 12),
      );
      await db.setRoStageEnabled(sediment.id, false);
      // Anchored but reminder opted out (due 20 Jul, within horizon).
      await db.insertRoReplacement(
        stageId: carbon.id,
        replacedAt: DateTime(2026, 1, 21, 12),
      );
      await db.updateRoStage(
        (await db.getRoStages())
            .firstWhere((s) => s.id == carbon.id)
            .copyWith(remindEnabled: false),
      );
      // The remaining stages have no replacement logged → no guessed due.
      expect(await scheduler.plan(now: now), isEmpty);
    });

    test('an RO stage and a tank plan falling due on the same day produce '
        'two notifications, each with its own title and route', () async {
      // Both are ReminderKind.maintenance on 21 Jul; only the null tankId
      // keeps them apart in coalesceReminders (Phase 1's domain test asserts
      // the merge never happens — this is its scheduler-level companion).
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 7));
      await db.seedDefaultRoStages();
      final sediment = (await db.getRoStages()).firstWhere(
        (s) => s.stageType == 'sediment',
      );
      await db.insertRoReplacement(
        stageId: sediment.id,
        replacedAt: DateTime(2026, 4, 22, 12),
      );

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(2));
      expect(
        planned.map((n) => n.fireAtLocal),
        everyElement(DateTime(2026, 7, 21, 9)),
      );
      // Same kind and channel, deliberately not the same notification.
      expect(
        planned.map((n) => n.kind),
        everyElement(ReminderKind.maintenance),
      );
      expect(
        planned.map((n) => n.channelName),
        everyElement('Maintenance reminders'),
      );

      // Device-scoped reminders sort first (tankId null → -1).
      expect(planned[0].title, 'Replace RO filters');
      expect(planned[0].body, 'Sediment filter');
      expect(planned[0].payload, contains('/ro'));
      expect(planned[0].payload, contains('"tankId":null'));

      expect(planned[1].title, 'Maintenance due');
      expect(planned[1].body, 'Water change');
      expect(planned[1].payload, contains('tab=actions'));
      expect(planned[1].payload, contains('"tankId":$t'));
    });
  });

  group('notification language', () {
    /// Seeds one maintenance reminder due 22 Jul, whatever the language.
    Future<void> seedWaterChange() async {
      final t = await tank('Reef');
      await settings.setRemindersMaintenance(true);
      await db.insertMaintenanceSchedule(
        tankId: t,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.insertWaterChange(tankId: t, changedAt: DateTime(2026, 7, 8));
    }

    test(
      'titles, bodies and channel names follow the stored app language',
      () async {
        await seedWaterChange();
        await settings.setLocaleCode('de');

        final planned = await scheduler.plan(now: now);
        expect(planned, hasLength(1));
        expect(planned.single.title, 'Wartung fällig');
        expect(planned.single.body, 'Wasserwechsel');
        expect(planned.single.channelName, 'Wartungs-Erinnerungen');
      },
    );

    test('a stored locale outside the seven supported languages falls back to '
        'English instead of planning nothing', () async {
      // lookupAppLocalizations throws a FlutterError for an unsupported
      // locale; resync's catch-all would swallow it and the user would get
      // zero reminders forever, with no symptom at all.
      await seedWaterChange();
      await settings.setLocaleCode('xx');

      final planned = await scheduler.plan(now: now);
      expect(planned, hasLength(1));
      expect(planned.single.title, 'Maintenance due');
      expect(planned.single.body, 'Water change');
      expect(planned.single.channelName, 'Maintenance reminders');
    });

    test(
      'every supported language renders a non-empty, localized title',
      () async {
        await seedWaterChange();
        final titles = <String, String>{};
        for (final code in ['en', 'cs', 'de', 'ru', 'pl', 'fr', 'it']) {
          await settings.setLocaleCode(code);
          final planned = await scheduler.plan(now: now);
          expect(planned, hasLength(1), reason: 'nothing planned for $code');
          expect(planned.single.title, isNotEmpty);
          expect(planned.single.body, isNotEmpty);
          expect(planned.single.channelName, isNotEmpty);
          titles[code] = planned.single.title;
        }
        // Not the English string smeared across every locale.
        expect(titles['de'], isNot(titles['en']));
        expect(titles['cs'], isNot(titles['en']));
      },
    );
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

  test('a throwing sink releases the single-flight latch, so the next resync '
      'still schedules', () async {
    // Without `finally { _syncing = false; }` one transient sink failure
    // disables every later reschedule until the process restarts.
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

    final flaky = _FlakySink();
    final s = ReminderScheduler(db, flaky);
    addTearDown(s.dispose);

    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    flaky.throwNext = true;
    await s.resync(); // must not rethrow — reminders never disrupt the app
    expect(flaky.syncs, isEmpty);
    expect(reported, hasLength(1));
    expect(reported.single.library, 'reminders');
    expect(reported.single.exception, isStateError);

    await s.resync();
    expect(
      flaky.syncs,
      hasLength(1),
      reason: 'the latch must have been released by the failed pass',
    );
    expect(flaky.syncs.single.single.body, 'Water change');
    expect(reported, hasLength(1), reason: 'the retry must not report again');
  });

  test('a write landing during an in-flight sync is re-planned by the dirty '
      're-loop, and the two passes never overlap', () async {
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

    final gated = _GatedSink();
    final s = ReminderScheduler(db, gated);
    addTearDown(s.dispose);

    final first = s.resync();
    await gated.firstEntered.future;
    expect(gated.syncs.single.map((n) => n.body), ['Water change']);

    // A new plan is created while the first pass is still handing its set to
    // the sink — the stale-alarm window.
    await db.insertMaintenanceSchedule(
      tankId: t,
      title: 'Clean skimmer',
      scheduledAt: DateTime.now().add(const Duration(days: 5)),
    );
    await s.resync();
    expect(
      gated.syncs,
      hasLength(1),
      reason: 'the second call must ride the running sync, not start its own',
    );

    gated.release.complete();
    await first;

    expect(gated.syncs, hasLength(2));
    expect(gated.syncs.last.map((n) => n.body), [
      'Water change',
      'Clean skimmer',
    ]);
    expect(
      gated.maxInFlight,
      1,
      reason: 'two interleaved passes would wipe each other',
    );
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
