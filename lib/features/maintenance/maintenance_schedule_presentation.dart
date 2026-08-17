/// Shared maintenance schedule presentation policy, independent of a screen.
library;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/reminders.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

bool maintenanceRepeats(MaintenanceSchedule schedule) =>
    schedule.cadenceDays != null ||
    schedule.monthDay != null ||
    parseWeekdays(schedule.weekdays).isNotEmpty;

String maintenanceRepeatText(
  BuildContext context,
  AppLocalizations l,
  MaintenanceSchedule schedule,
) {
  final days = parseWeekdays(schedule.weekdays);
  if (days.isNotEmpty) return l.everyWeekdays(formatWeekdays(context, days));
  if (schedule.monthDay != null) return l.monthlyOnDayN(schedule.monthDay!);
  final cadence = schedule.cadenceDays;
  if (cadence == null) return l.oneOff;
  return switch (MaintenanceCadenceUnit.fromName(schedule.cadenceUnit)) {
    MaintenanceCadenceUnit.weeks => l.everyWeeksN(cadence),
    MaintenanceCadenceUnit.months => l.everyMonthsN(cadence),
    _ => l.dosingEveryDaysN(cadence),
  };
}

IconData maintenanceIcon(MaintenanceSchedule schedule) =>
    switch (MaintenanceActionType.fromName(schedule.actionType)) {
      MaintenanceActionType.waterChange => Icons.format_color_fill,
      MaintenanceActionType.carbonChange => Icons.grain,
      MaintenanceActionType.equipmentCleaning =>
        Icons.cleaning_services_outlined,
      null => Icons.task_alt,
    };

String maintenanceName(AppLocalizations l, MaintenanceSchedule schedule) =>
    switch (MaintenanceActionType.fromName(schedule.actionType)) {
      MaintenanceActionType.waterChange => l.waterChange,
      MaintenanceActionType.carbonChange => l.carbonChange,
      MaintenanceActionType.equipmentCleaning => l.equipmentCleaning,
      null => schedule.title ?? '',
    };

String dueText(AppLocalizations l, DueStatus due) => due.daysLeft > 0
    ? l.dueInDaysN(due.daysLeft)
    : due.daysLeft == 0
    ? l.dueToday
    : l.overdueDaysN(-due.daysLeft);
