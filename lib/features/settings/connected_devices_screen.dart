import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';

/// Read-only inventory of every connected device (U36): the ReefFactory meters
/// the user added plus the Hanna checker once it has connected for a
/// measurement. Purely informational — managing/removing ReefFactory devices
/// happens on their dashboard; the Hanna row can't be edited here.
class ConnectedDevicesScreen extends ConsumerWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final devicesAsync = ref.watch(allDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.reefDevicesTitle)),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.reefDevicesEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final d in devices) _DeviceTile(device: d)],
          );
        },
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final DeviceRecord device;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isHanna = device.kind == 'hanna';
    final kindLabel =
        isHanna ? l.reefDevicesKindHanna : l.reefDevicesKindReefFactory;
    // ReefFactory shows its LAN address; Hanna is Bluetooth (no address).
    final connection = isHanna ? l.reefDevicesBluetooth : (device.address ?? '');
    final parts = [
      kindLabel,
      if (device.model != null && device.model!.isNotEmpty) device.model!,
      if (connection.isNotEmpty) connection,
    ];
    final seen = device.lastSeenAt;

    return ListTile(
      leading: Icon(isHanna ? Icons.bluetooth : Icons.sensors),
      title: Text(device.name ?? device.model ?? device.identifier),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts.join('  ·  ')),
          if (seen != null)
            Text(
              l.reefDevicesLastSeen(
                MaterialLocalizations.of(context).formatShortDate(seen),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      isThreeLine: seen != null,
    );
  }
}
