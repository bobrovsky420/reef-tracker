import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/cloud_folder.dart';
import '../../data/cloud_sync.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../data/settings.dart';
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
          // Cloud folder sync (U20). Android-only until the iOS CloudFolder
          // implementation lands (TODO U20 phase 3); gated on the target
          // platform, not dart:io, so widget tests exercise the tiles.
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            SwitchListTile(
              secondary: const Icon(Icons.cloud_sync_outlined),
              title: Text(l.cloudSyncTitle),
              subtitle: Text(l.cloudSyncSubtitle),
              value: ref.watch(cloudSyncEnabledProvider).value ?? false,
              onChanged: (v) => _toggleCloudSync(context, ref, l, v),
            ),
            if (ref.watch(cloudSyncEnabledProvider).value ?? false) ...[
              ListTile(
                leading: const Icon(Icons.folder_shared_outlined),
                title: Text(l.cloudSyncFolder),
                subtitle: Text(switch (ref
                    .watch(cloudSyncFolderNameProvider)
                    .value) {
                  final name? when name.isNotEmpty => name,
                  _ => l.cloudSyncNoFolder,
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _changeCloudFolder(context, ref, l),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(switch (ref.watch(lastCloudSyncAtProvider).value) {
                  final at? => l.cloudSyncLastSynced(
                    formatDateTime(context, at.toLocal(), weekday: false),
                  ),
                  null => l.cloudSyncNeverSynced,
                }),
              ),
              // Persistent warning while pushes fail (same contract as the
              // backup-error row above); the folder tile is the recovery
              // path when the grant was revoked or the folder deleted.
              if (ref.watch(lastCloudSyncErrorAtProvider).value
                  case final errorAt?)
                ListTile(
                  leading: Icon(
                    Icons.cloud_off_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l.cloudSyncLastFailed(
                      formatDateTime(
                        context,
                        errorAt.toLocal(),
                        weekday: false,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l.cloudSyncRestoreTitle),
                subtitle: Text(l.cloudSyncRestoreSubtitle),
                onTap: () => _restoreFromCloud(context, ref, l),
              ),
            ],
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

  // --- cloud folder sync (U20) -----------------------------------------------

  /// Turns cloud sync on/off. Enabling requires a usable folder first: reuse
  /// the stored one when its grant is still valid, otherwise open the system
  /// picker (cancel = the switch stays off). On enable, an immediate manual
  /// backup runs so the folder holds current data right away — its push (and
  /// any failure stamps) ride the normal pipeline.
  Future<void> _toggleCloudSync(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    bool enable,
  ) async {
    final settings = ref.read(settingsProvider);
    if (!enable) {
      await settings.setCloudSyncEnabled(false);
      return;
    }
    final db = ref.read(dbProvider);
    final uri = await settings.readCloudSyncFolderUri();
    var haveFolder = uri != null && await _cloudAccess(uri);
    if (!haveFolder && context.mounted) {
      haveFolder = await _pickCloudFolder(context, settings, l);
    }
    if (!haveFolder) return;
    await settings.setCloudSyncEnabled(true);
    // Fire-and-forget: failures stamp the backup/sync error rows themselves.
    unawaited(backupNow(db).then<void>((_) {}, onError: (_) {}));
  }

  /// The folder tile: re-pick at any time (also the recovery path for a
  /// revoked grant). A successful pick clears the push hash (see
  /// [AppSettings.setCloudSyncFolder]), so the backup triggered here pushes
  /// into the new folder unconditionally.
  Future<void> _changeCloudFolder(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final settings = ref.read(settingsProvider);
    final db = ref.read(dbProvider);
    if (await _pickCloudFolder(context, settings, l)) {
      unawaited(backupNow(db).then<void>((_) {}, onError: (_) {}));
    }
  }

  /// Lists the synced folder's backups in a bottom sheet and funnels the
  /// chosen one through the exact same confirm + three-stage import pipeline
  /// as a file-picker restore.
  Future<void> _restoreFromCloud(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final settings = ref.read(settingsProvider);
    final db = ref.read(dbProvider);
    final uri = await settings.readCloudSyncFolderUri();
    if (uri == null) {
      if (context.mounted) _snack(context, l.cloudSyncNoFolder);
      return;
    }
    final List<CloudFileInfo> files;
    try {
      files = await listCloudSyncBackups(cloudFolderBackend, uri);
    } catch (_) {
      if (context.mounted) _snack(context, l.cloudSyncListFailed);
      return;
    }
    if (files.isEmpty) {
      if (context.mounted) _snack(context, l.cloudSyncNoBackups);
      return;
    }
    if (!context.mounted) return;

    final chosen = await showModalBottomSheet<CloudFileInfo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l.cloudSyncChooseBackup,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final f in files)
              ListTile(
                leading: const Icon(Icons.history),
                // The provider-reported time is best-effort (can be the
                // upload time), but it is the only human-readable stamp we
                // have — the list itself is ordered by the filename's UTC
                // stamp, which is authoritative.
                title: Text(
                  formatDateTime(ctx, f.modified.toLocal(), weekday: false),
                ),
                subtitle: Text(formatFileSize(l, f.size)),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

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
      final bytes = await cloudFolderBackend.read(uri, chosen.name);
      // Decode in a worker isolate (T5); InvalidBackupException crosses the
      // boundary typed.
      final data = await Isolate.run(() => decodeBackupBytes(bytes));
      await importBackup(db, data);
      // Suppress the echo push: local data now equals this file, so record
      // its content hash as "already pushed" — otherwise the next backup
      // would bury the folder's newest file under an identical copy. If the
      // re-encode doesn't reproduce the hash exactly (e.g. the file came
      // from an older app version whose sections encode differently), the
      // cost is one redundant push — fail-safe. utf8 can't throw here:
      // decodeBackupBytes already decoded these bytes.
      await settings.setLastCloudSyncHash(
        cloudSyncContentHash(utf8.decode(bytes)),
      );
      if (context.mounted) _snack(context, l.backupRestored);
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
    }
  }

  /// Opens the system folder picker and stores the choice. Returns whether a
  /// folder was picked (false = cancelled or the picker failed).
  Future<bool> _pickCloudFolder(
    BuildContext context,
    AppSettings settings,
    AppLocalizations l,
  ) async {
    try {
      final picked = await cloudFolderBackend.pickFolder();
      if (picked == null) return false;
      await settings.setCloudSyncFolder(uri: picked.uri, name: picked.name);
      return true;
    } catch (_) {
      if (context.mounted) _snack(context, l.cloudSyncPickFailed);
      return false;
    }
  }

  /// Whether the stored folder is still usable; channel errors read as "no".
  Future<bool> _cloudAccess(String uri) async {
    try {
      return await cloudFolderBackend.checkAccess(uri);
    } catch (_) {
      return false;
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
