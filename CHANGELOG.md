# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.17.0] - 2026-07-05

### Added
- Test sets on the Add Reading screen: name the parameter subsets you test
  together ("Weekly big test", "Daily Alk") and switch between them with
  chips at the top of the form — the set you used last is preselected per
  aquarium. Values you typed stay (and are saved) even if the current set
  hides them. Create a set from the "+" chip (parameters you just filled in
  come pre-selected); edit, delete, and reorder sets from the checklist
  button in the top bar (or long-press a chip to edit it). Test sets are
  included in backups.
- Settings → Backup gained "Export measurements (CSV)": shares the active
  aquarium's measurements as a spreadsheet-friendly CSV file (one row per
  measurement with timestamp, parameter, value in your display units, unit,
  and note) for analysis in Excel/Google Sheets or comparison with lab
  results.
- Measurements with a note now stand out on graphs as a ringed accent dot
  (shown even on dense graphs where regular point dots are hidden), and
  touching one shows the note in the tooltip.
- The parameter history graph supports pinch-zoom and pan (horizontal, up to
  10×); double-tap the graph to reset the view.
- Carbon changes and equipment cleanings now appear on parameter graphs as
  vertical marker lines alongside water changes, each with its own color and
  dash style, plus a small legend naming the line styles visible in the
  current time window (under the history graph, above the comparison view).

### Fixed
- Touching a point on a graph now shows a readable tooltip: high-contrast
  colors that follow the light/dark theme (previously blue text on dark grey,
  barely visible), the value formatted with its unit in your locale, and the
  measurement's date and time. Ratio graphs show the value in their display
  form (e.g. "1 : 100"). The tooltip also stays inside the chart instead of
  being clipped at the edges.

## [0.16.3] - 2026-07-04

### Added
- Backups now carry an integrity checksum, so a backup file damaged after it
  was written (bad storage, broken transfer) is detected and rejected as
  corrupted at import instead of silently restoring altered values. Automatic
  backups are additionally verified on disk before they replace an older
  backup in the rotation. Older backups without a checksum still restore.

### Changed
- Performance: single-parameter chart data (history, ratio and dose
  calculator screens) is now released when you leave the screen. Previously
  every parameter chart ever opened kept its full measurement series live in
  the background and re-read it on each save for the rest of the session.
- Performance: the measurement list on the parameter history screen and the
  ratio screen's value list now build only the rows on screen; with years of
  data on the "All" range, both previously built every row (with its swipe
  handling) on each rebuild.
- Performance: typing a value on the Add reading screen now updates only that
  row's zone indicator instead of rebuilding the whole form on every
  keystroke, and ratio series are computed in a single pass over the data.
- Performance: all settings are now read through a single database query
  instead of one per setting (~14), and changing one setting no longer
  re-notifies screens watching the others.

### Fixed
- The tank health card at the top of the dashboard was slightly wider than
  the parameter tile grid below it; both now align to the same edges.
- Opening a broken or outdated link into the app now shows a translated
  "page not found" screen with a button back to the home screen, instead of
  an untranslated English error page with no way back.
- A link to an unknown ratio type now goes to the home screen instead of
  silently opening the PO₄/NO₃ ratio.

## [0.16.2] - 2026-07-03

### Changed
- Trends are more stable for frequently measured parameters: the trend line
  now always covers at least 5 days of history. When you measure a parameter
  several times a day, the configured number of readings alone spans only a
  day or two, and test-kit noise over such a short base made slopes and
  forecasts jumpy — the fit now widens to include every reading from the last
  5 days. Parameters measured daily or less often behave exactly as before.
- Performance: the dashboard, trend chips and health score now load only the
  newest few readings of each parameter instead of the tank's entire
  measurement history, and no longer re-read that history on every save. With
  years of data, saving a reading previously re-loaded every stored row; the
  full history is now only read while a chart screen that actually plots it
  is open. Graphs are unaffected and still show all readings.

## [0.16.1] - 2026-07-02

### Changed
- The database now runs in SQLite WAL journal mode, so long reads (such as a
  backup being written) and saves no longer block each other.
- Creating and restoring backups no longer freezes the app: the JSON
  encoding/decoding and the pre-restore rehearsal now run off the UI thread.
  This matters most on "backup day", when the automatic backup fires right at
  startup or on resume with years of readings in the database.
- Backup files are now written as compact JSON (roughly half the size), which
  also reduces what the rotating backups count against the Android cloud
  backup quota. Existing pretty-printed backups restore unchanged.

