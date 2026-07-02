import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('zoneBands', () {
    // Convenience: the band covering a given zone, or null if none was emitted.
    ZoneBand? bandFor(List<ZoneBand> bands, Zone zone) {
      final matches = bands.where((b) => b.zone == zone).toList();
      return matches.isEmpty ? null : matches.single;
    }

    test('full four-bound config yields red/amber/green/amber/red spanning', () {
      const b = ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);
      final bands = zoneBands(b, 0, 14);

      // Every band is non-empty and non-inverted.
      for (final band in bands) {
        expect(band.y1, lessThan(band.y2));
      }

      final green = bandFor(bands, Zone.green)!;
      expect(green.y1, 7.5);
      expect(green.y2, 8.5);

      // Two amber bands (low side and high side).
      final amber = bands.where((x) => x.zone == Zone.amber).toList();
      expect(amber.length, 2);
      expect(amber.any((x) => x.y1 == 7 && x.y2 == 7.5), isTrue);
      expect(amber.any((x) => x.y1 == 8.5 && x.y2 == 9), isTrue);

      // Two red bands out to the chart edges.
      final red = bands.where((x) => x.zone == Zone.red).toList();
      expect(red.length, 2);
      expect(red.any((x) => x.y1 == 0 && x.y2 == 7), isTrue);
      expect(red.any((x) => x.y1 == 9 && x.y2 == 14), isTrue);
    });

    test('one-sided green falls back to the amber bound, not the chart edge', () {
      // greenLow cleared but amberLow kept: the green band must start at amberLow
      // (7), not at minY (0) where it would paint over the red band below it.
      const b = ZoneBounds(amberLow: 7, greenHigh: 8.5, amberHigh: 9);
      final bands = zoneBands(b, 0, 14);

      final green = bandFor(bands, Zone.green)!;
      expect(green.y1, 7); // amberLow fallback, not 0
      expect(green.y2, 8.5);

      // The red band below runs up to amberLow and does not overlap the green.
      final red = bands.where((x) => x.zone == Zone.red).toList();
      expect(red.any((x) => x.y1 == 0 && x.y2 == 7), isTrue);
      expect(green.y1, greaterThanOrEqualTo(7));
    });

    test('green falls back to chart edges only when no amber bound on that side',
        () {
      const b = ZoneBounds(greenLow: 7.5, greenHigh: 8.5);
      final bands = zoneBands(b, 0, 14);
      expect(bands.length, 1);
      final green = bands.single;
      expect(green.zone, Zone.green);
      expect(green.y1, 7.5);
      expect(green.y2, 8.5);
    });

    test('bounds violating the ordering invariant paint nothing (#30)', () {
      // greenLow > greenHigh (possible via restored backups) makes the whole
      // config unusable: no bands, matching classify() returning unknown.
      const b = ZoneBounds(greenLow: 9, greenHigh: 8);
      expect(zoneBands(b, 0, 14), isEmpty);
      expect(b.classify(8.5), Zone.unknown);
    });

    test('amber-only bounds paint green between them, matching classify (#30)',
        () {
      // Both greens null: classify() calls everything between the amber
      // bounds green, so the chart must paint that region green too.
      const b = ZoneBounds(amberLow: 5, amberHigh: 10);
      expect(b.classify(7), Zone.green);

      final bands = zoneBands(b, 0, 14);
      final green = bandFor(bands, Zone.green)!;
      expect(green.y1, 5);
      expect(green.y2, 10);
      final red = bands.where((x) => x.zone == Zone.red).toList();
      expect(red.any((x) => x.y1 == 0 && x.y2 == 5), isTrue);
      expect(red.any((x) => x.y1 == 10 && x.y2 == 14), isTrue);
    });

    test('empty bounds produce no bands', () {
      expect(zoneBands(const ZoneBounds(), 0, 14), isEmpty);
    });

    test('bands never overlap for a consistent config', () {
      const b = ZoneBounds(amberLow: 7, greenLow: 7.5, greenHigh: 8.5, amberHigh: 9);
      final bands = zoneBands(b, 0, 14)..sort((a, c) => a.y1.compareTo(c.y1));
      for (var i = 1; i < bands.length; i++) {
        // Each band starts where (or after) the previous one ended.
        expect(bands[i].y1, greaterThanOrEqualTo(bands[i - 1].y2));
      }
    });
  });
}
