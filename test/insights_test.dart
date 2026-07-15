import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/health_score.dart';
import 'package:reeftracker/domain/insights.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  final now = DateTime(2026, 7, 15, 12);

  // Alkalinity-style bounds: green 7–9, amber 6–10.
  const alkBounds = ZoneBounds(
    amberLow: 6,
    greenLow: 7,
    greenHigh: 9,
    amberHigh: 10,
  );

  TankHealth healthWith(List<HealthInput> inputs) =>
      computeTankHealth(inputs, now: now);

  HealthInput fresh(
    String key,
    double value, {
    ZoneBounds bounds = alkBounds,
  }) => (
    paramKey: key,
    bounds: bounds,
    latest: value,
    takenAt: now.subtract(const Duration(days: 1)),
  );

  group('rule 1 — out of range', () {
    test('red-low value flags a critical low insight', () {
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 5.5)]),
        trends: const {},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights, hasLength(1));
      final i = insights.single;
      expect(i.paramKey, 'alkalinity');
      expect(i.kind, InsightKind.outOfRange);
      expect(i.severity, InsightSeverity.critical);
      expect(i.isLow, isTrue);
      expect(i.worsening, isFalse); // no trend available
    });

    test('amber-high value flags a warning high insight', () {
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 9.5)]),
        trends: const {},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      final i = insights.single;
      expect(i.severity, InsightSeverity.warning);
      expect(i.isLow, isFalse);
    });

    test('a falling trend on a low value marks it worsening', () {
      const falling = TrendResult(
        slopePerDay: -0.2,
        direction: TrendDirection.falling,
        window: 5,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 6.5)]),
        trends: const {'alkalinity': falling},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights.single.worsening, isTrue);
    });

    test('a rising trend on a low value is NOT worsening', () {
      // Rising but not flagged recovering by the trend (e.g. flat epsilon
      // edge): still an out-of-range insight, just without "still falling".
      const rising = TrendResult(
        slopePerDay: 0.2,
        direction: TrendDirection.rising,
        window: 5,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 6.5)]),
        trends: const {'alkalinity': rising},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights.single.kind, InsightKind.outOfRange);
      expect(insights.single.worsening, isFalse);
    });

    test('a green value produces no out-of-range insight', () {
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 8)]),
        trends: const {},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights, isEmpty);
    });
  });

  group('rule 2 — forecast', () {
    test('an in-range value crossing amber within the horizon is flagged', () {
      const trend = TrendResult(
        slopePerDay: -0.2,
        direction: TrendDirection.falling,
        window: 5,
        daysToAmber: 5,
        daysToRed: 20, // beyond the horizon -> notice, not warning
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 8)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        horizonDays: 14,
        now: now,
      );
      final i = insights.single;
      expect(i.kind, InsightKind.forecast);
      expect(i.severity, InsightSeverity.notice);
      expect(i.isLow, isTrue);
      expect(i.days, 5);
    });

    test('a red crossing within the horizon escalates to warning', () {
      const trend = TrendResult(
        slopePerDay: -0.4,
        direction: TrendDirection.falling,
        window: 5,
        daysToAmber: 3,
        daysToRed: 8,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 8)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        horizonDays: 14,
        now: now,
      );
      expect(insights.single.severity, InsightSeverity.warning);
    });

    test('a crossing beyond the horizon is not an insight', () {
      const trend = TrendResult(
        slopePerDay: -0.02,
        direction: TrendDirection.falling,
        window: 5,
        daysToAmber: 40,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 8)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        horizonDays: 14,
        now: now,
      );
      expect(insights, isEmpty);
    });

    test('sub-day crossings round up to ~1 d, never 0', () {
      const trend = TrendResult(
        slopePerDay: -2,
        direction: TrendDirection.falling,
        window: 5,
        daysToAmber: 0.3,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 8)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights.single.days, 1);
    });
  });

  group('rule 3 — recovering', () {
    test('a recovering out-of-range value reassures instead of alarming', () {
      const trend = TrendResult(
        slopePerDay: 0.3,
        direction: TrendDirection.rising,
        window: 5,
        daysToGreen: 2.4,
        recovering: true,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 6.5)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      final i = insights.single;
      expect(i.kind, InsightKind.recovering);
      expect(i.severity, InsightSeverity.positive);
      expect(i.isLow, isTrue);
      expect(i.days, 2);
      // The out-of-range insight is suppressed — one message per parameter.
      expect(insights.where((x) => x.kind == InsightKind.outOfRange), isEmpty);
    });

    test('recovering without a re-entry estimate keeps days null', () {
      const trend = TrendResult(
        slopePerDay: 0.3,
        direction: TrendDirection.rising,
        window: 5,
        recovering: true,
      );
      final insights = computeInsights(
        health: healthWith([fresh('alkalinity', 6.5)]),
        trends: const {'alkalinity': trend},
        bounds: const {'alkalinity': alkBounds},
        now: now,
      );
      expect(insights.single.days, isNull);
    });
  });

  group('rule 4 — stale test', () {
    test(
      'a reading older than the freshness window is flagged with its age',
      () {
        final health = healthWith([
          (
            paramKey: 'phosphate',
            bounds: alkBounds,
            latest: 8.0,
            takenAt: now.subtract(const Duration(days: 45)),
          ),
        ]);
        final insights = computeInsights(
          health: health,
          trends: const {},
          bounds: const {'phosphate': alkBounds},
          now: now,
        );
        final i = insights.single;
        expect(i.kind, InsightKind.staleTest);
        expect(i.severity, InsightSeverity.notice);
        expect(i.days, 45);
      },
    );

    test('a never-tested parameter is deliberately not flagged', () {
      final health = healthWith([
        (paramKey: 'phosphate', bounds: alkBounds, latest: null, takenAt: null),
      ]);
      final insights = computeInsights(
        health: health,
        trends: const {},
        bounds: const {'phosphate': alkBounds},
        now: now,
      );
      expect(insights, isEmpty);
    });
  });

  group('ordering', () {
    test('severity ranks first, importance weight breaks ties', () {
      final health = healthWith([
        fresh('nitrate', 9.5), // amber -> warning, weight 2
        fresh('alkalinity', 9.5), // amber -> warning, weight 3
        fresh('calcium', 5.5), // red -> critical, weight 2
      ]);
      final insights = computeInsights(
        health: health,
        trends: const {},
        bounds: const {
          'nitrate': alkBounds,
          'alkalinity': alkBounds,
          'calcium': alkBounds,
        },
        now: now,
      );
      expect(insights.map((i) => i.paramKey).toList(), [
        'calcium', // critical first regardless of weight
        'alkalinity', // warning, weight 3
        'nitrate', // warning, weight 2
      ]);
    });

    test('positive insights sort last', () {
      const recovering = TrendResult(
        slopePerDay: 0.3,
        direction: TrendDirection.rising,
        window: 5,
        recovering: true,
      );
      final health = healthWith([
        fresh('alkalinity', 6.5), // recovering -> positive
        (
          paramKey: 'phosphate',
          bounds: alkBounds,
          latest: 8.0,
          takenAt: now.subtract(const Duration(days: 45)),
        ), // stale -> notice
      ]);
      final insights = computeInsights(
        health: health,
        trends: const {'alkalinity': recovering},
        bounds: const {'alkalinity': alkBounds, 'phosphate': alkBounds},
        now: now,
      );
      expect(insights.map((i) => i.kind).toList(), [
        InsightKind.staleTest,
        InsightKind.recovering,
      ]);
    });
  });

  group('lowSideOf', () {
    test(
      'places values against green bounds, amber fallback, and in-range',
      () {
        expect(lowSideOf(alkBounds, 6.5), isTrue);
        expect(lowSideOf(alkBounds, 9.5), isFalse);
        expect(lowSideOf(alkBounds, 8), isNull);
        // Amber-only bounds (#30 class): the amber bound is the range edge.
        const amberOnly = ZoneBounds(amberLow: 5, amberHigh: 10);
        expect(lowSideOf(amberOnly, 4), isTrue);
        expect(lowSideOf(amberOnly, 11), isFalse);
        // Invalid bounds can't place anything.
        const inverted = ZoneBounds(greenLow: 9, greenHigh: 8);
        expect(lowSideOf(inverted, 10), isNull);
      },
    );
  });

  test('Insight is value-equal (T2)', () {
    const a = Insight(
      paramKey: 'alkalinity',
      kind: InsightKind.forecast,
      severity: InsightSeverity.notice,
      isLow: true,
      days: 5,
    );
    const b = Insight(
      paramKey: 'alkalinity',
      kind: InsightKind.forecast,
      severity: InsightSeverity.notice,
      isLow: true,
      days: 5,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
