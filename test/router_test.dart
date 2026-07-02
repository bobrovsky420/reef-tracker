import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/home/home_shell.dart';
import 'package:reeftracker/features/manage_parameters/manage_parameters_screen.dart';
import 'package:reeftracker/features/tanks/tanks_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Regression tests for TODO #1/#2: the `/tanks/:id/edit` and
/// `/parameters/:id/edit` routes must work from the URL alone (deep link,
/// state restoration) — `state.extra` is only an in-app fast path.
void main() {
  /// Boots the real [appRouter] against an in-memory database and returns the
  /// database for seeding.
  Future<AppDatabase> pumpRouterApp(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // The router singleton keeps its location across tests; park it at home
    // so the next test starts from a known state.
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
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('/parameters/:id/edit without extra resolves the param from the DB',
      (tester) async {
    final db = await pumpRouterApp(tester);
    final tankId =
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    final params = await db.watchTrackedParameters(tankId).first;
    expect(params, isNotEmpty, reason: 'preset must track parameters');

    appRouter.go('/parameters/${params.first.id}/edit');
    await tester.pumpAndSettle();

    expect(find.byType(ParameterEditScreen), findsOneWidget);
  });

  testWidgets('/tanks/:id/edit without extra opens the edit form, not create',
      (tester) async {
    final db = await pumpRouterApp(tester);
    final tankId =
        await db.createTankWithPreset(name: 'Reef One', type: SetupType.mixed);

    appRouter.go('/tanks/$tankId/edit');
    await tester.pumpAndSettle();

    expect(find.byType(TankEditScreen), findsOneWidget);
    // The form is pre-filled with the existing tank, not a blank create form.
    expect(find.text('Reef One'), findsWidgets);
  });

  testWidgets('an unknown :id redirects home instead of crashing',
      (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/parameters/424242/edit');
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
  });
}
