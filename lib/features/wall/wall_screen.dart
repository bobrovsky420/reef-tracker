import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/device_read_scope.dart';
import '../../data/rb_device_link.dart';
import '../../data/rb_protocol.dart';
import '../../data/wall_sources.dart';
import '../../domain/device_vendors.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/pro_features.dart';
import '../../domain/reminders.dart';
import '../../domain/units.dart';
import '../../domain/wall_display.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/zone_visuals.dart';
import '../apex/apex_screen.dart';
import '../reefbeat/reefbeat_screen.dart';
import '../reeffactory/reeffactory_screen.dart';
import 'wall_tiles.dart';

/// Wall display mode (U49) — "the tablet on the wall": a pushed full-screen
/// route with its own scaffold-less layout. No app bar, no nav, no FAB,
/// nothing tappable that isn't part of the mode; a tap only lifts the night
/// dim, and leaving takes a 1.5 s hold (§12f) so a brushed-past panel never
/// navigates away.
///
/// The mode never writes a `Reading` (§12d, the load-bearing decision): the
/// poll results live in this state and in the display-only `DeviceSamples`
/// buckets, never in the measurement history, so no implausible-value dialog
/// can ever park an unattended kiosk. Logging unattended is U45's job.
class WallScreen extends ConsumerStatefulWidget {
  const WallScreen({super.key});

  @override
  ConsumerState<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends ConsumerState<WallScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // --- live device state (same shape the Devices body holds) ---------------
  final Map<String, RfLive> _rfLive = {};
  final Map<String, RbLive> _rbLive = {};
  final Map<String, ApLive> _apLive = {};
  final Map<String, DateTime> _readAt = {};
  final Map<String, WallPollSchedule> _schedules = {};

  /// The 24 h sample cache, keyed by card id, oldest first — reloaded after
  /// every poll cycle so a tile's line and its number agree.
  Map<WallCardId, List<DeviceSample>> _samples = {};

  Timer? _pollTimer;
  Timer? _uiTimer;
  Timer? _pageTimer;
  Timer? _shiftTimer;
  Duration? _timerInterval;
  int? _timerPageSeconds;

  bool _polling = false;
  bool _foreground = true;
  int _cycles = 0;
  DateTime? _updatedAt;

  final PageController _pageCtrl = PageController();
  int _page = 0;
  int _pageCount = 1;

  int _shiftIndex = 0;
  DateTime? _dimLiftedUntil;

  /// Exit gesture: a raw-pointer hold with a progress ring — deliberately not
  /// a GestureDetector, so it never competes with the PageView's swipe arena
  /// and a swipe simply cancels the ring by moving.
  late final AnimationController _exitCtrl;
  Offset? _exitPos;

