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

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'ap_protocol.dart';
import 'rb_device_link.dart';
import 'rf_protocol.dart';

typedef WallReading = ({String paramKey, double value});

/// Whether an inventory device belongs on this wall. A sole aquarium is the
/// unambiguous home for an unassigned device; this also self-heals the visible
/// effect of restores made before the restore merge retained tank links.
bool deviceInWallTank(
  int? deviceTankId, {
  required int activeTankId,
  required int tankCount,
}) => deviceTankId == activeTankId || (deviceTankId == null && tankCount == 1);

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

/// An Apex controller's wall readings ([ApStatus.readings] already resolves
/// one probe per parameter and drops non-ppt conductivity).
List<WallReading> wallApReadings(ApStatus status) => _canonical([
  for (final r in status.readings) (paramKey: r.paramKey, value: r.value),
]);

/// A ReefBeat device's wall readings. Red Sea gear reports what it is doing
/// rather than measurements — the one exception is the ReefATO+'s level
/// sensor, which carries a temperature probe.
List<WallReading> wallRbReadings(RbSnapshot snap) => _canonical([
  if (snap.ato?.temperatureC case final t?) (paramKey: 'temperature', value: t),
]);
