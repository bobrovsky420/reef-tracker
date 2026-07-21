/// Hanna checker direct BLE (U33) — the pure app-layer protocol for the
/// HI97115C "Marine Master" photometer. No Flutter, no DB, no BLE plugin:
/// everything here operates on the ASCII lines the transport delivers.
///
/// Protocol facts (reverse-engineered; see HANNA.md for the captures):
/// plain unencrypted ASCII lines over a Nordic-UART-style GATT pair, commands
/// written as text, responses notified as `PREFIX,fields...` CSV-ish lines
/// terminated with `\n`. A measurement streams `T,`/`M,` progress frames full
/// of `-` placeholders and finally ONE `M,` frame whose **last field is `R`**
/// — only that frame carries a real value + timestamp.
///
/// The protocol is unofficial and firmware-coupled (the meter updates through
/// Hanna Lab), which is why the whole feature ships flagged experimental.
library;

import 'package:meta/meta.dart';

part 'hanna_meter.g.dart';

/// Advertised-name prefix used to pick the meter out of a scan. The meter's
/// BLE address is a *random static* address that can differ per unit and
/// rotate — never match on MAC.
const String kHannaMeterNamePrefix = 'HI97115';

/// Protocol version reported by `info` (`v5.0` at capture time). Kept for a
/// future "unknown protocol" guard; the client currently only logs it.
const String kHannaKnownProtocolVersion = 'v5.0';

// --- commands ----------------------------------------------------------------

const String hannaCmdInfo = 'info';
const String hannaCmdGetBattery = 'get battery';
const String hannaCmdGetSetup = 'get setup';
const String hannaCmdGetTanks = 'get setup tank,all';
const String hannaCmdMeasOn = 'set meas on';
const String hannaCmdStart = 'set setup start';
const String hannaCmdExit = 'set setup exit';

String hannaCmdSelectMethod(int code) => 'set setup method,$code';

/// RTC sync (`set time YYYYMMDDHHMMSS`) — sent on every connect so the
/// timestamps the result frames carry (meter wall-clock) match the phone's.
String hannaCmdSetTime(DateTime now) {
  String p2(int v) => v.toString().padLeft(2, '0');
  return 'set time ${now.year.toString().padLeft(4, '0')}${p2(now.month)}'
      '${p2(now.day)}${p2(now.hour)}${p2(now.minute)}${p2(now.second)}';
}

// --- method registry ---------------------------------------------------------

/// One measurement method the meter offers, keyed by its numeric code — the
/// stable identifier the protocol uses (`set setup method,<code>`, field 2 of
/// every measurement frame). Range variants are distinct codes but the SAME
/// analyte: the reading is stored under [paramKey]; the code is provenance
/// only. Same principle as the U32 CSV mapping on `Method`, never on value.
///
/// The method table itself ([kHannaMeterMethods]) is generated from
/// `hanna_methods.yaml` — edit the YAML, then run
/// `dart run tool/gen_hanna_methods.dart`.
@immutable
class HannaMeterMethod {
  const HannaMeterMethod(
    this.code,
    this.paramKey, {
    this.lowRange = false,
    this.factor = 1,
  });

  /// The meter's numeric method code (e.g. `2002`).
  final int code;

  /// The catalog parameter the reading lands on.
  final String paramKey;

  /// Whether this is a low-range chemistry — display-only (the picker adds a
  /// low-range tag). A parameter may have both a standard and a low-range
  /// code (nitrate) or only a low-range one (nitrite).
  final bool lowRange;

  /// Multiplier from the meter's reported value to the catalog's canonical
  /// unit — 1 for most methods (they already report ppm/dKH/pH); nitrite LR
  /// reports ppb, so 0.001 to ppm.
  final double factor;
}

/// Lookup by numeric code; null for a code this build doesn't know.
HannaMeterMethod? hannaMethodByCode(int code) {
  for (final m in kHannaMeterMethods) {
    if (m.code == code) return m;
  }
  return null;
}

/// A user-configured, named pre-selection of methods to run as a group
/// ("Daily test", "Weekly test"…). Stored as one JSON settings value
/// (`SettingKey.hannaMethodSets`); the codes reference [kHannaMeterMethods]
/// and unknown codes are dropped on decode, so a set survives a future
/// method-table change gracefully.
@immutable
class HannaMethodSet {
  const HannaMethodSet({required this.name, required this.codes});

  final String name;
  final List<int> codes;
}

// --- line assembly -----------------------------------------------------------

/// Reassembles the notify stream into whole lines: BLE notifications chunk on
/// MTU boundaries, so a line may arrive split (or several may arrive glued).
/// Feed raw text, get back only complete `\n`-terminated lines, trimmed.
class HannaLineBuffer {
  final StringBuffer _pending = StringBuffer();

  List<String> feed(String chunk) {
    _pending.write(chunk);
    final all = _pending.toString();
    final parts = all.split('\n');
    _pending
      ..clear()
      ..write(parts.removeLast()); // possibly-partial tail stays buffered
    return [
      for (final p in parts)
        if (p.trim().isNotEmpty) p.trim(),
    ];
  }
}

// --- response parsing --------------------------------------------------------

/// `info` response: identity + firmware of the connected meter.
@immutable
class HannaMeterInfo {
  const HannaMeterInfo({
    required this.model,
    required this.deviceId,
    required this.firmware,
    required this.serial,
    required this.protocolVersion,
  });

  final String model;
  final String deviceId;
  final String firmware;
  final String serial;
  final String protocolVersion;
}

