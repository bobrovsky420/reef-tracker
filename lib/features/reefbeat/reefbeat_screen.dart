import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/lan_discovery.dart';
import '../../data/rb_device_link.dart';
import '../../data/rb_protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../devices/device_rename_dialog.dart';
import '../devices/discovery_sheet.dart';

/// One row of the dashboard list: either a single device, or every ReefWave
/// collapsed into a group (see [_entriesOf]).
class _ListEntry {
  const _ListEntry(this.devices, {this.isWaveGroup = false});
  final List<DeviceRecord> devices;
  final bool isWaveGroup;
}

/// Collapses the ReefWaves into one entry, positioned where the first of them
/// sat, and leaves every other device an entry of its own.
///
/// Grouping is decided from the stored model ([rbIsWaveModel]) rather than a
/// snapshot's `hw_type`, because the list is built before any device has been
/// read — the layout must not reshuffle as refreshes land.
List<_ListEntry> _entriesOf(List<DeviceRecord> devices) {
  final waves = [
    for (final d in devices)
      if (rbIsWaveModel(d.model)) d,
  ];
  final entries = <_ListEntry>[];
  var groupPlaced = false;
  for (final d in devices) {
    if (rbIsWaveModel(d.model)) {
      if (groupPlaced) continue;
      groupPlaced = true;
      entries.add(_ListEntry(waves, isWaveGroup: true));
    } else {
      entries.add(_ListEntry([d]));
    }
  }
  return entries;
}

/// Transient per-device live state held by the screen (not persisted): the
/// last refresh result.
class _Live {
  const _Live({this.loading = false, this.snapshot, this.error});
  final bool loading;
  final RbSnapshot? snapshot;
  final RbLinkError? error;
}

/// The Red Sea ReefBeat devices dashboard (U38): a persistent list of local
/// ReefBeat devices — ReefDose dosing pumps (2- or 4-head), ReefATO
/// auto-top-off units and ReefMat roller filters so far — read on open and by
/// one **Refresh all** above the list. Unlike the ReefFactory dashboard this is
/// purely informational: the cards show operational status, not values to save
/// as readings. Read-only — the app never writes to the devices.
class ReefBeatScreen extends ConsumerStatefulWidget {
  const ReefBeatScreen({super.key});

  @override
  ConsumerState<ReefBeatScreen> createState() => _ReefBeatScreenState();
}

class _ReefBeatScreenState extends ConsumerState<ReefBeatScreen> {
  /// Live snapshots keyed by device identifier (hwid).
  final Map<String, _Live> _live = {};

  /// Whether the on-open auto-read has already run (it must fire only once,
  /// not on every device-list stream emission).
  bool _autoRefreshed = false;

