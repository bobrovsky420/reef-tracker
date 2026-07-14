/// Pure, testable tank-health scoring. Like `trend.dart`, `ratio.dart` and
/// `dose_calculator.dart` this has no Flutter and no DB dependency — it works on
/// plain numbers and [ZoneBounds] so it can be unit-tested in isolation.
///
/// Where the zone bands answer *"where is each value now?"*, the health score
/// collapses every tracked parameter's current standing into a single 0–100
/// number plus a worst-case [Zone] band, so a tank's overall state is glanceable
/// on the dashboard and app bar. The number reflects how well, on balance, the
/// parameters sit inside their ranges; the band always reflects the *worst*
/// parameter, so one red can never be hidden behind several greens.
library;

import 'clock.dart';
import 'zones.dart';

/// Parameters tested longer ago than this are considered stale: their last
/// reading no longer reflects the tank's current state, so they're excluded from
/// the aggregate score and surfaced separately ("not tested recently").
const int kHealthFreshnessDays = 30;

/// Relative importance of each parameter in the aggregate. Parameters whose
/// swings harm livestock fastest weigh most; trace elements weigh least.
/// Anything not listed defaults to [_kDefaultWeight].
const double _kDefaultWeight = 1;
const Map<String, double> _kImportance = {
  'temperature': 3,
  'salinity': 3,
  'alkalinity': 3,
  'ammonia': 3,
  'nitrite': 3,
  'ph': 2.5,
  'calcium': 2,
  'magnesium': 2,
  'nitrate': 2,
  'phosphate': 2,
};

/// Public so the stability score (`stability_score.dart`) weighs parameters
/// identically — one importance table for both aggregates.
double importanceWeightFor(String paramKey) =>
    _kImportance[paramKey] ?? _kDefaultWeight;

/// Per-parameter input for scoring: its bounds and latest reading (if any).
typedef HealthInput = ({
  String paramKey,
  ZoneBounds bounds,
  double? latest,
  DateTime? takenAt,
});

/// Coarse, localizable overall grade derived from the score and band.
enum HealthGrade { excellent, good, caution, critical, unknown }

/// One parameter's contribution to the overall health, retained so the UI can
/// explain the score (group offenders, show healthy ones, flag stale ones).
class ParameterHealth {
  const ParameterHealth({
    required this.paramKey,
    required this.zone,
    required this.value,
    required this.takenAt,
    required this.stale,
    required this.includedInScore,
  });

  final String paramKey;

  /// Zone of the latest reading against the bounds, or [Zone.unknown] when there
  /// is no reading or no usable bounds.
  final Zone zone;

  /// Latest canonical value, or null when the parameter has no reading.
  final double? value;

  /// When the latest reading was taken, or null when there is none.
  final DateTime? takenAt;

  /// True when the latest reading is too old to trust: older than
  /// [kHealthFreshnessDays], or (defensively) carrying a value with no
  /// timestamp at all.
  final bool stale;

  /// True when this parameter actually contributed to the aggregate (has a
  /// fresh reading and usable bounds).
  final bool includedInScore;

  bool get hasReading => value != null;

  /// Value equality (see [TankHealth.==]).
  @override
  bool operator ==(Object other) =>
      other is ParameterHealth &&
      other.paramKey == paramKey &&
      other.zone == zone &&
      other.value == value &&
      other.takenAt == takenAt &&
      other.stale == stale &&
      other.includedInScore == includedInScore;

  @override
  int get hashCode =>
      Object.hash(paramKey, zone, value, takenAt, stale, includedInScore);
}

/// The overall health of a tank: an optional 0–100 [score], the worst-case
/// [band] it maps to, a coarse [grade], and the per-parameter breakdown.
class TankHealth {
  const TankHealth({
    required this.score,
    required this.band,
    required this.grade,
    required this.parameters,
  });

  /// 0–100, or null when nothing could be scored (no fresh, bounded readings).
  final int? score;

  /// Worst-case zone across scored parameters — drives the badge color. Always
  /// matches the most severe zone present, never an "averaged" colour.
  final Zone band;

  final HealthGrade grade;

  /// Every input, in the order supplied, for building the breakdown sheet.
  final List<ParameterHealth> parameters;

  bool get hasData => score != null;

  /// Fresh parameters outside their green range — reds first, then ambers, each
  /// group ordered worst-first by how far out they are isn't available here, so
  /// reds simply precede ambers (input order within a zone).
  List<ParameterHealth> get offenders => [
    ...parameters.where((p) => p.includedInScore && p.zone == Zone.red),
    ...parameters.where((p) => p.includedInScore && p.zone == Zone.amber),
  ];

  /// Fresh parameters sitting inside their green range.
  List<ParameterHealth> get healthy => parameters
      .where((p) => p.includedInScore && p.zone == Zone.green)
      .toList();

  /// Parameters that couldn't be scored: stale readings, no reading yet, or no
  /// usable bounds. Surfaced so the score isn't silently treating them as fine.
  List<ParameterHealth> get notScored =>
      parameters.where((p) => !p.includedInScore).toList();

