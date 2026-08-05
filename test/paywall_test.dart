import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/entitlement.dart';
import 'package:reeftracker/data/purchases.dart';
import 'package:reeftracker/domain/pro_features.dart';
import 'package:reeftracker/features/paywall/paywall_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so
/// the entitlement sidecar has somewhere to live (see router_test.dart).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// The paywall (U19). Its states are all reachable in tests through the fake
/// store; in a shipped build only the first one is, because the only store
/// compiled in resolves nothing.
void main() {
  late Directory docsDir;
  late ProEntitlementStore entitlement;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-paywall-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    entitlement = ProEntitlementStore(directory: () async => docsDir);
  });
  tearDown(() async {
    entitlement.dispose();
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  /// Bounded fake-time settle — NOT pumpAndSettle (see router_test.dart).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpPaywall(
    WidgetTester tester, {
    required PurchaseStore store,
    ProFeature? feature,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PaywallScreen(feature: feature),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
  }

  testWidgets('NO PRODUCT RESOLVED means no buy button — the state every '
      'shipped build is in', (tester) async {
    final store = FakePurchaseStore(products: const []);
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store);
      expect(find.textContaining('Unlock Pro'), findsNothing);
      // Restore stays visible regardless: Apple requires a restore control on
      // any screen that sells a non-consumable.
      expect(find.text('Restore purchases'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('an unavailable store says so and offers nothing to buy', (
    tester,
  ) async {
    final store = FakePurchaseStore(available: false);
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store);
      expect(
        find.textContaining("aren't available on this device"),
        findsOneWidget,
      );
      expect(find.textContaining('Unlock Pro'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a resolved product shows the STORE price, never one the app '
      'made up', (tester) async {
    final store = FakePurchaseStore(
      products: const [
        ProProduct(
          id: kProUnlockProductId,
          title: 'ReefTracker Pro',
          price: '129 Kč',
        ),
      ],
    );
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store, feature: ProFeature.icpImport);
      expect(find.text('Unlock Pro — 129 Kč'), findsOneWidget);
      // The screen also says what the user was reaching for.
      expect(find.textContaining('part of ReefTracker Pro'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('buying grants the unlock, acknowledges it, and offers the way '
      'back to the gated action', (tester) async {
    final store = FakePurchaseStore();
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store);
      await tester.tap(find.textContaining('Unlock Pro'));
      await settle(tester);

      expect(find.text('Pro unlocked. Thank you!'), findsOneWidget);
      expect(await entitlement.read(), isTrue);
      expect(
        store.completed,
        hasLength(1),
        reason: 'unacknowledged purchases are auto-refunded and revoked',
      );
      // The buy button is replaced by the return path, not left tappable.
      expect(find.textContaining('Unlock Pro'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('restoring nothing says so plainly', (tester) async {
    final store = FakePurchaseStore(products: const []);
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store);
      await tester.tap(find.text('Restore purchases'));
      await settle(tester);
      expect(
        find.textContaining('No previous purchase was found'),
        findsOneWidget,
      );
      expect(await entitlement.read(), isFalse);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('restoring an owned purchase unlocks Pro', (tester) async {
    final store = FakePurchaseStore(
      products: const [],
      owned: const [
        PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.restored,
          pendingComplete: true,
        ),
      ],
    );
    addTearDown(store.dispose);
    try {
      await pumpPaywall(tester, store: store);
      await tester.tap(find.text('Restore purchases'));
      await settle(tester);
      expect(find.text('Your Pro unlock has been restored.'), findsOneWidget);
      expect(await entitlement.read(), isTrue);
      expect(store.completed, hasLength(1));
    } finally {
      await unmountApp(tester);
    }
  });
}
