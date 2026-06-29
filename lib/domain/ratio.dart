import '../data/database.dart';
import 'zones.dart';

/// Stable parameter keys used to compute the supported ratios.
const String kPhosphateKey = 'phosphate';
const String kNitrateKey = 'nitrate';
const String kMagnesiumKey = 'magnesium';
const String kCalciumKey = 'calcium';
const String kAlkalinityKey = 'alkalinity';

/// How a ratio is rendered as text/chart values.
enum RatioDisplay {
  /// `1 : N`, where N = denominator/numerator (e.g. PO₄ : NO₃ ≈ 1 : 100).
  oneToN,

  /// A single number = numerator/denominator, to one decimal (e.g. Mg : Ca ≈ 3.1).
  decimal,
}

/// A ratio between two tracked parameters that can be shown on the dashboard.
enum RatioKind {
  po4no3(kPhosphateKey, kNitrateKey, 'PO₄', 'NO₃', RatioDisplay.oneToN),
  mgca(kMagnesiumKey, kCalciumKey, 'Mg', 'Ca', RatioDisplay.decimal),
  caalk(kCalciumKey, kAlkalinityKey, 'Ca', 'Alk', RatioDisplay.decimal),
  mgalk(kMagnesiumKey, kAlkalinityKey, 'Mg', 'Alk', RatioDisplay.decimal);

  const RatioKind(this.numeratorKey, this.denominatorKey, this.numeratorSymbol,
      this.denominatorSymbol, this.display);

  final String numeratorKey;
  final String denominatorKey;
  final String numeratorSymbol;
  final String denominatorSymbol;
  final RatioDisplay display;
}

extension RatioKindZones on RatioKind {
  /// Recommended red/amber/green bounds expressed in the *displayed* metric
  /// space (the value [ratioChartY] plots): for PO₄ : NO₃ that is N = NO₃/PO₄
  /// (a ~100:1 NO₃:PO₄ "Redfield-style" target is widely recommended; lopsided
  /// ratios feed cyano/dinos), for Mg : Ca that is Mg/Ca (≈3:1, natural
  /// seawater ≈3.1). Used to color the cards and draw the graph zone bands.
  ZoneBounds get defaultBounds {
    switch (this) {
      case RatioKind.po4no3:
        return const ZoneBounds(
            amberLow: 25, greenLow: 50, greenHigh: 150, amberHigh: 250);
      case RatioKind.mgca:
        return const ZoneBounds(
            amberLow: 2.6, greenLow: 2.9, greenHigh: 3.3, amberHigh: 3.6);
      case RatioKind.caalk:
        // Ca (ppm) ÷ Alk (dKH). Ca and carbonate alkalinity are consumed
        // together when corals build CaCO₃, so this flags dosing imbalance.
        // NSW ≈ 412 / 7.0 ≈ 59; balanced reef setups (Ca 420–450, Alk 8–9)
        // land ≈ 48–56. Extremes hint that one is being dosed out of step.
        return const ZoneBounds(
            amberLow: 40, greenLow: 46, greenHigh: 62, amberHigh: 70);
      case RatioKind.mgalk:
        // Mg (ppm) ÷ Alk (dKH). Magnesium keeps Ca and alkalinity in solution;
        // a low value hints at why both are hard to hold. NSW ≈ 1280 / 7.0 ≈
        // 183; reef setups (Mg 1300–1400, Alk 8–9) land ≈ 155–185.
        return const ZoneBounds(
            amberLow: 135, greenLow: 150, greenHigh: 190, amberHigh: 210);
    }
  }

  /// Default display order, placing ratio cards after measurements until the
  /// user reorders them.
  int get defaultOrder => 1000 + index;
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
    case RatioDisplay.decimal:
      if (!ratio.isFinite) return '—';
      return ratio.toStringAsFixed(1);
  }
}

/// A short, language-neutral label for the value the zones classify (the
/// displayed metric): e.g. "NO₃ ÷ PO₄" for PO₄ : NO₃, "Mg ÷ Ca" for Mg : Ca.
String ratioMetricLabel(RatioKind kind) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      return '${kind.denominatorSymbol} ÷ ${kind.numeratorSymbol}';
    case RatioDisplay.decimal:
      return '${kind.numeratorSymbol} ÷ ${kind.denominatorSymbol}';
  }
}

/// Formats a zone-bound value [v] (expressed in the displayed metric space,
/// e.g. N for `1 : N`) the same way the ratio itself is shown.
String formatRatioBound(RatioKind kind, double v) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      return v == 0 ? '—' : formatRatioValue(kind, 1 / v);
    case RatioDisplay.decimal:
      return formatRatioValue(kind, v);
  }
}

/// The value to plot on the chart for a [ratio] of [kind] (NaN if undefined).
double ratioChartY(RatioKind kind, double ratio) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      return ratio > 0 ? 1 / ratio : double.nan;
    case RatioDisplay.decimal:
      return ratio;
  }
}

/// The effective zone bounds for [kind] on a tank: the per-tank row's bounds
/// when set, otherwise the kind's recommended defaults. (A row with no bounds
/// at all — e.g. created only to toggle visibility — falls back to defaults.)
ZoneBounds ratioBounds(RatioKind kind, RatioVisibility? row) {
  if (row == null) return kind.defaultBounds;
  final b = ZoneBounds(
    amberLow: row.amberLow,
    greenLow: row.greenLow,
    greenHigh: row.greenHigh,
    amberHigh: row.amberHigh,
  );
  return b.isEmpty ? kind.defaultBounds : b;
}

/// Health zone for a [ratio] of [kind], classifying the displayed metric
/// against [bounds].
Zone ratioZone(RatioKind kind, ZoneBounds bounds, double ratio) {
  final y = ratioChartY(kind, ratio);
  if (!y.isFinite) return Zone.unknown;
  return bounds.classify(y);
}

/// Whether a ratio card is shown, from its per-tank settings row (a missing
/// row means visible — the default).
bool ratioRowVisible(RatioVisibility? row) => row?.visible ?? true;

/// The dashboard display order of a ratio card from its settings row, falling
/// back to the kind's default order when no row exists yet.
double ratioRowOrder(RatioKind kind, RatioVisibility? row) =>
    (row?.displayOrder ?? kind.defaultOrder).toDouble();

/// A compact "Symbol value · Symbol value" breakdown of a ratio point's inputs.
String ratioBreakdown(RatioKind kind, RatioPoint p) =>
    '${kind.numeratorSymbol} ${formatRatio(p.numerator)}'
    ' · ${kind.denominatorSymbol} ${formatRatio(p.denominator)}';
