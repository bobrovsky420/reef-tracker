/// Pure, testable drift / trend detection. Like `dose_calculator.dart` and
/// `ratio.dart` this has no Flutter and no DB dependency — it works on plain
/// numbers so it can be unit-tested in isolation.
///
/// Where the zone bands answer *"where is this value now?"*, the trend answers
/// *"where is it heading, and when will it leave its healthy range?"* It fits a
/// least-squares line through the most recent N readings (`window`) — widened
/// to cover at least [kTrendMinSpanDays] days when they are measured more
/// often than daily — to get a signed change-per-day, then projects that line
/// forward to the parameter's zone boundaries to estimate when the value will
/// enter the amber and red zones. A trend is only produced once at least
/// `window` readings exist.
///
/// A fitted slope is not automatically a *trend*, though: run a line through a
/// parameter that merely oscillates and you get a confident-looking slope whose
/// **sign flips with the window size**, and a forecast built on it warns about
/// a crossing that will never happen (#31). Every fit is therefore significance
/// tested — [TrendResult.slopeSignificant] — and only a slope distinguishable
/// from zero is allowed to produce a forecast. A rejected slope whose scatter is
/// large relative to the parameter's own green band is reported as
/// [TrendResult.oscillating] instead: swinging, not drifting.
library;

import 'dart:math' as math;

import 'dose_calculator.dart' show DosePoint, linearFit;
import 'zones.dart';

export 'dose_calculator.dart' show DosePoint;

/// Default / allowed number of recent readings used to define a trend. The
/// window is also the minimum reading count before any trend is shown.
const int kTrendDefaultWindow = 5;
const int kTrendMinWindow = 3;
const int kTrendMaxWindow = 10;

/// Minimum time span (days) the fitted readings should cover. With several
/// measurements a day, the newest `window` readings can span just a day or
/// two, and test-kit noise over such a short base inflates into large
/// per-day slopes and jumpy forecasts. When the newest `window` readings
/// span less than this, the fit widens to include every reading within the
/// last [kTrendMinSpanDays] days of the newest one. Readings taken daily or
/// less often are unaffected — their window already covers the span.
const int kTrendMinSpanDays = 5;

/// Forecast horizon (days): a projected zone crossing is only surfaced as a
/// dashboard "attention" chip when it falls within this many days. Bounds keep
/// the configurable value sensible.
const int kTrendDefaultHorizon = 14;
const int kTrendMinHorizon = 3;
const int kTrendMaxHorizon = 90;

/// Whether the trend feature is on by default (first run, no setting stored).
const bool kTrendDefaultEnabled = true;

/// Below this absolute slope (canonical units per day) the value is treated as
/// holding steady, so noise doesn't read as a trend with a far-off "forecast".
const double _flatEpsilon = 1e-9;

/// Relative swing (residual RMS / [oscillationScale]) at or above which a
/// non-significant fit is called [TrendResult.oscillating] rather than passed
/// over in silence. Matches the stability score's "variable" threshold — the
/// relative oscillation at which `stability_score.dart` drops a parameter's
/// sub-score below 70 — so the two features agree about which parameters are
/// swinging noticeably. Below it, the scatter is small enough that "no trend"
/// is the whole story and no message is worth showing.
const double kTrendOscillationRelative = 0.37;

/// Two-sided 95% critical values of Student's t by degrees of freedom, indexed
/// `df - 1`. A slope counts as real when `|slope| / SE(slope)` clears the entry
/// for its `n - 2` degrees of freedom (two spent on the fit).
///
/// The df-dependent value matters: a flat `t >= 2` rule passes the very
/// six-point pH fits this test exists to reject, because with df = 4 the
/// threshold is 2.776, not 2. Beyond the table the true critical value keeps
/// falling toward 1.96; the last entry is reused instead, which errs toward
/// suppressing a marginal forecast rather than inventing one.
const List<double> _tCritical95 = [
  12.706, 4.303, 3.182, 2.776, 2.571, //
  2.447, 2.365, 2.306, 2.262, 2.228, //
  2.201, 2.179, 2.160, 2.145, 2.131, //
  2.120, 2.110, 2.101, 2.093, 2.086, //
];

double _tCriticalFor(int df) =>
    _tCritical95[math.min(df, _tCritical95.length) - 1];

/// Direction of a parameter's recent movement.
enum TrendDirection { rising, falling, flat }

/// A recent-trend estimate for one parameter.
class TrendResult {
  const TrendResult({
    required this.slopePerDay,
    required this.direction,
    required this.window,
    this.daysToAmber,
    this.daysToRed,
    this.daysToGreen,
    this.recovering = false,
    this.slopeSignificant = true,
    this.sigma,
    this.relativeSwing,
  });

  /// Signed least-squares slope over the window, in canonical units per day
  /// (negative = falling).
  final double slopePerDay;
  final TrendDirection direction;

