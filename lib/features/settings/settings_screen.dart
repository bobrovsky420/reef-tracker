import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../domain/pro_features.dart';
import '../../domain/stability_score.dart';
import '../../domain/trend.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Selectable forecast-horizon values (days), within
/// [kTrendMinHorizon]..[kTrendMaxHorizon].
const _trendHorizonOptions = [3, 7, 14, 30, 60, 90];

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
    final settings = ref.read(settingsProvider);

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
              onChanged: (v) => settings.setLocaleCode(v),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l.languageSystem),
                ),
                DropdownMenuItem(value: 'en', child: Text(l.languageEnglish)),
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
              onSelectionChanged: (s) => settings.setTempUnit(s.first),
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
              onSelectionChanged: (s) => settings.setSalinityUnit(s.first),
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
              onSelectionChanged: (s) => settings.setVolumeUnit(s.first),
            ),
          ),
          const Divider(),
          _SectionHeader(l.dashboardSection),
          ListTile(
            leading: const Icon(Icons.speed),
            title: Text(l.healthDisplayTitle),
            subtitle: Text(l.healthDisplaySubtitle),
            trailing: DropdownButton<HealthDisplay>(
              value:
                  ref.watch(healthDisplayProvider).value ?? HealthDisplay.both,
              underline: const SizedBox.shrink(),
              onChanged: (v) => v == null ? null : settings.setHealthDisplay(v),
              items: [
                DropdownMenuItem(
                  value: HealthDisplay.both,
                  child: Text(l.healthDisplayBoth),
                ),
                DropdownMenuItem(
                  value: HealthDisplay.badge,
                  child: Text(l.healthDisplayBadge),
                ),
                DropdownMenuItem(
                  value: HealthDisplay.off,
                  child: Text(l.healthDisplayOff),
                ),
              ],
            ),
          ),
          // Stability window (U26). Only shown to installs entitled to the
          // stability score — a knob for a locked feature would just confuse.
          if (ref.watch(proFeatureProvider(ProFeature.stabilityScore)))
            ListTile(
              leading: const Icon(Icons.waves),
              title: Text(l.stabilityWindowTitle),
              subtitle: Text(l.stabilityWindowSubtitle),
              trailing: DropdownButton<int>(
                value:
                    ref.watch(stabilityWindowProvider).value ??
                    kStabilityWindowDays,
                underline: const SizedBox.shrink(),
                onChanged: (v) =>
                    v == null ? null : settings.setStabilityWindow(v),
                items: [
                  for (final n in kStabilityWindowChoices)
                    DropdownMenuItem(
                      value: n,
                      child: Text(l.trendHorizonDays(n)),
                    ),
                ],
              ),
            ),
          const Divider(),
          _SectionHeader(l.trendSection),
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: Text(l.trendShowTitle),
            subtitle: Text(l.trendShowSubtitle),
            value:
                ref.watch(trendEnabledProvider).value ?? kTrendDefaultEnabled,
            onChanged: (v) => settings.setTrendEnabled(v),
          ),
          if (ref.watch(trendEnabledProvider).value ??
              kTrendDefaultEnabled) ...[
            ListTile(
              leading: const Icon(Icons.timeline),
              title: Text(l.trendWindow),
              subtitle: Text(l.trendWindowSubtitle(kTrendMinSpanDays)),
              trailing: DropdownButton<int>(
                value:
                    ref.watch(trendWindowProvider).value ?? kTrendDefaultWindow,
                underline: const SizedBox.shrink(),
                onChanged: (v) => v == null ? null : settings.setTrendWindow(v),
                items: [
                  for (var n = kTrendMinWindow; n <= kTrendMaxWindow; n++)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l.trendHorizon),
              subtitle: Text(l.trendHorizonSubtitle),
              trailing: DropdownButton<int>(
                value:
                    ref.watch(trendHorizonProvider).value ??
                    kTrendDefaultHorizon,
                underline: const SizedBox.shrink(),
                onChanged: (v) =>
                    v == null ? null : settings.setTrendHorizon(v),
                items: [
                  for (final n in _trendHorizonOptions)
                    DropdownMenuItem(
                      value: n,
                      child: Text(l.trendHorizonDays(n)),
                    ),
                ],
              ),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l.remindersTitle),
            subtitle: Text(l.remindersSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reminders'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: Text(l.roUnitTitle),
            subtitle: Text(l.roUnitToggleSubtitle),
            value: ref.watch(roUnitEnabledProvider).value ?? true,
            onChanged: (v) => settings.setRoUnitEnabled(v),
          ),
          // Microelements feature switch (U17): off hides the dashboard tile
          // and silences micro test reminders — measurements stay stored.
          SwitchListTile(
            secondary: const Icon(Icons.science_outlined),
            title: Text(l.microTitle),
            subtitle: Text(l.microToggleSubtitle),
            value: ref.watch(microEnabledProvider).value ?? true,
            onChanged: (v) => settings.setMicroEnabled(v),
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
            leading: const Icon(Icons.backup),
            title: Text(l.backupNow),
            subtitle: Text(
              ref
                  .watch(lastBackupAtProvider)
                  .maybeWhen(
                    data: (t) => t == null
                        ? l.backupNeverRun
                        // Shared helper honors the device 12/24-hour
                        // preference (#41).
                        : l.backupLastRun(
                            formatDateTime(
                              context,
                              t.toLocal(),
                              weekday: false,
                            ),
                          ),
                    orElse: () => l.backupNeverRun,
                  ),
            ),
            onTap: () => _backupNow(context, db, l),
          ),
          // A failed backup attempt is worth a loud, persistent warning: the
          // user believes they are protected while nothing is being written
          // (#22). Cleared automatically by the next successful backup.
          if (ref.watch(lastBackupErrorAtProvider).value case final errorAt?)
            ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l.backupLastFailed(
                  formatDateTime(context, errorAt.toLocal(), weekday: false),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l.backupExport),
            subtitle: Text(l.backupExportSubtitle),
            onTap: () => _export(context, db, l),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l.csvExportTitle),
            subtitle: Text(l.csvExportSubtitle),
            onTap: () => _exportCsv(context, ref, l),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l.backupImport),
            subtitle: Text(l.backupImportSubtitle),
            onTap: () => _import(context, db, l),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: Text(l.autoBackupTitle),
            subtitle: Text(l.autoBackupSubtitle),
            value:
                ref.watch(autoBackupEnabledProvider).value ??
                kAutoBackupDefaultEnabled,
            onChanged: (v) => settings.setAutoBackupEnabled(v),
          ),
          if (ref.watch(autoBackupEnabledProvider).value ??
              kAutoBackupDefaultEnabled) ...[
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l.autoBackupFrequency),
              trailing: DropdownButton<AutoBackupInterval>(
                value:
                    ref.watch(autoBackupIntervalProvider).value ??
                    AutoBackupInterval.daily,
                underline: const SizedBox.shrink(),
                onChanged: (v) =>
                    v == null ? null : settings.setAutoBackupInterval(v),
                items: [
                  DropdownMenuItem(
                    value: AutoBackupInterval.daily,
                    child: Text(l.autoBackupDaily),
                  ),
                  DropdownMenuItem(
                    value: AutoBackupInterval.weekly,
                    child: Text(l.autoBackupWeekly),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.manageBackups),
              subtitle: Text(l.manageBackupsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backups'),
            ),
          ],
          const Divider(),
          _SectionHeader(l.aboutSection),
          ListTile(
            leading: const Icon(Icons.waves),
            title: Text(l.aquariums),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${tanks.length}'),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/tanks'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l.replayTour),
            subtitle: Text(l.replayTourSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await settings.setTourSeen(false);
              if (context.mounted) context.go('/');
            },
          ),
          _EditionTile(
            edition: ref.watch(editionProvider).value ?? AppEdition.standard,
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

  Future<void> _backupNow(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await backupNow(db);
      messenger.showSnackBar(SnackBar(content: Text(l.backupDone)));
    } catch (_) {
      // A local write failed — not an export, so don't claim one did (#23).
      messenger.showSnackBar(SnackBar(content: Text(l.backupNowFailed)));
    }
  }

  Future<void> _export(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l,
  ) async {
    try {
      await exportBackup(db);
    } catch (_) {
      if (context.mounted) _snack(context, l.backupExportFailed);
    }
  }

  /// Shares the active aquarium's measurements as a CSV file (U3). Reads
  /// tank/prefs synchronously before the first await so no context or ref is
  /// used across the async gap.
  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final tankId = ref.read(activeTankIdProvider).value;
    if (tankId == null) {
      _snack(context, l.csvExportNoData);
      return;
    }
    final tank = (ref.read(tanksProvider).value ?? const <Tank>[])
        .where((t) => t.id == tankId)
        .firstOrNull;
    try {
      final shared = await exportReadingsCsv(
        ref.read(dbProvider),
        tankId: tankId,
        tankName: tank?.name ?? '',
        prefs: ref.read(unitPrefsProvider),
      );
      // An empty tank is not an error — tell the user why nothing opened.
      if (!shared && context.mounted) _snack(context, l.csvExportNoData);
    } catch (_) {
      if (context.mounted) _snack(context, l.csvExportFailed);
    }
  }

  Future<void> _import(
    BuildContext context,
    AppDatabase db,
    AppLocalizations l,
  ) async {
    final BackupData data;
    try {
      final picked = await pickBackupData();
      if (picked == null) return; // user cancelled the file picker
      data = picked;
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
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
      await importBackup(db, data);
      if (context.mounted) _snack(context, l.backupRestored);
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The Edition row (U19 phase 0): shows whether this install is recognized as
/// an early adopter ("Founder's Edition") or the standard edition; tapping
/// opens a short explanation. Until a Pro build exists every install is
/// seeded as Founder, so the standard branch is dormant future-proofing.
class _EditionTile extends StatelessWidget {
  const _EditionTile({required this.edition});
  final AppEdition edition;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final founder = edition == AppEdition.founder;
    final name = founder ? l.editionFounder : l.editionStandard;
    return ListTile(
      leading: const Icon(Icons.workspace_premium_outlined),
      title: Text(l.editionLabel),
      subtitle: Text(name),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(name),
          content: Text(founder ? l.founderInfoBody : l.standardInfoBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
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
