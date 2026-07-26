// Neptune Systems Apex local wire protocol (pure Dart — no Flutter, no
// dart:io, so every parser here is unit-testable in isolation).
//
// ## The two firmware families
//
// An Apex on the LAN serves one of two shapes, and which one it is has to be
// discovered rather than configured:
//
//   * **AOS 5.x** (Apex 2016 / A3 / EL on current firmware) — a session API.
//     `POST /rest/login` with `{login, password, remember_me:false}` answers a
//     `connect.sid`, and `GET /rest/status` (carrying that cookie) returns
//     `{system, inputs, outputs, feed}`.
//   * **Classic / Jr / older AOS 4.x** — no `/rest` at all (the login POST
//     404s). `GET /cgi-bin/status.json` behind HTTP Basic auth returns the same
//     information wrapped in a single `istat` key.
//
// Both shapes decode into one [ApStatus] here, so nothing above this file has
// to care which answered. Neither is documented by Neptune: the layouts below
// follow the long-standing community integrations (Home Assistant's `apex-ha`,
// Telegraf's `neptune_apex` input) and are pinned by golden vectors in
// ap_protocol_test.dart. Parsing is deliberately tolerant throughout — a field
// that moved or vanished must degrade the card, never throw away a refresh.
//
// ## What is read, and what is deliberately not
//
// Probes whose type maps to a tracked water parameter (`Temp`, `pH`, `ORP`,
// `Cond`, and a Trident's `alk`/`ca`/`mg`) become [ApReading]s the dashboard
// can save. The rest of an Apex's inputs — amps, watts, volts, optical/leak
// digitals, tank-level inches — are parsed into [ApStatus.probes] but produce
// no reading: they are power and plumbing telemetry, not water chemistry, and
// the app has nowhere truthful to store them.
//
// Outlets are read-only status. The app never switches an outlet, runs a feed
// cycle or edits a program — that stays in Fusion / the Apex UI.

/// Which API family a controller answered on. Also the only honest "model"
/// this integration can report: an Apex does not publish a product name, so
/// what we know is which firmware generation is talking.
enum ApFirmware {
  /// AOS 5.x `/rest/*` with a session cookie.
  aos5,

  /// `/cgi-bin/status.json` behind Basic auth (Classic, Jr, older AOS).
  classic,
}

/// The unit an Apex reports a temperature probe in. The controller is set to
/// one or the other globally and `status` never states which — see
/// [apTempUnitFromConfig] and [ApProbe.celsius] for how it is resolved.
enum ApTempUnit { celsius, fahrenheit }

/// Identity of one controller.
class ApDeviceInfo {
  const ApDeviceInfo({
    required this.serial,
    required this.hostname,
    required this.software,
    required this.hardware,
    required this.firmware,
  });

  /// e.g. `AC5:12345`. Globally unique and stable across DHCP changes, so it
  /// is the `Devices.identifier`.
  final String serial;

  /// The controller's own name (`apex`).
  final String hostname;

  /// Firmware build string (`5.04_7A18`).
  final String software;

  /// Hardware revision string (`1.0`).
  final String hardware;

  final ApFirmware firmware;

  /// The model code stored on the device row: the serial's prefix (`AC5`),
  /// which is as close to a model as an Apex reports. Falls back to the whole
  /// serial when it carries no `:`.
  String get modelCode {
    final i = serial.indexOf(':');
    return i > 0 ? serial.substring(0, i) : serial;
  }

  /// The default device name on add. Deliberately *not* a guessed product name
  /// ("Apex 2016", "Apex EL"): the wire tells us which API answered and
  /// nothing more, so that is all this claims.
  String get displayName =>
      firmware == ApFirmware.classic ? 'Apex Classic' : 'Apex';
}

/// One value read from a probe, keyed by the app's parameter-catalog key.
/// [unit] is the unit [value] is already expressed in — the catalog's
/// canonical unit, except salinity, which arrives as ppt and is converted to
/// specific gravity by the save path (exactly as the ReefFactory Salinity
/// Guardian's is).
class ApReading {
  const ApReading(this.paramKey, this.value, this.unit);

