import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/ro.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('RoStageType.fromName', () {
    test('resolves every stage type by name', () {
      for (final t in RoStageType.values) {
        expect(RoStageType.fromName(t.name), t);
      }
    });

    test('returns null for garbage and null (never a guess)', () {
      expect(RoStageType.fromName('sedimint'), isNull);
      expect(RoStageType.fromName(''), isNull);
      expect(RoStageType.fromName(null), isNull);
    });
  });

  group('roStageDue', () {
    final now = DateTime(2026, 7, 6, 10);

    test('is elastic: last replacement + lifespan', () {
      expect(
        roStageDue(
          lastReplacedAt: DateTime(2026, 6, 1, 9, 30),
          lifespanDays: 90,
          now: now,
        ),
        DateTime(2026, 8, 30, 9, 30),
      );
    });

    test('a stage never replaced is never due — unknown age, no guess', () {
      expect(roStageDue(lifespanDays: 90, now: now), isNull);
    });

    test('an invalid stored lifespan yields no due date (#8)', () {
      expect(
        roStageDue(
          lastReplacedAt: DateTime(2026, 6, 1),
          lifespanDays: 0,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('roAmberWindowDays', () {
    test('floors short lifespans at $kRoAmberMinDays days', () {
      expect(roAmberWindowDays(90), 14); // 10% = 9 < the 14-day floor
      expect(roAmberWindowDays(120), 14);
    });

    test('scales with long lifespans', () {
      expect(roAmberWindowDays(720), 72); // 10%
    });

    test('caps at half the lifespan so short stages can read green', () {
      expect(roAmberWindowDays(10), 5);
      expect(roAmberWindowDays(20), 10);
    });
  });

  group('roRemainingFraction', () {
    test('clamps to 0..1', () {
      expect(roRemainingFraction(daysLeft: -5, lifespanDays: 90), 0);
      expect(roRemainingFraction(daysLeft: 90, lifespanDays: 90), 1);
      expect(roRemainingFraction(daysLeft: 200, lifespanDays: 90), 1);
    });

    test('is the linear share of lifespan left', () {
      expect(roRemainingFraction(daysLeft: 45, lifespanDays: 90), 0.5);
    });

    test('an invalid lifespan reads as fully drained, not a crash', () {
      expect(roRemainingFraction(daysLeft: 10, lifespanDays: 0), 0);
    });
  });

  group('roStageZone', () {
    test('red once overdue', () {
      expect(roStageZone(daysLeft: -1, lifespanDays: 90), Zone.red);
    });

    test('amber inside the warning window (inclusive)', () {
      expect(roStageZone(daysLeft: 14, lifespanDays: 90), Zone.amber);
      expect(roStageZone(daysLeft: 0, lifespanDays: 90), Zone.amber);
      expect(roStageZone(daysLeft: 72, lifespanDays: 720), Zone.amber);
    });

    test('green outside it', () {
      expect(roStageZone(daysLeft: 15, lifespanDays: 90), Zone.green);
      expect(roStageZone(daysLeft: 73, lifespanDays: 720), Zone.green);
      // Short lifespan: fresh must still be green despite the 14-day floor
      // (the window caps at half the lifespan — 10 of 20 days is amber,
      // anything above is green).
      expect(roStageZone(daysLeft: 11, lifespanDays: 20), Zone.green);
      expect(roStageZone(daysLeft: 20, lifespanDays: 20), Zone.green);
    });

    test('unknown for an invalid lifespan (#8)', () {
      expect(roStageZone(daysLeft: 5, lifespanDays: 0), Zone.unknown);
    });
  });

  test('default stage set covers the typical 4-stage unit, in water order', () {
    expect(kRoDefaultStageOrder, [
      RoStageType.sediment,
      RoStageType.carbonBlock,
      RoStageType.membrane,
      RoStageType.diResin,
    ]);
    for (final t in kRoDefaultStageOrder) {
      expect(kRoDefaultLifespanDays[t], greaterThanOrEqualTo(1));
    }
  });
}
