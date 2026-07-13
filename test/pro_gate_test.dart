import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/micro/micro_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the first Pro-gated surface (U19): the ICP import action
/// on the Microelements screen. Founder's Edition installs (grandfathered)
/// pass straight through to the import flow; a non-entitled install gets the
/// Pro-feature dialog instead. The locked branch is unreachable in production
/// until a Pro build ships (every install seeds the founder marker) — these
/// tests are what exercise it.
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

  Future<AppDatabase> pumpMicro(
    WidgetTester tester, {
    String? legacyFreeSince,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (legacyFreeSince != null) {
      await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
    }
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MicroScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('a non-entitled install gets the Pro dialog, not the '
      'import flow', (tester) async {
    try {
      await pumpMicro(tester); // no marker -> standard edition
      await tester.tap(find.byIcon(Icons.upload_file_outlined));
      await settle(tester);

      expect(find.text('Pro feature'), findsOneWidget);
      expect(
        find.textContaining('part of ReefTracker Pro'),
        findsOneWidget,
      );
      // The format-choice sheet must NOT have opened. ("Fauna Marin ICP"
      // itself can't discriminate — the screen's view chips carry it too.)
      expect(find.text('Choose the export format of the file.'), findsNothing);

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a Founder install goes straight to the import flow '
      '(grandfathered)', (tester) async {
    try {
      await pumpMicro(tester, legacyFreeSince: '0.26.0');
      await tester.tap(find.byIcon(Icons.upload_file_outlined));
      await settle(tester);

      // The format-choice sheet opened; no Pro dialog anywhere.
      expect(
        find.text('Choose the export format of the file.'),
        findsOneWidget,
      );
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });
}
