import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../domain/pro_features.dart';
import 'auto_backup.dart' show backupNow, kAutoBackupPrefix;
import 'backup.dart';
import 'cloud_auth.dart';
import 'cloud_backup_store.dart';
import 'database.dart';
import 'entitlement.dart';
import 'settings.dart';

/// Cloud backup sync engine — Google Drive on Android (U24), iCloud Drive on
/// iOS (U44).
///
/// Backup-**file** sync, not record-level data sync: the engine pushes the
/// current database state as one more timestamped backup document into the
/// app-owned cloud folder and prunes the folder to the newest N — no merging,
/// ever. Multi-device safety comes from the content-hash dirty gate: a device
/// whose data hasn't changed (a read-mostly second phone) hashes clean and
/// never uploads, so it can't bury the writer device's newer file; a stale
/// writer can add an older-stamped file but never destroy a newer one.
///
/// Opportunistic like the local auto-backup (launch/resume/back-up-now, no
/// background workers): `main.dart` calls [runCloudSyncIfDirty] right after
/// `runAutoBackupIfDue` completes. The engine has its own single-flight slot,
/// mirroring `_autoBackupInFlight`, so a launch and a near-simultaneous
/// resume share one run.
///
/// Everything is injected ([CloudBackupStore], [CloudAuth], [CloudSyncState])
/// — the engine never touches `google_sign_in`, a platform channel (both
/// throw under `flutter test`) or the network directly, so
/// `cloud_sync_test.dart` drives it entirely against in-memory fakes. Which
/// provider a device uses is decided once, in `cloudBackupStoreProvider` /
/// `cloudSyncStateProvider` (the U24 platform branch) — the engine itself is
/// provider-blind.

/// Per-provider sync-state pack (U44): everything the engine and the U35
/// checks persist differs between providers only in *which settings keys*
/// hold it (`sync_gdrive_*` vs `sync_icloud_*`) and in what "enabled" means
/// (account presence vs a plain toggle). Kept as one seam so the engine can't
/// half-migrate the way the hand-copied key list once did (#74).
sealed class CloudSyncState {
  const CloudSyncState(this.settings);

  final AppSettings settings;

  /// Whether sync is on for this provider on this device.
  Future<bool> isEnabled();

  /// Cached provider folder id, when this provider caches one (Drive).
  /// Reading null makes the engine call [CloudBackupStore.ensureFolder].
  Future<String?> readFolderId();
  Future<void> setFolderId(String? id);

  Future<String?> readLastPushedHash();
  Future<void> setLastPushedHash(String? hash);
  Future<String?> readLastPushedName();
  Future<void> setLastPushedName(String? name);
  Future<void> setLastPushAt(DateTime? when);
  Future<void> setLastErrorAt(DateTime? when);
  Future<String?> readDismissedName();
  Future<void> setDismissedName(String? name);
}

/// Google Drive keys (U24): the connected account's presence is the on-state,
/// and the Drive folder id is cached (re-resolved on a 404, the user may have
/// deleted the folder on drive.google.com).
class GDriveSyncState extends CloudSyncState {
  const GDriveSyncState(super.settings);

  @override
  Future<bool> isEnabled() async =>
      await settings.readSyncGdriveAccount() != null;
  @override
  Future<String?> readFolderId() => settings.readSyncGdriveFolderId();
  @override
  Future<void> setFolderId(String? id) => settings.setSyncGdriveFolderId(id);
  @override
  Future<String?> readLastPushedHash() =>
      settings.readSyncGdriveLastPushedHash();
  @override
  Future<void> setLastPushedHash(String? hash) =>
      settings.setSyncGdriveLastPushedHash(hash);
  @override
  Future<String?> readLastPushedName() =>
      settings.readSyncGdriveLastPushedName();
  @override
  Future<void> setLastPushedName(String? name) =>
      settings.setSyncGdriveLastPushedName(name);
  @override
  Future<void> setLastPushAt(DateTime? when) =>
      settings.setSyncGdriveLastPushAt(when);
  @override
  Future<void> setLastErrorAt(DateTime? when) =>
      settings.setSyncGdriveLastErrorAt(when);
  @override
  Future<String?> readDismissedName() => settings.readSyncGdriveDismissedName();
  @override
  Future<void> setDismissedName(String? name) =>
      settings.setSyncGdriveDismissedName(name);
}

