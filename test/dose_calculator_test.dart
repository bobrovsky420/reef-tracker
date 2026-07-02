import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/dose_calculator.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Builds a minimal [DosingEntry] for the daily-equivalent tests.
DosingEntry entry({
  double? amount,
  String? basis,
  String? frequency,
  int? intervalDays,
  String? weekdays,
}) =>
    DosingEntry(
      id: 1,
      tankId: 1,
      product: 'Test',
      amount: amount,
      basis: basis,
      frequency: frequency,
      intervalDays: intervalDays,
      weekdays: weekdays,
      displayOrder: 0,
      createdAt: DateTime(2026, 1, 1),
      state: DosingState.active.name,
    );

void main() {
  final t0 = DateTime(2026, 1, 1);
  List<DosePoint> series(List<double> values, {int stepDays = 1}) => [
        for (var i = 0; i < values.length; i++)
          (t: t0.add(Duration(days: i * stepDays)), value: values[i])
      ];

  group('slopePerDay', () {
    test('returns null with fewer than two points', () {
      expect(slopePerDay([]), isNull);
      expect(slopePerDay(series([400])), isNull);
    });

    test('returns null when all points share an instant', () {
      expect(
        slopePerDay([(t: t0, value: 400), (t: t0, value: 410)]),
        isNull,
      );
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
            entry(amount: 14, frequency: 'everyNDays', intervalDays: 2)),
        closeTo(7, 1e-9),
      );
    });

    test('weekly with 3 days -> amount * 3/7', () {
      expect(
        dailyEquivalentDose(
            entry(amount: 7, frequency: 'weekly', weekdays: '1,3,5')),
        closeTo(3.0, 1e-9),
      );
    });

    test('everyNDays with a zero or negative interval contributes nothing',
        () {
      // Regression test for #8: the UI now validates the interval, and the
      // calculator treats a garbage stored interval (pre-fix rows) as an
      // unknown cadence (0) instead of silently pretending "daily".
      expect(
        dailyEquivalentDose(
            entry(amount: 10, frequency: 'everyNDays', intervalDays: 0)),
        0,
      );
      expect(
        dailyEquivalentDose(
            entry(amount: 10, frequency: 'everyNDays', intervalDays: -3)),
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
        dailyEquivalentDose(entry(amount: 7, frequency: 'weekly', weekdays: '')),
        closeTo(7, 1e-9),
      );
      // Out-of-range and non-numeric entries are all discarded -> count 0.
      expect(
        dailyEquivalentDose(
            entry(amount: 7, frequency: 'weekly', weekdays: '0,8,abc')),
        closeTo(7, 1e-9),
      );
    });

    test('weekly counts only the valid weekday numbers', () {
      // 1 and 4 are valid; 0, 9 and junk are ignored -> 2 dosing days.
      expect(
        dailyEquivalentDose(
            entry(amount: 7, frequency: 'weekly', weekdays: '1,0,9,4,x')),
        closeTo(2.0, 1e-9),
      );
    });

    test('basis is currently ignored: perDose equals perDay', () {
      // Pins that dailyEquivalentDose reads only the schedule — the stored
      // basis (perDay vs perDose) does not change the result today (both mean
      // "amount per active day"). If basis ever starts contributing, this
      // must be revisited deliberately.
      final perDay = dailyEquivalentDose(entry(
          amount: 12, basis: 'perDay', frequency: 'everyNDays', intervalDays: 3));
      final perDose = dailyEquivalentDose(entry(
          amount: 12,
          basis: 'perDose',
          frequency: 'everyNDays',
          intervalDays: 3));
      expect(perDay, perDose);
      expect(perDay, closeTo(4.0, 1e-9));
    });
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

    test('no dosing: consumption equals the drop, but needs potency for dose',
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
    });

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
  });
}
