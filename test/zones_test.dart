import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/widgets/zone_visuals.dart';

void main() {
  group('ZoneBounds.classify', () {
    const b = ZoneBounds(
      amberLow: 7,
      greenLow: 7.5,
      greenHigh: 8.5,
      amberHigh: 9,
    );

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

    test('amber bound with null matching green bound still goes red', () {
      // greenHigh cleared but amberHigh kept: a value far above amberHigh must
      // be red, not short-circuit to green.
      const amberHighOnly = ZoneBounds(greenLow: 7.5, amberHigh: 20);
      expect(amberHighOnly.classify(999), Zone.red);
      expect(amberHighOnly.classify(15), Zone.green); // within unbounded green
      expect(amberHighOnly.classify(5), Zone.amber); // below green, no amberLow

      const amberLowOnly = ZoneBounds(amberLow: 5, greenHigh: 8.5);
      expect(amberLowOnly.classify(1), Zone.red);
      expect(amberLowOnly.classify(6), Zone.green); // within unbounded green
    });

    test('green with unbounded sides', () {
      const greenLowOnly = ZoneBounds(greenLow: 10);
      expect(greenLowOnly.classify(1000), Zone.green);
      expect(greenLowOnly.classify(5), Zone.amber); // below green, no amberLow
    });

    test(
      'bounds violating the ordering invariant classify as unknown (#30)',
      () {
        // Inverted greens (possible via restored/hand-edited backups) used to
        // label every value amber; they are unusable, not a real config.
        const inverted = ZoneBounds(greenLow: 9, greenHigh: 8);
        expect(inverted.isValid, isFalse);
        expect(inverted.classify(8.5), Zone.unknown);
        expect(inverted.classify(1), Zone.unknown);

        const crossed = ZoneBounds(amberLow: 8, greenLow: 7);
        expect(crossed.isValid, isFalse);
        expect(crossed.classify(7.5), Zone.unknown);
      },
    );

    test('ordered and partial bounds are valid', () {
      expect(b.isValid, isTrue);
      expect(const ZoneBounds().isValid, isTrue);
      expect(const ZoneBounds(amberLow: 5, amberHigh: 10).isValid, isTrue);
      expect(const ZoneBounds(greenLow: 7, greenHigh: 7).isValid, isTrue);
    });
  });

  group('ZoneBounds.copyWith / isEmpty', () {
    test('isEmpty only when every bound is null', () {
      expect(const ZoneBounds().isEmpty, isTrue);
      expect(const ZoneBounds(greenLow: 7).isEmpty, isFalse);
    });

    test('copyWith overrides only the supplied bounds', () {
      const b = ZoneBounds(
        amberLow: 7,
        greenLow: 7.5,
        greenHigh: 8.5,
        amberHigh: 9,
      );
      final c = b.copyWith(greenHigh: 9.0);
      expect(c.amberLow, 7);
      expect(c.greenLow, 7.5);
      expect(c.greenHigh, 9.0);
      expect(c.amberHigh, 9);
    });
  });

  group('ZoneVisuals', () {
    test('every zone maps to a distinct colour and icon', () {
      final colors = Zone.values.map((z) => z.color).toSet();
      final icons = Zone.values.map((z) => z.icon).toSet();
      expect(colors.length, Zone.values.length);
      expect(icons.length, Zone.values.length);
    });
  });
}
