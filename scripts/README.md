# Build scripts

This repo used to live inside OneDrive, which locks Flutter's churning build
files. It has since moved to `C:\Dev\ReefTracker` (out of OneDrive), but the
volatile build directories remain **NTFS directory junctions** pointing to
`C:\Android\reefbuild\ReefTracker\` (override with the `REEFBUILD_ROOT` env
var), so the `flutter clean` pitfall below still applies:

| Link (in repo)    | Target                                          |
|-------------------|-------------------------------------------------|
| `build`           | `…\reefbuild\ReefTracker\build`                 |
| `.dart_tool`      | `…\reefbuild\ReefTracker\dart_tool`             |
| `android\.gradle` | `…\reefbuild\ReefTracker\android_gradle`        |
| `android\.kotlin` | `…\reefbuild\ReefTracker\android_kotlin`        |

## ⚠ Never run `flutter clean` here

`flutter clean` **deletes the junction links**. The next build then recreates
them as real folders *inside* OneDrive, so the artifact lands in OneDrive and the
out-of-OneDrive target stays stale — plus the file-lock failures come back. Use
the scripts below instead; they heal the links before touching anything.

## Scripts

Run from the repo root (PowerShell 7 / `pwsh`):

```powershell
# Build a signed release AAB — heals junctions first, then builds & verifies.
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1

# Replace `flutter clean` (empties the caches, keeps the junctions).
powershell -ExecutionPolicy Bypass -File scripts\safe-clean.ps1

# Just repair clobbered junctions (e.g. after an accidental `flutter clean`).
powershell -ExecutionPolicy Bypass -File scripts\heal-junctions.ps1
```

`build-release.ps1` heals the junctions **before** building, so even a stray
`flutter clean` can't strand the output in OneDrive. The finished AAB is reported
at its real location: `…\reefbuild\ReefTracker\build\app\outputs\bundle\release\app-release.aab`.

If `heal-junctions` had to rebuild `.dart_tool`, run `flutter pub get` afterwards
(`build-release.ps1` does this for you).
