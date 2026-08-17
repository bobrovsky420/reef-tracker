// Environment sources (U37): device-agnostic access to *current* environment
// readings — salinity, temperature, pH, ORP — from connected hardware, so a Hanna
// BLE measurement session (U33) can save the tank's environment alongside its
// own results.
//
// The Hanna screen never talks to a vendor transport: it asks
// [environmentSourcesForTank] for the target tank's sources, reads each once,
// and funnels the per-source results through [selectEnvironmentValues], which
// picks exactly ONE value per parameter in the same vendor/device order as the
// Devices page. Implementations wrap ReefFactory LAN
// meters (U36) and Red Sea ReefControl probes; adding another device kind does
// not change the Hanna flow.

import '../domain/device_vendors.dart';
import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'database.dart';
import 'rb_device_link.dart';
import 'rb_measurements.dart';
import 'rb_protocol.dart';
import 'rf_device_link.dart';

/// The parameters environment capture deals in (canonical catalog keys).
const Set<String> kEnvironmentParams = {'temperature', 'salinity', 'ph', 'orp'};

/// One source's successful read: which device, when, and what it reported
/// (values in canonical units, impossible values already dropped).
typedef EnvSourceReadings = ({
  String identifier,
  String displayName,
  DateTime takenAt,
  List<({String paramKey, double value})> readings,
});

/// One selected environment value — the winner for its parameter.
typedef EnvValue = ({
  String paramKey,
  double value,
  String deviceName,
  DateTime takenAt,
});

/// A registered device that can report current environment readings.
abstract class EnvironmentSource {
  /// Stable device identity (the `Devices.identifier` serial) — the
  /// deterministic last-resort tie-break of [selectEnvironmentValues].
  String get identifier;

  /// User-facing device label for the card's "from …" line.
  String get displayName;

  /// Reads the device's current values. Throws on transport failure.
  Future<EnvSourceReadings> read();
}

/// [EnvironmentSource] over a ReefFactory LAN meter (the U36 transport).
class RfEnvironmentSource implements EnvironmentSource {
  RfEnvironmentSource(this._device, this._link);

  final DeviceRecord _device;
  final RfDeviceLink _link;

  @override
  String get identifier => _device.identifier;

  /// Same fallback chain as the ReefFactory dashboard's card title.
  @override
  String get displayName => _device.name ?? _device.model ?? _device.identifier;

  @override
  Future<EnvSourceReadings> read() async {
    final address = _device.address;
    if (address == null || address.isEmpty) {
      throw const RfLinkException(RfLinkError.unreachable, 'no address');
    }
    final snap = await _link.readOnce(address);
    return (
      identifier: identifier,
      displayName: displayName,
      takenAt: DateTime.now(),
      readings: [
        // Same normalization as the dashboard save path (`rfReadingsToSave`):
        // the Guardian reports ppt but salinity is stored as specific gravity,
        // and impossible values are noise, not data. The dashboard's
        // temperature-source rule is deliberately NOT applied here: the
        // user's vendor and card order decides which duplicate wins.
        //
        // Only *impossible* values are dropped, and only here: a suspicious
        // one (outside the plausible range, or on the probe's rail) is a
        // question for the keeper, not for a data source to answer silently,
        // so it travels on and the Hanna results step puts it to them with
        // the meter's own values (#71).
        for (final r in snap.readings.map(
          (r) => (
            paramKey: r.paramKey,
            value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
          ),
        ))
          if (checkParamValue(r.paramKey, r.value) !=
              ParamValueCheck.impossible)
            r,
      ],
    );
  }
}

/// [EnvironmentSource] over a Red Sea ReefControl Lite/Pro.
class RbEnvironmentSource implements EnvironmentSource {
  RbEnvironmentSource(this._device, this._link);

  final DeviceRecord _device;
  final RbDeviceLink _link;

  @override
  String get identifier => _device.identifier;

  /// Same fallback chain as the Red Sea device card title.
  @override
  String get displayName => _device.name ?? _device.model ?? _device.identifier;

  @override
  Future<EnvSourceReadings> read() async {
    final address = _device.address;
    if (address == null || address.isEmpty) {
      throw const RbLinkException(RbLinkError.unreachable, 'no address');
    }
    final snap = await _link.readOnce(address);
    final status = snap.control;
    if (status == null) {
      throw const RbLinkException(
        RbLinkError.protocol,
        'not a ReefControl snapshot',
      );
    }
    return (
      identifier: identifier,
      displayName: displayName,
      takenAt: DateTime.now(),
      readings: [
        for (final r in rbControlMeasurements(status))
          if (kEnvironmentParams.contains(r.paramKey)) r,
      ],
    );
  }
}

/// The environment sources for [tankId]: every registered device assigned to
/// that tank that can report environment readings: ReefFactory meters and Red
/// Sea ReefControl devices with a usable address.
List<EnvironmentSource> environmentSourcesForTank({
  required int tankId,
  required List<String> vendorOrder,
  required List<DeviceRecord> rfDevices,
  required RfDeviceLink rfLink,
  required List<DeviceRecord> rbDevices,
  required RbDeviceLink rbLink,
}) {
  List<DeviceRecord> eligible(
    List<DeviceRecord> devices, {
    bool Function(DeviceRecord)? where,
  }) =>
      [
        for (final d in devices)
          if (d.tankId == tankId &&
              d.address != null &&
              d.address!.isNotEmpty &&
              (where == null || where(d)))
            d,
      ]..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        if (byOrder != 0) return byOrder;
        return deviceDisplayName(
          a,
        ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
      });

  final byVendor = <String, List<EnvironmentSource>>{
    kDeviceKindReefFactory: [
      for (final d in eligible(rfDevices)) RfEnvironmentSource(d, rfLink),
    ],
    kDeviceKindReefBeat: [
      for (final d in eligible(
        rbDevices,
        where: (d) => rbIsControlModel(d.model),
      ))
        RbEnvironmentSource(d, rbLink),
    ],
  };
  return [
    for (final kind in orderDeviceVendors(encodeDeviceVendorOrder(vendorOrder)))
      ...byVendor[kind] ?? const <EnvironmentSource>[],
  ];
}

/// Picks exactly one value per environment parameter from the per-source
/// [results] — the first value wins. Callers supply results in the Devices
/// page's order: the user's vendor order, then card order within that vendor;
/// readings within a device remain in its probe/payload order. A failed source
/// is absent, so the next available source naturally becomes the winner.
///
/// Parameters outside [kEnvironmentParams] are ignored.
Map<String, EnvValue> selectEnvironmentValues(
  Iterable<EnvSourceReadings> results,
) {
  final winners = <String, EnvValue>{};
  for (final result in results) {
    for (final r in result.readings) {
      if (!kEnvironmentParams.contains(r.paramKey)) continue;
      winners.putIfAbsent(
        r.paramKey,
        () => (
          paramKey: r.paramKey,
          value: r.value,
          deviceName: result.displayName,
          takenAt: result.takenAt,
        ),
      );
    }
  }
  return winners;
}
