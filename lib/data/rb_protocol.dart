// Red Sea ReefBeat local-device REST payloads (pure Dart — no Flutter, no
// dart:io, so the payload parsers are unit-testable in isolation; the HTTP
// transport lives in rb_device_link.dart).
//
// ReefBeat devices (ReefDose dosing pumps, and siblings like ReefATO/ReefMat)
// expose an unauthenticated JSON REST API on the LAN. The two endpoints used
// here:
//
//   GET /device-info   → identity: `hw_type` ("reef-dosing"), `hw_model`
//                        ("RSDOSE4"/"RSDOSE2"), `name`, `hwid` (MAC-derived —
//                        stable across DHCP changes, our device identifier).
//   GET /dashboard     → live status; for a dosing pump: device-level flags
//                        plus a `heads` map ("1".."4") of per-head dosing
//                        state.
//
// The layouts were captured from a live RSDOSE4 (see rb_protocol_test.dart for
// the golden vectors). Parsing is deliberately tolerant — firmware drift should
// degrade a card, not crash a refresh — so every field is nullable or
// defaulted, and only structurally unusable payloads are rejected.

/// `hw_type` of the ReefDose family — the only ReefBeat device type supported
/// so far. Other types (ATO, wave pumps, …) are reported as unsupported.
const String kRbDosingHwType = 'reef-dosing';

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
