import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/ratio.dart';
import 'package:reeftracker/domain/zones.dart';

Reading _r(String key, double value, int msEpoch) => Reading(
      id: msEpoch,
      tankId: 1,
      paramKey: key,
      value: value,
      takenAt: DateTime.fromMillisecondsSinceEpoch(msEpoch),
      note: null,
    );

void main() {
  group('latestRatio (numerator, denominator; newest-first input)', () {
    test('uses the most recent value of each parameter', () {
      // PO₄ : NO₃ -> numerator = phosphate, denominator = nitrate.
      final phosphate = [
        _r(kPhosphateKey, 0.1, 2000),
        _r(kPhosphateKey, 0.2, 1000)
      ];
      final nitrate = [_r(kNitrateKey, 10, 2000), _r(kNitrateKey, 5, 1000)];
      final ratio = latestRatio(phosphate, nitrate);
      expect(ratio, isNotNull);
      expect(ratio!.ratio, closeTo(0.01, 1e-12)); // 0.1 / 10
      expect(ratio.numerator, 0.1);
      expect(ratio.denominator, 10);
    });

    test('null when either parameter is missing', () {
      expect(latestRatio([_r(kPhosphateKey, 0.1, 1000)], []), isNull);
      expect(latestRatio([], [_r(kNitrateKey, 10, 1000)]), isNull);
    });

    test('null when denominator is zero (undefined ratio)', () {
      final ratio = latestRatio(
          [_r(kPhosphateKey, 0.1, 1000)], [_r(kNitrateKey, 0, 1000)]);
      expect(ratio, isNull);
    });

    test('null when the halves are further apart than maxSkew (#32)', () {
      // Today's PO₄ against a months-old NO₃ is not a "current" ratio.
      const day = 24 * 60 * 60 * 1000;
      final phosphate = [_r(kPhosphateKey, 0.1, 100 * day)];
      final staleNitrate = [_r(kNitrateKey, 10, 0)];
      expect(latestRatio(phosphate, staleNitrate), isNull);

      // Within the default 30-day window the pair still counts…
      final recentNitrate = [_r(kNitrateKey, 10, 80 * day)];
      expect(latestRatio(phosphate, recentNitrate), isNotNull);

      // …and the gate is symmetric and tunable.
      expect(latestRatio(staleNitrate, phosphate), isNull);
      expect(
        latestRatio(phosphate, staleNitrate,
            maxSkew: const Duration(days: 365)),
        isNotNull,
      );
    });
  });

  group('computeRatioSeries (oldest-first input)', () {
    test('carries forward the latest value of the other parameter', () {
      final phosphate = [_r(kPhosphateKey, 0.1, 2000)];
      final nitrate = [_r(kNitrateKey, 10, 1000), _r(kNitrateKey, 20, 3000)];
      final series = computeRatioSeries(phosphate, nitrate);
      // No ratio before phosphate exists; then a point at 2000 and 3000.
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000, 3000]);
      expect(series[0].ratio, closeTo(0.1 / 10, 1e-12));
      expect(series[1].ratio, closeTo(0.1 / 20, 1e-12));
    });

    test('empty when one series is empty', () {
      expect(computeRatioSeries([_r(kPhosphateKey, 0.1, 1000)], []), isEmpty);
    });

    test('skips timestamps where denominator is zero', () {
      final phosphate = [_r(kPhosphateKey, 0.1, 1000)];
      final nitrate = [_r(kNitrateKey, 0, 1000), _r(kNitrateKey, 10, 2000)];
      final series = computeRatioSeries(phosphate, nitrate);
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000]);
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
    test('falls back to the kind default when no row or no bounds', () {
      expect(ratioBounds(RatioKind.mgca, null).greenLow,
          RatioKind.mgca.defaultBounds.greenLow);
      final blank = const RatioVisibility(
          tankId: 1, ratioKey: 'mgca', visible: true, displayOrder: 1000);
      expect(ratioBounds(RatioKind.mgca, blank).greenHigh,
          RatioKind.mgca.defaultBounds.greenHigh);
    });

    test('uses the row bounds when set', () {
      final row = const RatioVisibility(
        tankId: 1,
        ratioKey: 'mgca',
        visible: true,
        displayOrder: 1000,
        amberLow: 2.0,
        greenLow: 2.5,
        greenHigh: 3.5,
        amberHigh: 4.0,
      );
      final b = ratioBounds(RatioKind.mgca, row);
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
