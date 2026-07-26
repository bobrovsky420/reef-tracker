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

import 'rb_protocol.dart';

/// Why a refresh failed — surfaced to the UI for a specific message rather
/// than a raw exception string.
enum RbLinkError {
  /// Couldn't reach the device (offline, wrong IP, different network).
  unreachable,

  /// Reached it, but a response didn't arrive in time.
  timeout,

  /// It answered, but it isn't a ReefBeat device type we support (only
  /// ReefDose pumps, ReefATO units and ReefMat filters so far).
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

/// The decoded result of one manual refresh: identity + the live status
/// matching the device family — exactly one of [dose]/[ato]/[mat]/[run]/
/// [light]/[wave] is set.
class RbSnapshot {
  const RbSnapshot({
    required this.info,
    this.dose,
    this.ato,
    this.mat,
    this.run,
    this.light,
    this.wave,
  });

  final RbDeviceInfo info;
  final RbDoseStatus? dose;
  final RbAtoStatus? ato;
  final RbMatStatus? mat;
  final RbRunStatus? run;
  final RbLightStatus? light;
  final RbWaveStatus? wave;

  /// The most precise model code known — a mat's `/configuration` reports the
  /// width ("RSMAT250") that `/device-info` omits; everything else uses its
  /// `hw_model` as-is.
  String get modelCode => mat?.modelCode ?? info.hwModel;

  /// The friendly product name for [modelCode] ("ReefMat 250").
  String get modelDisplayName => rbModelDisplayName(modelCode);
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
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Duration timeout;
  final HttpClient Function() _clientFactory;

  /// Be forgiving about pasted addresses: strip a scheme and trailing slashes.
  static String _normalizeHost(String host) {
    var h = host.trim().replaceFirst(RegExp(r'^https?://'), '');
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  @override
  Future<RbDeviceInfo> identify(String host) async {
    final info = RbDeviceInfo.fromJson(
      await _getJson(_normalizeHost(host), '/device-info'),
    );
    if (info == null) {
      throw const RbLinkException(RbLinkError.protocol, 'no device identity');
    }
    return info;
  }

  @override
  Future<RbSnapshot> readOnce(String host) async {
    final h = _normalizeHost(host);
    final info = await identify(h);

    switch (info.hwType) {
      case kRbDosingHwType:
        final dashboard = await _getJson(h, '/dashboard');
        // The dosing queue labels each dose with the head's *short* supplement
        // name ("Zin"), and only `/head/<n>/settings` carries it — so every
        // head the dashboard reported is read too. Doing it on every refresh
        // (rather than once at add time) is what keeps the mapping right after
        // the keeper reassigns a supplement in the ReefBeat app. Tolerant: a
        // head whose settings don't answer just keeps no abbreviation.
        final headSettings = <int, Map<String, Object?>>{};
        for (final head in RbDoseStatus.fromJson(dashboard).heads) {
          final settings = await _tryGetJson(
            h,
            '/head/${head.number}/settings',
          );
          if (settings != null) headSettings[head.number] = settings;
        }
        return RbSnapshot(
          info: info,
          dose: RbDoseStatus.fromJson(dashboard, headSettings: headSettings),
        );
      case kRbAtoHwType:
        return RbSnapshot(
          info: info,
          ato: RbAtoStatus.fromJson(await _getJson(h, '/dashboard')),
        );
      case kRbMatHwType:
        final dashboard = await _getJson(h, '/dashboard');
        // Only to recover the sized model code — a mat whose configuration is
        // unreadable still gets a complete card, just a generic name.
        final configuration = await _tryGetJson(h, '/configuration');
        return RbSnapshot(
          info: info,
          mat: RbMatStatus.fromJson(dashboard, configuration: configuration),
        );
      case kRbRunHwType:
        return RbSnapshot(
          info: info,
          run: RbRunStatus.fromJson(await _getJson(h, '/dashboard')),
        );
      case kRbLightsHwType:
        return RbSnapshot(
          info: info,
          light: RbLightStatus.fromJson(await _getJson(h, '/dashboard')),
        );
      case kRbWaveHwType:
        // The wave serves no /dashboard — see rb_protocol.dart. `/mode` is
        // required; `/auto` (the day's wave schedule, the only way to know what
        // output the pump is running) enriches it.
        final mode = await _getJson(h, '/mode');
        final auto = await _tryGetJson(h, '/auto');
        return RbSnapshot(
          info: info,
          wave: RbWaveStatus.fromJson(mode, auto: auto),
        );
      default:
        throw RbLinkException(RbLinkError.unsupportedModel, info.hwType);
    }
  }

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async {
    final decoded = await _get(_normalizeHost(host), '/dosing-queue');
    if (decoded is! List) {
      throw const RbLinkException(RbLinkError.protocol, 'not a JSON array');
    }
    return RbDoseQueueEntry.listFromJson(decoded);
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
        throw RbLinkException(RbLinkError.protocol, 'HTTP ${response.statusCode}');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return jsonDecode(body);
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
