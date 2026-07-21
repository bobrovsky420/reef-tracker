import 'dart:convert';
import 'dart:io';

/// Cloud storage seam for backup sync (U24).
///
/// Provider-neutral: the sync engine (`cloud_sync.dart`) and the Manage-
/// backups UI talk only to this interface, so OneDrive/Dropbox can slot in
/// later as pure additions, and tests run against an in-memory fake
/// (`test/fakes/fake_cloud_backup_store.dart`) without any plugin or network.
/// Folder and file identifiers are opaque provider strings (Drive file ids
/// here; Graph item ids for a future OneDrive store).
///
/// Every method may throw:
/// - [CloudApiException] — the provider rejected the call (HTTP 4xx/5xx).
///   `isAuthError` marks 401/403, which the UI surfaces as "reconnect".
/// - [SocketException] / other `dart:io` network errors — offline. The engine
///   treats these as "try again next launch", never as a recorded failure.
abstract interface class CloudBackupStore {
  /// Finds or creates the app's backup folder, returning its opaque id.
  Future<String> ensureFolder();

  /// The backup files inside [folderId], newest first (by name — backup
  /// filenames are UTC-timestamped, so lexical order is chronological).
  Future<List<CloudBackupFile>> list(String folderId);

  /// Downloads the raw bytes of [fileId]. Implementations must refuse files
  /// larger than [kCloudBackupMaxBytes] (throwing [CloudApiException]) rather
  /// than buffering them whole in memory.
  Future<List<int>> read(String fileId);

  /// Uploads [bytes] as a new file [name] inside [folderId].
  Future<void> write(String folderId, String name, List<int> bytes);

  /// Permanently deletes [fileId].
  Future<void> delete(String fileId);
}

/// Ceiling on a single downloaded response (#64). Backup documents are small
/// JSON (a decade of readings is single-digit MB), but the app folder is a
/// normal, user-visible My Drive folder anyone with access can drop files
/// into — without a cap, `read` would pull an arbitrarily large file whole
/// into memory on the UI isolate and OOM a low-memory device. The restore
/// list also uses this to show an over-size entry as an error tile instead of
/// attempting the download.
const kCloudBackupMaxBytes = 64 * 1024 * 1024;

/// One remote backup file, as much metadata as the list call returns.
class CloudBackupFile {
  const CloudBackupFile({
    required this.id,
    required this.name,
    this.modifiedAt,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;
}

/// A cloud provider rejected an API call. Distinguished from network-level
/// `dart:io` errors, which mean "offline" rather than "broken".
class CloudApiException implements Exception {
  const CloudApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  /// Expired/revoked grant (401) or insufficient scope (403): the fix is a
  /// reconnect, not a retry.
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'CloudApiException($statusCode): $message';
}

/// Signals that no access token could be obtained silently — the user needs
/// to reconnect the account. Thrown by stores whose token provider returned
/// null; the Settings row shows the reconnect state.
class CloudAuthRequiredException implements Exception {
  const CloudAuthRequiredException();
}

/// Google Drive implementation over plain REST (`dart:io` [HttpClient]) with
/// the `drive.file` scope — deliberately no `googleapis` package; only four
/// endpoints are needed. `drive.file` means the app sees exactly the files it
/// created: [ensureFolder]'s query can only ever find the app's own folder,
/// and [list] only its own uploads, so no user data outside the app's folder
/// is even visible to the queries.
class DriveBackupStore implements CloudBackupStore {
  DriveBackupStore(
    this._accessToken, {
    HttpClient Function()? clientFactory,
    this.connectionTimeout = const Duration(seconds: 15),
    this.requestTimeout = const Duration(seconds: 60),
    this.maxResponseBytes = kCloudBackupMaxBytes,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  /// Returns a currently valid OAuth access token, or null when silent
  /// authorization failed (→ [CloudAuthRequiredException]). Called per
  /// request; token caching is the auth layer's business.
  final Future<String?> Function() _accessToken;
  final HttpClient Function() _clientFactory;

  /// Wall-clock bounds on one REST call (#58). Without them a half-open
  /// socket (captive portal, Wi-Fi dropped mid-request) hangs the send or the
  /// response drain forever: the sync engine's single-flight slot then stays
  /// pinned to the dead future for the rest of the session and the
  /// Manage-backups list spins indefinitely. A timeout surfaces as
  /// [SocketException] so it rides the engine's IOException → offline branch
  /// (silent retry next launch), never a recorded failure.
  final Duration connectionTimeout;
  final Duration requestTimeout;

  /// Response-size ceiling (#64), [kCloudBackupMaxBytes] in production;
  /// injectable so tests exercise the cap without streaming 64 MB.
  final int maxResponseBytes;

  /// Human-visible folder created in the user's My Drive. Deliberately the
  /// plain app name: the user can browse drive.google.com and download a
  /// backup on a new phone before the app is even installed.
  static const kFolderName = 'ReefTracker';

  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  @override
  Future<String> ensureFolder() async {
    const q =
        "name = '$kFolderName' "
        "and mimeType = 'application/vnd.google-apps.folder' "
        "and 'root' in parents and trashed = false";
    final found =
        await _requestJson(
              'GET',
              Uri.parse(
                '$_api/files?q=${Uri.encodeQueryComponent(q)}'
                '&fields=files(id)&pageSize=1',
              ),
            )
            as Map<String, dynamic>;
    final files = found['files'];
    if (files is List && files.isNotEmpty) {
      return (files.first as Map<String, dynamic>)['id'] as String;
    }
    final created =
        await _requestJson(
              'POST',
              Uri.parse('$_api/files?fields=id'),
              body: utf8.encode(
                jsonEncode({
                  'name': kFolderName,
                  'mimeType': 'application/vnd.google-apps.folder',
                }),
              ),
              contentType: 'application/json; charset=utf-8',
            )
            as Map<String, dynamic>;
    return created['id'] as String;
  }

  @override
  Future<List<CloudBackupFile>> list(String folderId) async {
    final q = "'$folderId' in parents and trashed = false";
    final result =
        await _requestJson(
              'GET',
              Uri.parse(
                '$_api/files?q=${Uri.encodeQueryComponent(q)}'
                '&fields=files(id,name,modifiedTime,size)'
                '&orderBy=name desc&pageSize=100',
              ),
            )
            as Map<String, dynamic>;
    final files = result['files'];
    if (files is! List) return const [];
    return [
      for (final f in files.cast<Map<String, dynamic>>())
        CloudBackupFile(
          id: f['id'] as String,
          name: f['name'] as String? ?? '',
          modifiedAt: DateTime.tryParse(f['modifiedTime'] as String? ?? ''),
          sizeBytes: int.tryParse(f['size'] as String? ?? ''),
        ),
    ];
  }

  @override
  Future<List<int>> read(String fileId) =>
      _request('GET', Uri.parse('$_api/files/$fileId?alt=media'));

  @override
  Future<void> write(String folderId, String name, List<int> bytes) async {
    // Multipart upload: part 1 = file metadata (name + parent folder),
    // part 2 = content. Backup JSON is well under the 5 MB multipart limit's
    // practical concerns; no resumable-upload machinery needed.
    const boundary = 'reeftracker_backup_boundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': [folderId],
    });
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; charset=utf-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=utf-8\r\n\r\n',
      ),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];
    await _request(
      'POST',
      Uri.parse('$_upload/files?uploadType=multipart&fields=id'),
      body: body,
      contentType: 'multipart/related; boundary=$boundary',
    );
  }

