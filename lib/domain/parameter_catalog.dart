/// A reef water parameter that can be tracked. The catalog below is static
/// app data (not stored in the DB) so it can evolve without DB migrations.
class ParameterDef {
  const ParameterDef({
    required this.key,
    required this.name,
    required this.unit,
    required this.decimals,
    this.help,
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
}

/// The built-in catalog of typical reef aquarium parameters.
const List<ParameterDef> kReefParameters = [
  ParameterDef(
    key: 'temperature',
    name: 'Temperature',
    unit: '°C',
    decimals: 1,
    help: 'Water temperature. Stability matters more than the exact value.',
  ),
  ParameterDef(key: 'ph', name: 'pH', unit: 'pH', decimals: 2),
  ParameterDef(
    key: 'salinity',
    name: 'Salinity',
    unit: 'SG',
    decimals: 3,
    help: 'Specific gravity. ~1.026 SG ≈ 35 ppt.',
  ),
  ParameterDef(
    key: 'alkalinity',
    name: 'Alkalinity',
    unit: 'dKH',
    decimals: 1,
    help: 'Carbonate hardness. Keep stable — avoid swings.',
  ),
  ParameterDef(key: 'calcium', name: 'Calcium (Ca)', unit: 'ppm', decimals: 0),
  ParameterDef(
      key: 'magnesium', name: 'Magnesium (Mg)', unit: 'ppm', decimals: 0),
  ParameterDef(
    key: 'nitrate',
    name: 'Nitrate (NO₃)',
    unit: 'ppm',
    decimals: 1,
    help: 'A nutrient. Corals need a little; too much fuels algae.',
  ),
  ParameterDef(
    key: 'phosphate',
    name: 'Phosphate (PO₄)',
    unit: 'ppm',
    decimals: 2,
  ),
  ParameterDef(
    key: 'ammonia',
    name: 'Ammonia (NH₃/₄)',
    unit: 'ppm',
    decimals: 2,
    help: 'Toxic. Should read effectively zero in a cycled tank.',
  ),
  ParameterDef(key: 'nitrite', name: 'Nitrite (NO₂)', unit: 'ppm', decimals: 2),
  ParameterDef(key: 'orp', name: 'ORP', unit: 'mV', decimals: 0),
  ParameterDef(key: 'potassium', name: 'Potassium', unit: 'ppm', decimals: 0),
  ParameterDef(key: 'strontium', name: 'Strontium', unit: 'ppm', decimals: 1),
  ParameterDef(key: 'iodine', name: 'Iodine', unit: 'ppm', decimals: 2),
  ParameterDef(key: 'iron', name: 'Iron', unit: 'ppm', decimals: 2),
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
