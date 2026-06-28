# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2026-06-28

### Added
- A language selector on the first-run welcome screen, so you can choose your
  language before creating your first aquarium without digging into Settings.

## [0.7.0] - 2026-06-26

### Added
- Supplement dosing. A new **Dosing** tab lets you record, per aquarium, the
  supplements you dose — pick the vendor and product from a built-in catalog of
  major reef brands and programs (Red Sea, Tropic Marin, Triton, Fauna Marin,
  Aquaforest, ZEOvit, generic/DIY), or enter your own with "Other…". Each entry
  notes its target element and, optionally, a dosage (amount in ml or g, per day
  or per dose) and a descriptive schedule (daily, every N days, or weekly on
  chosen weekdays, with an optional time of day). This first version is for
  reference only. Dosing entries are included in backups.

## [0.6.0] - 2026-06-26

### Added
- Automatic backups. The app now saves a backup of all your data on the device
  on a schedule (daily by default, switchable to weekly), keeping the most
  recent copies and pruning older ones. A new "Manage backups" screen in
  Settings lets you view, restore, share, or delete these automatic backups.
  On Android, app data is also included in the system's cloud backup, so your
  data is restored automatically when you reinstall or set up a new device.

## [0.5.3] - 2026-06-25

### Added
- Editing a measurement now also lets you change its date/time (like editing an
  action). When the measurement was recorded together with others at the same
  moment, changing the time asks whether to re-time only that value or all
  values entered together.

## [0.5.2] - 2026-06-25

### Changed
- In the Measurements and Actions lists, tap a row to edit it instead of using a
  separate edit icon. The edit icon is replaced by a subtle chevron indicating
  the row is tappable; swipe-left to delete is unchanged.

### Fixed
- Fixed the app crashing immediately on launch on some physical devices, caused
  by a corrupted native library in the previously published release build.
  Rebuilt cleanly (build 12).

## [0.5.1] - 2026-06-25

### Changed
- The bottom navigation bar is now more compact (reduced height), with new
  icons — a speedometer for Measurements and a clipboard with a checkmark for
  Actions.
- Dashboard measurement and ratio cards are now slightly smaller (~5%), fitting
  a bit more on screen.
- Ratio cards selected for display now always appear on the dashboard. When a
  ratio can't be computed yet (a measurement is missing or the denominator is
  zero), the card shows **"No readings"**, just like a measurement card, instead
  of being hidden.

## [0.5.0] - 2026-06-25

### Changed
- The two main screens — **Measurements** and **Actions** — are now reachable
  from a persistent **bottom navigation bar** instead of opening Actions as a
  pushed screen with a back button. Switching tabs preserves each screen's
  state. The tank selector and the manage-parameters / settings buttons stay in
  the shared app bar on both tabs.

## [0.4.2] - 2026-06-24

### Added
- Ratio cards now have **editable per-tank zone bounds** (red/amber/green),
  edited the same way as measurement parameters (Manage Parameters → edit).
  Bounds default to the recommended ranges and are included in backup/restore.

## [0.4.1] - 2026-06-24

### Added
- Recommended red/amber/green health zones for the ratio cards (PO₄ : NO₃ green
  ≈ 50–150 / a ~100:1 NO₃:PO₄ target; Mg : Ca green ≈ 2.9–3.3 / ≈3:1): ratio
  values are now color-coded and the ratio graphs show zone bands.

### Changed
- The Mg : Ca ratio is now shown as a single number (Mg ÷ Ca, to one decimal)
  instead of `N : 1`.
- Ratio cards are now full dashboard cards, identical in size and appearance to
  the measurement cards, and live in the same grid.
- Ratio card show/hide moved from app Settings to the Manage Parameters screen
  (in the same reorderable list as measurements) and is stored **per tank**
  (`RatioVisibilities` table, included in backup/restore). Ratio cards can now be
  **reordered** alongside measurements via a shared display order.

## [0.4.0] - 2026-06-24

### Added
- Magnesium-to-calcium (Mg : Ca) ratio: dashboard card and history graph.
- Equipment-cleaning entries in the action log, including backup/restore support.
- Settings → Dashboard section with toggles to show or hide the PO₄ : NO₃ and
  Mg : Ca ratio cards.

### Changed
- The PO₄ : NO₃ ratio is now displayed in the conventional reef form `1 : N`
  (and its graph plots `N`).
- Ratio handling generalized over a `RatioKind` enum, sharing one graph screen
  and the `/ratio/:type` route across all ratios.
- Build: pinned every Kotlin compile task to JVM target 17 to fix an
  "Inconsistent JVM-target compatibility" failure (e.g. from `file_picker`).
- Documentation: added version-bumping guidance to `CLAUDE.md`; updated
  `DESIGN.md`.

## [0.3.2] - 2026-06-24

### Added
- Action log screen (`/actions`) combining water changes and activated-carbon
  changes.

### Changed
- Documentation updates.

## [0.2.1] - 2026-06-24

### Added
- Water-change tracking, with change markers drawn on the history graphs.
- PO₄ : NO₃ ratio: dashboard card and history graph.
- Volume unit preference (litres ↔ gallons), applied across the app.

## [0.2.0] - 2026-06-24

### Added
- Group deletion of readings entered together (delete one value or the whole
  batch).

### Fixed
- Time-series graph rendering (axes, labels, and single-point handling).

## [0.1.0] - 2026-06-23

Initial development release.

### Added
- Multi-tank reef aquarium tracking with per-tank tracked parameters and
  green/amber/red health zones.
- Dashboard with per-parameter status tiles (latest value, trend, timestamp).
- Per-parameter history graphs with zone bands and selectable time ranges.
- Setup-type presets (fish-only, soft, LPS, SPS, mixed) seeding default
  parameters and zone boundaries.
- Reading entry (batch logging) plus editing and deletion.
- Unit preferences: temperature (°C ↔ °F) and salinity (ppt ↔ SG), with values
  stored canonically and converted for display.
- Standalone salinity calculator (ppt ↔ SG).
- Optional tank start date.
- Backup export and restore (replace all data from a file).
- Full localization in English, Czech, German, Russian, and Polish.
- App icons and title.
