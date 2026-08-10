import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/entitlement.dart';
import 'package:reeftracker/data/purchases.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/pro_features.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/dosing/dose_calculator_screen.dart';
import 'package:reeftracker/features/micro/micro_screen.dart';
import 'package:reeftracker/features/paywall/paywall_screen.dart';
import 'package:reeftracker/features/tanks/tanks_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/pro_feature_dialog.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so
/// the full app shell can build under `flutter test` (see router_test.dart).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// Widget tests for the Pro-gated surfaces (U19): the ICP import action on
/// the Microelements screen and the dose calculator icon on the Dosing tab.
/// Founder's Edition installs (grandfathered) pass straight through; a
/// non-entitled install gets the Pro-feature dialog instead — and, because no
/// product resolves in a build with no billing library, the *dialog* is what
/// it gets rather than the paywall. The locked branch is unreachable in
/// production until the tier is activated (every install seeds the founder
/// marker, and every registry entry is grandfathered) — these tests are what
/// exercise it.
void main() {
  /// Bounded fake-time settle — NOT pumpAndSettle (see router_test.dart).
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

  Future<AppDatabase> pumpMicro(
    WidgetTester tester, {
    String? legacyFreeSince,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (legacyFreeSince != null) {
      await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
    }
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MicroScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('a non-entitled install gets the Pro dialog, not the '
      'import flow', (tester) async {
    try {
      await pumpMicro(tester); // no marker -> standard edition
      await tester.tap(find.byIcon(Icons.upload_file_outlined));
      await settle(tester);

      expect(find.text('Pro feature'), findsOneWidget);
      expect(find.textContaining('part of ReefTracker Pro'), findsOneWidget);
      // The format-choice sheet must NOT have opened. ("Fauna Marin ICP"
      // itself can't discriminate — the screen's view chips carry it too.)
      expect(find.text('Choose the export format of the file.'), findsNothing);

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a Founder install goes straight to the import flow '
      '(grandfathered)', (tester) async {
    try {
      await pumpMicro(tester, legacyFreeSince: '0.26.0');
      await tester.tap(find.byIcon(Icons.upload_file_outlined));
      await settle(tester);

      // The format-choice sheet opened; no Pro dialog anywhere.
      expect(
        find.text('Choose the export format of the file.'),
        findsOneWidget,
      );
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  group('dose calculator gate', () {
    late Directory docsDir;
    setUp(() async {
      docsDir = await Directory.systemTemp.createTemp('reeftracker-progate-');
      PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    });
    tearDown(() async {
      if (await docsDir.exists()) await docsDir.delete(recursive: true);
    });

    /// Boots the real app shell (the gated icon lives in HomeShell's app bar)
    /// and lands on the Dosing tab with the calculator icon visible.
    Future<AppDatabase> pumpDosingTab(
      WidgetTester tester, {
      String? legacyFreeSince,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      if (legacyFreeSince != null) {
        await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
      }
      // Not a tour test — left unseen, the tour's delayed showcase overlays
      // land after teardown and fail the test (see router_test.dart).
      await AppSettings(db).setTourSeen(true);
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
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
      await tester.tap(find.text('Dosing'));
      await settle(tester);
      return db;
    }

    testWidgets('a non-entitled install gets the Pro dialog, not the '
        'calculator', (tester) async {
      try {
        await pumpDosingTab(tester); // no marker -> standard edition
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await settle(tester);

        expect(find.text('Pro feature'), findsOneWidget);
        expect(find.textContaining('part of ReefTracker Pro'), findsOneWidget);
        expect(find.byType(DoseCalculatorScreen), findsNothing);

        await tester.tap(find.text('OK'));
        await settle(tester);
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('a Founder install opens the calculator (grandfathered)', (
      tester,
    ) async {
      try {
        await pumpDosingTab(tester, legacyFreeSince: '0.26.0');
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await settle(tester);

        expect(find.byType(DoseCalculatorScreen), findsOneWidget);
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });
  });

  group('tank cap gate (U21)', () {
    /// Seeds [tankCount] tanks and shows the tanks list inside a minimal
    /// router (the FAB navigates via `context.push`, so a bare MaterialApp
    /// can't host it).
    Future<AppDatabase> pumpTanksList(
      WidgetTester tester, {
      String? legacyFreeSince,
      required int tankCount,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      if (legacyFreeSince != null) {
        await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
      }
      for (var i = 1; i <= tankCount; i++) {
        await db.createTankWithPreset(name: 'Tank $i', type: SetupType.mixed);
      }
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TanksScreen()),
          GoRoute(
            path: '/tanks/new',
            builder: (_, _) => const TankEditScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      return db;
    }

    testWidgets('a non-entitled install at the cap gets the Pro dialog, '
        'not the new-tank form', (tester) async {
      try {
        await pumpTanksList(tester, tankCount: 2); // standard edition
        await tester.tap(find.text('Add aquarium'));
        await settle(tester);

        expect(find.text('Pro feature'), findsOneWidget);
        expect(find.textContaining('part of ReefTracker Pro'), findsOneWidget);
        expect(find.byType(TankEditScreen), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('a non-entitled install below the cap reaches the '
        'new-tank form', (tester) async {
      try {
        await pumpTanksList(tester, tankCount: 1); // standard edition
        await tester.tap(find.text('Add aquarium'));
        await settle(tester);

        expect(find.byType(TankEditScreen), findsOneWidget);
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('a Founder install at the cap adds tanks freely '
        '(grandfathered)', (tester) async {
      try {
        await pumpTanksList(tester, tankCount: 2, legacyFreeSince: '0.26.0');
        await tester.tap(find.text('Add aquarium'));
        await settle(tester);

        expect(find.byType(TankEditScreen), findsOneWidget);
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('the save-time guard blocks creation past the cap even when '
        'the form is reached directly (deep link)', (tester) async {
      try {
        // The form is taller than the default 600px test surface and the
        // create button sits at its bottom — use a phone-like tall viewport
        // so the button is on-screen without scrolling.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
        await db.createTankWithPreset(name: 'QT', type: SetupType.mixed);
        // Straight to the form, bypassing the FAB gate — as a deep link or a
        // restored route would.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TankEditScreen(),
            ),
          ),
        );
        await settle(tester);
        // Nothing on this screen watches the settings map, so warm it up the
        // way main.dart's pre-warm does. Without it the entitlement is still
        // "loading" and the gate fails closed, so the block below would pass
        // for the wrong reason — this test is about the tank CAP, not the
        // loading default.
        // listen + settle, NOT `await ….future`: awaiting a drift stream
        // inside the test's fake-async zone hangs (see router_test.dart).
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TankEditScreen)),
        );
        container.listen(settingsMapProvider, (_, _) {});
        await settle(tester);

        await tester.enterText(find.byType(TextFormField).first, 'Frag tank');
        await tester.tap(find.text('Create aquarium'));
        await settle(tester);

        expect(find.text('Pro feature'), findsOneWidget);
        expect((await db.getTanks()).length, 2, reason: 'no tank created');
      } finally {
        await unmountApp(tester);
      }
    });
  });

  /// `runProGated`'s **activation-day** half: the branch that only exists once
  /// a store product resolves, so no shipped build has ever taken it (the only
  /// `PurchaseStore` compiled in resolves nothing, which is why every test
  /// above gets the informational dialog instead of the paywall). Overriding
  /// `purchaseStoreProvider` with a resolving fake is what opens it.
  ///
  /// The contract is one sentence with three ways to get it wrong: the gated
  /// action resumes **only** when the user comes back from the paywall having
  /// unlocked Pro. A paywall dismissed with no result must read as `false` —
  /// `showProFeatureDialog`'s `?? false` — and a purchase the store refused
  /// must not resume anything either.
  group('runProGated resumes after a paywall purchase (U19)', () {
    // In-memory, not the file-backed store: real dart:io futures never
    // complete inside `testWidgets`' fake-async zone (see paywall_test.dart).
    late MemoryProEntitlementStore entitlement;
    setUp(() => entitlement = MemoryProEntitlementStore());
    tearDown(() => entitlement.dispose());

    /// A single button whose `onPressed` is `runProGated`, plus the real
    /// paywall on `/paywall` — the smallest thing that exercises the whole
    /// push/return round trip rather than a stubbed route's return value.
    /// Every run the action makes is appended to [ran].
    Future<void> pumpGatedAction(
      WidgetTester tester, {
      required PurchaseStore store,
      required List<String> ran,
      String? legacyFreeSince,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      if (legacyFreeSince != null) {
        await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
      }
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => runProGated(
                      context,
                      ref,
                      ProFeature.icpImport,
                      () => ran.add('action'),
                    ),
                    child: const Text('Gated action'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/paywall',
            builder: (_, state) =>
                PaywallScreen(feature: state.extra as ProFeature?),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            purchaseStoreProvider.overrideWithValue(store),
            proEntitlementStoreProvider.overrideWithValue(entitlement),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      // Nothing on this bare screen watches the settings map, so warm it the
      // way main.dart's pre-warm does — otherwise the entitlement is still
      // "loading" and every case below would pass on the fail-closed default
      // instead of on the edition it means to test. listen + settle, NOT
      // `await ….future` (see router_test.dart).
      final container = ProviderScope.containerOf(
        tester.element(find.text('Gated action')),
      );
      container.listen(settingsMapProvider, (_, _) {});
      await settle(tester);
    }

    testWidgets('buying on the paywall resumes the action the user was '
        'reaching for', (tester) async {
      final ran = <String>[];
      final store = FakePurchaseStore();
      addTearDown(store.dispose);
      try {
        await pumpGatedAction(tester, store: store, ran: ran);

        await tester.tap(find.text('Gated action'));
        await settle(tester);
        // A resolving product means the PAYWALL, not the informational dialog.
        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.text('Pro feature'), findsNothing);
        expect(ran, isEmpty, reason: 'nothing runs while the gate is shut');

        await tester.tap(find.textContaining('Unlock Pro'));
        await settle(tester);
        expect(find.text('Pro unlocked. Thank you!'), findsOneWidget);
        expect(
          ran,
          isEmpty,
          reason: 'the action waits for the user to come back',
        );

        await tester.tap(find.text('Continue'));
        await settle(tester);
        expect(find.byType(PaywallScreen), findsNothing);
        expect(ran, ['action'], reason: 'resumed exactly once');
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('backing out of the paywall with no result does NOT run the '
        'action (the `?? false`)', (tester) async {
      final ran = <String>[];
      final store = FakePurchaseStore();
      addTearDown(store.dispose);
      try {
        await pumpGatedAction(tester, store: store, ran: ran);

        await tester.tap(find.text('Gated action'));
        await settle(tester);
        expect(find.byType(PaywallScreen), findsOneWidget);

        // The system/AppBar back button pops with no value, so the awaited
        // push completes as null. Reading that as "go ahead" would hand Pro
        // to anyone who opened the paywall and changed their mind.
        await tester.pageBack();
        await settle(tester);

        expect(find.byType(PaywallScreen), findsNothing);
        expect(ran, isEmpty);
        expect(await entitlement.read(), isFalse);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('a purchase the store refuses leaves the action unrun', (
      tester,
    ) async {
      final ran = <String>[];
      final store = FakePurchaseStore()..buyThrows = true;
      addTearDown(store.dispose);
      try {
        await pumpGatedAction(tester, store: store, ran: ran);

        await tester.tap(find.text('Gated action'));
        await settle(tester);
        await tester.tap(find.textContaining('Unlock Pro'));
        await settle(tester);

        expect(
          find.text('The store could not complete that. Please try again.'),
          findsOneWidget,
        );
        // No return path is offered, because nothing was unlocked.
        expect(find.text('Continue'), findsNothing);
        expect(find.textContaining('Unlock Pro'), findsOneWidget);
        expect(await entitlement.read(), isFalse);

        await tester.pageBack();
        await settle(tester);
        expect(ran, isEmpty);

        // A refused buy leaves `ProEntitlementService.buy`'s 5-minute
        // await-the-event timeout armed; drain it so the binding's pending
        // timer check doesn't blame this test for the service's own guard.
        await tester.pump(const Duration(minutes: 6));
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('an entitled install runs the action immediately, with no '
        'paywall at all', (tester) async {
      final ran = <String>[];
      final store = FakePurchaseStore();
      addTearDown(store.dispose);
      try {
        await pumpGatedAction(
          tester,
          store: store,
          ran: ran,
          legacyFreeSince: '0.26.0',
        );

        await tester.tap(find.text('Gated action'));
        await settle(tester);

        expect(ran, ['action']);
        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });
  });
}
