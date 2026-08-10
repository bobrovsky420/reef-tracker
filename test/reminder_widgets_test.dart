import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is only exposed as a public type through misc.dart in riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/notifications.dart';
import 'package:reeftracker/data/setting_keys.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the reminders & schedules UX (U1/U2/U12): the /schedule
/// screen (create/edit/delete/mark-done with undo), the Actions-tab due
/// chips, Settings → Reminders, the parameter-edit cadence chips, and the
/// dosing-edit "Remind me" gating.
void main() {
  /// Bounded fake-time settle — NOT pumpAndSettle, which never settles while
  /// a CircularProgressIndicator animates (see router_test.dart).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<(AppDatabase, int)> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    addTearDown(() => appRouter.go('/'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter,
        ),
      ),
    );
    await settle(tester);
    return (db, tankId);
  }

  group('/schedule screen (U12)', () {
    testWidgets('creates a typed recurring plan via the sheet', (tester) async {
      final (db, tankId) = await pumpApp(tester);
      appRouter.go('/schedule');
      await settle(tester);

      // Empty state, then the add sheet with its defaults (water change,
      // repeating every 14 days).
      expect(find.textContaining('No maintenance tasks yet'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      expect(find.text('Add task'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final row = (await db.getMaintenanceSchedules(tankId)).single;
      expect(row.actionType, 'waterChange');
      expect(row.cadenceDays, 14);
      expect(find.text('Water change'), findsOneWidget);
      // Never done, no planned date: due immediately.
      expect(find.textContaining('Due today'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('delete from the edit sheet offers undo', (tester) async {
      final (db, tankId) = await pumpApp(tester);
      await db.insertMaintenanceSchedule(
        tankId: tankId,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      appRouter.go('/schedule');
      await settle(tester);

      await tester.tap(find.text('Water change'));
      await settle(tester);
      expect(find.text('Edit task'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(await db.getMaintenanceSchedules(tankId), isEmpty);
      expect(find.text('Task deleted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(
        (await db.getMaintenanceSchedules(tankId)).single.actionType,
        'waterChange',
      );
      await unmountApp(tester);
    });

    testWidgets('mark done stamps a custom task; undo restores it', (
      tester,
    ) async {
      final (db, tankId) = await pumpApp(tester);
      await db.insertMaintenanceSchedule(
        tankId: tankId,
        title: 'Clean skimmer',
        cadenceDays: 7,
      );
      appRouter.go('/schedule');
      await settle(tester);

      await tester.tap(find.byTooltip('Mark done'));
      await settle(tester);
      expect(
        (await db.getMaintenanceSchedules(tankId)).single.lastDoneAt,
        isNotNull,
      );
      expect(find.text('Marked as done'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(
        (await db.getMaintenanceSchedules(tankId)).single.lastDoneAt,
        isNull,
      );
      await unmountApp(tester);
    });
  });

  testWidgets('Actions tab shows due chips; a typed chip opens the '
      'pre-selected action dialog', (tester) async {
    final (db, tankId) = await pumpApp(tester);
    await db.insertMaintenanceSchedule(
      tankId: tankId,
      actionType: 'waterChange',
      cadenceDays: 7,
    );
    await db.insertWaterChange(
      tankId: tankId,
      changedAt: DateTime.now().subtract(const Duration(days: 10)),
    );
    appRouter.go('/');
    await settle(tester);
    await tester.tap(find.text('Actions'));
    await settle(tester);

    // Overdue by 3 days (10 ago + 7 cadence).
    expect(find.textContaining('3 d overdue'), findsOneWidget);
    await tester.tap(find.textContaining('3 d overdue'));
    await settle(tester);
    // Straight into the water-change dialog — no kind sheet.
    expect(find.text('Record water change'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('Settings → Reminders: switches default off; enabling writes '
      'the setting', (tester) async {
    final (db, _) = await pumpApp(tester);
    appRouter.go('/settings/reminders');
    await settle(tester);

    // REDESIGN #23: the category rows are ReefSettingsRows carrying bare
    // adaptive switches (full-row tap preserved via the row's onTap).
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    for (final s in tester.widgetList<Switch>(switches)) {
      expect(s.value, isFalse);
    }

    await tester.tap(find.text('Testing reminders'));
    await settle(tester);
    expect(await db.getSetting(kRemindersTestingKey), 'true');
    await unmountApp(tester);
  });

  // The permission half of the same screen. `ReminderNotifications` reads an
  // *unknown* plugin answer as `true` on both methods (`?? true`) so a device
  // with no runtime gate never gets a spurious warning — which also means a
  // broken wiring (a method that stops being called, or a plugin that starts
  // answering null) looks exactly like "permitted". Nothing then fires, and
  // the screen still says everything is fine. These drive the screen against a
  // platform that answers, so the warning row is pinned to a real denial.
  group('Settings → Reminders: the OS permission warning (U1)', () {
    Future<_FakeNotifications> openReminders(
      WidgetTester tester, {
      required bool permitted,
    }) async {
      final notifications = _FakeNotifications(permitted: permitted);
      await pumpApp(
        tester,
        overrides: [
          reminderNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      appRouter.go('/settings/reminders');
      await settle(tester);
      return notifications;
    }

    final warning = find.textContaining('Notifications are blocked');

    testWidgets('enabling a category with the permission denied shows the '
        'warning row', (tester) async {
      final notifications = await openReminders(tester, permitted: false);

      // Nothing is on yet, so a denial is not worth saying — the app has
      // asked the OS for nothing.
      expect(notifications.areEnabledCalls, 1, reason: 'the initState check');
      expect(warning, findsNothing);

      await tester.tap(find.text('Testing reminders'));
      await settle(tester);

      // Enabling is the moment the permission is requested (never at start),
      // and a refusal has to be visible: the switch is on, but nothing will
      // ever be delivered.
      expect(notifications.requestCalls, 1);
      expect(warning, findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('a granted permission leaves the screen clean', (tester) async {
      final notifications = await openReminders(tester, permitted: true);

      await tester.tap(find.text('Testing reminders'));
      await settle(tester);

      expect(notifications.requestCalls, 1);
      expect(warning, findsNothing);
      await unmountApp(tester);
    });

    testWidgets('turning the last category off retires the warning and '
        're-reads the permission', (tester) async {
      final notifications = await openReminders(tester, permitted: false);

      await tester.tap(find.text('Testing reminders'));
      await settle(tester);
      expect(warning, findsOneWidget);

      await tester.tap(find.text('Testing reminders'));
      await settle(tester);

      // Off again: the denial is still true but no longer costs the keeper
      // anything, so the row goes. Disabling re-reads rather than re-asking —
      // the request dialog is a once-per-install affair.
      expect(warning, findsNothing);
      expect(notifications.requestCalls, 1, reason: 'never asked again');
      expect(notifications.areEnabledCalls, 2);
      await unmountApp(tester);
    });

    testWidgets('a permission granted in system settings clears the warning '
        'on the next toggle', (tester) async {
      final notifications = await openReminders(tester, permitted: false);
      await tester.tap(find.text('Testing reminders'));
      await settle(tester);
      expect(warning, findsOneWidget);

      // The keeper leaves for the system settings, allows notifications, and
      // comes back to switch on a second category.
      notifications.permitted = true;
      await tester.tap(find.text('Dosing reminders'));
      await settle(tester);

      expect(warning, findsNothing);
      await unmountApp(tester);
    });
  });

  testWidgets('parameter edit: cadence preset chip round-trips (U1)', (
    tester,
  ) async {
    final (db, tankId) = await pumpApp(tester);
    final param = (await db.getTrackedParameters(tankId)).first;
    // push, not go: the screen's Save pops, which needs a page underneath
    // (exactly how the app reaches it from Manage Parameters).
    unawaited(appRouter.push('/parameters/${param.id}/edit'));
    await settle(tester);

    // The cadence chips sit low in a lazily built ListView — scroll them
    // into existence first (ensureVisible can't find unbuilt children).
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, '7 d'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '7 d'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(
      (await db.getTrackedParameters(
        tankId,
      )).firstWhere((p) => p.id == param.id).testCadenceDays,
      7,
    );
    await unmountApp(tester);
  });

  testWidgets('dosing edit: Remind me is disabled without a dose time (U2)', (
    tester,
  ) async {
    await pumpApp(tester);
    appRouter.go('/dosing/edit');
    await settle(tester);

    await tester.scrollUntilVisible(
      find.widgetWithText(SwitchListTile, 'Remind me'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Remind me'),
    );
    expect(tile.onChanged, isNull);
    expect(find.text('Set a time of day to enable reminders'), findsOneWidget);
    await unmountApp(tester);
  });
}

/// A notification platform that actually answers — the seam §3 asked for, on
/// [ReminderNotifications] rather than on the scheduler, because
/// `requestPermission()` / `areEnabled()` live here.
///
/// It exists because the real methods cannot run under `flutter test` at all:
/// they reach `resolvePlatformSpecificImplementation`, whose
/// `FlutterLocalNotificationsPlatform.instance` is a `late` field only plugin
/// registration initializes, so it throws — and both methods catch that and
/// fall through to their `return true`. Every test would therefore see
/// "permitted" no matter what the screen did with the answer.
///
/// [permitted] is settable so a test can play the keeper who steps out to
/// system settings and comes back; the counters pin *which* method each path
/// asks (enabling requests, disabling only re-reads).
class _FakeNotifications extends ReminderNotifications {
  _FakeNotifications({required this.permitted});

  bool permitted;
  int requestCalls = 0;
  int areEnabledCalls = 0;

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    return permitted;
  }

  @override
  Future<bool> areEnabled() async {
    areEnabledCalls++;
    return permitted;
  }
}
