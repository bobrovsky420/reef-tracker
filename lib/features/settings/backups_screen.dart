import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/cloud_backup_store.dart';
import '../../data/cloud_sync.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_menu.dart';
import '../../widgets/reef_settings.dart';
import 'sync_device_name_dialog.dart';

/// Lists the rotating automatic backups stored on the device — plus, when
/// cloud sync is on, the backups in the app's cloud folder (Google Drive on
/// Android, U24; iCloud Drive on iOS, U44) — and lets the user restore,
/// share (local only), or delete each.
///
/// Layout per REDESIGN #23: rebuilt on the `reef_settings.dart` primitives (a
/// Settings push screen speaks the Settings dialect on both platforms) — one
/// labeled section per storage, rows with date title, mono size sub and a
/// trailing overflow menu.
class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

/// A backup file paired with its stat, taken once at list time so tiles never
/// do filesystem I/O inside `build` (T5).
typedef _BackupEntry = ({File file, FileStat stat});

Future<List<_BackupEntry>> _loadBackups() async {
  final files = await listAutoBackups();
  return [for (final f in files) (file: f, stat: await f.stat())];
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  late Future<List<_BackupEntry>> _backups;

  /// The cloud folder listing — created lazily on the first connected build
  /// (mirrors the pre-redesign mount-on-connect section), reloaded in place
  /// after mutations. A network call, not a watchable stream.
  Future<List<CloudBackupFile>>? _cloud;

  @override
  void initState() {
    super.initState();
    _backups = _loadBackups();
  }

  // Block bodies on purpose: with `() => _backups = _loadBackups()` the
  // closure returns the assigned Future, and setState's debug assert throws
  // on a Future-returning callback — reloads silently never happened in
  // debug builds (release strips the assert, which is why it went unnoticed).
  void _reload() => setState(() {
    _backups = _loadBackups();
  });

  void _reloadCloud() => setState(() {
    _cloud = _loadCloud();
  });

  Future<List<CloudBackupFile>> _loadCloud() async {
    final store = ref.read(cloudBackupStoreProvider);
    // The provider-neutral state pack (U44) owns the folder-id caching rules
    // (Drive caches, iCloud re-resolves every time).
    final state = ref.read(cloudSyncStateProvider);
    var folderId = await state.readFolderId();
    List<CloudBackupFile> files;
    try {
      folderId ??= await store.ensureFolder();
      files = await store.list(folderId);
    } on CloudApiException catch (e) {
      // A cached folder id can go stale (folder deleted on drive.google.com);
      // re-resolve once, same as the sync engine's push path.
      if (e.statusCode != 404) rethrow;
      folderId = await store.ensureFolder();
      files = await store.list(folderId);
    }
    await state.setFolderId(folderId);
    return files
        .where(
          (f) =>
              f.name.startsWith(kAutoBackupPrefix) && f.name.endsWith('.json'),
        )
        .toList()
      // UTC-stamped names: lexical desc == newest first, like the local list.
      ..sort((a, b) => b.name.compareTo(a.name));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The cloud section shows only while sync is on — Drive-connected on
    // Android (U24), the iCloud toggle on iOS (U44); same deliberate
    // platform branch as the Settings rows. Otherwise the screen keeps its
    // original local-only layout.
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final cloudConnected = isIos
        ? (ref.watch(syncIcloudEnabledProvider).value ?? false)
        : defaultTargetPlatform == TargetPlatform.android &&
              ref.watch(syncGdriveAccountProvider).value != null;
    if (cloudConnected) _cloud ??= _loadCloud();
    // Connected but nameless (a connect from before the name prompt existed,
    // U35): every file this device uploads shows anonymous in this very list.
    // `hasValue` keeps the row from flashing during the initial settings load.
    final deviceName = ref.watch(syncDeviceNameProvider);
    final nudgeDeviceName =
        cloudConnected && deviceName.hasValue && deviceName.value == null;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupsScreenTitle)),
      body: FutureBuilder<List<_BackupEntry>>(
        future: _backups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <_BackupEntry>[];
          if (entries.isEmpty && !cloudConnected) {
            return _EmptyState(l: l);
          }
          final localSection = ReefSettingsSection(
            // The section label only earns its place when both storages show.
            label: cloudConnected ? l.backupsLocalSection : null,
            children: [
              if (entries.isEmpty)
                // Only reachable with the cloud section below (the full-screen
                // empty state handles the local-only case): a quiet hint keeps
                // the section structure intact.
                _QuietRow(text: l.noAutoBackups)
              else
                for (final e in entries)
                  _BackupRow(file: e.file, stat: e.stat, onChanged: _reload),
            ],
          );
          if (!cloudConnected) {
            return ReefSettingsList(sections: [localSection]);
          }
          return FutureBuilder<List<CloudBackupFile>>(
            future: _cloud,
            builder: (context, cloudSnapshot) => ReefSettingsList(
              sections: [
                localSection,
                ReefSettingsSection(
                  label: isIos ? l.backupsIcloudSection : l.backupsDriveSection,
                  children: [
                    // Above the listing rows, independent of their fate: the
                    // nudge is about this device's own setting, not the
                    // folder contents.
                    if (nudgeDeviceName)
                      _DeviceNameNudgeRow(onPushed: _reloadCloud),
                    ..._cloudRows(l, isIos, cloudSnapshot),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _cloudRows(
    AppLocalizations l,
    bool isIos,
    AsyncSnapshot<List<CloudBackupFile>> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (snapshot.hasError) {
      // Offline or the provider said no — either way the local list above
      // stays fully usable; this section just reports itself unavailable.
      return [
        _QuietRow(
          icon: Icons.cloud_off,
          text: isIos ? l.backupsIcloudLoadFailed : l.backupsDriveLoadFailed,
        ),
      ];
    }
    final files = snapshot.data ?? const <CloudBackupFile>[];
    if (files.isEmpty) {
      return [
        _QuietRow(text: isIos ? l.backupsIcloudEmpty : l.backupsDriveEmpty),
      ];
    }
    return [
      for (final f in files) _CloudBackupRow(file: f, onChanged: _reloadCloud),
    ];
  }
}

/// Muted single-line row for the loading-adjacent sub-states (empty section,
/// Drive unavailable).
class _QuietRow extends StatelessWidget {
  const _QuietRow({this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return ReefSettingsRow(icon: icon, title: text, titleColor: tokens.textDim);
  }
}

/// Call-to-action shown while cloud sync is on but this device has no
/// name set: opens the shared device-name dialog. On an actual change the
/// dialog cleared the dirty gate (see `renameSyncDevice`), so the immediate
/// sync here uploads a labeled file — [onPushed] then reloads the listing so
/// it shows up. The row itself disappears reactively via
/// `syncDeviceNameProvider` the moment the name is saved.
class _DeviceNameNudgeRow extends ConsumerWidget {
  const _DeviceNameNudgeRow({required this.onPushed});

  final VoidCallback onPushed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ReefSettingsRow(
      icon: Icons.smartphone_outlined,
      title: l.backupsDeviceNameNudge,
      description: l.backupsDeviceNameNudgeHint,
      onTap: () => unawaited(_setName(context, ref)),
    );
  }

  Future<void> _setName(BuildContext context, WidgetRef ref) async {
    // Read before the dialog: saving a name unmounts this very row (the
    // `syncDeviceNameProvider` watch), and the disposed element's `ref`
    // throws — which would silently skip the push (caught on-device).
    final db = ref.read(dbProvider);
    final store = ref.read(cloudBackupStoreProvider);
    final state = ref.read(cloudSyncStateProvider);
    if (!await showSyncDeviceNameDialog(context, ref)) return;
    final outcome = await runCloudSyncIfDirty(
      db,
      store: store,
      state: state,
      authorizer: ref.read(proCapabilityAuthorizerProvider),
    );
    // Only a confirmed upload changes the folder contents; offline/failed
    // outcomes are already surfaced by the Settings error row, and reloading
    // here would just repaint the same list.
    if (outcome == CloudSyncOutcome.pushed) onPushed();
  }
}

/// The size sub-line style shared by both row kinds: 12 px mono `textDim`
/// (§A.6 — numerals render in the bundled mono family).
TextStyle _sizeStyle(BuildContext context) => ReefTokens.monoTextStyle.copyWith(
  fontSize: 12,
  color: ReefTokens.of(context).textDim,
);

class _CloudBackupRow extends ConsumerWidget {
  const _CloudBackupRow({required this.file, required this.onChanged});

  final CloudBackupFile file;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final modified = file.modifiedAt?.toLocal();
    // The store refuses downloads past kCloudBackupMaxBytes (#64), so a file
    // the listing already shows as over-size becomes an error tile — no
    // restore action that could only fail; delete stays available.
    final tooLarge = (file.sizeBytes ?? 0) > kCloudBackupMaxBytes;
    // Which device uploaded the file (U35) — advisory metadata, absent on
    // files from app versions predating device names.
    final device = file.metadata[kCloudMetaDevice];
    final subParts = [
      if (file.sizeBytes != null) _formatSize(l, file.sizeBytes!),
      ?device,
    ];
    return ReefSettingsRow(
      icon: tooLarge ? Icons.cloud_off : Icons.cloud_outlined,
      iconColor: tooLarge ? Theme.of(context).colorScheme.error : null,
      // Drive always reports modifiedTime; the name is the (unlocalized)
      // fallback for a hand-uploaded file that somehow lacks it.
      title: modified != null
          ? formatDateTime(context, modified, weekday: false)
          : file.name,
      description: tooLarge
          ? l.backupsDriveTooLarge(_formatSize(l, file.sizeBytes!))
          : subParts.isEmpty
          ? null
          : subParts.join(' · '),
      descriptionStyle: tooLarge
          ? _sizeStyle(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.error)
          : _sizeStyle(context),
      trailing: ReefMenuButton<String>(
        icon: Icons.more_vert,
        onSelected: (action) {
          switch (action) {
            case 'restore':
              unawaited(_restore(context, ref, l));
            case 'delete':
              unawaited(_delete(context, ref, l));
          }
        },
        entries: [
          if (!tooLarge)
            ReefMenuItem(
              value: 'restore',
              icon: Icons.settings_backup_restore,
              label: l.restore,
            ),
          ReefMenuItem(
            value: 'delete',
            icon: Icons.delete_outline,
            label: l.delete,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await _confirm(
      context,
      title: l.backupRestoreConfirmTitle,
      body: l.backupRestoreConfirmBody,
      action: l.restore,
    );
    if (confirmed != true) return;

    try {
      // Shared U35 restore path: local safety backup first, the three-stage
      // import pipeline, then echo suppression (the restored data must not be
      // re-uploaded as "dirty" — it came FROM the cloud).
      await restoreCloudBackup(
        ref.read(dbProvider),
        store: ref.read(cloudBackupStoreProvider),
        state: ref.read(cloudSyncStateProvider),
        file: file,
      );
      if (context.mounted) _snack(context, l.backupRestored);
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
    } catch (_) {
      // Download failed (offline, revoked grant) or the import itself did.
      if (context.mounted) _snack(context, l.backupImportFailed);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await _confirm(
      context,
      title: l.backupDeleteConfirmTitle,
      body: l.backupDeleteConfirmBody,
      action: l.delete,
    );
    if (confirmed != true) return;
    try {
      await ref.read(cloudBackupStoreProvider).delete(file.id);
    } catch (_) {
      // The reload below shows the real state either way.
    }
    onChanged();
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(AppLocalizations.of(ctx).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.backup_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l.noAutoBackups,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l.noAutoBackupsHint,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupRow extends ConsumerWidget {
  const _BackupRow({
    required this.file,
    required this.stat,
    required this.onChanged,
  });

  final File file;
  final FileStat stat;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Shared helper honors the device 12/24-hour preference (#41).
    final when = formatDateTime(context, stat.modified, weekday: false);
    final size = _formatSize(l, stat.size);

    return ReefSettingsRow(
      icon: Icons.history,
      title: when,
      description: size,
      descriptionStyle: _sizeStyle(context),
      trailing: ReefMenuButton<String>(
        icon: Icons.more_vert,
        onSelected: (action) {
          switch (action) {
            case 'restore':
              unawaited(_restore(context, ref, l));
            case 'share':
              unawaited(_share(context, l));
            case 'delete':
              unawaited(_delete(context, l));
          }
        },
        entries: [
          ReefMenuItem(
            value: 'restore',
            icon: Icons.settings_backup_restore,
            label: l.restore,
          ),
          ReefMenuItem(
            value: 'share',
            icon: Icons.share_outlined,
            label: l.share,
          ),
          ReefMenuItem(
            value: 'delete',
            icon: Icons.delete_outline,
            label: l.delete,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
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
      // Decode in a worker isolate (T5) so a large backup doesn't freeze the
      // UI; InvalidBackupException crosses the boundary typed. Contents are
      // read *before* the safety copy below — its rotation prune could
      // otherwise delete the very file being restored.
      final contents = await file.readAsString();
      final data = await Isolate.run(() => decodeBackup(contents));
      final db = ref.read(dbProvider);
      // Safety copy into the rotation before the replace (#94), mirroring
      // `restoreCloudBackup`. A failed write aborts the restore (the catch
      // below) rather than proceeding uncovered.
      if ((await db.getTanks()).isNotEmpty) {
        await backupNow(db);
      }
      await importBackup(db, data);
      if (context.mounted) _snack(context, l.backupRestored);
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
      return;
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
      return;
    }
    // The safety copy changed the folder contents — reload the list so it
    // shows up immediately, same as after a delete. Outside the try: a
    // reload hiccup must not relabel a completed restore as failed.
    onChanged();
  }

  Future<void> _share(BuildContext context, AppLocalizations l) async {
    final name = p.basename(file.path);
    try {
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json', name: name),
      ], subject: name);
    } catch (_) {
      // E.g. the file was pruned/deleted meanwhile, or no share target (#23).
      if (context.mounted) _snack(context, l.backupShareFailed);
    }
  }

  Future<void> _delete(BuildContext context, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.backupDeleteConfirmTitle),
        content: Text(l.backupDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
    } catch (_) {
      // Ignore; the list reload below reflects the real state either way.
    }
    onChanged();
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Localized file size: translated unit symbols and the locale's decimal
/// separator (#42). Shared by the local and Drive backup rows.
String _formatSize(AppLocalizations l, int bytes) {
  if (bytes < 1024) return l.sizeBytes('$bytes');
  final kb = bytes / 1024;
  if (kb < 1024) return l.sizeKilobytes(formatLocaleNumber(kb, 1));
  return l.sizeMegabytes(formatLocaleNumber(kb / 1024, 1));
}
