import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so
/// screens that touch the backup directory can build under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// Manage Parameters untrack tests (U11): swipe-to-untrack with an Undo that
/// restores the captured row verbatim, the derived free-ammonia row vanishing
/// with ammonia, and the edit screen's accessible non-swipe counterpart (#45).
void main() {
  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-untrack-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  /// Pumps a bounded amount of fake time in small steps — NOT `pumpAndSettle`,
  /// which never settles while a `CircularProgressIndicator` animates (see
  /// router_test.dart).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app inside the test body to flush drift's pending stream
  /// timers before the binding's leak check runs (see router_test.dart).
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Seeds a mixed tank, parks the router on `/parameters` and pumps the app.
  /// A tall viewport so every manage row (params + ratios + free ammonia) is
  /// laid out — sliver rows off-screen are never built, so a swipe target
  /// below the fold would not be findable.
  Future<AppDatabase> pumpManage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    addTearDown(() => appRouter.go('/'));
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    appRouter.go('/parameters');

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

  testWidgets('swipe untracks a parameter; Undo restores the row verbatim '
      '(U11)', (tester) async {
    final db = await pumpManage(tester);
    final tankId = (await db.select(db.tanks).get()).single.id;
    // Per-row state only a verbatim restore preserves (an addTrackedParameter
    // re-add would reset cadence, order and unit).
    final alk = (await db.getTrackedParameters(
      tankId,
    )).firstWhere((p) => p.paramKey == 'alkalinity');
    await db.setTestCadence(alk.id, 7);
    final captured = (await db.getTrackedParameters(
      tankId,
    )).firstWhere((p) => p.paramKey == 'alkalinity');
    await settle(tester);

    expect(find.text('Alkalinity'), findsOneWidget);
    await tester.drag(find.text('Alkalinity'), const Offset(-500, 0));
    await settle(tester);

    expect(find.text('Alkalinity'), findsNothing);
    expect(
      find.text('Parameter untracked – readings are kept'),
      findsOneWidget,
    );
    expect(
      (await db.getTrackedParameters(tankId)).map((p) => p.paramKey),
      isNot(contains('alkalinity')),
    );

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Alkalinity'), findsOneWidget);
    final restored = (await db.getTrackedParameters(
      tankId,
    )).firstWhere((p) => p.paramKey == 'alkalinity');
    expect(restored, captured);

    await unmountApp(tester);
  });

  testWidgets('untracking ammonia removes the derived free-ammonia row too', (
    tester,
  ) async {
    await pumpManage(tester);
    expect(find.text('Free ammonia (NH₃)'), findsOneWidget);

    await tester.drag(find.text('Ammonia (NH₃/₄)'), const Offset(-500, 0));
    await settle(tester);

    expect(find.text('Ammonia (NH₃/₄)'), findsNothing);
    expect(find.text('Free ammonia (NH₃)'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the edit screen offers Untrack as the accessible non-swipe '
      'path (#45) and pops back to the list', (tester) async {
    final db = await pumpManage(tester);
    final tankId = (await db.select(db.tanks).get()).single.id;
    final alk = (await db.getTrackedParameters(
      tankId,
    )).firstWhere((p) => p.paramKey == 'alkalinity');

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('p${alk.id}')),
        matching: find.byTooltip('Edit zones'),
      ),
    );
    await settle(tester);

    await tester.tap(find.byTooltip('Untrack'));
    await settle(tester);

    // Back on the manage list, row gone, Undo offered.
    expect(find.text('Add parameter'), findsOneWidget);
    expect(find.text('Alkalinity'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    expect(
      (await db.getTrackedParameters(tankId)).map((p) => p.paramKey),
      isNot(contains('alkalinity')),
    );

    await unmountApp(tester);
  });
}
