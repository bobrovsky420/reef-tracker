import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/environment_sources.dart';
import '../../domain/hanna_import.dart';
import '../../domain/hanna_meter.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/experimental_chip.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_settings.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/section_header.dart';
import 'hanna_meter_session.dart';

/// Live measurements over BLE from the Hanna HI97115C checker (U33,
/// experimental). One route hosts the whole flow, phase-switched off the
/// [HannaMeterSession] so the connection survives every step: connect →
/// aquarium + method selection (with user-defined method sets) → the
/// one-by-one measurement runner → results confirm/save.
///
/// Saving reuses the U32 import machinery — per-reading meter timestamps
/// inside one reading group, and the shared `hannaLab` (tank, source)
/// watermark, so a reading captured live today doesn't re-import from a CSV
/// export of the meter's log tomorrow.
/// The audio player id for the timer/result beep. Fixed rather than the
/// package's random UUID: it names the one player this screen owns, on the
/// native side and in the event channel a widget test has to stub out.
const kHannaBeepPlayerId = 'reeftracker_hanna_beep';

class HannaMeterScreen extends ConsumerStatefulWidget {
  const HannaMeterScreen({super.key});

  @override
  ConsumerState<HannaMeterScreen> createState() => _HannaMeterScreenState();
}

class _HannaMeterScreenState extends ConsumerState<HannaMeterScreen> {
  late final HannaMeterSession _session;

  /// Checked method codes on the selection step.
  final Set<int> _selected = {};

  /// Index into [HannaMeterSession.meterTanks]; the first entry is
  /// preselected once the list arrives.
  int _meterTank = 0;

  /// Explicit save-target choice on the results step; null = resolve from
  /// the remembered location → tank mapping / active tank.
  int? _saveTankOverride;

  /// Results the user unchecked on the confirm step — a value they know is
  /// wrong (wrong reagent, spoiled cuvette). Kept visible and reversible,
  /// like a deselected environment chip; identity-keyed, the run objects
  /// live as long as the session.
  final Set<HannaMethodRun> _excludedRuns = {};

  /// Results marked with ↻ for another go on the meter. Marking excludes the
  /// value too — you only redo one you distrust, and a distrusted value must
  /// never save by accident.
  final Set<HannaMethodRun> _remeasureMarks = {};

  /// The runs handed to the running re-measure pass, held until it ends so
  /// the ones that produced a new value can be re-included in one shot.
  List<HannaMethodRun> _pendingPass = const [];

  List<ImportSource>? _sources;
  bool _saving = false;
  bool _saved = false;

