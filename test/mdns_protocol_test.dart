import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/mdns_protocol.dart';

/// Builds a DNS message from parts, so the decoder can be exercised against
/// byte layouts (including compression pointers) without a network.
class _MessageBuilder {
  final BytesBuilder _body = BytesBuilder();
  int _records = 0;

  /// Offset of the next byte written, counted from the start of the message —
  /// what a compression pointer has to target.
  int get offset => 12 + _body.length;

  void addName(String name) {
    for (final label in name.split('.')) {
      if (label.isEmpty) continue;
      _body.addByte(label.length);
      _body.add(label.codeUnits);
    }
    _body.addByte(0);
  }

  void addPointer(int target) {
    _body.addByte(0xc0 | ((target >> 8) & 0x3f));
    _body.addByte(target & 0xff);
  }

  void addRecord({
    required int type,
    required List<int> rdata,
    String? name,
    int? namePointer,
  }) {
    if (name != null) {
      addName(name);
    } else {
      addPointer(namePointer!);
    }
    _body
      ..addByte(0)
      ..addByte(type)
      ..addByte(0x80)
      ..addByte(0x01) // class IN, cache-flush
      ..add(const [0, 0, 0x0e, 0x10]); // TTL
    _body
      ..addByte((rdata.length >> 8) & 0xff)
      ..addByte(rdata.length & 0xff)
      ..add(rdata);
    _records++;
  }

  static List<int> txtRdata(List<String> items) {
    final out = <int>[];
    for (final item in items) {
      out
        ..add(item.length)
        ..addAll(item.codeUnits);
    }
    return out;
  }

  Uint8List build() {
    final out = BytesBuilder();
    out.add(const [0, 0]); // id
    out.add(const [0x84, 0x00]); // flags: authoritative response
    out.add(const [0, 0]); // qdcount
    out.add([(_records >> 8) & 0xff, _records & 0xff]); // ancount
    out.add(const [0, 0, 0, 0]); // ns/ar count
    out.add(_body.toBytes());
    return out.toBytes();
  }
}

