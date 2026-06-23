import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/units.dart';

/// Settings: unit preferences, tools, and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final prefs = ref.watch(unitPrefsProvider);
    final db = ref.read(dbProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Units'),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: const Text('Temperature'),
            subtitle: const Text('Unit used across the app'),
            trailing: SegmentedButton<TempUnit>(
              segments: const [
                ButtonSegment(value: TempUnit.celsius, label: Text('°C')),
                ButtonSegment(value: TempUnit.fahrenheit, label: Text('°F')),
              ],
              selected: {prefs.temp},
              onSelectionChanged: (s) =>
                  db.setSetting(kTempUnitKey, s.first.name),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('Salinity'),
            subtitle: const Text('Unit used across the app'),
            trailing: SegmentedButton<SalinityUnit>(
              segments: const [
                ButtonSegment(value: SalinityUnit.ppt, label: Text('ppt')),
                ButtonSegment(value: SalinityUnit.sg, label: Text('SG')),
              ],
              selected: {prefs.salinity},
              onSelectionChanged: (s) =>
                  db.setSetting(kSalinityUnitKey, s.first.name),
            ),
          ),
          const Divider(),
          const _SectionHeader('Tools'),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Salinity calculator'),
            subtitle: const Text('Convert ppt ↔ specific gravity (SG)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/calculator/salinity'),
          ),
          const Divider(),
          const _SectionHeader('About'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
