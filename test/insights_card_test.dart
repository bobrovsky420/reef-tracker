import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/setting_keys.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/insights_card.dart';
import 'package:reeftracker/widgets/reef_card.dart';

/// Widget tests for the dashboard Insights card (U28): the Pro teaser for a
/// non-entitled install, the insight rows + sheet for a Founder install, and
/// the hidden state when there is nothing to say. Same harness as
/// `pro_gate_test.dart` (in-memory drift DB, bounded fake-time settle).
void main() {
  /// Bounded settle — NOT pumpAndSettle (see router_test.dart).
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

  Future<AppDatabase> pumpCard(
    WidgetTester tester, {
    String? legacyFreeSince,
    bool withRedAlkalinity = true,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (legacyFreeSince != null) {
      await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
    }
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    if (withRedAlkalinity) {
      // Mixed preset alkalinity: amberLow 7 -> 5.0 dKH is red-low. A single
      // reading, so no trend — the pure out-of-range rule fires.
      await db.insertReadingGroup(
        tankId: tankId,
        takenAt: DateTime.now().subtract(const Duration(hours: 2)),
        values: [(paramKey: 'alkalinity', value: 5.0)],
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: InsightsCard()),
          ),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('a non-entitled install sees the teaser and gets the Pro '
      'dialog, never the insights', (tester) async {
    try {
      await pumpCard(tester); // no marker -> standard edition
      expect(find.text('Insights'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
      // The computed insight must not leak through the teaser.
      expect(find.textContaining('Alkalinity'), findsNothing);

      await tester.tap(find.text('Insights'));
      await settle(tester);
      expect(find.text('Pro feature'), findsOneWidget);
      expect(find.textContaining('part of ReefTracker Pro'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a Founder install sees the insight rows and the sheet '
      '(grandfathered)', (tester) async {
    try {
      await pumpCard(tester, legacyFreeSince: '0.28.0');
      expect(find.text('Insights'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
      expect(find.text('Alkalinity is below its target range'), findsOneWidget);

      // Tapping the card opens the full sheet (card row + sheet row).
      await tester.tap(find.text('Insights'));
      await settle(tester);
      expect(
        find.text('What your recent readings suggest to keep an eye on.'),
        findsOneWidget,
      );
      expect(
        find.text('Alkalinity is below its target range'),
        findsNWidgets(2),
      );
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('with nothing to say the card renders nothing at all', (
    tester,
  ) async {
    try {
      await pumpCard(
        tester,
        legacyFreeSince: '0.28.0',
        withRedAlkalinity: false,
      );
      expect(find.text('Insights'), findsNothing);
      expect(find.byType(ReefCard), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });
}
