// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: ro_defaults.yaml
// Regenerate: dart run tool/gen_ro_defaults.dart

part of 'ro.dart';

/// Typical replacement lifespans (days) per usage level,
/// generated from `ro_defaults.yaml`. Seeds the default
/// stage set on first RO-screen open and re-applies when the
/// user picks a usage level; `moderate` is the default.
/// Deliberately conservative, mainstream values — the user
/// edits them to match their water and unit.
/// [RoStageType.custom] has no default: custom stages are
/// user-created.
const Map<RoUsageLevel, Map<RoStageType, int>> kRoLifespanDaysByUsage = {
  RoUsageLevel.light: {
    RoStageType.sediment: 180,
    RoStageType.carbonBlock: 360,
    RoStageType.membrane: 1080,
    RoStageType.diResin: 240,
  },
  RoUsageLevel.moderate: {
    RoStageType.sediment: 90,
    RoStageType.carbonBlock: 180,
    RoStageType.membrane: 720,
    RoStageType.diResin: 120,
  },
  RoUsageLevel.heavy: {
    RoStageType.sediment: 45,
    RoStageType.carbonBlock: 90,
    RoStageType.membrane: 360,
    RoStageType.diResin: 60,
  },
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
