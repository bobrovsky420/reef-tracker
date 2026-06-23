import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';

/// Settings: language, unit preferences, tools, and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final prefs = ref.watch(unitPrefsProvider);
    final localeCode = ref.watch(localeCodeProvider).value ?? 'system';
    final db = ref.read(dbProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          _SectionHeader(l.languageSection),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(l.language),
            trailing: DropdownButton<String>(
              value: localeCode,
              underline: const SizedBox.shrink(),
              onChanged: (v) => db.setSetting(kLocaleKey, v),
              items: [
                DropdownMenuItem(
                    value: 'system', child: Text(l.languageSystem)),
                DropdownMenuItem(
                    value: 'en', child: Text(l.languageEnglish)),
                DropdownMenuItem(value: 'cs', child: Text(l.languageCzech)),
                DropdownMenuItem(value: 'de', child: Text(l.languageGerman)),
                DropdownMenuItem(value: 'ru', child: Text(l.languageRussian)),
                DropdownMenuItem(value: 'pl', child: Text(l.languagePolish)),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l.unitsSection),
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: Text(l.temperature),
            subtitle: Text(l.unitUsedAcrossApp),
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
            title: Text(l.salinity),
            subtitle: Text(l.unitUsedAcrossApp),
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
          _SectionHeader(l.toolsSection),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: Text(l.salinityCalculator),
            subtitle: Text(l.salinityCalculatorSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/calculator/salinity'),
          ),
          const Divider(),
          _SectionHeader(l.aboutSection),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(l.aquariums),
            trailing: Text('${tanks.length}'),
          ),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: l.appTitle,
            applicationVersion: '1.0.0',
            aboutBoxChildren: [Text(l.aboutDescription)],
            child: Text(l.aboutAppName),
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
