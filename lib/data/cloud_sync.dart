import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'auto_backup.dart' show backupNow, kAutoBackupPrefix;
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

  /// A backup document was uploaded (and the cloud folder pruned,
  /// best-effort).
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
    // Advisory metadata (U35): the launch restore check on *other* devices
    // reads the device name and content hash straight off the listing,
    // without downloading the file.
    final metadata = {
      kCloudMetaDevice: ?await settings.readSyncDeviceName(),
      kCloudMetaContentHash: hash,
    };
    try {
      await store.write(folderId, name, utf8.encode(json), metadata: metadata);
    } on CloudApiException catch (e) {
      // A cached folder id can go stale (the user deleted the folder on
      // drive.google.com); recreate once and retry — any other failure
      // propagates to the error stamp below.
      if (e.statusCode != 404) rethrow;
      folderId = await store.ensureFolder();
      await settings.setSyncGdriveFolderId(folderId);
      await store.write(folderId, name, utf8.encode(json), metadata: metadata);
    }
    // The upload is durable on Drive at this point — record it before the
    // prune (#63), matching the local contract (`writeAutoBackup` first,
    // best-effort prune after). Stamping late would let a prune-only network
    // hiccup discard the push record: the dirty gate re-uploads the identical
    // DB next launch, or a non-IO throw stamps a false "sync failed".
    await settings.setSyncGdriveLastPushedHash(hash);
    await settings.setSyncGdriveLastPushedName(name);
    await settings.setSyncGdriveLastPushAt(DateTime.now());
    await settings.setSyncGdriveLastErrorAt(null);
    try {
      await _pruneCloud(store, folderId, await settings.readAutoBackupKeep());
    } catch (_) {
      // Best-effort, like the local prune: at most one extra stale file is
      // left for the next run to trim.
    }
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

/// Records the content hash — and, when known, the cloud filename — of a
/// backup document just restored *from* the cloud as "already pushed" (echo
/// suppression): without this, the next launch would hash the freshly
/// restored data as dirty and re-upload the very file the user just
/// downloaded (and the launch restore check would re-propose it as foreign).
/// Also clears the dismissed-file marker: the declined proposal is moot once
/// a cloud restore actually happened.
Future<void> recordRestoredCloudBackup(
  AppDatabase db,
  String json, {
  String? fileName,
}) async {
  final hash = await Isolate.run(() => backupContentHash(json));
  final settings = AppSettings(db);
  await settings.setSyncGdriveLastPushedHash(hash);
  if (fileName != null) await settings.setSyncGdriveLastPushedName(fileName);
  await settings.setSyncGdriveDismissedName(null);
}

/// A newer cloud backup another device wrote, found by [checkCloudNewerBackup]
/// and proposed to the user at launch (U35).
class CloudRestoreProposal {
  const CloudRestoreProposal({
    required this.file,
    required this.deviceName,
    required this.diverged,
    this.contents,
  });

  /// The newest foreign backup file in the cloud folder.
  final CloudBackupFile file;

  /// The name of the device that wrote it, or null when unknown (uploaded by
  /// an app version predating device names, or no name was configured there).
  final String? deviceName;

  /// Whether this device's data ALSO changed since its last push/restore
  /// (or has never synced at all while holding data): restoring would discard
  /// local changes, so the prompt must offer an explicit keep-mine choice
  /// instead of a plain fast-forward.
  final bool diverged;

  /// The downloaded document, when the check had to fetch it to identify the
  /// file (no content-hash metadata). Passed along so an accepted restore
  /// doesn't download twice.
  final String? contents;
}

