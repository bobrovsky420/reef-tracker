// LAN discovery (U39): finds every supported Red Sea ReefBeat and ReefFactory
// device on the phone's network, so a keeper never has to read an IP address
// off a router page.
//
// ## Why it is shaped like this
//
// The two vendors behave completely differently on the wire, which was
// established by probing live hardware:
//
//   * **Red Sea (ReefBeat)** advertises over mDNS, and its `_http._tcp` TXT
//     record carries `hwid`, `hw_model` and `hw_type` — the entire identity,
//     without an HTTP request. Every Red Sea device answers in ~2 s.
//   * **ReefFactory advertises nothing at all.** A full service enumeration
//     returns silence from them; they are only findable by connecting.
//
// So mDNS alone can never be the mechanism — a **port-80 sweep of the local
// /24 is mandatory**. mDNS earns its place as a *classifier* instead: it
// identifies the Red Sea hosts up front, so the sweep's survivors only need
// the slow WebSocket probe for the handful that mDNS didn't explain. On a real
// network that turns ~14 protocol probes into ~5.
//
// It is also the fallback-safe order. If mDNS yields nothing — the system
// responder holds the port, a network blocks multicast, or iOS withholds the
// multicast entitlement — discovery still finds everything via the sweep, just
// with more probing. Nothing here treats an empty mDNS result as an error.
//
// Measured on a live network: the /24 sweep takes ~2.5 s at 48-way
// concurrency with a 400 ms connect timeout; mDNS ~2 s in parallel; the
// leftover protocol probes a few seconds more.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'mdns_protocol.dart';
import 'rb_device_link.dart';
import 'rb_protocol.dart';
import 'rf_device_link.dart';

/// Which integration a discovered device belongs to — the `kind` column of the
/// devices table.
enum DiscoveredKind { reefbeat, reeffactory }

/// A device found on the network, before the user decides to add it.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.kind,
    required this.identifier,
    required this.address,
    required this.modelCode,
    required this.modelDisplayName,
    required this.supported,
    this.hwType,
    this.hostname,
    this.viaMdns = false,
  });

  final DiscoveredKind kind;

  /// The stable unique id — a ReefBeat `hwid` or a ReefFactory serial. Matches
  /// `Devices.identifier`, so a rediscovered device updates its row rather than
  /// duplicating it.
  final String identifier;

  /// The IPv4 address it answered on.
  final String address;

  /// Model code ("RSDOSE4", "RFSG01") and its friendly name.
  final String modelCode;
  final String modelDisplayName;

  /// Whether this app can actually read the device. Unsupported devices are
  /// still reported — a keeper with a ReefWave should see it was found, not
  /// wonder why the scan "missed" it.
  final bool supported;

  /// ReefBeat `hw_type`, for explaining an unsupported find.
  final String? hwType;

  /// The `.local` name from mDNS, shown as a hint only — never stored as the
  /// address, because Android does not resolve `.local` without NsdManager.
  final String? hostname;

  /// True when mDNS identified it (no HTTP probe was needed).
  final bool viaMdns;
}

/// How far along a scan is. [total] and [scanned] describe the current
/// [phase] only, so the UI can show one honest bar per stage.
enum DiscoveryPhase { sweeping, identifying, done }

class DiscoveryProgress {
  const DiscoveryProgress({
    required this.phase,
    required this.devices,
    this.scanned = 0,
    this.total = 0,
    this.noNetwork = false,
    this.permissionDenied = false,
  });

  final DiscoveryPhase phase;

  /// Everything found so far, deduplicated by identifier, in discovery order.
  final List<DiscoveredDevice> devices;

  final int scanned;
  final int total;

  /// No private IPv4 network to scan — cellular-only, Wi-Fi off, or an
  /// interface the app can't see. The UI explains this rather than reporting
  /// "no devices found".
  final bool noNetwork;

  /// The OS refused the sweep's connections outright (#89) — iOS 14+ with the
  /// Local Network permission denied. Everything LAN fails in that state,
  /// manual IP entry included, so the UI points at the system setting instead
  /// of blaming the router. Only set on the [DiscoveryPhase.done] event.
  final bool permissionDenied;
}

