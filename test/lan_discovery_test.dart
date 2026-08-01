import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/lan_discovery.dart';
import 'package:reeftracker/data/mdns_protocol.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';

/// A scripted network: which hosts answer on port 80, and what mDNS returns.
class _FakeScanner implements LanScanner {
  _FakeScanner({
    this.prefixes = const ['192.168.1'],
    this.mine = const {'192.168.1.100'},
    this.openHosts = const {},
    this.deniedHosts = const {},
    this.denyAll = false,
    this.mdns = const {},
  });

  final List<String> prefixes;
  final Set<String> mine;
  final Set<String> openHosts;

  /// Hosts whose probe the OS refuses ([PortProbe.denied]); [denyAll] scripts
  /// the iOS denied-Local-Network state, where *every* connect is refused.
  final Set<String> deniedHosts;
  final bool denyAll;

  final Map<String, RbMdnsIdentity> mdns;

  /// Every host the sweep actually tried, so tests can assert coverage.
  final List<String> swept = [];

  @override
  Future<List<String>> localPrefixes() async => prefixes;

  @override
  Future<Set<String>> localAddresses() async => mine;

  @override
  Future<PortProbe> probePort(String ip, int port, Duration timeout) async {
    swept.add(ip);
    if (openHosts.contains(ip)) return PortProbe.open;
    if (denyAll || deniedHosts.contains(ip)) return PortProbe.denied;
    return PortProbe.closed;
  }

  @override
  Future<Map<String, RbMdnsIdentity>> mdnsSweep(Duration budget) async => mdns;
}

/// Scripted `/device-info`: an identity per address, [RbLinkError.unreachable]
/// for anything else — what a router or a NAS looks like to this probe.
class _FakeRbProbe implements RbIdentityProbe {
  _FakeRbProbe(this.byAddress);
  final Map<String, RbDeviceInfo> byAddress;
  final List<String> calls = [];

  @override
  Future<RbDeviceInfo> identify(String host) async {
    calls.add(host);
    final info = byAddress[host];
    if (info == null) throw const RbLinkException(RbLinkError.unreachable);
    return info;
  }
}

/// Scripted ReefFactory handshake.
class _FakeRfProbe implements RfIdentityProbe {
  _FakeRfProbe(this.byAddress);
  final Map<String, RfIdentity> byAddress;
  final List<String> calls = [];

  @override
  Future<RfIdentity> identify(String host) async {
    calls.add(host);
    final id = byAddress[host];
    if (id == null) throw const RfLinkException(RfLinkError.unreachable);
    return id;
  }
}

RbMdnsIdentity _mdns(String hwid, String model, String type) => RbMdnsIdentity(
  hwid: hwid,
  hwModel: model,
  hwType: type,
  hostname: '$model.local',
);

RbDeviceInfo _info(String hwid, String model, String type) =>
    RbDeviceInfo(hwType: type, hwModel: model, hwid: hwid);

