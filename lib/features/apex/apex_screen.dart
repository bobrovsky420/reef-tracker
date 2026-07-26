import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/ap_device_link.dart';
import '../../data/ap_protocol.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../devices/device_rename_dialog.dart';

/// How many outlets a card lists before collapsing behind "+N more". A fully
/// populated Apex drives thirty-odd outlets; the whole list is worth having,
/// but not at the cost of burying every other card below it.
const int kApexOutletPreview = 8;

/// Filters a controller's live [readings] down to what should be persisted:
/// values converted to the catalog's canonical unit (an Apex conductivity
/// probe reports ppt, salinity is stored as specific gravity) and physically
/// impossible ones dropped, so a save can't store noise from an unplugged
/// probe. Pure, so it is unit-tested directly.
///
/// There is no cross-device precedence rule of the ReefFactory kind here: a
/// controller already reports one value per parameter (see [ApStatus.readings]),
/// and an Apex *is* the tank's instrumentation hub rather than one meter
/// among several.
List<({String paramKey, double value})> apReadingsToSave(
  List<ApReading> readings,
) {
  return [
    for (final r in readings.map(
      (r) => (
        paramKey: r.paramKey,
        value: r.paramKey == 'salinity' ? pptToSg(r.value) : r.value,
      ),
    ))
      if (checkParamValue(r.paramKey, r.value) != ParamValueCheck.impossible) r,
  ];
}

/// Transient per-controller live state held by the screen (not persisted).
class _Live {
  const _Live({this.loading = false, this.status, this.error});
  final bool loading;
  final ApStatus? status;
  final ApLinkError? error;
}

/// The Neptune Apex dashboard (U40): the registered controllers, read on open
/// and by one **Refresh all**, each card carrying a **Save** that persists its
/// probe values as measurements. Read-only towards the controller — the app
/// never switches an outlet, starts a feed cycle or edits a program.
class ApexScreen extends ConsumerStatefulWidget {
  const ApexScreen({super.key});

  @override
  ConsumerState<ApexScreen> createState() => _ApexScreenState();
}

class _ApexScreenState extends ConsumerState<ApexScreen> {
  /// Live status keyed by device identifier (the controller's serial).
  final Map<String, _Live> _live = {};
  bool _autoRefreshed = false;

  Tank? _tankFor(int? id, List<Tank> tanks) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The credentials stored with a device row, or null when it carries none
  /// (a row restored from a backup — the password is deliberately not in one).
  ApCredentials? _credentialsOf(DeviceRecord d) {
    final username = d.username;
    final password = d.secret;
    if (username == null || password == null) return null;
    return ApCredentials(username: username, password: password);
  }