  /// Transient "hold to exit" hint, shown on entry and after a tap that had
  /// no dim to lift — the gesture teaches itself.
  DateTime? _hintUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exitCtrl = AnimationController(vsync: this, duration: kWallExitHold)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _exit();
      });
    // Always-on housekeeping (§12e). SystemChrome is called nowhere else in
    // the app, so exit restores edge-to-edge — Flutter's default on current
    // Android/iOS.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _setWakelock(true);
    _hintUntil = DateTime.now().add(const Duration(seconds: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startUp());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _uiTimer?.cancel();
    _pageTimer?.cancel();
    _shiftTimer?.cancel();
    _exitCtrl.dispose();
    _pageCtrl.dispose();
    _setWakelock(false);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  /// Held only while the mode is on screen **and** the app is foregrounded —
  /// a phone that wandered into the mode must never burn its battery in a
  /// pocket (§12e). The poll loop pauses with it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _setWakelock(foreground);
    if (foreground) {
      unawaited(_pollCycle());
    }
  }

  /// Best-effort: a missing platform implementation (tests) must not surface.
  void _setWakelock(bool on) {
    unawaited(WakelockPlus.toggle(enable: on).catchError((_) {}));
  }

  Future<void> _startUp() async {
    final tank = ref.read(activeTankProvider);
    if (tank != null) {
      // One sweep at mode start (§12m); later sweeps ride every Nth cycle.
      await ref
          .read(dbProvider)
          .pruneDeviceSamples(DateTime.now().subtract(kWallSampleRetention));
      await _loadSamples(tank.id);
      if (mounted) setState(() {});
    }
    await _pollCycle();
  }

  // --- the poll loop (§12d / §12n) -----------------------------------------

  void _ensureTimers(Duration interval, int pageSeconds) {
    if (_timerInterval != interval) {
      _timerInterval = interval;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(interval, (_) {
        if (_foreground) unawaited(_pollCycle());
      });
    }
    if (_timerPageSeconds != pageSeconds) {
      _timerPageSeconds = pageSeconds;
      _pageTimer?.cancel();
      _pageTimer = Timer.periodic(
        Duration(seconds: pageSeconds),
        (_) => _rotatePage(),
      );
    }
    // The 30 s UI tick redraws the clock, the ages on every provenance line
    // and the night-window check; the 10 min tick walks the burn-in lattice.
    _uiTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _shiftTimer ??= Timer.periodic(kWallBurnInShiftEvery, (_) {
      if (mounted) {
        setState(
          () => _shiftIndex = (_shiftIndex + 1) % kWallBurnInOffsets.length,
        );
      }
    });
  }

  void _rotatePage() {
    if (!mounted || _pageCount < 2 || !_pageCtrl.hasClients) return;
    final next = (_page + 1) % _pageCount;
    unawaited(
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// One pass over the devices in scope: reads what is due, folds the results
  /// into the sample buckets, prunes every Nth cycle, reloads the cache.
  Future<void> _pollCycle() async {
    if (_polling || !mounted) return;
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    if (!ref.read(proFeatureProvider(ProFeature.wallDisplay))) return;
    if (!_devicesEnabled) return;
    _polling = true;
    try {
      final scope = _dueScope(tank);
      await readDeviceScope(
        scope,
        (kind, d) => _readDevice(kind, d, tank),
        keepGoing: () => mounted && _foreground,
      );
      _cycles++;
      if (_cycles % kWallPruneEveryCycles == 0) {
        await ref
            .read(dbProvider)
            .pruneDeviceSamples(DateTime.now().subtract(kWallSampleRetention));
      }
      if (mounted) await _loadSamples(tank.id);
    } finally {
      _polling = false;
    }
    if (mounted) setState(() => _updatedAt = DateTime.now());
  }

  /// The wall is not experimental (§12h), but the LAN integrations it reads
  /// are (U36/U38/U40): with the master switch off the mode degrades honestly
  /// — no device tiles, no polling, stored readings only.
  bool get _devicesEnabled =>
      ref.read(experimentalEnabledProvider).value ?? false;

  /// The devices this cycle contacts: the active tank's, in vendor + card
  /// order, minus muted devices (§12q — a device whose known cards are all
  /// hidden leaves the rotation entirely) and minus devices not yet due
  /// (backoff, per-kind floor).
  DeviceScope _dueScope(Tank tank) {
    final order = [
      for (final kind
          in ref.read(deviceVendorOrderProvider).value ?? kDeviceVendors)
        if (deviceKindRefreshes(kind)) kind,
    ];
    final byKind = {
      kDeviceKindReefFactory:
          ref.read(reefFactoryDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindReefBeat:
          ref.read(reefBeatDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindApex:
          ref.read(apexDevicesProvider).value ?? const <DeviceRecord>[],
    };
    final polled = wallPolledDevices([
      for (final list in byKind.values)
        for (final d in list)
          if (d.tankId == tank.id) d.identifier,
    ], _cards(tank));
    final now = DateTime.now();
    final base = _baseInterval;
    List<DeviceRecord> due(String kind) => _sorted([
      for (final d in byKind[kind] ?? const <DeviceRecord>[])
        if (d.tankId == tank.id &&
            polled.contains(d.identifier) &&
            _scheduleOf(kind, d).isDue(now))
          d,
    ]);
    // A stored base-interval change mid-mode must re-arm, not wait out an old
    // long interval — schedules only apply it on their next success/failure,
    // so nothing else needs invalidating.
    _ensureTimers(base, _pageSeconds);
    return DeviceScope(
      order: order,
      byVendor: {for (final kind in order) kind: due(kind)},
    );
  }

  List<DeviceRecord> _sorted(List<DeviceRecord> devices) =>
      devices..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        if (byOrder != 0) return byOrder;
        return deviceDisplayName(
          a,
        ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
      });

  Duration get _baseInterval =>
      ref.read(wallRefreshIntervalProvider).value ??
      const Duration(seconds: kWallDefaultRefreshSeconds);

  int get _pageSeconds =>
      ref.read(wallPageSecondsProvider).value ?? kWallDefaultPageSeconds;

  WallPollSchedule _scheduleOf(String kind, DeviceRecord d) =>
      _schedules.putIfAbsent(
        d.identifier,
        () => WallPollSchedule(floor: minPollIntervalOf(kind, model: d.model)),
      );

  Future<void> _readDevice(String kind, DeviceRecord d, Tank tank) async {
    final schedule = _scheduleOf(kind, d);
    final now = DateTime.now();
    List<WallReading>? readings;
    String signature = '';
    switch (kind) {
      case kDeviceKindReefFactory:
        final r = await rfReadDevice(ref, d);
        if (!mounted) return;
        // On failure the tile keeps its last snapshot and ages visibly — the
        // error only drives the backoff and the header dot.
        final snap = r.snapshot ?? _rfLive[d.identifier]?.snapshot;
        _rfLive[d.identifier] = RfLive(snapshot: snap, error: r.error);
        if (r.snapshot != null) {
          readings = wallRfReadings(r.snapshot!);
          signature = wallPayloadSignature(readings);
        }
      case kDeviceKindReefBeat:
        final r = await rbReadDevice(ref, d);
        if (!mounted) return;
        final snap = r.snapshot ?? _rbLive[d.identifier]?.snapshot;
        _rbLive[d.identifier] = RbLive(snapshot: snap, error: r.error);
        if (r.snapshot != null) {
          readings = wallRbReadings(r.snapshot!);
          signature =
              '${wallPayloadSignature(readings)}|'
              '${_rbStatusSignature(r.snapshot!)}';
        }
      case kDeviceKindApex:
        final r = await apReadDevice(ref, d);
        if (!mounted) return;
        final status = r.status ?? _apLive[d.identifier]?.status;
        _apLive[d.identifier] = ApLive(status: status, error: r.error);
        if (r.status != null) {
          readings = wallApReadings(r.status!);
          signature = wallPayloadSignature(readings);
        }
      default:
        return;
    }
    if (readings == null) {
      schedule.onFailure(now, _baseInterval);
      return;
    }
    _readAt[d.identifier] = now;
    schedule.onSuccess(now, _baseInterval, signature);
    await _recordSamples(tank, d, readings);
  }

  /// What of a ReefBeat status snapshot counts as "changed" for the no-change
  /// backoff — the fields the status tiles actually show.
  String _rbStatusSignature(RbSnapshot snap) => [
    snap.ato?.waterLevelRaw,
    snap.ato?.leakAlarm,
    snap.ato?.todayVolumeMl,
    snap.ato?.daysTillEmpty,
    for (final h in snap.dose?.heads ?? const <RbDoseHead>[]) h.dosedToday,
    snap.mat?.daysTillEndOfRoll,
    snap.mat?.modeRaw,
    for (final p in snap.run?.pumps ?? const <RbRunPump>[]) p.state,
  ].join(';');

  /// Folds a successful read into the sample table: visible cards only (§12q
  /// — a hidden value is not sampled), rail values dropped at write time (the
  /// only validation, §12m rule 4), one bucket per 5 min. Also remembers any
  /// newly discovered card as a sparse row, hidden by default when its device
  /// is muted, so the Settings list is complete across sessions.
  Future<void> _recordSamples(
    Tank tank,
    DeviceRecord d,
    List<WallReading> readings,
  ) async {
    if (readings.isEmpty) return;
    final db = ref.read(dbProvider);
    final rows = _tileRows(tank);
    final known = {
      for (final r in rows)
        if (r.deviceIdentifier == d.identifier) r.paramKey,
    };
    final missing = [
      for (final r in readings)
        if (!known.contains(r.paramKey))
          (
            deviceIdentifier: d.identifier,
            paramKey: r.paramKey,
            visible: !isWallDeviceMuted(d.identifier, rows),
          ),
    ];
    if (missing.isNotEmpty) {
      await db.insertMissingWallTiles(tank.id, missing);
    }
    final visible = {
      for (final c in _cards(tank))
        if (c.visible && c.id.deviceIdentifier == d.identifier) c.id.paramKey,
    };
    final bucket = bucketStartFor(DateTime.now());
    for (final r in readings) {
      if (!visible.contains(r.paramKey)) continue;
      if (isRailValue(r.paramKey, r.value)) continue;
      await db.upsertDeviceSample(
        tankId: tank.id,
        deviceIdentifier: d.identifier,
        paramKey: r.paramKey,
        bucketStart: bucket,
        value: r.value,
      );
    }
  }

  Future<void> _loadSamples(int tankId) async {
    final since = DateTime.now().subtract(kWallSampleWindow);
    final rows = await ref
        .read(dbProvider)
        .getDeviceSamplesSince(tankId, since);
    final grouped = <WallCardId, List<DeviceSample>>{};
    for (final row in rows) {
      (grouped[(
                deviceIdentifier: row.deviceIdentifier,
                paramKey: row.paramKey,
              )] ??=
              [])
          .add(row);
    }
    _samples = grouped;
  }

  // --- card assembly (§12q) -------------------------------------------------

  List<WallTileConfig> _tileRows(Tank tank) => [
    for (final r
        in ref.read(wallTileSettingsProvider).value ??
            const <WallTileSetting>[])
      WallTileConfig(
        deviceIdentifier: r.deviceIdentifier,
        paramKey: r.paramKey,
        displayOrder: r.displayOrder,
        visible: r.visible,
      ),
  ];

  /// The tank's devices in page order (vendor order, card order), with what
  /// each is known to report — live snapshot first, remembered rows as the
  /// cold-start memory, sample cache as a backstop.
  Map<String, List<String>> _reportedByDevice(Tank tank) {
    final rows = _tileRows(tank);
    final result = <String, List<String>>{};
    void report(String id, Iterable<String> params) {
      final list = result.putIfAbsent(id, () => []);
      for (final p in params) {
        if (!list.contains(p)) list.add(p);
      }
    }

    for (final (kind, d) in _pageOrderDevices(tank)) {
      final live = switch (kind) {
        kDeviceKindReefFactory => switch (_rfLive[d.identifier]?.snapshot) {
          final s? => wallRfReadings(s).map((r) => r.paramKey),
          null => const <String>[],
        },
        kDeviceKindReefBeat => switch (_rbLive[d.identifier]?.snapshot) {
          final s? => wallRbReadings(s).map((r) => r.paramKey),
          null => const <String>[],
        },
        _ => switch (_apLive[d.identifier]?.status) {
          final s? => wallApReadings(s).map((r) => r.paramKey),
          null => const <String>[],
        },
      };
      report(d.identifier, live);
      report(d.identifier, [
        for (final r in rows)
          if (r.deviceIdentifier == d.identifier) r.paramKey,
      ]);
      report(d.identifier, [
        for (final id in _samples.keys)
          if (id.deviceIdentifier == d.identifier) id.paramKey,
      ]);
    }
    return result;
  }

  Iterable<(String, DeviceRecord)> _pageOrderDevices(Tank tank) sync* {
    if (!_devicesEnabled) return;
    final order = ref.read(deviceVendorOrderProvider).value ?? kDeviceVendors;
    final byKind = {
      kDeviceKindReefFactory:
          ref.read(reefFactoryDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindReefBeat:
          ref.read(reefBeatDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindApex:
          ref.read(apexDevicesProvider).value ?? const <DeviceRecord>[],
    };
    for (final kind in order) {
      if (!deviceKindRefreshes(kind)) continue;
      for (final d in _sorted([
        for (final d in byKind[kind] ?? const <DeviceRecord>[])
          if (d.tankId == tank.id) d,
      ])) {
        yield (kind, d);
      }
    }
  }

  List<WallCard> _cards(Tank tank) {
    final tracked = ref.read(trackedParametersProvider).value ?? const [];
    return buildWallCards(
      trackedKeys: [
        for (final p in tracked)
          if (p.enabled) p.paramKey,
      ],
      reportedByDevice: _reportedByDevice(tank),
      rows: _tileRows(tank),
    );
  }

  // --- leaving (§12f) -------------------------------------------------------

  void _exit() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      // The autostart redirect made /wall the initial route — go home.
      context.go('/');
    }
  }

  bool get _dimmed {
    if (!(ref.read(wallNightEnabledProvider).value ?? true)) return false;
    final now = DateTime.now();
    final lifted = _dimLiftedUntil;
    if (lifted != null && now.isBefore(lifted)) return false;
    return inNightWindow(
      now.hour * 60 + now.minute,
      from:
          ref.read(wallNightFromProvider).value ?? kWallDefaultNightFromMinutes,
      to: ref.read(wallNightToProvider).value ?? kWallDefaultNightToMinutes,
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    _exitPos = e.position;
    unawaited(_exitCtrl.forward(from: 0));
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _exitPos;
    if (start != null && (e.position - start).distance > 24) {
      _cancelHold();
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasHolding = _exitCtrl.isAnimating;
    _cancelHold();
    if (!wasHolding) return;
    // A short press is a tap: lift the night dim (§12e); with nothing to
    // lift, teach the exit gesture instead.
    setState(() {
      if (_dimmed) {
        _dimLiftedUntil = DateTime.now().add(kWallNightLift);
      } else {
        _hintUntil = DateTime.now().add(const Duration(seconds: 4));
      }
    });
  }

  void _cancelHold() {
    if (_exitCtrl.isAnimating) _exitCtrl.stop();
    _exitCtrl.value = 0;
    _exitPos = null;
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tank = ref.watch(activeTankProvider);
    final entitled = ref.watch(proFeatureProvider(ProFeature.wallDisplay));
    // Watched so a settings change mid-mode re-arms the timers and re-renders.
    final interval =
        ref.watch(wallRefreshIntervalProvider).value ??
        const Duration(seconds: kWallDefaultRefreshSeconds);
    final pageSeconds =
        ref.watch(wallPageSecondsProvider).value ?? kWallDefaultPageSeconds;
    ref.watch(wallNightEnabledProvider);
    ref.watch(wallNightFromProvider);
    ref.watch(wallNightToProvider);
    ref.watch(wallTileSettingsProvider);
    ref.watch(experimentalEnabledProvider);
    _ensureTimers(interval, pageSeconds);

    final now = DateTime.now();
    final Widget body;
    if (tank == null) {
      body = _CenteredNote(text: l.wallNoTank);
    } else if (!entitled) {
      body = _CenteredNote(text: l.wallProLocked);
    } else {
      body = _buildBoard(context, l, tank, now);
    }

    final dimmed = _dimmed;
    final showHint = _hintUntil != null && now.isBefore(_hintUntil!) && !dimmed;

    return Material(
      color: cs.surface,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) => _cancelHold(),
        child: Stack(
          children: [
            // The burn-in lattice: the whole board drifts a few pixels every
            // 10 min (§12e); page rotation moves content anyway.
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(
                  kWallBurnInOffsets[_shiftIndex].$1,
                  kWallBurnInOffsets[_shiftIndex].$2,
                ),
                child: body,
              ),
            ),
            // Night dim: a scrim, deliberately not screen brightness — that
            // would need another native plugin (§12e). Content stays beneath
            // it; a tap lifts it for 60 s.
            if (dimmed)
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.88)),
              ),
            if (showHint)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.wallExitHint,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // The exit hold's progress ring, drawn under the finger so the
            // gesture teaches itself (§12f).
            if (_exitPos != null && _exitCtrl.value > 0.02)
              Positioned(
                left: _exitPos!.dx - 36,
                top: _exitPos!.dy - 36,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: _exitCtrl.value,
                      strokeWidth: 5,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(
    BuildContext context,
    AppLocalizations l,
    Tank tank,
    DateTime now,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tiles = _buildTiles(context, l, tank, now);
    final due = _dueToday(l);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(l, cs, tank, now),
            const SizedBox(height: 8),
            Expanded(
              child: tiles.isEmpty
                  ? _CenteredNote(text: l.noReadings)
                  : _pagedGrid(context, tiles, now),
            ),
            if (_pageCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? cs.onSurfaceVariant
                              : cs.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
            if (due.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.wallDueToday(due.join(', ')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l, ColorScheme cs, Tank tank, DateTime now) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final clock = (use24 ? DateFormat.Hm() : DateFormat.jm()).format(now);
    final dim = TextStyle(fontSize: 14, color: cs.onSurfaceVariant);
    final (dotColor, dotLabel) = _connection(l);
    return Row(
      children: [
        Expanded(
          child: Text(
            tank.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dim.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(clock, style: dim),
        const SizedBox(width: 10),
        Semantics(
          label: dotLabel,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
        ),
        if (_updatedAt != null) ...[
          const SizedBox(width: 10),
          Text(
            l.wallUpdatedAt(
              (use24 ? DateFormat.Hm() : DateFormat.jm()).format(_updatedAt!),
            ),
            style: dim,
          ),
        ],
      ],
    );
  }

  /// The single header dot (§12c), split into honest states (§12r): all
  /// polled devices failing reads as "check the network", a partial failure
  /// as "a device is unreachable" — without it a dropped Wi-Fi link reads as
  /// four simultaneous device failures.
  (Color, String) _connection(AppLocalizations l) {
    final tokens = Theme.of(context);
    final cs = tokens.colorScheme;
    var failing = 0, total = 0;
    for (final s in _schedules.values) {
      total++;
      if (s.failures > 0) failing++;
    }
    if (total == 0) return (cs.outlineVariant, l.wallNoDevices);
    if (failing == 0) return (Zone.green.colorOf(context), l.wallAllReachable);
    if (failing < total) {
      return (Zone.amber.colorOf(context), l.wallSomeUnreachable);
    }
    return (Zone.red.colorOf(context), l.wallNetworkDown);
  }

  Widget _pagedGrid(BuildContext context, List<Widget> tiles, DateTime now) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The grid sizes columns against a *scaled* minimum tile size, so a
        // larger system font yields fewer, bigger tiles rather than clipped
        // ones (§12c); the value text then auto-fits its box.
        final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
        final minW = 250.0 * scale;
        final minH = 165.0 * scale;
        final cols = (constraints.maxWidth / minW).floor().clamp(1, 8);
        final rows = (constraints.maxHeight / minH).floor().clamp(1, 8);
        final perPage = cols * rows;
        final pageCount = ((tiles.length + perPage - 1) ~/ perPage).clamp(
          1,
          99,
        );
        if (pageCount != _pageCount) {
          _pageCount = pageCount;
          if (_page >= pageCount) _page = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        const gap = 10.0;
        return PageView.builder(
          controller: _pageCtrl,
          itemCount: pageCount,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, page) {
            final start = page * perPage;
            final pageTiles = tiles.sublist(
              start,
              (start + perPage).clamp(0, tiles.length),
            );
            return Column(
              children: [
                for (var r = 0; r < rows; r++) ...[
                  if (r > 0) const SizedBox(height: gap),
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < cols; c++) ...[
                          if (c > 0) const SizedBox(width: gap),
                          Expanded(
                            child: r * cols + c < pageTiles.length
                                ? pageTiles[r * cols + c]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // --- tile data ------------------------------------------------------------

  List<Widget> _buildTiles(
    BuildContext context,
    AppLocalizations l,
    Tank tank,
    DateTime now,
  ) {
    final prefs = ref.watch(unitPrefsProvider);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final readings = ref.watch(recentReadingsProvider).value ?? const [];
    final trackedByKey = {for (final p in tracked) p.paramKey: p};
    // Latest stored reading per parameter (arrive newest-first), plus the
    // oldest-first series for fallback lines and markers.
    final latest = <String, Reading>{};
    for (final r in readings) {
      latest.putIfAbsent(r.paramKey, () => r);
    }
    final series = <String, List<SparkPoint>>{};
    for (final r in readings.reversed) {
      (series[r.paramKey] ??= []).add((time: r.takenAt, value: r.value));
    }

    final deviceNames = <String, String>{};
    final liveValues = <String, Map<String, double>>{};
    for (final (kind, d) in _pageOrderDevices(tank)) {
      deviceNames[d.identifier] = deviceDisplayName(d);
      final extracted = switch (kind) {
        kDeviceKindReefFactory => switch (_rfLive[d.identifier]?.snapshot) {
          final s? => wallRfReadings(s),
          null => const <WallReading>[],
        },
        kDeviceKindReefBeat => switch (_rbLive[d.identifier]?.snapshot) {
          final s? => wallRbReadings(s),
          null => const <WallReading>[],
        },
        _ => switch (_apLive[d.identifier]?.status) {
          final s? => wallApReadings(s),
          null => const <WallReading>[],
        },
      };
      liveValues[d.identifier] = {
        for (final r in extracted) r.paramKey: r.value,
      };
    }

    final tiles = <Widget>[];
    for (final card in _cards(tank)) {
      if (!card.visible) continue;
      final id = card.id;
      final deviceCard = id.deviceIdentifier != kWallNoDevice;
      final samples = _samples[id] ?? const <DeviceSample>[];
      final lastSample = samples.isNotEmpty ? samples.last : null;
      final storedLatest = latest[id.paramKey];
      final value = resolveWallTileValue(
        deviceCard: deviceCard,
        liveValue: liveValues[id.deviceIdentifier]?[id.paramKey],
        liveAt: _readAt[id.deviceIdentifier],
        sampleValue: lastSample?.value,
        sampleAt: lastSample?.bucketStart,
        readingValue: storedLatest?.value,
        readingAt: storedLatest?.takenAt,
      );
      final param = trackedByKey[id.paramKey];
      final bounds = param?.bounds ?? const ZoneBounds();
      final zone = value.value != null
          ? bounds.classify(value.value!)
          : Zone.unknown;
      final pres = param != null
          ? presentationOf(param, prefs)
          : presentationForKey(
              id.paramKey,
              kParameterByKey[id.paramKey]?.unit ?? '',
              prefs,
            );

      // The graph: ≥2 sample points in the window → the 24 h line with its
      // min/max band and hand-measurement markers; otherwise the dashboard's
      // 14-day readings sparkline, window named in the footer (§12m).
      final useSamples = deviceCard && samples.length >= kWallMinSamplePoints;
      final tileData = WallTileData(
        id: id,
        title: l.paramName(id.paramKey),
        sourceName: deviceCard ? deviceNames[id.deviceIdentifier] : null,
        value: value,
        zone: zone,
        pres: pres,
        line: useSamples
            ? [
                for (final s in samples)
                  (time: s.bucketStart, value: pres.toDisplay(s.value)),
              ]
            : [
                for (final p in series[id.paramKey] ?? const <SparkPoint>[])
                  (time: p.time, value: pres.toDisplay(p.value)),
              ],
        band: useSamples
            ? [
                for (final s in samples)
                  (
                    time: s.bucketStart,
                    min: pres.toDisplay(s.minValue),
                    max: pres.toDisplay(s.maxValue),
                  ),
              ]
            : const [],
        markers: useSamples
            ? [
                for (final p in series[id.paramKey] ?? const <SparkPoint>[])
                  if (now.difference(p.time) <= kWallSampleWindow)
                    (time: p.time, value: pres.toDisplay(p.value)),
              ]
            : const [],
        window: useSamples ? kWallSampleWindow : kWallReadingsWindow,
        isSampleWindow: useSamples,
      );
      tiles.add(WallValueTile(data: tileData, now: now));
    }

    tiles.addAll(_statusTiles(l, tank));
    return tiles;
  }

  /// Status tiles (§12b): non-measurement facts from the same snapshots the
  /// Devices cards render — reservoir, leak, doses today, fleece roll,
  /// skimmer cup — plus the RO stage due, if any. Always after the value
  /// cards.
  List<Widget> _statusTiles(AppLocalizations l, Tank tank) {
    final tiles = <Widget>[];
    for (final (kind, d) in _pageOrderDevices(tank)) {
      if (kind != kDeviceKindReefBeat) continue;
      final snap = _rbLive[d.identifier]?.snapshot;
      if (snap == null) continue;
      final name = deviceDisplayName(d);
      final ato = snap.ato;
      if (ato != null) {
        final leak = ato.leakSensorActive && ato.leakAlarm;
        final levelLine = switch (ato.waterLevel) {
          RbAtoWaterLevel.ok => l.reefBeatAtoLevelOk,
          RbAtoWaterLevel.low => l.reefBeatAtoLevelLow,
          RbAtoWaterLevel.high => l.reefBeatAtoLevelHigh,
          RbAtoWaterLevel.unknown => ato.waterLevelRaw ?? '—',
        };
        tiles.add(
          WallStatusTile(
            data: WallStatusData(
              icon: leak ? Icons.water_damage_outlined : Icons.waves_outlined,
              title: name,
              line: leak ? l.reefBeatAtoLeak : levelLine,
              extra: ato.daysTillEmpty != null
                  ? '${l.reefBeatAtoReservoir} · '
                        '${l.reefBeatDaysLeft(ato.daysTillEmpty!)}'
                  : null,
              tone: leak
                  ? Zone.red
                  : (ato.waterLevel == RbAtoWaterLevel.ok
                        ? Zone.unknown
                        : Zone.amber),
            ),
          ),
        );
      }
      final dose = snap.dose;
      if (dose != null && dose.heads.isNotEmpty) {
        double dosed = 0, daily = 0;
        int? minDays;
        for (final h in dose.heads) {
          if (h.switchedOff) continue;
          dosed += h.dosedToday;
          daily += h.dailyDose ?? 0;
          if (h.remainingDays != null &&
              (minDays == null || h.remainingDays! < minDays)) {
            minDays = h.remainingDays;
          }
        }
        tiles.add(
          WallStatusTile(
            data: WallStatusData(
              icon: Icons.medication_liquid_outlined,
              title: name,
              line: daily > 0
                  ? l.reefBeatDosedOfDaily(
                      formatLocaleNumberTrim(dosed),
                      formatLocaleNumberTrim(daily),
                    )
                  : l.reefBeatDosedNoDaily(formatLocaleNumberTrim(dosed)),
              extra: minDays != null ? l.reefBeatDaysLeft(minDays) : null,
              tone: minDays != null && minDays <= kRbStockCriticalDays
                  ? Zone.red
                  : (minDays != null && minDays <= kRbStockCautionDays
                        ? Zone.amber
                        : Zone.unknown),
            ),
          ),
        );
      }
      final mat = snap.mat;
      if (mat != null) {
        final empty = mat.modeRaw == kRbMatEndOfRollMode;
        tiles.add(
          WallStatusTile(
            data: WallStatusData(
              icon: Icons.album_outlined,
              title: name,
              line: empty
                  ? l.reefBeatMatRollEmpty
                  : (mat.daysTillEndOfRoll != null
                        ? l.reefBeatDaysLeft(mat.daysTillEndOfRoll!)
                        : l.reefBeatMatRoll),
              tone: empty ? Zone.red : Zone.unknown,
            ),
          ),
        );
      }
      final run = snap.run;
      if (run != null) {
        for (final p in run.pumps) {
          if (p.isEmptySocket || p.type != 'skimmer') continue;
          tiles.add(
            WallStatusTile(
              data: WallStatusData(
                icon: Icons.bubble_chart_outlined,
                title: p.name ?? name,
                line: p.fullCup ? l.reefBeatRunFullCup : l.zoneOk,
                tone: p.fullCup
                    ? Zone.red
                    : (p.faulted ? Zone.amber : Zone.unknown),
              ),
            ),
          );
        }
      }
    }
    // The RO stage most in need, when the feature is on and something is due.
    if (ref.watch(roUnitEnabledProvider).value ?? true) {
      final statuses = ref.watch(roStageStatusProvider);
      RoStageDueLine? worst;
      for (final s in statuses) {
        final due = s.due;
        if (!s.stage.enabled || !s.stage.remindEnabled || due == null) {
          continue;
        }
        if (due.daysLeft > 0) continue;
        if (worst == null || due.daysLeft < worst.daysLeft) {
          worst = (
            name: l.roStageName(s.stage.stageType, s.stage.title),
            daysLeft: due.daysLeft,
          );
        }
      }
      if (worst != null) {
        tiles.add(
          WallStatusTile(
            data: WallStatusData(
              icon: Icons.water_outlined,
              title: l.roUnitTitle,
              line: worst.name,
              extra: l.wallRoDue,
              tone: worst.daysLeft < 0 ? Zone.red : Zone.amber,
            ),
          ),
        );
      }
    }
    return tiles;
  }

  /// The optional bottom strip (§12c): today's due maintenance plans and
  /// parameter tests, as plain text.
  List<String> _dueToday(AppLocalizations l) {
    final names = <String>[];
    for (final d in ref.watch(maintenanceDueProvider)) {
      if (d.due.daysLeft > 0) continue;
      names.add(switch (d.schedule.actionType) {
        'waterChange' => l.waterChange,
        'carbonChange' => l.carbonChange,
        'equipmentCleaning' => l.equipmentCleaning,
        _ => d.schedule.title ?? '',
      });
    }
    final readings = ref.watch(recentReadingsProvider).value ?? const [];
    final latest = <String, DateTime>{};
    for (final r in readings) {
      latest.putIfAbsent(r.paramKey, () => r.takenAt);
    }
    for (final p
        in ref.watch(trackedParametersProvider).value ??
            const <ResolvedParameter>[]) {
      final cadence = p.testCadenceDays;
      if (!p.enabled || cadence == null) continue;
      final last = latest[p.paramKey];
      if (last == null) continue; // Never measured: no anchor, no due (U16).
      final dueAt = last.add(Duration(days: cadence));
      if (daysLeftUntil(dueAt) <= 0) {
        names.add(l.wallTestDue(l.paramName(p.paramKey)));
      }
    }
    return [
      for (final n in names)
        if (n.isNotEmpty) n,
    ];
  }
}

typedef RoStageDueLine = ({String name, int daysLeft});

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
