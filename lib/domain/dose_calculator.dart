/// Pure, testable math for the supplement consumption / dose-adjustment
/// calculator. Like `ratio.dart` this has no Flutter and no DB dependency — it
/// works on plain numbers so it can be unit-tested in isolation.
///
/// Water changes are intentionally ignored in this phase: the model assumes the
/// only thing adding the element back is dosing.
///
/// ## Model (all in the element's canonical unit, e.g. ppm for Ca, dKH for Alk)
///
/// Over the chosen window the measured concentration changes at
/// `observedChangePerDay` (the least-squares slope; negative = falling). Dosing
/// `currentDailyDose` units/day of a supplement with potency `p` into a tank of
/// `volumeLiters` raises the concentration by `dosingInputPerDay = p *
/// currentDailyDose / volumeLiters`. One-off manual doses given during the
/// window (total spread over its span, `manualDailyDose` units/day) add
/// `manualInputPerDay` the same way. Therefore:
///
///   consumptionPerDay =
///       dosingInputPerDay + manualInputPerDay - observedChangePerDay
///
/// and the scheduled dose that holds the element steady (net change 0,
/// assuming no further manual doses) is
///
///   suggestedDailyDose = consumptionPerDay * volumeLiters / p   (clamped >= 0)
library;

import 'dart:math';

import 'supplement_catalog.dart';
import 'units.dart';

/// A timestamped measurement used to derive the consumption trend.
typedef DosePoint = ({DateTime t, double value});

/// The schedule half of a dosing plan entry — the only fields
/// [dailyEquivalentDose] reads. A plain record so the domain stays decoupled
/// from the DB's `DosingEntry` row (callers map via `DosingEntry.schedule`).
typedef DoseSchedule = ({
  double? amount,
  String? frequency,
  int? intervalDays,
  String? weekdays,
});

/// Outcome category for a calculation, driving the guidance message in the UI.
enum DoseCalcStatus {
  /// Not enough readings (need >= 2 spanning a non-zero time span).
  insufficientData,

  /// Consumption is known but a supplement potency is required to recommend a
  /// dose (happens only when nothing is currently dosed).
  needsPotency,

  /// Current dose already roughly matches consumption — keep it.
  stable,

  /// The element is being consumed faster than dosed — dose more.
  increase,

  /// The element is being consumed slower than dosed — dose less.
  decrease,

  /// The element is rising (consumption <= 0) — reduce or stop dosing.
  overdosing,

  /// Nothing is dosed and the element is not falling — no dose is needed.
  /// (Distinct from [overdosing]: there is nothing to reduce or pause.)
  noDoseNeeded,
}

/// The full result of a dose calculation. Nullable fields are absent when they
/// cannot be computed (e.g. no potency, or insufficient data).
class DoseCalcResult {
  const DoseCalcResult({
    required this.status,
    this.observedChangePerDay,
    this.dosingInputPerDay,
    this.manualInputPerDay,
    this.consumptionPerDay,
    this.suggestedDailyDose,
    this.adjustment,
  });

  final DoseCalcStatus status;

  /// Measured slope of the readings, in element-unit per day (signed).
  final double? observedChangePerDay;

  /// Element-unit per day currently contributed by the dosing.
  final double? dosingInputPerDay;

  /// Element-unit per day contributed by one-off manual doses in the window.
  final double? manualInputPerDay;

  /// Real daily consumption of the element, in element-unit per day.
  final double? consumptionPerDay;

  /// Daily dose (ml/g) that would hold the element steady, clamped >= 0.
  final double? suggestedDailyDose;

  /// `suggestedDailyDose - currentDailyDose` (signed), when both are known.
  final double? adjustment;
}

/// A least-squares line fit through a series: its slope in value-per-day and
/// the fitted (regression) value at the last point's timestamp — a noise-free
/// anchor for projections, unlike the raw last reading.
typedef LinearFit = ({double slopePerDay, double valueAtLast});

/// Least-squares fit of [points] (see [LinearFit]), or null when there are
/// fewer than two points or they share a single instant (zero time span).
LinearFit? linearFit(List<DosePoint> points) {
  if (points.length < 2) return null;
  final t0 = points.first.t.millisecondsSinceEpoch.toDouble();
  const msPerDay = 86400000.0;
  // Days relative to the first point keep the numbers small and stable.
  final xs = [
    for (final p in points)
      (p.t.millisecondsSinceEpoch.toDouble() - t0) / msPerDay,
  ];
  final ys = [for (final p in points) p.value];
  final n = points.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  var sxx = 0.0;
  var sxy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    sxx += dx * dx;
    sxy += dx * (ys[i] - meanY);
  }
  if (sxx == 0) return null; // all readings at the same instant
  final slope = sxy / sxx;
  return (slopePerDay: slope, valueAtLast: meanY + slope * (xs.last - meanX));
}

