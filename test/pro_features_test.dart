import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/pro_features.dart';

void main() {
  group('hasProFeature gate (U19)', () {
    test('a purchase unlocks everything', () {
      for (final f in ProFeature.values) {
        expect(
          hasProFeature(f, purchased: true, legacyFree: false),
          isTrue,
          reason: '$f must be unlocked by a purchase',
        );
      }
    });

    test('founders get exactly the grandfathered features', () {
      for (final f in ProFeature.values) {
        expect(
          hasProFeature(f, purchased: false, legacyFree: true),
          kGrandfatheredFeatures.contains(f),
          reason:
              '$f: legacyFree entitles grandfathered features, nothing else',
        );
      }
    });

    test('no entitlement, no access', () {
      for (final f in ProFeature.values) {
        expect(hasProFeature(f, purchased: false, legacyFree: false), isFalse);
      }
    });
  });

  group('grandfathered set freeze (U19)', () {
    test('the grandfathered set contains exactly the promised features', () {
      // THE FREEZE PIN. "Founder's Edition keeps these free forever" is a
      // public promise: entries may be ADDED here (a pre-cutoff feature going
      // Pro must grandfather), but an existing entry must NEVER be removed.
      // If this test fails because a key disappeared, revert the
      // pro_features.yaml change — don't update the expectation.
      expect(kGrandfatheredFeatures, {
        ProFeature.icpImport,
        ProFeature.doseCalculator,
        ProFeature.unlimitedTanks,
        ProFeature.stabilityScore,
        ProFeature.driveSync,
        ProFeature.smartInsights,
        ProFeature.hannaImport,
      });
    });
  });

  group('tank cap (U21)', () {
    test('unlimitedTanks entitlement lifts the cap entirely', () {
      for (final count in [0, kFreeTankLimit, 100]) {
        expect(canCreateTank(count, unlimitedTanks: true), isTrue);
      }
    });

    test('a non-entitled install may create up to kFreeTankLimit tanks', () {
      for (var count = 0; count < kFreeTankLimit; count++) {
        expect(canCreateTank(count, unlimitedTanks: false), isTrue);
      }
      expect(canCreateTank(kFreeTankLimit, unlimitedTanks: false), isFalse);
      // Over the cap (restored backup): existing tanks stay usable, but no
      // further creation.
      expect(canCreateTank(kFreeTankLimit + 1, unlimitedTanks: false), isFalse);
    });

    test('the free tier covers a display tank plus a quarantine tank', () {
      // Product decision pin: lowering the limit below 2 would punish
      // quarantining — don't.
      expect(kFreeTankLimit, greaterThanOrEqualTo(2));
    });
  });
}
