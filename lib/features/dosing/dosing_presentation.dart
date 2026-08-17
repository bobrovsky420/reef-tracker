/// Shared dosing presentation policy, independent of any screen.
library;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

String dosingDetailLine(
  BuildContext context,
  AppLocalizations l,
  DosingEntry entry,
) {
  final parts = <String>[];

  if (entry.amount != null) {
    final unit = DoseUnit.fromName(entry.amountUnit);
    var amount = '${formatDoseAmount(entry.amount!)} ${unit.symbol}';
    final basis = DoseBasis.fromName(entry.basis);
    if (basis == DoseBasis.perDay) amount = '$amount ${l.dosingPerDay}';
    if (basis == DoseBasis.perDose) amount = '$amount ${l.dosingPerDose}';
    parts.add(amount);
  }

  switch (DoseFrequency.fromName(entry.frequency)) {
    case DoseFrequency.daily:
      parts.add(l.dosingFreqDaily);
    case DoseFrequency.everyNDays:
      parts.add(l.dosingEveryDaysN(entry.intervalDays ?? 0));
    case DoseFrequency.weekly:
      final days = parseWeekdays(entry.weekdays);
      if (days.isNotEmpty) parts.add(formatWeekdays(context, days));
    case null:
      break;
  }

  if (entry.doseTime case final time? when time.isNotEmpty) {
    parts.add(formatDoseTime(context, time));
  }
  return parts.isEmpty ? l.dosingNoDosage : parts.join(' · ');
}

String formatDoseAmount(double value, {int decimals = 1}) =>
    formatLocaleNumberTrim(value, decimals: decimals);

const int kDoseEditDecimals = 3;

List<int> parseWeekdays(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((value) => int.tryParse(value.trim()))
      .whereType<int>()
      .where((day) => day >= 1 && day <= 7)
      .toList()
    ..sort();
}

String formatDoseTime(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
}