/// What one TCP probe of the sweep learned about a host.
enum PortProbe {
  /// The port accepted a connection.
  open,

  /// Nothing usable answered — refused, timed out, or any ordinary failure.
  closed,

  /// The **OS** refused the connection before it left the phone (#89): on
  /// iOS 14+ a denied Local Network permission fails every LAN connect
  /// immediately with EPERM/EHOSTUNREACH. Never reported on Android, which
  /// has no such permission.
  denied,
}

/// The raw network primitives discovery needs, behind a seam so the service is
/// testable without a LAN (mirrors the `RbDeviceLink` / `RfDeviceLink`
/// fake-injection pattern).
abstract class LanScanner {
  /// The `a.b.c` prefixes of the private IPv4 /24s worth scanning.
  Future<List<String>> localPrefixes();

  /// The phone's own addresses, skipped by the sweep.
  Future<Set<String>> localAddresses();

  /// Whether [ip] accepts a TCP connection on [port] within [timeout] — and,
  /// when it doesn't, whether the OS itself blocked the attempt (#89).
  Future<PortProbe> probePort(String ip, int port, Duration timeout);

  /// One mDNS sweep, returning Red Sea identities keyed by the responder's IP.
  /// Returns empty rather than throwing when mDNS is unavailable.
  Future<Map<String, RbMdnsIdentity>> mdnsSweep(Duration budget);
}

/// Finds ReefBeat and ReefFactory devices on the local network.
class LanDiscoveryService {
  LanDiscoveryService({
    required this.scanner,
    required this.reefBeatProbe,
    required this.reefFactoryProbe,
    this.connectTimeout = const Duration(milliseconds: 400),
    this.mdnsBudget = const Duration(milliseconds: 2500),
    this.sweepConcurrency = 48,
    this.probeConcurrency = 8,
    this.maxSubnets = 2,
  });

  final LanScanner scanner;
  final RbIdentityProbe reefBeatProbe;
  final RfIdentityProbe reefFactoryProbe;

  /// Per-host TCP connect timeout for the sweep. Short on purpose: a device
  /// that is up answers a LAN SYN in single-digit milliseconds, and this
  /// multiplies by 254.
  final Duration connectTimeout;

  /// How long to listen for mDNS answers. Runs concurrently with the sweep, so
  /// it costs no extra wall-clock.
  final Duration mdnsBudget;

  final int sweepConcurrency;
  final int probeConcurrency;

  /// A phone on several private networks (Wi-Fi + VPN + hotspot) would
  /// otherwise multiply the sweep; two is already generous for a home reef.
  final int maxSubnets;

