import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/features/settings/settings_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the Edition row in Settings (U19 phase 0): the row shows
/// "Founder's Edition" when the early-adopter marker is present, "Standard"
/// when it is absent, and tapping opens the explanation dialog.
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

  /// Pumps the Settings screen over an in-memory database. The version tile's
  /// [appVersionProvider] is stubbed: PackageInfo has no platform channel
  /// under `flutter test`.
  Future<AppDatabase> pumpSettings(
    WidgetTester tester, {
    String? legacyFreeSince,
  }) async {
    // Tall surface so the About section (bottom of the list) is on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (legacyFreeSince != null) {
      await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('shows Standard when the marker is absent', (tester) async {
    try {
      await pumpSettings(tester);
      expect(find.text('Edition'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text("Founder's Edition"), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('shows Founder\'s Edition when the marker is present '
      'and explains it on tap', (tester) async {
    try {
      await pumpSettings(tester, legacyFreeSince: '0.26.0');
      expect(find.text("Founder's Edition"), findsOneWidget);
      expect(find.text('Standard'), findsNothing);

      await tester.tap(find.text("Founder's Edition"));
      await settle(tester);
      // Dialog: the edition name repeats as the title, plus the promise body.
      expect(find.text("Founder's Edition"), findsNWidgets(2));
      expect(find.textContaining('stays free for you'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.textContaining('stays free for you'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('standard edition dialog explains the edition', (tester) async {
    try {
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await settle(tester);
      expect(find.textContaining('standard edition'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });
}
