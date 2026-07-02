/// A reef water parameter that can be tracked. The catalog below is static
/// app data (not stored in the DB) so it can evolve without DB migrations.
///
/// Display name and help text are localized (`l.paramName`/`l.paramHelp`
/// keyed by [key]), not stored here — do not add English text fields back
/// (#54).
class ParameterDef {
  const ParameterDef({
    required this.key,
    required this.unit,
    required this.decimals,
    this.minValue,
    this.plausibleMin,
    this.plausibleMax,
  });

  /// Stable identifier persisted in the database (e.g. `alkalinity`).
  final String key;

  /// Default unit of measure (e.g. `dKH`). Editable per tank.
  final String unit;

  /// How many decimal places to show when formatting values.
  final int decimals;

  /// Hard physical floor in the *canonical* unit (°C, SG, ppm, …); values
  /// below it are impossible measurements (negative concentrations, SG below
  /// pure water) and are rejected outright. Null = no floor (e.g. ORP can be
  /// legitimately negative).
  final double? minValue;

  /// Plausible measurement range in the canonical unit. Values outside it are
  /// accepted only after explicit user confirmation (#31). The bounds are
  /// deliberately generous — they exist to catch order-of-magnitude slips
  /// (`1,300` read as 1.3, ppt typed into an SG field), not to police
  /// unusual tanks, so genuinely extreme readings stay recordable.
  final double? plausibleMin;
  final double? plausibleMax;
}

/// Result of sanity-checking a canonical reading value against its
/// [ParameterDef] limits.
enum ParamValueCheck {
  /// Within the plausible range (or the parameter defines no limits).
  ok,

  /// Below the hard physical floor — reject, there is nothing to confirm.
  impossible,

  /// Physically possible but outside the plausible range — ask the user to
  /// confirm before storing.
  implausible,
}

/// Classifies a *canonical* [value] for [paramKey] against the catalog's
/// physical floor and plausible range. Unknown keys check as [ParamValueCheck.ok].
ParamValueCheck checkParamValue(String paramKey, double value) {
  final def = kParameterByKey[paramKey];
  if (def == null) return ParamValueCheck.ok;
  if (!value.isFinite) return ParamValueCheck.impossible;
  final min = def.minValue;
  if (min != null && value < min) return ParamValueCheck.impossible;
  final lo = def.plausibleMin;
  final hi = def.plausibleMax;
  if ((lo != null && value < lo) || (hi != null && value > hi)) {
    return ParamValueCheck.implausible;
  }
  return ParamValueCheck.ok;
}

/// The built-in catalog of typical reef aquarium parameters.
const List<ParameterDef> kReefParameters = [
  ParameterDef(
    key: 'temperature',
    unit: '°C',
    decimals: 1,
    minValue: 0,
    plausibleMin: 10,
    plausibleMax: 40,
  ),
  ParameterDef(
    key: 'ph',
    unit: 'pH',
    decimals: 2,
    minValue: 0,
    plausibleMin: 5,
    plausibleMax: 10,
  ),
  ParameterDef(
    key: 'salinity',
    unit: 'SG',
    decimals: 3,
    minValue: 1.0,
    plausibleMin: 1.0,
    plausibleMax: 1.05,
  ),
  ParameterDef(
    key: 'alkalinity',
    unit: 'dKH',
    decimals: 1,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 30,
  ),
  ParameterDef(
    key: 'calcium',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 100,
    plausibleMax: 1000,
  ),
  ParameterDef(
    key: 'magnesium',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 800,
    plausibleMax: 2000,
  ),
  ParameterDef(
    key: 'nitrate',
    unit: 'ppm',
    decimals: 1,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 250,
  ),
  ParameterDef(
    key: 'phosphate',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 5,
  ),
  ParameterDef(
    key: 'ammonia',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 10,
  ),
  ParameterDef(
    key: 'nitrite',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 10,
  ),
  // ORP can dip below zero in anoxic conditions — no hard floor.
  ParameterDef(
    key: 'orp',
    unit: 'mV',
    decimals: 0,
    plausibleMin: -300,
    plausibleMax: 700,
  ),
  ParameterDef(
    key: 'potassium',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 100,
    plausibleMax: 800,
  ),
  ParameterDef(
    key: 'strontium',
    unit: 'ppm',
    decimals: 1,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 50,
  ),
  ParameterDef(
    key: 'iodine',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
  ParameterDef(
    key: 'iron',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
];

/// Lookup by key for O(1) access.
final Map<String, ParameterDef> kParameterByKey = {
  for (final p in kReefParameters) p.key: p,
};

/// Formats [value] using the parameter's configured precision.
String formatParamValue(String paramKey, double value) {
  final decimals = kParameterByKey[paramKey]?.decimals ?? 2;
  return value.toStringAsFixed(decimals);
}
