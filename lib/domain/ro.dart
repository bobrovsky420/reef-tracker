/// Pure logic for the shared reverse-osmosis (RO/RODI) unit (U16) — no
/// Flutter, no DB. The unit is **device-scoped, not tank-scoped**: one RO
/// unit serves every aquarium, so nothing here carries a tank id.
///
/// A stage (sediment filter, carbon block, membrane, DI resin, or a custom
/// part) has a lifespan in days and a log of replacements. Due math is the
/// same elastic model as testing/maintenance reminders: next due = last
/// replacement + lifespan ([nextElasticDue]). A stage with **no logged
/// replacement is never due** — the app cannot know how old the filter is,
/// and guessing "due now" would greet a fresh setup with a wall of overdue
/// warnings (the #8 never-guess rule applied to anchors).
library;

import 'reminders.dart';
import 'zones.dart';

part 'ro.g.dart';

/// The stage types of a typical 4-stage RO/RODI unit, plus [custom] for
/// non-standard parts (a second sediment stage, an extra DI cartridge, …).
/// Stored as [name] in `RoStages.stageType`.
enum RoStageType {
  sediment,
  carbonBlock,
  membrane,
  diResin,
  custom;

  /// Strict lookup: unknown names return null (restored backups are
  /// whitelisted; garbage must never coerce into a real stage type).
  static RoStageType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

// The default stage set (`kRoDefaultLifespanDays`, `kRoDefaultStageOrder`)
// is GENERATED from `ro_defaults.yaml` into `ro.g.dart` — edit the YAML,
// then run `dart run tool/gen_ro_defaults.dart`.

/// Remaining-life warning window: a stage turns amber within the last
/// [kRoAmberFraction] of its lifespan, floored at [kRoAmberMinDays] (a pure
/// fraction would warn only 9 days ahead on a 90-day cartridge) and capped at
/// half the lifespan (so a short-lived stage can still read green at all).
const double kRoAmberFraction = 0.1;
const int kRoAmberMinDays = 14;

/// Days-remaining threshold at which a stage of [lifespanDays] turns amber.
int roAmberWindowDays(int lifespanDays) {
  final fraction = (lifespanDays * kRoAmberFraction).round();
  final floored = fraction > kRoAmberMinDays ? fraction : kRoAmberMinDays;
  final cap = lifespanDays ~/ 2;
  return floored < cap ? floored : cap;
}

/// Next replacement due date, or null when it cannot be computed: no
/// replacement has been logged yet (unknown filter age — never a guess) or
/// the stored lifespan is invalid (< 1, possible only via restored data, #8).
DateTime? roStageDue({
  DateTime? lastReplacedAt,
  required int lifespanDays,
  DateTime? now,
}) {
  if (lastReplacedAt == null || lifespanDays < 1) return null;
  return nextElasticDue(
    lastDone: lastReplacedAt,
    cadenceDays: lifespanDays,
    now: now,
  );
}

/// Fraction of the stage's lifespan still remaining, clamped to 0..1 —
/// drives the overview progress bar. Overdue clamps to 0, a same-day
/// replacement to 1.
double roRemainingFraction({required int daysLeft, required int lifespanDays}) {
  if (lifespanDays < 1) return 0;
  final f = daysLeft / lifespanDays;
  return f < 0 ? 0 : (f > 1 ? 1 : f);
}

/// Zone color of a stage's remaining life: red once overdue, amber inside
/// the [roAmberWindowDays] warning window, green otherwise. Reuses the
/// app-wide [Zone] semantics so the RO bars read like every other health
/// surface.
Zone roStageZone({required int daysLeft, required int lifespanDays}) {
  if (lifespanDays < 1) return Zone.unknown;
  if (daysLeft < 0) return Zone.red;
  if (daysLeft <= roAmberWindowDays(lifespanDays)) return Zone.amber;
  return Zone.green;
}
