/// Pro-tier feature gating (U19). Pure domain — no Flutter, no DB.
///
/// The feature list and the grandfathered set are GENERATED from
/// `pro_features.yaml` (edit the YAML, then
/// `dart run tool/gen_pro_features.dart`). Which features are paid is a
/// one-line YAML decision; this file only owns the gate rule.
///
/// Entitlement sources (see `editionProvider` / `proFeatureProvider` in
/// `app/providers.dart`):
/// - `purchased` — the future Pro in-app purchase. No purchase mechanism
///   exists yet, so callers currently pass false.
/// - `legacyFree` — the early-adopter marker (`legacy_free_since`, seeded by
///   every pre-Pro build): those installs keep every *grandfathered* feature
///   free forever. Features added to the registry with `grandfathered: false`
///   after the cutoff are paid for everyone.
library;

part 'pro_features.g.dart';

/// Whether an install with the given entitlements may use [feature].
bool hasProFeature(
  ProFeature feature, {
  required bool purchased,
  required bool legacyFree,
}) => purchased || (legacyFree && kGrandfatheredFeatures.contains(feature));

/// How many aquariums a non-entitled install may hold: a display tank plus a
/// quarantine tank, so the free tier never penalizes quarantining.
const int kFreeTankLimit = 2;

/// Whether an install already holding [tankCount] live (non-deleted) aquariums
/// may create another. The cap gates only CREATION — existing tanks beyond the
/// limit (restored backup, lapsed entitlement) stay fully usable; data is
/// never locked away. [unlimitedTanks] is the caller's
/// `ProFeature.unlimitedTanks` gate result.
bool canCreateTank(int tankCount, {required bool unlimitedTanks}) =>
    unlimitedTanks || tankCount < kFreeTankLimit;
