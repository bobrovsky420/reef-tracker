import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/setup_type.dart';

void main() {
  group('presets integrity', () {
    test('every preset key exists in the catalog', () {
      for (final entry in kPresets.entries) {
        for (final key in entry.value.keys) {
          expect(kParameterByKey.containsKey(key), isTrue,
              reason: '${entry.key} references unknown parameter "$key"');
        }
      }
    });

    test('every setup type has at least one parameter', () {
      for (final type in SetupType.values) {
        expect(defaultTrackedKeys(type), isNotEmpty, reason: '$type has none');
      }
    });

    test('bounds are monotonically increasing where defined', () {
      for (final entry in kPresets.entries) {
        for (final bounds in entry.value.values) {
          final seq = [
            bounds.amberLow,
            bounds.greenLow,
            bounds.greenHigh,
            bounds.amberHigh,
          ].whereType<double>().toList();
          for (var i = 1; i < seq.length; i++) {
            expect(seq[i] >= seq[i - 1], isTrue,
                reason: 'Out-of-order bound in ${entry.key}: $seq');
          }
        }
      }
    });
  });
}
