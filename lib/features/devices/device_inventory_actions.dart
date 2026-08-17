/// Shared inventory mutations for every device family.
///
/// Vendor sections provide localized nouns; this module owns the interaction
/// and persistence sequence, including integration-specific post-delete
/// cleanup.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import 'device_rename_dialog.dart';

typedef DeviceRemovedCallback = Future<void> Function(DeviceRecord device);

class DeviceInventoryLabels {
  const DeviceInventoryLabels({
    required this.renameTitle,
    required this.nameField,
    required this.selectTankTitle,
    required this.removeTitle,
    required this.removeConfirm,
  });

  final String renameTitle;
  final String nameField;
  final String selectTankTitle;
  final String removeTitle;
  final String Function(String displayName) removeConfirm;
}

class DeviceInventoryActions {
  const DeviceInventoryActions({required this.ref, this.onRemoved});

  final WidgetRef ref;
  final DeviceRemovedCallback? onRemoved;

  Tank? tankFor(int? id, Iterable<Tank> tanks) {
    if (id == null) return null;
    for (final tank in tanks) {
      if (tank.id == id) return tank;
    }
    return null;
  }

  bool canMove(DeviceRecord device, Iterable<Tank> tanks) =>
      tanks.any((tank) => tank.id != device.tankId);

  Future<void> rename(
    BuildContext context,
    DeviceRecord device,
    DeviceInventoryLabels labels,
  ) async {
    final name = await showDeviceRenameDialog(
      context,
      title: labels.renameTitle,
      fieldLabel: labels.nameField,
      initial: device.name ?? '',
    );
    if (name == null) return;
    await ref
        .read(dbProvider)
        .updateDeviceNameTank(
          device.id,
          name: name.isEmpty ? null : name,
          tankId: device.tankId,
        );
  }

  Future<void> move(
    BuildContext context,
    DeviceRecord device,
    DeviceInventoryLabels labels,
  ) async {
    final tanks = ref.read(tanksProvider).value ?? const <Tank>[];
    final tankId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(labels.selectTankTitle),
        children: [
          for (final tank in tanks)
            if (tank.id != device.tankId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, tank.id),
                child: Text(tank.name),
              ),
        ],
      ),
    );
    if (tankId == null) return;
    await ref
        .read(dbProvider)
        .updateDeviceNameTank(device.id, name: device.name, tankId: tankId);
  }

  Future<void> remove(
    BuildContext context,
    DeviceRecord device,
    DeviceInventoryLabels labels,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels.removeTitle),
        content: Text(labels.removeConfirm(deviceDisplayName(device))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(labels.removeTitle),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).deleteDevice(device.id);
    await ref.read(deviceIntegrationRegistryProvider).cleanup(device);
    await onRemoved?.call(device);
  }
}