/// Looks for a cloud backup newer than this device's data (U35): the launch
/// pull-check. Returns null when there is nothing to propose — not connected,
/// offline, folder empty, the newest file is this device's own last push or
/// restore, its content is identical to the local data, or the user already
/// dismissed exactly this file.
///
/// Freshness is decided by **lineage, not clocks**: the newest cloud file is
/// foreign iff its name differs from `sync_gdrive_last_pushed_name` (and its
/// content hash from the last pushed hash — covering uploads from before
/// filenames were recorded). Device clocks never order anything; timestamps
/// are display-only. Never throws: any failure (offline, dead grant, garbage
/// file) reads as "nothing to propose" and the next launch retries.
///
/// Must run **before** the launch Drive push: a stale-but-dirty device that
/// pushed first would bury the newer file this check is trying to surface.
Future<CloudRestoreProposal?> checkCloudNewerBackup(
  AppDatabase db, {
  required CloudBackupStore store,
}) async {
  try {
    final settings = AppSettings(db);
    if (await settings.readSyncGdriveAccount() == null) return null;

    var folderId = await settings.readSyncGdriveFolderId();
    List<CloudBackupFile> files;
    try {
      folderId ??= await store.ensureFolder();
      files = await store.list(folderId);
    } on CloudApiException catch (e) {
      // Stale cached folder id — re-resolve once, like the push path.
      if (e.statusCode != 404) rethrow;
      folderId = await store.ensureFolder();
      files = await store.list(folderId);
    }
    await settings.setSyncGdriveFolderId(folderId);

    final backups =
        files
            .where(
              (f) =>
                  f.name.startsWith(kAutoBackupPrefix) &&
                  f.name.endsWith('.json'),
            )
            .toList()
          // UTC-stamped names: lexical desc == newest first.
          ..sort((a, b) => b.name.compareTo(a.name));
    if (backups.isEmpty) return null;
    final newest = backups.first;
    // Over the download cap (#64): the restore action could only fail, so
    // there is nothing to propose (the Manage-backups list shows the error).
    if ((newest.sizeBytes ?? 0) > kCloudBackupMaxBytes) return null;

    // Ours by name — the overwhelmingly common case, settled by the listing
    // alone (one REST call, no download, no local encode).
    if (newest.name == await settings.readSyncGdriveLastPushedName()) {
      return null;
    }

    final lastPushedHash = await settings.readSyncGdriveLastPushedHash();
    var remoteHash = newest.metadata[kCloudMetaContentHash];
    var deviceName = newest.metadata[kCloudMetaDevice];
    String? contents;
    if (remoteHash == null) {
      // Pre-metadata upload: identify it the expensive way, once — the
      // name/hash stamps below settle every later launch.
      contents = utf8.decode(await store.read(newest.id));
      final doc = contents;
      remoteHash = await Isolate.run(() => backupContentHash(doc));
      deviceName ??= backupDeviceName(doc);
    }
    if (remoteHash == lastPushedHash) {
      // Content-identical to this device's own last push/restore (an upload
      // from before filenames were recorded): backfill the name so the next
      // launch takes the cheap path, and stay quiet.
      await settings.setSyncGdriveLastPushedName(newest.name);
      return null;
    }

    if (newest.name == await settings.readSyncGdriveDismissedName()) {
      return null;
    }

    final tanksExist = (await db.getTanks()).isNotEmpty;
    var diverged = false;
    if (tanksExist) {
      final json = await encodeBackupFromDb(db);
      final currentHash = await Isolate.run(() => backupContentHash(json));
      if (currentHash == remoteHash) {
        // Another device pushed data identical to what this one holds —
        // nothing to restore. Adopt the file as this device's synced state so
        // neither the dirty gate nor this check ever reconsiders it.
        await settings.setSyncGdriveLastPushedHash(currentHash);
        await settings.setSyncGdriveLastPushedName(newest.name);
        return null;
      }
      // Diverged = this device holds changes that never reached the cloud:
      // either it drifted since its last push/restore, or it has data but no
      // sync lineage at all (fresh connect on a device with existing data).
      diverged = lastPushedHash == null || currentHash != lastPushedHash;
    }

    return CloudRestoreProposal(
      file: newest,
      deviceName: deviceName,
      diverged: diverged,
      contents: contents,
    );
  } catch (_) {
    // Offline, dead grant, a garbage file where a backup should be — all
    // read as "nothing to propose"; the next launch simply retries. This is
    // a read path: it must never stamp `sync_gdrive_last_error_at`.
    return null;
  }
}

/// Records that the user declined to restore [fileName] (U35): the launch
/// prompt stays quiet until an even newer foreign file appears. Deliberately
/// only prompt suppression — pushes keep following the normal dirty-gate
/// rules.
Future<void> dismissCloudRestore(AppDatabase db, String fileName) =>
    AppSettings(db).setSyncGdriveDismissedName(fileName);

/// Downloads and restores cloud backup [file] into the live database (U35):
/// the accept path of the launch proposal and of the Manage-backups Drive
/// tiles. [contents] skips the download when the caller already holds the
/// document (a proposal that had to fetch it).
///
/// Safety first: when this device holds any data, a local rotating backup is
/// written *before* the replace — so "use cloud backup" on a diverged device
/// is undoable from Manage backups. A failed safety write aborts the restore
/// (rethrows): silently proceeding would make the divergent local data
/// unrecoverable. Then the standard three-stage [importBackup] pipeline runs,
/// and echo suppression records the file as this device's synced state.
Future<void> restoreCloudBackup(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudBackupFile file,
  String? contents,
}) async {
  final doc = contents ?? utf8.decode(await store.read(file.id));
  final data = await Isolate.run(() => decodeBackup(doc));
  if ((await db.getTanks()).isNotEmpty) {
    await backupNow(db);
  }
  await importBackup(db, data);
  await recordRestoredCloudBackup(db, doc, fileName: file.name);
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
  await settings.setSyncGdriveLastPushedName(null);
  await settings.setSyncGdriveDismissedName(null);
  await settings.setSyncGdriveLastPushAt(null);
  await settings.setSyncGdriveLastErrorAt(null);
  // `sync_device_name` deliberately survives: it names this device, not the
  // account relationship, and should greet a later reconnect prefilled.
}
