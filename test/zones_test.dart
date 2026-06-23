import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('ZoneBounds.classify', () {
    const b = ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);

    test('inside green range', () {
      expect(b.classify(7.5), Zone.green);
      expect(b.classify(8.0), Zone.green);
      expect(b.classify(8.5), Zone.green);
    });

    test('amber just outside green', () {
      expect(b.classify(7.2), Zone.amber);
      expect(b.classify(8.8), Zone.amber);
    });

    test('red beyond amber bounds', () {
      expect(b.classify(6.9), Zone.red);
      expect(b.classify(9.1), Zone.red);
    });

    test('empty bounds are unknown', () {
      expect(const ZoneBounds().classify(5), Zone.unknown);
    });

    test('one-sided bounds (no lower limit) never go red below', () {
      const upperOnly = ZoneBounds(greenHigh: 0.02, amberHigh: 0.1);
      expect(upperOnly.classify(0), Zone.green);
      expect(upperOnly.classify(0.05), Zone.amber);
      expect(upperOnly.classify(0.2), Zone.red);
    });

    test('green with unbounded sides', () {
      const greenLowOnly = ZoneBounds(greenLow: 10);
      expect(greenLowOnly.classify(1000), Zone.green);
      expect(greenLowOnly.classify(5), Zone.amber); // below green, no amberLow
    });
  });
}
