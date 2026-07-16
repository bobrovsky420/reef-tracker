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

void main() {
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
