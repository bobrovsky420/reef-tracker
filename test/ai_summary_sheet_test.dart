import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/setting_keys.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/ai_summary/ai_summary_sheet.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the "Ask your AI" pre-share sheet (U27): preview renders
/// the document, Copy puts it on the clipboard (+ SnackBar), and the
/// no-readings empty state. Same harness as `insights_card_test.dart`.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<AppDatabase> pumpSheet(
    WidgetTester tester, {
    bool withReading = true,
    String? legacyFreeSince,
    double readingValue = 8.0,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (legacyFreeSince != null) {
      await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
    }
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
      volumeLiters: 200,
    );
    if (withReading) {
      await db.insertReading(
        tankId: tankId,
        paramKey: 'alkalinity',
        value: readingValue,
        takenAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AiSummarySheet()),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('renders the preview and copies it to the clipboard', (
    tester,
  ) async {
    // Capture Clipboard.setData platform calls.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    try {
      await pumpSheet(tester);
      expect(find.text('Ask your AI'), findsOneWidget);
      // The preview contains the rendered document.
      expect(
        find.textContaining('Reef — saltwater aquarium summary'),
        findsOneWidget,
      );
      expect(find.textContaining('Alkalinity (alkalinity)'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await settle(tester);
      expect(copied, hasLength(1));
      expect(copied.single, contains('# Reef — saltwater aquarium summary'));
      expect(find.text('Copied — paste it into your AI chat.'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('switching the window chip re-renders the preview', (
    tester,
  ) async {
    try {
      await pumpSheet(tester);
      expect(find.textContaining('the last 8 weeks'), findsOneWidget);

      await tester.tap(find.text('4 weeks'));
      await settle(tester);
      expect(find.textContaining('the last 4 weeks'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a tank with no readings shows the empty state, no buttons', (
    tester,
  ) async {
    try {
      await pumpSheet(tester, withReading: false);
      expect(
        find.text('No readings yet — nothing to summarize.'),
        findsOneWidget,
      );
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Share'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  // The exported document is presentation: the Pro-gated computed layers the
  // in-app teasers hide (U26 stability, U28 insights) must not leak into a
  // Standard-tier export. A red alkalinity value guarantees an insight.
  testWidgets('a Standard export omits the Pro-gated observations', (
    tester,
  ) async {
    try {
      await pumpSheet(tester, readingValue: 5.0); // no marker -> standard
      expect(find.textContaining('Health score:'), findsOneWidget);
      expect(
        find.textContaining("The app's rule-based observations:"),
        findsNothing,
      );
      expect(find.textContaining('Stability score:'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a Founder export includes the observations (grandfathered)', (
    tester,
  ) async {
    try {
      await pumpSheet(tester, readingValue: 5.0, legacyFreeSince: '0.29.0');
      expect(
        find.textContaining("The app's rule-based observations:"),
        findsOneWidget,
      );
      expect(
        find.textContaining('Alkalinity is below its target range'),
        findsOneWidget,
      );
    } finally {
      await unmountApp(tester);
    }
  });
}
