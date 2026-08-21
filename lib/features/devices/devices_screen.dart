import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/device_live.dart';
import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/device_integrations.dart';
import '../../data/device_read_scope.dart';
import '../../domain/device_vendors.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/implausible_value_dialog.dart';
import '../../widgets/pro_feature_dialog.dart';
import 'device_presentations.dart';

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

  /// Distinct tank parameters in scope that Save all would persist right now,
  /// after each integration's filtering and the first-displayed-wins merge.
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
///   disabled — when the selection holds no meter-capable device. A Red Sea
///   selection counts ReefControl but not its status-only device families.
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

  /// How old a held snapshot may be before an automatic page refresh or a
  /// save re-reads it (see [kDeviceSnapshotStaleAfter]). A parameter only so
  /// that tests can exercise the stale paths without waiting out the real
  /// window.
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

/// Presentation-only group for persisted kinds this build cannot parse. Never
/// written to the database or the vendor-order setting.
const String _kUnsupportedDeviceGroup = '__unsupported__';

String _deviceVendorLabel(AppLocalizations l, String vendor) =>
    vendor == _kUnsupportedDeviceGroup
    ? l.discoveryUnsupported
    : devicePresentationRegistry.forId(vendor)?.label(l) ??
          l.discoveryUnsupported;

/// How long the page takes to scroll back to the top after a swipe changed the
/// vendor — see [DevicesBodyState._stepVendor], where that scroll is the
/// feedback rather than housekeeping.
const Duration _kVendorSwipeScrollBack = Duration(milliseconds: 250);

