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
import 'package:reeftracker/features/ratio/ratio_screen.dart';
import 'package:reeftracker/features/tanks/tanks_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Regression tests for TODO #1/#2: the `/tanks/:id/edit` and
/// `/parameters/:id/edit` routes must work from the URL alone (deep link,
/// state restoration) — `state.extra` is only an in-app fast path.
void main() {
  /// Pumps a bounded amount of fake time in small steps.
  ///
  /// Deliberately NOT [WidgetTester.pumpAndSettle]: the app legitimately shows
  /// a `CircularProgressIndicator` while drift streams load, and its endless
  /// animation keeps scheduling frames, so `pumpAndSettle` never settles and
  /// the test hangs until the 10-minute watchdog (this hung CI too). Stepping
  /// fake time forward fires drift's zero-duration stream timers and lets the
  /// UI rebuild with data, without ever waiting for "no scheduled frames".
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app and flushes the timers that drift's watched queries keep
  /// pending, *inside* the test body — the binding's "A Timer is still
  /// pending" invariant check runs before `addTearDown` callbacks, so a
  /// teardown-time unmount is too late. Call as the last step of every test.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Boots the real [appRouter] against an in-memory database and returns the
  /// database for seeding.
  Future<AppDatabase> pumpRouterApp(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // These tests exercise routing, not the first-run feature tour. Left
    // unseen, the tour fires once a tank exists and its delayed showcase
    // overlay insertions land after navigation/teardown, failing the test.
    await AppSettings(db).setTourSeen(true);
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
    await settle(tester);
    return db;
  }

  testWidgets(
    '/parameters/:id/edit without extra resolves the param from the DB',
    (tester) async {
      final db = await pumpRouterApp(tester);
      final tankId = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      // A plain get, not `watchTrackedParameters(...).first`: awaiting a drift
      // *stream* inside testWidgets' FakeAsync zone deadlocks — the emission is
      // scheduled on a zero-duration timer that only fires while pumping.
      final params = await db.getTrackedParameters(tankId);
      expect(params, isNotEmpty, reason: 'preset must track parameters');

      appRouter.go('/parameters/${params.first.id}/edit');
      await settle(tester);

      expect(find.byType(ParameterEditScreen), findsOneWidget);
      await unmountApp(tester);
    },
  );

  testWidgets('/tanks/:id/edit without extra opens the edit form, not create', (
    tester,
  ) async {
    final db = await pumpRouterApp(tester);
    final tankId = await db.createTankWithPreset(
      name: 'Reef One',
      type: SetupType.mixed,
    );

    appRouter.go('/tanks/$tankId/edit');
    await settle(tester);

    expect(find.byType(TankEditScreen), findsOneWidget);
    // The form is pre-filled with the existing tank, not a blank create form.
    expect(find.text('Reef One'), findsWidgets);
    await unmountApp(tester);
  });

  testWidgets('an unknown :id redirects home instead of crashing', (
    tester,
  ) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/parameters/424242/edit');
    await settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('an unknown route shows the localized error screen with a way '
      'home (T8)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/no/such/route');
    await settle(tester);

    // The localized screen, not go_router's built-in English error page.
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go to home screen'));
    await settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('a garbage ratio type redirects home instead of opening '
      'po4no3 (T8)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/ratio/garbage');
    await settle(tester);
    expect(find.byType(RatioScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    // A valid type still opens the ratio screen through the same route.
    appRouter.go('/ratio/po4no3');
    await settle(tester);
    expect(find.byType(RatioScreen), findsOneWidget);
    await unmountApp(tester);
  });
}