  final String paramKey;
  final double value;
  final String unit;
}

/// A raw input as the controller reports it.
class ApProbe {
  const ApProbe({
    required this.did,
    required this.name,
    required this.type,
    required this.value,
  });

  /// Device id (`base_Temp`) — stable across renames, unlike [name].
  final String did;

  /// The keeper's label for the probe (`Tmp`, `Salt`).
  final String name;

  /// Apex probe type (`Temp`, `pH`, `ORP`, `Cond`, `alk`, `Amps`, `digital`…).
  /// Empty when the controller omits it (older `status.json` does for derived
  /// inputs).
  final String type;

  /// Null when the controller reported no numeric value — a probe that is
  /// unplugged, or a string state we can't read as a number.
  final double? value;

  /// [value] in °C, given the controller's configured [unit]. Rounded to the
  /// one decimal an Apex actually displays, so a °F conversion doesn't grow a
  /// long binary tail.
  double? celsius(ApTempUnit unit) {
    final v = value;
    if (v == null) return null;
    if (unit == ApTempUnit.celsius) return v;
    return (((v - 32) * 5 / 9) * 10).round() / 10;
  }
}

/// What an outlet is doing. The Apex convention — visible in every Apex UI —
/// is that a leading `A` means "the program decided this": `AON`/`AOF` are
/// program-driven on/off, bare `ON`/`OFF` are a human override that will stay
/// until cleared. Anything else (`TBL`, `PF1`…) is a profile driving a
/// variable output, where "on or off" is not a question with an answer.
class ApOutlet {
  const ApOutlet({
    required this.did,
    required this.name,
    required this.type,
    required this.state,
  });

  final String did;
  final String name;

  /// `outlet`, `dos`, `variable`, `virtual`, `vortech`, `alert`, `24v`, …
  final String type;

  /// The raw state string, kept verbatim — it is what an Apex owner reads in
  /// Fusion, so an unrecognised one is shown rather than swallowed.
  final String state;

  /// True/false for the four states that mean on or off; null for a profile
  /// (`TBL`, `PF1`) or anything unrecognised.
  bool? get on => switch (state.toUpperCase()) {
    'AON' || 'ON' => true,
    'AOF' || 'OFF' => false,
    _ => null,
  };

  /// Whether a human has overridden the program (`ON`/`OFF` without the `A`).
  /// This is the one outlet fact worth surfacing on a dashboard: an override
  /// left on is how a return pump stays off after a water change.
  bool get overridden {
    final s = state.toUpperCase();
    return s == 'ON' || s == 'OFF';
  }

  /// Outlets that exist in the data but are not a switched load: the email
  /// alarm, the virtual "control" outputs. They are kept out of the card's
  /// outlet list, which is about what is powered.
  bool get isAlarmOrVirtual => type == 'alert' || type == 'virtual';
}

/// A running feed cycle (the Apex's "pause the pumps while I feed" timer).
class ApFeed {
  const ApFeed({required this.name, required this.secondsLeft});

  /// Which cycle (1–4 = A–D). 0 or 6 mean "none" depending on firmware, so
  /// [running] rather than this is what callers should test.
  final int name;

  /// Seconds remaining. Both firmwares park an *idle* timer at a large
  /// sentinel (AOS 5 uses values above 50000; Classic reports `name: 6`), so a
  /// plausibility bound is part of deciding whether one is actually running.
  final int secondsLeft;

  /// A cycle is running only when a real cycle is selected *and* the remaining
  /// time is inside the range a feed timer can hold. Written as one rule
  /// covering both firmwares rather than branching on the family — the
  /// sentinels don't overlap with real values.
  bool get running =>
      name >= 1 && name <= 4 && secondsLeft > 0 && secondsLeft < 50000;

  /// The cycle letter (`A`–`D`), or null when none is running.
  String? get letter =>
      running ? String.fromCharCode('A'.codeUnitAt(0) + name - 1) : null;
}

