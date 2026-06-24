# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
