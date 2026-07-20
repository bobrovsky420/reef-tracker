import 'parameter_catalog.dart';
import 'zones.dart';

part 'micro_views.g.dart';

/// Microelements (U17) — pure domain rules for the ICP panel: default zone
/// bounds per element and the status summary the dashboard tile / screen
/// header show. No Flutter, no DB.

/// Default zone bounds per microelement, in **canonical ppm** (mg/L) like all
/// stored bounds — the catalog's per-element `defaultBounds` (edited in
/// `parameters.yaml`, in catalog order). Sensible starting points anchored on
/// natural seawater and the target ranges ICP labs publish — deliberately
/// generous, and editable per tank exactly like core-parameter bounds.
/// Contaminants (and silicon) are one-sided: anything up to the green bound
/// is fine, there is no "too little lead".
///
/// Used as the fallback whenever a tank has no `TrackedParameters` row for an
/// element yet (rows are created lazily on first save/edit), and as the seed
/// when such a row is created.
final Map<String, ZoneBounds> kMicroDefaultBounds = {
  for (final p in kMicroParameters)
    if (p.defaultBounds != null) p.key: p.defaultBounds!,
};

/// Default bounds for [paramKey], or empty bounds for a non-micro/unknown key.
ZoneBounds microDefaultBounds(String paramKey) =>
    kMicroDefaultBounds[paramKey] ?? const ZoneBounds();

/// The elements hobbyists test at home between ICPs (Salifert/Red Sea kits
/// exist for these — `hobbyKit` in `parameters.yaml`) — the compact filter of
/// the micro entry form, in catalog order.
final List<String> kMicroHobbyKitKeys = [
  for (final p in kMicroParameters)
    if (p.hobbyKit) p.key,
];

// --- Element views ------------------------------------------------------------
//
// A *view* is a named subset of the panel the Microelements screen (and its
// entry form) is filtered to — typically "the elements my ICP lab reports".
// Two kinds exist: built-in presets below (code-defined, per lab panel) and
// user-created views (the `MicroViews` table). The active selection is a
// device-local per-tank setting holding one of the tokens below.

/// Active-view token for the built-in "everything in the catalog" view.
const String kMicroViewFullToken = 'preset:full';

/// Token prefix for user-created views: `view:<MicroViews row id>`.
const String kMicroViewCustomPrefix = 'view:';

/// One built-in lab view preset ("the elements my ICP lab reports").
///
/// The presets themselves are data, not code: they are edited in
/// `micro_views.yaml` and generated into [kMicroViewPresets] (in
/// `micro_views.g.dart`) by `tool/gen_micro_views.dart` — the same
/// source-of-truth pattern as `parameters.yaml` / `supplements.yaml`. Tokens
/// (`preset:<id>`) are persisted in the device-local `micro_view` setting;
/// names are lab proper nouns, deliberately not localized.
class MicroViewPreset {
  const MicroViewPreset({
    required this.token,
    required this.name,
    required this.keys,
  });

  final String token;
  final String name;
  final List<String> keys;
}

/// Resolves a built-in preset token to its element keys. Returns null for the
/// full view (= no filtering) and for anything that isn't a known preset
/// token (custom-view tokens are resolved against the DB by the caller).
Set<String>? microPresetKeys(String token) {
  for (final p in kMicroViewPresets) {
    if (p.token == token) return p.keys.toSet();
  }
  return null;
}

// --- Panel filters --------------------------------------------------------
//
// The two quick filter switches on the Microelements screen. Pure predicates
// on (effective bounds, latest value) so they are unit-testable and shared
// with nothing UI-specific.

/// Whether an element's latest value calls for attention: it classifies
/// amber or red against the effective bounds. Never-measured elements and
/// unclassifiable values (empty/invalid bounds) don't need attention.
bool microNeedsAttention(ZoneBounds bounds, double? latest) {
  if (latest == null) return false;
  final zone = bounds.classify(latest);
  return zone == Zone.amber || zone == Zone.red;
}

/// Whether the "hide undetectable" filter hides this element: the latest
/// reading is exactly 0 (ICP reports print undetectable elements as zero)
/// **and** zero is not itself abnormal. For elements with a lower bound
/// (sodium, potassium, iodine, …) a zero means a real deficiency — those stay
/// visible even with the filter on; one-sided "keep low" elements
/// (contaminants and most traces) classify zero as fine and are hidden.
bool microHiddenAsUndetectable(ZoneBounds bounds, double? latest) =>
    latest == 0 && !microNeedsAttention(bounds, latest);

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
  Zone statusZone,
  DateTime? lastMeasuredAt,
});

/// Collapses the panel into (measured count, out-of-range count, status zone,
/// newest measurement). Elements without a reading are skipped — never
/// counted as a problem; an element whose bounds can't classify (empty or
/// invalid) counts as measured but not against the range.
///
/// The status zone is the **dominant** deviation zone, not the worst single
/// element: an ICP report covers ~30 trace elements, so "any red wins" would
/// leave the summary permanently red. Red only when reds are at least as
/// numerous as ambers; a red minority reads amber (the headline count still
/// includes it).
MicroStatus computeMicroStatus(Iterable<MicroInput> inputs) {
  var measured = 0;
  var ambers = 0;
  var reds = 0;
  var greens = 0;
  DateTime? lastAt;
  for (final i in inputs) {
    final latest = i.latest;
    if (latest == null) continue;
    measured++;
    final at = i.takenAt;
    if (at != null && (lastAt == null || at.isAfter(lastAt))) lastAt = at;
    switch (i.bounds.classify(latest)) {
      case Zone.red:
        reds++;
      case Zone.amber:
        ambers++;
      case Zone.green:
        greens++;
      case Zone.unknown:
        break;
    }
  }
  final zone = reds > 0 && reds >= ambers
      ? Zone.red
      : ambers > 0
      ? Zone.amber
      : greens > 0
      ? Zone.green
      : Zone.unknown;
  return (
    measured: measured,
    outOfRange: reds + ambers,
    statusZone: zone,
    lastMeasuredAt: lastAt,
  );
}
