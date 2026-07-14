/// Pure, testable tank-stability scoring. Like `health_score.dart` and
/// `trend.dart` this has no Flutter and no DB dependency — it works on plain
/// numbers and [ZoneBounds] so it can be unit-tested in isolation.
///
/// Where the health score answers *"where do the values sit right now?"*, the
/// stability score answers *"how much have they been swinging?"* — the reef
/// keeper's second axis: a tank whose alkalinity oscillates between 7 and
/// 10 dKH is in trouble even when today's reading happens to be green.
///
/// Per parameter, the recent readings (a [kStabilityWindowDays]-day window)
/// are detrended with a least-squares line and the **residual RMS** is taken
/// as the oscillation measure: a steady linear drift is a *trend* (covered by
/// `trend.dart`'s forecasts), not an oscillation — without detrending, a tank
/// that simply consumes alkalinity between doses would read "unstable" for
/// consuming. The RMS is then normalized by the parameter's **green-band
/// half-width**, so "how much swing is too much" is defined by the user's own
/// target range and is automatically unit- and scale-free (pH swings of 0.2
/// and calcium swings of 20 ppm compare fairly).
library;

import 'dart:math' as math;

import 'dose_calculator.dart' show DosePoint, linearFit;
import 'health_score.dart' show importanceWeightFor;
import 'zones.dart';

/// Readings older than the window take no part in the stability measure: the
/// score describes how steady the tank is *now*, not last season. The default
/// matches the health score's freshness horizon so, out of the box, the two
/// numbers describe the same period.
const int kStabilityWindowDays = 30;

/// The window lengths the setting offers (`stability_window`, default
/// [kStabilityWindowDays]): 30 d for frequent testers, 60/90 d so relaxed
/// testing cadences (monthly fish-only tanks) can still accumulate the
/// [kStabilityMinReadings] needed for a score.
const List<int> kStabilityWindowChoices = [30, 60, 90];

/// Minimum readings inside the window before a parameter's oscillation is
/// measurable — two points always fit a line perfectly (zero residual), so at
/// least three are needed for any variability signal at all.
const int kStabilityMinReadings = 3;

/// Minimum time span (first→last reading in the window) before the residuals
/// mean anything: three tests in one evening measure test-kit repeatability,
/// not tank stability.
const int kStabilityMinSpanHours = 48;

/// Relative oscillation (residual RMS / green half-width) at or below which a
/// parameter scores a full 100. Swings within a tenth of the half-band are
/// test-kit noise territory — punishing them would make 100 unreachable.
const double _kDeadband = 0.10;

/// Relative oscillation at or above which a parameter scores 0: the swing is
/// as large as the green half-band itself, i.e. the value can cross the whole
/// target range between two tests.
const double _kFullScale = 1.0;

/// Per-parameter input: bounds plus the recent readings (any order; the
/// window/freshness filtering happens inside [computeTankStability]).
typedef StabilityInput = ({
  String paramKey,
  ZoneBounds bounds,
  List<DosePoint> points,
});

/// Coarse, localizable overall stability grade.
enum StabilityGrade { rockSolid, steady, variable, unstable, unknown }

/// One parameter's stability, retained so the UI can explain the score.
class ParameterStability {
  const ParameterStability({
    required this.paramKey,
    required this.subScore,
    required this.sigma,
    required this.sampleCount,
    required this.includedInScore,
  });

  final String paramKey;

  /// 0–100 stability sub-score, or null when not measurable.
  final double? subScore;

  /// Detrended residual RMS in **canonical units** ("the typical swing"), or
  /// null when not measurable. UI shows it as "±σ" in display units.
  final double? sigma;

  /// Readings that fell inside the window (regardless of measurability).
  final int sampleCount;

  /// True when this parameter contributed to the aggregate (enough recent
  /// readings over a long-enough span, and usable bounds to scale by).
  final bool includedInScore;

  /// Value equality (see [TankStability.==]).
  @override
  bool operator ==(Object other) =>
      other is ParameterStability &&
      other.paramKey == paramKey &&
      other.subScore == subScore &&
      other.sigma == sigma &&
      other.sampleCount == sampleCount &&
      other.includedInScore == includedInScore;

  @override
  int get hashCode =>
      Object.hash(paramKey, subScore, sigma, sampleCount, includedInScore);
}

/// The overall stability of a tank: an optional 0–100 [score], the [Zone]
/// band it maps to (drives the ring color, reusing the app-wide zone colors),
/// a coarse [grade], and the per-parameter breakdown.
class TankStability {
  const TankStability({
    required this.score,
    required this.band,
    required this.grade,
    required this.parameters,
  });

  /// 0–100, or null when nothing could be scored.
  final int? score;

  /// Color band for the score: green ≥ 70, amber ≥ 40, red below.
  final Zone band;

  final StabilityGrade grade;

  /// Every input, in the order supplied, for building the breakdown sheet.
  final List<ParameterStability> parameters;

  bool get hasData => score != null;

  /// Scored parameters swinging noticeably (sub-score < 70), worst first —
  /// unlike the health breakdown the sub-scores are directly comparable, so a
  /// true worst-first ordering is possible here.
  List<ParameterStability> get mostVariable =>
      parameters.where((p) => p.includedInScore && p.subScore! < 70).toList()
        ..sort((a, b) => a.subScore!.compareTo(b.subScore!));

  /// Scored parameters holding steady (sub-score ≥ 70), input order.
  List<ParameterStability> get steady =>
      parameters.where((p) => p.includedInScore && p.subScore! >= 70).toList();

