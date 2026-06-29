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
| Persistence        | `drift` over SQLite (`sqlite3_flutter_libs`), code-generated via `dart run build_runner build` |
| Charts             | `fl_chart` |
| Routing            | `go_router` |
| i18n / formatting  | Flutter `gen-l10n` (ARB files) + `intl` |
| Backup I/O         | `share_plus` (export via OS share sheet) + `file_picker` (import) |
| App metadata       | `package_info_plus` (real version/build for the About box) |

## Architecture overview

The codebase is organized into four layers:

```
lib/
  domain/    Pure Dart business rules — no Flutter, no DB. Static app data.
  data/      Drift database, backup encode/decode. The only persistence layer.
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
- `domain/units.dart` owns all conversions and `ParamPresentation`
  (`presentationForKey` / `presentationOf` in `database.dart`) which knows how to
  format/parse a parameter's value for the current prefs.
- **Zone classification always compares canonical values against canonical
  bounds**, so changing display units never changes health colors.

Volume is *not* a tracked parameter — it is a property of a tank
(`volumeLiters`) and of a water change (`amountLiters`). The US gallon is
`3.785411784 L`. Salinity ↔ SG is linear, anchored at 35 ppt = 1.0264 SG @ 25 °C.
Carbon-change weight is stored in **grams** (no unit preference, suffix `g`).

## Domain layer (`lib/domain/`) — static, no DB migrations

| File | Responsibility |
|------|----------------|
| `zones.dart` | `ZoneBounds{amberLow, greenLow, greenHigh, amberHigh}` + `classify(value) → Zone` (green/amber/red/unknown). **Single source of truth for zone color logic.** Any bound may be null = unbounded on that side. Green = `[greenLow, greenHigh]`; amber = just outside green but within amber bounds; red = beyond an amber bound. |
| `units.dart` | Unit enums (`TempUnit`, `SalinityUnit`, `VolumeUnit`), conversions, `UnitPrefs`, and `ParamPresentation` (format/parse). |
| `parameter_catalog.dart` | `kReefParameters` — the master list (temp, pH, salinity, alk, Ca, Mg, NO₃, PO₄, NH₃/₄, NO₂, ORP, K, Sr, I) with default units, plus `kParameterByKey` lookup and `formatParamValue`. |
| `presets.dart` | `kPresets[SetupType][paramKey] = ZoneBounds`. Which keys are present per setup type = the parameters tracked by default for that type. `presetBounds`, `defaultTrackedKeys`. |
| `setup_type.dart` | `SetupType` enum: fishOnly / soft / lps / sps / mixed. Stored as `.name`; `fromName` defaults to `mixed`. |
| `ratio.dart` | Parameter-ratio math + `RatioKind` enum (PO₄ : NO₃, Mg : Ca); see Features. |
| `trend.dart` | Pure, testable drift/trend detection (no Flutter/DB). `computeTrend(points, bounds, window)` → `TrendResult?` (signed `slopePerDay` reusing `dose_calculator.slopePerDay`, `TrendDirection`, and projected `daysToAmber`/`daysToRed` — when the value reaches the green→amber and amber→red bounds it is heading toward). Uses the most recent `window` readings and returns null until that many exist. Tuning consts: `kTrendDefaultWindow`=5, `kTrendMinWindow`=3, `kTrendMaxWindow`=10, `kTrendDefaultEnabled`, plus the forecast-horizon bounds `kTrendDefaultHorizon`=14, `kTrendMinHorizon`=3, `kTrendMaxHorizon`=90 (UI gating only — not used by `computeTrend`). See Features. |
| `dose_calculator.dart` | Pure, testable math for the dose calculator (no Flutter/DB): `slopePerDay` (least-squares change/day over readings), `potencyFromReference` (vendor reference dose → potency per unit per litre), `dailyEquivalentDose` (a `DosingEntry`'s average daily amount from basis + schedule), and `computeDoseCalc` → `DoseCalcResult` (consumption/day + maintenance-dose recommendation + `DoseCalcStatus`). Water changes ignored. See Features. |
| `supplement_catalog.dart` | Model + lookups for the dosing **vendors → programs → products** catalog + `DoseUnit` (ml/g), `DoseBasis` (per day/dose), `DoseFrequency` (daily/everyNDays/weekly) enums. Each `SupplementProduct` has a stable `key` (persisted on dosing entries), a target `elementKey` (a real param key), a default unit, and an optional `strength` potency map reserved for the future consumption calculator. Brand/product names are proper nouns — **not** localized. `kDosingElementKeys` = the param keys offered in the dosing element picker. **The data (`kSupplementVendors`) is generated** — see below. |
| `supplements.yaml` + `supplement_catalog.g.dart` | `supplements.yaml` (commented, hand-edited) is the **source of truth** for the catalog data; `dart run tool/gen_supplements.dart` validates it (unique product keys; every `element`/`strength` key is a real param key; `unit` ∈ ml/g) and generates the `part` file `supplement_catalog.g.dart` (`const kSupplementVendors`). Edit the YAML, never the `.g.dart`. `test/supplement_catalog_test.dart` re-checks the same invariants on the generated catalog. |

## Data layer (`lib/data/`)

### Schema (`database.dart`, generated `database.g.dart`) — **schemaVersion 9**

| Table | Key columns |
|-------|-------------|
| `Tanks` | id, name, setupType, volumeLiters?, startDate?, notes?, vendor?, model?, createdAt |
| `TrackedParameters` | id, tankId (FK cascade), paramKey, unit, enabled, displayOrder, + 4 zone bounds (amberLow/greenLow/greenHigh/amberHigh) |
| `Readings` | id, tankId (FK cascade), paramKey, value (canonical), takenAt, note? |
| `WaterChanges` | id, tankId (FK cascade), changedAt, amountLiters?, note? |
| `CarbonChanges` | id, tankId (FK cascade), changedAt, grams?, note? |
| `EquipmentCleanings` | id, tankId (FK cascade), cleanedAt, note? |
| `RatioVisibilities` | tankId + ratioKey (composite PK), tankId FK cascade, visible, displayOrder, amberLow?/greenLow?/greenHigh?/amberHigh? — per-tank ratio-card visibility, dashboard position (shared order space with `TrackedParameters.displayOrder`), and editable zone bounds; a missing row (or all-null bounds) = visible, ordered last, default zones |
| `DosingEntries` | id, tankId (FK cascade), productKey? (stable catalog id; null = custom), vendor?/program?/product (denormalized display names), elementKey? (real param key), amount?/amountUnit? (canonical ml or g)/basis? (per day/dose), frequency?/intervalDays?/weekdays?/doseTime? (descriptive schedule), note?, displayOrder, createdAt — per-tank supplement-dosing plan (info-only) |
| `Settings` | key (PK), value? — generic kv store |

`Settings` keys in use: `active_tank_id`, `temp_unit`, `salinity_unit`,
`volume_unit`, `locale`, `chart_range`, `auto_backup_enabled`,
`auto_backup_interval`, `auto_backup_keep`, `last_auto_backup_at`,
`trend_enabled`, `trend_window`, `trend_horizon`.

**Migrations** (`MigrationStrategy`): v2 added `Tanks.startDate` via `addColumn`;
v3 added the `WaterChanges` table via `createTable`; v4 added `WaterChanges.note`
(`addColumn`) and the `CarbonChanges` table (`createTable`); v5 added the
`EquipmentCleanings` table (`createTable`, guarded by `_tableExists`); v6 added
the `RatioVisibilities` table (`createTable`, guarded by `_tableExists`); v7
added `RatioVisibilities.displayOrder` (`addColumn`, guarded by `_columnExists`);
v8 added `RatioVisibilities` zone-bound columns (`addColumn` ×4, guarded); v9
added the `DosingEntries` table (`createTable`, guarded by `_tableExists`); v10
added `Tanks.notes`/`vendor`/`model` (`addColumn` ×3, guarded by `_columnExists`).
Foreign keys are enabled in `beforeOpen` (`PRAGMA foreign_keys = ON`). **When you
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
- `readingsAt` / `deleteReadingsAt` / `updateReadingsTimeAt` operate on a group
  of readings entered together (same timestamp) — used by group edit/delete and
  by re-timing a whole batch.

### Backup (`backup.dart`)

JSON document, `format: "reeftracker-backup"`, `version` (`kBackupVersion = 1`).
DateTimes serialized as epoch millis. `encodeBackup` dumps every table;
`decodeBackup` validates the format/version guard and is **forward-tolerant**
(older backups without the `waterChanges` / `carbonChanges` /
`equipmentCleanings` / `ratioVisibilities` / `dosingEntries` keys decode to empty
lists).
`exportBackup` writes a timestamped file to a temp dir and hands it to the OS
share sheet; `pickBackupData` uses the file picker. `restoreFromBackup`
**replaces the entire database in one transaction**, preserving primary keys so
FK links survive (deletes children→parents, inserts parents→children).
`encodeBackupFromDb(db)` is the shared "read every table → JSON" helper used by
both manual export and the automatic backup service.

### Automatic backup (`auto_backup.dart`)

Two layers, **no new dependencies and no runtime permissions**:

1. **Local rotating backups.** `runAutoBackupIfDue(db)` is called
   opportunistically on app launch and on resume (`main.dart`,
   `WidgetsBindingObserver`); it writes a backup only when the feature is
   enabled, at least one tank exists, and the chosen interval
   (`AutoBackupInterval` daily/weekly) has elapsed since `last_auto_backup_at`.
   `writeAutoBackup` serializes via `encodeBackupFromDb` to
   `<appDocuments>/backups/reeftracker-auto-<stamp>.json`, then `pruneAutoBackups`
   keeps the newest *N* (`kAutoBackupDefaultKeep`). The **Manage backups** screen
   (`features/settings/backups_screen.dart`, route `/settings/backups`) lists
   them and offers restore (reuses `decodeBackup` + `restoreFromBackup`), share,
   and delete.
2. **Android Auto Backup.** `android:allowBackup="true"` plus empty
   `res/xml/backup_rules.xml` / `data_extraction_rules.xml` (default = back up
   all app data) mean the SQLite DB *and* the `backups/` folder are synced to the
   user's Google Drive and auto-restored on reinstall / new device.

Settings keys: `auto_backup_enabled` (default on), `auto_backup_interval`
(`daily`/`weekly`), `auto_backup_keep`, `last_auto_backup_at`. Providers:
`autoBackupEnabledProvider`, `autoBackupIntervalProvider`.

## State layer (`lib/app/providers.dart`)

All app state is Riverpod providers over the singleton `dbProvider`:

- `tanksProvider` (all tanks), `activeTankIdProvider` (persisted), `activeTankProvider`
  (resolves id → tank, falls back to first tank).
- `trackedParametersProvider`, `tankReadingsProvider` (newest-first),
  `paramReadingsProvider(paramKey)` family (oldest-first, chart-friendly),
  `waterChangesProvider`, `carbonChangesProvider`, `equipmentCleaningsProvider`
  (all newest-first), `dosingEntriesProvider` (dashboard order).
- Unit prefs: `tempUnitProvider`, `salinityUnitProvider`, `volumeUnitProvider`,
  combined `unitPrefsProvider`.
- `localeCodeProvider` / `localeProvider` (null = follow system).
- `chartRangeProvider` — shared time range (`7d`/`30d`/`90d`/`All`, default `30d`)
  applied to *all* graphs.
- `trendEnabledProvider` (default on) / `trendWindowProvider` (default
  `kTrendDefaultWindow`) / `trendHorizonProvider` (default `kTrendDefaultHorizon`)
  — the Trends feature toggle, window size, and dashboard forecast horizon.
- `tankTrendsProvider` — `Map<paramKey, TrendResult>` for the active tank. **The
  trend cache:** a plain `Provider` derived from the two trend settings +
  `trackedParametersProvider` + `tankReadingsProvider`; Riverpod memoizes it and
  re-runs `computeTrend` only when those inputs change, never on a widget
  rebuild. Empty when trends are off or no param has `window` readings yet.

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
| `/settings` | Units, language, backup/restore, automatic backup |
| `/settings/backups` | Manage automatic backups (list / restore / share / delete) |
| `/calculator/salinity` | Standalone ppt ↔ SG converter |

The Actions log is no longer a standalone route — it is the second tab inside the
home shell (see Features).

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

### Dashboard (`dashboard_screen.dart`) — Measurements tab

- `DashboardBody` renders the parameter grid for the active tank; the
  surrounding chrome (app bar with `TankSelector`, bottom nav, FAB) is owned by
  `HomeShell`.
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
  reading. Visibility + order are set in the **Manage Parameters** screen
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
  width). Empty-in-range params show a muted placeholder to preserve order;
  tapping a chart opens `/history/:paramKey`. Measurements only — ratio cards are
  not included.

### Trend chart widget (`widgets/trend_chart.dart`)

Shared `fl_chart` building blocks used by both the history and comparison views:
`ChartRange` enum + `chartRangeFromLabel`/`chartRangeLabel`, the
`ChartRangeSelector` (writes `chartRangeProvider`), and `TrendChart` — a
per-parameter line chart with **zone bands** drawn as `RangeAnnotations`
(green/amber regions from the param's bounds) and water-change markers. When
given explicit `minX`/`maxX` it pins to that window (comparison alignment);
otherwise it derives the window from the data (a single reading is centered).
`showBottomTitles` controls whether the date axis is drawn.

### History graph (`history/history_screen.dart`)

Per-parameter history built on the shared `TrendChart` (zone bands + water-change
markers) with the shared `ChartRangeSelector`. Values are presented in the user's
units while bounds/zones stay canonical. Below the chart is the readings list:
tap a row to edit its **value and date/time** (`_ReadingDialog`, the date/time
picker mirroring the actions log); when the moved reading shares its timestamp
with sibling measurements, the user is asked whether to re-time only that value
or all values entered together (`updateReadingsTimeAt`). Swipe-left deletes, with
the same one-vs-all choice for grouped readings (`deleteReadingsAt`).

### Trend detection (`domain/trend.dart` + `widgets/trend_view.dart`)

Layered on top of the zone bands: where the bands say *where a value is*, the
trend says *where it's heading and when it leaves its range*. The math is the
pure `computeTrend` (domain); the per-tank results are cached in
`tankTrendsProvider` (state layer). Two shared widgets render a `TrendResult`:
- `TrendCard` — full block under the **history** chart (shown only when a trend
  exists): the per-day rate (`slopePerDay` converted to the display unit via the
  affine `toDisplay(slope) − toDisplay(0)`, signed) plus projected "reaches
  attention/critical zone in ~N d" lines, or a "holding steady / within range"
  note. Independent of the chart range — it always uses the most recent `window`
  readings.
- `TrendChip` — compact forecast on each **dashboard** `_ParameterTile`, shown
  only when a zone crossing is projected within the configurable `horizonDays`
  (`trendHorizonProvider`, default 14): the soonest of attention (amber) /
  act-now (red) with its day estimate, drawn in the matching zone color. The
  horizon gates only this dashboard chip — the history `TrendCard` always shows
  the full projection.

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
  from the newest reading of each (null if either missing or denominator = 0).
- `computeRatioSeries(numerator, denominator)` builds a time series: at each
  timestamp where either parameter was measured, the most recent value of the
  *other* is carried forward, so a point exists whenever both have ≥1 reading.
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
  and tap-the-row-to-edit (a trailing chevron hints at tappability). The shell's
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
- `water_change_markers.dart` — `waterChangeLines(...)` builds dashed
  `VerticalLine`s rendered on **every** time-series graph (history and ratio) via
  `extraLinesData`, so water changes line up visually with parameter movements.
  (Carbon changes are logged only; they are not drawn on graphs.)

### Dosing (`features/dosing/`) — Dosing tab

An information-only, per-tank **supplement-dosing plan** (a standing regimen, not
a log of discrete doses). Rendered as the **Dosing tab** of the home shell.

- `dosing_screen.dart` — `DosingBody` lists the active tank's `dosingEntriesProvider`
  rows. Each row: a chemistry icon, the product name with a target-element chip,
  a `vendor · program` line, and a localized dosage/schedule summary
  (`dosingDetailLine`) — or "No dosage set" when neither is recorded. Tap a row to
  edit; swipe-left to delete. Helpers here also parse/format the stored weekday
  list and `HH:mm` time using `MaterialLocalizations` (device 12/24-h + locale).
- `dosing_edit_screen.dart` — `DosingEditScreen` (route `/dosing/edit`, `extra` =
  `DosingEntry?`) is the add/edit form. It cascades **Vendor → Product → Element**
  off `kSupplementVendors`: picking a catalog product auto-fills its element and
  default unit; an "Other…" choice in either dropdown swaps in a free-text field
  (custom entries persist `productKey = null`). Optional **Dosage** = amount +
  unit (ml/g) + basis (per day/dose); optional **Schedule** = frequency
  (daily / every N days / weekly with weekday chips) + time. On save it writes a
  `DosingEntries` row, keeping the stable `productKey` (for the future dose-log +
  consumption features) and a denormalized vendor/program/product snapshot.
- **Display names resolve live.** `DosingBody` shows vendor/program/product via
  `resolveSupplementNames(...)`: when `productKey` still matches a catalog
  product it uses the **current** catalog names (so a YAML rename/move is
  reflected on existing entries), falling back to the stored snapshot only for
  custom or orphaned entries. The target element stays the stored, user-editable
  value.

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
  (stable / increase / decrease / overdosing / needs-potency / insufficient-data).
  Works with no dosing (consumption = the measured drop) and flags a rising
  element as over-dosing.

### Manage parameters (`manage_parameters_screen.dart`)

One reorderable list (`_DashItem` sealed type: `_ParamItem` | `_RatioItem`)
mixing tracked parameters and ratio cards, ordered by their shared
`displayOrder`. Toggle which parameters are tracked / which ratio cards are
shown, drag to reorder either, and edit a parameter's zone bounds
(`ParameterEditScreen`). Reordering writes the new combined order back via
`applyDashboardOrder` (params → `TrackedParameters`, ratios →
`RatioVisibilities`). Each row has an edit button: parameters open
`ParameterEditScreen`, ratios open `RatioEditScreen` (per-tank zone bounds).
Re-applying a setup-type preset is available.

### Add reading (`add_reading_screen.dart`)

Enter several parameters at once for a single timestamp (group). Inputs accept
values in the user's display units and are converted to canonical on save.

### Tanks (`tanks_screen.dart`)

Create/edit/delete tanks. Editor converts volume to/from the display unit and
captures optional free-text `vendor` and `model` (single line) plus multi-line
`notes`. The setup type drives which parameters are seeded. The list and the
Settings → About row use the `Icons.waves` glyph for an aquarium (tinted with
the primary colour for the active tank).

### Settings (`settings_screen.dart`)

Unit selectors (temp/salinity/volume), language selector, a **Trends** section
(on/off switch + recent-readings window selector `kTrendMinWindow`..`kTrendMaxWindow`
+ alert-horizon selector within `kTrendMinHorizon`..`kTrendMaxHorizon`),
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
- Tests (`flutter test`): `test/zones_test.dart`, `test/presets_test.dart`,
  `test/units_test.dart`, `test/ratio_test.dart`, `test/backup_test.dart`,
  `test/supplement_catalog_test.dart`, `test/dose_calculator_test.dart`,
`test/trend_test.dart`.

## Maintaining this document

`DESIGN.md` is the high-level map of the app's design and important features. Keep
it accurate: after any change that alters the design — new/changed tables or
migrations, new screens or routes, new domain rules, new features, or shifts in
the layering/state model — update the relevant section here in the same change.
Skip updates for purely cosmetic or trivial edits that don't change the design
(wording tweaks, styling, refactors with no behavioral/structural effect).
