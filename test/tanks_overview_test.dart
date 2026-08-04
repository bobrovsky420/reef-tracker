import 'dart:async';
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

/// The aquarium list's per-tank overview (U7): every row carries its tank's
/// health ring and a freshness line, and tapping a row activates that tank and
/// hands the user back to where the screen was opened from.
void main() {
  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-tanks-');
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

  /// Seeds three tanks — freshly tested, long stale, never tested — and pumps
  /// the app with `/tanks` pushed on top of the dashboard, so the tap test has
  /// something to pop back to.
  Future<AppDatabase> pumpTanks(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    addTearDown(() => appRouter.go('/'));

    final fresh = await db.createTankWithPreset(
      name: 'Fresh tank',
      type: SetupType.mixed,
    );
    final stale = await db.createTankWithPreset(
      name: 'Stale tank',
      type: SetupType.mixed,
    );
    await db.createTankWithPreset(name: 'Empty tank', type: SetupType.mixed);
    await db.setActiveTank(fresh);

    final now = DateTime.now();
    // Mid-green alkalinity, so the ring scores rather than reading "no data".
    await db.insertReading(
      tankId: fresh,
      paramKey: 'alkalinity',
      value: 8.3,
      takenAt: now,
    );
    await db.insertReading(
      tankId: stale,
      paramKey: 'alkalinity',
      value: 8.3,
      takenAt: now.subtract(const Duration(days: 45)),
    );

    appRouter.go('/');
    // The pushed route's future completes when the screen pops — which is
    // exactly what the tap test asserts, so it is deliberately not awaited.
    unawaited(appRouter.push('/tanks'));

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

  testWidgets('each row states when the tank was last tested (U7)', (
    tester,
  ) async {
    await pumpTanks(tester);

    // Fresh: relative wording. Stale: the elapsed span, past the 30-day
    // freshness horizon. Never tested: no reading to age at all.
    expect(find.text('Last tested just now'), findsOneWidget);
    expect(find.text('Not tested in 45 d'), findsOneWidget);
    expect(find.text('Not tested yet'), findsOneWidget);

    // The freshly tested tank is scored; a tank whose only reading is stale
    // and one that was never tested both show the empty ring.
    expect(find.text('—'), findsNWidgets(2));

    await unmountApp(tester);
  });

  testWidgets('tapping a row activates that tank and pops back', (
    tester,
  ) async {
    final db = await pumpTanks(tester);
    final tanks = await db.getTanks();
    final stale = tanks.firstWhere((t) => t.name == 'Stale tank');
    expect(await db.getActiveTankId(), isNot(stale.id));

    await tester.tap(find.text('Stale tank'));
    await settle(tester);

    expect(await db.getActiveTankId(), stale.id);
    // The screen is gone — the tap handed the user back to the dashboard.
    // (The activated tank's *name* survives: it is the app-bar selector's
    // title there.)
    expect(find.text('Aquariums'), findsNothing);
    expect(find.text('Not tested yet'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the ring hides when the health score is switched off', (
    tester,
  ) async {
    final db = await pumpTanks(tester);
    expect(find.byIcon(Icons.waves), findsNothing);

    await AppSettings(db).setHealthDisplay(HealthDisplay.off);
    await settle(tester);

    // One waves glyph per row instead of a ring; the freshness line stays.
    expect(find.byIcon(Icons.waves), findsNWidgets(3));
    expect(find.text('Not tested in 45 d'), findsOneWidget);

    await unmountApp(tester);
  });
}
