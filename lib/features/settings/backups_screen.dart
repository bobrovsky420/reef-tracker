import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/cloud_backup_store.dart';
import '../../data/cloud_sync.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Lists the rotating automatic backups stored on the device — plus, when
/// Drive sync is connected (U24), the backups in the app's Google Drive
/// folder — and lets the user restore, share (local only), or delete each.
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

  @override
  void initState() {
    super.initState();
    _backups = _loadBackups();
  }

  void _reload() => setState(() => _backups = _loadBackups());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Drive section only when connected: without an account there is nothing
    // to list and the screen keeps its original local-only layout.
    final driveConnected =
        ref.watch(syncGdriveAccountProvider).value != null;
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
          return ListView(
            children: [
              if (driveConnected) _SectionLabel(l.backupsLocalSection),
              if (entries.isEmpty)
                // Only reachable with the Drive section below (the full-screen
                // empty state handles the local-only case): a quiet hint keeps
                // the section structure intact.
                ListTile(subtitle: Text(l.noAutoBackups))
              else
                for (final (i, e) in entries.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _BackupTile(file: e.file, stat: e.stat, onChanged: _reload),
                ],
              if (driveConnected) ...[
                const Divider(),
                _SectionLabel(l.backupsDriveSection),
                const _DriveSection(),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Small section header matching the Settings screen's, for the local/Drive
/// split — only shown when both sections are present.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// The backups in the app's Drive folder. Loaded once per screen visit (a
/// network call, not a watchable stream); mutations reload in place.
class _DriveSection extends ConsumerStatefulWidget {
  const _DriveSection();

  @override
  ConsumerState<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends ConsumerState<_DriveSection> {
  late Future<List<CloudBackupFile>> _files;

  @override
  void initState() {
    super.initState();
    _files = _load();
  }

  void _reload() => setState(() => _files = _load());

  Future<List<CloudBackupFile>> _load() async {
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
    return FutureBuilder<List<CloudBackupFile>>(
      future: _files,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          // Offline or the provider said no — either way the local list above
          // stays fully usable; this section just reports itself unavailable.
          return ListTile(
            leading: const Icon(Icons.cloud_off),
            subtitle: Text(l.backupsDriveLoadFailed),
          );
        }
        final files = snapshot.data ?? const <CloudBackupFile>[];
        if (files.isEmpty) {
          return ListTile(subtitle: Text(l.backupsDriveEmpty));
        }
        return Column(
          children: [
            for (final (i, f) in files.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _DriveBackupTile(file: f, onChanged: _reload),
            ],
          ],
        );
      },
    );
  }
}

class _DriveBackupTile extends ConsumerWidget {
  const _DriveBackupTile({required this.file, required this.onChanged});

  final CloudBackupFile file;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final modified = file.modifiedAt?.toLocal();
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      // Drive always reports modifiedTime; the name is the (unlocalized)
      // fallback for a hand-uploaded file that somehow lacks it.
      title: Text(
        modified != null
            ? formatDateTime(context, modified, weekday: false)
            : file.name,
      ),
      subtitle: file.sizeBytes != null
          ? Text(_formatSize(l, file.sizeBytes!))
          : null,
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'restore':
              unawaited(_restore(context, ref, l));
            case 'delete':
              unawaited(_delete(context, ref, l));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'restore', child: Text(l.restore)),
          PopupMenuItem(value: 'delete', child: Text(l.delete)),
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

class _BackupTile extends ConsumerWidget {
  const _BackupTile({
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

    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(when),
      subtitle: Text(size),
      trailing: PopupMenuButton<String>(
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
        itemBuilder: (context) => [
          PopupMenuItem(value: 'restore', child: Text(l.restore)),
          PopupMenuItem(value: 'share', child: Text(l.share)),
          PopupMenuItem(value: 'delete', child: Text(l.delete)),
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
/// separator (#42). Shared by the local and Drive backup tiles.
String _formatSize(AppLocalizations l, int bytes) {
  if (bytes < 1024) return l.sizeBytes('$bytes');
  final kb = bytes / 1024;
  if (kb < 1024) return l.sizeKilobytes(formatLocaleNumber(kb, 1));
  return l.sizeMegabytes(formatLocaleNumber(kb / 1024, 1));
}
