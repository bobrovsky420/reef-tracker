// Red Sea ReefBeat local-device REST payloads (pure Dart — no Flutter, no
// dart:io, so the payload parsers are unit-testable in isolation; the HTTP
// transport lives in rb_device_link.dart).
//
// ReefBeat devices (ReefDose dosing pumps, ReefATO top-off units, ReefMat
// roller filters, ReefRun pump controllers, ReefLED lights and ReefWave pumps)
// expose an unauthenticated JSON REST API on the LAN. The endpoints used here:
//
//   GET /device-info   → identity: `hw_type` ("reef-dosing"/"reef-ato"/
//                        "reef-mat"/"reef-run"/"reef-lights"/"reef-wave"),
//                        `hw_model` ("RSDOSE4"/"RSATO+"/"RSMAT"/"RSRUN"/
//                        "RSLED90"/"RSWAVE25"/…), `name`, `hwid` (MAC-derived
//                        — stable across DHCP changes, our device identifier).
//   GET /dashboard     → live status; for a dosing pump: device-level flags
//                        plus a `heads` map ("1".."4") of per-head dosing
//                        state; for an ATO: water level, pump state, fill and
//                        volume counters, reservoir estimate, leak-sensor and
//                        level-sensor blocks; for a mat: roll level and
//                        remaining length, advance state and fleece-usage
//                        counters; for a ReefRun: a `pump_<n>` block per
//                        connected pump; for a ReefLED: channel intensities,
//                        heatsink temperature, acclimation and moon state.
//   GET /configuration → mat only, and only to refine the model code: the mat
//                        reports a bare "RSMAT" in `/device-info` while its
//                        width (RSMAT250/500/1200) lives here.
//   GET /mode, /wifi   → the ReefWave's *only* live endpoints (see below).
//
// **The ReefWave is deliberately thin.** Its ESP8266 firmware serves no
// `/dashboard` at all (404), and no endpoint exposes pump speed, wave mode or
// schedule — that lives on a separate wave-controller chip with no HTTP
// surface. All the local API offers is the operating mode and the Wi-Fi link,
// so the wave card reports exactly that rather than pretending to more.
//
// The layouts were captured from live hardware — an RSDOSE4, an RSATO+, an
// RSMAT250, an RSRUN, an RSLED90 and two RSWAVE25s (see rb_protocol_test.dart
// for the golden vectors). Parsing is deliberately tolerant — firmware drift
// should degrade a card, not crash a refresh — so every field is nullable or
// defaulted, and only structurally unusable payloads are rejected.

/// `hw_type` of the ReefDose family.
const String kRbDosingHwType = 'reef-dosing';

/// `hw_type` of the ReefATO family.
const String kRbAtoHwType = 'reef-ato';

/// `hw_type` of the ReefMat family.
const String kRbMatHwType = 'reef-mat';

/// `hw_type` of the ReefRun pump-controller family.
const String kRbRunHwType = 'reef-run';

/// `hw_type` of the ReefLED family.
const String kRbLightsHwType = 'reef-lights';

/// `hw_type` of the ReefWave family. Supported, but with a much thinner
/// payload than the rest — see the note at the top of this file.
const String kRbWaveHwType = 'reef-wave';

/// Every `hw_type` this app can read. Anything else is reported as
/// [RbLinkError.unsupportedModel] — and surfaced by LAN discovery as a
/// found-but-unsupported device rather than being hidden.
const Set<String> kRbSupportedHwTypes = {
  kRbDosingHwType,
  kRbAtoHwType,
  kRbMatHwType,
  kRbRunHwType,
  kRbLightsHwType,
  kRbWaveHwType,
};

/// Supplement-stock warning thresholds for [RbStockSeverity], in days of
/// remaining supplement. Below [kRbStockCriticalDays] the stock indicator is
/// critical (red); below [kRbStockCautionDays] it is caution (amber);
/// otherwise healthy (green).
const int kRbStockCautionDays = 14;
const int kRbStockCriticalDays = 7;

/// How urgent a head's remaining-supplement level is (maps onto the theme's
/// healthy / caution / critical status tokens).
enum RbStockSeverity { healthy, caution, critical }

RbStockSeverity rbStockSeverity(int remainingDays) {
  if (remainingDays < kRbStockCriticalDays) return RbStockSeverity.critical;
  if (remainingDays < kRbStockCautionDays) return RbStockSeverity.caution;
  return RbStockSeverity.healthy;
}

