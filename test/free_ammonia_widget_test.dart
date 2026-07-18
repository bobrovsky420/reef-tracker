import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/dashboard/dashboard_screen.dart';
import 'package:reeftracker/features/manage_parameters/manage_parameters_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/free_ammonia_view.dart';

/// Widget tests for the free (toxic) ammonia dashboard visualization: it
/// renders in the Ratios area of both layouts when ammonia/pH/temperature have
/// readings, is gated on the ammonia parameter being enabled + the per-tank
/// visibility preference, and flags outdated pH/temp inputs. Same in-memory
/// drift + bounded-settle harness as dashboard_sections_widget_test.dart. The
/// formula itself is unit-tested in ammonia_toxicity_test.dart.
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

  /// Seeds a mixed-preset tank and (optionally) a fresh set of ammonia/pH/
  /// temperature readings, then pumps the dashboard. [phAgeDays] ages only the
  /// pH reading to exercise the staleness warning.
  Future<AppDatabase> pumpDashboard(
    WidgetTester tester, {
    DashboardLayout? layout,
    bool seedReadings = true,
    int phAgeDays = 0,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (layout != null) await AppSettings(db).setDashboardLayout(layout);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    if (seedReadings) {
      final now = DateTime.now();
      await db.insertReading(
        tankId: tankId,
        paramKey: 'ammonia',
        value: 0.5,
        takenAt: now,
      );
      await db.insertReading(
        tankId: tankId,
        paramKey: 'ph',
        value: 8.3,
        takenAt: now.subtract(Duration(days: phAgeDays)),
      );
      await db.insertReading(
        tankId: tankId,
        paramKey: 'temperature',
        value: 25,
        takenAt: now,
      );
    }
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

  testWidgets('grouped layout shows the free-ammonia gauge with a computed '
      'toxic fraction', (tester) async {
    await pumpDashboard(tester);

    expect(find.byType(FreeAmmoniaRow), findsOneWidget);
    expect(find.text('Free ammonia (NH₃)'), findsOneWidget);
    // The breakdown line renders the computed toxic percentage.
    expect(find.textContaining('% toxic'), findsOneWidget);
    // Fresh inputs → no staleness warning.
    expect(
      find.descendant(
        of: find.byType(FreeAmmoniaRow),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('classic layout shows the free-ammonia card', (tester) async {
    await pumpDashboard(tester, layout: DashboardLayout.classic);

    expect(find.byType(FreeAmmoniaTile), findsOneWidget);
    expect(find.byType(FreeAmmoniaRow), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('disabling the ammonia parameter hides the free-ammonia gauge', (
    tester,
  ) async {
    final db = await pumpDashboard(tester);
    expect(find.byType(FreeAmmoniaRow), findsOneWidget);

    final tracked = await db.getTrackedParameters(
      (await db.getActiveTankId())!,
    );
    final ammonia = tracked.firstWhere((p) => p.paramKey == 'ammonia');
    await db.updateTrackedParameter(ammonia.copyWith(enabled: false));
    await settle(tester);

    expect(find.byType(FreeAmmoniaRow), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the visibility preference hides the free-ammonia gauge', (
    tester,
  ) async {
    final db = await pumpDashboard(tester);
    expect(find.byType(FreeAmmoniaRow), findsOneWidget);

    await AppSettings(db).setFreeAmmoniaVisible((await db.getActiveTankId())!, false);
    await settle(tester);

    expect(find.byType(FreeAmmoniaRow), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('an outdated pH reading raises the inaccuracy warning', (
    tester,
  ) async {
    await pumpDashboard(tester, phAgeDays: 10);

    expect(
      find.descendant(
        of: find.byType(FreeAmmoniaRow),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );

    await unmountApp(tester);
  });

  /// Pumps the Manage Parameters screen for a fresh mixed-preset tank.
  Future<AppDatabase> pumpManageParameters(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ManageParametersScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('Manage Parameters lists a Free ammonia visibility row', (
    tester,
  ) async {
    await pumpManageParameters(tester);

    // The row exists (the reported gap: it must be selectable here)...
    final row = find.ancestor(
      of: find.text('Free ammonia (NH₃)'),
      matching: find.byKey(const ValueKey('free-ammonia')),
    );
    expect(row, findsOneWidget);
    // ...and it is not the ammonia parameter row itself.
    expect(find.text('Ammonia (NH₃/₄)'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Free ammonia row shows the hint when ammonia is disabled', (
    tester,
  ) async {
    final db = await pumpManageParameters(tester);

    final tracked = await db.getTrackedParameters(
      (await db.getActiveTankId())!,
    );
    final ammonia = tracked.firstWhere((p) => p.paramKey == 'ammonia');
    await db.updateTrackedParameter(ammonia.copyWith(enabled: false));
    await settle(tester);

    // The row is still listed, now nudging the user to enable ammonia.
    expect(find.text('Free ammonia (NH₃)'), findsOneWidget);
    expect(find.text('Enable ammonia to show this.'), findsOneWidget);

    await unmountApp(tester);
  });
}