  Future<void> _refresh(DeviceRecord device) async {
    final address = device.address;
    if (address == null || address.isEmpty) return;
    setState(() => _live[device.identifier] = const _Live(loading: true));
    try {
      final snap = await ref.read(rbDeviceLinkProvider).readOnce(address);
      final db = ref.read(dbProvider);
      await db.touchDeviceSeen(device.identifier);
      // A full read can learn a more precise model than identification could —
      // a mat only reveals its width in `/configuration`. Persist it so the
      // card header stops saying the generic "RSMAT".
      if (snap.modelCode != device.model) {
        await db.updateDeviceModel(device.id, snap.modelCode);
      }
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(snapshot: snap));
    } on RbLinkException catch (e) {
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(error: e.error));
    }
  }

  /// Refreshes every device in turn (sequential — gentle on the devices, which
  /// each also serve the vendor app).
  Future<void> _refreshAll(List<DeviceRecord> devices) async {
    for (final d in devices) {
      await _refresh(d);
    }
  }

  String _errorText(AppLocalizations l, RbLinkError e) => switch (e) {
    RbLinkError.unreachable => l.reefBeatErrUnreachable,
    RbLinkError.timeout => l.reefBeatErrTimeout,
    RbLinkError.unsupportedModel => l.reefBeatErrUnsupported,
    RbLinkError.protocol => l.reefBeatErrProtocol,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final devicesAsync = ref.watch(reefBeatDevicesProvider);
    // Watched (not just read in _moveDevice) so the move-to-tank menu item's
    // visibility reacts to tanks being added/removed.
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    final activeTank = ref.watch(activeTankProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.reefBeatTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDiscoverySheet,
        icon: const Icon(Icons.add),
        label: Text(l.reefBeatAddDevice),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (allDevices) {
          // Tank-scoped view: the active tank's devices plus unassigned ones
          // (assignment lives in the card menu, so hiding them would make
          // them unreachable) — the ReefFactory dashboard's rule.
          // Manual card order (drag to reorder); devices that share a position
          // — an inventory never reordered — read alphabetically, as they did
          // before the order was user-controllable.
          final devices = [
            for (final d in allDevices)
              if (d.tankId == null || d.tankId == activeTank?.id) d,
          ]..sort((a, b) {
              final byOrder = a.displayOrder.compareTo(b.displayOrder);
              if (byOrder != 0) return byOrder;
              return deviceDisplayName(a).toLowerCase().compareTo(
                    deviceDisplayName(b).toLowerCase(),
                  );
            });
          // One-shot read of the visible devices when the screen opens;
          // everything after that is manual.
          if (!_autoRefreshed && devices.isNotEmpty) {
            _autoRefreshed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_refreshAll(devices));
            });
          }
          final anyLoading =
              devices.any((d) => _live[d.identifier]?.loading ?? false);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DisclaimerBanner(text: l.reefBeatDisclaimer),
                      const SizedBox(height: 12),
                      if (devices.isEmpty)
                        _EmptyState(
                          title: l.reefBeatEmptyTitle,
                          body: l.reefBeatEmptyBody,
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: anyLoading
                              ? null
                              : () => _refreshAll(devices),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(l.reefBeatRefreshAll),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              // Drag-orderable cards (the #13 list pattern, cards instead of
              // rows): the handle sits in each card's header. Wave pumps are
              // collapsed into a single entry (see [_entriesOf]) — a tank often
              // runs several and a full-width card each, for one number, wasted
              // the screen.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                sliver: Builder(
                  builder: (context) {
                    final entries = _entriesOf(devices);
                    return SliverReorderableList(
                      itemCount: entries.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final moved = [...entries];
                        moved.insert(newIndex, moved.removeAt(oldIndex));
                        // A group carries its members, so the wave pumps stay
                        // contiguous however the list is rearranged.
                        unawaited(
                          ref.read(dbProvider).reorderDevices([
                            for (final e in moved)
                              for (final d in e.devices) d.id,
                          ]),
                        );
                      },
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        final canReorder = entries.length > 1;
                        if (entry.isWaveGroup) {
                          return _WaveGroup(
                            key: ValueKey('waves-${entry.devices.first.id}'),
                            devices: entry.devices,
                            index: i,
                            canReorder: canReorder,
                            liveOf: (d) =>
                                _live[d.identifier] ?? const _Live(),
                            errorTextOf: (e) => _errorText(l, e),
                            onRename: _renameDevice,
                            onMove: (d) => tanks.any((t) => t.id != d.tankId)
                                ? () => _moveDevice(d)
                                : null,
                            onRemove: _confirmRemove,
                          );
                        }
                        final d = entry.devices.single;
                        return _DeviceCard(
                          key: ValueKey(d.id),
                          device: d,
                          index: i,
                          canReorder: canReorder,
                          live: _live[d.identifier] ?? const _Live(),
                          errorTextOf: (e) => _errorText(l, e),
                          onRename: () => _renameDevice(d),
                          // No other tank to move to → no menu item.
                          onMove: tanks.any((t) => t.id != d.tankId)
                              ? () => _moveDevice(d)
                              : null,
                          onRemove: () => _confirmRemove(d),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Renames [d]. The card header carries nothing but the name now, and a
  /// device's own name is a serial-suffixed code ("RSDOSE4-1752835676"), so a
  /// keeper-chosen one is what the list has to read by. An emptied field falls
  /// back to the model, as an unnamed device already does.
  Future<void> _renameDevice(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final name = await showDeviceRenameDialog(
      context,
      title: l.reefBeatRenameDevice,
      fieldLabel: l.reefBeatDeviceNameLabel,
      initial: d.name ?? '',
    );
    if (name == null) return;
    await ref.read(dbProvider).updateDeviceNameTank(
      d.id,
      name: name.isEmpty ? null : name,
      tankId: d.tankId,
    );
  }

  /// Reassigns [d] to a tank picked from a dialog (all tanks except its
  /// current one). Also serves as the initial assignment for an unassigned
  /// device.
  Future<void> _moveDevice(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tankId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.reefBeatSelectTank),
        children: [
          for (final t in tanks)
            if (t.id != d.tankId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t.id),
                child: Text(t.name),
              ),
        ],
      ),
    );
    if (tankId != null) {
      await ref
          .read(dbProvider)
          .updateDeviceNameTank(d.id, name: d.name, tankId: tankId);
    }
  }

  Future<void> _confirmRemove(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reefBeatRemove),
        content: Text(l.reefBeatRemoveConfirm(deviceDisplayName(d))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.reefBeatRemove),
          ),
        ],
      ),
    );
    if (ok == true) {
      _live.remove(d.identifier);
      await ref.read(dbProvider).deleteDevice(d.id);
    }
  }

  /// The primary add path (U39): scan the network and pick from what answered.
  /// Manual IP entry stays one tap away inside the sheet, for the setups a
  /// sweep can't reach.
  Future<void> _showDiscoverySheet() async {
    final db = ref.read(dbProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DeviceDiscoverySheet(
        kind: DiscoveredKind.reefbeat,
        onAdd: (found) => db.upsertReefBeatDevice(
          identifier: found.identifier,
          model: found.modelCode,
          address: found.address,
          // The friendly product name, as the manual flow defaults to — the
          // device's own name is a serial-suffixed code.
          name: found.modelDisplayName,
          tankId: ref.read(activeTankProvider)?.id,
        ),
        onUpdateAddress: (existing, found) =>
            db.updateDeviceAddress(existing.id, found.address),
        onManualEntry: () {
          Navigator.pop(ctx);
          unawaited(_showAddSheet());
        },
      ),
    );
    // Anything added or repointed while the sheet was open has no live status
    // yet, so pull one for the whole list.
    if (!mounted) return;
    final devices = ref.read(reefBeatDevicesProvider).value;
    if (devices != null && devices.isNotEmpty) unawaited(_refreshAll(devices));
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddDeviceSheet(
          link: ref.read(rbDeviceLinkProvider),
          tanks: ref.read(tanksProvider).value ?? const <Tank>[],
          activeTankId: ref.read(activeTankProvider)?.id,
          errorTextOf: (e) => _errorText(AppLocalizations.of(ctx), e),
          onAdd:
              ({
                required hwid,
                required model,
                required host,
                required name,
                required tankId,
                required snapshot,
              }) async {
                await ref.read(dbProvider).upsertReefBeatDevice(
                  identifier: hwid,
                  model: model,
                  address: host,
                  name: name,
                  tankId: tankId,
                );
                // The probe already read the device, so seed the new card with
                // that snapshot — it shows live status right away without a
                // second connect.
                if (mounted) {
                  setState(() => _live[hwid] = _Live(snapshot: snapshot));
                }
              },
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    super.key,
    required this.device,
    required this.index,
    required this.canReorder,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onMove,
    required this.onRemove,
  });

  final DeviceRecord device;

  /// Position in the reorderable list (what the drag handle reports).
  final int index;

  /// False for a one-card list — nothing to drag against, so no handle.
  final bool canReorder;
  final _Live live;
  final String Function(RbLinkError) errorTextOf;
  final VoidCallback onRename;

  /// Null when there is no other tank to move to (the item is hidden).
  final VoidCallback? onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final snap = live.snapshot;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(deviceDisplayName(device), style: t.titleMedium),
                ),
                if (canReorder)
                  ReorderableDragStartListener(
                    index: index,
                    // The padding keeps the 18 px glyph draggable with a
                    // finger (the schedule-list convention).
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: ReefTokens.of(context).textFaint,
                        semanticLabel: l.reorder,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') onRename();
                    if (v == 'move') onMove?.call();
                    if (v == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l.edit)),
                    if (onMove != null)
                      PopupMenuItem(
                        value: 'move',
                        child: Text(l.reefBeatMoveToTank),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l.reefBeatRemove),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Live status area.
            if (live.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (live.error != null)
              Text(
                errorTextOf(live.error!),
                style: t.bodyMedium?.copyWith(color: cs.error),
              )
            else if (snap?.dose != null)
              _PumpStatus(status: snap!.dose!)
            else if (snap?.ato != null)
              _AtoStatus(status: snap!.ato!)
            else if (snap?.mat != null)
              _MatStatus(status: snap!.mat!)
            else if (snap?.run != null)
              _RunStatus(status: snap!.run!)
            else if (snap?.light != null)
              _LightStatus(status: snap!.light!)
            else
              Text(
                l.reefBeatNotReadYet,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// The dosing status of one pump: device-level warnings + one row per head.
class _PumpStatus extends StatelessWidget {
  const _PumpStatus({required this.status});
  final RbDoseStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.timeError || status.batteryWarning) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.timeError)
                _WarnChip(
                  label: l.reefBeatTimeError,
                  color: tokens.critical,
                  softColor: tokens.criticalSoft,
                ),
              if (status.batteryWarning)
                _WarnChip(
                  label: l.reefBeatBatteryLow,
                  color: tokens.caution,
                  softColor: tokens.cautionSoft,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final (i, head) in status.heads.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _HeadRow(head: head),
        ],
      ],
    );
  }
}

