import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
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

  Future<(AppDatabase, int)> pumpApp(WidgetTester tester) async {
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
        overrides: [dbProvider.overrideWithValue(db)],
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

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(3));
    for (final s in tester.widgetList<SwitchListTile>(switches)) {
      expect(s.value, isFalse);
    }

    await tester.tap(find.text('Testing reminders'));
    await settle(tester);
    expect(await db.getSetting(kRemindersTestingKey), 'true');
    await unmountApp(tester);
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