class DevicesBodyState extends ConsumerState<DevicesBody>
    with WidgetsBindingObserver {
  /// One normalized live-state map, keyed by device identifier. Family-owned
  /// card sections receive typed presentation views from their descriptors.
  final Map<String, DeviceLiveState> _live = {};

  /// When each device was last asked for a refresh. Unlike [_readAt], this is
  /// recorded for failed attempts too: a device that is off the LAN must not
  /// be hammered again on every rebuild. It drives automatic refreshes when a
  /// stale page is revisited, resumed, or switched back to a vendor.
  final Map<String, DateTime> _refreshedAt = {};

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
  /// (Save all and every vendor's per-card buttons all funnel through [_save]).
  bool _saving = false;

  /// The vendors that had a chip on the last build. Kept so [addDevice] — which
  /// the host's app bar calls between builds — can resolve the effective
  /// selection exactly as the page renders it, without re-deriving it from the
  /// providers.
  List<String> _present = const [];

  /// The scope the last build rendered — what the host's Refresh all / Save
  /// all FABs act on between builds, same reasoning as [_present].
  DeviceScope _scope = const DeviceScope.empty();

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant DevicesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _scheduleStaleAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _scheduleStaleAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (_vendor == vendor) return;
    setState(() => _vendor = vendor);
    unawaited(ref.read(settingsProvider).setDeviceVendorFilter(vendor));
    // The build following this selection replaces [_scope]. Wait for it, then
    // refresh the newly visible vendor if its last attempt has aged out.
    _scheduleStaleAutoRefresh();
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
    // With a single vendor the bar isn't rendered at all, and All and that
    // vendor show the same one section — stepping between them would change
    // the header and the disclaimer with nothing on screen to explain why.
    if (_present.length < 2) return;
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

  bool get _liveIoAuthorized => ref.read(
    proCapabilityProvider(ProCapabilityBoundary.connectedDeviceLiveIo),
  );

  /// Schedules a stale check after the current change has rebuilt [_scope].
  /// Several lifecycle/selection events may queue callbacks in one frame; the
  /// attempt timestamps set by the first callback make the rest no-ops.
  void _scheduleStaleAutoRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _autoRefreshScope();
    });
  }

  /// Automatically reads devices in the visible scope that have never been
  /// attempted, plus previously attempted ones whose refresh window has
  /// elapsed. Explicit refresh actions still read the whole scope regardless
  /// of age.
  void _autoRefreshScope() {
    if (!mounted || !widget.active || !_liveIoAuthorized) return;
    final now = DateTime.now();
    final byVendor = <String, List<DeviceRecord>>{};
    for (final (kind, device) in _scope.inPageOrder) {
      if (!_kindRefreshes(kind) ||
          (_live[device.identifier]?.loading ?? false)) {
        continue;
      }
      final refreshedAt = _refreshedAt[device.identifier];
      if (refreshedAt != null &&
          now.difference(refreshedAt) <= widget.staleAfter) {
        continue;
      }
      (byVendor[kind] ??= []).add(device);
    }
    if (byVendor.isEmpty) return;

    // Claim every candidate before starting any I/O. This prevents another
    // post-frame callback or rebuild from launching the same automatic read.
    for (final devices in byVendor.values) {
      for (final device in devices) {
        _refreshedAt[device.identifier] = now;
      }
    }
    unawaited(
      _refreshScope(
        DeviceScope(
          order: [
            for (final kind in _scope.order)
              if (byVendor.containsKey(kind)) kind,
          ],
          byVendor: byVendor,
        ),
      ),
    );
  }

  /// Reads one registered device. Dispatch, errors and payload typing stay in
  /// the integration registry; the screen only owns lifecycle state.
  Future<void> _refreshDevice(String kind, DeviceRecord d) async {
    final registry = ref.read(deviceIntegrationRegistryProvider);
    final integration = registry.integrationForId(kind);
    if (!mounted ||
        !_liveIoAuthorized ||
        integration == null ||
        !integration.capabilities.refreshes) {
      return;
    }
    final previous = _live[d.identifier];
    setState(() {
      _refreshedAt[d.identifier] = DateTime.now();
      _live[d.identifier] = DeviceLiveState.loadingFrom(previous);
    });
    final result = await readRegisteredDevice(ref, d);
    if (!mounted || !_liveIoAuthorized) return;
    setState(() {
      _live[d.identifier] = DeviceLiveState.completed(
        result,
        previous: previous,
      );
      if (result.hasFreshPayload) _readAt[d.identifier] = DateTime.now();
    });
  }

  /// Reads everything refreshable in [scope] through the shared walk
  /// ([readDeviceScope], U49 §12d): sequential within a vendor, vendors
  /// concurrent — the politeness rule lives there now, beside the wall
  /// display's poll loop.
  Future<void> _refreshScope(DeviceScope scope) async {
    if (!_liveIoAuthorized) return;
    final now = DateTime.now();
    for (final (kind, device) in scope.inPageOrder) {
      if (_kindRefreshes(kind)) _refreshedAt[device.identifier] = now;
    }
    await readDeviceScope(
      scope,
      _refreshDevice,
      keepGoing: () => mounted && _liveIoAuthorized,
    );
  }

  Future<void> _refreshOneInteractive(String kind, DeviceRecord device) async {
    if (!await requestProCapability(
          context,
          ref,
          ProCapabilityBoundary.connectedDeviceLiveIo,
        ) ||
        !mounted) {
      return;
    }
    await _refreshDevice(kind, device);
  }

  // --- saving ------------------------------------------------------------

  Future<void> _persistValues(
    Tank tank,
    List<({String paramKey, double value})> values,
    DateTime takenAt,
  ) async {
    if (!_liveIoAuthorized) return;
    final db = ref.read(dbProvider);
    for (final key in {for (final v in values) v.paramKey}) {
      await db.addTrackedParameter(tank.id, key);
      if (!_liveIoAuthorized) return;
    }
    if (!_liveIoAuthorized) return;
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
  Future<void> _freshen(DeviceScope scope, DeviceRecord? only) async {
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
    // Through the ordinary read path, so the same one-socket-at-a-time
    // courtesy per vendor applies.
    await _refreshScope(
      DeviceScope(order: stale.keys.toList(), byVendor: stale),
    );
  }

  /// Saves one card's values — the per-card Save button. The device's own
  /// vendor list still rides along in [scope], because a ReefFactory meter's
  /// values depend on which *other* meters the tank has (the Temperature
  /// Controller rule).
  Future<void> _saveOne(DeviceRecord device, DeviceScope scope) =>
      _save(scope, only: device);

  /// The values a save would persist for [d] right now: what its last read
  /// produced, run through that vendor's own save filter. Empty when the device
  /// hasn't been read yet, holds nothing savable, or is of a kind that never
  /// reports measurements.
  ///
  /// The one place normalized live state is turned into savable values — Save
  /// all, the savable count and per-card Save all ask the same integration.
  List<({String paramKey, double value})> _pendingValues(
    String kind,
    DeviceRecord d,
    DeviceScope scope,
  ) {
    final result = _live[d.identifier]?.result;
    if (result == null) return const [];
    return ref
        .read(deviceIntegrationRegistryProvider)
        .valuesToSave(d, result, scope.of(kind));
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
  Future<void> _save(DeviceScope scope, {DeviceRecord? only}) async {
    if (_saving) return;
    if (!await requestProCapability(
          context,
          ref,
          ProCapabilityBoundary.connectedDeviceLiveIo,
        ) ||
        !mounted) {
      return;
    }
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

  Future<void> _saveGuarded(DeviceScope scope, {DeviceRecord? only}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _freshen(scope, only);
    if (!mounted || !_liveIoAuthorized) return;
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

    // The confirmation above can stay open while a refund/restore changes the
    // entitlement. Do not let its stale callback cross the commit boundary.
    if (!_liveIoAuthorized) return;

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
    final entitled = ref.watch(
      proCapabilityProvider(ProCapabilityBoundary.connectedDeviceLiveIo),
    );
    final order = ref.watch(deviceVendorOrderProvider).value ?? kDeviceVendors;

    final inventory = {
      for (final kind in kDeviceKinds)
        kind: ref.watch(devicesOfKindProvider(kind)),
    };
    final unsupportedAsync = ref.watch(unsupportedDevicesProvider);
    final unsupported = _scoped(unsupportedAsync.value ?? const [], tankId);
    final byVendor = {
      for (final entry in inventory.entries)
        entry.key.id: _scoped(entry.value.value ?? const [], tankId),
      _kUnsupportedDeviceGroup: unsupported,
    };
    final displayOrder = [
      ...order,
      if (unsupported.isNotEmpty) _kUnsupportedDeviceGroup,
    ];

    // A vendor earns a chip only by having a device in view.
    final present = [
      for (final v in displayOrder)
        if ((byVendor[v] ?? const []).isNotEmpty) v,
    ];
    _present = present;
    // Watched, not read: the setting's arrival must itself trigger a rebuild,
    // or a settings map that loads after the last device rebuild would leave
    // the stored selection unapplied until something else redraws the page.
    _restoreSelection(
      present,
      devicesLoaded:
          inventory.values.every((value) => value.hasValue) &&
          unsupportedAsync.hasValue,
      stored: ref.watch(deviceVendorFilterProvider).value,
    );
    final selected = present.contains(_vendor) ? _vendor : null;
    final inScope = selected == null ? present : [selected];
    final scope = DeviceScope(
      order: inScope,
      byVendor: {for (final v in inScope) v: byVendor[v] ?? const []},
    );
    _scope = scope;
    _publishFabStatus(entitled, scope);

    // The first on-open read, scoped to the selection and once per device.
    // Later automatic reads are event-driven by tab return, app resume, and
    // vendor changes; build itself never loops merely because the timeout has
    // elapsed. Only the tab actually on screen may read — see
    // [DevicesBody.active]. Non-refreshable kinds (the Hanna checker) are left
    // out rather than marked, so the guards stay honest if one becomes
    // refreshable later.
    if (entitled && widget.active) {
      final toRead = DeviceScope(
        order: [
          for (final kind in scope.order)
            if (_kindRefreshes(kind)) kind,
        ],
        byVendor: {
          for (final kind in scope.order)
            if (_kindRefreshes(kind))
              kind: [
                for (final d in scope.of(kind))
                  if (!_refreshedAt.containsKey(d.identifier)) d,
              ],
        },
      );
      if (toRead.length > 0) {
        final now = DateTime.now();
        for (final (_, d) in toRead.inPageOrder) {
          _refreshedAt[d.identifier] = now;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refreshScope(toRead));
        });
      }
    }

    if (present.isEmpty) return const _EmptyState();
    final canRefresh = entitled && _refreshableCount(scope) > 0;
    final list = CustomScrollView(
      controller: _scrollCtrl,
      // A one-card dashboard may not otherwise have enough content to
      // overscroll. Pull-to-refresh must still be available from its top.
      physics: canRefresh ? const AlwaysScrollableScrollPhysics() : null,
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
                            _deviceVendorLabel(l, selected),
                            scope.length,
                          ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : _ProNotice(
                    onTap: () => unawaited(
                      requestProCapability(
                        context,
                        ref,
                        ProCapabilityBoundary.connectedDeviceLiveIo,
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
                  _deviceVendorLabel(l, vendor).toUpperCase(),
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
    // Nothing follows the finger; the step happens when it lifts. The bar's own
    // horizontal scroller wins the arena against this for gestures that start
    // on the chips, which is the right way round — that strip pans the chips.
    //
    // Wrapped unconditionally, with [_stepVendor] declining when there is no
    // bar to step: making the wrapper itself conditional would re-root the list
    // whenever the vendor count crossed one, throwing away its scroll position.
    final width = MediaQuery.sizeOf(context).width;
    final page = GestureDetector(
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (d) => _onSwipeEnd(d, width),
      child: list,
    );
    // Pulling past the top is the touch-first twin of Refresh all: it uses the
    // exact same selected-vendor scope and is absent when the scope contains
    // nothing pollable (or live reads are not entitled).
    return canRefresh
        ? RefreshIndicator(onRefresh: refreshAll, child: page)
        : page;
  }

  /// Publishes what the host's FABs need for the frame just built. Post-frame
  /// because the host may rebuild in response, and value-compared (via
  /// [DevicesFabStatus.==]) so a no-change build notifies no one — the
  /// post-frame callback itself must not schedule another frame forever.
  void _publishFabStatus(bool entitled, DeviceScope scope) {
    final notifier = widget.fabStatus;
    if (notifier == null) return;
    final status = DevicesFabStatus(
      entitled: entitled,
      refreshable: _refreshableCount(scope),
      busy: _busy(scope),
      meters: _meterCount(scope),
      savable: _savableCount(scope),
      saving: _saving,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = status;
    });
  }

  /// Reads every refreshable device in the current selection — the host's
  /// Refresh all FAB.
  Future<void> refreshAll() async {
    // The FAB is disabled while a read is running; the pull gesture needs the
    // same guard so dragging during the on-open read cannot start a duplicate
    // request to every device.
    if (_busy(_scope)) return;
    if (!await requestProCapability(
          context,
          ref,
          ProCapabilityBoundary.connectedDeviceLiveIo,
        ) ||
        !mounted) {
      return;
    }
    await _refreshScope(_scope);
  }

  /// Saves every meter in the current selection — the host's Save all FAB.
  Future<void> saveAll() => _save(_scope);

  /// The scope a per-card Save runs in: that card's vendor, with the rest of
  /// its section still present, since a device's savable values can depend on
  /// its neighbours (the ReefFactory temperature-source rule).
  DeviceScope _vendorScope(
    String vendor,
    Map<String, List<DeviceRecord>> byVendor,
  ) => DeviceScope(
    order: [vendor],
    byVendor: {vendor: byVendor[vendor] ?? const []},
  );

  Widget _sectionFor(String vendor, Map<String, List<DeviceRecord>> byVendor) {
    final presentation = devicePresentationRegistry.forId(vendor);
    if (presentation != null) {
      return presentation.buildSection(
        devices: byVendor[vendor]!,
        live: _live,
        saving: _saving,
        // The shown family snapshot is deliberately ignored: the save funnel
        // re-freshens and derives candidates from normalized live state.
        onSave: (device) =>
            unawaited(_saveOne(device, _vendorScope(vendor, byVendor))),
        onRemoved: _onDeviceRemoved,
        onRefresh: (device) =>
            unawaited(_refreshOneInteractive(vendor, device)),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          for (final device in byVendor[vendor] ?? const <DeviceRecord>[])
            Card(
              child: ListTile(
                leading: const Icon(Icons.device_unknown_outlined),
                title: Text(deviceDisplayName(device)),
                subtitle: Text(
                  '${device.kind}\n'
                  '${AppLocalizations.of(context).discoveryUnsupportedHelp}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }

  /// The read-only notice. Generic in All; in a vendor view it swaps to that
  /// vendor's own text, which can name the app to use instead (ReefBeat,
  /// the ReefFactory app, Fusion).
  String _disclaimerFor(AppLocalizations l, String? vendor) {
    if (vendor == null) return l.devicesDisclaimer;
    if (vendor == _kUnsupportedDeviceGroup) {
      return l.discoveryUnsupportedHelp;
    }
    return devicePresentationRegistry.forId(vendor)?.disclaimer(l) ??
        l.discoveryUnsupportedHelp;
  }

  bool _busy(DeviceScope scope) => scope.inPageOrder.any(
    (entry) => _live[entry.$2.identifier]?.loading ?? false,
  );

  bool _kindRefreshes(String kind) =>
      ref
          .read(deviceIntegrationRegistryProvider)
          .integrationForId(kind)
          ?.capabilities
          .refreshes ??
      false;

  int _refreshableCount(DeviceScope scope) =>
      scope.inPageOrder.where((entry) => _kindRefreshes(entry.$1)).length;

  int _meterCount(DeviceScope scope) {
    final registry = ref.read(deviceIntegrationRegistryProvider);
    return scope.inPageOrder
        .where((entry) => registry.savesModel(entry.$2))
        .length;
  }

  /// How many distinct tank parameters in scope a Save all would persist.
  ///
  /// This mirrors [_saveGuarded]'s first-displayed-wins merge: supplementary
  /// readings count (for example, a ReefControl probe's temperature), while a
  /// second probe or device reporting the same parameter for the same tank
  /// does not. An unassigned device contributes nothing because the save would
  /// skip it.
  int _savableCount(DeviceScope scope) {
    final parameters = <(int, String)>{};
    for (final (kind, d) in scope.inPageOrder) {
      final tankId = d.tankId;
      if (tankId == null) continue;
      for (final value in _pendingValues(kind, d, scope)) {
        parameters.add((tankId, value.paramKey));
      }
    }
    return parameters.length;
  }

  Future<void> _onDeviceRemoved(DeviceRecord device) async {
    if (!mounted) return;
    setState(() {
      _live.remove(device.identifier);
      _refreshedAt.remove(device.identifier);
      _readAt.remove(device.identifier);
    });
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
    final kindId = vendor ?? await _pickVendor();
    if (kindId == null || !mounted) return;
    final presentation = devicePresentationRegistry.forId(kindId);
    if (presentation == null) return;
    await presentation.add(
      context,
      ref,
      onSeed: (identifier, payload) {
        if (!mounted) return;
        setState(() {
          _live[identifier] = DeviceLiveState.completed(
            DeviceReadResult.success(payload.kind, payload),
          );
          _readAt[identifier] = DateTime.now();
        });
      },
    );
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
            for (final presentation in devicePresentationRegistry.values)
              if (presentation.addAvailable(ref))
                ListTile(
                  leading: Icon(presentation.icon),
                  title: Text(presentation.label(l)),
                  onTap: () => Navigator.pop(ctx, presentation.kind.id),
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
                      title: Text(_deviceVendorLabel(l, v)),
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

// The scope type itself ([DeviceScope]) and the polite bulk-read walk moved to
// `data/device_read_scope.dart` (U49 §12d) so the wall display and U45 share
// them with this page instead of growing copies.

/// The vendor selector: one chip per vendor that has a device, in the user's
/// order, preceded by All.
class _VendorBar extends StatefulWidget {
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
  State<_VendorBar> createState() => _VendorBarState();
}

class _VendorBarState extends State<_VendorBar> {
  /// One key per stop (`null` = All), kept across builds so the selected chip
  /// can be found and scrolled to.
  final Map<String?, GlobalKey> _chipKeys = {};

  GlobalKey _chipKey(String? vendor) =>
      _chipKeys.putIfAbsent(vendor, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    // A restored selection can be off-screen on the very first build, exactly
    // as a swiped-to one can.
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant _VendorBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected();
  }

  /// Centres the selected chip in the strip. Tapping can only ever select a
  /// chip already in view, but **swiping can land on one the strip has scrolled
  /// past** — and a bar showing four unselected chips answers the one question
  /// the swipe leaves open. Centring rather than merely revealing also keeps
  /// the neighbouring brands visible, which is where the next swipe goes.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chipContext = _chipKeys[widget.selected]?.currentContext;
      if (chipContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          chipContext,
          alignment: 0.5,
          duration: _kVendorSwipeScrollBack,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vendors = widget.vendors;
    final selected = widget.selected;
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
                    key: _chipKey(null),
                    label: Text(l.devicesAll),
                    selected: selected == null,
                    onSelected: (_) => widget.onSelected(null),
                  ),
                  for (final v in vendors) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: _chipKey(v),
                      label: Text(
                        l.devicesScopeVendor(
                          _deviceVendorLabel(l, v),
                          widget.countOf(v),
                        ),
                      ),
                      selected: selected == v,
                      onSelected: (_) => widget.onSelected(v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l.devicesReorderBrands,
            icon: const Icon(Icons.swap_vert),
            onPressed: widget.onReorder,
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
IconData deviceVendorIcon(String kind) =>
    devicePresentationRegistry.forId(kind)?.icon ??
    Icons.device_unknown_outlined;
