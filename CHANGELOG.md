# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.14.0] - 2026-06-30

### Added
- **Tank health score** — an at-a-glance 0–100 rating of the active tank,
  derived from how each tracked parameter's latest reading sits within its
  green/amber/red range. Shown as a ring badge in the dashboard header and a
  compact badge beside the tank name in the app bar. The worst parameter always
  sets the colour and grade (Excellent / Good / Caution / Critical), so one
  critical value can't be hidden behind several healthy ones.
- Tapping the badge opens a breakdown sheet grouping parameters into "needs
  attention", "looking good" and "not tested recently", each row linking to its
  history graph. Parameters not tested within 30 days are excluded from the
  score and flagged separately.
- Settings → Dashboard control for the tank-health display with three choices:
  badge & card (default), badge only, or hidden.

## [0.13.4] - 2026-06-30

### Added
- New Red Sea dosing program: **Complete Reef Care Program**, the all-in-one
  4-part system (Part 1 Calcium & Magnesium, Part 2 KH/Alkalinity & pH
  Stabilizer, Part 3 Iodine & Potassium, Part 4 Iron & Bioactive Elements).
- **Iron** is now a trackable reef parameter (ppm), so iron-dosing supplements
  (e.g. Red Sea Trace Colors C) can target it.
- Dose-potency (strength) data for the Red Sea Foundation/Trace Colors and
  Complete Reef Care parts, and for the Tropic Marin Balling parts, derived
  from each vendor's published dosing charts.

### Changed
- Renamed the Red Sea Reef Care Program to **Foundation ABC** and updated its
  product names to match Red Sea's current labelling (Foundation A/B/C and
  Trace Colors A–D). NO₃:PO₄-X is now a standalone Red Sea product instead of
  being grouped with the foundation supplements.

## [0.13.3] - 2026-06-30

### Fixed
- Trend delta chips no longer display a negative-zero (`-0.0`) or an inconsistent
  sign: a change that rounds to zero at the shown precision is now always rendered
  as an unsigned `0.0`, and the `+`/`-` prefix always matches the displayed
  magnitude.
- Sharing a backup no longer leaves a plaintext copy of the whole database behind
  in temporary storage: the exported file is deleted once the share sheet closes,
  and any leftovers from earlier exports are swept on the next export.
- Automatic backups can no longer run twice at once (e.g. when the app resumes
  immediately after launch), which previously could duplicate work and collide on
  the same backup filename. Concurrent triggers now share a single in-flight run.

## [0.13.2] - 2026-06-30

### Changed
- Restoring a backup is now validated before it touches your data: the backup is
  checked for schema compatibility and internal consistency and then rehearsed in
  a temporary database, so an incompatible or damaged file is rejected **without**
  wiping the current database. Restore errors now explain what's wrong (too new,
  damaged, or inconsistent) instead of a single generic message.

### Fixed
- Health zone classification no longer shows a dangerously out-of-range value as
  **OK (green)** when only the amber bound is set on that side. Red (beyond an
  amber bound) is now evaluated before the green check, so e.g. a reading far
  above the amber-high limit is correctly flagged red even with no green-high
  bound configured.
- Numeric inputs (readings, zone/ratio bounds, aquarium volume, dose and
  salinity calculators) now reject non-finite values like `Infinity` and `NaN`,
  which previously parsed successfully and, once stored, corrupted charts, zone
  classification and trend math. Aquarium volume additionally must be a positive
  number.
- The Save button on the add-reading and aquarium screens no longer gets stuck
  in a disabled spinner state if the database write fails — the error is now
  shown and the button is re-enabled.
- A batch of readings entered together is now saved atomically, so a failure
  partway through can no longer leave a partial group behind.

## [0.13.1] - 2026-06-30

### Added
- The feature tour now also covers the **dose calculator**: after the
  Measurements-tab steps it switches to the Dosing tab and spotlights the
  calculator button as its final step.

## [0.13.0] - 2026-06-30

### Added
- A one-time **feature tour** on first launch that spotlights the less-obvious
  top-bar controls — the aquarium selector, the grid/compare-graphs toggle, and
  the manage-parameters button — with short explanations and Next/Skip buttons.
- **Settings → Replay tour** to show the tour again at any time.

## [0.12.0] - 2026-06-29

### Added
- Two new parameter-ratio cards: **Ca : Alk** (calcium-to-alkalinity balance, a
  guide to whether the two are being dosed in step) and **Mg : Alk**. Like the
  existing ratios they appear on the dashboard with health zones and editable
  per-tank bounds.
- The Parameters screen's overflow (⋮) menu now has a descriptive tooltip
  ("More options") for clarity and screen-reader accessibility, matching the
  tooltips already present on the top-bar action icons.

## [0.11.1] - 2026-06-29

### Changed
- The water-change action now uses a bucket (pouring) icon instead of the water
  drop, in both the actions list and the "add action" menu.

## [0.11.0] - 2026-06-29

### Added
- Aquariums can now record an optional **vendor** and **model** (single-line free
  text) and free-text multi-line **notes**, editable both when creating a tank
  and later from its editor.

### Changed
- New aquarium icon: tanks now use a water-waves glyph in the aquariums list and
  in Settings → About (the active tank is tinted), replacing the old water-drop
  and flask icons.

## [0.10.1] - 2026-06-29

### Added
- A configurable **alert horizon** for trends (Settings → Trends). The dashboard
  now flags a parameter with an attention chip only when it's projected to leave
  its range within the chosen time (3–90 days, default 14), so far-off drifts
  don't clutter the grid. The per-parameter history screen still shows the full
  projection regardless.

## [0.10.0] - 2026-06-29

### Added
- **Trend detection** for each parameter. Beyond showing where a value sits in
  its green/amber/red zones, the app now fits a line through your most recent
  readings to estimate how fast a parameter is drifting and projects when it
  will leave its healthy range. The per-parameter history screen shows the
  recent rate (e.g. "−0.25 dKH/day") and any projected crossing into the
  attention or critical zone, and dashboard tiles show a compact forecast chip
  when a crossing is coming up. Toggle the feature on/off and choose how many
  recent readings define a trend (3–10, default 5) in Settings → Trends; a
  trend appears only once that many readings exist.

## [0.9.0] - 2026-06-28

### Added
- A **Dose calculator** on the Dosing tab (app-bar calculator icon). Pick an
  element (e.g. Calcium) and it reads your stored measurements over a chosen
  window to estimate how fast the tank actually consumes it, then proposes the
  daily dose that holds it steady. Your current dose and tank volume are
  pre-filled from your dosing plan and aquarium (all editable), and the
  supplement strength can come from the built-in catalog or be entered from the
  bottle's reference dose. Also works when you dose nothing yet, and warns when
  an element is rising (over-dosing). Water changes are not considered yet.

### Changed
- The built-in catalog now includes verified potency data for Fauna Marin
  Balling Light (Calcium, Carbonate and Magnesium Mix), so the dose calculator
  can pre-fill their strength automatically.

## [0.8.0] - 2026-06-28

### Added
- A **Compare graphs** view on the Measurements tab. Toggle the app-bar icon to
  switch the parameter grid for a stack of trend charts — one per tracked
  parameter, in the same order as the dashboard — all sharing a single, aligned
  time axis. Reading straight down a point in time shows how your parameters
  move together, with the usual zone bands and water-change markers lined up
  across every chart.

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