### Fixed
- The app could hang forever on the launch splash screen on some devices
  (seen on 0.15.3): startup waited unbounded on a platform call that never
  answers when made before the first frame (flutter/flutter#72872). The
  pre-frame locale/database warm-up is now time-bounded and the database's
  directory lookup retries after the first frame, so launch always proceeds.

## [0.16.0] - 2026-07-02

### Changed
- Performance: the dashboard, health badge and history screens no longer
  rebuild when unrelated data changes (e.g. a reading saved for another
  aquarium) — identical database emissions and unchanged trend/health results
  are now filtered out before they reach the UI.
- Internal architecture cleanup with no behavior changes: the domain layer
  (zones, ratios, dose math, parameter catalog) no longer depends on Flutter
  or the database, dead English-only display fields were removed in favor of
  the localization pipeline, and the `active_tank_id` settings key now has a
  single shared definition.

### Removed
- The end-of-life `sqlite3_flutter_libs` dependency (inert — the bundled
  SQLite already comes from the actively maintained `sqlite3` package).

## [0.15.3] - 2026-07-01

### Added
- **Delete and Stop are reachable without swiping**: the measurement and
  action edit dialogs now include a Delete button (with the same
  batch-aware confirmation and Undo as swiping), and the supplement edit
  screen has a Stop action — so TalkBack and switch-access users can manage
  entries too.

### Changed
- **Numbers now display in your language's format**: Czech, German, Polish and
  Russian users see "2,5 ml" instead of "2.5 ml" everywhere — tiles, charts,
  dialogs, the calculators — matching the comma input the app already accepted.
- Counts are **properly pluralized in every language** ("Saved 1 reading" /
  "Saved 3 readings", including the Czech/Polish/Russian few/many forms),
  replacing the old "reading(s)" and "1 readings" style.
- The app now **starts directly in your chosen language** instead of flashing
  the system language for the first moment; the database is also opened before
  the first frame.
- **Dashboard tiles grow with the system font size** instead of clipping their
  text at large accessibility scales.
- Backup timestamps in Settings honor the device's **24-hour clock preference**,
  and backup file sizes are shown with translated units (e.g. КБ/МБ in
  Russian) and locale decimals.
- The water-change marker on charts now follows the app **theme** (readable in
  both light and dark mode); status chips, list drag handles and the
  parameter switches are now **labeled for screen readers**; the gram suffix in
  the carbon dialog is localized.

### Fixed
- **Switching aquariums no longer flashes the previous tank's data**: for a
  moment the dashboard, actions and dosing lists could show tank A's readings
  under tank B's name; each tank's data now loads fresh on switch.
- A failed **"Back up now" shows an accurate message** ("Could not save the
  backup" instead of the misleading "Could not export the backup"), and a
  failed share of a stored backup now shows an error instead of failing
  silently.
- **Measurements saved in the same second no longer merge into one batch**:
  each "Add reading" save is tagged with its own batch id, so batch delete/
  re-time can no longer drag in unrelated readings that happen to share a
  timestamp (existing data keeps the old timestamp grouping).
- The **dose calculator no longer overwrites what you typed**: the automatic
  prefill of tank volume and current dose now only fills empty fields and
  can't fire mid-edit anymore.
- The add-parameter sheet can no longer briefly **offer parameters that are
  already tracked** while the list is loading, and rapid double-taps can no
  longer create duplicate parameters or dosing rows (the checks now run
  atomically).
- An empty chart series now shows "No readings in this range" instead of
  being able to crash the chart widget (defensive; not reachable from the
  current screens).

### Changed
- The dose calculator's **"stable" verdict now scales with your dose** (±5%,
  with a small absolute floor) instead of a flat 0.5 ml: a large mismatch on a
  small dose of a potent supplement is no longer waved through as "keep your
  current dose", and big dosers aren't nagged over trivial tweaks.
- **Exported backups no longer linger in the app's share cache**: the plaintext
  copy the share sheet works from is removed as soon as the share is dismissed,
  and any copy left by a completed share is cleaned up on the next export.
- **Android cloud Auto Backup no longer uploads the rotating JSON backups**
  alongside the database — they are the same data twice, doubled the cleartext
  copies in Google Drive, and ate into the backup quota. Device-to-device
  transfer still carries everything.

### Fixed
- **Trends no longer warn about a parameter that is recovering**: a value
  outside its range but moving back toward green used to get an "attention in
  ~N days" forecast for crossing the *far* boundary; it now simply shows the
  improving direction with no false alarm.
- **Trend forecasts are less swayed by a single noisy reading**: the projection
  now starts from the fitted trend line instead of the raw last measurement, so
  one outlier test result can no longer flip "fine" into "critical in ~4 days".
- The dose calculator now gives **correct guidance when nothing is dosed**: a
  rising element says "no dose needed" instead of "reduce or pause dosing", and
  any real consumption recommends starting a dose instead of "keep your current
  dose" (of nothing).
- **Zone limits restored from an edited or corrupted backup can no longer paint
  every reading amber**: limits that contradict their own ordering are treated
  as unset (gray/unknown) until re-saved. Amber-only limits now draw their green
  chart band, so the chart no longer contradicts the tile color.
- A ratio card whose two measurements are **more than 30 days apart** now shows
  its value muted instead of confidently health-colored — e.g. today's
  phosphate against a months-old nitrate is not a current ratio.
- A health-score input carrying a value without a timestamp is now treated as
  stale instead of eternally fresh (defensive; not reachable from the app's own
  data).
- **Importing a backup with unrecognizable aquarium-type or dosing lifecycle
  values is now rejected** with a clear message instead of restoring rows the
  app can neither display correctly nor manage.
- A **binary or non-text file renamed to `.json`** now gets the specific "not a
  backup file" message on import instead of a generic "import failed".
- A backup file whose version field is **missing or damaged** (e.g. truncated
  by a failed download) is no longer misreported as "backup from a newer app".

### Added
- Settings now shows a **persistent warning when the last backup attempt
  failed** ("Last backup failed on …"), cleared automatically by the next
  successful backup. Previously a failing backup was completely silent, so you
  could believe you were protected while nothing was being written.

### Changed
- Screens that show a lot of history (measurements, charts, water/carbon/cleaning
  logs, and dosing) now load faster and stay snappy as your log grows, thanks to
  new database indexes on the most-used lookups.

### Fixed
- **Database errors are no longer invisible**: when reading data fails (e.g. a
  damaged database), the app now shows a "Some data failed to load" warning and
  logs the error, instead of silently rendering the affected screens as if the
  tank were empty.
- **Cancelling the time picker now aborts** when logging a reading, water
  change, or cleaning at a custom date & time — previously the entry was
  silently recorded at midnight of the chosen day.
- **Backups no longer stop silently after a clock rollback**: if the device
  clock moves backwards past the last-backup timestamp, the next
  launch/resume takes a backup immediately instead of waiting for the clock to
  catch up.
- A manual **"Back up now" no longer races the automatic backup**: the two are
  serialized, and backup filenames carry millisecond timestamps, so two
  backups written in the same second can no longer overwrite each other.
- Backup filenames are stamped in **UTC**, so the repeated hour at the end of
  daylight-saving time can no longer make the rotation delete a newer backup
  before an older one.
- Readings are now **sanity-checked when saving**: physically impossible values
  (a negative concentration, salinity below pure water) are rejected with a
  clear message, and values outside the typical range (e.g. magnesium 1.3 ppm —
  usually a typo or a decimal-separator slip) ask for confirmation showing the
  value as the app understood it, so extreme-but-real readings stay recordable.
- The **water-change and carbon-dosing dialogs** no longer silently discard an
  unreadable amount (e.g. `5o`) or accept a negative one — invalid input now
  shows an error instead of saving "Amount not recorded".
- The **supplement form validates the dosage and schedule**: a garbage amount is
  no longer silently dropped, and "every N days" requires a whole number of at
  least 1 — schedules like "Every 0 days" can no longer be stored (previously
  they silently skewed the dose calculator as if dosing daily; existing bad rows
  are now treated as an unknown schedule instead).
- Adding a parameter after removing another **no longer duplicates its dashboard
  position**, which could make the parameter order ambiguous.
- Restoring a **crafted or corrupted backup with absurd row ids** (which could
  permanently prevent the app from ever saving new readings) is now rejected by
  backup validation.
- Navigating away from the home screen and back (e.g. a deep link that falls
  back to home) no longer breaks the **feature-tour overlay**: during a route
  swap the incoming home screen registered its tour scope before the outgoing
  one cleaned up, and the cleanup tore down the fresh registration.
- Restoring a backup no longer overwrites **this device's own preferences**
  (language, units, active aquarium, chart range, trend/health display, and the
  automatic-backup settings). Only your aquarium data is replaced, so importing a
  backup — even one made on another device — keeps your local settings intact.
- Typed numbers are now understood **according to your language's number
  format**: `1,300` means thirteen hundred in English but 1.3 in
  Czech/German/Polish/Russian, thousands separators (`1,300` / `1.300` /
  `1 300`) are recognized, and input mixing both separators (`1.234,5`) is
  rejected instead of being silently misread as a wildly wrong value.
- **Automatic backups are written atomically.** A backup interrupted mid-write
  (full storage, app killed) can no longer leave a truncated file that would
  count as the newest backup and push valid older backups out of the rotation.
- Tapping **Save twice quickly on a supplement** no longer creates duplicate
  dosing entries or duplicate dose-history segments.
- Opening a tank or parameter **edit screen from a link or a restored session**
  no longer crashes (parameters) or shows a blank "new tank" form under an edit
  URL (tanks) — the item is now looked up by its id.
- Fixed rare crashes when the **tank start-date or dose-time picker** was still
  open while its screen was closed.

## [0.15.2] - 2026-07-01

### Added
- The Backup settings now show **when the last backup ran** and offer a one-tap
  **Back up now** button, so it's clear your data is protected. A manual backup
  is saved into the same rotating on-device backup list as the automatic ones.

### Changed
- The restore confirmation now **warns that restoring replaces your app
  settings too** (language, units, and preferences), not just your aquarium data.
- Swiping away a reading or an action now **deletes it immediately with an
  "Undo" option** in a SnackBar, instead of a confirmation dialog — faster for
  the common case and safe against accidental swipes. Readings that were entered
  together still ask whether to delete only that value or all of them first.

## [0.15.1] - 2026-07-01

### Added
- A **Dosing history** screen (from the history icon on the Dosing tab) shows
  every past and current dose period per supplement — including stopped ones —
  with the option to permanently delete a record entered by mistake.
- The dose calculator now **warns when the dose changed within the measurement
  window**, so a mid-window adjustment no longer silently skews the consumption
  and dose-recommendation figures.

### Changed
- Dosing entries now **keep their history**. Adjusting a dose (amount, product,
  element, or schedule) no longer overwrites the old values: the previous dose
  period is retained and a new one starts, recording exactly when it changed.
- Swiping a supplement now **stops** it (removing it from the active plan while
  keeping its history) instead of permanently deleting it.

## [0.15.0] - 2026-07-01

### Added
- Dosing entries can now be **reordered** by dragging the handle on each row;
  the new order is saved per tank.

### Fixed
- Readings, water changes and cleanings can no longer be dated in the future:
  the date/time picker is capped at the current moment, so a future timestamp
  can't skew trends, freshness or "time ago" labels or get clipped off charts.
- Freshness, "time ago" and "not tested for N days" no longer misbehave when a
  timestamp is in the future or the device clock moves: ages are clamped to zero
  instead of going negative, and day counts are rounded rather than truncated so
  the staleness cutoff and the displayed day count agree.
- Dosing entries no longer occasionally jump position after deleting one and
  adding another (new entries are now ordered after the current maximum instead
  of by row count, which could collide).
- In the comparison view, a parameter's header value now reflects the latest
  reading within the selected range instead of the newest reading overall, so a
  zone-colored value no longer appears above a "No readings in range" chart.
- Chart zone bands no longer overlap or invert when a parameter has one-sided
  or partial green/amber bounds: the green band now falls back to the matching
  amber bound (never the chart edge) so it can't paint over the red band, and
  any band that would render with a zero or inverted height is skipped.
- The parameter and ratio bound editors now reject saving an amber boundary
  without its matching green boundary on the same side — the configuration that
  produced the misleading chart bands — with a clear validation message.
- The first-run feature tour is now marked as seen only when it actually ends
  (its final step finishes, or it is skipped) instead of the moment it starts,
  so a tour interrupted by backgrounding, rotating, or killing the app replays
  on the next launch rather than being lost half-seen.
- Editing a reading now validates the value field: a blank or unparseable entry
  shows an inline error and keeps the dialog open instead of silently reverting
  to the original value, so a mistyped edit can no longer look like it saved.

## [0.14.1] - 2026-06-30

### Changed
- The active tank on the Manage Aquariums screen is now marked with an "Active"
  badge next to its name; its icon is the default colour instead of being tinted
  blue, matching the other list icons.
- The Aquariums row in Settings now opens the Manage Aquariums screen.

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
