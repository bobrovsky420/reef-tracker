/// Pure due-date math for reminders & schedules (U1 testing cadences,
/// U2 dosing reminders, U12 planned maintenance) — no Flutter, no DB.
///
/// Two anchoring models, deliberately different:
///
/// * **Elastic** (testing, maintenance intervals): due = last done + cadence.
///   Logging a reading / action resets the timer — reefers test "a week after
///   the last test", not "every Monday". [nextElasticDue]. Maintenance plans
///   can also repeat on **fixed weekdays or a day of the month** — calendar
///   anchored, the next matching date after the last completion — all routed
///   through [nextMaintenanceDue].
/// * **Calendar** (dosing): occurrences expand from the dosing entry's own
///   schedule (frequency / interval / weekdays / time of day), anchored on the
///   segment's `startedAt`, regardless of what was logged. [doseOccurrences].
///
/// The notification layer converts the returned local-time instants to UTC and
/// schedules them; the in-app due chips consume [dueStatus] directly.
library;

import 'supplement_catalog.dart';

/// Notification category — one Android channel (and one master switch) each.
enum ReminderKind { testing, dosing, maintenance }

/// The three logged maintenance action types a [ReminderKind.maintenance]
/// schedule can target. Stored as [name] in `MaintenanceSchedules.actionType`;
/// a null stored type means a custom (free-titled) task instead.
enum MaintenanceActionType {
  waterChange,
  carbonChange,
  equipmentCleaning;

  /// Strict lookup: unknown/null names return null (restored backups are
  /// whitelisted, but a null column is the legitimate "custom task" marker —
  /// never coerce garbage into a real action type).
  static MaintenanceActionType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// A due date plus its signed distance from now: `daysLeft` > 0 = due in N
/// days, 0 = due today, < 0 = N days overdue.
typedef DueStatus = ({DateTime dueAt, int daysLeft});

/// Signed whole days from [now] to [t], rounded to the nearest day (the same
/// rounding convention as `clock.daysSince`, but not clamped — the sign is
/// the information here).
int daysLeftUntil(DateTime t, {DateTime? now}) =>
    (t.difference(now ?? DateTime.now()).inMinutes / (60 * 24)).round();

/// Bundles [dueAt] with its [daysLeftUntil] relative to [now].
DueStatus dueStatus(DateTime dueAt, {DateTime? now}) =>
    (dueAt: dueAt, daysLeft: daysLeftUntil(dueAt, now: now));

/// Next due date of an elastic (anchor-on-last-done) reminder, or null when
/// the reminder cannot be due.
///
/// * Recurring ([cadenceDays] >= 1): due [cadenceDays] after [lastDone].
///   Never done → [scheduledAt] when set (a planned first occurrence),
///   otherwise due immediately ([now]).
/// * One-off ([cadenceDays] null): due at [scheduledAt]; once done (or with
///   no date at all) it is never due again — the caller retires the plan.
/// * A stored cadence < 1 (possible only via restored/hand-edited data) means
///   the true cadence is unknown → null, mirroring `dailyEquivalentDose`'s
///   treatment of invalid intervals (#8) rather than guessing "daily".
///
/// Testing reminders (U1) are the `scheduledAt == null` special case:
/// `nextElasticDue(lastDone: latestReading, cadenceDays: testCadenceDays)`.
DateTime? nextElasticDue({
  DateTime? lastDone,
  int? cadenceDays,
  DateTime? scheduledAt,
  DateTime? now,
}) {
  if (cadenceDays == null) {
    // One-off: due at its planned date until completed.
    return lastDone == null ? scheduledAt : null;
  }
  if (cadenceDays < 1) return null;
  if (lastDone == null) return scheduledAt ?? (now ?? DateTime.now());
  return DateTime(
    lastDone.year,
    lastDone.month,
    lastDone.day + cadenceDays,
    lastDone.hour,
    lastDone.minute,
  );
}

/// Unit of a maintenance plan's interval cadence ("every N days/weeks/
/// months"). Stored as [name] in `MaintenanceSchedules.cadenceUnit`; a null
/// column means days (the only unit that existed before v17).
enum MaintenanceCadenceUnit {
  days,
  weeks,
  months;

