import '../data/database.dart';

/// Stable parameter keys used to compute the supported ratios.
const String kPhosphateKey = 'phosphate';
const String kNitrateKey = 'nitrate';
const String kMagnesiumKey = 'magnesium';
const String kCalciumKey = 'calcium';

/// How a ratio is rendered as text/chart values.
enum RatioDisplay {
  /// `1 : N`, where N = denominator/numerator (e.g. PO₄ : NO₃ ≈ 1 : 100).
  oneToN,

  /// `N : 1`, where N = numerator/denominator (e.g. Mg : Ca ≈ 3 : 1).
  nToOne,
}

/// A ratio between two tracked parameters that can be shown on the dashboard.
enum RatioKind {
  po4no3(kPhosphateKey, kNitrateKey, 'PO₄', 'NO₃', RatioDisplay.oneToN),
  mgca(kMagnesiumKey, kCalciumKey, 'Mg', 'Ca', RatioDisplay.nToOne);

  const RatioKind(this.numeratorKey, this.denominatorKey, this.numeratorSymbol,
      this.denominatorSymbol, this.display);

  final String numeratorKey;
  final String denominatorKey;
  final String numeratorSymbol;
  final String denominatorSymbol;
  final RatioDisplay display;
}

/// A single point of a ratio time series. [ratio] is numerator/denominator.
class RatioPoint {
  const RatioPoint({
    required this.time,
    required this.ratio,
    required this.numerator,
    required this.denominator,
  });

  final DateTime time;
  final double ratio;
  final double numerator;
  final double denominator;
}

/// Computes the ratio for the latest available measurement of each parameter.
/// Returns null when either value is missing or the denominator is zero
/// (undefined ratio). Both lists are newest-first (as stored for a tank).
RatioPoint? latestRatio(List<Reading> numerator, List<Reading> denominator) {
  if (numerator.isEmpty || denominator.isEmpty) return null;
  final num = numerator.first;
  final den = denominator.first;
  if (den.value == 0) return null;
  return RatioPoint(
    time: num.takenAt.isAfter(den.takenAt) ? num.takenAt : den.takenAt,
    ratio: num.value / den.value,
    numerator: num.value,
    denominator: den.value,
  );
}

/// Builds the ratio over time. For each timestamp at which either parameter was
/// measured, the most recent value of the *other* parameter is carried forward,
/// so a ratio is produced whenever both have been recorded at least once. Both
/// lists must be oldest-first.
List<RatioPoint> computeRatioSeries(
    List<Reading> numerator, List<Reading> denominator) {
  if (numerator.isEmpty || denominator.isEmpty) return const [];

  final times = <DateTime>{
    for (final r in numerator) r.takenAt,
    for (final r in denominator) r.takenAt,
  }.toList()
    ..sort();

  final points = <RatioPoint>[];
  for (final t in times) {
    final num = _latestAtOrBefore(numerator, t);
    final den = _latestAtOrBefore(denominator, t);
    if (num == null || den == null) continue;
    if (den.value == 0) continue;
    points.add(RatioPoint(
      time: t,
      ratio: num.value / den.value,
      numerator: num.value,
      denominator: den.value,
    ));
  }
  return points;
}

/// Last reading in [readings] (oldest-first) taken at or before [t], or null.
Reading? _latestAtOrBefore(List<Reading> readings, DateTime t) {
  Reading? found;
  for (final r in readings) {
    if (r.takenAt.isAfter(t)) break;
    found = r;
  }
  return found;
}

/// Formats a value with precision that scales with its magnitude, so both
/// small (~0.01) and large (~1400) values read cleanly. Used for the raw
/// measurements shown alongside the ratio.
String formatRatio(double r) {
  if (!r.isFinite) return '—';
  if (r >= 100) return r.toStringAsFixed(0);
  if (r >= 10) return r.toStringAsFixed(1);
  if (r >= 1) return r.toStringAsFixed(2);
  if (r >= 0.1) return r.toStringAsFixed(3);
  return r.toStringAsFixed(4);
}

/// Formats just the `N` side of a `1 : N` / `N : 1` ratio (and chart labels).
String formatRatioN(double n) {
  if (!n.isFinite) return '—';
  if (n >= 10) return n.toStringAsFixed(0);
  if (n >= 1) return n.toStringAsFixed(1);
  return n.toStringAsFixed(2);
}

/// Formats a [ratio] (numerator/denominator) for display per [kind].
String formatRatioValue(RatioKind kind, double ratio) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      if (!ratio.isFinite || ratio <= 0) return '—';
      return '1 : ${formatRatioN(1 / ratio)}';
    case RatioDisplay.nToOne:
      if (!ratio.isFinite || ratio <= 0) return '—';
      return '${formatRatioN(ratio)} : 1';
  }
}

/// The value to plot on the chart for a [ratio] of [kind] (NaN if undefined).
double ratioChartY(RatioKind kind, double ratio) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      return ratio > 0 ? 1 / ratio : double.nan;
    case RatioDisplay.nToOne:
      return ratio;
  }
}

/// A compact "Symbol value · Symbol value" breakdown of a ratio point's inputs.
String ratioBreakdown(RatioKind kind, RatioPoint p) =>
    '${kind.numeratorSymbol} ${formatRatio(p.numerator)}'
    ' · ${kind.denominatorSymbol} ${formatRatio(p.denominator)}';
