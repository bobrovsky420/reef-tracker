import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/hanna_import.dart';
import 'package:reeftracker/domain/icp_import.dart';
import 'package:reeftracker/features/import/measurement_import_sources.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

const _hannaCsv =
    'Meter,HI97115\n'
    'Sample Location,Display\n'
    'Reading,Unit,Method,Date,Status,Note\n'
    '7.8,dKH,Alkalinity Marine,19/07/2026 13:08:57,,\n';

const _zimsCsv =
    '"Date","Time","Measurement","MeasurementValue","UnitofMeasure",'
    '"MeasuredBy"\n'
    '"2026-06-02","07:10:45","Calcium (Ca)","412",'
    '"milligrams per litre","Lab"\n';

void main() {
  test(
    'registry order, settings identity, and parser invocation are explicit',
    () {
      expect(measurementImportSources.sources.map((source) => source.id), [
        kHannaImportSource,
        'icp-faunaMarin',
        'icp-zims',
      ]);
      expect(measurementImportSources.settingsSources, hasLength(1));
      expect(
        measurementImportSources.settingsSources.single.settingsSourceId,
        kHannaImportSource,
      );

      final hanna = measurementImportSources
          .availableFor(MeasurementImportGroup.appHistory)
          .single;
      expect(hanna.parse(_hannaCsv), isA<HannaImportResult>());

      final icp = measurementImportSources.availableFor(
        MeasurementImportGroup.icpReport,
      );
      expect(icp, hasLength(2));
      expect(icp.last.parse(_zimsCsv), isA<IcpImportResult>());
      expect(
        () => icp.first.parse(_zimsCsv),
        throwsA(isA<IcpImportException>()),
      );
    },
  );

  testWidgets(
    'source sheets expose only descriptors in their requested group',
    (tester) async {
      Future<void> pump(MeasurementImportGroup group) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      unawaited(runMeasurementImportSourceFlow(context, group)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await pump(MeasurementImportGroup.appHistory);
      expect(find.text('Hanna Lab'), findsOneWidget);
      expect(find.text('Fauna Marin ICP'), findsNothing);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await pump(MeasurementImportGroup.icpReport);
      expect(find.text('Fauna Marin ICP'), findsOneWidget);
      expect(find.text('ZIMS'), findsOneWidget);
      expect(find.text('Hanna Lab'), findsNothing);
    },
  );
}
