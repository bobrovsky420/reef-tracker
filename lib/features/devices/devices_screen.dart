import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/device_vendors.dart';
import '../../domain/pro_features.dart';
import '../../domain/setup_type.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../apex/apex_screen.dart';
import '../reefbeat/reefbeat_screen.dart';
import '../reeffactory/reeffactory_screen.dart';

/// The unified Devices screen (U41): every LAN device the keeper has connected,
/// on one page, behind a vendor selector.
///
/// It replaces the three per-vendor dashboards (`/reeffactory`, `/reefbeat`,
/// `/apex`) *and* the read-only Settings inventory (`/settings/devices`) — four
/// routes collapsed into one, reached from the Measurements-tab overflow menu.
///
/// The shape that keeps a mixed fleet readable:
/// - **Vendor chips** across the top, in the user's own order ([kDeviceVendors]
///   by default). A vendor with no devices has no chip and no section; with a
///   single vendor the selector disappears entirely, since a one-choice
///   selector is noise.
/// - **Full cards**, not summaries: each vendor's section renders exactly the
///   cards its own dashboard did. In All they sit under vendor headers, in the
///   vendor's own order; filtering changes nothing about a card's neighbours.
/// - **Refresh all / Save all act on the current selection only**, and the
///   scope line above them says what that is. Save all is *hidden* — not
///   disabled — when the selection holds no meter-capable device, because for
///   a Red Sea filter there is nothing to save and never will be.
/// - Live snapshots live **here**, not in the sections, so switching the filter
///   never throws away values the user just refreshed.
///
/// Pro gating (`ProFeature.connectedDevices`): the page itself is **ungated** —
/// the inventory it replaced was a Standard feature, and a keeper must always
/// be able to see what they have connected. Reading, saving and adding are
/// gated; a non-entitled install gets a banner where the action buttons sit.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  /// Live state per vendor, keyed by device identifier. Held at page level so
  /// it survives filter switches.
  final Map<String, RfLive> _rfLive = {};
  final Map<String, RbLive> _rbLive = {};
  final Map<String, ApLive> _apLive = {};

  /// Identifiers already auto-read this session. The on-open read covers the
  /// current selection only; switching to a vendor not yet read pulls it then,
  /// and switching back doesn't re-read — that is what Refresh is for.
  final Set<String> _autoRead = {};

  /// The selected vendor kind, or null for All. Null until the stored
  /// preference has been applied once (see [_restoreSelection]).
  String? _vendor;
  bool _selectionRestored = false;

  /// Applies the persisted filter once the setting has loaded, dropping it if
  /// that vendor no longer has any devices (its last one was removed).
  void _restoreSelection(List<String> present) {
    if (_selectionRestored) return;
    final stored = ref.read(deviceVendorFilterProvider).value;
    if (stored == null) return; // Setting not loaded yet — try next build.
    _selectionRestored = true;
    if (stored.isNotEmpty && present.contains(stored)) _vendor = stored;
  }

  void _select(String? vendor) {
    setState(() => _vendor = vendor);
    unawaited(ref.read(settingsProvider).setDeviceVendorFilter(vendor));
  }

  // --- reading -----------------------------------------------------------

  Future<void> _refreshRf(DeviceRecord d) async {
    setState(() => _rfLive[d.identifier] = const RfLive(loading: true));
    final result = await rfReadDevice(ref, d);
    if (!mounted) return;
    setState(() => _rfLive[d.identifier] = result);
  }

  Future<void> _refreshRb(DeviceRecord d) async {
    setState(() => _rbLive[d.identifier] = const RbLive(loading: true));
    final result = await rbReadDevice(ref, d);
    if (!mounted) return;
    setState(() => _rbLive[d.identifier] = result);
  }

  Future<void> _refreshAp(DeviceRecord d) async {
    setState(() => _apLive[d.identifier] = const ApLive(loading: true));
    final result = await apReadDevice(ref, d);
    if (!mounted) return;
    setState(() => _apLive[d.identifier] = result);
  }

  /// Reads one device of [kind] — the per-vendor read behind every bulk
  /// action, so callers can work from a `(kind, device)` pair rather than
  /// knowing which map holds which vendor.
  Future<void> _refreshDevice(String kind, DeviceRecord d) => switch (kind) {
    kDeviceKindReefFactory => _refreshRf(d),
    kDeviceKindReefBeat => _refreshRb(d),
    _ => _refreshAp(d),
  };

  /// Reads everything in [scope]. Sequential **within** a vendor — a meter is
  /// also serving the vendor's own cloud app, and one socket at a time is
  /// gentle on it — but the vendors run concurrently, so a slow controller
  /// doesn't hold up the meters.
  Future<void> _refreshScope(_Scope scope) async {
    Future<void> series(String kind) async {
      for (final d in scope.of(kind)) {
        await _refreshDevice(kind, d);
      }
    }

    await Future.wait([for (final kind in scope.order) series(kind)]);
  }

  // --- saving ------------------------------------------------------------

  Future<void> _persistValues(
    Tank tank,
    List<({String paramKey, double value})> values,
  ) async {
    final db = ref.read(dbProvider);
    final type = SetupType.fromName(tank.setupType);
    for (final key in {for (final v in values) v.paramKey}) {
      await db.addTrackedParameter(tank.id, key, type);
    }
    await db.insertReadingGroup(
      tankId: tank.id,
      takenAt: DateTime.now(),
      values: values,
    );
  }

  Tank? _tankFor(int? id, List<Tank> tanks) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Saves one card's values — the per-card Save button.
  Future<void> _saveOne(
    DeviceRecord device,
    List<({String paramKey, double value})> values,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tank = _tankFor(device.tankId, tanks);
    if (tank == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.reefFactoryNoTank)));
      return;
    }
    if (values.isEmpty) return;
    try {
      await _persistValues(tank, values);
      messenger.showSnackBar(
        SnackBar(content: Text(l.reefFactorySavedSnack(values.length))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed(e.toString()))),
      );
    }
  }

  /// The values a save would persist for [d] right now: what its last read
  /// produced, run through that vendor's own save filter. Empty when the device
  /// hasn't been read yet, holds nothing savable, or is of a kind that never
  /// reports measurements.
  ///
  /// The one place a vendor's live map is turned into savable values — Save
  /// all, the savable count and the Save-all button's own visibility all ask
  /// here, so a vendor can't be honoured by one and forgotten by another.
  List<({String paramKey, double value})> _pendingValues(
    String kind,
    DeviceRecord d,
    _Scope scope,
  ) {
    switch (kind) {
      case kDeviceKindReefFactory:
        final snap = _rfLive[d.identifier]?.snapshot;
        if (snap == null) return const [];
        return rfValuesToSave(d, snap, scope.of(kind));
      case kDeviceKindApex:
        final status = _apLive[d.identifier]?.status;
        if (status == null) return const [];
        return apReadingsToSave(status.readings);
      default:
        // Every meter-capable kind must have a branch above, or Save all would
        // count its devices (via [deviceKindSaves]) and then save nothing.
        assert(
          !deviceKindSaves(kind),
          'meter-capable vendor "$kind" has no save mapping',
        );
        return const [];
    }
  }

  /// Saves every meter in [scope] at once, merging everything bound for one
  /// tank into a single reading group — so a meter's salinity and a
  /// controller's temperature, read a minute apart, land as one measurement
  /// instead of two.
  ///
  /// **First displayed wins.** When two devices report the same parameter for
  /// the same tank, the one higher on the page keeps it: vendor order first
  /// (the "Reorder brands" sheet), then the user's drag order within that
  /// vendor. Reordering a card *is* the preference UI. The winner is named in
  /// the confirmation rather than chosen silently — a wrong probe quietly
  /// becoming your history is exactly what this rule must not do.
  Future<void> _saveAll(_Scope scope) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];

    final byTank = <int, Map<String, ({String paramKey, double value})>>{};
    final tankById = <int, Tank>{};
    // paramKey → the display name of the device whose value won it.
    final winner = <String, String>{};
    final contested = <String>{};
    var skippedNoTank = false;

    void offer(DeviceRecord d, List<({String paramKey, double value})> values) {
      final tank = _tankFor(d.tankId, tanks);
      if (tank == null) {
        if (values.isNotEmpty) skippedNoTank = true;
        return;
      }
      final bucket = byTank.putIfAbsent(tank.id, () => {});
      tankById[tank.id] = tank;
      for (final v in values) {
        final existing = bucket[v.paramKey];
        if (existing == null) {
          bucket[v.paramKey] = v;
          winner[v.paramKey] = deviceDisplayName(d);
        } else if (existing.value != v.value) {
          // A real disagreement, not two devices echoing the same figure.
          contested.add(v.paramKey);
        }
      }
    }

    // Page order, from the same list the page renders: vendors in the user's
    // brand order, devices as they sit in each section. Iterating the vendors
    // by hand here is exactly how the promise above used to be broken.
    for (final (kind, d) in scope.inPageOrder) {
      final values = _pendingValues(kind, d, scope);
      if (values.isNotEmpty) offer(d, values);
    }

    if (byTank.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            skippedNoTank ? l.reefFactoryNoTank : l.reefFactoryNothingToSave,
          ),
        ),
      );
      return;
    }
    try {
      var total = 0;
      for (final entry in byTank.entries) {
        final values = entry.value.values.toList();
        await _persistValues(tankById[entry.key]!, values);
        total += values.length;
      }
      final notes = [
        for (final key in contested.take(2))
          l.devicesSourceNote(l.paramName(key), winner[key] ?? ''),
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            [l.reefFactorySavedSnack(total), ...notes].join('  ·  '),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed(e.toString()))),
      );
    }
  }

  // --- build -------------------------------------------------------------

  /// The active tank's devices plus unassigned ones (assignment lives in the
  /// card menu, so hiding them would make them unreachable), in the user's
  /// manual card order with the display name as the tie-break.
  List<DeviceRecord> _scoped(List<DeviceRecord> all, int? activeTankId) {
    return [
      for (final d in all)
        if (d.tankId == null || d.tankId == activeTankId) d,
    ]..sort((a, b) {
      final byOrder = a.displayOrder.compareTo(b.displayOrder);
      if (byOrder != 0) return byOrder;
      return deviceDisplayName(
        a,
      ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final activeTank = ref.watch(activeTankProvider);
    final tankId = activeTank?.id;
    final entitled = ref.watch(proFeatureProvider(ProFeature.connectedDevices));
    final order = ref.watch(deviceVendorOrderProvider).value ?? kDeviceVendors;

    final rf = _scoped(
      ref.watch(reefFactoryDevicesProvider).value ?? const [],
      tankId,
    );
    final rb = _scoped(
      ref.watch(reefBeatDevicesProvider).value ?? const [],
      tankId,
    );
    final ap = _scoped(
      ref.watch(apexDevicesProvider).value ?? const [],
      tankId,
    );
    final byVendor = {
      kDeviceKindReefFactory: rf,
      kDeviceKindReefBeat: rb,
      kDeviceKindApex: ap,
    };

    // A vendor earns a chip only by having a device in view.
    final present = [
      for (final v in order)
        if ((byVendor[v] ?? const []).isNotEmpty) v,
    ];
    _restoreSelection(present);
    final selected = present.contains(_vendor) ? _vendor : null;
    final inScope = selected == null ? present : [selected];
    final scope = _Scope(
      order: inScope,
      byVendor: {for (final v in inScope) v: byVendor[v] ?? const []},
    );

    // The on-open read, scoped to the selection and once per device.
    if (entitled) {
      final toRead = _Scope(
        order: scope.order,
        byVendor: {
          for (final kind in scope.order)
            kind: [
              for (final d in scope.of(kind))
                if (!_autoRead.contains(d.identifier)) d,
            ],
        },
      );
      if (toRead.length > 0) {
        for (final (_, d) in toRead.inPageOrder) {
          _autoRead.add(d.identifier);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refreshScope(toRead));
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.devicesTitle),
        actions: [
          // Vendor order is only meaningful with more than one vendor on the
          // page — and it is what decides save precedence, so it lives beside
          // the list it orders rather than in Settings.
          if (present.length > 1)
            PopupMenuButton<String>(
              onSelected: (_) => unawaited(_showReorderSheet(order, byVendor)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'reorder',
                  child: Text(l.devicesReorderBrands),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: present.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => unawaited(_addDevice(entitled, selected)),
              icon: const Icon(Icons.add),
              label: Text(l.devicesAddDevice),
            ),
      body: present.isEmpty
          ? _EmptyState(onAdd: () => unawaited(_addDevice(entitled, null)))
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DisclaimerBanner(text: _disclaimerFor(l, selected)),
                  ),
                ),
                // Scrolls with the content rather than pinning: the app paints
                // a gradient behind the scaffold, so a pinned bar would need an
                // opaque strip of a colour that doesn't exist here — and the
                // list is short enough that the chips are never far away.
                if (present.length > 1)
                  SliverToBoxAdapter(
                    child: _VendorBar(
                      vendors: present,
                      selected: selected,
                      countOf: (v) => (byVendor[v] ?? const []).length,
                      onSelected: _select,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: entitled
                        ? _ScopeBar(
                            label: selected == null
                                ? l.devicesScopeAll(scope.length)
                                : l.devicesScopeVendor(
                                    l.deviceVendorName(selected),
                                    scope.length,
                                  ),
                            busy: _busy(scope),
                            total: scope.length,
                            savable: _savableCount(scope),
                            meters: scope.meters,
                            onRefresh: () => unawaited(_refreshScope(scope)),
                            onSaveAll: () => unawaited(_saveAll(scope)),
                          )
                        : _ProNotice(
                            onTap: () => unawaited(
                              showProFeatureDialog(
                                context,
                                ProFeature.connectedDevices,
                              ),
                            ),
                          ),
                  ),
                ),
                for (final vendor in inScope) ...[
                  // Headers separate the vendors in All; with one vendor in
                  // view its chip already names it.
                  if (selected == null && present.length > 1)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          l.deviceVendorName(vendor).toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: _sectionFor(vendor, byVendor),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }

  Widget _sectionFor(String vendor, Map<String, List<DeviceRecord>> byVendor) =>
      switch (vendor) {
        kDeviceKindReefFactory => RfDeviceSection(
          devices: byVendor[vendor]!,
          live: _rfLive,
          onSave: (d, snap) => unawaited(
            _saveOne(d, rfValuesToSave(d, snap, byVendor[vendor]!)),
          ),
          onRemoved: (id) => setState(() {
            _rfLive.remove(id);
            _autoRead.remove(id);
          }),
        ),
        kDeviceKindReefBeat => RbDeviceSection(
          devices: byVendor[vendor]!,
          live: _rbLive,
          onRemoved: (id) => setState(() {
            _rbLive.remove(id);
            _autoRead.remove(id);
          }),
        ),
        _ => ApDeviceSection(
          devices: byVendor[vendor]!,
          live: _apLive,
          onSave: (d, status) =>
              unawaited(_saveOne(d, apReadingsToSave(status.readings))),
          onRemoved: (id) => setState(() {
            _apLive.remove(id);
            _autoRead.remove(id);
          }),
          onRefreshRequested: (d) => unawaited(_refreshAp(d)),
        ),
      };

  /// The read-only notice. Generic in All; in a vendor view it swaps to that
  /// vendor's own text, which can name the app to use instead (ReefBeat,
  /// the ReefFactory app, Fusion).
  String _disclaimerFor(AppLocalizations l, String? vendor) => switch (vendor) {
    kDeviceKindReefFactory => l.reefFactoryDisclaimer,
    kDeviceKindReefBeat => l.reefBeatDisclaimer,
    kDeviceKindApex => l.apexDisclaimer,
    _ => l.devicesDisclaimer,
  };

  bool _busy(_Scope scope) => scope.inPageOrder.any(
    (e) => switch (e.$1) {
      kDeviceKindReefFactory => _rfLive[e.$2.identifier]?.loading ?? false,
      kDeviceKindReefBeat => _rbLive[e.$2.identifier]?.loading ?? false,
      _ => _apLive[e.$2.identifier]?.loading ?? false,
    },
  );

  /// How many devices in scope currently hold values a save would persist.
  int _savableCount(_Scope scope) {
    var n = 0;
    for (final (kind, d) in scope.inPageOrder) {
      if (_pendingValues(kind, d, scope).isNotEmpty) n++;
    }
    return n;
  }

  // --- actions -----------------------------------------------------------

  /// Adding is a Pro action like reading: a device you can register but never
  /// read would be a dead card.
  Future<void> _addDevice(bool entitled, String? vendor) async {
    if (!entitled) {
      await showProFeatureDialog(context, ProFeature.connectedDevices);
      return;
    }
    // In a vendor view the brand is already chosen; in All, ask.
    final kind = vendor ?? await _pickVendor();
    if (kind == null || !mounted) return;
    switch (kind) {
      case kDeviceKindReefFactory:
        await showRfAddFlow(
          context,
          ref,
          onSeed: (id, snap) {
            if (mounted) {
              setState(() => _rfLive[id] = RfLive(snapshot: snap));
            }
          },
        );
      case kDeviceKindReefBeat:
        await showRbAddFlow(
          context,
          ref,
          onSeed: (id, snap) {
            if (mounted) {
              setState(() => _rbLive[id] = RbLive(snapshot: snap));
            }
          },
          // Anything added or repointed by the discovery half has no live
          // status yet; the next build's auto-read picks it up.
          onAdded: () {},
        );
      default:
        await showApAddFlow(
          context,
          ref,
          onSeed: (id, status) {
            if (mounted) {
              setState(() => _apLive[id] = ApLive(status: status));
            }
          },
        );
    }
  }

  Future<String?> _pickVendor() {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l.devicesAddPickBrand,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final v in kDeviceVendors)
              ListTile(
                leading: Icon(deviceVendorIcon(v)),
                title: Text(l.deviceVendorName(v)),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReorderSheet(
    List<String> order,
    Map<String, List<DeviceRecord>> byVendor,
  ) async {
    final l = AppLocalizations.of(context);
    final working = [...order];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l.devicesReorderBrands,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              // Sized by its rows rather than by a per-row guess, so a larger
              // font setting can't clip the last brand's device count.
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: working.length,
                  // onReorderItem already accounts for the removed item, so
                  // the classic newIndex fix-up must not be applied here.
                  onReorderItem: (oldIndex, newIndex) {
                    setSheetState(
                      () =>
                          working.insert(newIndex, working.removeAt(oldIndex)),
                    );
                    unawaited(
                      ref.read(settingsProvider).setDeviceVendorOrder(working),
                    );
                  },
                  itemBuilder: (ctx, i) {
                    final v = working[i];
                    final count = (byVendor[v] ?? const []).length;
                    return ListTile(
                      key: ValueKey(v),
                      leading: Icon(deviceVendorIcon(v)),
                      title: Text(l.deviceVendorName(v)),
                      subtitle: Text(l.devicesCount(count)),
                      // A real drag handle, like the device cards' — not a
                      // decorative glyph next to a long-press-only row.
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Naming the rule where it is being set: the order is not
              // cosmetic, it decides which device's reading survives a
              // Save all.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  l.devicesReorderBrandsHint,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The devices in view — what Refresh all and Save all act on — **in the order
/// the page renders them**: vendors in the user's brand order, devices in their
/// own card order within each vendor.
///
/// The order is the point, not a convenience: Save all resolves a parameter two
/// devices both report by "first displayed wins", so anything that walks this
/// scope must walk [inPageOrder] rather than picking vendors out by hand.
class _Scope {
  const _Scope({required this.order, required this.byVendor});

  /// The vendor kinds in view, in the user's own order.
  final List<String> order;

  /// Each vendor's devices, already scoped to the active tank and sorted by
  /// the page.
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
  /// Asks [deviceKindSaves] instead of naming vendors, so a future meter vendor
  /// is counted without an edit here.
  int get meters =>
      order.where(deviceKindSaves).fold(0, (n, kind) => n + of(kind).length);
}

/// The vendor selector: one chip per vendor that has a device, in the user's
/// order, preceded by All.
class _VendorBar extends StatelessWidget {
  const _VendorBar({
    required this.vendors,
    required this.selected,
    required this.countOf,
    required this.onSelected,
  });

  final List<String> vendors;
  final String? selected;
  final int Function(String) countOf;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l.devicesAll),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final v in vendors) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('${l.deviceVendorName(v)}  ${countOf(v)}'),
              selected: selected == v,
              onSelected: (_) => onSelected(v),
            ),
          ],
        ],
      ),
    );
  }
}

/// The scope line plus the two bulk actions it describes.
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.label,
    required this.busy,
    required this.total,
    required this.savable,
    required this.meters,
    required this.onRefresh,
    required this.onSaveAll,
  });

  final String label;
  final bool busy;

  /// Devices the refresh would read — the button carries the number so "all"
  /// never has to be guessed at.
  final int total;

  /// Devices in scope holding values right now (Save all's count).
  final int savable;

  /// Meter-capable devices in scope — zero means Save all is meaningless here
  /// and is hidden rather than disabled.
  final int meters;
  final VoidCallback onRefresh;
  final VoidCallback onSaveAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.devicesRefreshAll(total)),
              ),
            ),
            if (meters > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: savable > 0 ? onSaveAll : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(l.devicesSaveAll(savable)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// What sits where the action buttons would be on a non-entitled install: the
/// list stays readable, reading and saving do not.
class _ProNotice extends StatelessWidget {
  const _ProNotice({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 20, color: cs.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.devicesProLocked,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The persistent read-only notice. Uses the theme's tertiary container so it
/// reads as informational, not an error.
class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: cs.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// No devices at all: one clear message and the button that fixes it. No chips,
/// no scope bar, no disclaimer — there is nothing yet to be read-only about.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_input_antenna,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l.devicesEmptyTitle,
              style: t.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l.devicesEmptyBody,
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.devicesAddDevice),
            ),
          ],
        ),
      ),
    );
  }
}

/// The icon standing for a vendor in the picker and the reorder sheet — the
/// same glyphs the old per-vendor Settings rows used.
IconData deviceVendorIcon(String kind) => switch (kind) {
  kDeviceKindReefFactory => Icons.sensors,
  kDeviceKindReefBeat => Icons.water_drop_outlined,
  _ => Icons.hub_outlined,
};
