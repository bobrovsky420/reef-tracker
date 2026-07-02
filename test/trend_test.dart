import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  List<DosePoint> series(List<double> values, {int stepDays = 1}) => [
        for (var i = 0; i < values.length; i++)
          (t: t0.add(Duration(days: i * stepDays)), value: values[i])
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
      final pts = [
        for (var i = 0; i < 5; i++) (t: t0, value: 8.0),
      ];
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

  group('forecasts toward bounds', () {
    test('rising value projects days to amber (greenHigh) and red (amberHigh)',
        () {
      // 8.5 rising 0.1/day: greenHigh 9 in 5 d, amberHigh 10 in 15 d.
      final t =
          computeTrend(points: series([8.1, 8.2, 8.3, 8.4, 8.5]), bounds: bounds, window: 5)!;
      expect(t.direction, TrendDirection.rising);
      expect(t.daysToAmber, closeTo(5, 1e-9));
      expect(t.daysToRed, closeTo(15, 1e-9));
      expect(t.soonestCrossing, closeTo(5, 1e-9));
      expect(t.hasForecast, isTrue);
    });

    test('falling value projects days to amber (greenLow) and red (amberLow)',
        () {
      // 7.9 falling 0.1/day: greenLow 7.5 in 4 d, amberLow 7 in 9 d.
      final t = computeTrend(
          points: series([8.3, 8.2, 8.1, 8.0, 7.9]), bounds: bounds, window: 5)!;
      expect(t.direction, TrendDirection.falling);
      expect(t.daysToAmber, closeTo(4, 1e-9));
      expect(t.daysToRed, closeTo(9, 1e-9));
    });

    test('already in amber forecasts only red, not amber', () {
      // 9.2 (already above greenHigh) rising 0.1/day: only amberHigh 10 ahead.
      final t = computeTrend(
          points: series([8.8, 8.9, 9.0, 9.1, 9.2]), bounds: bounds, window: 5)!;
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, closeTo(8, 1e-9));
    });

    test('no bound on the direction of travel yields no forecast', () {
      // Falling, but no lower bounds set.
      const upperOnly = ZoneBounds(greenHigh: 9, amberHigh: 10);
      final t = computeTrend(
          points: series([8.4, 8.3, 8.2, 8.1, 8.0]),
          bounds: upperOnly,
          window: 5)!;
      expect(t.direction, TrendDirection.falling);
      expect(t.hasForecast, isFalse);
    });

    test('flat trend has no forecast', () {
      final t = computeTrend(
          points: series([8, 8, 8, 8, 8]), bounds: bounds, window: 5)!;
      expect(t.direction, TrendDirection.flat);
      expect(t.hasForecast, isFalse);
    });

    test('a value exactly on a bound reports a zero-day crossing', () {
      // 9.0 == greenHigh, still rising: the amber crossing is "now".
      final t = computeTrend(
          points: series([8.6, 8.7, 8.8, 8.9, 9.0]), bounds: bounds, window: 5)!;
      expect(t.daysToAmber, 0);
      expect(t.soonestCrossing, 0);
      expect(t.hasForecast, isTrue);
    });
  });

  group('recovering values (#25)', () {
    test('a recovering low-amber value gets no forecast, only the flag', () {
      // 7.2 sits in the LOW amber zone and is rising back toward green: the
      // only bounds ahead lie on the far side of green, so no crossing is
      // forecast — the parameter is actively improving.
      final t = computeTrend(
          points: series([7.0, 7.05, 7.1, 7.15, 7.2]),
          bounds: bounds,
          window: 5)!;
      expect(t.direction, TrendDirection.rising);
      expect(t.recovering, isTrue);
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, isNull);
      expect(t.hasForecast, isFalse);
    });

    test('a recovering high-side value (falling back to green) is symmetric',
        () {
      // 9.4 in high amber, falling toward green.
      final t = computeTrend(
          points: series([9.8, 9.7, 9.6, 9.5, 9.4]), bounds: bounds, window: 5)!;
      expect(t.direction, TrendDirection.falling);
      expect(t.recovering, isTrue);
      expect(t.hasForecast, isFalse);
    });

    test('a worsening amber value still forecasts the red crossing', () {
      // 9.2 in high amber and still rising: not recovering — red ahead.
      final t = computeTrend(
          points: series([8.8, 8.9, 9.0, 9.1, 9.2]), bounds: bounds, window: 5)!;
      expect(t.recovering, isFalse);
      expect(t.daysToRed, closeTo(8, 1e-9));
    });

    test('an out-of-range value holding flat is not "recovering"', () {
      final t = computeTrend(
          points: series([7.2, 7.2, 7.2, 7.2, 7.2]), bounds: bounds, window: 5)!;
      expect(t.direction, TrendDirection.flat);
      expect(t.recovering, isFalse);
      expect(t.hasForecast, isFalse);
    });
  });

  group('projection anchor (#26)', () {
    test('projects from the fitted line, not a noisy raw endpoint', () {
      // One outlier endpoint (9.05 after a steady 8.0→8.3 run) inflates the
      // slope; the anchor is the regression value at the last timestamp
      // (mean 8.33 + slope 0.23 × 2 = 8.79, still inside green), so the amber
      // crossing survives instead of vanishing behind the raw 9.05.
      final t = computeTrend(
          points: series([8.0, 8.1, 8.2, 8.3, 9.05]),
          bounds: bounds,
          window: 5)!;
      expect(t.slopePerDay, closeTo(0.23, 1e-9));
      expect(t.recovering, isFalse);
      expect(t.daysToAmber, closeTo((9 - 8.79) / 0.23, 1e-6)); // ≈ 0.9 d
      expect(t.daysToRed, closeTo((10 - 8.79) / 0.23, 1e-6)); // ≈ 5.3 d
    });
  });

  group('value equality (T2)', () {
    test('recomputing identical inputs yields an equal result', () {
      final a = computeTrend(
          points: series([8.0, 8.1, 8.2, 8.3, 8.4]), bounds: bounds, window: 5);
      final b = computeTrend(
          points: series([8.0, 8.1, 8.2, 8.3, 8.4]), bounds: bounds, window: 5);
      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // A genuinely different trend still compares unequal.
      final c = computeTrend(
          points: series([8.0, 8.1, 8.2, 8.3, 8.9]), bounds: bounds, window: 5);
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
          window: 5)!;
      expect(t.direction, TrendDirection.rising);
      expect(t.hasForecast, isFalse);
      expect(t.recovering, isFalse);
    });
  });
}
