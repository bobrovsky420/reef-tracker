# ReefTracker

## Design documentation

[DESIGN.md](DESIGN.md) is the high-level map of the app's architecture and most important features. **Keep it up to date: after any change that alters the design, update the relevant section of `DESIGN.md` in the same change.** This includes new or changed database tables/migrations, new screens or routes, new domain rules, new features, or changes to the layering/state model. Skip updates for purely cosmetic or trivial edits that don't affect the design (wording tweaks, styling, refactors with no behavioral or structural effect).

## Version bumping

The version lives in [pubspec.yaml](pubspec.yaml) as `major.minor.patch+build`. When asked to bump the version, decide based on whether there are **uncommitted changes** in the working tree:

- **No uncommitted changes** (clean tree):
  - Bigger change (new feature) → bump the **minor** version (and reset patch to 0).
  - Smaller change (bug fix, small improvement to an existing feature) → bump the **patch** number.
- **Uncommitted changes still present** (the current working set already carries unreleased edits):
  - Bigger change (new feature):
    - if current patch > 0 → bump the **minor** version (reset patch to 0).
    - if current patch = 0 (minor was already bumped in this working set) → **do not change** the version.
  - Smaller change:
    - if current patch > 0 → **do nothing**.
    - if current patch = 0 → bump the **patch**.

Always increment the `+build` number by 1 on any version change (it must stay monotonic for Android).

## Changelog

[CHANGELOG.md](CHANGELOG.md) follows [Keep a Changelog](https://keepachangelog.com/) format. **Update it with every change that affects users or behavior, in the same change.** Add entries under the appropriate version heading, grouped into `Added` / `Changed` / `Fixed` / `Removed`. When the version is bumped (see above), add a new `## [<version>] - <date>` section for it; otherwise record entries under the most recent version section. Skip purely internal edits with no user-facing or behavioral effect (formatting, comments).

## Localization

This app is fully localized. **Whenever you add or change any user-facing text, you MUST update the translations for every existing language — no language may be left out of sync.**

- ARB files live in [lib/l10n/](lib/l10n/). The template is [app_en.arb](lib/l10n/app_en.arb).
- Existing languages: English (`app_en.arb`), Czech (`app_cs.arb`), German (`app_de.arb`), Russian (`app_ru.arb`), Polish (`app_pl.arb`).
- Config: [l10n.yaml](l10n.yaml).

Rules:
- Never hardcode user-facing strings in widgets. Add a key to the template ARB and reference it via the generated localizations.
- When you add a key, add it to **all** `app_*.arb` files with a proper translation (not just a copy of the English text).
- When you change or remove a key, apply the same change across **all** `app_*.arb` files.
- Keep `@<key>` metadata (descriptions, placeholders) in the template ARB up to date.
- After editing ARB files, regenerate the localizations (`flutter gen-l10n`) and ensure every language still builds.
