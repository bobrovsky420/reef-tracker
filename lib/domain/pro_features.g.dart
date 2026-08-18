// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: pro_features.yaml
// Regenerate: dart run tool/gen_pro_features.dart

part of 'pro_features.dart';

/// Every feature behind the Pro gate, generated from
/// `pro_features.yaml`.
enum ProFeature {
  icpImport,
  doseCalculator,
  unlimitedTanks,
  stabilityScore,
  cloudSync,
  smartInsights,
  hannaImport,
  hannaConnect,
  hannaScan,
  connectedDevices,
  wallDisplay,
}

/// Features that existed at the monetization cutoff: free
/// FOREVER for Founder's Edition installs. Entries are never
/// removed (see pro_features.yaml).
const Set<ProFeature> kGrandfatheredFeatures = {
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
  ProFeature.wallDisplay,
};
