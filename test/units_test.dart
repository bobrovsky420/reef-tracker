import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/units.dart';

void main() {
  group('parseUserDouble', () {
    test('parses plain and comma-decimal numbers', () {
      expect(parseUserDouble('8.2'), 8.2);
      expect(parseUserDouble('8,2'), 8.2);
      expect(parseUserDouble('  -1.5 '), -1.5);
    });

    test('blank or null is null', () {
      expect(parseUserDouble(null), isNull);
      expect(parseUserDouble(''), isNull);
      expect(parseUserDouble('   '), isNull);
    });

    test('non-numeric is null', () {
      expect(parseUserDouble('abc'), isNull);
    });

    test('rejects non-finite Infinity/NaN', () {
      expect(parseUserDouble('Infinity'), isNull);
      expect(parseUserDouble('-Infinity'), isNull);
      expect(parseUserDouble('NaN'), isNull);
    });
  });

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

  group('volume conversion', () {
    test('US gallon reference and round trips', () {
      expect(gallonsToLiters(1), closeTo(3.785411784, 1e-9));
      expect(litersToGallons(3.785411784), closeTo(1, 1e-9));
      expect(volumeToCanonical(volumeToDisplay(200, VolumeUnit.gallons),
              VolumeUnit.gallons),
          closeTo(200, 1e-9));
    });

    test('litres unit is identity', () {
      expect(volumeToDisplay(200, VolumeUnit.liters), 200);
      expect(volumeToCanonical(200, VolumeUnit.liters), 200);
    });

    test('formatVolume trims whole numbers and rounds to one decimal', () {
      expect(formatVolume(200, VolumeUnit.liters), '200');
      expect(formatVolume(200.5, VolumeUnit.liters), '200.5');
      // 200 L ≈ 52.8 gal
      expect(formatVolume(200, VolumeUnit.gallons), '52.8');
      // 3.785411784 L = exactly 1 gal -> no decimals
      expect(formatVolume(gallonsToLiters(50), VolumeUnit.gallons), '50');
    });

    test('fromName defaults to litres', () {
      expect(VolumeUnit.fromName(null), VolumeUnit.liters);
      expect(VolumeUnit.fromName('gallons'), VolumeUnit.gallons);
      expect(VolumeUnit.fromName('bogus'), VolumeUnit.liters);
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

  group('formatChange', () {
    final p = presentationFor(
        'salinity', 'SG', 3, const UnitPrefs(salinity: SalinityUnit.sg));

    test('signs visible changes explicitly', () {
      expect(p.formatChange(1.026, 1.024), '+0.002');
      expect(p.formatChange(1.024, 1.026), '-0.002');
    });

    test('exact zero is unsigned', () {
      expect(p.formatChange(1.025, 1.025), '0.000');
    });

    test('near-zero negative delta does not render as -0.0', () {
      // -0.0004 rounds to 0.000 at 3 decimals; must not show a "-0.000".
      final s = p.formatChange(1.0250, 1.0254);
      expect(s, '0.000');
      expect(s.startsWith('-'), isFalse);
    });

    test('tiny positive delta that rounds to zero is unsigned', () {
      final s = p.formatChange(1.0254, 1.0250);
      expect(s, '0.000');
      expect(s.startsWith('+'), isFalse);
    });
  });
}
