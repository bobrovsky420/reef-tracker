import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/wall_display.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/features/wall/wall_tiles.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    WallOperatingState? state,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: WallValueTile(
              now: DateTime(2026, 8, 12, 12),
              data: WallTileData(
                id: const (deviceIdentifier: 'rftc', paramKey: 'temperature'),
                title: 'Temperature',
                sourceName: 'Temperature Controller',
                value: WallTileValue(
                  value: 25.2,
                  source: WallValueSource.live,
                  at: DateTime(2026, 8, 12, 12),
                ),
                zone: Zone.green,
                pres: ParamPresentation(
                  unitLabel: '°C',
                  decimals: 1,
                  toDisplay: (v) => v,
                  toCanonical: (v) => v,
                ),
                operatingState: state,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the Temperature Controller heating state', (tester) async {
    await pumpTile(tester, state: WallOperatingState.heating);

    expect(find.text('Heating'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(WallValueTile)).label,
      'Temperature: 25.2 °C, OK, Heating',
    );
  });

  testWidgets('shows cooling and leaves idle silent', (tester) async {
    await pumpTile(tester, state: WallOperatingState.cooling);
    expect(find.text('Cooling'), findsOneWidget);

    await pumpTile(tester);
    expect(find.text('Heating'), findsNothing);
    expect(find.text('Cooling'), findsNothing);
  });
}
