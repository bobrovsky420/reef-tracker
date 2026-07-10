import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import 'cloud_folder.dart';
import 'database.dart';
import 'settings.dart';

/// Cloud folder sync (U20): after every successful backup, push the backup
/// JSON into a user-picked, provider-synced folder (see `cloud_folder.dart`)
/// so other devices can restore it. Explicitly a one-writer / read-mostly
/// model — restore stays a full replace; nothing merges.

/// Filename prefix of pushed backups in the synced folder. Distinct from the
/// local rotation's `reeftracker-auto-` so a user pointing sync at a folder
/// they also copy manual exports into can tell the two apart. Matching is by
/// prefix only (no `.json` requirement): a SAF provider is allowed to adjust
/// the display name it stores, and a mangled extension must not hide our own
/// file from restore/prune.
const String kCloudSyncPrefix = 'reeftracker-sync-';

/// How many pushed backups to keep in the synced folder. Fixed rather than
/// the local keep setting: the rotation here is only insurance against a
/// truncated newest upload (SAF writes to cloud providers are not atomic;
/// the import checksum rejects a damaged file and the previous one is still
/// there), not an archive.
const int kCloudSyncKeep = 5;

/// The [CloudFolder] backend used when none is passed explicitly — the SAF
/// channel in production; tests swap in a fake. A mutable global rather than
/// a constructor dependency because the push is called from the module-level
/// auto-backup pipeline, which has no object to hang a dependency on.
CloudFolder cloudFolderBackend = const SafCloudFolder();

/// Content hash of a backup document: sha256 over the compact JSON with the
/// volatile parts removed —
///  - `exportedAt` and `checksum` change on every encode by construction;
///  - the whole `settings` section, because it carries per-device stamps
///    (`last_auto_backup_at` is rewritten by every backup) that would make
///    every encode hash differently. Semantically right, not just expedient:
///    restore drops device-local settings anyway, so the hash covers exactly
///    the data a restore would transfer. (The one non-device-local setting,
///    `ro_stages_seeded`, only ever changes together with the RoStages table,
///    which *is* hashed.)
///
/// Implemented as string surgery on the encoded document instead of a
/// decode→strip→re-encode round trip (the document can be MBs). Safe because
/// JSON string escaping guarantees the raw byte sequences `"exportedAt":"`
/// and `,"settings":` cannot occur inside a string value — and `encodeBackup`
/// keeps `settings` as the last section, an invariant pinned by a comment
/// there and by the stability test in `test/cloud_sync_test.dart`. If that
/// ordering ever broke, the failure mode is over-pushing (hash never
/// matches), never a missed push.
String cloudSyncContentHash(String backupJson) {
  var s = backupJson;
  final settingsIdx = s.lastIndexOf(',"settings":');
  if (settingsIdx >= 0) s = '${s.substring(0, settingsIdx)}}';
  s = s.replaceFirst(RegExp(r'"exportedAt":"[^"]*",'), '');
  return sha256.convert(utf8.encode(s)).toString();
}

/// The pushed backups currently in the synced folder, newest first. Ordering
/// goes by the UTC timestamp embedded in the filename (lexical == chrono,
/// same trick as the local rotation), because provider-reported modification
/// times can be upload times. Foreign files are ignored, never touched.
Future<List<CloudFileInfo>> listCloudSyncBackups(
  CloudFolder folder,
  String uri,
) async {
  final files = await folder.list(uri);
  return files.where((f) => f.name.startsWith(kCloudSyncPrefix)).toList()
    ..sort((a, b) => b.name.compareTo(a.name));
}

/// Pushes [backupFile] (the just-written local backup) into the synced
/// folder, if the feature is enabled and the data actually changed since
/// this device's last successful push (see [cloudSyncContentHash]).
///
/// Never throws: the push is a bonus on top of an already-successful local
/// backup, so failures only stamp `last_cloud_sync_error_at` (surfaced as a
/// persistent Settings warning, mirroring the backup-error row) and the next
/// backup retries. Runs inside the auto-backup single-flight slot, so pushes
/// never overlap each other or a concurrent backup.
Future<void> runCloudSyncPushIfEnabled(
  AppDatabase db,
  File backupFile, {
  CloudFolder? folder,
}) async {
  final settings = AppSettings(db);
  if (!await settings.readCloudSyncEnabled()) return;
  final uri = await settings.readCloudSyncFolderUri();
  if (uri == null) return;
  final backend = folder ?? cloudFolderBackend;
  try {
    final json = await backupFile.readAsString();
    final hash = cloudSyncContentHash(json);
    if (hash == await settings.readLastCloudSyncHash()) return;
    // Same UTC stamp format as the local rotation (#13/#14: milliseconds
    // against same-second collisions, UTC so lexical order survives DST).
    final stamp = DateFormat(
      'yyyyMMdd-HHmmss-SSS',
    ).format(DateTime.now().toUtc());
    await backend.write(uri, '$kCloudSyncPrefix$stamp.json', utf8.encode(json));
    await _pruneCloudSyncBackups(backend, uri);
    await settings.setLastCloudSyncHash(hash);
    await settings.setLastCloudSyncAt(DateTime.now());
    await settings.setLastCloudSyncErrorAt(null);
  } catch (_) {
    try {
      await settings.setLastCloudSyncErrorAt(DateTime.now());
    } catch (_) {
      // Best-effort: if even the settings write fails, the DB itself is in
      // trouble and the backup layer's own error path is already reporting.
    }
  }
}

/// Deletes the oldest pushed backups so at most [kCloudSyncKeep] remain.
/// Best-effort per file: a provider refusing one delete must not fail the
/// push that just succeeded.
Future<void> _pruneCloudSyncBackups(CloudFolder folder, String uri) async {
  final files = await listCloudSyncBackups(folder, uri);
  for (final stale in files.skip(kCloudSyncKeep)) {
    try {
      await folder.delete(uri, stale.name);
    } catch (_) {
      // Retried implicitly on the next push's prune.
    }
  }
}
