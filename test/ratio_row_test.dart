import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/ratio.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/l10n/l10n_helpers.dart';
import 'package:reeftracker/widgets/ratio_row.dart';

/// Widget tests for the dashboard's [RatioRow] (REDESIGN #8/§A.4).
///
/// Two states are only observable here:
///
/// * **stale** — the latest numerator and denominator readings lie further
///   apart than `kRatioMaxSkew`, so the pair describes two tank states, not
///   one. The row still shows the number (it is the last thing we computed)
///   but must render it muted and drop the marker dot: a zone-coloured dot
///   sitting inside the green band is a confident claim about *now*. The band
///   itself is a property of the bounds, not of the reading, so it stays.
/// * **no axis** — `gaugeAxis` returns null for bounds that cannot be
///   positioned (a hand-edited or partially restored custom range with no
///   amber bounds). The row must degrade to a bar-less text row rather than
///   throw or draw a track with a made-up scale.
void main() {
  const tokens = ReefTokens.light;

  // The 10 px ringed dot the track paints at the current value.
  final marker = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  Finder trackPartColored(Color color) => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == color,
  );

  final points = <RatioPoint>[
    RatioPoint(
      time: DateTime(2026, 7, 1),
      ratio: 3.0,
      numerator: 1290,
      denominator: 430,
    ),
    RatioPoint(
      time: DateTime(2026, 7, 20),
      ratio: 3.1,
      numerator: 1333,
      denominator: 430,
    ),
  ];

  Future<void> pumpRow(
    WidgetTester tester, {
    required ZoneBounds bounds,
    bool stale = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildReefTheme(Brightness.light, TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: RatioRow(
                kind: RatioKind.mgca,
                points: points,
                bounds: bounds,
                stale: stale,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a fresh pair renders the value in its zone colour with the '
      'marker on the track', (tester) async {
    await pumpRow(tester, bounds: RatioKind.mgca.defaultBounds);

    // 3.1 sits inside Mg:Ca's green range (2.9–3.3).
    expect(tester.widget<Text>(find.text('3.1')).style?.color, tokens.healthy);
    expect(marker, findsOneWidget);
    expect(trackPartColored(tokens.track), findsOneWidget);
    expect(trackPartColored(tokens.band), findsOneWidget);
  });

  testWidgets('a stale pair mutes the value and hides the marker while the '
      'ideal band stays drawn', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpRow(tester, bounds: RatioKind.mgca.defaultBounds, stale: true);

    // The label and the number are still there — only the confidence goes.
    expect(find.text(l.ratioCardLabel(RatioKind.mgca)), findsOneWidget);
    final value = tester.widget<Text>(find.text('3.1'));
    expect(value.style?.color, tokens.textFaint);
    expect(
      value.style?.color,
      isNot(tokens.healthy),
      reason: 'a stale pair must not read as a confident green',
    );
    // No dot: the row makes no claim about where the ratio is right now.
    expect(marker, findsNothing);
    // The track and its green band describe the bounds, not the reading.
    expect(trackPartColored(tokens.track), findsOneWidget);
    expect(trackPartColored(tokens.band), findsOneWidget);
  });

  testWidgets('bounds with no axis render a bar-less row instead of throwing', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Green-only custom bounds: valid, so the value still classifies, but
    // gaugeAxis has no amber range to lay out (ratios pass no fallback).
    const bounds = ZoneBounds(greenLow: 2.9, greenHigh: 3.3);
    expect(gaugeAxis(bounds), isNull, reason: 'fixture must have no axis');

    await pumpRow(tester, bounds: bounds);

    expect(tester.takeException(), isNull);
    expect(find.text(l.ratioCardLabel(RatioKind.mgca)), findsOneWidget);
    expect(tester.widget<Text>(find.text('3.1')).style?.color, tokens.healthy);
    // No track at all — neither the rail, the band, nor the marker.
    expect(trackPartColored(tokens.track), findsNothing);
    expect(trackPartColored(tokens.band), findsNothing);
    expect(marker, findsNothing);
  });
}
