import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/clock.dart';

void main() {
  final now = DateTime(2026, 6, 1, 12);

  group('ageSince', () {
    test('measures the age of a past instant', () {
      expect(
        ageSince(now.subtract(const Duration(hours: 5)), now: now),
        const Duration(hours: 5),
      );
    });

    test('the same instant is zero', () {
      expect(ageSince(now, now: now), Duration.zero);
    });

    test('a future instant clamps to zero instead of going negative', () {
      expect(
        ageSince(now.add(const Duration(days: 2)), now: now),
        Duration.zero,
      );
    });
  });

  group('daysSince', () {
    test('rounds to the nearest day instead of truncating', () {
      // 18 h into the 7th day reads as 7 days, not 6.
      expect(
        daysSince(now.subtract(const Duration(days: 6, hours: 18)), now: now),
        7,
      );
      expect(
        daysSince(now.subtract(const Duration(days: 6, hours: 6)), now: now),
        6,
      );
    });

    test('half a day rounds up, just under half a day rounds down', () {
      expect(daysSince(now.subtract(const Duration(hours: 12)), now: now), 1);
      expect(daysSince(now.subtract(const Duration(hours: 11)), now: now), 0);
    });

    test('a future timestamp clamps to zero days', () {
      expect(daysSince(now.add(const Duration(days: 3)), now: now), 0);
    });
  });
}
