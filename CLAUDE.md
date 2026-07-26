# ReefTracker

## Design documentation

[DESIGN.md](DESIGN.md) is the high-level map of the app's architecture and most important features. **Keep it up to date: after any change that alters the design, update the relevant section of `DESIGN.md` in the same change.** This includes new or changed database tables/migrations, new screens or routes, new domain rules, new features, or changes to the layering/state model. Skip updates for purely cosmetic or trivial edits that don't affect the design (wording tweaks, styling, refactors with no behavioral or structural effect).

## Feature overview

[docs/features.html](docs/features.html) is the **user-facing** feature overview, published on the website (marketing/store-adjacent wording, one table row per feature, each marked Standard or **PRO**). **Update it in the same change whenever a feature is added, meaningfully changed, removed, or re-tiered** — including when a feature's edition assignment in `lib/domain/pro_features.yaml` changes. Write it for reef keepers, not developers: what the feature does for them, no implementation detail. It is a hand-maintained HTML page in the site's shared style (en dashes, PRO/EXPERIMENTAL pills, dark-mode CSS variables) — keep new rows consistent with that. Skip it for internal changes with no user-visible feature impact (bug fixes, refactors, UI polish that doesn't add capability).

## Platform parity (Android + iOS)

The app ships on **both Android and iOS** from this single Flutter codebase. Pure Dart changes (`lib/`, l10n, tests) apply to both platforms automatically — nothing extra to do. But **whenever a change touches anything platform-sensitive, apply it to both platforms in the same change**, or state explicitly why one side is deferred:

- New dependencies with native code → verify setup on both sides: [android/](android/) (manifest entries, permissions, Gradle config) **and** [ios/](ios/) (`Info.plist` usage keys, capabilities). Don't assume a plugin that works on Android is configured for iOS.
- Features involving permissions, notifications, file access, sharing, deep links, background work, or app icons/splash are the usual suspects — check both platforms even when the Dart code is shared.
- Avoid `Platform.isAndroid`/`isIOS` branching unless genuinely required (there is currently none in `lib/` — keep it that way where possible). If you must branch, implement and test both branches.
- iOS builds only on macOS/CI (Codemagic) — it cannot be built or run on this Windows machine. When a change affects iOS behavior but can't be validated locally, say so in the changelog/commit rather than silently assuming it works.

## Run it on the emulator

`flutter analyze` and a green `flutter test` prove the code compiles and its units behave. They do **not** prove the feature works. **Whenever a change adds or meaningfully alters something a user can see or do, run it on the Android emulator and look at it before calling it done** — navigate to the feature, exercise its main path, and read the screenshots. Report what you actually saw; if you couldn't run it, say so plainly rather than implying it works.

Skip it only when there is nothing to look at: pure refactors, docs, generator/tooling changes, and fixes fully pinned by a test. When in doubt, run it — the cost is a few minutes.

The mechanics on this machine (see also the toolchain notes in memory):

- Boot: `C:\Android\Sdk\emulator\emulator.exe -avd reef_pixel` (also `reef_tab7` / `reef_tab10` / `reef_iphone` for the store-screenshot sizes). Wait on `adb shell getprop sys.boot_completed`.
- **Don't drive the app with `flutter run` from a non-interactive shell** — it reads EOF on stdin and quits, terminating the app. Build/install once, then launch with `adb shell monkey -p cz.reeftracker.reeftracker -c android.intent.category.LAUNCHER 1` so the app outlives the tooling.
- A debug build's cold start on this emulator reliably trips Android's "isn't responding" dialog, which then steals every tap. `adb shell settings put global hide_error_dialogs 1` once per boot removes it; it is an emulator artifact, never a finding about the change.
- Drive with `adb shell input tap/text/swipe` and capture with `adb exec-out screencap -p`. **Look at each screenshot** — a blank or unchanged frame is a failure, not a pass.

**Features that talk to hardware get a fake device, committed under [tool/](tool/).** The app integrates devices most contributors (and the maintainer) don't own, so "untestable without the hardware" would mean untested forever. Write a small `dart:io` server that speaks the real protocol — [tool/apex_emulator.dart](tool/apex_emulator.dart) is the reference: it serves both Apex firmware families, drifts its values, and exposes `/emu/*` endpoints to force a state worth seeing. Two rules make it pay off twice: **the Android emulator reaches the host at `10.0.2.2`** (`10.0.2.2:8080`, entered as the device address), and the server class must be **importable, so a test can drive the real transport against it** ([test/ap_device_link_test.dart](test/ap_device_link_test.dart)) rather than only hand-written fixtures. Say explicitly in the changelog or commit when a feature has only ever been exercised against the fake and never against real hardware.

## Version bumping

The version lives in [pubspec.yaml](pubspec.yaml) as `major.minor.patch+build`.

**Never bump the version as part of an ordinary change.** Feature work, fixes and refactors leave `pubspec.yaml` untouched — their changelog entries accumulate under `## [Unreleased]` (see below). Producing a local release build for testing is **not** a release and does not justify a bump.

Bump **only when the user explicitly says they are cutting a release** ("release this", "ready to release", "bump the version"). At that moment, pick the new number from what has accumulated under `## [Unreleased]`:

- Contains any new feature → bump the **minor** version, reset patch to 0.
- Only fixes / small improvements to existing features → bump the **patch** number.
- **Major** bumps are never inferred — only when the user asks for one by name.

Always increment the `+build` number by 1 on any version change (it must stay monotonic for Android's `versionCode` and iOS's `CFBundleVersion`). Also increment it alone (leaving `major.minor.patch` as is) if a build of an already-released version has to be uploaded to a store again — both stores reject a re-used build number.

**Internal testing builds are not releases.** To upload a work-in-progress build to Play internal testing or TestFlight, increment **only** the `+build` number and leave `major.minor.patch` at the last released version. Both stores require a unique, increasing build number per upload but allow the version name to repeat, and the app shows `version+build` in-app ([appVersionProvider](lib/app/providers.dart)), so testers and bug reports can still identify the exact build. Never use a pre-release version name (`1.1.0-rc.1`) to mark a test build — Flutter maps it to iOS `CFBundleShortVersionString`, which must stay numeric.

When the release itself is cut, bump `major.minor.patch` (+ build) as above, write the store release notes for it (see [Release notes](#release-notes)), upload **that** build to internal testing as the release candidate, and promote the same artifact to production once verified — don't rebuild between testing and release.

**Both platforms share this one version stream** — Flutter maps it to Android `versionName`/`versionCode` and iOS `CFBundleShortVersionString`/`CFBundleVersion` automatically; never fork per-platform versions. A given version may be released to only one store (the other store simply skips it — both tolerate gaps as long as the build number is monotonic).

## Changelog

[CHANGELOG.md](CHANGELOG.md) follows [Keep a Changelog](https://keepachangelog.com/) format. **Update it with every change that affects users or behavior, in the same change.** Add entries under the appropriate version heading, grouped into `Added` / `Changed` / `Fixed` / `Removed` — always keep the groups within a version section in that order. Entries for unreleased work go under a `## [Unreleased]` heading at the top of the file, **with no date** — create it if it isn't there, and never write entries into an already-released version's section. When the user cuts a release, rename that heading to `## [<version>] - <YYYY-MM-DD>` with the release date. Don't leave an empty `## [Unreleased]` behind afterwards; the next change recreates it. Skip purely internal edits with no user-facing or behavioral effect (formatting, comments).

There is **one changelog for both platforms**: prefix an entry with `iOS:` or `Android:` when it applies to a single platform; untagged entries apply to both. Store release notes (Play "What's new", App Store "What's New") are curated, localized excerpts written per release — CHANGELOG.md stays the English master.

## Release notes

**Every release build must ship with store release notes**, written in the same change that cuts the release — a release is not complete until they exist. They are the text attached to the upload in Play ("What's new") and App Store Connect ("What's New").

- They live in `store_assets/release_notes/<version>/<lang>.txt` — one plain-text file per language, named with the same language codes as the ARB files (`en`, `cs`, `de`, `ru`, `pl`, `fr`, `it`). **All languages are required**, same rule as [Localization](#localization) below: no language may be left out.
- Source them from that version's `CHANGELOG.md` section, rewritten for reef keepers: what they get, not what changed in the code. Drop entries with no user-visible effect.
- **Keep each file under 500 characters** — that is Play's hard limit per language, and the App Store's larger limit is satisfied automatically by the same text.
- Short bullet lines (`•` or `-`), no version number, no date, no headings — the stores render the text as-is under their own version heading.
- Both stores get the same text per language; write it once. If an entry applies to one platform only, simply leave it out of the other store's notes rather than tagging it the way CHANGELOG.md does.

Internal testing uploads (build-number-only bumps, see [Version bumping](#version-bumping)) do **not** need localized notes — a one-line English "what to test" in the Play/TestFlight field is enough, and nothing is committed for them.

## Localization

This app is fully localized. **Whenever you add or change any user-facing text, you MUST update the translations for every existing language — no language may be left out of sync.**

- ARB files live in [lib/l10n/](lib/l10n/). The template is [app_en.arb](lib/l10n/app_en.arb).
- Existing languages: English (`app_en.arb`), Czech (`app_cs.arb`), German (`app_de.arb`), Russian (`app_ru.arb`), Polish (`app_pl.arb`), French (`app_fr.arb`), Italian (`app_it.arb`).
- Config: [l10n.yaml](l10n.yaml).

Rules:
- Never hardcode user-facing strings in widgets. Add a key to the template ARB and reference it via the generated localizations.
- When you add a key, add it to **all** `app_*.arb` files with a proper translation (not just a copy of the English text).
- When you change or remove a key, apply the same change across **all** `app_*.arb` files.
- Keep `@<key>` metadata (descriptions, placeholders) in the template ARB up to date.
- After editing ARB files, regenerate the localizations (`flutter gen-l10n`) and ensure every language still builds.
