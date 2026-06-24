import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/ratio.dart';

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

    test('Mg : Ca renders as N : 1 (N = Mg/Ca)', () {
      expect(formatRatioValue(RatioKind.mgca, 3.12), '3.1 : 1'); // 1300 / 416
      expect(formatRatioValue(RatioKind.mgca, 3.0), '3.0 : 1');
    });

    test('returns a dash for non-positive or non-finite ratios', () {
      expect(formatRatioValue(RatioKind.po4no3, 0), '—');
      expect(formatRatioValue(RatioKind.mgca, double.infinity), '—');
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
