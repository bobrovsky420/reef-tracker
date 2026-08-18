/// ReefFactory measurement normalization shared by the integration registry,
/// Devices save flow, and tests. Pure Dart: no widget or provider dependency.
library;

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'database.dart';
import 'device_measurements.dart';
import 'rf_protocol.dart';

/// Filters live ReefFactory [readings] down to values safe to persist.
///
/// Salinity is converted from ppt to the catalog's canonical specific gravity,
/// physically impossible values are removed, and a dedicated Temperature
/// Controller wins over the Salinity Guardian's incidental thermometer.
List<DeviceMeasurement> rfReadingsToSave({
  required String? deviceModel,
  required List<RfReading> readings,
  required bool hasTempController,
}) {
  return [
    for (final r in readings.map(
      (r) => (
        paramKey: r.paramKey,
        value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
      ),
    ))
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible &&
          !(r.paramKey == 'temperature' &&
              deviceModel != kRfTempControllerModel &&
              hasTempController))
        r,
  ];
}

/// The values [snapshot] would persist for [device]. Only a Temperature
/// Controller assigned to the same tank suppresses another meter's incidental
/// temperature.
List<DeviceMeasurement> rfValuesToSave(
  DeviceRecord device,
  RfSnapshot snapshot,
  Iterable<DeviceRecord> peerDevices,
) => rfReadingsToSave(
  deviceModel: device.model,
  readings: snapshot.readings,
  hasTempController: peerDevices.any(
    (d) => d.model == kRfTempControllerModel && d.tankId == device.tankId,
  ),
);
