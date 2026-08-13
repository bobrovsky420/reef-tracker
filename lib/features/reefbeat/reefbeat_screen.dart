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
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/device_values.dart';
import '../devices/device_details_dialog.dart';
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

/// Transient per-device live state (not persisted): the last refresh result.
/// Held by the unified Devices screen (U41), so switching the vendor filter
/// doesn't discard snapshots the user just refreshed.
class RbLive {
  const RbLive({this.loading = false, this.snapshot, this.error});
  final bool loading;
  final RbSnapshot? snapshot;
  final RbLinkError? error;
}

/// Reads one ReefBeat device, returning the outcome for the caller to store.
/// Touches `lastSeenAt`, and persists a more precise model when the full read
/// learns one — a mat only reveals its width in `/configuration`, so the card
/// header stops saying the generic "RSMAT".
Future<RbLive> rbReadDevice(WidgetRef ref, DeviceRecord device) async {
  final address = device.address;
  if (address == null || address.isEmpty) return const RbLive();
  try {
    final snap = await ref.read(rbDeviceLinkProvider).readOnce(address);
    final db = ref.read(dbProvider);
    await db.touchDeviceSeen(device.identifier);
    if (snap.modelCode != device.model) {
      await db.updateDeviceModel(device.id, snap.modelCode);
    }
    return RbLive(snapshot: snap);
  } on RbLinkException catch (e) {
    return RbLive(error: e.error);
  }
}

String rbErrorText(AppLocalizations l, RbLinkError e) => switch (e) {
  RbLinkError.unreachable => l.reefBeatErrUnreachable,
  RbLinkError.timeout => l.reefBeatErrTimeout,
  RbLinkError.unsupportedModel => l.reefBeatErrUnsupported,
  RbLinkError.protocol => l.reefBeatErrProtocol,
};

/// Classifies a ReefControl's primary water reading against ReefTracker's
/// effective bounds for the active aquarium. Firmware `level` fields are
/// deliberately irrelevant: every screen must agree with the ranges the
/// keeper configured in this app.
@visibleForTesting
Zone reefControlProbeZone(
  RbControlProbe probe,
  Map<String, ZoneBounds> boundsByParam,
) {
  final paramKey = switch (probe.type) {
    'ec' => 'salinity',
    'ph' => 'ph',
    'orp' => 'orp',
    _ => null,
  };
  if (paramKey == null) return Zone.unknown;

  final rawValue = probe.type == 'ec' ? probe.salinityPpt : probe.value;
  if (rawValue == null) return Zone.unknown;
  final canonicalValue = paramKey == 'salinity' ? pptToSg(rawValue) : rawValue;
  return (boundsByParam[paramKey] ?? const ZoneBounds()).classify(
    canonicalValue,
  );
}

/// ReefTracker-zone classification for a combined probe's temperature sensor.
/// Like [reefControlProbeZone], this intentionally ignores the firmware's
/// `temp_level` label.
@visibleForTesting
Zone reefControlProbeTemperatureZone(
  RbControlProbe probe,
  Map<String, ZoneBounds> boundsByParam,
) {
  final value = probe.temperatureC;
  if (value == null) return Zone.unknown;
  return (boundsByParam['temperature'] ?? const ZoneBounds()).classify(value);
}

/// Formats a ReefControl probe's primary value. Salinity arrives in ppt but
/// goes through canonical SG so the app's salinity preference controls both
/// its unit and precision.
@visibleForTesting
String formatReefControlProbeValue(RbControlProbe probe, UnitPrefs prefs) {
  if (probe.type == 'ec') {
    final ppt = probe.salinityPpt;
    if (ppt == null) return '—';
    final presentation = presentationFor('salinity', 'SG', 3, prefs);
    return '${presentation.format(pptToSg(ppt))} '
        '${presentation.unitLabel}';
  }

  final value = probe.value;
  if (value == null) return '—';
  final unit = switch (probe.type) {
    'orp' => probe.measurementUnit ?? 'mV',
    _ => probe.measurementUnit ?? '',
  };
  final formatted = formatDeviceValue(value);
  return unit.isEmpty ? formatted : '$formatted $unit';
}