/// The status of a ReefATO unit: warning chips (leak, sensor trouble, pump
/// running) above label–value rows — water level, probe temperature, today's
/// top-off activity, average evaporation, and the reservoir estimate with
/// days-left colored by the shared stock severity.
class _AtoStatus extends StatelessWidget {
  const _AtoStatus({required this.status});
  final RbAtoStatus status;

  /// The ATO reports millilitres but moves litres — show litres with one
  /// decimal from 1 L up, bare millilitres below.
  static String _fmtVol(double ml) => ml >= 1000
      ? '${(ml / 1000).toStringAsFixed(1)} L'
      : '${ml.round()} ml';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);

    final levelText = switch (status.waterLevel) {
      RbAtoWaterLevel.ok => l.reefBeatAtoLevelOk,
      RbAtoWaterLevel.low => l.reefBeatAtoLevelLow,
      RbAtoWaterLevel.high => l.reefBeatAtoLevelHigh,
      RbAtoWaterLevel.unknown => status.waterLevelRaw ?? '—',
    };
    final levelColor = switch (status.waterLevel) {
      RbAtoWaterLevel.ok => tokens.healthy,
      RbAtoWaterLevel.low || RbAtoWaterLevel.high => tokens.caution,
      RbAtoWaterLevel.unknown => tokens.text,
    };

    final fills = status.todayFills;
    final todayVol = status.todayVolumeMl;
    final todayText = [
      if (fills != null) l.reefBeatAtoFills(fills),
      if (todayVol != null) _fmtVol(todayVol),
    ].join(' · ');

    final days = status.daysTillEmpty;
    final left = status.volumeLeftMl;
    final reservoirText = [
      if (left != null) _fmtVol(left),
      if (days != null) l.reefBeatDaysLeft(days),
    ].join(' · ');
    final reservoirColor = days == null
        ? tokens.text
        : switch (rbStockSeverity(days)) {
            RbStockSeverity.healthy => tokens.healthy,
            RbStockSeverity.caution => tokens.caution,
            RbStockSeverity.critical => tokens.critical,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.leakAlarm || status.sensorWarning || status.isPumpOn) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.leakAlarm)
                _WarnChip(
                  label: l.reefBeatAtoLeak,
                  color: tokens.critical,
                  softColor: tokens.criticalSoft,
                ),
              if (status.sensorWarning)
                _WarnChip(
                  label: l.reefBeatAtoSensorError,
                  color: tokens.caution,
                  softColor: tokens.cautionSoft,
                ),
              if (status.isPumpOn)
                _WarnChip(
                  label: l.reefBeatAtoFilling,
                  color: tokens.healthy,
                  softColor: tokens.healthySoft,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _StatusRow(
          label: l.reefBeatAtoWaterLevel,
          value: levelText,
          valueColor: levelColor,
        ),
        if (status.temperatureC != null)
          _StatusRow(
            label: l.reefBeatAtoTemperature,
            value: '${status.temperatureC!.toStringAsFixed(1)} °C',
          ),
        if (todayText.isNotEmpty)
          _StatusRow(label: l.reefBeatAtoToday, value: todayText),
        if (status.dailyVolumeAvgMl != null)
          _StatusRow(
            label: l.reefBeatAtoEvaporation,
            value: l.reefBeatAtoPerDay(_fmtVol(status.dailyVolumeAvgMl!)),
          ),
        if (reservoirText.isNotEmpty)
          _StatusRow(
            label: l.reefBeatAtoReservoir,
            value: reservoirText,
            valueColor: reservoirColor,
          ),
      ],
    );
  }
}

