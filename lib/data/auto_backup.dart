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
        kLastBackupErrorAtKey,
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
  final files =
      (await dir.list().toList()).whereType<File>().where((f) {
          final name = p.basename(f.path);
          return name.startsWith(kAutoBackupPrefix) && name.endsWith('.json');
        }).toList()
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
  // UTC keeps lexical order == chronological order across DST fall-back, when
  // a local-time stamp would repeat an hour (#14); milliseconds keep two
  // writes within the same second from colliding on one filename (#13).
  final stamp = DateFormat(
    'yyyyMMdd-HHmmss-SSS',
  ).format(DateTime.now().toUtc());
  final dir = await autoBackupDir();
  final file = File(p.join(dir.path, '$kAutoBackupPrefix$stamp.json'));
  // Write to a tmp name and rename (atomic on the same filesystem) so a
  // disk-full or mid-write kill can never leave a truncated `.json` in the
  // rotation — the `.tmp` suffix is invisible to [listAutoBackups] and
  // therefore to [pruneAutoBackups].
  final tmp = File('${file.path}.tmp');
  try {
    await tmp.writeAsString(json, flush: true);
    // Verify before rename (#11 follow-up, T7): read the file back and compare
    // to what was encoded, so a write the filesystem corrupted silently can
    // never enter the rotation as the newest backup. Failure surfaces through
    // the normal backup-error path (`last_backup_error_at`, #22).
    if (await tmp.readAsString() != json) {
      throw FileSystemException('written backup does not match', tmp.path);
    }
    await tmp.rename(file.path);
  } catch (_) {
    try {
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {
      // Best-effort cleanup; the original error is what matters.
    }
    rethrow;
  }
  await pruneAutoBackups(keep);
  return file;
}

/// Writes a backup immediately, ignoring the schedule, and records it as the
/// most recent backup (so the "last backup" status updates at once). Used by
/// the manual "Back up now" action. Writes into the same rotating auto-backup
/// folder as [runAutoBackupIfDue], so it counts against [kAutoBackupKeepKey]
/// and shows up in the Manage-backups list.
///
/// Serialized with the scheduled run (#13): if a launch/resume auto-backup is
/// in flight, the manual write waits for it to finish (even if it fails), and
/// while the manual write runs it occupies the same in-flight slot so a
/// concurrent [runAutoBackupIfDue] awaits it instead of encoding in parallel.
Future<File> backupNow(AppDatabase db) {
  final prior = _autoBackupInFlight;
  final Future<File> run = prior == null
      ? _backupNow(db)
      // A failed scheduled run must not block the manual one queued behind it.
      : prior.catchError((_) => false).then((_) => _backupNow(db));
  // The slot future swallows errors: [run] (returned to the caller) is where
  // failures are handled; the slot only signals "a backup attempt is active".
  // It resolves true either way: a manual backup is a backup event, and even a
  // failed attempt must let a concurrent scheduled caller run the Drive push
  // (the cloud copy matters most when local storage misbehaves).
  late final Future<bool> slot;
  slot = run.then<bool>((_) => true, onError: (_) => true).whenComplete(() {
    if (identical(_autoBackupInFlight, slot)) _autoBackupInFlight = null;
  });
  _autoBackupInFlight = slot;
  return run;
}

Future<File> _backupNow(AppDatabase db) async {
  final keep = await AppSettings(db).readAutoBackupKeep();
  return _writeAndStamp(db, keep: keep);
}

/// Writes the backup, then stamps success — or records the failure in
/// `last_backup_error_at` before rethrowing, so the UI can tell the user their
/// safety net is not being written (#22).
Future<File> _writeAndStamp(AppDatabase db, {required int keep}) async {
  try {
    final file = await writeAutoBackup(db, keep: keep);
    await _stampLastBackup(db);
    return file;
  } catch (_) {
    try {
      await AppSettings(db).setLastBackupErrorAt(DateTime.now());
    } catch (_) {
      // Best-effort: if the DB itself is broken this write fails too, and the
      // original error is the one worth propagating.
    }
    rethrow;
  }
}

/// Records "a backup just completed" so the schedule and the visible
/// last-backup status share one source of truth — and clears any recorded
/// failure, so `last_backup_error_at` always describes the *latest* attempt.
Future<void> _stampLastBackup(AppDatabase db) async {
  final settings = AppSettings(db);
  await settings.setLastBackupAt(DateTime.now());
  await settings.setLastBackupErrorAt(null);
}

/// In-flight guard shared by [runAutoBackupIfDue] and [backupNow]. The launch
/// post-frame callback and a `resumed` lifecycle event can fire almost
/// simultaneously (e.g. resume right after cold start); without this, two runs
/// could both pass the "is due" check and each do the full encode/write before
/// either records `last_auto_backup_at`. [backupNow] occupies the same slot so
/// a manual backup never overlaps a scheduled one (#13). Resolves to whether a
/// backup event happened (see [runAutoBackupIfDue]'s return value).
Future<bool>? _autoBackupInFlight;

/// Takes an automatic backup if the feature is enabled, there is data worth
/// saving, and at least one [AutoBackupInterval] has elapsed since the last
/// one. Safe to call on every launch/resume; it returns quickly when not due.
///
/// Returns whether a backup was written — the Drive push (U24) is coupled to
/// local backup events, so `main.dart` only syncs when this reports true (or
/// the run threw: an attempted-but-failed local write must still push, because
/// the cloud copy matters most when local storage misbehaves).
///
/// Single-flight: while one run is in progress, concurrent callers await the
/// same future instead of starting a second, overlapping backup.
Future<bool> runAutoBackupIfDue(AppDatabase db) {
  final existing = _autoBackupInFlight;
  if (existing != null) return existing;
  late final Future<bool> run;
  run = _runAutoBackupIfDue(db).whenComplete(() {
    // Only clear the slot if a newer run (e.g. a manual backupNow chained
    // behind this one) hasn't taken it over meanwhile.
    if (identical(_autoBackupInFlight, run)) _autoBackupInFlight = null;
  });
  return _autoBackupInFlight = run;
}

Future<bool> _runAutoBackupIfDue(AppDatabase db) async {
  final settings = AppSettings(db);
  if (!await settings.readAutoBackupEnabled()) return false;

  // Nothing to protect until the user has created at least one aquarium.
  // Visible tanks only: soft-deleted ones (U10) are excluded from the encode,
  // so backing up a database holding nothing else would write an empty file
  // into the rotation, evicting a useful older backup.
  if ((await db.getTanks()).isEmpty) return false;

  final last = await settings.readLastBackupAt();
  if (last != null) {
    final interval = await settings.readAutoBackupInterval();
    final sinceLast = DateTime.now().difference(last);
    // A negative difference means the device clock was rolled back past the
    // stamp; treat that as due instead of silently never backing up until the
    // clock catches up with the stamp again (#12).
    if (sinceLast >= Duration.zero && sinceLast < interval.period) {
      return false;
    }
  }

  await _writeAndStamp(db, keep: await settings.readAutoBackupKeep());
  return true;
}