  /// Number of readings the fit actually used: the configured window, or more
  /// when the window was widened to cover at least [kTrendMinSpanDays].
  final int window;

  /// Projected days until the value first leaves the green zone (crosses
  /// `greenLow`/`greenHigh` into amber), or null when it isn't heading toward a
  /// green bound (flat, moving away, already past it, no bound on that side,
  /// or [recovering]).
  final double? daysToAmber;

  /// Projected days until the value reaches the red zone (crosses
  /// `amberLow`/`amberHigh`), or null under the same conditions as
  /// [daysToAmber].
  final double? daysToRed;

  /// Projected days until a [recovering] value re-enters its green range
  /// (crosses the *near* green bound), or null when not recovering. The
  /// positive counterpart of [daysToAmber]/[daysToRed] (U15).
  final double? daysToGreen;

  /// True when the value is currently *outside* its green range but moving
  /// back toward it. No crossing forecast is produced then — projecting the
  /// trajectory across the green zone to the far bound would warn about a
  /// parameter that is actively improving (#25). Instead [daysToGreen]
  /// estimates when it will be back in range, surfaced positively (U15).
  final bool recovering;

  /// True when the fitted slope is distinguishable from zero at 95% confidence
  /// (`|slope| / SE(slope)` clears [_tCriticalFor] for `n - 2` df). False means
  /// the readings scatter too much around the line for its direction to be
  /// trusted — no forecast is produced, and [direction], while still the
  /// measured sign, must not be presented as where the value is heading.
  ///
  /// Always true for a two-point fit: with zero degrees of freedom there is
  /// nothing to test, and the pre-existing "any window >= 2 forecasts"
  /// behaviour is kept rather than silently dropped.
  final bool slopeSignificant;

  /// Residual RMS around the fitted line in canonical units ("the typical
  /// swing"), or null for a two-point fit. Same measure as
  /// `stability_score.dart`'s per-parameter sigma, over the trend's window.
  final double? sigma;

  /// [sigma] as a fraction of the parameter's [oscillationScale] — scale- and
  /// unit-free, so pH and calcium compare fairly. Null when [sigma] is null or
  /// the bounds give no scale to measure against.
  final double? relativeSwing;

  /// True when the readings swing noticeably ([kTrendOscillationRelative])
  /// without a slope that survives the significance test: the honest summary is
  /// "bouncing around", not a direction and certainly not a forecast. Drives the
  /// oscillating chip/insight in place of a fabricated crossing estimate (#31).
  bool get oscillating =>
      !slopeSignificant &&
      relativeSwing != null &&
      relativeSwing! >= kTrendOscillationRelative;

  /// True when the value is heading out of its healthy range and we can say
  /// roughly when.
  bool get hasForecast => daysToAmber != null || daysToRed != null;

  /// The soonest projected zone crossing (amber or red), or null when neither
  /// is forecast. Amber always comes before red on the same trajectory.
  double? get soonestCrossing => daysToAmber ?? daysToRed;

  /// Value equality, so recomputing an unchanged trend doesn't read as a new
  /// one — providers/`select`s can skip notifying their watchers (T2).
  @override
  bool operator ==(Object other) =>
      other is TrendResult &&
      other.slopePerDay == slopePerDay &&
      other.direction == direction &&
      other.window == window &&
      other.daysToAmber == daysToAmber &&
      other.daysToRed == daysToRed &&
      other.daysToGreen == daysToGreen &&
      other.recovering == recovering &&
      other.slopeSignificant == slopeSignificant &&
      other.sigma == sigma &&
      other.relativeSwing == relativeSwing;

  @override
  int get hashCode => Object.hash(
    slopePerDay,
    direction,
    window,
    daysToAmber,
    daysToRed,
    daysToGreen,
    recovering,
    slopeSignificant,
    sigma,
    relativeSwing,
  );
}