/// Least-squares slope of [points] in value-per-day, or null when there are
/// fewer than two points or they share a single instant (zero time span).
double? slopePerDay(List<DosePoint> points) => linearFit(points)?.slopePerDay;

/// The subset of [doses] given inside the slope-fit window: from [from]
/// (inclusive — a dose at the first reading's instant influences every later
/// reading) up to but excluding [to] (a dose at or after the last reading has
/// not shown up in any measurement yet). [time] extracts each dose's
/// timestamp, so callers pass their own row type (the DB's `ManualDose`)
/// without coupling the domain to it. Element/unit filtering is the caller's.
List<T> manualDosesInWindow<T>(
  Iterable<T> doses, {
  required DateTime Function(T) time,
  required DateTime from,
  required DateTime to,
}) => [
  for (final d in doses)
    if (!time(d).isBefore(from) && time(d).isBefore(to)) d,
];

/// Potency `p` (element rise per 1 unit of product per 1 litre) from a vendor
/// reference dose: [doseAmount] units in [refVolumeLiters] litres raises the
/// element by [rise]. Returns null for non-positive inputs.
double? potencyFromReference({
  required double doseAmount,
  required double refVolumeLiters,
  required double rise,
}) {
  if (doseAmount <= 0 || refVolumeLiters <= 0 || rise <= 0) return null;
  return rise * refVolumeLiters / doseAmount;
}

/// Average daily amount (in the entry's own unit) implied by a dosing plan's
/// [schedule]: its `amount` scaled by how often it is actually dosed.
///
/// The entry's stored basis (`perDay` = daily total on each dosing day,
/// `perDose` = one discrete dose) is deliberately not part of [DoseSchedule]:
/// for both, the per-active-day amount is `amount`, so it cannot change the
/// result. The schedule sets dosing days per week (daily → 7, every-N-days →
/// 7/N, weekly → number of selected weekdays; no schedule → treated as daily).
/// Returns 0 when no amount is recorded, or when a stored every-N-days
/// interval is invalid (≤ 0): a garbage interval means the true cadence is
/// unknown, and pretending "daily" would skew the dose calculator upward (#8).
double dailyEquivalentDose(DoseSchedule schedule) {
  final amount = schedule.amount;
  if (amount == null) return 0;
  final freq = DoseFrequency.fromName(schedule.frequency);
  double dosingDaysPerWeek;
  switch (freq) {
    case DoseFrequency.everyNDays:
      final n = schedule.intervalDays ?? 1;
      if (n <= 0) return 0;
      dosingDaysPerWeek = 7 / n;
    case DoseFrequency.weekly:
      final count = _weekdayCount(schedule.weekdays);
      dosingDaysPerWeek = count > 0 ? count.toDouble() : 7;
    case DoseFrequency.daily:
    case null:
      dosingDaysPerWeek = 7;
  }
  // For both bases the per-active-day amount is `amount`; averaging over the
  // week gives the mean daily input the consumption math needs.
  return amount * dosingDaysPerWeek / 7;
}

int _weekdayCount(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  return raw
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .where((d) => d != null && d >= 1 && d <= 7)
      .length;
}

