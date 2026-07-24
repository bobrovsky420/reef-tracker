// ReefFactory local-device wire protocol (pure Dart — no Flutter, no dart:io,
// so the frame codec and payload parsers are unit-testable in isolation).
//
// ReefFactory meters (Salinity Guardian, pH Monitor, …) speak a binary
// WebSocket protocol on the LAN with no authentication. Every frame — both
// directions — is five NUL-delimited fields:
//
//     serial \0 command \0 subcommand \0 msgId \0 payload
//
// Reading flow (see [RfModelSpec]): the client sends `get/config`, the device
// replies `refresh/config` (its serial, whose 6-char prefix identifies the
// model), then the client sends `<prefix>Connect/join` and the device streams
// `<prefix>Refresh/settings` frames whose payload carries the live values.
//
// The layouts here were reverse-engineered from the devices' own web UI and
// verified against real hardware (RFSG01 @ conductivity 52.4 mS/cm, 24.9 °C →
// 34.6 ppt; RFPM01 → pH 8.39). See rf_protocol_test.dart for the golden vectors.

import 'dart:math' as math;
import 'dart:typed_data';

/// Fixed-point divisor for the salinity/pH meters: they encode each measurement
/// as an int32 scaled by 10000 (e.g. pH 8.39 is transmitted as 83900).
const int _scale = 10000;

/// The Temperature Controller uses a coarser fixed-point (×1000): 25.2 °C is
/// transmitted as 25200. (Per its own firmware — a different scale from the
/// salinity/pH family above.)
const int _tempScale = 1000;

/// Serial-prefix of the Temperature Controller. The save path treats it as the
/// authoritative temperature source: a Salinity Guardian's temperature reading
/// is only saved when no device of this model is present.
const String kRfTempControllerModel = 'RFTC01';

/// A single value read from a device, keyed by the app's parameter-catalog key
/// (`'salinity'`, `'ph'`, `'temperature'`). [unit] is the unit the value is
/// already in — the canonical catalog unit for that parameter — so the save
/// path can store it directly.
class RfReading {
  const RfReading(this.paramKey, this.value, this.unit);

  final String paramKey;
  final double value;
  final String unit;
}

/// The decoded result of one manual refresh of a device.
class RfSnapshot {
  const RfSnapshot({
    required this.serial,
    required this.modelPrefix,
    required this.modelName,
    required this.modelDisplayName,
    required this.readings,
  });

  final String serial;
  final String modelPrefix;

  /// Short telemetry label ("salinity", "pH", "temperature").
  final String modelName;

  /// Vendor product name ("Salinity Guardian", "pH Monitor", "Temperature
  /// Controller") — used as the default device name on add.
  final String modelDisplayName;

  final List<RfReading> readings;
}

/// One protocol frame, in either direction.
class RfFrame {
  const RfFrame(
    this.serial,
    this.command,
    this.subcommand,
    this.msgId,
    this.payload,
  );

  final String serial;
  final String command;
  final String subcommand;
  final String msgId;
  final Uint8List payload;

  /// Encodes `serial\0 command\0 subcommand\0 msgId\0 payload\0`.
  ///
  /// The device's own client always terminates the payload with a trailing NUL;
  /// we do the same for byte-for-byte parity with its firmware expectations.
  static Uint8List encode({
    required String command,
    String subcommand = '',
    String msgId = '',
    String serial = '0000000000000000',
    List<int> payload = const [],
  }) {
    final b = BytesBuilder();
    void field(String v) {
      b.add(v.codeUnits);
      b.addByte(0);
    }

    field(serial);
    field(command);
    field(subcommand);
    field(msgId);
    b.add(payload);
    b.addByte(0);
    return b.toBytes();
  }

  /// Decodes an inbound frame. The payload is everything after the fourth NUL
  /// (the device does not always trail its payload with a NUL, so we take the
  /// remainder rather than scanning for one).
  static RfFrame decode(List<int> data) {
    var i = 0;
    String readField() {
      final start = i;
      while (i < data.length && data[i] != 0) {
        i++;
      }
      final s = String.fromCharCodes(data, start, i);
      if (i < data.length) i++; // skip the NUL
      return s;
    }

    final serial = readField();
    final command = readField();
    final subcommand = readField();
    final msgId = readField();
    final payload = Uint8List.fromList(
      data.sublist(math.min(i, data.length)),
    );
    return RfFrame(serial, command, subcommand, msgId, payload);
  }
}

/// Reads the leading NUL-terminated C string of a payload (used for the serial
/// number at the head of a `refresh/config` payload).
String readCString(Uint8List p) {
  var i = 0;
  while (i < p.length && p[i] != 0) {
    i++;
  }
  return String.fromCharCodes(p, 0, i);
}

int _i32(Uint8List p, int off) =>
    ByteData.sublistView(p, off, off + 4).getInt32(0, Endian.big);

