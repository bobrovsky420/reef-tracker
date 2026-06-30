import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';

void main() {
  group('kReefParameters catalog integrity', () {
    test('keys are unique', () {
      final keys = kReefParameters.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length,
          reason: 'duplicate parameter key in catalog');
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
        expect(p.name, isNotEmpty, reason: '${p.key} has empty name');
        expect(p.unit, isNotEmpty, reason: '${p.key} has empty unit');
        expect(p.decimals, greaterThanOrEqualTo(0),
            reason: '${p.key} has negative decimals');
        expect(p.decimals, lessThanOrEqualTo(4),
            reason: '${p.key} has implausible decimals');
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
