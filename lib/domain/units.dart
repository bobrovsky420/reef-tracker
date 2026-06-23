import 'parameter_catalog.dart';

/// Temperature display unit. Canonical storage is always Celsius.
enum TempUnit {
  celsius('°C'),
  fahrenheit('°F');

  const TempUnit(this.symbol);
  final String symbol;

  static TempUnit fromName(String? n) =>
      TempUnit.values.firstWhere((e) => e.name == n,
          orElse: () => TempUnit.celsius);
}

/// Salinity display unit. Canonical storage is always specific gravity (SG).
enum SalinityUnit {
  ppt('ppt'),
  sg('SG');

  const SalinityUnit(this.symbol);
  final String symbol;

  static SalinityUnit fromName(String? n) =>
      SalinityUnit.values.firstWhere((e) => e.name == n,
          orElse: () => SalinityUnit.ppt);
}

/// User's preferred display units. Defaults: Celsius and ppt.
class UnitPrefs {
  const UnitPrefs({
    this.temp = TempUnit.celsius,
    this.salinity = SalinityUnit.ppt,
  });

  final TempUnit temp;
  final SalinityUnit salinity;
}

// --- Temperature (canonical = Celsius) -------------------------------------

double celsiusToF(double c) => c * 9 / 5 + 32;
double fToCelsius(double f) => (f - 32) * 5 / 9;

// --- Salinity (canonical = specific gravity, referenced at 25 °C) ----------
//
// Anchored on the standard reference point 35 ppt = 1.0264 SG at 25 °C
// (i.e. SG = 1 + ppt * 0.0264/35). This is a linear approximation valid for
// the brackish-to-marine range hobbyists care about.

const double sgPerPpt = 0.0264 / 35; // ≈ 0.00075428...

double pptToSg(double ppt) => 1 + ppt * sgPerPpt;
double sgToPpt(double sg) => (sg - 1) / sgPerPpt;

/// How to present a parameter's value: the unit label, decimals, and the
/// conversions between canonical storage and the user's display unit.
class ParamPresentation {
  const ParamPresentation({
    required this.unitLabel,
    required this.decimals,
    required this.toDisplay,
    required this.toCanonical,
    this.unitFollowsSettings = false,
  });

  final String unitLabel;
  final int decimals;
  final double Function(double canonical) toDisplay;
  final double Function(double display) toCanonical;

  /// True for temperature/salinity, whose unit comes from app settings rather
  /// than the per-parameter unit field.
  final bool unitFollowsSettings;

  /// Formats a canonical value for display in the preferred unit.
  String format(double canonical) =>
      toDisplay(canonical).toStringAsFixed(decimals);

  /// Formats the change between two canonical values in the display unit,
  /// always prefixed with an explicit sign (e.g. "+0.2", "-0.1", "0.0").
  String formatChange(double current, double previous) {
    final delta = toDisplay(current) - toDisplay(previous);
    final s = delta.toStringAsFixed(decimals);
    return delta > 0 ? '+$s' : s;
  }
}

/// Builds the presentation for a parameter given its stored unit/decimals and
/// the user's unit preferences. Temperature and salinity are converted; all
/// other parameters are shown as-is in their stored unit.
ParamPresentation presentationFor(
  String paramKey,
  String storedUnit,
  int storedDecimals,
  UnitPrefs prefs,
) {
  switch (paramKey) {
    case 'temperature':
      final u = prefs.temp;
      final f = u == TempUnit.fahrenheit;
      return ParamPresentation(
        unitLabel: u.symbol,
        decimals: 1,
        toDisplay: (c) => f ? celsiusToF(c) : c,
        toCanonical: (v) => f ? fToCelsius(v) : v,
        unitFollowsSettings: true,
      );
    case 'salinity':
      final u = prefs.salinity;
      final ppt = u == SalinityUnit.ppt;
      return ParamPresentation(
        unitLabel: u.symbol,
        decimals: ppt ? 1 : 3,
        toDisplay: (sg) => ppt ? sgToPpt(sg) : sg,
        toCanonical: (v) => ppt ? pptToSg(v) : v,
        unitFollowsSettings: true,
      );
    default:
      return ParamPresentation(
        unitLabel: storedUnit,
        decimals: storedDecimals,
        toDisplay: (v) => v,
        toCanonical: (v) => v,
      );
  }
}

/// Convenience overload using the catalog's default decimals for [paramKey].
ParamPresentation presentationForKey(
        String paramKey, String storedUnit, UnitPrefs prefs) =>
    presentationFor(paramKey, storedUnit,
        kParameterByKey[paramKey]?.decimals ?? 2, prefs);
