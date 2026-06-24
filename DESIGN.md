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
| `ratio.dart` | PO₄ : NO₃ ratio math (see Features). |

## Data layer (`lib/data/`)

### Schema (`database.dart`, generated `database.g.dart`) — **schemaVersion 4**

| Table | Key columns |
|-------|-------------|
| `Tanks` | id, name, setupType, volumeLiters?, startDate?, createdAt |
| `TrackedParameters` | id, tankId (FK cascade), paramKey, unit, enabled, displayOrder, + 4 zone bounds (amberLow/greenLow/greenHigh/amberHigh) |
| `Readings` | id, tankId (FK cascade), paramKey, value (canonical), takenAt, note? |
| `WaterChanges` | id, tankId (FK cascade), changedAt, amountLiters?, note? |
| `CarbonChanges` | id, tankId (FK cascade), changedAt, grams?, note? |
| `Settings` | key (PK), value? — generic kv store |

`Settings` keys in use: `active_tank_id`, `temp_unit`, `salinity_unit`,
`volume_unit`, `locale`, `chart_range`.

**Migrations** (`MigrationStrategy`): v2 added `Tanks.startDate` via `addColumn`;
v3 added the `WaterChanges` table via `createTable`; v4 added `WaterChanges.note`
(`addColumn`) and the `CarbonChanges` table (`createTable`). Foreign keys are
enabled in `beforeOpen` (`PRAGMA foreign_keys = ON`). **When you add/change a
table or column you must bump `schemaVersion` and add the matching migration**,
then run `dart run build_runner build`.

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
- `readingsAt` / `deleteReadingsAt` operate on a group of readings entered
  together (same timestamp) — used by group edit/delete.

### Backup (`backup.dart`)

JSON document, `format: "reeftracker-backup"`, `version` (`kBackupVersion = 1`).
DateTimes serialized as epoch millis. `encodeBackup` dumps every table;
`decodeBackup` validates the format/version guard and is **forward-tolerant**
(older backups without the `waterChanges` / `carbonChanges` keys decode to empty
lists).
`exportBackup` writes a timestamped file to a temp dir and hands it to the OS
share sheet; `pickBackupData` uses the file picker. `restoreFromBackup`
**replaces the entire database in one transaction**, preserving primary keys so
FK links survive (deletes children→parents, inserts parents→children).

## State layer (`lib/app/providers.dart`)

All app state is Riverpod providers over the singleton `dbProvider`:

- `tanksProvider` (all tanks), `activeTankIdProvider` (persisted), `activeTankProvider`
  (resolves id → tank, falls back to first tank).
- `trackedParametersProvider`, `tankReadingsProvider` (newest-first),
  `paramReadingsProvider(paramKey)` family (oldest-first, chart-friendly),
  `waterChangesProvider`, `carbonChangesProvider` (both newest-first).
- Unit prefs: `tempUnitProvider`, `salinityUnitProvider`, `volumeUnitProvider`,
  combined `unitPrefsProvider`.
- `localeCodeProvider` / `localeProvider` (null = follow system).
- `chartRangeProvider` — shared time range (`7d`/`30d`/`90d`/`All`, default `30d`)
  applied to *all* graphs.

## Routing (`lib/app/router.dart`)

| Route | Screen |
|-------|--------|
| `/` | Dashboard |
| `/tanks`, `/tanks/new`, `/tanks/:id/edit` | Manage / create / edit tanks |
| `/parameters`, `/parameters/:id/edit` | Manage tracked parameters & zone bounds |
| `/add-reading` | Log a batch of readings |
| `/history/:paramKey` | Single-parameter history graph |
| `/ratio` | PO₄ : NO₃ ratio history graph |
| `/actions` | Combined action log (water changes + carbon changes) |
| `/settings` | Units, language, backup/restore |
| `/calculator/salinity` | Standalone ppt ↔ SG converter |

## Features (`lib/features/`)

### Dashboard (`dashboard_screen.dart`) — home

- App-bar `_TankSelector` popup to switch active tank or jump to manage-tanks;
  app-bar actions for the action log, manage parameters, settings; FAB to add a
  reading.
