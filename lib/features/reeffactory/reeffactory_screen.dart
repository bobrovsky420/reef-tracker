import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/device_live.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/lan_discovery.dart';
import '../../data/rf_device_link.dart';
import '../../data/rf_protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/device_values.dart';
import '../devices/device_card_reorder.dart';
import '../devices/device_details_dialog.dart';
import '../devices/device_rename_dialog.dart';
import '../devices/discovery_sheet.dart';

String rfErrorText(AppLocalizations l, RfLinkError e) => switch (e) {
  RfLinkError.unreachable => l.reefFactoryErrUnreachable,
  RfLinkError.timeout => l.reefFactoryErrTimeout,
  RfLinkError.unsupportedModel => l.reefFactoryErrUnsupported,
  RfLinkError.protocol => l.reefFactoryErrProtocol,
};

/// The ReefFactory section of the Devices screen (U41): the meter cards, as one
/// reorderable sliver. Stateless towards the live values — the parent screen
/// owns those and passes them in — but it keeps the vendor's own dialogs
/// (rename / move / remove / add), so ReefFactory wording stays ReefFactory's.
class RfDeviceSection extends ConsumerWidget {
  const RfDeviceSection({
    super.key,
    required this.devices,
    required this.live,
    required this.onSave,
    required this.onRemoved,
  });

  /// Already filtered to the active tank and sorted by the parent.
  final List<DeviceRecord> devices;
  final Map<String, RfLive> live;

  /// Null while the parent has a save in flight — every card's Save button
  /// disables for the duration (#86).
  final void Function(DeviceRecord device, RfSnapshot snap)? onSave;

  /// Lets the parent drop a removed device's live entry.
  final Future<void> Function(DeviceRecord device) onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    return SliverReorderableList(
      itemCount: devices.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final d in devices) d.id];
        ids.insert(newIndex, ids.removeAt(oldIndex));
        unawaited(ref.read(dbProvider).reorderDevices(ids));
      },
      proxyDecorator: (child, index, animation) => deviceCardDragProxyDecorator(
        context,
        child,
        index,
        animation,
        semanticLabel: l.reorder,
      ),
      itemBuilder: (context, i) {
        final d = devices[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(d.id),
          index: i,
          enabled: devices.length > 1,
          child: _DeviceCard(
            device: d,
            tank: _tankFor(d.tankId, tanks),
            live: live[d.identifier] ?? const RfLive(),
            errorTextOf: (e) => rfErrorText(l, e),
            onRename: () => _renameDevice(context, ref, d),
            onSave: onSave == null ? null : (snap) => onSave!(d, snap),
            // No other tank to move to → no menu item.
            onMove: tanks.any((t) => t.id != d.tankId)
                ? () => _moveDevice(context, ref, d)
                : null,
            onRemove: () => _confirmRemove(context, ref, d),
          ),
        );
      },
    );
  }

  static Tank? _tankFor(int? id, List<Tank> tanks) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Renames [d]. The card header carries nothing but the name now, so a
  /// keeper-chosen one is what tells two meters of the same model apart. An
  /// emptied field falls back to the model, as an unnamed device already does.
  Future<void> _renameDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
    final l = AppLocalizations.of(context);
    final name = await showDeviceRenameDialog(
      context,
      title: l.reefFactoryRenameDevice,
      fieldLabel: l.reefFactoryDeviceNameLabel,
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

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reefFactoryRemove),
        content: Text(l.reefFactoryRemoveConfirm(deviceDisplayName(d))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.reefFactoryRemove),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dbProvider).deleteDevice(d.id);
      await onRemoved(d);
    }
  }
}

/// The ReefFactory add path (U39): scan the network and pick from what
/// answered, with manual entry one tap away inside the sheet. ReefFactory
/// devices advertise nothing over mDNS, so this relies entirely on the port
/// sweep — which is exactly why manual entry stays available.
///
/// [onSeed] receives the probe's snapshot for a device that was just added, so
/// the new card shows live values without a second connect.
Future<void> showRfAddFlow(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String identifier, RfSnapshot snap) onSeed,
}) async {
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
        unawaited(showRfManualSheet(context, ref, onSeed: onSeed));
      },
    ),
  );
}

/// The type-an-IP half of the add flow, reached from the discovery sheet.
/// Public only so a widget test can open it without driving a network sweep.
@visibleForTesting
Future<void> showRfManualSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String identifier, RfSnapshot snap) onSeed,
}) async {
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
        errorTextOf: (e) => rfErrorText(AppLocalizations.of(ctx), e),
        findExisting: (identifier) =>
            ref.read(dbProvider).deviceByIdentifier(identifier),
        onAdd:
            ({
              required serial,
              required model,
              required host,
              required name,
              required tankId,
              required snapshot,
            }) async {
              await ref
                  .read(dbProvider)
                  .upsertReefFactoryDevice(
                    identifier: serial,
                    model: model,
                    address: host,
                    name: name,
                    tankId: tankId,
                  );
              onSeed(serial, snapshot);
            },
      ),
    ),
  );
}

