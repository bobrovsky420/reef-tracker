// Transport for Neptune Systems Apex controllers on the LAN, decoded by
// ap_protocol.dart.
//
// Unlike the ReefFactory and ReefBeat devices, an Apex is **authenticated**:
// every status read needs the controller's own login (the credentials the
// keeper uses on its web UI — factory default `admin` / `1234`). Which
// authentication applies is discovered per read rather than configured,
// because the two firmware families answer differently and a controller can be
// updated under the app's feet:
//
//   1. `POST /rest/login` — 200 with a `connect.sid` means AOS 5.x, and that
//      cookie carries the subsequent `GET /rest/status`.
//   2. A **404** on that POST means the controller has no `/rest` API at all
//      (Classic / Jr / older AOS): fall back to `GET /cgi-bin/status.json`
//      with HTTP Basic auth.
//   3. A **401** means it answered the route but rejected the credentials as a
//      session login; older builds want Basic auth on the same paths, so that
//      is tried before giving up. Only if Basic fails too is it [
//      ApLinkError.auth].
//
// A refresh logs in afresh rather than holding a session. It costs one extra
// request, and it is what makes a read stateless: no cookie to expire between
// two manual refreshes hours apart, and no reconnect logic when the controller
// reboots. The same rationale as the transient reads on the other two
// integrations.
//
// The link is abstracted so a fake can be injected in widget tests (mirrors
// `RbDeviceLink` / `RfDeviceLink`); [ApHttpLink] is the real implementation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ap_protocol.dart';
import 'device_http.dart';

/// Why a read failed — surfaced to the UI for a specific message rather than a
/// raw exception string.
enum ApLinkError {
  /// Couldn't reach the controller (offline, wrong IP, different network).
  unreachable,

  /// Reached it, but a response didn't arrive in time.
  timeout,

  /// It answered and rejected the username/password.
  auth,

  /// It answered, but not with anything an Apex serves — or the body didn't
  /// decode to the expected shape.
  protocol,
}

class ApLinkException implements Exception {
  const ApLinkException(this.error, [this.detail]);
  final ApLinkError error;
  final String? detail;
  @override
  String toString() =>
      'ApLinkException($error${detail == null ? '' : ': $detail'})';
}

/// The credentials one controller was added with.
class ApCredentials {
  const ApCredentials({required this.username, required this.password});

  /// The Apex web-UI login. `admin` from the factory.
  final String username;

  /// The Apex web-UI password. `1234` from the factory — which is exactly why
  /// this integration is LAN-only and never relays anything off the network.
  final String password;
}

abstract class ApDeviceLink {
  /// Reads one status from the controller at [host] (IP or hostname,
  /// optionally with a `:port`). Throws [ApLinkException] on any failure.
  Future<ApStatus> readOnce(String host, ApCredentials credentials);
}