/// Friendly product names per `hw_model`, used as the default device name on
/// add (the device's own `name` is a serial-suffixed default like
/// "RSDOSE4-1752835676"). Unknown models fall back to the raw `hw_model`.
const Map<String, String> kRbModelDisplayNames = {
  'RSDOSE2': 'ReefDose 2',
  'RSDOSE4': 'ReefDose 4',
  'RSATO+': 'ReefATO+',
  // Mats report a bare "RSMAT" in `/device-info`; the width comes from
  // `/configuration` (see [RbMatStatus.modelCode]), which is why the sized
  // variants are listed too.
  'RSMAT': 'ReefMat',
  'RSMAT250': 'ReefMat 250',
  'RSMAT500': 'ReefMat 500',
  'RSMAT1200': 'ReefMat 1200',
  'RSRUN': 'ReefRun',
  'RSLED50': 'ReefLED 50',
  'RSLED90': 'ReefLED 90',
  'RSLED115': 'ReefLED 115',
  'RSLED160': 'ReefLED 160',
  'RSWAVE25': 'ReefWave 25',
  'RSWAVE45': 'ReefWave 45',
};

String rbModelDisplayName(String hwModel) =>
    kRbModelDisplayNames[hwModel] ?? hwModel;

double? _asDouble(Object? v) => switch (v) {
  final num n => n.toDouble(),
  _ => null,
};

int? _asInt(Object? v) => switch (v) {
  final int n => n,
  final double n => n.round(),
  _ => null,
};

/// Identity from `GET /device-info`. [hwid] is the stable unique identifier
/// (MAC-derived); [hwType] discriminates the device family.
class RbDeviceInfo {
  const RbDeviceInfo({
    required this.hwType,
    required this.hwModel,
    required this.hwid,
    this.name,
    this.status,
  });

  final String hwType;
  final String hwModel;
  final String hwid;

  /// The device's own name (defaults to `<model>-<serial>`).
  final String? name;

  /// Cloud-pairing status ("unpaired"/"paired") — informational only; the
  /// local API works either way.
  final String? status;

  /// Null when the payload lacks the identity fields (not a ReefBeat device).
  static RbDeviceInfo? fromJson(Map<String, Object?> json) {
    final hwType = json['hw_type'];
    final hwModel = json['hw_model'];
    final hwid = json['hwid'];
    if (hwType is! String || hwModel is! String || hwid is! String) {
      return null;
    }
    return RbDeviceInfo(
      hwType: hwType,
      hwModel: hwModel,
      hwid: hwid,
      name: json['name'] as String?,
      status: json['status'] as String?,
    );
  }
}

/// One dosing head from the `/dashboard` `heads` map.
class RbDoseHead {
  const RbDoseHead({
    required this.number,
    this.supplement,
    this.enabled = true,
    this.autoDosedToday = 0,
    this.manualDosedToday = 0,
    this.dosesToday,
    this.dailyDose,
    this.dailyDoses,
    this.remainingDays,
    this.stockLevel,
    this.recalibrationRequired = false,
    this.missedVolume = 0,
    this.isFoodHead = false,
  });

  /// 1-based head number (the key in the `heads` map).
  final int number;

  /// The supplement name as configured in the ReefBeat app.
  final String? supplement;

  /// `state == "on"`.
  final bool enabled;

  /// Volumes already delivered today (ml), by the schedule and by manual
  /// (app-triggered) dosing respectively.
  final double autoDosedToday;
  final double manualDosedToday;

  /// Number of individual doses delivered today, and scheduled per day.
  final int? dosesToday;
  final int? dailyDoses;

  /// The total scheduled volume for today (ml).
  final double? dailyDose;

  /// Days of supplement left in the container at the current rate.
  final int? remainingDays;

  /// The pump's own coarse stock label ("high"/"low"/…) — kept for display
  /// fallback; the color thresholds use [remainingDays].
  final String? stockLevel;

  final bool recalibrationRequired;

  /// Volume (ml) of missed doses awaiting recovery.
  final double missedVolume;

  final bool isFoodHead;

  /// Everything delivered today (ml) — the gauge's filled portion.
  double get dosedToday => autoDosedToday + manualDosedToday;