/// Test seam for the complete ReefControl status body without making the
/// implementation widget part of the app's public UI surface.
@visibleForTesting
Widget reefControlStatusForTesting(RbControlStatus status) =>
    _ControlStatus(status: status);

/// The Red Sea section of the Devices screen (U41): status cards for the
/// ReefDose pumps, ReefATO units, ReefMat filters, ReefRun controllers, ReefLED
/// fixtures, (grouped) ReefWave pumps and ReefControl probe controllers.
/// ReefControl is the measuring device in this otherwise status-only vendor,
/// so its card alone carries Save; the other ReefBeat cards remain read-only.
class RbDeviceSection extends ConsumerWidget {
  const RbDeviceSection({
    super.key,
    required this.devices,
    required this.live,
    required this.onSave,
    required this.onRemoved,
  });

  /// Already filtered to the active tank and sorted by the parent.
  final List<DeviceRecord> devices;
  final Map<String, RbLive> live;

  /// Null while the parent has a save in flight — the ReefControl card's Save
  /// button disables for the duration. Status-only Red Sea models ignore it.
  final void Function(DeviceRecord device, RbSnapshot snap)? onSave;
  final void Function(String identifier) onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Watched (not just read in _moveDevice) so the move-to-tank menu item's
    // visibility reacts to tanks being added/removed.
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    // Wave pumps are collapsed into a single entry (see [_entriesOf]) — a tank
    // often runs several and a full-width card each, for one number, wasted
    // the screen.
    final entries = _entriesOf(devices);
    return SliverReorderableList(
      itemCount: entries.length,
      onReorderItem: (oldIndex, newIndex) {
        final moved = [...entries];
        moved.insert(newIndex, moved.removeAt(oldIndex));
        // A group carries its members, so the wave pumps stay contiguous
        // however the list is rearranged.
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
            liveOf: (d) => live[d.identifier] ?? const RbLive(),
            errorTextOf: (e) => rbErrorText(l, e),
            onRename: (d) => _renameDevice(context, ref, d),
            onMove: (d) => tanks.any((t) => t.id != d.tankId)
                ? () => _moveDevice(context, ref, d)
                : null,
            onRemove: (d) => _confirmRemove(context, ref, d),
          );
        }
        final d = entry.devices.single;
        return _DeviceCard(
          key: ValueKey(d.id),
          device: d,
          index: i,
          canReorder: canReorder,
          tank: _tankFor(d.tankId, tanks),
          live: live[d.identifier] ?? const RbLive(),
          errorTextOf: (e) => rbErrorText(l, e),
          onRename: () => _renameDevice(context, ref, d),
          onSave: rbIsControlModel(d.model) && onSave != null
              ? (snap) => onSave!(d, snap)
              : null,
          // No other tank to move to → no menu item.
          onMove: tanks.any((t) => t.id != d.tankId)
              ? () => _moveDevice(context, ref, d)
              : null,
          onShowQueue: rbIsDoseModel(d.model)
              ? () => _showDosingQueue(context, ref, d)
              : null,
          onRemove: () => _confirmRemove(context, ref, d),
        );
      },
    );
  }

  static Tank? _tankFor(int? id, List<Tank> tanks) {
    if (id == null) return null;
    for (final tank in tanks) {
      if (tank.id == id) return tank;
    }
    return null;
  }

  /// Renames [d]. The card header carries nothing but the name now, and a
  /// device's own name is a serial-suffixed code ("RSDOSE4-1752835676"), so a
  /// keeper-chosen one is what the list has to read by. An emptied field falls
  /// back to the model, as an unnamed device already does.
  Future<void> _renameDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
    final l = AppLocalizations.of(context);
    final name = await showDeviceRenameDialog(
      context,
      title: l.reefBeatRenameDevice,
      fieldLabel: l.reefBeatDeviceNameLabel,
      initial: d.name ?? '',
    );
    if (name == null) return;
    await ref
        .read(dbProvider)
        .updateDeviceNameTank(
          d.id,
          name: name.isEmpty ? null : name,
          tankId: d.tankId,
        );
  }

  /// Reassigns [d] to a tank picked from a dialog (all tanks except its
  /// current one). Also serves as the initial assignment for an unassigned
  /// device.
  Future<void> _moveDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
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

  /// Shows what [d] still has scheduled for today (`/dosing-queue`). Read on
  /// open rather than with the card — only a ReefDose serves it, and it is a
  /// detail worth one extra request when asked for, not on every refresh.
  Future<void> _showDosingQueue(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
    final address = d.address;
    if (address == null || address.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DosingQueueSheet(
        title: deviceDisplayName(d),
        // The queue names heads by abbreviation only; the last refresh's heads
        // carry the abbreviation → supplement mapping (see [RbDoseHead]).
        status: live[d.identifier]?.snapshot?.dose,
        load: () => ref.read(rbDeviceLinkProvider).readDosingQueue(address),
        errorTextOf: (e) => rbErrorText(AppLocalizations.of(ctx), e),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
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
      onRemoved(d.identifier);
      await ref.read(dbProvider).deleteDevice(d.id);
    }
  }
}

