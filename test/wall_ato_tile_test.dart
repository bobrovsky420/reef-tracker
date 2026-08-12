import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/features/wall/wall_tiles.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The wall ATO tile (§12b): two rows of the same form — water level and
/// reservoir estimate — each tinted by its own severity, the card washed only
/// by an amber/red row (green stays neutral like the other status tiles).
void main() {
  Future<BuildContext> pumpTile(WidgetTester tester, WallAtoData data) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // One wall grid cell of realistic size — both rows must fit it.
          body: Center(
            child: SizedBox(
              width: 260,
              height: 140,
              child: WallAtoTile(data: data),
            ),
          ),
        ),
      ),
    );
    return tester.element(find.byType(WallAtoTile));
  }

  Color? cardColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(WallAtoTile),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  testWidgets('level and reservoir rows carry their own severity colors', (
    tester,
  ) async {
    const tokens = ReefTokens.light;
    await pumpTile(
      tester,
      const WallAtoData(
        title: 'ReefATO+',
        levelIcon: Icons.waves_outlined,
        levelText: 'Low',
        levelTone: Zone.amber,
        reservoirText: '5 days',
        reservoirTone: Zone.red,
        tone: Zone.red,
      ),
    );

    final level = tester.widget<Icon>(find.byIcon(Icons.waves_outlined));
    expect(level.color, tokens.caution);
    final tank = tester.widget<Icon>(
      find.byIcon(Icons.propane_tank_outlined),
    );
    expect(tank.color, tokens.critical);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    // The card is washed by the worse of the two rows.
    expect(cardColor(tester), tokens.criticalSoft);
  });

  testWidgets('an all-healthy tile keeps the neutral card wash', (
    tester,
  ) async {
    const tokens = ReefTokens.light;
    final context = await pumpTile(
      tester,
      const WallAtoData(
        title: 'ReefATO+',
        levelIcon: Icons.waves_outlined,
        levelText: 'OK',
        levelTone: Zone.green,
        reservoirText: '68 days',
        reservoirTone: Zone.green,
        tone: Zone.unknown,
      ),
    );

    for (final icon in [Icons.waves_outlined, Icons.propane_tank_outlined]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color, tokens.healthy);
    }
    // Green rows never wash the card — status tiles color only for alarms.
    expect(
      cardColor(tester),
      Theme.of(context).colorScheme.surfaceContainerLow,
    );
  });

  testWidgets('a leak replaces the level row in red', (tester) async {
    const tokens = ReefTokens.light;
    await pumpTile(
      tester,
      const WallAtoData(
        title: 'ReefATO+',
        levelIcon: Icons.water_damage_outlined,
        levelText: 'Leak detected!',
        levelTone: Zone.red,
        reservoirText: '12 days',
        reservoirTone: Zone.amber,
        tone: Zone.red,
      ),
    );

    final leak = tester.widget<Icon>(find.byIcon(Icons.water_damage_outlined));
    expect(leak.color, tokens.critical);
    expect(find.text('Leak detected!'), findsOneWidget);
    expect(cardColor(tester), tokens.criticalSoft);
  });

  testWidgets('a missing reservoir estimate renders a gray dash', (
    tester,
  ) async {
    final context = await pumpTile(
      tester,
      const WallAtoData(
        title: 'ReefATO+',
        levelIcon: Icons.waves_outlined,
        levelText: 'OK',
        levelTone: Zone.green,
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.propane_tank_outlined)).color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
  });

  test('the card washes only on amber/red — never on green', () {
    expect(wallWorstAlarmTone(const []), Zone.unknown);
    expect(wallWorstAlarmTone(const [Zone.green, Zone.green]), Zone.unknown);
    expect(wallWorstAlarmTone(const [Zone.green, Zone.amber]), Zone.amber);
    expect(wallWorstAlarmTone(const [Zone.amber, Zone.red]), Zone.red);
    expect(wallWorstAlarmTone(const [Zone.red, Zone.amber]), Zone.red);
    expect(wallWorstAlarmTone(const [Zone.unknown, Zone.red]), Zone.red);
  });
}
