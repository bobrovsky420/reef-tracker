// The "scan network" bottom sheet (U39), shared by the ReefBeat and
// ReefFactory dashboards.
//
// It shows one kind at a time — the kind of the dashboard it was opened from —
// so it stays inside that integration's Pro gate and its mental model, even
// though a single scan finds both vendors at once.
//
// Devices already registered are shown too rather than filtered out, because
// the most valuable thing this sheet does after first-time setup is repair a
// **changed IP address**: a DHCP lease change silently breaks a stored address,
// and matching by hwid/serial lets one tap fix it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/lan_discovery.dart';
import '../../data/rb_protocol.dart';
import '../../l10n/app_localizations.dart';

/// A found device paired with what the database already knows about it.
enum _RowState { fresh, known, moved, unsupported }

class DeviceDiscoverySheet extends ConsumerStatefulWidget {
  const DeviceDiscoverySheet({
    super.key,
    required this.kind,
    required this.onAdd,
    required this.onUpdateAddress,
    required this.onManualEntry,
  });

  final DiscoveredKind kind;

  /// Registers a newly found device (the dashboard supplies the right upsert).
  final Future<void> Function(DiscoveredDevice found) onAdd;

  /// Points an already-registered device at its new address.
  final Future<void> Function(DeviceRecord existing, DiscoveredDevice found)
      onUpdateAddress;

  /// Falls back to typing an IP by hand — kept for static-IP, VLAN and
  /// isolated-network setups that a sweep cannot reach.
  final VoidCallback onManualEntry;

  @override
  ConsumerState<DeviceDiscoverySheet> createState() =>
      _DeviceDiscoverySheetState();
}

class _DeviceDiscoverySheetState extends ConsumerState<DeviceDiscoverySheet> {
  StreamSubscription<DiscoveryProgress>? _sub;
  DiscoveryProgress? _progress;

  /// Identifiers with an add/update in flight, so a row can't be double-tapped.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _startScan() {
    unawaited(_sub?.cancel());
    setState(() => _progress = null);
    _sub = ref.read(lanDiscoveryProvider).scan().listen((p) {
      if (mounted) setState(() => _progress = p);
    });
  }

  Future<void> _run(String identifier, Future<void> Function() action) async {
    setState(() => _busy.add(identifier));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(identifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final progress = _progress;
    final scanning = progress == null || progress.phase != DiscoveryPhase.done;

    final existing = switch (widget.kind) {
      DiscoveredKind.reefbeat => ref.watch(reefBeatDevicesProvider).value,
      DiscoveredKind.reeffactory => ref.watch(reefFactoryDevicesProvider).value,
    } ?? const <DeviceRecord>[];
    final byIdentifier = {for (final d in existing) d.identifier: d};

    final devices = [
      for (final d in progress?.devices ?? const <DiscoveredDevice>[])
        if (d.kind == widget.kind) d,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.discoveryTitle, style: t.titleLarge),
            const SizedBox(height: 12),
            if (scanning) ...[
              LinearProgressIndicator(
                value: _fractionOf(progress),
                // Indeterminate until the first progress event names a total.
              ),
              const SizedBox(height: 8),
              Text(
                _statusText(l, progress),
                style: t.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (progress?.noNetwork == true)
              _Notice(text: l.discoveryNoNetwork)
            else if (devices.isEmpty && !scanning)
              _Notice(text: l.discoveryNothingFoundHelp)
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final device = devices[i];
                    final known = byIdentifier[device.identifier];
                    return _DeviceRow(
                      device: device,
                      state: _stateOf(device, known),
                      busy: _busy.contains(device.identifier),
                      onAdd: () => _run(
                        device.identifier,
                        () => widget.onAdd(device),
                      ),
                      onUpdate: known == null
                          ? null
                          : () => _run(
                              device.identifier,
                              () => widget.onUpdateAddress(known, device),
                            ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: scanning ? null : _startScan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l.discoveryRescan),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: widget.onManualEntry,
                    child: Text(l.discoveryManualEntry),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static _RowState _stateOf(DiscoveredDevice d, DeviceRecord? known) {
    if (!d.supported) return _RowState.unsupported;
    if (known == null) return _RowState.fresh;
    return known.address == d.address ? _RowState.known : _RowState.moved;
  }

  /// Null (indeterminate) until a phase reports a total to divide by.
  static double? _fractionOf(DiscoveryProgress? p) {
    if (p == null || p.total <= 0) return null;
    return (p.scanned / p.total).clamp(0.0, 1.0);
  }

  static String _statusText(AppLocalizations l, DiscoveryProgress? p) =>
      switch (p?.phase) {
        null || DiscoveryPhase.sweeping => l.discoverySweeping,
        DiscoveryPhase.identifying => l.discoveryIdentifying,
        DiscoveryPhase.done => l.discoveryDone,
      };
}

/// One found device: what it is, where it answered, and the single action that
/// makes sense for it.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.state,
    required this.busy,
    required this.onAdd,
    required this.onUpdate,
  });

  final DiscoveredDevice device;
  final _RowState state;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final unsupported = state == _RowState.unsupported;

    final subtitle = switch (state) {
      _RowState.moved => l.discoveryAddressChanged(device.address),
      _RowState.unsupported => l.discoveryUnsupportedHelp,
      _ => device.address,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _iconFor(device),
        color: unsupported ? tokens.textFaint : tokens.primary,
      ),
      title: Text(
        device.modelDisplayName,
        style: t.titleSmall?.copyWith(
          color: unsupported ? tokens.textDim : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: t.bodySmall?.copyWith(
          color: state == _RowState.moved ? tokens.caution : tokens.textDim,
        ),
      ),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : switch (state) {
              _RowState.fresh => FilledButton(
                  onPressed: onAdd,
                  child: Text(l.discoveryAdd),
                ),
              _RowState.moved => FilledButton.tonal(
                  onPressed: onUpdate,
                  child: Text(l.discoveryUpdate),
                ),
              _RowState.known => Text(
                  l.discoveryAlreadyAdded,
                  style: t.labelMedium?.copyWith(color: tokens.textDim),
                ),
              _RowState.unsupported => Text(
                  l.discoveryUnsupported,
                  style: t.labelMedium?.copyWith(color: tokens.textFaint),
                ),
            },
    );
  }

  /// A glyph per device family, so a list of six Red Sea devices is scannable
  /// at a glance instead of six identical rows.
  static IconData _iconFor(DiscoveredDevice device) {
    if (device.kind == DiscoveredKind.reeffactory) return Icons.sensors;
    return switch (device.hwType) {
      kRbDosingHwType => Icons.science_outlined,
      kRbAtoHwType => Icons.opacity,
      kRbMatHwType => Icons.filter_alt_outlined,
      kRbRunHwType => Icons.cyclone,
      kRbLightsHwType => Icons.lightbulb_outline,
      kRbWaveHwType => Icons.waves,
      _ => Icons.device_unknown,
    };
  }
}

/// An explanatory block for the two dead ends — no network, or nothing found.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
