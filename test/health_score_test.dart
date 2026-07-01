import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/health_score.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  // A comfortable alkalinity range used across the cases below.
  const alkBounds =
      ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);

  final now = DateTime(2026, 6, 1, 12);

  HealthInput input(
    String key,
    ZoneBounds bounds, {
    double? value,
    DateTime? takenAt,
  }) =>
      (paramKey: key, bounds: bounds, latest: value, takenAt: takenAt ?? now);

  group('computeTankHealth — no scorable data', () {
    test('empty input scores nothing', () {
      final h = computeTankHealth(const [], now: DateTime(2026, 6, 1));
      expect(h.score, isNull);
      expect(h.hasData, isFalse);
      expect(h.band, Zone.unknown);
      expect(h.grade, HealthGrade.unknown);
    });

    test('a parameter with no reading is not scored', () {
      final h = computeTankHealth([input('alkalinity', alkBounds, value: null)],
          now: now);
      expect(h.score, isNull);
      expect(h.parameters.single.includedInScore, isFalse);
      expect(h.notScored.single.paramKey, 'alkalinity');
    });

    test('a parameter with no usable bounds is not scored', () {
      final h = computeTankHealth(
          [input('ph', const ZoneBounds(), value: 8.1)],
          now: now);
      expect(h.score, isNull);
      expect(h.parameters.single.zone, Zone.unknown);
      expect(h.parameters.single.includedInScore, isFalse);
    });
  });

  group('computeTankHealth — banding & grades', () {
    test('a centred green reading scores 100 / excellent', () {
      final h = computeTankHealth([input('alkalinity', alkBounds, value: 8.0)],
          now: now);
      expect(h.score, 100);
      expect(h.band, Zone.green);
      expect(h.grade, HealthGrade.excellent);
      expect(h.offenders, isEmpty);
      expect(h.healthy.single.paramKey, 'alkalinity');
    });

    test('one red caps the whole tank into the red band despite greens', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // centred green, weight 3
        input('nitrate', const ZoneBounds(greenHigh: 10, amberHigh: 20),
            value: 100), // far red, weight 2
      ], now: now);
      // Worst-zone ceiling clamps the aggregate into the red band regardless of
      // how healthy the other parameter is.
      expect(h.band, Zone.red);
      expect(h.score, lessThanOrEqualTo(39));
      expect(h.grade, HealthGrade.critical);
      expect(h.offenders.map((p) => p.paramKey), contains('nitrate'));
    });

    test('one amber (no red) caps into the amber band / caution', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // green
        input('phosphate', const ZoneBounds(greenHigh: 0.05, amberHigh: 0.1),
            value: 0.08), // amber
      ], now: now);
      expect(h.band, Zone.amber);
      expect(h.score, inInclusiveRange(40, 69));
      expect(h.grade, HealthGrade.caution);
      expect(h.offenders.single.paramKey, 'phosphate');
    });
  });

  group('computeTankHealth — staleness', () {
    test('a reading older than the freshness window is excluded', () {
      final stale = now.subtract(const Duration(days: 40));
      final h = computeTankHealth(
          [input('alkalinity', alkBounds, value: 8.0, takenAt: stale)],
          now: now);
      expect(h.score, isNull); // its only reading was stale
      final p = h.parameters.single;
      expect(p.stale, isTrue);
      expect(p.includedInScore, isFalse);
      expect(h.notScored.single.paramKey, 'alkalinity');
    });

    test('a reading exactly at the freshness boundary is still fresh', () {
      // daysSince rounds; exactly `freshnessDays` days old is NOT `> freshness`.
      final boundary = now.subtract(const Duration(days: kHealthFreshnessDays));
      final h = computeTankHealth(
          [input('alkalinity', alkBounds, value: 8.0, takenAt: boundary)],
          now: now);
      expect(h.parameters.single.stale, isFalse);
      expect(h.score, 100);
    });

    test('a fresh reading past the boundary flips to stale', () {
      final justPast =
          now.subtract(const Duration(days: kHealthFreshnessDays + 1));
      final h = computeTankHealth(
          [input('alkalinity', alkBounds, value: 8.0, takenAt: justPast)],
          now: now);
      expect(h.parameters.single.stale, isTrue);
      expect(h.score, isNull);
    });

    test('a stale parameter does not drag down a fresh green score', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // fresh, centred green
        input('calcium', const ZoneBounds(greenLow: 400, greenHigh: 450),
            value: 100, takenAt: now.subtract(const Duration(days: 60))),
      ], now: now);
      // The stale (and out-of-range) calcium is excluded; only alk is scored.
      expect(h.score, 100);
      expect(h.band, Zone.green);
      expect(h.notScored.single.paramKey, 'calcium');
    });
  });

  test('importance weighting lets a heavy param dominate a light one', () {
    // salinity (weight 3) sits centred green (100); a default-weight (1)
    // parameter sits at an amber edge. With the amber ceiling removed by using
    // a green light param instead, the heavy green should pull the mean high.
    final heavyGreenLightLower = computeTankHealth([
      input('salinity', const ZoneBounds(greenLow: 33, greenHigh: 35),
          value: 34), // heavy, centred green -> 100
      input('kh_extra', const ZoneBounds(greenLow: 0, greenHigh: 100),
          value: 100), // light, green but hugging the top edge -> 70
    ], now: now);
    // Weighted mean: (3*100 + 1*70) / 4 = 92.5 -> 93, well above the unweighted
    // mean of 85, proving the heavy parameter dominates.
    expect(heavyGreenLightLower.score, greaterThan(85));
    expect(heavyGreenLightLower.band, Zone.green);
  });
}
