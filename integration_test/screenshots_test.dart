// Screenshot harness for store listing assets.
// Seeds the on-device DB with the showcase dataset (test/tool/showcase_data.dart),
// then drives the app to each screen and captures a screenshot.
//
// Run via:
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart \
//     -d <device> --dart-define=SHOTS=phone   (or tablet)
// with SHOT_DIR=<phone|tablet7|tablet10|iphone> in the host env selecting the
// output folder under store_assets/screenshots/.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/main.dart';

import '../test/tool/showcase_data.dart';

Future<void> _seedDatabase() async {
  final db = AppDatabase();
  await seedShowcaseData(db);
  await db.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const target = String.fromEnvironment('SHOTS', defaultValue: 'phone');

  testWidgets('capture store screenshots', (tester) async {
    await _seedDatabase();

    await tester.pumpWidget(const ProviderScope(child: ReefTrackerApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> tapIcon(IconData icon) async {
      final f = find.byIcon(icon);
      expect(f, findsWidgets, reason: 'icon $icon not found');
      await tester.tap(f.first);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }

    // 1. Measurements (default tab, tile grid)
    await shot('01-measurements');

    // 2. Graphs (toggle the compare view on the Measurements tab)
    await tapIcon(Icons.stacked_line_chart);
    await shot('02-graphs');
    await tapIcon(Icons.grid_view); // back to grid

    if (target == 'phone') {
      // 3. Actions tab
      await tapIcon(Icons.fact_check_outlined);
      await shot('03-actions');

      // 4. Dosing tab
      await tapIcon(Icons.science_outlined);
      await shot('04-dosing');

      // 5. Settings (fourth bottom-nav tab since the U33 redesign)
      await tapIcon(Icons.settings_outlined);
      await shot('05-settings');

      // back to Measurements so the home state is clean
      await tapIcon(Icons.speed_outlined);

      // 6. Salinity converter
      unawaited(appRouter.push('/calculator/salinity'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await shot('06-salinity');
      appRouter.pop();
      await tester.pumpAndSettle();

      // 7. Dose calculator
      unawaited(appRouter.push('/dosing/calculator'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await shot('07-dose-calculator');
      appRouter.pop();
      await tester.pumpAndSettle();
    }
  });
}
