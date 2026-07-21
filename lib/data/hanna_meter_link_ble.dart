import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/hanna_meter.dart';
import 'hanna_meter_link.dart';

/// The one place in the codebase that touches `flutter_blue_plus` — everything
/// else sees [HannaMeterLink]. Connect flow: adapter check (with a best-effort
/// `turnOn` where the platform allows it) → scan filtered by the `HI97115`
/// advertised-name prefix (the meter uses a random static address, so a MAC
/// filter would break; HANNA.md §3.0) → GATT discovery → subscribe notify →
/// ASCII lines in both directions.
class BleHannaMeterLink implements HannaMeterLink {
  static const _scanTimeout = Duration(seconds: 15);
  static const _connectTimeout = Duration(seconds: 15);

  /// Nordic UART Service — the conventional UUID trio for exactly this kind
  /// of serial-over-GATT protocol. The capture carries only attribute handles
  /// (the phone's GATT cache was warm, so discovery never hit the air), so
  /// these are the *preferred* match; [_pickCharacteristics] falls back to
  /// any custom service exposing a write + notify pair.
  static final Guid _nusService = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _nusWrite = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _nusNotify = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  final _lines = StreamController<String>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  final _buffer = HannaLineBuffer();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _disposed = false;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<void> get onDisconnected => _disconnected.stream;

  @override
  Future<String> connect() async {
    if (await FlutterBluePlus.isSupported == false) {
      throw const HannaLinkException(HannaLinkError.unsupported);
    }
    await _ensureAdapterOn();

    final device = await _scanForMeter();
    _device = device;
    try {
      await device.connect(timeout: _connectTimeout);
      final (write, notify) = await _pickCharacteristics(device);
      _write = write;

      await notify.setNotifyValue(true);
      _subs.add(
        notify.onValueReceived.listen((chunk) {
          for (final line in _buffer.feed(utf8.decode(chunk, allowMalformed: true))) {
            _lines.add(line);
          }
        }),
      );
      // Established-connection watchdog: from here on a drop is an event, not
      // a connect error.
      _subs.add(
        device.connectionState.listen((s) {
          if (s == BluetoothConnectionState.disconnected && !_disposed) {
            _disconnected.add(null);
          }
        }),
      );
    } on HannaLinkException {
      await _teardownDevice();
      rethrow;
    } catch (e) {
      await _teardownDevice();
      throw HannaLinkException(HannaLinkError.connectionFailed, e.toString());
    }
    final adv = device.platformName;
    return adv.isNotEmpty ? adv : kHannaMeterNamePrefix;
  }

  Future<void> _ensureAdapterOn() async {
    var state = await FlutterBluePlus.adapterState.first;
    if (state == BluetoothAdapterState.on) return;
    // Android can prompt the user to enable Bluetooth; elsewhere this throws
    // and we simply fall through to the wait below.
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {}
    try {
      state = await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      throw const HannaLinkException(HannaLinkError.bluetoothOff);
    }
  }

  Future<BluetoothDevice> _scanForMeter() async {
    final found = Completer<BluetoothDevice>();
    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        if (name.startsWith(kHannaMeterNamePrefix) && !found.isCompleted) {
          found.complete(r.device);
        }
      }
    });
    try {
      // flutter_blue_plus requests the runtime permissions itself here; a
      // denial surfaces as an exception → connectionFailed.
      await FlutterBluePlus.startScan(timeout: _scanTimeout);
      final device = await found.future.timeout(
        _scanTimeout + const Duration(seconds: 2),
        onTimeout: () => throw const HannaLinkException(HannaLinkError.notFound),
      );
      return device;
    } on HannaLinkException {
      rethrow;
    } catch (e) {
      throw HannaLinkException(HannaLinkError.connectionFailed, e.toString());
    } finally {
      unawaited(scanSub.cancel());
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  /// Finds the command (write) and response (notify) characteristics: the
  /// Nordic UART pair when present, otherwise the first custom (128-bit UUID)
  /// service exposing both a writable and a notifying characteristic.
  Future<(BluetoothCharacteristic, BluetoothCharacteristic)>
  _pickCharacteristics(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final s in services) {
      if (s.uuid != _nusService) continue;
      BluetoothCharacteristic? w, n;
      for (final c in s.characteristics) {
        if (c.uuid == _nusWrite) w = c;
        if (c.uuid == _nusNotify) n = c;
      }
      if (w != null && n != null) return (w, n);
    }

    for (final s in services) {
      // 16-bit UUIDs are Bluetooth-SIG standard services (battery, device
      // info…) — the meter's serial service is a vendor 128-bit one.
      if (s.uuid.str.length <= 4) continue;
      BluetoothCharacteristic? w, n;
      for (final c in s.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) w ??= c;
        if (c.properties.notify || c.properties.indicate) n ??= c;
      }
      if (w != null && n != null) return (w, n);
    }
    throw const HannaLinkException(
      HannaLinkError.connectionFailed,
      'no write/notify characteristic pair',
    );
  }

  @override
  Future<void> send(String command) async {
    final w = _write;
    if (w == null) {
      throw const HannaLinkException(HannaLinkError.connectionFailed, 'not connected');
    }
    // Bare ASCII, no terminator, acknowledged write — exactly what the
    // capture shows the official app doing (ATT Write Request 0x12).
    await w.write(utf8.encode(command), withoutResponse: false);
  }

  Future<void> _teardownDevice() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _write = null;
    final d = _device;
    _device = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _teardownDevice();
    await _lines.close();
    await _disconnected.close();
  }
}
