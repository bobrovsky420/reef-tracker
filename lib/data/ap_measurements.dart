/// Neptune Apex measurement normalization shared by the integration registry,
/// Devices save flow, and tests. Pure Dart: no widget dependency.
library;

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'ap_protocol.dart';
import 'device_measurements.dart';

/// Converts Apex probe readings to canonical storage values and removes only
/// physically impossible noise. A controller already supplies one chosen
/// reading per parameter, so no cross-device precedence is applied here.
List<DeviceMeasurement> apReadingsToSave(List<ApReading> readings) {
  return [
    for (final r in readings.map(
      (r) => (
        paramKey: r.paramKey,
        value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
      ),
    ))
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible) r,
  ];
}