  /// Whether the head is effectively switched off. The firmware reports an
  /// off head either as `state != "on"` or as a zero scheduled dose count
  /// (`daily_doses: 0`) with `state` still "on" — treat both the same. An
  /// *absent* `daily_doses` stays tolerant and does not count as off.
  bool get switchedOff => !enabled || dailyDoses == 0;

  static RbDoseHead fromJson(int number, Map<String, Object?> json) {
    final missed = json['missed_dose'];
    return RbDoseHead(
      number: number,
      supplement: json['supplement'] as String?,
      enabled: json['state'] == null || json['state'] == 'on',
      autoDosedToday: _asDouble(json['auto_dosed_today']) ?? 0,
      manualDosedToday: _asDouble(json['manual_dosed_today']) ?? 0,
      dosesToday: _asInt(json['doses_today']),
      dailyDose: _asDouble(json['daily_dose']),
      dailyDoses: _asInt(json['daily_doses']),
      remainingDays: _asInt(json['remaining_days']),
      stockLevel: json['stock_level'] as String?,
      recalibrationRequired: json['recalibration_required'] == true,
      missedVolume: missed is Map<String, Object?>
          ? (_asDouble(missed['missed_volume']) ?? 0)
          : 0,
      isFoodHead: json['is_food_head'] == true,
    );
  }
}

/// The decoded `/dashboard` of a ReefDose pump.
class RbDoseStatus {
  const RbDoseStatus({
    this.batteryLevel,
    this.timeError = false,
    this.heads = const [],
  });

  /// Backup-battery level ("high"/"low"/…). A warning is shown for anything
  /// other than "high"/null.
  final String? batteryLevel;

  /// The device clock is wrong (schedules unreliable until fixed).
  final bool timeError;

  /// Heads sorted by number. Heads whose entry isn't an object are skipped.
  final List<RbDoseHead> heads;

  /// Whether the battery flag warrants a warning chip.
  bool get batteryWarning => batteryLevel != null && batteryLevel != 'high';

  static RbDoseStatus fromJson(Map<String, Object?> json) {
    final headsJson = json['heads'];
    final heads = <RbDoseHead>[];
    if (headsJson is Map<String, Object?>) {
      for (final entry in headsJson.entries) {
        final number = int.tryParse(entry.key);
        final value = entry.value;
        if (number == null || value is! Map<String, Object?>) continue;
        heads.add(RbDoseHead.fromJson(number, value));
      }
      heads.sort((a, b) => a.number.compareTo(b.number));
    }
    return RbDoseStatus(
      batteryLevel: json['battery_level'] as String?,
      timeError: json['time_error'] == true,
      heads: heads,
    );
  }
}

/// Coarse water-level reading of the ATO's sump sensor, derived from the raw
/// firmware string (`"desired_level_2"`, …). [unknown] keeps unrecognized
/// firmware values displayable via [RbAtoStatus.waterLevelRaw].
enum RbAtoWaterLevel { ok, low, high, unknown }

/// The decoded `/dashboard` of a ReefATO. All volumes are millilitres (the
/// unit the firmware reports).
class RbAtoStatus {
  const RbAtoStatus({
    this.waterLevelRaw,
    this.isPumpOn = false,
    this.todayFills,
    this.todayVolumeMl,
    this.dailyVolumeAvgMl,
    this.volumeLeftMl,
    this.daysTillEmpty,
    this.leakAlarm = false,
    this.sensorWarning = false,
    this.temperatureC,
  });

  /// The firmware's water-level string, verbatim (fallback display for
  /// [RbAtoWaterLevel.unknown]).
  final String? waterLevelRaw;

  /// The fill pump is running right now.
  final bool isPumpOn;

  /// Auto-top-off activity today: number of fills and volume delivered (ml).
  final int? todayFills;
  final double? todayVolumeMl;

  /// Rolling average daily consumption (ml/day) — effectively the tank's
  /// evaporation rate.
  final double? dailyVolumeAvgMl;

  /// The device's reservoir estimate: volume remaining (ml) and days until
  /// empty at the average rate.
  final double? volumeLeftMl;
  final int? daysTillEmpty;

  /// The leak sensor reports water where it shouldn't be.
  final bool leakAlarm;

  /// The level sensor is in error or not connected — top-off is unreliable.
  final bool sensorWarning;

  /// The level sensor's built-in temperature probe (°C), when enabled.
  final double? temperatureC;

