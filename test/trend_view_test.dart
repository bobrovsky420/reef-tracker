import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/trend_view.dart';

/// Widget tests for [TrendCard]'s honesty rules (#31) and its unit handling.
///
/// The card is the one place the trend subsystem *speaks*: it turns a
/// [TrendResult] into a headline, an icon and a forecast line. Three of its
/// rules are only visible here, not in `trend_test.dart`:
///
/// * an **oscillating** fit must retract its rate — the headline becomes the
///   measured swing ("±0.12 pH") and the arrow becomes the swap glyph, because
///   a line drawn through noise has no direction to point at;
/// * a fit whose slope failed the significance test still prints its rate but
///   must read as *holding steady*, with a flat arrow — never "staying within
///   range at this rate", which claims a rate the domain just rejected;
/// * every value shown in display units is a **delta**, so the conversion is
///   affine: `toDisplay(x) - toDisplay(0)`. A ±0.5 °C swing is ±0.9 °F, not the
///   ±32.9 °F a naive `toDisplay(sigma)` would print.
///
/// Fixtures are built as [TrendResult] values directly (rather than through
/// [computeTrend]) so the retraction rules can be driven at their boundaries;
/// `sigma`/`relativeSwing` are always set, since [TrendResult.oscillating]
/// reads both.
void main() {
  final pHPres = presentationFor('ph', 'pH', 2, const UnitPrefs());
  final fahrenheitPres = presentationFor(
    'temperature',
    '°C',
    1,
    const UnitPrefs(temp: TempUnit.fahrenheit),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    TrendResult trend,
    ParamPresentation pres,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildReefTheme(Brightness.light, TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: TrendCard(trend: trend, pres: pres),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an oscillating fit shows the swing, not a rate, and swaps the '
      'direction arrow for the swap glyph', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Not significant + swing at/above kTrendOscillationRelative (0.37).
    const trend = TrendResult(
      slopePerDay: 0.03,
      direction: TrendDirection.rising,
      window: 6,
      slopeSignificant: false,
      sigma: 0.12,
      relativeSwing: 0.5,
    );
    expect(trend.oscillating, isTrue, reason: 'fixture must be oscillating');

    await pumpCard(tester, trend, pHPres);

    // Headline is the typical swing in display units...
    expect(find.text('±0.12 pH'), findsOneWidget);
    // ...and the fitted rate is withdrawn entirely, not printed beside it.
    expect(find.textContaining('/day'), findsNothing);
    expect(find.text(l.trendOscillating), findsOneWidget);
    // No direction claim: the swap arrows replace the up arrow.
    expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });

  testWidgets('a fit whose slope is not significant reads as holding steady '
      'with a flat arrow, even while the measured rate is rising', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Rejected slope, but the scatter is small relative to the green band —
    // below the oscillating threshold, so "no trend" is the whole story.
    const trend = TrendResult(
      slopePerDay: 0.02,
      direction: TrendDirection.rising,
      window: 5,
      slopeSignificant: false,
      sigma: 0.05,
      relativeSwing: 0.2,
    );
    expect(trend.oscillating, isFalse, reason: 'fixture must not oscillate');

    await pumpCard(tester, trend, pHPres);

    // The measured rate is still printed — only the *direction* claim goes.
    expect(find.text(l.trendRatePerDay('+0.02 pH')), findsOneWidget);
    expect(find.text(l.trendFlat), findsOneWidget);
    // "Staying within range at this rate" would assert a rate the
    // significance test just rejected.
    expect(find.text(l.trendWithinRange), findsNothing);
    expect(find.byIcon(Icons.trending_flat), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });

  testWidgets('°F converts the per-day rate as a delta, not as a value', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // +0.5 °C/day is +0.9 °F/day. A naive toDisplay(slope) would print the
    // +32° offset as part of the rate: "+32.9 °F/day".
    const trend = TrendResult(
      slopePerDay: 0.5,
      direction: TrendDirection.rising,
      window: 5,
      sigma: 0.1,
      relativeSwing: 0.1,
    );

    await pumpCard(tester, trend, fahrenheitPres);

    expect(find.text(l.trendRatePerDay('+0.9 °F')), findsOneWidget);
    expect(find.textContaining('32.9'), findsNothing);
  });

  testWidgets('°F converts the oscillation swing as a delta too', (
    tester,
  ) async {
    // The same affine rule for the ± headline: a ±0.5 °C swing is ±0.9 °F.
    const trend = TrendResult(
      slopePerDay: -0.4,
      direction: TrendDirection.falling,
      window: 6,
      slopeSignificant: false,
      sigma: 0.5,
      relativeSwing: 0.9,
    );
    expect(trend.oscillating, isTrue);

    await pumpCard(tester, trend, fahrenheitPres);

    expect(find.text('±0.9 °F'), findsOneWidget);
    expect(find.text('±32.9 °F'), findsNothing);
  });

  testWidgets('a sub-day crossing is floored at "~1 d" rather than "~0 d", '
      'and longer estimates round to the nearest day', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    const trend = TrendResult(
      slopePerDay: -0.5,
      direction: TrendDirection.falling,
      window: 5,
      daysToAmber: 0.2,
      daysToRed: 3.6,
      sigma: 0.1,
      relativeSwing: 0.1,
    );

    await pumpCard(tester, trend, pHPres);

    expect(find.text(l.trendAmberInDays(1)), findsOneWidget);
    expect(find.text(l.trendAmberInDays(0)), findsNothing);
    expect(find.text(l.trendRedInDays(4)), findsOneWidget);
    // With forecasts present, the "holding steady / within range" note is not
    // shown at all.
    expect(find.text(l.trendWithinRange), findsNothing);
    expect(find.text(l.trendFlat), findsNothing);
  });

  testWidgets('a recovering value is floored at "~1 d" as well', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // An exact on-the-bound hit reports 0 days from the domain (the fitted
    // anchor is computed, so it can land a few ulps either side).
    const trend = TrendResult(
      slopePerDay: 0.4,
      direction: TrendDirection.rising,
      window: 5,
      daysToGreen: 0,
      recovering: true,
      sigma: 0.1,
      relativeSwing: 0.1,
    );

    await pumpCard(tester, trend, pHPres);

    expect(find.text(l.trendBackInRangeDays(1)), findsOneWidget);
    expect(find.text(l.trendBackInRangeDays(0)), findsNothing);
  });
}
