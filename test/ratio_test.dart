import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/ratio.dart';
import 'package:reeftracker/domain/zones.dart';

RatioReading _r(double value, int msEpoch) =>
    (takenAt: DateTime.fromMillisecondsSinceEpoch(msEpoch), value: value);

/// A reading on a real (local) calendar day, for the same-day collapsing tests.
RatioReading _at(double value, int day, int hour, int minute) => (
  takenAt: DateTime(2026, 8, day, hour, minute),
  value: value,
);

void main() {
  group('latestRatio (numerator, denominator; newest-first input)', () {
    test('uses the most recent value of each parameter', () {
      // PO₄ : NO₃ -> numerator = phosphate, denominator = nitrate.
      final phosphate = [_r(0.1, 2000), _r(0.2, 1000)];
      final nitrate = [_r(10, 2000), _r(5, 1000)];
      final ratio = latestRatio(phosphate, nitrate);
      expect(ratio, isNotNull);
      expect(ratio!.ratio, closeTo(0.01, 1e-12)); // 0.1 / 10
      expect(ratio.numerator, 0.1);
      expect(ratio.denominator, 10);
    });

    test('null when either parameter is missing', () {
      expect(latestRatio([_r(0.1, 1000)], []), isNull);
      expect(latestRatio([], [_r(10, 1000)]), isNull);
    });

    test('null when denominator is zero (undefined ratio)', () {
      final ratio = latestRatio([_r(0.1, 1000)], [_r(0, 1000)]);
      expect(ratio, isNull);
    });

    test('null when the halves are further apart than maxSkew (#32)', () {
      // Today's PO₄ against a months-old NO₃ is not a "current" ratio.
      const day = 24 * 60 * 60 * 1000;
      final phosphate = [_r(0.1, 100 * day)];
      final staleNitrate = [_r(10, 0)];
      expect(latestRatio(phosphate, staleNitrate), isNull);

      // Within the default 30-day window the pair still counts…
      final recentNitrate = [_r(10, 80 * day)];
      expect(latestRatio(phosphate, recentNitrate), isNotNull);

      // …and the gate is symmetric and tunable.
      expect(latestRatio(staleNitrate, phosphate), isNull);
      expect(
        latestRatio(
          phosphate,
          staleNitrate,
          maxSkew: const Duration(days: 365),
        ),
        isNotNull,
      );
    });
  });

  // The merge/carry-forward semantics, isolated from the same-day collapsing
  // below (all these timestamps share one day) via collapseSameDay: false.
  group('computeRatioSeries (oldest-first input)', () {
    test('carries forward the latest value of the other parameter', () {
      final phosphate = [_r(0.1, 2000)];
      final nitrate = [_r(10, 1000), _r(20, 3000)];
      final series = computeRatioSeries(
        phosphate,
        nitrate,
        collapseSameDay: false,
      );
      // No ratio before phosphate exists; then a point at 2000 and 3000.
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000, 3000]);
      expect(series[0].ratio, closeTo(0.1 / 10, 1e-12));
      expect(series[1].ratio, closeTo(0.1 / 20, 1e-12));
    });

    test('empty when one series is empty', () {
      expect(computeRatioSeries([_r(0.1, 1000)], []), isEmpty);
    });

    test('skips timestamps where denominator is zero', () {
      final phosphate = [_r(0.1, 1000)];
      final nitrate = [_r(0, 1000), _r(10, 2000)];
      final series = computeRatioSeries(
        phosphate,
        nitrate,
        collapseSameDay: false,
      );
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000]);
    });

    // Pins the single-merge-pass rewrite (T15) to the original semantics.
    test('interleaved series produce one point per distinct timestamp', () {
      final phosphate = [_r(0.10, 1000), _r(0.20, 3000), _r(0.30, 5000)];
      final nitrate = [_r(10, 2000), _r(20, 4000)];
      final series = computeRatioSeries(
        phosphate,
        nitrate,
        collapseSameDay: false,
      );
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [
        2000,
        3000,
        4000,
        5000,
      ]);
      expect(series.map((p) => p.ratio), [
        closeTo(0.10 / 10, 1e-12),
        closeTo(0.20 / 10, 1e-12),
        closeTo(0.20 / 20, 1e-12),
        closeTo(0.30 / 20, 1e-12),
      ]);
    });

    test('a timestamp shared by both series merges into one point', () {
      final phosphate = [_r(0.1, 1000), _r(0.2, 2000)];
      final nitrate = [_r(10, 2000)];
      final series = computeRatioSeries(
        phosphate,
        nitrate,
        collapseSameDay: false,
      );
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000]);
      expect(series.single.ratio, closeTo(0.2 / 10, 1e-12));
    });

    test('equal timestamps within one series: the later entry wins', () {
      // Two same-second readings of one parameter (list order = storage
      // order): the point reflects the last one, as before the rewrite.
      final phosphate = [_r(0.1, 1000), _r(0.4, 1000)];
      final nitrate = [_r(10, 1000)];
      final series = computeRatioSeries(
        phosphate,
        nitrate,
        collapseSameDay: false,
      );
      expect(series.single.ratio, closeTo(0.4 / 10, 1e-12));
    });
  });

  group('computeRatioSeries same-day collapsing (#33)', () {
    test('one testing session yields one point, not one per measurement', () {
      // The reported case: a Hanna session stamps NO₃ at 14:15 and PO₄ at
      // 14:20, so the carry-forward used to plot an extra dot pairing the new
      // NO₃ with yesterday's PO₄.
      final phosphate = [_at(0.05, 1, 9, 0), _at(0.03, 2, 14, 20)];
      final nitrate = [_at(5.0, 1, 9, 0), _at(6.0, 2, 14, 15)];
      final series = computeRatioSeries(phosphate, nitrate);
      expect(series.length, 2);
      // Day 2 keeps only the fully-updated pairing, at the later timestamp.
      expect(series.last.time, DateTime(2026, 8, 2, 14, 20));
      expect(series.last.numerator, 0.03);
      expect(series.last.denominator, 6.0);
      expect(series.last.ratio, closeTo(0.03 / 6.0, 1e-12));
    });

    test('measurements on different days stay separate points', () {
      final phosphate = [_at(0.05, 1, 10, 0), _at(0.03, 3, 10, 0)];
      final nitrate = [_at(5.0, 2, 10, 0), _at(6.0, 4, 10, 0)];
      final series = computeRatioSeries(phosphate, nitrate);
      expect(series.map((p) => p.time), [
        DateTime(2026, 8, 2, 10, 0),
        DateTime(2026, 8, 3, 10, 0),
        DateTime(2026, 8, 4, 10, 0),
      ]);
    });

    test('the day boundary is the calendar day, not a fixed gap', () {
      // 23:50 and 00:10 are 20 minutes apart but belong to different days.
      final phosphate = [_at(0.05, 1, 23, 50)];
      final nitrate = [_at(5.0, 1, 23, 50), _at(6.0, 2, 0, 10)];
      final series = computeRatioSeries(phosphate, nitrate);
      expect(series.map((p) => p.time), [
        DateTime(2026, 8, 1, 23, 50),
        DateTime(2026, 8, 2, 0, 10),
      ]);
    });

    test('a later zero denominator does not drop the day it shares', () {
      // The 18:00 pairing is undefined and skipped; the day keeps its valid
      // 09:00 point rather than being emptied by the invalid one.
      final phosphate = [_at(0.05, 1, 9, 0)];
      final nitrate = [_at(5.0, 1, 9, 0), _at(0, 1, 18, 0)];
      final series = computeRatioSeries(phosphate, nitrate);
      expect(series.single.time, DateTime(2026, 8, 1, 9, 0));
      expect(series.single.ratio, closeTo(0.05 / 5.0, 1e-12));
    });
  });

  group('formatRatio', () {
    test('scales precision with magnitude', () {
      expect(formatRatio(150), '150');
      expect(formatRatio(12.3), '12.3');
      expect(formatRatio(1.234), '1.23');
      expect(formatRatio(0.123), '0.123');
      expect(formatRatio(0.0123), '0.0123');
    });
  });

  group('formatRatioValue', () {
    test('PO₄ : NO₃ renders as 1 : N (N = NO₃/PO₄)', () {
      expect(formatRatioValue(RatioKind.po4no3, 0.01), '1 : 100'); // 0.1 / 10
      expect(formatRatioValue(RatioKind.po4no3, 0.02), '1 : 50');
      expect(formatRatioValue(RatioKind.po4no3, 1 / 3), '1 : 3.0');
    });

    test('Mg : Ca renders as a single number to one decimal', () {
      expect(formatRatioValue(RatioKind.mgca, 3.12), '3.1'); // 1300 / 416
      expect(formatRatioValue(RatioKind.mgca, 3.0), '3.0');
      expect(formatRatioValue(RatioKind.mgca, 12.34), '12.3');
    });

    test('returns a dash for undefined ratios', () {
      expect(formatRatioValue(RatioKind.po4no3, 0), '—');
      expect(formatRatioValue(RatioKind.mgca, double.infinity), '—');
    });
  });

  group('ratioBounds', () {
    test('falls back to the kind default when no settings or no bounds', () {
      expect(
        ratioBounds(RatioKind.mgca, null).greenLow,
        RatioKind.mgca.defaultBounds.greenLow,
      );
      const blank = (visible: true, displayOrder: 1000, bounds: ZoneBounds());
      expect(
        ratioBounds(RatioKind.mgca, blank).greenHigh,
        RatioKind.mgca.defaultBounds.greenHigh,
      );
    });

    test('uses the stored bounds when set', () {
      const settings = (
        visible: true,
        displayOrder: 1000,
        bounds: ZoneBounds(
          amberLow: 2.0,
          greenLow: 2.5,
          greenHigh: 3.5,
          amberHigh: 4.0,
        ),
      );
      final b = ratioBounds(RatioKind.mgca, settings);
      expect(b.greenLow, 2.5);
      expect(b.amberHigh, 4.0);
    });
  });

  group('ratioZone', () {
    test('PO₄ : NO₃ classifies on N = NO₃/PO₄ (green ~100)', () {
      final b = RatioKind.po4no3.defaultBounds;
      // ratio = PO4/NO3; N = 1/ratio. Green band N in [50, 150].
      expect(ratioZone(RatioKind.po4no3, b, 1 / 100), Zone.green); // N = 100
      expect(ratioZone(RatioKind.po4no3, b, 1 / 40), Zone.amber); // N = 40
      expect(ratioZone(RatioKind.po4no3, b, 1 / 300), Zone.red); // N = 300
    });

    test('Mg : Ca classifies on Mg/Ca (green ~3.1)', () {
      final b = RatioKind.mgca.defaultBounds;
      expect(ratioZone(RatioKind.mgca, b, 3.1), Zone.green);
      expect(ratioZone(RatioKind.mgca, b, 2.7), Zone.amber);
      expect(ratioZone(RatioKind.mgca, b, 2.4), Zone.red);
    });
  });

  group('ratioChartY', () {
    test('PO₄ : NO₃ plots the inverse (N of 1 : N)', () {
      expect(ratioChartY(RatioKind.po4no3, 0.01), closeTo(100, 1e-9));
    });

    test('Mg : Ca plots the ratio directly', () {
      expect(ratioChartY(RatioKind.mgca, 3.12), closeTo(3.12, 1e-9));
    });
  });
}
