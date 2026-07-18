import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/actions/actions_screen.dart';
import 'package:reeftracker/features/dosing/dosing_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_card.dart';

/// Structural widget tests for the REDESIGN #11/#13 list cards: the Actions
/// log and the Dosing plan collapse into one `ReefSliverCard` of divided rows,
/// the RO summary renders as the alert card when a stage is overdue, and the
/// dosing element tag carries the element's live zone color. Same
/// in-memory-drift + bounded-settle harness as dashboard_sections_widget_test.
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

  Future<AppDatabase> pumpBody(WidgetTester tester, Widget body) async {
    // Phone-width viewport so a row overflow would fail here, not on device.
    tester.view.physicalSize = const Size(390, 844);
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
          home: Scaffold(body: body),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('Actions log renders as one card of rows; swipe-delete still '
      'offers Undo', (tester) async {
    final db = await pumpBody(tester, const ActionsBody());
    final tankId = (await db.getActiveTankId())!;
    await db.insertWaterChange(
      tankId: tankId,
      changedAt: DateTime(2026, 7, 1),
      amountLiters: 20,
    );
    await db.insertCarbonChange(
      tankId: tankId,
      changedAt: DateTime(2026, 7, 2),
      grams: 50,
    );
    await settle(tester);

    expect(find.byType(ReefSliverCard), findsOneWidget);
    expect(find.text('Water change'), findsOneWidget);
    expect(find.text('Carbon change'), findsOneWidget);

    // Swipe-delete conventions survive the row swap (Dismissible + Undo).
    await tester.drag(find.text('Water change'), const Offset(-500, 0));
    await settle(tester);
    expect(find.text('Water change'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an overdue RO stage renders the alert card variant', (
    tester,
  ) async {
    final db = await pumpBody(tester, const ActionsBody());
    final stageId = await db.insertRoStage(
      stageType: 'membrane',
      title: null,
      lifespanDays: 30,
      enabled: true,
      remindEnabled: false,
      note: null,
    );
    await db.insertRoReplacement(
      stageId: stageId,
      replacedAt: DateTime.now().subtract(const Duration(days: 100)),
      note: null,
    );
    await settle(tester);

    expect(find.text('Reverse osmosis unit'), findsOneWidget);
    // "{stage} · N d overdue" in the critical color.
    final sub = tester.widget<Text>(find.textContaining('overdue'));
    expect(sub.style?.color, ReefTokens.light.critical);

    await unmountApp(tester);
  });

  testWidgets('Dosing rows render in one card with live element tags', (
    tester,
  ) async {
    final db = await pumpBody(tester, const DosingBody());
    final tankId = (await db.getActiveTankId())!;
    await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tankId),
        product: const Value('Alk Mix'),
        elementKey: const Value('alkalinity'),
      ),
    );
    await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tankId),
        product: const Value('Mg Mix'),
        elementKey: const Value('magnesium'),
      ),
    );
    // A fresh in-range alkalinity reading → green tag; magnesium has no
    // reading → neutral tag.
    final alk = (await db.getTrackedParameters(
      tankId,
    )).firstWhere((t) => t.paramKey == 'alkalinity');
    final bounds = boundsOf(alk);
    await db.insertReading(
      tankId: tankId,
      paramKey: 'alkalinity',
      value: (bounds.greenLow! + bounds.greenHigh!) / 2,
      takenAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await settle(tester);

    expect(find.byType(ReefSliverCard), findsOneWidget);
    expect(find.text('Alk Mix'), findsOneWidget);
    expect(find.text('Mg Mix'), findsOneWidget);

    final alkTag = tester.widget<Text>(find.text('Alkalinity'));
    expect(alkTag.style?.color, ReefTokens.light.healthy);
    final mgTag = tester.widget<Text>(find.text('Magnesium (Mg)'));
    expect(mgTag.style?.color, ReefTokens.light.textDim);

    await unmountApp(tester);
  });
}
