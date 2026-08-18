import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/features/reefbeat/reefbeat_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  group('reefControlProbeZone', () {
    test('uses app bounds and ignores contradictory firmware levels', () {
      final bounds = <String, ZoneBounds>{
        'salinity': ZoneBounds(
          amberLow: pptToSg(32),
          greenLow: pptToSg(34),
          greenHigh: pptToSg(36),
          amberHigh: pptToSg(38),
        ),
        'ph': const ZoneBounds(
          amberLow: 7.8,
          greenLow: 8.0,
          greenHigh: 8.3,
          amberHigh: 8.4,
        ),
      };

      expect(
        reefControlProbeZone(
          const RbControlProbe(type: 'ec', ppt: 35.8, level: 'danger'),
          bounds,
        ),
        Zone.green,
        reason: 'salinity is classified after canonical ppt-to-SG conversion',
      );
      expect(
        reefControlProbeZone(
          const RbControlProbe(type: 'ph', value: 7.7, level: 'desired'),
          bounds,
        ),
        Zone.red,
      );
    });

    test('stays neutral without a configured range or usable value', () {
      expect(
        reefControlProbeZone(
          const RbControlProbe(type: 'orp', value: 320, level: 'danger'),
          const {},
        ),
        Zone.unknown,
      );
      expect(
        reefControlProbeZone(
          const RbControlProbe(type: 'ph', level: 'desired'),
          const {'ph': ZoneBounds(greenLow: 8.0, greenHigh: 8.3)},
        ),
        Zone.unknown,
      );
    });

    test('probe temperatures use app bounds and ignore temp_level', () {
      const bounds = {
        'temperature': ZoneBounds(
          amberLow: 23,
          greenLow: 24,
          greenHigh: 26,
          amberHigh: 27,
        ),
      };
      expect(
        reefControlProbeTemperatureZone(
          const RbControlProbe(
            type: 'ph',
            temperatureC: 25.8,
            temperatureLevel: 'danger',
          ),
          bounds,
        ),
        Zone.green,
      );
    });
  });

  group('formatReefControlProbeValue', () {
    const salinity = RbControlProbe(type: 'ec', ppt: 35.8);

    test('salinity follows the app unit and shows no secondary values', () {
      expect(
        formatReefControlProbeValue(
          salinity,
          const UnitPrefs(salinity: SalinityUnit.ppt),
        ),
        '35.8 ppt',
      );
      expect(
        formatReefControlProbeValue(
          salinity,
          const UnitPrefs(salinity: SalinityUnit.sg),
        ),
        '1.027 SG',
      );
    });
  });

  testWidgets('card has parameter-only rows aligned to one right edge', (
    tester,
  ) async {
    const status = RbControlStatus(
      probes: [
        RbControlProbe(
          type: 'ec',
          name: 'Salinity 5AA',
          ppt: 35.8,
          sg: 1.027,
          ec: 54.2,
          temperatureC: 25.6,
        ),
        RbControlProbe(type: 'orp', name: 'ORP 7C', value: 81),
        RbControlProbe(
          type: 'ph',
          name: 'pH 579',
          value: 8.06,
          temperatureC: 25.8,
        ),
        RbControlProbe(type: 'leak', name: 'Leak 39E', detected: false),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unitPrefsProvider.overrideWithValue(
            const UnitPrefs(
              temp: TempUnit.fahrenheit,
              salinity: SalinityUnit.sg,
            ),
          ),
          trackedParametersProvider.overrideWithValue(
            const AsyncValue<List<ResolvedParameter>>.data([]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: reefControlStatusForTesting(status),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Salinity'), findsOneWidget);
    expect(find.text('ORP'), findsOneWidget);
    expect(find.text('pH'), findsOneWidget);
    expect(find.text('Temperature'), findsNWidgets(2));
    expect(find.text('Leak sensor'), findsOneWidget);
    expect(find.text('Dry'), findsOneWidget);
    expect(find.text('Salinity 5AA'), findsNothing);
    expect(find.text('ORP 7C'), findsNothing);
    expect(find.text('pH 579'), findsNothing);
    expect(find.text('1.027 SG'), findsOneWidget);
    expect(find.text('35.8 ppt'), findsNothing);
    expect(find.textContaining('mS/cm'), findsNothing);
    expect(find.text('78.1 °F'), findsOneWidget);
    expect(find.text('78.4 °F'), findsOneWidget);

    final scaffoldContext = tester.element(find.byType(Scaffold));
    final textTheme = Theme.of(scaffoldContext).textTheme;
    expect(
      tester.widget<Text>(find.text('Dry')).style?.color,
      ReefTokens.of(scaffoldContext).healthy,
    );
    for (final label in ['Salinity', 'ORP', 'pH', 'Leak sensor']) {
      expect(
        tester.widget<Text>(find.text(label)).style,
        textTheme.titleSmall,
        reason: '$label exactly matches a ReefRun pump name',
      );
    }
    for (final temperature in find.text('Temperature').evaluate()) {
      expect(
        (temperature.widget as Text).style?.fontWeight,
        textTheme.bodyMedium?.fontWeight,
        reason: 'Temperature stays a subordinate row label',
      );
    }

    final rightEdges = [
      for (final value in [
        '1.027 SG',
        '81.0 mV',
        '8.06',
        '78.1 °F',
        '78.4 °F',
        'Dry',
      ])
        tester.getTopRight(find.text(value)).dx,
    ];
    for (final edge in rightEdges.skip(1)) {
      expect(edge, closeTo(rightEdges.first, 0.01));
    }
  });

  testWidgets('ATO card localizes every leak-sensor state with connection '
      'precedence', (tester) async {
    Future<void> pump(RbAtoStatus status) => tester.pumpWidget(
      ProviderScope(
        overrides: [unitPrefsProvider.overrideWithValue(const UnitPrefs())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 500, child: reefAtoStatusForTesting(status)),
          ),
        ),
      ),
    );

    await pump(const RbAtoStatus());
    expect(find.text('Leak sensor'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);

    await pump(
      const RbAtoStatus(
        leakSensorConnected: true,
        leakStatusRaw: 'aquarium_water_leak',
      ),
    );
    expect(find.text('Not enabled'), findsOneWidget);
    expect(find.text('aquarium_water_leak'), findsNothing);

    await pump(
      const RbAtoStatus(
        leakSensorConnected: true,
        leakSensorEnabled: true,
        leakStatusRaw: 'dry',
      ),
    );
    expect(find.text('Dry'), findsOneWidget);

    await pump(
      const RbAtoStatus(
        leakSensorConnected: true,
        leakSensorEnabled: true,
        leakStatusRaw: 'aquarium_water_leak',
        leakAlarm: true,
      ),
    );
    expect(find.text('Aquarium water leak'), findsOneWidget);
    expect(find.text('aquarium_water_leak'), findsNothing);

    await pump(
      const RbAtoStatus(
        leakSensorConnected: true,
        leakSensorEnabled: true,
        leakStatusRaw: 'rodi_water_leak',
        leakAlarm: true,
      ),
    );
    expect(find.text('RO/DI water leak'), findsOneWidget);
    expect(find.text('rodi_water_leak'), findsNothing);
  });
}