  Future<void> _refresh(DeviceRecord device) async {
    final address = device.address;
    final credentials = _credentialsOf(device);
    if (address == null || address.isEmpty) return;
    if (credentials == null) {
      // A restored row: the address survived the backup, the password did not.
      setState(
        () => _live[device.identifier] = const _Live(error: ApLinkError.auth),
      );
      return;
    }
    setState(() => _live[device.identifier] = const _Live(loading: true));
    try {
      final status = await ref
          .read(apDeviceLinkProvider)
          .readOnce(address, credentials);
      await ref.read(dbProvider).touchDeviceSeen(device.identifier);
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(status: status));
    } on ApLinkException catch (e) {
      if (!mounted) return;
      setState(() => _live[device.identifier] = _Live(error: e.error));
    }
  }

  /// Reads every controller in turn — sequential, like the other dashboards: a
  /// controller is also serving Fusion and its own web UI.
  Future<void> _refreshAll(List<DeviceRecord> devices) async {
    for (final d in devices) {
      await _refresh(d);
    }
  }

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

  Future<void> _save(DeviceRecord device, ApStatus status) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tank = _tankFor(device.tankId, tanks);
    if (tank == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.apexNoTank)));
      return;
    }
    final values = apReadingsToSave(status.readings);
    if (values.isEmpty) return;
    try {
      await _persistValues(tank, values);
      messenger.showSnackBar(
        SnackBar(content: Text(l.apexSavedSnack(values.length))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed(e.toString()))),
      );
    }
  }

  /// Saves every controller's last-read values at once, merging readings bound
  /// for the same tank into one group (deduped by parameter) exactly as the
  /// ReefFactory dashboard does.
  Future<void> _saveAll(List<DeviceRecord> devices) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final byTank = <int, Map<String, ({String paramKey, double value})>>{};
    final tankById = <int, Tank>{};
    var skippedNoTank = false;
    for (final d in devices) {
      final status = _live[d.identifier]?.status;
      if (status == null) continue;
      final tank = _tankFor(d.tankId, tanks);
      if (tank == null) {
        skippedNoTank = true;
        continue;
      }
      final values = apReadingsToSave(status.readings);
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
          content: Text(skippedNoTank ? l.apexNoTank : l.apexNothingToSave),
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
        SnackBar(content: Text(l.apexSavedSnack(total))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed(e.toString()))),
      );
    }
  }

  String _errorText(AppLocalizations l, ApLinkError e) => switch (e) {
    ApLinkError.unreachable => l.apexErrUnreachable,
    ApLinkError.timeout => l.apexErrTimeout,
    ApLinkError.auth => l.apexErrAuth,
    ApLinkError.protocol => l.apexErrProtocol,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final devicesAsync = ref.watch(apexDevicesProvider);
    final tanks = ref.watch(tanksProvider).value ?? const <Tank>[];
    final activeTank = ref.watch(activeTankProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.apexTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(l.apexAddDevice),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (allDevices) {
          // Same tank scoping as the other device dashboards: the active
          // tank's controllers plus unassigned ones, in manual card order with
          // the display name as the tie-break.
          final devices = [
            for (final d in allDevices)
              if (d.tankId == null || d.tankId == activeTank?.id) d,
          ]..sort((a, b) {
            final byOrder = a.displayOrder.compareTo(b.displayOrder);
            if (byOrder != 0) return byOrder;
            return deviceDisplayName(
              a,
            ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
          });
          if (!_autoRefreshed && devices.isNotEmpty) {
            _autoRefreshed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_refreshAll(devices));
            });
          }
          final anyLoading = devices.any(
            (d) => _live[d.identifier]?.loading ?? false,
          );
          final anyStatus = devices.any(
            (d) => _live[d.identifier]?.status != null,
          );
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DisclaimerBanner(text: l.apexDisclaimer),
                      const SizedBox(height: 12),
                      if (devices.isEmpty)
                        _EmptyState(
                          title: l.apexEmptyTitle,
                          body: l.apexEmptyBody,
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: anyLoading
                                    ? null
                                    : () => _refreshAll(devices),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(l.apexRefreshAll),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: anyStatus
                                    ? () => _saveAll(devices)
                                    : null,
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: Text(l.apexSaveAll),
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
                    return _ControllerCard(
                      key: ValueKey(d.id),
                      device: d,
                      index: i,
                      canReorder: devices.length > 1,
                      tank: _tankFor(d.tankId, tanks),
                      live: _live[d.identifier] ?? const _Live(),
                      errorTextOf: (e) => _errorText(l, e),
                      onRename: () => _renameDevice(d),
                      onCredentials: () => _editCredentials(d),
                      onSave: (status) => _save(d, status),
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

  Future<void> _renameDevice(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final name = await showDeviceRenameDialog(
      context,
      title: l.apexRenameDevice,
      fieldLabel: l.apexDeviceNameLabel,
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

  /// Re-enters the controller's login. Needed after the password is changed on
  /// the Apex itself, and after a backup restore — a restored row carries the
  /// username but never the password.
  Future<void> _editCredentials(DeviceRecord d) async {
    final result = await showModalBottomSheet<({String user, String pass})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CredentialsSheet(initialUsername: d.username ?? 'admin'),
      ),
    );
    if (result == null) return;
    await ref
        .read(dbProvider)
        .updateDeviceCredentials(
          d.id,
          username: result.user,
          password: result.pass,
        );
    // The stored row the refresh reads from is the stream's, not `d` — reread
    // it so the retry uses the credentials just saved.
    final fresh = await ref.read(dbProvider).deviceByIdentifier(d.identifier);
    if (fresh != null && mounted) unawaited(_refresh(fresh));
  }

  Future<void> _moveDevice(DeviceRecord d) async {
    final l = AppLocalizations.of(context);
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tankId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.apexSelectTank),
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
        title: Text(l.apexRemove),
        content: Text(l.apexRemoveConfirm(deviceDisplayName(d))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.apexRemove),
          ),
        ],
      ),
    );
    if (ok == true) {
      _live.remove(d.identifier);
      await ref.read(dbProvider).deleteDevice(d.id);
    }
  }

  /// The add path is manual address + login, with no discovery step: an Apex
  /// will not identify itself to an unauthenticated probe, so the network
  /// sweep that finds ReefBeat and ReefFactory devices has nothing to go on
  /// here (see DESIGN.md).
  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddDeviceSheet(
          link: ref.read(apDeviceLinkProvider),
          tanks: ref.read(tanksProvider).value ?? const <Tank>[],
          activeTankId: ref.read(activeTankProvider)?.id,
          errorTextOf: (e) => _errorText(AppLocalizations.of(ctx), e),
          onAdd:
              ({
                required host,
                required credentials,
                required name,
                required tankId,
                required status,
              }) async {
                await ref
                    .read(dbProvider)
                    .upsertApexDevice(
                      identifier: status.info.serial,
                      model: status.info.modelCode,
                      address: host,
                      username: credentials.username,
                      password: credentials.password,
                      name: name,
                      tankId: tankId,
                    );
                // The probe already read the controller — seed the card so it
                // shows live values without a second round trip.
                if (mounted) {
                  setState(
                    () =>
                        _live[status.info.serial] = _Live(status: status),
                  );
                }
              },
        ),
      ),
    );
  }
}

