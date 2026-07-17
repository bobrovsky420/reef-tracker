import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/dashboard/dashboard_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Structural widget tests for the grouped dashboard (REDESIGN #6): section
/// headers render for populated groups, and a group with every parameter
/// disabled disappears entirely — header included (the user's explicit
/// requirement). Same in-memory-drift + bounded-settle harness as
/// insights_card_test.dart. Sort/section-mapping logic is unit-tested in
/// dashboard_sections_test.dart; this only asserts the sliver wiring.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Unmounts the app so drift's pending stream timers are flushed before the
  // binding's timer check (see router_test.dart / widget-test-pitfalls).
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<AppDatabase> pumpDashboard(WidgetTester tester) async {
    // A tall viewport so every section's sliver is built — SliverGrid builds
    // lazily, so an off-screen section header simply isn't in the tree and
    // find.text can't see it (the default 800×600 surface pushes Environment
    // below the fold).
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // The mixed preset enables all three groups: temperature/ph/salinity
    // (environment), alkalinity/calcium/magnesium (core chemistry),
    // nitrate/phosphate/ammonia/nitrite (nutrients). Sets the tank active.
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DashboardBody()),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  // Section headers are uppercased by SectionHeader.
  final coreHeader = find.text('CORE CHEMISTRY');
  final nutrientHeader = find.text('NUTRIENTS');
  final envHeader = find.text('ENVIRONMENT');

  testWidgets('renders a header for every populated group', (tester) async {
    await pumpDashboard(tester);

    expect(coreHeader, findsOneWidget);
    expect(nutrientHeader, findsOneWidget);
    expect(envHeader, findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('disabling every parameter in a group hides the whole group, '
      'header included, leaving the others intact', (tester) async {
    final db = await pumpDashboard(tester);

    // Disable the entire environment group (temperature, pH, salinity — ORP
    // is not in the mixed preset).
    final tracked = await db.getTrackedParameters(
      (await db.getActiveTankId())!,
    );
    for (final p in tracked) {
      if ({'temperature', 'ph', 'salinity'}.contains(p.paramKey)) {
        await db.updateTrackedParameter(p.copyWith(enabled: false));
      }
    }
    await settle(tester);

    expect(envHeader, findsNothing, reason: 'empty group must not show');
    expect(coreHeader, findsOneWidget);
    expect(nutrientHeader, findsOneWidget);

    await unmountApp(tester);
  });
}
