import 'zones.dart';

/// Microelements (U17) — pure domain rules for the ICP panel: default zone
/// bounds per element and the status summary the dashboard tile / screen
/// header show. No Flutter, no DB.

/// Shorthand mirroring `presets.dart`.
ZoneBounds _b(
  double? amberLow,
  double? greenLow,
  double? greenHigh,
  double? amberHigh,
) => ZoneBounds(
  amberLow: amberLow,
  greenLow: greenLow,
  greenHigh: greenHigh,
  amberHigh: amberHigh,
);

/// Default zone bounds per microelement, in **canonical ppm** (mg/L) like all
/// stored bounds. Sensible starting points anchored on natural seawater and
/// the target ranges ICP labs publish — deliberately generous, and editable
/// per tank exactly like core-parameter bounds. Contaminants (and silicon)
/// are one-sided: anything up to the green bound is fine, there is no "too
/// little lead".
///
/// Used as the fallback whenever a tank has no `TrackedParameters` row for an
/// element yet (rows are created lazily on first save/edit), and as the seed
/// when such a row is created.
final Map<String, ZoneBounds> kMicroDefaultBounds = {
  // Major ions (NSW at 35 ppt: Na ~10 760, S ~905, B ~4.4, Br ~65).
  'sodium': _b(9500, 10000, 11200, 12000),
  'sulfur': _b(780, 850, 980, 1100),
  'boron': _b(3.0, 3.8, 5.5, 7.0),
  'bromine': _b(45, 55, 75, 95),
  'silicon': _b(null, null, 0.15, 0.5),
  // Trace elements (NSW: Sr ~8.1 ppm, I ~60 µg/L, Mo ~10 µg/L, Li ~180 µg/L,
  // Ba ~10–15 µg/L; the rest are "keep low" ceilings).
  'strontium': _b(5.5, 7.0, 9.5, 12.0),
  'iodine': _b(0.03, 0.05, 0.08, 0.12),
  'iron': _b(null, null, 0.005, 0.015),
  'zinc': _b(null, null, 0.01, 0.03),
  'vanadium': _b(null, null, 0.003, 0.008),
  'copper': _b(null, null, 0.002, 0.01),
  'nickel': _b(null, null, 0.002, 0.008),
  'manganese': _b(null, null, 0.005, 0.02),
  'molybdenum': _b(0.001, 0.005, 0.015, 0.03),
  'chromium': _b(null, null, 0.001, 0.005),
  'cobalt': _b(null, null, 0.001, 0.004),
  'lithium': _b(0.05, 0.12, 0.25, 0.4),
  'barium': _b(0.001, 0.004, 0.02, 0.05),
  'selenium': _b(null, null, 0.005, 0.015),
  // Contaminants (ceilings roughly at "reports start flagging this").
  'aluminium': _b(null, null, 0.01, 0.05),
  'antimony': _b(null, null, 0.002, 0.01),
  'tin': _b(null, null, 0.003, 0.01),
  'beryllium': _b(null, null, 0.0005, 0.002),
  'silver': _b(null, null, 0.0005, 0.002),
  'tungsten': _b(null, null, 0.001, 0.005),
  'lanthanum': _b(null, null, 0.001, 0.005),
  'titanium': _b(null, null, 0.002, 0.01),
  'zirconium': _b(null, null, 0.001, 0.005),
  'arsenic': _b(null, null, 0.004, 0.012),
  'cadmium': _b(null, null, 0.0005, 0.002),
  'mercury': _b(null, null, 0.0003, 0.001),
  'lead': _b(null, null, 0.002, 0.008),
};

/// Default bounds for [paramKey], or empty bounds for a non-micro/unknown key.
ZoneBounds microDefaultBounds(String paramKey) =>
    kMicroDefaultBounds[paramKey] ?? const ZoneBounds();

/// The elements hobbyists test at home between ICPs (Salifert/Red Sea kits
/// exist for these) — the compact filter of the micro entry form.
const List<String> kMicroHobbyKitKeys = ['iodine', 'iron', 'strontium'];

/// One element's inputs for [computeMicroStatus]: its effective bounds and
/// latest reading (null = never measured).
typedef MicroInput = ({
  String paramKey,
  ZoneBounds bounds,
  double? latest,
  DateTime? takenAt,
});

/// Summary of the whole panel for the dashboard tile / screen header.
/// Deliberately *not* folded into the tank health score: microelements are
/// measured on an ICP cadence (months), which the 30-day core freshness rule
/// would permanently classify as stale.
typedef MicroStatus = ({
  int measured,
  int outOfRange,
  Zone worstZone,
  DateTime? lastMeasuredAt,
});

/// Collapses the panel into (measured count, out-of-range count, worst zone,
/// newest measurement). Elements without a reading are skipped — never
/// counted as a problem; an element whose bounds can't classify (empty or
/// invalid) counts as measured but not against the range.
MicroStatus computeMicroStatus(Iterable<MicroInput> inputs) {
  var measured = 0;
  var outOfRange = 0;
  var worst = Zone.unknown;
  DateTime? lastAt;
  for (final i in inputs) {
    final latest = i.latest;
    if (latest == null) continue;
    measured++;
    final at = i.takenAt;
    if (at != null && (lastAt == null || at.isAfter(lastAt))) lastAt = at;
    final zone = i.bounds.classify(latest);
    if (zone == Zone.amber || zone == Zone.red) outOfRange++;
    worst = switch ((worst, zone)) {
      (_, Zone.red) || (Zone.red, _) => Zone.red,
      (_, Zone.amber) || (Zone.amber, _) => Zone.amber,
      (_, Zone.green) || (Zone.green, _) => Zone.green,
      _ => Zone.unknown,
    };
  }
  return (
    measured: measured,
    outOfRange: outOfRange,
    worstZone: worst,
    lastMeasuredAt: lastAt,
  );
}
