import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/cloud_sync.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../domain/pro_features.dart';
import '../../domain/stability_score.dart';
import '../../domain/trend.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/reef_segmented.dart';
import '../../widgets/reef_settings.dart';

/// Selectable forecast-horizon values (days), within
/// [kTrendMinHorizon]..[kTrendMaxHorizon].
const _trendHorizonOptions = [3, 7, 14, 30, 60, 90];

/// Standalone Settings route (`/settings`). With tanks present, Settings is
/// the home shell's fourth bottom-nav tab (U33) and nothing pushes this
/// route; it remains for the no-tanks welcome screen, whose settings button
/// needs a pushed screen with a back affordance (Settings → Backups →
/// restore is the reinstall path).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: const SettingsBody(),
    );
  }
}

/// Settings: language, unit preferences, tools, and about — grouped sections
/// rendered by the dialect-aware `ReefSettings*` widgets (REDESIGN #14/#15):
/// inset-grouped cards on the Cupertino dialect, full-width rows with
/// dividers on the M3 dialect. Scaffold-less so the same body serves both the
/// home shell's Settings tab (U33) and the standalone [SettingsScreen].
class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final prefs = ref.watch(unitPrefsProvider);
    final localeCode = ref.watch(localeCodeProvider).value ?? 'system';
    final db = ref.read(dbProvider);
    final settings = ref.read(settingsProvider);
    final trendEnabled =
        ref.watch(trendEnabledProvider).value ?? kTrendDefaultEnabled;
    final roEnabled = ref.watch(roUnitEnabledProvider).value ?? true;
    final microEnabled = ref.watch(microEnabledProvider).value ?? true;
    final autoBackupEnabled =
        ref.watch(autoBackupEnabledProvider).value ?? kAutoBackupDefaultEnabled;
    final experimentalEnabled =
        ref.watch(experimentalEnabledProvider).value ?? false;
    final scanFabEnabled = ref.watch(hannaScanFabProvider).value ?? false;
    final appVersion = ref.watch(appVersionProvider).value ?? '';

    return ReefSettingsList(
      sections: [
        ReefSettingsSection(
          label: l.languageSection,
          children: [
            ReefSettingsRow(
              icon: Icons.translate,
              title: l.language,
              trailing: ReefSettingsDropdown<String>(
                value: localeCode,
                onChanged: (v) => settings.setLocaleCode(v),
                items: [
                  ('system', l.languageSystem),
                  // Sorted alphabetically by native language name (Latin
                  // scripts first), with the system default pinned on top.
                  ('cs', l.languageCzech),
                  ('de', l.languageGerman),
                  ('en', l.languageEnglish),
                  ('fr', l.languageFrench),
                  ('it', l.languageItalian),
                  ('pl', l.languagePolish),
                  ('ru', l.languageRussian),
                ],
              ),
            ),
          ],
        ),
        // Theme mode (REDESIGN #16): the segmented System/Light/Dark choice
        // replacing the mockups' navbar sun/moon toggle.
        ReefSettingsSection(
          label: l.appearanceSection,
          children: [
            ReefSettingsRow(
              icon: Icons.dark_mode_outlined,
              title: l.themeTitle,
              trailing: ReefSegmented<AppThemeMode>(
                options: [
                  (AppThemeMode.system, l.themeSystem),
                  (AppThemeMode.light, l.themeLight),
                  (AppThemeMode.dark, l.themeDark),
                ],
                selected:
                    ref.watch(themeModeProvider).value ?? AppThemeMode.system,
                onChanged: settings.setThemeMode,
              ),
            ),
          ],
        ),
        ReefSettingsSection(
          label: l.unitsSection,
          children: [
            ReefSettingsRow(
              icon: Icons.thermostat,
              title: l.temperature,
              description: l.unitUsedAcrossApp,
              trailing: ReefSegmented<TempUnit>(
                options: const [
                  (TempUnit.celsius, '°C'),
                  (TempUnit.fahrenheit, '°F'),
                ],
                selected: prefs.temp,
                onChanged: settings.setTempUnit,
              ),
            ),
            ReefSettingsRow(
              icon: Icons.water_drop_outlined,
              title: l.salinity,
              description: l.unitUsedAcrossApp,
              trailing: ReefSegmented<SalinityUnit>(
                options: const [
                  (SalinityUnit.ppt, 'ppt'),
                  (SalinityUnit.sg, 'SG'),
                ],
                selected: prefs.salinity,
                onChanged: settings.setSalinityUnit,
              ),
            ),
            ReefSettingsRow(
              icon: Icons.local_drink_outlined,
              title: l.volume,
              description: l.unitUsedAcrossApp,
              trailing: ReefSegmented<VolumeUnit>(
                options: const [
                  (VolumeUnit.liters, 'L'),
                  (VolumeUnit.gallons, 'gal'),
                ],
                selected: prefs.volume,
                onChanged: settings.setVolumeUnit,
              ),
            ),
          ],
        ),
        ReefSettingsSection(
          label: l.dashboardSection,
          children: [
            ReefSettingsRow(
              icon: Icons.dashboard_customize,
              title: l.dashboardLayoutTitle,
              description: l.dashboardLayoutSubtitle,
              trailing: ReefSettingsDropdown<DashboardLayout>(
                value:
                    ref.watch(dashboardLayoutProvider).value ??
                    DashboardLayout.grouped,
                onChanged: settings.setDashboardLayout,
                items: [
                  (DashboardLayout.classic, l.dashboardLayoutFlat),
                  (DashboardLayout.grouped, l.dashboardLayoutGrouped),
                ],
              ),
            ),
            ReefSettingsRow(
              icon: Icons.speed,
              title: l.healthDisplayTitle,
              description: l.healthDisplaySubtitle,
              trailing: ReefSettingsDropdown<HealthDisplay>(
                value:
                    ref.watch(healthDisplayProvider).value ??
                    HealthDisplay.both,
                onChanged: settings.setHealthDisplay,
                items: [
                  (HealthDisplay.both, l.healthDisplayBoth),
                  (HealthDisplay.badge, l.healthDisplayBadge),
                  (HealthDisplay.off, l.healthDisplayOff),
                ],
              ),
            ),
            // Stability window (U26). Only shown to installs entitled to
            // the stability score — a knob for a locked feature would just
            // confuse.
            if (ref.watch(proFeatureProvider(ProFeature.stabilityScore)))
              ReefSettingsRow(
                icon: Icons.waves,
                title: l.stabilityWindowTitle,
                description: l.stabilityWindowSubtitle,
                trailing: ReefSettingsDropdown<int>(
                  value:
                      ref.watch(stabilityWindowProvider).value ??
                      kStabilityWindowDays,
                  onChanged: settings.setStabilityWindow,
                  items: [
                    for (final n in kStabilityWindowChoices)
                      (n, l.trendHorizonDays(n)),
                  ],
                ),
              ),
          ],
        ),
        ReefSettingsSection(
          label: l.trendSection,
          children: [
            ReefSettingsRow(
              icon: Icons.trending_up,
              title: l.trendShowTitle,
              description: l.trendShowSubtitle,
              trailing: Switch.adaptive(
                value: trendEnabled,
                onChanged: (v) => settings.setTrendEnabled(v),
              ),
              onTap: () => settings.setTrendEnabled(!trendEnabled),
            ),
            if (trendEnabled) ...[
              ReefSettingsRow(
                icon: Icons.timeline,
                title: l.trendWindow,
                description: l.trendWindowSubtitle(kTrendMinSpanDays),
                trailing: ReefSettingsDropdown<int>(
                  value:
                      ref.watch(trendWindowProvider).value ??
                      kTrendDefaultWindow,
                  onChanged: settings.setTrendWindow,
                  items: [
                    for (var n = kTrendMinWindow; n <= kTrendMaxWindow; n++)
                      (n, '$n'),
                  ],
                ),
              ),
              ReefSettingsRow(
                icon: Icons.notifications_active_outlined,
                title: l.trendHorizon,
                description: l.trendHorizonSubtitle,
                trailing: ReefSettingsDropdown<int>(
                  value:
                      ref.watch(trendHorizonProvider).value ??
                      kTrendDefaultHorizon,
                  onChanged: settings.setTrendHorizon,
                  items: [
                    for (final n in _trendHorizonOptions)
                      (n, l.trendHorizonDays(n)),
                  ],
                ),
              ),
            ],
          ],
        ),
        ReefSettingsSection(
          children: [
            ReefSettingsRow(
              icon: Icons.notifications_outlined,
              title: l.remindersTitle,
              description: l.remindersSubtitle,
              trailing: const ReefSettingsValue(),
              onTap: () => context.push('/settings/reminders'),
            ),
            ReefSettingsRow(
              icon: Icons.water_drop_outlined,
              title: l.roUnitTitle,
              description: l.roUnitToggleSubtitle,
              trailing: Switch.adaptive(
                value: roEnabled,
                onChanged: (v) => settings.setRoUnitEnabled(v),
              ),
              onTap: () => settings.setRoUnitEnabled(!roEnabled),
            ),
            // Microelements feature switch (U17): off hides the dashboard
            // tile and silences micro test reminders — measurements stay
            // stored.
            ReefSettingsRow(
              icon: Icons.science_outlined,
              title: l.microTitle,
              description: l.microToggleSubtitle,
              trailing: Switch.adaptive(
                value: microEnabled,
                onChanged: (v) => settings.setMicroEnabled(v),
              ),
              onTap: () => settings.setMicroEnabled(!microEnabled),
            ),
          ],
        ),
        ReefSettingsSection(
          label: l.toolsSection,
          children: [
            ReefSettingsRow(
              icon: Icons.calculate_outlined,
              title: l.salinityCalculator,
              description: l.salinityCalculatorSubtitle,
              trailing: const ReefSettingsValue(),
              onTap: () => context.push('/calculator/salinity'),
            ),
          ],
        ),
        // Experimental features (U33/U34): the master switch (default off)
        // hides both features everywhere — here, the Measurements-tab
        // overflow menu and the scan FAB. Off only hides; nothing stored is
        // touched.
        ReefSettingsSection(
          label: l.experimentalSection,
          children: [
            ReefSettingsRow(
              icon: Icons.biotech_outlined,
              title: l.experimentalToggleTitle,
              description: l.experimentalToggleSubtitle,
              trailing: Switch.adaptive(
                value: experimentalEnabled,
                onChanged: (v) => settings.setExperimentalEnabled(v),
              ),
              onTap: () =>
                  settings.setExperimentalEnabled(!experimentalEnabled),
            ),
            if (experimentalEnabled) ...[
              // Hanna checker live measurement (U33). Pro-gated on entry,
              // same idiom as the Drive-sync connect row; hidden entirely on
              // devices without a BLE stack (the manifest keeps Bluetooth
              // optional so Play doesn't filter the app there).
              if (ref.watch(hannaBleSupportedProvider).value ?? true)
                ReefSettingsRow(
                  icon: Icons.bluetooth,
                  title: l.hannaConnectTitle,
                  description: l.hannaConnectSubtitle,
                  trailing: const ReefSettingsValue(),
                  onTap: ref.watch(proFeatureProvider(ProFeature.hannaConnect))
                      ? () => context.push('/hanna/measure')
                      : () => showProFeatureDialog(
                          context,
                          ProFeature.hannaConnect,
                        ),
                ),
              // Checker camera scan (U34) — read a pocket checker's LCD with
              // the camera. Same Pro-gate idiom.
              ReefSettingsRow(
                icon: Icons.photo_camera_outlined,
                title: l.hannaScanTitle,
                description: l.hannaScanSubtitle,
                trailing: const ReefSettingsValue(),
                onTap: ref.watch(proFeatureProvider(ProFeature.hannaScan))
                    ? () => context.push('/hanna/scan')
                    : () => showProFeatureDialog(context, ProFeature.hannaScan),
              ),
              // Opt-in quick-access camera button above "Add reading": most
              // users don't own a pocket checker, so the FAB space is off by
              // default. Without it the scan stays reachable from the
              // Measurements-tab overflow menu and the row above.
              ReefSettingsRow(
                icon: Icons.smart_button,
                title: l.hannaScanFabTitle,
                description: l.hannaScanFabSubtitle,
                trailing: Switch.adaptive(
                  value: scanFabEnabled,
                  onChanged: (v) => settings.setHannaScanFab(v),
                ),
                onTap: () => settings.setHannaScanFab(!scanFabEnabled),
              ),
            ],
          ],
        ),
        ReefSettingsSection(
          label: l.backupSection,
          children: [
            ReefSettingsRow(
              icon: Icons.backup,
              title: l.backupNow,
              description: ref
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
              onTap: () => _backupNow(context, ref, l),
            ),
            // A failed backup attempt is worth a loud, persistent warning:
            // the user believes they are protected while nothing is being
            // written (#22). Cleared automatically by the next successful
            // backup.
            if (ref.watch(lastBackupErrorAtProvider).value case final errorAt?)
              ReefSettingsRow(
                icon: Icons.error_outline,
                iconColor: Theme.of(context).colorScheme.error,
                title: l.backupLastFailed(
                  formatDateTime(context, errorAt.toLocal(), weekday: false),
                ),
                titleColor: Theme.of(context).colorScheme.error,
              ),
            ReefSettingsRow(
              icon: Icons.upload_file_outlined,
              title: l.backupExport,
              description: l.backupExportSubtitle,
              onTap: () => _export(context, db, l),
            ),
            ReefSettingsRow(
              icon: Icons.table_chart_outlined,
              title: l.csvExportTitle,
              description: l.csvExportSubtitle,
              onTap: () => _exportCsv(context, ref, l),
            ),
            ReefSettingsRow(
              icon: Icons.settings_backup_restore,
              title: l.backupImport,
              description: l.backupImportSubtitle,
              onTap: () => _import(context, db, l),
            ),
            ReefSettingsRow(
              icon: Icons.backup_outlined,
              title: l.autoBackupTitle,
              description: l.autoBackupSubtitle,
              trailing: Switch.adaptive(
                value: autoBackupEnabled,
                onChanged: (v) => settings.setAutoBackupEnabled(v),
              ),
              onTap: () => settings.setAutoBackupEnabled(!autoBackupEnabled),
            ),
            if (autoBackupEnabled) ...[
              ReefSettingsRow(
                icon: Icons.schedule,
                title: l.autoBackupFrequency,
                trailing: ReefSettingsDropdown<AutoBackupInterval>(
                  value:
                      ref.watch(autoBackupIntervalProvider).value ??
                      AutoBackupInterval.daily,
                  onChanged: settings.setAutoBackupInterval,
                  items: [
                    (AutoBackupInterval.daily, l.autoBackupDaily),
                    (AutoBackupInterval.weekly, l.autoBackupWeekly),
                  ],
                ),
              ),
              ReefSettingsRow(
                icon: Icons.folder_outlined,
                title: l.manageBackups,
                description: l.manageBackupsSubtitle,
                trailing: const ReefSettingsValue(),
                onTap: () => context.push('/settings/backups'),
              ),
            ],
            // Google Drive sync (U24) — **Android-only surface** (iOS gets
            // its own cloud-backup solution later; the plugin is
            // unconfigured there, so the row would only ever produce an
            // error snackbar). This is the codebase's one deliberate
            // platform branch; defaultTargetPlatform (not dart:io Platform)
            // so widget tests can exercise both sides via
            // debugDefaultTargetPlatformOverride.
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              // Presence of the connected account IS the "on" state (no
              // separate toggle); Pro-gated on the connect action only — a
              // connected account keeps working (U19: limits gate creation,
              // never access).
              if (ref.watch(syncGdriveAccountProvider).value
                  case final account?)
                ReefSettingsRow(
                  icon: Icons.add_to_drive,
                  title: l.syncGdriveTitle,
                  description:
                      '$account\n'
                      '${switch (ref.watch(syncGdriveLastPushAtProvider).value) {
                        final at? => l.syncGdriveLastPush(formatDateTime(context, at.toLocal(), weekday: false)),
                        null => l.syncGdriveNeverPushed,
                      }}',
                  onTap: () => _gdriveOptions(context, ref, l, account),
                )
              else
                ReefSettingsRow(
                  icon: Icons.add_to_drive,
                  title: l.syncGdriveTitle,
                  description: l.syncGdriveSubtitle,
                  onTap: ref.watch(proFeatureProvider(ProFeature.driveSync))
                      ? () => _connectGdrive(context, ref, l)
                      : () =>
                            showProFeatureDialog(context, ProFeature.driveSync),
                ),
              // Same loud-persistent-warning idiom as the local backup
              // (#22): non-null means the latest push attempt failed
              // (offline skips are not recorded), cleared by the next
              // successful push.
              if (ref.watch(syncGdriveLastErrorAtProvider).value
                  case final syncErrorAt?)
                ReefSettingsRow(
                  icon: Icons.cloud_off,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: l.syncGdriveLastFailed(
                    formatDateTime(
                      context,
                      syncErrorAt.toLocal(),
                      weekday: false,
                    ),
                  ),
                  titleColor: Theme.of(context).colorScheme.error,
                ),
            ],
            // Measurement import status/rewind (U32) — only meaningful once
            // something was imported, hidden until then.
            if ((ref.watch(importSourcesProvider).value ?? const []).isNotEmpty)
              ReefSettingsRow(
                icon: Icons.move_to_inbox_outlined,
                title: l.measurementImportSettingsTitle,
                description: l.measurementImportSettingsSubtitle,
                onTap: () => context.push('/settings/import'),
              ),
          ],
        ),
        ReefSettingsSection(
          label: l.aboutSection,
          children: [
            ReefSettingsRow(
              icon: Icons.waves,
              title: l.aquariums,
              trailing: ReefSettingsValue(value: '${tanks.length}'),
              onTap: () => context.push('/tanks'),
            ),
            ReefSettingsRow(
              icon: Icons.help_outline,
              title: l.replayTour,
              description: l.replayTourSubtitle,
              trailing: const ReefSettingsValue(),
              onTap: () async {
                await settings.setTourSeen(false);
                if (context.mounted) context.go('/');
              },
            ),
            // Website links (reeftracker.org), opened in the external
            // browser. The URLs are English-only pages, so no locale suffix.
            ReefSettingsRow(
              icon: Icons.menu_book_outlined,
              title: l.aboutUserGuide,
              description: l.aboutUserGuideSubtitle,
              trailing: const ReefSettingsValue(),
              onTap: () => _openWebsite(context, l, 'guide/'),
            ),
            ReefSettingsRow(
              icon: Icons.contact_support_outlined,
              title: l.aboutSupport,
              description: l.aboutSupportSubtitle,
              trailing: const ReefSettingsValue(),
              onTap: () => _openWebsite(context, l, 'support.html'),
            ),
            ReefSettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: l.aboutPrivacyPolicy,
              trailing: const ReefSettingsValue(),
              onTap: () => _openWebsite(context, l, 'privacy-policy.html'),
            ),
            _EditionRow(
              edition: ref.watch(editionProvider).value ?? AppEdition.standard,
            ),
            ReefSettingsRow(
              icon: Icons.info_outline,
              title: l.aboutAppName,
              onTap: () => showAboutDialog(
                context: context,
                applicationName: l.appTitle,
                applicationVersion: appVersion,
                children: [Text(l.aboutDescription)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens a page of the app's website in the external browser.
  /// `launchUrl` only (no `canLaunchUrl` — that needs extra package-visibility
  /// / Info.plist entries and can false-negative); a `false` return or a
  /// platform exception both land in the same "could not open" SnackBar.
  Future<void> _openWebsite(
    BuildContext context,
    AppLocalizations l,
    String page,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('https://reeftracker.org/$page'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l.linkOpenFailed)));
    }
  }

  Future<void> _backupNow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    try {
      await backupNow(db);
      messenger.showSnackBar(SnackBar(content: Text(l.backupDone)));
    } catch (_) {
      // A local write failed — not an export, so don't claim one did (#23).
      messenger.showSnackBar(SnackBar(content: Text(l.backupNowFailed)));
      return;
    }
    // A manual backup is the user's explicit "protect this now" — mirror it
    // to Drive immediately (U24) instead of waiting for the next launch or
    // resume. The engine's own dirty gate still applies: unchanged data
    // uploads nothing. Fire-and-forget; failures land in the persistent
    // `sync_gdrive_last_error_at` row like every other push.
    unawaited(
      runGDriveSyncIfDirty(db, store: ref.read(cloudBackupStoreProvider)),
    );
  }

  /// Interactive Drive connect (U24): system account picker + consent sheet,
  /// then an immediate first push — the user just asked for cloud backups,
  /// so don't make them wait for the next launch.
  Future<void> _connectGdrive(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    try {
      final account = await connectGDrive(db, ref.read(cloudAuthProvider));
      if (account == null) return; // Cancelled the picker/consent — no noise.
      messenger.showSnackBar(
        SnackBar(content: Text(l.syncGdriveConnectedSnack(account.email))),
      );
      unawaited(
        runGDriveSyncIfDirty(db, store: ref.read(cloudBackupStoreProvider)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.syncGdriveConnectFailed)),
      );
    }
  }

  Future<void> _gdriveOptions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    final disconnect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.add_to_drive),
        title: Text(l.syncGdriveTitle),
        content: Text(l.syncGdriveDialogBody(account)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.syncGdriveDisconnect),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    if (disconnect != true) return;
    await disconnectGDrive(db, ref.read(cloudAuthProvider));
    messenger.showSnackBar(
      SnackBar(content: Text(l.syncGdriveDisconnectedSnack)),
    );
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
class _EditionRow extends StatelessWidget {
  const _EditionRow({required this.edition});
  final AppEdition edition;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final founder = edition == AppEdition.founder;
    final name = founder ? l.editionFounder : l.editionStandard;
    return ReefSettingsRow(
      icon: Icons.workspace_premium_outlined,
      title: l.editionLabel,
      description: name,
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
