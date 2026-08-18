/// Canonical ReefControl measurements shared by history saves and the Hanna
/// checker's environment suggestions.
library;

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'rb_protocol.dart';

/// Extracts one storable value per ReefControl parameter, in probe order.
///
/// Salinity is converted from the controller's ppt value to ReefTracker's
/// canonical specific gravity. A combined probe's temperature is added only
/// once: the first water probe carrying one wins, exactly matching the device
/// rule used by both save surfaces. Firmware `level` / `temp_level` fields are
/// presentation metadata and intentionally never participate.
///
/// Impossible values are dropped at the device boundary. Suspicious-but-
/// storable values remain so the normal confirmation flow can ask the keeper.
List<({String paramKey, double value})> rbControlMeasurements(
  RbControlStatus status,
) {
  final values = <({String paramKey, double value})>[];
  final seen = <String>{};

  void add(String paramKey, double? value) {
    if (value == null || seen.contains(paramKey)) return;
    if (checkParamValue(paramKey, value) == ParamValueCheck.impossible) return;
    seen.add(paramKey);
    values.add((paramKey: paramKey, value: value));
  }

  for (final probe in status.waterProbes) {
    switch (probe.type) {
      case 'ec':
        final ppt = probe.salinityPpt;
        add('salinity', ppt == null ? null : pptToSg(ppt));
      case 'ph':
        add('ph', probe.value);
      case 'orp':
        add('orp', probe.value);
    }
    add('temperature', probe.temperatureC);
  }
  return values;
}