  /// The reagent reaction timer on the runner step. The meter itself doesn't
  /// count the reaction/deproteinization waits its method leaflets prescribe,
  /// so the screen offers the common ones as one-tap presets.
  static const _timerPresets = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ];
  Timer? _timerTicker;
  DateTime? _timerEndsAt;
  Duration? _timerPreset;
  final _beepPlayer = AudioPlayer(playerId: kHannaBeepPlayerId);

  /// Whether this state currently holds the wakelock (measuring phase only).
  bool _wakelockOn = false;

  // --- environment capture (U37) ---------------------------------------------

  /// A shown environment value older than this is silently re-read when the
  /// save button is tapped (the user may have sat on the results step), the
  /// shown values remaining the fallback if the re-read fails.
  static const _envStaleAfter = Duration(minutes: 5);

  /// The selected environment values by paramKey (one winner per parameter,
  /// [selectEnvironmentValues]); null until a fetch has delivered anything.
  Map<String, EnvValue>? _envValues;

  /// Tank [_envValues] belongs to — display and the failure fallback both
  /// check it, so another tank's values are never shown or saved as this
  /// tank's environment.
  int? _envValuesTank;

  /// When [_envValues] was read — drives the age line and the staleness rule.
  DateTime? _envFetchedAt;

  bool _envFetching = false;

  /// Whether the last fetch ended with every source failing (drives the
  /// "unreachable" line; a partial failure just shows fewer chips).
  bool _envAllFailed = false;

  /// Parameters the user tapped off on the card — excluded from this save
  /// only; the persistent choice is the settings toggle.
  final Set<String> _envExcluded = {};

  /// Tank the current fetch/values belong to; a differing save target
  /// (initial entry, dropdown change) triggers a fresh fetch from the build.
  int? _envTankId;

  /// Monotonic fetch token: a slow stale fetch must not clobber a newer one.
  int _envFetchSeq = 0;

  @override
  void initState() {
    super.initState();
    _session = HannaMeterSession(ref.read(hannaMeterLinkFactoryProvider));
    _session.addListener(_onSession);
    unawaited(_session.connect());
    unawaited(
      ref.read(dbProvider).getAllImportSources().then((s) {
        if (mounted) setState(() => _sources = s);
      }),
    );
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    _setWakelock(false);
    unawaited(_beepPlayer.dispose());
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  /// Set once we've recorded this checker in the connected-devices inventory,
  /// so a reconnect/retry doesn't re-touch it every listener tick.
  bool _deviceCaptured = false;

  /// How many results the previous listener tick had — a growth means the
  /// meter just delivered another parameter's value. Restored values don't
  /// count, so an abandoned re-measure can't masquerade as a fresh result.
  int _completedSeen = 0;

  void _onSession() {
    if (!mounted) return;
    // Each finished parameter earns the same attention signal as the reagent
    // timer: the user is working on the meter (or across the room waiting on
    // a reaction), not watching the phone. Skips and a mid-run disconnect
    // don't add results, so they stay silent.
    final completed = [
      for (final r in _session.completedRuns)
        if (!r.remeasureAbandoned) r,
    ].length;
    if (completed > _completedSeen) {
      unawaited(HapticFeedback.vibrate());
      unawaited(_playBeep());
    }
    _completedSeen = completed;
    // A finished re-measure pass re-includes what it actually re-measured;
    // a target that came back without a new value stays unchecked, so a
    // value the user distrusted can't slip into the save by being skipped.
    if (_pendingPass.isNotEmpty &&
        _session.phase != HannaSessionPhase.measuring) {
      for (final run in _pendingPass) {
        if (!run.remeasureAbandoned) _excludedRuns.remove(run);
      }
      _pendingPass = const [];
    }
    // Record the checker in the connected-devices inventory (U36) the first
    // time it advertises its name — informational only; the read-only Settings
    // page lists it. The name (e.g. "HI97115 06150128") is the stable identity,
    // its leading token the model.
    final deviceName = _session.deviceName;
    if (!_deviceCaptured && deviceName != null && deviceName.isNotEmpty) {
      _deviceCaptured = true;
      unawaited(
        ref.read(dbProvider).ensureHannaDevice(
          identifier: deviceName,
          model: deviceName.split(' ').first,
        ),
      );
    }
    final measuring = _session.phase == HannaSessionPhase.measuring;
    _setWakelock(measuring);
    setState(() {
      if (_meterTank >= _session.meterTanks.length) _meterTank = 0;
      // The timer belongs to the runner step; don't let one tick on into
      // the results view.
      if (!measuring) _cancelTimer();
    });
  }

  /// Best-effort: a missing platform implementation (tests) must not surface.
  void _setWakelock(bool on) {
    if (on == _wakelockOn) return;
    _wakelockOn = on;
    unawaited(WakelockPlus.toggle(enable: on).catchError((_) {}));
  }

  String? get _selectedMeterTank =>
      _meterTank < _session.meterTanks.length
      ? _session.meterTanks[_meterTank]
      : null;

  /// The meter-side location the captured readings actually belong to: the
  /// name the result frames carried (that's what the meter logs them under,
  /// and what a later CSV export will say), falling back to the on-screen
  /// selection.
  String? get _location => _session.resultTankName ?? _selectedMeterTank;

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phase = _session.phase;
    // Mid-run (or with unsaved results) a stray back gesture must not
    // silently drop captured values.
    final guarded =
        !_saved &&
        (phase == HannaSessionPhase.measuring ||
            (phase == HannaSessionPhase.finished &&
                _session.completedRuns.isNotEmpty));
    return PopScope(
      canPop: !guarded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  phase == HannaSessionPhase.finished
                      ? l.hannaResultsTitle
                      : l.hannaConnectTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const ExperimentalChip(),
            ],
          ),
        ),
        body: switch (phase) {
          HannaSessionPhase.connecting => _connectingView(l),
          HannaSessionPhase.failed => _failedView(l),
          HannaSessionPhase.ready => _selectionView(l),
          HannaSessionPhase.measuring => _runnerView(l),
          HannaSessionPhase.finished => _resultsView(l),
        },
      ),
    );
  }

  // --- connecting / failed ---------------------------------------------------

  Widget _connectingView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final connectedToDevice = _session.deviceName != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              connectedToDevice ? l.hannaReadingSetup : l.hannaScanning,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.text),
            ),
            const SizedBox(height: 8),
            Text(
              connectedToDevice
                  ? (_session.deviceName ?? '')
                  : l.hannaScanHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final message = switch (_session.error) {
      HannaSessionErrorKind.unsupported => l.hannaErrUnsupported,
      HannaSessionErrorKind.bluetoothOff => l.hannaErrBluetoothOff,
      HannaSessionErrorKind.notFound => l.hannaErrNotFound,
      HannaSessionErrorKind.connectionLost => l.hannaErrConnectionLost,
      HannaSessionErrorKind.connectionFailed || null => l.hannaErrConnectionFailed,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled, size: 40, color: tokens.textDim),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.text),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => unawaited(_session.connect()),
              icon: const Icon(Icons.refresh),
              label: Text(l.hannaTryAgain),
            ),
          ],
        ),
      ),
    );
  }

  // --- selection -------------------------------------------------------------

  Widget _selectionView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final sets = ref.watch(hannaMethodSetsProvider).value ?? const [];
    final tanks = _session.meterTanks;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _meterCard(l),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            l.hannaExperimentalNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            l.hannaMeasureOnlyNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
          ),
        ),
        if (tanks.isNotEmpty) ...[
          SectionHeader(l.hannaAquarium),
          ReefCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                const ReefIconChip(Icons.waves),
                const SizedBox(width: 12),
                Expanded(
                  child: ReefSettingsDropdown<int>(
                    value: _meterTank,
                    items: [
                      for (var i = 0; i < tanks.length; i++) (i, tanks[i]),
                    ],
                    onChanged: (i) => setState(() => _meterTank = i),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (sets.isNotEmpty) ...[
          SectionHeader(l.hannaSetsTitle),
          ReefCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: sets.length,
              onReorderItem: (oldIndex, newIndex) {
                final reordered = List<HannaMethodSet>.of(sets);
                reordered.insert(newIndex, reordered.removeAt(oldIndex));
                unawaited(
                  ref.read(settingsProvider).setHannaMethodSets(reordered),
                );
              },
              // The dragged row leaves the card, so give it an opaque
              // lifted surface (the dark-theme card fill is translucent
              // — rows underneath would show through the bare row).
              proxyDecorator: (child, index, animation) => Material(
                elevation: 3,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (context, i) {
                final s = sets[i];
                return ReefSettingsRow(
                  key: ValueKey(s.name),
                  icon: Icons.playlist_add_check,
                  title: s.name,
                  description: l.hannaSetCount(s.codes.length),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: tokens.textDim,
                        ),
                        onSelected: (v) => unawaited(_onSetAction(s, v)),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'update',
                            child: Text(l.hannaSetUpdate),
                          ),
                          PopupMenuItem(value: 'delete', child: Text(l.delete)),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        // The padding keeps the 16 px glyph draggable
                        // with a finger.
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle,
                            size: 16,
                            color: tokens.textFaint,
                            semanticLabel: l.reorder,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(s.codes);
                  }),
                );
              },
            ),
          ),
        ],
        SectionHeader(l.hannaAllMethods),
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final m in kHannaMeterMethods)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    _methodLabel(l, m),
                    style: TextStyle(fontSize: 15, color: tokens.text),
                  ),
                  value: _selected.contains(m.code),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _selected.add(m.code);
                    } else {
                      _selected.remove(m.code);
                    }
                  }),
                ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _selected.isEmpty ? null : () => unawaited(_saveSet()),
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(l.hannaSaveSet),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => unawaited(
                  _session.startMeasurements([
                    for (final m in kHannaMeterMethods)
                      if (_selected.contains(m.code)) m,
                  ]),
                ),
          icon: const Icon(Icons.play_arrow),
          label: Text(l.hannaStartMeasurements),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _meterCard(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final info = _session.info;
    final battery = _session.battery;
    return ReefCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const ReefIconChip(Icons.bluetooth_connected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.deviceName ?? kHannaMeterNamePrefix,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                  ),
                ),
                if (battery != null || info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.hannaMeterStatus(battery ?? 0, info?.firmware ?? '—'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSetAction(HannaMethodSet set, String action) async {
    final settings = ref.read(settingsProvider);
    final sets = List<HannaMethodSet>.of(
      ref.read(hannaMethodSetsProvider).value ?? const [],
    );
    final i = sets.indexWhere((s) => s.name == set.name);
    if (i < 0) return;
    if (action == 'delete') {
      sets.removeAt(i);
    } else if (action == 'update') {
      if (_selected.isEmpty) return;
      sets[i] = HannaMethodSet(
        name: set.name,
        codes: [
          for (final m in kHannaMeterMethods)
            if (_selected.contains(m.code)) m.code,
        ],
      );
    }
    await settings.setHannaMethodSets(sets);
  }

  Future<void> _saveSet() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.hannaSaveSet),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: l.hannaSetName),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    // The dialog's exit transition still builds the TextField briefly after
    // the future completes — dispose after it has fully gone.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final settings = ref.read(settingsProvider);
    final sets = List<HannaMethodSet>.of(
      ref.read(hannaMethodSetsProvider).value ?? const [],
    );
    final codes = [
      for (final m in kHannaMeterMethods)
        if (_selected.contains(m.code)) m.code,
    ];
    final i = sets.indexWhere((s) => s.name == name);
    final entry = HannaMethodSet(name: name, codes: codes);
    if (i >= 0) {
      sets[i] = entry; // same name = overwrite, the "edit a set" path
    } else {
      sets.add(entry);
    }
    await settings.setHannaMethodSets(sets);
  }

  // --- runner ----------------------------------------------------------------

  void _startTimer(Duration preset) {
    _timerTicker?.cancel();
    setState(() {
      _timerPreset = preset;
      _timerEndsAt = DateTime.now().add(preset);
    });
    // Sub-second ticks so the displayed count never visibly skips a second.
    _timerTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final ends = _timerEndsAt;
      if (ends == null) return;
      if (DateTime.now().isBefore(ends)) {
        setState(() {}); // repaint the countdown
      } else {
        setState(_cancelTimer);
        unawaited(HapticFeedback.vibrate());
        unawaited(_playBeep());
      }
    });
  }

  /// Clears the ticker and countdown state; callers wrap in setState as
  /// needed (dispose must not).
  void _cancelTimer() {
    _timerTicker?.cancel();
    _timerTicker = null;
    _timerEndsAt = null;
    _timerPreset = null;
  }

  /// The attention signal for both the timer expiry and a completed
  /// measurement. Best-effort: if audio playback is unavailable the haptic
  /// and the on-screen change still carry it.
  Future<void> _playBeep() async {
    try {
      await _beepPlayer.play(AssetSource('sounds/timer_beep.wav'));
    } catch (_) {}
  }

  Duration get _timerRemaining {
    final ends = _timerEndsAt;
    if (ends == null) return Duration.zero;
    final ms = ends.difference(DateTime.now()).inMilliseconds;
    return Duration(seconds: ms <= 0 ? 0 : (ms / 1000).ceil());
  }

  String _timerLabel(AppLocalizations l, Duration d) => d.inSeconds < 60
      ? l.hannaTimerSec(d.inSeconds)
      : l.hannaTimerMin(d.inMinutes);

  Widget _timerCard(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final running = _timerEndsAt != null;
    final remaining = _timerRemaining;
    final chipStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    return ReefCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: running ? tokens.primary : tokens.textDim,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: running
                ? Row(
                    children: [
                      Text(
                        '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: ReefTokens.monoTextStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: l.hannaTimerStop,
                        onPressed: () => setState(_cancelTimer),
                        icon: Icon(Icons.close, color: tokens.textDim),
                      ),
                    ],
                  )
                : Text(
                    l.hannaTimerHint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
                  ),
          ),
          for (final preset in _timerPresets) ...[
            const SizedBox(width: 6),
            if (running && _timerPreset == preset)
              // Tapping the active preset restarts it — the common case when
              // timing the same reagent step for the next method.
              FilledButton.tonal(
                style: chipStyle,
                onPressed: () => _startTimer(preset),
                child: Text(_timerLabel(l, preset)),
              )
            else
              OutlinedButton(
                style: chipStyle,
                onPressed: () => _startTimer(preset),
                child: Text(_timerLabel(l, preset)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _runnerView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final current = _session.currentRun;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_session.remeasuring)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l.hannaMeasuringAgain,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
            ),
          ),
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              // The current pass only: a re-measure lists the parameters it
              // is redoing, not the whole session.
              for (final run in _session.passRuns)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _runIcon(run, tokens),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _methodLabel(l, run.method),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: run.status == HannaRunStatus.running
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: tokens.text,
                              ),
                            ),
                            if (run.status == HannaRunStatus.running)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  run.progressStep != null
                                      ? '${l.hannaFollowMeter} · ${l.hannaStepN(run.progressStep!)}'
                                      : l.hannaFollowMeter,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: tokens.textDim),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (run.status == HannaRunStatus.done)
                        Text(
                          _formatValue(run, prefs),
                          style: ReefTokens.monoTextStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.text,
                          ),
                        )
                      else if (run.status == HannaRunStatus.skipped)
                        Text(
                          l.hannaStatusSkipped,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: tokens.textFaint),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _timerCard(l),
        const SizedBox(height: 24),
        Row(
          children: [
            if (current != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(_session.skipCurrent()),
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text(l.hannaSkip),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => unawaited(_session.stopEarly()),
                icon: const Icon(Icons.stop, size: 18),
                label: Text(l.hannaFinishNow),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _runIcon(HannaMethodRun run, ReefTokens tokens) => switch (run.status) {
    HannaRunStatus.pending => Icon(
      Icons.radio_button_unchecked,
      size: 20,
      color: tokens.textFaint,
    ),
    HannaRunStatus.running => const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    HannaRunStatus.done => Icon(
      Icons.check_circle,
      size: 20,
      color: tokens.healthy,
    ),
    HannaRunStatus.skipped => Icon(
      Icons.remove_circle_outline,
      size: 20,
      color: tokens.textFaint,
    ),
  };

  // --- results ---------------------------------------------------------------

  Widget _resultsView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final results = _session.completedRuns;
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: tokens.textDim),
              const SizedBox(height: 16),
              Text(
                l.hannaNoResults,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: tokens.text),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: Text(l.close),
              ),
            ],
          ),
        ),
      );
    }

    final target = tanks.isEmpty ? null : _resolveSaveTank(tanks);
    final attachEnv = ref.watch(hannaAttachEnvironmentProvider).value ?? false;
    final envSources = target == null
        ? const <EnvironmentSource>[]
        : ref.watch(environmentSourcesProvider(target.id));
    if (target != null &&
        attachEnv &&
        envSources.isNotEmpty &&
        _envTankId != target.id &&
        !_envFetching) {
      // First entry to this step, or the save target changed: the shown
      // values (if any) belong to another tank. Fetch after this frame —
      // never during build. `_envTankId` is set synchronously so one build
      // schedules at most one fetch.
      _envTankId = target.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fetchEnvironment(target.id));
      });
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Covers both endings: a run cut short by a drop, and a meter that
        // went away while the user sat on this step. Either way the values
        // are safe and the ↻ buttons are gone — say why.
        if (!_session.canRemeasure)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.hannaResultsDisconnected,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.caution),
            ),
          ),
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++)
                _resultRow(
                  l,
                  prefs,
                  results[i],
                  last: i == results.length - 1,
                ),
            ],
          ),
        ),
        if (_remeasureMarks.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => unawaited(_startRemeasure()),
            icon: const Icon(Icons.replay, size: 18),
            label: Text(l.hannaRemeasureCount(_remeasureMarks.length)),
          ),
        ],
        if (target != null && envSources.isNotEmpty) ...[
          SectionHeader(l.environmentTitle),
          _environmentCard(l, attachEnv, target, results),
        ],
        if (target != null) ...[
          SectionHeader(l.hannaSaveTo),
          ReefCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                const ReefIconChip(Icons.waves),
                const SizedBox(width: 12),
                Expanded(
                  child: ReefSettingsDropdown<int>(
                    value: target.id,
                    enabled: !_saving,
                    items: [for (final t in tanks) (t.id, t.name)],
                    onChanged: (id) => setState(() => _saveTankOverride = id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            // Nothing checked = nothing to write; the environment readings
            // ride along with the session's values, they aren't a save of
            // their own.
            onPressed: _saving || _toSave(results).isEmpty
                ? null
                : () => unawaited(_save(target)),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done),
            label: Text(switch ((
              _toSave(results).length,
              _envToSave(results, target.id, attachEnv).length,
            )) {
              (0, _) => l.hannaNothingSelected,
              (final count, 0) => l.hannaSaveButton(count),
              (final count, final envCount) => l.hannaSaveButtonEnv(
                count,
                envCount,
              ),
            }),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => unawaited(_confirmDiscard()),
            child: Text(l.hannaDiscard),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  /// One result on the confirm step: the include checkbox (the whole row is
  /// its tap target), the value, and the ↻ mark that queues the parameter for
  /// another go on the meter. The caption carries whichever state the row is
  /// in — queued, gated, restored, redone — falling back to the meter
  /// timestamp.
  Widget _resultRow(
    AppLocalizations l,
    UnitPrefs prefs,
    HannaMethodRun run, {
    required bool last,
  }) {
    final tokens = ReefTokens.of(context);
    final check = _check(run);
    final locked = check == ParamValueCheck.impossible;
    final marked = _remeasureMarks.contains(run);
    final included = _included(run);
    // Once the link is gone the captured values are still savable, but
    // nothing can be measured again without a fresh session.
    final canRemeasure = !_saving && _session.canRemeasure;
    final takenAt = run.takenAt == null
        ? ''
        : formatDateTime(context, run.takenAt!, weekday: false);

    String caption;
    Color captionColor;
    if (marked) {
      caption = l.hannaRemeasureQueued;
      captionColor = tokens.primary;
    } else if (locked) {
      caption = l.hannaValueImpossible;
      captionColor = tokens.critical;
    } else if (run.remeasureAbandoned) {
      caption = l.hannaRemeasureKept;
      captionColor = tokens.caution;
    } else if (run.previousValue != null) {
      // A redone value, shown against what it replaced — the cheapest sanity
      // check on whether the second run actually fixed anything.
      caption =
          '$takenAt · '
          '${l.hannaPreviousValue(_formatAmount(run.previousValue!, run.method, prefs))}';
      captionColor = tokens.textFaint;
    } else {
      caption = takenAt;
      captionColor = tokens.textFaint;
    }

    return Container(
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.surfaceBorder)),
            ),
      child: InkWell(
        onTap: locked || _saving ? null : () => setState(() => _toggleIncluded(run)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              Checkbox(
                value: included,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                semanticLabel: l.hannaIncludeInSave,
                onChanged: locked || _saving
                    ? null
                    : (_) => setState(() => _toggleIncluded(run)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _methodLabel(l, run.method),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: included ? tokens.text : tokens.textDim,
                      ),
                    ),
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: captionColor),
                      ),
                  ],
                ),
              ),
              if (check == ParamValueCheck.implausible)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: tokens.caution,
                  ),
                ),
              Text(
                _formatValue(run, prefs),
                style: ReefTokens.monoTextStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: included ? tokens.text : tokens.textFaint,
                  decoration: included ? null : TextDecoration.lineThrough,
                ),
              ),
              if (canRemeasure)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: l.hannaRemeasure,
                  onPressed: () => setState(() => _toggleMark(run)),
                  icon: Icon(
                    marked ? Icons.replay_circle_filled : Icons.replay,
                    color: marked ? tokens.primary : tokens.textDim,
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Tapping the row/checkbox. Re-including a value also clears its ↻ mark —
  /// "save this" and "this needs redoing" contradict each other.
  void _toggleIncluded(HannaMethodRun run) {
    if (_excludedRuns.remove(run)) {
      _remeasureMarks.remove(run);
    } else {
      _excludedRuns.add(run);
    }
  }

  /// Tapping ↻. Marking excludes the value from the save; un-marking puts it
  /// back, the one-tap undo for a mis-tap.
  void _toggleMark(HannaMethodRun run) {
    if (_remeasureMarks.remove(run)) {
      _excludedRuns.remove(run);
    } else {
      _remeasureMarks.add(run);
      _excludedRuns.add(run);
    }
  }

  /// Hands the marked results back to the meter as one pass. The marks become
  /// the pass, so a failure to start puts them back rather than losing the
  /// user's selection.
  Future<void> _startRemeasure() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final targets = [
      for (final r in _session.completedRuns)
        if (_remeasureMarks.contains(r)) r,
    ];
    if (targets.isEmpty) return;
    setState(() {
      _remeasureMarks.clear();
      _pendingPass = targets;
    });
    if (await _session.remeasure(targets)) return;
    if (!mounted) return;
    setState(() {
      _pendingPass = const [];
      _remeasureMarks.addAll(targets);
    });
    messenger.showSnackBar(SnackBar(content: Text(l.hannaRemeasureFailed)));
  }

  ParamValueCheck _check(HannaMethodRun run) =>
      checkParamValue(run.method.paramKey, run.value ?? 0);

  /// Whether [run] goes into the save: impossible values never do (#31 sanity
  /// gate at meter scale, the checkbox is locked off), nor do the ones the
  /// user unchecked or marked for another go.
  bool _included(HannaMethodRun run) =>
      _check(run) != ParamValueCheck.impossible && !_excludedRuns.contains(run);

  /// The results that will actually be written — drives the save button's
  /// count, the environment card's "already measured" rule and [_save].
  List<HannaMethodRun> _toSave(List<HannaMethodRun> results) => [
    for (final r in results)
      if (_included(r)) r,
  ];

  int? _mappedTankId(String? location) {
    if (location == null) return null;
    for (final s in _sources ?? const <ImportSource>[]) {
      if (s.source == kHannaImportSource && s.location == location) {
        return s.tankId;
      }
    }
    return null;
  }

  Tank _resolveSaveTank(List<Tank> tanks) {
    for (final id in [_saveTankOverride, _mappedTankId(_location)]) {
      if (id == null) continue;
      for (final t in tanks) {
        if (t.id == id) return t;
      }
    }
    return ref.read(activeTankProvider) ?? tanks.first;
  }

  // --- environment capture (U37) ---------------------------------------------

  /// Reads every environment source of [tankId] (sequentially — one socket at
  /// a time is gentle on the meters, the U36 rule) and keeps the per-parameter
  /// winners. A total failure falls back to the values already shown, if any:
  /// best-effort context beats none, and the save must never block on the LAN.
  Future<void> _fetchEnvironment(int tankId) async {
    final sources = ref.read(environmentSourcesProvider(tankId));
    final seq = ++_envFetchSeq;
    final previous = _envValuesTank == tankId ? _envValues : null;
    final previousAt = _envValuesTank == tankId ? _envFetchedAt : null;
    if (!mounted) return;
    setState(() {
      _envTankId = tankId;
      _envFetching = true;
      _envValues = null;
      _envFetchedAt = null;
      _envAllFailed = false;
    });
    final results = <EnvSourceReadings>[];
    for (final s in sources) {
      try {
        results.add(await s.read());
      } catch (_) {
        // A dead device degrades the card, never the save.
      }
    }
    if (!mounted || seq != _envFetchSeq) return;
    setState(() {
      _envFetching = false;
      if (results.isNotEmpty) {
        _envValues = selectEnvironmentValues(results);
        _envValuesTank = tankId;
        _envFetchedAt = DateTime.now();
      } else {
        _envValues = previous;
        _envValuesTank = previous == null ? null : tankId;
        _envFetchedAt = previousAt;
        _envAllFailed = true;
      }
    });
  }

  /// The environment winners for [tankId] minus parameters this session
  /// itself measured — Hanna wins (the "pH only if not measured with Hanna"
  /// rule). User-tapped exclusions are *not* applied here, so an excluded
  /// chip stays visible (deselected) on the card; [_envToSave] applies them.
  Map<String, EnvValue> _envDisplay(List<HannaMethodRun> results, int tankId) {
    if (_envValuesTank != tankId) return const {};
    // Keyed on what actually saves: unchecking a bad Hanna pH lets the tank's
    // own device fill that parameter in instead of leaving a hole.
    final measured = {for (final r in _toSave(results)) r.method.paramKey};
    return {
      for (final e in (_envValues ?? const <String, EnvValue>{}).entries)
        if (!measured.contains(e.key)) e.key: e.value,
    };
  }

  /// What actually saves alongside the session: the displayed values minus
  /// the tapped-off chips; empty when the toggle is off.
  List<EnvValue> _envToSave(
    List<HannaMethodRun> results,
    int tankId,
    bool attach,
  ) {
    if (!attach) return const [];
    return [
      for (final e in _envDisplay(results, tankId).values)
        if (!_envExcluded.contains(e.paramKey)) e,
    ];
  }

  IconData _envIcon(String paramKey) => switch (paramKey) {
    'temperature' => Icons.device_thermostat,
    'salinity' => Icons.water_drop_outlined,
    _ => Icons.science_outlined,
  };

  String _formatEnvValue(EnvValue e, UnitPrefs prefs) {
    final def = kParameterByKey[e.paramKey];
    final pres = presentationForKey(e.paramKey, def?.unit ?? '', prefs);
    final v = pres.format(e.value);
    return pres.unitLabel.isEmpty ? v : '$v ${pres.unitLabel}';
  }

  /// The distinct device names behind the shown values, in chip order.
  String _envDeviceNames(List<EnvValue> display) {
    final names = <String>[];
    for (final e in display) {
      if (!names.contains(e.deviceName)) names.add(e.deviceName);
    }
    return names.join(' · ');
  }

  String _envAgeLabel(AppLocalizations l) {
    final at = _envFetchedAt;
    if (at == null) return '';
    final mins = DateTime.now().difference(at).inMinutes;
    return mins < 1 ? l.environmentJustNow : l.environmentMinutesAgo(mins);
  }

  Widget _environmentCard(
    AppLocalizations l,
    bool attach,
    Tank target,
    List<HannaMethodRun> results,
  ) {
    final tokens = ReefTokens.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final display = _envDisplay(results, target.id).values.toList()
      ..sort(
        (a, b) => (kParameterIndexByKey[a.paramKey] ?? 0).compareTo(
          kParameterIndexByKey[b.paramKey] ?? 0,
        ),
      );
    return ReefCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.environmentInclude,
                  style: TextStyle(fontSize: 15, color: tokens.text),
                ),
              ),
              if (attach)
                _envFetching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        tooltip: l.reefFactoryRefresh,
                        onPressed: _saving
                            ? null
                            : () => unawaited(_fetchEnvironment(target.id)),
                        icon: Icon(Icons.refresh, color: tokens.textDim),
                      ),
              Switch(
                value: attach,
                onChanged: _saving
                    ? null
                    : (v) {
                        unawaited(
                          ref
                              .read(settingsProvider)
                              .setHannaAttachEnvironment(v),
                        );
                        if (v) unawaited(_fetchEnvironment(target.id));
                      },
              ),
            ],
          ),
          if (attach && display.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final e in display)
                    FilterChip(
                      avatar: Icon(_envIcon(e.paramKey), size: 16),
                      tooltip: l.paramName(e.paramKey),
                      label: Text(_formatEnvValue(e, prefs)),
                      selected: !_envExcluded.contains(e.paramKey),
                      onSelected: _saving
                          ? null
                          : (on) => setState(() {
                              if (on) {
                                _envExcluded.remove(e.paramKey);
                              } else {
                                _envExcluded.add(e.paramKey);
                              }
                            }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                '${_envDeviceNames(display)} · ${_envAgeLabel(l)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textFaint),
              ),
            ),
          ] else if (attach && !_envFetching && _envAllFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                l.environmentUnreachable,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.caution),
              ),
            )
          else if (attach && !_envFetching && _envValuesTank == target.id)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                l.environmentAllMeasured,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textFaint),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save(Tank tank) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final results = _toSave(_session.completedRuns);
    if (results.isEmpty) return;

    // Same wrong-tank guard as the U32 import: this meter location was
    // previously saved into a different tank.
    final location = _location;
    final mapped = _mappedTankId(location);
    if (mapped != null && mapped != tank.id && location != null) {
      final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
      final mappedName = [
        for (final t in tanks)
          if (t.id == mapped) t.name,
      ].firstOrNull;
      if (mappedName != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.hannaImportWrongTankTitle),
            content: Text(
              l.hannaImportWrongTankBody(location, mappedName, tank.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.icpImportAnyway),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    // One batch confirm for implausible values (#31 at bulk scale).
    final implausible = [
      for (final r in results)
        if (_check(r) == ParamValueCheck.implausible) r,
    ];
    if (implausible.isNotEmpty) {
      final proceed = await _confirmImplausible(l, implausible);
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Environment capture (U37): re-read silently when the shown values
      // have gone stale (the user may have sat on the results step); the
      // shown values are the fallback — the save never blocks on the LAN.
      final attachEnv = ref.read(hannaAttachEnvironmentProvider).value ?? false;
      var envToSave = _envToSave(results, tank.id, attachEnv);
      if (envToSave.isNotEmpty &&
          (_envFetchedAt == null ||
              DateTime.now().difference(_envFetchedAt!) > _envStaleAfter)) {
        await _fetchEnvironment(tank.id);
        envToSave = _envToSave(results, tank.id, attachEnv);
      }

      final type = SetupType.fromName(tank.setupType);
      for (final key in {
        for (final r in results) r.method.paramKey,
        for (final e in envToSave) e.paramKey,
      }) {
        await db.addTrackedParameter(tank.id, key, type);
      }
      // One session = one reading group, each reading on its own meter
      // timestamp (the U32 rule — collapsing would break the rewind-diff).
      final groupId = newReadingGroupId();
      await db.insertImportedReadings(tank.id, [
        for (final r in results)
          (
            paramKey: r.method.paramKey,
            value: r.value!,
            takenAt: r.takenAt!,
            groupId: groupId,
          ),
        // Environment readings join the session's group at their own read
        // time — ordinary readings thereafter. The hannaLab watermark below
        // stays meter-only: these values never came from the meter's log.
        for (final e in envToSave)
          (
            paramKey: e.paramKey,
            value: e.value,
            takenAt: e.takenAt,
            groupId: groupId,
          ),
      ]);

      // Advance the shared hannaLab watermark so a later CSV export of the
      // meter's log doesn't re-import these readings; never move it back.
      ImportSource? prior;
      for (final s in _sources ?? const <ImportSource>[]) {
        if (s.tankId == tank.id && s.source == kHannaImportSource) prior = s;
      }
      // The watermark covers every value the meter produced this session, not
      // just the saved ones: a reading the user rejected here still sits in
      // the meter's own log, and must not come back through a later CSV
      // export of it.
      var upTo = results.first.takenAt!;
      for (final r in _session.completedRuns) {
        if (r.takenAt!.isAfter(upTo)) upTo = r.takenAt!;
      }
      final priorUpTo = prior?.importedUpTo;
      if (priorUpTo != null && priorUpTo.isAfter(upTo)) upTo = priorUpTo;
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tank.id,
          source: kHannaImportSource,
          location: Value(location ?? prior?.location),
          importedUpTo: Value(upTo),
          // Preserve a pending settings rewind — it belongs to the CSV path
          // and must survive a live session.
          rewound: Value(prior?.rewound ?? false),
        ),
      );

      _saved = true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.hannaSavedSnack(results.length + envToSave.length)),
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    List<HannaMethodRun> runs,
  ) {
    final prefs = ref.read(unitPrefsProvider);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.implausibleTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.implausibleIntro),
              const SizedBox(height: 12),
              for (final r in runs)
                if (kParameterByKey[r.method.paramKey] case final def?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Builder(
                      builder: (_) {
                        final pres = presentationForKey(
                          def.key,
                          def.unit,
                          prefs,
                        );
                        return Text(
                          l.implausibleValueLine(
                            l.paramName(def.key),
                            '${pres.format(r.value!)} ${pres.unitLabel}',
                            pres.format(def.plausibleMin!),
                            '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.hannaDiscardTitle),
        content: Text(l.hannaDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.hannaDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _saved = true; // disarm the pop guard
      context.pop();
    }
  }

  // --- shared helpers --------------------------------------------------------

  String _methodLabel(AppLocalizations l, HannaMeterMethod m) => m.lowRange
      ? l.hannaMethodLowRange(l.paramName(m.paramKey))
      : l.paramName(m.paramKey);

  String _formatValue(HannaMethodRun run, UnitPrefs prefs) =>
      _formatAmount(run.value ?? 0, run.method, prefs);

  String _formatAmount(double value, HannaMeterMethod method, UnitPrefs prefs) {
    final def = kParameterByKey[method.paramKey];
    final pres = presentationForKey(method.paramKey, def?.unit ?? '', prefs);
    return '${pres.format(value)} ${pres.unitLabel}';
  }
}
