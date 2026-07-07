import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/backup.dart';
import '../domain/clock.dart';
import '../domain/health_score.dart';
import '../domain/ratio.dart';
import '../domain/ro.dart';
import '../domain/setup_type.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import 'app_localizations.dart';

/// Formats a date together with a time of day, choosing 12h (AM/PM) vs 24h
/// from the **device's** clock setting (`MediaQuery.alwaysUse24HourFormat`) —
/// the same signal the native time picker honors. `DateFormat.jm()` alone would
/// follow the app's Intl locale and force AM/PM for English regardless of the
/// user's regional 24-hour preference.
///
/// Set [weekday] to false in width-constrained spots (e.g. dialogs) to drop the
/// leading weekday so the date + time fit on one line.
String formatDateTime(BuildContext context, DateTime t, {bool weekday = true}) {
  final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
  final time = use24 ? DateFormat.Hm() : DateFormat.jm();
  final date = weekday ? DateFormat.yMMMEd() : DateFormat.yMMMd();
  return '${date.format(t)} ${time.format(t)}';
}

/// Date-only companion of [formatDateTime] (due dates, schedules) — follows
/// `Intl.defaultLocale`, which MaterialApp keeps in sync with the app locale.
String formatDate(DateTime t) => DateFormat.yMMMd().format(t);

/// "Just now" / "N min ago" / "N h ago" / "N d ago", falling back to a plain
/// date past a week — the timestamp line of the dashboard tiles and the
/// Microelements rows. `ageSince` clamps a future/clock-skewed timestamp to
/// zero → "just now" instead of a negative "-N min ago".
String relativeTimeLabel(AppLocalizations l, DateTime t) {
  final d = ageSince(t);
  if (d.inMinutes < 1) return l.timeJustNow;
  if (d.inMinutes < 60) return l.timeMinAgo(d.inMinutes);
  if (d.inHours < 24) return l.timeHoursAgo(d.inHours);
  if (d.inDays < 7) return l.timeDaysAgo(d.inDays);
  return DateFormat.yMMMd().format(t);
}

/// Localized short weekday names (e.g. "Mon, Thu") for [days] (1=Mon … 7=Sun,
/// rendered in ascending order). Shared by the dosing rows and the
/// maintenance-schedule subtitles.
String formatWeekdays(BuildContext context, Iterable<int> days) {
  // 2024-01-01 is a Monday; offset by (weekday-1) to reach each day.
  // `narrowWeekdays` is Sunday-first (index 0 = Sun) while DateTime.weekday is
  // 1 = Mon … 7 = Sun, so `% 7` folds Sunday (7) onto index 0.
  final base = DateTime(2024, 1, 1);
  return (days.toList()..sort())
      .map(
        (d) => MaterialLocalizations.of(
          context,
        ).narrowWeekdays[base.add(Duration(days: d - 1)).weekday % 7],
      )
      .join(', ');
}

/// Shows a date picker followed by a time picker and returns the composed
/// [DateTime], **clamped so it can never land in the future** — readings,
/// water changes and cleanings are always logged in the past or now. Returns
/// `null` if the user cancels either step (or the context unmounts): a
/// cancelled time picker aborts the whole pick rather than defaulting the
/// time to midnight (#16).
///
/// Guards two ways the native pickers could otherwise produce a future time:
/// the date page is capped at today (`lastDate: now`), and because
/// `showTimePicker` is unconstrained, the composed value is clamped down to the
/// current minute. [initial] seeds both pickers, itself clamped to now so an
/// already-future value can't push `initialDate` past `lastDate` (which asserts).
Future<DateTime?> pickPastDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final seed = initial.isAfter(DateTime.now()) ? DateTime.now() : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(seed),
  );
  if (time == null || !context.mounted) return null;
  final now = DateTime.now();
  final composed = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  // Truncate to the minute (readings group at minute precision) when clamping.
  return composed.isAfter(now)
      ? DateTime(now.year, now.month, now.day, now.hour, now.minute)
      : composed;
}

