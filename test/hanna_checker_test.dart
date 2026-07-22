import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/hanna_checker.dart';
import 'package:reeftracker/domain/seven_segment.dart';

void main() {
  group('classifyCaseColor', () {
    test('recognizes the obvious families', () {
      expect(classifyCaseColor(110, 200, 120), CheckerColor.green);
      expect(classifyCaseColor(80, 140, 210), CheckerColor.blue);
      expect(classifyCaseColor(220, 60, 50), CheckerColor.red);
      expect(classifyCaseColor(240, 150, 60), CheckerColor.orange);
      expect(classifyCaseColor(240, 210, 70), CheckerColor.yellow);
      expect(classifyCaseColor(190, 170, 230), CheckerColor.lavender);
      expect(classifyCaseColor(235, 233, 230), CheckerColor.white);
      expect(classifyCaseColor(95, 97, 100), CheckerColor.graphite);
    });

    test('refuses uncertain samples instead of guessing', () {
      // Washed-out mid-gray at medium brightness: neither white nor
      // graphite with confidence.
      expect(classifyCaseColor(165, 163, 158), isNull);
      // Cyan — no checker family lives there.
      expect(classifyCaseColor(60, 200, 200), isNull);
    });
  });

  group('candidateCheckersFor', () {
    test('format narrows, color orders', () {
      // "0.30": two-decimals readout matches the green phosphate pair and
      // the yellow ammonia / lavender nitrate-LR models. With a green case
      // the phosphate pair leads, marine ULR first (registry order).
      const reading = SevenSegmentReading('0.30');
      final green = candidateCheckersFor(reading, color: CheckerColor.green);
      expect(green.map((c) => c.model).take(2), ['HI774', 'HI713']);
      expect(green.length, greaterThan(2)); // non-family matches follow
      final plain = candidateCheckersFor(reading);
      expect(plain.map((c) => c.model).toSet(), green.map((c) => c.model).toSet());
    });

    test('integer readouts resolve by family', () {
      // "93" fits several integer displays; a green case puts the nitrite
      // ULR and phosphorus ULR first.
      const reading = SevenSegmentReading('93');
      final green = candidateCheckersFor(reading, color: CheckerColor.green);
      expect(green.first.color, CheckerColor.green);
      final orange = candidateCheckersFor(reading, color: CheckerColor.orange);
      expect(orange.first.model, 'HI767');
    });

    test('out-of-format models never appear', () {
      // "1350" only fits the magnesium checker.
      const reading = SevenSegmentReading('1350');
      final c = candidateCheckersFor(reading);
      expect(c.map((m) => m.model), ['HI783']);
    });

    test('a unique color+format pair resolves to one leading model', () {
      const reading = SevenSegmentReading('10.0');
      final blue = candidateCheckersFor(reading, color: CheckerColor.blue);
      expect(blue.first.model, 'HI772');
    });
  });

  group('outcome collapsing', () {
    test('same-measurement models collapse into one choice', () {
      // "0.30": phosphate ULR and LR both save phosphate/ppm/×1 — no
      // choice to make between them; ammonia and nitrate LR remain
      // distinct outcomes.
      const reading = SevenSegmentReading('0.30');
      final candidates = candidateCheckersFor(
        reading,
        color: CheckerColor.green,
      );
      final outcomes = distinctOutcomeCheckers(candidates);
      expect(outcomes.map((c) => c.model), ['HI774', 'HI784', 'HI781']);
      expect(outcomeIsShared(outcomes.first, candidates), isTrue);
      expect(outcomeIsShared(outcomes[1], candidates), isFalse);
    });

    test('the three ppb nitrite checkers are one outcome', () {
      // "150" fits all three nitrite checkers (identical stored value),
      // the ppm alkalinity checker and the phosphorus ULR — three real
      // choices, not five.
      const reading = SevenSegmentReading('150');
      final outcomes = distinctOutcomeCheckers(candidateCheckersFor(reading));
      expect(outcomes.map((c) => c.model), ['HI755', 'HI764', 'HI736']);
    });
  });
}