/// Computes consumption and the maintenance-dose recommendation.
///
/// [slopePerDay] is the measured change/day (null = not enough data),
/// [currentDailyDose] the average daily dose in ml/g (0 = not dosing),
/// [manualDailyDose] the average ml/g per day contributed by one-off manual
/// doses in the window (the total spread over the window's span; 0 = none —
/// it shares the supplement's [potency]), [potency] the element rise per unit
/// per litre (null = unknown), and [volumeLiters] the tank volume.
///
/// The current dose is reported as [DoseCalcStatus.stable] when the suggested
/// adjustment is within `max(stableFraction * currentDailyDose,
/// stableThreshold)`: the tolerance scales with the dose (±5% by default) so
/// "stable" means the same *relative* chemical mismatch regardless of product
/// potency, with [stableThreshold] (ml/g) as an absolute floor below typical
/// dosing precision.
DoseCalcResult computeDoseCalc({
  required double? slopePerDay,
  required double currentDailyDose,
  double manualDailyDose = 0,
  required double? potency,
  required double? volumeLiters,
  double stableThreshold = 0.1,
  double stableFraction = 0.05,
}) {
  if (slopePerDay == null || volumeLiters == null || volumeLiters <= 0) {
    return const DoseCalcResult(status: DoseCalcStatus.insufficientData);
  }

  final hasPotency = potency != null && potency > 0;

  // Rise/day the current dose and the window's manual doses contribute (0 when
  // not dosing, even if potency is unknown).
  final dosingInputPerDay = (currentDailyDose > 0 && hasPotency)
      ? potency * currentDailyDose / volumeLiters
      : 0.0;
  final manualInputPerDay = (manualDailyDose > 0 && hasPotency)
      ? potency * manualDailyDose / volumeLiters
      : 0.0;

  // If something is dosed (scheduled or manually) but we don't know its
  // potency, we can't separate input from consumption — fall back to needing
  // potency.
  if ((currentDailyDose > 0 || manualDailyDose > 0) && !hasPotency) {
    return DoseCalcResult(
      status: DoseCalcStatus.needsPotency,
      observedChangePerDay: slopePerDay,
    );
  }

  // Sign convention: a falling element (slope < 0) means the tank consumes
  // more than the dose adds, so consumption = input − slope grows; a rising
  // element makes it shrink (and go negative when input exceeds consumption).
  final consumptionPerDay = dosingInputPerDay + manualInputPerDay - slopePerDay;

  // Without a potency we can still report consumption (no dosing case) but
  // cannot turn it into a dose.
  if (!hasPotency) {
    return DoseCalcResult(
      status: DoseCalcStatus.needsPotency,
      observedChangePerDay: slopePerDay,
      dosingInputPerDay: dosingInputPerDay,
      consumptionPerDay: consumptionPerDay,
    );
  }

  final suggestedRaw = consumptionPerDay * volumeLiters / potency;
  final suggested = suggestedRaw < 0 ? 0.0 : suggestedRaw;
  final adjustment = suggested - currentDailyDose;

  final DoseCalcStatus status;
  if (consumptionPerDay <= 0) {
    // Nothing is being consumed. With an active dose (scheduled or manual)
    // that's overdosing; with no dose there is nothing to "reduce or pause" —
    // the element holds (or rises) on its own.
    status = currentDailyDose > 0 || manualDailyDose > 0
        ? DoseCalcStatus.overdosing
        : DoseCalcStatus.noDoseNeeded;
  } else if (currentDailyDose <= 0) {
    // Consumption but nothing dosed: always recommend starting — "keep your
    // current dose" would be advice to keep dosing nothing.
    status = DoseCalcStatus.increase;
  } else if (adjustment.abs() <=
      max(stableFraction * currentDailyDose, stableThreshold)) {
    status = DoseCalcStatus.stable;
  } else if (adjustment > 0) {
    status = DoseCalcStatus.increase;
  } else {
    status = DoseCalcStatus.decrease;
  }

  return DoseCalcResult(
    status: status,
    observedChangePerDay: slopePerDay,
    dosingInputPerDay: dosingInputPerDay,
    manualInputPerDay: manualInputPerDay,
    consumptionPerDay: consumptionPerDay,
    suggestedDailyDose: suggested,
    adjustment: adjustment,
  );
}

// --- Correction (one-off) dose -----------------------------------------------

/// Outcome category for a correction-dose calculation.
enum CorrectionStatus {
  /// Current value, target or tank volume is missing/invalid.
  missingInputs,

  /// The rise is known but a supplement potency is required for a dose.
  needsPotency,

  /// The current value already meets or exceeds the target — nothing to dose.
  atOrAboveTarget,

  /// The whole correction is safe to give as one dose.
  singleDose,

  /// The rise exceeds the element's safe daily limit — spread over [CorrectionResult.days].
  splitDose,
}

/// The result of a correction-dose calculation. Nullable fields are absent
/// when they cannot be computed for the status.
class CorrectionResult {
  const CorrectionResult({
    required this.status,
    this.rise,
    this.totalDose,
    this.days,
    this.dailyDose,
  });

  final CorrectionStatus status;

  /// `target - current`, in the element's canonical unit (> 0 when dosing).
  final double? rise;

  /// Total product amount (in the dose unit the potency is expressed in).
  final double? totalDose;

  /// Days to spread the correction over (1 for [CorrectionStatus.singleDose]).
  final int? days;

  /// Product amount per day when split ([totalDose] / [days]).
  final double? dailyDose;
}