/// Apex probe type → the app's parameter-catalog key. Types absent here are
/// still parsed into [ApStatus.probes]; they simply have nowhere to be saved.
/// The Trident's three tests (`alk`/`ca`/`mg`) ride the same input list as the
/// analog probes, which is why a Trident needs no separate integration.
const Map<String, String> kApProbeParams = {
  'Temp': 'temperature',
  'pH': 'ph',
  'ORP': 'orp',
  // Conductivity probe, reported in ppt (the Apex's salinity display unit).
  'Cond': 'salinity',
  'alk': 'alkalinity',
  'ca': 'calcium',
  'mg': 'magnesium',
};

/// The unit each mapped parameter arrives in on the wire. Temperature is
/// resolved separately (the controller is globally °C or °F) and salinity is
/// converted to SG by the save path, as the catalog stores it.
const Map<String, String> _paramWireUnits = {
  'temperature': '°C',
  'ph': 'pH',
  'orp': 'mV',
  'salinity': 'ppt',
  'alkalinity': 'dKH',
  'calcium': 'ppm',
  'magnesium': 'ppm',
};

/// One decoded read of a controller.
class ApStatus {
  const ApStatus({
    required this.info,
    required this.probes,
    required this.outlets,
    this.feed,
    this.tempUnit = ApTempUnit.celsius,
  });

  final ApDeviceInfo info;
  final List<ApProbe> probes;
  final List<ApOutlet> outlets;
  final ApFeed? feed;

  /// The unit [probes] of type `Temp` are expressed in. Resolved from
  /// `/rest/config` when the controller serves it, else inferred — see
  /// [apTempUnitFromConfig] and [apInferTempUnit].
  final ApTempUnit tempUnit;

  /// The savable water parameters from [probes], in catalog units except
  /// salinity (ppt — see [ApReading]). A probe with no numeric value, or of a
  /// type that maps to nothing, contributes nothing.
  ///
  /// **First probe of a type wins.** A tank commonly carries two temperature
  /// probes (display and sump); saving both would write one parameter twice in
  /// the same group, and the app has no way to know which is the display tank.
  /// The keeper controls the choice by ordering probes in the Apex itself.
  List<ApReading> get readings {
    final out = <ApReading>[];
    final seen = <String>{};
    for (final p in probes) {
      final key = kApProbeParams[p.type];
      if (key == null || !seen.add(key)) continue;
      final value = key == 'temperature' ? p.celsius(tempUnit) : p.value;
      if (value == null) {
        seen.remove(key);
        continue;
      }
      out.add(ApReading(key, value, _paramWireUnits[key] ?? ''));
    }
    return out;
  }

  /// The outlets worth listing on a card: real loads, not the alarm and
  /// virtual control outputs.
  List<ApOutlet> get switchedOutlets => [
    for (final o in outlets)
      if (!o.isAlarmOrVirtual) o,
  ];

  /// Outlets a human has overridden away from their program. Surfaced as a
  /// warning chip — this is the state that silently costs people corals.
  List<ApOutlet> get overriddenOutlets => [
    for (final o in switchedOutlets)
      if (o.overridden) o,
  ];

  /// Decodes an AOS 5.x `GET /rest/status` body.
  static ApStatus fromRestJson(
    Map<String, Object?> json, {
    ApTempUnit? tempUnit,
  }) {
    final system = _map(json['system']);
    final probes = _probesFrom(json['inputs']);
    return ApStatus(
      info: ApDeviceInfo(
        serial: _str(system['serial']),
        hostname: _str(system['hostname']),
        software: _str(system['software']),
        hardware: _str(system['hardware']),
        firmware: ApFirmware.aos5,
      ),
      probes: probes,
      outlets: _outletsFrom(json['outputs']),
      feed: _feedFrom(json['feed']),
      tempUnit: tempUnit ?? apInferTempUnit(probes),
    );
  }