/// Computes the recent trend for [points] (oldest-first) using at least the
/// most recent [window] readings — widened to every reading within the last
/// [minSpanDays] days when the window alone spans less than that (frequent
/// measurers, see [kTrendMinSpanDays]) — projecting toward [bounds].
///
/// Returns null when [window] < 2, fewer than [window] readings exist, or the
/// readings share a single instant (no computable slope).
TrendResult? computeTrend({
  required List<DosePoint> points,
  required ZoneBounds bounds,
  required int window,
  int minSpanDays = kTrendMinSpanDays,
}) {
  if (window < 2 || points.length < window) return null;
  var start = points.length - window;
  // Hybrid window: when the newest [window] readings span less than
  // [minSpanDays], take every reading inside that span instead (strictly
  // newer than the cutoff, so once-a-day readings keep exactly the window).
  final cutoff = points.last.t.subtract(Duration(days: minSpanDays));
  if (points[start].t.isAfter(cutoff)) {
    while (start > 0 && points[start - 1].t.isAfter(cutoff)) {
      start--;
    }
  }
  final recent = points.sublist(start);
  final fit = linearFit(recent);
  if (fit == null) return null;
  final slope = fit.slopePerDay;

  // Is this slope distinguishable from zero, or is it a line drawn through
  // noise? Residual RMS (n - 2 df, matching stability_score.dart) gives the
  // standard error of the slope, SE = sigma / sqrt(Sxx).
  final n = recent.length;
  final t0 = recent.first.t.millisecondsSinceEpoch.toDouble();
  const msPerDay = 86400000.0;
  final xs = [
    for (final p in recent)
      (p.t.millisecondsSinceEpoch.toDouble() - t0) / msPerDay,
  ];
  final meanX = xs.reduce((a, b) => a + b) / n;
  var sxx = 0.0;
  var ssResidual = 0.0;
  for (var i = 0; i < n; i++) {
    sxx += (xs[i] - meanX) * (xs[i] - meanX);
    final fitted = fit.valueAtLast + slope * (xs[i] - xs.last);
    final residual = recent[i].value - fitted;
    ssResidual += residual * residual;
  }
  // n == 2 fits the two points exactly: no residual, no degrees of freedom,
  // nothing to test — keep the historical "always forecasts" behaviour.
  final double? sigma = n > 2 ? math.sqrt(ssResidual / (n - 2)) : null;
  final bool slopeSignificant;
  if (sigma == null) {
    slopeSignificant = true;
  } else {
    final se = sigma / math.sqrt(sxx);
    slopeSignificant =
        se == 0 || slope.abs() / se >= _tCriticalFor(n - 2);
  }

  final scale = oscillationScale(bounds);
  final double? relativeSwing = (sigma != null && scale != null)
      ? sigma / scale
      : null;

  final TrendDirection direction;
  if (slope > _flatEpsilon) {
    direction = TrendDirection.rising;
  } else if (slope < -_flatEpsilon) {
    direction = TrendDirection.falling;
  } else {
    direction = TrendDirection.flat;
  }

  // Anchor the projection on the fitted value at the last timestamp, not the
  // raw last reading, so one noisy endpoint can't swing the forecast (#26).
  final current = fit.valueAtLast;

  // Bounds violating the ordering invariant classify as unknown — don't
  // project toward them either.
  final b = bounds.isValid ? bounds : const ZoneBounds();

  // A value already outside its green range but heading back toward it is
  // recovering, not at risk: the only bounds ahead of it are on the *far* side
  // of green, and forecasting those would flag an improving parameter (#25).
  final belowGreen =
      (b.greenLow != null && current < b.greenLow!) ||
      (b.amberLow != null && current < b.amberLow!);
  final aboveGreen =
      (b.greenHigh != null && current > b.greenHigh!) ||
      (b.amberHigh != null && current > b.amberHigh!);
  // A slope that failed the significance test says nothing about where the
  // value is going, so it can neither promise a recovery nor threaten a
  // crossing — every projection below collapses to null (#31).
  final recovering =
      slopeSignificant &&
      ((belowGreen && direction == TrendDirection.rising) ||
          (aboveGreen && direction == TrendDirection.falling));

  // Days until the line from `current` at `slope` reaches `bound`, but only
  // when that bound lies ahead in the direction of travel (a bound behind us
  // yields null rather than a negative or backwards estimate). A crossing
  // within numerical noise of "now" reports 0 — the fitted anchor is a
  // computed value, so an exact on-the-bound hit can land a few ulps off.
  double? daysTo(double? bound) {
    if (bound == null ||
        direction == TrendDirection.flat ||
        !slopeSignificant) {
      return null;
    }
    final days = (bound - current) / slope;
    if (days.abs() < 1e-9) return 0;
    return days < 0 ? null : days;
  }

  double? toAmber;
  double? toRed;
  double? toGreen;
  if (recovering) {
    // The near green bound the value is heading back across (U15). With
    // amber-only bounds (#30) green starts at the amber bound itself.
    toGreen = direction == TrendDirection.rising
        ? daysTo(b.greenLow ?? b.amberLow)
        : daysTo(b.greenHigh ?? b.amberHigh);
  } else {
    switch (direction) {
      case TrendDirection.rising:
        toAmber = daysTo(b.greenHigh);
        toRed = daysTo(b.amberHigh);
      case TrendDirection.falling:
        toAmber = daysTo(b.greenLow);
        toRed = daysTo(b.amberLow);
      case TrendDirection.flat:
        break;
    }
  }

  return TrendResult(
    slopePerDay: slope,
    direction: direction,
    window: recent.length,
    daysToAmber: toAmber,
    daysToRed: toRed,
    daysToGreen: toGreen,
    recovering: recovering,
    slopeSignificant: slopeSignificant,
    sigma: sigma,
    relativeSwing: relativeSwing,
  );
}
