/// Locale- and unit-aware rendering for values read live from LAN devices
/// (#102): the #39 convention — locale decimal separators in every display
/// path — extended to the device screens, and temperatures converted to the
/// user's TempUnit preference.
///
/// The conversion deliberately includes *equipment* temperatures (ReefRun
/// pump motors, ReefLED heatsinks), not only water probes: every temperature
/// the app renders follows the preference, so a Fahrenheit keeper is never
/// handed °C to convert in their head. Device-native display for the
/// equipment rows was considered and rejected for the inconsistency it would
/// create next to the converted water rows on the same page.
library;

import '../domain/units.dart';

/// A live device value in the app's common style: locale decimal separator,
/// whole values keeping one decimal ("350,0") so they still read as
/// measurements, fractional values trimmed to their own precision.
String formatDeviceValue(double v) => v == v.roundToDouble()
    ? formatLocaleNumber(v, 1)
    : formatLocaleNumberTrim(v, decimals: 3);

/// A device temperature (always reported in canonical °C) in the user's
/// display unit, with the unit symbol.
String formatDeviceTempC(double celsius, UnitPrefs prefs) {
  final pres = presentationFor('temperature', '°C', 1, prefs);
  return '${formatLocaleNumber(pres.toDisplay(celsius), pres.decimals)} '
      '${pres.unitLabel}';
}

/// One device reading as `value unit` — temperature converted per [prefs],
/// everything else in the unit the device reported (an Apex/ReefFactory
/// salinity probe's ppt stays ppt here; only the save path converts it to
/// canonical SG).
String formatDeviceReading({
  required String paramKey,
  required double value,
  required String unit,
  required UnitPrefs prefs,
}) {
  if (paramKey == 'temperature') return formatDeviceTempC(value, prefs);
  final s = formatDeviceValue(value);
  return unit.isEmpty ? s : '$s $unit';
}
