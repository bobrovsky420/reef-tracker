# ReefTracker — Design

ReefTracker is an offline-first Flutter app for tracking reef-aquarium water
parameters over time. The user logs measurements (temperature, pH, salinity,
alkalinity, calcium, nitrate, phosphate, …) per tank and sees, at a glance,
whether each value is healthy via green / amber / red "zones", plus history
graphs and trends. Everything is stored locally in SQLite — there is no backend
and no account.

> Keep this document up to date — see "Maintaining this document" at the bottom.

## Platforms & status

- **Android-first**, iOS-ready: the code is fully cross-platform; the iOS folder
  is intentionally absent in this workspace (build hygiene, not a code limit).
- Local-only, single-user, no network calls.

## Tech stack

| Concern            | Choice |
|--------------------|--------|
| UI framework       | Flutter (Material 3, seed color reef-blue `0xFF0277BD`, light + dark themes) |
| State management   | `flutter_riverpod` 3.x (note: in v3 `AsyncValue.value` is the nullable getter; `valueOrNull` does not exist) |
| Persistence        | `drift` over SQLite (native library built by `sqlite3` 3.x build hooks), code-generated via `dart run build_runner build` |
| Charts             | `fl_chart` |
| Routing            | `go_router` |
| i18n / formatting  | Flutter `gen-l10n` (ARB files) + `intl` |
| Backup I/O         | `share_plus` (export via OS share sheet) + `file_picker` (import) + `crypto` (sha256 integrity checksum) |
| App metadata       | `package_info_plus` (real version/build for the About box) |
| Feature tour       | `showcaseview` (first-run spotlight tour of the top bar) |
| Reminders          | `flutter_local_notifications` (scheduled local notifications; requires core-library desugaring in `android/app/build.gradle.kts` and the two receivers declared in the app manifest) + `timezone` (pure Dart; instants are scheduled as absolute UTC — no timezone-lookup plugin) |

> ⚠️ **Pinned plugins.** `share_plus` (10.1.4) and `file_picker` (11.0.0) are
> pinned to exact known-good versions, and `package_info_plus` is held below 10:
> newer releases fail the **release** build against this project's Android
> toolchain (Kotlin 2.3 / AGP 9 / Gradle 9.1) or pull conflicting `win32`
> constraints. Do not bump any of them individually — see the comment in
> `pubspec.yaml`; they must move together once verified.

## Architecture overview

The codebase is organized into four layers:

```
lib/
  domain/    Pure Dart business rules — no Flutter, no DB. Static app data.
  data/      Drift database, backup encode/decode, CSV export. The only persistence layer.
  app/       Riverpod providers (state graph) + go_router route table + theme.
  features/  One folder per screen/feature, wired to providers.
  l10n/      ARB source strings + generated AppLocalizations + domain-label helpers.
  widgets/   Small shared widgets.
  main.dart  App entry: ProviderScope + MaterialApp.router.
```

Data flows one way: **domain rules + Drift tables → providers → feature
widgets**. Widgets never touch the database directly except through
`ref.read(dbProvider)` for writes; reads always go through stream providers so
the UI is reactive to DB changes.

### Canonical values, presentational units

A core design decision: **all measurements are stored in canonical units and
converted only for display/input.**

- Temperature stored in **°C**, salinity in **SG**, volume in **litres**.
- The user's unit preferences (°C/°F, ppt/SG, L/gal) live in the `Settings`
  key/value table and are surfaced via `unitPrefsProvider`.
- `domain/units.dart` owns all conversions **and** `ParamPresentation` itself
  (plus its `presentationFor` / `presentationForKey` factories) — the object
  that knows how to format/parse a parameter's value for the current prefs.
  `database.dart` adds only the thin `presentationOf(trackedParam, prefs)`
  bridge from a DB row to `presentationForKey`.
- **Zone classification always compares canonical values against canonical
  bounds**, so changing display units never changes health colors.

Volume is *not* a tracked parameter — it is a property of a tank
(`volumeLiters`) and of a water change (`amountLiters`). The US gallon is
`3.785411784 L`. Salinity ↔ SG is linear, anchored at 35 ppt = 1.0264 SG @ 25 °C.
Carbon-change weight is stored in **grams** (no unit preference, suffix `g`).

## Domain layer (`lib/domain/`) — static, no DB migrations

