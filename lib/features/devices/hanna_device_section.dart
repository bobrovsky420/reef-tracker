import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import 'device_card_frame.dart';
import 'device_card_reorder.dart';
import 'device_details_dialog.dart';
import 'device_inventory_actions.dart';

/// The Hanna section of the Devices screen (U43): one card per checker the
/// measurement flow has ever connected to (`ensureHannaDevice` records it on
/// first BLE contact — there is no add flow of its own).
///
/// Deliberately thinner than the LAN vendors' cards: the checker holds no
/// live state to poll, so the card is inventory — name, serial, when it last
/// measured — plus the one action it exists for, starting a new measurement.
/// `lastSeenAt` *is* the last-measurement time: the row is touched exactly
/// when a measurement session connects.
class HannaDeviceSection extends ConsumerWidget {
  const HannaDeviceSection({
    super.key,
    required this.devices,
    required this.onRemoved,
  });

  /// Already filtered to the active tank and sorted by the parent.
  final List<DeviceRecord> devices;
  final DeviceRemovedCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The measure entry point follows the same gates as everywhere else
    // (U33): experimental features opted in, and a BLE stack present at all.
    // The card itself stays — it is inventory the keeper already earned.
    final measurable =
        (ref.watch(experimentalEnabledProvider).value ?? false) &&
        (ref.watch(hannaBleSupportedProvider).value ?? true);
    final inventory = DeviceInventoryActions(ref: ref, onRemoved: onRemoved);
    final labels = DeviceInventoryLabels(
      renameTitle: l.hannaRenameDevice,
      nameField: l.hannaDeviceNameLabel,
      selectTankTitle: '',
      removeTitle: l.hannaRemove,
      removeConfirm: l.hannaRemoveConfirm,
    );
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
          child: _CheckerCard(
            device: d,
            onMeasure: measurable
                ? () => _startMeasurement(context, ref)
                : null,
            onRename: () => inventory.rename(context, d, labels),
            onRemove: () => inventory.remove(context, d, labels),
          ),
        );
      },
    );
  }

  /// Starts a live measurement — the same Pro gate as the Measurements-tab
  /// menu entry (`hannaConnect`, the checker's own gate, not the LAN devices'
  /// `connectedDevices`).
  Future<void> _startMeasurement(BuildContext context, WidgetRef ref) =>
      runProGated(
        context,
        ref,
        ProFeature.hannaConnect,
        () => context.push('/hanna/measure'),
      );
}

class _CheckerCard extends StatelessWidget {
  const _CheckerCard({
    required this.device,
    required this.onMeasure,
    required this.onRename,
    required this.onRemove,
  });

  final DeviceRecord device;

  /// Null hides the measure button (experimental features off, or no BLE
  /// stack) — the entry points hide rather than dead-end.
  final VoidCallback? onMeasure;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  /// The serial as the checker advertises it: the identifier is
  /// `<model> <serial>` ("HI97115 06150128"), so everything after the model
  /// token. An identifier without a space stands whole.
  static String _serialOf(DeviceRecord d) {
    final id = d.identifier;
    final space = id.indexOf(' ');
    return space > 0 ? id.substring(space + 1).trim() : id;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tokens = ReefTokens.of(context);
    final seen = device.lastSeenAt;

    Widget row(String label, String value) => Padding(
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
              color: tokens.text,
            ),
          ),
        ],
      ),
    );

    return DeviceCardFrame(
      title: deviceDisplayName(device),
      onMenuSelected: (v) {
        if (v == 'rename') onRename();
        if (v == 'details') {
          unawaited(showDeviceDetailsDialog(context, device));
        }
        if (v == 'remove') onRemove();
      },
      menuItems: [
        PopupMenuItem(value: 'rename', child: Text(l.edit)),
        PopupMenuItem(value: 'details', child: Text(l.devicesDetails)),
        PopupMenuItem(value: 'remove', child: Text(l.hannaRemove)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(l.hannaSerialNumber, _serialOf(device)),
          row(
            l.hannaLastMeasurement,
            seen == null ? '—' : formatDateTime(context, seen, weekday: false),
          ),
          if (onMeasure != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onMeasure,
                icon: const Icon(Icons.bluetooth, size: 18),
                label: Text(l.hannaNewMeasurement),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
