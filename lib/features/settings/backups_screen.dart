import 'dart:async';
import 'dart:convert';
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

/// Lists the rotating automatic backups stored on the device — plus, when
/// Drive sync is connected (U24), the backups in the app's Google Drive
/// folder — and lets the user restore, share (local only), or delete each.
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

  /// The Drive folder listing — created lazily on the first connected build
  /// (mirrors the pre-redesign mount-on-connect section), reloaded in place
  /// after mutations. A network call, not a watchable stream.
  Future<List<CloudBackupFile>>? _drive;

  @override
  void initState() {
    super.initState();
    _backups = _loadBackups();
  }

  void _reload() => setState(() => _backups = _loadBackups());

  void _reloadDrive() => setState(() => _drive = _loadDrive());

  Future<List<CloudBackupFile>> _loadDrive() async {
    final store = ref.read(cloudBackupStoreProvider);
    final settings = ref.read(settingsProvider);
    var folderId = await settings.readSyncGdriveFolderId();
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
    await settings.setSyncGdriveFolderId(folderId);
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
    // Drive section only on Android (the U24 surface is Android-only — same
    // deliberate platform branch as the Settings row) and only when
    // connected: otherwise the screen keeps its original local-only layout.
    final driveConnected =
        defaultTargetPlatform == TargetPlatform.android &&
        ref.watch(syncGdriveAccountProvider).value != null;
    if (driveConnected) _drive ??= _loadDrive();
    return Scaffold(
      appBar: AppBar(title: Text(l.backupsScreenTitle)),
      body: FutureBuilder<List<_BackupEntry>>(
        future: _backups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <_BackupEntry>[];
          if (entries.isEmpty && !driveConnected) {
            return _EmptyState(l: l);
          }
          final localSection = ReefSettingsSection(
            // The section label only earns its place when both storages show.
            label: driveConnected ? l.backupsLocalSection : null,
            children: [
              if (entries.isEmpty)
                // Only reachable with the Drive section below (the full-screen
                // empty state handles the local-only case): a quiet hint keeps
                // the section structure intact.
                _QuietRow(text: l.noAutoBackups)
              else
                for (final e in entries)
                  _BackupRow(file: e.file, stat: e.stat, onChanged: _reload),
            ],
          );
          if (!driveConnected) {
            return ReefSettingsList(sections: [localSection]);
          }
          return FutureBuilder<List<CloudBackupFile>>(
            future: _drive,
            builder: (context, driveSnapshot) => ReefSettingsList(
              sections: [
                localSection,
                ReefSettingsSection(
                  label: l.backupsDriveSection,
                  children: _driveRows(l, driveSnapshot),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _driveRows(
    AppLocalizations l,
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
      return [_QuietRow(icon: Icons.cloud_off, text: l.backupsDriveLoadFailed)];
    }
    final files = snapshot.data ?? const <CloudBackupFile>[];
    if (files.isEmpty) {
      return [_QuietRow(text: l.backupsDriveEmpty)];
    }
    return [
      for (final f in files) _DriveBackupRow(file: f, onChanged: _reloadDrive),
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

/// The size sub-line style shared by both row kinds: 12 px mono `textDim`
/// (§A.6 — numerals render in the bundled mono family).
TextStyle _sizeStyle(BuildContext context) => ReefTokens.monoTextStyle.copyWith(
  fontSize: 12,
  color: ReefTokens.of(context).textDim,
);

class _DriveBackupRow extends ConsumerWidget {
  const _DriveBackupRow({required this.file, required this.onChanged});

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
          : file.sizeBytes != null
          ? _formatSize(l, file.sizeBytes!)
          : null,
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
      final bytes = await ref.read(cloudBackupStoreProvider).read(file.id);
      final contents = utf8.decode(bytes);
      // Decode in a worker isolate (T5), same as the local restore path.
      final data = await Isolate.run(() => decodeBackup(contents));
      final db = ref.read(dbProvider);
      await importBackup(db, data);
      // Echo suppression: the restored data must not be re-uploaded as
      // "dirty" on the next launch — it came FROM the cloud.
      await recordRestoredCloudBackup(db, contents);
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
      // UI; InvalidBackupException crosses the boundary typed.
      final contents = await file.readAsString();
      final data = await Isolate.run(() => decodeBackup(contents));
      await importBackup(ref.read(dbProvider), data);
      if (context.mounted) _snack(context, l.backupRestored);
    } on InvalidBackupException catch (e) {
      if (context.mounted) _snack(context, l.backupRejection(e.reason));
    } catch (_) {
      if (context.mounted) _snack(context, l.backupImportFailed);
    }
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