/// ReefFactory's own salinity conversion (ported verbatim from the device's
/// `RfSg01Main.calculateSalinity`): PSS-78 from in-situ conductivity [c] in
/// mS/cm and temperature [t] in °C, returning practical salinity (ppt), rounded
/// to one decimal exactly as the meter's display does.
double calculateSalinity(double c, double t) {
  final rt = 0.6766097 +
      t * (0.0200564 + t * (0.0001104259 + t * (1.0031e-9 * t - 6.9698e-7)));
  final r = math.sqrt(1e3 * c / 42914 / rt);
  final s = 0.008 +
      r * (r * (25.3851 + r * (14.0941 + r * (2.7081 * r - 7.0261))) - 0.1692) +
      (5e-4 +
              r * (r * (r * (r * (0.0636 + -0.0144 * r) - 0.0375) - 0.0066) - 0.0056)) *
          ((t - 15) / (1 + 0.0162 * (t - 15)));
  return (s * 10).round() / 10;
}

/// Per-model protocol description: the join/refresh command names and the
/// payload parser. Adding a new meter is one entry here plus its parser.
class RfModelSpec {
  const RfModelSpec({
    required this.name,
    required this.displayName,
    required this.connectCommand,
    required this.refreshCommand,
    required this.parse,
  });

  /// Human/telemetry label ("salinity", "pH", "temperature").
  final String name;

  /// Vendor product name, per reeffactory.com/en/smart-devices — used as the
  /// default device name when a device is first added.
  final String displayName;

  /// e.g. `sgConnect` (salinity), `pmConnect` (pH). Sent with subcommand `join`.
  final String connectCommand;

  /// e.g. `sgRefresh` / `pmRefresh`. Live values arrive under subcommand
  /// `settings`.
  final String refreshCommand;

  /// Parses a `settings` payload into readings. Returns empty (rather than
  /// throwing) if the payload is shorter than the known layout — firmware drift
  /// should degrade gracefully, not crash a refresh.
  final List<RfReading> Function(Uint8List payload) parse;
}

/// RFSG01 Salinity Guardian. Payload (int32 BE ÷10000 unless noted):
///   0–3 raw conductivity (mS/cm) · 4 display-unit byte · 5–36 four alarm
///   low/high pairs · 37 alert · 38 sound · 39–42 temperature · 43 temp-unit …
/// Salinity (ppt) is computed from conductivity + temperature; the device does
/// the same math client-side.
List<RfReading> _parseSalinity(Uint8List p) {
  if (p.length < 43) return const [];
  final conductivity = _i32(p, 0) / _scale;
  final temperature = _i32(p, 39) / _scale;
  return [
    RfReading('salinity', calculateSalinity(conductivity, temperature), 'ppt'),
    RfReading('temperature', temperature, '°C'),
  ];
}

/// RFPM01 pH Monitor. Payload: 0–3 pH ×10000 · 4 skip · 5–8 alarm low ·
///   9–12 alarm high · … (no temperature field). Simplest of the family — the
/// value needs no conversion.
List<RfReading> _parsePh(Uint8List p) {
  if (p.length < 4) return const [];
  return [RfReading('ph', _i32(p, 0) / _scale, '')];
}

/// RFTC01 Temperature Controller. Payload (from the device's own `RfTc01Main`):
///   0–3 current temperature (int32 BE ÷1000) · 4 unit byte (0 = °C, else °F) ·
///   then programmed range / alarm / heating-cooling flags. An all-`0xFF`
///   temperature field is the meter's "--.-" (probe unavailable) sentinel → no
///   reading. Temperature is normalised to °C (the catalog's canonical unit).
List<RfReading> _parseTemperature(Uint8List p) {
  if (p.length < 5) return const [];
  if (p[0] == 0xFF && p[1] == 0xFF && p[2] == 0xFF && p[3] == 0xFF) {
    return const [];
  }
  var temp = _i32(p, 0) / _tempScale;
  if (p[4] != 0) {
    // Device set to Fahrenheit — convert, rounding to the meter's 1-decimal
    // display precision to avoid a long binary tail.
    temp = ((temp - 32) * 5 / 9 * 10).round() / 10;
  }
  return [RfReading('temperature', temp, '°C')];
}

/// Registry keyed by the 6-character serial prefix. Unknown prefixes yield a
/// null lookup so the UI can show "unsupported model" instead of failing.
const Map<String, RfModelSpec> kRfModels = {
  'RFSG01': RfModelSpec(
    name: 'salinity',
    displayName: 'Salinity Guardian',
    connectCommand: 'sgConnect',
    refreshCommand: 'sgRefresh',
    parse: _parseSalinity,
  ),
  'RFPM01': RfModelSpec(
    name: 'pH',
    displayName: 'pH Monitor',
    connectCommand: 'pmConnect',
    refreshCommand: 'pmRefresh',
    parse: _parsePh,
  ),
  kRfTempControllerModel: RfModelSpec(
    name: 'temperature',
    displayName: 'Temperature Controller',
    connectCommand: 'tcConnect',
    refreshCommand: 'tcRefresh',
    parse: _parseTemperature,
  ),
};

/// Looks up the model spec for a device serial, or null if unsupported.
RfModelSpec? rfModelForSerial(String serial) =>
    serial.length >= 6 ? kRfModels[serial.substring(0, 6)] : null;