/// iCloud keys (U44): a plain enabled flag (the Apple ID is the OS's
/// business, there is no account to hold) and **no cached folder id** — the
/// ubiquity container is re-resolved every run by `ensureFolder` (one cheap
/// channel call; a persisted path could go stale across OS updates with no
/// 404-style recovery signal, so [readFolderId] always answers null).
class ICloudSyncState extends CloudSyncState {
  const ICloudSyncState(super.settings);

  @override
  Future<bool> isEnabled() => settings.readSyncIcloudEnabled();
  @override
  Future<String?> readFolderId() async => null;
  @override
  Future<void> setFolderId(String? id) async {}
  @override
  Future<String?> readLastPushedHash() =>
      settings.readSyncIcloudLastPushedHash();
  @override
  Future<void> setLastPushedHash(String? hash) =>
      settings.setSyncIcloudLastPushedHash(hash);
  @override
  Future<String?> readLastPushedName() =>
      settings.readSyncIcloudLastPushedName();
  @override
  Future<void> setLastPushedName(String? name) =>
      settings.setSyncIcloudLastPushedName(name);
  @override
  Future<void> setLastPushAt(DateTime? when) =>
      settings.setSyncIcloudLastPushAt(when);
  @override
  Future<void> setLastErrorAt(DateTime? when) =>
      settings.setSyncIcloudLastErrorAt(when);
  @override
  Future<String?> readDismissedName() => settings.readSyncIcloudDismissedName();
  @override
  Future<void> setDismissedName(String? name) =>
      settings.setSyncIcloudDismissedName(name);
}

/// How a [runCloudSyncIfDirty] run ended. Informational: the run itself
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
  /// (`sync_gdrive_last_error_at` / `sync_icloud_last_error_at`) was recorded
  /// and Settings shows it.
  failed,
}

/// In-flight guard mirroring `_autoBackupInFlight` (launch post-frame and a
/// `resumed` event can fire near-simultaneously); concurrent callers share
/// the same run's outcome. One module-global slot is enough: a device only
/// ever runs one provider (the platform branch in `cloudSyncStateProvider`).
Future<CloudSyncOutcome>? _syncInFlight;

/// Pushes the current database state to the cloud provider if sync is enabled
/// and the aquarium data changed since the last push. Never throws; failures
/// are stamped into the provider's last-error key (cleared by the next
/// successful run) and reported as [CloudSyncOutcome.failed].
Future<CloudSyncOutcome> runCloudSyncIfDirty(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudSyncState state,
}) {
  final existing = _syncInFlight;
  if (existing != null) return existing;
  late final Future<CloudSyncOutcome> run;
  run = _runCloudSyncIfDirty(db, store, state).whenComplete(() {
    if (identical(_syncInFlight, run)) _syncInFlight = null;
  });
  return _syncInFlight = run;
}

