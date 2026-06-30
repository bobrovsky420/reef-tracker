import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/setup_type.dart';

void main() {
  group('SetupType.fromName', () {
    test('round-trips every enum name', () {
      for (final type in SetupType.values) {
        expect(SetupType.fromName(type.name), type);
      }
    });

    test('falls back to mixed for unknown/legacy values', () {
      expect(SetupType.fromName('legacy-value'), SetupType.mixed);
      expect(SetupType.fromName(''), SetupType.mixed);
    });
  });
}
