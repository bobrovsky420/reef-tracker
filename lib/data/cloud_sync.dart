import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'auto_backup.dart' show kAutoBackupPrefix;
import 'backup.dart';
import 'cloud_auth.dart';
import 'cloud_backup_store.dart';
import 'database.dart';
import 'settings.dart';

/// Google Drive backup sync engine (U24).
///
/// Backup-**file** sync, not record-level data sync: the engine pushes the
/// current database state as one more timestamped backup document into the
/// app-owned Drive folder and prunes the folder to the newest N — no merging,
/// ever. Multi-device safety comes from the content-hash dirty gate: a device
/// whose data hasn't changed (a read-mostly second phone) hashes clean and
/// never uploads, so it can't bury the writer device's newer file; a stale
/// writer can add an older-stamped file but never destroy a newer one.
///
/// Opportunistic like the local auto-backup (launch/resume/back-up-now, no
/// background workers): `main.dart` calls [runGDriveSyncIfDirty] right after
/// `runAutoBackupIfDue` completes. The engine has its own single-flight slot,
/// mirroring `_autoBackupInFlight`, so a launch and a near-simultaneous
/// resume share one run.
///
/// Everything is injected ([CloudBackupStore], [CloudAuth]) — the engine
/// never touches `google_sign_in` (plugin calls throw under `flutter test`)
/// or the network directly, so `cloud_sync_test.dart` drives it entirely
/// against in-memory fakes.

/// How a [runGDriveSyncIfDirty] run ended. Informational: the run itself
/// records success/failure state in settings; callers only need this for
/// user-visible feedback on the manual "Sync now" path.
enum CloudSyncOutcome {
  /// Sync is not connected (no account) or there is nothing to protect yet.
  skippedDisabled,

  /// The content hash matched the last pushed one — nothing to upload.
  skippedClean,

  /// A backup document was uploaded (and the cloud folder pruned).
  pushed,

  /// No network — not an error; the next launch/resume retries.
  offline,

  /// The provider rejected the call or silent auth failed; the error stamp
  /// (`sync_gdrive_last_error_at`) was recorded and Settings shows it.
  failed,
}

/// In-flight guard mirroring `_autoBackupInFlight` (launch post-frame and a
/// `resumed` event can fire near-simultaneously); concurrent callers share
/// the same run's outcome.
Future<CloudSyncOutcome>? _syncInFlight;

/// Pushes the current database state to Google Drive if the account is
/// connected and the aquarium data changed since the last push. Never throws;
/// failures are stamped into `sync_gdrive_last_error_at` (cleared by the next
/// successful run) and reported as [CloudSyncOutcome.failed].
Future<CloudSyncOutcome> runGDriveSyncIfDirty(
  AppDatabase db, {
  required CloudBackupStore store,
}) {
  final existing = _syncInFlight;
  if (existing != null) return existing;
  late final Future<CloudSyncOutcome> run;
  run = _runGDriveSyncIfDirty(db, store).whenComplete(() {
    if (identical(_syncInFlight, run)) _syncInFlight = null;
  });
  return _syncInFlight = run;
}

Future<CloudSyncOutcome> _runGDriveSyncIfDirty(
  AppDatabase db,
  CloudBackupStore store,
) async {
  final settings = AppSettings(db);
  if (await settings.readSyncGdriveAccount() == null) {
    return CloudSyncOutcome.skippedDisabled;
  }
  // Same "nothing to protect" rule as the local auto-backup: no visible
  // tanks means an empty document that would only evict a useful older file
  // from the cloud rotation.
  if ((await db.getTanks()).isEmpty) return CloudSyncOutcome.skippedDisabled;

  // Encode + hash off the UI isolate (T5): this runs right after the first
  // frame, and the encode is the same cost as the local auto-backup's.
  final json = await encodeBackupFromDb(db);
  final hash = await Isolate.run(() => backupContentHash(json));
  if (hash == await settings.readSyncGdriveLastPushedHash()) {
    return CloudSyncOutcome.skippedClean;
  }

  try {
    var folderId = await settings.readSyncGdriveFolderId();
    folderId ??= await store.ensureFolder();
    await settings.setSyncGdriveFolderId(folderId);
    final name = cloudBackupFileName(DateTime.now());
    try {
      await store.write(folderId, name, utf8.encode(json));
    } on CloudApiException catch (e) {
      // A cached folder id can go stale (the user deleted the folder on
      // drive.google.com); recreate once and retry — any other failure
      // propagates to the error stamp below.
      if (e.statusCode != 404) rethrow;
      folderId = await store.ensureFolder();
      await settings.setSyncGdriveFolderId(folderId);
      await store.write(folderId, name, utf8.encode(json));
    }
    await _pruneCloud(store, folderId, await settings.readAutoBackupKeep());
    await settings.setSyncGdriveLastPushedHash(hash);
    await settings.setSyncGdriveLastPushAt(DateTime.now());
    await settings.setSyncGdriveLastErrorAt(null);
    return CloudSyncOutcome.pushed;
  } on IOException {
    // Offline (DNS failure, no route, timeout): silently retry next time —
    // stamping an error would nag about airplane mode.
    return CloudSyncOutcome.offline;
  } catch (_) {
    try {
      await settings.setSyncGdriveLastErrorAt(DateTime.now());
    } catch (_) {
      // Best-effort: if the DB write fails too there is nothing left to do.
    }
    return CloudSyncOutcome.failed;
  }
}

