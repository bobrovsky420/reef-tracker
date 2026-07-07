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
    this.category = ParamCategory.core,
    this.symbol,
    this.displayFactor = 1,
    this.minValue,
    this.plausibleMin,
    this.plausibleMax,
  });

  /// Stable identifier persisted in the database (e.g. `alkalinity`).
  final String key;

  /// Default unit of measure (e.g. `dKH`). Editable per tank — except for
  /// parameters with a [displayFactor], whose unit is fixed to this label.
  final String unit;

  /// How many decimal places to show when formatting values.
  final int decimals;

  /// Where the parameter surfaces in the app: [ParamCategory.core] lives on
  /// the dashboard/Add Reading; everything else lives on the Microelements
  /// screen (U17).
  final ParamCategory category;

  /// Chemical element symbol ("Zn") for microelements, shown next to the
  /// localized name so rows match the symbols on an ICP report. Null for the
  /// classic core parameters.
  final String? symbol;

  /// Canonical→display multiplier. Storage stays canonical ppm (mg/L) for all
  /// concentrations; trace elements are *displayed* in µg/L via factor 1000
  /// (the same stored-canonical/display-converted pattern as °C→°F). Fixed
  /// per parameter — no user preference — so [unit] is the display label.
  final double displayFactor;

  /// True for parameters shown on the Microelements screen instead of the
  /// dashboard (U17).
  bool get isMicro => category != ParamCategory.core;

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

/// Coarse grouping of the catalog, mirroring how ICP labs (and hobbyists)
/// think about seawater chemistry. [core] parameters are the classic
/// dashboard set (temp, pH, alk, nutrients, …); the other three categories
/// are the ICP panel and surface on the Microelements screen (U17):
/// [major] = bulk ions with wide tolerances, [trace] = desirable at low
/// levels, [contaminant] = wanted near zero (one-sided bounds).
enum ParamCategory { core, major, trace, contaminant }

/// True when [paramKey] belongs to a core (dashboard) parameter. Unknown keys
/// count as core — the pre-catalog behavior, so hand-edited/legacy rows keep
/// appearing where they always did.
bool isCoreParam(String paramKey) =>
    (kParameterByKey[paramKey]?.category ?? ParamCategory.core) ==
    ParamCategory.core;

/// The microelement panel (everything not [ParamCategory.core]), in catalog
/// order — the row order of the Microelements screen.
final List<ParameterDef> kMicroParameters = [
  for (final p in kReefParameters)
    if (p.isMicro) p,
];

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
  // --- Microelements (U17): the ICP panel. Categories major/trace/
  // contaminant surface on the Microelements screen, not the dashboard.
  // Canonical storage stays ppm (mg/L) for every concentration; elements
  // measured in the µg/L range display through displayFactor 1000.
  // Strontium, iodine and iron predate the panel: their keys and stored ppm
  // values are unchanged, they only moved category (iodine/iron additionally
  // gained the µg/L display, which is presentation-only).
  ParameterDef(
    key: 'strontium',
    unit: 'ppm',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Sr',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 50,
  ),
  ParameterDef(
    key: 'iodine',
    unit: 'µg/L',
    decimals: 0,
    category: ParamCategory.trace,
    symbol: 'I',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
  ParameterDef(
    key: 'iron',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Fe',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
  // Major ions (mg/L on ICP reports; wide tolerances).
  ParameterDef(
    key: 'sodium',
    unit: 'ppm',
    decimals: 0,
    category: ParamCategory.major,
    symbol: 'Na',
    minValue: 0,
    plausibleMin: 3000,
    plausibleMax: 20000,
  ),
  ParameterDef(
    key: 'sulfur',
    unit: 'ppm',
    decimals: 0,
    category: ParamCategory.major,
    symbol: 'S',
    minValue: 0,
    plausibleMin: 200,
    plausibleMax: 2000,
  ),
  ParameterDef(
    key: 'boron',
    unit: 'ppm',
    decimals: 1,
    category: ParamCategory.major,
    symbol: 'B',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 20,
  ),
  ParameterDef(
    key: 'bromine',
    unit: 'ppm',
    decimals: 0,
    category: ParamCategory.major,
    symbol: 'Br',
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 300,
  ),
  // Silicon sits with the majors on ICP reports but is wanted *low*
  // (diatoms) — its default bounds are one-sided like a contaminant's.
  ParameterDef(
    key: 'silicon',
    unit: 'µg/L',
    decimals: 0,
    category: ParamCategory.major,
    symbol: 'Si',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 10,
  ),
  // Desirable trace elements (µg/L range).
  ParameterDef(
    key: 'zinc',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Zn',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'vanadium',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'V',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'copper',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Cu',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'nickel',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Ni',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'manganese',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Mn',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'molybdenum',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Mo',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'chromium',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.trace,
    symbol: 'Cr',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'cobalt',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.trace,
    symbol: 'Co',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'lithium',
    unit: 'µg/L',
    decimals: 0,
    category: ParamCategory.trace,
    symbol: 'Li',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 5,
  ),
  ParameterDef(
    key: 'barium',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.trace,
    symbol: 'Ba',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'selenium',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.trace,
    symbol: 'Se',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  // Contaminants: wanted near zero, one-sided default bounds.
  ParameterDef(
    key: 'aluminium',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.contaminant,
    symbol: 'Al',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 2,
  ),
  ParameterDef(
    key: 'antimony',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Sb',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'tin',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Sn',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'beryllium',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Be',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'silver',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Ag',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'tungsten',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'W',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'lanthanum',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'La',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'titanium',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.contaminant,
    symbol: 'Ti',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'zirconium',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Zr',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'arsenic',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.contaminant,
    symbol: 'As',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'cadmium',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Cd',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'mercury',
    unit: 'µg/L',
    decimals: 2,
    category: ParamCategory.contaminant,
    symbol: 'Hg',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
  ),
  ParameterDef(
    key: 'lead',
    unit: 'µg/L',
    decimals: 1,
    category: ParamCategory.contaminant,
    symbol: 'Pb',
    displayFactor: 1000,
    minValue: 0,
    plausibleMin: 0,
    plausibleMax: 1,
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