/// The ReefBeat add path (U39): scan the network and pick from what answered.
/// Manual IP entry stays one tap away inside the sheet, for the setups a sweep
/// can't reach. [onSeed] carries the probe's snapshot into the new card; the
/// discovery half instead asks the caller to [onAdded] — anything added or
/// repointed there has no live status yet.
Future<void> showRbAddFlow(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String identifier, RbSnapshot snap) onSeed,
  required VoidCallback onAdded,
}) async {
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
        unawaited(showRbManualSheet(context, ref, onSeed: onSeed));
      },
    ),
  );
  onAdded();
}

/// The type-an-IP half of the add flow, reached from the discovery sheet.
/// Public only so a widget test can open it without driving a network sweep.
@visibleForTesting
Future<void> showRbManualSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String identifier, RbSnapshot snap) onSeed,
}) async {
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
        errorTextOf: (e) => rbErrorText(AppLocalizations.of(ctx), e),
        findExisting: (identifier) =>
            ref.read(dbProvider).deviceByIdentifier(identifier),
        onAdd:
            ({
              required hwid,
              required model,
              required host,
              required name,
              required tankId,
              required snapshot,
            }) async {
              await ref
                  .read(dbProvider)
                  .upsertReefBeatDevice(
                    identifier: hwid,
                    model: model,
                    address: host,
                    name: name,
                    tankId: tankId,
                  );
              onSeed(hwid, snapshot);
            },
      ),
    ),
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    super.key,
    required this.device,
    required this.index,
    required this.canReorder,
    required this.tank,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onSave,
    required this.onMove,
    required this.onShowQueue,
    required this.onRemove,
  });

  final DeviceRecord device;

  /// Position in the reorderable list (what the drag handle reports).
  final int index;

  /// False for a one-card list — nothing to drag against, so no handle.
  final bool canReorder;
  final Tank? tank;
  final RbLive live;
  final String Function(RbLinkError) errorTextOf;
  final VoidCallback onRename;

  /// Non-null only for ReefControl, and null while a save is in flight.
  final void Function(RbSnapshot snap)? onSave;

  /// Null when there is no other tank to move to (the item is hidden).
  final VoidCallback? onMove;

  /// Null for anything but a ReefDose — only those serve a dosing queue.
  final VoidCallback? onShowQueue;
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
                    if (v == 'save' &&
                        snap?.control != null &&
                        tank != null &&
                        onSave != null) {
                      onSave!(snap!);
                    }
                    if (v == 'rename') onRename();
                    if (v == 'move') onMove?.call();
                    if (v == 'queue') onShowQueue?.call();
                    if (v == 'details') {
                      unawaited(showDeviceDetailsDialog(context, device));
                    }
                    if (v == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    if (snap?.control != null)
                      PopupMenuItem(
                        value: 'save',
                        enabled: tank != null && onSave != null,
                        child: Text(l.save),
                      ),
                    PopupMenuItem(value: 'rename', child: Text(l.edit)),
                    if (onMove != null)
                      PopupMenuItem(
                        value: 'move',
                        child: Text(l.reefBeatMoveToTank),
                      ),
                    if (onShowQueue != null)
                      PopupMenuItem(
                        value: 'queue',
                        child: Text(l.reefBeatDosingQueue),
                      ),
                    PopupMenuItem(
                      value: 'details',
                      child: Text(l.devicesDetails),
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
            else if (snap?.control != null)
              _ControlStatus(status: snap!.control!)
            else
              Text(
                l.reefBeatNotReadYet,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            // Only ReefControl saves measurements; other Red Sea models do
            // not need a tank merely to display their operational status.
            if (rbIsControlModel(device.model) && tank == null) ...[
              const SizedBox(height: 10),
              Text(
                l.reefFactoryNoTank,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A ReefControl Lite/Pro card keeps every attached probe together. Each probe
/// gets one parameter row; a combined probe's temperature sensor gets its own
/// labelled row immediately beneath it, and an attached leak detector gets the
/// same green-dry/red-leak row as ReefATO. Numeric values use the app's
/// configured units and ranges, never the controller's presentation metadata.
class _ControlStatus extends ConsumerWidget {
  const _ControlStatus({required this.status});

  final RbControlStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final tokens = ReefTokens.of(context);
    final boundsByParam = {
      for (final parameter
          in ref.watch(trackedParametersProvider).value ??
              const <ResolvedParameter>[])
        parameter.paramKey: parameter.bounds,
    };

    Color? colorFor(RbControlProbe probe) =>
        switch (reefControlProbeZone(probe, boundsByParam)) {
          Zone.green => tokens.healthy,
          Zone.amber => tokens.caution,
          Zone.red => tokens.critical,
          Zone.unknown => null,
        };

    Color? temperatureColorFor(RbControlProbe probe) =>
        switch (reefControlProbeTemperatureZone(probe, boundsByParam)) {
          Zone.green => tokens.healthy,
          Zone.amber => tokens.caution,
          Zone.red => tokens.critical,
          Zone.unknown => null,
        };

    String labelFor(RbControlProbe probe) => switch (probe.type) {
      'ec' => l.paramName('salinity'),
      'ph' => l.paramName('ph'),
      'orp' => l.paramName('orp'),
      _ => probe.type.toUpperCase(),
    };

    final probes = status.waterProbes.toList(growable: false);
    final leakProbe = status.leakProbe;
    if (probes.isEmpty && leakProbe == null) {
      return Text(
        l.reefBeatNotReadYet,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: tokens.textDim),
      );
    }

    return Column(
      children: [
        for (final (index, probe) in probes.indexed) ...[
          if (index > 0) const Divider(height: 18),
          _StatusRow(
            label: labelFor(probe),
            value: formatReefControlProbeValue(probe, prefs),
            valueColor: colorFor(probe),
            labelFontWeight: Theme.of(context).textTheme.titleSmall?.fontWeight,
          ),
          if (probe.temperatureC case final temperature?)
            _StatusRow(
              label: l.paramName('temperature'),
              value: formatDeviceTempC(temperature, prefs),
              valueColor: temperatureColorFor(probe),
            ),
        ],
        if (leakProbe != null) ...[
          if (probes.isNotEmpty) const Divider(height: 18),
          _StatusRow(
            label: l.reefBeatAtoLeakSensor,
            value: switch (leakProbe.detected) {
              true => l.reefBeatAtoLeak,
              false => l.reefBeatAtoLeakDry,
              null => '—',
            },
            valueColor: switch (leakProbe.detected) {
              true => tokens.critical,
              false => tokens.healthy,
              null => null,
            },
          ),
        ],
      ],
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
class _AtoStatus extends ConsumerWidget {
  const _AtoStatus({required this.status});
  final RbAtoStatus status;

  /// The ATO reports millilitres but moves litres — show litres with one
  /// decimal from 1 L up, bare millilitres below.
  static String _fmtVol(double ml) =>
      ml >= 1000 ? '${formatLocaleNumber(ml / 1000, 1)} L' : '${ml.round()} ml';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);

    final levelText = switch (status.waterLevel) {
      RbAtoWaterLevel.ok => l.reefBeatAtoLevelOk,
      RbAtoWaterLevel.below => l.reefBeatAtoLevelLow,
      RbAtoWaterLevel.above => l.reefBeatAtoLevelAbove,
      RbAtoWaterLevel.unknown => status.waterLevelRaw ?? '—',
    };
    final levelColor = switch (status.waterLevel) {
      RbAtoWaterLevel.ok => tokens.healthy,
      RbAtoWaterLevel.below || RbAtoWaterLevel.above => tokens.caution,
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
            value: formatDeviceTempC(
              status.temperatureC!,
              ref.watch(unitPrefsProvider),
            ),
          ),
        // Only an attached, enabled sensor earns the row — an absent one would
        // otherwise read as "dry", which is exactly the wrong reassurance.
        // Known statuses are localized; an unrecognized one shows verbatim
        // (the waterLevelRaw convention).
        if (status.leakSensorActive)
          _StatusRow(
            label: l.reefBeatAtoLeakSensor,
            value: switch (status.leakStatusRaw) {
              'dry' => l.reefBeatAtoLeakDry,
              'rodi_water_leak' => l.reefBeatAtoLeakRodi,
              final String raw => raw,
              null => '—',
            },
            valueColor: status.leakAlarm ? tokens.critical : tokens.healthy,
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
      cm >= 100 ? '${formatLocaleNumber(cm / 100, 1)} m' : '${cm.round()} cm';

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

    // "End of roll" is raised only when the mat itself says so (its `mode`);
    // until then an urgent roll gets the "running low" chip, colored by the
    // severity — the firmware's level and remaining length both read empty
    // long before the fleece is actually gone.
    final lowChip =
        !status.rollSpent &&
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
            value:
                '${formatDate(installed)}  ·  '
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
        if (status.timeError ||
            status.batteryWarning ||
            status.sensorWarning) ...[
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
class _RunPumpRow extends ConsumerWidget {
  const _RunPumpRow({required this.pump});
  final RbRunPump pump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      // A full cup and over-skimming are the non-operational states a keeper
      // acts on routinely, so they get their own plain labels instead of the
      // generic raw-state chip ("full_cup" / "over-skimming").
      if (pump.faulted && !pump.missingPump)
        _WarnChip(
          label: pump.fullCup
              ? l.reefBeatRunFullCup
              : pump.overSkimming
              ? l.reefBeatRunOverSkimming
              : l.reefBeatRunState(pump.state ?? ''),
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
                  value: formatDeviceTempC(
                    pump.temperatureC!,
                    ref.watch(unitPrefsProvider),
                  ),
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
class _LightStatus extends ConsumerWidget {
  const _LightStatus({required this.status});
  final RbLightStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                : l.reefBeatLightMoonDay(
                    status.moonPhaseName!,
                    status.moonDay!,
                  ),
          ),
        if (status.fanPercent != null)
          _StatusRow(
            label: l.reefBeatLightFan,
            value: l.reefBeatPercent(status.fanPercent!),
          ),
        if (status.temperatureC != null)
          _StatusRow(
            label: l.reefBeatLightTemperature,
            value: formatDeviceTempC(
              status.temperatureC!,
              ref.watch(unitPrefsProvider),
            ),
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

/// Every ReefWave on the dashboard, as one card: one row per pump, laid out
/// like a ReefRun's sockets.
///
/// A tank commonly runs two or more wave pumps, and each has exactly one number
/// worth showing — a full card apiece pushed everything else off the screen.
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
  final RbLive Function(DeviceRecord) liveOf;
  final String Function(RbLinkError) errorTextOf;
  final void Function(DeviceRecord) onRename;
  final VoidCallback? Function(DeviceRecord) onMove;
  final void Function(DeviceRecord) onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;

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
                  child: Text(l.reefBeatWaveGroup, style: t.titleMedium),
                ),
                if (canReorder)
                  ReorderableDragStartListener(
                    index: index,
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
              ],
            ),
            const SizedBox(height: 10),
            for (final (i, d) in devices.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _WavePumpRow(
                device: d,
                live: liveOf(d),
                errorTextOf: errorTextOf,
                onRename: () => onRename(d),
                onMove: onMove(d),
                onRemove: () => onRemove(d),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One wave pump inside the group card: the forward output scheduled for right
/// now as a gauge, the pump's name beside it, and its own overflow menu.
///
/// The pump never reports its *live* speed (see rb_protocol.dart), so the
/// figure comes from the `/auto` schedule resolved against the current time of
/// day. Only the forward percentage is shown — reverse output and the
/// alternation durations are parsed but would crowd the row without telling a
/// keeper anything they act on.
class _WavePumpRow extends StatelessWidget {
  const _WavePumpRow({
    required this.device,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onMove,
    required this.onRemove,
  });

  final DeviceRecord device;
  final RbLive live;
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

    return Row(
      children: [
        if (live.loading)
          const SizedBox(
            width: _CircularGauge.size,
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
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceDisplayName(device),
                style: t.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              // The gauge reads as a plain dash when the pump can't be reached;
              // the reason is the one extra line the row still earns.
              if (live.error != null)
                Text(
                  errorTextOf(live.error!),
                  style: t.bodySmall?.copyWith(color: tokens.critical),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') onRename();
            if (v == 'move') onMove?.call();
            if (v == 'details') {
              unawaited(showDeviceDetailsDialog(context, device));
            }
            if (v == 'remove') onRemove();
          },
          icon: Icon(Icons.more_vert, size: 18, color: tokens.textFaint),
          padding: EdgeInsets.zero,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text(l.edit)),
            if (onMove != null)
              PopupMenuItem(value: 'move', child: Text(l.reefBeatMoveToTank)),
            PopupMenuItem(value: 'details', child: Text(l.devicesDetails)),
            PopupMenuItem(value: 'remove', child: Text(l.reefBeatRemove)),
          ],
        ),
      ],
    );
  }
}

/// One label–value line of a status card: dim label left, mono value right.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelFontWeight,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? labelFontWeight;

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
                fontWeight: labelFontWeight,
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

/// Trims trailing ".0" so whole millilitres render bare ("40"), fractional
/// ones with one locale-formatted decimal ("26,7" for a comma locale, #102) —
/// matching the pump's own display. Shared by the head rows and the
/// dosing-queue sheet.
String _fmtMl(double v) => formatLocaleNumberTrim(v);

/// One dosing head: supplement name + remaining-days tag, a horizontal
/// dosed-today gauge, and any per-head warnings.
class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.head});
  final RbDoseHead head;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);

    final daily = head.dailyDose;
    final days = head.remainingDays;
    final off = head.switchedOff;
    // The gauge measures the schedule alone: manual dosing is delivered on top
    // of the plan, so folding it into the fraction both overfills the bar and
    // hides whether anything is still due. It gets its own suffix below.
    final auto = head.autoDosedToday;
    final manual = head.manualDosedToday;
    final remaining = head.scheduledRemaining;

    // With no schedule to measure against there is nothing to be "through", so
    // the value line falls back to the plain total — and when every drop of it
    // was hand-dosed it says so, instead of repeating itself in the suffix.
    final String valueText;
    if (daily != null && daily > 0) {
      valueText = l.reefBeatDosedOfDaily(_fmtMl(auto), _fmtMl(daily));
    } else if (manual > 0 && auto == 0) {
      valueText = l.reefBeatDosedManual(_fmtMl(manual));
    } else {
      valueText = l.reefBeatDosedNoDaily(_fmtMl(head.dosedToday));
    }

    // Third line, kept honest by only appearing when it adds something: a head
    // that finished its plan with no manual dosing is already fully described
    // by a full bar and "8 / 8 ml".
    final doses = head.dosesToday;
    final dailyDoses = head.dailyDoses;
    final String? progressText = (remaining == null || off)
        ? null
        : [
            remaining > 0
                ? l.reefBeatDoseDue(_fmtMl(remaining))
                : l.reefBeatPlanComplete,
            if (doses != null && dailyDoses != null)
              l.reefBeatDoseCount(doses, dailyDoses),
          ].join(' · ');
    final manualText = manual > 0 && (remaining != null || auto > 0)
        ? l.reefBeatDosedManualExtra(_fmtMl(manual))
        : null;
    final showProgressRow =
        manualText != null || (remaining != null && remaining > 0 && !off);

    // Screen readers get the two volumes spelled out rather than the terse
    // "44 / 44 ml", which gives no clue which number is the plan.
    final semanticsLabel = [
      daily != null && daily > 0
          ? l.reefBeatDosedSemantics(_fmtMl(auto), _fmtMl(daily))
          : valueText,
      if (manualText != null) l.reefBeatDosedManualSemantics(_fmtMl(manual)),
      ?progressText,
    ].join(', ');
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
        // Today's progress through the schedule: auto-dosed so far vs the
        // scheduled daily total. With no schedule (daily dose absent/zero) the
        // track stays empty — the mono text still reports what was dosed.
        // Missed-dose recovery can over-deliver, so the fraction is clamped
        // while the text stays truthful ("48 / 44 ml").
        Semantics(
          container: true,
          excludeSemantics: true,
          label: semanticsLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DoseGauge(
                      fraction: (daily == null || daily <= 0)
                          ? 0
                          : (auto / daily).clamp(0.0, 1.0),
                      enabled: !off,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    valueText,
                    style: ReefTokens.monoTextStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: off ? tokens.textDim : tokens.text,
                    ),
                  ),
                ],
              ),
              if (showProgressRow) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progressText ?? '',
                        style: t.bodySmall?.copyWith(color: tokens.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (manualText != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        manualText,
                        style: t.bodySmall?.copyWith(
                          color: off ? tokens.textDim : tokens.caution,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
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
  const _DoseGauge({required this.fraction, required this.enabled, this.fill});

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bottom sheet: what a ReefDose still has scheduled for today, read live from
/// its `/dosing-queue` when the sheet opens. The pump drops each dose from the
/// queue as it delivers it, so an empty list is a finished day, not a fault.
class _DosingQueueSheet extends StatefulWidget {
  const _DosingQueueSheet({
    required this.title,
    required this.status,
    required this.load,
    required this.errorTextOf,
  });

  /// The device's display name — the sheet's own title says what is listed.
  final String title;

  /// The pump's last-read status, used to resolve each queued dose's head
  /// abbreviation to the supplement the card names. Null before a successful
  /// refresh, in which case the rows fall back to the abbreviation.
  final RbDoseStatus? status;
  final Future<List<RbDoseQueueEntry>> Function() load;
  final String Function(RbLinkError) errorTextOf;

  @override
  State<_DosingQueueSheet> createState() => _DosingQueueSheetState();
}

class _DosingQueueSheetState extends State<_DosingQueueSheet> {
  List<RbDoseQueueEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final entries = await widget.load();
      if (!mounted) return;
      setState(() => _entries = entries);
    } on RbLinkException catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.errorTextOf(e.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final entries = _entries;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reefBeatDosingQueue, style: t.titleLarge),
          const SizedBox(height: 2),
          Text(
            widget.title,
            style: t.bodySmall?.copyWith(color: tokens.textDim),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else if (entries == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (entries.isEmpty)
            Text(
              l.reefBeatDosingQueueEmpty,
              style: t.bodyMedium?.copyWith(color: tokens.textDim),
            )
          else ...[
            Text(
              l.reefBeatDosingQueueTotal(
                entries.length,
                _fmtMl(entries.fold(0, (sum, e) => sum + (e.volumeMl ?? 0))),
              ),
              style: t.labelMedium?.copyWith(color: tokens.textDim),
            ),
            const SizedBox(height: 10),
            // The queue can be long (a KH head alone runs a dozen doses a
            // day), so it scrolls inside the sheet rather than growing past it.
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _QueueRow(
                  entry: entries[i],
                  head: widget.status?.headForShortName(entries[i].head),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One queued dose: when it is due, which head it is for, how much.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.entry, required this.head});
  final RbDoseQueueEntry entry;

  /// The head the pump's abbreviation resolved to, or null when nothing
  /// matched — see [RbDoseStatus.headForShortName].
  final RbDoseHead? head;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final volume = entry.volumeMl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay(hour: entry.hour, minute: entry.minute)),
          style: ReefTokens.monoTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // Named as the card names it, so a queued "Zin" reads "Zinc". With
          // no matching head the pump's own abbreviation stands — it is still
          // more use than nothing.
          child: Text(
            switch (head) {
              final RbDoseHead h when h.supplement?.trim().isNotEmpty == true =>
                h.supplement!.trim(),
              final RbDoseHead h => l.reefBeatHead(h.number),
              _ when entry.head?.trim().isNotEmpty == true =>
                entry.head!.trim(),
              _ => '—',
            },
            style: t.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (volume != null) ...[
          const SizedBox(width: 8),
          Text(
            l.reefBeatDosingQueueVolume(_fmtMl(volume)),
            style: ReefTokens.monoTextStyle.copyWith(
              fontSize: 13,
              color: tokens.textDim,
            ),
          ),
        ],
      ],
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
    required this.findExisting,
    required this.onAdd,
  });

  final RbDeviceLink link;
  final List<Tank> tanks;
  final int? activeTankId;
  final String Function(RbLinkError) errorTextOf;

  /// The row already registered under the probed `hwid`, if any (#75). The
  /// sheet has no notion of an existing device — it prefills the *product*
  /// name and the *active* tank — so adding one twice would overwrite both.
  /// It refuses instead and says so; re-pointing a moved device is the
  /// discovery sheet's job, which matches by identifier and updates only the
  /// address.
  final Future<DeviceRecord?> Function(String identifier) findExisting;

  final Future<void> Function({
    required String hwid,
    required String model,
    required String host,
    required String? name,
    required int? tankId,
    required RbSnapshot snapshot,
  })
  onAdd;

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

  /// Display name of the already-registered device the probe landed on (#75).
  /// Non-null puts the sheet in its dead-end state: the message, and Close.
  String? _duplicateOf;

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
      final existing = await widget.findExisting(snap.info.hwid);
      if (!mounted) return;
      if (existing != null) {
        setState(() => _duplicateOf = deviceDisplayName(existing));
        return;
      }
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
    final duplicateOf = _duplicateOf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      // Scrollable like the Apex add sheet: the keyboard is up from frame one
      // (autofocus) and at large text scale the probe result + fields would
      // otherwise overflow with the Add button unreachable (#103, the #44
      // class).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reefBeatAddDevice, style: t.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _host,
              autofocus: true,
              // Frozen once the probe lands on an already-added device: with the
              // Check button gone there is nothing left to do here but close.
              enabled: duplicateOf == null,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.reefBeatHostLabel,
                hintText: l.reefBeatHostHint,
                helperText: l.reefBeatHostHelp,
                helperMaxLines: 2,
              ),
              onSubmitted: (_) => _probe(),
            ),
            if (duplicateOf != null) ...[
              const SizedBox(height: 10),
              Text(
                l.deviceAlreadyAdded(duplicateOf),
                style: t.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
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
                      if (h.supplement?.trim().isNotEmpty == true)
                        h.supplement!,
                  ].join('   ·   '),
                  style: t.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.reefBeatDeviceNameLabel,
                ),
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
                if (duplicateOf != null)
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.close),
                  )
                else ...[
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
