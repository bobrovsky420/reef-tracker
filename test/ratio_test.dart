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
  group('latestRatio (newest-first input)', () {
    test('uses the most recent value of each parameter', () {
      final nitrate = [_r(kNitrateKey, 10, 2000), _r(kNitrateKey, 5, 1000)];
      final phosphate = [_r(kPhosphateKey, 0.1, 2000), _r(kPhosphateKey, 0.2, 1000)];
      final ratio = latestRatio(nitrate, phosphate);
      expect(ratio, isNotNull);
      expect(ratio!.ratio, closeTo(0.01, 1e-12)); // 0.1 / 10
      expect(ratio.nitrate, 10);
      expect(ratio.phosphate, 0.1);
    });

    test('null when either parameter is missing', () {
      expect(latestRatio([], [_r(kPhosphateKey, 0.1, 1000)]), isNull);
      expect(latestRatio([_r(kNitrateKey, 10, 1000)], []), isNull);
    });

    test('null when nitrate is zero (undefined ratio)', () {
      final ratio = latestRatio(
          [_r(kNitrateKey, 0, 1000)], [_r(kPhosphateKey, 0.1, 1000)]);
      expect(ratio, isNull);
    });
  });

  group('computeRatioSeries (oldest-first input)', () {
    test('carries forward the latest value of the other parameter', () {
      final nitrate = [_r(kNitrateKey, 10, 1000), _r(kNitrateKey, 20, 3000)];
      final phosphate = [_r(kPhosphateKey, 0.1, 2000)];
      final series = computeRatioSeries(nitrate, phosphate);
      // No ratio before phosphate exists; then a point at 2000 and 3000.
      expect(series.map((p) => p.time.millisecondsSinceEpoch), [2000, 3000]);
      expect(series[0].ratio, closeTo(0.1 / 10, 1e-12));
      expect(series[1].ratio, closeTo(0.1 / 20, 1e-12));
    });

    test('empty when one series is empty', () {
      expect(computeRatioSeries([], [_r(kPhosphateKey, 0.1, 1000)]), isEmpty);
    });

    test('skips timestamps where nitrate is zero', () {
      final nitrate = [_r(kNitrateKey, 0, 1000), _r(kNitrateKey, 10, 2000)];
      final phosphate = [_r(kPhosphateKey, 0.1, 1000)];
      final series = computeRatioSeries(nitrate, phosphate);
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

  group('formatRatioOneToN', () {
    test('renders PO4/NO3 ratio as 1 : N (N = NO3/PO4)', () {
      expect(formatRatioOneToN(0.01), '1 : 100'); // 0.1 / 10
      expect(formatRatioOneToN(0.02), '1 : 50');
      expect(formatRatioOneToN(1 / 3), '1 : 3.0'); // small N keeps a decimal
      expect(formatRatioOneToN(0.5), '1 : 2.0');
    });

    test('returns a dash for non-positive or non-finite ratios', () {
      expect(formatRatioOneToN(0), '—');
      expect(formatRatioOneToN(double.infinity), '—');
    });
  });
}
