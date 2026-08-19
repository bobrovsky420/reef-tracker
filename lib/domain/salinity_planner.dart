/// Pure salt-mix and salinity-correction calculations.
///
/// All salinity inputs are practical salinity (ppt) and every volume is in
/// litres. Specific gravity and the keeper's preferred volume unit belong at
/// the presentation boundary; using SG directly in a concentration balance
/// would incorrectly include its freshwater baseline of 1.0.
library;

/// A keeper-calibrated commercial salt mix.
///
/// [gramsPerLiter] is grams of dry product per litre of *final prepared
/// saltwater* at [referencePpt]. Commercial mixes contain hydrated salts and
/// vary by product and batch, so this is deliberately not inferred from ppt.
class SaltMixCalibration {
  const SaltMixCalibration({
    this.name,
    required this.gramsPerLiter,
    required this.referencePpt,
  });

  final String? name;
  final double gramsPerLiter;
  final double referencePpt;

  bool get isValid =>
      _positiveFinite(gramsPerLiter) && _positiveFinite(referencePpt);
}

/// Normalizes an observed batch to [referencePpt].
///
/// Example: 764 g made 20 L measured at 35 ppt, normalized to 35 ppt, gives
/// 38.2 g/L. The linear salinity scaling is a starting estimate; the prepared
/// water must still be measured and adjusted.
double calibrateSaltMixGramsPerLiter({
  required double dryMassG,
  required double finalVolumeLiters,
  required double measuredPpt,
  required double referencePpt,
}) {
  _requirePositive(dryMassG, 'dryMassG');
  _requirePositive(finalVolumeLiters, 'finalVolumeLiters');
  _requirePositive(measuredPpt, 'measuredPpt');
  _requirePositive(referencePpt, 'referencePpt');
  return dryMassG / finalVolumeLiters * referencePpt / measuredPpt;
}

/// Estimated dry product needed for [finalVolumeLiters] at [targetPpt].
double saltMixMassGrams({
  required double finalVolumeLiters,
  required double targetPpt,
  required SaltMixCalibration calibration,
}) {
  _requirePositive(finalVolumeLiters, 'finalVolumeLiters');
  _requirePositive(targetPpt, 'targetPpt');
  if (!calibration.isValid) {
    throw ArgumentError.value(calibration, 'calibration', 'must be valid');
  }
  return finalVolumeLiters *
      calibration.gramsPerLiter *
      targetPpt /
      calibration.referencePpt;
}

/// Litres of tank water to remove and replace while keeping volume constant.
///
/// This is the well-mixed mass balance:
/// `Vx = V * (target - current) / (replacement - current)`.
/// The replacement must lie strictly beyond the target in the desired
/// direction. A tank already at target is a valid zero-work result.
double salinityCorrectionExchangeLiters({
  required double tankVolumeLiters,
  required double currentPpt,
  required double targetPpt,
  required double replacementPpt,
}) {
  _requirePositive(tankVolumeLiters, 'tankVolumeLiters');
  _requirePositive(currentPpt, 'currentPpt');
  _requirePositive(targetPpt, 'targetPpt');
  _requireNonNegative(replacementPpt, 'replacementPpt');

  if (currentPpt == targetPpt) return 0;
  final raising = targetPpt > currentPpt;
  final brackets = raising
      ? replacementPpt > targetPpt
      : replacementPpt < targetPpt;
  if (!brackets) {
    throw ArgumentError.value(
      replacementPpt,
      'replacementPpt',
      'must lie beyond targetPpt in the correction direction',
    );
  }

  final result =
      tankVolumeLiters *
      (targetPpt - currentPpt) /
      (replacementPpt - currentPpt);
  if (!result.isFinite || result <= 0 || result > tankVolumeLiters) {
    throw StateError('correction exchange is outside the tank volume');
  }
  return result;
}

/// Dry-product equivalent of the salt missing from a low-salinity tank.
///
/// This is informational only: dry commercial mix must not be added directly
/// to a stocked aquarium. A correction uses separately prepared replacement
/// water, whose volume is calculated by [salinityCorrectionExchangeLiters].
double additionalSaltEquivalentGrams({
  required double tankVolumeLiters,
  required double currentPpt,
  required double targetPpt,
  required SaltMixCalibration calibration,
}) {
  _requirePositive(tankVolumeLiters, 'tankVolumeLiters');
  _requirePositive(currentPpt, 'currentPpt');
  _requirePositive(targetPpt, 'targetPpt');
  if (targetPpt < currentPpt) {
    throw ArgumentError.value(
      targetPpt,
      'targetPpt',
      'must not be below currentPpt',
    );
  }
  if (!calibration.isValid) {
    throw ArgumentError.value(calibration, 'calibration', 'must be valid');
  }
  return tankVolumeLiters *
      calibration.gramsPerLiter *
      (targetPpt - currentPpt) /
      calibration.referencePpt;
}

bool _positiveFinite(double value) => value.isFinite && value > 0;

void _requirePositive(double value, String name) {
  if (!_positiveFinite(value)) {
    throw ArgumentError.value(value, name, 'must be positive and finite');
  }
}

void _requireNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be non-negative and finite');
  }
}