void main() {
  Future<DiscoveryProgress> runScan(LanDiscoveryService service) async =>
      (await service.scan().toList()).last;

  test('mDNS identifies Red Sea devices without any HTTP probe', () async {
    final scanner = _FakeScanner(
      openHosts: {'192.168.1.3', '192.168.1.235'},
      mdns: {
        '192.168.1.3': _mdns('cc7b5c267a68', 'RSDOSE4', kRbDosingHwType),
        '192.168.1.235': _mdns('c4d8d59260f4', 'RSMAT', kRbMatHwType),
      },
    );
    final rb = _FakeRbProbe({});
    final rf = _FakeRfProbe({});
    final result = await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: rb,
        reefFactoryProbe: rf,
      ),
    );

    expect(result.phase, DiscoveryPhase.done);
    expect(result.devices, hasLength(2));
    expect(result.devices.every((d) => d.viaMdns), isTrue);
    expect(result.devices.first.modelDisplayName, 'ReefDose 4');
    // The whole point of the mDNS pre-pass: those hosts are never probed.
    expect(rb.calls, isEmpty);
    expect(rf.calls, isEmpty);
  });

  test(
    'ReefFactory devices, which advertise nothing, are found by the sweep',
    () async {
      final scanner = _FakeScanner(openHosts: {'192.168.1.7'});
      final rb = _FakeRbProbe({});
      final rf = _FakeRfProbe({
        '192.168.1.7': const RfIdentity(
          serial: 'RFSG012110010070',
          modelPrefix: 'RFSG01',
          modelName: 'salinity',
          displayName: 'Salinity Guardian',
        ),
      });
      final result = await runScan(
        LanDiscoveryService(
          scanner: scanner,
          reefBeatProbe: rb,
          reefFactoryProbe: rf,
        ),
      );

      expect(result.devices, hasLength(1));
      final device = result.devices.single;
      expect(device.kind, DiscoveredKind.reeffactory);
      expect(device.identifier, 'RFSG012110010070');
      expect(device.modelDisplayName, 'Salinity Guardian');
      expect(device.supported, isTrue);
      expect(device.viaMdns, isFalse);
      // ReefBeat is tried first because it is the cheaper probe.
      expect(rb.calls, ['192.168.1.7']);
    },
  );

  test('only hosts mDNS could not explain get a protocol probe', () async {
    final scanner = _FakeScanner(
      openHosts: {'192.168.1.1', '192.168.1.3', '192.168.1.16'},
      mdns: {'192.168.1.3': _mdns('cc7b5c267a68', 'RSDOSE4', kRbDosingHwType)},
    );
    final rb = _FakeRbProbe({});
    final rf = _FakeRfProbe({});
    await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: rb,
        reefFactoryProbe: rf,
      ),
    );

    expect(rb.calls, containsAll(['192.168.1.1', '192.168.1.16']));
    expect(rb.calls, isNot(contains('192.168.1.3')));
  });

  test('an unsupported hw_type is reported, not hidden', () async {
    final scanner = _FakeScanner(
      openHosts: {'192.168.1.4'},
      mdns: {'192.168.1.4': _mdns('e868e7eb7a28', 'RSWAVE25', 'reef-future')},
    );
    final result = await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );

    final device = result.devices.single;
    expect(device.supported, isFalse);
    expect(device.hwType, 'reef-future');
    expect(device.modelDisplayName, 'ReefWave 25');
  });

  test('every supported ReefBeat type is marked supported', () async {
    for (final type in kRbSupportedHwTypes) {
      final scanner = _FakeScanner(
        openHosts: {'192.168.1.9'},
        mdns: {'192.168.1.9': _mdns('aa', 'RSX', type)},
      );
      final result = await runScan(
        LanDiscoveryService(
          scanner: scanner,
          reefBeatProbe: _FakeRbProbe({}),
          reefFactoryProbe: _FakeRfProbe({}),
        ),
      );
      expect(result.devices.single.supported, isTrue, reason: type);
    }
  });

  test('the same device seen twice is reported once', () async {
    // mDNS answers for .3, and the HTTP probe would too — the identifier keys
    // the map, so a duplicate can never reach the list.
    final scanner = _FakeScanner(
      openHosts: {'192.168.1.3'},
      mdns: {'192.168.1.3': _mdns('cc7b5c267a68', 'RSDOSE4', kRbDosingHwType)},
    );
    final result = await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: _FakeRbProbe({
          '192.168.1.3': _info('cc7b5c267a68', 'RSDOSE4', kRbDosingHwType),
        }),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );
    expect(result.devices, hasLength(1));
  });

  test(
    'reports noNetwork rather than an empty result when there is no LAN',
    () async {
      final result = await runScan(
        LanDiscoveryService(
          scanner: _FakeScanner(prefixes: const []),
          reefBeatProbe: _FakeRbProbe({}),
          reefFactoryProbe: _FakeRfProbe({}),
        ),
      );
      expect(result.noNetwork, isTrue);
      expect(result.phase, DiscoveryPhase.done);
      expect(result.devices, isEmpty);
    },
  );

  test('sweeps the whole /24 except the phone itself', () async {
    final scanner = _FakeScanner(mine: const {'192.168.1.100'});
    await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );
    expect(scanner.swept, hasLength(253));
    expect(scanner.swept, contains('192.168.1.1'));
    expect(scanner.swept, contains('192.168.1.254'));
    expect(scanner.swept, isNot(contains('192.168.1.100')));
    expect(scanner.swept, isNot(contains('192.168.1.255')));
  });

  test('several private subnets are swept, bounded by maxSubnets', () async {
    final scanner = _FakeScanner(
      prefixes: const ['192.168.1', '10.0.0', '172.16.5'],
      mine: const {},
    );
    await runScan(
      LanDiscoveryService(
        scanner: scanner,
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
        maxSubnets: 2,
      ),
    );
    expect(scanner.swept, hasLength(254 * 2));
    expect(scanner.swept.any((ip) => ip.startsWith('172.16.5')), isFalse);
  });

  test('progress runs through sweeping then identifying to done', () async {
    final events = await LanDiscoveryService(
      scanner: _FakeScanner(openHosts: {'192.168.1.7'}),
      reefBeatProbe: _FakeRbProbe({}),
      reefFactoryProbe: _FakeRfProbe({
        '192.168.1.7': const RfIdentity(
          serial: 'RFPM012204210108',
          modelPrefix: 'RFPM01',
          modelName: 'ph',
          displayName: 'pH Monitor',
        ),
      }),
    ).scan().toList();

    expect(events.first.phase, DiscoveryPhase.sweeping);
    expect(events.map((e) => e.phase), contains(DiscoveryPhase.identifying));
    expect(events.last.phase, DiscoveryPhase.done);
    // The sweep bar never exceeds its total.
    for (final event in events) {
      expect(event.scanned, lessThanOrEqualTo(event.total));
    }
  });

  test('a host that is neither vendor is dropped silently', () async {
    final result = await runScan(
      LanDiscoveryService(
        scanner: _FakeScanner(openHosts: {'192.168.1.1', '192.168.1.16'}),
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );
    expect(result.devices, isEmpty);
    expect(result.noNetwork, isFalse);
    expect(result.permissionDenied, isFalse);
  });

  test(
    'a sweep the OS refuses outright reports permissionDenied (#89)',
    () async {
      // The iOS denied-Local-Network state: every connect fails immediately as
      // refused-by-policy, nothing opens, mDNS is equally blocked.
      final result = await runScan(
        LanDiscoveryService(
          scanner: _FakeScanner(denyAll: true),
          reefBeatProbe: _FakeRbProbe({}),
          reefFactoryProbe: _FakeRfProbe({}),
        ),
      );
      expect(result.phase, DiscoveryPhase.done);
      expect(result.devices, isEmpty);
      expect(result.permissionDenied, isTrue);
    },
  );

  test('scattered refusals never claim a permission problem', () async {
    final result = await runScan(
      LanDiscoveryService(
        scanner: _FakeScanner(deniedHosts: {'192.168.1.5', '192.168.1.6'}),
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );
    expect(result.permissionDenied, isFalse);
  });

  test('anything actually found disproves a denied sweep', () async {
    // Contradictory by construction (denied means multicast is blocked too),
    // but the honest reading of "a device was found" wins over the errnos.
    final result = await runScan(
      LanDiscoveryService(
        scanner: _FakeScanner(
          denyAll: true,
          mdns: {
            '192.168.1.3': _mdns('cc7b5c267a68', 'RSDOSE4', kRbDosingHwType),
          },
        ),
        reefBeatProbe: _FakeRbProbe({}),
        reefFactoryProbe: _FakeRfProbe({}),
      ),
    );
    expect(result.devices, hasLength(1));
    expect(result.permissionDenied, isFalse);
  });
}
