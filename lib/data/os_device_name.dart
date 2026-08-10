import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Best-effort human-friendly name of this device as the OS reports it —
/// the *prefill* for the U35 device-name dialog, never a silent default:
/// the user always sees and can correct it before anything is saved.
///
/// Returns null when the platform has nothing usable (or the plugin call
/// fails/times out — e.g. under `flutter test` there is no platform channel),
/// in which case the dialog simply opens empty as before.
Future<String?> osDeviceName({
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    return await _query().timeout(timeout);
  } catch (_) {
    return null;
  }
}

Future<String?> _query() async {
  final plugin = DeviceInfoPlugin();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final info = await plugin.androidInfo;
      return friendlyAndroidDeviceName(
        name: info.name,
        manufacturer: info.manufacturer,
        model: info.model,
      );
    case TargetPlatform.iOS:
      final info = await plugin.iosInfo;
      return friendlyIosDeviceName(
        name: info.name,
        model: info.model,
        modelName: info.modelName,
      );
    default:
      return null;
  }
}

/// Pure combining logic, separated from the plugin call so it is testable
/// under `flutter test`.
///
/// Prefers the user-assigned device name (Settings.Global.DEVICE_NAME — what
/// Android shows in Settings → About phone; "Pixel 7" or "Alex's phone");
/// falls back to manufacturer + model (deduplicated: Samsung models don't
/// repeat "samsung", but `Build.MODEL` alone is "SM-S918B"-cryptic without
/// the brand).
String? friendlyAndroidDeviceName({
  required String name,
  required String manufacturer,
  required String model,
}) {
  final assigned = name.trim();
  if (assigned.isNotEmpty) return _clip(assigned);
  final mod = model.trim();
  final man = manufacturer.trim();
  // "unknown" is Build.MANUFACTURER's literal placeholder on some devices.
  if (man.isEmpty || man.toLowerCase() == 'unknown') {
    return mod.isEmpty ? null : _clip(mod);
  }
  if (mod.isEmpty) return _clip(_capitalized(man));
  if (mod.toLowerCase().startsWith(man.toLowerCase())) return _clip(mod);
  return _clip('${_capitalized(man)} $mod');
}

/// iOS: `name` is the user's own device name on installs entitled to read it
/// (and on iOS < 16), but the entitlement-less generic form is just the
/// device class — identical to `model` ("iPhone") — where the commercial
/// `modelName` ("iPhone 16 Pro") says strictly more.
String? friendlyIosDeviceName({
  required String name,
  required String model,
  required String modelName,
}) {
  final assigned = name.trim();
  if (assigned.isNotEmpty && assigned != model.trim()) return _clip(assigned);
  final marketing = modelName.trim();
  if (marketing.isNotEmpty) return _clip(marketing);
  return assigned.isEmpty ? null : _clip(assigned);
}

/// Build.MANUFACTURER is frequently all-lowercase ("samsung", "xiaomi");
/// capitalize those, but leave mixed-case brands ("OnePlus") untouched.
String _capitalized(String s) =>
    s == s.toLowerCase() ? s[0].toUpperCase() + s.substring(1) : s;

/// The dialog's TextField caps input at 40 characters — hand it a prefill
/// that already fits.
String _clip(String s) => s.length <= 40 ? s : s.substring(0, 40).trimRight();