| File | Responsibility |
|------|----------------|
| `zones.dart` | `ZoneBounds{amberLow, greenLow, greenHigh, amberHigh}` + `classify(value) → Zone` (green/amber/red/unknown). **Single source of truth for zone color logic.** (How a zone *renders* — its color/icon — is the `ZoneVisuals` extension in `widgets/zone_visuals.dart`, keeping this file Flutter-free; #53.) Any bound may be null = unbounded on that side, **but an amber bound requires its matching green bound on the same side** (enforced by the bound editors' `_pairsOk()` check; amber-without-green is what produced the old chart-band overlap). Green = `[greenLow, greenHigh]`; amber = just outside green but within amber bounds; red = beyond an amber bound. `classify` deliberately tests **red before green**, so a beyond-amber value can't short-circuit to "green" through an open (null) green side. Bounds violating the ordering invariant (`isValid` = present bounds non-decreasing; violations are possible only via restored/hand-edited backups, the editors validate) are treated as **unusable**: `classify` returns `unknown` and `zoneBands` paints nothing, instead of labeling every value amber. Amber-only bounds (both greens null) classify — and paint — the region between the ambers as green, keeping tile color and chart bands in agreement. |
| `clock.dart` | Wall-clock helpers, `now`-injectable/testable: `ageSince(t, {now})` (difference clamped to `>= 0`) and `daysSince(t, {now})` (whole days, **rounded** not truncated, `>= 0`). Used so a future or clock-skewed timestamp reads as "just now"/age 0 rather than a negative duration that would appear "fresh" or "-N days ago" (freshness, "time ago", "not tested for N days"). Rounding (not truncating) avoids under-counting: a reading 18 h into its 7th day reads as 7 days, not 6 — which matters right at the 30-day health-freshness cutoff. |
| `units.dart` | Unit enums (`TempUnit`, `SalinityUnit`, `VolumeUnit`), conversions, `UnitPrefs`, and `ParamPresentation` (format/parse). `parseUserDouble` is **locale-aware** (via `Intl.defaultLocale`): the locale's decimal separator is always a decimal, the opposite separator/space in strict thousands positions is grouping (`1,300` → 1300 in en, 1.3 in cs/de), a lone opposite separator that can't be grouping is a tolerant decimal (`2,5` on comma keyboards in an en app), and mixed-separator input is rejected. Display formatting is the mirror image: `formatLocaleNumber`/`formatLocaleNumberTrim` render with the locale's decimal separator (grouping deliberately off — grouped output with decimals would mix separators, which the parser rejects, and formatted values are seeded back into edit fields); all user-facing number formatting routes through them (`ParamPresentation.format`, volumes, dose amounts, ratios, chart axes). |
| `parameter_catalog.dart` | `kReefParameters` — the master list (temp, pH, salinity, alk, Ca, Mg, NO₃, PO₄, NH₃/₄, NO₂, ORP, K, Sr, I, Fe) with default units, plus `kParameterByKey` lookup and `formatParamValue`. Each `ParameterDef` also carries **value-sanity limits in canonical units**: `minValue` = hard physical floor (0 for concentrations, 1.0 for SG; ORP has none — legitimately negative) and a deliberately generous `plausibleMin`/`plausibleMax` pair (e.g. Mg 800–2000, SG 1.0–1.05). `checkParamValue(paramKey, canonicalValue)` → `ParamValueCheck` (ok / impossible / implausible): **impossible** values are rejected by the reading inputs outright; **implausible** ones require an explicit "Save anyway" confirmation that echoes the value as parsed next to the typical range — the backstop that turns a locale decimal-separator mis-parse (`1,300` → 1.3) into a visible prompt instead of silent data corruption, while keeping extreme-but-real crash readings recordable. Enforced in Add Reading and the history value-edit dialog, always on the canonical value (after °F/ppt conversion). |
| `presets.dart` | `kPresets[SetupType][paramKey] = ZoneBounds`. Which keys are present per setup type = the parameters tracked by default for that type. `presetBounds`, `defaultTrackedKeys`. |
| `setup_type.dart` | `SetupType` enum: fishOnly / soft / lps / sps / mixed. Stored as `.name`; `fromName` defaults to `mixed`. |
| `ratio.dart` | Parameter-ratio math + `RatioKind` enum (PO₄ : NO₃, Mg : Ca); see Features. Pure (no DB): consumes plain `RatioReading` (`{takenAt, value}`) records and `RatioSettings` (`{visible, displayOrder, bounds}`) instead of drift rows — `database.dart` hosts the thin row→record mappers (#52). |
| `trend.dart` | Pure, testable drift/trend detection (no Flutter/DB). `computeTrend(points, bounds, window)` → `TrendResult?` (signed `slopePerDay` reusing `dose_calculator.linearFit`, `TrendDirection`, projected `daysToAmber`/`daysToRed` — when the value reaches the green→amber and amber→red bounds it is heading toward — and a `recovering` flag). Uses the most recent `window` readings and returns null until that many exist. The projection is **anchored on the fitted (regression) value at the last timestamp**, not the raw last reading, so one noisy endpoint can't swing the forecast. A value already *outside* its green range but moving back toward it is **recovering**: no crossing is forecast (the only bounds ahead are on the far side of green — forecasting them would warn about an improving parameter) and `recovering` is set so the UI could one day surface it positively (TODO U15). Tuning consts: `kTrendDefaultWindow`=5, `kTrendMinWindow`=3, `kTrendMaxWindow`=10, `kTrendDefaultEnabled`, plus the forecast-horizon bounds `kTrendDefaultHorizon`=14, `kTrendMinHorizon`=3, `kTrendMaxHorizon`=90 (UI gating only — not used by `computeTrend`). Slopes with magnitude < 1e-9 (`_flatEpsilon`) classify as flat (no forecast), a bound projection is dropped when the bound lies opposite the direction of travel ("the bound is behind us"), and bounds failing `ZoneBounds.isValid` produce no forecast at all. See Features. |
| `health_score.dart` | Pure, testable tank-health scoring (no Flutter/DB). `computeTankHealth(inputs)` → `TankHealth` (optional 0–100 `score`, worst-case `Zone` `band`, coarse `HealthGrade`, and per-parameter `ParameterHealth` breakdown). Each fresh, bounded parameter gets a 0–100 sub-score from its position in/beyond its bands (green 70–100, amber 40–69, red 0–39), interpolated linearly within the band: centred in green = 100, at a green bound = 70; amber runs 69→40 from the green toward the amber bound; red falls 39→0 with distance measured in *amber-band widths* past the amber bound (so a wide amber band forgives overshoot proportionally); one-sided/unmeasurable cases use flat 90 / 55 / 20. The aggregate is the importance-weighted mean — **weights:** 3 = temp, salinity, alk, NH₃/₄, NO₂ · 2.5 = pH · 2 = Ca, Mg, NO₃, PO₄ · 1 = everything else — then **capped to the worst zone's ceiling** (any red ⇒ ≤ 39, else any amber ⇒ ≤ 69) so one red can't be hidden behind greens. **Grade thresholds:** excellent ≥ 85, good ≥ 70, caution ≥ 40, critical < 40. Readings older than `kHealthFreshnessDays`=30 are excluded and surfaced separately; a value carrying no timestamp counts as stale too (freshness can't be verified), never as eternally fresh. See Features. |
| `reminders.dart` | Pure due-date math for reminders & schedules (U1/U2/U12). `ReminderKind` (testing/dosing/maintenance — one notification channel + master switch each), `MaintenanceActionType` (the three logged action types; null stored type = custom task), `DueStatus` (`{dueAt, daysLeft}` — signed, negative = overdue). Two anchoring models, deliberately different: **elastic** for testing/maintenance (`nextElasticDue`: due = last done + cadence; logging resets the timer; never-done → `scheduledAt` seed or due now; one-off = due at `scheduledAt`, retired once done; a stored cadence < 1 is *unknown*, not daily — the #8 rule) and **calendar** for dosing (`doseOccurrences` expands frequency/interval/weekdays/`doseTime` from the segment's `startedAt`; no/garbage dose time, empty weekly weekdays, or an invalid interval → no occurrences, never a guess). Maintenance plans route through `nextMaintenanceDue`, which layers the **repeat modes** over the elastic core (field priority weekdays > monthDay > cadence): every N days/weeks/months (`MaintenanceCadenceUnit`, elastic — month steps clamp the day, Jan 31 + 1 mo = Feb 28), fixed weekdays ("every Monday") and fixed day-of-month ("every 1st", 31 clamps to short months) — both calendar anchored on the *next matching date strictly after last done* (never done → first match on/after the `scheduledAt` seed, else today — no phantom overdue), pinned to noon so the whole due day reads "due today". Unknown units, garbage weekday lists and out-of-range month days → null (#8 again). `coalesceReminders` merges items into one notification per (tank, kind, day) — earliest fire time, deduped labels. `parseDoseTime`/`parseWeekdays` are the shared strict parsers. |
| `dose_calculator.dart` | Pure, testable math for the dose calculator (no Flutter/DB): `linearFit` (least-squares slope/day + fitted value at the last timestamp; `slopePerDay` is its slope-only wrapper), `potencyFromReference` (vendor reference dose → potency per unit per litre), `dailyEquivalentDose` (a dosing plan's average daily amount from its `DoseSchedule` record — amount + frequency/interval/weekdays, mapped from the `DosingEntry` row via `DosingEntry.schedule`; the stored basis is deliberately not an input since both bases mean "amount per active day"; a stored every-N-days interval ≤ 0 — possible only in pre-validation rows — counts as an *unknown* cadence contributing 0, not as daily), and `computeDoseCalc` → `DoseCalcResult` (consumption/day + maintenance-dose recommendation + `DoseCalcStatus`). Sign convention: `consumption = dosingInput − slope`, so a falling element (negative slope) means consumption exceeds the dose. Statuses: `consumption ≤ 0` reports `overdosing` when something is dosed, `noDoseNeeded` when nothing is (there is nothing to "reduce or pause"); with consumption but no current dose the result is always `increase` (never "keep your current dose" of nothing); otherwise `stable` when \|suggested − current\| ≤ max(5% of the current dose (`stableFraction`), 0.1 ml/g (`stableThreshold`)) — relative, so "stable" means the same chemical mismatch regardless of product potency — else `increase`/`decrease`. Water changes ignored. See Features. |
| `supplement_catalog.dart` | Model + lookups for the dosing **vendors → programs → products** catalog + `DoseUnit` (ml/g), `DoseBasis` (per day/dose), `DoseFrequency` (daily/everyNDays/weekly) enums. Each `SupplementProduct` has a stable `key` (persisted on dosing entries), a target `elementKey` (a real param key), a default unit, and an optional `strength` potency map reserved for the future consumption calculator. Product `key`s are **never reused or repurposed** — stored entries (and the future dose log) resolve display names and potency through them. `strength` is recorded **only when verified against the vendor's own dosing chart**; an unverified potency would silently corrupt consumption estimates (e.g. Triton Core7 carries none because the vendor publishes no concentrations). Brand/product names are proper nouns — **not** localized. `kDosingElementKeys` = the param keys offered in the dosing element picker. **The data (`kSupplementVendors`) is generated** — see below. |
| `supplements.yaml` + `supplement_catalog.g.dart` | `supplements.yaml` (commented, hand-edited) is the **source of truth** for the catalog data; `dart run tool/gen_supplements.dart` validates it (unique product keys; every `element`/`strength` key is a real param key; `unit` ∈ ml/g) and generates the `part` file `supplement_catalog.g.dart` (`const kSupplementVendors`). Edit the YAML, never the `.g.dart`. `test/supplement_catalog_test.dart` re-checks the same invariants on the generated catalog. |

## Data layer (`lib/data/`)

### Schema (`database.dart`, generated `database.g.dart`) — **schemaVersion 17**

| Table | Key columns |
|-------|-------------|
| `Tanks` | id, name, setupType, volumeLiters?, startDate?, notes?, vendor?, model?, createdAt, deletedAt? — `deletedAt` is the soft-delete stamp (U10): non-null rows are hidden from every read path during the delete-undo window and finalized by `hardDeleteTank`/`purgeDeletedTanks` |
| `TrackedParameters` | id, tankId (FK cascade), paramKey, unit, enabled, displayOrder, + 4 zone bounds (amberLow/greenLow/greenHigh/amberHigh), testCadenceDays? — "remind to test every N days" (U1), null = no reminder |
| `Readings` | id, tankId (FK cascade), paramKey, value (canonical), takenAt, note?, groupId? — `groupId` tags readings entered together as one add-reading batch (generated by `newReadingGroupId`, no uuid dependency); null on pre-v13 rows, which fall back to same-timestamp grouping |
| `WaterChanges` | id, tankId (FK cascade), changedAt, amountLiters?, note? |
| `CarbonChanges` | id, tankId (FK cascade), changedAt, grams?, note? |
| `EquipmentCleanings` | id, tankId (FK cascade), cleanedAt, note? |
| `RatioVisibilities` | tankId + ratioKey (composite PK), tankId FK cascade, visible, displayOrder, amberLow?/greenLow?/greenHigh?/amberHigh? — per-tank ratio-card visibility, dashboard position (shared order space with `TrackedParameters.displayOrder`), and editable zone bounds; a missing row (or all-null bounds) = visible, ordered last, default zones |
| `DosingEntries` | id, tankId (FK cascade), productKey? (stable catalog id; null = custom), vendor?/program?/product (denormalized display names), elementKey? (real param key), amount?/amountUnit? (canonical ml or g)/basis? (per day/dose), frequency?/intervalDays?/weekdays?/doseTime? (descriptive schedule), remindEnabled (U2 dosing reminders — opt-in, effective only while active with a parsable doseTime), note?, displayOrder, createdAt, startedAt? (segment start; backfilled from createdAt), endedAt? (null = current), state (`DosingState`: active/ended/paused) — per-tank supplement-dosing plan (info-only). A plan is a chain of **dated segments**: editing a dose-affecting field ends the current segment (`state=ended`, `endedAt` set) and starts a new active one; stopping soft-ends it. Only `active` rows show in the Dosing tab and feed the calculator; `ended` rows are retained history. `paused` is reserved for a later phase. |
| `ReadingTemplates` | id, tankId (FK cascade), name, paramKeys (JSON array of stable *catalog* keys — `encodeTemplateParamKeys`/`decodeTemplateParamKeys`, tolerant decode), displayOrder — per-tank **test sets** (U9): named parameter subsets whose chips filter the Add Reading form. Catalog keys, not `TrackedParameters` ids, so a set survives disable/untrack + re-add; keys not currently tracked+enabled are skipped at display, never deleted |
| `MaintenanceSchedules` | id, tankId (FK cascade), actionType? (`MaintenanceActionType.name`, null = custom task), title? (required iff custom), cadenceDays? + cadenceUnit? (`MaintenanceCadenceUnit.name` days/weeks/months, null = days — repeat every N units; all repeat fields null = one-off), weekdays? (comma list 1=Mon…7=Sun — fixed-weekday repeat, same format as `DosingEntries.weekdays`), monthDay? (1–31, clamped to short months — fixed-date repeat), scheduledAt? (seeds the first occurrence), lastDoneAt? (completion stamp for **custom** rows — typed rows derive last-done from their action log), remindEnabled, note?, displayOrder — the user-maintained maintenance plan list (U12); due math in `domain/reminders.dart` (`nextMaintenanceDue`, field priority weekdays > monthDay > cadence) |
| `Settings` | key (PK), value? — generic kv store |

**Secondary indexes** (declared as `@TableIndex` on the table classes, so
`createAll` builds them for fresh installs; the v12 migration creates them for
existing DBs) back the hot reactive read paths — each stream filters on `tankId`
and orders by a timestamp: `Readings(tankId, paramKey, takenAt)` and
`Readings(tankId, takenAt)` (both kept — the 3-column one can't order by
`takenAt` when only `tankId` is filtered), `WaterChanges(tankId, changedAt)`,
`CarbonChanges(tankId, changedAt)`, `EquipmentCleanings(tankId, cleanedAt)`,
`DosingEntries(tankId)`, `ReadingTemplates(tankId)`, and
`MaintenanceSchedules(tankId)`.

`Settings` keys in use: `active_tank_id`, `temp_unit`, `salinity_unit`,
`volume_unit`, `locale`, `chart_range`, `auto_backup_enabled`,
`auto_backup_interval`, `auto_backup_keep`, `last_auto_backup_at`,
`trend_enabled`, `trend_window`, `trend_horizon`, `health_display` (tank-health
surfacing: both/badge/off), `tour_v1_seen` (first-run feature-tour flag),
`last_reading_template` (last-used test set per tank as one JSON object
`{"<tankId>": <templateId>}`; missing/dangling entries mean "All"),
`reminders_testing` / `reminders_dosing` / `reminders_maintenance` (the
notification master switches, all default off — opt-in), and `reminder_time`
(`HH:mm` delivery time for testing/maintenance reminders, default 09:00). The
reminder keys are device-local: notification preferences must not ride a
backup onto another device.

All settings access goes through the typed **`AppSettings` facade**
(`data/settings.dart`, exposed as `settingsProvider`) — the single source of
truth for each key, its default, and its typed encode/decode, so call sites stop
doing stringly-typed `== 'true'` / `int.tryParse(..) ?? default` with the
default duplicated everywhere. The `SettingKey` enum registers every key with a
`deviceLocal` flag; `SettingKey.deviceLocalKeys` is what `restoreFromBackup`
preserves (#18). Providers delegate to the facade's `watchX()` streams; screens
call its `setX(value)` setters. The raw key strings themselves live in the leaf
`data/setting_keys.dart` (re-exported by `settings.dart`) so `database.dart`'s
active-tank helpers can share them without an import cycle (#55).

**Migrations** (`MigrationStrategy`): v2 added `Tanks.startDate` via `addColumn`;
v3 added the `WaterChanges` table via `createTable`; v4 added `WaterChanges.note`
(`addColumn`) and the `CarbonChanges` table (`createTable`); v5 added the
`EquipmentCleanings` table (`createTable`, guarded by `_tableExists`); v6 added
the `RatioVisibilities` table (`createTable`, guarded by `_tableExists`); v7
added `RatioVisibilities.displayOrder` (`addColumn`, guarded by `_columnExists`);
v8 added `RatioVisibilities` zone-bound columns (`addColumn` ×4, guarded); v9
added the `DosingEntries` table (`createTable`, guarded by `_tableExists`); v10
added `Tanks.notes`/`vendor`/`model` (`addColumn` ×3, guarded by `_columnExists`);
v11 added `DosingEntries.startedAt`/`endedAt`/`state` (`addColumn` ×3, guarded)
and backfills `started_at = created_at` for pre-existing rows via `customStatement`;
v12 added the secondary indexes above (`CREATE INDEX IF NOT EXISTS` ×6 via
`customStatement`, matching the `@TableIndex` definitions that `createAll` uses
for new installs); v13 added `Readings.groupId` (`addColumn`, guarded — pre-v13
rows stay null and keep legacy timestamp grouping); v14 added the
`ReadingTemplates` table (`createTable`, guarded by `_tableExists`) and its
`tankId` index (U9); v15 added `Tanks.deletedAt` (`addColumn`, guarded — U10
soft delete); v16 added `TrackedParameters.testCadenceDays` +
`DosingEntries.remindEnabled` (`addColumn` ×2, guarded) and the
`MaintenanceSchedules` table + its `tankId` index (U1/U2/U12 reminders); v17
added `MaintenanceSchedules.cadenceUnit`/`weekdays`/`monthDay` (`addColumn`
×3, guarded — the extended maintenance repeat modes; pre-v17 rows stay null =
plain every-N-days).
Foreign keys are enabled in
`beforeOpen` (`PRAGMA foreign_keys = ON`), and the database opens in **WAL
journal mode** (`pragma journal_mode = WAL` in the
`NativeDatabase.createInBackground` setup callback, T6) so readers and writers
don't block each other — e.g. a backup encode's SELECTs vs. a concurrent user
write. WAL is persistent in the DB file, but the pragma runs on every open to
cover fresh installs and pre-WAL databases alike; the `-wal`/`-shm` sidecar
files were already handled by the backup/restore paths. **When you
add/change a table or column you must bump `schemaVersion` and add the matching
migration**, then run `dart run build_runner build`.

> ⚠️ **`createTable`/`createAll` build from the _current_ table definition, not
> the historical one.** So when a user upgrades across several versions at once,
> an earlier `createTable(x)` step already creates `x` with columns that a later
> step then tries to `addColumn` — throwing `duplicate column`. The v4 step
> guards against this with the idempotent `_tableExists` / `_columnExists`
> helpers (skip `addColumn`/`createTable` when the target already exists).
> Prefer that pattern for every new column/table migration.

Notable DB behavior:
- `createTankWithPreset` seeds `TrackedParameters` from the setup-type preset and
  makes the tank active, all in one transaction.
- `boundsOf(TrackedParameter)` builds `ZoneBounds`; `presentationOf` bridges a
  tracked param + prefs to a `ParamPresentation`.
- `applyPreset` re-applies preset bounds to known params without adding/removing.
- `readingGroup` / `deleteReadingGroup` / `updateReadingGroupTime` operate on a
  batch of readings entered together, keyed on `Readings.groupId`
  (`insertReadingGroup` stamps each batch) with a legacy fallback for pre-v13
  rows: same tank + timestamp **and** null groupId, so an old group can never
  swallow a new batch that lands on the same second. Re-timing a single value
  out of its batch clears its groupId; the delete-undo path and backups
  round-trip it.
- **Dosing segment operations:** `insertDosingEntry` assigns
  `displayOrder = max(existing) + 1` — *not* the row count, which collides with
  an existing order after a middle row is deleted — and stamps
  `startedAt = now` / `state = active` when absent. `supersedeDosingEntry` ends
  the old segment and inserts the new active one **in one transaction**, reusing
  the old `displayOrder` so the row keeps its list position. `stopDosingEntry`
  is a soft end (`state = ended`, row retained as history) and
  `restoreDosingEntry` writes a captured pre-stop row back verbatim (the
  stop-undo path, U10); `deleteDosingEntry` is the only hard delete.
  `watchDosingHistory` orders by
  `coalesce(startedAt, createdAt)` desc so pre-v11 rows still sort correctly.
- **Tank soft delete (U10):** `softDeleteTank` stamps `deletedAt` and hands the
  active-tank slot to another visible tank; `watchTanks`/`getTanks` filter
  `deletedAt IS NULL`, so the tank vanishes everywhere at once while its rows
  survive the undo window. `restoreTank` clears the stamp (returns false when
  the row is gone, so the caller doesn't re-activate a ghost id);
  `hardDeleteTank` finalizes (FK cascade), **guarded to soft-deleted rows
  only** so a stale undo-window callback can't remove a live tank that reused
  the id; `purgeDeletedTanks` is the post-first-frame startup sweep
  (`main.dart`) collecting rows orphaned by a process kill mid-window.
- **Transaction boundaries:** every multi-step write is atomic —
  `createTankWithPreset` (insert + seed + activate), `softDeleteTank` (stamp +
  active-tank fallback), `supersedeDosingEntry`, `applyDashboardOrder` (params
  batch + ratio insert-or-update), `addTrackedParameter` (exists-check +
  max-order + insert), `insertDosingEntry` (max-order + insert),
  `insertReadingTemplate` (max-order + insert), and `restoreFromBackup`. `setRatioVisible`/`setRatioBounds` are single
  `insertOnConflictUpdate` upserts on the composite PK (only the companion's
  present columns are written on conflict).

### Backup (`backup.dart`)

JSON document, `format: "reeftracker-backup"`, `version` (`kBackupVersion = 1`),
plus the DB `schemaVersion` it was written against. DateTimes serialized as epoch
millis. `encodeBackup` dumps every table — except tanks inside their
delete-undo window (`deletedAt` set, U10) and their child rows, which
`encodeBackupFromDb` filters out so a backup racing the window never resurrects
the tank (`deletedAt` never enters the format, keeping older apps compatible);
`decodeBackup` validates the
format/version guard (distinguishing a missing version = not a backup file, a
non-int version = corrupted, and a genuinely newer document) and is
**forward-tolerant** (older backups without the
`waterChanges` / `carbonChanges` / `equipmentCleanings` / `ratioVisibilities` /
`dosingEntries` / `readingTemplates` / `maintenanceSchedules` keys decode to
empty lists, pre-v16 rows without `testCadenceDays`/`remindEnabled` decode
to null/off, and pre-v17 maintenance rows without
`cadenceUnit`/`weekdays`/`monthDay` decode to null = plain every-N-days).
Each table is decoded in isolation,
so a failure throws an `InvalidBackupException` naming the offending section
rather than one catch-all "corrupted". Field-level decoding is likewise
forward-tolerant: a pre-v11 `dosingEntries` row without `startedAt`/`endedAt`/
`state` decodes with `startedAt = createdAt`, `endedAt = null`, `state = active`.
Where a missing optional column has a table default, the decoder emits Drift's
`Value.absent()` so the **default** applies rather than NULL (e.g. an old ratio
row without `displayOrder` gets the table default 1000 = ordered last).

Every document carries an **integrity checksum** (T7): `checksum` = sha256 hex
of the compact JSON encoding of the document *without* that key. `decodeBackup`
strips the key, re-encodes the rest and compares — jsonDecode preserves key
order and Dart's number encoding round-trips, so the bytes match exactly; a
mismatch (in-field corruption that keeps the JSON parseable) rejects as
`corrupted`. Checksum-less backups from older app versions are accepted
unverified, and `kBackupVersion` stays 1 so older apps can import new files
(they ignore the extra key).

`exportBackup` writes a timestamped file to a temp dir and hands it to the OS
share sheet via the shared `shareExportFile` helper (`export_share.dart`),
which cleans up the plaintext copies: the staging file as soon as the sheet
returns, share_plus's internal copy (under `<temp>/share_plus/`) immediately
when the sheet was dismissed, and any copy a completed share left behind at
the start of the next export (deleting it right away could break a receiver
still streaming the content URI). The sweep recognizes both export naming
patterns (backup JSON and measurement CSV) and never touches foreign files.
`pickBackupData` uses the file
picker; read/UTF-8 failures stay inside the `InvalidBackupException` contract
so a binary file renamed `.json` gets the specific rejection message. `restoreFromBackup`
**replaces the entire database in one transaction**, preserving primary keys so
FK links survive (deletes children→parents, inserts parents→children). It takes
a `preserveSettingKeys` set (the caller passes `SettingKey.deviceLocalKeys`):
those settings rows are neither deleted nor imported, so restoring a backup —
possibly from another device — **never overwrites this device's own preferences**
(units, language, active tank, chart range, trend/health display, the tour flag,
auto-backup config; #18). Only the aquarium/domain data is replaced.

**Importing is a three-stage safety pipeline** (`importBackup`), so a bad file
never wipes live data:
1. `validateBackup` — in-memory pre-flight: rejects a backup whose
   `schemaVersion` is newer than the app's, and checks internal consistency:
   no duplicate primary keys, no child row referencing a missing aquarium,
   row ids within `1..2^31` (a crafted huge id would exhaust SQLite's
   AUTOINCREMENT space and permanently break inserts), and enum-ish text
   columns (`setupType`, dosing `state`/`frequency`/`amountUnit`/`basis`)
   whitelisted against the app's enums so a garbage `state` can't restore an
   unmanageable zombie row, and test-set names must not be blank (their
   `paramKeys` must be a JSON list of strings — enforced by the section
   decoder). Maintenance plans are checked the same way: `actionType` must be
   a known `MaintenanceActionType` name or null-with-a-non-blank-`title`
   (custom task), a present `cadenceDays` must be ≥ 1 and `cadenceUnit` a
   known `MaintenanceCadenceUnit` name, a present `weekdays` list must parse
   to at least one valid day, and a present `monthDay` must be 1–31 (the #8
   unknown-cadence rule applied at the door — each of these would otherwise
   restore a permanently silent plan).
2. *Rehearsal* — the restore is run against a throwaway temp database so the real
   SQLite engine (FK / NOT NULL / uniqueness) proves the rows insert cleanly.
3. The actual transactional `restoreFromBackup` into the live DB.
Failures in stage 1 or 2 surface a specific localized message
(`BackupRejection` → `l10n.backupRejection`) and leave the live DB untouched.

`encodeBackupFromDb(db)` is the shared "read every table → JSON" helper used by
both manual export and the automatic backup service. The CPU-heavy halves of
the pipeline run **off the UI isolate** (T5): JSON encoding and decoding happen
in `Isolate.run` workers (auto-backup fires right after the first frame and on
resume, so a large database would otherwise jank startup), and the rehearsal
restore uses `NativeDatabase.createInBackground`. Backup JSON is compact, not
pretty-printed — indentation would double the encode cost and file size, and
nothing reads it.

### Measurement CSV export (`csv_export.dart`)

Settings → Backup offers "Export measurements (CSV)" (U3): the **active
tank's readings only**, shared through the same `shareExportFile` staging/
sweep path as the JSON backup. `encodeReadingsCsv` is a pure function (unit
tested) producing RFC 4180 output — comma-delimited, CRLF, quote-escaped —
one row per measurement, oldest first, header
`taken_at,parameter,value,unit,note`. `parameter` is the stable catalog key
(same identifier as the JSON backup) so files compare across app languages;
values are converted to the user's display units at display precision but
always with a `.` decimal separator (locale decimals would fight the comma
delimiter); timestamps are device-local `yyyy-MM-dd HH:mm:ss`. Readings whose
tracked-parameter row was removed fall back to the catalog's default unit.
Encoding runs in `Isolate.run` (readings are the largest table); the fetch is
a one-shot `getReadingsForTank`, not a watcher. An empty tank shows a
localized "nothing to export" SnackBar instead of opening the share sheet.

### Automatic backup (`auto_backup.dart`)

Two layers, **no new dependencies and no runtime permissions**:

1. **Local rotating backups.** `runAutoBackupIfDue(db)` is called
   opportunistically on app launch and on resume (`main.dart`,
   `WidgetsBindingObserver`); it writes a backup only when the feature is
   enabled, at least one tank exists, and the chosen interval
   (`AutoBackupInterval` daily/weekly) has elapsed since `last_auto_backup_at`.
   A rolled-back device clock (stamp in the future) counts as due, so backups
   can never be silently suspended until the clock catches up.
   `writeAutoBackup` serializes via `encodeBackupFromDb` to
   `<appDocuments>/backups/reeftracker-auto-<stamp>.json` — **atomically**, via
   a `.json.tmp` write + read-back verification + rename, so an interrupted or
   silently corrupted write can never leave a truncated file in the rotation —
   then `pruneAutoBackups`
   keeps the newest *N* (`kAutoBackupDefaultKeep`). The filename stamp is
   **UTC with millisecond precision** (`yyyyMMdd-HHmmss-SSS`): UTC keeps the
   lexical sort chronological across DST fall-back, milliseconds keep two
   near-simultaneous writes from colliding on one name (filenames are never
   shown as dates — the UI formats the file's mtime). The **Manage backups**
   screen (`features/settings/backups_screen.dart`, route `/settings/backups`)
   lists them and offers restore (reuses `decodeBackup` + `importBackup`),
   share, and delete. `backupNow(db)` powers the **Back up now** action in
   Settings: it writes into the same rotating folder regardless of the schedule
   and stamps `last_auto_backup_at`, so the visible "last backup" status
   (surfaced via `lastBackupAtProvider`) updates at once. The schedule and the
   manual button share `_stampLastBackup` as the single source of truth for
   that timestamp. Both entry points are **serialized through one in-flight
   slot** (a module-level `_autoBackupInFlight` future): concurrent
   `runAutoBackupIfDue` calls (the launch post-frame callback and a `resumed`
   event can fire near-simultaneously) share the same run, and `backupNow`
   queues behind an in-flight run and then occupies the slot itself, so a
   manual and a scheduled backup can never encode/write concurrently.
   **Failures are recorded, not swallowed**: a failed write persists
   `last_backup_error_at` (cleared by the next successful backup), which
   Settings surfaces as a persistent "Last backup failed on …" warning row via
   `lastBackupErrorAtProvider`. Note the role split: `writeAutoBackup` is
   schedule-agnostic and does **not** stamp the timestamp or the error — the
   shared `_writeAndStamp` path used by `runAutoBackupIfDue` and `backupNow`
   does.
2. **Android Auto Backup.** `android:allowBackup="true"` plus
   `res/xml/backup_rules.xml` / `data_extraction_rules.xml` mean the SQLite DB
   is synced to the user's Google Drive and auto-restored on reinstall / new
   device. Cloud backup **excludes the rotating `backups/` folder**
   (`<exclude domain="root" path="app_flutter/backups"/>`): the JSONs duplicate
   the DB, would double the cleartext copies in Drive, and count against the
   ~25 MB Auto Backup quota. Device-to-device transfer (API 31+) still carries
   everything.

Settings keys: `auto_backup_enabled` (default on), `auto_backup_interval`
(`daily`/`weekly`), `auto_backup_keep`, `last_auto_backup_at`,
`last_backup_error_at`. Providers: `autoBackupEnabledProvider`,
`autoBackupIntervalProvider`, `lastBackupAtProvider`,
`lastBackupErrorAtProvider`.

### Reminders & notification scheduling (`notifications.dart`, `reminder_scheduler.dart`)

Local, opt-in reminder notifications (U1 testing, U2 dosing, U12 maintenance).
Two layers with a test seam between them:

- **`notifications.dart` — the platform wrapper.** Thin service over
  `flutter_local_notifications`: init + tap callback, the Android 13+
  POST_NOTIFICATIONS request (asked when the user first enables a category —
  never at startup), three notification channels (one per `ReminderKind`, so
  system settings can tune each), and `syncPlanned(list)` = `cancelAll()` +
  schedule fresh (safe: the app owns no other notifications and every sync
  recomputes the full set). Scheduling is **inexact**
  (`AndroidScheduleMode.inexactAllowWhileIdle` — reminders don't need minute
  precision, and it avoids the SCHEDULE_EXACT_ALARM permission/Play review;
  observed delivery windows are minutes). Instants are scheduled as **absolute
  UTC** (`tz.TZDateTime.from(utc, tz.UTC)`), so no timezone-lookup plugin is
  needed; a DST shift is at most an hour off until the next resync. The
  `ReminderSink` interface is the seam scheduler tests fake. The app manifest
  declares the plugin's `ScheduledNotificationReceiver` +
  `ScheduledNotificationBootReceiver` (with RECEIVE_BOOT_COMPLETED), which the
  plugin does **not** declare itself — reminders would otherwise silently not
  fire / not survive reboots.
- **`reminder_scheduler.dart` — the brains.** Reads the whole database with
  **cross-tank one-shot queries** (deliberately not the active-tank-scoped UI
  providers; soft-deleted tanks are excluded for free by the U10 read filter),
  computes every due event in a rolling **14-day horizon** via the pure domain
  math, coalesces per (tank, kind, day) — the tank is named in the title only
  when more than one tank exists — and hands ≤ 50 `PlannedNotification`s to
  the sink. Notification strings are rendered at schedule time through
  `lookupAppLocalizations` (stored app language, falling back to the system
  locale, then English), so they localize without a BuildContext. Triggers:
  post-first-frame + every resume (`main.dart`), plus a drift `tableUpdates`
  listener over the reminder-relevant tables debounced ~2 s — every launch
  recomputes everything, so the design is self-healing. `resync()` is
  single-flight with a dirty re-loop. Trade-off accepted by design: local
  notifications only exist while scheduled ahead, so a user who doesn't open
  the app for 14+ days stops getting reminders (the in-app due chips catch up
  instantly). Notification payloads carry `{tankId, route}` as JSON;
  `handleReminderPayload` activates the tank (if it still exists) and
  navigates — `/add-reading` for testing, `/?tab=dosing` / `/?tab=actions`
  for the others; a cold-start tap is replayed via
  `getNotificationAppLaunchDetails` after the first frame.

## State layer (`lib/app/providers.dart`)

All app state is Riverpod providers over the singleton `dbProvider`. Two
provider shapes are used deliberately: **every DB read is a `StreamProvider`**
wrapping a Drift watch stream (the UI reacts to any DB change with no manual
invalidation), while **derived values are plain memoized `Provider`s**
(`unitPrefsProvider`, `localeProvider`, `tankTrendsProvider`,
`tankHealthProvider`, and every per-key settings provider) that Riverpod
re-runs only when a watched input changes — never on a mere widget rebuild.

**All settings ride one query** (T4): `settingsMapProvider` is the single
`StreamProvider` over the whole settings table (`AppSettings.watchAll()`,
deduped with `mapEquals`), and each public settings provider
(`tempUnitProvider`, `trendWindowProvider`, `lastBackupAtProvider`, …) is a
plain `Provider<AsyncValue<T>>` `select`ing its key out of the map and decoding
it with the same static `AppSettings.decode*` function the stream facade uses.
A settings write (e.g. the auto-backup timestamp) re-runs one SQL query instead
of ~14 `watchSingleOrNull`s, and `select`'s equality check means only the
watchers of the key that actually changed are notified.

**Tank-scoped providers are family-backed** (#20): each public tank-scoped
provider (`trackedParametersProvider`, `tankReadingsProvider`,
`recentReadingsProvider`, `waterChangesProvider`, `carbonChangesProvider`,
`equipmentCleaningsProvider`, `dosingEntriesProvider`,
`dosingHistoryProvider`, `paramReadingsProvider`, `ratioSettingsProvider`,
`readingTemplatesProvider`, `maintenanceSchedulesProvider`) is a plain
`Provider<AsyncValue<…>>` delegating to a
private **autoDispose `StreamProvider` family keyed by tank id**. Switching the
active tank swaps to a fresh family instance, so consumers briefly see
loading/empty instead of the previous tank's rows flashing under the new tank's
name (a rebuilt non-family StreamProvider keeps its previous value while the
new stream loads); the old tank's instance loses its only listener and its live
query is disposed. Consumers are unaffected — `ref.watch` yields the same
`AsyncValue` either way.

**Stream emissions are deduplicated** (T2): Drift invalidates watch queries at
*table* granularity and re-emits a freshly built (identity-unequal) list even
when the result is unchanged — e.g. a write for another tank. Every list/map
stream above is wrapped in `.distinct(listEquals/mapEquals)` so an identical
re-emission never becomes a new `AsyncValue`, and the derived results
(`TrendResult`, `TankHealth`) are value-equal so an unchanged recompute doesn't
notify watchers either (Riverpod 3 filters updates with `==`). Net effect: a
write only rebuilds the widgets whose data actually changed.

Beyond those internal families only the two full-series wrappers —
`tankReadingsProvider` and `paramReadingsProvider` (T3) — use `autoDispose`:
their unbounded live queries exist only while a chart screen watches them.
The rest of the state is small and single-user, so those providers simply
live for the app's lifetime (pairing with the home shell's `IndexedStack`,
which keeps tab widget state alive too), and the permanent wrappers keep the
*active* tank's data warm for `ref.read` call sites.

**The full readings history is not kept live** (T1). `tankReadingsProvider`
streams the tank's *entire* readings table — a query whose per-write re-run
cost grows unboundedly with years of data (Drift invalidates at table
granularity, so every saved reading re-materializes the whole result). Its
only consumer is the comparison view's charts, so its wrapper is
`autoDispose`: the unbounded query lives only while that tab is on screen.
Everything on the dashboard path — parameter tiles, ratio-card headlines,
`tankTrendsProvider`, `tankHealthProvider` — instead watches
`recentReadingsProvider`, which caps the stream at the newest
`kRecentReadingsPerParam` (40) readings *per parameter*
(`watchRecentReadingsPerParam`, a `ROW_NUMBER()` window function riding
`idx_readings_tank_param_taken`), enough for the latest value + change (2),
the health score's latest-per-parameter (1) and the hybrid trend window
(`kTrendMaxWindow` readings or everything within `kTrendMinSpanDays`,
whichever is more — 40 allows ~8 measurements/day over the 5-day span);
the ratio headline reads only the last two merged series points, which
can only ever carry each parameter's latest readings, so the cap is exact
there too. Per-parameter full series (history/ratio/dose-calculator screens)
stay on `paramReadingsProvider`.

Consumers read the stream providers as `.value ?? const []`, so a failed DB
query would otherwise render as "no data". `ProviderErrorObserver`
(`lib/app/provider_errors.dart`, installed on the root `ProviderScope` in
`main.dart`) closes that gap: every provider failure — build throw or
Stream/Future error emission — is logged via `FlutterError.reportError` and
surfaced as a localized SnackBar through `MaterialApp.router`'s
`scaffoldMessengerKey`, rate-limited (one per minute) because a single broken
query cascades through the derived providers and riverpod's automatic retries.

**Startup pre-warm is time-bounded.** `main()` awaits the first
`settingsMapProvider` value (which carries the stored locale override) before
`runApp` so the first frame renders in the stored language (and the database
open/migration is front-loaded), but only up
to a 3 s timeout: platform-channel calls made before the first frame can hang
forever on some devices (flutter/flutter#72872), which would freeze the app on
the native splash screen. On timeout the app starts in the system locale and
snaps once the value arrives. For the same reason `_documentsDir()` in
`database.dart` retries `getApplicationDocumentsDirectory()` with a per-attempt
timeout — `LazyDatabase` caches its open future, so a single stalled pre-frame
call must not leave the database permanently unopenable.

The graph:

- `tanksProvider` (all tanks), `activeTankIdProvider` (persisted), `activeTankProvider`
  (resolves id → tank, falls back to first tank).
- `trackedParametersProvider`, `tankReadingsProvider` (newest-first, full
  history — comparison view only, autoDispose), `recentReadingsProvider`
  (newest `kRecentReadingsPerParam` per parameter — dashboard/trends/health, T1),
  `paramReadingsProvider(paramKey)` family (oldest-first, chart-friendly,
  autoDispose),
  `waterChangesProvider`, `carbonChangesProvider`, `equipmentCleaningsProvider`
  (all newest-first), `dosingEntriesProvider` (dashboard order).
- Unit prefs: `tempUnitProvider`, `salinityUnitProvider`, `volumeUnitProvider`,
  combined `unitPrefsProvider`.
- `localeCodeProvider` (raw stored code; reads as `'system'` while the stream is
  still loading) → `localeProvider` (`Locale?`, null = follow system) — a
  two-stage mapping so MaterialApp's `locale:` stays null unless the user has
  explicitly picked a language.
- `chartRangeProvider` — shared time range (`7d`/`30d`/`90d`/`All`, default `30d`)
  applied to *all* graphs.
- `trendEnabledProvider` (default on) / `trendWindowProvider` (default
  `kTrendDefaultWindow`) / `trendHorizonProvider` (default `kTrendDefaultHorizon`)
  — the Trends feature toggle, window size, and dashboard forecast horizon.
- `tankTrendsProvider` — `Map<paramKey, TrendResult>` for the active tank. **The
  trend cache:** a plain `Provider` derived from the two trend settings +
  `trackedParametersProvider` + `recentReadingsProvider`; Riverpod memoizes it and
  re-runs `computeTrend` only when those inputs change, never on a widget
  rebuild. Empty when trends are off or no param has `window` readings yet.
- `tankHealthProvider` — `TankHealth` for the active tank. Like `tankTrendsProvider`,
  a memoized plain `Provider` derived from `trackedParametersProvider` +
  `recentReadingsProvider`; collapses each parameter's latest reading + bounds into
  the overall score/band/grade via `computeTankHealth`.
- `healthDisplayProvider` — `HealthDisplay` (both / badge / off, default both):
  how much of the tank-health feature to surface. `showCard` gates the dashboard
  card, `showBadge` gates the compact app-bar badge.
- `settingsProvider` — the typed `AppSettings` facade instance (see Data layer);
  all settings reads/writes flow through it.
- `tourSeenProvider` — reactive `tour_v1_seen` flag; drives the first-run tour
  and Settings → "Replay tour".
- `dosingHistoryProvider` — all dose segments (active + ended, newest first)
  for the history timeline. `ratioSettingsProvider` — per-tank
  `Map<RatioKind.name, RatioVisibility>` for ratio-card visibility/order/bounds.
- `autoBackupEnabledProvider` / `autoBackupIntervalProvider` /
  `lastBackupAtProvider` — see Data → Automatic backup.
- Reminders: `remindersTestingProvider` / `remindersDosingProvider` /
  `remindersMaintenanceProvider` (master switches, default off) +
  `reminderTimeProvider` (delivery time) ride the settings map;
  `maintenanceSchedulesProvider` (tank family) feeds the schedule screen, and
  the derived `maintenanceDueProvider` joins it with the three action-log
  streams into the Actions-tab due chips (`{schedule, DueStatus}` per plan,
  recomputed live when an action is logged). `reminderNotificationsProvider` /
  `reminderSchedulerProvider` hold the platform wrapper and the background
  scheduler (see Data → Reminders).
- `appVersionProvider` — `FutureProvider` over `package_info_plus`; feeds the
  About box so the version is never hardcoded.

## App entry & lifecycle (`lib/main.dart`)

`main.dart` is a `ProviderScope` around `MaterialApp.router`, plus two pieces of
lifecycle wiring that are easy to miss:

- **Auto-backup triggers.** The root widget is a `WidgetsBindingObserver`;
  `runAutoBackupIfDue(db)` fires once after the first frame and again on every
  `AppLifecycleState.resumed`. Both calls are fire-and-forget — a failed backup
  must never block or crash the UI (the schedule simply retries on the next
  launch/resume) — but failures are logged via `FlutterError.reportError` and
  persisted by the backup layer (`last_backup_error_at`, surfaced in Settings),
  never silently swallowed.
- **`Intl.defaultLocale` is set inside MaterialApp's `builder`**, not in
  `initState`: the builder runs after Flutter has resolved the effective locale
  (and re-runs when it changes), so `DateFormat` immediately renders dates in a
  newly selected language without an app restart.
- **Reminder wiring** (`_initReminders`, post-first-frame — the notification
  plugin's init is a platform-channel call, and those can hang before the
  first frame, flutter/flutter#72872): initializes the plugin with the tap
  handler, starts the scheduler's table listener, plans the initial
  notification set, and replays a cold-start notification tap. Every resume
  also `resync()`s, refreshing the 14-day scheduling horizon.

## Routing (`lib/app/router.dart`)

| Route | Screen |
|-------|--------|
| `/` | Home shell — bottom-nav host for the Measurements (Dashboard), Actions, and Dosing tabs |
| `/tanks`, `/tanks/new`, `/tanks/:id/edit` | Manage / create / edit tanks |
| `/parameters`, `/parameters/:id/edit` | Manage tracked parameters & zone bounds |
| `/add-reading` | Log a batch of readings |
| `/history/:paramKey` | Single-parameter history graph |
| `/ratio/:type` | Ratio history graph (`type` = `po4no3`, `mgca`, `caalk`, or `mgalk`) |
| `/ratio/:type/edit` | Edit a ratio card's per-tank zone bounds |
| `/dosing/edit` | Add / edit a supplement-dosing entry (`extra` = `DosingEntry?`) |
| `/dosing/calculator` | Consumption / dose-adjustment calculator |
| `/dosing/history` | Read-only timeline of all dose segments (active + ended) with permanent-delete |
| `/settings` | Units, language, reminders, backup/restore, automatic backup |
| `/settings/backups` | Manage automatic backups (list / restore / share / delete) |
| `/settings/reminders` | Reminder master switches + delivery time + permission warning |
| `/schedule` | Maintenance schedule (U12): the user-maintained plan list |
| `/calculator/salinity` | Standalone ppt ↔ SG converter |

The Actions log is no longer a standalone route — it is the second tab inside the
home shell (see Features). `/` accepts a `?tab=measurements|actions|dosing`
query selecting a bottom-nav tab — the only URL form a notification tap can
carry; `HomeShell` applies it in `initState`/`didUpdateWidget`.

The two `:id` edit routes treat `state.extra` (the object passed by in-app
`context.push`) as a fast path only: when it is absent — deep link, state
restoration — a `_ResolveById` widget resolves the row by `:id` from
`tanksProvider` / `trackedParametersProvider` and navigates home when the id
doesn't exist, instead of crashing or opening a blank create form.

Unknown routes land on a localized "page not found" screen with a go-home
button (`errorBuilder`) instead of go_router's built-in English-only error
page, and a `/ratio/:type` segment that names no known `RatioKind` redirects
home instead of silently opening the PO₄/NO₃ ratio (T8).

## Features (`lib/features/`)

### Home shell (`home/home_shell.dart`) — `/`

`HomeShell` is the app's root scaffold. It hosts the three primary peer
destinations — **Measurements** (the dashboard), **Actions**, and **Dosing** —
behind a bottom `NavigationBar`, swapping only the body via an `IndexedStack` so
each tab keeps its scroll/state. The **app bar is shared** across all tabs: the
`TankSelector` (every tab is tank-scoped, and the bottom-nav label already names
the current screen) plus the manage-parameters and settings buttons, so the
active tank and settings are always reachable. The **FAB is per-tab**: "Add
reading" on Measurements, "Add action" (`showAddActionSheet`) on Actions, and
"Add supplement" (pushes `/dosing/edit`) on Dosing. With no tanks, the bottom bar
and FAB are hidden and `NoTanksView` is shown. The tab screens expose their
bodies (`DashboardBody`, `ActionsBody`, `DosingBody`) and the shell composes them.

**First-run feature tour:** `HomeShell` registers a `showcaseview` `ShowcaseView`
(in `initState`, unregistered in `dispose`) and spotlights the less-obvious
top-bar elements once, each wrapped in a `Showcase` with a localized
title/description and Next/Skip actions. Because the dosing-history and
dose-calculator icons only render on the Dosing tab, the tour runs in **two
phases** tracked by `_tourPhase`: phase 1 on the Measurements tab (`TankSelector`
→ compare/grid toggle → manage-parameters), then `onFinish` switches to the
Dosing tab and starts phase 2 (dosing history → the dose calculator) as its final
steps; finishing or skipping phase 2 returns to the Measurements tab. It auto-starts (after the first frame)
only when a tank exists and the `tour_v1_seen` setting is unset, forcing the
Measurements tab first. `tour_v1_seen = 'true'` is persisted (`_markTourSeen`)
**only when the tour actually ends** — phase 2's `onFinish` or a dismiss — not at
start, so a tour interrupted by backgrounding/rotating/killing the app replays on
the next launch; an in-session `_tourStarted` guard prevents a duplicate start
meanwhile. **Settings → "Replay tour"** resets the flag to
`'false'` and returns to `/`; `tourSeenProvider` is reactive, so the shell
re-runs the tour. Every action icon also carries a localized `tooltip`
(long-press / accessibility).

### Deletion & undo conventions (cross-cutting)

Destructive affordances follow one rule of thumb — **frequent, low-stakes
deletes act immediately and offer an Undo SnackBar; rare or irreversible ones go
behind a confirmation dialog**:

- Readings and action-log rows (water/carbon/cleaning): swipe deletes at once
  and the SnackBar's Undo re-inserts the exact row (grouped readings first ask
  the one-vs-all question).
- Stopping a supplement (Dosing-tab swipe or the edit screen's Stop button)
  acts immediately with an Undo SnackBar (U10): the stop is already a soft end
  (segment retained as history) and Undo writes the captured pre-stop row back
  (`restoreDosingEntry`). No confirm dialog. The SnackBar goes through the
  app-level messenger, so it survives the edit screen popping.
- Deleting a tank — the largest possible loss — gets **both**: the confirm
  dialog stays, then `softDeleteTank` + a 7 s Undo SnackBar
  (`persist: false` — an action otherwise makes a SnackBar persist forever on
  current Flutter). Undo restores the tank (and the active slot if it held
  it); any other close of the SnackBar finalizes via `hardDeleteTank`, and a
  startup sweep (`purgeDeletedTanks`) catches process kills mid-window.
- Hard deletes with no undo (a dosing-history record, restoring a backup over
  live data, deleting a backup file) are irreversible and always confirm
  first — never undo-after-the-fact.

### Dashboard (`dashboard_screen.dart`) — Measurements tab

- `DashboardBody` renders the parameter grid for the active tank; the
  surrounding chrome (app bar with `TankSelector`, bottom nav, FAB) is owned by
  `HomeShell`.
- A `CustomScrollView` whose first sliver is the **tank-health card**
  (`TankHealthHeader`, `widgets/tank_health_badge.dart`) — a ring score + grade +
  "N to watch", tappable to a breakdown sheet grouping parameters by zone, each
  row linking to its history. The card scrolls with the tiles. A compact
  `TankHealthBadgeCompact` also sits beside the tank name in `TankSelector`.
  `healthDisplayProvider` (Settings → Dashboard) chooses badge & card / badge
  only / off. Both read `tankHealthProvider`.
- One grid mixing `_ParameterTile`s (enabled tracked params) and `_RatioTile`s
  (visible ratio cards), ordered together by a **shared display order**
  (`TrackedParameters.displayOrder` and `RatioVisibilities.displayOrder` live in
  the same integer space). Both tile types are the same size/layout: latest value
  **colored by its zone**, a trend indicator (delta vs. previous), and a relative
  timestamp; tapping opens the parameter history or `/ratio/<kind>`. Measurement
  tiles also show a `TrendChip` forecast when a zone crossing is due (see Trend
  detection); ratio tiles do not.
- A ratio tile shows whenever its card is visible (per settings), regardless of
  whether a value can be computed yet: with no computable ratio — a parameter is
  missing or the denominator is zero, so `computeRatioSeries` is empty — the tile
  shows **"No readings"**, exactly like a measurement tile before its first
  reading. When the latest pair of readings is more than `kRatioMaxSkew` (30 d)
  apart (`latestRatio` returns null while the series isn't empty), the headline
  value renders **muted** (hint color) instead of zone-colored — it no longer
  describes a single current tank state. Visibility + order are set in the **Manage Parameters** screen
  (ratios and measurements share one reorderable list) and stored **per tank** in
  `RatioVisibilities` (`ratioSettingsProvider` → `Map<RatioKind.name,
  RatioVisibility>`, resolved with `ratioRowVisible` / `ratioRowOrder`).
- Empty states: `NoTanksView` (first-run welcome: a language selector +
  add-aquarium prompt — lets the user pick their language before creating a tank
  without opening Settings) and `_NoParamsView`.
- **Compare graphs view** (`dashboard/comparison_view.dart`, `ComparisonBody`):
  an app-bar toggle on the Measurements tab (state `_compare` in `HomeShell`)
  swaps the tile grid for a vertical stack of trend charts — one per enabled
  tracked parameter, **in the same `displayOrder`** as the grid. Every chart is
  pinned to **one shared time window** (`minX`/`maxX` = range start → now; for
  "All" the oldest reading across params) so the X axes align and a vertical
  time-slice reads all parameters at once; each chart keeps its own auto Y scale,
  zone bands, and water-change markers (which line up across charts). Only the
  last chart draws date labels (alignment is fixed by the constant left-axis
  width). Each chart's header shows its newest **in-range** reading (zone-colored
  from that value), so the number always matches the chart below; empty-in-range
  params show no header value and a muted placeholder to preserve order. Tapping a
  chart opens `/history/:paramKey`. Measurements only — ratio cards are not
  included.

### Trend chart widget (`widgets/trend_chart.dart`)

Shared `fl_chart` building blocks used by both the history and comparison views:
`ChartRange` enum + `chartRangeFromLabel`/`chartRangeLabel`, the
`ChartRangeSelector` (writes `chartRangeProvider`), and `TrendChart` — a
per-parameter line chart with **zone bands** drawn as `RangeAnnotations`
(green/amber/red regions from the param's bounds) and water-change markers. Band
rendering is defensive: the green band falls back to the matching amber bound
(never the chart edge) so a one-sided green bound can't paint over the red band,
and any band that would come out with `y1 >= y2` (inverted/empty) is skipped, so
inconsistent or legacy bounds never produce overlapping/misleading regions. When
given explicit `minX`/`maxX` it pins to that window (comparison alignment);
otherwise it derives the window from the data (a single reading is centered in
a 12-hour window rather than pinned to a chart edge).
`showBottomTitles` controls whether the date axis is drawn.

Touch interactions: `chartLineTouchData(context, formatValue:, noteFor:)` is
the shared tooltip for all line charts (including the ratio graph) — theme
inverse-surface colors (readable in both brightnesses, unlike fl_chart's
default), a bold locale-formatted value + unit line, a localized timestamp
line, and (TrendChart only) the reading's note collapsed to one truncated
italic line. **Note markers:** readings with a note draw a ringed
tertiary-colored accent dot (same "annotation" color family as the
water-change lines; shape tells them apart) and stay visible even on dense
series where regular dots are hidden (> 40 points). **Zoom/pan** (`zoomable`,
history screen only): horizontal pinch-zoom (max 10×) + pan via fl_chart's
`FlTransformationConfig`; double-tap resets. Comparison-view charts stay
non-zoomable — they must keep their shared aligned time window.
**Action markers** (`markers` + `showMarkerLegend`): see
`features/actions/action_markers.dart` under the Actions section.

### History graph (`history/history_screen.dart`)

Per-parameter history built on the shared `TrendChart` (zone bands + water-change
markers) with the shared `ChartRangeSelector`. Values are presented in the user's
units while bounds/zones stay canonical. Below the chart is the readings list:
tap a row to edit its **value and date/time** (`_ReadingDialog`, the date/time
picker mirroring the actions log); when the moved reading belongs to a batch of
sibling measurements, the user is asked whether to re-time only that value
(detaching it from the batch) or all values entered together
(`updateReadingGroupTime`). Swipe-left deletes: a standalone reading is removed
immediately with an **"Undo" SnackBar** (`_showUndo` re-inserts it, preserving
the batch id); a grouped reading still prompts the one-vs-all choice
(`deleteReadingGroup`) first, then offers the same undo. The edit dialog also
carries a **Delete** button that reuses the exact swipe flow — the accessible
path for screen-reader/switch-access users, mirrored by Delete in the action
dialogs and Stop on the dosing edit screen.

### Trend detection (`domain/trend.dart` + `widgets/trend_view.dart`)

Layered on top of the zone bands: where the bands say *where a value is*, the
trend says *where it's heading and when it leaves its range*. The math is the
pure `computeTrend` (domain); the per-tank results are cached in
`tankTrendsProvider` (state layer). The fit uses a **hybrid window**: at least
the configured `window` readings *and* at least `kTrendMinSpanDays` (5) of
coverage — when the newest `window` readings span less than that (several
measurements a day), the fit widens to every reading within the span, so
test-kit noise over a few hours doesn't read as a steep per-day slope.
Once-a-day-or-sparser readings keep exactly the `window` newest. Two shared
widgets render a `TrendResult`:
- `TrendCard` — full block under the **history** chart (shown only when a trend
  exists): the per-day rate (`slopePerDay` converted to the display unit via the
  affine `toDisplay(slope) − toDisplay(0)`, signed) plus projected "reaches
  attention/critical zone in ~N d" lines, or a "holding steady / within range"
  note. Independent of the chart range — it always uses the hybrid trend
  window above.
- `TrendChip` — compact forecast on each **dashboard** `_ParameterTile`, shown
  only when a zone crossing is projected within the configurable `horizonDays`
  (`trendHorizonProvider`, default 14): the soonest of attention (amber) /
  act-now (red) with its day estimate, drawn in the matching zone color. The
  horizon gates only this dashboard chip — the history `TrendCard` always shows
  the full projection. A **recovering** value (out of range but heading back
  toward green) carries no forecast, so neither widget warns about it.

Enable/disable, the window size, and the alert horizon live in **Settings →
Trends**; both widgets disappear when the feature is off (the provider returns
an empty map).

### Parameter ratios (`domain/ratio.dart` + `features/ratio/ratio_screen.dart`)

Generic over a `RatioKind` enum (each carries numerator/denominator param keys,
display symbols, and a `RatioDisplay` form). Current kinds: `po4no3` (PO₄ : NO₃,
shown as `1 : N`), `mgca` (Mg : Ca), `caalk` (Ca : Alk), and `mgalk` (Mg : Alk) —
the last three shown as a single number = numerator/denominator to one decimal.
`RatioDisplay` = `oneToN` | `decimal`.
- `latestRatio(numerator, denominator)` → current ratio (= numerator/denominator)
  from the newest reading of each (null if either missing, denominator = 0, or
  the two readings lie further apart than `maxSkew`, default `kRatioMaxSkew` =
  30 d — today's PO₄ against a months-old NO₃ is not a "current" ratio).
- `computeRatioSeries(numerator, denominator)` builds a time series: at each
  timestamp where either parameter was measured, the most recent value of the
  *other* is carried forward, so a point exists whenever both have ≥1 reading.
  Points whose denominator is 0 at that instant are skipped (no
  division-by-zero / NaN on the chart).
- `formatRatioValue(kind, ratio)` renders per the kind's `RatioDisplay`;
  `ratioChartY(kind, ratio)` maps a ratio to its plotted Y (PO₄ : NO₃ plots the
  inverse N). `ratioBreakdown` shows the raw inputs. `formatRatio`/`formatRatioN`
  scale precision to magnitude. Localized labels/titles via `ratioCardLabel` /
  `ratioScreenTitle` in `l10n_helpers.dart`. The single `RatioScreen` renders any
  kind.
- **Health zones:** each `RatioKind` carries recommended red/amber/green
  `defaultBounds` (in displayed-metric space; `RatioKindZones` extension) from
  reef guidance — PO₄ : NO₃ green ≈ 50–150 (a ~100:1 NO₃:PO₄ target), Mg : Ca
  green ≈ 2.9–3.3 (≈3:1), Ca : Alk green ≈ 46–62 (ppm/dKH, calcification balance),
  Mg : Alk green ≈ 150–190 (ppm/dKH). Bounds are **editable per tank** via `RatioEditScreen`
  (`/ratio/:type/edit`), stored on the `RatioVisibilities` row; `ratioBounds(kind,
  row)` resolves the effective bounds (row when set, else defaults).
  `ratioZone(kind, bounds, ratio)` colors the dashboard tile and `RatioScreen`
  draws the same bands as `RangeAnnotations`.
- Adding a ratio = add a `RatioKind` value (with symbols, display form, and
  `defaultBounds`) + its ARB label/title keys.

### Actions log (`features/actions/`)

A single combined log of tank maintenance actions for the active tank, newest
first. Rendered as the **Actions tab** of the home shell.

- `actions_screen.dart` — `ActionsBody` merges `waterChangesProvider` +
  `carbonChangesProvider` + `equipmentCleaningsProvider` into one sorted list
  (`_Entry` sealed type: `_WaterEntry` / `_CarbonEntry` / `_EquipmentEntry`).
  Each row: type icon, type name, value (litres in the display volume unit, or
  grams; none for equipment cleaning), optional note, timestamp; swipe-to-delete
  (`_deleteWithUndo` removes the row immediately and shows an **"Undo" SnackBar**
  that re-inserts it) and tap-the-row-to-edit (a trailing chevron hints at
  tappability). The shell's
  Actions-tab FAB calls the top-level
  `showAddActionSheet`, which opens a bottom sheet to choose which action to add.
  A shared
  `_ActionDialog` (date/time picker + **optional** numeric value with a unit
  suffix + optional note) drives both add and edit for every type; when its
  `valueLabel` is null the numeric field is hidden (equipment cleaning).
  - **Water change**: optional litres (converted to/from the display volume
    unit) + note (e.g. salt brand).
  - **Carbon change**: optional weight in grams + note (e.g. brand).
  - **Equipment cleaning**: date/time + optional note only (e.g. which gear).
- `action_markers.dart` (U6) — all three action types are drawn as dashed
  `VerticalLine`s on the parameter graphs (history + comparison view) via
  `extraLinesData`, so maintenance lines up visually with parameter movements.
  `ActionMarker`/`actionMarkers(...)` flatten the three logs;
  `actionMarkerLines(...)` builds the in-window lines. Each kind has a
  theme-derived color (water = tertiary, carbon = secondary, cleaning =
  outline) **and** a distinct dash pattern, so the types stay apart for
  color-blind users. `ActionMarkerLegend` names the styles actually visible:
  the history chart renders it under the plot (`TrendChart.showMarkerLegend`),
  the comparison view draws one shared legend above its stack. Ratio graphs
  draw no markers (computed series, not measurements).

### Reminders & maintenance schedule (U1/U2/U12)

One reminders subsystem, three sources — the shared shape is *cadence/schedule
+ last-done anchor → due date → in-app chips + notification*. The due math is
`domain/reminders.dart`; scheduling/delivery is Data → Reminders. All
notifications are **opt-in** (Settings → Reminders, three master switches; the
first enable triggers the permission request, and a persistent error-colored
row warns while the system permission is denied — the "last backup failed"
pattern).

- **Testing reminders (U1), elastic.** Each tracked parameter's edit screen
  has a "Remind to test" cadence (preset chips Off/3/7/14/30 d + Custom days,
  validated ≥ 1). The reminder anchors on the parameter's *latest reading*
  (`latestReadingTimesPerParam`) — logging a test resets the timer. Parameters
  due the same day coalesce into one notification ("Time to test: Alkalinity,
  Calcium"); tapping opens `/add-reading` for the right tank. The dashboard
  needs no new chrome — health's "not tested in N d" already covers in-app
  staleness.
- **Dosing reminders (U2), calendar-based.** The dosing edit screen has a
  per-entry "Remind me" switch, enabled only while a dose time is set (a
  cleared time also clears the stored opt-in). Occurrences follow the entry's
  own schedule (daily / every N days from `startedAt` / weekly weekdays) at
  its own `doseTime`; only **active** segments of visible tanks remind.
  Toggling the switch is a cosmetic edit (no new dose segment).
- **Maintenance schedule (U12), elastic + planned.** `/schedule` (calendar
  button in the Actions tab's app bar) lists the tank's user-maintained plans:
  recurring or one-off, for the three logged action types or custom-titled
  tasks. The add/edit sheet picks type (incl. Custom + required title), repeat
  (↔ one-off) with a **repeat-mode dropdown** — every X days / weeks / months
  (interval field), days of the week (weekday chips, ≥ 1 required), or day of
  the month (1–31) — an optional first-due date (`scheduledAt`, required
  for one-offs), a per-plan remind switch, and a note; rows drag-reorder;
  delete and "Mark done" act immediately with an Undo SnackBar restoring the
  captured row verbatim (`restoreMaintenanceSchedule` — U10's cheap-restore
  convention; a completed one-off is retired the same way). **Typed plans
  advance automatically** when the matching action is logged anywhere in the
  app (anchor = newest action-log row); custom plans stamp their own
  `lastDoneAt`. The Actions tab shows a horizontally scrollable **due-chip
  row** above the log (`maintenanceDueProvider`, most-urgent first, overdue in
  error color): a typed chip opens the pre-selected add-action dialog, a
  custom chip marks the task done.
- Testing/maintenance notifications arrive at the configurable reminder time
  (default 09:00) on the due day; an overdue item is not re-notified — the
  chips carry the overdue state persistently. Dosing notifications use each
  entry's own time.

### Dosing (`features/dosing/`) — Dosing tab

An information-only, per-tank **supplement-dosing plan** (a standing regimen, not
a log of discrete doses). It is a chain of **dated segments** per entry: only
`active` segments are shown and used; adjusting a dose or stopping a supplement
retains the prior period as history (see `DosingEntries` / `DosingState`).
Rendered as the **Dosing tab** of the home shell.

- `dosing_screen.dart` — `DosingBody` lists the active tank's `dosingEntriesProvider`
  rows (**active segments only**; `watchDosingEntries` filters on `state`). Each row:
  a chemistry icon, the product name with a target-element chip, a `vendor · program`
  line, and a localized dosage/schedule summary (`dosingDetailLine`) — or "No dosage
  set" when neither is recorded. Tap a row to edit; **swipe-left to stop**
  (`_confirmStop` → `stopDosingEntry`, a soft-end that keeps the row as history, not
  a hard delete); drag the handle to reorder (a `ReorderableListView` with explicit
  drag handles so swipe and drag don't clash, persisting the new order via
  `reorderDosingEntries`). New entries are appended with `max(displayOrder)+1`.
  Helpers here also parse/format the stored weekday list and `HH:mm` time using
  `MaterialLocalizations` (device 12/24-h + locale).
- `dosing_edit_screen.dart` — `DosingEditScreen` (route `/dosing/edit`, `extra` =
  `DosingEntry?`) is the add/edit form. It cascades **Vendor → Product → Element**
  off `kSupplementVendors`: picking a catalog product auto-fills its element and
  default unit; an "Other…" choice in either dropdown swaps in a free-text field
  (custom entries persist `productKey = null`). Optional **Dosage** = amount +
  unit (ml/g) + basis (per day/dose); optional **Schedule** = frequency
  (daily / every N days / weekly with weekday chips) + time. On save: a new entry
  is inserted; editing an existing one **branches on `_doseAffectingChanged`** — a
  dose-affecting change (product, element, amount/unit/basis, frequency/interval/
  weekdays) calls `supersedeDosingEntry` (ends the old segment, starts a new active
  one keeping `displayOrder`), while a cosmetic-only change (display name, note,
  time) updates in place via `updateDosingEntry`. It keeps the stable `productKey`
  and a denormalized vendor/program/product snapshot.
- **Display names resolve live.** `DosingBody` shows vendor/program/product via
  `resolveSupplementNames(...)`: when `productKey` still matches a catalog
  product it uses the **current** catalog names (so a YAML rename/move is
  reflected on existing entries), falling back to the stored snapshot only for
  custom or orphaned entries. The target element stays the stored, user-editable
  value.
- `dosing_history_screen.dart` — `DosingHistoryScreen` (route `/dosing/history`,
  opened from a **history icon in the Dosing tab's app bar**, contextual to
  `_index == 2`) is a read-only timeline of **all** segments for the active tank
  (`watchDosingHistory` / `dosingHistoryProvider`, active + ended, newest first).
  Each row reuses `dosingDetailLine` for the dosage and shows the segment's period
  (`Since {date}` for active, `{from} – {to}` for ended). A trailing delete
  **permanently** removes a record entered by mistake (`deleteDosingEntry`, a real
  hard delete — distinct from the reversible `stopDosingEntry`), behind an
  irreversible confirmation that warns when the record isn't the most recent for
  its element.

**Future-proofing (decided up front):** dose amounts are stored canonically (ml/g
only — no unit-preference conversion), `elementKey` is always a real
`Readings.paramKey`, and every catalog product carries a stable `key` plus a
`strength` potency slot — so a later phase can log actual doses and compute
element consumption by joining entries → product → potency → readings. The plan's
schedule is purely descriptive and is **not** the source of truth for that math.
The Fauna Marin Balling Light products now carry verified `strength` values
(from the vendor's dosing chart); the dose calculator (below) consumes them.

### Dose calculator (`features/dosing/dose_calculator_screen.dart`) — `/dosing/calculator`

Opened from the Dosing tab's app-bar calculator icon (`HomeShell`, shown when
`_index == 2`). Estimates an element's real daily consumption and proposes the
maintenance dose, **ignoring water changes** (only dosing is assumed to add the
element back). The math is the pure `domain/dose_calculator.dart`; the screen is
just inputs + a result card and stores nothing.

- **Inputs, all editable, mostly pre-filled:** element (from `kDosingElementKeys`,
  default = first dosing-plan element); measurement window (a *local* `ChartRange`
  selector that does **not** touch the shared `chartRangeProvider`); tank volume
  (from `activeTankProvider.volumeLiters`, shown/parsed in the user's volume unit);
  current daily dose (Σ `dailyEquivalentDose` over the element's plan entries, in
  the entry's ml/g); and supplement strength (catalog `strength[element]` when a
  plan entry's product has it, else a vendor reference dose → `potencyFromReference`,
  with reference volume converted to litres).
- **Output card:** measured change/day, consumption/day, current dosing input/day,
  suggested daily dose + adjustment, and a `DoseCalcStatus` guidance banner
  (stable / increase / decrease / overdosing / no-dose-needed / needs-potency /
  insufficient-data). Works with no dosing: consumption = the measured drop, any
  consumption recommends starting a dose (`increase`), and a rising element with
  nothing dosed reads `noDoseNeeded` — only an actively dosed rising element is
  flagged as over-dosing.
- **Dose-changed warning (warn-only).** The slope math assumes the current dose
  held for the whole window. `_doseChangedInWindow` takes the latest `startedAt`
  over the element's active segments and, if some readings in the window predate it,
  shows an info notice (`doseCalcDoseChanged`) that the result mixes two dose
  regimes. It does **not** clamp the window (that could drop below two readings).
  Single-element for now; multi-element per-entry potency is a later phase.

### Manage parameters (`manage_parameters_screen.dart`)

One reorderable list (`_DashItem` sealed type: `_ParamItem` | `_RatioItem`)
mixing tracked parameters and ratio cards, ordered by their shared
`displayOrder`. Toggle which parameters are tracked / which ratio cards are
shown, drag to reorder either, and edit a parameter's zone bounds
(`ParameterEditScreen`). Reordering writes the new combined order back via
`applyDashboardOrder` (params → `TrackedParameters`, ratios →
`RatioVisibilities`). Each row has an edit button: parameters open
`ParameterEditScreen`, ratios open `RatioEditScreen` (per-tank zone bounds).
Both editors render their four bound fields through the shared
`ZoneBoundsEditor` widget ([lib/widgets/zone_bounds_editor.dart](lib/widgets/zone_bounds_editor.dart)),
which owns the controllers, draws the legend + zone-colored fields, and centralizes
the order (`amberLow ≤ … ≤ amberHigh`) and amber-implies-green pairing rules; each
screen keeps only its own seeding (display-unit vs. ratio-metric) and save target.
Re-applying a setup-type preset is available.

### Add reading (`add_reading_screen.dart`)

Enter several parameters at once for a single timestamp (group). Inputs accept
values in the user's display units and are converted to canonical on save. The
timestamp is chosen via the shared `pickPastDateTime` helper (in
[l10n_helpers.dart](lib/l10n/l10n_helpers.dart)) — also used by the reading-edit
and actions dialogs — which caps the date/time picker at the current minute so a
reading/action can **never** be dated in the future (a future timestamp would
skew trends/health/"time ago" and be clipped off charts pinned to `now`), and
aborts (returns null) when either the date or the time step is cancelled. The
downstream consumers additionally tolerate a moving clock via `clock.dart`
(`ageSince`/`daysSince`).

**Test sets (U9)** — a horizontal single-select `ChoiceChip` row under the
timestamp card: `[All] [set…] [+ new]`, backed by `readingTemplatesProvider`
(the `ReadingTemplates` table). Selecting a set narrows which parameter rows
are *shown*; it is strictly a view filter — controllers persist across chip
switches and `_save` always receives the full enabled-parameter list, so a
typed value hidden by the current selection is still saved (the
"Saved N readings" SnackBar reports the true count). The tapped chip is
persisted per tank (`last_reading_template` setting) and preselected on the
next visit; a dangling stored id silently falls back to All. A set whose
key intersection with the enabled parameters is empty renders a hint instead
of rows. The `+` chip opens the create sheet (`test_set_sheets.dart`) with the
currently-typed parameters pre-checked; an app-bar checklist action opens the
manage sheet (list + edit/delete/drag-reorder — the accessible path, chip
long-press being only a shortcut to edit, #45 precedent). Editing preserves a
set's keys that are currently disabled/untracked (shown nowhere, never
dropped); deleting is a plain confirm with no undo (recreating a set is cheap
— deliberate exception to the undo conventions above).

### Tanks (`tanks_screen.dart`)

Create/edit/delete tanks (delete = confirm dialog + soft delete + Undo
SnackBar; see the deletion & undo conventions above). Editor converts volume
to/from the display unit and
captures optional free-text `vendor` and `model` (single line) plus multi-line
`notes`. The setup type drives which parameters are seeded. The list and the
Settings → About row use the `Icons.waves` glyph for an aquarium (tinted with
the primary colour for the active tank).

### Settings (`settings_screen.dart`)

Unit selectors (temp/salinity/volume), language selector, a **Trends** section
(on/off switch + recent-readings window selector `kTrendMinWindow`..`kTrendMaxWindow`
+ alert-horizon selector within `kTrendMinHorizon`..`kTrendMaxHorizon`),
a **Reminders** link (`/settings/reminders` — see Reminders & maintenance
schedule above),
and **Backup & Restore** (export → share sheet, import → file picker → full replace), plus an
**Automatic backup** toggle + frequency and a link to the **Manage backups**
screen (see Data → Automatic backup). Link to the salinity calculator. The About box shows the live app version via
`appVersionProvider` (`package_info_plus`), never a hardcoded string.

### Salinity calculator (`calculator/salinity_calculator_screen.dart`)

Standalone ppt ↔ SG converter, independent of stored data.

## Internationalization

The app is **fully localized — no user-facing string is hardcoded.** See
`CLAUDE.md` for the hard rules.

- Source strings: `lib/l10n/app_<locale>.arb`; template is `app_en.arb`. Config
  in `l10n.yaml` (output to `lib/l10n`, non-synthetic).
- Languages: en (template), cs, de, pl, ru — every key kept in sync across all
  files; non-template ARBs need no `@` metadata but must contain every key and
  placeholder or `gen-l10n` errors.
- Domain labels (parameter names/help, setup types, zones) are localized through
  `extension L10nDomain` in `lib/l10n/l10n_helpers.dart` (e.g. `volumeWithUnit`,
  `litersSuffix`/`gallonsSuffix`).
- `main.dart` sets `Intl.defaultLocale` from the resolved locale so `DateFormat`
  renders dates in the selected language. Locale stored in `Settings` (`locale`:
  `system`/`en`/`cs`/…). Adding a language = drop in another `app_xx.arb`.
- After editing ARBs, run `flutter gen-l10n` (or build) and re-analyze.

## Build & test

- Codegen after schema changes: `dart run build_runner build` (the newer
  build_runner dropped `--delete-conflicting-outputs`).
- Regenerate the supplement catalog after editing `lib/domain/supplements.yaml`:
  `dart run tool/gen_supplements.dart` (validates + writes
  `supplement_catalog.g.dart`).
- Localization codegen: `flutter gen-l10n`.
- Tests (`flutter test`): domain — `test/zones_test.dart`,
  `test/presets_test.dart`, `test/units_test.dart`, `test/ratio_test.dart`,
  `test/parameter_catalog_test.dart`, `test/setup_type_test.dart`,
  `test/supplement_catalog_test.dart`, `test/dose_calculator_test.dart`,
  `test/trend_test.dart`, `test/health_score_test.dart` (tank-health banding,
  weighting, staleness), `test/zone_bands_test.dart` (chart band geometry);
  data — `test/database_test.dart`, `test/migration_test.dart` (multi-version
  upgrade idempotency), `test/backup_test.dart`, `test/auto_backup_test.dart`,
  `test/settings_test.dart`, `test/dosing_history_test.dart`,
  `test/reminders_test.dart` (due math), `test/reminder_scheduler_test.dart`
  (planning against a fake notification sink); plus the widget
  tests (e.g. `test/zone_chip_test.dart`, `test/reminder_widgets_test.dart`).
- `test/tool/seed_sample_data.dart` is a *tool in test clothing*: running
  `flutter test test/tool/seed_sample_data.dart` generates a seeded
  `reeftracker.sqlite` at the current schema, for pushing into an emulator's
  `app_flutter/` via `adb run-as` — the fastest way to demo or regress against
  realistic data.
- **Testing convention:** chart/health/zone logic lives in pure, Flutter-free
  functions (`domain/health_score.dart`, `zoneBands` in `domain/zones.dart`) so
  it can be unit-tested without a widget; the thin widgets (`trend_chart.dart`)
  only map that output onto `fl_chart`. Widget tests pump through the shared
  `test/support/pump.dart` helper (ProviderScope + MaterialApp + l10n delegates);
  DB-touching tests use `NativeDatabase.memory()` with a faked `path_provider`.
- **CI (`.github/workflows/ci.yml`):** every push/PR to `master` runs two jobs
  on `ubuntu-latest` (Flutter pinned to 3.44.3; superseded runs on the same ref
  are cancelled). The main job runs `dart format --set-exit-if-changed`, a
  regenerate-and-diff guard for all committed generated sources
  (`flutter gen-l10n`, `dart run build_runner build`, then
  `dart run tool/gen_supplements.dart` — build_runner deletes
  `supplement_catalog.g.dart` as an unclaimed output, so the supplement
  generator must run after it), `flutter analyze`, and
  `flutter test --coverage` with the lcov file uploaded as an artifact. A
  second job builds a **debug** APK on JDK 21 (Temurin) to exercise the
  Android platform layer — debug needs no `key.properties` and works with the
  pinned plugins. `flutter analyze` runs **without** `--fatal-infos` (some
  test files carry pre-existing info-level lints) and fails on
  warnings/errors — keep that baseline clean, and keep the whole repo
  `dart format`-clean.

### OneDrive & the build scripts (`scripts/`)

The repo lives inside OneDrive, which locks Flutter's churning build files. The
volatile directories (`build`, `.dart_tool`, `android/.gradle`,
`android/.kotlin`) are therefore **NTFS junctions** pointing outside OneDrive
(default target `C:\Android\reefbuild\ReefTracker\`; override with the
`REEFBUILD_ROOT` env var).

- **Never run `flutter clean` here** — it deletes the junctions, and the next
  build recreates them as real in-OneDrive folders: the file locks return and
  release artifacts land in the stale in-OneDrive location. Use
  `scripts\safe-clean.ps1` instead (empties the caches, keeps the junctions).
- `scripts\build-release.ps1` — heals the junctions first, then builds and
  verifies the signed release AAB (reported at its real out-of-OneDrive path).
- `scripts\heal-junctions.ps1` — repairs clobbered junctions after an
  accidental `flutter clean`.

See [scripts/README.md](scripts/README.md) for the full junction table and
details.

## Maintaining this document

`DESIGN.md` is the high-level map of the app's design and important features. Keep
it accurate: after any change that alters the design — new/changed tables or
migrations, new screens or routes, new domain rules, new features, or shifts in
the layering/state model — update the relevant section here in the same change.
Skip updates for purely cosmetic or trivial edits that don't change the design
(wording tweaks, styling, refactors with no behavioral/structural effect).

Related documents: [TODO.md](TODO.md) is the audited, severity-rated backlog of
known bugs and improvements — `#N` references in code comments point at entries
there (it cross-references the older numbering some comments still use).
[CHANGELOG.md](CHANGELOG.md) records user-facing changes (update rules in
`CLAUDE.md`); [scripts/README.md](scripts/README.md) documents the OneDrive
build-junction workflow.
