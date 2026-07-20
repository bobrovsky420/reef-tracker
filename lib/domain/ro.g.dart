// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: ro_defaults.yaml
// Regenerate: dart run tool/gen_ro_defaults.dart

part of 'ro.dart';

/// Typical replacement lifespans (days) used to seed the
/// default stage set the first time the RO screen is opened,
/// generated from `ro_defaults.yaml`. Deliberately
/// conservative, mainstream values — the user edits them to
/// match their water and unit. [RoStageType.custom] has no
/// default: custom stages are user-created.
const Map<RoStageType, int> kRoDefaultLifespanDays = {
  RoStageType.sediment: 90,
  RoStageType.carbonBlock: 180,
  RoStageType.membrane: 720,
  RoStageType.diResin: 120,
};

/// Seed order of the default stages — the water path through
/// the unit. Generated from `ro_defaults.yaml` (listing
/// order).
const List<RoStageType> kRoDefaultStageOrder = [
  RoStageType.sediment,
  RoStageType.carbonBlock,
  RoStageType.membrane,
  RoStageType.diResin,
];
