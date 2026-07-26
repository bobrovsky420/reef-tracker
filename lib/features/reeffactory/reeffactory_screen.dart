import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/lan_discovery.dart';
import '../../data/rf_device_link.dart';
import '../../data/rf_protocol.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../devices/device_rename_dialog.dart';
import '../devices/discovery_sheet.dart';

/// Filters a device's live [readings] down to what should be persisted, applying
/// three rules (pure, so it is unit-tested directly):
///  1. values are converted to the catalog's canonical unit — the Salinity
///     Guardian reports ppt, but salinity is stored as specific gravity;
///  2. physically impossible values are dropped (a save shouldn't store noise);
///  3. **temperature source** — a non-Temperature-Controller device's
///     temperature (i.e. the Salinity Guardian's) is dropped when a dedicated
///     Temperature Controller (`RFTC01`) is present, so the controller is the
///     single authoritative temperature source. With no controller, the
///     Guardian's temperature is kept.
List<({String paramKey, double value})> rfReadingsToSave({
  required String? deviceModel,
  required List<RfReading> readings,
  required bool hasTempController,
}) {
  return [
    for (final r in readings.map(
      (r) => (
        paramKey: r.paramKey,
        value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
      ),
    ))
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible &&
          !(r.paramKey == 'temperature' &&
              deviceModel != kRfTempControllerModel &&
              hasTempController))
        r,
  ];
}

/// Transient per-device live state held by the screen (not persisted): the last
/// refresh result. Saving is a separate, explicit action.
class _Live {
  const _Live({this.loading = false, this.snapshot, this.error});
  final bool loading;
  final RfSnapshot? snapshot;
  final RfLinkError? error;
}

/// The ReefFactory devices dashboard (U36): a persistent list of local meters,
/// read on open and by one **Refresh all** above the list, each card carrying a
/// separate **Save** (persist the shown values as measurements). Read-only —
/// the app never writes to the devices.
class ReefFactoryScreen extends ConsumerStatefulWidget {
  const ReefFactoryScreen({super.key});

  @override
  ConsumerState<ReefFactoryScreen> createState() => _ReefFactoryScreenState();
}

class _ReefFactoryScreenState extends ConsumerState<ReefFactoryScreen> {
  /// Live snapshots keyed by device identifier (serial).
  final Map<String, _Live> _live = {};

  /// Whether the on-open auto-read has already run (it must fire only once,
  /// not on every device-list stream emission).
  bool _autoRefreshed = false;