  @override
  Future<void> delete(String fileId) async {
    await _request('DELETE', Uri.parse('$_api/files/$fileId'));
  }

  Future<dynamic> _requestJson(
    String method,
    Uri uri, {
    List<int>? body,
    String? contentType,
  }) async => jsonDecode(
    utf8.decode(
      await _request(method, uri, body: body, contentType: contentType),
    ),
  );

  Future<List<int>> _request(
    String method,
    Uri uri, {
    List<int>? body,
    String? contentType,
  }) async {
    final token = await _accessToken();
    if (token == null) throw const CloudAuthRequiredException();
    final client = _clientFactory()..connectionTimeout = connectionTimeout;
    try {
      Future<List<int>> send() async {
        final request = await client.openUrl(method, uri);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (body != null) {
          request.headers.set(HttpHeaders.contentTypeHeader, contentType!);
          request.contentLength = body.length;
          request.add(body);
        }
        final response = await request.close();
        // Size cap (#64): refuse over-size responses up front when the server
        // declares a length, and abort the drain past the ceiling either way
        // (chunked responses declare -1). CloudApiException rides the
        // engine's/UI's existing provider-error handling — this is a broken
        // or hostile file, not an offline condition to silently retry.
        if (response.contentLength > maxResponseBytes) {
          throw CloudApiException(
            413,
            '$method ${uri.path}: response of ${response.contentLength} bytes '
            'exceeds the $maxResponseBytes-byte cap',
          );
        }
        final payload = <int>[];
        await for (final chunk in response) {
          payload.addAll(chunk);
          if (payload.length > maxResponseBytes) {
            throw CloudApiException(
              413,
              '$method ${uri.path}: response exceeds the '
              '$maxResponseBytes-byte cap',
            );
          }
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw CloudApiException(
            response.statusCode,
            '$method ${uri.path}: ${utf8.decode(payload, allowMalformed: true)}',
          );
        }
        return payload;
      }

      // One cap over send + drain: a server that accepts the socket but never
      // answers stalls past connectionTimeout's reach.
      return await send().timeout(
        requestTimeout,
        onTimeout: () => throw SocketException(
          '$method ${uri.path}: no response within $requestTimeout',
        ),
      );
    } finally {
      // force: on timeout the stalled socket would otherwise linger; the
      // client is created per request, so nothing else shares it.
      client.close(force: true);
    }
  }
}