/// Localized labels for domain values (parameter names/help, setup types,
/// zones) that live as keys/enums rather than free text.
extension L10nDomain on AppLocalizations {
  String paramName(String key) {
    switch (key) {
      case 'temperature':
        return paramTemperature;
      case 'ph':
        return paramPh;
      case 'salinity':
        return paramSalinity;
      case 'alkalinity':
        return paramAlkalinity;
      case 'calcium':
        return paramCalcium;
      case 'magnesium':
        return paramMagnesium;
      case 'nitrate':
        return paramNitrate;
      case 'phosphate':
        return paramPhosphate;
      case 'ammonia':
        return paramAmmonia;
      case 'nitrite':
        return paramNitrite;
      case 'orp':
        return paramOrp;
      case 'potassium':
        return paramPotassium;
      case 'strontium':
        return paramStrontium;
      case 'iodine':
        return paramIodine;
      case 'iron':
        return paramIron;
      // Microelements (U17). Names carry the element symbol ("Zinc (Zn)") so
      // rows match the symbols on an ICP report.
      case 'sodium':
        return paramSodium;
      case 'sulfur':
        return paramSulfur;
      case 'boron':
        return paramBoron;
      case 'bromine':
        return paramBromine;
      case 'silicon':
        return paramSilicon;
      case 'zinc':
        return paramZinc;
      case 'vanadium':
        return paramVanadium;
      case 'copper':
        return paramCopper;
      case 'nickel':
        return paramNickel;
      case 'manganese':
        return paramManganese;
      case 'molybdenum':
        return paramMolybdenum;
      case 'chromium':
        return paramChromium;
      case 'cobalt':
        return paramCobalt;
      case 'lithium':
        return paramLithium;
      case 'barium':
        return paramBarium;
      case 'selenium':
        return paramSelenium;
      case 'aluminium':
        return paramAluminium;
      case 'antimony':
        return paramAntimony;
      case 'tin':
        return paramTin;
      case 'beryllium':
        return paramBeryllium;
      case 'silver':
        return paramSilver;
      case 'tungsten':
        return paramTungsten;
      case 'lanthanum':
        return paramLanthanum;
      case 'titanium':
        return paramTitanium;
      case 'zirconium':
        return paramZirconium;
      case 'arsenic':
        return paramArsenic;
      case 'cadmium':
        return paramCadmium;
      case 'mercury':
        return paramMercury;
      case 'lead':
        return paramLead;
      default:
        return key;
    }
  }

  String? paramHelp(String key) {
    switch (key) {
      case 'temperature':
        return helpTemperature;
      case 'salinity':
        return helpSalinity;
      case 'alkalinity':
        return helpAlkalinity;
      case 'nitrate':
        return helpNitrate;
      case 'ammonia':
        return helpAmmonia;
      default:
        return null;
    }
  }

  String setupLabel(SetupType type) {
    switch (type) {
      case SetupType.fishOnly:
        return setupFishOnly;
      case SetupType.soft:
        return setupSoft;
      case SetupType.lps:
        return setupLps;
      case SetupType.sps:
        return setupSps;
      case SetupType.mixed:
        return setupMixed;
    }
  }

  /// A canonical litre value formatted with its localized unit suffix in the
  /// user's preferred volume [unit] (e.g. "200 L" or "53 gal").
  String volumeWithUnit(double liters, VolumeUnit unit) {
    final value = formatVolume(liters, unit);
    switch (unit) {
      case VolumeUnit.liters:
        return litersSuffix(value);
      case VolumeUnit.gallons:
        return gallonsSuffix(value);
    }
  }

  /// Short label for a ratio card/segment (e.g. "PO₄ : NO₃", "Mg : Ca").
  String ratioCardLabel(RatioKind kind) {
    switch (kind) {
      case RatioKind.po4no3:
        return ratioPo4No3Label;
      case RatioKind.mgca:
        return ratioMgCaLabel;
      case RatioKind.caalk:
        return ratioCaAlkLabel;
      case RatioKind.mgalk:
        return ratioMgAlkLabel;
    }
  }

  /// Full title for a ratio screen (e.g. "PO₄ : NO₃ ratio").
  String ratioScreenTitle(RatioKind kind) {
    switch (kind) {
      case RatioKind.po4no3:
        return ratioPo4No3Title;
      case RatioKind.mgca:
        return ratioMgCaTitle;
      case RatioKind.caalk:
        return ratioCaAlkTitle;
      case RatioKind.mgalk:
        return ratioMgAlkTitle;
    }
  }

  String healthGradeLabel(HealthGrade grade) {
    switch (grade) {
      case HealthGrade.excellent:
        return healthGradeExcellent;
      case HealthGrade.good:
        return healthGradeGood;
      case HealthGrade.caution:
        return healthGradeCaution;
      case HealthGrade.critical:
        return healthGradeCritical;
      case HealthGrade.unknown:
        return healthGradeUnknown;
    }
  }

  String zoneLabel(Zone zone) {
    switch (zone) {
      case Zone.green:
        return zoneOk;
      case Zone.amber:
        return zoneAttention;
      case Zone.red:
        return zoneActNow;
      case Zone.unknown:
        return zoneUnknown;
    }
  }

  /// Display name of an RO stage: the localized type name, or the stored
  /// title for custom stages (an unknown stored type — hand-edited data —
  /// falls back to the title too, never crashes).
  String roStageName(String stageType, String? title) =>
      switch (RoStageType.fromName(stageType)) {
        RoStageType.sediment => roStageSediment,
        RoStageType.carbonBlock => roStageCarbonBlock,
        RoStageType.membrane => roStageMembrane,
        RoStageType.diResin => roStageDiResin,
        RoStageType.custom || null => title ?? '',
      };

  /// The localized message explaining why a backup file was rejected.
  String backupRejection(BackupRejection reason) {
    switch (reason) {
      case BackupRejection.notBackupFile:
        return backupInvalidFile;
      case BackupRejection.newerVersion:
        return backupTooNew;
      case BackupRejection.corrupted:
        return backupCorrupted;
      case BackupRejection.inconsistent:
        return backupInconsistent;
    }
  }
}