void main() {
  group('encodeMdnsQuery', () {
    test('encodes labels, type and the QU bit', () {
      final query = encodeMdnsQuery('_http._tcp.local');
      // Header, then 4"_http" 4"_tcp" 5"local" 0, then type + class.
      expect(query.sublist(0, 12), [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
      expect(query[12], 5);
      expect(String.fromCharCodes(query.sublist(13, 18)), '_http');
      expect(query[18], 4);
      expect(String.fromCharCodes(query.sublist(19, 23)), '_tcp');
      // Trailing: root label, type PTR, class with the unicast-response bit.
      expect(query.sublist(query.length - 5), [0, 0, kDnsTypePtr, 0x80, 1]);
    });

    test('clears the QU bit when a multicast answer is wanted', () {
      final query = encodeMdnsQuery('_http._tcp.local', unicastResponse: false);
      expect(query.sublist(query.length - 2), [0x00, 1]);
    });

    test('rejects a label too long to encode', () {
      expect(
        () => encodeMdnsQuery('${'a' * 64}.local'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('decodeMdnsMessage', () {
    test('decodes A, PTR, SRV and TXT records', () {
      final b = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeA,
          name: 'RSDOSE4-1752835676.local',
          rdata: const [192, 168, 1, 3],
        );
      final srvRdata = <int>[0, 0, 0, 0, 0, 80];
      for (final label in ['RSDOSE4-1752835676', 'local']) {
        srvRdata
          ..add(label.length)
          ..addAll(label.codeUnits);
      }
      srvRdata.add(0);
      b
        ..addRecord(
          type: kDnsTypeSrv,
          name: 'RSDOSE4-1752835676._http._tcp.local',
          rdata: srvRdata,
        )
        ..addRecord(
          type: kDnsTypeTxt,
          name: 'RSDOSE4-1752835676._http._tcp.local',
          rdata: _MessageBuilder.txtRdata([
            'hwid=cc7b5c267a68',
            'firmware_version=3.0.0',
            'hw_model=RSDOSE4',
            'hw_type=reef-dosing',
          ]),
        );

      final records = decodeMdnsMessage(b.build());
      expect(records, hasLength(3));

      expect(records[0].type, kDnsTypeA);
      expect(records[0].value, '192.168.1.3');

      expect(records[1].type, kDnsTypeSrv);
      expect(records[1].port, 80);
      expect(records[1].value, 'RSDOSE4-1752835676.local');

      expect(records[2].type, kDnsTypeTxt);
      expect(records[2].txt['hwid'], 'cc7b5c267a68');
      expect(records[2].txt['hw_model'], 'RSDOSE4');
      expect(records[2].txt['hw_type'], 'reef-dosing');
      expect(records[2].txt['firmware_version'], '3.0.0');
    });

    test('follows a compression pointer to an earlier name', () {
      final b = _MessageBuilder();
      final firstNameOffset = b.offset;
      b.addRecord(
        type: kDnsTypeA,
        name: 'RSMAT-4099969749.local',
        rdata: const [192, 168, 1, 235],
      );
      // Second record reuses the first record's name by pointer.
      b.addRecord(
        type: kDnsTypeTxt,
        namePointer: firstNameOffset,
        rdata: _MessageBuilder.txtRdata(['hw_type=reef-mat']),
      );

      final records = decodeMdnsMessage(b.build());
      expect(records, hasLength(2));
      expect(records[1].name, 'RSMAT-4099969749.local');
      expect(records[1].txt['hw_type'], 'reef-mat');
    });

    test('a truncated message yields what could be read, not an exception', () {
      final full = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeA,
          name: 'a.local',
          rdata: const [10, 0, 0, 1],
        )
        ..addRecord(
          type: kDnsTypeA,
          name: 'b.local',
          rdata: const [10, 0, 0, 2],
        );
      final bytes = full.build();
      final truncated = Uint8List.sublistView(bytes, 0, bytes.length - 6);
      expect(decodeMdnsMessage(truncated), hasLength(1));
    });

    test('a runt packet decodes to nothing', () {
      expect(decodeMdnsMessage(Uint8List.fromList(const [0, 0, 1])), isEmpty);
    });

    // The decoder runs on every UDP datagram any host on the LAN chooses to
    // send while a scan is open — hostile shapes must terminate and yield
    // whatever is readable, never hang or throw (a hung decode stalls the
    // whole discovery stream).
    test('a name pointing at itself terminates via the label budget', () {
      final b = _MessageBuilder();
      b.addRecord(
        type: kDnsTypeA,
        namePointer: b.offset, // the pointer's own position: a 1-step cycle
        rdata: const [10, 0, 0, 1],
      );
      final records = decodeMdnsMessage(b.build());
      expect(records, hasLength(1));
      expect(records.single.name, isEmpty);
      expect(records.single.value, '10.0.0.1');
    });

    test('a mutual pointer cycle (owner ↔ rdata) terminates', () {
      // Owner name at 12 points at the rdata (offset 24), whose bytes point
      // back at 12 — a two-step cycle reached from both the owner-name walk
      // and the PTR-value walk.
      final b = _MessageBuilder();
      b.addRecord(type: kDnsTypePtr, namePointer: 24, rdata: const [0xc0, 12]);
      final records = decodeMdnsMessage(b.build());
      expect(records, hasLength(1));
      expect(records.single.type, kDnsTypePtr);
    });

    test('inflated header record counts stop at the real data', () {
      // The header is attacker-controlled; the walker must trust the bytes
      // that exist, not the counts. Claim 65535 records in every section
      // over a single real one.
      final b = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeA,
          name: 'a.local',
          rdata: const [10, 0, 0, 1],
        );
      final bytes = b.build();
      for (final at in [6, 7, 8, 9, 10, 11]) {
        bytes[at] = 0xff; // an/ns/ar counts all 0xffff
      }
      final records = decodeMdnsMessage(bytes);
      expect(records, hasLength(1));
      expect(records.single.value, '10.0.0.1');
    });

    test('a TXT item without "=" becomes a valueless key', () {
      final b = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeTxt,
          name: 'x._arduino._tcp.local',
          rdata: _MessageBuilder.txtRdata(['board=nodemcuv2', 'flag']),
        );
      final txt = decodeMdnsMessage(b.build()).single.txt;
      expect(txt['board'], 'nodemcuv2');
      expect(txt['flag'], '');
    });
  });

  group('reefBeatIdentityFrom', () {
    List<MdnsRecord> redSeaRecords() {
      final b = _MessageBuilder();
      final srvRdata = <int>[0, 0, 0, 0, 0, 80];
      for (final label in ['RSATO+3625739455', 'local']) {
        srvRdata
          ..add(label.length)
          ..addAll(label.codeUnits);
      }
      srvRdata.add(0);
      b
        ..addRecord(
          type: kDnsTypeSrv,
          name: 'RSATO+3625739455._http._tcp.local',
          rdata: srvRdata,
        )
        ..addRecord(
          type: kDnsTypeTxt,
          name: 'RSATO+3625739455._http._tcp.local',
          rdata: _MessageBuilder.txtRdata([
            'hwid=8813bf641cd8',
            'firmware_version=1.11.2',
            'hw_model=RSATO+',
            'hw_type=reef-ato',
          ]),
        );
      return decodeMdnsMessage(b.build());
    }

    test('recovers the whole identity, and the hostname from the SRV', () {
      final identity = reefBeatIdentityFrom(redSeaRecords())!;
      expect(identity.hwid, '8813bf641cd8');
      expect(identity.hwModel, 'RSATO+');
      expect(identity.hwType, 'reef-ato');
      expect(identity.instance, 'RSATO+3625739455');
      expect(identity.hostname, 'RSATO+3625739455.local');
      expect(identity.firmwareVersion, '1.11.2');
    });

    test('ignores a non-Red-Sea responder advertising _http._tcp', () {
      final b = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeTxt,
          name: 'Hue Bridge - A2A9B8._hue._tcp.local',
          rdata: _MessageBuilder.txtRdata([
            'bridgeid=001788fffea2a9b8',
            'modelid=BSB002',
          ]),
        );
      expect(reefBeatIdentityFrom(decodeMdnsMessage(b.build())), isNull);
    });

    test('a TXT missing any of the three identity keys is not a match', () {
      final b = _MessageBuilder()
        ..addRecord(
          type: kDnsTypeTxt,
          name: 'x._http._tcp.local',
          rdata: _MessageBuilder.txtRdata([
            'hwid=abc',
            'hw_model=RSDOSE4',
            // no hw_type
          ]),
        );
      expect(reefBeatIdentityFrom(decodeMdnsMessage(b.build())), isNull);
    });

    test('empty records yield no identity', () {
      expect(reefBeatIdentityFrom(const []), isNull);
    });
  });
}
