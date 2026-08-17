/// The device-vendor model behind the unified Devices screen (U41). Pure
/// domain — no Flutter, no DB — so the ordering rules are unit-tested directly.
///
/// A *vendor* here is a `Devices.kind` value that has its own section and
/// selector chip on the page: ReefFactory meters (U36), Red Sea ReefBeat
/// devices (U38), Neptune Apex controllers (U40) — and, since U43, the Hanna
/// checker. The checker is the odd one out: it is the keeper's own test kit
/// reached over Bluetooth for a single measurement, not tank hardware sitting
/// on the network, so its card is inventory plus a "new measurement" entry
/// point — never polled ([deviceKindRefreshes]), never saved from
/// ([deviceKindSaves]), and it keeps its own Pro gate (`hannaConnect`).
library;

/// Pure capabilities shared by inventory, bulk actions, backup validation,
/// and integration composition. Model-specific capability checks stay on
/// [DeviceKind] because ReefBeat mixes measuring and status-only families.
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.refreshes,
    required this.containsSavableModels,
    required this.contributesEnvironment,
    this.authenticated = false,
  });

  final bool refreshes;
  final bool containsSavableModels;
  final bool contributesEnvironment;
  final bool authenticated;
}

/// The canonical device integration identity.
///
/// [id] is persisted in `Devices.kind`, backup documents, and settings. These
/// values are a storage contract: never rename one. Parsing is deliberately
/// exact and nullable so corrupt/future values become unsupported instead of
/// being guessed as another integration.
enum DeviceKind {
  reefFactory(
    'reeffactory',
    DeviceCapabilities(
      refreshes: true,
      containsSavableModels: true,
      contributesEnvironment: true,
    ),
  ),
  reefBeat(
    'reefbeat',
    DeviceCapabilities(
      refreshes: true,
      containsSavableModels: true,
      contributesEnvironment: true,
    ),
  ),
  apex(
    'apex',
    DeviceCapabilities(
      refreshes: true,
      containsSavableModels: true,
      contributesEnvironment: false,
      authenticated: true,
    ),
  ),
  hanna(
    'hanna',
    DeviceCapabilities(
      refreshes: false,
      containsSavableModels: false,
      contributesEnvironment: false,
    ),
  );

  const DeviceKind(this.id, this.capabilities);

  final String id;
  final DeviceCapabilities capabilities;

  static DeviceKind? tryParse(String id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// Whether one stored model exposes measurements the Devices page can save.
  bool savesModel(String? model) => switch (this) {
    DeviceKind.reefFactory || DeviceKind.apex => true,
    DeviceKind.reefBeat =>
      model != null && model.toUpperCase().startsWith('RSCONTROL'),
    DeviceKind.hanna => false,
  };
}

/// Registration order is also the default Devices-page vendor order.
const List<DeviceKind> kDeviceKinds = DeviceKind.values;

/// The complete allowlist for persisted and restored `Devices.kind` values.
const Set<String> kKnownDeviceKindIds = {
  'reeffactory',
  'reefbeat',
  'apex',
  'hanna',
};

// Compatibility names for storage-facing code that still accepts strings.
// New integration code should carry [DeviceKind] and convert only at the DB,
// backup, or settings boundary.
const String kDeviceKindReefFactory = 'reeffactory';
const String kDeviceKindReefBeat = 'reefbeat';
const String kDeviceKindApex = 'apex';
const String kDeviceKindHanna = 'hanna';

/// Every vendor the Devices screen knows, in **registration order** — the order
/// their integrations shipped. This is the default vendor order, and the
/// fallback position for any vendor missing from a stored order (see
/// [orderDeviceVendors]): a vendor added by a later app update lands at the end
/// rather than silently jumping ahead of the user's arrangement.
const List<String> kDeviceVendors = [
  kDeviceKindReefFactory,
  kDeviceKindReefBeat,
  kDeviceKindApex,
  kDeviceKindHanna,
];

/// Whether [kind] contains devices that can report values Save persists.
///
/// ReefBeat is a mixed vendor: ReefControl is a measuring device, while its
/// pumps, lights, ATO and filter report operational status only. Use
/// [deviceModelSaves] for a particular card/count; this broader predicate is
/// the exhaustiveness guard for vendor save mappings.
bool deviceKindSaves(String kind) =>
    DeviceKind.tryParse(kind)?.capabilities.containsSavableModels ?? false;

/// Whether one stored device model exposes measurements that can be saved.
///
/// ReefFactory and Apex are measurement-capable throughout their registered
/// families. Red Sea becomes capable only for ReefControl Lite/Pro; prefix
/// matching keeps a later ReefControl model working without teaching this
/// domain layer every product suffix.
bool deviceModelSaves(String kind, String? model) =>
    DeviceKind.tryParse(kind)?.savesModel(model) ?? false;

/// Whether devices of [kind] are read over the LAN by the page's refresh
/// actions (on-open auto-read and Refresh all alike). The Hanna checker is
/// not: it is connected over Bluetooth only for the duration of a measurement
/// session its card starts, so there is nothing to poll — and it must not be
/// counted by the Refresh-all button either.
bool deviceKindRefreshes(String kind) =>
    DeviceKind.tryParse(kind)?.capabilities.refreshes ?? false;

/// Per-model minimum poll interval for the wall display's loop (U49 §12n):
/// what the *device* is capable of, as opposed to how live the user wants the
/// wall to feel (the one visible knob). A batch-measurement device that
/// produces a new number every N minutes is floored here whatever the display
/// interval says; continuous probes are absent and run at the display rate.
///
/// Empty today — every model the app integrates (ReefFactory probes, ReefBeat
/// status, Apex probes) reports continuously. The seam exists so the first
/// batch device (an Alkatronic-class titrator) is a one-line entry, not a
/// design change.
const Map<String, Duration> kDeviceModelPollFloor = {};

/// The poll floor for a device of [kind] / [model], or null for continuous
/// devices (no floor — the display interval applies unchanged).
Duration? minPollIntervalOf(String kind, {String? model}) =>
    model == null ? null : kDeviceModelPollFloor[model];

/// The user's vendor order, resolved from the [stored] setting value against
/// the vendors this build knows ([known], defaulting to [kDeviceVendors]).
///
/// Vendor order is not cosmetic: the Devices screen resolves a duplicated
/// parameter on Save all by **first displayed wins**, so this list also decides
/// which vendor's temperature beats which. That is why it is user-arrangeable
/// (the "Reorder brands" sheet) rather than fixed.
///
/// Tolerant by construction, because the stored value outlives app versions: an
/// unknown kind (a vendor removed from the app) is dropped, a duplicate is kept
/// once, and any known kind the stored order doesn't mention is appended in
/// registration order. A null/blank/garbage value therefore yields exactly
/// [known].
///
/// A vendor whose devices have all been removed deliberately **keeps its
/// position** — its chip simply doesn't render — so adding one back later puts
/// it where the user left it instead of at the end.
List<String> orderDeviceVendors(
  String? stored, {
  List<String> known = kDeviceVendors,
}) {
  final ordered = <String>[];
  for (final raw in (stored ?? '').split(',')) {
    final kind = raw.trim();
    if (known.contains(kind) && !ordered.contains(kind)) ordered.add(kind);
  }
  for (final kind in known) {
    if (!ordered.contains(kind)) ordered.add(kind);
  }
  return ordered;
}

/// Encodes a vendor order for storage. The inverse of [orderDeviceVendors]'s
/// parsing half.
String encodeDeviceVendorOrder(List<String> order) => order.join(',');
