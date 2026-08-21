import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/features/calculator/reef_unit_converter_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  Future<void> pumpConverter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildReefTheme(Brightness.light, TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReefUnitConverterScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String valueOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('every unit is editable and recalculates its sibling fields', (
    tester,
  ) async {
    await pumpConverter(tester);

    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.byType(TextField), findsNWidgets(8));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.readOnly, isFalse);
      expect(field.onChanged, isNotNull);
    }

    await tester.enterText(
      find.byKey(const Key('reef-unit-alkalinity-meq')),
      '3.57',
    );
    expect(valueOf(tester, 'reef-unit-alkalinity-meq'), '3.57');
    expect(valueOf(tester, 'reef-unit-alkalinity-dkh'), '10.00');
    expect(valueOf(tester, 'reef-unit-alkalinity-ppm-caco3'), '178.5');

    await tester.enterText(
      find.byKey(const Key('reef-unit-temperature-fahrenheit')),
      '32',
    );
    expect(valueOf(tester, 'reef-unit-temperature-fahrenheit'), '32');
    expect(valueOf(tester, 'reef-unit-temperature-celsius'), '0.0');

    await tester.enterText(
      find.byKey(const Key('reef-unit-volume-imperial-gallons')),
      '10',
    );
    expect(valueOf(tester, 'reef-unit-volume-imperial-gallons'), '10');
    expect(valueOf(tester, 'reef-unit-volume-liters'), '45.5');
    expect(valueOf(tester, 'reef-unit-volume-us-gallons'), '12.01');
  });

  testWidgets('clearing an input clears stale equivalents', (tester) async {
    await pumpConverter(tester);

    await tester.enterText(
      find.byKey(const Key('reef-unit-temperature-celsius')),
      '',
    );

    expect(valueOf(tester, 'reef-unit-temperature-celsius'), '');
    expect(valueOf(tester, 'reef-unit-temperature-fahrenheit'), '');
  });
}
