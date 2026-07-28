import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
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

    test('value equality — what decides "still the defaults?" (v28)', () {
      // The bound editor stores an override only when the submitted values
      // differ from the resolved defaults; that comparison is this operator.
      const a = ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);
      const b = ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5)));
      // A null bound is not the same as an absent-but-equal one.
      expect(const ZoneBounds(greenHigh: 1), isNot(const ZoneBounds()));
      expect(const ZoneBounds(), const ZoneBounds());
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

    test('amberLow == greenLow drops the low amber step (silicon)', () {
      // Red straight into green on the low side: a null amberLow would make
      // everything below green *amber*, so silicon's catalog default sets the
      // two bounds equal instead.
      const noLowAmber = ZoneBounds(
        amberLow: 0.1,
        greenLow: 0.1,
        greenHigh: 0.2,
        amberHigh: 0.22,
      );
      expect(noLowAmber.isValid, isTrue);
      expect(noLowAmber.classify(0.09), Zone.red);
      expect(noLowAmber.classify(0.1), Zone.green);
      expect(noLowAmber.classify(0.2), Zone.green);
      expect(noLowAmber.classify(0.21), Zone.amber);
      expect(noLowAmber.classify(0.23), Zone.red);

      // ...and the zero-width amber band is dropped rather than painted.
      final bands = zoneBands(noLowAmber, 0, 0.3);
      expect(bands.where((b) => b.zone == Zone.amber), hasLength(1));
      expect(bands.singleWhere((b) => b.zone == Zone.amber).y1, 0.2);
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

  group('gaugeAxis (REDESIGN #7/#8)', () {
    test('amber range expanded by 10% each side', () {
      const b = ZoneBounds(
        amberLow: 7,
        greenLow: 7.5,
        greenHigh: 8.5,
        amberHigh: 9,
      );
      final axis = gaugeAxis(b)!;
      expect(axis.min, closeTo(6.8, 1e-9)); // 7 − 0.1·2
      expect(axis.max, closeTo(9.2, 1e-9)); // 9 + 0.1·2
    });

    test('missing amber bound falls back to the supplied plausible bound', () {
      // Ammonia-style one-sided bounds: no lower limits at all.
      const b = ZoneBounds(greenHigh: 0.05, amberHigh: 0.25);
      final axis = gaugeAxis(b, fallbackLow: 0)!;
      expect(axis.min, closeTo(-0.025, 1e-9));
      expect(axis.max, closeTo(0.275, 1e-9));
    });

    test('unboundable side yields no axis', () {
      const b = ZoneBounds(greenHigh: 0.05, amberHigh: 0.25);
      expect(gaugeAxis(b), isNull); // no amberLow, no fallback
      expect(gaugeAxis(const ZoneBounds()), isNull);
    });

    test('invalid or empty spans yield no axis', () {
      const inverted = ZoneBounds(greenLow: 9, greenHigh: 8);
      expect(gaugeAxis(inverted, fallbackLow: 0, fallbackHigh: 10), isNull);
      // Degenerate span (lo == hi) can't position anything.
      const point = ZoneBounds(amberLow: 5, amberHigh: 5);
      expect(gaugeAxis(point), isNull);
    });

    test('fallbacks are ignored when the amber bounds exist', () {
      const b = ZoneBounds(amberLow: 7, amberHigh: 9);
      final axis = gaugeAxis(b, fallbackLow: 0, fallbackHigh: 100)!;
      expect(axis.min, closeTo(6.8, 1e-9));
      expect(axis.max, closeTo(9.2, 1e-9));
    });
  });

  group('ZoneVisuals', () {
    test('every zone maps to a distinct icon', () {
      final icons = Zone.values.map((z) => z.icon).toSet();
      expect(icons.length, Zone.values.length);
    });

    for (final brightness in Brightness.values) {
      testWidgets('every zone maps to a distinct colour ($brightness)', (
        tester,
      ) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildReefTheme(brightness, TargetPlatform.android),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final colors = Zone.values.map((z) => z.colorOf(ctx)).toSet();
        final softs = Zone.values.map((z) => z.softColorOf(ctx)).toSet();
        expect(colors.length, Zone.values.length);
        expect(softs.length, Zone.values.length);
      });
    }
  });
}
