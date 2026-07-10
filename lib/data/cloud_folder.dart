import 'package:flutter/services.dart';

/// Abstraction over "a user-picked folder that some cloud provider syncs".
///
/// The production implementation ([SafCloudFolder]) talks to the Android
/// Storage Access Framework through a MethodChannel hosted in
/// `MainActivity.kt`, so the folder can live in Google Drive, Dropbox,
/// OneDrive, an SD card — anything with a documents provider. Tests (and a
/// future iOS implementation, see TODO U20 phase 3) swap in their own
/// [CloudFolder]; this interface is the seam, same pattern as `ReminderSink`.
///
/// A folder is identified by an opaque [String] `uri` (an Android tree URI).
/// The uri and its permission grant are **meaningless on another device** —
/// whatever persists it must be a device-local setting.
abstract class CloudFolder {
  /// Opens the system folder picker and persists a read/write grant for the
  /// choice. Returns null when the user cancels.
  Future<CloudFolderSelection?> pickFolder();

  /// Whether the persisted grant for [uri] is still valid and the folder
  /// still exists and is writable (the user can revoke grants or delete the
  /// folder at any time).
  Future<bool> checkAccess(String uri);

  /// The files (not subfolders) currently in the folder, unordered.
  Future<List<CloudFileInfo>> list(String uri);

  /// Reads the file called [name] in the folder. Throws when absent.
  Future<Uint8List> read(String uri, String name);

  /// Writes [bytes] as [name] in the folder, overwriting an existing file of
  /// that name.
  Future<void> write(String uri, String name, Uint8List bytes);

  /// Deletes [name] from the folder; a missing file is not an error.
  Future<void> delete(String uri, String name);
}

/// A picked folder: the opaque [uri] to operate on plus a human-readable
/// [name] for display (the uri itself is an unreadable content:// blob).
class CloudFolderSelection {
  const CloudFolderSelection({required this.uri, required this.name});
  final String uri;
  final String name;
}

/// One file inside a [CloudFolder], as much as SAF can cheaply tell us.
class CloudFileInfo {
  const CloudFileInfo({
    required this.name,
    required this.modified,
    required this.size,
  });

  final String name;

  /// Provider-reported last modification time. For cloud providers this is
  /// best-effort (may be the upload time) — ordering our own files goes by
  /// the UTC timestamp in the filename, not by this.
  final DateTime modified;
  final int size;
}

/// The Android SAF implementation, backed by the `cloud_folder` channel in
/// `MainActivity.kt`. Every method maps 1:1 onto a channel call; provider I/O
/// runs on a background thread on the platform side.
class SafCloudFolder implements CloudFolder {
  const SafCloudFolder();

  static const _channel = MethodChannel(
    'cz.reeftracker.reeftracker/cloud_folder',
  );

  @override
  Future<CloudFolderSelection?> pickFolder() async {
    final res = await _channel.invokeMapMethod<String, Object?>('pickFolder');
    if (res == null) return null;
    return CloudFolderSelection(
      uri: res['uri']! as String,
      name: res['name'] as String? ?? '',
    );
  }

  @override
  Future<bool> checkAccess(String uri) async =>
      await _channel.invokeMethod<bool>('checkAccess', {'uri': uri}) ?? false;

  @override
  Future<List<CloudFileInfo>> list(String uri) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('list', {
          'uri': uri,
        }) ??
        const [];
    return [
      for (final row in rows)
        CloudFileInfo(
          name: row['name']! as String,
          modified: DateTime.fromMillisecondsSinceEpoch(
            row['modified'] as int? ?? 0,
          ),
          size: row['size'] as int? ?? 0,
        ),
    ];
  }

  @override
  Future<Uint8List> read(String uri, String name) async => (await _channel
      .invokeMethod<Uint8List>('read', {'uri': uri, 'name': name}))!;

  @override
  Future<void> write(String uri, String name, Uint8List bytes) => _channel
      .invokeMethod<void>('write', {'uri': uri, 'name': name, 'bytes': bytes});

  @override
  Future<void> delete(String uri, String name) =>
      _channel.invokeMethod<void>('delete', {'uri': uri, 'name': name});
}
