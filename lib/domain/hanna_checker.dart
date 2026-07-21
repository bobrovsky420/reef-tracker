/// Hanna pocket-checker registry (U34 — checker camera scan). Pure domain:
/// which Checker HC models the camera scan supports, what their LCD shows
/// (unit, decimal position, range) and how a displayed value converts to the
/// catalog's canonical unit.
///
/// The display format doubles as decode validation: a scanned readout whose
/// decimal position or range doesn't match the selected model is a misread
/// (or the wrong checker) and is rejected, never converted on faith.
library;

import 'package:meta/meta.dart';

import 'seven_segment.dart';

part 'hanna_checker.g.dart';

/// One pocket-checker model the scan supports. The table itself
/// ([kHannaCheckers]) is generated from `hanna_methods.yaml` — edit the
/// YAML, then run `dart run tool/gen_hanna_methods.dart`.
@immutable
class HannaChecker {
  const HannaChecker(
    this.model,
    this.paramKey, {
    this.tag,
    required this.unit,
    required this.decimals,
    required this.min,
    required this.max,
    this.factor = 1,
  });

  /// The Hanna model number, e.g. `HI774` — the stable identifier.
  final String model;

  /// The catalog parameter the reading lands on.
  final String paramKey;

  /// Range/variant disambiguator shown after the parameter name (`ULR`,
  /// `LR`, `HR`, `dKH`, `ppm`) when one parameter has several models; null
  /// when the model is its parameter's only entry.
  final String? tag;

  /// The unit printed on the checker's face (`ppm`, `ppb`, `dKH`, `pH`) —
  /// what the displayed number means, for the confirm UI.
  final String unit;

  /// Digits after the decimal point on the LCD (the display resolution).
  final int decimals;

  /// Display-unit range of the LCD readout.
  final double min;
  final double max;

  /// Multiplier from the displayed value to the catalog's canonical unit —
  /// 1 for most models; ppb nitrite → ppm is 0.001, ppb P → ppm PO₄ is
  /// 0.003066 (Hanna's ×3.066 P→PO₄ conversion), ppm CaCO₃ → dKH is 0.056.
  final double factor;

  /// Whether a decoded readout is a valid reading *for this model*: the
  /// decimal position must match the LCD's fixed format and the value must
  /// lie in the display range.
  bool matches(SevenSegmentReading reading) =>
      reading.decimals == decimals &&
      reading.value >= min &&
      reading.value <= max;
}

/// Lookup by model number; null for a model this build doesn't know.
HannaChecker? hannaCheckerByModel(String model) {
  for (final c in kHannaCheckers) {
    if (c.model == model) return c;
  }
  return null;
}