/// The status of a ReefMat roller filter: warning chips (roll spent or running
/// low, a fouled sensor, auto-advance switched off, advancing right now) above
/// the roll gauge — fleece left of the roll's nominal length, draining and
/// colored by the shared stock severity — and the usage rows.
class _MatStatus extends StatelessWidget {
  const _MatStatus({required this.status});
  final RbMatStatus status;

  /// The mat reports centimetres but a roll is metres long — show metres with
  /// one decimal from 1 m up, whole centimetres below.
  static String _fmtLen(double cm) =>
      cm >= 100 ? '${(cm / 100).toStringAsFixed(1)} m' : '${cm.round()} cm';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);

    final severity = status.rollSeverity;
    final rollColor = switch (severity) {
      RbStockSeverity.healthy => tokens.healthy,
      RbStockSeverity.caution => tokens.caution,
      RbStockSeverity.critical => tokens.critical,
      null => tokens.text,
    };
    final rollSoftColor = switch (severity) {
      RbStockSeverity.critical => tokens.criticalSoft,
      _ => tokens.cautionSoft,
    };

    final remaining = status.remainingLengthCm;
    final total = status.rollLengthCm;
    final days = status.daysTillEndOfRoll;
    final installed = status.rollInstalledAt;

    // With no nominal roll length (an unparseable material name) there is no
    // denominator, so the gauge is dropped and the remaining length stands on
    // its own.
    final hasGauge = remaining != null && total != null && total > 0;
    final lengthText = switch ((remaining, total)) {
      (final double r, final double tot) when tot > 0 =>
        '${_fmtLen(r)} / ${_fmtLen(tot)}',
      (final double r, _) => _fmtLen(r),
      _ => '—',
    };

    // The roll is only called "running low" when it still has fleece on it —
    // once spent it gets the stronger chip instead.
    final lowChip = !status.rollSpent &&
        (severity == RbStockSeverity.caution ||
            severity == RbStockSeverity.critical);
    final chips = [
      if (status.rollSpent)
        _WarnChip(
          label: l.reefBeatMatRollEmpty,
          color: tokens.critical,
          softColor: tokens.criticalSoft,
        )
      else if (lowChip)
        _WarnChip(
          label: l.reefBeatMatRollLow,
          color: rollColor,
          softColor: rollSoftColor,
        ),
      if (status.uncleanSensor)
        _WarnChip(
          label: l.reefBeatMatCleanSensor,
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
      if (!status.autoAdvance)
        _WarnChip(
          label: l.reefBeatMatAutoAdvanceOff,
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
      if (status.isAdvancing)
        _WarnChip(
          label: l.reefBeatMatAdvancing,
          color: tokens.healthy,
          softColor: tokens.healthySoft,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 6, children: chips),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(l.reefBeatMatRoll, style: t.titleSmall)),
            const SizedBox(width: 8),
            if (days != null)
              Text(
                l.reefBeatDaysLeft(days),
                style: t.labelMedium?.copyWith(
                  color: rollColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (hasGauge) ...[
              Expanded(
                child: _DoseGauge(
                  fraction: (remaining / total).clamp(0.0, 1.0),
                  enabled: true,
                  fill: rollColor,
                ),
              ),
              const SizedBox(width: 10),
            ] else
              const Spacer(),
            Text(
              lengthText,
              style: ReefTokens.monoTextStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (status.usedTodayCm != null)
          _StatusRow(
            label: l.reefBeatMatUsedToday,
            value: _fmtLen(status.usedTodayCm!),
          ),
        if (status.dailyAverageCm != null)
          _StatusRow(
            label: l.reefBeatMatAverage,
            value: l.reefBeatMatPerDay(_fmtLen(status.dailyAverageCm!)),
          ),
        if (installed != null)
          _StatusRow(
            label: l.reefBeatMatInstalled,
            value: '${formatDate(installed)}  ·  '
                '${l.reefBeatMatRollAge(_daysSince(installed))}',
          ),
      ],
    );
  }

  /// Whole days the current roll has been running (never negative, so a device
  /// clock set slightly ahead reads as "0 days" rather than "-1").
  static int _daysSince(DateTime t) {
    final days = DateTime.now().difference(t).inDays;
    return days < 0 ? 0 : days;
  }
}

/// The status of a ReefRun pump controller: device-level chips above one block
/// per connected pump — its speed as a gauge, plus motor temperature and any
/// pump-level fault.
class _RunStatus extends StatelessWidget {
  const _RunStatus({required this.status});
  final RbRunStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);

    final pumps = [
      for (final p in status.pumps)
        if (!p.isEmptySocket) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.timeError || status.batteryWarning || status.sensorWarning)
          ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.timeError)
                _WarnChip(
                  label: l.reefBeatTimeError,
                  color: tokens.critical,
                  softColor: tokens.criticalSoft,
                ),
              if (status.batteryWarning)
                _WarnChip(
                  label: l.reefBeatBatteryLow,
                  color: tokens.caution,
                  softColor: tokens.cautionSoft,
                ),
              if (status.sensorWarning)
                _WarnChip(
                  label: l.reefBeatRunSensorOffline,
                  color: tokens.caution,
                  softColor: tokens.cautionSoft,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final (i, pump) in pumps.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _RunPumpRow(pump: pump),
        ],
      ],
    );
  }
}

