import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/device_vendors.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/implausible_value_dialog.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../apex/apex_screen.dart';
import '../reefbeat/reefbeat_screen.dart';
import '../reeffactory/reeffactory_screen.dart';
import 'hanna_device_section.dart';

/// Standalone Devices route (`/devices`). With tanks present, Devices is the
/// home shell's fourth bottom-nav tab (U42) and nothing pushes this route; it
/// remains as a stable deep-link target and for hosts without the bottom bar,
/// mirroring `SettingsScreen` and `/settings`.
///
/// Stateful only to own [_bodyKey]: a key minted in `build` would be a new key
/// on every rebuild, and the body's live snapshots would go with the old one.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, this.staleAfter = kDeviceSnapshotStaleAfter});

  /// See [DevicesBody.staleAfter].
  final Duration staleAfter;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  /// The body owns its own state, so the app bar's add action and the FABs
  /// reach it through a key rather than duplicating the flows — the same
  /// arrangement the home shell uses.
  final GlobalKey<DevicesBodyState> _bodyKey = GlobalKey();

  /// What the body last published for the FABs — see [DevicesBody.fabStatus].
  final ValueNotifier<DevicesFabStatus> _fabStatus = ValueNotifier(
    const DevicesFabStatus(),
  );

  @override
  void dispose() {
    _fabStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.devicesTitle),
        actions: [
          // Adding moved up here so the FAB slots could take the bulk actions
          // — an icon is enough for the rarer of the two jobs.
          IconButton(
            tooltip: l.devicesAddDevice,
            icon: const Icon(Icons.add),
            onPressed: () {
              final body = _bodyKey.currentState;
              if (body != null) unawaited(body.addDevice());
            },
          ),
        ],
      ),
      floatingActionButton: DevicesActionFabs(
        status: _fabStatus,
        onRefreshAll: () {
          final body = _bodyKey.currentState;
          if (body != null) unawaited(body.refreshAll());
        },
        onSaveAll: () {
          final body = _bodyKey.currentState;
          if (body != null) unawaited(body.saveAll());
        },
      ),
      body: DevicesBody(
        key: _bodyKey,
        staleAfter: widget.staleAfter,
        fabStatus: _fabStatus,
      ),
    );
  }
}

/// What the host needs to render the bulk-action FABs: the counts and flags
/// the in-page action bar used before the buttons moved to the FAB slot. The
/// body publishes it after each build ([DevicesBody.fabStatus]); value
/// equality keeps an unchanged build from notifying anyone.
class DevicesFabStatus {
  const DevicesFabStatus({
    this.entitled = false,
    this.refreshable = 0,
    this.busy = false,
    this.meters = 0,
    this.savable = 0,
    this.saving = false,
  });

  /// Reading and saving are Pro ([ProFeature.connectedDevices]); the body
  /// shows its lock notice instead, so the FABs hide entirely.
  final bool entitled;

  /// Devices in scope a Refresh all would actually read — LAN kinds only
  /// ([deviceKindRefreshes]), so a Hanna checker never inflates the count.
  final int refreshable;

  /// A read is in flight somewhere in scope — Refresh all disables and shows
  /// a spinner for its duration.
  final bool busy;

  /// Meter-capable devices in scope — zero means Save all is meaningless here
  /// and is hidden rather than disabled, exactly as the action bar did.
  final int meters;

  /// Devices in scope holding values right now (Save all's count).
  final int savable;

  /// A save is already in flight — Save all disables for its duration (#86).
  final bool saving;

  @override
  bool operator ==(Object other) =>
      other is DevicesFabStatus &&
      other.entitled == entitled &&
      other.refreshable == refreshable &&
      other.busy == busy &&
      other.meters == meters &&
      other.savable == savable &&
      other.saving == saving;

  @override
  int get hashCode =>
      Object.hash(entitled, refreshable, busy, meters, savable, saving);
}

/// The Devices tab's floating actions: Refresh all above Save all, fed by the
/// body's published [DevicesFabStatus]. Shared by the standalone
/// [DevicesScreen] and the home shell's Devices tab, which passes [scale] so
/// the buttons play its FAB entrance animation.
class DevicesActionFabs extends StatelessWidget {
  const DevicesActionFabs({
    super.key,
    required this.status,
    required this.onRefreshAll,
    required this.onSaveAll,
    this.scale,
  });

