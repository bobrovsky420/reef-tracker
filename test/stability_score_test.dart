import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/stability_score.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  final now = DateTime(2026, 7, 14, 12);

  // Alkalinity-like bounds: green 7–9 (half-width 1), amber 6–10.
  const bounds = ZoneBounds(
    amberLow: 6,
    greenLow: 7,
    greenHigh: 9,
    amberHigh: 10,
  );

  List<DosePoint> series(List<double> values, {int stepDays = 3}) => [
    for (var i = 0; i < values.length; i++)
      (
        t: now.subtract(Duration(days: (values.length - 1 - i) * stepDays)),
        value: values[i],
      ),
  ];

  StabilityInput input(List<DosePoint> pts, {String key = 'alkalinity'}) =>
      (paramKey: key, bounds: bounds, points: pts);

  group('computeTankStability', () {
    test('a flat series scores 100 / rock solid', () {
      final r = computeTankStability([
        input(series([8, 8, 8, 8, 8])),
      ], now: now);
      expect(r.score, 100);
      expect(r.grade, StabilityGrade.rockSolid);
      expect(r.band, Zone.green);
      expect(r.parameters.single.includedInScore, isTrue);
      expect(r.parameters.single.sigma, closeTo(0, 1e-9));
    });

    test('a steady linear drift is a trend, not an oscillation', () {
      // 8.8 -> 7.2, perfectly linear: detrending leaves zero residual.
      final r = computeTankStability([
        input(series([8.8, 8.4, 8.0, 7.6, 7.2])),
      ], now: now);
      expect(r.score, 100);
    });

    test('swings comparable to the green half-band score low', () {
      // Alternating 7.0 / 9.0 around a flat mean: residual RMS ≈ 1 = the
      // half-band, i.e. full-scale oscillation.
      final r = computeTankStability([
        input(series([7, 9, 7, 9, 7, 9])),
      ], now: now);
      expect(r.score, lessThan(40));
      expect(r.grade, StabilityGrade.unstable);
      expect(r.band, Zone.red);
    });

    test('small swings inside the deadband still score 100', () {
      // ±0.05 around 8: 5% of the half-band, within test-kit noise.
      final r = computeTankStability([
        input(series([8.05, 7.95, 8.05, 7.95, 8.05])),
      ], now: now);
      expect(r.score, 100);
    });

    test('fewer than kStabilityMinReadings readings are not scored', () {
      final r = computeTankStability([
        input(series([8, 9])),
      ], now: now);
      expect(r.hasData, isFalse);
      expect(r.grade, StabilityGrade.unknown);
      expect(r.band, Zone.unknown);
      expect(r.parameters.single.includedInScore, isFalse);
      expect(r.parameters.single.sampleCount, 2);
    });

    test('a burst of tests inside the minimum span is not scored', () {
      // Three tests within one day measure kit repeatability, not the tank.
      final pts = [
        (t: now.subtract(const Duration(hours: 20)), value: 8.0),
        (t: now.subtract(const Duration(hours: 10)), value: 8.6),
        (t: now, value: 7.4),
      ];
      final r = computeTankStability([input(pts)], now: now);
      expect(r.hasData, isFalse);
      expect(r.parameters.single.includedInScore, isFalse);
    });

    test('readings outside the window are ignored', () {
      // A wildly swinging history older than the window plus a calm recent
      // series: only the recent one counts.
      final old = [
        (t: now.subtract(const Duration(days: 90)), value: 6.0),
        (t: now.subtract(const Duration(days: 80)), value: 10.0),
        (t: now.subtract(const Duration(days: 70)), value: 6.0),
      ];
      final r = computeTankStability([
        input([
          ...old,
          ...series([8, 8, 8, 8]),
        ]),
      ], now: now);
      expect(r.score, 100);
      expect(r.parameters.single.sampleCount, 4);
    });

    test('only stale-window readings mean no data at all', () {
      final old = [
        (t: now.subtract(const Duration(days: 90)), value: 8.0),
        (t: now.subtract(const Duration(days: 80)), value: 8.0),
        (t: now.subtract(const Duration(days: 70)), value: 8.0),
      ];
      final r = computeTankStability([input(old)], now: now);
      expect(r.hasData, isFalse);
      expect(r.parameters.single.sampleCount, 0);
    });

    test('unusable bounds exclude the parameter', () {
      const open = ZoneBounds(
        amberLow: null,
        greenLow: null,
        greenHigh: null,
        amberHigh: null,
      );
      final r = computeTankStability([
        (paramKey: 'orp', bounds: open, points: series([300, 310, 305, 300])),
      ], now: now);
      expect(r.hasData, isFalse);
      expect(r.parameters.single.includedInScore, isFalse);
    });

    test('a one-sided green range scales by its green→amber gap', () {
      // Ammonia-like: green up to 0.05, amber up to 0.2 (gap 0.15).
      const oneSided = ZoneBounds(
        amberLow: null,
        greenLow: null,
        greenHigh: 0.05,
        amberHigh: 0.2,
      );
      final calm = computeTankStability([
        (
          paramKey: 'ammonia',
          bounds: oneSided,
          points: series([0.0, 0.01, 0.0, 0.01]),
        ),
      ], now: now);
      expect(calm.hasData, isTrue);
      expect(calm.score, greaterThanOrEqualTo(85));

      final wild = computeTankStability([
        (
          paramKey: 'ammonia',
          bounds: oneSided,
          points: series([0.0, 0.3, 0.0, 0.3, 0.0, 0.3]),
        ),
      ], now: now);
      expect(wild.score, lessThan(40));
    });

    test('one hard-swinging parameter caps the aggregate at 69', () {
      final r = computeTankStability([
        input(series([7, 9, 7, 9, 7, 9])), // unstable (sub < 40)
        input(series([8, 8, 8, 8]), key: 'calcium'),
        input(series([8, 8, 8, 8]), key: 'magnesium'),
        input(series([8, 8, 8, 8]), key: 'nitrate'),
        input(series([8, 8, 8, 8]), key: 'phosphate'),
        input(series([8, 8, 8, 8]), key: 'temperature'),
      ], now: now);
      expect(r.score, lessThanOrEqualTo(69));
      expect(r.band, isNot(Zone.green));
    });

    test('mostVariable is ordered worst-first, steady keeps input order', () {
      final r = computeTankStability([
        input(series([7.5, 8.5, 7.5, 8.5, 7.5]), key: 'calcium'), // moderate
        input(series([7, 9, 7, 9, 7, 9])), // alkalinity, worst
        input(series([8, 8, 8, 8]), key: 'nitrate'), // steady
      ], now: now);
      expect(r.mostVariable.map((p) => p.paramKey), ['alkalinity', 'calcium']);
      expect(r.steady.map((p) => p.paramKey), ['nitrate']);
    });

    test('a wider window admits older readings (the 60/90-day setting)', () {
      // Monthly-ish cadence: only one reading falls inside 30 d, so the
      // default window can't score — 90 d can.
      final pts = [
        (t: now.subtract(const Duration(days: 80)), value: 8.0),
        (t: now.subtract(const Duration(days: 50)), value: 8.0),
        (t: now.subtract(const Duration(days: 10)), value: 8.0),
      ];
      final d30 = computeTankStability([input(pts)], now: now);
      expect(d30.hasData, isFalse);
      expect(d30.parameters.single.sampleCount, 1);

      final d90 = computeTankStability([input(pts)], now: now, windowDays: 90);
      expect(d90.score, 100);
      expect(d90.parameters.single.sampleCount, 3);
    });

    test('value equality holds across recomputation (T2)', () {
      final inputs = [
        input(series([8, 8.2, 7.9, 8.1])),
      ];
      final a = computeTankStability(inputs, now: now);
      final b = computeTankStability(inputs, now: now);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('input order does not matter — the domain sorts', () {
      // The stability provider feeds points newest-first and relies on this
      // sort; removing it as "redundant" would make the span guard see a
      // negative span and every parameter report "not enough data".
      final oldestFirst = series([7.6, 8.4, 7.8, 8.2, 8.0]);
      final newestFirst = oldestFirst.reversed.toList();
      final shuffled = [
        oldestFirst[2],
        oldestFirst[4],
        oldestFirst[0],
        oldestFirst[3],
        oldestFirst[1],
      ];

      final canonical = computeTankStability([input(oldestFirst)], now: now);
      expect(canonical.hasData, isTrue);
      for (final variant in [newestFirst, shuffled]) {
        final r = computeTankStability([input(variant)], now: now);
        expect(r, canonical);
        expect(r.parameters.single.includedInScore, isTrue);
      }
    });
  });

  group('trend ↔ stability swing-threshold agreement', () {
    // kTrendOscillationRelative (0.37) is documented as "the relative
    // oscillation at which the stability score drops a sub-score below 70",
    // so the TrendChip's "swinging" verdict and the stability sheet's
    // "variable" list agree about which parameters swing noticeably. The
    // stability constants (_kDeadband/_kFullScale) are private, so the
    // agreement is probed behaviourally, just above and just below the
    // threshold. Strictly above/below only: at exactly 0.37 the two already
    // differ (trend's >= vs stability's < 70), which is accepted.
    //
    // Both aggregates run over the identical point set (trend window == full
    // series, no widening at 3-day spacing) and share linearFit and the
    // n-2-df residual RMS, so their sigma — and therefore the relative
    // swing — is the same number.
    TrendResult? trendFor(List<DosePoint> pts) =>
        computeTrend(points: pts, bounds: bounds, window: pts.length);

    List<DosePoint> alternating(double amplitude) => series([
      for (var i = 0; i < 6; i++) 8 + (i.isEven ? amplitude : -amplitude),
    ]);

    test(
      'just above the threshold: trend says oscillating, stability says variable',
      () {
        final pts = alternating(0.34);
        final trend = trendFor(pts)!;
        final stability = computeTankStability([input(pts)], now: now);
        final param = stability.parameters.single;

        // Same sigma from both aggregates — the shared definition of the swing.
        expect(param.sigma, isNotNull);
        expect(trend.sigma, closeTo(param.sigma!, 1e-9));
        // Self-check the probe actually landed just above the threshold.
        expect(trend.relativeSwing, greaterThan(kTrendOscillationRelative));
        expect(trend.relativeSwing, lessThan(kTrendOscillationRelative + 0.08));

        expect(trend.slopeSignificant, isFalse);
        expect(trend.oscillating, isTrue);
        expect(param.subScore, lessThan(70)); // "variable" in the breakdown
        expect(stability.mostVariable.single.paramKey, 'alkalinity');
      },
    );

    test('just below the threshold: neither feature calls it swinging', () {
      final pts = alternating(0.28);
      final trend = trendFor(pts)!;
      final stability = computeTankStability([input(pts)], now: now);
      final param = stability.parameters.single;

      expect(trend.relativeSwing, lessThan(kTrendOscillationRelative));
      expect(
        trend.relativeSwing,
        greaterThan(kTrendOscillationRelative - 0.08),
      );

      expect(trend.oscillating, isFalse);
      expect(param.subScore, greaterThanOrEqualTo(70));
      expect(stability.steady.single.paramKey, 'alkalinity');
    });
  });
}
