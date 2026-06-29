/// Pure, testable drift / trend detection. Like `dose_calculator.dart` and
/// `ratio.dart` this has no Flutter and no DB dependency — it works on plain
/// numbers so it can be unit-tested in isolation.
///
/// Where the zone bands answer *"where is this value now?"*, the trend answers
/// *"where is it heading, and when will it leave its healthy range?"* It fits a
/// least-squares line through the most recent N readings (`window`) to get a
/// signed change-per-day, then projects that line forward to the parameter's
/// zone boundaries to estimate when the value will enter the amber and red
/// zones. A trend is only produced once at least `window` readings exist.
library;

import 'dose_calculator.dart' show DosePoint, slopePerDay;
import 'zones.dart';

export 'dose_calculator.dart' show DosePoint;

/// Default / allowed number of recent readings used to define a trend. The
/// window is also the minimum reading count before any trend is shown.
const int kTrendDefaultWindow = 5;
const int kTrendMinWindow = 3;
const int kTrendMaxWindow = 10;

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
  });

  /// Signed least-squares slope over the window, in canonical units per day
  /// (negative = falling).
  final double slopePerDay;
  final TrendDirection direction;

  /// Number of readings the fit used.
  final int window;

  /// Projected days until the value first leaves the green zone (crosses
  /// `greenLow`/`greenHigh` into amber), or null when it isn't heading toward a
  /// green bound (flat, moving away, already past it, or no bound on that side).
  final double? daysToAmber;

  /// Projected days until the value reaches the red zone (crosses
  /// `amberLow`/`amberHigh`), or null under the same conditions as
  /// [daysToAmber].
  final double? daysToRed;

  /// True when the value is heading out of its healthy range and we can say
  /// roughly when.
  bool get hasForecast => daysToAmber != null || daysToRed != null;

  /// The soonest projected zone crossing (amber or red), or null when neither
  /// is forecast. Amber always comes before red on the same trajectory.
  double? get soonestCrossing => daysToAmber ?? daysToRed;
}

/// Computes the recent trend for [points] (oldest-first) using up to the most
/// recent [window] readings, projecting toward [bounds].
///
/// Returns null when [window] < 2, fewer than [window] readings exist, or the
/// readings share a single instant (no computable slope).
TrendResult? computeTrend({
  required List<DosePoint> points,
  required ZoneBounds bounds,
  required int window,
}) {
  if (window < 2 || points.length < window) return null;
  final recent = points.sublist(points.length - window);
  final slope = slopePerDay(recent);
  if (slope == null) return null;

  final TrendDirection direction;
  if (slope > _flatEpsilon) {
    direction = TrendDirection.rising;
  } else if (slope < -_flatEpsilon) {
    direction = TrendDirection.falling;
  } else {
    direction = TrendDirection.flat;
  }

  final current = recent.last.value;

  // Days until the line from `current` at `slope` reaches `bound`, but only
  // when that bound lies ahead in the direction of travel (so a value already
  // past a bound, or moving away from it, yields null rather than a negative or
  // backwards estimate).
  double? daysTo(double? bound) {
    if (bound == null || direction == TrendDirection.flat) return null;
    final delta = bound - current;
    if (delta == 0) return 0;
    if ((delta > 0) != (slope > 0)) return null; // bound is behind us
    return delta / slope;
  }

  double? toAmber;
  double? toRed;
  switch (direction) {
    case TrendDirection.rising:
      toAmber = daysTo(bounds.greenHigh);
      toRed = daysTo(bounds.amberHigh);
    case TrendDirection.falling:
      toAmber = daysTo(bounds.greenLow);
      toRed = daysTo(bounds.amberLow);
    case TrendDirection.flat:
      break;
  }

  return TrendResult(
    slopePerDay: slope,
    direction: direction,
    window: window,
    daysToAmber: toAmber,
    daysToRed: toRed,
  );
}
