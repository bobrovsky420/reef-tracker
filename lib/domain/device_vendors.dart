/// The device-vendor model behind the unified Devices screen (U41). Pure
/// domain — no Flutter, no DB — so the ordering rules are unit-tested directly.
///
/// A *vendor* here is a `Devices.kind` value that has its own LAN integration
/// and therefore its own selector chip: ReefFactory meters (U36), Red Sea
/// ReefBeat devices (U38) and Neptune Apex controllers (U40). The Hanna checker
/// is deliberately **not** one — it is the keeper's own test kit reached over
/// Bluetooth for a single measurement, not tank hardware sitting on the network,
/// and it keeps its own screens and its own Pro gates.
library;

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
];

/// Whether devices of [kind] can report values that Save persists as readings.
///
/// This is a property of the *kind*, not of the current snapshot: a card of a
/// meter-capable kind always shows its Save button (disabled until a read
/// actually produces a value), while a controller-only card never shows one at
/// all — so a missing button reads as "nothing to save here", never as "not
/// ready yet". ReefBeat devices dose, top off, roll fleece and push water; none
/// of it is a measurement.
bool deviceKindSaves(String kind) =>
    kind == kDeviceKindReefFactory || kind == kDeviceKindApex;

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
