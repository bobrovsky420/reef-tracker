/// Pure, testable free (un-ionized) ammonia toxicity math — no Flutter and no
/// DB dependency. Like `ratio.dart`, it consumes plain timestamped records
/// ([AmmoniaInput]) mapped from `Reading` rows at the data boundary, so it can
/// be unit-tested in isolation.
///
/// ## The chemistry
///
/// A total-ammonia test measures **TAN** (total ammonia nitrogen): the sum of
/// harmless ammonium (NH₄⁺) and toxic free/un-ionized ammonia (NH₃), which sit
/// in the acid-base equilibrium
///
///     NH₄⁺ ⇌ NH₃ + H⁺
///
/// Only the **NH₃** form is toxic. Its share of the total climbs steeply with
/// pH and temperature, which is why a reef (pH ≈ 8.0–8.4) turns far more of the
/// same total ammonia into the toxic form than a pH-7 freshwater tank does.
///
/// Fraction of TAN present as free NH₃:
///
///     f = 1 / (1 + 10^(pKa − pH))
///
/// **pKa temperature dependence** — Emerson et al. (1975), "Aqueous ammonia
/// equilibrium calculations: effect of pH and temperature", J. Fish. Res.
/// Board Can. 32:2379–2383 (fitted to the Bates & Pinching 1949
/// infinite-dilution data). T in kelvin:
///
///     pKa₀ = 0.09018 + 2729.92 / T
///
/// **Salinity correction** — seawater modestly *lowers* the free fraction
/// versus freshwater at the same pH. Per the US EPA (1989) saltwater ammonia
/// criteria (after Whitfield 1974 / Bower & Bidwell 1978), salinity is the
/// least influential of the three factors and is inversely correlated with the
/// un-ionized fraction. Ionic strength from salinity (EPA 1989 Eq. 5, S in
/// g/kg ≈ ppt):
///
///     I = 19.9273·S / (1000 − 1.005109·S)
///
/// The dominant residual effect is the salting-out of neutral NH₃ — the NH₄⁺
/// and H⁺ ionic-strength effects nearly cancel, both being singly charged on
/// opposite sides of the equilibrium — so the apparent pKa rises slightly with
/// I:
///
///     pKa = pKa₀ + k·I
///
/// This reproduces ≈9–10 % NH₃ at pH 8.3 / 25 °C / 35 ppt and the ≈13 % rise at
/// 27 °C reported in the reef-chemistry literature, while sitting ≈1 pp below
/// the freshwater fraction. The salinity term is minor (< ~10 % relative) and
/// dwarfed by hobby pH-kit uncertainty (±0.1 pH ≈ ±25 % on the fraction), so
/// its exact coefficient barely moves the result.
///
/// pH is assumed to be on the NBS scale, i.e. what a hobby meter/kit calibrated
/// with standard buffers reads (EPA 1989 notes the NBS↔free-H seawater scale
/// difference is ≤ 0.02 pH at 30 g/kg — negligible here).
library;

import 'dart:math' as math;

import 'units.dart';
import 'zones.dart';

/// Stable parameter keys the free-ammonia calculation reads.
const String kAmmoniaKey = 'ammonia';
const String kPhKey = 'ph';
const String kTemperatureKey = 'temperature';
const String kSalinityKey = 'salinity';

/// A timestamped parameter value used by the free-ammonia math. A plain record
/// so the domain stays decoupled from the DB's `Reading` row.
typedef AmmoniaInput = ({DateTime takenAt, double value});

// --- Model constants ---------------------------------------------------------

const double _pkaTempA = 0.09018;
const double _pkaTempB = 2729.92;
const double _zeroCelsiusK = 273.15;

/// NH₃ salting-out (Setschenow-style) coefficient, kg/mol — the one empirical
/// constant of the marine correction. See the library doc: the effect is minor
/// and swamped by pH-measurement uncertainty.
const double _nh3SaltingOut = 0.049;

/// Reference salinity (ppt) used when a tank has no salinity reading. Reef
/// water is held near 35 ppt, so this is a safe stand-in; the result flags
/// whether it was actually measured ([FreeAmmonia.salinityMeasured]).
const double kDefaultSalinityPpt = 35.0;

/// Toxicity zone bounds for free NH₃, in **ppm NH₃** (one-sided — there is no
/// "too little" toxic ammonia). Green up to [kFreeAmmoniaGreenHigh] ppm, amber
/// up to [kFreeAmmoniaAmberHigh] ppm, red beyond. Anchored on the US EPA (1989)
/// saltwater four-day chronic criterion of 0.035 mg NH₃/L, kept conservative
/// for sensitive reef invertebrates and corals.
const double kFreeAmmoniaGreenHigh = 0.02;
const double kFreeAmmoniaAmberHigh = 0.05;

/// The fixed default zone bounds for the free-ammonia gauge/card.
const ZoneBounds kFreeAmmoniaBounds = ZoneBounds(
  greenHigh: kFreeAmmoniaGreenHigh,
  amberHigh: kFreeAmmoniaAmberHigh,
);

/// The gauge axis for the free-ammonia horizontal track / card: a toxic scale
/// that starts at 0 (perfectly safe) and extends just past the red threshold.
const GaugeAxis kFreeAmmoniaAxis = (min: 0.0, max: kFreeAmmoniaAmberHigh * 1.2);