  /// Decodes a Classic `GET /cgi-bin/status.json` body — the same information
  /// one level down, under `istat`, with identity fields at that level rather
  /// than in a `system` object.
  static ApStatus fromLegacyJson(
    Map<String, Object?> json, {
    ApTempUnit? tempUnit,
  }) {
    // Tolerant of both the wrapped and unwrapped shapes: some firmware builds
    // (and every proxy that unwraps it) serve the inner object directly.
    final istat = json['istat'] is Map ? _map(json['istat']) : json;
    final probes = _probesFrom(istat['inputs']);
    return ApStatus(
      info: ApDeviceInfo(
        serial: _str(istat['serial']),
        hostname: _str(istat['hostname']),
        software: _str(istat['software']),
        hardware: _str(istat['hardware']),
        firmware: ApFirmware.classic,
      ),
      probes: probes,
      outlets: _outletsFrom(istat['outputs']),
      feed: _feedFrom(istat['feed']),
      tempUnit: tempUnit ?? apInferTempUnit(probes),
    );
  }

  static List<ApProbe> _probesFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          ApProbe(
            did: _str(e['did']),
            name: _str(e['name']),
            type: _str(e['type']),
            value: _num(e['value']),
          ),
    ];
  }

  static List<ApOutlet> _outletsFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          ApOutlet(
            did: _str(e['did']),
            name: _str(e['name']),
            type: _str(e['type']),
            // `status` is a 4-slot array whose first element is the state;
            // firmware that reports a bare string is accepted too.
            state: switch (e['status']) {
              final List<Object?> s when s.isNotEmpty => _str(s.first),
              final String s => s,
              _ => '',
            },
          ),
    ];
  }

  static ApFeed? _feedFrom(Object? raw) {
    if (raw is! Map) return null;
    final name = _num(raw['name'])?.round();
    final active = _num(raw['active'])?.round();
    if (name == null || active == null) return null;
    return ApFeed(name: name, secondsLeft: active);
  }
}

/// The controller's temperature unit as stated by `GET /rest/config`, or null
/// when the call didn't answer or says nothing about it.
///
/// The unit lives on the *probe's* config entry (`iconf[].extra.range`), which
/// is the only authoritative statement of it anywhere in the API — `status`
/// reports a bare number. Only AOS 5.x serves `/rest/config`; Classic falls
/// back to [apInferTempUnit].
ApTempUnit? apTempUnitFromConfig(Map<String, Object?>? config) {
  if (config == null) return null;
  final iconf = config['iconf'];
  if (iconf is! List) return null;
  for (final entry in iconf) {
    if (entry is! Map) continue;
    final extra = entry['extra'];
    if (extra is! Map) continue;
    // Neptune's own spelling — "Celcius" — is the wire value, not a typo here.
    final range = _str(extra['range']).toLowerCase();
    if (range.startsWith('celcius') || range.startsWith('celsius')) {
      return ApTempUnit.celsius;
    }
    if (range.startsWith('faren') || range.startsWith('fahren')) {
      return ApTempUnit.fahrenheit;
    }
  }
  return null;
}

/// Infers the temperature unit from the reading itself, for controllers that
/// won't state it (Classic firmware serves no `/rest/config`).
///
/// This is a range test, not a guess: an aquarium sits at 18–32 °C, which is
/// 64–90 °F, and the two intervals do not overlap. Anything above 45 is a
/// Fahrenheit number — no water an Apex is plumbed into is 45 °C — and
/// anything below it is Celsius. With no temperature probe at all the answer
/// doesn't matter, and Celsius (the catalog's unit) is the identity choice.
ApTempUnit apInferTempUnit(List<ApProbe> probes) {
  for (final p in probes) {
    if (p.type != 'Temp') continue;
    final v = p.value;
    if (v == null) continue;
    return v > 45 ? ApTempUnit.fahrenheit : ApTempUnit.celsius;
  }
  return ApTempUnit.celsius;
}

Map<String, Object?> _map(Object? v) =>
    v is Map ? v.cast<String, Object?>() : const {};

String _str(Object? v) => v is String ? v.trim() : (v?.toString().trim() ?? '');

/// Reads a number the controller may have sent as a JSON number *or* as a
/// padded string (`"30.1 "`, `"  35 "` — the legacy shapes both do this).
double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
