import 'package:intl/intl.dart';

import 'parameter_catalog.dart';

/// Parses a user-entered number, accepting either `,` or `.` as the decimal
/// separator and rejecting non-finite values (`Infinity`/`NaN`), which
/// `double.tryParse` otherwise accepts and which corrupt charts, zone
/// classification and trend math once stored.
///
/// Separator semantics follow the active app locale (`Intl.defaultLocale`,
/// kept in sync with the resolved locale by the app builder):
/// - The locale's decimal separator is always a decimal point, so a Czech
///   user's `1,025` is 1.025 while an English user's `1.025` is too.
/// - The *opposite* separator in strict thousands positions is grouping:
///   `1,300` is 1300 in an English-locale app, `1.300` is 1300 in a German
///   one. Space-grouped input (`1 300`, cs/pl/ru style) is always grouping.
/// - A single opposite separator that cannot be grouping (`2,5` in an
///   English app — comma-only keyboards) is an unambiguous decimal.
/// - Input mixing both separators (`1.234,5`) is rejected as ambiguous.
///
/// Returns `null` when [text] is blank, ambiguous, or does not parse to a
/// finite number.
double? parseUserDouble(String? text) {
  var t = text?.trim() ?? '';
  if (t.isEmpty) return null;

  // Space-style thousands grouping (regular, no-break, or narrow no-break
  // spaces), stripped only when the spaces sit in strict grouping positions.
  if (RegExp(r'^[+-]?\d{1,3}([\u00A0\u202F ]\d{3})+([.,]\d+)?$').hasMatch(t)) {
    t = t.replaceAll(RegExp(r'[\u00A0\u202F ]'), '');
  }

  final hasDot = t.contains('.');
  final hasComma = t.contains(',');
  if (hasDot && hasComma) return null;

  if (hasDot || hasComma) {
    final sep = hasComma ? ',' : '.';
    final single = t.indexOf(sep) == t.lastIndexOf(sep);
    if (sep == _decimalSeparator()) {
      if (!single) return null;
      t = t.replaceAll(sep, '.');
    } else if (RegExp('^[+-]?\\d{1,3}(${RegExp.escape(sep)}\\d{3})+\$')
        .hasMatch(t)) {
      t = t.replaceAll(sep, '');
    } else if (single) {
      t = t.replaceAll(sep, '.');
    } else {
      return null;
    }
  }

  final value = double.tryParse(t);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// The active locale's decimal separator (`.` for en, `,` for cs/de/pl/ru).
String _decimalSeparator() =>
    NumberFormat.decimalPattern(Intl.defaultLocale).symbols.DECIMAL_SEP;

/// Formats [value] for display in the active app locale with exactly
/// [decimals] fraction digits — the display-side counterpart of
/// [parseUserDouble] (#39), so "2,5" typed by a cs/de user is echoed back as
/// "2,5" and not "2.5".
///
/// Grouping separators are deliberately turned off: formatted values are also
/// seeded into edit fields, and a grouped value with decimals (de "1.300,5")
/// mixes both separators, which [parseUserDouble] rejects as ambiguous.
String formatLocaleNumber(double value, int decimals) {
  final f = NumberFormat.decimalPatternDigits(
      locale: Intl.defaultLocale, decimalDigits: decimals)
    ..turnOffGrouping();
  return f.format(value);
}

/// Formats [value] like [formatLocaleNumber], but with at most [decimals]
/// fraction digits and no trailing zero fraction (e.g. `5`, `2,5`) — the app's
/// common style for dose amounts, gram weights and volumes.
String formatLocaleNumberTrim(double value, {int decimals = 1}) {
  final f = NumberFormat.decimalPattern(Intl.defaultLocale)
    ..turnOffGrouping()
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = decimals;
  return f.format(value);
}

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

/// Volume display unit. Canonical storage is always litres.
enum VolumeUnit {
  liters('L'),
  gallons('gal');

  const VolumeUnit(this.symbol);
  final String symbol;

  static VolumeUnit fromName(String? n) =>
      VolumeUnit.values.firstWhere((e) => e.name == n,
          orElse: () => VolumeUnit.liters);
}

/// User's preferred display units. Defaults: Celsius, ppt, and litres.
class UnitPrefs {
  const UnitPrefs({
    this.temp = TempUnit.celsius,
    this.salinity = SalinityUnit.ppt,
    this.volume = VolumeUnit.liters,
  });

  final TempUnit temp;
  final SalinityUnit salinity;
  final VolumeUnit volume;
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

// --- Volume (canonical = litres) -------------------------------------------

const double litersPerUsGallon = 3.785411784; // US liquid gallon

double litersToGallons(double l) => l / litersPerUsGallon;
double gallonsToLiters(double g) => g * litersPerUsGallon;

/// Converts a canonical litre value into [unit] for display.
double volumeToDisplay(double liters, VolumeUnit unit) =>
    unit == VolumeUnit.gallons ? litersToGallons(liters) : liters;

/// Converts a value typed in [unit] back to canonical litres for storage.
double volumeToCanonical(double display, VolumeUnit unit) =>
    unit == VolumeUnit.gallons ? gallonsToLiters(display) : display;

/// Formats a canonical litre value as a bare number string in [unit] (whole
/// numbers without decimals, otherwise one decimal place).
String formatVolume(double liters, VolumeUnit unit) =>
    formatLocaleNumberTrim(volumeToDisplay(liters, unit));

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

  /// Formats a canonical value for display in the preferred unit, using the
  /// active locale's decimal separator.
  String format(double canonical) =>
      formatLocaleNumber(toDisplay(canonical), decimals);

  /// Formats the change between two canonical values in the display unit,
  /// always prefixed with an explicit sign (e.g. "+0.2", "-0.1", "0.0").
  ///
  /// Deltas that round to zero at the configured precision (including a negative
  /// delta like `-0.04` that would otherwise render as `-0.0`) are normalized to
  /// an unsigned zero, so the sign always matches the displayed magnitude.
  String formatChange(double current, double previous) {
    final delta = toDisplay(current) - toDisplay(previous);
    // Round first (via the fixed-decimals string) so the sign reflects what's
    // actually shown; only then apply the locale display formatting.
    final rounded = double.parse(delta.toStringAsFixed(decimals));
    if (rounded == 0) return formatLocaleNumber(0, decimals);
    final s = formatLocaleNumber(rounded, decimals);
    return rounded > 0 ? '+$s' : s;
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
