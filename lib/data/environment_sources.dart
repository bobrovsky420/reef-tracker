// Environment sources (U37): device-agnostic access to *current* environment
// readings — salinity, temperature, pH — from connected hardware, so a Hanna
// BLE measurement session (U33) can save the tank's environment alongside its
// own results.
//
// The Hanna screen never talks to a vendor transport: it asks
// [environmentSourcesForTank] for the target tank's sources, reads each once,
// and funnels the per-source results through [selectEnvironmentValues], which
// picks exactly ONE value per parameter (a deterministic priority instead of
// asking the user — see that function). Today the only implementation wraps
// ReefFactory LAN meters (U36); a future device kind is one new
// [EnvironmentSource] implementation here, with no change to the Hanna flow.

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'database.dart';
import 'rf_device_link.dart';
import 'rf_protocol.dart';

/// The parameters environment capture deals in (canonical catalog keys).
const Set<String> kEnvironmentParams = {'temperature', 'salinity', 'ph'};

/// One source's successful read: which device, when, and what it reported
/// (values in canonical units, impossible values already dropped).
typedef EnvSourceReadings = ({
  String identifier,
  String displayName,
  Set<String> primaryParams,
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

  /// The parameters this device is *dedicated* to, as opposed to reporting
  /// incidentally: a Temperature Controller is primary for temperature, while
  /// a Salinity Guardian reports temperature only as a side effect of
  /// measuring conductivity.
  Set<String> get primaryParams;

  /// Reads the device's current values. Throws on transport failure.
  Future<EnvSourceReadings> read();
}

/// [EnvironmentSource] over a ReefFactory LAN meter (the U36 transport).
class RfEnvironmentSource implements EnvironmentSource {
  RfEnvironmentSource(this._device, this._link);

  final DeviceRecord _device;
  final RfDeviceLink _link;

  /// Which parameter each ReefFactory model is dedicated to. A model absent
  /// here (future firmware) counts as primary for nothing — its values still
  /// win when no dedicated device competes.
  static const Map<String, Set<String>> _primaryByModel = {
    'RFSG01': {'salinity'},
    'RFPM01': {'ph'},
    kRfTempControllerModel: {'temperature'},
  };

  @override
  String get identifier => _device.identifier;

  /// Same fallback chain as the ReefFactory dashboard's card title.
  @override
  String get displayName => _device.name ?? _device.model ?? _device.identifier;

  @override
  Set<String> get primaryParams => _primaryByModel[_device.model] ?? const {};

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
      primaryParams: primaryParams,
      takenAt: DateTime.now(),
      readings: [
        // Same normalization as the dashboard save path (`rfReadingsToSave`):
        // the Guardian reports ppt but salinity is stored as specific gravity,
        // and impossible values are noise, not data. The dashboard's
        // temperature-source rule is deliberately NOT applied here —
        // [selectEnvironmentValues]'s dedicated-device priority generalizes it.
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
          if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible)
            r,
      ],
    );
  }
}

/// The environment sources for [tankId]: every registered device assigned to
/// that tank that can report environment readings. Today: ReefFactory meters
/// with a usable address.
List<EnvironmentSource> environmentSourcesForTank({
  required int tankId,
  required List<DeviceRecord> rfDevices,
  required RfDeviceLink rfLink,
}) => [
  for (final d in rfDevices)
    if (d.tankId == tankId && d.address != null && d.address!.isNotEmpty)
      RfEnvironmentSource(d, rfLink),
];

/// Picks exactly one value per environment parameter from the per-source
/// [results] — the "simple algorithm instead of asking the user" rule:
///
///  1. a source *dedicated* to the parameter beats one reporting it
///     incidentally (generalizes the U36 temperature-source rule: the
///     Temperature Controller wins over the Salinity Guardian's thermometer);
///  2. among equals, the more recent read wins;
///  3. remaining ties break on device identifier, so the choice never
///     flip-flops between sessions.
///
/// Parameters outside [kEnvironmentParams] are ignored.
Map<String, EnvValue> selectEnvironmentValues(
  Iterable<EnvSourceReadings> results,
) {
  final winners =
      <String, ({EnvValue value, bool primary, String identifier})>{};
  for (final result in results) {
    for (final r in result.readings) {
      if (!kEnvironmentParams.contains(r.paramKey)) continue;
      final candidate = (
        value: (
          paramKey: r.paramKey,
          value: r.value,
          deviceName: result.displayName,
          takenAt: result.takenAt,
        ),
        primary: result.primaryParams.contains(r.paramKey),
        identifier: result.identifier,
      );
      final current = winners[r.paramKey];
      final bool wins;
      if (current == null) {
        wins = true;
      } else if (candidate.primary != current.primary) {
        wins = candidate.primary;
      } else if (!candidate.value.takenAt.isAtSameMomentAs(
        current.value.takenAt,
      )) {
        wins = candidate.value.takenAt.isAfter(current.value.takenAt);
      } else {
        wins = candidate.identifier.compareTo(current.identifier) < 0;
      }
      if (wins) winners[r.paramKey] = candidate;
    }
  }
  return {for (final e in winners.entries) e.key: e.value.value};
}
