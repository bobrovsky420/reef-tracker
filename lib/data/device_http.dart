// Response-size hygiene shared by the LAN device transports (#72).
//
// The links buffer a whole HTTP response before decoding it, which is fine for
// the few kilobytes a reef device serves and catastrophic for anything else —
// and "anything else" is reachable, because LAN discovery points the identity
// probes at *every* host answering on port 80: the router admin page, the NAS,
// a media server. #64 established the rule for the cloud store
// (`kCloudBackupMaxBytes`); this is the same treatment for the device side,
// with the ceiling tiered by who chose the address.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

/// Ceiling for an identity probe — the reads LAN discovery aims at arbitrary
/// hosts. A ReefBeat `/device-info` is a few hundred bytes, so this is already
/// two orders of magnitude of headroom.
const kDeviceProbeMaxBytes = 64 * 1024;

/// Ceiling for every other device read — the ones aimed at an address the
/// keeper typed or confirmed. The largest legitimate document any supported
/// device serves is an Apex `/rest/config`, which carries each output's program
/// text: single-digit KB on a modest controller, plausibly low hundreds of KB
/// on a heavily programmed one. 1 MB leaves room for a controller bigger than
/// any seen, which is the right way to be wrong — a cap set too low would
/// silently break a keeper's device with no user-facing knob to raise it.
const kDeviceResponseMaxBytes = 1024 * 1024;

/// A response that ran past its ceiling. Each link catches this and maps it to
/// its own `protocol` error, so it flows into the existing error handling
/// rather than surfacing as an OOM.
class DeviceResponseTooLarge implements Exception {
  const DeviceResponseTooLarge(this.limit, [this.declared]);

  /// The ceiling that was exceeded, in bytes.
  final int limit;

  /// The `Content-Length` the host declared, when it declared one over the
  /// ceiling up front. Null when the overrun was found while draining.
  final int? declared;

  String get detail => declared == null
      ? 'response exceeds the $limit-byte cap'
      : 'response declares $declared bytes, over the $limit-byte cap';

  @override
  String toString() => 'DeviceResponseTooLarge($detail)';
}

/// Drains [response] as text, refusing anything past [maxBytes].
///
/// The counter on the drain is the actual defence; the `contentLength` check is
/// only a fast path that saves reading a body already declared too big. It
/// cannot be relied on: `HttpClient.autoUncompress` is true by default, so
/// `contentLength` is the *compressed* header value and a gzipped body
/// declaring 100 KB can expand to gigabytes on the stream. Chunked responses
/// declare -1 and skip the fast path entirely.
///
/// Malformed UTF-8 decodes to replacement characters rather than throwing: the
/// body of a host that is not a reef device is not text at all half the time,
/// and every caller feeds this to `jsonDecode`, whose `FormatException` is
/// already mapped to a protocol error.
Future<String> readBoundedText(
  HttpClientResponse response,
  int maxBytes,
) async {
  if (response.contentLength > maxBytes) {
    throw DeviceResponseTooLarge(maxBytes, response.contentLength);
  }
  final buffer = BytesBuilder(copy: false);
  await for (final List<int> chunk in response) {
    buffer.add(chunk);
    // Throwing out of the `await for` cancels the subscription; the caller's
    // `finally` force-closes the client, so the socket goes with it.
    if (buffer.length > maxBytes) throw DeviceResponseTooLarge(maxBytes);
  }
  return utf8.decode(buffer.takeBytes(), allowMalformed: true);
}
