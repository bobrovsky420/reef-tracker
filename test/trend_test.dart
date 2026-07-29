import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/dose_calculator.dart' show linearFit;
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  List<DosePoint> series(List<double> values, {int stepDays = 1}) => [
    for (var i = 0; i < values.length; i++)
      (t: t0.add(Duration(days: i * stepDays)), value: values[i]),
  ];

  // Alkalinity-like bounds: amber 7–7.5, green 7.5–9, amber 9–10.
  const bounds = ZoneBounds(
    amberLow: 7,
    greenLow: 7.5,
    greenHigh: 9,
    amberHigh: 10,
  );

  group('computeTrend window gating', () {
    test('returns null with fewer readings than the window', () {
      expect(
        computeTrend(points: series([8, 8.1]), bounds: bounds, window: 5),
        isNull,
      );
    });

    test('returns null when all readings share an instant', () {
      final pts = [for (var i = 0; i < 5; i++) (t: t0, value: 8.0)];
      expect(computeTrend(points: pts, bounds: bounds, window: 5), isNull);
    });

    test('uses only the most recent window readings', () {
      // An old spike then a steady 0.1/day rise over the last 5 points.
      final pts = series([20, 8.0, 8.1, 8.2, 8.3, 8.4]);
      final t = computeTrend(points: pts, bounds: bounds, window: 5)!;
      expect(t.window, 5);
      expect(t.slopePerDay, closeTo(0.1, 1e-9));
      expect(t.direction, TrendDirection.rising);
    });
  });

  group('minimum-span widening (kTrendMinSpanDays)', () {
    // Two measurements a day: 12 h between points.
    List<DosePoint> dense(List<double> values) => [
      for (var i = 0; i < values.length; i++)
        (t: t0.add(Duration(hours: i * 12)), value: values[i]),
    ];

    test('a sub-span window widens to every reading within the span', () {
      // 12 points every 12 h: the newest 5 span only 2 days, so the fit must
      // widen to all points strictly within kTrendMinSpanDays (5 d) of the
      // newest — the 10 newest here. The flat older points inside the span
      // pull the slope below the last-5-only fit (0.2/day).
      final pts = dense([
        8.0,
        8.0,
        8.0,
        8.0,
        8.0,
        8.0,
        8.0,
        8.1,
        8.2,
        8.3,
        8.4,
        8.5,
      ]);
      final t = computeTrend(points: pts, bounds: bounds, window: 5)!;
      expect(t.window, 10);
      expect(
        t.slopePerDay,
        closeTo(linearFit(pts.sublist(2))!.slopePerDay, 1e-9),
      );
      expect(t.slopePerDay, lessThan(0.2));
    });

    test('daily readings keep exactly the configured window', () {
      // Daily spacing: the newest 5 already cover the span (the cutoff point
      // itself is excluded, so nothing older leaks into the fit).
      final t = computeTrend(
        points: series([7.0, 7.0, 7.0, 8.1, 8.2, 8.3, 8.4, 8.5]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.window, 5);
      expect(t.slopePerDay, closeTo(0.1, 1e-9));
    });

    test('sparser-than-daily readings are unaffected', () {
      final t = computeTrend(
        points: series([8.1, 8.2, 8.3, 8.4, 8.5], stepDays: 7),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.window, 5);
      expect(t.slopePerDay, closeTo(0.1 / 7, 1e-9));
    });

    test('minSpanDays: 0 disables widening', () {
      final pts = dense([8.0, 8.0, 8.0, 8.0, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        minSpanDays: 0,
      )!;
      expect(t.window, 5);
      expect(t.slopePerDay, closeTo(0.2, 1e-9));
    });
  });

  group('forecasts toward bounds', () {
    test(
      'rising value projects days to amber (greenHigh) and red (amberHigh)',
      () {
        // 8.5 rising 0.1/day: greenHigh 9 in 5 d, amberHigh 10 in 15 d.
        final t = computeTrend(
          points: series([8.1, 8.2, 8.3, 8.4, 8.5]),
          bounds: bounds,
          window: 5,
        )!;
        expect(t.direction, TrendDirection.rising);
        expect(t.daysToAmber, closeTo(5, 1e-9));
        expect(t.daysToRed, closeTo(15, 1e-9));
        expect(t.soonestCrossing, closeTo(5, 1e-9));
        expect(t.hasForecast, isTrue);
      },
    );

    test(
      'falling value projects days to amber (greenLow) and red (amberLow)',
      () {
        // 7.9 falling 0.1/day: greenLow 7.5 in 4 d, amberLow 7 in 9 d.
        final t = computeTrend(
          points: series([8.3, 8.2, 8.1, 8.0, 7.9]),
          bounds: bounds,
          window: 5,
        )!;
        expect(t.direction, TrendDirection.falling);
        expect(t.daysToAmber, closeTo(4, 1e-9));
        expect(t.daysToRed, closeTo(9, 1e-9));
      },
    );

    test('already in amber forecasts only red, not amber', () {
      // 9.2 (already above greenHigh) rising 0.1/day: only amberHigh 10 ahead.
      final t = computeTrend(
        points: series([8.8, 8.9, 9.0, 9.1, 9.2]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, closeTo(8, 1e-9));
    });

    test('no bound on the direction of travel yields no forecast', () {
      // Falling, but no lower bounds set.
      const upperOnly = ZoneBounds(greenHigh: 9, amberHigh: 10);
      final t = computeTrend(
        points: series([8.4, 8.3, 8.2, 8.1, 8.0]),
        bounds: upperOnly,
        window: 5,
      )!;
      expect(t.direction, TrendDirection.falling);
      expect(t.hasForecast, isFalse);
    });

    test('flat trend has no forecast', () {
      final t = computeTrend(
        points: series([8, 8, 8, 8, 8]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.direction, TrendDirection.flat);
      expect(t.hasForecast, isFalse);
    });

    test('a value exactly on a bound reports a zero-day crossing', () {
      // 9.0 == greenHigh, still rising: the amber crossing is "now".
      final t = computeTrend(
        points: series([8.6, 8.7, 8.8, 8.9, 9.0]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.daysToAmber, 0);
      expect(t.soonestCrossing, 0);
      expect(t.hasForecast, isTrue);
    });
  });

  group('recovering values (#25, U15)', () {
    test('a recovering low-amber value forecasts green, not amber/red', () {
      // 7.2 sits in the LOW amber zone and is rising back toward green: the
      // only bounds ahead lie on the far side of green, so no warning is
      // forecast — instead the near green bound (7.5 at 0.05/day) gives the
      // positive "back in range" estimate.
      final t = computeTrend(
        points: series([7.0, 7.05, 7.1, 7.15, 7.2]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.direction, TrendDirection.rising);
      expect(t.recovering, isTrue);
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, isNull);
      expect(t.hasForecast, isFalse);
      expect(t.daysToGreen, closeTo(6, 1e-9));
    });

    test(
      'a recovering high-side value (falling back to green) is symmetric',
      () {
        // 9.4 in high amber, falling toward green (9.0 at 0.1/day).
        final t = computeTrend(
          points: series([9.8, 9.7, 9.6, 9.5, 9.4]),
          bounds: bounds,
          window: 5,
        )!;
        expect(t.direction, TrendDirection.falling);
        expect(t.recovering, isTrue);
        expect(t.hasForecast, isFalse);
        expect(t.daysToGreen, closeTo(4, 1e-9));
      },
    );

    test('amber-only bounds recover toward the amber bound itself', () {
      // With no green bounds, "green" is the region between the amber bounds
      // (#30): 6.4 rising at 0.1/day reaches amberLow 7 in 6 days.
      final t = computeTrend(
        points: series([6.0, 6.1, 6.2, 6.3, 6.4]),
        bounds: const ZoneBounds(amberLow: 7, amberHigh: 10),
        window: 5,
      )!;
      expect(t.recovering, isTrue);
      expect(t.daysToGreen, closeTo(6, 1e-9));
    });

    test('a worsening amber value still forecasts the red crossing', () {
      // 9.2 in high amber and still rising: not recovering — red ahead.
      final t = computeTrend(
        points: series([8.8, 8.9, 9.0, 9.1, 9.2]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.recovering, isFalse);
      expect(t.daysToRed, closeTo(8, 1e-9));
      expect(t.daysToGreen, isNull);
    });

    test('an out-of-range value holding flat is not "recovering"', () {
      final t = computeTrend(
        points: series([7.2, 7.2, 7.2, 7.2, 7.2]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.direction, TrendDirection.flat);
      expect(t.recovering, isFalse);
      expect(t.hasForecast, isFalse);
      expect(t.daysToGreen, isNull);
    });
  });

  group('projection anchor (#26)', () {
    test('projects from the fitted line, not a noisy raw endpoint', () {
      // A firm 0.2/day rise overshooting to 9.05 on the last test. The raw
      // endpoint is already past greenHigh (a projection anchored on it would
      // put the amber crossing in the past and report nothing); the anchor is
      // the regression value at the last timestamp (mean 8.45 + slope 0.25 × 2
      // = 8.95, still inside green), so the crossing survives.
      final t = computeTrend(
        points: series([8.0, 8.2, 8.4, 8.6, 9.05]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.slopePerDay, closeTo(0.25, 1e-9));
      expect(t.recovering, isFalse);
      expect(t.slopeSignificant, isTrue);
      expect(t.daysToAmber, closeTo((9 - 8.95) / 0.25, 1e-6)); // ≈ 0.2 d
      expect(t.daysToRed, closeTo((10 - 8.95) / 0.25, 1e-6)); // ≈ 4.2 d
    });

    test('a single outlier big enough to fail the t-test forecasts nothing', () {
      // The same shape but with the rise carried entirely by the outlier
      // (8.0→8.3 in 0.1 steps, then 9.05): |t| = 3.07 against a df-3 critical
      // value of 3.182, i.e. p ≈ 0.055. Marginal, and marginal is exactly what
      // #31 declines to build a "crosses amber tomorrow" warning on.
      final t = computeTrend(
        points: series([8.0, 8.1, 8.2, 8.3, 9.05]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.slopePerDay, closeTo(0.23, 1e-9)); // still measured…
      expect(t.direction, TrendDirection.rising); // …and still signed…
      expect(t.slopeSignificant, isFalse); // …but not trusted.
      expect(t.hasForecast, isFalse);
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, isNull);
    });
  });

  group('value equality (T2)', () {
    test('recomputing identical inputs yields an equal result', () {
      final a = computeTrend(
        points: series([8.0, 8.1, 8.2, 8.3, 8.4]),
        bounds: bounds,
        window: 5,
      );
      final b = computeTrend(
        points: series([8.0, 8.1, 8.2, 8.3, 8.4]),
        bounds: bounds,
        window: 5,
      );
      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // A genuinely different trend still compares unequal.
      final c = computeTrend(
        points: series([8.0, 8.1, 8.2, 8.3, 8.9]),
        bounds: bounds,
        window: 5,
      );
      expect(a, isNot(equals(c)));
    });
  });

  group('invalid bounds', () {
    test('bounds violating the ordering invariant yield no forecast', () {
      // Inverted greens (possible via restored backups) classify as unknown;
      // the trend must not project toward garbage bounds either.
      const inverted = ZoneBounds(greenLow: 9, greenHigh: 8);
      final t = computeTrend(
        points: series([8.1, 8.2, 8.3, 8.4, 8.5]),
        bounds: inverted,
        window: 5,
      )!;
      expect(t.direction, TrendDirection.rising);
      expect(t.hasForecast, isFalse);
      expect(t.recovering, isFalse);
    });
  });

  group('slope significance (#31)', () {
    test('a clean drift is significant and still forecasts', () {
      final t = computeTrend(
        points: series([8.5, 8.4, 8.2, 8.1, 7.9, 7.8]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.slopeSignificant, isTrue);
      expect(t.oscillating, isFalse);
      expect(t.hasForecast, isTrue);
      expect(t.sigma, lessThan(0.05)); // hugs the line
    });

    test('an oscillating series forecasts nothing and reports the swing', () {
      // Sawtooth around 8.3 with no underlying drift: the fit finds a slope,
      // but nowhere near its own standard error.
      final t = computeTrend(
        points: series([8.6, 8.0, 8.6, 8.0, 8.6, 8.0]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.slopeSignificant, isFalse);
      expect(t.hasForecast, isFalse);
      expect(t.daysToGreen, isNull);
      expect(t.recovering, isFalse);
      expect(t.oscillating, isTrue);
      expect(t.sigma, greaterThan(0.25));
      // Swing measured against the green half-width ((9 - 7.5) / 2 = 0.75).
      expect(t.relativeSwing, closeTo(t.sigma! / 0.75, 1e-9));
    });

    test('small scatter is neither significant nor worth calling out', () {
      // Wobbles of ±0.02 in a 1.5-wide green band: no trend, but nothing to
      // report either — oscillating stays false so no message is shown.
      final t = computeTrend(
        points: series([8.30, 8.32, 8.28, 8.31, 8.29, 8.30]),
        bounds: bounds,
        window: 5,
      )!;
      expect(t.slopeSignificant, isFalse);
      expect(t.hasForecast, isFalse);
      expect(t.relativeSwing, lessThan(kTrendOscillationRelative));
      expect(t.oscillating, isFalse);
    });

    test('the threshold is df-aware, not a flat |t| >= 2', () {
      // |t| = 2.32 over 6 points (df 4, critical 2.776): a flat "|t| >= 2"
      // rule would pass this; the df-aware one must not.
      final pts = [
        (t: t0, value: 8.47),
        (t: t0.add(const Duration(days: 1, hours: 18)), value: 8.38),
        (t: t0.add(const Duration(days: 2, hours: 20)), value: 8.44),
        (t: t0.add(const Duration(days: 3, hours: 14)), value: 8.28),
        (t: t0.add(const Duration(days: 3, hours: 17)), value: 8.38),
        (t: t0.add(const Duration(days: 4, hours: 13)), value: 8.31),
      ];
      // pH-like bounds (mixed reef): green 7.9–8.4.
      const phBounds = ZoneBounds(
        amberLow: 7.8,
        greenLow: 7.9,
        greenHigh: 8.4,
        amberHigh: 8.6,
      );
      final t = computeTrend(points: pts, bounds: phBounds, window: 5)!;
      expect(t.direction, TrendDirection.falling);
      expect(t.slopeSignificant, isFalse);
      expect(t.hasForecast, isFalse);
    });

    test('a two-point fit has nothing to test and keeps forecasting', () {
      final t = computeTrend(
        points: series([8.5, 8.7]),
        bounds: bounds,
        window: 2,
      )!;
      expect(t.sigma, isNull);
      expect(t.relativeSwing, isNull);
      expect(t.slopeSignificant, isTrue);
      expect(t.oscillating, isFalse);
      expect(t.daysToAmber, closeTo(1.5, 1e-9));
    });

    test('bounds with no usable scale leave the swing unmeasured', () {
      // Nothing to divide sigma by: no relative swing, so never "oscillating"
      // — but the significance test itself is unaffected.
      const noScale = ZoneBounds(greenHigh: 9);
      final t = computeTrend(
        points: series([8.6, 8.0, 8.6, 8.0, 8.6, 8.0]),
        bounds: noScale,
        window: 5,
      )!;
      expect(t.sigma, isNotNull);
      expect(t.relativeSwing, isNull);
      expect(t.slopeSignificant, isFalse);
      expect(t.oscillating, isFalse);
    });
  });
}
