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

/// A ratio between two tracked parameters that can be shown on the dashboard.
enum RatioKind {
  po4no3(kPhosphateKey, kNitrateKey, 'PO₄', 'NO₃'),
  mgca(kMagnesiumKey, kCalciumKey, 'Mg', 'Ca'),
  caalk(kCalciumKey, kAlkalinityKey, 'Ca', 'Alk'),
  mgalk(kMagnesiumKey, kAlkalinityKey, 'Mg', 'Alk');

  const RatioKind(
    this.numeratorKey,
    this.denominatorKey,
    this.numeratorSymbol,
    this.denominatorSymbol,
  );

  final String numeratorKey;
  final String denominatorKey;
  final String numeratorSymbol;
  final String denominatorSymbol;
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
/// Same-day points collapse into one (unless [collapseSameDay] is false): a
/// testing session stamps each measurement with its own exact time — a Hanna
/// checker records NO₃ at 14:15 and PO₄ at 14:20 of the same sitting — and the
/// carry-forward would otherwise plot the 14:15 pairing of the *new* NO₃ with
/// the *previous* PO₄ as its own dot, right beside the real one. That
/// intermediate pairing is an artifact of the order the session was entered in,
/// not a tank state that ever existed, so a day contributes a single point,
/// carrying that day's last value of each parameter (#33). Days are the local
/// calendar days of the reading timestamps.
///
/// A single merge pass with two carry-forward cursors — O(n+m), not a rescan of
/// both lists per merged timestamp (T15); this runs on the dashboard path for
/// every visible ratio card.
List<RatioPoint> computeRatioSeries(
  List<RatioReading> numerator,
  List<RatioReading> denominator, {
  bool collapseSameDay = true,
}) {
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
    final point = RatioPoint(
      time: t,
      ratio: num.value / den.value,
      numerator: num.value,
      denominator: den.value,
    );
    // Later in the same day supersedes: by construction the last point of a day
    // pairs that day's final value of both parameters.
    if (collapseSameDay && points.isNotEmpty && _sameDay(points.last.time, t)) {
      points[points.length - 1] = point;
    } else {
      points.add(point);
    }
  }
  return points;
}

/// Whether two instants fall on the same local calendar day. Compared
/// field-wise rather than by truncating to midnight, which would be ambiguous
/// on a DST transition day.
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The value to plot on the chart for a [ratio] of [kind] (NaN if undefined).
double ratioChartY(RatioKind kind, double ratio) => switch (kind) {
  RatioKind.po4no3 => ratio > 0 ? 1 / ratio : double.nan,
  RatioKind.mgca || RatioKind.caalk || RatioKind.mgalk => ratio,
};

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
///
/// Each side is formatted with **its own parameter's** presentation, so a value
/// reads here exactly as it does on the dashboard card and in the parameter's
/// history — same unit, same fixed number of decimals. An earlier version
/// derived the precision from the value's magnitude instead, which made the
/// column ragged (PO₄ "0.114" beside "0.12" beside "0.1") and disagreed with
/// the rest of the app.
String ratioBreakdown(
  RatioKind kind,
  RatioPoint p, {
  required ParamPresentation numerator,
  required ParamPresentation denominator,
}) =>
    '${kind.numeratorSymbol} ${numerator.format(p.numerator)}'
    ' · ${kind.denominatorSymbol} ${denominator.format(p.denominator)}';
