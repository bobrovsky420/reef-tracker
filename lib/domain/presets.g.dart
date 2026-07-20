// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: tank_presets.yaml
// Regenerate: dart run tool/gen_tank_presets.dart

part of 'presets.dart';

/// Default boundaries per setup type, generated from
/// `tank_presets.yaml`. The *keys present* in each map are
/// the parameters tracked by default for that setup type;
/// everything else can be added manually later. These are
/// sensible starting points — every bound is editable per
/// tank.
const Map<SetupType, Map<String, ZoneBounds>> kPresets = {
  SetupType.fishOnly: {
    'temperature': ZoneBounds(
      amberLow: 22,
      greenLow: 24,
      greenHigh: 27,
      amberHigh: 29,
    ),
    'ph': ZoneBounds(
      amberLow: 7.6,
      greenLow: 7.8,
      greenHigh: 8.4,
      amberHigh: 8.6,
    ),
    'salinity': ZoneBounds(
      amberLow: 1.018,
      greenLow: 1.02,
      greenHigh: 1.025,
      amberHigh: 1.027,
    ),
    'ammonia': ZoneBounds(greenLow: 0, greenHigh: 0.02, amberHigh: 0.1),
    'nitrite': ZoneBounds(greenLow: 0, greenHigh: 0.1, amberHigh: 0.4),
    'nitrate': ZoneBounds(greenLow: 0, greenHigh: 40, amberHigh: 80),
  },
  SetupType.soft: {
    'temperature': ZoneBounds(
      amberLow: 23,
      greenLow: 24,
      greenHigh: 26,
      amberHigh: 28,
    ),
    'ph': ZoneBounds(
      amberLow: 7.7,
      greenLow: 7.8,
      greenHigh: 8.4,
      amberHigh: 8.6,
    ),
    'salinity': ZoneBounds(
      amberLow: 1.022,
      greenLow: 1.024,
      greenHigh: 1.026,
      amberHigh: 1.028,
    ),
    'alkalinity': ZoneBounds(
      amberLow: 6.5,
      greenLow: 7,
      greenHigh: 10,
      amberHigh: 12,
    ),
    'calcium': ZoneBounds(
      amberLow: 360,
      greenLow: 400,
      greenHigh: 450,
      amberHigh: 500,
    ),
    'magnesium': ZoneBounds(
      amberLow: 1150,
      greenLow: 1250,
      greenHigh: 1400,
      amberHigh: 1500,
    ),
    'nitrate': ZoneBounds(
      amberLow: 0.5,
      greenLow: 2,
      greenHigh: 15,
      amberHigh: 40,
    ),
    'phosphate': ZoneBounds(
      amberLow: 0.0,
      greenLow: 0.02,
      greenHigh: 0.1,
      amberHigh: 0.25,
    ),
    'ammonia': ZoneBounds(greenLow: 0, greenHigh: 0.02, amberHigh: 0.1),
    'nitrite': ZoneBounds(greenLow: 0, greenHigh: 0.05, amberHigh: 0.2),
  },
  SetupType.lps: {
    'temperature': ZoneBounds(
      amberLow: 23,
      greenLow: 24,
      greenHigh: 26,
      amberHigh: 28,
    ),
    'ph': ZoneBounds(
      amberLow: 7.8,
      greenLow: 7.9,
      greenHigh: 8.4,
      amberHigh: 8.6,
    ),
    'salinity': ZoneBounds(
      amberLow: 1.023,
      greenLow: 1.025,
      greenHigh: 1.026,
      amberHigh: 1.027,
    ),
    'alkalinity': ZoneBounds(
      amberLow: 7,
      greenLow: 7.5,
      greenHigh: 9.5,
      amberHigh: 11,
    ),
    'calcium': ZoneBounds(
      amberLow: 380,
      greenLow: 400,
      greenHigh: 450,
      amberHigh: 480,
    ),
    'magnesium': ZoneBounds(
      amberLow: 1200,
      greenLow: 1300,
      greenHigh: 1400,
      amberHigh: 1500,
    ),
    'nitrate': ZoneBounds(
      amberLow: 0.5,
      greenLow: 1,
      greenHigh: 10,
      amberHigh: 25,
    ),
    'phosphate': ZoneBounds(
      amberLow: 0.0,
      greenLow: 0.02,
      greenHigh: 0.08,
      amberHigh: 0.2,
    ),
    'ammonia': ZoneBounds(greenLow: 0, greenHigh: 0.02, amberHigh: 0.1),
    'nitrite': ZoneBounds(greenLow: 0, greenHigh: 0.05, amberHigh: 0.2),
  },
  SetupType.sps: {
    'temperature': ZoneBounds(
      amberLow: 24,
      greenLow: 25,
      greenHigh: 26.5,
      amberHigh: 28,
    ),
    'ph': ZoneBounds(
      amberLow: 7.9,
      greenLow: 8.0,
      greenHigh: 8.4,
      amberHigh: 8.6,
    ),
    'salinity': ZoneBounds(
      amberLow: 1.024,
      greenLow: 1.025,
      greenHigh: 1.026,
      amberHigh: 1.027,
    ),
    'alkalinity': ZoneBounds(
      amberLow: 7,
      greenLow: 7.5,
      greenHigh: 8.5,
      amberHigh: 9.5,
    ),
    'calcium': ZoneBounds(
      amberLow: 400,
      greenLow: 420,
      greenHigh: 440,
      amberHigh: 470,
    ),
    'magnesium': ZoneBounds(
      amberLow: 1250,
      greenLow: 1300,
      greenHigh: 1400,
      amberHigh: 1500,
    ),
    'nitrate': ZoneBounds(
      amberLow: 0.2,
      greenLow: 1,
      greenHigh: 5,
      amberHigh: 15,
    ),
    'phosphate': ZoneBounds(
      amberLow: 0.0,
      greenLow: 0.01,
      greenHigh: 0.05,
      amberHigh: 0.12,
    ),
    'ammonia': ZoneBounds(greenLow: 0, greenHigh: 0.02, amberHigh: 0.1),
    'nitrite': ZoneBounds(greenLow: 0, greenHigh: 0.05, amberHigh: 0.2),
  },
  SetupType.mixed: {
    'temperature': ZoneBounds(
      amberLow: 23,
      greenLow: 24,
      greenHigh: 26,
      amberHigh: 28,
    ),
    'ph': ZoneBounds(
      amberLow: 7.8,
      greenLow: 7.9,
      greenHigh: 8.4,
      amberHigh: 8.6,
    ),
    'salinity': ZoneBounds(
      amberLow: 1.023,
      greenLow: 1.025,
      greenHigh: 1.026,
      amberHigh: 1.027,
    ),
    'alkalinity': ZoneBounds(
      amberLow: 7,
      greenLow: 7.5,
      greenHigh: 9,
      amberHigh: 11,
    ),
    'calcium': ZoneBounds(
      amberLow: 390,
      greenLow: 410,
      greenHigh: 450,
      amberHigh: 480,
    ),
    'magnesium': ZoneBounds(
      amberLow: 1250,
      greenLow: 1300,
      greenHigh: 1400,
      amberHigh: 1500,
    ),
    'nitrate': ZoneBounds(
      amberLow: 0.5,
      greenLow: 2,
      greenHigh: 10,
      amberHigh: 25,
    ),
    'phosphate': ZoneBounds(
      amberLow: 0.0,
      greenLow: 0.02,
      greenHigh: 0.08,
      amberHigh: 0.2,
    ),
    'ammonia': ZoneBounds(greenLow: 0, greenHigh: 0.02, amberHigh: 0.1),
    'nitrite': ZoneBounds(greenLow: 0, greenHigh: 0.05, amberHigh: 0.2),
  },
};

/// Default correction *targets* per setup type, generated
/// from `tank_presets.yaml` (`target` fields) — see
/// [presetTarget] for the fallback rule.
const Map<SetupType, Map<String, double>> kPresetTargets = {
  SetupType.soft: {'alkalinity': 8.5},
  SetupType.lps: {'alkalinity': 8.5},
  SetupType.sps: {'alkalinity': 8.0},
  SetupType.mixed: {'alkalinity': 8.3},
};
