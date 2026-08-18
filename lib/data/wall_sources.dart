/// Wall display (U49): what each vendor's snapshot contributes to the wall —
/// the measurement readings behind the value cards (§12q: one card per device
/// *and* parameter) and nothing else. Pure functions over the protocol types,
/// shared by the tile renderer and the sample writer so a card and its graph
/// can never disagree about what a device reported.
///
/// Canonicalization mirrors the save paths (`rfValuesToSave` /
/// `apReadingsToSave`): salinity arrives as ppt and is stored/displayed as
/// specific gravity, and physically **impossible** values are dropped — they
/// are noise, not data. Rail values (a dead probe's 0 dKH) are *kept* here —
/// the tile shows what the device says — and dropped only by the sample
/// writer, so they can't destroy the graph's y-scale (§12m rule 4).
///
/// Deliberately NO ReefFactory temperature-source rule and no cross-device
/// precedence: under §12q every value every device reports gets its own card,
/// and the keeper expresses preference by hiding cards, not by a merge rule.
library;

import '../domain/device_vendors.dart';
import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import '../domain/wall_display.dart';
import 'ap_protocol.dart';
import 'database.dart';
import 'rb_measurements.dart';
import 'rb_snapshot.dart';
import 'rf_protocol.dart';

typedef WallReading = ({String paramKey, double value});

enum WallSourceOperatingState { heating, cooling }

enum WallLevelState { ok, below, above, unknown }

enum WallStockLevel { healthy, caution, critical, unknown }

sealed class WallStatusFact {
  const WallStatusFact();
}

class WallAtoFact extends WallStatusFact {
  const WallAtoFact({
    required this.level,
    this.rawLevel,
    required this.leakSensorActive,
    required this.leakAlarm,
    this.daysTillEmpty,
    required this.stockLevel,
  });

  final WallLevelState level;
  final String? rawLevel;
  final bool leakSensorActive;
  final bool leakAlarm;
  final int? daysTillEmpty;
  final WallStockLevel stockLevel;
}

class WallDoseHeadFact {
  const WallDoseHeadFact({
    required this.label,
    required this.switchedOff,
    this.remainingDays,
    required this.stockLevel,
  });

  final String label;
  final bool switchedOff;
  final int? remainingDays;
  final WallStockLevel stockLevel;
}

class WallDoseFact extends WallStatusFact {
  const WallDoseFact(this.heads);

  final List<WallDoseHeadFact> heads;
}

class WallFilterRollFact extends WallStatusFact {
  const WallFilterRollFact({required this.empty, this.daysTillEndOfRoll});

  final bool empty;
  final int? daysTillEndOfRoll;
}

class WallSkimmerFact extends WallStatusFact {
  const WallSkimmerFact({
    this.name,
    required this.fullCup,
    required this.overSkimming,
    required this.faulted,
  });

  final String? name;
  final bool fullCup;
  final bool overSkimming;
  final bool faulted;
}

/// Everything Wall needs from one successful device payload. No vendor DTO
/// crosses this boundary, so renderers and poll scheduling are integration
/// agnostic.
class WallDeviceSnapshot {
  const WallDeviceSnapshot({
    this.readings = const [],
    this.statusFacts = const [],
    this.operatingStates = const {},
    required this.signature,
  });

  final List<WallReading> readings;
  final List<WallStatusFact> statusFacts;
  final Map<String, WallSourceOperatingState> operatingStates;
  final String signature;
}

/// Whether an inventory device belongs on this wall. A sole aquarium is the
/// unambiguous home for an unassigned device; this also self-heals the visible
/// effect of restores made before the restore merge retained tank links.
bool deviceInWallTank(
  int? deviceTankId, {
  required int activeTankId,
  required int tankCount,
}) => deviceTankId == activeTankId || (deviceTankId == null && tankCount == 1);

class WallInventoryEntry {
  const WallInventoryEntry({required this.kind, required this.device});

  final DeviceKind kind;
  final DeviceRecord device;
}

class WallDeviceInventory {
  const WallDeviceInventory({
    this.entries = const [],
    this.unsupported = const [],
  });

  final List<WallInventoryEntry> entries;
  final List<DeviceRecord> unsupported;
}

