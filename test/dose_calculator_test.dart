import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/dose_calculator.dart';
import 'package:reeftracker/domain/units.dart';

/// Builds a [DoseSchedule] record for the daily-equivalent tests.
DoseSchedule entry({
  double? amount,
  String? frequency,
  int? intervalDays,
  String? weekdays,
}) => (
  amount: amount,
  frequency: frequency,
  intervalDays: intervalDays,
  weekdays: weekdays,
);

void main() {
  final t0 = DateTime(2026, 1, 1);
  List<DosePoint> series(List<double> values, {int stepDays = 1}) => [
    for (var i = 0; i < values.length; i++)
      (t: t0.add(Duration(days: i * stepDays)), value: values[i]),
  ];

  group('slopePerDay', () {
    test('returns null with fewer than two points', () {
      expect(slopePerDay([]), isNull);
      expect(slopePerDay(series([400])), isNull);
    });

    test('returns null when all points share an instant', () {
      expect(slopePerDay([(t: t0, value: 400), (t: t0, value: 410)]), isNull);
    });

    test('falling element gives a negative slope', () {
      final s = slopePerDay(series([420, 410, 400, 390]));
      expect(s, isNotNull);
      expect(s!, closeTo(-10, 1e-9));
    });

    test('rising element gives a positive slope', () {
      final s = slopePerDay(series([400, 405, 410]));
      expect(s!, closeTo(5, 1e-9));
    });
  });

  group('linearFit', () {
    test('on a perfect line the fitted last value equals the raw last', () {
      final f = linearFit(series([400, 405, 410]))!;
      expect(f.slopePerDay, closeTo(5, 1e-9));
      expect(f.valueAtLast, closeTo(410, 1e-9));
    });

    test('an outlier endpoint is pulled back toward the regression line', () {
      // 8.0→8.3 steady, then a noisy 9.05: mean 8.33 + slope 0.23 × 2 = 8.79.
      final f = linearFit(series([8.0, 8.1, 8.2, 8.3, 9.05]))!;
      expect(f.slopePerDay, closeTo(0.23, 1e-9));
      expect(f.valueAtLast, closeTo(8.79, 1e-9));
    });

    test('null under the same conditions as slopePerDay', () {
      expect(linearFit([]), isNull);
      expect(linearFit(series([400])), isNull);
      expect(linearFit([(t: t0, value: 400.0), (t: t0, value: 410.0)]), isNull);
    });
  });

  group('manualDosesInWindow', () {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2026, 1, 11);

    test('includes the start boundary, excludes the end boundary', () {
      // A dose at the first reading's instant influences every later reading;
      // a dose at (or after) the last reading hasn't shown up in any yet.
      final doses = [
        (t: from, amount: 5.0),
        (t: DateTime(2026, 1, 5), amount: 3.0),
        (t: to, amount: 7.0),
      ];
      final inWindow = manualDosesInWindow(
        doses,
        time: (d) => d.t,
        from: from,
        to: to,
      );
      expect(inWindow.map((d) => d.amount), [5.0, 3.0]);
    });

    test('drops doses before and after the window', () {
      final doses = [
        (t: from.subtract(const Duration(minutes: 1)), amount: 5.0),
        (t: to.add(const Duration(days: 2)), amount: 3.0),
      ];
      expect(
        manualDosesInWindow(doses, time: (d) => d.t, from: from, to: to),
        isEmpty,
      );
    });
  });

  group('potencyFromReference', () {
    test('matches the Fauna Marin Calcium chart (10 ml/100 L -> +11)', () {
      final p = potencyFromReference(
        doseAmount: 10,
        refVolumeLiters: 100,
        rise: 11,
      );
      expect(p, closeTo(110, 1e-9));
    });

    test('rejects non-positive inputs', () {
      expect(
        potencyFromReference(doseAmount: 0, refVolumeLiters: 100, rise: 11),
        isNull,
      );
      expect(
        potencyFromReference(doseAmount: 10, refVolumeLiters: 100, rise: 0),
        isNull,
      );
    });
  });

  group('dailyEquivalentDose', () {
    test('no amount -> 0', () {
      expect(dailyEquivalentDose(entry()), 0);
    });

    test('daily -> full amount', () {
      expect(
        dailyEquivalentDose(entry(amount: 20, frequency: 'daily')),
        closeTo(20, 1e-9),
      );
    });

    test('no schedule -> treated as daily', () {
      expect(dailyEquivalentDose(entry(amount: 20)), closeTo(20, 1e-9));
    });

    test('every 2 days -> halved', () {
      expect(
        dailyEquivalentDose(
          entry(amount: 14, frequency: 'everyNDays', intervalDays: 2),
        ),
        closeTo(7, 1e-9),
      );
    });

    test('weekly with 3 days -> amount * 3/7', () {
      expect(
        dailyEquivalentDose(
          entry(amount: 7, frequency: 'weekly', weekdays: '1,3,5'),
        ),
        closeTo(3.0, 1e-9),
      );
    });

    test('everyNDays with a zero or negative interval contributes nothing', () {
      // Regression test for #8: the UI now validates the interval, and the
      // calculator treats a garbage stored interval (pre-fix rows) as an
      // unknown cadence (0) instead of silently pretending "daily".
      expect(
        dailyEquivalentDose(
          entry(amount: 10, frequency: 'everyNDays', intervalDays: 0),
        ),
        0,
      );
      expect(
        dailyEquivalentDose(
          entry(amount: 10, frequency: 'everyNDays', intervalDays: -3),
        ),
        0,
      );
    });

    test('everyNDays with no interval recorded treats it as every day', () {
      expect(
        dailyEquivalentDose(entry(amount: 10, frequency: 'everyNDays')),
        closeTo(10, 1e-9),
      );
    });

    test('weekly with no valid weekdays falls back to daily', () {
      expect(
        dailyEquivalentDose(
          entry(amount: 7, frequency: 'weekly', weekdays: ''),
        ),
        closeTo(7, 1e-9),
      );
      // Out-of-range and non-numeric entries are all discarded -> count 0.
      expect(
        dailyEquivalentDose(
          entry(amount: 7, frequency: 'weekly', weekdays: '0,8,abc'),
        ),
        closeTo(7, 1e-9),
      );
    });

    test('weekly counts only the valid weekday numbers', () {
      // 1 and 4 are valid; 0, 9 and junk are ignored -> 2 dosing days.
      expect(
        dailyEquivalentDose(
          entry(amount: 7, frequency: 'weekly', weekdays: '1,0,9,4,x'),
        ),
        closeTo(2.0, 1e-9),
      );
    });

    // Note: the entry's stored basis (perDay vs perDose) is structurally
    // ignored now — it is not part of [DoseSchedule] — so the old pinning
    // test ("perDose equals perDay") is guaranteed by the signature.
  });

  group('computeDoseCalc', () {
    const potency = 110.0; // Fauna Marin Calcium Mix, ppm·L/ml
    const volume = 100.0;

    test('insufficient data when slope or volume missing', () {
      expect(
        computeDoseCalc(
          slopePerDay: null,
          currentDailyDose: 10,
          potency: potency,
          volumeLiters: volume,
        ).status,
        DoseCalcStatus.insufficientData,
      );
      expect(
        computeDoseCalc(
          slopePerDay: -5,
          currentDailyDose: 10,
          potency: potency,
          volumeLiters: null,
        ).status,
        DoseCalcStatus.insufficientData,
      );
    });

    test(
      'no dosing: consumption equals the drop, but needs potency for dose',
      () {
        // Ca falling 11 ppm/day, nothing dosed.
        final r = computeDoseCalc(
          slopePerDay: -11,
          currentDailyDose: 0,
          potency: null,
          volumeLiters: volume,
        );
        expect(r.status, DoseCalcStatus.needsPotency);
        expect(r.consumptionPerDay, closeTo(11, 1e-9));
        expect(r.suggestedDailyDose, isNull);
      },
    );

    test('no dosing with potency recommends a starting dose', () {
      // Consuming 11 ppm/day in 100 L; potency 110 -> 10 ml/day to maintain.
      final r = computeDoseCalc(
        slopePerDay: -11,
        currentDailyDose: 0,
        potency: potency,
        volumeLiters: volume,
      );
      expect(r.consumptionPerDay, closeTo(11, 1e-9));
      expect(r.suggestedDailyDose, closeTo(10, 1e-9));
      expect(r.adjustment, closeTo(10, 1e-9));
      expect(r.status, DoseCalcStatus.increase);
    });

    test('under-dosing: holding steady needs more', () {
      // Dosing 10 ml/day (+11 ppm/day) but Ca still falls 5 ppm/day ->
      // consumption 16 ppm/day -> need ~14.5 ml/day.
      final r = computeDoseCalc(
        slopePerDay: -5,
        currentDailyDose: 10,
        potency: potency,
        volumeLiters: volume,
      );
      expect(r.dosingInputPerDay, closeTo(11, 1e-9));
      expect(r.consumptionPerDay, closeTo(16, 1e-9));
      expect(r.suggestedDailyDose, closeTo(16 * volume / potency, 1e-9));
      expect(r.status, DoseCalcStatus.increase);
    });

    test('stable when current dose already matches consumption', () {
      // Dosing 10 ml/day (+11 ppm/day), Ca flat -> consumption 11 -> suggest 10.
      final r = computeDoseCalc(
        slopePerDay: 0,
        currentDailyDose: 10,
        potency: potency,
        volumeLiters: volume,
      );
      expect(r.suggestedDailyDose, closeTo(10, 1e-9));
      expect(r.status, DoseCalcStatus.stable);
    });

    test('overdosing: rising element clamps suggested dose to zero', () {
      // Dosing 20 ml/day (+22 ppm/day) and Ca rising 11 ppm/day ->
      // consumption 11 ppm/day... wait, rising means input>consumption.
      final r = computeDoseCalc(
        slopePerDay: 22, // rising fast, more than dosed input
        currentDailyDose: 10, // +11 ppm/day
        potency: potency,
        volumeLiters: volume,
      );
      expect(r.consumptionPerDay! <= 0, isTrue);
      expect(r.suggestedDailyDose, 0);
      expect(r.status, DoseCalcStatus.overdosing);
    });

    test('dosing without potency needs potency', () {
      final r = computeDoseCalc(
        slopePerDay: -5,
        currentDailyDose: 10,
        potency: null,
        volumeLiters: volume,
      );
      expect(r.status, DoseCalcStatus.needsPotency);
    });

    group('nothing dosed (#27)', () {
      test('rising element with no dose → noDoseNeeded, not overdosing', () {
        // "Reduce or pause dosing" is wrong when nothing is dosed.
        final r = computeDoseCalc(
          slopePerDay: 5,
          currentDailyDose: 0,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.status, DoseCalcStatus.noDoseNeeded);
        expect(r.suggestedDailyDose, 0);
      });

      test('tiny consumption with no dose → increase, never stable', () {
        // Suggested dose ≈ 0.045 ml/day is below the stability tolerance, but
        // "keep your current dose" would mean keep dosing nothing.
        final r = computeDoseCalc(
          slopePerDay: -0.05,
          currentDailyDose: 0,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.suggestedDailyDose!, greaterThan(0));
        expect(r.status, DoseCalcStatus.increase);
      });
    });

    group('manual (one-off) doses in the window', () {
      test('manual input joins consumption and is reported separately', () {
        // Dosing 10 ml/day (+11 ppm/day) plus manual doses averaging
        // 5 ml/day (+5.5 ppm/day); Ca flat → the tank actually consumes
        // 16.5 ppm/day, so the scheduled dose alone must grow to 15 ml/day.
        final r = computeDoseCalc(
          slopePerDay: 0,
          currentDailyDose: 10,
          manualDailyDose: 5,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.dosingInputPerDay, closeTo(11, 1e-9));
        expect(r.manualInputPerDay, closeTo(5.5, 1e-9));
        expect(r.consumptionPerDay, closeTo(16.5, 1e-9));
        expect(r.suggestedDailyDose, closeTo(15, 1e-9));
        expect(r.status, DoseCalcStatus.increase);
      });

      test('a rise explained by manual doses is not called overdosing', () {
        // No scheduled dose; manual doses add 11 ppm/day but Ca only rises
        // 5.5 ppm/day → the tank still consumes 5.5 ppm/day → recommend a
        // 5 ml/day scheduled dose rather than "reduce dosing".
        final r = computeDoseCalc(
          slopePerDay: 5.5,
          currentDailyDose: 0,
          manualDailyDose: 10,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.consumptionPerDay, closeTo(5.5, 1e-9));
        expect(r.suggestedDailyDose, closeTo(5, 1e-9));
        expect(r.status, DoseCalcStatus.increase);
      });

      test('manual dosing with a rising element beyond it is overdosing', () {
        // Manual doses add 5.5 ppm/day but Ca rises 11 ppm/day → nothing is
        // consumed; with manual doses active this is overdosing, not
        // noDoseNeeded.
        final r = computeDoseCalc(
          slopePerDay: 11,
          currentDailyDose: 0,
          manualDailyDose: 5,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.consumptionPerDay! <= 0, isTrue);
        expect(r.status, DoseCalcStatus.overdosing);
      });

      test('manual dose without potency needs potency', () {
        final r = computeDoseCalc(
          slopePerDay: -5,
          currentDailyDose: 0,
          manualDailyDose: 5,
          potency: null,
          volumeLiters: volume,
        );
        expect(r.status, DoseCalcStatus.needsPotency);
        expect(r.consumptionPerDay, isNull);
      });

      test('omitting the manual dose keeps the previous behaviour', () {
        final base = computeDoseCalc(
          slopePerDay: -5,
          currentDailyDose: 10,
          potency: potency,
          volumeLiters: volume,
        );
        final zero = computeDoseCalc(
          slopePerDay: -5,
          currentDailyDose: 10,
          manualDailyDose: 0,
          potency: potency,
          volumeLiters: volume,
        );
        expect(zero.status, base.status);
        expect(zero.suggestedDailyDose, base.suggestedDailyDose);
        expect(zero.manualInputPerDay, 0);
      });
    });

    group('stability tolerance scales with the dose (#28)', () {
      // Same chemical mismatch (suggested = dose + 0.4 ml/day) judged against
      // a 10 ml/day dose (within ±5%) and a 1 ml/day dose (way past ±5%).
      test('a ±5% mismatch on a large dose is stable', () {
        // input 11 ppm/d, consumption 11.44 → suggested 10.4, adjustment +0.4.
        final r = computeDoseCalc(
          slopePerDay: -0.44,
          currentDailyDose: 10,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.adjustment, closeTo(0.4, 1e-9));
        expect(r.status, DoseCalcStatus.stable);
      });

      test('the same absolute mismatch on a small dose is actionable', () {
        // input 1.1 ppm/d, consumption 1.54 → suggested 1.4, adjustment +0.4:
        // 40% under-dosed — the old flat 0.5 ml threshold called this stable.
        final r = computeDoseCalc(
          slopePerDay: -0.44,
          currentDailyDose: 1,
          potency: potency,
          volumeLiters: volume,
        );
        expect(r.adjustment, closeTo(0.4, 1e-9));
        expect(r.status, DoseCalcStatus.increase);
      });
    });
  });

  group('computeCorrectionDose', () {
    test('missing current, target or volume', () {
      expect(
        computeCorrectionDose(
          current: null,
          target: 8.5,
          potency: 10,
          volumeLiters: 200,
        ).status,
        CorrectionStatus.missingInputs,
      );
      expect(
        computeCorrectionDose(
          current: 7.5,
          target: null,
          potency: 10,
          volumeLiters: 200,
        ).status,
        CorrectionStatus.missingInputs,
      );
      expect(
        computeCorrectionDose(
          current: 7.5,
          target: 8.5,
          potency: 10,
          volumeLiters: 0,
        ).status,
        CorrectionStatus.missingInputs,
      );
    });

    test('at or above the target — nothing to dose', () {
      final r = computeCorrectionDose(
        current: 8.7,
        target: 8.5,
        potency: 10,
        volumeLiters: 200,
      );
      expect(r.status, CorrectionStatus.atOrAboveTarget);
      expect(r.totalDose, isNull);
    });

    test('rise known but potency missing', () {
      final r = computeCorrectionDose(
        current: 7.5,
        target: 8.5,
        potency: null,
        volumeLiters: 200,
      );
      expect(r.status, CorrectionStatus.needsPotency);
      expect(r.rise, closeTo(1.0, 1e-9));
    });

    test('single dose: rise * volume / potency', () {
      // Raise by 1 dKH in 200 L with p = 10 dKH·L per ml → 20 ml.
      final r = computeCorrectionDose(
        current: 7.5,
        target: 8.5,
        potency: 10,
        volumeLiters: 200,
        maxDailyRise: 1.4,
      );
      expect(r.status, CorrectionStatus.singleDose);
      expect(r.totalDose, closeTo(20, 1e-9));
      expect(r.days, 1);
      expect(r.dailyDose, closeTo(20, 1e-9));
    });

    test('a rise at exactly the daily limit stays a single dose', () {
      final r = computeCorrectionDose(
        current: 7.1,
        target: 8.5,
        potency: 10,
        volumeLiters: 200,
        maxDailyRise: 1.4,
      );
      expect(r.status, CorrectionStatus.singleDose);
    });

    test('a rise above the daily limit splits over ceil(rise/limit) days', () {
      // 3.0 dKH at 1.4/day → 3 days; total 60 ml → 20 ml/day.
      final r = computeCorrectionDose(
        current: 5.5,
        target: 8.5,
        potency: 10,
        volumeLiters: 200,
        maxDailyRise: 1.4,
      );
      expect(r.status, CorrectionStatus.splitDose);
      expect(r.days, 3);
      expect(r.totalDose, closeTo(60, 1e-9));
      expect(r.dailyDose, closeTo(20, 1e-9));
    });

    test('no limit -> never split, however large the rise', () {
      final r = computeCorrectionDose(
        current: 0.02,
        target: 0.06,
        potency: 0.5,
        volumeLiters: 200,
      );
      expect(r.status, CorrectionStatus.singleDose);
      expect(r.totalDose, closeTo(16, 1e-9));
    });
  });

  group('resolveTankSalinity', () {
    final now = DateTime(2026, 7, 22, 12);
    // Salinity readings are stored in SG; build them from ppt for legibility.
    DosePoint sal(int daysAgo, double ppt) =>
        (t: now.subtract(Duration(days: daysAgo)), value: pptToSg(ppt));

    test('null with no readings', () {
      expect(resolveTankSalinity([], now: now), isNull);
    });

    test('averages the readings inside the 14-day window', () {
      final s = resolveTankSalinity([
        sal(10, 32),
        sal(5, 33),
        sal(1, 34),
      ], now: now)!;
      expect(s.ppt, closeTo(33, 1e-9));
      expect(s.isAverage, isTrue);
      expect(s.measuredAt, now.subtract(const Duration(days: 1)));
    });

    test('older readings are excluded when recent ones exist', () {
      final s = resolveTankSalinity([sal(60, 20), sal(2, 33)], now: now)!;
      expect(s.ppt, closeTo(33, 1e-9));
      expect(s.isAverage, isFalse); // a single in-window reading, no average
    });

    test('falls back to the latest reading when none are recent', () {
      final s = resolveTankSalinity([sal(90, 31), sal(40, 32)], now: now)!;
      expect(s.ppt, closeTo(32, 1e-9));
      expect(s.isAverage, isFalse);
      expect(s.measuredAt, now.subtract(const Duration(days: 40)));
    });
  });

  group('adjustTargetForSalinity', () {
    test('scales linearly with salinity: Ca 420 at 33 ppt -> 396', () {
      expect(adjustTargetForSalinity(420, 33), closeTo(396, 1e-9));
    });

    test('35 ppt is the identity', () {
      expect(adjustTargetForSalinity(8.5, 35), closeTo(8.5, 1e-9));
    });

    test('salinity above 35 ppt raises the target', () {
      expect(adjustTargetForSalinity(1300, 36), closeTo(1337.142857, 1e-4));
    });

    test('implausible salinities are clamped to 20-45 ppt', () {
      // A typo'd 3.5 ppt clamps to 20, not a 10x-too-low target.
      expect(adjustTargetForSalinity(420, 3.5), closeTo(420 * 20 / 35, 1e-9));
      expect(adjustTargetForSalinity(420, 80), closeTo(420 * 45 / 35, 1e-9));
    });
  });
}
