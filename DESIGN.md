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
| `supplement_catalog.dart` | Model + lookups for the dosing **vendors → programs → products** catalog + `DoseUnit` (ml/g), `DoseBasis` (per day/dose), `DoseFrequency` (daily/everyNDays/weekly) enums. Each `SupplementProduct` has a stable `key` (persisted on dosing entries), a target `elementKey` (a real param key), a default unit, and an optional `strength` potency map reserved for the future consumption calculator. Brand/product names are proper nouns — **not** localized. `kDosingElementKeys` = the param keys offered in the dosing element picker. **The data (`kSupplementVendors`) is generated** — see below. |
| `supplements.yaml` + `supplement_catalog.g.dart` | `supplements.yaml` (commented, hand-edited) is the **source of truth** for the catalog data; `dart run tool/gen_supplements.dart` validates it (unique product keys; every `element`/`strength` key is a real param key; `unit` ∈ ml/g) and generates the `part` file `supplement_catalog.g.dart` (`const kSupplementVendors`). Edit the YAML, never the `.g.dart`. `test/supplement_catalog_test.dart` re-checks the same invariants on the generated catalog. |

## Data layer (`lib/data/`)

### Schema (`database.dart`, generated `database.g.dart`) — **schemaVersion 9**

| Table | Key columns |
|-------|-------------|
| `Tanks` | id, name, setupType, volumeLiters?, startDate?, createdAt |
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
`auto_backup_interval`, `auto_backup_keep`, `last_auto_backup_at`.

**Migrations** (`MigrationStrategy`): v2 added `Tanks.startDate` via `addColumn`;
v3 added the `WaterChanges` table via `createTable`; v4 added `WaterChanges.note`
(`addColumn`) and the `CarbonChanges` table (`createTable`); v5 added the
`EquipmentCleanings` table (`createTable`, guarded by `_tableExists`); v6 added
the `RatioVisibilities` table (`createTable`, guarded by `_tableExists`); v7
added `RatioVisibilities.displayOrder` (`addColumn`, guarded by `_columnExists`);
v8 added `RatioVisibilities` zone-bound columns (`addColumn` ×4, guarded); v9
added the `DosingEntries` table (`createTable`, guarded by `_tableExists`).
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

## Routing (`lib/app/router.dart`)

| Route | Screen |
|-------|--------|
| `/` | Home shell — bottom-nav host for the Measurements (Dashboard), Actions, and Dosing tabs |
| `/tanks`, `/tanks/new`, `/tanks/:id/edit` | Manage / create / edit tanks |
| `/parameters`, `/parameters/:id/edit` | Manage tracked parameters & zone bounds |
| `/add-reading` | Log a batch of readings |
| `/history/:paramKey` | Single-parameter history graph |
| `/ratio/:type` | Ratio history graph (`type` = `po4no3` or `mgca`) |
| `/ratio/:type/edit` | Edit a ratio card's per-tank zone bounds |
| `/dosing/edit` | Add / edit a supplement-dosing entry (`extra` = `DosingEntry?`) |
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
  timestamp; tapping opens the parameter history or `/ratio/<kind>`.
- A ratio tile shows whenever its card is visible (per settings), regardless of
  whether a value can be computed yet: with no computable ratio — a parameter is
  missing or the denominator is zero, so `computeRatioSeries` is empty — the tile
  shows **"No readings"**, exactly like a measurement tile before its first
  reading. Visibility + order are set in the **Manage Parameters** screen
  (ratios and measurements share one reorderable list) and stored **per tank** in
  `RatioVisibilities` (`ratioSettingsProvider` → `Map<RatioKind.name,
  RatioVisibility>`, resolved with `ratioRowVisible` / `ratioRowOrder`).
- Empty states: `_NoTanksView` (welcome + add aquarium) and `_NoParamsView`.

### History graph (`history/history_screen.dart`)

Per-parameter `fl_chart` line chart with **zone bands** drawn as
`RangeAnnotations` (green/amber regions from the param's bounds), shared time-range
selector, and water-change markers (see below). Values are presented in the user's
units while bounds/zones stay canonical. Below the chart is the readings list:
tap a row to edit its **value and date/time** (`_ReadingDialog`, the date/time
picker mirroring the actions log); when the moved reading shares its timestamp
with sibling measurements, the user is asked whether to re-time only that value
or all values entered together (`updateReadingsTimeAt`). Swipe-left deletes, with
the same one-vs-all choice for grouped readings (`deleteReadingsAt`).

### Parameter ratios (`domain/ratio.dart` + `features/ratio/ratio_screen.dart`)

Generic over a `RatioKind` enum (each carries numerator/denominator param keys,
display symbols, and a `RatioDisplay` form). Current kinds: `po4no3` (PO₄ : NO₃,
shown as `1 : N`) and `mgca` (Mg : Ca, shown as a single number = Mg/Ca to one
decimal). `RatioDisplay` = `oneToN` | `decimal`.
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
  green ≈ 2.9–3.3 (≈3:1). Bounds are **editable per tank** via `RatioEditScreen`
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
`Readings.paramKey`, and every catalog product carries a stable `key` plus an
(as-yet-unpopulated) `strength` potency slot — so a later phase can log actual
doses and compute element consumption (dosed input vs. measured change) by
joining entries → product → potency → readings. The plan's schedule is purely
descriptive and is **not** the source of truth for that math.

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

Create/edit/delete tanks. Editor converts volume to/from the display unit. The
setup type drives which parameters are seeded.

### Settings (`settings_screen.dart`)

Unit selectors (temp/salinity/volume), language selector, and **Backup &
Restore** (export → share sheet, import → file picker → full replace), plus an
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
  `test/supplement_catalog_test.dart`.

## Maintaining this document

`DESIGN.md` is the high-level map of the app's design and important features. Keep
it accurate: after any change that alters the design — new/changed tables or
migrations, new screens or routes, new domain rules, new features, or shifts in
the layering/state model — update the relevant section here in the same change.
Skip updates for purely cosmetic or trivial edits that don't change the design
(wording tweaks, styling, refactors with no behavioral/structural effect).