/// Real transport over `http://<host>/…`.
class ApHttpLink implements ApDeviceLink {
  ApHttpLink({
    this.timeout = const Duration(seconds: 8),
    this.maxResponseBytes = kDeviceResponseMaxBytes,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  /// Longer than the ReefBeat link's 6 s: an Apex serving `/rest/status` on a
  /// fully populated controller is measurably slower than a single-purpose
  /// device serving one small JSON object, and a read here is at most two
  /// requests behind an explicit user action.
  final Duration timeout;

  /// Response-size ceiling (#72), [kDeviceResponseMaxBytes] in production. An
  /// Apex is the roomiest case the constant was picked for: `/rest/config`
  /// carries every output's program text, so it is the largest document any
  /// supported device serves. Injectable so a test can shrink it.
  final int maxResponseBytes;

  final HttpClient Function() _clientFactory;

  /// Be forgiving about pasted addresses: strip a scheme and trailing slashes.
  static String _normalizeHost(String host) {
    var h = host.trim().replaceFirst(RegExp(r'^https?://'), '');
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  static String _basic(ApCredentials c) =>
      'Basic ${base64.encode(utf8.encode('${c.username}:${c.password}'))}';

  @override
  Future<ApStatus> readOnce(String host, ApCredentials credentials) async {
    final h = _normalizeHost(host);
    final session = await _login(h, credentials);
    if (session == null) return _readLegacy(h, credentials);

    final status = await _getJson(
      h,
      '/rest/status',
      headers: {'Cookie': 'connect.sid=$session'},
    );
    // Only AOS 5.x has a config document, and it is the sole authoritative
    // statement of the controller's temperature unit. Tolerant: a controller
    // that won't serve it still gets a complete card, with the unit inferred
    // from the reading's own magnitude (see `apInferTempUnit`).
    final config = await _tryGetJson(
      h,
      '/rest/config',
      headers: {'Cookie': 'connect.sid=$session'},
    );
    return ApStatus.fromRestJson(
      status,
      tempUnit: apTempUnitFromConfig(config),
    );
  }

  /// Opens an AOS 5.x session, or returns null when this controller has no
  /// `/rest` API (a 404, or a 401 that Basic auth can still satisfy — both
  /// mean "try the legacy path").
  Future<String?> _login(String host, ApCredentials credentials) async {
    final body = jsonEncode({
      'login': credentials.username,
      'password': credentials.password,
      'remember_me': false,
    });
    final (:statusCode, :text) = await _send(
      host,
      '/rest/login',
      method: 'POST',
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (statusCode == HttpStatus.notFound) return null;
    if (statusCode == HttpStatus.unauthorized) return null;
    if (statusCode != HttpStatus.ok) {
      throw ApLinkException(ApLinkError.protocol, 'login HTTP $statusCode');
    }
    final decoded = _decodeObject(text);
    final sid = decoded['connect.sid'];
    if (sid is! String || sid.isEmpty) {
      // A 200 with no session is how some builds report bad credentials.
      throw const ApLinkException(
        ApLinkError.auth,
        'no session in login reply',
      );
    }
    // #83: the session id is LAN-attacker-controlled data headed for a Cookie
    // header. A real Apex mints a printable token; anything with whitespace or
    // control characters is refused here rather than letting HttpHeaders throw
    // on it (the catch in [_send] is the backstop, this is the clean error).
    if (!_cookieToken.hasMatch(sid)) {
      throw const ApLinkException(ApLinkError.protocol, 'malformed session id');
    }
    return sid;
  }

  /// Printable ASCII with no whitespace — the shape of every cookie value an
  /// Apex actually mints.
  static final RegExp _cookieToken = RegExp(r'^[\x21-\x7e]+$');

  /// The Classic path: Basic auth against `/cgi-bin/status.json`. The
  /// cache-busting query parameter is what the Apex's own web UI sends; older
  /// builds serve a stale document without it.
  Future<ApStatus> _readLegacy(String host, ApCredentials credentials) async {
    final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final json = await _getJson(
      host,
      '/cgi-bin/status.json?$stamp',
      headers: {'Authorization': _basic(credentials)},
    );
    return ApStatus.fromLegacyJson(json);
  }

  Future<Map<String, Object?>?> _tryGetJson(
    String host,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _getJson(host, path, headers: headers);
    } on ApLinkException {
      return null;
    }
  }

  Future<Map<String, Object?>> _getJson(
    String host,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final (:statusCode, :text) = await _send(host, path, headers: headers);
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      throw ApLinkException(ApLinkError.auth, 'HTTP $statusCode');
    }
    if (statusCode != HttpStatus.ok) {
      throw ApLinkException(ApLinkError.protocol, 'HTTP $statusCode');
    }
    return _decodeObject(text);
  }

  Map<String, Object?> _decodeObject(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      // The overwhelmingly common cause is an address that hosts *something*
      // but not an Apex — a router admin page answering with HTML.
      throw ApLinkException(ApLinkError.protocol, e.message);
    }
    if (decoded is! Map<String, Object?>) {
      throw const ApLinkException(ApLinkError.protocol, 'not a JSON object');
    }
    return decoded;
  }

  /// One request. Non-2xx is returned rather than thrown so each caller can
  /// decide what a 401 or 404 means — the login handshake reads them as
  /// firmware detection, everything else as failure.
  Future<({int statusCode, String text})> _send(
    String host,
    String path, {
    String method = 'GET',
    String? body,
    Map<String, String> headers = const {},
  }) async {
    final client = _clientFactory()..connectionTimeout = timeout;
    try {
      final url = Uri.parse('http://$host$path');
      final request =
          await (method == 'POST' ? client.postUrl(url) : client.getUrl(url))
              .timeout(timeout);
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close().timeout(timeout);
      final text = await readBoundedText(
        response,
        maxResponseBytes,
      ).timeout(timeout);
      return (statusCode: response.statusCode, text: text);
    } on DeviceResponseTooLarge catch (e) {
      throw ApLinkException(ApLinkError.protocol, e.detail);
    } on TimeoutException {
      throw const ApLinkException(ApLinkError.timeout);
    } on SocketException catch (e) {
      throw ApLinkException(ApLinkError.unreachable, e.message);
    } on HttpException catch (e) {
      throw ApLinkException(ApLinkError.unreachable, e.message);
    } on FormatException catch (e) {
      // #83: `Uri.parse` on a typed address with a bad `:port`, or a header
      // value the device controls (the login session id) containing a
      // character HttpHeaders rejects. Both are "not an Apex conversation",
      // and must not escape the ApLinkException contract every caller relies
      // on.
      throw ApLinkException(ApLinkError.protocol, e.message);
    } finally {
      client.close(force: true);
    }
  }
}
