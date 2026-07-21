# ReefTracker — Feature Overview

ReefTracker is an offline-first reef-aquarium companion for Android and iOS.
Log your water tests in seconds and see at a glance whether every value is
healthy — with color-coded safe ranges, history graphs, trends and early
warnings, dosing tools, maintenance reminders, and safe backups. Everything is
stored on your device: no account, no cloud requirement, no ads.

Each feature below is marked **Standard** (included for everyone) or **Pro**
(part of the ReefTracker Pro tier).

---

## Water parameter tracking

| Feature | Edition |
|---|---|
| Core reef parameters: temperature, pH, salinity, alkalinity, calcium, magnesium, nitrate, phosphate, ammonia, nitrite, ORP | Standard |
| Color-coded health zones — every value classified green / amber / red against its safe range | Standard |
| Setup-type presets: fish-only, soft coral, LPS, SPS and mixed tanks each come with recommended parameters and safe ranges | Standard |
| Fully editable safe ranges per parameter, per aquarium — tune the app to *your* tank's targets | Standard |
| Choose which parameters to track, and in what order they appear | Standard |
| Batch reading entry — log a whole test session at once, kept together as one session | Standard |
| Test sets — named parameter groups (e.g. "Daily test", "Weekly test") to speed up routine entry | Standard |
| Typo protection — physically impossible values are rejected, implausible ones ask for confirmation before saving | Standard |
| Notes on every reading, water change and maintenance event | Standard |
| Sensible display precision and units per parameter (e.g. nitrite in ppb) | Standard |

## Multiple aquariums

| Feature | Edition |
|---|---|
| Up to 2 aquariums (e.g. a display tank and a quarantine tank), each with its own parameters, ranges, history and dosing | Standard |
| Unlimited aquariums | **Pro** |
| One-tap aquarium switcher from the top bar | Standard |
| Per-tank profile: name, setup type, volume, start date, vendor/model, notes | Standard |
| Deleted aquariums can be restored with Undo before the deletion becomes final | Standard |

## Dashboard & tank health

| Feature | Edition |
|---|---|
| Grouped dashboard with gauge dials for chemistry and nutrients, compact environment pills, and a combined ratios card | Standard |
| Alternative "Flat" dashboard layout — one custom-ordered grid of cards | Standard |
| Tank health score — a 0–100 score with a grade (excellent / good / caution / critical), weighted by parameter importance and never letting one red value hide behind greens | Standard |
| Per-parameter health breakdown — see exactly which values drag the score down | Standard |
| Tank stability score — the second axis of tank health: how much values have been *swinging* over the last 30/60/90 days, independent of where they sit now | **Pro** |
| Smart insights — a short, prioritized list of plain-language observations: out-of-range values, predicted problems, recovering parameters and overdue tests. Computed entirely on-device by deterministic rules — no AI service, no network | **Pro** |
| Freshness awareness — readings older than 30 days are surfaced as stale instead of silently coloring the dashboard | Standard |
| Parameter ratios with recommended zones: PO₄ : NO₃, Mg : Ca, Ca : Alk, Mg : Alk | Standard |
| Free (toxic) ammonia estimate — derives un-ionized NH₃ from your ammonia, pH, temperature and salinity using published scientific models (Emerson 1975, US EPA 1989), shown against EPA-anchored toxicity limits | Standard |

## Graphs, history & trends

| Feature | Edition |
|---|---|
| History graph for every parameter with the safe range shaded behind the data | Standard |
| Pinch-zoom and pan on all graphs, double-tap to reset | Standard |
| Min / Avg / Max / test-count statistics per parameter and time range | Standard |
| Compare view — all parameter graphs on one screen | Standard |
| Ratio graphs with the same zoom, pan and value popups as parameter graphs | Standard |
| Trend detection — a regression over your recent readings shows the direction and per-day rate of change | Standard |
| Early-warning forecast — projects when a drifting value will leave its safe range ("amber in ~5 d"), before it happens | Standard |
| Recovery detection — a value moving back toward its safe range is recognized as improving, not flagged as a problem | Standard |
| Share any graph as an image | Standard |
| Edit or delete past readings, including whole test sessions, with Undo | Standard |

## Microelements & ICP

| Feature | Edition |
|---|---|
| Full 33-element trace panel — majors, trace elements and contaminants, matching professional ICP reports | Standard |
| Default safe ranges per element anchored on natural seawater and ICP-lab targets; contaminants use one-sided "up to a ceiling" ranges | Standard |
| ICP-style units: mg/L for majors, µg/L for traces and contaminants | Standard |
| Hobby-kit filter — quick entry for the elements home test kits exist for (strontium, iodine, iron) | Standard |
| Custom element views — save the exact element set your lab reports, plus built-in presets (Full list, Fauna Marin ICP) | Standard |
| Microelement summary card on the dashboard: how many measured, how many out of range, worst status, last test date | Standard |
| ICP report import — load a Fauna Marin or ATI/ZIMS ICP report file and store the whole analysis in one step | **Pro** |

## Measurement import & meters