  /// Strict lookup: unknown names return null so garbage from a hand-edited
  /// backup reads as "unknown cadence" (#8), never as a guessed unit — a
  /// "months" plan misread as "days" would nag 30× too often.
  static MaintenanceCadenceUnit? fromName(String? name) {
    if (name == null) return days;
    for (final u in values) {
      if (u.name == name) return u;
    }
    return null;
  }
}

/// Next due date of a maintenance plan, or null when it cannot be due.
///
/// Three repeat models, resolved in priority order from the stored fields:
///
/// 1. **Fixed weekdays** ([weekdays] parses non-empty, e.g. "every Monday"):
///    the first matching calendar day strictly after [lastDone]. A present
///    but garbage list → null (#8), never a guess.
/// 2. **Fixed day of month** ([monthDay] 1–31, e.g. "every 1st"): the first
///    calendar day strictly after [lastDone] whose day-of-month matches;
///    short months clamp ("every 31st" fires Feb 28 / Apr 30). Out of range
///    → null.
/// 3. **Elastic interval** ([cadenceDays] ≥ 1 in [cadenceUnit] units): due =
///    [lastDone] + N days / weeks / months — logging resets the timer.
///    Month steps clamp the day (Jan 31 + 1 month = Feb 28). A cadence < 1
///    or an unknown unit → null (#8).
///
/// With no repeat field set the plan is a one-off: due at [scheduledAt],
/// retired once done. Never-done plans fall back to [scheduledAt] as the
/// anchor (calendar modes: first match on/after it; elastic: due exactly
/// then), else they are due now (elastic) / on the next matching day
/// (calendar — "every Monday" created on a Wednesday means next Monday, not
/// overdue since a completion that never happened).
///
/// Calendar-mode results are pinned to **noon** so the whole due day rounds
/// to "due today" in [daysLeftUntil]; elastic results keep [lastDone]'s
/// time of day (the pre-v17 behavior). The notification layer only uses the
/// date part either way.
DateTime? nextMaintenanceDue({
  DateTime? lastDone,
  int? cadenceDays,
  String? cadenceUnit,
  String? weekdays,
  int? monthDay,
  DateTime? scheduledAt,
  DateTime? now,
}) {
  if (weekdays != null && weekdays.trim().isNotEmpty) {
    final days = parseWeekdays(weekdays);
    if (days.isEmpty) return null;
    return _nextCalendarDue(
      lastDone: lastDone,
      scheduledAt: scheduledAt,
      now: now,
      matches: (day) => days.contains(day.weekday),
    );
  }
  if (monthDay != null) {
    if (monthDay < 1 || monthDay > 31) return null;
    return _nextCalendarDue(
      lastDone: lastDone,
      scheduledAt: scheduledAt,
      now: now,
      // Clamp to short months: "day 31" matches the month's last day.
      matches: (day) => day.day == _clampToMonth(monthDay, day),
    );
  }
  final unit = MaintenanceCadenceUnit.fromName(cadenceUnit);
  if (unit == null) return null;
  if (unit != MaintenanceCadenceUnit.months || cadenceDays == null) {
    // Days/weeks (and the one-off / invalid-cadence cases) are the existing
    // elastic math with the interval expressed in days.
    return nextElasticDue(
      lastDone: lastDone,
      cadenceDays: unit == MaintenanceCadenceUnit.weeks && cadenceDays != null
          ? cadenceDays * 7
          : cadenceDays,
      scheduledAt: scheduledAt,
      now: now,
    );
  }
  if (cadenceDays < 1) return null;
  if (lastDone == null) return scheduledAt ?? (now ?? DateTime.now());
  final targetMonth = DateTime(lastDone.year, lastDone.month + cadenceDays);
  return DateTime(
    targetMonth.year,
    targetMonth.month,
    _clampToMonth(lastDone.day, targetMonth),
    lastDone.hour,
    lastDone.minute,
  );
}

/// [day] clamped to the number of days in [month]'s month.
int _clampToMonth(int day, DateTime month) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  return day < daysInMonth ? day : daysInMonth;
}

/// First calendar day accepted by [matches], at noon: strictly after
/// [lastDone] when the task has been done, else on/after [scheduledAt] when
/// planned, else on/after today (so "every Monday" is due this Monday,
/// including today). Scans a bounded window — a month-day match is at most
/// ~31 days out, a weekday at most 7; null past the bound (unmatchable).
DateTime? _nextCalendarDue({
  required bool Function(DateTime day) matches,
  DateTime? lastDone,
  DateTime? scheduledAt,
  DateTime? now,
}) {
  final anchor = lastDone ?? scheduledAt ?? now ?? DateTime.now();
  var day = DateTime(
    anchor.year,
    anchor.month,
    anchor.day + (lastDone != null ? 1 : 0),
    12,
  );
  for (var i = 0; i <= 62; i++) {
    if (matches(day)) return day;
    day = DateTime(day.year, day.month, day.day + 1, 12);
  }
  return null;
}

