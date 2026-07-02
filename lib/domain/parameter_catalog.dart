/// A reef water parameter that can be tracked. The catalog below is static
/// app data (not stored in the DB) so it can evolve without DB migrations.
class ParameterDef {
  const ParameterDef({
    required this.key,
    required this.name,
    required this.unit,
    required this.decimals,
    this.help,
    this.minValue,
    this.plausibleMin,
    this.plausibleMax,
  });

  /// Stable identifier persisted in the database (e.g. `alkalinity`).
  final String key;

  /// Display name (e.g. `Alkalinity`).
  final String name;

  /// Default unit of measure (e.g. `dKH`). Editable per tank.
  final String unit;

  /// How many decimal places to show when formatting values.
  final int decimals;

  /// Optional short hint shown in the parameter editor.
  final String? help;

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
    name: 'Temperature',
    unit: '°C',
    decimals: 1,
    help: 'Water temperature. Stability matters more than the exact value.',
    minValue: 0,
    plausibleMin: 10,
    plausibleMax: 40,
  ),
  ParameterDef(
    key: 'ph',
    name: 'pH',
    unit: 'pH',
    decimals: 2,
    minValue: 0,
    plausibleMin: 5,
    plausibleMax: 10,
  ),
  ParameterDef(
    key: 'salinity',
    name: 'Salinity',
    unit: 'SG',
    decimals: 3,
    help: 'Specific gravity. ~1.026 SG ≈ 35 ppt.',
    minValue: 1.0,
    plausibleMin: 1.0,
    plausibleMax: 1.05,
  ),
  ParameterDef(
    key: 'alkalinity',
    name: 'Alkalinity',
    unit: 'dKH',
    decimals: 1,
    help: 'Carbonate hardness. Keep stable — avoid swings.',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 30,
  ),
  ParameterDef(
    key: 'calcium',
    name: 'Calcium (Ca)',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 100,
    plausibleMax: 1000,
  ),
  ParameterDef(
    key: 'magnesium',
    name: 'Magnesium (Mg)',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 800,
    plausibleMax: 2000,
  ),
  ParameterDef(
    key: 'nitrate',
    name: 'Nitrate (NO₃)',
    unit: 'ppm',
    decimals: 1,
    help: 'A nutrient. Corals need a little; too much fuels algae.',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 250,
  ),
  ParameterDef(
    key: 'phosphate',
    name: 'Phosphate (PO₄)',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 5,
  ),
  ParameterDef(
    key: 'ammonia',
    name: 'Ammonia (NH₃/₄)',
    unit: 'ppm',
    decimals: 2,
    help: 'Toxic. Should read effectively zero in a cycled tank.',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 10,
  ),
  ParameterDef(
    key: 'nitrite',
    name: 'Nitrite (NO₂)',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 10,
  ),
  // ORP can dip below zero in anoxic conditions — no hard floor.
  ParameterDef(
    key: 'orp',
    name: 'ORP',
    unit: 'mV',
    decimals: 0,
    plausibleMin: -300,
    plausibleMax: 700,
  ),
  ParameterDef(
    key: 'potassium',
    name: 'Potassium',
    unit: 'ppm',
    decimals: 0,
    minValue: 0,
    plausibleMin: 100,
    plausibleMax: 800,
  ),
  ParameterDef(
    key: 'strontium',
    name: 'Strontium',
    unit: 'ppm',
    decimals: 1,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 50,
  ),
  ParameterDef(
    key: 'iodine',
    name: 'Iodine',
    unit: 'ppm',
    decimals: 2,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
  ParameterDef(
    key: 'iron',
    name: 'Iron',
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