  /// Runs one scan, emitting progress as it goes and ending with a
  /// [DiscoveryPhase.done] event.
  ///
  /// Cancelling the subscription stops the scan at the next progress event.
  Stream<DiscoveryProgress> scan() async* {
    final found = <String, DiscoveredDevice>{};

    final prefixes = (await scanner.localPrefixes()).take(maxSubnets).toList();
    if (prefixes.isEmpty) {
      yield const DiscoveryProgress(
        phase: DiscoveryPhase.done,
        devices: [],
        noNetwork: true,
      );
      return;
    }

    // Start mDNS immediately; it resolves while the sweep runs.
    final mdnsFuture = scanner.mdnsSweep(mdnsBudget);
    final mine = await scanner.localAddresses();
    final hosts = <String>[
      for (final prefix in prefixes)
        for (var octet = 1; octet <= 254; octet++)
          if (!mine.contains('$prefix.$octet')) '$prefix.$octet',
    ];

    // --- Phase 1: who is listening on port 80 at all? --------------------
    final open = <String>[];
    var denied = 0;
    var scanned = 0;
    yield DiscoveryProgress(
      phase: DiscoveryPhase.sweeping,
      devices: const [],
      total: hosts.length,
    );
    for (var i = 0; i < hosts.length; i += sweepConcurrency) {
      final batch = hosts.skip(i).take(sweepConcurrency).toList();
      final results = await Future.wait([
        for (final ip in batch) scanner.probePort(ip, 80, connectTimeout),
      ]);
      for (var j = 0; j < batch.length; j++) {
        switch (results[j]) {
          case PortProbe.open:
            open.add(batch[j]);
          case PortProbe.denied:
            denied++;
          case PortProbe.closed:
            break;
        }
      }
      scanned += batch.length;
      yield DiscoveryProgress(
        phase: DiscoveryPhase.sweeping,
        devices: found.values.toList(),
        scanned: scanned,
        total: hosts.length,
      );
    }

    // --- Phase 2: let mDNS explain the Red Sea hosts for free ------------
    final identities = await mdnsFuture;
    for (final entry in identities.entries) {
      final device = _fromMdns(entry.key, entry.value);
      found[device.identifier] = device;
    }

    // Only hosts mDNS could not account for need a protocol probe.
    final unexplained = [
      for (final ip in open)
        if (!identities.containsKey(ip)) ip,
    ];
    yield DiscoveryProgress(
      phase: DiscoveryPhase.identifying,
      devices: found.values.toList(),
      total: unexplained.length,
    );

    // --- Phase 3: identify the leftovers ---------------------------------
    var probed = 0;
    for (var i = 0; i < unexplained.length; i += probeConcurrency) {
      final batch = unexplained.skip(i).take(probeConcurrency).toList();
      final results = await Future.wait([
        for (final ip in batch) _identify(ip),
      ]);
      for (final device in results) {
        if (device != null) found[device.identifier] = device;
      }
      probed += batch.length;
      yield DiscoveryProgress(
        phase: DiscoveryPhase.identifying,
        devices: found.values.toList(),
        scanned: probed,
        total: unexplained.length,
      );
    }

    yield DiscoveryProgress(
      phase: DiscoveryPhase.done,
      devices: found.values.toList(),
      scanned: unexplained.length,
      total: unexplained.length,
      // A denied Local Network permission (#89) rejects *every* probe
      // immediately — a majority of the sweep, nothing open, nothing found
      // (mDNS multicast is blocked in the same state). A network where a few
      // hosts merely answer strangely never claims it.
      permissionDenied:
          found.isEmpty && open.isEmpty && denied > hosts.length ~/ 2,
    );
  }

  static DiscoveredDevice _fromMdns(String ip, RbMdnsIdentity id) =>
      DiscoveredDevice(
        kind: DiscoveredKind.reefbeat,
        identifier: id.hwid,
        address: ip,
        modelCode: id.hwModel,
        modelDisplayName: rbModelDisplayName(id.hwModel),
        supported: kRbSupportedHwTypes.contains(id.hwType),
        hwType: id.hwType,
        hostname: id.hostname,
        viaMdns: true,
      );

  /// Identifies one open host: ReefBeat first (a plain HTTP GET, fast and
  /// cheap), then ReefFactory (a WebSocket handshake). Anything else — a
  /// router, a NAS, a smart plug — returns null.
  Future<DiscoveredDevice?> _identify(String ip) async {
    try {
      final info = await reefBeatProbe.identify(ip);
      return DiscoveredDevice(
        kind: DiscoveredKind.reefbeat,
        identifier: info.hwid,
        address: ip,
        modelCode: info.hwModel,
        modelDisplayName: rbModelDisplayName(info.hwModel),
        supported: kRbSupportedHwTypes.contains(info.hwType),
        hwType: info.hwType,
      );
    } on RbLinkException {
      // Not a ReefBeat device — fall through to the ReefFactory handshake.
    }
    try {
      final id = await reefFactoryProbe.identify(ip);
      return DiscoveredDevice(
        kind: DiscoveredKind.reeffactory,
        identifier: id.serial,
        address: ip,
        modelCode: id.modelPrefix,
        modelDisplayName: id.displayName ?? id.modelPrefix,
        supported: id.supported,
      );
    } on RfLinkException {
      return null;
    }
  }
}