  RbAtoWaterLevel get waterLevel {
    final raw = waterLevelRaw?.toLowerCase();
    if (raw == null || raw.isEmpty) return RbAtoWaterLevel.unknown;
    if (raw.contains('desired')) return RbAtoWaterLevel.ok;
    if (raw.contains('low')) return RbAtoWaterLevel.low;
    if (raw.contains('high')) return RbAtoWaterLevel.high;
    return RbAtoWaterLevel.unknown;
  }

  static RbAtoStatus fromJson(Map<String, Object?> json) {
    final leak = json['leak_sensor'];
    var leakAlarm = false;
    if (leak is Map<String, Object?>) {
      // Only an active, connected sensor reporting other than "dry" alarms —
      // a disabled or absent sensor stays quiet.
      final status = leak['status'];
      leakAlarm = leak['connected'] == true &&
          leak['enabled'] != false &&
          status is String &&
          status != 'dry';
    }

    final sensor = json['ato_sensor'];
    var sensorWarning = false;
    double? temperatureC;
    if (sensor is Map<String, Object?>) {
      sensorWarning =
          sensor['is_sensor_error'] == true || sensor['connected'] == false;
      // `current_read` is the probe temperature; suppress it when the probe
      // is disabled or reported disconnected.
      final probeStatus = sensor['temperature_probe_status'];
      if (sensor['is_temp_enabled'] != false &&
          (probeStatus is! String || probeStatus == 'connected')) {
        temperatureC = _asDouble(sensor['current_read']);
      }
    }

    return RbAtoStatus(
      waterLevelRaw: json['water_level'] as String?,
      isPumpOn: json['is_pump_on'] == true,
      todayFills: _asInt(json['today_fills']),
      todayVolumeMl: _asDouble(json['today_volume_usage']),
      dailyVolumeAvgMl: _asDouble(json['daily_volume_average']),
      volumeLeftMl: _asDouble(json['volume_left']),
      daysTillEmpty: _asInt(json['days_till_empty']),
      leakAlarm: leakAlarm,
      sensorWarning: sensorWarning,
      temperatureC: temperatureC,
    );
  }
}

/// Coarse state of the mat's fleece roll, derived from the firmware's
/// `roll_level` string ("running_low", …). [unknown] keeps unrecognized values
/// out of the severity colors.
enum RbRollLevel { ok, low, empty, unknown }

/// The decoded `/dashboard` of a ReefMat roller filter. All lengths are
/// centimetres (the unit the firmware reports).
///
/// The mat's operating state (`mode`, schedule settings) and its motor-step
/// counters are deliberately not modelled: the card is about the roll and the
/// few things a keeper can act on.
class RbMatStatus {
  const RbMatStatus({
    this.rollLevelRaw,
    this.daysTillEndOfRoll,
    this.remainingLengthCm,
    this.rollLengthCm,
    this.materialName,
    this.usedTodayCm,
    this.dailyAverageCm,
    this.autoAdvance = true,
    this.isAdvancing = false,
    this.uncleanSensor = false,
    this.rollInstalledAt,
    this.modelCode,
  });

  /// The sized model code ("RSMAT250") from `/configuration`, when that call
  /// succeeded — `/device-info` only ever reports a bare "RSMAT". Null when the
  /// configuration wasn't readable, in which case the generic name stands.
  final String? modelCode;

  /// The firmware's roll-level string, verbatim.
  final String? rollLevelRaw;

  /// The device's own estimate of days until the roll runs out, at the current
  /// rate.
  final int? daysTillEndOfRoll;

  /// Fleece left on the roll (cm), and the roll's nominal total length (cm)
  /// parsed from [materialName] — the gauge's denominator.
  final double? remainingLengthCm;
  final double? rollLengthCm;

  /// The installed roll as the device names it ("32 Meter").
  final String? materialName;

  /// Fleece advanced today (cm) and the rolling daily average (cm/day).
  final double? usedTodayCm;
  final double? dailyAverageCm;

  /// Automatic advancing is enabled (with it off the mat only advances when
  /// told to, so the tank can overflow unattended).
  final bool autoAdvance;

  /// The motor is advancing the fleece right now.
  final bool isAdvancing;

  /// The water-detection sensor is fouled and needs cleaning.
  final bool uncleanSensor;

  /// When the current roll was fitted (the firmware's `setup_date`).
  final DateTime? rollInstalledAt;