/// Parses `I,HI97115,06150128,FW,v1.07,nRF FW,v1.01,SN,906150128111,RCL,130,
/// English,v5.0`. Labeled fields are located by their label (not position) so
/// a firmware inserting a field doesn't break identity.
HannaMeterInfo? parseHannaInfo(String line) {
  final f = _fields(line);
  if (f.length < 3 || f[0] != 'I') return null;
  String after(String label) {
    final i = f.indexOf(label);
    return i >= 0 && i + 1 < f.length ? f[i + 1] : '';
  }

  return HannaMeterInfo(
    model: f[1],
    deviceId: f[2],
    firmware: after('FW'),
    serial: after('SN'),
    protocolVersion: f.isNotEmpty ? f.last : '',
  );
}

/// Parses `GB,75,%` to the battery percentage, or null.
int? parseHannaBattery(String line) {
  final f = _fields(line);
  if (f.length < 2 || f[0] != 'GB') return null;
  return int.tryParse(f[1]);
}

/// Whether [line] is the `PREFIX,Ack` acknowledgement for a command class
/// (`ST`/`SM`/`SS`/`SD`/`SE`...).
bool isHannaAck(String line, String prefix) {
  final f = _fields(line);
  return f.length >= 2 && f[0] == prefix && f[1] == 'Ack';
}

/// Parses one `GL,name,name,...,` page of the tank/location list (the meter
/// paginates 15 names per line, up to 100 total). Returns null for non-GL
/// lines; trailing empty fields (the `,` terminator) are dropped.
List<String>? parseHannaTankPage(String line) {
  final f = _fields(line);
  if (f.isEmpty || f[0] != 'GL') return null;
  final names = f.sublist(1);
  while (names.isNotEmpty && names.last.isEmpty) {
    names.removeLast();
  }
  return names;
}

/// How many names a full `GL` page carries — a shorter page means the list
/// is complete (a multiple-of-page-size list ends on a quiet timeout instead).
const int kHannaTankPageSize = 15;

/// A progress tick of a running measurement (`T,`/`M,` frame without the
/// final `R`): the method it belongs to and the meter's `STATUS` step.
@immutable
class HannaProgress {
  const HannaProgress({required this.methodCode, required this.step});

  final int methodCode;
  final int? step;
}

/// One completed measurement — the decoded `…,R` result frame.
@immutable
class HannaMeasurement {
  const HannaMeasurement({
    required this.methodCode,
    required this.value,
    required this.tankName,
    required this.takenAt,
  });

  final int methodCode;
  final double value;

  /// The meter-side tank/location the meter recorded the reading under.
  final String tankName;

  /// Meter wall-clock timestamp (`YYYYMMDDHHMMSS`, local), or null when the
  /// frame carried `-` — callers fall back to the receive time.
  final DateTime? takenAt;
}

/// Parses a measurement frame. Returns a [HannaMeasurement] for the final
/// result frame (`M,…,R`), a [HannaProgress] for `T,`/`M,` ticks, and null
/// for anything that isn't a measurement frame at all.
///
/// Fields are anchored from the END (`…,tank,locidx,devid,timestamp,STATUS,
/// step,Z,R`) rather than by index from the start: a meter configured to a
/// comma decimal separator would split the value field in two, shifting
/// everything after it. Whatever sits between the unit field and the range
/// flag is the value — one part (`8.104962`) or two (`8,104962`).
Object? parseHannaMeasurementFrame(String line) {
  final f = _fields(line);
  if (f.length < 12 || (f[0] != 'M' && f[0] != 'T')) return null;
  final code = int.tryParse(f[1]);
  if (code == null) return null;

  if (f[0] != 'M' || f.last != 'R') {
    // Progress tick: step is the field after the STATUS label.
    final si = f.lastIndexOf('STATUS');
    final step = si >= 0 && si + 1 < f.length ? int.tryParse(f[si + 1]) : null;
    return HannaProgress(methodCode: code, step: step);
  }

  // Result frame, end-anchored: [-1]=R [-2]=Z [-3]=step [-4]=STATUS
  // [-5]=timestamp [-6]=devid [-7]=locidx [-8]=tank [-9]=range flag.
  final n = f.length;
  if (f[n - 4] != 'STATUS') return null;
  final tankName = f[n - 8];
  final takenAt = _parseHannaTimestamp(f[n - 5]);
  // Value = everything between the unit field (index 2) and the range flag.
  final valueParts = f.sublist(3, n - 9);
  final raw = valueParts.length == 2
      ? '${valueParts[0]}.${valueParts[1]}'
      : valueParts.length == 1
      ? valueParts[0].replaceAll(',', '.')
      : '';
  final value = double.tryParse(raw.trim());
  if (value == null || !value.isFinite) return null;
  return HannaMeasurement(
    methodCode: code,
    value: value,
    tankName: tankName,
    takenAt: takenAt,
  );
}

/// Parses the meter's `YYYYMMDDHHMMSS` wall-clock stamp as local time, or
/// null for `-`/garbage.
DateTime? _parseHannaTimestamp(String raw) {
  final t = raw.trim();
  if (t.length != 14 || int.tryParse(t) == null) return null;
  final dt = DateTime(
    int.parse(t.substring(0, 4)),
    int.parse(t.substring(4, 6)),
    int.parse(t.substring(6, 8)),
    int.parse(t.substring(8, 10)),
    int.parse(t.substring(10, 12)),
    int.parse(t.substring(12, 14)),
  );
  // DateTime rolls out-of-range components over; reject those.
  return dt.month == int.parse(t.substring(4, 6)) &&
          dt.day == int.parse(t.substring(6, 8))
      ? dt
      : null;
}

List<String> _fields(String line) => [
  for (final p in line.trim().split(',')) p.trim(),
];
