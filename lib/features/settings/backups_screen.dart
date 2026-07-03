import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Lists the rotating automatic backups stored on the device and lets the user
/// restore, share, or delete each one.
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
    return Scaffold(
      appBar: AppBar(title: Text(l.backupsScreenTitle)),
      body: FutureBuilder<List<_BackupEntry>>(
        future: _backups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <_BackupEntry>[];
          if (entries.isEmpty) {
            return _EmptyState(l: l);
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _BackupTile(
              file: entries[i].file,
              stat: entries[i].stat,
              onChanged: _reload,
            ),
          );
        },
      ),
    );
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
              _restore(context, ref, l);
            case 'share':
              _share(context, l);
            case 'delete':
              _delete(context, l);
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

  /// Localized file size: translated unit symbols and the locale's decimal
  /// separator (#42).
  static String _formatSize(AppLocalizations l, int bytes) {
    if (bytes < 1024) return l.sizeBytes('$bytes');
    final kb = bytes / 1024;
    if (kb < 1024) return l.sizeKilobytes(formatLocaleNumber(kb, 1));
    return l.sizeMegabytes(formatLocaleNumber(kb / 1024, 1));
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
