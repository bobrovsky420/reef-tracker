import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/rf_device_link.dart';
import '../../data/rf_protocol.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Filters a device's live [readings] down to what should be persisted, applying
/// two rules (pure, so it is unit-tested directly):
///  1. physically impossible values are dropped (a save shouldn't store noise);
///  2. **temperature source** — a non-Temperature-Controller device's
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
    for (final r in readings)
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible &&
          !(r.paramKey == 'temperature' &&
              deviceModel != kRfTempControllerModel &&
              hasTempController))
        (paramKey: r.paramKey, value: r.value),
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
/// each with a manual **Refresh** (pull live values into the card) and a
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
  /// (needed for the temperature-source rule). See [rfReadingsToSave].
  List<({String paramKey, double value})> _valuesToSave(
    DeviceRecord device,
    RfSnapshot snap,
    List<DeviceRecord> devices,
  ) =>
      rfReadingsToSave(
        deviceModel: device.model,
        readings: snap.readings,
        hasTempController:
            devices.any((d) => d.model == kRfTempControllerModel),
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

    return Scaffold(
      appBar: AppBar(title: Text(l.reefFactoryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(l.reefFactoryAddDevice),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (devices) {
          final anyLoading =
              devices.any((d) => _live[d.identifier]?.loading ?? false);
          final anySnapshot =
              devices.any((d) => _live[d.identifier]?.snapshot != null);
          return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _DisclaimerBanner(text: l.reefFactoryDisclaimer),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              _EmptyState(title: l.reefFactoryEmptyTitle, body: l.reefFactoryEmptyBody)
            else ...[
              // Common actions applied to every device at once.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: anyLoading ? null : () => _refreshAll(devices),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l.reefFactoryRefreshAll),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: anySnapshot ? () => _saveAll(devices) : null,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(l.reefFactorySaveAll),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final d in devices)
                _DeviceCard(
                  device: d,
                  tanks: tanks,
                  tank: _tankFor(d.tankId, tanks),
                  live: _live[d.identifier] ?? const _Live(),
                  errorTextOf: (e) => _errorText(l, e),
                  onRefresh: () => _refresh(d),
                  onSave: (snap) => _save(d, snap),
                  onTankChanged: (tankId) => ref
                      .read(dbProvider)
                      .updateDeviceNameTank(d.id, name: d.name, tankId: tankId),
                  onRemove: () => _confirmRemove(d),
                ),
            ],
          ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reefFactoryRemove),
        content: Text(l.reefFactoryRemoveConfirm(d.name ?? d.model ?? d.identifier)),
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
          onAdd: ({required serial, required model, required host, required name, required tankId}) async {
            await ref.read(dbProvider).upsertReefFactoryDevice(
              identifier: serial,
              model: model,
              address: host,
              name: name,
              tankId: tankId,
            );
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
    required this.device,
    required this.tanks,
    required this.tank,
    required this.live,
    required this.errorTextOf,
    required this.onRefresh,
    required this.onSave,
    required this.onTankChanged,
    required this.onRemove,
  });

  final DeviceRecord device;
  final List<Tank> tanks;
  final Tank? tank;
  final _Live live;
  final String Function(RfLinkError) errorTextOf;
  final VoidCallback onRefresh;
  final void Function(RfSnapshot) onSave;
  final void Function(int? tankId) onTankChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name ?? device.model ?? device.identifier, style: t.titleMedium),
                      Text(
                        '${device.model ?? ''}  ·  ${device.address ?? ''}',
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'remove' ? onRemove() : null,
                  itemBuilder: (_) => [
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
            // Tank assignment (needed before Save can persist).
            Row(
              children: [
                Text('${l.reefFactoryTankLabel}: ', style: t.bodyMedium),
                Expanded(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: tank?.id,
                    hint: Text(l.reefFactorySelectTank),
                    items: [
                      for (final tk in tanks)
                        DropdownMenuItem(value: tk.id, child: Text(tk.name)),
                    ],
                    onChanged: onTankChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: live.loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l.reefFactoryRefresh),
                ),
                const SizedBox(width: 8),
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
