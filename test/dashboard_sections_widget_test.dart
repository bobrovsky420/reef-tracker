import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/dashboard/dashboard_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_card.dart';

/// Structural widget tests for the dashboard layouts (REDESIGN #6): in the
/// grouped layout, section headers render for populated groups and a group
/// with every parameter disabled disappears entirely — header included (the
/// user's explicit requirement); in the classic layout the tiles render with
/// no section headers at all. Same in-memory-drift + bounded-settle harness as
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

  Future<AppDatabase> pumpDashboard(
    WidgetTester tester, {
    DashboardLayout? layout,
    Size viewport = const Size(1200, 3000),
  }) async {
    // A tall viewport so every section's sliver is built — slivers build
    // lazily, so an off-screen section header simply isn't in the tree and
    // find.text can't see it (the default 800×600 surface pushes Environment
    // below the fold). Callers pass a narrower width to force a known column
    // count for centering assertions.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (layout != null) await AppSettings(db).setDashboardLayout(layout);
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
  // The Microelements card gets its own header in the grouped layout (visual
  // separation from Environment), even though it is always a single card.
  final microHeader = find.text('MICROELEMENTS');

  testWidgets('renders a header for every populated group', (tester) async {
    await pumpDashboard(tester);

    expect(coreHeader, findsOneWidget);
    expect(nutrientHeader, findsOneWidget);
    expect(envHeader, findsOneWidget);
    expect(microHeader, findsOneWidget);

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

  testWidgets('classic layout renders the tiles with no section headers', (
    tester,
  ) async {
    await pumpDashboard(tester, layout: DashboardLayout.classic);

    // The flat grid still shows every parameter tile...
    expect(find.text('Alkalinity'), findsOneWidget);
    expect(find.text('Calcium (Ca)'), findsOneWidget);
    // ...but none of the grouped-layout section headers.
    expect(coreHeader, findsNothing);
    expect(nutrientHeader, findsNothing);
    expect(envHeader, findsNothing);
    expect(microHeader, findsNothing);

    await unmountApp(tester);
  });

  testWidgets('an odd last tile in a section is horizontally centered', (
    tester,
  ) async {
    // A phone-width viewport → 2 columns, so Core chemistry's 3rd tile
    // (Magnesium) is alone in the last row and must be centered rather than
    // sitting in the bottom-left slot. Viewport width 480 → the tile grid's
    // center is at x = 240.
    await pumpDashboard(tester, viewport: const Size(480, 3000));

    final magCard = find.ancestor(
      of: find.text('Magnesium (Mg)'),
      matching: find.byType(ReefCard),
    );
    expect(magCard, findsOneWidget);
    expect(tester.getCenter(magCard).dx, closeTo(240, 1));

    await unmountApp(tester);
  });
}
