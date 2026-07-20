/// Default zone bounds, correction targets, and default tracked-parameter
/// sets per tank setup type.
///
/// **The data ([kPresets], [kPresetTargets]) is GENERATED from
/// `tank_presets.yaml`** — do not edit it by hand. Edit the YAML, then run
/// `dart run tool/gen_tank_presets.dart` to regenerate `presets.g.dart`.
/// This file owns the lookups.
library;

import 'setup_type.dart';
import 'zones.dart';

part 'presets.g.dart';

/// The default zone boundaries for a given setup type + parameter, or an empty
/// [ZoneBounds] if the preset does not define that parameter.
ZoneBounds presetBounds(SetupType type, String paramKey) =>
    kPresets[type]?[paramKey] ?? const ZoneBounds();

/// The default correction target for a setup type + parameter, in the
/// parameter's canonical unit — the value the dose calculator's correction
/// mode aims for. Null when the preset defines none: targets are only defined
/// where the sensible target is NOT simply the middle of the green zone
/// (currently alkalinity, whose wide safe band sits above the commonly
/// recommended set point); callers fall back to the green-zone midpoint.
/// Seeded into `TrackedParameters.targetValue` (editable per tank, like the
/// bounds).
double? presetTarget(SetupType type, String paramKey) =>
    kPresetTargets[type]?[paramKey];

/// The parameter keys tracked by default for a setup type, in preset order.
List<String> defaultTrackedKeys(SetupType type) =>
    (kPresets[type] ?? const {}).keys.toList();
