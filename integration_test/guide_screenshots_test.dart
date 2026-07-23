// Screenshot harness for the user guide (docs/guide/).
// Seeds the on-device DB with the showcase dataset (test/tool/showcase_data.dart),
// then drives the app to each screen documented in the guide and captures a
// screenshot. Unlike the store harness (screenshots_test.dart) this one visits
// many more secondary screens (forms, settings sub-pages, calculators).
//
// Run via:
//   flutter drive --driver=test_driver/guide_screenshot_driver.dart \
//     --target=integration_test/guide_screenshots_test.dart -d <device>
// Raw captures land in build/guide_shots/; resize into docs/img before
// publishing via scripts/resize_guide_shots.ps1.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/main.dart';

import '../test/tool/showcase_data.dart';

Future<void> _seedDatabase() async {
  final db = AppDatabase();
  await seedShowcaseData(db);
  await db.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture guide screenshots', (tester) async {
    // Render one frame before any platform-channel work: channel replies can
    // be queued until the first frame on Android (flutter#72872), and the
    // seeder's path_provider lookup otherwise risks awaiting forever.
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF000000)));
    await tester.pump();
    debugPrint('guide: seeding…');
    await _seedDatabase();
    debugPrint('guide: seeded, starting app');

    await tester.pumpWidget(const ProviderScope(child: ReefTrackerApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('guide: app settled, converting surface');
    await binding.convertFlutterSurfaceToImage();
    debugPrint('guide: surface converted');

    // Bounded settle: a stuck animation on one screen must not eat the
    // 10-minute default timeout and kill the whole run.
    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 600),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );
      } catch (_) {}
    }

    Future<void> shot(String name) async {
      await settle();
      debugPrint('guide: capturing $name');
      await binding.takeScreenshot(name);
      debugPrint('guide: captured $name');
    }

    Future<void> tapIcon(IconData icon) async {
      final f = find.byIcon(icon);
      expect(f, findsWidgets, reason: 'icon $icon not found');
      await tester.tap(f.first);
      await settle();
    }

    // Push a route, capture it, pop back. Failures skip the shot rather than
    // aborting the run.
    Future<void> routeShot(String path, String name) async {
      try {
        debugPrint('guide: routing to $path');
        unawaited(appRouter.push(path));
        await settle();
        await binding.takeScreenshot(name);
        debugPrint('guide: captured $name');
        appRouter.pop();
        await settle();
      } catch (e) {
        debugPrint('guide shot $name failed: $e');
      }
    }

    // --- Measurements tab ---------------------------------------------------
    await shot('dashboard');

    // Dark-theme variant of the dashboard, shown in the guide's Settings &
    // personalization section. Flipped through the app's own provider so the
    // watching settings stream rebuilds MaterialApp, then reverted.
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(ReefTrackerApp)),
      listen: false,
    ).read(settingsProvider);
    await settings.setThemeMode(AppThemeMode.dark);
    await shot('dashboard-dark');
    await settings.setThemeMode(AppThemeMode.system);
    await settle();

    await tapIcon(Icons.stacked_line_chart); // compare view
    await shot('compare');
    await tapIcon(Icons.grid_view); // back to the grid

    await routeShot('/add-reading', 'add-reading');
    await routeShot('/history/alkalinity', 'history');
    await routeShot('/ratio/po4no3', 'ratio');
    await routeShot('/micro', 'micro');
    await routeShot('/micro/add', 'micro-add');
    await routeShot('/tanks', 'tanks');
    await routeShot('/parameters', 'parameters');

    // --- Actions tab --------------------------------------------------------
    await tapIcon(Icons.fact_check_outlined);
    await shot('actions');
    await routeShot('/schedule', 'schedule');
    await routeShot('/ro', 'ro');

    // --- Dosing tab ---------------------------------------------------------
    await tapIcon(Icons.science_outlined);
    await shot('dosing');
    await routeShot('/dosing/history', 'dosing-history');
    await routeShot('/dosing/calculator', 'dose-calculator');
    await routeShot('/dosing/calculator?mode=correction', 'dose-correction');
    await routeShot('/calculator/salinity', 'salinity');

    // --- Settings tab -------------------------------------------------------
    await tapIcon(Icons.settings_outlined);
    await shot('settings');
    await routeShot('/settings/backups', 'backups');
    await routeShot('/settings/reminders', 'reminders');
    await routeShot('/settings/import', 'import-sources');

    // Leave the app on the Measurements tab so the emulator is demo-ready.
    await tapIcon(Icons.speed_outlined);
  });
}
