import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/dose_calculator.dart' show linearFit;
import 'package:reeftracker/domain/health_score.dart';
import 'package:reeftracker/domain/insights.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/setup_type.dart';
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

  // Every fixture here is dated from [t0], which is in the past. Forecasts are
  // gated on the series being fresh (S1), so any test that asserts a day
  // estimate pins the clock to its own newest reading — "as of the last test".
  // The staleness rule itself is exercised by its own group below.

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
        final pts = series([8.1, 8.2, 8.3, 8.4, 8.5]);
        final t = computeTrend(
          points: pts,
          bounds: bounds,
          window: 5,
          now: pts.last.t,
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
        final pts = series([8.3, 8.2, 8.1, 8.0, 7.9]);
        final t = computeTrend(
          points: pts,
          bounds: bounds,
          window: 5,
          now: pts.last.t,
        )!;
        expect(t.direction, TrendDirection.falling);
        expect(t.daysToAmber, closeTo(4, 1e-9));
        expect(t.daysToRed, closeTo(9, 1e-9));
      },
    );

    test('already in amber forecasts only red, not amber', () {
      // 9.2 (already above greenHigh) rising 0.1/day: only amberHigh 10 ahead.
      final pts = series([8.8, 8.9, 9.0, 9.1, 9.2]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, closeTo(8, 1e-9));
    });

    test('no bound on the direction of travel yields no forecast', () {
      // Falling, but no lower bounds set.
      const upperOnly = ZoneBounds(greenHigh: 9, amberHigh: 10);
      final pts = series([8.4, 8.3, 8.2, 8.1, 8.0]);
      final t = computeTrend(
        points: pts,
        bounds: upperOnly,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.direction, TrendDirection.falling);
      expect(t.hasForecast, isFalse);
    });

    test('flat trend has no forecast', () {
      final pts = series([8, 8, 8, 8, 8]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.direction, TrendDirection.flat);
      expect(t.hasForecast, isFalse);
    });

    test('a value exactly on a bound reports a zero-day crossing', () {
      // 9.0 == greenHigh, still rising: the amber crossing is "now".
      final pts = series([8.6, 8.7, 8.8, 8.9, 9.0]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.daysToAmber, 0);
      expect(t.soonestCrossing, 0);
      expect(t.hasForecast, isTrue);
    });
  });

  group('stale series carry no forecast (S1)', () {
    // A firm 0.1/day rise ending at t0 + 4 d: fresh, it crosses greenHigh in
    // 5 days. The question is what happens when nobody tests again for months.
    final rising = series([8.1, 8.2, 8.3, 8.4, 8.5]);

    test('the same series still forecasts while it is fresh', () {
      // Characterization: the pre-gate behaviour, unchanged for a live tank.
      final t = computeTrend(
        points: rising,
        bounds: bounds,
        window: 5,
        now: rising.last.t,
      )!;
      expect(t.hasForecast, isTrue);
      expect(t.daysToAmber, closeTo(5, 1e-9));
      expect(t.daysToRed, closeTo(15, 1e-9));
    });

    test('a January series carries no forecast in August', () {
      // The bug this gates: the crossing estimate is measured from the last
      // reading, so a long-abandoned series keeps promising "amber in ~5 d"
      // for as long as the tank goes untested.
      final t = computeTrend(
        points: rising,
        bounds: bounds,
        window: 5,
        now: DateTime(2026, 8, 9),
      )!;
      expect(t.hasForecast, isFalse);
      expect(t.daysToAmber, isNull);
      expect(t.daysToRed, isNull);
      expect(t.soonestCrossing, isNull);
    });

    test(
      'the fit itself is still reported — only the projection is withheld',
      () {
        final t = computeTrend(
          points: rising,
          bounds: bounds,
          window: 5,
          now: DateTime(2026, 8, 9),
        )!;
        expect(t.slopePerDay, closeTo(0.1, 1e-9));
        expect(t.direction, TrendDirection.rising);
        expect(t.window, 5);
        expect(t.slopeSignificant, isTrue);
        expect(t.sigma, isNotNull);
        expect(t.relativeSwing, isNotNull);
      },
    );

    test('the boundary is the health score\'s freshness rule', () {
      TrendResult at(Duration age) => computeTrend(
        points: rising,
        bounds: bounds,
        window: 5,
        now: rising.last.t.add(age),
      )!;
      // daysSince rounds, so 30 d exactly is still fresh and 30 d + 13 h is
      // the first stale instant — the same arithmetic computeTankHealth uses.
      expect(
        at(const Duration(days: kHealthFreshnessDays)).hasForecast,
        isTrue,
      );
      expect(
        at(const Duration(days: kHealthFreshnessDays, hours: 13)).hasForecast,
        isFalse,
      );
      expect(
        at(const Duration(days: kHealthFreshnessDays + 1)).hasForecast,
        isFalse,
      );
    });

    test('freshnessDays is injectable, like computeTankHealth\'s', () {
      final t = computeTrend(
        points: rising,
        bounds: bounds,
        window: 5,
        now: rising.last.t.add(const Duration(days: 10)),
        freshnessDays: 7,
      )!;
      expect(t.hasForecast, isFalse);
    });

    test('a stale recovering series promises no return date either', () {
      // 7.2 in low amber, rising back toward green: fresh, it is back in
      // range in 6 days — but not if the last test was months ago.
      final pts = series([7.0, 7.05, 7.1, 7.15, 7.2]);
      final fresh = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(fresh.daysToGreen, closeTo(6, 1e-9));

      final stale = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t.add(const Duration(days: 90)),
      )!;
      expect(stale.recovering, isTrue); // still the measured relationship…
      expect(stale.daysToGreen, isNull); // …but no "back in range in ~N d".
    });

    test('now defaults to the wall clock', () {
      // No `now`: a series ending today forecasts, the same series shifted a
      // season into the past does not.
      final today = DateTime.now();
      List<DosePoint> endingAt(DateTime end) => [
        for (var i = 4; i >= 0; i--)
          (t: end.subtract(Duration(days: i)), value: 8.5 - i * 0.1),
      ];
      expect(
        computeTrend(
          points: endingAt(today),
          bounds: bounds,
          window: 5,
        )!.hasForecast,
        isTrue,
      );
      expect(
        computeTrend(
          points: endingAt(today.subtract(const Duration(days: 120))),
          bounds: bounds,
          window: 5,
        )!.hasForecast,
        isFalse,
      );
    });
  });

  group('a floor is not a bound to cross (S2)', () {
    // The shape every preset actually ships for a keep-low nutrient, taken
    // from the preset table rather than hand-written: green starts at 0
    // because nothing measures below it, not because 0 is a healthy limit.
    final ammoniaBounds = presetBounds(SetupType.mixed, 'ammonia');
    final ammoniaFloor = kParameterByKey['ammonia']!.minValue;

    // A finished cycle: ammonia inside green and still falling 0.004/day, so
    // the fitted 0.002 reaches "greenLow" 0 in half a day.
    final falling = series([0.018, 0.014, 0.010, 0.006, 0.002]);
    TrendResult fallingTrend({double? floor}) => computeTrend(
      points: falling,
      bounds: ammoniaBounds,
      window: 5,
      now: falling.last.t,
      floor: floor,
    )!;

    test('the preset really is the keep-low shape', () {
      expect(ammoniaBounds.greenLow, 0);
      expect(ammoniaBounds.greenHigh, 0.02);
      expect(ammoniaBounds.amberLow, isNull);
      expect(ammoniaFloor, 0); // …and the catalog floor sits on it.
    });

    test('without a floor, falling toward zero forecasts a crossing', () {
      // Characterization of the behaviour this seam changes: the app warned
      // that a cycling tank was about to leave its healthy range, on the one
      // trajectory the keeper is waiting for.
      final t = fallingTrend();
      expect(t.direction, TrendDirection.falling);
      expect(t.daysToAmber, closeTo(0.5, 1e-9));
      expect(t.hasForecast, isTrue);
    });

    test('with the floor supplied, no low-side crossing is forecast', () {
      final t = fallingTrend(floor: ammoniaFloor);
      expect(t.direction, TrendDirection.falling); // still measured…
      expect(t.slopeSignificant, isTrue); // …still a real slope…
      expect(t.daysToAmber, isNull); // …but nowhere to cross to.
      expect(t.daysToRed, isNull);
      expect(t.hasForecast, isFalse);
      expect(t.recovering, isFalse);
    });

    test('the high side of the same parameter still forecasts', () {
      // Ammonia rising through green is exactly what a warning is for.
      final rising = series([0.002, 0.006, 0.010, 0.014, 0.018]);
      final t = computeTrend(
        points: rising,
        bounds: ammoniaBounds,
        window: 5,
        now: rising.last.t,
        floor: ammoniaFloor,
      )!;
      expect(t.daysToAmber, closeTo(0.5, 1e-9)); // greenHigh 0.02
      expect(t.daysToRed, closeTo(20.5, 1e-9)); // amberHigh 0.1
    });

    test('a genuine low bound above the floor is untouched', () {
      // Alkalinity's floor is also 0, but its greenLow is 7.5 — a bound the
      // value can and does cross. Supplying the floor must not silence it.
      final pts = series([8.3, 8.2, 8.1, 8.0, 7.9]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
        floor: kParameterByKey['alkalinity']!.minValue,
      )!;
      expect(t.daysToAmber, closeTo(4, 1e-9));
      expect(t.daysToRed, closeTo(9, 1e-9));
    });

    test(
      'an amber low bound on the floor is skipped, greenLow above it is not',
      () {
        // Both low bounds in one fixture: greenLow 1 is real, amberLow 0 is the
        // floor. 1.2 falling 0.1/day reaches greenLow in 2 d and would "reach"
        // amberLow in 12.
        const mixed = ZoneBounds(amberLow: 0, greenLow: 1, greenHigh: 10);
        final pts = series([1.6, 1.5, 1.4, 1.3, 1.2]);
        final t = computeTrend(
          points: pts,
          bounds: mixed,
          window: 5,
          now: pts.last.t,
          floor: 0,
        )!;
        expect(t.daysToAmber, closeTo(2, 1e-9));
        expect(t.daysToRed, isNull);
      },
    );

    group('and no insight warns about it either', () {
      // The dashboard Insights card composes from the same trend, so the
      // suppression has to survive computeInsights — the second half of the
      // user-visible symptom (a chip *and* a card entry).
      List<Insight> insightsFor(TrendResult t) {
        final health = computeTankHealth([
          (
            paramKey: 'ammonia',
            bounds: ammoniaBounds,
            latest: 0.002,
            takenAt: falling.last.t,
          ),
        ], now: falling.last.t);
        expect(health.parameters.single.zone, Zone.green);
        return computeInsights(
          health: health,
          trends: {'ammonia': t},
          bounds: {'ammonia': ammoniaBounds},
          now: falling.last.t,
        );
      }

      test('without the floor, an insight warns of the crossing', () {
        final list = insightsFor(fallingTrend());
        expect(list, hasLength(1));
        expect(list.single.kind, InsightKind.forecast);
        expect(list.single.isLow, isTrue);
        expect(list.single.days, 1);
      });

      test('with the floor, the card stays silent', () {
        expect(insightsFor(fallingTrend(floor: ammoniaFloor)), isEmpty);
      });
    });
  });

  group('recovering values (#25, U15)', () {
    test('a recovering low-amber value forecasts green, not amber/red', () {
      // 7.2 sits in the LOW amber zone and is rising back toward green: the
      // only bounds ahead lie on the far side of green, so no warning is
      // forecast — instead the near green bound (7.5 at 0.05/day) gives the
      // positive "back in range" estimate.
      final pts = series([7.0, 7.05, 7.1, 7.15, 7.2]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
        final pts = series([9.8, 9.7, 9.6, 9.5, 9.4]);
        final t = computeTrend(
          points: pts,
          bounds: bounds,
          window: 5,
          now: pts.last.t,
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
      final pts = series([6.0, 6.1, 6.2, 6.3, 6.4]);
      final t = computeTrend(
        points: pts,
        bounds: const ZoneBounds(amberLow: 7, amberHigh: 10),
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.recovering, isTrue);
      expect(t.daysToGreen, closeTo(6, 1e-9));
    });

    test('a worsening amber value still forecasts the red crossing', () {
      // 9.2 in high amber and still rising: not recovering — red ahead.
      final pts = series([8.8, 8.9, 9.0, 9.1, 9.2]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.recovering, isFalse);
      expect(t.daysToRed, closeTo(8, 1e-9));
      expect(t.daysToGreen, isNull);
    });

    test('an out-of-range value holding flat is not "recovering"', () {
      final pts = series([7.2, 7.2, 7.2, 7.2, 7.2]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
      final pts = series([8.0, 8.2, 8.4, 8.6, 9.05]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
      final pts = series([8.0, 8.1, 8.2, 8.3, 9.05]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
      final pts = series([8.1, 8.2, 8.3, 8.4, 8.5]);
      final t = computeTrend(
        points: pts,
        bounds: inverted,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.direction, TrendDirection.rising);
      expect(t.hasForecast, isFalse);
      expect(t.recovering, isFalse);
    });
  });

  group('slope significance (#31)', () {
    test('a clean drift is significant and still forecasts', () {
      final pts = series([8.5, 8.4, 8.2, 8.1, 7.9, 7.8]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.slopeSignificant, isTrue);
      expect(t.oscillating, isFalse);
      expect(t.hasForecast, isTrue);
      expect(t.sigma, lessThan(0.05)); // hugs the line
    });

    test('an oscillating series forecasts nothing and reports the swing', () {
      // Sawtooth around 8.3 with no underlying drift: the fit finds a slope,
      // but nowhere near its own standard error.
      final pts = series([8.6, 8.0, 8.6, 8.0, 8.6, 8.0]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
      final pts = series([8.30, 8.32, 8.28, 8.31, 8.29, 8.30]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 5,
        now: pts.last.t,
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
      final t = computeTrend(
        points: pts,
        bounds: phBounds,
        window: 5,
        now: pts.last.t,
      )!;
      expect(t.direction, TrendDirection.falling);
      expect(t.slopeSignificant, isFalse);
      expect(t.hasForecast, isFalse);
    });

    test('a two-point fit has nothing to test and keeps forecasting', () {
      final pts = series([8.5, 8.7]);
      final t = computeTrend(
        points: pts,
        bounds: bounds,
        window: 2,
        now: pts.last.t,
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