/// Computes the one-off dose that raises an element from [current] to
/// [target] in [volumeLiters] litres using a supplement of [potency] (element
/// rise per 1 unit of product per 1 litre — same definition as
/// [computeDoseCalc]).
///
/// When [maxDailyRise] (element units per day, from `kMaxDailyRiseByElement`)
/// is given and the needed rise exceeds it, the correction is split over
/// `ceil(rise / maxDailyRise)` days with an even daily dose. All values are in
/// the element's canonical unit.
CorrectionResult computeCorrectionDose({
  required double? current,
  required double? target,
  required double? potency,
  required double? volumeLiters,
  double? maxDailyRise,
}) {
  if (current == null ||
      target == null ||
      volumeLiters == null ||
      volumeLiters <= 0) {
    return const CorrectionResult(status: CorrectionStatus.missingInputs);
  }
  final rise = target - current;
  if (rise <= 0) {
    return CorrectionResult(
      status: CorrectionStatus.atOrAboveTarget,
      rise: rise,
    );
  }
  if (potency == null || potency <= 0) {
    return CorrectionResult(status: CorrectionStatus.needsPotency, rise: rise);
  }
  final totalDose = rise * volumeLiters / potency;
  // The relative epsilon absorbs float noise (8.5 - 7.1 > 1.4 in doubles), so
  // a rise at exactly the limit is a single dose and `days` never rounds a
  // hair over an integer up to the next day.
  if (maxDailyRise != null &&
      maxDailyRise > 0 &&
      rise > maxDailyRise * (1 + 1e-9)) {
    final days = (rise / maxDailyRise - 1e-9).ceil();
    return CorrectionResult(
      status: CorrectionStatus.splitDose,
      rise: rise,
      totalDose: totalDose,
      days: days,
      dailyDose: totalDose / days,
    );
  }
  return CorrectionResult(
    status: CorrectionStatus.singleDose,
    rise: rise,
    totalDose: totalDose,
    days: 1,
    dailyDose: totalDose,
  );
}

// --- Salinity-adjusted correction target -------------------------------------

/// The reference salinity that catalog presets and hobby "book" targets are
/// stated at: natural seawater, 35 ppt.
const double kReferenceSalinityPpt = 35.0;

/// Plausible band a measured tank salinity is clamped into before scaling a
/// target ([adjustTargetForSalinity]) — a typo'd or corrupt salinity reading
/// must not silently produce an absurd correction dose.
const double kSalinityAdjustMinPpt = 20.0;
const double kSalinityAdjustMaxPpt = 45.0;

/// How far back salinity readings are averaged by [resolveTankSalinity];
/// beyond it a lone latest reading counts as stale (the UI says so).
const Duration kSalinityAdjustWindow = Duration(days: 14);

/// The tank salinity a correction target is scaled by: the value in ppt, when
/// the newest contributing reading was taken (staleness display), and whether
/// it averages several readings inside [kSalinityAdjustWindow] or is a single
/// reading.
class TankSalinity {
  const TankSalinity({
    required this.ppt,
    required this.measuredAt,
    required this.isAverage,
  });

  final double ppt;
  final DateTime measuredAt;
  final bool isAverage;
}

/// Resolves the salinity to scale correction targets by from the tank's
/// stored salinity [readings] (canonical SG, oldest first): the average of
/// the readings inside [kSalinityAdjustWindow] before [now], else the latest
/// reading ever (possibly stale — [TankSalinity.measuredAt] tells), or null
/// when the tank has no salinity readings at all.
TankSalinity? resolveTankSalinity(
  List<DosePoint> readings, {
  required DateTime now,
}) {
  if (readings.isEmpty) return null;
  final cutoff = now.subtract(kSalinityAdjustWindow);
  final recent = [
    for (final r in readings)
      if (!r.t.isBefore(cutoff)) r,
  ];
  if (recent.isEmpty) {
    final last = readings.last;
    return TankSalinity(
      ppt: sgToPpt(last.value),
      measuredAt: last.t,
      isAverage: false,
    );
  }
  final avg = recent.fold(0.0, (s, r) => s + r.value) / recent.length;
  return TankSalinity(
    ppt: sgToPpt(avg),
    measuredAt: recent.last.t,
    isAverage: recent.length > 1,
  );
}

/// Scales a 35 ppt-referenced [target] to the tank's [salinityPpt]. The ionic
/// content of seawater scales linearly with salinity, so the equivalent
/// target is `target × salinity / 35` — e.g. Ca 420 ppm at 33 ppt becomes
/// 396 ppm. [salinityPpt] is clamped to [kSalinityAdjustMinPpt]..
/// [kSalinityAdjustMaxPpt] first (see there).
double adjustTargetForSalinity(double target, double salinityPpt) =>
    target *
    salinityPpt.clamp(kSalinityAdjustMinPpt, kSalinityAdjustMaxPpt) /
    kReferenceSalinityPpt;
