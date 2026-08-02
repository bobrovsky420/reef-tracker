import 'dart:io';

import 'package:flutter/services.dart';

import 'cloud_backup_store.dart';

/// iCloud Drive implementation of [CloudBackupStore] (U44) — the iOS
/// counterpart of `DriveBackupStore`.
///
/// Files live in the `Documents/` folder of the app's ubiquity container,
/// which `NSUbiquitousContainerIsDocumentScopePublic` makes visible as a
/// "ReefTracker" folder in the Files app — the same browsable-folder property
/// U24 chose the visible Drive folder for. All the actual iCloud work is on
/// the native side (`ICloudBackupChannel` in `ios/Runner/AppDelegate.swift`):
/// nothing in Dart can resolve a ubiquity container, download an evicted
/// file, or coordinate file access. A `write` returns once the document is
/// durably in the local container — the OS daemon uploads it in the
/// background, so the sync engine's `offline` outcome effectively disappears
/// from the push path.
///
/// **No advisory metadata**: iCloud has no `appProperties` analog (extended
/// attributes don't sync reliably), so [write] drops the metadata map and
/// [list] returns files without one — the U35 checks then take their
/// documented degrade path (one download + hash for a foreign newest file).
///
/// Error mapping onto the [CloudBackupStore] contract:
/// - iCloud unavailable (signed out, iCloud Drive off for the app) ⇒
///   [CloudAuthRequiredException] — the fix is user action in the OS
///   Settings, the closest analog of "reconnect".
/// - Download timeout ⇒ [SocketException] — rides the engine's
///   IOException → offline branch (silent retry next launch).
/// - Over the size cap ⇒ [CloudApiException] 413, like `DriveBackupStore`.
/// - Anything else the native side reports ⇒ [CloudApiException] 500, so it
///   lands in the engine's error stamp rather than escaping untyped.
class ICloudBackupStore implements CloudBackupStore {
  ICloudBackupStore({
    MethodChannel? channel,
    this.maxResponseBytes = kCloudBackupMaxBytes,
    this.readTimeout = const Duration(seconds: 60),
  }) : _channel = channel ?? _defaultChannel;

  static const _defaultChannel = MethodChannel('cz.reeftracker/icloud_backup');

  final MethodChannel _channel;

  /// Same ceiling as `DriveBackupStore` (#64): the Files-visible folder is
  /// user-writable, so a foreign file must not be buffered whole. Enforced on
  /// the native side before the bytes cross the channel, and re-checked here.
  final int maxResponseBytes;

  /// Bound on one [read], download included (#58's rule: a stalled transfer
  /// must surface as offline, not pin the engine's single-flight slot).
  final Duration readTimeout;

  @override
  Future<String> ensureFolder() async {
    final path = await _invoke<String>('ensureFolder');
    if (path == null) {
      throw const CloudApiException(500, 'ensureFolder returned no path');
    }
    return path;
  }

  @override
  Future<List<CloudBackupFile>> list(String folderId) async {
    final entries = await _invoke<List<dynamic>>('list', {'folder': folderId});
    return [
      for (final e in (entries ?? const []).cast<Map<dynamic, dynamic>>())
        if (e['path'] is String && e['name'] is String)
          CloudBackupFile(
            id: e['path'] as String,
            name: e['name'] as String,
            modifiedAt: switch (e['modifiedMs']) {
              final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
              _ => null,
            },
            // Null for a not-yet-downloaded placeholder whose real size the
            // metadata query couldn't report; `read` still enforces the cap.
            sizeBytes: e['sizeBytes'] as int?,
          ),
    ];
  }

  @override
  Future<List<int>> read(String fileId) async {
    final bytes = await _invoke<Uint8List>('read', {
      'path': fileId,
      'maxBytes': maxResponseBytes,
      'timeoutMs': readTimeout.inMilliseconds,
    });
    if (bytes == null) {
      throw CloudApiException(500, 'read $fileId returned no data');
    }
    // Defense in depth: the native side already refuses over-size files.
    if (bytes.length > maxResponseBytes) {
      throw CloudApiException(
        413,
        'read $fileId: ${bytes.length} bytes exceeds the '
        '$maxResponseBytes-byte cap',
      );
    }
    return bytes;
  }

  @override
  Future<void> write(
    String folderId,
    String name,
    List<int> bytes, {
    Map<String, String> metadata = const {},
  }) async {
    // `metadata` is advisory by contract and iCloud has nowhere to put it —
    // dropped, see the class doc.
    await _invoke<void>('write', {
      'folder': folderId,
      'name': name,
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<void> delete(String fileId) =>
      _invoke<void>('delete', {'path': fileId});

  /// One choke point mapping [PlatformException] codes (set by the Swift
  /// side) onto the store's typed errors.
  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'unavailable' => const CloudAuthRequiredException(),
        'timeout' => SocketException('$method: ${e.message ?? 'timed out'}'),
        'too_large' => CloudApiException(413, '$method: ${e.message}'),
        'not_found' => CloudApiException(404, '$method: ${e.message}'),
        _ => CloudApiException(500, '$method [${e.code}]: ${e.message}'),
      };
    } on MissingPluginException {
      // Android or `flutter test` reaching an iOS-only store: a wiring bug,
      // but surface it typed so the engine stamps a failure instead of
      // swallowing an untyped escape.
      throw const CloudApiException(500, 'iCloud channel not available');
    }
  }
}
