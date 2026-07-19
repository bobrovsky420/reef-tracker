import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/features/settings/settings_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_card.dart';
import 'package:reeftracker/widgets/reef_segmented.dart';

/// Widget tests for the restyled Settings screen (REDESIGN #14/#15): the
/// grouped IA renders per platform dialect (M3 full-width rows vs Cupertino
/// inset group cards), the shared segmented control writes the setting, and
/// the full-row tap still toggles switch rows (the old `SwitchListTile`
/// behavior).
void main() {
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

  /// Pumps Settings under the real app theme built for [platform] — the
  /// dialect resolves from `ThemeData.platform`, so no
  /// `debugDefaultTargetPlatformOverride` is needed.
  Future<AppDatabase> pumpSettings(
    WidgetTester tester, {
    required TargetPlatform platform,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
        ],
        child: MaterialApp(
          theme: buildReefTheme(Brightness.light, platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('M3 dialect: uppercase section labels, no inset group cards', (
    tester,
  ) async {
    try {
      await pumpSettings(tester, platform: TargetPlatform.android);
      expect(find.text('UNITS'), findsOneWidget);
      expect(find.text('TRENDS'), findsOneWidget);
      expect(find.byType(ReefCard), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('Cupertino dialect: rows sit in inset group cards', (
    tester,
  ) async {
    try {
      await pumpSettings(tester, platform: TargetPlatform.iOS);
      expect(find.text('UNITS'), findsOneWidget);
      expect(find.byType(ReefCard), findsWidgets);
    } finally {
      await unmountApp(tester);
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('segmented control writes the unit setting ($platform)', (
      tester,
    ) async {
      try {
        final db = await pumpSettings(tester, platform: platform);
        expect(find.byType(ReefSegmented<TempUnit>), findsOneWidget);
        await tester.tap(find.text('°F'));
        await settle(tester);
        expect(await db.getSetting('temp_unit'), 'fahrenheit');
      } finally {
        await unmountApp(tester);
      }
    });
  }

  testWidgets('theme segmented row writes the theme-mode setting (#16)', (
    tester,
  ) async {
    try {
      final db = await pumpSettings(tester, platform: TargetPlatform.android);
      expect(find.byType(ReefSegmented<AppThemeMode>), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(await db.getSetting('theme_mode'), 'dark');
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('tapping a switch row toggles it (full-row tap parity)', (
    tester,
  ) async {
    try {
      final db = await pumpSettings(tester, platform: TargetPlatform.android);
      // Trend sub-rows are visible while trends are on (the default)…
      expect(find.text('Readings used'), findsOneWidget);
      await tester.tap(find.text('Show trends'));
      await settle(tester);
      // …and collapse once the row tap turns them off.
      expect(await db.getSetting('trend_enabled'), 'false');
      expect(find.text('Readings used'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });
}
