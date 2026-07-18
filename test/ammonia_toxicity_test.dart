import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/ammonia_toxicity.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('ammoniumPKa', () {
    test('freshwater 25 °C matches Emerson (1975) ≈ 9.246', () {
      expect(
        ammoniumPKa(tempC: 25, salinityPpt: 0),
        closeTo(9.2464, 0.001),
      );
    });

    test('seawater raises pKa slightly above freshwater (lower toxic share)', () {
      final fresh = ammoniumPKa(tempC: 25, salinityPpt: 0);
      final sea = ammoniumPKa(tempC: 25, salinityPpt: 35);
      expect(sea, greaterThan(fresh));
      // The salinity shift is minor (< ~0.05 pKa at reef salinity).
      expect(sea - fresh, closeTo(0.035, 0.01));
    });

    test('pKa falls as temperature rises', () {
      expect(
        ammoniumPKa(tempC: 27, salinityPpt: 35),
        lessThan(ammoniumPKa(tempC: 25, salinityPpt: 35)),
      );
    });
  });

  group('freeAmmoniaFraction', () {
    test('reef conditions ≈ 9–10 % NH₃ at pH 8.3 / 25 °C / 35 ppt', () {
      expect(
        freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 35),
        closeTo(0.094, 0.005),
      );
    });

    test('freshwater at the same pH/temp is a touch higher', () {
      final sea = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 35);
      final fresh = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 0);
      expect(fresh, greaterThan(sea));
      expect(fresh, closeTo(0.102, 0.005));
    });

    test('rises steeply with pH', () {
      final low = freeAmmoniaFraction(pH: 7.8, tempC: 25, salinityPpt: 35);
      final high = freeAmmoniaFraction(pH: 8.4, tempC: 25, salinityPpt: 35);
      // ~0.6 pH units ≈ roughly a 3–4× change.
      expect(high, greaterThan(low * 3));
    });

    test('rises with temperature (~13 % more at 27 vs 25 °C)', () {
      final warm = freeAmmoniaFraction(pH: 8.3, tempC: 27, salinityPpt: 35);
      final cool = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 35);
      expect(warm, greaterThan(cool));
      expect((warm - cool) / cool, closeTo(0.135, 0.03));
    });

    test('falls as salinity rises', () {
      final brackish = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 10);
      final marine = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 35);
      expect(marine, lessThan(brackish));
    });
  });

  group('kFreeAmmoniaBounds', () {
    test('one-sided toxicity classification', () {
      expect(kFreeAmmoniaBounds.classify(0.01), Zone.green);
      expect(kFreeAmmoniaBounds.classify(0.03), Zone.amber);
      expect(kFreeAmmoniaBounds.classify(0.08), Zone.red);
      // No "too little" toxic ammonia — zero is perfectly safe.
      expect(kFreeAmmoniaBounds.classify(0), Zone.green);
    });
  });

  group('computeFreeAmmonia', () {
    final t0 = DateTime(2026, 7, 18, 12);
    AmmoniaInput at(DateTime when, double value) => (takenAt: when, value: value);

    test('returns null when any of ammonia/pH/temperature is missing', () {
      expect(
        computeFreeAmmonia(
          ammonia: const [],
          ph: [at(t0, 8.2)],
          temperature: [at(t0, 25)],
        ),
        isNull,
      );
      expect(
        computeFreeAmmonia(
          ammonia: [at(t0, 0.5)],
          ph: const [],
          temperature: [at(t0, 25)],
        ),
        isNull,
      );
      expect(
        computeFreeAmmonia(
          ammonia: [at(t0, 0.5)],
          ph: [at(t0, 8.2)],
          temperature: const [],
        ),
        isNull,
      );
    });

    test('free NH₃ = total × fraction, using the latest reading of each', () {
      final fa = computeFreeAmmonia(
        ammonia: [at(t0, 0.5)],
        ph: [at(t0, 8.3)],
        temperature: [at(t0, 25)],
        salinity: [at(t0, pptToSg(35))],
      )!;
      final f = freeAmmoniaFraction(pH: 8.3, tempC: 25, salinityPpt: 35);
      expect(fa.total, 0.5);
      expect(fa.fraction, closeTo(f, 1e-9));
      expect(fa.freeNh3, closeTo(0.5 * f, 1e-9));
      expect(fa.salinityMeasured, isTrue);
      expect(fa.salinityPpt, closeTo(35, 0.01));
    });

    test('missing salinity falls back to 35 ppt, flagged unmeasured', () {
      final fa = computeFreeAmmonia(
        ammonia: [at(t0, 0.5)],
        ph: [at(t0, 8.3)],
        temperature: [at(t0, 25)],
      )!;
      expect(fa.salinityMeasured, isFalse);
      expect(fa.salinityPpt, kDefaultSalinityPpt);
    });

    test('negative total ammonia is clamped to zero', () {
      final fa = computeFreeAmmonia(
        ammonia: [at(t0, -1)],
        ph: [at(t0, 8.3)],
        temperature: [at(t0, 25)],
      )!;
      expect(fa.total, 0);
      expect(fa.freeNh3, 0);
    });

    test('flags outdated inputs when pH/temp are far from the ammonia reading', () {
      // pH measured 10 days before the ammonia reading → outdated.
      final stale = computeFreeAmmonia(
        ammonia: [at(t0, 0.5)],
        ph: [at(t0.subtract(const Duration(days: 10)), 8.3)],
        temperature: [at(t0, 25)],
      )!;
      expect(stale.inputsOutdated, isTrue);

      // Everything within a couple of days → fresh.
      final fresh = computeFreeAmmonia(
        ammonia: [at(t0, 0.5)],
        ph: [at(t0.subtract(const Duration(days: 2)), 8.3)],
        temperature: [at(t0.subtract(const Duration(days: 1)), 25)],
      )!;
      expect(fresh.inputsOutdated, isFalse);
    });

    test('zone reflects the free NH₃ value against the toxicity bounds', () {
      // High pH + high total pushes the toxic value into the red.
      final fa = computeFreeAmmonia(
        ammonia: [at(t0, 1.0)],
        ph: [at(t0, 8.4)],
        temperature: [at(t0, 27)],
        salinity: [at(t0, pptToSg(35))],
      )!;
      expect(fa.freeNh3, greaterThan(kFreeAmmoniaAmberHigh));
      expect(fa.zone, Zone.red);
    });
  });
}
