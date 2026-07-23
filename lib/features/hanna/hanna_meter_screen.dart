import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
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

  List<ImportSource>? _sources;
  bool _saving = false;
  bool _saved = false;

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
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {
      if (_meterTank >= _session.meterTanks.length) _meterTank = 0;
    });
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

  Widget _runnerView(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final current = _session.currentRun;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final run in _session.runs)
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_session.endedByDisconnect)
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
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == results.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.surfaceBorder),
                          ),
                        ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _methodLabel(l, results[i].method),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.text,
                              ),
                            ),
                            if (results[i].takenAt != null)
                              Text(
                                formatDateTime(
                                  context,
                                  results[i].takenAt!,
                                  weekday: false,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.textFaint),
                              ),
                          ],
                        ),
                      ),
                      if (_check(results[i]) != ParamValueCheck.ok)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: _check(results[i]) == ParamValueCheck.impossible
                                ? tokens.critical
                                : tokens.caution,
                          ),
                        ),
                      Text(
                        _formatValue(results[i], prefs),
                        style: ReefTokens.monoTextStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
            onPressed: _saving ? null : () => unawaited(_save(target)),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done),
            label: Text(l.hannaSaveButton(_saveableOf(results).length)),
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

  ParamValueCheck _check(HannaMethodRun run) =>
      checkParamValue(run.method.paramKey, run.value ?? 0);

  /// Everything except impossible values — those never save (#31 sanity gate
  /// at meter scale); the red warning icon on the row is their explanation.
  List<HannaMethodRun> _saveableOf(List<HannaMethodRun> results) => [
    for (final r in results)
      if (_check(r) != ParamValueCheck.impossible) r,
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

  Future<void> _save(Tank tank) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final results = _saveableOf(_session.completedRuns);
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
      final type = SetupType.fromName(tank.setupType);
      for (final key in {for (final r in results) r.method.paramKey}) {
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
      ]);

      // Advance the shared hannaLab watermark so a later CSV export of the
      // meter's log doesn't re-import these readings; never move it back.
      ImportSource? prior;
      for (final s in _sources ?? const <ImportSource>[]) {
        if (s.tankId == tank.id && s.source == kHannaImportSource) prior = s;
      }
      var upTo = results.first.takenAt!;
      for (final r in results) {
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
        SnackBar(content: Text(l.hannaSavedSnack(results.length))),
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

  String _formatValue(HannaMethodRun run, UnitPrefs prefs) {
    final def = kParameterByKey[run.method.paramKey];
    final pres = presentationForKey(
      run.method.paramKey,
      def?.unit ?? '',
      prefs,
    );
    return '${pres.format(run.value ?? 0)} ${pres.unitLabel}';
  }
}
