import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/reminders.dart';

void main() {
  // A Wednesday, well away from any DST edge in common zones.
  final now = DateTime(2026, 7, 15, 10, 30);

  group('nextElasticDue', () {
    test('recurring: due cadence days after last done', () {
      final due = nextElasticDue(
        lastDone: DateTime(2026, 7, 10, 18, 15),
        cadenceDays: 7,
        now: now,
      );
      expect(due, DateTime(2026, 7, 17, 18, 15));
    });

    test('recurring, never done, no seed: due immediately', () {
      expect(nextElasticDue(cadenceDays: 7, now: now), now);
    });

    test('recurring, never done, seeded: due at the planned first date', () {
      final seed = DateTime(2026, 8, 1, 9);
      expect(
        nextElasticDue(cadenceDays: 14, scheduledAt: seed, now: now),
        seed,
      );
    });

    test('recurring, done: a seed earlier than the elastic due is ignored', () {
      final due = nextElasticDue(
        lastDone: DateTime(2026, 7, 14),
        cadenceDays: 3,
        scheduledAt: DateTime(2026, 7, 1),
        now: now,
      );
      expect(due, DateTime(2026, 7, 17));
    });

    test('recurring, done: a later planned first-due floors the elastic due '
        '(typed plans: the action log predates the plan)', () {
      final due = nextElasticDue(
        lastDone: DateTime(2026, 6, 6),
        cadenceDays: 28,
        scheduledAt: DateTime(2026, 7, 16),
        now: now,
      );
      expect(due, DateTime(2026, 7, 16));
    });

    test('one-off: due at its planned date until completed', () {
      final seed = DateTime(2026, 7, 20, 9);
      expect(nextElasticDue(scheduledAt: seed, now: now), seed);
      expect(
        nextElasticDue(
          scheduledAt: seed,
          lastDone: DateTime(2026, 7, 20, 11),
          now: now,
        ),
        isNull,
      );
    });

    test('one-off: a pre-plan action does not retire it (#97 floor — typed '
        'plans pass the newest logged action, which predates the plan)', () {
      final seed = DateTime(2026, 8, 15, 9);
      expect(
        nextElasticDue(
          scheduledAt: seed,
          lastDone: DateTime(2026, 7, 12, 11),
          now: now,
        ),
        seed,
      );
    });

    test('one-off without a date is never due', () {
      expect(nextElasticDue(now: now), isNull);
    });

    test('invalid stored cadence (< 1) is unknown, not daily (#8 rule)', () {
      expect(nextElasticDue(lastDone: now, cadenceDays: 0, now: now), isNull);
      expect(nextElasticDue(lastDone: now, cadenceDays: -3, now: now), isNull);
    });

    test('cadence crossing a month boundary normalizes', () {
      final due = nextElasticDue(
        lastDone: DateTime(2026, 7, 28, 8),
        cadenceDays: 7,
        now: now,
      );
      expect(due, DateTime(2026, 8, 4, 8));
    });
  });

  group('nextMaintenanceDue', () {
    test('null / "days" unit matches the elastic every-N-days math', () {
      final lastDone = DateTime(2026, 7, 10, 18, 15);
      for (final unit in [null, 'days']) {
        expect(
          nextMaintenanceDue(
            lastDone: lastDone,
            cadenceDays: 7,
            cadenceUnit: unit,
            now: now,
          ),
          DateTime(2026, 7, 17, 18, 15),
          reason: 'unit=$unit',
        );
      }
    });

    test('weeks: due N*7 days after last done, keeping the time', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 7, 10, 18, 15),
          cadenceDays: 2,
          cadenceUnit: 'weeks',
          now: now,
        ),
        DateTime(2026, 7, 24, 18, 15),
      );
    });

    test('months: calendar month step, keeping the time', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 7, 10, 8),
          cadenceDays: 2,
          cadenceUnit: 'months',
          now: now,
        ),
        DateTime(2026, 9, 10, 8),
      );
      // Year wrap.
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 11, 15, 8),
          cadenceDays: 3,
          cadenceUnit: 'months',
          now: now,
        ),
        DateTime(2027, 2, 15, 8),
      );
    });

    test('months: short target months clamp the day (Jan 31 + 1 = Feb 28)', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 1, 31, 8),
          cadenceDays: 1,
          cadenceUnit: 'months',
          now: now,
        ),
        DateTime(2026, 2, 28, 8),
      );
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 3, 31, 8),
          cadenceDays: 1,
          cadenceUnit: 'months',
          now: now,
        ),
        DateTime(2026, 4, 30, 8),
      );
    });

    test('months: a later planned first-due floors the month step (#97 — '
        'same rule the weeks mode already had)', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 6, 20, 8),
          cadenceDays: 1,
          cadenceUnit: 'months',
          scheduledAt: DateTime(2026, 8, 5),
          now: now,
        ),
        DateTime(2026, 8, 5),
      );
      // An earlier seed is ignored, exactly like the elastic branch.
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 6, 20, 8),
          cadenceDays: 1,
          cadenceUnit: 'months',
          scheduledAt: DateTime(2026, 6, 1),
          now: now,
        ),
        DateTime(2026, 7, 20, 8),
      );
    });

    test('months, never done: seed date, else due now (like elastic)', () {
      final seed = DateTime(2026, 8, 1, 9);
      expect(
        nextMaintenanceDue(
          cadenceDays: 1,
          cadenceUnit: 'months',
          scheduledAt: seed,
          now: now,
        ),
        seed,
      );
      expect(
        nextMaintenanceDue(cadenceDays: 1, cadenceUnit: 'months', now: now),
        now,
      );
    });

    test('unknown unit or cadence < 1 is unknown, never a guess (#8)', () {
      expect(
        nextMaintenanceDue(
          lastDone: now,
          cadenceDays: 2,
          cadenceUnit: 'fortnights',
          now: now,
        ),
        isNull,
      );
      for (final unit in ['weeks', 'months']) {
        expect(
          nextMaintenanceDue(
            lastDone: now,
            cadenceDays: 0,
            cadenceUnit: unit,
            now: now,
          ),
          isNull,
          reason: 'unit=$unit',
        );
      }
    });

    test('weekdays: next matching day strictly after last done, at noon', () {
      // now/lastDone is a Wednesday.
      expect(
        nextMaintenanceDue(lastDone: now, weekdays: '1', now: now), // Mon
        DateTime(2026, 7, 20, 12),
      );
      expect(
        nextMaintenanceDue(lastDone: now, weekdays: '1,4', now: now),
        DateTime(2026, 7, 16, 12), // Thu comes first
      );
      // Done on a matching day: strictly after → the following week.
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 7, 13, 9), // a Monday
          weekdays: '1',
          now: now,
        ),
        DateTime(2026, 7, 20, 12),
      );
    });

    test('weekdays, never done: today counts (no phantom overdue)', () {
      expect(
        nextMaintenanceDue(weekdays: '3', now: now), // Wednesday = today
        DateTime(2026, 7, 15, 12),
      );
      // Seeded: first match on/after the planned date.
      expect(
        nextMaintenanceDue(
          weekdays: '1',
          scheduledAt: DateTime(2026, 8, 1), // a Saturday
          now: now,
        ),
        DateTime(2026, 8, 3, 12),
      );
    });

    test('a fresh "every 4 weeks, first due tomorrow" plan is due tomorrow, '
        'not overdue (regression: action logged 5+ weeks before the plan)', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 6, 6), // last logged action, pre-plan
          cadenceDays: 4,
          cadenceUnit: 'weeks',
          scheduledAt: DateTime(2026, 7, 16), // "tomorrow" for now = 15 Jul
          now: now,
        ),
        DateTime(2026, 7, 16),
      );
    });

    test('weekdays: a planned first-due after last done seeds the scan', () {
      expect(
        nextMaintenanceDue(
          lastDone: now, // Wed 15 Jul
          weekdays: '1',
          scheduledAt: DateTime(2026, 8, 1), // a Saturday
          now: now,
        ),
        DateTime(2026, 8, 3, 12), // first Monday on/after the seed, not 20 Jul
      );
    });

    test('weekdays take precedence over a stored cadence', () {
      expect(
        nextMaintenanceDue(
          lastDone: now,
          weekdays: '1',
          cadenceDays: 5,
          now: now,
        ),
        DateTime(2026, 7, 20, 12),
      );
    });

    test('present-but-garbage weekday list is unknown → null (#8)', () {
      expect(
        nextMaintenanceDue(lastDone: now, weekdays: '0,9', now: now),
        isNull,
      );
    });

    test('monthDay: next matching date strictly after last done, at noon', () {
      expect(
        nextMaintenanceDue(lastDone: now, monthDay: 1, now: now),
        DateTime(2026, 8, 1, 12),
      );
      // Done on the matching day: next month.
      expect(
        nextMaintenanceDue(lastDone: now, monthDay: 15, now: now),
        DateTime(2026, 8, 15, 12),
      );
    });

    test('monthDay 31 clamps to short months (Feb 28, Apr 30)', () {
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 1, 31),
          monthDay: 31,
          now: now,
        ),
        DateTime(2026, 2, 28, 12),
      );
      expect(
        nextMaintenanceDue(
          lastDone: DateTime(2026, 3, 31),
          monthDay: 31,
          now: now,
        ),
        DateTime(2026, 4, 30, 12),
      );
    });

    test('monthDay, never done: next occurrence from today / the seed', () {
      expect(
        nextMaintenanceDue(monthDay: 20, now: now),
        DateTime(2026, 7, 20, 12),
      );
      expect(
        nextMaintenanceDue(monthDay: 10, now: now),
        DateTime(2026, 8, 10, 12), // the 10th already passed this month
      );
    });

    test('monthDay out of range is unknown → null', () {
      for (final d in [0, 32, -1]) {
        expect(
          nextMaintenanceDue(lastDone: now, monthDay: d, now: now),
          isNull,
          reason: 'monthDay=$d',
        );
      }
    });

    test('no repeat fields: one-off passthrough', () {
      final seed = DateTime(2026, 7, 20, 9);
      expect(nextMaintenanceDue(scheduledAt: seed, now: now), seed);
      // A completion at/after the planned date retires it; one *before* it is
      // the pre-plan action-log anchor and does not (#97 floor).
      expect(
        nextMaintenanceDue(
          scheduledAt: seed,
          lastDone: seed.add(const Duration(hours: 2)),
          now: now,
        ),
        isNull,
      );
      expect(
        nextMaintenanceDue(scheduledAt: seed, lastDone: now, now: now),
        seed,
      );
    });
  });

  group('MaintenanceCadenceUnit.fromName', () {
    test('null means days (pre-v17 rows); garbage is null, not a guess', () {
      expect(
        MaintenanceCadenceUnit.fromName(null),
        MaintenanceCadenceUnit.days,
      );
      expect(
        MaintenanceCadenceUnit.fromName('weeks'),
        MaintenanceCadenceUnit.weeks,
      );
      expect(MaintenanceCadenceUnit.fromName('fortnights'), isNull);
    });
  });

  group('dueStatus / daysLeftUntil', () {
    test('future, today and overdue are signed', () {
      expect(daysLeftUntil(now.add(const Duration(days: 3)), now: now), 3);
      expect(daysLeftUntil(now, now: now), 0);
      expect(
        daysLeftUntil(now.subtract(const Duration(days: 2)), now: now),
        -2,
      );
    });

    test('compares calendar dates, not 24 h buckets', () {
      expect(daysLeftUntil(now.add(const Duration(hours: 30)), now: now), 1);
      expect(daysLeftUntil(now.add(const Duration(hours: 42)), now: now), 2);
      expect(
        daysLeftUntil(now.subtract(const Duration(hours: 42)), now: now),
        -2,
      );
      // A due date picked in the calendar is stored at midnight. From the
      // afternoon before (now = 10:30, and even later), tomorrow-at-midnight
      // is < 24 h away but must read "due in 1 d", never "due today"...
      expect(
        daysLeftUntil(DateTime(2026, 7, 16), now: DateTime(2026, 7, 15, 22)),
        1,
      );
      // ...and today-at-midnight must read "due today" all day, not become
      // "1 d overdue" by the afternoon.
      expect(
        daysLeftUntil(DateTime(2026, 7, 15), now: DateTime(2026, 7, 15, 22)),
        0,
      );
    });

    test('dueStatus bundles both', () {
      final due = DateTime(2026, 7, 18, 10, 30);
      expect(dueStatus(due, now: now), (dueAt: due, daysLeft: 3));
    });
  });

  group('MaintenanceActionType.fromName', () {
    test('resolves known names, null for garbage and null', () {
      expect(
        MaintenanceActionType.fromName('waterChange'),
        MaintenanceActionType.waterChange,
      );
      expect(MaintenanceActionType.fromName('bogus'), isNull);
      expect(MaintenanceActionType.fromName(null), isNull);
    });
  });

  group('parseDoseTime', () {
    test('accepts HH:mm and H:mm', () {
      expect(parseDoseTime('08:30'), (hour: 8, minute: 30));
      expect(parseDoseTime('8:05'), (hour: 8, minute: 5));
      expect(parseDoseTime(' 23:59 '), (hour: 23, minute: 59));
    });

    test('rejects garbage, out-of-range, null', () {
      expect(parseDoseTime(null), isNull);
      expect(parseDoseTime(''), isNull);
      expect(parseDoseTime('24:00'), isNull);
      expect(parseDoseTime('12:60'), isNull);
      expect(parseDoseTime('noon'), isNull);
      expect(parseDoseTime('12:5'), isNull);
    });
  });

  group('parseWeekdays', () {
    test('parses and filters the stored CSV', () {
      expect(parseWeekdays('1,3,7'), {1, 3, 7});
      expect(parseWeekdays(' 2 , 4 '), {2, 4});
      expect(parseWeekdays('0,8,x,3'), {3});
      expect(parseWeekdays(''), isEmpty);
      expect(parseWeekdays(null), isEmpty);
    });
  });

  group('doseOccurrences', () {
    final from = DateTime(2026, 7, 15); // Wednesday
    final until = DateTime(2026, 7, 21, 23, 59);
    final started = DateTime(2026, 7, 1, 12);

    test('daily: one per day at the dose time, inclusive window', () {
      final occ = doseOccurrences(
        frequency: 'daily',
        doseTime: '09:00',
        startedAt: started,
        from: from,
        until: until,
      );
      expect(occ, [for (var d = 15; d <= 21; d++) DateTime(2026, 7, d, 9)]);
    });

    test('null frequency behaves as daily (legacy rows)', () {
      final occ = doseOccurrences(
        doseTime: '09:00',
        startedAt: started,
        from: from,
        until: DateTime(2026, 7, 16, 23),
      );
      expect(occ.length, 2);
    });

    test('no dose time — or garbage — means no reminders, ever', () {
      for (final t in [null, '', '25:00', 'soon']) {
        expect(
          doseOccurrences(
            frequency: 'daily',
            doseTime: t,
            startedAt: started,
            from: from,
            until: until,
          ),
          isEmpty,
          reason: 'doseTime=$t',
        );
      }
    });

    test('weekly: only the stored weekdays', () {
      final occ = doseOccurrences(
        frequency: 'weekly',
        weekdays: '1,4', // Mon, Thu
        doseTime: '20:15',
        startedAt: started,
        from: from,
        until: until,
      );
      expect(occ, [
        DateTime(2026, 7, 16, 20, 15), // Thu
        DateTime(2026, 7, 20, 20, 15), // Mon
      ]);
    });

    test('weekly with no valid weekdays stays silent (unlike the dose-math '
        'average-as-daily rule — firing daily here would be spam)', () {
      for (final w in [null, '', '0,9']) {
        expect(
          doseOccurrences(
            frequency: 'weekly',
            weekdays: w,
            doseTime: '20:15',
            startedAt: started,
            from: from,
            until: until,
          ),
          isEmpty,
          reason: 'weekdays=$w',
        );
      }
    });

    test('everyNDays: anchored on startedAt, stepping N', () {
      final occ = doseOccurrences(
        frequency: 'everyNDays',
        intervalDays: 5,
        doseTime: '07:00',
        // Anchor day 1 Jul → 6, 11, 16, 21 Jul…
        startedAt: started,
        from: from,
        until: until,
      );
      expect(occ, [DateTime(2026, 7, 16, 7), DateTime(2026, 7, 21, 7)]);
    });

    test('everyNDays with a far-past startedAt keeps the anchor phase '
        'without scanning the whole span (#61)', () {
      // 2000-01-01 + 9690 days (= 1938 × 5) lands on 2026-07-13, so the two
      // anchors are phase-equivalent; the phase-jump must produce exactly the
      // same occurrences a plain scan would (first in-window hit: 18 Jul).
      List<DateTime> occ(DateTime startedAt) => doseOccurrences(
        frequency: 'everyNDays',
        intervalDays: 5,
        doseTime: '07:00',
        startedAt: startedAt,
        from: from,
        until: until,
      );
      final farPast = occ(DateTime(2000, 1, 1, 12));
      expect(farPast, [DateTime(2026, 7, 18, 7)]);
      expect(farPast, occ(DateTime(2026, 7, 13, 12)));
    });

    test(
      'everyNDays with missing/invalid interval is unknown → silent (#8)',
      () {
        for (final n in [null, 0, -2]) {
          expect(
            doseOccurrences(
              frequency: 'everyNDays',
              intervalDays: n,
              doseTime: '07:00',
              startedAt: started,
              from: from,
              until: until,
            ),
            isEmpty,
            reason: 'intervalDays=$n',
          );
        }
      },
    );

    test('occurrences never precede startedAt', () {
      final occ = doseOccurrences(
        frequency: 'daily',
        doseTime: '09:00',
        startedAt: DateTime(2026, 7, 17, 12), // starts mid-window, after 09:00
        from: from,
        until: until,
      );
      // 17 Jul 09:00 precedes the segment start at 12:00 → first is the 18th.
      expect(occ.first, DateTime(2026, 7, 18, 9));
    });

    test('inverted window is empty', () {
      expect(
        doseOccurrences(
          frequency: 'daily',
          doseTime: '09:00',
          startedAt: started,
          from: until,
          until: from,
        ),
        isEmpty,
      );
    });

    test('everyNDays phase jump equals a brute-force day walk '
        '(property: n 1–7 × 5 anchors)', () {
      // The #61 shortcut jumps `difference().inDays ~/ n` whole cadences to
      // the window instead of stepping day by day. An overshoot by even one
      // cadence silently skips the first dose reminder of every window. The
      // property is zone-independent by construction: both sides use
      // DateTime(y, m, d + n) stepping, so DST-length days normalize
      // identically.
      final windowFrom = DateTime(2026, 3, 10, 8);
      final windowUntil = DateTime(2026, 3, 24, 22);
      final anchors = [
        DateTime(2026, 3, 15, 9, 30), // inside the window
        DateTime(2026, 3, 9, 23, 30), // the evening before it opens
        DateTime(2026, 2, 1, 6), // weeks before
        DateTime(2025, 3, 29, 12), // about a year back
        DateTime(2016, 7, 4, 18), // a restored backup's decade-old anchor
      ];
      for (var n = 1; n <= 7; n++) {
        for (final anchor in anchors) {
          final jumped = doseOccurrences(
            frequency: 'everyNDays',
            intervalDays: n,
            doseTime: '09:00',
            startedAt: anchor,
            from: windowFrom,
            until: windowUntil,
          );
          // Reference: naive n-day stepping from the anchor day, with the
          // same window/start-clamp rules.
          final expected = <DateTime>[];
          final start = windowFrom.isAfter(anchor) ? windowFrom : anchor;
          var day = DateTime(anchor.year, anchor.month, anchor.day);
          while (!day.isAfter(windowUntil)) {
            final t = DateTime(day.year, day.month, day.day, 9, 0);
            if (!t.isBefore(start) && !t.isAfter(windowUntil)) {
              expected.add(t);
            }
            day = DateTime(day.year, day.month, day.day + n);
          }
          expect(jumped, expected, reason: 'n=$n anchor=$anchor');
          expect(expected, isNotEmpty, reason: 'vacuous case: n=$n $anchor');
        }
      }
    });
  });

  group('coalesceReminders', () {
    test('merges per (tank, kind, day); earliest time wins; labels dedup in '
        'first-seen order', () {
      final planned = coalesceReminders([
        (
          tankId: 1,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'KH',
        ),
        (
          tankId: 1,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 16, 8),
          label: 'Ca',
        ),
        (
          tankId: 1,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'KH', // duplicate
        ),
      ]);
      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 7, 16, 8));
      expect(planned.single.labels, ['KH', 'Ca']);
    });

    test('different tank, kind or day never merge', () {
      final planned = coalesceReminders([
        (
          tankId: 1,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'KH',
        ),
        (
          tankId: 2,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'KH',
        ),
        (
          tankId: 1,
          kind: ReminderKind.maintenance,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'Water change',
        ),
        (
          tankId: 1,
          kind: ReminderKind.testing,
          fireAt: DateTime(2026, 7, 17, 9),
          label: 'KH',
        ),
      ]);
      expect(planned, hasLength(4));
    });

    test('sorted by fire time, then tank id', () {
      final planned = coalesceReminders([
        (
          tankId: 2,
          kind: ReminderKind.dosing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'B',
        ),
        (
          tankId: 1,
          kind: ReminderKind.dosing,
          fireAt: DateTime(2026, 7, 16, 9),
          label: 'A',
        ),
        (
          tankId: 3,
          kind: ReminderKind.dosing,
          fireAt: DateTime(2026, 7, 15, 9),
          label: 'C',
        ),
      ]);
      expect(planned.map((p) => p.tankId), [3, 1, 2]);
    });

    test('empty in, empty out', () {
      expect(coalesceReminders(const []), isEmpty);
    });

    test('null-tank (RO) reminders never merge with a tank\'s and sort '
        'deterministically', () {
      // U16's RO unit is the only tankId == null producer and shares
      // ReminderKind.maintenance with tank maintenance. A merge would give
      // the notification the wrong title AND the wrong deep link (a tank's
      // maintenance route instead of the RO screen).
      final at = DateTime(2026, 8, 7, 9);
      final items = <ReminderItem>[
        (
          tankId: 1,
          kind: ReminderKind.maintenance,
          fireAt: at,
          label: 'Water change',
        ),
        (
          tankId: null,
          kind: ReminderKind.maintenance,
          fireAt: at.add(const Duration(hours: 1)),
          label: 'RO membrane',
        ),
        (
          tankId: null,
          kind: ReminderKind.maintenance,
          fireAt: at,
          label: 'RO sediment filter',
        ),
      ];
      final planned = coalesceReminders(items);
      expect(planned, hasLength(2));

      final ro = planned.singleWhere((p) => p.tankId == null);
      expect(ro.labels, ['RO membrane', 'RO sediment filter']);
      expect(ro.fireAt, at); // earliest member of the RO group
      final tank = planned.singleWhere((p) => p.tankId == 1);
      expect(tank.labels, ['Water change']);

      // Same instant → the device-scoped group sorts first, and the order
      // is stable however the items arrive.
      expect(planned.first.tankId, isNull);
      expect(
        coalesceReminders(items.reversed).map((p) => (p.tankId, p.fireAt)),
        planned.map((p) => (p.tankId, p.fireAt)),
      );
    });
  });
}