/// The persistent read-only notice, in the tertiary container so it reads as
/// informational rather than as an error (shared shape with the other device
/// dashboards).
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
            Icons.hub_outlined,
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

class _ControllerCard extends StatefulWidget {
  const _ControllerCard({
    super.key,
    required this.device,
    required this.index,
    required this.canReorder,
    required this.tank,
    required this.live,
    required this.errorTextOf,
    required this.onRename,
    required this.onCredentials,
    required this.onSave,
    required this.onMove,
    required this.onRemove,
  });

  final DeviceRecord device;
  final int index;
  final bool canReorder;
  final Tank? tank;
  final _Live live;
  final String Function(ApLinkError) errorTextOf;
  final VoidCallback onRename;
  final VoidCallback onCredentials;
  final void Function(ApStatus) onSave;
  final VoidCallback? onMove;
  final VoidCallback onRemove;

  @override
  State<_ControllerCard> createState() => _ControllerCardState();
}

class _ControllerCardState extends State<_ControllerCard> {
  /// Whether the outlet list is expanded past [kApexOutletPreview].
  bool _allOutlets = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tokens = ReefTokens.of(context);
    final status = widget.live.status;
    final outlets = status?.switchedOutlets ?? const <ApOutlet>[];
    final shown = _allOutlets
        ? outlets
        : outlets.take(kApexOutletPreview).toList();

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
                  child: Text(
                    deviceDisplayName(widget.device),
                    style: t.titleMedium,
                  ),
                ),
                if (widget.canReorder)
                  ReorderableDragStartListener(
                    index: widget.index,
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
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') widget.onRename();
                    if (v == 'credentials') widget.onCredentials();
                    if (v == 'move') widget.onMove?.call();
                    if (v == 'remove') widget.onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l.edit)),
                    PopupMenuItem(
                      value: 'credentials',
                      child: Text(l.apexCredentialsMenu),
                    ),
                    if (widget.onMove != null)
                      PopupMenuItem(
                        value: 'move',
                        child: Text(l.apexMoveToTank),
                      ),
                    PopupMenuItem(value: 'remove', child: Text(l.apexRemove)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.live.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (widget.live.error != null) ...[
              Text(
                widget.errorTextOf(widget.live.error!),
                style: t.bodyMedium?.copyWith(color: cs.error),
              ),
              // An auth failure is the one error the keeper can fix from here.
              if (widget.live.error == ApLinkError.auth) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onCredentials,
                    icon: const Icon(Icons.key_outlined, size: 18),
                    label: Text(l.apexCredentialsMenu),
                  ),
                ),
              ],
            ] else if (status != null) ...[
              if (status.readings.isEmpty)
                Text(
                  l.apexNoProbes,
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final r in status.readings)
                      _ReadingChip(
                        label: l.paramName(r.paramKey),
                        value: r.value,
                        unit: r.unit,
                      ),
                  ],
                ),
              // Status chips: a running feed cycle (pumps are paused right
              // now) and outlets a human has left overridden — the two facts
              // that explain a tank behaving unlike its program.
              if (status.feed?.running == true ||
                  status.overriddenOutlets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status.feed?.letter case final letter?)
                      _StateBadge(
                        label: l.apexFeedRunning(letter),
                        color: tokens.healthy,
                        softColor: tokens.healthySoft,
                      ),
                    if (status.overriddenOutlets.isNotEmpty)
                      _StateBadge(
                        label: l.apexOverridden(
                          status.overriddenOutlets.length,
                        ),
                        color: tokens.caution,
                        softColor: tokens.cautionSoft,
                      ),
                  ],
                ),
              ],
              if (outlets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l.apexOutlets.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final o in shown) _OutletPill(outlet: o)],
                ),
                if (outlets.length > kApexOutletPreview) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _allOutlets = !_allOutlets),
                      child: Text(
                        _allOutlets
                            ? l.apexShowFewer
                            : l.apexShowAll(
                                outlets.length - kApexOutletPreview,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ] else
              Text(
                l.apexNotReadYet,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            if (widget.tank == null) ...[
              Text(
                l.apexNoTank,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed:
                      (status != null &&
                          status.readings.isNotEmpty &&
                          widget.tank != null)
                      ? () => widget.onSave(status)
                      : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(l.apexSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One outlet as a compact pill: a state dot plus the keeper's own name for
/// it. An overridden outlet is drawn in the caution token — the whole reason
/// the list is here is to make a forgotten override visible.
class _OutletPill extends StatelessWidget {
  const _OutletPill({required this.outlet});
  final ApOutlet outlet;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final on = outlet.on;
    final color = outlet.overridden
        ? tokens.caution
        : (on == true ? tokens.healthy : tokens.textFaint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A profile-driven output (TBL/PF1) is neither on nor off, so it
          // gets a hollow ring rather than a filled dot claiming a state.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on == null ? null : color,
              border: on == null ? Border.all(color: color, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            outlet.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: outlet.overridden ? color : tokens.text,
              fontWeight: outlet.overridden
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

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
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({
    required this.label,
    required this.value,
    required this.unit,
  });
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
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          unit.isEmpty ? _fmt(value) : '${_fmt(value)} $unit',
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();
}

/// Username/password entry, shared by the add sheet's inline fields and the
/// card menu's "Sign in again".
class _CredentialsSheet extends StatefulWidget {
  const _CredentialsSheet({required this.initialUsername});
  final String initialUsername;

  @override
  State<_CredentialsSheet> createState() => _CredentialsSheetState();
}

class _CredentialsSheetState extends State<_CredentialsSheet> {
  late final TextEditingController _user = TextEditingController(
    text: widget.initialUsername,
  );
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.apexCredentialsMenu, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _user,
            decoration: InputDecoration(labelText: l.apexUsernameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l.apexPasswordLabel),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, (
                  user: _user.text.trim(),
                  pass: _pass.text,
                )),
                child: Text(l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: address + login, probe to identify, then name it and pick a
/// tank before adding.
class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({
    required this.link,
    required this.tanks,
    required this.activeTankId,
    required this.errorTextOf,
    required this.onAdd,
  });

  final ApDeviceLink link;
  final List<Tank> tanks;
  final int? activeTankId;
  final String Function(ApLinkError) errorTextOf;
  final Future<void> Function({
    required String host,
    required ApCredentials credentials,
    required String? name,
    required int? tankId,
    required ApStatus status,
  })
  onAdd;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _host = TextEditingController();
  // The factory login every Apex ships with. Prefilling it is not a security
  // hole — it is printed in the quick-start guide — and it is right for most
  // controllers, which saves the keeper a trip to find it.
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController(text: '1234');
  final _name = TextEditingController();
  bool _probing = false;
  String? _error;
  ApStatus? _found;
  int? _tankId;

  @override
  void initState() {
    super.initState();
    _tankId = widget.activeTankId;
  }

  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  ApCredentials get _credentials =>
      ApCredentials(username: _user.text.trim(), password: _pass.text);

  Future<void> _probe() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _probing = true;
      _error = null;
      _found = null;
    });
    try {
      final status = await widget.link.readOnce(host, _credentials);
      if (!mounted) return;
      setState(() {
        _found = status;
        if (_name.text.isEmpty) _name.text = status.info.displayName;
      });
    } on ApLinkException catch (e) {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.apexAddDevice, style: t.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _host,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.apexHostLabel,
                hintText: l.apexHostHint,
                helperText: l.apexHostHelp,
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _user,
                    decoration: InputDecoration(labelText: l.apexUsernameLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l.apexPasswordLabel),
                    onSubmitted: (_) => _probe(),
                  ),
                ),
              ],
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
                l.apexFound(found.info.displayName, found.info.serial),
                style: t.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  for (final r in found.readings)
                    '${l.paramName(r.paramKey)} ${r.value}'
                        '${r.unit.isEmpty ? '' : ' ${r.unit}'}',
                ].join('   ·   '),
                style: t.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l.apexDeviceNameLabel),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _tankId,
                decoration: InputDecoration(labelText: l.apexTankLabel),
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
                        : Text(l.apexCheck),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      await widget.onAdd(
                        host: _host.text.trim(),
                        credentials: _credentials,
                        name: _name.text.trim().isEmpty
                            ? null
                            : _name.text.trim(),
                        tankId: _tankId,
                        status: found,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(l.apexAddDevice),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