  Tank? _tankFor(int? id, List<Tank> tanks) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _refresh(DeviceRecord device) async {
    final address = device.address;
    if (address == null || address.isEmpty) return;
    setState(() => _live[device.identifier] = const _Live(loading: true));
    try {
      final snap = await ref.read(rfDeviceLinkProvider).readOnce(address);
      await ref.read(dbProvider).touchDeviceSeen(device.identifier);
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(snapshot: snap));
    } on RfLinkException catch (e) {
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(error: e.error));
    }
  }

  /// Refreshes every device in turn (sequential — one socket at a time is gentle
  /// on the meters, which each also serve the vendor cloud app).
  Future<void> _refreshAll(List<DeviceRecord> devices) async {
    for (final d in devices) {
      await _refresh(d);
    }
  }

  /// The values from [snap] to persist for [device], given the full device list
  /// (needed for the temperature-source rule). Only a controller assigned to
  /// the *same tank* suppresses the Guardian's temperature — one tank's
  /// controller says nothing about another tank's water. See [rfReadingsToSave].
  List<({String paramKey, double value})> _valuesToSave(
    DeviceRecord device,
    RfSnapshot snap,
    List<DeviceRecord> devices,
  ) =>
      rfReadingsToSave(
        deviceModel: device.model,
        readings: snap.readings,
        hasTempController: devices.any(
          (d) =>
              d.model == kRfTempControllerModel && d.tankId == device.tankId,
        ),
      );

  /// Persists one reading group for [tank]. Ensures each parameter is tracked
  /// first so it appears on the dashboard.
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

  Future<void> _save(DeviceRecord device, RfSnapshot snap) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final devices = ref.read(reefFactoryDevicesProvider).value ?? const [];
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tank = _tankFor(device.tankId, tanks);
    if (tank == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.reefFactoryNoTank)));
      return;
    }
    final values = _valuesToSave(device, snap, devices);
    if (values.isEmpty) return;
    try {
      await _persistValues(tank, values);
      messenger.showSnackBar(
        SnackBar(content: Text(l.reefFactorySavedSnack(values.length))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(e.toString()))));
    }
  }

  /// Saves the last-refreshed values of every device at once. Readings destined
  /// for the same tank are merged into one group (so a Salinity Guardian's
  /// salinity, a pH Monitor's pH and a Temperature Controller's temperature on
  /// one tank land together), deduped by parameter.
  Future<void> _saveAll(List<DeviceRecord> devices) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final byTank = <int, Map<String, ({String paramKey, double value})>>{};
    final tankById = <int, Tank>{};
    var skippedNoTank = false;
    for (final d in devices) {
      final snap = _live[d.identifier]?.snapshot;
      if (snap == null) continue;
      final tank = _tankFor(d.tankId, tanks);
      if (tank == null) {
        skippedNoTank = true;
        continue;
      }
      final values = _valuesToSave(d, snap, devices);
      if (values.isEmpty) continue;
      final bucket = byTank.putIfAbsent(tank.id, () => {});
      for (final v in values) {
        bucket[v.paramKey] = v;
      }
      tankById[tank.id] = tank;
    }
    if (byTank.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(skippedNoTank ? l.reefFactoryNoTank : l.reefFactoryNothingToSave),
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
      messenger.showSnackBar(
        SnackBar(content: Text(l.reefFactorySavedSnack(total))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(e.toString()))));
    }
  }

  String _errorText(AppLocalizations l, RfLinkError e) => switch (e) {
    RfLinkError.unreachable => l.reefFactoryErrUnreachable,
    RfLinkError.timeout => l.reefFactoryErrTimeout,
    RfLinkError.unsupportedModel => l.reefFactoryErrUnsupported,
    RfLinkError.protocol => l.reefFactoryErrProtocol,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final devicesAsync = ref.watch(reefFactoryDevicesProvider);
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    final activeTank = ref.watch(activeTankProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.reefFactoryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDiscoverySheet,
        icon: const Icon(Icons.add),
        label: Text(l.reefFactoryAddDevice),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (allDevices) {
          // Tank-scoped view: only the active tank's devices. Unassigned
          // devices stay visible on every tank — assignment now lives in the
          // card menu, so hiding them would make them unreachable.
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
          // everything after that is manual. (Periodic auto-refresh stays
          // deferred.)
          if (!_autoRefreshed && devices.isNotEmpty) {
            _autoRefreshed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_refreshAll(devices));
            });
          }
          final anyLoading =
              devices.any((d) => _live[d.identifier]?.loading ?? false);
          final anySnapshot =
              devices.any((d) => _live[d.identifier]?.snapshot != null);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DisclaimerBanner(text: l.reefFactoryDisclaimer),
                      const SizedBox(height: 12),
                      if (devices.isEmpty)
                        _EmptyState(
                          title: l.reefFactoryEmptyTitle,
                          body: l.reefFactoryEmptyBody,
                        )
                      else ...[
                        // Common actions applied to every device at once.
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: anyLoading
                                    ? null
                                    : () => _refreshAll(devices),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(l.reefFactoryRefreshAll),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: anySnapshot
                                    ? () => _saveAll(devices)
                                    : null,
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: Text(l.reefFactorySaveAll),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              // Drag-orderable cards (the #13 list pattern, cards instead of
              // rows): the handle sits in each card's header.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                sliver: SliverReorderableList(
                  itemCount: devices.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = [for (final d in devices) d.id];
                    ids.insert(newIndex, ids.removeAt(oldIndex));
                    unawaited(ref.read(dbProvider).reorderDevices(ids));
                  },
                  itemBuilder: (context, i) {
                    final d = devices[i];
                    return _DeviceCard(
                      key: ValueKey(d.id),
                      device: d,
                      index: i,
                      // A single card has nothing to reorder against.
                      canReorder: devices.length > 1,
                      tank: _tankFor(d.tankId, tanks),
                      live: _live[d.identifier] ?? const _Live(),
                      errorTextOf: (e) => _errorText(l, e),
                      onRename: () => _renameDevice(d),
                      onSave: (snap) => _save(d, snap),
                      // No other tank to move to → no menu item.
                      onMove: tanks.any((t) => t.id != d.tankId)
                          ? () => _moveDevice(d)
                          : null,
                      onRemove: () => _confirmRemove(d),
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

  /// Renames [d]. The card header carries nothing but the name now, so a
  /// keeper-chosen one is what tells two meters of the same model apart. An
  /// emptied field falls back to the model, as an unnamed device already does.
  Future<void> _renameDevice(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final name = await showDeviceRenameDialog(
      context,
      title: l.reefFactoryRenameDevice,
      fieldLabel: l.reefFactoryDeviceNameLabel,
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
        title: Text(l.reefFactorySelectTank),
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
        title: Text(l.reefFactoryRemove),
        content: Text(l.reefFactoryRemoveConfirm(deviceDisplayName(d))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.reefFactoryRemove)),
        ],
      ),
    );
    if (ok == true) {
      _live.remove(d.identifier);
      await ref.read(dbProvider).deleteDevice(d.id);
    }
  }

  /// The primary add path (U39): scan the network and pick from what answered.
  /// ReefFactory devices advertise nothing over mDNS, so this relies entirely
  /// on the port sweep — which is exactly why manual entry stays available.
  Future<void> _showDiscoverySheet() async {
    final db = ref.read(dbProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DeviceDiscoverySheet(
        kind: DiscoveredKind.reeffactory,
        onAdd: (found) => db.upsertReefFactoryDevice(
          identifier: found.identifier,
          model: found.modelCode,
          address: found.address,
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
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddDeviceSheet(
          link: ref.read(rfDeviceLinkProvider),
          tanks: ref.read(tanksProvider).value ?? const <Tank>[],
          activeTankId: ref.read(activeTankProvider)?.id,
          errorTextOf: (e) => _errorText(AppLocalizations.of(ctx), e),
          onAdd: ({required serial, required model, required host, required name, required tankId, required snapshot}) async {
            await ref.read(dbProvider).upsertReefFactoryDevice(
              identifier: serial,
              model: model,
              address: host,
              name: name,
              tankId: tankId,
            );
            // The probe already read the device, so seed the new card with
            // that snapshot — it shows live values right away without a
            // second connect.
            if (mounted) {
              setState(() => _live[serial] = _Live(snapshot: snapshot));
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
          Icon(Icons.sensors_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
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
    required this.onRemove,
  });

  final DeviceRecord device;

  /// Position in the reorderable list (what the drag handle reports).
  final int index;

  /// False for a one-card list — nothing to drag against, so no handle.
  final bool canReorder;
  final Tank? tank;
  final _Live live;
  final String Function(RfLinkError) errorTextOf;
  final VoidCallback onRename;
  final void Function(RfSnapshot) onSave;

  /// Null when there is no other tank to move to (the item is hidden).
  final VoidCallback? onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tokens = ReefTokens.of(context);
    final snap = live.snapshot;
    // What the Temperature Controller's outputs are doing right now. Idle is
    // deliberately silent — a badge that is always present says nothing, and
    // "neither output running" is the state a healthy tank sits in most of the
    // day. Warm amber for heating, the actinic accent for cooling: both read as
    // "this is running", neither borrows the alarm red.
    final badge = switch (snap?.thermal) {
      RfThermalState.heating => (
          label: l.reefFactoryHeating,
          color: tokens.caution,
          soft: tokens.cautionSoft,
        ),
      RfThermalState.cooling => (
          label: l.reefFactoryCooling,
          color: tokens.primary,
          soft: tokens.primary.withValues(alpha: 0.14),
        ),
      _ => null,
    };

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
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  _StateBadge(
                    label: badge.label,
                    color: badge.color,
                    softColor: badge.soft,
                  ),
                ],
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
                      PopupMenuItem(value: 'move', child: Text(l.reefFactoryMoveToTank)),
                    PopupMenuItem(value: 'remove', child: Text(l.reefFactoryRemove)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Live value area.
            if (live.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (live.error != null)
              Text(errorTextOf(live.error!), style: t.bodyMedium?.copyWith(color: cs.error))
            else if (snap != null)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final r in snap.readings)
                    _ReadingChip(
                      label: l.paramName(r.paramKey),
                      value: r.value,
                      unit: r.unit,
                    ),
                ],
              )
            else
              Text(l.reefFactoryNotReadYet, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            // A tank assignment is needed before Save can persist; assignment
            // happens via the card menu ("Move to another tank").
            if (tank == null) ...[
              Text(
                l.reefFactoryNoTank,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: (snap != null && tank != null) ? () => onSave(snap) : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(l.reefFactorySave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill in a card header stating what the device is doing right now
/// (same shape as the ReefBeat dashboard's status chips).
class _StateBadge extends StatelessWidget {
  const _StateBadge({
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

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({required this.label, required this.value, required this.unit});
  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(
          unit.isEmpty ? _fmt(value) : '${_fmt(value)} $unit',
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();
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

  final RfDeviceLink link;
  final List<Tank> tanks;
  final int? activeTankId;
  final String Function(RfLinkError) errorTextOf;
  final Future<void> Function({
    required String serial,
    required String model,
    required String host,
    required String? name,
    required int? tankId,
    required RfSnapshot snapshot,
  }) onAdd;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _host = TextEditingController();
  final _name = TextEditingController();
  bool _probing = false;
  String? _error;
  RfSnapshot? _found;
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
        // Default the name to the vendor product name (Salinity Guardian, pH
        // Monitor, Temperature Controller).
        if (_name.text.isEmpty) _name.text = snap.modelDisplayName;
      });
    } on RfLinkException catch (e) {
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
          Text(l.reefFactoryAddDevice, style: t.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _host,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.reefFactoryHostLabel,
              hintText: l.reefFactoryHostHint,
              helperText: l.reefFactoryHostHelp,
              helperMaxLines: 2,
            ),
            onSubmitted: (_) => _probe(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          if (found != null) ...[
            const SizedBox(height: 16),
            Text(
              l.reefFactoryFound(found.modelDisplayName),
              style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              [for (final r in found.readings) '${l.paramName(r.paramKey)} ${r.value}${r.unit.isEmpty ? '' : ' ${r.unit}'}'].join('   ·   '),
              style: t.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.reefFactoryDeviceNameLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _tankId,
              decoration: InputDecoration(labelText: l.reefFactoryTankLabel),
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
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.reefFactoryCheck),
                )
              else
                FilledButton(
                  onPressed: () async {
                    await widget.onAdd(
                      serial: found.serial,
                      model: found.modelPrefix,
                      host: _host.text.trim(),
                      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                      tankId: _tankId,
                      snapshot: found,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l.reefFactoryAddDevice),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
