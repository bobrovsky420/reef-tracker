// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: wall_parameters.yaml
// Regenerate: dart run tool/gen_wall_parameters.dart

part of 'wall_display.dart';

/// The parameters that may appear on the wall board — the
/// selectable card set, generated from `wall_parameters.yaml`.
/// Microelements are excluded by design (the generator
/// rejects them); `buildWallCards` drops any key outside this
/// set, whatever a tank tracks or a device reports.
const Set<String> kWallParameterKeys = {
  'temperature',
  'ph',
  'salinity',
  'alkalinity',
  'calcium',
  'magnesium',
  'nitrate',
  'phosphate',
  'ammonia',
  'nitrite',
  'orp',
};