/// Parses a stored `HH:mm` dose time; null for anything else. Shared by the
/// occurrence expansion and the dosing-edit "Remind me" gating.
({int hour, int minute})? parseDoseTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// Parses the stored comma-separated weekday numbers (1=Mon … 7=Sun),
/// dropping anything out of range.
Set<int> parseWeekdays(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  return raw
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .where((d) => d >= 1 && d <= 7)
      .toSet();
}

/// Concrete local-time instants at which a dosing entry's schedule says a dose
/// happens, within `[from, until]` (inclusive), chronological.
///
/// Returns empty — no reminders, never a guess — when [doseTime] is absent or
/// malformed (a reminder needs a time of day), when a weekly schedule has no
/// valid weekdays, or when an every-N-days interval is missing/invalid (the
/// #8 unknown-cadence rule again). Note the deliberate difference from
/// `dailyEquivalentDose`, which *averages* an empty weekly schedule as daily:
/// averaging is harmless there, firing daily notifications here would not be.
///
/// Occurrences never precede [startedAt] (the dose segment didn't exist yet).
/// Day stepping uses `DateTime(y, m, d + n)` so DST-length days normalize.
List<DateTime> doseOccurrences({
  String? frequency,
  int? intervalDays,
  String? weekdays,
  String? doseTime,
  required DateTime startedAt,
  required DateTime from,
  required DateTime until,
}) {
  final time = parseDoseTime(doseTime);
  if (time == null || until.isBefore(from)) return const [];
  final start = from.isAfter(startedAt) ? from : startedAt;
  final freq = DoseFrequency.fromName(frequency);

  bool inWindow(DateTime t) => !t.isBefore(start) && !t.isAfter(until);
  DateTime atTime(DateTime day) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  final result = <DateTime>[];
  switch (freq) {
    case DoseFrequency.everyNDays:
      final n = intervalDays ?? 0;
      if (n < 1) return const [];
      var day = DateTime(startedAt.year, startedAt.month, startedAt.day);
      while (!day.isAfter(until)) {
        final t = atTime(day);
        if (inWindow(t)) result.add(t);
        day = DateTime(day.year, day.month, day.day + n);
      }
    case DoseFrequency.weekly:
      final days = parseWeekdays(weekdays);
      if (days.isEmpty) return const [];
      var day = DateTime(start.year, start.month, start.day);
      while (!day.isAfter(until)) {
        if (days.contains(day.weekday)) {
          final t = atTime(day);
          if (inWindow(t)) result.add(t);
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
    case DoseFrequency.daily:
    case null:
      var day = DateTime(start.year, start.month, start.day);
      while (!day.isAfter(until)) {
        final t = atTime(day);
        if (inWindow(t)) result.add(t);
        day = DateTime(day.year, day.month, day.day + 1);
      }
  }
  return result;
}

/// One thing to remind about: where ([tankId]), which channel ([kind]), when
/// ([fireAt], local time), and the display line it contributes ([label]).
typedef ReminderItem = ({
  int tankId,
  ReminderKind kind,
  DateTime fireAt,
  String label,
});

/// A coalesced notification: every [ReminderItem] of one (tank, kind,
/// calendar day) merged into a single notification, fired at the earliest
/// member's time.
typedef PlannedReminder = ({
  int tankId,
  ReminderKind kind,
  DateTime fireAt,
  List<String> labels,
});

/// Coalesces items into one notification per (tank, kind, day) — "Time to
/// test: KH, Ca, Mg" instead of three pings. Labels keep first-seen order and
/// are deduplicated; the result is sorted by fire time (then tank for a
/// stable order).
List<PlannedReminder> coalesceReminders(Iterable<ReminderItem> items) {
  final groups = <(int, ReminderKind, int, int, int), List<ReminderItem>>{};
  for (final item in items) {
    final key = (
      item.tankId,
      item.kind,
      item.fireAt.year,
      item.fireAt.month,
      item.fireAt.day,
    );
    groups.putIfAbsent(key, () => []).add(item);
  }
  final result = <PlannedReminder>[];
  for (final group in groups.values) {
    var fireAt = group.first.fireAt;
    final labels = <String>[];
    for (final item in group) {
      if (item.fireAt.isBefore(fireAt)) fireAt = item.fireAt;
      if (!labels.contains(item.label)) labels.add(item.label);
    }
    result.add((
      tankId: group.first.tankId,
      kind: group.first.kind,
      fireAt: fireAt,
      labels: labels,
    ));
  }
  result.sort((a, b) {
    final byTime = a.fireAt.compareTo(b.fireAt);
    return byTime != 0 ? byTime : a.tankId.compareTo(b.tankId);
  });
  return result;
}
