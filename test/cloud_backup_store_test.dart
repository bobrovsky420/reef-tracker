import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';

/// An [HttpClient] whose requests never complete — the half-open-socket /
/// captive-portal case of #58. Only the members [DriveBackupStore._request]
/// touches are implemented; anything else failing loudly is a test bug.
class _HangingHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;

  bool? closeForce;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  void close({bool force = false}) {
    closeForce = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves one canned [HttpClientResponse] for any request — just enough of
/// the `HttpClient` surface for [DriveBackupStore._request]'s GET path, and
/// recording enough of what went out ([requests]) to assert the wire format
/// the live Drive store speaks.
class _CannedHttpClient implements HttpClient {
  _CannedHttpClient(this._response);

  final HttpClientResponse _response;

  /// Everything [DriveBackupStore] put on the wire through this client.
  final List<_CannedRequest> requests = [];

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = _CannedRequest(_response, method, url);
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CannedRequest implements HttpClientRequest {
  _CannedRequest(this._response, this.method, this.uri);

  final HttpClientResponse _response;

  @override
  final String method;

  @override
  final Uri uri;

  /// Whatever was handed to [add] — the request body, byte for byte.
  final List<int> body = [];

  /// Left at the `dart:io` default so a body-less request is distinguishable
  /// from one the store forgot to declare a length for.
  @override
  int contentLength = -1;

  @override
  final _NullHeaders headers = _NullHeaders();

  @override
  void add(List<int> data) => body.addAll(data);

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NullHeaders implements HttpHeaders {
  /// Header name → value as set by [DriveBackupStore._request].
  final Map<String, Object> values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CannedResponse extends Stream<List<int>> implements HttpClientResponse {
  _CannedResponse(this._body, {this.contentLength = -1, this.statusCode = 200});

  final Stream<List<int>> _body;

  @override
  final int statusCode;

  @override
  final int contentLength;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('DriveBackupStore size cap (#64)', () {
    DriveBackupStore storeFor(HttpClientResponse response) => DriveBackupStore(
      () async => 'token',
      clientFactory: () => _CannedHttpClient(response),
      maxResponseBytes: 1024,
    );

    final throws413 = throwsA(
      isA<CloudApiException>().having((e) => e.statusCode, 'statusCode', 413),
    );

    test('a response under the cap is returned whole', () async {
      final store = storeFor(
        _CannedResponse(
          Stream.fromIterable([List.filled(512, 7), List.filled(256, 7)]),
        ),
      );
      expect(await store.read('file-id'), hasLength(768));
    });

    test('a declared over-size contentLength is refused up front', () async {
      final store = storeFor(
        _CannedResponse(const Stream.empty(), contentLength: 2048),
      );
      await expectLater(store.read('file-id'), throws413);
    });

    test('an over-size chunked response aborts mid-drain', () async {
      var chunksServed = 0;
      Stream<List<int>> body() async* {
        // 32 × 256 B = 8 KB, well past the 1 KB test cap; the drain must
        // bail out long before the stream runs dry.
        for (; chunksServed < 32; chunksServed++) {
          yield List.filled(256, 7);
        }
      }

      final store = storeFor(_CannedResponse(body()));
      await expectLater(store.read('file-id'), throws413);
      expect(
        chunksServed,
        lessThan(32),
        reason: 'the cap must stop the drain, not buffer the whole stream',
      );
    });
  });

  group('DriveBackupStore timeouts (#58)', () {
    test('a hung request times out as SocketException and force-closes '
        'the client', () async {
      final client = _HangingHttpClient();
      final store = DriveBackupStore(
        () async => 'token',
        clientFactory: () => client,
        requestTimeout: const Duration(milliseconds: 50),
      );

      // SocketException specifically: it implements IOException, so the sync
      // engine's existing offline branch (silent retry next launch) handles
      // the stall, and the single-flight slot self-clears instead of pinning
      // a dead future for the rest of the session.
      await expectLater(store.read('file-id'), throwsA(isA<SocketException>()));
      expect(
        client.connectionTimeout,
        isNotNull,
        reason: 'connect phase must be bounded too',
      );
      expect(
        client.closeForce,
        isTrue,
        reason: 'a stalled socket is only released by close(force: true)',
      );
    });
  });

  group('DriveBackupStore.write multipart body', () {
    /// One `--boundary`-delimited part, split into its header block and its
    /// payload (both stripped of the CRLFs the delimiters own).
    ({String header, String payload}) part(String raw) {
      final split = raw.indexOf('\r\n\r\n');
      return (
        header: raw.substring('\r\n'.length, split),
        payload: raw.substring(split + '\r\n\r\n'.length, raw.length - 2),
      );
    }

    test('two parts: file metadata (name, parent, appProperties) then the '
        'document bytes verbatim', () async {
      final client = _CannedHttpClient(
        _CannedResponse(Stream.value(utf8.encode('{"id":"new-file"}'))),
      );
      final store = DriveBackupStore(
        () async => 'token',
        clientFactory: () => client,
      );
      // Non-ASCII in the document: the content part is raw bytes, so a stray
      // re-encode of the assembled body would show up here.
      final document = utf8.encode('{"tanks":[{"name":"Nanoriff — Küvette"}]}');

      await store.write(
        'folder-9',
        'reeftracker-auto-20260809-101112-345.json',
        document,
        metadata: const {
          kCloudMetaDevice: 'Phone A',
          kCloudMetaContentHash: 'abc123',
        },
      );

      final request = client.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.queryParameters['uploadType'], 'multipart');
      expect(request.uri.host, 'www.googleapis.com');
      expect(request.uri.path, '/upload/drive/v3/files');

      final contentType =
          request.headers.values[HttpHeaders.contentTypeHeader] as String;
      expect(contentType, startsWith('multipart/related; boundary='));
      final boundary = contentType.split('boundary=').last;
      expect(boundary, isNotEmpty);

      final raw = utf8.decode(request.body);
      expect(
        request.contentLength,
        request.body.length,
        reason: 'Drive rejects a multipart upload without a declared length',
      );

      final parts = raw.split('--$boundary');
      expect(
        parts,
        hasLength(4),
        reason: 'preamble, metadata part, content part, closing delimiter',
      );
      expect(parts.first, isEmpty);
      expect(parts.last, '--', reason: 'the closing delimiter is "--B--"');

      final meta = part(parts[1]);
      expect(meta.header, 'Content-Type: application/json; charset=utf-8');
      expect(jsonDecode(meta.payload), {
        'name': 'reeftracker-auto-20260809-101112-345.json',
        'parents': ['folder-9'],
        'appProperties': {'device': 'Phone A', 'contentHash': 'abc123'},
      });

      final content = part(parts[2]);
      expect(content.header, 'Content-Type: application/json; charset=utf-8');
      expect(
        utf8.encode(content.payload),
        document,
        reason: 'the document must ride the wire byte for byte',
      );
    });

    test(
      'no metadata: the appProperties key is omitted, not sent empty',
      () async {
        final client = _CannedHttpClient(
          _CannedResponse(Stream.value(utf8.encode('{"id":"new-file"}'))),
        );
        final store = DriveBackupStore(
          () async => 'token',
          clientFactory: () => client,
        );

        await store.write('folder-9', 'backup.json', utf8.encode('{}'));

        final request = client.requests.single;
        final boundary =
            (request.headers.values[HttpHeaders.contentTypeHeader]! as String)
                .split('boundary=')
                .last;
        final metaPart = part(
          utf8.decode(request.body).split('--$boundary')[1],
        );
        expect(jsonDecode(metaPart.payload), {
          'name': 'backup.json',
          'parents': ['folder-9'],
        });
      },
    );
  });

  group('DriveBackupStore._request auth and status', () {
    test('a null token throws CloudAuthRequiredException and opens no '
        'socket at all', () async {
      var clientsCreated = 0;
      final store = DriveBackupStore(
        () async => null,
        clientFactory: () {
          clientsCreated++;
          return _CannedHttpClient(_CannedResponse(const Stream.empty()));
        },
      );

      // The Settings row's "reconnect" state hangs off this exact type: a
      // generic failure would read as a transient provider error instead.
      await expectLater(
        store.read('file-id'),
        throwsA(isA<CloudAuthRequiredException>()),
      );
      expect(
        clientsCreated,
        0,
        reason: 'no token means no request is worth attempting',
      );
    });

    test('every request carries the bearer token, and a body-less one '
        'declares no length and no content type', () async {
      final client = _CannedHttpClient(
        _CannedResponse(Stream.value(utf8.encode('backup bytes'))),
      );
      final store = DriveBackupStore(
        () async => 'ya29.token-value',
        clientFactory: () => client,
      );

      expect(await store.read('file-id'), utf8.encode('backup bytes'));

      final request = client.requests.single;
      expect(request.method, 'GET');
      expect(
        request.headers.values[HttpHeaders.authorizationHeader],
        'Bearer ya29.token-value',
      );
      expect(request.headers.values, isNot(contains('content-type')));
      expect(request.contentLength, -1);
      expect(request.body, isEmpty);
    });

    test('a non-2xx response surfaces as CloudApiException preserving its '
        'status and carrying the provider body', () async {
      // 404 in particular: both folder-recreate paths (the push in
      // `runCloudSyncIfDirty` and the pull-check in `checkCloudNewerBackup`)
      // branch on exactly this number.
      for (final status in [400, 401, 403, 404, 500]) {
        final client = _CannedHttpClient(
          _CannedResponse(
            Stream.value(utf8.encode('File not found: folder-9')),
            statusCode: status,
          ),
        );
        final store = DriveBackupStore(
          () async => 'token',
          clientFactory: () => client,
        );

        await expectLater(
          store.list('folder-9'),
          throwsA(
            isA<CloudApiException>()
                .having((e) => e.statusCode, 'statusCode', status)
                .having(
                  (e) => e.message,
                  'message',
                  contains('File not found: folder-9'),
                ),
          ),
        );
      }
    });
  });
}