/// The real [LanScanner], over `dart:io` sockets.
class IoLanScanner implements LanScanner {
  const IoLanScanner();

  /// Only RFC 1918 space is swept. This deliberately excludes 169.254/16
  /// (link-local, i.e. no DHCP), 127/8 and 100.64/10 (carrier-grade NAT on
  /// cellular) — sweeping a carrier's network would be both useless and rude.
  static bool _isPrivateIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  Future<List<InternetAddress>> _addresses() async {
    final out = <InternetAddress>[];
    // #85: an enumeration failure must degrade to "no network to scan" (an
    // explained dead end) — an escaping error would kill the whole scan
    // stream, and the sheet with it.
    final List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
    } catch (_) {
      return out;
    }
    for (final iface in interfaces) {
      out.addAll(iface.addresses);
    }
    return out;
  }

  @override
  Future<List<String>> localPrefixes() async {
    final prefixes = <String>[];
    for (final address in await _addresses()) {
      final ip = address.address;
      if (!_isPrivateIPv4(ip)) continue;
      // A /24 is assumed: NetworkInterface exposes no netmask, and every home
      // network this feature targets is one. Manual entry stays the escape
      // hatch for anything wider or segmented.
      final prefix = ip.substring(0, ip.lastIndexOf('.'));
      if (!prefixes.contains(prefix)) prefixes.add(prefix);
    }
    return prefixes;
  }

  @override
  Future<Set<String>> localAddresses() async => {
    for (final a in await _addresses()) a.address,
  };

  /// Whether a refused connect can mean the OS blocked LAN access. Only iOS
  /// has the Local Network permission (#89); Android must never report
  /// [PortProbe.denied] — its EHOSTUNREACH is an ordinary absent-host answer,
  /// not a policy statement, and the notice the flag drives names an iOS
  /// setting.
  static final bool _canBeDenied = Platform.isIOS;

  /// Darwin errnos of a connect the OS itself refused: EPERM (1) and
  /// EHOSTUNREACH (65) — what a denied Local Network permission produces,
  /// immediately, for every LAN peer.
  static const _deniedErrnos = {1, 65};

  @override
  Future<PortProbe> probePort(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return PortProbe.open;
    } on SocketException catch (e) {
      return _canBeDenied && _deniedErrnos.contains(e.osError?.errorCode)
          ? PortProbe.denied
          : PortProbe.closed;
    } catch (_) {
      return PortProbe.closed;
    }
  }

  @override
  Future<Map<String, RbMdnsIdentity>> mdnsSweep(Duration budget) async {
    RawDatagramSocket socket;
    try {
      // An ephemeral port, not :5353 — see [encodeMdnsQuery]'s QU note. The
      // queries ask for unicast answers, so nothing needs the well-known port
      // or a multicast group membership.
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return const {};
    }

    final recordsByIp = <String, List<MdnsRecord>>{};
    socket.readEventsEnabled = true;
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      (recordsByIp[datagram.address.address] ??= []).addAll(
        decodeMdnsMessage(Uint8List.fromList(datagram.data)),
      );
    });

    try {
      final group = InternetAddress(kMdnsGroupAddress);
      void ask(String name) {
        try {
          socket.send(encodeMdnsQuery(name), group, kMdnsPort);
        } catch (_) {
          // A network that refuses multicast sends: the sweep carries the scan.
        }
      }

      // Two rounds, because a single UDP query is allowed to go missing.
      // `_http._tcp` is what carries the Red Sea TXT identity; the service
      // enumeration prompts responders that answer it but ignore direct
      // browses.
      for (var round = 0; round < 2; round++) {
        ask(kMdnsHttpService);
        ask(kMdnsServiceEnumeration);
        await Future<void>.delayed(budget ~/ 2);
      }
    } finally {
      await sub.cancel();
      socket.close();
    }

    final out = <String, RbMdnsIdentity>{};
    for (final entry in recordsByIp.entries) {
      final identity = reefBeatIdentityFrom(entry.value);
      if (identity != null) out[entry.key] = identity;
    }
    return out;
  }
}
