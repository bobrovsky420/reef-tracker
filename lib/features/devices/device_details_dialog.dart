import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/device_vendors.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// The facts about a device that aren't on its card: which brand it is, its
/// model code, where it lives on the network and when the app last reached it.
///
/// This is where the read-only Settings inventory went (U41). That page listed
/// every device with exactly these fields; folding it into the card menus keeps
/// the information — including for a Standard install, since the Devices screen
/// itself is ungated — without a second screen listing the same devices again.
Future<void> showDeviceDetailsDialog(
  BuildContext context,
  DeviceRecord device,
) {
  final l = AppLocalizations.of(context);
  final kindLabel = l.deviceVendorName(device.kind);
  final seen = device.lastSeenAt;
  // A LAN device shows its address; the Hanna checker is Bluetooth and has
  // none.
  final connection = device.kind == kDeviceKindHanna
      ? l.reefDevicesBluetooth
      : (device.address ?? '');
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(deviceDisplayName(device)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kindLabel),
          if (device.model != null && device.model!.isNotEmpty)
            Text(
              device.model!,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          if (connection.isNotEmpty)
            Text(
              connection,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          if (seen != null) ...[
            const SizedBox(height: 8),
            Text(
              l.reefDevicesLastSeen(
                MaterialLocalizations.of(ctx).formatShortDate(seen),
              ),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.close),
        ),
      ],
    ),
  );
}