/// One ReefRun socket: name and speed, a speed gauge, then motor temperature
/// and any fault chips.
class _RunPumpRow extends StatelessWidget {
  const _RunPumpRow({required this.pump});
  final RbRunPump pump;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final intensity = pump.intensity;
    final faulted = pump.faulted || pump.missingPump;

    final chips = [
      if (pump.missingPump)
        _WarnChip(
          label: l.reefBeatRunMissingPump,
          color: tokens.critical,
          softColor: tokens.criticalSoft,
        ),
      if (pump.missingSensor && pump.sensorControlled)
        _WarnChip(
          label: l.reefBeatRunMissingSensor,
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
      if (pump.faulted && !pump.missingPump)
        _WarnChip(
          label: l.reefBeatRunState(pump.state ?? ''),
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CircularGauge(percent: intensity, enabled: !faulted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      pump.name?.trim().isNotEmpty == true
                          ? pump.name!
                          : l.reefBeatRunPump(pump.number),
                      style: t.titleSmall?.copyWith(
                        color: faulted ? tokens.textDim : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The overflow (water-level) sensor drives this socket — a
                  // standing capability, not a fault, so it reads as a quiet
                  // green badge rather than a warning chip.
                  if (pump.sensorControlled) ...[
                    const SizedBox(width: 8),
                    _WarnChip(
                      label: l.reefBeatRunSensorBadge,
                      color: tokens.healthy,
                      softColor: tokens.healthySoft,
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (!pump.scheduleEnabled)
                    Text(
                      l.reefBeatRunScheduleOff,
                      style: t.labelMedium?.copyWith(color: tokens.textDim),
                    ),
                ],
              ),
              if (pump.temperatureC != null)
                _StatusRow(
                  label: l.reefBeatRunTemperature,
                  value: '${pump.temperatureC!.toStringAsFixed(1)} °C',
                ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: chips),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The status of a ReefLED fixture: warning chips and a gauge per output
/// channel, with the heatsink temperature below.
class _LightStatus extends StatelessWidget {
  const _LightStatus({required this.status});
  final RbLightStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);

    final chips = [
      if (status.timeError)
        _WarnChip(
          label: l.reefBeatTimeError,
          color: tokens.critical,
          softColor: tokens.criticalSoft,
        ),
      if (status.batteryWarning)
        _WarnChip(
          label: l.reefBeatBatteryLow,
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
      if (status.tiltSwitch)
        _WarnChip(
          label: l.reefBeatLightTilt,
          color: tokens.critical,
          softColor: tokens.criticalSoft,
        ),
      if (status.acclimationEnabled)
        _WarnChip(
          label: status.acclimationRemainingDays == null
              ? l.reefBeatLightAcclimationOn
              : l.reefBeatLightAcclimation(status.acclimationRemainingDays!),
          color: tokens.caution,
          softColor: tokens.cautionSoft,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 6, children: chips),
          const SizedBox(height: 10),
        ],
        // All three channels are listed whenever the fixture reports them,
        // including one sitting at 0 — an absent row would read as "the light
        // has no moon channel" rather than "the moon channel is off".
        if (status.whitePercent != null) ...[
          const SizedBox(height: 6),
          _ChannelBar(
            label: l.reefBeatLightWhite,
            percent: status.whitePercent!,
            fill: tokens.ledWhite,
          ),
        ],
        if (status.bluePercent != null) ...[
          const SizedBox(height: 6),
          _ChannelBar(
            label: l.reefBeatLightBlue,
            percent: status.bluePercent!,
            fill: tokens.ledBlue,
          ),
        ],
        if (status.moonPercent != null) ...[
          const SizedBox(height: 6),
          _ChannelBar(
            label: l.reefBeatLightMoon,
            percent: status.moonPercent!,
            fill: tokens.ledMoon,
          ),
        ],
        const SizedBox(height: 8),
        if (status.moonPhaseEnabled && status.moonPhaseName != null)
          _StatusRow(
            label: l.reefBeatLightMoonPhase,
            value: status.moonDay == null
                ? status.moonPhaseName!
                : l.reefBeatLightMoonDay(status.moonPhaseName!, status.moonDay!),
          ),
        if (status.fanPercent != null)
          _StatusRow(
            label: l.reefBeatLightFan,
            value: l.reefBeatPercent(status.fanPercent!),
          ),
        if (status.temperatureC != null)
          _StatusRow(
            label: l.reefBeatLightTemperature,
            value: '${status.temperatureC!.toStringAsFixed(1)} °C',
          ),
      ],
    );
  }
}

/// One light channel: name, gauge, percentage.
class _ChannelBar extends StatelessWidget {
  const _ChannelBar({
    required this.label,
    required this.percent,
    required this.fill,
  });

  final String label;
  final int percent;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: t.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: _DoseGauge(
            fraction: (percent / 100).clamp(0.0, 1.0),
            enabled: true,
            fill: fill,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            l.reefBeatPercent(percent),
            textAlign: TextAlign.right,
            style: ReefTokens.monoTextStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Every ReefWave on the dashboard, as one entry: a row of compact tiles
/// instead of a full-width card each.
///
/// A tank commonly runs two or more wave pumps, and each has exactly one number
/// worth showing — a full card apiece pushed everything else off the screen.
/// The tiles size themselves to fit on one row where they can and wrap into
/// balanced rows when they can't (4 pumps read 2 + 2, not 3 + 1).
class _WaveGroup extends StatelessWidget {
  const _WaveGroup({
    super.key,
    required this.devices,
    required this.index,
    required this.canReorder,
    required this.liveOf,
    required this.errorTextOf,
    required this.onRename,
    required this.onMove,
    required this.onRemove,
  });

  final List<DeviceRecord> devices;
  final int index;
  final bool canReorder;
  final _Live Function(DeviceRecord) liveOf;
  final String Function(RbLinkError) errorTextOf;
  final void Function(DeviceRecord) onRename;
  final VoidCallback? Function(DeviceRecord) onMove;
  final void Function(DeviceRecord) onRemove;

  /// Narrowest a tile may get before the row splits — a gauge plus an
  /// ellipsized name still reads at this width.
  static const double _minTile = 108;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.reefBeatWaveGroup,
                  style: t.labelLarge?.copyWith(color: tokens.textDim),
                ),
              ),
              if (canReorder)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: tokens.textFaint,
                      semanticLabel: l.reorder,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = devices.length;
              // Fit as many as the width allows, then rebalance so the rows are
              // even rather than leaving a lone tile on the last row.
              final maxColumns = ((constraints.maxWidth + _gap) /
                      (_minTile + _gap))
                  .floor()
                  .clamp(1, count);
              final rows = (count / maxColumns).ceil();
              final columns = (count / rows).ceil();
              final width =
                  (constraints.maxWidth - _gap * (columns - 1)) / columns;
              return Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final d in devices)
                    SizedBox(
                      width: width,
                      child: _WaveTile(
                        device: d,
                        live: liveOf(d),
                        errorTextOf: errorTextOf,
                        onRename: () => onRename(d),
                        onMove: onMove(d),
                        onRemove: () => onRemove(d),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One wave pump: its name and the forward output scheduled for right now,
/// tagged **Alternate** when the running interval reverses the flow.
///
/// The pump never reports its *live* speed (see rb_protocol.dart), so the
/// figure comes from the `/auto` schedule resolved against the current time of
/// day. Only the forward percentage is shown — reverse output and the
/// alternation durations are parsed but would crowd a tile this size without
/// telling a keeper anything they act on.
class _WaveTile extends StatelessWidget {
  const _WaveTile({
    required this.device,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onMove,
    required this.onRemove,
  });

  final DeviceRecord device;
  final _Live live;
  final String Function(RbLinkError) errorTextOf;
  final VoidCallback onRename;
  final VoidCallback? onMove;
  final VoidCallback onRemove;

  /// Minutes since local midnight — what the schedule is indexed by.
  static int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final status = live.snapshot?.wave;
    final scheduled = status?.scheduleApplies ?? true;
    final interval = status?.intervalAt(_minuteOfDay(DateTime.now()));
    final forward = interval?.forwardPercent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deviceDisplayName(device),
                    style: t.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') onRename();
                    if (v == 'move') onMove?.call();
                    if (v == 'remove') onRemove();
                  },
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: tokens.textFaint,
                  ),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l.edit)),
                    if (onMove != null)
                      PopupMenuItem(
                        value: 'move',
                        child: Text(l.reefBeatMoveToTank),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l.reefBeatRemove),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (live.loading)
              const SizedBox(
                height: _CircularGauge.size,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _CircularGauge(percent: forward, enabled: scheduled),
            const SizedBox(height: 6),
            if (live.error != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  errorTextOf(live.error!),
                  style: t.bodySmall?.copyWith(color: tokens.critical),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            // The running interval's direction is what a keeper reads off the
            // tile; an `auto` pump simply doing what it's scheduled to needs no
            // label, so only a non-auto mode is worth naming.
            else if (interval?.direction == 'alt')
              Text(
                l.reefBeatWaveAlternate,
                style: t.bodySmall?.copyWith(color: tokens.textDim),
              )
            else if (status?.mode != null && status!.mode != 'auto')
              Text(
                _modeText(l, status.mode!),
                style: t.bodySmall?.copyWith(color: tokens.textDim),
              ),
          ],
        ),
      ),
    );
  }
}

