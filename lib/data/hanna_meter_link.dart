import 'dart:async';

/// Transport seam for the Hanna checker BLE feature (U33): the session logic
/// talks to this interface only, so tests (and any future non-BLE carrier of
/// the same ASCII protocol) can substitute a fake — the same override story
/// as `CloudAuth` for Drive sync. The real implementation is
/// [BleHannaMeterLink] (`hanna_meter_link_ble.dart`), the codebase's only
/// `flutter_blue_plus` touchpoint.
abstract class HannaMeterLink {
  /// Whole trimmed response lines from the meter, as a broadcast stream.
  /// Emits nothing until [connect] has completed.
  Stream<String> get lines;

  /// Fires once when an established connection drops (never for a failed
  /// [connect] — that throws instead).
  Stream<void> get onDisconnected;

  /// Scans for a meter and connects to it; resolves to the advertised device
  /// name (e.g. `HI97115 06150128`). Throws [HannaLinkException].
  Future<String> connect();

  /// Sends one ASCII command line. The wire format carries **no terminator**
  /// (verified against the capture) — implementations send the bare bytes.
  Future<void> send(String command);

  /// Tears the connection down; safe to call in any state.
  Future<void> dispose();
}

/// Why [HannaMeterLink.connect] gave up — drives the user-facing message.
enum HannaLinkError {
  /// No BLE stack on this device/platform.
  unsupported,

  /// Bluetooth is off and could not be turned on.
  bluetoothOff,

  /// The scan window elapsed without seeing a `HI97115`.
  notFound,

  /// Anything after discovery went wrong: connect failure, missing
  /// write/notify characteristics, or a denied runtime permission.
  connectionFailed,
}

class HannaLinkException implements Exception {
  const HannaLinkException(this.error, [this.detail]);

  final HannaLinkError error;
  final String? detail;

  @override
  String toString() =>
      'HannaLinkException(${error.name})${detail == null ? '' : ': $detail'}';
}
