import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';

/// Read-only inventory of every connected device (U36): the ReefFactory meters
/// and ReefBeat devices the user added plus the Hanna checker once it has
/// connected for a measurement. Purely informational — managing/removing
/// ReefFactory/ReefBeat devices happens on their dashboards; the Hanna row
/// can't be edited here.
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
          // Sort by the displayed name so the list order matches what the
          // user reads on the tiles.
          final sorted = [...devices]
            ..sort(
              (a, b) => _displayName(
                a,
              ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
            );
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final d in sorted) _DeviceTile(device: d)],
          );
        },
      ),
    );
  }
}

String _displayName(DeviceRecord d) => d.name ?? d.model ?? d.identifier;

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final DeviceRecord device;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isHanna = device.kind == 'hanna';
    final kindLabel = switch (device.kind) {
      'hanna' => l.reefDevicesKindHanna,
      'reefbeat' => l.reefDevicesKindReefBeat,
      _ => l.reefDevicesKindReefFactory,
    };
    // LAN devices show their address; Hanna is Bluetooth (no address).
    final connection = isHanna ? l.reefDevicesBluetooth : (device.address ?? '');
    final parts = [
      kindLabel,
      if (device.model != null && device.model!.isNotEmpty) device.model!,
      if (connection.isNotEmpty) connection,
    ];
    final seen = device.lastSeenAt;

    return ListTile(
      leading: Icon(switch (device.kind) {
        'hanna' => Icons.bluetooth,
        'reefbeat' => Icons.water_drop_outlined,
        _ => Icons.sensors,
      }),
      title: Text(_displayName(device)),
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
