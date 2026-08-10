// Minimal multicast-DNS (Bonjour) codec — pure Dart, no dart:io, so it is
// unit-testable from bytes alone; the socket lives in lan_discovery.dart.
//
// Only what LAN device discovery needs: build a PTR query, decode a response,
// and pull the TXT key/value pairs out of it. This is a deliberately partial
// DNS implementation — no compression on encode, no authority handling, no
// caching or TTL tracking — because one query/response round is all discovery
// does.
//
// Why it exists at all: Red Sea ReefBeat devices advertise `_http._tcp.local`
// with a TXT record carrying their whole identity —
//
//     hwid=cc7b5c267a68 hw_model=RSDOSE4 hw_type=reef-dosing
//                                        firmware_version=3.0.0
//
// — which is exactly what `GET /device-info` returns, so an mDNS sweep
// identifies every Red Sea device on the network in about two seconds without
// a single HTTP call. (ReefFactory devices advertise nothing at all; those are
// found by the port sweep in lan_discovery.dart.)

import 'dart:convert';
import 'dart:typed_data';

/// The IPv4 multicast group and port mDNS runs on.
const String kMdnsGroupAddress = '224.0.0.251';
const int kMdnsPort = 5353;

/// The service-type enumeration meta-query ("what services exist here?").
const String kMdnsServiceEnumeration = '_services._dns-sd._udp.local';

/// The service Red Sea devices publish their identity on.
const String kMdnsHttpService = '_http._tcp.local';

/// DNS record types this codec understands. Anything else decodes to a record
/// with an empty [MdnsRecord.value] and is ignored by callers.
const int kDnsTypeA = 1;
const int kDnsTypePtr = 12;
const int kDnsTypeTxt = 16;
const int kDnsTypeSrv = 33;

/// Encodes an mDNS query for [name] of [type].
///
/// [unicastResponse] sets the QU bit (the top bit of the question's class),
/// asking responders to reply straight to the sender's port instead of the
/// multicast group. Discovery wants that: it lets the client bind an ephemeral
/// port rather than fighting for :5353, which is already held by the system
/// responder on many platforms, and it avoids joining a multicast group at all
/// (no `CHANGE_WIFI_MULTICAST_STATE` on Android).
Uint8List encodeMdnsQuery(
  String name, {
  int type = kDnsTypePtr,
  bool unicastResponse = true,
}) {
  final out = BytesBuilder();
  out.add(const [0, 0]); // id
  out.add(const [0, 0]); // flags: standard query
  out.add(const [0, 1]); // qdcount = 1
  out.add(const [0, 0, 0, 0, 0, 0]); // an/ns/ar counts
  for (final label in name.split('.')) {
    if (label.isEmpty) continue;
    final bytes = utf8.encode(label);
    if (bytes.length > 63) {
      throw ArgumentError.value(name, 'name', 'label longer than 63 bytes');
    }
    out.addByte(bytes.length);
    out.add(bytes);
  }
  out.addByte(0); // root label
  out.add([(type >> 8) & 0xff, type & 0xff]);
  out.add([unicastResponse ? 0x80 : 0x00, 1]); // QU bit | class IN
  return out.toBytes();
}

/// One decoded resource record.
class MdnsRecord {
  const MdnsRecord({
    required this.name,
    required this.type,
    required this.value,
    this.txt = const {},
    this.port,
  });

  /// The owner name ("RSDOSE4-1752835676._http._tcp.local").
  final String name;

  final int type;

  /// The rdata rendered as text: a dotted quad for A, the target name for PTR,
  /// the target host for SRV, the raw joined strings for TXT. Empty for record
  /// types this codec doesn't decode.
  final String value;

  /// Parsed `key=value` pairs, for [kDnsTypeTxt] records only.
  final Map<String, String> txt;

  /// The SRV port, for [kDnsTypeSrv] records only.
  final int? port;
}

/// Reads a (possibly compression-pointer'd) name starting at [offset].
///
/// Returns the name and the offset just past it — for a name that jumped via a
/// pointer, that is past the pointer, not past the target, which is what the
/// record walker needs.
({String name, int next}) _readName(Uint8List data, int offset) {
  final parts = <String>[];
  var pos = offset;
  var next = -1;
  // A malformed message can point in a cycle; the label budget bounds it.
  var budget = 128;
  while (pos >= 0 && pos < data.length && budget-- > 0) {
    final len = data[pos];
    if (len == 0) {
      pos++;
      break;
    }
    if (len & 0xc0 == 0xc0) {
      if (pos + 1 >= data.length) break;
      if (next < 0) next = pos + 2;
      pos = ((len & 0x3f) << 8) | data[pos + 1];
      continue;
    }
    if (pos + 1 + len > data.length) break;
    parts.add(
      utf8.decode(data.sublist(pos + 1, pos + 1 + len), allowMalformed: true),
    );
    pos += 1 + len;
  }
  return (name: parts.join('.'), next: next >= 0 ? next : pos);
}

