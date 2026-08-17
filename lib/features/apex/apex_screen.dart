import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/device_live.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/ap_device_link.dart';
import '../../data/ap_protocol.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/device_values.dart';
import '../devices/device_card_reorder.dart';
import '../devices/device_details_dialog.dart';
import '../devices/device_rename_dialog.dart';

/// How many outlets a card lists before collapsing behind "+N more". A fully
/// populated Apex drives thirty-odd outlets; the whole list is worth having,
/// but not at the cost of burying every other card below it.
const int kApexOutletPreview = 8;

String apErrorText(AppLocalizations l, ApLinkError e) => switch (e) {
  ApLinkError.unreachable => l.apexErrUnreachable,
  ApLinkError.timeout => l.apexErrTimeout,
  ApLinkError.auth => l.apexErrAuth,
  ApLinkError.protocol => l.apexErrProtocol,
};

/// The Apex section of the Devices screen (U41): one card per controller, each
/// with its probe values, its outlets and its own Save.
class ApDeviceSection extends ConsumerWidget {
  const ApDeviceSection({
    super.key,
    required this.devices,
    required this.live,
    required this.onSave,
    required this.onRemoved,
    required this.onRefreshRequested,
  });

  /// Already filtered to the active tank and sorted by the parent.
  final List<DeviceRecord> devices;
  final Map<String, ApLive> live;

  /// Null while the parent has a save in flight — every card's Save button
  /// disables for the duration (#86).
  final void Function(DeviceRecord device, ApStatus status)? onSave;
  final void Function(String identifier) onRemoved;

  /// Re-read one controller — used after new credentials are entered, so the
  /// retry uses them immediately.
  final void Function(DeviceRecord device) onRefreshRequested;

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
          child: _ControllerCard(
            device: d,
            tank: _tankFor(d.tankId, tanks),
            live: live[d.identifier] ?? const ApLive(),
            errorTextOf: (e) => apErrorText(l, e),
            onRename: () => _renameDevice(context, ref, d),
            onCredentials: () => _editCredentials(context, ref, d),
            onSave: onSave == null ? null : (status) => onSave!(d, status),
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

  Future<void> _renameDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
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
  Future<void> _editCredentials(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
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
    // Two stores, one login: the name goes on the row, the password into the
    // backup-excluded sidecar (#68). Password first — a crash between the two
    // then leaves an unused sidecar entry rather than a row claiming a
    // credential that isn't there.
    await ref.read(deviceSecretsProvider).write(d.identifier, result.pass);
    await ref
        .read(dbProvider)
        .updateDeviceUsername(d.id, username: result.user);
    // The stored row the refresh reads from is the stream's, not `d` — reread
    // it so the retry uses the credentials just saved.
    final fresh = await ref.read(dbProvider).deviceByIdentifier(d.identifier);
    if (fresh != null) onRefreshRequested(fresh);
  }

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

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord d,
  ) async {
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
      onRemoved(d.identifier);
      await ref.read(dbProvider).deleteDevice(d.id);
      // The sidecar is keyed by identifier, not by row id, so it has to be
      // told: a forgotten controller must not leave its password behind.
      await ref.read(deviceSecretsProvider).remove(d.identifier);
    }
  }
}

/// The Apex add path: manual address + login, with no discovery step. An Apex
/// will not identify itself to an unauthenticated probe, so the network sweep
/// that finds ReefBeat and ReefFactory devices has nothing to go on here (see
/// DESIGN.md).
Future<void> showApAddFlow(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String identifier, ApStatus status) onSeed,
}) async {
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
        errorTextOf: (e) => apErrorText(AppLocalizations.of(ctx), e),
        onAdd:
            ({
              required host,
              required credentials,
              required name,
              required tankId,
              required status,
            }) async {
              await ref
                  .read(deviceSecretsProvider)
                  .write(status.info.serial, credentials.password);
              await ref
                  .read(dbProvider)
                  .upsertApexDevice(
                    identifier: status.info.serial,
                    model: status.info.modelCode,
                    address: host,
                    username: credentials.username,
                    name: name,
                    tankId: tankId,
                  );
              onSeed(status.info.serial, status);
            },
      ),
    ),
  );
}

class _ControllerCard extends StatefulWidget {
  const _ControllerCard({
    required this.device,
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
  final Tank? tank;
  final ApLive live;
  final String Function(ApLinkError) errorTextOf;
  final VoidCallback onRename;
  final VoidCallback onCredentials;

  /// Null while a save is in flight — the button disables (#86).
  final void Function(ApStatus)? onSave;
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
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'save' &&
                        status != null &&
                        status.readings.isNotEmpty &&
                        widget.tank != null &&
                        widget.onSave != null) {
                      widget.onSave!(status);
                    }
                    if (v == 'rename') widget.onRename();
                    if (v == 'credentials') widget.onCredentials();
                    if (v == 'move') widget.onMove?.call();
                    if (v == 'details') {
                      unawaited(
                        showDeviceDetailsDialog(context, widget.device),
                      );
                    }
                    if (v == 'remove') widget.onRemove();
                  },
                  itemBuilder: (_) => [
                    if (status != null && status.readings.isNotEmpty)
                      PopupMenuItem(
                        value: 'save',
                        enabled: widget.tank != null && widget.onSave != null,
                        child: Text(l.apexSave),
                      ),
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
                    PopupMenuItem(
                      value: 'details',
                      child: Text(l.devicesDetails),
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
                        paramKey: r.paramKey,
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
            // A tank assignment is needed before Save can persist; assignment
            // happens via the card menu ("Move to another tank").
            if (widget.tank == null) ...[
              const SizedBox(height: 10),
              Text(
                l.apexNoTank,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
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
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final on = outlet.on;
    final color = outlet.overridden
        ? tokens.caution
        : (on == true ? tokens.healthy : tokens.textFaint);
    // The dot's state, spelled out for screen readers (#104) — without it
    // TalkBack reads bare outlet names, defeating the list's purpose of
    // making a forgotten override visible. excludeSemantics keeps the name
    // from being read twice.
    final semantics = [
      outlet.name,
      switch (on) {
        true => l.apexOutletOnSemantics,
        false => l.apexOutletOffSemantics,
        null => l.apexOutletProfileSemantics,
      },
      if (outlet.overridden) l.apexOutletOverriddenSemantics,
    ].join(', ');
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.track,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Never color alone (#104): on is a filled dot, off a hollow
            // ring. A profile-driven output (TBL/PF1) is neither on nor off,
            // so it gets a dash claiming no switched state at all.
            SizedBox(
              width: 8,
              height: 8,
              child: on == null
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(1.25),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? color : null,
                        border: on
                            ? null
                            : Border.all(color: color, width: 1.5),
                      ),
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
      // Scrollable like the add sheet: the keyboard is up from frame one
      // (autofocus) and at large text scale the fields would otherwise
      // overflow with the buttons unreachable (#103, the #44 class).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.apexCredentialsMenu,
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
      ),
    );
  }
}

/// Bottom sheet: address + login, probe to identify, then name it and pick a
/// tank before adding.
class _AddDeviceSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<_AddDeviceSheet> {
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
                    '${l.paramName(r.paramKey)} '
                        '${formatDeviceReading(paramKey: r.paramKey, value: r.value, unit: r.unit, prefs: ref.watch(unitPrefsProvider))}',
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
