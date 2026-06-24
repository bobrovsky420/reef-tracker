import '../data/database.dart';

/// Stable parameter keys used to compute the PO₄ : NO₃ ratio.
const String kPhosphateKey = 'phosphate';
const String kNitrateKey = 'nitrate';

/// A single point of the PO₄ : NO₃ ratio time series.
class RatioPoint {
  const RatioPoint({
    required this.time,
    required this.ratio,
    required this.phosphate,
    required this.nitrate,
  });

  final DateTime time;

  /// PO₄ divided by NO₃ (both in their canonical ppm values).
  final double ratio;
  final double phosphate;
  final double nitrate;
}

/// Computes the PO₄ : NO₃ ratio for the latest available measurement of each.
/// Returns null when either value is missing or nitrate is zero (undefined
/// ratio). [nitrate] and [phosphate] are newest-first (as stored for a tank).
RatioPoint? latestRatio(List<Reading> nitrate, List<Reading> phosphate) {
  if (nitrate.isEmpty || phosphate.isEmpty) return null;
  final no3 = nitrate.first;
  final po4 = phosphate.first;
  if (no3.value == 0) return null;
  return RatioPoint(
    time: po4.takenAt.isAfter(no3.takenAt) ? po4.takenAt : no3.takenAt,
    ratio: po4.value / no3.value,
    phosphate: po4.value,
    nitrate: no3.value,
  );
}

/// Builds the PO₄ : NO₃ ratio over time. For each timestamp at which either
/// parameter was measured, the most recent value of the *other* parameter is
/// carried forward, so a ratio is produced whenever both have been recorded at
/// least once. [nitrate] and [phosphate] must be oldest-first.
List<RatioPoint> computeRatioSeries(
    List<Reading> nitrate, List<Reading> phosphate) {
  if (nitrate.isEmpty || phosphate.isEmpty) return const [];

  final times = <DateTime>{
    for (final r in nitrate) r.takenAt,
    for (final r in phosphate) r.takenAt,
  }.toList()
    ..sort();

  final points = <RatioPoint>[];
  for (final t in times) {
    final no3 = _latestAtOrBefore(nitrate, t);
    final po4 = _latestAtOrBefore(phosphate, t);
    if (no3 == null || po4 == null) continue;
    if (no3.value == 0) continue;
    points.add(RatioPoint(
      time: t,
      ratio: po4.value / no3.value,
      phosphate: po4.value,
      nitrate: no3.value,
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
/// small (~0.01) and large (~150) values read cleanly. Used for the raw PO₄/NO₃
/// measurements shown alongside the ratio.
String formatRatio(double r) {
  if (!r.isFinite) return '—';
  if (r >= 100) return r.toStringAsFixed(0);
  if (r >= 10) return r.toStringAsFixed(1);
  if (r >= 1) return r.toStringAsFixed(2);
  if (r >= 0.1) return r.toStringAsFixed(3);
  return r.toStringAsFixed(4);
}

/// Formats a PO₄/NO₃ ratio in the conventional reef form `1 : N`, where
/// N = NO₃/PO₄ (e.g. a ratio of 0.01 reads as `1 : 100`).
String formatRatioOneToN(double ratio) {
  if (!ratio.isFinite || ratio <= 0) return '—';
  return '1 : ${formatRatioN(1 / ratio)}';
}

/// Formats just the `N` side of a `1 : N` ratio (used for chart axis labels).
String formatRatioN(double n) {
  if (!n.isFinite) return '—';
  if (n >= 10) return n.toStringAsFixed(0);
  if (n >= 1) return n.toStringAsFixed(1);
  return n.toStringAsFixed(2);
}