/// Splits a TXT rdata block (a sequence of length-prefixed strings) into its
/// `key=value` pairs. A string without `=` maps to an empty value.
Map<String, String> _readTxt(Uint8List data, int start, int length) {
  final out = <String, String>{};
  var pos = start;
  final end = start + length;
  while (pos < end && pos < data.length) {
    final len = data[pos];
    if (len == 0 || pos + 1 + len > data.length) break;
    final item = utf8.decode(
      data.sublist(pos + 1, pos + 1 + len),
      allowMalformed: true,
    );
    final eq = item.indexOf('=');
    if (eq > 0) {
      out[item.substring(0, eq)] = item.substring(eq + 1);
    } else if (item.isNotEmpty) {
      out[item] = '';
    }
    pos += 1 + len;
  }
  return out;
}

/// Decodes every answer/authority/additional record of an mDNS message.
///
/// Tolerant by design: a truncated or malformed message yields the records
/// that could be read rather than throwing — a stray packet from an unrelated
/// device must not break a scan.
List<MdnsRecord> decodeMdnsMessage(Uint8List data) {
  final out = <MdnsRecord>[];
  if (data.length < 12) return out;
  final bd = ByteData.sublistView(data);
  final questions = bd.getUint16(4);
  final records = bd.getUint16(6) + bd.getUint16(8) + bd.getUint16(10);

  var pos = 12;
  for (var i = 0; i < questions && pos < data.length; i++) {
    pos = _readName(data, pos).next + 4; // + type, class
  }

  for (var i = 0; i < records && pos + 10 <= data.length; i++) {
    final owner = _readName(data, pos);
    pos = owner.next;
    if (pos + 10 > data.length) break;
    final type = bd.getUint16(pos);
    final rdLength = bd.getUint16(pos + 8);
    pos += 10;
    if (pos + rdLength > data.length) break;

    var value = '';
    var txt = const <String, String>{};
    int? port;
    switch (type) {
      case kDnsTypeA:
        if (rdLength == 4) value = data.sublist(pos, pos + 4).join('.');
      case kDnsTypePtr:
        value = _readName(data, pos).name;
      case kDnsTypeSrv:
        if (rdLength >= 7) {
          port = bd.getUint16(pos + 4);
          value = _readName(data, pos + 6).name;
        }
      case kDnsTypeTxt:
        txt = _readTxt(data, pos, rdLength);
        value = txt.entries.map((e) => '${e.key}=${e.value}').join(' ');
    }
    out.add(
      MdnsRecord(
        name: owner.name,
        type: type,
        value: value,
        txt: txt,
        port: port,
      ),
    );
    pos += rdLength;
  }
  return out;
}

/// A Red Sea device's identity, recovered from its `_http._tcp` TXT record
/// alone — the same three fields `GET /device-info` returns.
class RbMdnsIdentity {
  const RbMdnsIdentity({
    required this.hwid,
    required this.hwModel,
    required this.hwType,
    this.instance,
    this.hostname,
    this.firmwareVersion,
  });

  final String hwid;
  final String hwModel;
  final String hwType;

  /// The service instance name ("RSDOSE4-1752835676").
  final String? instance;

  /// The device's own `.local` name, from the SRV target. Informational: it is
  /// not stored as the device address, because Android's resolver does not
  /// handle `.local` without NsdManager while iOS's does — an address that
  /// works on one platform and not the other is worse than an IP.
  final String? hostname;

  final String? firmwareVersion;
}

/// Extracts a Red Sea identity from one responder's records, if it is one.
///
/// Matches on the TXT payload rather than the service name, because every
/// Red Sea device publishes plain `_http._tcp` — the `hwid`/`hw_model`/
/// `hw_type` triple is what distinguishes it from any other web server on the
/// network.
RbMdnsIdentity? reefBeatIdentityFrom(List<MdnsRecord> records) {
  for (final record in records) {
    if (record.type != kDnsTypeTxt) continue;
    final hwid = record.txt['hwid'];
    final hwModel = record.txt['hw_model'];
    final hwType = record.txt['hw_type'];
    if (hwid == null || hwModel == null || hwType == null) continue;
    if (hwid.isEmpty || hwModel.isEmpty || hwType.isEmpty) continue;

    // The SRV sharing this record's owner name carries the `.local` hostname.
    String? hostname;
    for (final srv in records) {
      if (srv.type == kDnsTypeSrv && srv.name == record.name) {
        hostname = srv.value;
        break;
      }
    }
    return RbMdnsIdentity(
      hwid: hwid,
      hwModel: hwModel,
      hwType: hwType,
      instance: record.name.split('.').first,
      hostname: hostname,
      firmwareVersion: record.txt['firmware_version'],
    );
  }
  return null;
}