/// One meter's card: name + menu, then full-width live values.
class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({
    required this.device,
    required this.tank,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onSave,
    required this.onMove,
    required this.onRemove,
  });

  final DeviceRecord device;
  final Tank? tank;
  final RfLive live;
  final String Function(RfLinkError) errorTextOf;
  final VoidCallback onRename;

  /// Null while a save is in flight — the button disables (#86).
  final void Function(RfSnapshot)? onSave;

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
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'save' &&
                        snap != null &&
                        tank != null &&
                        onSave != null) {
                      onSave!(snap);
                    }
                    if (v == 'rename') onRename();
                    if (v == 'move') onMove?.call();
                    if (v == 'details') {
                      unawaited(showDeviceDetailsDialog(context, device));
                    }
                    if (v == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    if (snap != null)
                      PopupMenuItem(
                        value: 'save',
                        enabled: tank != null && onSave != null,
                        child: Text(l.reefFactorySave),
                      ),
                    PopupMenuItem(value: 'rename', child: Text(l.edit)),
                    if (onMove != null)
                      PopupMenuItem(
                        value: 'move',
                        child: Text(l.reefFactoryMoveToTank),
                      ),
                    PopupMenuItem(
                      value: 'details',
                      child: Text(l.devicesDetails),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l.reefFactoryRemove),
                    ),
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
              Text(
                errorTextOf(live.error!),
                style: t.bodyMedium?.copyWith(color: cs.error),
              )
            else if (snap != null)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                // The badge rides the value line rather than the card header:
                // it qualifies the temperature ("34.0 °C — heating"), so it
                // belongs next to the number it explains.
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final r in snap.readings)
                    _ReadingChip(
                      paramKey: r.paramKey,
                      label: l.paramName(r.paramKey),
                      value: r.value,
                      unit: r.unit,
                    ),
                  if (badge != null)
                    Padding(
                      // Nudges the pill off the value's descender line so its
                      // centre lands on the digits, not below them.
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _StateBadge(
                        label: badge.label,
                        color: badge.color,
                        softColor: badge.soft,
                      ),
                    ),
                ],
              )
            else
              Text(
                l.reefFactoryNotReadYet,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            // A tank assignment is needed before Save can persist; assignment
            // happens via the card menu ("Move to another tank").
            if (tank == null) ...[
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

/// A small pill next to a live reading stating what the device is doing right
/// now (same shape as the ReefBeat dashboard's status chips).
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReadingChip extends ConsumerWidget {
  const _ReadingChip({
    required this.paramKey,
    required this.label,
    required this.value,
    required this.unit,
  });
  final String paramKey;
  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          formatDeviceReading(
            paramKey: paramKey,
            value: value,
            unit: unit,
            prefs: ref.watch(unitPrefsProvider),
          ),
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Bottom sheet: enter an IP/hostname, we probe and auto-identify the device,
/// then let the user name it and pick a tank before adding.
class _AddDeviceSheet extends ConsumerStatefulWidget {
  const _AddDeviceSheet({
    required this.link,
    required this.tanks,
    required this.activeTankId,
    required this.errorTextOf,
    required this.findExisting,
    required this.onAdd,
  });

  final RfDeviceLink link;
  final List<Tank> tanks;
  final int? activeTankId;
  final String Function(RfLinkError) errorTextOf;

  /// The row already registered under the probed serial, if any (#75). The
  /// sheet has no notion of an existing device — it prefills the *product*
  /// name and the *active* tank — so adding one twice would overwrite both.
  /// It refuses instead and says so; re-pointing a moved meter is the
  /// discovery sheet's job, which matches by serial and updates only the
  /// address.
  final Future<DeviceRecord?> Function(String identifier) findExisting;

  final Future<void> Function({
    required String serial,
    required String model,
    required String host,
    required String? name,
    required int? tankId,
    required RfSnapshot snapshot,
  })
  onAdd;

  @override
  ConsumerState<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<_AddDeviceSheet> {
  final _host = TextEditingController();
  final _name = TextEditingController();
  bool _probing = false;
  String? _error;
  RfSnapshot? _found;
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
      final existing = await widget.findExisting(snap.serial);
      if (!mounted) return;
      if (existing != null) {
        setState(() => _duplicateOf = deviceDisplayName(existing));
        return;
      }
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
            Text(l.reefFactoryAddDevice, style: t.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _host,
              autofocus: true,
              // Frozen once the probe lands on an already-added device: with the
              // Check button gone there is nothing left to do here but close.
              enabled: duplicateOf == null,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.reefFactoryHostLabel,
                hintText: l.reefFactoryHostHint,
                helperText: l.reefFactoryHostHelp,
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
                l.reefFactoryFound(found.modelDisplayName),
                style: t.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  for (final r in found.readings)
                    '${l.paramName(r.paramKey)} '
                        '${formatDeviceReading(paramKey: r.paramKey, value: r.value, unit: r.unit, prefs: ref.watch(unitPrefsProvider))}',
                ].join('   ·   '),
                style: t.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.reefFactoryDeviceNameLabel,
                ),
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
                          : Text(l.reefFactoryCheck),
                    )
                  else
                    FilledButton(
                      onPressed: () async {
                        await widget.onAdd(
                          serial: found.serial,
                          model: found.modelPrefix,
                          host: _host.text.trim(),
                          name: _name.text.trim().isEmpty
                              ? null
                              : _name.text.trim(),
                          tankId: _tankId,
                          snapshot: found,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(l.reefFactoryAddDevice),
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
