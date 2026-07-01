import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup.dart';
import 'database.dart';
import 'settings.dart';

// The auto-backup settings keys, defaults, and the [AutoBackupInterval] enum now
// live in the typed [Settings] facade; re-export so existing importers (and
// tests) that reach them through this library keep working.
export 'settings.dart'
    show
        kAutoBackupEnabledKey,
        kAutoBackupIntervalKey,
        kAutoBackupKeepKey,
        kLastAutoBackupAtKey,
        kAutoBackupDefaultEnabled,
        kAutoBackupDefaultKeep,
        AutoBackupInterval;

/// Filename prefix that distinguishes rotating auto-backups from manually
/// exported files; also makes lexical sort == chronological sort.
const String kAutoBackupPrefix = 'reeftracker-auto-';

/// Resolves (creating if needed) the on-device folder that holds rotating
/// automatic backups. It lives under the app documents directory, so it is
/// included in Android Auto Backup alongside the SQLite database.
Future<Directory> autoBackupDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'backups'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// The rotating auto-backup files, newest first.
Future<List<File>> listAutoBackups() async {
  final dir = await autoBackupDir();
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) {
        final name = p.basename(f.path);
        return name.startsWith(kAutoBackupPrefix) && name.endsWith('.json');
      })
      .toList()
    // Names are timestamp-ordered, so a reverse lexical sort = newest first.
    ..sort((a, b) => b.path.compareTo(a.path));
  return files;
}

/// Deletes the oldest auto-backups so that at most [keep] remain.
Future<void> pruneAutoBackups(int keep) async {
  if (keep < 0) keep = 0;
  final files = await listAutoBackups();
  for (final stale in files.skip(keep)) {
    try {
      await stale.delete();
    } catch (_) {
      // Best-effort cleanup; a failed delete must not abort the backup.
    }
  }
}

/// Writes a fresh auto-backup file now and prunes to [keep] newest. Returns
/// the file written. Does not consult the schedule — callers that want the
/// schedule honored should use [runAutoBackupIfDue].
Future<File> writeAutoBackup(
  AppDatabase db, {
  int keep = kAutoBackupDefaultKeep,
}) async {
  final json = await encodeBackupFromDb(db);
  final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final dir = await autoBackupDir();
  final file = File(p.join(dir.path, '$kAutoBackupPrefix$stamp.json'));
  await file.writeAsString(json);
  await pruneAutoBackups(keep);
  return file;
}

/// Writes a backup immediately, ignoring the schedule, and records it as the
/// most recent backup (so the "last backup" status updates at once). Used by
/// the manual "Back up now" action. Writes into the same rotating auto-backup
/// folder as [runAutoBackupIfDue], so it counts against [kAutoBackupKeepKey]
/// and shows up in the Manage-backups list.
Future<File> backupNow(AppDatabase db) async {
  final keep = await AppSettings(db).readAutoBackupKeep();
  final file = await writeAutoBackup(db, keep: keep);
  await _stampLastBackup(db);
  return file;
}

/// Records "a backup just completed" so the schedule and the visible
/// last-backup status share one source of truth.
Future<void> _stampLastBackup(AppDatabase db) =>
    AppSettings(db).setLastBackupAt(DateTime.now());

/// In-flight guard for [runAutoBackupIfDue]. The launch post-frame callback and
/// a `resumed` lifecycle event can fire almost simultaneously (e.g. resume right
/// after cold start); without this, two runs could both pass the "is due" check,
/// pick the same one-second filename stamp, and each do the full encode/write
/// before either records `last_auto_backup_at`.
Future<void>? _autoBackupInFlight;

/// Takes an automatic backup if the feature is enabled, there is data worth
/// saving, and at least one [AutoBackupInterval] has elapsed since the last
/// one. Safe to call on every launch/resume; it returns quickly when not due.
///
/// Single-flight: while one run is in progress, concurrent callers await the
/// same future instead of starting a second, overlapping backup.
Future<void> runAutoBackupIfDue(AppDatabase db) {
  return _autoBackupInFlight ??=
      _runAutoBackupIfDue(db).whenComplete(() => _autoBackupInFlight = null);
}

Future<void> _runAutoBackupIfDue(AppDatabase db) async {
  final settings = AppSettings(db);
  if (!await settings.readAutoBackupEnabled()) return;

  // Nothing to protect until the user has created at least one aquarium.
  if ((await db.getAllTanks()).isEmpty) return;

  final last = await settings.readLastBackupAt();
  if (last != null) {
    final interval = await settings.readAutoBackupInterval();
    if (DateTime.now().difference(last) < interval.period) return;
  }

  await writeAutoBackup(db, keep: await settings.readAutoBackupKeep());
  await _stampLastBackup(db);
}
