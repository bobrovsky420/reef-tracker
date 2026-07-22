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

/// Case-color families of the Checker HC line. Hanna color-codes the
/// bodies; several models share a family (both alkalinity checkers are
/// blue, the whole phosphate family is green), so a family narrows the
/// candidates — the readout's display format does the rest.
enum CheckerColor { red, orange, yellow, green, blue, lavender, graphite, white }

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
    required this.color,
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

  /// The case-color family of the body (verified from product photos).
  final CheckerColor color;

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

/// Classifies an average case-color sample (RGB 0–255) into a
/// [CheckerColor] family, or null when the sample is too washed-out or
/// falls between families — a null just means "no color hint", never an
/// error. Thresholds are calibrated against the product-photo fixtures
/// (see test/checker_photo_test.dart) and kept generous: camera white
/// balance shifts hue, so families are broad and unclassifiable gaps are
/// deliberate.
CheckerColor? classifyCaseColor(double r, double g, double b) {
  final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
  final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
  final v = maxC / 255;
  final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
  // Calibrated against the product-photo samples (hue/sat/v per model):
  // reds 0–1° s.42–.51, orange 10° s.50, yellow 46° s.41, greens 114–117°
  // s.19–.30, blues 202° s.18–.41, lavender 256° s.12(!), white s.00
  // v.91, graphite s.02 v.56.
  if (sat < 0.11) {
    // Achromatic: the white pH checker vs the graphite magnesium checker.
    if (v >= 0.72) return CheckerColor.white;
    if (v <= 0.62) return CheckerColor.graphite;
    return null;
  }
  final delta = maxC - minC;
  double hue;
  if (maxC == r) {
    hue = 60 * (((g - b) / delta) % 6);
  } else if (maxC == g) {
    hue = 60 * ((b - r) / delta + 2);
  } else {
    hue = 60 * ((r - g) / delta + 4);
  }
  if (hue < 0) hue += 360;
  if (hue >= 350 || hue < 6) return CheckerColor.red;
  if (hue < 42) return CheckerColor.orange;
  if (hue < 72) return CheckerColor.yellow;
  if (hue < 168) return CheckerColor.green;
  if (hue < 192) return null; // cyan gap — no checker is cyan
  if (hue < 235) return CheckerColor.blue;
  if (hue < 320) return CheckerColor.lavender;
  return null; // magenta gap
}

/// The models whose display format matches [reading], with the case-color
/// family's models first when a [color] hint is available. This is what
/// resolves "which checker is this" without asking: usually the color +
/// format pair is unique; when it isn't, the caller shows the candidates
/// (order preserved from the registry) and the first one is preselected.
List<HannaChecker> candidateCheckersFor(
  SevenSegmentReading reading, {
  CheckerColor? color,
}) {
  final matches = [
    for (final c in kHannaCheckers)
      if (c.matches(reading)) c,
  ];
  if (color == null) return matches;
  return [
    for (final c in matches)
      if (c.color == color) c,
    for (final c in matches)
      if (c.color != color) c,
  ];
}

/// Deduplicates candidates to one per *outcome*: two models that store the
/// same parameter with the same factor produce identical measurements
/// (phosphate ULR vs LR, the three ppb nitrite checkers), so choosing
/// between them would be meaningless friction — the user is only asked
/// when the choice changes what gets saved. Order is preserved; the first
/// member of each outcome group represents it.
List<HannaChecker> distinctOutcomeCheckers(List<HannaChecker> candidates) {
  final seen = <String>{};
  return [
    for (final c in candidates)
      if (seen.add('${c.paramKey}/${c.factor}')) c,
  ];
}

/// Whether [candidate]'s outcome group (same parameter + factor) holds more
/// than one model of [candidates] — the UI then labels it by parameter
/// instead of claiming a specific model number.
bool outcomeIsShared(HannaChecker candidate, List<HannaChecker> candidates) {
  var n = 0;
  for (final c in candidates) {
    if (c.paramKey == candidate.paramKey && c.factor == candidate.factor) n++;
  }
  return n > 1;
}
