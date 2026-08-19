import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/features/calculator/salinity_calculator_screen.dart';
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
    bool withCalibration = true,
  }) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
      volumeLiters: 200,
    );
    if (withCalibration) {
      await db.updateTankSaltCalibration(
        tankId: tankId,
        name: 'Measured salt',
        gramsPerLiter: 38.2,
        referencePpt: 35,
      );
    }
    await db.insertReading(
      tankId: tankId,
      paramKey: 'salinity',
      value: pptToSg(37),
      takenAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SalinityCalculatorScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('mixes a measured product and remembers its calibration', (
    tester,
  ) async {
    final db = await pumpPlanner(tester);
    await tester.tap(find.byKey(const Key('salinity-mode-mix')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('salt-mix-volume')), '20');
    await tester.enterText(find.byKey(const Key('salt-mix-target')), '35');
    await tester.tap(find.text('Calculate salt mix'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('salt-mix-result')), findsOneWidget);
    expect(find.textContaining('764 g'), findsOneWidget);
    final tank = (await db.getTanks()).single;
    expect(tank.saltMixName, 'Measured salt');
    expect(tank.saltMixGramsPerLiter, 38.2);
    expect(tank.saltMixReferencePpt, 35);
    await unmountApp(tester);
  });

  testWidgets(
    'catalogue seeds first selection then restores the measured product value',
    (tester) async {
      final db = await pumpPlanner(tester, withCalibration: false);
      await tester.tap(find.byKey(const Key('salinity-mode-mix')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salt-mix-product')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red Sea — Coral Pro Salt').last);
      await tester.pumpAndSettle();

      TextFormField factorField() => tester.widget<TextFormField>(
        find.byKey(const Key('salt-mix-factor')),
      );
      expect(factorField().controller!.text, '40.6');
      final tankId = (await db.getTanks()).single.id;
      var stored = await db.getSaltMixCalibrationForProduct(
        tankId,
        'red-sea-coral-pro',
      );
      expect(stored?.measured, isFalse);

      await tester.tap(find.text('Calibrate from a measured batch'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('salt-mix-calibration-mass')),
        '820',
      );
      await tester.enterText(
        find.byKey(const Key('salt-mix-calibration-volume')),
        '20',
      );
      await tester.enterText(
        find.byKey(const Key('salt-mix-calibration-salinity')),
        '35',
      );
      await tester.tap(find.text('Use this calibration'));
      await tester.pumpAndSettle();
      expect(factorField().controller!.text, '41');

      stored = await db.getSaltMixCalibrationForProduct(
        tankId,
        'red-sea-coral-pro',
      );
      expect(stored?.gramsPerLiter, 41);
      expect(stored?.measured, isTrue);

      await tester.tap(find.byKey(const Key('salt-mix-product')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red Sea — Salt').last);
      await tester.pumpAndSettle();
      expect(factorField().controller!.text, '38.2');

      await tester.tap(find.byKey(const Key('salt-mix-product')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red Sea — Coral Pro Salt').last);
      await tester.pumpAndSettle();
      expect(factorField().controller!.text, '41');
      expect(
        find.text('Using your measured calibration for this aquarium.'),
        findsOneWidget,
      );
      await unmountApp(tester);
    },
  );

  testWidgets('plans high and low correction paths and prefills the log', (
    tester,
  ) async {
    await pumpPlanner(tester);
    await tester.tap(find.byKey(const Key('salinity-mode-correct')));
    await tester.pumpAndSettle();

    // Tank volume and the latest 37-ppt reading are tank-aware prefills.
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('salinity-correction-volume')),
          )
          .controller!
          .text,
      '200',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('salinity-correction-current')),
          )
          .controller!
          .text,
      '37.0',
    );

    await tester.enterText(
      find.byKey(const Key('salinity-correction-target')),
      '35',
    );
    await tester.tap(find.text('Calculate correction'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10.81 L'), findsOneWidget);

    await tester.tap(find.text('Record completed water change'));
    await tester.pumpAndSettle();
    expect(find.text('Record water change'), findsOneWidget);
    expect(find.text('10.8'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Editing the current value below target reveals the separately prepared
    // replacement-water path and its salt calculations.
    await tester.enterText(
      find.byKey(const Key('salinity-correction-current')),
      '32',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('salinity-correction-replacement')),
      '40',
    );
    await tester.tap(find.text('Calculate correction'));
    await tester.pumpAndSettle();
    expect(find.textContaining('75 L'), findsOneWidget);
    expect(find.textContaining('3274.29 g'), findsOneWidget);
    expect(find.textContaining('654.86 g'), findsOneWidget);
    await unmountApp(tester);
  });
}