  RbRollLevel get rollLevel {
    final raw = rollLevelRaw?.toLowerCase();
    if (raw == null || raw.isEmpty) return RbRollLevel.unknown;
    // Checked before "low" so an "end_of_roll"/"empty" state wins.
    if (raw.contains('empty') || raw.contains('end')) return RbRollLevel.empty;
    if (raw.contains('low')) return RbRollLevel.low;
    if (raw.contains('high') ||
        raw.contains('normal') ||
        raw.contains('full') ||
        raw == 'ok') {
      return RbRollLevel.ok;
    }
    return RbRollLevel.unknown;
  }

  /// Whether the roll is used up — the firmware says so, or it reports nothing
  /// left on it.
  bool get rollSpent =>
      rollLevel == RbRollLevel.empty ||
      (remainingLengthCm != null && remainingLengthCm! <= 0);

  /// How urgent the roll is, on the same scale as supplement stock and the ATO
  /// reservoir. Null when the device reports neither days nor a level we
  /// recognize (nothing to color).
  RbStockSeverity? get rollSeverity {
    if (rollSpent) return RbStockSeverity.critical;
    final days = daysTillEndOfRoll;
    if (days != null) return rbStockSeverity(days);
    return switch (rollLevel) {
      RbRollLevel.low => RbStockSeverity.caution,
      RbRollLevel.ok => RbStockSeverity.healthy,
      RbRollLevel.empty => RbStockSeverity.critical,
      RbRollLevel.unknown => null,
    };
  }

  /// The nominal roll length in centimetres from the material name, which is a
  /// display string rather than a number ("32 Meter" → 3200). Null when it
  /// carries no length (then the card drops the gauge and shows the remaining
  /// length on its own).
  static double? parseRollLengthCm(String? materialName) {
    if (materialName == null) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(materialName);
    if (match == null) return null;
    final metres = double.tryParse(match.group(1)!.replaceFirst(',', '.'));
    if (metres == null || metres <= 0) return null;
    return metres * 100;
  }

  /// [configuration] is the optional `/configuration` payload, read only to
  /// recover the sized [modelCode]; everything else comes from `/dashboard`.
  static RbMatStatus fromJson(
    Map<String, Object?> json, {
    Map<String, Object?>? configuration,
  }) {
    final material = json['material'];
    final materialName =
        material is Map<String, Object?> ? material['name'] as String? : null;
    final installed = json['setup_date'];
    final model = configuration?['model'];

    return RbMatStatus(
      modelCode: model is String && model.isNotEmpty ? model : null,
      rollLevelRaw: json['roll_level'] as String?,
      daysTillEndOfRoll: _asInt(json['days_till_end_of_roll']),
      remainingLengthCm: _asDouble(json['remaining_length']),
      rollLengthCm: parseRollLengthCm(materialName),
      materialName: materialName,
      usedTodayCm: _asDouble(json['today_usage']),
      dailyAverageCm: _asDouble(json['daily_average_usage']),
      // Absent flags stay optimistic — a missing field must not raise a
      // warning chip out of nowhere.
      autoAdvance: json['auto_advance'] != false,
      isAdvancing: json['is_advancing'] == true,
      uncleanSensor: json['unclean_sensor'] == true,
      rollInstalledAt: installed is String
          ? DateTime.tryParse(installed)?.toLocal()
          : null,
    );
  }
}

/// One pump of a ReefRun controller, from a `pump_<n>` block of `/dashboard`.
class RbRunPump {
  const RbRunPump({
    required this.number,
    this.name,
    this.type,
    this.model,
    this.state,
    this.intensity,
    this.pulse,
    this.temperatureC,
    this.missingPump = false,
    this.missingSensor = false,
    this.scheduleEnabled = true,
    this.sensorControlled = false,
  });

  /// 1-based socket number (the `<n>` of the `pump_<n>` key).
  final int number;

  /// The pump's name as set in the ReefBeat app ("Return pump").
  final String? name;

  /// What the pump drives ("return"/"skimmer") and its product code
  /// ("return-6"/"rsk-300").
  final String? type;
  final String? model;

  /// The firmware's state string — "operational" when healthy.
  final String? state;

  /// Current speed and pulse settings, in percent.
  final int? intensity;
  final int? pulse;

  /// Motor temperature (°C).
  final double? temperatureC;

  /// The controller can't see the pump / its paired sensor.
  final bool missingPump;
  final bool missingSensor;

