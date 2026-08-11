/// The headless "read every device in scope" core (U49 §12d), lifted out of
/// the Devices page so the wall display — and later U45's unattended logging —
/// walk exactly the same scope with exactly the same politeness rule, instead
/// of growing private copies.
///
/// Pure Dart over the drift row type: the vendor transports stay behind the
/// caller-supplied [DeviceReader] (the `*DeviceLink` seam), so this file knows
/// how to *order* reads, never how to perform one.
library;

import '../domain/device_vendors.dart';
import 'database.dart';

/// The devices in view — what a bulk read or save acts on — **in the order
/// the Devices page renders them**: vendors in the user's brand order, devices
/// in their own card order within each vendor.
///
/// The order is the point, not a convenience: Save all resolves a parameter
/// two devices both report by "first displayed wins", so anything that walks a
/// scope must walk [inPageOrder] rather than picking vendors out by hand.
class DeviceScope {
  const DeviceScope({required this.order, required this.byVendor});

  const DeviceScope.empty() : this(order: const [], byVendor: const {});

  /// The vendor kinds in view, in the user's own order.
  final List<String> order;

  /// Each vendor's devices, already scoped to the active tank and sorted by
  /// the caller.
  final Map<String, List<DeviceRecord>> byVendor;

  List<DeviceRecord> of(String kind) => byVendor[kind] ?? const [];

  /// Every device in view, paired with its vendor kind, in page order.
  Iterable<(String, DeviceRecord)> get inPageOrder sync* {
    for (final kind in order) {
      for (final d in of(kind)) {
        yield (kind, d);
      }
    }
  }

  int get length => order.fold(0, (n, kind) => n + of(kind).length);

  /// Devices of a meter-capable kind in view — zero hides Save all entirely.
  /// Asks [deviceKindSaves] instead of naming vendors, so a future meter
  /// vendor is counted without an edit here.
  int get meters =>
      order.where(deviceKindSaves).fold(0, (n, kind) => n + of(kind).length);

  /// Devices a Refresh all would actually read — the button's count, and zero
  /// hides it (a Hanna-only view has nothing to poll). Same open-ended idiom
  /// as [meters], via [deviceKindRefreshes].
  int get refreshables => order
      .where(deviceKindRefreshes)
      .fold(0, (n, kind) => n + of(kind).length);
}

/// Reads one device of a kind — the caller's transport wrapper (the Devices
/// page's per-vendor refresh, the wall screen's poll-and-sample step).
typedef DeviceReader = Future<void> Function(String kind, DeviceRecord device);

/// Reads everything refreshable in [scope] through [read]. Sequential
/// **within** a vendor — a meter is also serving the vendor's own cloud app,
/// and one socket at a time is gentle on it — but the vendors run
/// concurrently, so a slow controller doesn't hold up the meters.
///
/// [keepGoing] aborts the remaining reads between devices (a screen that was
/// disposed mid-walk); reads already in flight still settle.
Future<void> readDeviceScope(
  DeviceScope scope,
  DeviceReader read, {
  bool Function()? keepGoing,
}) async {
  Future<void> series(String kind) async {
    for (final d in scope.of(kind)) {
      if (keepGoing != null && !keepGoing()) return;
      await read(kind, d);
    }
  }

  await Future.wait([
    for (final kind in scope.order)
      if (deviceKindRefreshes(kind)) series(kind),
  ]);
}
