import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_exclusion.dart';

/// Name of the credential sidecar, sibling to `reeftracker.sqlite` in the app
/// documents directory. Must stay excluded from OS backup in
/// `backup_rules.xml` and `data_extraction_rules.xml` (both sections) — the
/// whole scheme rests on this file *not* riding the OS channel.
const String kDeviceSecretsFileName = '.device_secrets';

/// Device credentials that must never leave this phone (#68).
///
/// An Apex controller is the only device API here that authenticates (U40), so
/// the app has to keep a password. It used to live in `devices.secret`, and the
/// column carried the right *intention* — `_deviceToJson` omits it, so it never
/// rides a backup document, a Drive sync file or a share sheet — but not the
/// enforcement: Android Auto Backup and "copy apps & data" copy the whole
/// SQLite file verbatim, through a channel that never goes past this app's own
/// backup code. The password was therefore uploaded to the user's Google
/// account and copied to any new phone, under a doc comment claiming it
/// couldn't be.
///
/// So the password lives beside the database instead of inside it, in a file
/// the OS is told to leave out of backup and transfer — the same trick #62
/// already uses for `.install_id`:
///
/// - Android: `<exclude domain="root" path="app_flutter/.device_secrets"/>` in
///   `res/xml/backup_rules.xml` (API ≤ 30) and in **both** sections of
///   `res/xml/data_extraction_rules.xml` (API ≥ 31 cloud backup *and* device
///   transfer).
/// - iOS: the `NSURLIsExcludedFromBackupKey` attribute, re-applied after every
///   write (see [excludeFromDeviceBackup]).
///
/// A restored or transferred install therefore finds the row but no password —
/// exactly the state a JSON restore already produced, which `apCredentialsOf`
/// resolves to an `auth` error and the card's "Sign in again" button fixes.
/// Restoring a backup onto *this* phone keeps working silently, because the
/// sidecar never went anywhere.
///
/// The file is plain JSON (`{"<identifier>": "<password>"}`), not encrypted:
/// app-private storage is the boundary here as it is for the rest of the
/// aquarium data, and an Apex password grants nothing beyond the LAN it sits
/// on. What changed is that the boundary is now the one the platform actually
/// enforces.
///
/// The file name is `.device_secrets`, sibling to `reeftracker.sqlite` in the
/// app documents directory.
class DeviceSecrets {
  /// [directory] is injectable so tests can point at a temp dir instead of the
  /// platform's documents directory.
  DeviceSecrets({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  /// Parsed file contents once read. The map is small (one entry per
  /// authenticated device) and read on every controller refresh, so it is held
  /// rather than re-parsed; every write goes through [_store], which keeps the
  /// cache and the file in step.
  Map<String, String>? _cache;

  /// Serializes read-modify-write cycles: two credential saves racing on the
  /// whole-file JSON would otherwise write from the same snapshot and drop one
  /// of the two passwords.
  Future<void> _queue = Future.value();

  /// The stored password for [identifier], or null if there is none — a fresh
  /// install, an OS-level restore, or a device that never had one.
  Future<String?> read(String identifier) =>
      _serialized(() async => (await _loaded())[identifier]);

  /// Stores (or replaces) the password for [identifier].
  Future<void> write(String identifier, String secret) => _serialized(() async {
    final current = await _loaded();
    if (current[identifier] == secret) return;
    await _store({...current, identifier: secret});
  });

  /// Drops the password for [identifier] — called when the device is removed,
  /// so a forgotten controller doesn't leave its login behind.
  Future<void> remove(String identifier) => _serialized(() async {
    final current = await _loaded();
    if (!current.containsKey(identifier)) return;
    await _store({...current}..remove(identifier));
  });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    // Keep the chain alive after a failure: one failed write must not wedge
    // every later read.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, String>> _loaded() async {
    final cached = _cache;
    if (cached != null) return cached;
    final file = await _file();
    var parsed = const <String, String>{};
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          parsed = {
            for (final e in raw.entries)
              if (e.value is String) '${e.key}': e.value as String,
          };
        }
      } on FormatException {
        // A torn or hand-edited file reads as "no passwords stored", which the
        // UI already handles (sign in again). The next write replaces it.
      }
    }
    return _cache = parsed;
  }

  Future<void> _store(Map<String, String> map) async {
    final file = await _file();
    // Atomic tmp + rename like `writeAutoBackup` and `.install_id`: a torn
    // write here would lose every stored password, not just the new one.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(map), flush: true);
    await tmp.rename(file.path);
    // After the rename, not before: the attribute lives on the file the name
    // now points at.
    await excludeFromDeviceBackup(file.path);
    _cache = map;
  }

  Future<File> _file() async =>
      File(p.join((await _directory()).path, kDeviceSecretsFileName));
}
