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

import '../data/database.dart';
import 'supplement_catalog.dart';

/// A timestamped measurement used to derive the consumption trend.
typedef DosePoint = ({DateTime t, double value});

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

/// Least-squares slope of [points] in value-per-day, or null when there are
/// fewer than two points or they share a single instant (zero time span).
double? slopePerDay(List<DosePoint> points) {
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
  return sxy / sxx;
}

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

/// Average daily amount (in the entry's own unit) implied by a dosing plan
/// [entry]: its `amount` scaled by how often it is actually dosed.
///
/// `perDay` basis = the amount is a daily total on each dosing day; `perDose`
/// basis = the amount is one discrete dose. The schedule sets dosing days per
/// week (daily → 7, every-N-days → 7/N, weekly → number of selected weekdays;
/// no schedule → treated as daily). Returns 0 when no amount is recorded.
double dailyEquivalentDose(DosingEntry entry) {
  final amount = entry.amount;
  if (amount == null) return 0;
  final freq = DoseFrequency.fromName(entry.frequency);
  double dosingDaysPerWeek;
  switch (freq) {
    case DoseFrequency.everyNDays:
      final n = entry.intervalDays ?? 1;
      dosingDaysPerWeek = n > 0 ? 7 / n : 7;
    case DoseFrequency.weekly:
      final count = _weekdayCount(entry.weekdays);
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
/// [stableThreshold] is the absolute dose difference (in ml/g) within which the
/// current dose is considered "good enough" and reported as [DoseCalcStatus.stable].
DoseCalcResult computeDoseCalc({
  required double? slopePerDay,
  required double currentDailyDose,
  required double? potency,
  required double? volumeLiters,
  double stableThreshold = 0.5,
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
    status = DoseCalcStatus.overdosing;
  } else if (adjustment.abs() <= stableThreshold) {
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
