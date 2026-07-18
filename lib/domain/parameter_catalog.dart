/// Static catalog of every trackable water parameter — the core dashboard
/// set plus the ICP microelement panel (U17). App data, not stored in the
/// DB, so it can evolve without a migration.
///
/// **The data ([kReefParameters]) is GENERATED from `parameters.yaml`** — do
/// not edit it by hand. Edit the YAML, then run
/// `dart run tool/gen_parameters.dart` to regenerate
/// `parameter_catalog.g.dart`. This file owns the model + lookups.
library;

part 'parameter_catalog.g.dart';

/// A reef water parameter that can be tracked. The catalog data lives in
/// `parameters.yaml` (generated into [kReefParameters]) so it is static app
/// data (not stored in the DB) and can evolve without DB migrations.
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
    this.dashboardGroup,
    this.symbol,
    this.displayFactor = 1,
    this.minValue,
    this.plausibleMin,
    this.plausibleMax,
  });

  /// Stable identifier persisted in the database (e.g. `alkalinity`).
  final String key;

  /// Default unit of measure (e.g. `dKH`). Editable per tank — except for
  /// microelements ([isMicro]), whose unit is fixed to this label so the
  /// panel always mirrors the units printed on an ICP report.
  final String unit;

  /// How many decimal places to show when formatting values.
  final int decimals;

  /// Where the parameter surfaces in the app: [ParamCategory.core] lives on
  /// the dashboard/Add Reading; everything else lives on the Microelements
  /// screen (U17).
  final ParamCategory category;

  /// Fixed dashboard section a core parameter renders in (REDESIGN #6).
  /// Always set for [ParamCategory.core] entries (the generator enforces it),
  /// null for microelements — and null for unknown legacy keys looked up via
  /// [kParameterByKey], which the dashboard renders in a trailing headerless
  /// section.
  final DashboardGroup? dashboardGroup;

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

/// The grouped dashboard's fixed sections for core parameters (REDESIGN #6):
/// [core] = the reef-building chemistry trio (alk, Ca, Mg), [nutrients] = the
/// nitrogen/phosphorus cycle (NO₃, PO₄, NH₃, NO₂), [environment] = physical
/// water state (temperature, pH, salinity, ORP). Ratios and the micro summary
/// tile have their own dashboard sections outside this enum.
enum DashboardGroup { core, nutrients, environment }

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

/// Lookup by key for O(1) access.
final Map<String, ParameterDef> kParameterByKey = {
  for (final p in kReefParameters) p.key: p,
};

/// Catalog position by key — the stable tiebreak of the dashboard sort
/// (REDESIGN #6) for the fresh-install case where a ratio's default order
/// collides numerically with a parameter's stored order.
final Map<String, int> kParameterIndexByKey = {
  for (var i = 0; i < kReefParameters.length; i++) kReefParameters[i].key: i,
};

/// Formats [value] using the parameter's configured precision.
String formatParamValue(String paramKey, double value) {
  final decimals = kParameterByKey[paramKey]?.decimals ?? 2;
  return value.toStringAsFixed(decimals);
}
