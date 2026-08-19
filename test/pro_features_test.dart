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
        // U49 wall display (2026-08-11): added pre-activation, so
        // grandfathered per the standing rule.
        ProFeature.wallDisplay,
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
      // `grandfathered: false` is the DEFAULT wording for the U21–U27 roadmap
      // block, and U22 (photo journal) is marked Pro and is next in line — so
      // this is a live hazard, not a theoretical one. The 2026-08-05 decision
      // overrides that default for everything shipped before activation.
      //
      // DECIDED 2026-08-05: every Pro feature delivered before activation
      // ships `grandfathered: true`, so if this fails, add the flag — there is
      // no per-feature deliberation left to have.
      //
      // This test is NOT relaxed at activation. It stays green afterwards and
      // becomes the permanent guard that a new key doesn't quietly take
      // something away from Founders. It costs the paid tier nothing: a
      // Standard install (every install created after activation) gets no
      // benefit from a grandfathered flag and meets the paywall on every key.
      // Only a capability invented after activation that even Founders should
      // pay for would ever justify `grandfathered: false` — and changing this
      // test is exactly the moment to prove that case was made deliberately.
      expect(
        ProFeature.values.where((f) => !kGrandfatheredFeatures.contains(f)),
        isEmpty,
        reason:
            'a non-grandfathered feature makes the paywall reachable, and no '
            'purchase mechanism exists to satisfy it',
      );
    });

    test('the sale flag is derived, so a half-flip cannot exist', () {
      // The three facts that make up activation — sale live, seeder stopped,
      // marker boundary honoured — all hang off one constant. The state that
      // used to be reachable by hand (sale ON while the seeder still mints
      // Founders, so every new install is entitled and nobody ever pays) is
      // now unrepresentable.
      expect(kProSaleLive, kActivationVersion != null);
      expect(
        shouldSeedFounderMarker(activationVersion: kActivationVersion),
        !kProSaleLive,
        reason: 'seeding and selling must never be on at the same time',
      );
    });

    test('the ACTIVATED behaviour is proven now, not on activation day', () {
      // `shouldSeedFounderMarker` takes the version as a parameter precisely
      // so the post-flip branch is exercised while it is still a value. On
      // activation day the constant changes and this behaviour is already
      // covered — no new test to write under pressure.
      expect(
        shouldSeedFounderMarker(activationVersion: null),
        isTrue,
        reason: 'dormant: every launch seeds',
      );
      expect(
        shouldSeedFounderMarker(activationVersion: '1.3.0'),
        isFalse,
        reason: 'activated: nothing is stamped, fresh installs are Standard',
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

  group('generated capability contracts (T29)', () {
    test(
      'every generated boundary has one contract and every feature has one',
      () {
        expect(
          kProCapabilityContracts.keys.toSet(),
          ProCapabilityBoundary.values.toSet(),
        );
        expect(
          kProCapabilityContracts.values.map((c) => c.feature).toSet(),
          ProFeature.values.toSet(),
        );
      },
    );

    for (final boundary in ProCapabilityBoundary.values) {
      final contract = proCapabilityContract(boundary);
      test('${boundary.name}: Standard, Founder and purchase matrix', () {
        expect(
          hasProCapability(boundary, purchased: false, legacyFree: false),
          isFalse,
          reason: 'Standard must fail closed at ${boundary.name}',
        );
        expect(
          hasProCapability(boundary, purchased: false, legacyFree: true),
          kGrandfatheredFeatures.contains(contract.feature),
          reason: 'Founder access follows ${contract.feature.name}',
        );
        expect(
          hasProCapability(boundary, purchased: true, legacyFree: false),
          isTrue,
          reason: 'a purchase unlocks ${boundary.name}',
        );
      });
    }
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
