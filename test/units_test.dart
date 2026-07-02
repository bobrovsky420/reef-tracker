import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

    test('en locale: comma in strict thousands positions is grouping (#6)',
        () {
      // Default test locale is en (dot-decimal): "1,300" is en-style
      // thousands grouping, "1.300" is a decimal.
      expect(parseUserDouble('1,300'), 1300);
      expect(parseUserDouble('1,300,000'), 1300000);
      expect(parseUserDouble('1,025'), 1025);
      expect(parseUserDouble('1.300'), 1.3);
      expect(parseUserDouble('1.025'), 1.025);
    });

    test('en locale: a lone comma that cannot be grouping is a decimal', () {
      // Comma-only keyboards must still be able to type decimals.
      expect(parseUserDouble('2,5'), 2.5);
      expect(parseUserDouble('1,30'), 1.3);
    });

    test('mixed or malformed separators are rejected', () {
      expect(parseUserDouble('1.234,5'), isNull);
      expect(parseUserDouble('1,234.5'), isNull);
      expect(parseUserDouble('1,2,3'), isNull);
      expect(parseUserDouble('1.2.3'), isNull);
    });

    group('comma-decimal locale (cs)', () {
      setUp(() => Intl.defaultLocale = 'cs');
      tearDown(() => Intl.defaultLocale = null);

      test('comma is always the decimal point', () {
        // The salinity case: "1,025" SG must parse as a decimal, not be
        // rejected as ambiguous grouping.
        expect(parseUserDouble('1,025'), 1.025);
        expect(parseUserDouble('1,300'), 1.3);
        expect(parseUserDouble('8,2'), 8.2);
      });

      test('dot- and space-grouped thousands are grouping', () {
        expect(parseUserDouble('1.300'), 1300);
        expect(parseUserDouble('1 300'), 1300);
        expect(parseUserDouble('1 300,5'), 1300.5);
        expect(parseUserDouble('1 300 000'), 1300000);
      });

      test('a lone dot that cannot be grouping is a decimal', () {
        expect(parseUserDouble('1.5'), 1.5);
      });
    });

    group('comma-decimal locale with dot grouping (de)', () {
      setUp(() => Intl.defaultLocale = 'de');
      tearDown(() => Intl.defaultLocale = null);

      test('de conventions parse both directions', () {
        expect(parseUserDouble('1,3'), 1.3);
        expect(parseUserDouble('1.300'), 1300);
        expect(parseUserDouble('1,025'), 1.025);
      });
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

    test('converts the delta into the display unit (°F)', () {
      final f = presentationFor('temperature', '°C', 1,
          const UnitPrefs(temp: TempUnit.fahrenheit));
      // ±1 °C reads as ±1.8 °F.
      expect(f.formatChange(26, 25), '+1.8');
      expect(f.formatChange(25, 26), '-1.8');
    });

    test('a change invisible in °C can still be visible in °F', () {
      final c = presentationFor('temperature', '°C', 1, const UnitPrefs());
      final f = presentationFor('temperature', '°C', 1,
          const UnitPrefs(temp: TempUnit.fahrenheit));
      // +0.03 °C rounds away at one decimal, but is +0.054 °F -> "+0.1".
      expect(c.formatChange(25.03, 25.0), '0.0');
      expect(f.formatChange(25.03, 25.0), '+0.1');
    });
  });

  group('formatLocaleNumber (#39)', () {
    tearDown(() => Intl.defaultLocale = null);

    test('en renders a decimal point, cs a comma', () {
      expect(formatLocaleNumber(2.5, 1), '2.5');
      Intl.defaultLocale = 'cs';
      expect(formatLocaleNumber(2.5, 1), '2,5');
      expect(formatLocaleNumber(-0.1, 1), '-0,1');
    });

    test('no grouping, so formatted output round-trips through the parser',
        () {
      for (final locale in [null, 'cs', 'de', 'pl', 'ru', 'en']) {
        Intl.defaultLocale = locale;
        for (final v in [1300.0, 1300.5, 1.025, 0.02]) {
          expect(parseUserDouble(formatLocaleNumber(v, 3)), closeTo(v, 1e-6),
              reason: 'locale=$locale value=$v');
        }
      }
    });

    test('trim variant drops the zero fraction and trailing zeros', () {
      expect(formatLocaleNumberTrim(5), '5');
      expect(formatLocaleNumberTrim(2.5), '2.5');
      expect(formatLocaleNumberTrim(0.025, decimals: 4), '0.025');
    });
  });

  group('format with non-finite input', () {
    test('renders the locale NaN/infinity symbols (no guard in format)', () {
      // Pins current behavior: `format` trusts canonical storage — the
      // finite-ness guard lives at the input boundary (parseUserDouble). A
      // non-finite value that sneaks into the DB renders as NumberFormat's
      // locale symbols (#39 routed display through intl).
      final ca = presentationFor('calcium', 'ppm', 0, const UnitPrefs());
      expect(ca.format(double.nan), 'NaN');
      expect(ca.format(double.infinity), '∞');
    });
  });
}