/// The firmware's mode string, localized where we know it and passed through
/// verbatim where we don't (firmware drift must not blank the row). `auto`
/// never reaches this — a scheduled pump carries no mode label.
String _modeText(AppLocalizations l, String mode) => switch (mode) {
  'manual' => l.reefBeatModeManual,
  _ => mode,
};

/// One label–value line of a status card: dim label left, mono value right.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: ReefTokens.monoTextStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? tokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// One dosing head: supplement name + remaining-days tag, a horizontal
/// dosed-today gauge, and any per-head warnings.
class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.head});
  final RbDoseHead head;

  /// Trims trailing ".0" so whole millilitres render bare ("40"), fractional
  /// ones with one decimal ("26.7") — matching the pump's own display.
  static String _fmtMl(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);

    final daily = head.dailyDose;
    final dosed = head.dosedToday;
    final days = head.remainingDays;
    final off = head.switchedOff;
    final daysColor = days == null
        ? tokens.textDim
        : switch (rbStockSeverity(days)) {
            RbStockSeverity.healthy => tokens.healthy,
            RbStockSeverity.caution => tokens.caution,
            RbStockSeverity.critical => tokens.critical,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                head.supplement?.trim().isNotEmpty == true
                    ? head.supplement!
                    : l.reefBeatHead(head.number),
                style: t.titleSmall?.copyWith(
                  color: off ? tokens.textDim : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (off)
              Text(
                l.reefBeatHeadOff,
                style: t.labelMedium?.copyWith(color: tokens.textDim),
              )
            else if (days != null)
              Text(
                l.reefBeatDaysLeft(days),
                style: t.labelMedium?.copyWith(
                  color: daysColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Today's progress: dosed so far vs the scheduled daily total. With no
        // schedule (daily dose absent/zero) the track stays empty — the mono
        // text still reports what was dosed.
        Row(
          children: [
            Expanded(
              child: _DoseGauge(
                fraction: (daily == null || daily <= 0)
                    ? 0
                    : (dosed / daily).clamp(0.0, 1.0),
                enabled: !off,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              daily == null
                  ? l.reefBeatDosedNoDaily(_fmtMl(dosed))
                  : l.reefBeatDosedOfDaily(_fmtMl(dosed), _fmtMl(daily)),
              style: ReefTokens.monoTextStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: off ? tokens.textDim : tokens.text,
              ),
            ),
          ],
        ),
        if (head.recalibrationRequired || head.missedVolume > 0) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (head.recalibrationRequired)
                _WarnChip(
                  label: l.reefBeatRecalibration,
                  color: tokens.caution,
                  softColor: tokens.cautionSoft,
                ),
              if (head.missedVolume > 0)
                _WarnChip(
                  label: l.reefBeatMissedDose(_fmtMl(head.missedVolume)),
                  color: tokens.critical,
                  softColor: tokens.criticalSoft,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A circular percentage gauge: a ring track with a fractional arc and the
/// percentage in the middle. Used for pump output — a ReefRun socket's speed
/// and a ReefWave's scheduled forward output — where the value is a standalone
/// setting rather than progress through a total, which is what the horizontal
/// [_DoseGauge] expresses.
class _CircularGauge extends StatelessWidget {
  const _CircularGauge({required this.percent, this.enabled = true});

  /// 0..100, or null when the device reported nothing (renders an empty ring
  /// with a dash rather than a misleading zero).
  final int? percent;
  final bool enabled;

  /// Sized to sit beside two or three label–value rows without dominating the
  /// card; the ring and label scale off it.
  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final value = percent;
    final color = enabled ? tokens.primary : tokens.textFaint;
    final label = value == null
        ? '—'
        : AppLocalizations.of(context).reefBeatPercent(value);

    return Semantics(
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: value == null ? 0 : (value / 100).clamp(0.0, 1.0),
            track: tokens.track,
            fill: color,
            strokeWidth: size / 9,
          ),
          child: Center(
            child: Text(
              label,
              style: ReefTokens.monoTextStyle.copyWith(
                fontSize: size / 4.6,
                fontWeight: FontWeight.w600,
                color: enabled ? tokens.text : tokens.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.strokeWidth,
  });

  final double fraction;
  final Color track;
  final Color fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, base);
    if (fraction <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 o'clock
      fraction * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}

/// A horizontal gauge: a rounded track with a fractional fill. Used for a
/// head's dosed-today progress and for the mat's remaining roll.
class _DoseGauge extends StatelessWidget {
  const _DoseGauge({
    required this.fraction,
    required this.enabled,
    this.fill,
  });

  /// 0..1 — the portion of today's scheduled volume already delivered (or, on
  /// the mat card, the fleece left on the roll).
  final double fraction;
  final bool enabled;

  /// Fill color; defaults to `primary` (dimmed when not [enabled]). The mat
  /// card passes the roll's severity color so a spent roll reads red.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: tokens.track)),
            FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: ColoredBox(
                color: fill ?? (enabled ? tokens.primary : tokens.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarnChip extends StatelessWidget {
  const _WarnChip({
    required this.label,
    required this.color,
    required this.softColor,
  });

  final String label;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bottom sheet: enter an IP/hostname, we probe and auto-identify the device,
/// then let the user name it and pick a tank before adding.
class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({
    required this.link,
    required this.tanks,
    required this.activeTankId,
    required this.errorTextOf,
    required this.onAdd,
  });

  final RbDeviceLink link;
  final List<Tank> tanks;
  final int? activeTankId;
  final String Function(RbLinkError) errorTextOf;
  final Future<void> Function({
    required String hwid,
    required String model,
    required String host,
    required String? name,
    required int? tankId,
    required RbSnapshot snapshot,
  }) onAdd;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _host = TextEditingController();
  final _name = TextEditingController();
  bool _probing = false;
  String? _error;
  RbSnapshot? _found;
  int? _tankId;

  @override
  void initState() {
    super.initState();
    _tankId = widget.activeTankId;
  }

  @override
  void dispose() {
    _host.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _probing = true;
      _error = null;
      _found = null;
    });
    try {
      final snap = await widget.link.readOnce(host);
      if (!mounted) return;
      setState(() {
        _found = snap;
        // Default the name to the friendly product name ("ReefDose 4") — the
        // device's own default name is a serial-suffixed code. Uses the
        // snapshot's refined model, so a mat reads "ReefMat 250".
        if (_name.text.isEmpty) {
          _name.text = snap.modelDisplayName;
        }
      });
    } on RbLinkException catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.errorTextOf(e.error));
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final found = _found;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reefBeatAddDevice, style: t.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _host,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.reefBeatHostLabel,
              hintText: l.reefBeatHostHint,
              helperText: l.reefBeatHostHelp,
              helperMaxLines: 2,
            ),
            onSubmitted: (_) => _probe(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (found != null) ...[
            const SizedBox(height: 16),
            Text(
              l.reefBeatFound(found.modelDisplayName),
              style: t.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (found.dose != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  for (final h in found.dose!.heads)
                    if (h.supplement?.trim().isNotEmpty == true) h.supplement!,
                ].join('   ·   '),
                style: t.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.reefBeatDeviceNameLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _tankId,
              decoration: InputDecoration(labelText: l.reefBeatTankLabel),
              items: [
                for (final tk in widget.tanks)
                  DropdownMenuItem(value: tk.id, child: Text(tk.name)),
              ],
              onChanged: (v) => setState(() => _tankId = v),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              const SizedBox(width: 8),
              if (found == null)
                FilledButton(
                  onPressed: _probing ? null : _probe,
                  child: _probing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.reefBeatCheck),
                )
              else
                FilledButton(
                  onPressed: () async {
                    await widget.onAdd(
                      hwid: found.info.hwid,
                      model: found.modelCode,
                      host: _host.text.trim(),
                      name: _name.text.trim().isEmpty
                          ? null
                          : _name.text.trim(),
                      tankId: _tankId,
                      snapshot: found,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l.reefBeatAddDevice),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
