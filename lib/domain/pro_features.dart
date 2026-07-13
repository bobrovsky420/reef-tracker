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
