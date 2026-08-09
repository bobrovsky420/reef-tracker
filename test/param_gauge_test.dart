import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/param_gauge.dart';

/// Widget tests for [ParamGaugeCard]'s ideal-range caption.
///
/// The dial's third line is the *effective* green range, and it has to agree
/// with `classify` rather than with whatever the dial happens to draw:
///
/// * a missing `greenLow` falls back to `amberLow` — the bound below which
///   `classify` calls the value red — so the caption reads the range the user
///   is actually being held to;
/// * bounds that are one-sided (no low bound at all) have no range to name.
///   The green band is still painted, because `zoneBands` extends it to the
///   axis edge, but neither the visible caption nor its screen-reader label
///   may be synthesised from the axis: the axis floor is a padded rendering
///   detail, not a chemistry bound, and printing it would invent a lower
///   limit the tank does not have.
///
/// The ordinary two-sided caption is already covered by
/// `dashboard_sections_widget_test.dart`; these are the two shapes it isn't.
void main() {
  Future<void> pumpGauge(
    WidgetTester tester, {
    required ZoneBounds bounds,
    required GaugeAxis axis,
    required ParamPresentation pres,
    required double latest,
    String title = 'KH',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildReefTheme(Brightness.light, TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: ParamGaugeCard(
                title: title,
                pres: pres,
                bounds: bounds,
                axis: axis,
                large: false,
                latest: latest,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a missing greenLow falls back to amberLow for the ideal '
      'caption and its screen-reader label', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Alkalinity-shaped bounds with no greenLow: classify calls everything
    // from 7 to 9 green, so that — not "unbounded below" — is the ideal range.
    const bounds = ZoneBounds(amberLow: 7, greenHigh: 9, amberHigh: 11);
    final axis = gaugeAxis(bounds)!;

    await pumpGauge(
      tester,
      bounds: bounds,
      axis: axis,
      pres: presentationFor('alkalinity', 'dKH', 1, const UnitPrefs()),
      latest: 8.2,
    );

    final ideal = find.text('7–9');
    expect(ideal, findsOneWidget);
    expect(
      tester.widget<Text>(ideal).semanticsLabel,
      l.gaugeIdealRange('7', '9'),
    );
  });

  testWidgets('one-sided bounds still paint the green band but name no ideal '
      'range, visibly or to a screen reader', (tester) async {
    // Only high bounds — nothing says how low the value may go.
    const bounds = ZoneBounds(greenHigh: 0.02, amberHigh: 0.1);
    // The plausible-range fallback supplies the missing low side of the axis
    // (as the dashboard does for the keep-low nutrients).
    final axis = gaugeAxis(bounds, fallbackLow: 0, fallbackHigh: 10)!;

    await pumpGauge(
      tester,
      bounds: bounds,
      axis: axis,
      pres: presentationFor('ammonia', 'ppm', 2, const UnitPrefs()),
      latest: 0.01,
      title: 'NH3',
    );

    // The value line renders as usual...
    expect(find.text('0.01'), findsOneWidget);
    // ...but there is no "lo–hi" caption anywhere on the dial.
    expect(find.textContaining('–'), findsNothing);
    // ...and no Text carries an ideal-range semantics label (the dial's only
    // semanticsLabel is the ideal line's).
    expect(
      find.byWidgetPredicate((w) => w is Text && w.semanticsLabel != null),
      findsNothing,
    );

    // The band is a property of the bounds, not of the caption: the dial
    // paints the track arc *and* the green band arc.
    expect(find.byType(ParamGaugeCard), paintsExactlyCountTimes(#drawArc, 2));
  });
}