- Grid of `_ParameterTile`s (enabled tracked params only): each shows the latest
  value **colored by its zone**, the display unit, a trend `_ChangeIndicator`
  (up/down/flat + delta vs. previous reading), and a relative timestamp.
  Tapping a tile opens that parameter's history.
- Optional `_RatioCard` banner at the top showing the latest PO₄ : NO₃ ratio
  (only when both NO₃ and PO₄ have readings); tap opens `/ratio`.
- Empty states: `_NoTanksView` (welcome + add aquarium) and `_NoParamsView`.

### History graph (`history/history_screen.dart`)

Per-parameter `fl_chart` line chart with **zone bands** drawn as
`RangeAnnotations` (green/amber regions from the param's bounds), shared time-range
selector, and water-change markers (see below). Values are presented in the user's
units while bounds/zones stay canonical.

### PO₄ : NO₃ ratio (`domain/ratio.dart` + `features/ratio/ratio_screen.dart`)

Reef keepers target a phosphate-to-nitrate balance.
- `latestRatio(...)` → the current ratio from the newest NO₃ and PO₄ (null if
  either missing or NO₃ = 0).
- `computeRatioSeries(...)` builds a time series: at each timestamp where either
  parameter was measured, the most recent value of the *other* is carried
  forward, so a point exists whenever both have ≥1 reading.
- Displayed in the conventional reef form `1 : N` (N = NO₃/PO₄) via
  `formatRatioOneToN`; the chart plots N. `formatRatio`/`formatRatioN` scale
  precision to magnitude.

### Actions log (`features/actions/`)

A single combined log of tank maintenance actions for the active tank, newest
first.

- `actions_screen.dart` — merges `waterChangesProvider` + `carbonChangesProvider`
  into one sorted list (`_Entry` sealed type: `_WaterEntry` / `_CarbonEntry`).
  Each row: type icon, type name, value (litres in the display volume unit, or
  grams), optional note, timestamp; swipe-to-delete and an edit button. The FAB
  opens a bottom sheet to choose which action to add. A shared `_ActionDialog`
  (date/time picker + optional numeric value with a unit suffix + optional note)
  drives both add and edit for either type.
  - **Water change**: optional litres (converted to/from the display volume
    unit) + note (e.g. salt brand).
  - **Carbon change**: optional weight in grams + note (e.g. brand).
- `water_change_markers.dart` — `waterChangeLines(...)` builds dashed
  `VerticalLine`s rendered on **every** time-series graph (history and ratio) via
  `extraLinesData`, so water changes line up visually with parameter movements.
  (Carbon changes are logged only; they are not drawn on graphs.)

### Manage parameters (`manage_parameters_screen.dart`)

Toggle which catalog parameters are tracked for the active tank, reorder them
(`displayOrder`), and edit each one's zone bounds (`ParameterEditScreen`).
Re-applying a setup-type preset is available.

### Add reading (`add_reading_screen.dart`)

Enter several parameters at once for a single timestamp (group). Inputs accept
values in the user's display units and are converted to canonical on save.

### Tanks (`tanks_screen.dart`)

Create/edit/delete tanks. Editor converts volume to/from the display unit. The
setup type drives which parameters are seeded.

### Settings (`settings_screen.dart`)

Unit selectors (temp/salinity/volume), language selector, and **Backup &
Restore** (export → share sheet, import → file picker → full replace). Link to
the salinity calculator. The About box shows the live app version via
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
- Localization codegen: `flutter gen-l10n`.
- Tests (`flutter test`): `test/zones_test.dart`, `test/presets_test.dart`,
  `test/units_test.dart`, `test/ratio_test.dart`, `test/backup_test.dart`.

## Maintaining this document

`DESIGN.md` is the high-level map of the app's design and important features. Keep
it accurate: after any change that alters the design — new/changed tables or
migrations, new screens or routes, new domain rules, new features, or shifts in
the layering/state model — update the relevant section here in the same change.
Skip updates for purely cosmetic or trivial edits that don't change the design
(wording tweaks, styling, refactors with no behavioral/structural effect).