  final ValueListenable<DevicesFabStatus> status;
  final VoidCallback onRefreshAll;
  final VoidCallback onSaveAll;
  final Animation<double>? scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<DevicesFabStatus>(
      valueListenable: status,
      builder: (context, s, _) {
        // Non-entitled installs act through the body's lock notice; an empty
        // (or Hanna-only) scope has nothing to refresh or save.
        if (!s.entitled || (s.refreshable == 0 && s.meters == 0)) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        final saveDisabled = s.savable == 0 || s.saving;
        Widget wrap(Widget child) => scale == null
            ? child
            : ScaleTransition(scale: scale!, child: child);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (s.refreshable > 0)
              wrap(
                FloatingActionButton.extended(
                  heroTag: 'devices-refresh-fab',
                  // FABs carry no disabled look of their own, so the busy
                  // state dims the colors by hand and swaps in a spinner.
                  backgroundColor: s.busy ? cs.surfaceContainerHighest : null,
                  foregroundColor: s.busy
                      ? cs.onSurface.withValues(alpha: 0.38)
                      : null,
                  onPressed: s.busy ? null : onRefreshAll,
                  icon: s.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l.devicesRefreshAll(s.refreshable)),
                ),
              ),
            if (s.refreshable > 0 && s.meters > 0) const SizedBox(height: 12),
            if (s.meters > 0)
              wrap(
                FloatingActionButton.extended(
                  heroTag: 'devices-save-fab',
                  backgroundColor: saveDisabled
                      ? cs.surfaceContainerHighest
                      : null,
                  foregroundColor: saveDisabled
                      ? cs.onSurface.withValues(alpha: 0.38)
                      : null,
                  onPressed: saveDisabled ? null : onSaveAll,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l.devicesSaveAll(s.savable)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The unified Devices body (U41): every LAN device the keeper has connected,
/// on one page, behind a vendor selector.
///
/// It replaced the three per-vendor dashboards (`/reeffactory`, `/reefbeat`,
/// `/apex`) *and* the read-only Settings inventory (`/settings/devices`) — four
/// routes collapsed into one. Scaffold-less, so the same body serves both the
/// home shell's Devices tab (U42) and the standalone [DevicesScreen]; the host
/// owns the app bar (whose add action calls [addDevice] on this state — the
/// add flows seed the live maps held here, which a top-level function could
/// not reach) and the Refresh all / Save all FABs, wired through [fabStatus],
/// [refreshAll] and [saveAll].
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
///   scope line above the list says what that is. Save all is *hidden* — not
///   disabled — when the selection holds no meter-capable device, because for
///   a Red Sea filter there is nothing to save and never will be.
/// - Live snapshots live **here**, not in the sections, so switching the filter
///   never throws away values the user just refreshed.
///
/// Pro gating (`ProFeature.connectedDevices`): the page itself is **ungated** —
/// the inventory it replaced was a Standard feature, and a keeper must always
/// be able to see what they have connected. Reading, saving and adding are
/// gated; a non-entitled install gets a banner where the action buttons sit.
class DevicesBody extends ConsumerStatefulWidget {
  const DevicesBody({
    super.key,
    this.staleAfter = kDeviceSnapshotStaleAfter,
    this.active = true,
    this.fabStatus,
  });

  /// How old a held snapshot may be before a save re-reads it (see
  /// [kDeviceSnapshotStaleAfter]). A parameter only so that a test can set it
  /// to zero and exercise the re-read without waiting out the real window.
  final Duration staleAfter;

  /// Whether this body is the tab the user is actually looking at. The home
  /// shell keeps every tab built inside an `IndexedStack`, so without this the
  /// on-open read would hit the LAN on every app launch — for a page nobody
  /// opened. False suppresses the automatic read only; everything the user
  /// asks for explicitly still works.
  final bool active;

  /// Where each build publishes what the host's FABs need ([DevicesFabStatus])
  /// — the host can't watch this state directly, and the FABs live in its
  /// Scaffold, not in this body. Published post-frame, value-compared, so a
  /// build that changed nothing notifies no one.
  final ValueNotifier<DevicesFabStatus>? fabStatus;

  @override
  DevicesBodyState createState() => DevicesBodyState();
}

/// A held snapshot older than this is re-read before its values are saved
/// (#76). Two minutes is long enough that an ordinary "read, glance, save"
/// never pays for a second round trip, and short enough that nothing stale
/// gets stamped into the history as a current measurement.
const Duration kDeviceSnapshotStaleAfter = Duration(minutes: 2);

/// What counts as a vendor-stepping swipe: a flick thrown at this speed
/// (logical px/s), or — for a drag too slow to register a velocity — one that
/// travelled [_kVendorSwipeFraction] of the page width. Two thresholds because
/// a flick and a deliberate shove are both plainly a swipe, and neither should
/// have to be repeated because it was the wrong *kind* of swipe.
const double _kVendorSwipeVelocity = 300;
const double _kVendorSwipeFraction = 0.2;

/// How long the page takes to scroll back to the top after a swipe changed the
/// vendor — see [DevicesBodyState._stepVendor], where that scroll is the
/// feedback rather than housekeeping.
const Duration _kVendorSwipeScrollBack = Duration(milliseconds: 250);

class DevicesBodyState extends ConsumerState<DevicesBody> {
  /// Live state per vendor, keyed by device identifier. Held at page level so
  /// it survives filter switches.
  final Map<String, RfLive> _rfLive = {};
  final Map<String, RbLive> _rbLive = {};
  final Map<String, ApLive> _apLive = {};

  /// Identifiers already auto-read this session. The on-open read covers the
  /// current selection only; switching to a vendor not yet read pulls it then,
  /// and switching back doesn't re-read — that is what Refresh is for.
  final Set<String> _autoRead = {};

  /// When each device's held snapshot was actually read. It dates the reading
  /// group a save writes, and decides what [_freshen] re-reads first (#76) —
  /// the page keeps a snapshot for as long as it is on screen, so "now" is not
  /// a safe stand-in for either.
  final Map<String, DateTime> _readAt = {};

  /// The selected vendor kind, or null for All. Null until the stored
  /// preference has been applied once (see [_restoreSelection]).
  String? _vendor;
  bool _selectionRestored = false;

  /// A save is in flight (the #3/#86 re-entrancy class): [_save] awaits a
  /// possible [_freshen] round of LAN traffic before its DB writes, and
  /// `insertReadingGroup` is a blind insert — a second tap during that window
  /// would write a full duplicate group. One flag guards every save surface
  /// (Save all and both vendors' per-card buttons all funnel through [_save]).
  bool _saving = false;

  /// The vendors that had a chip on the last build. Kept so [addDevice] — which
  /// the host's app bar calls between builds — can resolve the effective
  /// selection exactly as the page renders it, without re-deriving it from the
  /// providers.
  List<String> _present = const [];

  /// The scope the last build rendered — what the host's Refresh all / Save
  /// all FABs act on between builds, same reasoning as [_present].
  _Scope _scope = const _Scope(order: [], byVendor: {});

  /// Drives the scroll back to the top after a swipe changes the vendor
  /// ([_stepVendor]). Owned rather than taken from the ambient
  /// `PrimaryScrollController` — nothing in the app installs one, and
  /// `HistoryScreen` keeps its list's controller the same way.
  final ScrollController _scrollCtrl = ScrollController();

  /// How far the horizontal drag in progress has travelled, for the distance
  /// half of the swipe threshold. Deliberately not build state: nothing on
  /// screen follows the finger, so there is nothing to rebuild until the
  /// gesture ends.
  double _dragDx = 0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Applies the persisted filter once the setting *and* the device lists have
  /// loaded, dropping it if that vendor no longer has any devices (its last
  /// one was removed). Judging the stored vendor against still-loading lists
  /// would drop a valid selection on every cold start — the settings map
  /// usually wins the race against the four device streams — so the latch
  /// waits for both sides.
  void _restoreSelection(
    List<String> present, {
    required bool devicesLoaded,
    required String? stored,
  }) {
    if (_selectionRestored) return;
    if (stored == null || !devicesLoaded) return; // Not loaded — next build.
    _selectionRestored = true;
    if (stored.isNotEmpty && present.contains(stored)) _vendor = stored;
  }

  void _select(String? vendor) {
    setState(() => _vendor = vendor);
    unawaited(ref.read(settingsProvider).setDeviceVendorFilter(vendor));
  }

  /// Moves the selection one chip along the vendor bar — [delta] of 1 for the
  /// chip to the right, -1 for the one to the left — which is what a horizontal
  /// swipe does. `All` is a stop like any other, at the left end. Running off
  /// either end does nothing at all: with three or four stops, wrapping around
  /// is more disorienting than a dead end.
  ///
  /// The page then scrolls back to the top, and that is the *feedback*, not
  /// housekeeping. A chip tap can only happen near the top of the page, since
  /// the bar has to be on screen to be tapped; a swipe works from anywhere. Deep
  /// in a list, holding the offset would drop the keeper in front of an
  /// arbitrary card of a different vendor — an offset means nothing in content
  /// it wasn't measured against — with the bar still off screen and nothing
  /// naming where they landed. Scrolling up answers that: the page visibly
  /// moves, and the newly selected chip is there when it stops.
  ///
  /// Post-frame, so the new (possibly much shorter) content has settled its own
  /// extent first: a scroll correction during layout replaces the activity of an
  /// animation already in flight, which would strand the page mid-way.
  void _stepVendor(int delta) {
    final stops = <String?>[null, ..._present];
    // Same fallback as the build's `selected`: a stored vendor with no chip
    // left is All, so a swipe from it goes somewhere sensible.
    final from = _present.contains(_vendor) ? stops.indexOf(_vendor) : 0;
    final to = from + delta;
    if (to < 0 || to >= stops.length) return;
    _select(stops[to]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || _scrollCtrl.offset <= 0) {
        return;
      }
      unawaited(
        _scrollCtrl.animateTo(
          0,
          duration: _kVendorSwipeScrollBack,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  /// Decides what a finished horizontal drag meant: a flick past
  /// [_kVendorSwipeVelocity], or a slower drag across [_kVendorSwipeFraction]
  /// of [width]. Dragging left selects the chip to the right, and vice versa.
  void _onSwipeEnd(DragEndDetails details, double width) {
    final velocity = details.primaryVelocity ?? 0;
    final far = _dragDx.abs() >= width * _kVendorSwipeFraction;
    if (velocity <= -_kVendorSwipeVelocity || (far && _dragDx < 0)) {
      _stepVendor(1);
    } else if (velocity >= _kVendorSwipeVelocity || (far && _dragDx > 0)) {
      _stepVendor(-1);
    }
  }

  // --- reading -----------------------------------------------------------

  Future<void> _refreshRf(DeviceRecord d) async {
    if (!mounted) return;
    setState(() => _rfLive[d.identifier] = const RfLive(loading: true));
    final result = await rfReadDevice(ref, d);
    if (!mounted) return;
    setState(() {
      _rfLive[d.identifier] = result;
      if (result.snapshot != null) _readAt[d.identifier] = DateTime.now();
    });
  }

  Future<void> _refreshRb(DeviceRecord d) async {
    if (!mounted) return;
    setState(() => _rbLive[d.identifier] = const RbLive(loading: true));
    final result = await rbReadDevice(ref, d);
    if (!mounted) return;
    setState(() {
      _rbLive[d.identifier] = result;
      if (result.snapshot != null) _readAt[d.identifier] = DateTime.now();
    });
  }

  Future<void> _refreshAp(DeviceRecord d) async {
    if (!mounted) return;
    setState(() => _apLive[d.identifier] = const ApLive(loading: true));
    final result = await apReadDevice(ref, d);
    if (!mounted) return;
    setState(() {
      _apLive[d.identifier] = result;
      if (result.status != null) _readAt[d.identifier] = DateTime.now();
    });
  }

  /// Reads one device of [kind] — the per-vendor read behind every bulk
  /// action, so callers can work from a `(kind, device)` pair rather than
  /// knowing which map holds which vendor.
  Future<void> _refreshDevice(String kind, DeviceRecord d) => switch (kind) {
    kDeviceKindReefFactory => _refreshRf(d),
    kDeviceKindReefBeat => _refreshRb(d),
    kDeviceKindApex => _refreshAp(d),
    // The Hanna checker is not a polled device (see [deviceKindRefreshes]).
    _ => Future.value(),
  };

  /// Reads everything refreshable in [scope]. Sequential **within** a vendor —
  /// a meter is also serving the vendor's own cloud app, and one socket at a
  /// time is gentle on it — but the vendors run concurrently, so a slow
  /// controller doesn't hold up the meters.
  Future<void> _refreshScope(_Scope scope) async {
    Future<void> series(String kind) async {
      for (final d in scope.of(kind)) {
        if (!mounted) return;
        await _refreshDevice(kind, d);
      }
    }

    await Future.wait([
      for (final kind in scope.order)
        if (deviceKindRefreshes(kind)) series(kind),
    ]);
  }

  // --- saving ------------------------------------------------------------

  Future<void> _persistValues(
    Tank tank,
    List<({String paramKey, double value})> values,
    DateTime takenAt,
  ) async {
    final db = ref.read(dbProvider);
    for (final key in {for (final v in values) v.paramKey}) {
      await db.addTrackedParameter(tank.id, key);
    }
    await db.insertReadingGroup(
      tankId: tank.id,
      takenAt: takenAt,
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

  /// Re-reads every device whose held snapshot has aged past
  /// [DevicesBody.staleAfter] before its values are written (#76). The page reads
  /// each device once when it opens and then holds that snapshot for as long
  /// as it is on screen; without this, a keeper who opens Devices, gets
  /// distracted and taps Save an hour later writes hour-old probe values into
  /// the history as a measurement taken now — which then feeds trend slopes,
  /// the stability window and the health freshness rule. The Hanna results
  /// step already does exactly this for its environment card.
  ///
  /// A failed re-read is not fatal: the card shows the error, the held
  /// snapshot stays behind it, and the save goes ahead with those values on
  /// their own (older) read time — the save must never block on the LAN.
  Future<void> _freshen(_Scope scope, DeviceRecord? only) async {
    final now = DateTime.now();
    final stale = <String, List<DeviceRecord>>{};
    for (final (kind, d) in scope.inPageOrder) {
      if (only != null && d.identifier != only.identifier) continue;
      if (_pendingValues(kind, d, scope).isEmpty) continue;
      final at = _readAt[d.identifier];
      if (at != null && now.difference(at) <= widget.staleAfter) continue;
      (stale[kind] ??= []).add(d);
    }
    if (stale.isEmpty) return;
    final heldRf = {
      for (final d in stale[kDeviceKindReefFactory] ?? const <DeviceRecord>[])
        d.identifier: _rfLive[d.identifier]?.snapshot,
    };
    final heldAp = {
      for (final d in stale[kDeviceKindApex] ?? const <DeviceRecord>[])
        d.identifier: _apLive[d.identifier]?.status,
    };
    // Through the ordinary read path, so the same one-socket-at-a-time
    // courtesy per vendor applies.
    await _refreshScope(_Scope(order: stale.keys.toList(), byVendor: stale));
    if (!mounted) return;
    setState(() {
      for (final e in heldRf.entries) {
        final snap = e.value;
        if (snap == null || _rfLive[e.key]?.snapshot != null) continue;
        _rfLive[e.key] = RfLive(snapshot: snap, error: _rfLive[e.key]?.error);
      }
      for (final e in heldAp.entries) {
        final status = e.value;
        if (status == null || _apLive[e.key]?.status != null) continue;
        _apLive[e.key] = ApLive(status: status, error: _apLive[e.key]?.error);
      }
    });
  }

  /// Saves one card's values — the per-card Save button. The device's own
  /// vendor list still rides along in [scope], because a ReefFactory meter's
  /// values depend on which *other* meters the tank has (the Temperature
  /// Controller rule).
  Future<void> _saveOne(DeviceRecord device, _Scope scope) =>
      _save(scope, only: device);

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

  /// Saves every meter in [scope] at once ([only] narrows it to one card),
  /// merging everything bound for one tank into a single reading group — so a
  /// meter's salinity and a controller's temperature, read a minute apart,
  /// land as one measurement instead of two.
  ///
  /// **First displayed wins.** When two devices report the same parameter for
  /// the same tank, the one higher on the page keeps it: vendor order first
  /// (the "Reorder brands" sheet), then the user's drag order within that
  /// vendor. Reordering a card *is* the preference UI. The winner is named in
  /// the confirmation rather than chosen silently — a wrong probe quietly
  /// becoming your history is exactly what this rule must not do.
  ///
  /// The same reasoning is why the values go through [_freshen] and the
  /// suspicious-value confirmation on the way: this is the one path device
  /// readings take into the database, and it now applies the guards manual
  /// entry has always had (#71, #76).
  Future<void> _save(_Scope scope, {DeviceRecord? only}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveGuarded(scope, only: only);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  Future<void> _saveGuarded(_Scope scope, {DeviceRecord? only}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _freshen(scope, only);
    if (!mounted) return;
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];

    final byTank = <int, Map<String, ({String paramKey, double value})>>{};
    final tankById = <int, Tank>{};
    // tankId → the oldest read time among the values in its group. Stamping
    // the group with it never claims a value is fresher than it is.
    final readAtByTank = <int, DateTime>{};
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
          final at = _readAt[d.identifier];
          final group = readAtByTank[tank.id];
          if (at != null && (group == null || at.isBefore(group))) {
            readAtByTank[tank.id] = at;
          }
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
      if (only != null && d.identifier != only.identifier) continue;
      final values = _pendingValues(kind, d, scope);
      if (values.isNotEmpty) offer(d, values);
    }

    // The #31 gate the device paths never had: values that are storable but
    // suspicious — outside the plausible range, or sitting on the probe's
    // "no signal" rail — are named to the keeper before they become history.
    // Only the winners are questioned; a value that lost the merge is never
    // written, so asking about it would be noise.
    final suspect = <(int, String), SuspectValue>{};
    for (final tankEntry in byTank.entries) {
      for (final v in tankEntry.value.values) {
        final reason = deviceSuspectReason(v.paramKey, v.value);
        if (reason == null) continue;
        suspect[(tankEntry.key, v.paramKey)] = SuspectValue(
          v.paramKey,
          v.value,
          reason: reason,
        );
      }
    }
    if (suspect.isNotEmpty) {
      final choice = await showImplausibleValuesDialog(
        context,
        values: suspect.values.toList(),
        prefs: ref.read(unitPrefsProvider),
        intro: l.implausibleIntroDevices,
        // Declining drops the suspicious values and keeps the rest: one bad
        // probe must not cost the keeper every other reading in a Save all.
        allowSkip: true,
      );
      if (choice == SuspectChoice.cancel || !mounted) return;
      if (choice == SuspectChoice.skip) {
        for (final (tankId, paramKey) in suspect.keys) {
          byTank[tankId]?.remove(paramKey);
        }
        byTank.removeWhere((_, values) => values.isEmpty);
      }
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
        await _persistValues(
          tankById[entry.key]!,
          values,
          readAtByTank[entry.key] ?? DateTime.now(),
        );
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

    final rfAsync = ref.watch(reefFactoryDevicesProvider);
    final rbAsync = ref.watch(reefBeatDevicesProvider);
    final apAsync = ref.watch(apexDevicesProvider);
    final haAsync = ref.watch(hannaDevicesProvider);
    final rf = _scoped(rfAsync.value ?? const [], tankId);
    final rb = _scoped(rbAsync.value ?? const [], tankId);
    final ap = _scoped(apAsync.value ?? const [], tankId);
    final ha = _scoped(haAsync.value ?? const [], tankId);
    final byVendor = {
      kDeviceKindReefFactory: rf,
      kDeviceKindReefBeat: rb,
      kDeviceKindApex: ap,
      kDeviceKindHanna: ha,
    };

    // A vendor earns a chip only by having a device in view.
    final present = [
      for (final v in order)
        if ((byVendor[v] ?? const []).isNotEmpty) v,
    ];
    _present = present;
    // Watched, not read: the setting's arrival must itself trigger a rebuild,
    // or a settings map that loads after the last device rebuild would leave
    // the stored selection unapplied until something else redraws the page.
    _restoreSelection(
      present,
      devicesLoaded:
          rfAsync.hasValue &&
          rbAsync.hasValue &&
          apAsync.hasValue &&
          haAsync.hasValue,
      stored: ref.watch(deviceVendorFilterProvider).value,
    );
    final selected = present.contains(_vendor) ? _vendor : null;
    final inScope = selected == null ? present : [selected];
    final scope = _Scope(
      order: inScope,
      byVendor: {for (final v in inScope) v: byVendor[v] ?? const []},
    );
    _scope = scope;
    _publishFabStatus(entitled, scope);

    // The on-open read, scoped to the selection and once per device. Only for
    // the tab actually on screen — see [DevicesBody.active]. Non-refreshable
    // kinds (the Hanna checker) are left out rather than marked read, so the
    // guards stay honest if one ever becomes refreshable.
    if (entitled && widget.active) {
      final toRead = _Scope(
        order: [
          for (final kind in scope.order)
            if (deviceKindRefreshes(kind)) kind,
        ],
        byVendor: {
          for (final kind in scope.order)
            if (deviceKindRefreshes(kind))
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

    if (present.isEmpty) return const _EmptyState();
    final list = CustomScrollView(
      controller: _scrollCtrl,
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
              // Vendor order is only meaningful with more than one
              // vendor on the page — and it is what decides save
              // precedence, so it sits on the bar it reorders rather
              // than in an app-bar menu the tab host doesn't own.
              onReorder: () => unawaited(_showReorderSheet(order, byVendor)),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          sliver: SliverToBoxAdapter(
            // The scope line names what the host's Refresh all / Save all
            // FABs act on — the buttons themselves moved to the FAB slot.
            child: entitled
                ? Text(
                    selected == null
                        ? l.devicesScopeAll(scope.length)
                        : l.devicesScopeVendor(
                            l.deviceVendorName(selected),
                            scope.length,
                          ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        // Room for the host's FAB, plus whatever the host reserves
        // below the list (the shell's translucent tab bar).
        SliverToBoxAdapter(
          child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
    // A horizontal swipe steps the vendor bar one chip along, so the selection
    // can be changed from anywhere on the page — the bar scrolls away with the
    // content, and reaching a chip otherwise means scrolling back up for it.
    // Only where there is a bar to step: a single vendor has no chips. Nothing
    // follows the finger; the step happens when it lifts. The bar's own
    // horizontal scroller wins the arena against this for gestures that start
    // on the chips, which is the right way round — that strip pans the chips.
    if (present.length < 2) return list;
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (d) => _onSwipeEnd(d, width),
      child: list,
    );
  }

  /// Publishes what the host's FABs need for the frame just built. Post-frame
  /// because the host may rebuild in response, and value-compared (via
  /// [DevicesFabStatus.==]) so a no-change build notifies no one — the
  /// post-frame callback itself must not schedule another frame forever.
  void _publishFabStatus(bool entitled, _Scope scope) {
    final notifier = widget.fabStatus;
    if (notifier == null) return;
    final status = DevicesFabStatus(
      entitled: entitled,
      refreshable: scope.refreshables,
      busy: _busy(scope),
      meters: scope.meters,
      savable: _savableCount(scope),
      saving: _saving,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = status;
    });
  }

  /// Reads every refreshable device in the current selection — the host's
  /// Refresh all FAB.
  Future<void> refreshAll() => _refreshScope(_scope);

  /// Saves every meter in the current selection — the host's Save all FAB.
  Future<void> saveAll() => _save(_scope);

  /// The scope a per-card Save runs in: that card's vendor, with the rest of
  /// its section still present, since a device's savable values can depend on
  /// its neighbours (the ReefFactory temperature-source rule).
  _Scope _vendorScope(
    String vendor,
    Map<String, List<DeviceRecord>> byVendor,
  ) =>
      _Scope(order: [vendor], byVendor: {vendor: byVendor[vendor] ?? const []});

  Widget _sectionFor(String vendor, Map<String, List<DeviceRecord>> byVendor) =>
      switch (vendor) {
        kDeviceKindReefFactory => RfDeviceSection(
          devices: byVendor[vendor]!,
          live: _rfLive,
          // The shown snapshot is deliberately ignored: the save funnel
          // re-reads a stale one and re-derives the values from the live map,
          // so both Save buttons write through exactly the same guards.
          onSave: _saving
              ? null
              : (d, _) =>
                    unawaited(_saveOne(d, _vendorScope(vendor, byVendor))),
          onRemoved: (id) => setState(() {
            _rfLive.remove(id);
            _autoRead.remove(id);
            _readAt.remove(id);
          }),
        ),
        kDeviceKindReefBeat => RbDeviceSection(
          devices: byVendor[vendor]!,
          live: _rbLive,
          onRemoved: (id) => setState(() {
            _rbLive.remove(id);
            _autoRead.remove(id);
            _readAt.remove(id);
          }),
        ),
        // No live map and no removal bookkeeping: the checker's card is
        // inventory plus a measure button, nothing here holds its state.
        kDeviceKindHanna => HannaDeviceSection(devices: byVendor[vendor]!),
        _ => ApDeviceSection(
          devices: byVendor[vendor]!,
          live: _apLive,
          onSave: _saving
              ? null
              : (d, _) =>
                    unawaited(_saveOne(d, _vendorScope(vendor, byVendor))),
          onRemoved: (id) => setState(() {
            _apLive.remove(id);
            _autoRead.remove(id);
            _readAt.remove(id);
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
    // Its own wording: the generic text promises Wi-Fi reads, and the checker
    // is a Bluetooth device read only during a measurement session.
    kDeviceKindHanna => l.devicesHannaDisclaimer,
    _ => l.devicesDisclaimer,
  };

  bool _busy(_Scope scope) => scope.inPageOrder.any(
    (e) => switch (e.$1) {
      kDeviceKindReefFactory => _rfLive[e.$2.identifier]?.loading ?? false,
      kDeviceKindReefBeat => _rbLive[e.$2.identifier]?.loading ?? false,
      kDeviceKindApex => _apLive[e.$2.identifier]?.loading ?? false,
      _ => false, // the Hanna checker has no in-page read to be busy with
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

  /// Runs the add-device flow for the current selection — the host's app-bar
  /// action calls this rather than a top-level function, because the flows
  /// seed this state's live maps with what the new device reported (see
  /// [DevicesBody]).
  Future<void> addDevice() => _addDevice(
    // In a vendor view the brand is already chosen. A stored selection whose
    // last device has since been removed has no chip either, so it must not
    // decide the brand here.
    _present.contains(_vendor) ? _vendor : null,
  );

  /// Adding is a Pro action like reading: a device you can register but never
  /// read would be a dead card. Gated per kind, after the brand is known —
  /// the Hanna checker carries its own gate (`hannaConnect`), separate from
  /// the LAN devices' `connectedDevices` (it is the keeper's own test kit,
  /// not tank hardware).
  Future<void> _addDevice(String? vendor) async {
    // In a vendor view the brand is already chosen; in All, ask.
    final kind = vendor ?? await _pickVendor();
    if (kind == null || !mounted) return;
    if (kind == kDeviceKindHanna) {
      // There is no add sheet: the checker records itself on first connect,
      // so "adding" one is running a measurement.
      await runProGated(
        context,
        ref,
        ProFeature.hannaConnect,
        () => context.push('/hanna/measure'),
      );
      return;
    }
    if (!ref.read(proFeatureProvider(ProFeature.connectedDevices))) {
      // Not `runProGated`: what follows is a whole switch over vendors, and
      // re-entering `_addDevice` after a successful unlock replays the vendor
      // pick cleanly rather than resuming into a half-built branch.
      if (await showProFeatureDialog(context, ProFeature.connectedDevices) &&
          mounted) {
        await _addDevice(kind);
      }
      return;
    }
    switch (kind) {
      case kDeviceKindReefFactory:
        await showRfAddFlow(
          context,
          ref,
          onSeed: (id, snap) {
            if (mounted) {
              setState(() {
                _rfLive[id] = RfLive(snapshot: snap);
                _readAt[id] = DateTime.now();
              });
            }
          },
        );
      case kDeviceKindReefBeat:
        await showRbAddFlow(
          context,
          ref,
          onSeed: (id, snap) {
            if (mounted) {
              setState(() {
                _rbLive[id] = RbLive(snapshot: snap);
                _readAt[id] = DateTime.now();
              });
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
              setState(() {
                _apLive[id] = ApLive(status: status);
                _readAt[id] = DateTime.now();
              });
            }
          },
        );
    }
  }

  Future<String?> _pickVendor() {
    final l = AppLocalizations.of(context);
    // The checker's entry points exist only behind the experimental opt-in
    // and on hardware with a BLE stack at all — the same two gates as the
    // Measurements-tab menu entry (U33).
    final hannaAvailable =
        (ref.read(experimentalEnabledProvider).value ?? false) &&
        (ref.read(hannaBleSupportedProvider).value ?? true);
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
              if (v != kDeviceKindHanna || hannaAvailable)
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
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle,
                            semanticLabel: l.reorder,
                          ),
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

  /// Devices a Refresh all would actually read — the button's count, and zero
  /// hides it (a Hanna-only view has nothing to poll). Same open-ended idiom
  /// as [meters], via [deviceKindRefreshes].
  int get refreshables => order
      .where(deviceKindRefreshes)
      .fold(0, (n, kind) => n + of(kind).length);
}

/// The vendor selector: one chip per vendor that has a device, in the user's
/// order, preceded by All.
class _VendorBar extends StatelessWidget {
  const _VendorBar({
    required this.vendors,
    required this.selected,
    required this.countOf,
    required this.onSelected,
    required this.onReorder,
  });

  final List<String> vendors;
  final String? selected;
  final int Function(String) countOf;
  final void Function(String?) onSelected;

  /// Opens the brand-order sheet. Sits outside the horizontal scroller so it
  /// stays reachable however far the chips are scrolled.
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
            ),
          ),
          IconButton(
            tooltip: l.devicesReorderBrands,
            icon: const Icon(Icons.swap_vert),
            onPressed: onReorder,
          ),
        ],
      ),
    );
  }
}

/// What sits where the scope line would be on a non-entitled install: the
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

/// No devices at all: one clear message, pointing at the host's app-bar add
/// action. No chips, no scope line, no disclaimer — there is nothing yet to be
/// read-only about.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
  kDeviceKindHanna => Icons.bluetooth,
  _ => Icons.hub_outlined,
};
