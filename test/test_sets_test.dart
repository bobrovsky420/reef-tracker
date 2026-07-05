import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/add_reading/add_reading_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the Add Reading test-set chips (U9): the chip is a view
/// filter (typed values hidden by it are still saved), the last-used set is
/// preselected per tank, and the create sheet pre-checks typed parameters.
///
/// Finder notes: text finders are scoped to [AddReadingScreen] because the
/// screen is *pushed* over the home shell (as in the real app — save calls
/// `context.pop()`), whose dashboard shows the same parameter names. The
/// parameters used are Temperature/Alkalinity, never pH — the pH row's unit
/// suffix is the literal text "pH", so `find.text('pH')` matches twice within
/// the row itself.
void main() {
  /// Bounded fake-time settle — NOT pumpAndSettle, which never settles while
  /// a CircularProgressIndicator animates (see router_test.dart).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app inside the test body so drift's pending stream timers
  /// are flushed before the binding's timer check (see router_test.dart).
  /// Every test runs its body in try/finally around this — a failed
  /// expectation must still unmount, or the leftover timers hang the runner.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Boots the real router over an in-memory database seeded with one
  /// mixed-type tank, then *pushes* the Add Reading screen over home.
  Future<(AppDatabase, int)> pumpAddReading(WidgetTester tester) async {
    // Phone-tall surface: the create sheet lists ~10 checkboxes plus a Save
    // button, which doesn't fit the default 800×600 test viewport (the tap on
    // Save lands at the clipped bottom edge and misses).
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    // Not awaited: push's future completes only when the route is popped.
    unawaited(appRouter.push('/add-reading'));
    await settle(tester);
    return (db, tankId);
  }

  /// [f] within the Add Reading screen (the home shell beneath shows the same
  /// parameter names on its dashboard tiles).
  Finder inAdd(Finder f) =>
      find.descendant(of: find.byType(AddReadingScreen), matching: f);

  /// The value TextField in the parameter row titled [paramName].
  Finder paramField(String paramName) => find.descendant(
    of: find.ancestor(
      of: inAdd(find.text(paramName)),
      matching: find.byType(Row),
    ),
    matching: find.byType(TextField),
  );

  testWidgets('chips filter the visible rows; hidden typed values still save', (
    tester,
  ) async {
    final (db, tankId) = await pumpAddReading(tester);
    try {
      await db.insertReadingTemplate(
        tankId: tankId,
        name: 'Alk only',
        paramKeys: ['alkalinity'],
      );
      await settle(tester);

      // "All" is selected by default: every enabled parameter row is shown.
      expect(inAdd(find.text('Temperature')), findsOneWidget);
      expect(inAdd(find.text('Alkalinity')), findsOneWidget);

      // Type into two rows, then narrow to the Alk-only set.
      await tester.enterText(paramField('Temperature'), '25');
      await tester.enterText(paramField('Alkalinity'), '8.5');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Alk only'));
      await settle(tester);

      expect(inAdd(find.text('Alkalinity')), findsOneWidget);
      expect(inAdd(find.text('Temperature')), findsNothing);

      // Saving persists BOTH values: the chip filters the view, not the data.
      await tester.tap(find.text('Save readings'));
      await settle(tester);
      final readings = await db.getAllReadings();
      expect(readings.map((r) => r.paramKey).toSet(), {
        'temperature',
        'alkalinity',
      });

      // The chip tap was persisted as this tank's last-used set.
      final saved = AppSettings.decodeLastReadingTemplates(
        await db.getSetting(kLastReadingTemplateKey),
      );
      expect(saved[tankId], isNotNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('the last-used set is preselected on entry', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    final templateId = await db.insertReadingTemplate(
      tankId: tankId,
      name: 'Alk only',
      paramKeys: ['alkalinity'],
    );
    await AppSettings(db).setLastReadingTemplate(tankId, templateId);
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
    // Not awaited: push's future completes only when the route is popped.
    unawaited(appRouter.push('/add-reading'));
    await settle(tester);
    try {
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Alk only'),
      );
      expect(chip.selected, isTrue);
      expect(inAdd(find.text('Alkalinity')), findsOneWidget);
      expect(inAdd(find.text('Temperature')), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a set whose parameters are all disabled shows the hint', (
    tester,
  ) async {
    final (db, tankId) = await pumpAddReading(tester);
    try {
      await db.insertReadingTemplate(
        tankId: tankId,
        name: 'Ghost',
        // A key the mixed preset does not track — nothing to show.
        paramKeys: ['strontium'],
      );
      await settle(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ghost'));
      await settle(tester);

      expect(inAdd(find.text('Temperature')), findsNothing);
      expect(find.textContaining('has no enabled parameters'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('create sheet pre-checks typed parameters and selects the set', (
    tester,
  ) async {
    final (db, tankId) = await pumpAddReading(tester);
    try {
      await tester.enterText(paramField('Alkalinity'), '8.5');
      await tester.tap(find.widgetWithText(ActionChip, 'New test set'));
      await settle(tester);

      // The parameter holding a typed value comes pre-checked; others do not.
      final alkTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Alkalinity'),
      );
      expect(alkTile.value, isTrue);
      final tempTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Temperature'),
      );
      expect(tempTile.value, isFalse);

      await tester.enterText(find.byType(TextFormField).first, 'Daily Alk');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      // Created, and immediately the active filter.
      final template = (await db.getAllReadingTemplates()).single;
      expect(template.tankId, tankId);
      expect(template.name, 'Daily Alk');
      expect(template.keys, ['alkalinity']);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Daily Alk'),
      );
      expect(chip.selected, isTrue);
      expect(inAdd(find.text('Temperature')), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('manage sheet deletes a set after confirmation', (tester) async {
    final (db, tankId) = await pumpAddReading(tester);
    try {
      await db.insertReadingTemplate(
        tankId: tankId,
        name: 'Alk only',
        paramKeys: ['alkalinity'],
      );
      await settle(tester);

      await tester.tap(find.byIcon(Icons.checklist));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      expect(await db.getAllReadingTemplates(), isEmpty);
    } finally {
      await unmountApp(tester);
    }
  });
}
