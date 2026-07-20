// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: tank_presets.yaml (ratios section)
// Regenerate: dart run tool/gen_tank_presets.dart

part of 'ratio.dart';

/// Recommended zone bounds per ratio kind, generated from
/// `tank_presets.yaml` (`ratios` section) — see
/// [RatioKindZones.defaultBounds] for the metric space.
const Map<RatioKind, ZoneBounds> kRatioDefaultBounds = {
  RatioKind.po4no3: ZoneBounds(
    amberLow: 25,
    greenLow: 50,
    greenHigh: 150,
    amberHigh: 250,
  ),
  RatioKind.mgca: ZoneBounds(
    amberLow: 2.6,
    greenLow: 2.9,
    greenHigh: 3.3,
    amberHigh: 3.6,
  ),
  RatioKind.caalk: ZoneBounds(
    amberLow: 40,
    greenLow: 46,
    greenHigh: 62,
    amberHigh: 70,
  ),
  RatioKind.mgalk: ZoneBounds(
    amberLow: 135,
    greenLow: 150,
    greenHigh: 190,
    amberHigh: 210,
  ),
};
