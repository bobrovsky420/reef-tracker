import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';

void main() {
  group('kReefParameters catalog integrity', () {
    test('keys are unique', () {
      final keys = kReefParameters.map((p) => p.key).toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason: 'duplicate parameter key in catalog',
      );
    });

    test('kParameterByKey indexes every parameter', () {
      expect(kParameterByKey.length, kReefParameters.length);
      for (final p in kReefParameters) {
        expect(kParameterByKey[p.key], same(p));
      }
    });

    test('every definition is well-formed', () {
      for (final p in kReefParameters) {
        expect(p.key, isNotEmpty, reason: 'empty key');
        expect(p.key.trim(), p.key, reason: '${p.key} has surrounding space');
        expect(p.unit, isNotEmpty, reason: '${p.key} has empty unit');
        expect(
          p.decimals,
          greaterThanOrEqualTo(0),
          reason: '${p.key} has negative decimals',
        );
        expect(
          p.decimals,
          lessThanOrEqualTo(4),
          reason: '${p.key} has implausible decimals',
        );
      }
    });
  });

  group('checkParamValue (#31)', () {
    test('values inside the plausible range are ok', () {
      expect(checkParamValue('magnesium', 1300), ParamValueCheck.ok);
      expect(checkParamValue('calcium', 420), ParamValueCheck.ok);
      expect(checkParamValue('salinity', 1.026), ParamValueCheck.ok);
      expect(checkParamValue('temperature', 25.5), ParamValueCheck.ok);
      expect(checkParamValue('phosphate', 0.03), ParamValueCheck.ok);
      expect(checkParamValue('alkalinity', 8.2), ParamValueCheck.ok);
    });

    test('values below the hard floor are impossible', () {
      // Negative concentration — a stray minus sign (#31).
      expect(checkParamValue('calcium', -420), ParamValueCheck.impossible);
      expect(checkParamValue('phosphate', -0.1), ParamValueCheck.impossible);
      // SG below pure water.
      expect(checkParamValue('salinity', 0.9), ParamValueCheck.impossible);
      expect(checkParamValue('temperature', -3), ParamValueCheck.impossible);
    });

    test('non-finite values are impossible', () {
      expect(
        checkParamValue('calcium', double.nan),
        ParamValueCheck.impossible,
      );
      expect(
        checkParamValue('calcium', double.infinity),
        ParamValueCheck.impossible,
      );
    });

    test('locale mis-parse magnitudes land outside the plausible range', () {
      // "1,300" read as 1.3 ppm Mg, and the reverse 1300-fold overshoot.
      expect(checkParamValue('magnesium', 1.3), ParamValueCheck.implausible);
      expect(checkParamValue('magnesium', 13000), ParamValueCheck.implausible);
      // "1.025" SG read as 1025.
      expect(checkParamValue('salinity', 1025), ParamValueCheck.implausible);
      // "4.2" typed where 420 ppm Ca was meant.
      expect(checkParamValue('calcium', 4.2), ParamValueCheck.implausible);
    });

    test('extreme but physically possible values are implausible, not '
        'impossible (still recordable after confirmation)', () {
      expect(checkParamValue('temperature', 45), ParamValueCheck.implausible);
      expect(checkParamValue('ph', 11), ParamValueCheck.implausible);
      expect(checkParamValue('nitrate', 400), ParamValueCheck.implausible);
    });

    test('ORP has no hard floor: negative readings are merely checked for '
        'plausibility', () {
      expect(checkParamValue('orp', -100), ParamValueCheck.ok);
      expect(checkParamValue('orp', -500), ParamValueCheck.implausible);
    });

    test('unknown parameter keys check as ok', () {
      expect(checkParamValue('not-a-param', -99999), ParamValueCheck.ok);
    });

    test(
      'every catalog parameter with a plausible bound defines both bounds',
      () {
        // The confirmation dialogs render "typical {min}–{max}" and assume a
        // complete pair whenever a value classifies as implausible.
        for (final def in kReefParameters) {
          expect(
            (def.plausibleMin == null) == (def.plausibleMax == null),
            isTrue,
            reason: '${def.key} must define both plausible bounds or neither',
          );
        }
      },
    );

    test('plausible bounds sit above the hard floor and are ordered', () {
      for (final def in kReefParameters) {
        final min = def.minValue;
        final lo = def.plausibleMin;
        final hi = def.plausibleMax;
        if (min != null && lo != null) {
          expect(lo, greaterThanOrEqualTo(min), reason: def.key);
        }
        if (lo != null && hi != null) {
          expect(hi, greaterThan(lo), reason: def.key);
        }
      }
    });
  });

  group('formatParamValue', () {
    test('uses the parameter precision', () {
      // pH -> 2 decimals, calcium -> 0, salinity -> 3.
      expect(formatParamValue('ph', 8.234), '8.23');
      expect(formatParamValue('calcium', 419.6), '420');
      expect(formatParamValue('salinity', 1.0264), '1.026');
    });

    test('rounds half away following toStringAsFixed', () {
      expect(formatParamValue('temperature', 25.05), '25.1');
    });

    test('falls back to 2 decimals for an unknown key', () {
      expect(formatParamValue('does-not-exist', 1.2345), '1.23');
    });
  });
}
