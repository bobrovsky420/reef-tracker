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

    test('recurring, done: seed no longer matters', () {
      final due = nextElasticDue(
        lastDone: DateTime(2026, 7, 14),
        cadenceDays: 3,
        scheduledAt: DateTime(2026, 9, 1),
        now: now,
      );
      expect(due, DateTime(2026, 7, 17));
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

  group('dueStatus / daysLeftUntil', () {
    test('future, today and overdue are signed', () {
      expect(daysLeftUntil(now.add(const Duration(days: 3)), now: now), 3);
      expect(daysLeftUntil(now, now: now), 0);
      expect(
        daysLeftUntil(now.subtract(const Duration(days: 2)), now: now),
        -2,
      );
    });

    test('rounds to the nearest day like clock.daysSince', () {
      expect(daysLeftUntil(now.add(const Duration(hours: 30)), now: now), 1);
      expect(daysLeftUntil(now.add(const Duration(hours: 42)), now: now), 2);
      expect(
        daysLeftUntil(now.subtract(const Duration(hours: 42)), now: now),
        -2,
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
  });
}