| Feature | Edition |
|---|---|
| Hanna Lab file import — import the test history CSV shared from the Hanna Lab app (HI97115 Marine Master): original timestamps, grouped test sessions, smart de-duplication so re-imports only add what's new, and a one-tap undo | **Pro** |
| Import status per aquarium, with rewind/reset controls that never create duplicates | **Pro** |
| Hanna checker direct connection *(experimental)* — run measurements live over Bluetooth on a Hanna HI97115C photometer, method by method or via saved test sets, and save the confirmed results with the meter's timestamps | **Pro** |
| Checker display scan *(experimental)* — point the camera at a Hanna pocket checker's LCD and save the shown value without typing; 14 checker models supported, recognition runs fully on-device (no photos stored or uploaded) | **Pro** |

## Dosing & supplements

| Feature | Edition |
|---|---|
| Dosing plan per aquarium — record what you dose, how much and on which schedule (daily, every N days, or fixed weekdays) | Standard |
| Built-in supplement catalog of reef brands and dosing programs, with verified product potencies | Standard |
| Custom products for anything not in the catalog | Standard |
| Manual dose log — one-off doses, vitamins and medications, logged outside the regular plan | Standard |
| Dosing history — every past plan and change is kept as dated history, not overwritten | Standard |
| Element status tags — each supplement is tagged with the current dashboard status of the element it targets | Standard |
| Dose calculator (consumption mode) — computes your tank's actual daily consumption from recent readings and doses, and recommends whether to raise, lower or keep the current dose | **Pro** |
| Correction dose calculator — computes the one-off dose to lift an element to its target, and automatically splits it over several days when the rise would exceed the element's safe daily limit | **Pro** |
| Per-parameter correction targets, pre-seeded from your tank's setup type | Standard |
| Calculator shortcuts from a parameter's graph, including a "below range" prompt that jumps straight into correction mode | **Pro** |

## Maintenance, actions & reminders

| Feature | Edition |
|---|---|
| Action log: water changes (with volume), carbon/media changes (with weight), equipment cleanings — all with notes and full history | Standard |
| Maintenance schedule — recurring or one-off tasks: every N days/weeks/months, fixed weekdays ("every Monday"), or a fixed day of month ("every 1st") | Standard |
| Elastic scheduling — completing a task resets its timer, so a late water change doesn't stack phantom overdue warnings | Standard |
| Due and overdue tasks surfaced on the Actions tab, one tap to mark done | Standard |
| Testing reminders — "remind me to test every N days" per parameter, including microelements | Standard |
| Dosing reminders at the scheduled dose time | Standard |
| Local notifications, grouped per aquarium and kind, with a configurable delivery time — all opt-in | Standard |

## Reverse-osmosis unit

| Feature | Edition |
|---|---|
| RO/DI unit tracking, shared across all aquariums — sediment, carbon block, membrane and DI resin stages plus custom stages | Standard |
| Per-stage lifespan with a remaining-life bar and green/amber/red due status | Standard |
| Replacement log with full history and Undo | Standard |
| Replacement reminders | Standard |

## Backup, export & sync

| Feature | Edition |
|---|---|
| Full backup to a single file, shared anywhere via the system share sheet | Standard |
| Safe restore — every backup is integrity-checked, validated and rehearsed on a scratch database before it touches your data; a bad file can never wipe the app | Standard |
| Automatic local backups on a schedule, with a configurable number kept | Standard |
| Google Drive backup sync (Android) — backups upload to your own Drive automatically and restore on a new device; the app can only see its own folder | **Pro** |
| Measurement export as CSV for spreadsheets, using stable column names that compare across app languages | Standard |
| "Ask your AI" export — a ready-to-paste summary of your tank (values, ranges, trends, dosing, maintenance) for ChatGPT, Claude or any AI chat; prepared entirely on your device, nothing is sent anywhere | Standard |
| Backups carry everything: aquariums, readings, ranges, dosing, maintenance, RO unit, import state — while device preferences (language, units, theme) stay per-device | Standard |

## Tools & calculators

| Feature | Edition |
|---|---|
| Salinity calculator — convert between ppt and specific gravity | Standard |
| Free ammonia explanation view — see the toxic-fraction math and the inputs behind the estimate | Standard |

## Experience & platform

| Feature | Edition |
|---|---|
| 100 % offline — all data lives on your device; no account, no sign-up, no tracking, no ads | Standard |
| Android and iOS from one codebase, with platform-native controls and styling on each | Standard |
| Light and dark themes: follow the system or pick one | Standard |
| Unit preferences: °C/°F, ppt/SG, liters/gallons — switching units never changes health colors, because values are stored canonically | Standard |
| 7 languages: English, Czech, German, French, Italian, Polish, Russian — including locale-aware number entry | Standard |
| First-run feature tour | Standard |
| Undo everywhere — deleting readings, tanks, plans, tasks or stopping a dosing plan can always be taken back | Standard |

---

*This document describes what each feature does, not how to use it — see the
in-app screens for usage. Feature/edition assignment reflects the Pro registry
(`lib/domain/pro_features.yaml`); experimental features are marked as such in
the app.*
