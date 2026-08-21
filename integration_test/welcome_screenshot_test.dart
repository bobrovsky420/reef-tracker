// Focused screenshot target for the first-run welcome screen documented in
// docs/guide/. It uses the guide screenshot driver, so the raw capture lands
// at build/guide_shots/welcome.png alongside the main guide harness output.
//
// Run via:
//   flutter drive --driver=test_driver/guide_screenshot_driver.dart \
//     --target=integration_test/welcome_screenshot_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture first-run welcome screenshot', (tester) async {
    // Platform-channel replies can wait for the first Android frame, so render
    // once before opening the on-device database (flutter#72872).
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF000000)));
    await tester.pump();

    // Reset before mounting the app so providers never observe an in-flight
    // database wipe. Tanks control the welcome state; settings are cleared so
    // the experimental preference and every other device choice use defaults.
    final db = AppDatabase();
    await db.transaction(() async {
      await db.delete(db.tanks).go();
      await db.delete(db.settings).go();
    });
    await db.close();

    await tester.pumpWidget(const ProviderScope(child: ReefTrackerApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Welcome to ReefTracker'), findsOneWidget);
    expect(find.text('Experimental features'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);

    await binding.takeScreenshot('welcome');
  });
}
