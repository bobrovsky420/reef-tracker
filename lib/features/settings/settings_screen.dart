import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../data/database.dart';
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
          ListTile(
            leading: const Icon(Icons.local_drink_outlined),
            title: Text(l.volume),
            subtitle: Text(l.unitUsedAcrossApp),
            trailing: SegmentedButton<VolumeUnit>(
              segments: const [
                ButtonSegment(value: VolumeUnit.liters, label: Text('L')),
                ButtonSegment(value: VolumeUnit.gallons, label: Text('gal')),
              ],
              selected: {prefs.volume},
              onSelectionChanged: (s) =>
                  db.setSetting(kVolumeUnitKey, s.first.name),
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
          _SectionHeader(l.backupSection),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l.backupExport),
            subtitle: Text(l.backupExportSubtitle),
            onTap: () => _export(context, db, l),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l.backupImport),
            subtitle: Text(l.backupImportSubtitle),
            onTap: () => _import(context, db, l),
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
            applicationVersion: ref.watch(appVersionProvider).value ?? '',
            aboutBoxChildren: [Text(l.aboutDescription)],
            child: Text(l.aboutAppName),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
      BuildContext context, AppDatabase db, AppLocalizations l) async {
    try {
      await exportBackup(db);
    } catch (_) {
      if (context.mounted) _snack(context, l.backupExportFailed);
    }
  }

  Future<void> _import(
      BuildContext context, AppDatabase db, AppLocalizations l) async {
    final BackupData data;
    try {
      final picked = await pickBackupData();
      if (picked == null) return; // user cancelled the file picker
      data = picked;
    } on InvalidBackupException {
      if (context.mounted) _snack(context, l.backupInvalidFile);
      return;
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.backupRestoreConfirmTitle),
        content: Text(l.backupRestoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.restore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await db.restoreFromBackup(
        tankRows: data.tanks,
        paramRows: data.params,
        readingRows: data.readings,
        waterChangeRows: data.waterChanges,
        carbonChangeRows: data.carbonChanges,
        settingRows: data.settings,
      );
      if (context.mounted) _snack(context, l.backupRestored);
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
