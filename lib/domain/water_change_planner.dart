import 'dart:math' as math;

/// How replacement water enters and leaves the aquarium.
enum WaterChangeMethod {
  /// A volume is removed, then the same volume is replaced. The aquarium is
  /// assumed to mix completely before the next change.
  batch,

  /// Old and new water move simultaneously through a completely mixed system.
  continuous,
}

/// One row in a repeated water-change projection.
class WaterChangeStep {
  const WaterChangeStep({
    required this.number,
    required this.concentration,
    required this.effectiveChangeFraction,
  });

  final int number;
  final double concentration;
  final double effectiveChangeFraction;
}

/// Pure, unit-agnostic result of a water-change projection.
///
/// Concentrations must all use the same *linear* unit. The presentation layer
/// converts salinity from stored/display SG to ppt before calling this code.
class WaterChangeProjection {
  const WaterChangeProjection({
    required this.method,
    required this.tankVolumeLiters,
    required this.changeVolumeLiters,
    required this.initialConcentration,
    required this.replacementConcentration,
    required this.plannedChanges,
    required this.steps,
    required this.changesToTarget,
  });

  final WaterChangeMethod method;
  final double tankVolumeLiters;
  final double changeVolumeLiters;
  final double initialConcentration;
  final double replacementConcentration;
  final int plannedChanges;
  final List<WaterChangeStep> steps;

  /// Minimum whole changes that move the result to or past the target.
  /// Null means the replacement concentration does not strictly bracket the
  /// target, so no finite schedule can reach it under this model.
  final int? changesToTarget;

  WaterChangeStep get afterOne => steps.first;
  WaterChangeStep get afterPlanned => steps.last;
}

/// Projects one or more equal-volume water changes.
///
/// The calculation assumes constant system-water volume, complete mixing, and
/// no production, consumption, dosing, precipitation, adsorption, or other
/// source/sink between changes. It is an estimate, not an endpoint guarantee.
WaterChangeProjection projectWaterChanges({
  required WaterChangeMethod method,
  required double tankVolumeLiters,
  required double changeVolumeLiters,
  required double initialConcentration,
  required double replacementConcentration,
  required int plannedChanges,
  double? targetConcentration,
}) {
  _requirePositive(tankVolumeLiters, 'tankVolumeLiters');
  _requirePositive(changeVolumeLiters, 'changeVolumeLiters');
  _requireNonNegative(initialConcentration, 'initialConcentration');
  _requireNonNegative(replacementConcentration, 'replacementConcentration');
  if (changeVolumeLiters > tankVolumeLiters) {
    throw ArgumentError.value(
      changeVolumeLiters,
      'changeVolumeLiters',
      'must not exceed tankVolumeLiters',
    );
  }
  if (plannedChanges < 1 || plannedChanges > 10000) {
    throw ArgumentError.value(
      plannedChanges,
      'plannedChanges',
      'must be between 1 and 10000',
    );
  }
  if (targetConcentration != null) {
    _requireNonNegative(targetConcentration, 'targetConcentration');
  }

  final steps = <WaterChangeStep>[
    for (var n = 1; n <= plannedChanges; n++)
      WaterChangeStep(
        number: n,
        concentration: projectedWaterChangeConcentration(
          method: method,
          tankVolumeLiters: tankVolumeLiters,
          changeVolumeLiters: changeVolumeLiters,
          initialConcentration: initialConcentration,
          replacementConcentration: replacementConcentration,
          changes: n,
        ),
        effectiveChangeFraction: effectiveWaterChangeFraction(
          method: method,
          tankVolumeLiters: tankVolumeLiters,
          changeVolumeLiters: changeVolumeLiters,
          changes: n,
        ),
      ),
  ];

  return WaterChangeProjection(
    method: method,
    tankVolumeLiters: tankVolumeLiters,
    changeVolumeLiters: changeVolumeLiters,
    initialConcentration: initialConcentration,
    replacementConcentration: replacementConcentration,
    plannedChanges: plannedChanges,
    steps: List.unmodifiable(steps),
    changesToTarget: targetConcentration == null
        ? null
        : waterChangesToReachTarget(
            method: method,
            tankVolumeLiters: tankVolumeLiters,
            changeVolumeLiters: changeVolumeLiters,
            initialConcentration: initialConcentration,
            replacementConcentration: replacementConcentration,
            targetConcentration: targetConcentration,
          ),
  );
}

