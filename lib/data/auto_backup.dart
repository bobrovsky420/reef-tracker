import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup.dart';
import 'database.dart';

/// Settings keys driving the automatic backup feature.
const kAutoBackupEnabledKey = 'auto_backup_enabled';
const kAutoBackupIntervalKey = 'auto_backup_interval';
const kAutoBackupKeepKey = 'auto_backup_keep';
const kLastAutoBackupAtKey = 'last_auto_backup_at';

/// Defaults applied when the corresponding setting has never been written.
const bool kAutoBackupDefaultEnabled = true;
const int kAutoBackupDefaultKeep = 5;

/// Filename prefix that distinguishes rotating auto-backups from manually
/// exported files; also makes lexical sort == chronological sort.
const String kAutoBackupPrefix = 'reeftracker-auto-';

/// How often an automatic backup is taken (opportunistically, on app launch
/// or resume — see [runAutoBackupIfDue]).
enum AutoBackupInterval {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7));

  const AutoBackupInterval(this.period);

  /// Minimum time that must elapse between two automatic backups.
  final Duration period;

  static AutoBackupInterval fromName(String? name) =>
      AutoBackupInterval.values.firstWhere(
        (e) => e.name == name,
        orElse: () => AutoBackupInterval.daily,
      );
}

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
  final enabledRaw = await db.getSetting(kAutoBackupEnabledKey);
  final enabled =
      enabledRaw == null ? kAutoBackupDefaultEnabled : enabledRaw == 'true';
  if (!enabled) return;

  // Nothing to protect until the user has created at least one aquarium.
  if ((await db.getAllTanks()).isEmpty) return;

  final lastMillis = int.tryParse(await db.getSetting(kLastAutoBackupAtKey) ?? '');
  if (lastMillis != null) {
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    final interval =
        AutoBackupInterval.fromName(await db.getSetting(kAutoBackupIntervalKey));
    if (DateTime.now().difference(last) < interval.period) return;
  }

  final keep = int.tryParse(await db.getSetting(kAutoBackupKeepKey) ?? '') ??
      kAutoBackupDefaultKeep;
  await writeAutoBackup(db, keep: keep);
  await db.setSetting(
    kLastAutoBackupAtKey,
    DateTime.now().millisecondsSinceEpoch.toString(),
  );
}