  /// Parameters that couldn't be measured: too few recent readings, too short
  /// a span, or no usable bounds to scale the swing by.
  List<ParameterStability> get insufficient =>
      parameters.where((p) => !p.includedInScore).toList();

  /// Value equality, so recomputing an unchanged stability doesn't notify
  /// provider watchers (the [TankHealth] T2 pattern).
  @override
  bool operator ==(Object other) {
    if (other is! TankStability ||
        other.score != score ||
        other.band != band ||
        other.grade != grade ||
        other.parameters.length != parameters.length) {
      return false;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (other.parameters[i] != parameters[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(score, band, grade, Object.hashAll(parameters));
}

/// Computes the overall [TankStability] from per-parameter [inputs].
///
/// Each measurable parameter gets a 0–100 sub-score from its detrended
/// relative oscillation; the aggregate is the importance-weighted mean (same
/// weights as the health score — an alkalinity swing matters more than a
/// nitrate one). One capping rule mirrors the health score's worst-zone
/// ceiling: **any parameter scoring below 40 caps the aggregate at 69**, so a
/// hard-swinging parameter can't hide behind several steady ones. The cap is
/// deliberately one band softer than health's (never forces "unstable"):
/// a single noisy series is often the test kit, not the tank — it drags the
/// tank to "variable" and tops the breakdown, which is warning enough.
TankStability computeTankStability(
  List<StabilityInput> inputs, {
  DateTime? now,
  int windowDays = kStabilityWindowDays,
}) {
  final clock = now ?? DateTime.now();
  final cutoff = clock.subtract(Duration(days: windowDays));
  final params = <ParameterStability>[];

  double weightedSum = 0;
  double weightTotal = 0;
  bool anyUnstable = false;

  for (final input in inputs) {
    final recent = input.points.where((p) => !p.t.isBefore(cutoff)).toList()
      ..sort((a, b) => a.t.compareTo(b.t));

    final sub = _subScore(input.bounds, recent);

    if (sub != null) {
      final w = importanceWeightFor(input.paramKey);
      weightedSum += w * sub.score;
      weightTotal += w;
      if (sub.score < 40) anyUnstable = true;
    }

    params.add(
      ParameterStability(
        paramKey: input.paramKey,
        subScore: sub?.score,
        sigma: sub?.sigma,
        sampleCount: recent.length,
        includedInScore: sub != null,
      ),
    );
  }

  if (weightTotal == 0) {
    return TankStability(
      score: null,
      band: Zone.unknown,
      grade: StabilityGrade.unknown,
      parameters: params,
    );
  }

  var agg = weightedSum / weightTotal;
  if (anyUnstable) agg = agg.clamp(0, 69);
  final score = agg.round();

  final band = score >= 70
      ? Zone.green
      : score >= 40
      ? Zone.amber
      : Zone.red;

  final grade = score >= 85
      ? StabilityGrade.rockSolid
      : score >= 70
      ? StabilityGrade.steady
      : score >= 40
      ? StabilityGrade.variable
      : StabilityGrade.unstable;

  return TankStability(
    score: score,
    band: band,
    grade: grade,
    parameters: params,
  );
}

/// Scale that "a big swing" is measured against: the green half-width when
/// the green band is two-sided, else the width of whichever green→amber gap
/// exists (a one-sided range still says how much slack the user considers
/// "close to the edge"). Null = no usable scale, parameter unmeasurable.
double? _oscillationScale(ZoneBounds b) {
  final gl = b.greenLow, gh = b.greenHigh;
  if (gl != null && gh != null && gh > gl) return (gh - gl) / 2;
  final ah = b.amberHigh;
  if (gh != null && ah != null && ah > gh) return ah - gh;
  final al = b.amberLow;
  if (gl != null && al != null && gl > al) return gl - al;
  return null;
}

/// Detrended relative oscillation of [points] (already window-filtered,
/// oldest first) mapped to a 0–100 sub-score, or null when unmeasurable.
({double score, double sigma})? _subScore(
  ZoneBounds bounds,
  List<DosePoint> points,
) {
  if (points.length < kStabilityMinReadings) return null;
  final span = points.last.t.difference(points.first.t);
  if (span < const Duration(hours: kStabilityMinSpanHours)) return null;
  final scale = _oscillationScale(bounds);
  if (scale == null) return null;

  final fit = linearFit(points);
  if (fit == null) return null; // all readings at one instant (span guard won)

  // Residual RMS around the fitted line, with n-2 degrees of freedom (two
  // spent on the fit) so few-point series aren't flattered.
  final t0 = points.first.t.millisecondsSinceEpoch.toDouble();
  const msPerDay = 86400000.0;
  final lastX =
      (points.last.t.millisecondsSinceEpoch.toDouble() - t0) / msPerDay;
  var ss = 0.0;
  for (final p in points) {
    final x = (p.t.millisecondsSinceEpoch.toDouble() - t0) / msPerDay;
    final fitted = fit.valueAtLast + fit.slopePerDay * (x - lastX);
    final res = p.value - fitted;
    ss += res * res;
  }
  final sigma = points.length > 2
      ? math.sqrt(ss / (points.length - 2))
      : 0.0; // unreachable under kStabilityMinReadings >= 3; defensive.

  final rel = sigma / scale;
  final t = ((rel - _kDeadband) / (_kFullScale - _kDeadband)).clamp(0.0, 1.0);
  return (score: 100 * (1 - t), sigma: sigma);
}
