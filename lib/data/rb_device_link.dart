// Transport for Red Sea ReefBeat local devices: plain HTTP GETs against the
// device's LAN REST API (`/device-info` for identity, `/dashboard` for live
// status, plus a ReefDose's `/dosing-queue` on demand), decoded by
// rb_protocol.dart.
//
// A refresh is a transient request pair (no persistent connection) — it
// matches the manual-refresh UX of the ReefFactory dashboard and disturbs
// nothing (the device serves its own app the same way). The link is abstracted
// so a fake can be injected in widget tests (mirrors `RfDeviceLink` /
// `HannaMeterLink`); [RbHttpLink] is the real `dart:io` implementation.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'device_http.dart';
import 'rb_family_handlers.dart';
import 'rb_protocol.dart';
import 'rb_snapshot.dart';

export 'rb_snapshot.dart';

/// Why a refresh failed — surfaced to the UI for a specific message rather
/// than a raw exception string.
enum RbLinkError {
  /// Couldn't reach the device (offline, wrong IP, different network).
  unreachable,

  /// Reached it, but a response didn't arrive in time.
  timeout,

  /// It answered, but it isn't a ReefBeat device type we support.
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

abstract class RbDeviceLink {
  /// Reads one snapshot from the device at [host] (IP or hostname, optionally
  /// with a port). Throws [RbLinkException] on any failure.
  Future<RbSnapshot> readOnce(String host);

  /// Reads a ReefDose's remaining doses for today (`GET /dosing-queue`). Only
  /// ReefDose pumps serve it, so this is an on-demand read behind the card's
  /// menu rather than part of [readOnce]. Throws [RbLinkException] on any
  /// failure; an empty list means the day's dosing is done.
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host);
}

/// The cheap identity-only probe LAN discovery uses: one `GET /device-info`,
/// no dashboard. Kept separate from [RbDeviceLink] so the dashboard's test
/// fakes — which only ever script whole snapshots — don't have to implement it.
abstract class RbIdentityProbe {
  /// Reads just the identity of the device at [host]. Throws
  /// [RbLinkException] on any failure, including a host that answers HTTP but
  /// isn't a ReefBeat device.
  Future<RbDeviceInfo> identify(String host);
}

/// Real transport over `http://<host>/…`.
class RbHttpLink implements RbDeviceLink, RbIdentityProbe {
  RbHttpLink({
    this.timeout = const Duration(seconds: 6),
    this.maxResponseBytes = kDeviceResponseMaxBytes,
    HttpClient Function()? clientFactory,
    RbFamilyHandlerRegistry? families,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       families = families ?? rbFamilyHandlers;

  final Duration timeout;

  /// Response-size ceiling (#72). The cap belongs to the instance, not the
  /// method: the discovery probe is built with [kDeviceProbeMaxBytes] because
  /// it is aimed at arbitrary hosts, the dashboard's link keeps the roomier
  /// default. [identify] therefore inherits whichever one its instance carries,
  /// which is exactly right and needs no special-casing. Injectable so a test
  /// can shrink it.
  final int maxResponseBytes;

  final RbFamilyHandlerRegistry families;

  final HttpClient Function() _clientFactory;

  /// Be forgiving about pasted addresses: strip a scheme and trailing slashes.
  static String _normalizeHost(String host) {
    var h = host.trim().replaceFirst(RegExp(r'^https?://'), '');
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// #84 backstop: the payload parsers are written to tolerate firmware drift,
  /// but if one still trips over an unforeseen shape, the resulting [Error]
  /// (a TypeError, typically) must degrade to the [RbLinkError.protocol] every
  /// consumer already handles — not crash the refresh, wedge the card's
  /// spinner, or kill the discovery scan stream.
  static T _decode<T>(T Function() parse) {
    try {
      return parse();
    } on Error catch (e) {
      throw RbLinkException(RbLinkError.protocol, e.toString());
    }
  }

  @override
  Future<RbDeviceInfo> identify(String host) async {
    final json = await _getJson(_normalizeHost(host), '/device-info');
    final info = _decode(() => RbDeviceInfo.fromJson(json));
    if (info == null) {
      throw const RbLinkException(RbLinkError.protocol, 'no device identity');
    }
    return info;
  }

  @override
  Future<RbSnapshot> readOnce(String host) async {
    final h = _normalizeHost(host);
    final info = await identify(h);
    final handler = families.forHardwareType(info.hwType);
    if (handler == null) {
      throw RbLinkException(RbLinkError.unsupportedModel, info.hwType);
    }
    try {
      return await handler.read(
        RbFamilyReadContext(
          info: info,
          getJson: (path) => _getJson(h, path),
          tryGetJson: (path) => _tryGetJson(h, path),
        ),
      );
    } on Error catch (error) {
      throw RbLinkException(RbLinkError.protocol, error.toString());
    }
  }

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async {
    final decoded = await _get(_normalizeHost(host), '/dosing-queue');
    if (decoded is! List) {
      throw const RbLinkException(RbLinkError.protocol, 'not a JSON array');
    }
    return _decode(() => RbDoseQueueEntry.listFromJson(decoded));
  }

  /// A [_getJson] whose failure is not fatal — for endpoints that only enrich
  /// a card (the mat's `/configuration`, the wave's `/wifi`).
  Future<Map<String, Object?>?> _tryGetJson(String host, String path) async {
    try {
      return await _getJson(host, path);
    } on RbLinkException {
      return null;
    }
  }

  Future<Map<String, Object?>> _getJson(String host, String path) async {
    final decoded = await _get(host, path);
    if (decoded is! Map<String, Object?>) {
      throw const RbLinkException(RbLinkError.protocol, 'not a JSON object');
    }
    return decoded;
  }

  /// One GET, decoded. The shape is the caller's business — `/dashboard` and
  /// friends answer with an object, `/dosing-queue` with an array.
  Future<Object?> _get(String host, String path) async {
    final client = _clientFactory()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse('http://$host$path'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw RbLinkException(
          RbLinkError.protocol,
          'HTTP ${response.statusCode}',
        );
      }
      final body = await readBoundedText(
        response,
        maxResponseBytes,
      ).timeout(timeout);
      return jsonDecode(body);
    } on RbLinkException {
      rethrow;
    } on DeviceResponseTooLarge catch (e) {
      throw RbLinkException(RbLinkError.protocol, e.detail);
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