/// Timestamped cloud filename — the same shape as the local rotation
/// (`reeftracker-auto-<UTC stamp>.json`) so lexical sort is chronological
/// and files are recognizable in drive.google.com.
String cloudBackupFileName(DateTime now) {
  final u = now.toUtc();
  String p2(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${u.year}${p2(u.month)}${p2(u.day)}'
      '-${p2(u.hour)}${p2(u.minute)}${p2(u.second)}'
      '-${u.millisecond.toString().padLeft(3, '0')}';
  return '$kAutoBackupPrefix$stamp.json';
}

/// Deletes the oldest backup files beyond [keep], newest-by-name kept
/// (backup names are UTC-timestamped ⇒ lexical == chronological). Foreign
/// files in the folder (a user could drop anything into it) are ignored.
Future<void> _pruneCloud(
  CloudBackupStore store,
  String folderId,
  int keep,
) async {
  if (keep < 0) keep = 0;
  final files =
      (await store.list(folderId))
          .where(
            (f) =>
                f.name.startsWith(kAutoBackupPrefix) &&
                f.name.endsWith('.json'),
          )
          .toList()
        ..sort((a, b) => b.name.compareTo(a.name));
  for (final stale in files.skip(keep)) {
    try {
      await store.delete(stale.id);
    } catch (_) {
      // Best-effort, like the local prune: a failed delete must not fail the
      // push that just succeeded.
    }
  }
}

/// Records the content hash of a backup document just restored *from* the
/// cloud as "already pushed" (echo suppression): without this, the next
/// launch would hash the freshly restored data as dirty and re-upload the
/// very file the user just downloaded.
Future<void> recordRestoredCloudBackup(AppDatabase db, String json) async {
  final hash = await Isolate.run(() => backupContentHash(json));
  await AppSettings(db).setSyncGdriveLastPushedHash(hash);
}

/// Interactive connect flow driven from Settings: account picker + consent
/// (via [CloudAuth.connect]), then persists the account so sync is on.
/// Returns the connected account, or null when the user cancelled.
Future<CloudAccount?> connectGDrive(AppDatabase db, CloudAuth auth) async {
  final account = await auth.connect();
  if (account == null) return null;
  await AppSettings(db).setSyncGdriveAccount(account.email);
  return account;
}

/// Disconnects: revokes the grant and clears every `sync_gdrive_*` state key,
/// so a later reconnect starts fresh (fresh folder lookup, first push is a
/// full one). Cloud files are left in place — disconnecting the app must not
/// destroy the user's backups.
Future<void> disconnectGDrive(AppDatabase db, CloudAuth auth) async {
  try {
    await auth.disconnect();
  } catch (_) {
    // Revocation is best-effort (may be offline); the local state below is
    // what turns sync off, and the user can always revoke from their Google
    // account settings.
  }
  final settings = AppSettings(db);
  await settings.setSyncGdriveAccount(null);
  await settings.setSyncGdriveFolderId(null);
  await settings.setSyncGdriveLastPushedHash(null);
  await settings.setSyncGdriveLastPushAt(null);
  await settings.setSyncGdriveLastErrorAt(null);
}
