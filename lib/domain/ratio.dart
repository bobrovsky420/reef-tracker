/// Pure, testable ratio math and presentation helpers. Like `trend.dart` and
/// `dose_calculator.dart` this has no DB dependency — it works on plain
/// records ([RatioReading], [RatioSettings]) mapped from storage rows at the
/// data boundary, so it can be unit-tested in isolation.
library;

import 'units.dart';
import 'zones.dart';

part 'ratio.g.dart';

/// A timestamped parameter value used by the ratio math. A plain record so the
/// domain stays decoupled from the DB's `Reading` row (callers map via
/// `Reading.ratioReading`).
typedef RatioReading = ({DateTime takenAt, double value});

/// A tank's stored settings for one ratio card as the domain sees them,
/// mapped from the `RatioVisibilities` row at the data boundary (via
/// `RatioVisibility.settings`). [bounds] may be empty (= no custom bounds).
typedef RatioSettings = ({bool visible, int displayOrder, ZoneBounds bounds});

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

  const RatioKind(
    this.numeratorKey,
    this.denominatorKey,
    this.numeratorSymbol,
    this.denominatorSymbol,
    this.display,
  );

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
  ///
  /// The data ([kRatioDefaultBounds]) is generated from the `ratios` section
  /// of `tank_presets.yaml`, which also documents the chemistry behind each
  /// range — edit it there, then run `dart run tool/gen_tank_presets.dart`.
  ZoneBounds get defaultBounds => kRatioDefaultBounds[this]!;

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

/// Maximum age gap between the two halves of a "current" ratio: when the
/// latest numerator and denominator readings lie further apart than this, the
/// pair no longer describes a single tank state (today's PO₄ against a
/// months-old NO₃) and [latestRatio] reports null. Mirrors the health score's
/// freshness idea (`kHealthFreshnessDays`).
const Duration kRatioMaxSkew = Duration(days: 30);

/// Computes the ratio for the latest available measurement of each parameter.
/// Returns null when either value is missing, the denominator is zero
/// (undefined ratio), or the two readings are further apart than [maxSkew]
/// (the pair is half stale, not a confident "current" ratio). Both lists are
/// newest-first (as stored for a tank).
RatioPoint? latestRatio(
  List<RatioReading> numerator,
  List<RatioReading> denominator, {
  Duration maxSkew = kRatioMaxSkew,
}) {
  if (numerator.isEmpty || denominator.isEmpty) return null;
  final num = numerator.first;
  final den = denominator.first;
  if (den.value == 0) return null;
  if (num.takenAt.difference(den.takenAt).abs() > maxSkew) return null;
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
///
/// A single merge pass with two carry-forward cursors — O(n+m), not a rescan of
/// both lists per merged timestamp (T15); this runs on the dashboard path for
/// every visible ratio card.
List<RatioPoint> computeRatioSeries(
  List<RatioReading> numerator,
  List<RatioReading> denominator,
) {
  if (numerator.isEmpty || denominator.isEmpty) return const [];

  final points = <RatioPoint>[];
  var ni = 0; // next unconsumed numerator reading
  var di = 0; // next unconsumed denominator reading
  RatioReading? num; // carried-forward latest numerator at or before t
  RatioReading? den; // carried-forward latest denominator at or before t
  while (ni < numerator.length || di < denominator.length) {
    // The earliest timestamp not yet processed across both lists.
    final nt = ni < numerator.length ? numerator[ni].takenAt : null;
    final dt = di < denominator.length ? denominator[di].takenAt : null;
    final t = nt == null || (dt != null && dt.isBefore(nt)) ? dt! : nt;
    // Consume every reading at [t] (both lists, so equal timestamps merge into
    // one point); the last one wins, matching "the most recent value".
    while (ni < numerator.length && !numerator[ni].takenAt.isAfter(t)) {
      num = numerator[ni++];
    }
    while (di < denominator.length && !denominator[di].takenAt.isAfter(t)) {
      den = denominator[di++];
    }
    if (num == null || den == null) continue;
    if (den.value == 0) continue;
    points.add(
      RatioPoint(
        time: t,
        ratio: num.value / den.value,
        numerator: num.value,
        denominator: den.value,
      ),
    );
  }
  return points;
}

/// Formats a value with precision that scales with its magnitude, so both
/// small (~0.01) and large (~1400) values read cleanly. Used for the raw
/// measurements shown alongside the ratio.
String formatRatio(double r) {
  if (!r.isFinite) return '—';
  if (r >= 100) return formatLocaleNumber(r, 0);
  if (r >= 10) return formatLocaleNumber(r, 1);
  if (r >= 1) return formatLocaleNumber(r, 2);
  if (r >= 0.1) return formatLocaleNumber(r, 3);
  return formatLocaleNumber(r, 4);
}

/// Formats just the `N` side of a `1 : N` / `N : 1` ratio (and chart labels).
String formatRatioN(double n) {
  if (!n.isFinite) return '—';
  if (n >= 10) return formatLocaleNumber(n, 0);
  if (n >= 1) return formatLocaleNumber(n, 1);
  return formatLocaleNumber(n, 2);
}

/// Formats a [ratio] (numerator/denominator) for display per [kind].
String formatRatioValue(RatioKind kind, double ratio) {
  switch (kind.display) {
    case RatioDisplay.oneToN:
      if (!ratio.isFinite || ratio <= 0) return '—';
      return '1 : ${formatRatioN(1 / ratio)}';
    case RatioDisplay.decimal:
      if (!ratio.isFinite) return '—';
      return formatLocaleNumber(ratio, 1);
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

/// The effective zone bounds for [kind] on a tank: the per-tank stored bounds
/// when set, otherwise the kind's recommended defaults. (Settings with no
/// bounds at all — e.g. created only to toggle visibility — fall back to
/// defaults.)
ZoneBounds ratioBounds(RatioKind kind, RatioSettings? settings) {
  if (settings == null || settings.bounds.isEmpty) return kind.defaultBounds;
  return settings.bounds;
}

/// Health zone for a [ratio] of [kind], classifying the displayed metric
/// against [bounds].
Zone ratioZone(RatioKind kind, ZoneBounds bounds, double ratio) {
  final y = ratioChartY(kind, ratio);
  if (!y.isFinite) return Zone.unknown;
  return bounds.classify(y);
}

/// Whether a ratio card is shown, from its per-tank [settings] (missing
/// settings mean visible — the default).
bool ratioRowVisible(RatioSettings? settings) => settings?.visible ?? true;

/// The dashboard display order of a ratio card from its [settings], falling
/// back to the kind's default order when none are stored yet.
double ratioRowOrder(RatioKind kind, RatioSettings? settings) =>
    (settings?.displayOrder ?? kind.defaultOrder).toDouble();

/// A compact "Symbol value · Symbol value" breakdown of a ratio point's inputs.
String ratioBreakdown(RatioKind kind, RatioPoint p) =>
    '${kind.numeratorSymbol} ${formatRatio(p.numerator)}'
    ' · ${kind.denominatorSymbol} ${formatRatio(p.denominator)}';
