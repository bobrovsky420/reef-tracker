/// Default zone bounds, correction targets, and default tracked-parameter
/// sets per tank setup type.
///
/// **The data ([kPresets], [kPresetTargets]) is GENERATED from
/// `tank_presets.yaml`** — do not edit it by hand. Edit the YAML, then run
/// `dart run tool/gen_tank_presets.dart` to regenerate `presets.g.dart`.
/// This file owns the lookups.
library;

import 'parameter_catalog.dart';
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
/// Never stored: a tank keeps only its own override (`ParameterOverrides`),
/// and the absence of one resolves through [defaultTargetFor].
double? presetTarget(SetupType type, String paramKey) =>
    kPresetTargets[type]?[paramKey];

/// The parameter keys tracked by default for a setup type, in preset order.
List<String> defaultTrackedKeys(SetupType type) =>
    (kPresets[type] ?? const {}).keys.toList();

/// **The** default zone bounds for [paramKey] on a tank of [type] — the single
/// answer to "what should this parameter's zones be when the tank has not
/// overridden them".
///
/// Parameters resolve to their setup-type preset first, then to a catalog
/// default (`parameters.yaml`). Catalog defaults cover every microelement and
/// optional, setup-independent core parameters such as ORP. Empty when neither
/// defines one — a real case, not a bug: fish-only tanks have no calcium or
/// alkalinity preset, so tracking calcium there gives an uncoloured "No
/// boundaries set" row until the user sets bounds by hand.
///
/// Resolved on **read**, never stored. Changing a tank's setup type, or
/// shipping a new catalog, therefore re-colours every parameter the tank has
/// not overridden — with no migration and no re-apply step.
ZoneBounds defaultBoundsFor(SetupType type, String paramKey) {
  final preset = presetBounds(type, paramKey);
  return preset.isEmpty
      ? kParameterByKey[paramKey]?.defaultBounds ?? const ZoneBounds()
      : preset;
}

/// The default correction target for [paramKey] on a tank of [type]. Only the
/// setup-type presets define targets (currently alkalinity); microelements
/// have none and fall back to the green-zone midpoint at use time. Same
/// read-time resolution contract as [defaultBoundsFor].
double? defaultTargetFor(SetupType type, String paramKey) =>
    presetTarget(type, paramKey);
