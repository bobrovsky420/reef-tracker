import 'dart:async';
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
/// the `HttpClient` surface for [DriveBackupStore._request]'s GET path.
class _CannedHttpClient implements HttpClient {
  _CannedHttpClient(this._response);

  final HttpClientResponse _response;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _CannedRequest(_response);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CannedRequest implements HttpClientRequest {
  _CannedRequest(this._response);

  final HttpClientResponse _response;

  @override
  final HttpHeaders headers = _NullHeaders();

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NullHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CannedResponse extends Stream<List<int>> implements HttpClientResponse {
  _CannedResponse(this._body, {this.contentLength = -1});

  final Stream<List<int>> _body;

  @override
  int get statusCode => 200;

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
      await expectLater(
        store.read('file-id'),
        throwsA(isA<SocketException>()),
      );
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
}