  /// The pump follows a schedule, and is driven by the water-level sensor
  /// (a skimmer paused on sensor trigger).
  final bool scheduleEnabled;
  final bool sensorControlled;

  /// Whether the pump reports a state other than healthy. An *absent* state
  /// stays optimistic rather than raising a warning out of nowhere.
  bool get faulted => state != null && state != 'operational';

  /// Nothing to show a keeper — an empty socket rather than a real pump.
  bool get isEmptySocket =>
      missingPump && intensity == null && (name == null || name!.isEmpty);

  static RbRunPump fromJson(int number, Map<String, Object?> json) => RbRunPump(
    number: number,
    name: json['name'] as String?,
    type: json['type'] as String?,
    model: json['model'] as String?,
    state: json['state'] as String?,
    intensity: _asInt(json['intensity']),
    pulse: _asInt(json['pulse']),
    temperatureC: _asDouble(json['temperature']),
    missingPump: json['missing_pump'] == true,
    missingSensor: json['missing_sensor'] == true,
    scheduleEnabled: json['schedule_enabled'] != false,
    sensorControlled: json['sensor_controlled'] == true,
  );
}

/// The decoded `/dashboard` of a ReefRun DC pump controller: device-level
/// flags plus one entry per connected pump socket.
class RbRunStatus {
  const RbRunStatus({
    this.batteryLevel,
    this.timeError = false,
    this.ecSensorConnected = true,
    this.pumps = const [],
  });

  /// Backup-battery level ("high"/"low"/…), as on the dosing pump.
  final String? batteryLevel;

  /// The device clock is wrong (schedules unreliable until fixed).
  final bool timeError;

  /// The paired water-level (EC) sensor is connected. Only meaningful when a
  /// pump is [RbRunPump.sensorControlled].
  final bool ecSensorConnected;

  /// Pumps sorted by socket number.
  final List<RbRunPump> pumps;

  bool get batteryWarning => batteryLevel != null && batteryLevel != 'high';

  /// A sensor-driven pump has lost its sensor — the reason to show the EC
  /// warning at all (an unpaired sensor on a manual pump is not a fault).
  bool get sensorWarning =>
      !ecSensorConnected && pumps.any((p) => p.sensorControlled);

  static RbRunStatus fromJson(Map<String, Object?> json) {
    final pumps = <RbRunPump>[];
    for (final entry in json.entries) {
      if (!entry.key.startsWith('pump_')) continue;
      final number = int.tryParse(entry.key.substring(5));
      final value = entry.value;
      if (number == null || value is! Map<String, Object?>) continue;
      pumps.add(RbRunPump.fromJson(number, value));
    }
    pumps.sort((a, b) => a.number.compareTo(b.number));
    return RbRunStatus(
      batteryLevel: json['battery_level'] as String?,
      timeError: json['time_error'] == true,
      ecSensorConnected: json['ec_sensor_connected'] != false,
      pumps: pumps,
    );
  }
}

/// The decoded `/dashboard` of a ReefLED light.
///
/// The channel percentages come from the `manual` block, which — despite the
/// name — carries the light's *current* output in every mode (in `auto` it
/// tracks the running program), so it is what a keeper sees on the fixture.
class RbLightStatus {
  const RbLightStatus({
    this.mode,
    this.batteryLevel,
    this.timeError = false,
    this.tiltSwitch = false,
    this.whitePercent,
    this.bluePercent,
    this.moonPercent,
    this.fanPercent,
    this.temperatureC,
    this.programName,
    this.acclimationEnabled = false,
    this.acclimationRemainingDays,
    this.acclimationFactor,
    this.moonPhaseEnabled = false,
    this.moonPhaseName,
    this.moonDay,
  });

  /// Operating mode ("auto"/"manual"/…).
  final String? mode;

  final String? batteryLevel;
  final bool timeError;

  /// The fixture's tilt switch has tripped — it has been knocked or hung
  /// wrong, and the firmware cuts output when it does.
  final bool tiltSwitch;

  /// Current channel output, in percent.
  final int? whitePercent;
  final int? bluePercent;
  final int? moonPercent;

  /// Cooling-fan duty, in percent.
  final int? fanPercent;

  /// Heatsink temperature (°C) — an LED fixture runs far hotter than the
  /// water, so this is deliberately not compared against tank thresholds.
  final double? temperatureC;

  /// The running program, with the app's epoch suffix stripped.
  final String? programName;

