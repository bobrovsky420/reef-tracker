// Transport for Red Sea ReefBeat local devices: two plain HTTP GETs against
// the device's LAN REST API (`/device-info` for identity, `/dashboard` for
// live status), decoded by rb_protocol.dart.
//
// A refresh is a transient request pair (no persistent connection) — it
// matches the manual-refresh UX of the ReefFactory dashboard and disturbs
// nothing (the device serves its own app the same way). The link is abstracted
// so a fake can be injected in widget tests (mirrors `RfDeviceLink` /
// `HannaMeterLink`); [RbHttpLink] is the real `dart:io` implementation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'rb_protocol.dart';

/// Why a refresh failed — surfaced to the UI for a specific message rather
/// than a raw exception string.
enum RbLinkError {
  /// Couldn't reach the device (offline, wrong IP, different network).
  unreachable,

  /// Reached it, but a response didn't arrive in time.
  timeout,

  /// It answered, but it isn't a ReefBeat device type we support (only
  /// ReefDose pumps so far).
  unsupportedModel,

  /// The responses arrived but didn't decode to the expected shape.
  protocol,
}

class RbLinkException implements Exception {
  const RbLinkException(this.error, [this.detail]);
  final RbLinkError error;
  final String? detail;
  @override
  String toString() =>
      'RbLinkException($error${detail == null ? '' : ': $detail'})';
}

/// The decoded result of one manual refresh: identity + live dosing status.
class RbSnapshot {
  const RbSnapshot({required this.info, required this.status});
  final RbDeviceInfo info;
  final RbDoseStatus status;
}

abstract class RbDeviceLink {
  /// Reads one snapshot from the device at [host] (IP or hostname, optionally
  /// with a port). Throws [RbLinkException] on any failure.
  Future<RbSnapshot> readOnce(String host);
}

/// Real transport over `http://<host>/…`.
class RbHttpLink implements RbDeviceLink {
  RbHttpLink({
    this.timeout = const Duration(seconds: 6),
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Duration timeout;
  final HttpClient Function() _clientFactory;

  @override
  Future<RbSnapshot> readOnce(String host) async {
    // Be forgiving about pasted addresses: strip a scheme and trailing slash.
    var h = host.trim();
    h = h.replaceFirst(RegExp(r'^https?://'), '');
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }

    final infoJson = await _getJson(h, '/device-info');
    final info = RbDeviceInfo.fromJson(infoJson);
    if (info == null) {
      throw const RbLinkException(RbLinkError.protocol, 'no device identity');
    }
    if (info.hwType != kRbDosingHwType) {
      throw RbLinkException(RbLinkError.unsupportedModel, info.hwType);
    }
    final status = RbDoseStatus.fromJson(await _getJson(h, '/dashboard'));
    return RbSnapshot(info: info, status: status);
  }

  Future<Map<String, Object?>> _getJson(String host, String path) async {
    final client = _clientFactory()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse('http://$host$path'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw RbLinkException(RbLinkError.protocol, 'HTTP ${response.statusCode}');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        throw const RbLinkException(RbLinkError.protocol, 'not a JSON object');
      }
      return decoded;
    } on RbLinkException {
      rethrow;
    } on TimeoutException {
      throw const RbLinkException(RbLinkError.timeout);
    } on SocketException catch (e) {
      throw RbLinkException(RbLinkError.unreachable, e.message);
    } on HttpException catch (e) {
      throw RbLinkException(RbLinkError.unreachable, e.message);
    } on FormatException catch (e) {
      throw RbLinkException(RbLinkError.protocol, e.message);
    } finally {
      client.close(force: true);
    }
  }
}