double projectedWaterChangeConcentration({
  required WaterChangeMethod method,
  required double tankVolumeLiters,
  required double changeVolumeLiters,
  required double initialConcentration,
  required double replacementConcentration,
  required int changes,
}) {
  _validateCoreInputs(
    tankVolumeLiters,
    changeVolumeLiters,
    initialConcentration,
    replacementConcentration,
    changes,
  );
  final retained = _retainedFraction(
    method,
    changeVolumeLiters / tankVolumeLiters,
    changes,
  );
  return replacementConcentration +
      (initialConcentration - replacementConcentration) * retained;
}

double effectiveWaterChangeFraction({
  required WaterChangeMethod method,
  required double tankVolumeLiters,
  required double changeVolumeLiters,
  required int changes,
}) {
  _requirePositive(tankVolumeLiters, 'tankVolumeLiters');
  _requirePositive(changeVolumeLiters, 'changeVolumeLiters');
  if (changeVolumeLiters > tankVolumeLiters) {
    throw ArgumentError.value(changeVolumeLiters, 'changeVolumeLiters');
  }
  if (changes < 0) {
    throw ArgumentError.value(changes, 'changes');
  }
  return 1 -
      _retainedFraction(method, changeVolumeLiters / tankVolumeLiters, changes);
}

/// Minimum whole equal changes that move the concentration to or past target.
///
/// Returns 0 when already at target and null when the replacement water does
/// not sit strictly beyond the target in the desired direction. A replacement
/// equal to the target approaches it asymptotically and therefore also returns
/// null rather than promising a finite schedule.
int? waterChangesToReachTarget({
  required WaterChangeMethod method,
  required double tankVolumeLiters,
  required double changeVolumeLiters,
  required double initialConcentration,
  required double replacementConcentration,
  required double targetConcentration,
}) {
  _validateCoreInputs(
    tankVolumeLiters,
    changeVolumeLiters,
    initialConcentration,
    replacementConcentration,
    1,
  );
  _requireNonNegative(targetConcentration, 'targetConcentration');
  if (initialConcentration == targetConcentration) return 0;

  final lowering = targetConcentration < initialConcentration;
  final brackets = lowering
      ? replacementConcentration < targetConcentration
      : replacementConcentration > targetConcentration;
  if (!brackets) return null;

  final ratio =
      (targetConcentration - replacementConcentration) /
      (initialConcentration - replacementConcentration);
  if (!ratio.isFinite || ratio <= 0 || ratio >= 1) return null;

  final fraction = changeVolumeLiters / tankVolumeLiters;
  final raw = switch (method) {
    WaterChangeMethod.batch when fraction == 1 => 1.0,
    WaterChangeMethod.batch => math.log(ratio) / math.log(1 - fraction),
    WaterChangeMethod.continuous => -math.log(ratio) / fraction,
  };
  if (!raw.isFinite || raw <= 0) return null;
  // Subtract a tiny relative epsilon so an exact integer result does not grow
  // by one because of floating-point noise (e.g. log(a^3)/log(a)).
  final count = (raw - raw.abs() * 1e-12).ceil();
  return count < 1 ? 1 : count;
}

double _retainedFraction(
  WaterChangeMethod method,
  double fractionPerChange,
  int changes,
) => switch (method) {
  WaterChangeMethod.batch =>
    math.pow(1 - fractionPerChange, changes).toDouble(),
  WaterChangeMethod.continuous => math.exp(-fractionPerChange * changes),
};

void _validateCoreInputs(
  double tankVolumeLiters,
  double changeVolumeLiters,
  double initialConcentration,
  double replacementConcentration,
  int changes,
) {
  _requirePositive(tankVolumeLiters, 'tankVolumeLiters');
  _requirePositive(changeVolumeLiters, 'changeVolumeLiters');
  _requireNonNegative(initialConcentration, 'initialConcentration');
  _requireNonNegative(replacementConcentration, 'replacementConcentration');
  if (changeVolumeLiters > tankVolumeLiters) {
    throw ArgumentError.value(changeVolumeLiters, 'changeVolumeLiters');
  }
  if (changes < 0) {
    throw ArgumentError.value(changes, 'changes');
  }
}

void _requirePositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive and finite');
  }
}

void _requireNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be non-negative and finite');
  }
}