  /// Acclimation ramps output up over [acclimationRemainingDays] more days;
  /// [acclimationFactor] is today's percentage of the program's intensity.
  final bool acclimationEnabled;
  final int? acclimationRemainingDays;
  final int? acclimationFactor;

  /// Lunar-cycle simulation, and where in the cycle it is.
  final bool moonPhaseEnabled;
  final String? moonPhaseName;
  final int? moonDay;

  bool get batteryWarning => batteryLevel != null && batteryLevel != 'high';

  /// The ReefBeat app suffixes program names with the epoch-ms of their
  /// creation ("Winter Time-1769330261387"). Strip it for display, but only
  /// when it is unmistakably a timestamp — a program legitimately named
  /// "Blue-2" must survive.
  static String? cleanProgramName(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.replaceFirst(RegExp(r'-\d{12,}$'), '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static RbLightStatus fromJson(Map<String, Object?> json) {
    final manual = json['manual'];
    final acclimation = json['acclimation'];
    final moon = json['moon_phase'];
    final program = json['current_program'];

    int? channel(String key) => manual is Map<String, Object?>
        ? _asInt(manual[key])
        : null;

    return RbLightStatus(
      mode: json['mode'] as String?,
      batteryLevel: json['battery_level'] as String?,
      timeError: json['time_error'] == true,
      tiltSwitch: json['tilt_switch'] == true,
      whitePercent: channel('white'),
      bluePercent: channel('blue'),
      moonPercent: channel('moon'),
      fanPercent: channel('fan'),
      temperatureC: manual is Map<String, Object?>
          ? _asDouble(manual['temperature'])
          : null,
      programName: program is Map<String, Object?>
          ? cleanProgramName(program['name'] as String?)
          : null,
      acclimationEnabled:
          acclimation is Map<String, Object?> && acclimation['enabled'] == true,
      acclimationRemainingDays: acclimation is Map<String, Object?>
          ? _asInt(acclimation['remaining_days'])
          : null,
      acclimationFactor: acclimation is Map<String, Object?>
          ? _asInt(acclimation['current_intensity_factor'])
          : null,
      moonPhaseEnabled: moon is Map<String, Object?> && moon['enabled'] == true,
      moonPhaseName: moon is Map<String, Object?>
          ? moon['name'] as String?
          : null,
      moonDay: moon is Map<String, Object?>
          ? _asInt(moon['todays_moon_day'])
          : null,
    );
  }
}

/// Coarse Wi-Fi link quality derived from RSSI, for the wave card's signal row.
enum RbWifiQuality { good, fair, weak, unknown }

/// The ReefWave's live state — everything its firmware exposes, which is the
/// operating mode (`GET /mode`) and the Wi-Fi link (`GET /wifi`).
///
/// There is deliberately no pump speed, wave pattern or schedule here: the
/// ReefWave serves no `/dashboard`, and its wave controller is a second chip
/// with no HTTP surface. See the note at the top of this file.
class RbWaveStatus {
  const RbWaveStatus({
    this.mode,
    this.wifiConnected,
    this.ssid,
    this.signalDbm,
  });

  /// Operating mode ("auto"/"manual"/…).
  final String? mode;

  /// Wi-Fi association state and network, when `/wifi` was readable.
  final bool? wifiConnected;
  final String? ssid;

  /// RSSI in dBm (negative; closer to zero is stronger).
  final int? signalDbm;

  /// Buckets chosen for reef use: a pump in a sump behind glass and water is
  /// the classic weak-signal case, so anything past −75 dBm reads as weak.
  RbWifiQuality get wifiQuality {
    final dbm = signalDbm;
    if (dbm == null) return RbWifiQuality.unknown;
    if (dbm >= -60) return RbWifiQuality.good;
    if (dbm >= -75) return RbWifiQuality.fair;
    return RbWifiQuality.weak;
  }

  /// [wifi] is the optional `/wifi` payload; [mode] the `/mode` one.
  static RbWaveStatus fromJson(
    Map<String, Object?> mode, {
    Map<String, Object?>? wifi,
  }) => RbWaveStatus(
    mode: mode['mode'] as String?,
    wifiConnected: wifi == null ? null : wifi['connected'] == true,
    ssid: wifi?['ssid'] as String?,
    signalDbm: wifi == null ? null : _asInt(wifi['signal_dBm']),
  );
}
