import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_card.dart';
import 'package:reeftracker/widgets/trend_chart.dart';
import 'package:reeftracker/widgets/zone_chip.dart';

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

/// History-screen widget tests: the U31 Min / Avg / Max / test-count summary
/// (computed from the same list the chart plots, so readings outside the
/// range are excluded), and the REDESIGN #17 card layout — readings as one
/// `ReefSliverCard` of zone-badged rows with swipe-delete intact, and the
/// U14 share boundary capturing an opaque chart-card image.
void main() {
  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-stats-');
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

  testWidgets('history screen shows min/avg/max/count for the visible range', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    addTearDown(() => appRouter.go('/'));

    // Seed and park the router on the history route BEFORE pumping: the
    // dashboard's big-font tile rows overflow under the test-only Ahem font
    // (every glyph is em-wide), so the home route must never lay out with
    // reading values in this test.
    final tankId = await db.createTankWithPreset(
      name: 'A',
      type: SetupType.mixed,
    );
    final now = DateTime.now();
    for (final (value, takenAt) in [
      (7.4, now.subtract(const Duration(days: 2))),
      (8.2, now.subtract(const Duration(days: 1))),
      (9.3, now.subtract(const Duration(hours: 3))),
      // Outside the default 30d range — must not skew the stats.
      (5.0, now.subtract(const Duration(days: 60))),
    ]) {
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: value,
        takenAt: takenAt,
      );
    }
    appRouter.go('/history/alkalinity');

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

    final statsRow = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RangeStats',
    );
    expect(statsRow, findsOneWidget);
    Finder inStats(String text) =>
        find.descendant(of: statsRow, matching: find.text(text));
    // Labels render uppercased since the REDESIGN #17 restyle.
    expect(inStats('MIN'), findsOneWidget);
    expect(inStats('AVG'), findsOneWidget);
    expect(inStats('MAX'), findsOneWidget);
    expect(inStats('TESTS'), findsOneWidget);
    expect(inStats('7.4 dKH'), findsOneWidget);
    // Mean of the three in-range readings; the 60-day-old 5.0 is excluded
    // (it would drag the mean to 7.475 and the count to 4).
    expect(inStats('8.3 dKH'), findsOneWidget);
    expect(inStats('9.3 dKH'), findsOneWidget);
    expect(inStats('3'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('readings render as one card of rows (REDESIGN #17); the share '
      'boundary captures an opaque card image; swipe-delete offers Undo', (
    tester,
  ) async {
    // Phone-width viewport so the readings card is on screen below the chart
    // and a row overflow would fail here, not on device.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setTourSeen(true);
    addTearDown(() => appRouter.go('/'));

    final tankId = await db.createTankWithPreset(
      name: 'A',
      type: SetupType.mixed,
    );
    final now = DateTime.now();
    for (final (value, takenAt) in [
      (7.4, now.subtract(const Duration(days: 2))),
      (8.2, now.subtract(const Duration(days: 1))),
      (9.3, now.subtract(const Duration(hours: 3))),
    ]) {
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: value,
        takenAt: takenAt,
      );
    }
    appRouter.go('/history/alkalinity');

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

    // The readings list is one sliver card of zone-badged rows.
    expect(find.byType(ReefSliverCard), findsOneWidget);
    expect(find.byType(ZoneBadge), findsNWidgets(3));

    // U14: the share boundary now wraps backdrop + chart card — the captured
    // image must stay opaque (a transparent PNG is unreadable on forums).
    final chartContext = tester.element(find.byType(TrendChart));
    RenderRepaintBoundary? boundary;
    chartContext.visitAncestorElements((e) {
      final ro = e.renderObject;
      if (ro is RenderRepaintBoundary) {
        boundary = ro;
        return false;
      }
      return true;
    });
    expect(boundary, isNotNull);
    await tester.runAsync(() async {
      final image = await boundary!.toImage();
      final data = await image.toByteData();
      image.dispose();
      // Top-left pixel is the solid scaffoldBody backdrop around the card.
      expect(data!.getUint8(3), 255, reason: 'capture must be opaque');
      final argb = ReefTokens.light.scaffoldBody.toARGB32();
      expect(data.getUint8(0), (argb >> 16) & 0xFF);
      expect(data.getUint8(1), (argb >> 8) & 0xFF);
      expect(data.getUint8(2), argb & 0xFF);
    });

    // Swipe-delete conventions survive the row swap (Dismissible + Undo).
    // 8.2 is unique to its row (7.4/9.3 also appear as the Min/Max stats).
    await tester.drag(find.text('8.2 dKH'), const Offset(-500, 0));
    await settle(tester);
    expect(find.text('8.2 dKH'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await unmountApp(tester);
  });
}
