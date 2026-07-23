# ReefTracker

An offline-first mobile app for reef aquarium keeping, shipping on **Android
and iOS** from one Flutter codebase. Track water parameters with color-coded
health zones, history graphs and trends, dosing, maintenance schedules,
reminders, and safe backups. All data stays on-device (SQLite) — no account,
no server, no ads.

The app has a free **Standard** edition and a **Pro** tier; the feature/edition
registry lives in [lib/domain/pro_features.yaml](lib/domain/pro_features.yaml).

## Features

The full user-facing overview (one row per feature, marked Standard or Pro) is
[docs/features.html](docs/features.html), published at
[reeftracker.org/features.html](https://reeftracker.org/features.html). Highlights:

- **Parameter tracking** — core reef parameters plus a 33-element ICP micro
  panel; green / amber / red zones per value; setup-type presets (fish only,
  soft, LPS, SPS, mixed) with every bound editable per tank; batch entry, test
  sets, typo protection.
- **Multiple aquariums** with one-tap switching (2 in Standard, unlimited in
  Pro).
- **Dashboard & health** — gauge dials, a 0–100 tank health score, stability
  score (Pro), rule-based on-device smart insights (Pro), parameter ratios,
  and a free (toxic) ammonia estimate.
- **Graphs & trends** — zone bands behind the data, pinch-zoom/pan, trend
  regression with early-warning forecasts ("amber in ~5 d"), compare view,
  share as image.
- **Measurement import & meters** (Pro) — Hanna Lab CSV import, live Bluetooth
  measurements on a Hanna HI97115C photometer *(experimental)*, and a camera
  scan of pocket-checker LCDs using a pure-Dart on-device seven-segment
  decoder *(experimental)*.
- **Dosing** — plans with schedules, a verified supplement catalog, dosing
  history, and consumption/correction dose calculators (Pro).
- **Maintenance & reminders** — action log (water changes, media, cleanings),
  elastic maintenance schedules, testing/dosing reminders as local
  notifications; RO/DI unit stage tracking with replacement reminders.
- **Backup & export** — integrity-checked backup/restore, automatic local
  backups, Google Drive sync (Android, Pro), CSV export, and an "Ask your AI"
  tank summary export.
- **Experience** — 7 languages (en, cs, de, fr, it, pl, ru), light/dark
  themes, unit preferences (°C/°F, ppt/SG, L/gal) over canonical storage.

## Tech stack

Flutter (Material 3) • Riverpod 3 • Drift (SQLite) • fl_chart • go_router •
gen-l10n + intl • flutter_local_notifications • share_plus + file_picker
(backup I/O) • google_sign_in (Drive sync) • flutter_blue_plus 1.x (Hanna BLE)
• camera (checker scan)

> ⚠️ Several plugins are pinned to exact versions for toolchain/licensing
> reasons — see the comments in [pubspec.yaml](pubspec.yaml) before bumping
> anything.

## Project layout

```
lib/
  domain/    pure Dart business rules; YAML catalogs (*.yaml) → generated *.g.dart
  data/      Drift database, backup, CSV export, notifications, cloud sync, Hanna BLE
  app/       Riverpod providers, go_router routes, theme
  features/  one folder per screen (dashboard, history, dosing, actions, micro, scan, …)
  l10n/      ARB translations + generated AppLocalizations
  widgets/   shared widgets
tool/        generators for the YAML-driven domain catalogs
scripts/     Windows build scripts (junction healing, safe clean, release build)
test/        unit, widget and golden tests
integration_test/, test_driver/   store-screenshot harness
```

Companion docs: [DESIGN.md](DESIGN.md) (architecture, kept current),
[docs/features.html](docs/features.html) (user-facing features),
[CHANGELOG.md](CHANGELOG.md), [HANNA.md](HANNA.md) (Hanna meter protocol),
[CLAUDE.md](CLAUDE.md) (contribution rules: versioning, localization,
platform parity).

## Developing

```bash
flutter pub get
flutter gen-l10n                     # localization codegen after editing lib/l10n/*.arb
dart run build_runner build          # Drift codegen after DB schema changes
flutter analyze
flutter test
flutter run                          # on a connected device/emulator
```

The domain catalogs (parameters, presets, supplements, micro views, Pro
registry, Hanna methods, RO defaults) are edited as YAML in `lib/domain/` and
regenerated with the `tool/gen_*.dart` scripts. **Order matters:**
`build_runner` deletes the catalog `.g.dart` files as unclaimed outputs, so
run the catalog generators after it — `gen_parameters` first, then
`gen_supplements` (which imports the parameter catalog); the rest are
order-free.

Every user-facing string must be localized in **all** seven ARB files — see
the localization rules in [CLAUDE.md](CLAUDE.md).

### Windows builds: junctions, not `flutter clean`

`build/` and `.dart_tool/` are NTFS junctions pointing to
`C:\Android\reefbuild\` (a leftover of the repo's OneDrive days, kept because
they still isolate build churn). **Never run `flutter clean`** — it deletes
the junctions. Use the scripts instead (see
[scripts/README.md](scripts/README.md)):

```powershell
scripts\safe-clean.ps1      # replaces `flutter clean`
scripts\build-release.ps1   # signed release AAB (heals junctions first)
```

### iOS

iOS cannot be built on Windows; release builds run on Codemagic
([codemagic.yaml](codemagic.yaml)) — a manually triggered workflow that
builds a signed IPA and uploads it to TestFlight. The app is iPhone-only.

### CI

Every push/PR to `master` runs GitHub Actions: format check, a
regenerate-and-diff guard over all committed generated sources, `flutter
analyze`, `flutter test --coverage`, and a debug APK build.