/// Maximum age gap between the total-ammonia reading and the pH / temperature
/// readings used to interpret it. Beyond this the pH/temp inputs are treated as
/// too outdated for a confident toxicity estimate — the value still shows, but
/// flagged approximate ([FreeAmmonia.inputsOutdated]). Tighter than the 30-day
/// ratio skew because pH swings on a daily cycle and temperature drifts.
const Duration kAmmoniaInputMaxAge = Duration(days: 7);

// --- Formula -----------------------------------------------------------------

/// The apparent acid-dissociation constant pKa of ammonium at [tempC]
/// (Celsius) and [salinityPpt]. See the library doc for the model + sources.
double ammoniumPKa({required double tempC, required double salinityPpt}) {
  final tK = tempC + _zeroCelsiusK;
  final pKa0 = _pkaTempA + _pkaTempB / tK;
  // Ionic strength (EPA 1989 Eq. 5); clamp salinity to the model's fitted
  // 0–40 ppt range so a nonsensical input can't produce a wild pKa.
  final s = salinityPpt.clamp(0.0, 40.0);
  final ionicStrength = 19.9273 * s / (1000 - 1.005109 * s);
  return pKa0 + _nh3SaltingOut * ionicStrength;
}

/// Fraction (0..1) of total ammonia present as toxic free NH₃ at [pH], [tempC]
/// (Celsius) and [salinityPpt].
double freeAmmoniaFraction({
  required double pH,
  required double tempC,
  required double salinityPpt,
}) {
  final pKa = ammoniumPKa(tempC: tempC, salinityPpt: salinityPpt);
  return 1 / (1 + math.pow(10, pKa - pH));
}

// --- Current-state computation -----------------------------------------------

/// The computed free-ammonia state for the dashboard.
class FreeAmmonia {
  const FreeAmmonia({
    required this.total,
    required this.freeNh3,
    required this.fraction,
    required this.pH,
    required this.tempC,
    required this.salinityPpt,
    required this.salinityMeasured,
    required this.at,
    required this.inputsOutdated,
  });

  /// Total ammonia (TAN) as stored — ppm, on the NH₃ basis (the `ammonia`
  /// parameter's canonical unit). Never negative.
  final double total;

  /// Free (toxic) ammonia = [total] × [fraction], in ppm NH₃.
  final double freeNh3;

  /// Share of the total that is the toxic NH₃ form (0..1).
  final double fraction;

  /// The pH used (the latest pH reading's value).
  final double pH;

  /// The temperature used, in Celsius (canonical) — the latest reading.
  final double tempC;

  /// The salinity used, in ppt.
  final double salinityPpt;

  /// False when [salinityPpt] fell back to [kDefaultSalinityPpt] (no salinity
  /// reading for the tank).
  final bool salinityMeasured;

  /// The moment the value describes — the newest of the inputs used.
  final DateTime at;

  /// True when the pH or temperature reading is older than [kAmmoniaInputMaxAge]
  /// relative to the ammonia reading: the estimate may be inaccurate.
  final bool inputsOutdated;

  /// Toxic share as a percentage (0..100).
  double get fractionPercent => fraction * 100;

  /// The health zone of [freeNh3] against the default toxicity bounds.
  Zone get zone => kFreeAmmoniaBounds.classify(freeNh3);
}

/// Computes the current free-ammonia state from each parameter's latest reading
/// (each list newest-first, as stored for a tank). Salinity is optional — reef
/// water sits near 35 ppt, so a missing salinity falls back to
/// [kDefaultSalinityPpt] (surfaced via [FreeAmmonia.salinityMeasured]).
///
/// Returns null when ammonia, pH, or temperature has no reading — free NH₃
/// cannot be stated without all three.
FreeAmmonia? computeFreeAmmonia({
  required List<AmmoniaInput> ammonia,
  required List<AmmoniaInput> ph,
  required List<AmmoniaInput> temperature,
  List<AmmoniaInput> salinity = const [],
  Duration maxAge = kAmmoniaInputMaxAge,
}) {
  if (ammonia.isEmpty || ph.isEmpty || temperature.isEmpty) return null;
  final a = ammonia.first;
  final p = ph.first;
  final t = temperature.first;
  final s = salinity.isNotEmpty ? salinity.first : null;

  final salinityPpt = s != null ? sgToPpt(s.value) : kDefaultSalinityPpt;
  final fraction = freeAmmoniaFraction(
    pH: p.value,
    tempC: t.value,
    salinityPpt: salinityPpt,
  );
  final total = a.value < 0 ? 0.0 : a.value;

  Duration gap(DateTime other) => a.takenAt.difference(other).abs();
  final outdated = gap(p.takenAt) > maxAge || gap(t.takenAt) > maxAge;
  final at = [
    a.takenAt,
    p.takenAt,
    t.takenAt,
  ].reduce((x, y) => x.isAfter(y) ? x : y);

  return FreeAmmonia(
    total: total,
    freeNh3: total * fraction,
    fraction: fraction,
    pH: p.value,
    tempC: t.value,
    salinityPpt: salinityPpt,
    salinityMeasured: s != null,
    at: at,
    inputsOutdated: outdated,
  );
}
