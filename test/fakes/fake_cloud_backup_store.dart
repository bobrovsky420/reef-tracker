import 'dart:io';

import 'package:reeftracker/data/cloud_auth.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';

/// In-memory [CloudBackupStore] for the sync-engine and screen tests — the
/// fake the seam was designed around (U24). Failure modes are switchable per
/// test: [offline] throws [SocketException] from every call, [failWrites]
/// throws a [CloudApiException] from [write], and [invalidateFolder] makes the
/// current folder id stale (404 on use) the way deleting the folder on
/// drive.google.com would.
class FakeCloudBackupStore implements CloudBackupStore {
  /// name → bytes, within the single simulated folder.
  final Map<String, List<int>> files = {};

  /// name → the advisory metadata attached at write time (U35); absent for
  /// files seeded directly into [files] — exactly like pre-metadata uploads.
  final Map<String, Map<String, String>> fileMetadata = {};

  bool offline = false;
  bool failWrites = false;

  /// Thrown from [list] when set — the prune-only failure of #63, where the
  /// upload succeeded but the connection died before the prune's listing.
  Object? listError;

  int ensureFolderCalls = 0;
  int writeCalls = 0;

  String _folderId = 'folder-1';
  final Set<String> _deadFolderIds = {};

  /// Simulates the user deleting the app folder in Drive: the old id keeps
  /// 404ing and the next [ensureFolder] mints a fresh one.
  void invalidateFolder() {
    _deadFolderIds.add(_folderId);
    _folderId = 'folder-${_deadFolderIds.length + 1}';
  }

  void _checkOnline() {
    if (offline) throw const SocketException('offline');
  }

  void _checkFolder(String folderId) {
    if (folderId != _folderId) {
      throw CloudApiException(404, 'folder $folderId not found');
    }
  }

  @override
  Future<String> ensureFolder() async {
    _checkOnline();
    ensureFolderCalls++;
    return _folderId;
  }

  @override
  Future<List<CloudBackupFile>> list(String folderId) async {
    _checkOnline();
    final e = listError;
    if (e != null) throw e;
    _checkFolder(folderId);
    return [
      for (final e in files.entries)
        CloudBackupFile(
          id: e.key,
          name: e.key,
          modifiedAt: DateTime(2026, 1, 1),
          sizeBytes: e.value.length,
          metadata: fileMetadata[e.key] ?? const {},
        ),
    ];
  }

  @override
  Future<List<int>> read(String fileId) async {
    _checkOnline();
    final bytes = files[fileId];
    if (bytes == null) throw CloudApiException(404, 'file $fileId not found');
    return bytes;
  }

  @override
  Future<void> write(
    String folderId,
    String name,
    List<int> bytes, {
    Map<String, String> metadata = const {},
  }) async {
    _checkOnline();
    _checkFolder(folderId);
    if (failWrites) throw const CloudApiException(500, 'write failed');
    writeCalls++;
    files[name] = bytes;
    if (metadata.isNotEmpty) fileMetadata[name] = Map.of(metadata);
  }

  @override
  Future<void> delete(String fileId) async {
    _checkOnline();
    if (files.remove(fileId) == null) {
      throw CloudApiException(404, 'file $fileId not found');
    }
    fileMetadata.remove(fileId);
  }
}

/// In-memory [CloudAuth]: [account] non-null means connect succeeds and
/// silent tokens exist; null simulates a cancelled picker / dead grant.
class FakeCloudAuth implements CloudAuth {
  FakeCloudAuth({this.account = const CloudAccount(email: 'reef@test.dev')});

  CloudAccount? account;
  bool connectThrows = false;
  int disconnectCalls = 0;

  @override
  Future<CloudAccount?> connect() async {
    if (connectThrows) throw Exception('play services unavailable');
    return account;
  }

  @override
  Future<String?> accessToken() async => account == null ? null : 'fake-token';

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    account = null;
  }
}
