import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_menu.dart';

/// Widget tests for the tank-delete undo flow (U10): the confirm dialog is
/// followed by a soft delete + undo SnackBar; Undo restores the tank (and the
/// active-tank slot), while letting the SnackBar expire finalizes the delete
/// (cascading hard delete). The dosing-stop undo shares the same SnackBar
/// wiring and its data path is covered in database_test.dart.
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
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Boots the real router over an in-memory database seeded with one tank
  /// (carrying one reading) and navigates to the tank list.
  Future<(AppDatabase, int)> pumpTanks(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.insertReading(
      tankId: tankId,
      paramKey: 'ph',
      value: 8.1,
      takenAt: DateTime(2026, 1, 1),
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
    appRouter.go('/tanks');
    await settle(tester);
    return (db, tankId);
  }

  /// Opens the tank's overflow menu and confirms the delete dialog, landing
  /// in the undo window.
  Future<void> deleteViaMenu(WidgetTester tester) async {
    await tester.tap(find.byType(ReefMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
  }

  testWidgets('Undo on the delete SnackBar restores the tank', (tester) async {
    final (db, tankId) = await pumpTanks(tester);
    try {
      await deleteViaMenu(tester);

      // Soft-deleted: gone from the list, undo offered.
      expect(find.text('No aquariums yet.'), findsOneWidget);
      expect(find.text('Deleted "Reef"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);

      // Restored, with its data and the active slot handed back.
      expect(find.text('Reef'), findsWidgets);
      expect((await db.getTanks()).single.id, tankId);
      expect(await db.getActiveTankId(), tankId);
      expect((await db.getAllReadings()).length, 1);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('an expired delete SnackBar finalizes the delete', (
    tester,
  ) async {
    final (db, _) = await pumpTanks(tester);
    try {
      await deleteViaMenu(tester);
      expect(find.text('Deleted "Reef"'), findsOneWidget);

      // Let the 7 s undo window lapse (the SnackBar sets `persist: false` —
      // with an action the framework would otherwise keep it forever); its
      // close finalizes the hard delete.
      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);

      expect(await db.getAllTanks(), isEmpty);
      expect(await db.getAllReadings(), isEmpty); // cascaded
    } finally {
      await unmountApp(tester);
    }
  });
}
