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
      // Pro must grandfather), but a promised capability must NEVER lose its
      // free-forever status. If this test fails because a key disappeared,
      // revert the pro_features.yaml change — don't update the expectation.
      //
      // The one legitimate exception, and the only reason this list ever
      // shrinks: several grandfathered keys MERGING into one grandfathered key
      // covering the same capabilities. `connectedDevices` (2026-07-27) is
      // exactly that — it replaces reefFactory + reefBeat + apex, so every
      // install that had those three free still does. A merge that dropped a
      // capability, or landed on a non-grandfathered key, would break the
      // promise just as removal would.
      expect(kGrandfatheredFeatures, {
        ProFeature.icpImport,
        ProFeature.doseCalculator,
        ProFeature.unlimitedTanks,
        ProFeature.stabilityScore,
        ProFeature.cloudSync,
        ProFeature.smartInsights,
        ProFeature.hannaImport,
        ProFeature.hannaConnect,
        ProFeature.hannaScan,
        ProFeature.connectedDevices,
      });
    });
  });

  group('dormancy invariant (U19 §10 A10)', () {
    test('while the tier is dormant, every feature is grandfathered', () {
      // THE PROPERTY THE WHOLE DORMANT-SHIP PLAN RESTS ON. The paywall is
      // unreachable if and only if every registry entry is grandfathered —
      // *not* "because everyone is a Founder". Founder status only passes the
      // gate for grandfathered features, so one routine `grandfathered: false`
      // entry would put a priceless, unbuyable paywall in front of every
      // existing user in a production build.
      //
      // `grandfathered: false` is the DEFAULT for the U21–U27 roadmap block,
      // and U22 (photo journal) is marked Pro and is next in line — so this is
      // a live hazard, not a theoretical one.
      //
      // If this fails, the feature you just added either ships
      // `grandfathered: true` or ships ungated until activation. Decide per
      // feature — but never silently. Relax this test only in the activation
      // commit itself (§10 B1), together with the sale switch.
      expect(
        ProFeature.values.where((f) => !kGrandfatheredFeatures.contains(f)),
        isEmpty,
        reason:
            'a non-grandfathered feature makes the paywall reachable, and no '
            'purchase mechanism exists to satisfy it',
      );
    });

    test('the paid tier has not been activated', () {
      // The other half of the same invariant: the activation version is what
      // switches the marker from "presence is enough" to "must predate
      // activation". Setting it is a deliberate release-day act (§10 B1), so
      // an accidental value would silently strip Founder status from
      // everyone.
      expect(kActivationVersion, isNull);
    });
  });

  group('marker integrity (U19 §10 A11)', () {
    test('while dormant, any marker grants Founder', () {
      expect(markerGrantsFounder('0.26.0'), isTrue);
      expect(markerGrantsFounder('99.0.0'), isTrue);
    });

    test('no marker, no Founder', () {
      expect(markerGrantsFounder(null), isFalse);
      expect(markerGrantsFounder(''), isFalse);
    });

    test('version comparison orders the way activation will need it', () {
      // The rule at activation is `marker < activation`. These are the cases
      // that decide whether a rollback-minted marker (§10's one-way valve) can
      // be told apart from a genuine early one.
      expect(compareAppVersions('0.26.0', '1.2.0'), lessThan(0));
      expect(compareAppVersions('1.2.0', '1.2.0'), 0);
      expect(compareAppVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareAppVersions('1.2', '1.2.0'), 0);
      // A `+build` suffix is not part of the ordering.
      expect(compareAppVersions('1.2.0+142', '1.2.0'), 0);
      // Garbage degrades to "oldest possible" rather than throwing on launch.
      expect(compareAppVersions('nonsense', '0.0.1'), lessThan(0));
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
