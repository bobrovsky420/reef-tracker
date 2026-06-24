# ReefTracker

## Design documentation

[DESIGN.md](DESIGN.md) is the high-level map of the app's architecture and most important features. **Keep it up to date: after any change that alters the design, update the relevant section of `DESIGN.md` in the same change.** This includes new or changed database tables/migrations, new screens or routes, new domain rules, new features, or changes to the layering/state model. Skip updates for purely cosmetic or trivial edits that don't affect the design (wording tweaks, styling, refactors with no behavioral or structural effect).

## Localization

This app is fully localized. **Whenever you add or change any user-facing text, you MUST update the translations for every existing language — no language may be left out of sync.**

- ARB files live in [lib/l10n/](lib/l10n/). The template is [app_en.arb](lib/l10n/app_en.arb).
- Existing languages: English (`app_en.arb`), Czech (`app_cs.arb`).
- Config: [l10n.yaml](l10n.yaml).

Rules:
- Never hardcode user-facing strings in widgets. Add a key to the template ARB and reference it via the generated localizations.
- When you add a key, add it to **all** `app_*.arb` files with a proper translation (not just a copy of the English text).
- When you change or remove a key, apply the same change across **all** `app_*.arb` files.
- Keep `@<key>` metadata (descriptions, placeholders) in the template ARB up to date.
- After editing ARB files, regenerate the localizations (`flutter gen-l10n`) and ensure every language still builds.
