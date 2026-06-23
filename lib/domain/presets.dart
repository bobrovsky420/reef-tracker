import 'setup_type.dart';
import 'zones.dart';

/// Shorthand for building [ZoneBounds] from an amber-low / green-low /
/// green-high / amber-high tuple. `null` outer bounds mean "never red on that
/// side".
ZoneBounds _b(double? amberLow, double greenLow, double greenHigh,
        double? amberHigh) =>
    ZoneBounds(
      amberLow: amberLow,
      greenLow: greenLow,
      greenHigh: greenHigh,
      amberHigh: amberHigh,
    );

/// Default boundaries per setup type. The *keys present* in each map are the
/// parameters tracked by default for that setup type; everything else can be
/// added manually later. These are sensible starting points — every bound is
/// editable per tank.
final Map<SetupType, Map<String, ZoneBounds>> kPresets = {
  SetupType.fishOnly: {
    'temperature': _b(22, 24, 27, 29),
    'ph': _b(7.6, 7.8, 8.4, 8.6),
    'salinity': _b(1.018, 1.020, 1.025, 1.027),
    'ammonia': _b(null, 0, 0.02, 0.1),
    'nitrite': _b(null, 0, 0.1, 0.4),
    'nitrate': _b(null, 0, 40, 80),
  },
  SetupType.soft: {
    'temperature': _b(23, 24, 26, 28),
    'ph': _b(7.7, 7.8, 8.4, 8.6),
    'salinity': _b(1.022, 1.024, 1.026, 1.028),
    'alkalinity': _b(6.5, 7, 10, 12),
    'calcium': _b(360, 400, 450, 500),
    'magnesium': _b(1150, 1250, 1400, 1500),
    'nitrate': _b(0.5, 2, 15, 40),
    'phosphate': _b(0.0, 0.02, 0.10, 0.25),
    'ammonia': _b(null, 0, 0.02, 0.1),
    'nitrite': _b(null, 0, 0.05, 0.2),
  },
  SetupType.lps: {
    'temperature': _b(23, 24, 26, 28),
    'ph': _b(7.8, 7.9, 8.4, 8.6),
    'salinity': _b(1.023, 1.025, 1.026, 1.027),
    'alkalinity': _b(7, 7.5, 9.5, 11),
    'calcium': _b(380, 400, 450, 480),
    'magnesium': _b(1200, 1300, 1400, 1500),
    'nitrate': _b(0.5, 1, 10, 25),
    'phosphate': _b(0.0, 0.02, 0.08, 0.2),
    'ammonia': _b(null, 0, 0.02, 0.1),
    'nitrite': _b(null, 0, 0.05, 0.2),
  },
  SetupType.sps: {
    'temperature': _b(24, 25, 26.5, 28),
    'ph': _b(7.9, 8.0, 8.4, 8.6),
    'salinity': _b(1.024, 1.025, 1.026, 1.027),
    'alkalinity': _b(7, 7.5, 8.5, 9.5),
    'calcium': _b(400, 420, 440, 470),
    'magnesium': _b(1250, 1300, 1400, 1500),
    'nitrate': _b(0.2, 1, 5, 15),
    'phosphate': _b(0.0, 0.01, 0.05, 0.12),
    'ammonia': _b(null, 0, 0.02, 0.1),
    'nitrite': _b(null, 0, 0.05, 0.2),
  },
  SetupType.mixed: {
    'temperature': _b(23, 24, 26, 28),
    'ph': _b(7.8, 7.9, 8.4, 8.6),
    'salinity': _b(1.023, 1.025, 1.026, 1.027),
    'alkalinity': _b(7, 7.5, 9, 11),
    'calcium': _b(390, 410, 450, 480),
    'magnesium': _b(1250, 1300, 1400, 1500),
    'nitrate': _b(0.5, 2, 10, 25),
    'phosphate': _b(0.0, 0.02, 0.08, 0.2),
    'ammonia': _b(null, 0, 0.02, 0.1),
    'nitrite': _b(null, 0, 0.05, 0.2),
  },
};

/// The default zone boundaries for a given setup type + parameter, or an empty
/// [ZoneBounds] if the preset does not define that parameter.
ZoneBounds presetBounds(SetupType type, String paramKey) =>
    kPresets[type]?[paramKey] ?? const ZoneBounds();

/// The parameter keys tracked by default for a setup type, in catalog order.
List<String> defaultTrackedKeys(SetupType type) =>
    (kPresets[type] ?? const {}).keys.toList();
