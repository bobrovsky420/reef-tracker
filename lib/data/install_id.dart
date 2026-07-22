import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'settings.dart';

/// Install-identity guard against Android OS-level restore (#62).
///
/// The `sync_gdrive_*` keys are device-local by design: the app's own JSON
/// restore preserves them ([SettingKey.deviceLocalKeys]). But Android Auto
/// Backup / device-to-device transfer copies the raw SQLite database verbatim
/// — that channel never goes through `restoreFromBackup`, so the old device's
/// sync identity (plaintext account email, folder id, pushed-hash bookkeeping)
/// would land on the new device and make Settings claim a connected, protected
/// state no live sign-in backs.
///
/// Detection: a random fingerprint is written to **both** the Settings table
/// and a sibling file (`.install_id` in the app documents directory) that the
/// backup rules exclude from OS backup/transfer. The database rides the OS
/// channel, the file does not — so after an OS restore the database carries
/// the *old* install's fingerprint while the file is missing (fresh install)
/// or holds this install's own. [reconcileInstallFingerprint] runs once per
/// process, before the first Drive sync: on mismatch it clears the
/// `sync_gdrive_*` keys (the local half of `disconnectGDrive` — no revoke; the
/// grant belongs to the old device) so the user re-connects deliberately.
///
/// A database with **no** fingerprint proves nothing — it may be a legitimate
/// upgrade from a pre-fingerprint version — so it only seeds, never clears.

/// Name of the fingerprint file, sibling to `reeftracker.sqlite` in the app
/// documents directory. Must stay excluded from OS backup in
/// `backup_rules.xml` and `data_extraction_rules.xml` (both sections) — the
/// whole scheme rests on this file *not* riding the OS channel.
const String kInstallIdFileName = '.install_id';

/// Once-per-process slot: the check is only meaningful before the first Drive
/// sync of a process (an OS restore can't happen while the app runs), and
/// memoizing prevents two near-simultaneous launch/resume callers from
/// minting competing ids. A failed run clears the slot so the next
/// launch/resume retries instead of caching the failure.
Future<void>? _reconciled;

/// Seeds or verifies the install fingerprint, clearing the Google Drive sync
/// identity when the database provably arrived via an OS-level restore or
/// device transfer. Call before the first [runGDriveSyncIfDirty] of the
/// process; concurrent and repeated calls share one run. Throws on I/O
/// failure — callers treat that as "leave everything untouched" (fail open:
/// a broken filesystem must not disconnect a working sync).
Future<void> reconcileInstallFingerprint(AppDatabase db) {
  final existing = _reconciled;
  if (existing != null) return existing;
  late final Future<void> run;
  run = _reconcile(db).then(
    (_) {},
    onError: (Object e, StackTrace s) {
      if (identical(_reconciled, run)) _reconciled = null;
      Error.throwWithStackTrace(e, s);
    },
  );
  return _reconciled = run;
}

/// Clears the once-per-process slot so tests can run the check repeatedly.
void resetInstallFingerprintForTest() => _reconciled = null;

Future<void> _reconcile(AppDatabase db) async {
  final settings = AppSettings(db);
  final docs = await getApplicationDocumentsDirectory();
  final file = File(p.join(docs.path, kInstallIdFileName));

  String? fileId;
  if (await file.exists()) {
    final raw = (await file.readAsString()).trim();
    if (raw.isNotEmpty) fileId = raw;
  }
  final dbId = await settings.readInstallFingerprint();

  if (dbId != null && dbId == fileId) return; // The normal launch: all quiet.

  if (dbId != null) {
    // The database carries another install's fingerprint → it arrived via OS
    // restore/transfer. Drop the old device's sync identity (local clear
    // only — `disconnectGDrive` minus the revoke, which would need the old
    // device's Credential Manager session anyway).
    await settings.setSyncGdriveAccount(null);
    await settings.setSyncGdriveFolderId(null);
    await settings.setSyncGdriveLastPushedHash(null);
    await settings.setSyncGdriveLastPushAt(null);
    await settings.setSyncGdriveLastErrorAt(null);
  }

  // Adopt the file's id when it exists (it *is* this install's identity);
  // otherwise mint one. File first, database second: a crash in between
  // leaves file-without-db, which the next run adopts harmlessly — the
  // reverse order would fabricate a mismatch and clear a fresh connection.
  final id = fileId ?? _newInstallId();
  if (fileId == null) {
    // Atomic tmp+rename like `writeAutoBackup`: a torn write here would
    // read back as a mismatch next launch and spuriously disconnect.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(id, flush: true);
    await tmp.rename(file.path);
  }
  await settings.setInstallFingerprint(id);
}

/// 128 random bits, hex-encoded. Only equality matters; `Random.secure()`
/// merely guarantees two installs can't collide by seeding alike.
String _newInstallId() {
  final rnd = Random.secure();
  return List.generate(
    16,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
