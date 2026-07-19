@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/ratio.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/env_pill.dart';
import 'package:reeftracker/widgets/param_gauge.dart';
import 'package:reeftracker/widgets/ratio_row.dart';

/// Golden regression tests for the pure redesign widgets (REDESIGN #7–#9,
/// cross-cutting rule 8): gauge dials, ratio band rows, environment pills —
/// each family as one light + one dark gallery covering the zone states plus
/// the empty ("No readings") form. Text renders in the test binding's Ahem
/// font (deterministic; the goldens guard geometry, color and layout, not
/// glyph shapes). Regenerate with
/// `flutter test --update-goldens test/redesign_golden_test.dart`; the tag
/// lets CI on another OS exclude them (`--exclude-tags golden`) if renderer
/// differences ever bite.
void main() {
  const identity = ParamPresentation(
    unitLabel: 'dKH',
    decimals: 1,
    toDisplay: _same,
    toCanonical: _same,
  );
  const tempPres = ParamPresentation(
    unitLabel: '°C',
    decimals: 1,
    toDisplay: _same,
    toCanonical: _same,
  );

  // Alkalinity-like two-sided bounds and the amber/red sample values.
  const alkBounds = ZoneBounds(
    amberLow: 6.5,
    greenLow: 7.5,
    greenHigh: 9,
    amberHigh: 10,
  );
  // Nitrate-like one-sided bounds (no amberLow) with a plausible-range floor.
  const no3Bounds = ZoneBounds(greenHigh: 10, amberHigh: 25);

  final risingTrend = const TrendResult(
    slopePerDay: 0.2,
    direction: TrendDirection.rising,
    window: 5,
    daysToAmber: 4,
  );

  Future<void> pumpGallery(
    WidgetTester tester,
    Brightness brightness,
    Widget child,
  ) async {
    tester.view.physicalSize = const Size(460, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = buildReefTheme(brightness, TargetPlatform.android);
    final tokens = brightness == Brightness.dark
        ? ReefTokens.dark
        : ReefTokens.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('golden'),
          // The themed scaffold is transparent (gradient lives in the app's
          // MaterialApp.builder) — paint the solid body color so the capture
          // is opaque, like the chart-share capture does (#17).
          child: ColoredBox(
            color: tokens.scaffoldBody,
            child: Center(
              child: Padding(padding: const EdgeInsets.all(12), child: child),
            ),
          ),
        ),
      ),
    );
  }

  Finder golden() => find.byKey(const ValueKey('golden'));

  Widget gaugeGallery() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // L dial, green zone, delta footer (takenAt stays null — the
          // relative-time label depends on the wall clock).
          SizedBox(
            width: 200,
            child: ParamGaugeCard(
              title: 'KH',
              pres: identity,
              bounds: alkBounds,
              axis: gaugeAxis(alkBounds)!,
              large: true,
              latest: 8.2,
              previous: 8.0,
            ),
          ),
          const SizedBox(width: 12),
          // L dial, amber zone, urgency line (TrendChip forecast).
          SizedBox(
            width: 200,
            child: ParamGaugeCard(
              title: 'KH',
              pres: identity,
              bounds: alkBounds,
              axis: gaugeAxis(alkBounds)!,
              large: true,
              latest: 7.0,
              previous: 7.4,
              trend: risingTrend,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // S dial, red zone, one-sided bounds (band runs to the gauge edge).
          SizedBox(
            width: 140,
            child: ParamGaugeCard(
              title: 'NO3',
              pres: identity,
              bounds: no3Bounds,
              axis: gaugeAxis(no3Bounds, fallbackLow: 0)!,
              large: false,
              latest: 30,
              previous: 22,
            ),
          ),
          const SizedBox(width: 12),
          // S dial, no readings: track + band only, muted overlay, no marker.
          SizedBox(
            width: 140,
            child: ParamGaugeCard(
              title: 'NO3',
              pres: identity,
              bounds: no3Bounds,
              axis: gaugeAxis(no3Bounds, fallbackLow: 0)!,
              large: false,
            ),
          ),
        ],
      ),
    ],
  );

  Widget ratioGallery() {
    final t = DateTime(2026, 1, 1);
    RatioPoint p(double ratio) =>
        RatioPoint(time: t, ratio: ratio, numerator: 3, denominator: 1);
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Green marker with a delta (two points).
          RatioRow(
            kind: RatioKind.mgca,
            points: [p(3.0), p(3.1)],
            bounds: RatioKind.mgca.defaultBounds,
          ),
          // Stale pair: muted value, no marker.
          RatioRow(
            kind: RatioKind.mgca,
            points: [p(3.1)],
            bounds: RatioKind.mgca.defaultBounds,
            stale: true,
          ),
          // Empty series: "No readings", track + band only.
          RatioRow(
            kind: RatioKind.mgca,
            points: const [],
            bounds: RatioKind.mgca.defaultBounds,
          ),
        ],
      ),
    );
  }

  Widget pillGallery() => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Green with delta.
      SizedBox(
        width: 130,
        child: EnvPill(
          title: 'TEMP',
          pres: tempPres,
          zone: Zone.green,
          latest: 25.3,
          previous: 25.1,
        ),
      ),
      const SizedBox(width: 10),
      // Amber with urgency line.
      SizedBox(
        width: 130,
        child: EnvPill(
          title: 'TEMP',
          pres: tempPres,
          zone: Zone.amber,
          latest: 27.1,
          previous: 26.5,
          trend: risingTrend,
        ),
      ),
      const SizedBox(width: 10),
      // No readings: faint dot + muted dash.
      SizedBox(width: 130, child: EnvPill(title: 'TEMP', pres: tempPres)),
    ],
  );

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('gauge dials — $mode', (tester) async {
      await pumpGallery(tester, brightness, gaugeGallery());
      await expectLater(
        golden(),
        matchesGoldenFile('goldens/param_gauge_$mode.png'),
      );
    });

    testWidgets('ratio rows — $mode', (tester) async {
      await pumpGallery(tester, brightness, ratioGallery());
      await expectLater(
        golden(),
        matchesGoldenFile('goldens/ratio_row_$mode.png'),
      );
    });

    testWidgets('environment pills — $mode', (tester) async {
      await pumpGallery(tester, brightness, pillGallery());
      await expectLater(
        golden(),
        matchesGoldenFile('goldens/env_pill_$mode.png'),
      );
    });
  }
}

double _same(double v) => v;
