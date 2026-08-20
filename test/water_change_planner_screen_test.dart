import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/features/calculator/water_change_planner_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  Future<AppDatabase> pumpPlanner(
    WidgetTester tester, {
    VolumeUnit volumeUnit = VolumeUnit.liters,
  }) async {
    tester.view.physicalSize = const Size(430, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).setVolumeUnit(volumeUnit);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
      volumeLiters: 200,
    );
    await db.insertReading(
      tankId: tankId,
      paramKey: 'nitrate',
      value: 20,
      takenAt: DateTime.now().subtract(const Duration(days: 31)),
    );
    await db.insertWaterChange(
      tankId: tankId,
      amountLiters: 20,
      changedAt: DateTime.now().subtract(const Duration(days: 7)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WaterChangePlannerScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  TextEditingController controller(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!;

  Future<void> selectNitrate(WidgetTester tester) async {
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('water-change-parameter')),
        )
        .onChanged!('nitrate');
    await tester.pumpAndSettle();
  }

  testWidgets('uses tank context and projects batch and automatic changes', (
    tester,
  ) async {
    await pumpPlanner(tester);
    await selectNitrate(tester);

    expect(controller(tester, 'water-change-tank-volume').text, '200');
    expect(controller(tester, 'water-change-change-volume').text, '20');
    expect(controller(tester, 'water-change-current').text, '20.0');
    expect(find.textContaining('over 30 days old'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('water-change-replacement')),
      '0',
    );
    await tester.enterText(find.byKey(const Key('water-change-target')), '15');
    await tester.enterText(find.byKey(const Key('water-change-count')), '3');
    await tester.tap(find.byKey(const Key('water-change-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('water-change-result')), findsOneWidget);
    expect(find.text('18.0 ppm'), findsWidgets);
    expect(find.text('14.6 ppm'), findsWidgets);
    expect(find.text('27.1%'), findsOneWidget);
    expect(find.textContaining('3 changes'), findsWidgets);

    await tester.tap(find.byKey(const Key('water-change-method-automatic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('water-change-calculate')));
    await tester.pumpAndSettle();
    expect(find.text('18.1 ppm'), findsWidgets);
    expect(find.text('14.8 ppm'), findsWidgets);
    expect(find.text('25.92%'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('prefills and calculates through the US-gallon boundary', (
    tester,
  ) async {
    await pumpPlanner(tester, volumeUnit: VolumeUnit.gallons);
    await selectNitrate(tester);

    expect(controller(tester, 'water-change-tank-volume').text, '52.8');
    expect(controller(tester, 'water-change-change-volume').text, '5.3');
    await tester.enterText(
      find.byKey(const Key('water-change-replacement')),
      '0',
    );
    await tester.enterText(find.byKey(const Key('water-change-target')), '15');
    await tester.enterText(find.byKey(const Key('water-change-count')), '3');
    await tester.tap(find.byKey(const Key('water-change-calculate')));
    await tester.pumpAndSettle();

    expect(find.text('14.6 ppm'), findsWidgets);
    expect(find.textContaining('15.9 gal total'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('rejects a change larger than the system volume', (tester) async {
    await pumpPlanner(tester);
    await selectNitrate(tester);
    await tester.enterText(
      find.byKey(const Key('water-change-change-volume')),
      '201',
    );
    await tester.enterText(
      find.byKey(const Key('water-change-replacement')),
      '0',
    );
    await tester.tap(find.byKey(const Key('water-change-calculate')));
    await tester.pumpAndSettle();
    expect(
      find.text('Each change must not exceed the system-water volume.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('water-change-result')), findsNothing);
    await unmountApp(tester);
  });
}
