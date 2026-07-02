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
/// currentDailyDose / volumeLiters`. Therefore:
///
///   consumptionPerDay = dosingInputPerDay - observedChangePerDay
///
/// and the dose that holds the element steady (net change 0) is
///
///   suggestedDailyDose = consumptionPerDay * volumeLiters / p   (clamped >= 0)
library;

import 'dart:math';

import 'supplement_catalog.dart';

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
    this.consumptionPerDay,
    this.suggestedDailyDose,
    this.adjustment,
  });

  final DoseCalcStatus status;

  /// Measured slope of the readings, in element-unit per day (signed).
  final double? observedChangePerDay;

  /// Element-unit per day currently contributed by the dosing.
  final double? dosingInputPerDay;

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
      (p.t.millisecondsSinceEpoch.toDouble() - t0) / msPerDay
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
  return (
    slopePerDay: slope,
    valueAtLast: meanY + slope * (xs.last - meanX),
  );
}

/// Least-squares slope of [points] in value-per-day, or null when there are
/// fewer than two points or they share a single instant (zero time span).
double? slopePerDay(List<DosePoint> points) => linearFit(points)?.slopePerDay;

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
/// [potency] the element rise per unit per litre (null = unknown), and
/// [volumeLiters] the tank volume.
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
  required double? potency,
  required double? volumeLiters,
  double stableThreshold = 0.1,
  double stableFraction = 0.05,
}) {
  if (slopePerDay == null || volumeLiters == null || volumeLiters <= 0) {
    return const DoseCalcResult(status: DoseCalcStatus.insufficientData);
  }

  // Rise/day the current dose contributes (0 when not dosing, even if potency
  // is unknown).
  final dosingInputPerDay =
      (currentDailyDose > 0 && potency != null && potency > 0)
          ? potency * currentDailyDose / volumeLiters
          : 0.0;

  // If something is dosed but we don't know its potency, we can't separate
  // input from consumption — fall back to needing potency.
  if (currentDailyDose > 0 && (potency == null || potency <= 0)) {
    return DoseCalcResult(
      status: DoseCalcStatus.needsPotency,
      observedChangePerDay: slopePerDay,
    );
  }

  // Sign convention: a falling element (slope < 0) means the tank consumes
  // more than the dose adds, so consumption = input − slope grows; a rising
  // element makes it shrink (and go negative when input exceeds consumption).
  final consumptionPerDay = dosingInputPerDay - slopePerDay;

  // Without a potency we can still report consumption (no dosing case) but
  // cannot turn it into a dose.
  if (potency == null || potency <= 0) {
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
    // Nothing is being consumed. With an active dose that's overdosing; with
    // no dose there is nothing to "reduce or pause" — the element holds (or
    // rises) on its own.
    status = currentDailyDose > 0
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
    consumptionPerDay: consumptionPerDay,
    suggestedDailyDose: suggested,
    adjustment: adjustment,
  );
}
