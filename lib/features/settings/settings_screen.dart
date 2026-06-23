import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Minimal settings / about screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanks = ref.watch(tanksProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.water),
            title: Text('ReefTracker'),
            subtitle: Text('Track your reef aquarium water parameters'),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Aquariums'),
            trailing: Text('${tanks.length}'),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'ReefTracker',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [
              Text('Offline reef aquarium parameter tracker with history, '
                  'time graphs, and green/amber/red health zones.'),
            ],
          ),
        ],
      ),
    );
  }
}
