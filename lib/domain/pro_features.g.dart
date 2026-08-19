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

/// Every authoritative Pro authorization boundary, generated
/// from `pro_features.yaml`.
enum ProCapabilityBoundary {
  icpImportCommit,
  doseCalculatorRoute,
  unlimitedTankCreate,
  stabilityScorePresentation,
  cloudSyncEnable,
  cloudSyncPush,
  smartInsightsPresentation,
  hannaImportCommit,
  hannaConnectRoute,
  hannaScanRoute,
  connectedDeviceLiveIo,
  wallDisplayRoute,
  wallDisplayAutoStart,
}

/// Feature and enforcement kind for each capability boundary.
const Map<ProCapabilityBoundary, ProCapabilityContract>
kProCapabilityContracts = {
  ProCapabilityBoundary.icpImportCommit: ProCapabilityContract(
    feature: ProFeature.icpImport,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.doseCalculatorRoute: ProCapabilityContract(
    feature: ProFeature.doseCalculator,
    kind: ProBoundaryKind.routeResource,
  ),
  ProCapabilityBoundary.unlimitedTankCreate: ProCapabilityContract(
    feature: ProFeature.unlimitedTanks,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.stabilityScorePresentation: ProCapabilityContract(
    feature: ProFeature.stabilityScore,
    kind: ProBoundaryKind.presentation,
  ),
  ProCapabilityBoundary.cloudSyncEnable: ProCapabilityContract(
    feature: ProFeature.cloudSync,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.cloudSyncPush: ProCapabilityContract(
    feature: ProFeature.cloudSync,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.smartInsightsPresentation: ProCapabilityContract(
    feature: ProFeature.smartInsights,
    kind: ProBoundaryKind.presentation,
  ),
  ProCapabilityBoundary.hannaImportCommit: ProCapabilityContract(
    feature: ProFeature.hannaImport,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.hannaConnectRoute: ProCapabilityContract(
    feature: ProFeature.hannaConnect,
    kind: ProBoundaryKind.routeResource,
  ),
  ProCapabilityBoundary.hannaScanRoute: ProCapabilityContract(
    feature: ProFeature.hannaScan,
    kind: ProBoundaryKind.routeResource,
  ),
  ProCapabilityBoundary.connectedDeviceLiveIo: ProCapabilityContract(
    feature: ProFeature.connectedDevices,
    kind: ProBoundaryKind.command,
  ),
  ProCapabilityBoundary.wallDisplayRoute: ProCapabilityContract(
    feature: ProFeature.wallDisplay,
    kind: ProBoundaryKind.routeResource,
  ),
  ProCapabilityBoundary.wallDisplayAutoStart: ProCapabilityContract(
    feature: ProFeature.wallDisplay,
    kind: ProBoundaryKind.configuration,
  ),
};

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