/// The single inventory/scoping rule consumed by Wall and Wall Settings.
/// Unsupported persisted rows are retained explicitly for diagnostics but are
/// never polled or rendered as another integration.
WallDeviceInventory buildWallDeviceInventory({
  required int activeTankId,
  required int tankCount,
  required List<String> vendorOrder,
  required Map<DeviceKind, List<DeviceRecord>> devicesByKind,
  List<DeviceRecord> unsupported = const [],
}) {
  List<DeviceRecord> scoped(Iterable<DeviceRecord> devices) =>
      [
        for (final device in devices)
          if (deviceInWallTank(
            device.tankId,
            activeTankId: activeTankId,
            tankCount: tankCount,
          ))
            device,
      ]..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        if (byOrder != 0) return byOrder;
        return deviceDisplayName(
          a,
        ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
      });

  final entries = <WallInventoryEntry>[];
  for (final kindId in orderDeviceVendors(
    encodeDeviceVendorOrder(vendorOrder),
  )) {
    final kind = DeviceKind.tryParse(kindId);
    if (kind == null || !kind.capabilities.refreshes) continue;
    for (final device in scoped(devicesByKind[kind] ?? const [])) {
      entries.add(WallInventoryEntry(kind: kind, device: device));
    }
  }
  return WallDeviceInventory(
    entries: entries,
    unsupported: scoped(unsupported),
  );
}

/// The readings a registered ReefFactory meter is known to expose before its
/// first successful wall poll. The stored model is authoritative; the serial
/// prefix remains a fallback for older inventory rows without a model.
List<String> wallKnownRfParams({String? model, required String identifier}) {
  final spec =
      (model == null ? null : kRfModels[model]) ?? rfModelForSerial(identifier);
  return switch (spec?.name) {
    'salinity' => const ['salinity', 'temperature'],
    'pH' => const ['ph'],
    'temperature' => const ['temperature'],
    _ => const [],
  };
}

List<WallReading> _canonical(Iterable<WallReading> raw) => [
  for (final r in raw.map(
    (r) => (
      paramKey: r.paramKey,
      value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
    ),
  ))
    if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible) r,
];

/// A ReefFactory meter's wall readings — everything the snapshot carries,
/// the Salinity Guardian's incidental temperature included.
List<WallReading> wallRfReadings(RfSnapshot snap) => _canonical([
  for (final r in snap.readings) (paramKey: r.paramKey, value: r.value),
]);

WallDeviceSnapshot wallRfSnapshot(RfSnapshot snapshot) {
  final readings = wallRfReadings(snapshot);
  final operating = switch (snapshot.thermal) {
    RfThermalState.heating => WallSourceOperatingState.heating,
    RfThermalState.cooling => WallSourceOperatingState.cooling,
    _ => null,
  };
  return WallDeviceSnapshot(
    readings: readings,
    operatingStates: {'temperature': ?operating},
    signature: wallPayloadSignature(readings),
  );
}

/// An Apex controller's wall readings ([ApStatus.readings] already resolves
/// one probe per parameter and drops non-ppt conductivity).
List<WallReading> wallApReadings(ApStatus status) => _canonical([
  for (final r in status.readings) (paramKey: r.paramKey, value: r.value),
]);

WallDeviceSnapshot wallApSnapshot(ApStatus status) {
  final readings = wallApReadings(status);
  return WallDeviceSnapshot(
    readings: readings,
    signature: wallPayloadSignature(readings),
  );
}

/// A ReefBeat device's wall readings. Most Red Sea gear reports what it is
/// doing rather than measurements; ReefATO+ contributes its level-sensor
/// temperature and ReefControl contributes one primary value per attached
/// water probe plus the first valid combined-probe temperature, matching the
/// controller's save and Hanna-environment rule.
List<WallReading> wallRbReadings(RbSnapshot snap) {
  final readings = switch (snap) {
    RbAtoSnapshot(:final status) => <WallReading>[
      if (status.temperatureC case final t?)
        (paramKey: 'temperature', value: t),
    ],
    RbControlSnapshot(:final status) => <WallReading>[
      for (final r in rbControlMeasurements(status))
        (paramKey: r.paramKey, value: r.value),
    ],
    RbDoseSnapshot() ||
    RbMatSnapshot() ||
    RbRunSnapshot() ||
    RbLightSnapshot() ||
    RbWaveSnapshot() => <WallReading>[],
  };
  // ReefControl values are already canonicalized by the shared save/Hanna
  // extractor. ReefATO temperature needs only the same impossible-value guard.
  return [
    for (final r in readings)
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible) r,
  ];
}
