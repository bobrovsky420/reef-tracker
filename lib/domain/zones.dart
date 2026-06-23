import 'package:flutter/material.dart';

/// Health classification of a single reading against its configured boundaries.
enum Zone {
  /// Value is within the OK range.
  green,

  /// Value needs attention but is not yet critical.
  amber,

  /// Value requires immediate reaction.
  red,

  /// No boundaries configured / no reading available.
  unknown,
}

/// The four boundaries that split the number line into green / amber / red.
///
/// Invariant (when all non-null): `amberLow <= greenLow <= greenHigh <= amberHigh`.
///
/// - green zone:  `[greenLow, greenHigh]`
/// - amber zone:  `[amberLow, greenLow)` and `(greenHigh, amberHigh]`
/// - red zone:    `< amberLow` or `> amberHigh`
///
/// Any bound may be `null`, meaning "unbounded on that side" — e.g. a parameter
/// whose value can never be too low only sets the upper bounds.
@immutable
class ZoneBounds {
  const ZoneBounds({
    this.amberLow,
    this.greenLow,
    this.greenHigh,
    this.amberHigh,
  });

  final double? amberLow;
  final double? greenLow;
  final double? greenHigh;
  final double? amberHigh;

  bool get isEmpty =>
      amberLow == null &&
      greenLow == null &&
      greenHigh == null &&
      amberHigh == null;

  ZoneBounds copyWith({
    double? amberLow,
    double? greenLow,
    double? greenHigh,
    double? amberHigh,
  }) =>
      ZoneBounds(
        amberLow: amberLow ?? this.amberLow,
        greenLow: greenLow ?? this.greenLow,
        greenHigh: greenHigh ?? this.greenHigh,
        amberHigh: amberHigh ?? this.amberHigh,
      );

  /// Classifies [value] into a [Zone] using these boundaries.
  Zone classify(double value) {
    if (isEmpty) return Zone.unknown;

    final aboveGreenLow = greenLow == null || value >= greenLow!;
    final belowGreenHigh = greenHigh == null || value <= greenHigh!;
    if (aboveGreenLow && belowGreenHigh) return Zone.green;

    // Outside green — red only if beyond a defined amber bound.
    if (amberLow != null && value < amberLow!) return Zone.red;
    if (amberHigh != null && value > amberHigh!) return Zone.red;
    return Zone.amber;
  }
}

extension ZoneVisuals on Zone {
  Color get color {
    switch (this) {
      case Zone.green:
        return const Color(0xFF2E9E5B);
      case Zone.amber:
        return const Color(0xFFE6A100);
      case Zone.red:
        return const Color(0xFFD93838);
      case Zone.unknown:
        return const Color(0xFF9E9E9E);
    }
  }

  String get label {
    switch (this) {
      case Zone.green:
        return 'OK';
      case Zone.amber:
        return 'Attention';
      case Zone.red:
        return 'Act now';
      case Zone.unknown:
        return '—';
    }
  }

  IconData get icon {
    switch (this) {
      case Zone.green:
        return Icons.check_circle;
      case Zone.amber:
        return Icons.warning_amber_rounded;
      case Zone.red:
        return Icons.error;
      case Zone.unknown:
        return Icons.help_outline;
    }
  }
}
