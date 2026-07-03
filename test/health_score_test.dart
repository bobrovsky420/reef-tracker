import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/health_score.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  // A comfortable alkalinity range used across the cases below.
  const alkBounds = ZoneBounds(
    amberLow: 7,
    greenLow: 7.5,
    greenHigh: 8.5,
    amberHigh: 9,
  );

  final now = DateTime(2026, 6, 1, 12);

  HealthInput input(
    String key,
    ZoneBounds bounds, {
    double? value,
    DateTime? takenAt,
  }) => (paramKey: key, bounds: bounds, latest: value, takenAt: takenAt ?? now);

  group('computeTankHealth — no scorable data', () {
    test('empty input scores nothing', () {
      final h = computeTankHealth(const [], now: DateTime(2026, 6, 1));
      expect(h.score, isNull);
      expect(h.hasData, isFalse);
      expect(h.band, Zone.unknown);
      expect(h.grade, HealthGrade.unknown);
    });

    test('a parameter with no reading is not scored', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: null),
      ], now: now);
      expect(h.score, isNull);
      expect(h.parameters.single.includedInScore, isFalse);
      expect(h.notScored.single.paramKey, 'alkalinity');
    });

    test('a parameter with no usable bounds is not scored', () {
      final h = computeTankHealth([
        input('ph', const ZoneBounds(), value: 8.1),
      ], now: now);
      expect(h.score, isNull);
      expect(h.parameters.single.zone, Zone.unknown);
      expect(h.parameters.single.includedInScore, isFalse);
    });
  });

  group('computeTankHealth — banding & grades', () {
    test('a centred green reading scores 100 / excellent', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0),
      ], now: now);
      expect(h.score, 100);
      expect(h.band, Zone.green);
      expect(h.grade, HealthGrade.excellent);
      expect(h.offenders, isEmpty);
      expect(h.healthy.single.paramKey, 'alkalinity');
    });

    test('one red caps the whole tank into the red band despite greens', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // centred green, weight 3
        input(
          'nitrate',
          const ZoneBounds(greenHigh: 10, amberHigh: 20),
          value: 100,
        ), // far red, weight 2
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
        input(
          'phosphate',
          const ZoneBounds(greenHigh: 0.05, amberHigh: 0.1),
          value: 0.08,
        ), // amber
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
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0, takenAt: stale),
      ], now: now);
      expect(h.score, isNull); // its only reading was stale
      final p = h.parameters.single;
      expect(p.stale, isTrue);
      expect(p.includedInScore, isFalse);
      expect(h.notScored.single.paramKey, 'alkalinity');
    });

    test('a reading exactly at the freshness boundary is still fresh', () {
      // daysSince rounds; exactly `freshnessDays` days old is NOT `> freshness`.
      final boundary = now.subtract(const Duration(days: kHealthFreshnessDays));
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0, takenAt: boundary),
      ], now: now);
      expect(h.parameters.single.stale, isFalse);
      expect(h.score, 100);
    });

    test('a fresh reading past the boundary flips to stale', () {
      final justPast = now.subtract(
        const Duration(days: kHealthFreshnessDays + 1),
      );
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0, takenAt: justPast),
      ], now: now);
      expect(h.parameters.single.stale, isTrue);
      expect(h.score, isNull);
    });

    test('every parameter stale -> no score, unknown band and grade', () {
      final old = now.subtract(const Duration(days: 45));
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0, takenAt: old),
        input(
          'calcium',
          const ZoneBounds(greenLow: 400, greenHigh: 450),
          value: 420,
          takenAt: old,
        ),
      ], now: now);
      expect(h.score, isNull);
      expect(h.band, Zone.unknown);
      expect(h.grade, HealthGrade.unknown);
      expect(h.notScored, hasLength(2));
      expect(h.parameters.every((p) => p.stale), isTrue);
    });

    test('a value with no timestamp is stale, not eternally fresh (#29)', () {
      // HealthInput permits latest != null with takenAt == null; freshness
      // can't be verified then, so the reading must not be scored.
      final h = computeTankHealth([
        (paramKey: 'alkalinity', bounds: alkBounds, latest: 8.0, takenAt: null),
      ], now: now);
      expect(h.score, isNull);
      final p = h.parameters.single;
      expect(p.stale, isTrue);
      expect(p.includedInScore, isFalse);
    });

    test('no value and no timestamp is "no reading", not stale', () {
      final h = computeTankHealth([
        (
          paramKey: 'alkalinity',
          bounds: alkBounds,
          latest: null,
          takenAt: null,
        ),
      ], now: now);
      expect(h.parameters.single.stale, isFalse);
      expect(h.parameters.single.includedInScore, isFalse);
    });

    test('a stale parameter does not drag down a fresh green score', () {
      final h = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // fresh, centred green
        input(
          'calcium',
          const ZoneBounds(greenLow: 400, greenHigh: 450),
          value: 100,
          takenAt: now.subtract(const Duration(days: 60)),
        ),
      ], now: now);
      // The stale (and out-of-range) calcium is excluded; only alk is scored.
      expect(h.score, 100);
      expect(h.band, Zone.green);
      expect(h.notScored.single.paramKey, 'calcium');
    });
  });

  group('computeTankHealth — sub-score shape', () {
    test('deeper red scores lower (depth gradient)', () {
      // Both readings are red below amberLow (7); depth is measured in
      // amber-band widths (greenLow − amberLow = 0.5).
      final shallow = computeTankHealth([
        input('alkalinity', alkBounds, value: 6.9),
      ], now: now);
      final deep = computeTankHealth([
        input('alkalinity', alkBounds, value: 6.5),
      ], now: now);
      expect(shallow.band, Zone.red);
      expect(deep.band, Zone.red);
      expect(shallow.score, 31); // 0.2 widths past the bound: 39 − 39·0.2
      expect(deep.score, 0); // a full width past amberLow bottoms out
      expect(shallow.score!, greaterThan(deep.score!));
    });

    test('amber with no matching amber bound falls back to 55', () {
      // Below greenLow with no amberLow: distance can't be normalized, so the
      // sub-score is the flat mid-amber 55.
      const greensOnly = ZoneBounds(greenLow: 7.5, greenHigh: 8.5);
      final h = computeTankHealth([
        input('alkalinity', greensOnly, value: 7.2),
      ], now: now);
      expect(h.band, Zone.amber);
      expect(h.score, 55);
    });

    test('red with no green bound to measure a width falls back to 20', () {
      // Above amberHigh with no greenHigh: no amber-band width exists, so the
      // sub-score is the flat deep-red 20.
      const amberHighOnly = ZoneBounds(amberHigh: 10);
      final h = computeTankHealth([
        input('nitrate', amberHighOnly, value: 11),
      ], now: now);
      expect(h.band, Zone.red);
      expect(h.score, 20);
    });
  });

  group('computeTankHealth — exact band boundaries', () {
    test('score 70 is green/good; 69 is amber/caution', () {
      // A green value hugging its bound scores exactly 70 — the green floor.
      const wide = ZoneBounds(greenLow: 0, greenHigh: 100);
      final at70 = computeTankHealth([input('kh', wide, value: 100)], now: now);
      expect(at70.score, 70);
      expect(at70.band, Zone.green);
      expect(at70.grade, HealthGrade.good);

      // One amber present: the worst-zone ceiling clamps an otherwise-high
      // weighted mean (≈85) down to exactly 69, the top of the amber band.
      final at69 = computeTankHealth([
        input('alkalinity', alkBounds, value: 8.0), // 100, weight 3
        input(
          'phosphate',
          const ZoneBounds(greenHigh: 0.05, amberHigh: 0.1),
          value: 0.06,
        ), // amber 63.2, weight 2
      ], now: now);
      expect(at69.score, 69);
      expect(at69.band, Zone.amber);
      expect(at69.grade, HealthGrade.caution);
    });

    test('score 40 is amber/caution; 39 is red/critical', () {
      // Exactly on amberHigh classifies amber and scores the amber floor, 40.
      final at40 = computeTankHealth([
        input('alkalinity', alkBounds, value: 9.0),
      ], now: now);
      expect(at40.score, 40);
      expect(at40.band, Zone.amber);
      expect(at40.grade, HealthGrade.caution);

      // Barely past amberLow rounds to 39, the top of the red band.
      final at39 = computeTankHealth([
        input('alkalinity', alkBounds, value: 6.999),
      ], now: now);
      expect(at39.score, 39);
      expect(at39.band, Zone.red);
      expect(at39.grade, HealthGrade.critical);
    });
  });

  test('value equality: identical recomputes are equal (T2)', () {
    final inputs = [
      input('alkalinity', alkBounds, value: 8.5),
      input(
        'salinity',
        const ZoneBounds(greenLow: 33, greenHigh: 35),
        value: 34,
      ),
    ];
    final a = computeTankHealth(inputs, now: now);
    final b = computeTankHealth(inputs, now: now);
    expect(a, isNot(same(b)));
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    // A genuinely different health still compares unequal.
    final c = computeTankHealth([
      input('alkalinity', alkBounds, value: 9.5),
    ], now: now);
    expect(a, isNot(equals(c)));
  });

  test('importance weighting lets a heavy param dominate a light one', () {
    // salinity (weight 3) sits centred green (100); a default-weight (1)
    // parameter sits at an amber edge. With the amber ceiling removed by using
    // a green light param instead, the heavy green should pull the mean high.
    final heavyGreenLightLower = computeTankHealth([
      input(
        'salinity',
        const ZoneBounds(greenLow: 33, greenHigh: 35),
        value: 34,
      ), // heavy, centred green -> 100
      input(
        'kh_extra',
        const ZoneBounds(greenLow: 0, greenHigh: 100),
        value: 100,
      ), // light, green but hugging the top edge -> 70
    ], now: now);
    // Weighted mean: (3*100 + 1*70) / 4 = 92.5 -> 93, well above the unweighted
    // mean of 85, proving the heavy parameter dominates.
    expect(heavyGreenLightLower.score, greaterThan(85));
    expect(heavyGreenLightLower.band, Zone.green);
  });
}
