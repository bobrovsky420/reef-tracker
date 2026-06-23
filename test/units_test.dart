import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/units.dart';

void main() {
  group('temperature conversion', () {
    test('C <-> F round trips', () {
      expect(celsiusToF(25), closeTo(77, 1e-9));
      expect(fToCelsius(77), closeTo(25, 1e-9));
      expect(fToCelsius(celsiusToF(26.5)), closeTo(26.5, 1e-9));
    });
  });

  group('salinity conversion', () {
    test('reference point 35 ppt = 1.0264 SG', () {
      expect(pptToSg(35), closeTo(1.0264, 1e-6));
      expect(sgToPpt(1.0264), closeTo(35, 1e-3));
    });

    test('round trips', () {
      expect(sgToPpt(pptToSg(33)), closeTo(33, 1e-6));
      expect(pptToSg(sgToPpt(1.025)), closeTo(1.025, 1e-9));
    });
  });

  group('presentationFor', () {
    test('temperature follows prefs and converts', () {
      final f = presentationFor('temperature', '°C', 1,
          const UnitPrefs(temp: TempUnit.fahrenheit));
      expect(f.unitLabel, '°F');
      expect(f.toDisplay(25), closeTo(77, 1e-9));
      expect(f.toCanonical(77), closeTo(25, 1e-9));
      expect(f.unitFollowsSettings, isTrue);
    });

    test('salinity ppt vs SG decimals', () {
      final ppt = presentationFor(
          'salinity', 'SG', 3, const UnitPrefs(salinity: SalinityUnit.ppt));
      expect(ppt.unitLabel, 'ppt');
      expect(ppt.decimals, 1);
      final sg = presentationFor(
          'salinity', 'SG', 3, const UnitPrefs(salinity: SalinityUnit.sg));
      expect(sg.unitLabel, 'SG');
      expect(sg.decimals, 3);
      expect(sg.toDisplay(1.026), closeTo(1.026, 1e-9));
    });

    test('other parameters are identity in stored unit', () {
      final ca = presentationFor('calcium', 'ppm', 0, const UnitPrefs());
      expect(ca.unitLabel, 'ppm');
      expect(ca.toDisplay(420), 420);
      expect(ca.toCanonical(420), 420);
      expect(ca.unitFollowsSettings, isFalse);
    });
  });
}
