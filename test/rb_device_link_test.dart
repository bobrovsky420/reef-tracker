// Coverage of the ReefBeat transport (U38) — the first test of its own for
// `RbHttpLink`; `rb_protocol_test.dart` covers only the parsers, against
// hand-written JSON.
//
// The server here is deliberately not a ReefBeat emulator. It serves the golden
// `/device-info` and `/dashboard` payloads well enough to prove the happy path
// still works, and is otherwise built to behave like the things LAN discovery
// actually points this link at: a host that answers with megabytes, one that
// lies about its Content-Length, one that gzips a bomb, one that serves HTML.
// That is what the #72 cap exists for.
//
// Every server binds port 0, so the suite never collides with anything running.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/device_http.dart';
import 'package:reeftracker/data/rb_device_link.dart';

/// A live RSATO+'s identity, as `rb_protocol_test.dart` captured it.
const _deviceInfo = {
  'name': 'RSATO+3625739455',
  'hw_type': 'reef-ato',
  'hw_model': 'RSATO+',
  'hwid': '8813bf641cd8',
};

/// The same unit's `/dashboard`, abridged to the fields the card reads.
const _dashboard = {
  'mode': 'auto',
  'water_level': 'desired_level_2',
  'is_pump_on': false,
  'today_fills': 4,
  'today_volume_usage': 1630,
  'daily_volume_average': 2969,
  'volume_left': 3467,
  'days_till_empty': 1,
  'leak_sensor': {'connected': true, 'enabled': true, 'status': 'dry'},
  'ato_sensor': {
    'is_sensor_error': false,
    'is_temp_enabled': true,
    'connected': true,
    'current_read': 24.96,
  },
};

void main() {
  late HttpServer server;
  late String host;

  /// Serves the two real endpoints; `/flood` and friends stand in for whatever
  /// else answers on port 80 across a household LAN.
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    host = '127.0.0.1:${server.port}';
    server.listen((request) async {
      final response = request.response;
      // Match the *first* segment: the link builds its own paths, so a hostile
      // route is reached by passing `127.0.0.1:port/flood` as the host and
      // letting it append `/dosing-queue`.
      final route = request.uri.pathSegments.isEmpty
          ? ''
          : '/${request.uri.pathSegments.first}';
      switch (route) {
        case '/device-info':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(_deviceInfo));
        case '/dashboard':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(_dashboard));
        case '/flood':
          // Chunked (no Content-Length, so the up-front check can't fire):
          // 4 MB in 64 KB pieces, the shape of a media server streaming a file.
          final chunk = List.filled(64 * 1024, 0x41);
          for (var i = 0; i < 64; i++) {
            response.add(chunk);
          }
        case '/declared':
          // Honest about a size that is over the ceiling — the fast path.
          final body = utf8.encode('x' * (300 * 1024));
          response.headers.contentLength = body.length;
          response.add(body);
        case '/gzipbomb':
          // 8 MB of zeros, gzipped to a few KB. `Content-Length` therefore
          // *declares* a small body, and `autoUncompress` expands it on the
          // way in: only a counter on the drain catches this.
          final bomb = gzip.encode(List.filled(8 * 1024 * 1024, 0));
          response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          response.headers.contentLength = bomb.length;
          response.add(bomb);
        case '/router':
          response.headers.contentType = ContentType.html;
          response.write('<html><body>Login</body></html>');
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
  }

  setUp(start);
  tearDown(() => server.close(force: true));

  test('reads a real device with the production ceiling in place', () async {
    final link = RbHttpLink(timeout: const Duration(seconds: 5));
    final snapshot = await link.readOnce(host);
    expect(snapshot.info.hwid, '8813bf641cd8');
    expect(snapshot.info.hwModel, 'RSATO+');
    expect(snapshot.ato, isNotNull);
  });

  test('the probe ceiling is far above a real identity payload', () async {
    // The point of the number: /device-info is a few hundred bytes, so the
    // discovery instance's 64 KB is headroom, not a limit anyone can hit.
    expect(jsonEncode(_deviceInfo).length, lessThan(kDeviceProbeMaxBytes ~/ 50));
    final link = RbHttpLink(
      timeout: const Duration(seconds: 5),
      maxResponseBytes: kDeviceProbeMaxBytes,
    );
    expect((await link.identify(host)).hwid, '8813bf641cd8');
  });

  group('the #72 cap', () {
    Future<void> expectRefused(String path, {int max = 128 * 1024}) async {
      final link = RbHttpLink(
        timeout: const Duration(seconds: 10),
        maxResponseBytes: max,
      );
      await expectLater(
        link.readDosingQueue('$host$path'),
        throwsA(
          isA<RbLinkException>()
              .having((e) => e.error, 'error', RbLinkError.protocol)
              .having((e) => e.detail, 'detail', contains('cap')),
        ),
      );
    }

    test('a chunked flood is refused instead of buffered', () async {
      // 4 MB served, 128 KB allowed. Without the cap this is a String the size
      // of whatever the host feels like sending.
      await expectRefused('/flood');
    });

    test('a declared over-size length is refused up front', () async {
      await expectRefused('/declared');
    });

    test('a gzip bomb is caught on the drain, not by Content-Length', () async {
      // The declared length is a few KB — under the ceiling — so this can only
      // be caught by counting decompressed bytes.
      await expectRefused('/gzipbomb');
    });

    test('the cap does not change what a non-device host reports', () async {
      // A router admin page was a protocol error before the cap and still is:
      // the ceiling must not turn "not a reef device" into something else.
      final link = RbHttpLink(
        timeout: const Duration(seconds: 5),
        maxResponseBytes: kDeviceProbeMaxBytes,
      );
      await expectLater(
        link.identify('$host/router'),
        throwsA(
          isA<RbLinkException>().having(
            (e) => e.error,
            'error',
            RbLinkError.protocol,
          ),
        ),
      );
    });
  });
}