Future<CloudSyncOutcome> _runCloudSyncIfDirty(
  AppDatabase db,
  CloudBackupStore store,
  CloudSyncState state,
) async {
  // The whole body sits inside the try (#95): the pre-flight reads and the
  // encode can throw too (a failing DB, an isolate spawn error), and a throw
  // escaping here would break the "Never throws" contract the
  // fire-and-forget callers rely on, bypassing the error stamp.
  try {
    if (!await state.isEnabled()) return CloudSyncOutcome.skippedDisabled;
    // Same "nothing to protect" rule as the local auto-backup: no visible
    // tanks means an empty document that would only evict a useful older file
    // from the cloud rotation.
    if ((await db.getTanks()).isEmpty) return CloudSyncOutcome.skippedDisabled;

    // Encode + hash off the UI isolate (T5): this runs right after the first
    // frame, and the encode is the same cost as the local auto-backup's.
    final json = await encodeBackupFromDb(db);
    final hash = await Isolate.run(() => backupContentHash(json));
    if (hash == await state.readLastPushedHash()) {
      return CloudSyncOutcome.skippedClean;
    }

    var folderId = await state.readFolderId();
    folderId ??= await store.ensureFolder();
    await state.setFolderId(folderId);
    final name = cloudBackupFileName(DateTime.now());
    // Advisory metadata (U35): the launch restore check on *other* devices
    // reads the device name and content hash straight off the listing,
    // without downloading the file. A provider without metadata support
    // (iCloud) drops it; the checks degrade to the download path.
    final metadata = {
      kCloudMetaDevice: ?await state.settings.readSyncDeviceName(),
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
      await state.setFolderId(folderId);
      await store.write(folderId, name, utf8.encode(json), metadata: metadata);
    }
    // The upload is durable at this point (on Drive; on iCloud it is durably
    // queued in the local container for the OS daemon) — record it before the
    // prune (#63), matching the local contract (`writeAutoBackup` first,
    // best-effort prune after). Stamping late would let a prune-only network
    // hiccup discard the push record: the dirty gate re-uploads the identical
    // DB next launch, or a non-IO throw stamps a false "sync failed".
    await state.setLastPushedHash(hash);
    await state.setLastPushedName(name);
    await state.setLastPushAt(DateTime.now());
    await state.setLastErrorAt(null);
    try {
      await _pruneCloud(
        store,
        folderId,
        await state.settings.readAutoBackupKeep(),
        justWritten: name,
      );
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
      await state.setLastErrorAt(DateTime.now());
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
///
/// [justWritten] is the name this run uploaded, and is never a deletion
/// candidate: the folder can already hold [keep] files that sort *newer* than
/// anything this device can mint — a second device with a fast clock, a
/// hand-copied or future-dated file — in which case the fresh push is the
/// first entry past the cut and would be deleted seconds after it landed.
/// The push record is stamped before the prune (#63), so the dirty gate would
/// then read clean and never re-upload: Settings reports "backed up" over a
/// folder holding none of this device's data, indefinitely.
Future<void> _pruneCloud(
  CloudBackupStore store,
  String folderId,
  int keep, {
  String? justWritten,
}) async {
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
  // The exempt file still occupies a slot of the keep budget, so the rotation
  // depth the user chose is honoured either way.
  final mine = files.where((f) => f.name == justWritten).length;
  final others = files.where((f) => f.name != justWritten);
  final budget = (keep - mine).clamp(0, keep);
  for (final stale in others.skip(budget)) {
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
  String json, {
  required CloudSyncState state,
  String? fileName,
}) async {
  final hash = await Isolate.run(() => backupContentHash(json));
  await state.setLastPushedHash(hash);
  if (fileName != null) await state.setLastPushedName(fileName);
  await state.setDismissedName(null);
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
/// foreign iff its name differs from the provider's last-pushed name (and its
/// content hash from the last pushed hash — covering uploads from before
/// filenames were recorded). Device clocks never order anything; timestamps
/// are display-only. Never throws: any failure (offline, dead grant, garbage
/// file) reads as "nothing to propose" and the next launch retries.
///
/// Must run **before** the launch cloud push: a stale-but-dirty device that
/// pushed first would bury the newer file this check is trying to surface.
Future<CloudRestoreProposal?> checkCloudNewerBackup(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudSyncState state,
}) async {
  try {
    if (!await state.isEnabled()) return null;

    var folderId = await state.readFolderId();
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
    await state.setFolderId(folderId);

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
    // alone (one list call, no download, no local encode).
    if (newest.name == await state.readLastPushedName()) {
      return null;
    }

    final lastPushedHash = await state.readLastPushedHash();
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
      await state.setLastPushedName(newest.name);
      return null;
    }

    if (newest.name == await state.readDismissedName()) {
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
        await state.setLastPushedHash(currentHash);
        await state.setLastPushedName(newest.name);
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
    // a read path: it must never stamp the provider's last-error key.
    return null;
  }
}

/// The newest restorable backup in the cloud folder, or null when it holds
/// none — the welcome-screen "Restore from Google Drive / iCloud" path (U35):
/// a fresh, unconnected device adopting the cloud state, so unlike
/// [checkCloudNewerBackup] there is no lineage to compare against and no
/// cached folder id. **Deliberately ungated** (U19: limits gate creation,
/// never access — pulling your own data is access; only ongoing push sync is
/// the Pro feature). Files over the download cap (#64) are skipped — offering
/// one could only fail. Network/provider errors propagate; the caller owns
/// the messaging.
Future<CloudBackupFile?> fetchNewestCloudBackup(CloudBackupStore store) async {
  final folderId = await store.ensureFolder();
  final backups =
      (await store.list(folderId))
          .where(
            (f) =>
                f.name.startsWith(kAutoBackupPrefix) &&
                f.name.endsWith('.json') &&
                (f.sizeBytes ?? 0) <= kCloudBackupMaxBytes,
          )
          .toList()
        ..sort((a, b) => b.name.compareTo(a.name));
  return backups.isEmpty ? null : backups.first;
}

/// Completes the welcome-screen restore (U35) once the user confirmed: the
/// shared [restoreCloudBackup] path, then push sync is turned on — via the
/// caller's [enableSync], which persists the provider's on-state (the Google
/// account on Android, the iCloud toggle on iOS) — **only when the restored
/// data entitles this install** to [ProFeature.cloudSync] (the founder marker
/// rides the backup, so a founder's second device comes out fully synced; a
/// Standard install gets its data and nothing else — the ungated action is
/// the one-shot pull, ongoing sync stays the gated feature). Returns whether
/// sync was turned on, so the UI can word its confirmation.
///
/// [entitlement] is the device-local purchase flag. It is a parameter, not a
/// hardwired false, because this path runs **outside Riverpod** — and a paying
/// user who reinstalls and restores from the welcome screen would otherwise
/// come out with cloud sync switched off, which is the one feature they bought
/// (§10 A3).
Future<bool> completeWelcomeRestore(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudSyncState state,
  required CloudBackupFile file,
  required ProEntitlementStore entitlement,
  required Future<void> Function() enableSync,
}) async {
  await restoreCloudBackup(db, store: store, state: state, file: file);
  final entitled = (await readEntitlement(
    db,
    entitlement: entitlement,
  )).has(ProFeature.cloudSync);
  if (entitled) await enableSync();
  return entitled;
}

/// Records that the user declined to restore [fileName] (U35): the launch
/// prompt stays quiet until an even newer foreign file appears. Deliberately
/// only prompt suppression — pushes keep following the normal dirty-gate
/// rules.
Future<void> dismissCloudRestore(CloudSyncState state, String fileName) =>
    state.setDismissedName(fileName);

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
  required CloudSyncState state,
  required CloudBackupFile file,
  String? contents,
}) async {
  final doc = contents ?? utf8.decode(await store.read(file.id));
  final data = await Isolate.run(() => decodeBackup(doc));
  if ((await db.getTanks()).isNotEmpty) {
    await backupNow(db);
  }
  await importBackup(db, data);
  await recordRestoredCloudBackup(doc, state: state, fileName: file.name);
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
  // Every `sync_gdrive_*` key, derived rather than listed here — the same
  // clear `reconcileInstallFingerprint` runs after a device transfer (#74).
  // `sync_device_name` deliberately survives: it names this device, not the
  // account relationship, and should greet a later reconnect prefilled.
  await AppSettings(db).clearGDriveSyncState();
}

/// Saves the user-chosen device name (U35) and returns whether it actually
/// changed (input is normalized like the setting itself: trimmed, empty ⇒
/// null). A change also clears the pushed-hash dirty gate: `device` is
/// deliberately excluded from [backupContentHash] (a restore must not read
/// dirty), so without this a rename would only reach the cloud with the next
/// real data change — and a device naming itself for the first time (a
/// connect from before the name prompt existed) would keep its whole
/// rotation anonymous until then. Callers kick [runCloudSyncIfDirty] on
/// `true` so a freshly-labeled file appears in the rotation right away.
/// Both providers' hashes are cleared unconditionally — the inactive one's
/// key is null anyway, and the shared name dialog has no business knowing
/// which provider this device runs.
Future<bool> renameSyncDevice(AppDatabase db, String? name) async {
  final settings = AppSettings(db);
  final normalized = AppSettings.decodeSyncDeviceName(name);
  if (normalized == await settings.readSyncDeviceName()) return false;
  await settings.setSyncDeviceName(normalized);
  await settings.setSyncGdriveLastPushedHash(null);
  await settings.setSyncIcloudLastPushedHash(null);
  return true;
}
