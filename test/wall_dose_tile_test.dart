import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/features/wall/wall_tiles.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The wall doser tile (§12b): one entry per configured head, the dosing icon
/// tinted by stock severity (gray for a switched-off head), the card washed by
/// the worst head, and the days/months compaction rule for the time left.
void main() {
  Future<BuildContext> pumpTile(WidgetTester tester, WallDoseData data) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // One wall grid cell of realistic size: a vertical overflow of the
          // 2×2 head grid fails here, not on the tablet.
          body: Center(
            child: SizedBox(
              width: 260,
              height: 140,
              child: WallDoseTile(data: data),
            ),
          ),
        ),
      ),
    );
    return tester.element(find.byType(WallDoseTile));
  }

  testWidgets('four heads render as a 2×2 grid with per-head stock colors', (
    tester,
  ) async {
    const tokens = ReefTokens.light;
    final context = await pumpTile(
      tester,
      const WallDoseData(
        title: 'ReefDose 4',
        tone: Zone.red,
        heads: [
          WallDoseHeadData(label: 'KH', timeLeft: '5 days', tone: Zone.red),
          WallDoseHeadData(label: 'Ca', timeLeft: '10 days', tone: Zone.amber),
          WallDoseHeadData(label: 'Mg', timeLeft: '4 months', tone: Zone.green),
          WallDoseHeadData(label: 'NPX', tone: Zone.unknown),
        ],
      ),
    );

    final icons = tester
        .widgetList<Icon>(find.byIcon(Icons.science_outlined))
        .toList();
    expect(icons, hasLength(4));
    expect(icons[0].color, tokens.critical);
    expect(icons[1].color, tokens.caution);
    expect(icons[2].color, tokens.healthy);
    // The switched-off head is gray, and shows a dash instead of a duration.
    expect(icons[3].color, Theme.of(context).colorScheme.onSurfaceVariant);
    expect(find.text('—'), findsOneWidget);

    for (final label in ['KH', 'Ca', 'Mg', 'NPX']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('5 days'), findsOneWidget);

    // The card itself is washed by the worst head.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(WallDoseTile),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration?)?.color, tokens.criticalSoft);
  });

  testWidgets('a 2-head pump renders one row and a neutral card', (
    tester,
  ) async {
    final context = await pumpTile(
      tester,
      const WallDoseData(
        title: 'ReefDose 2',
        heads: [
          WallDoseHeadData(label: 'KH', timeLeft: '68 days', tone: Zone.green),
          WallDoseHeadData(label: 'NPX', timeLeft: '48 days', tone: Zone.green),
        ],
      ),
    );

    expect(find.byIcon(Icons.science_outlined), findsNWidgets(2));
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(WallDoseTile),
        matching: find.byType(Container),
      ),
    );
    // All heads healthy → the card stays neutral, like the other status
    // tiles; only the icons carry green.
    expect(
      (container.decoration as BoxDecoration?)?.color,
      Theme.of(context).colorScheme.surfaceContainerLow,
    );
  });

  testWidgets('the time left compacts to days under 100 and months beyond', (
    tester,
  ) async {
    final context = await pumpTile(
      tester,
      const WallDoseData(title: 'ReefDose 4', heads: []),
    );
    final l = AppLocalizations.of(context);

    expect(wallSupplementTimeLeft(l, 1), '1 day');
    expect(wallSupplementTimeLeft(l, 68), '68 days');
    // The boundary: 99 stays precise, 100 rounds to the smallest possible
    // months value — "1 month" or "2 months" can never appear.
    expect(wallSupplementTimeLeft(l, 99), '99 days');
    expect(wallSupplementTimeLeft(l, 100), '3 months');
    expect(wallSupplementTimeLeft(l, 117), '4 months');
    expect(wallSupplementTimeLeft(l, 450), '15 months');
  });
}
