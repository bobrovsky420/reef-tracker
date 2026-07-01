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

    // Red wins first: beyond a defined amber bound is critical regardless of
    // whether the matching green bound is set. (A config with an amber bound but
    // a null green bound on the same side must not short-circuit to green.)
    if (amberLow != null && value < amberLow!) return Zone.red;
    if (amberHigh != null && value > amberHigh!) return Zone.red;

    final aboveGreenLow = greenLow == null || value >= greenLow!;
    final belowGreenHigh = greenHigh == null || value <= greenHigh!;
    if (aboveGreenLow && belowGreenHigh) return Zone.green;

    return Zone.amber;
  }
}

/// A single horizontal zone band for a chart: fill the vertical range
/// `[y1, y2)` with [zone]'s colour. [y1] is always strictly less than [y2] —
/// [zoneBands] drops empty/inverted bands.
typedef ZoneBand = ({double y1, double y2, Zone zone});

/// Builds the green / amber / red horizontal bands for a chart spanning
/// [minY]..[maxY] from [b], as a pure, Flutter-free description so band
/// generation can be unit-tested without a chart widget.
///
/// The green band falls back to the *matching amber bound* (not the chart edge)
/// when a green bound is null, so a one-sided green bound can never spill over
/// the red band beyond it (finding #15). Any band that would be empty or
/// inverted (`y1 >= y2`), e.g. from inconsistent legacy/restored bounds, is
/// dropped rather than painted as a misleading sliver or overlap.
List<ZoneBand> zoneBands(ZoneBounds b, double minY, double maxY) {
  final bands = <ZoneBand>[];
  void add(double y1, double y2, Zone zone) {
    if (y1 < y2) bands.add((y1: y1, y2: y2, zone: zone));
  }

  // Green band.
  if (b.greenLow != null || b.greenHigh != null) {
    add(b.greenLow ?? b.amberLow ?? minY, b.greenHigh ?? b.amberHigh ?? maxY,
        Zone.green);
  }
  // Amber bands (between amber and green bounds).
  if (b.amberLow != null && b.greenLow != null) {
    add(b.amberLow!, b.greenLow!, Zone.amber);
  }
  if (b.amberHigh != null && b.greenHigh != null) {
    add(b.greenHigh!, b.amberHigh!, Zone.amber);
  }
  // Red bands (beyond amber bounds).
  if (b.amberLow != null) add(minY, b.amberLow!, Zone.red);
  if (b.amberHigh != null) add(b.amberHigh!, maxY, Zone.red);
  return bands;
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
