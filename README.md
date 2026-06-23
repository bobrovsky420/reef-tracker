# ReefTracker

An offline-first mobile app to track water parameters in reef aquariums, with
history, time-series graphs, and at-a-glance health zones.

## Features

- **Multiple aquariums** with quick switching from the app bar.
- **Typical reef parameters** to choose from: temperature, pH, salinity,
  alkalinity, calcium, magnesium, nitrate, phosphate, ammonia, nitrite, ORP,
  potassium, strontium, iodine.
- **Green / amber / red zones** per parameter:
  - green = value is OK,
  - amber = needs attention,
  - red = act immediately.
- **Setup-type presets** (Fish-only/FOWLR, Soft, LPS, SPS, Mixed reef) seed
  sensible default boundaries — every bound is editable per tank.
- **History & charts**: time-series graph per parameter with colored zone
  bands and 7d/30d/90d/all ranges; edit or delete past readings.
- **Local & offline**: all data stored on-device (SQLite). No account, no
  server.

## Tech stack

Flutter • Riverpod • Drift (SQLite) • fl_chart • go_router

## Project layout

```
lib/
  domain/      zone logic, parameter catalog, setup-type presets (pure Dart)
  data/        Drift database, tables, DAOs (database.g.dart is generated)
  app/         Riverpod providers + go_router routes
  features/    dashboard, tanks, manage_parameters, add_reading, history, settings
  widgets/     shared widgets (zone chip)
test/          unit tests for zone classification and preset integrity
```

## Developing

This project targets Android first; the code is cross-platform and iOS support
can be added later on a Mac with `flutter create --platforms ios .`.

```bash
flutter pub get
dart run build_runner build      # (re)generate Drift code after DB changes
flutter analyze
flutter test
flutter run                      # on a connected device/emulator
flutter build apk                # release APK
```

> Note: if the repo lives inside a OneDrive folder, Flutter's build
> directories are redirected outside OneDrive via NTFS junctions to avoid file
> locking during builds.
