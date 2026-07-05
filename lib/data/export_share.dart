import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Filename prefix of full-backup JSON exports (`exportBackup`). Used to
/// recognize (and sweep) our own leftovers in the temp directory.
const String kBackupExportPrefix = 'reeftracker-backup-';

/// Filename prefix of measurement CSV exports (`exportReadingsCsv`).
const String kCsvExportPrefix = 'reeftracker-readings-';

/// Whether [name] matches one of our export naming patterns. Only such files
/// are ever swept — foreign files in the shared temp/cache dirs are untouched.
bool _isOurExport(String name) =>
    (name.startsWith(kBackupExportPrefix) && name.endsWith('.json')) ||
    (name.startsWith(kCsvExportPrefix) && name.endsWith('.csv'));

/// Stages [content] as a temp file named [fileName] and hands it to the OS
/// share sheet.
///
/// Exports are plaintext copies of user data, so the staging file is deleted
/// as soon as the share sheet returns, and any leftovers from earlier runs
/// (e.g. a process killed mid-share) are swept first. share_plus keeps its
/// *own* copy of every shared file under `<temp>/share_plus/` and clears it
/// only on the next share (#35): when the sheet is dismissed no receiver
/// holds the content URI, so that copy is deleted at once; after a completed
/// share the target app may still be streaming it, so it is left for the next
/// export's sweep instead.
Future<void> shareExportFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  await _sweepStaleExports(dir);
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(content);

  try {
    final result = await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType, name: fileName),
    ], subject: fileName);
    if (result.status == ShareResultStatus.dismissed) {
      await _sweepSharePlusCopies(dir);
    }
  } finally {
    if (await file.exists()) await file.delete();
  }
}

/// Best-effort deletion of stale plaintext export files left in [dir] by
/// earlier exports — both our own staging files and the copies share_plus
/// keeps under its cache subfolder. Never throws — a failed sweep must not
/// block a new export.
Future<void> _sweepStaleExports(Directory dir) async {
  try {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (_isOurExport(p.basename(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {
          // Ignore; another export may be sharing it right now.
        }
      }
    }
  } catch (_) {
    // Temp dir unreadable; nothing to sweep.
  }
  await _sweepSharePlusCopies(dir);
}

/// Deletes our export copies from share_plus's `share_plus/` cache subfolder
/// (it copies every shared XFile there and clears the folder itself only on
/// the *next* share, #35). Only files matching our export naming are touched.
/// Best-effort, never throws.
Future<void> _sweepSharePlusCopies(Directory tempDir) async {
  try {
    final shareDir = Directory(p.join(tempDir.path, 'share_plus'));
    await for (final entity in shareDir.list()) {
      if (entity is! File) continue;
      if (_isOurExport(p.basename(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {
          // Ignore; the receiver may still hold it open.
        }
      }
    }
  } catch (_) {
    // Folder absent (no share happened yet) or unreadable; nothing to sweep.
  }
}
