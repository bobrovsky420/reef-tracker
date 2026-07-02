import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/backup.dart';
import '../domain/health_score.dart';
import '../domain/ratio.dart';
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
  final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
  final time = use24 ? DateFormat.Hm() : DateFormat.jm();
  final date = weekday ? DateFormat.yMMMEd() : DateFormat.yMMMd();
  return '${date.format(t)} ${time.format(t)}';
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
  final composed =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