  /// Value equality, so recomputing an unchanged health doesn't read as a new
  /// one — the health provider can skip notifying its watchers (T2).
  @override
  bool operator ==(Object other) {
    if (other is! TankHealth ||
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

/// Computes the overall [TankHealth] from per-parameter [inputs].
///
/// Each parameter with a fresh reading and usable bounds gets a 0–100 sub-score
/// from its position within (or beyond) its bands; the aggregate is the
/// importance-weighted mean, then capped to the worst zone's ceiling so the
/// band — and therefore the colour and grade — always reflects the most severe
/// parameter present.
TankHealth computeTankHealth(
  List<HealthInput> inputs, {
  DateTime? now,
  int freshnessDays = kHealthFreshnessDays,
}) {
  final clock = now ?? DateTime.now();
  final params = <ParameterHealth>[];

  double weightedSum = 0;
  double weightTotal = 0;
  bool anyRed = false;
  bool anyAmber = false;

  for (final input in inputs) {
    final value = input.latest;
    final zone = value == null ? Zone.unknown : input.bounds.classify(value);
    // A value with no timestamp cannot be verified as fresh — treat it as
    // stale rather than eternally fresh (#29). Without a value there is
    // nothing to be stale.
    final stale =
        value != null &&
        (input.takenAt == null ||
            daysSince(input.takenAt!, now: clock) > freshnessDays);

    final sub = (value != null && zone != Zone.unknown && !stale)
        ? _subScore(input.bounds, value, zone)
        : null;
    final included = sub != null;

    if (included) {
      final w = importanceWeightFor(input.paramKey);
      weightedSum += w * sub;
      weightTotal += w;
      if (zone == Zone.red) {
        anyRed = true;
      } else if (zone == Zone.amber) {
        anyAmber = true;
      }
    }

    params.add(
      ParameterHealth(
        paramKey: input.paramKey,
        zone: zone,
        value: value,
        takenAt: input.takenAt,
        stale: stale,
        includedInScore: included,
      ),
    );
  }

  if (weightTotal == 0) {
    return TankHealth(
      score: null,
      band: Zone.unknown,
      grade: HealthGrade.unknown,
      parameters: params,
    );
  }

  var agg = weightedSum / weightTotal;
  // Worst-zone ceiling: a red caps the score into the red band, an amber into
  // the amber band — so good parameters can never paper over a dangerous one.
  if (anyRed) {
    agg = agg.clamp(0, 39);
  } else if (anyAmber) {
    agg = agg.clamp(0, 69);
  }
  final score = agg.round();

  final band = score >= 70
      ? Zone.green
      : score >= 40
      ? Zone.amber
      : Zone.red;

  final grade = score >= 85
      ? HealthGrade.excellent
      : score >= 70
      ? HealthGrade.good
      : score >= 40
      ? HealthGrade.caution
      : HealthGrade.critical;

  return TankHealth(score: score, band: band, grade: grade, parameters: params);
}

/// Maps a single [value] to a 0–100 sub-score given its [zone] and [bounds].
///
/// Bands: green → [70,100], amber → [40,69], red → [0,39]. Within a band the
/// score interpolates by how favourably the value sits — centred in green
/// scores highest; hugging a bound scores at the band edge; deep in red scores
/// toward zero. When a side's bounds are open (null) a representative flat value
/// is used since distance can't be measured.
double _subScore(ZoneBounds bounds, double value, Zone zone) {
  switch (zone) {
    case Zone.green:
      final lo = bounds.greenLow, hi = bounds.greenHigh;
      if (lo != null && hi != null && hi > lo) {
        final mid = (lo + hi) / 2;
        final half = (hi - lo) / 2;
        final t = (1 - (value - mid).abs() / half).clamp(0.0, 1.0);
        return 70 + 30 * t;
      }
      return 90; // one-sided green: solidly OK, centredness unknown.
    case Zone.amber:
      // Low-side amber: between amberLow and greenLow.
      if (bounds.greenLow != null && value < bounds.greenLow!) {
        final gl = bounds.greenLow!, al = bounds.amberLow;
        if (al != null && gl > al) {
          final f = ((gl - value) / (gl - al)).clamp(0.0, 1.0);
          return 40 + 29 * (1 - f);
        }
        return 55;
      }
      // High-side amber: between greenHigh and amberHigh.
      if (bounds.greenHigh != null && value > bounds.greenHigh!) {
        final gh = bounds.greenHigh!, ah = bounds.amberHigh;
        if (ah != null && ah > gh) {
          final f = ((value - gh) / (ah - gh)).clamp(0.0, 1.0);
          return 40 + 29 * (1 - f);
        }
        return 55;
      }
      return 55;
    case Zone.red:
      // Below amberLow: score by how far past the amber bound, measured in
      // amber-band widths.
      if (bounds.amberLow != null && value < bounds.amberLow!) {
        final al = bounds.amberLow!, gl = bounds.greenLow;
        final width = (gl != null && gl > al) ? gl - al : null;
        if (width != null) {
          final over = ((al - value) / width).clamp(0.0, 1.0);
          return 39 - 39 * over;
        }
        return 20;
      }
      if (bounds.amberHigh != null && value > bounds.amberHigh!) {
        final ah = bounds.amberHigh!, gh = bounds.greenHigh;
        final width = (gh != null && ah > gh) ? ah - gh : null;
        if (width != null) {
          final over = ((value - ah) / width).clamp(0.0, 1.0);
          return 39 - 39 * over;
        }
        return 20;
      }
      return 20;
    case Zone.unknown:
      return 0;
  }
}
