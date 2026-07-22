import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/seven_segment.dart';

/// Renders a seven-segment readout the way a checker LCD looks through the
/// viewfinder: dark bars with corner gaps on a light background, optional
/// speckle noise / lighting gradient / annunciator icon.
GrayImage renderLcd(
  String text, {
  int inkLuma = 60,
  int bgLuma = 180,
  double noise = 0,
  int gradient = 0,
  bool batteryIcon = false,
  int seed = 7,
}) {
  const dw = 60, dh = 100, t = 12, gap = 2, spacing = 16, margin = 24;
  const segments = {
    '0': 0x3F,
    '1': 0x06,
    '2': 0x5B,
    '3': 0x4F,
    '4': 0x66,
    '5': 0x6D,
    '6': 0x7D,
    '7': 0x07,
    '8': 0x7F,
    '9': 0x6F,
  };
  var width = margin * 2;
  for (final ch in text.split('')) {
    width += ch == '.' ? t + spacing : dw + spacing;
  }
  final height = dh + margin * 2;
  final pixels = Uint8List(width * height);
  final rnd = Random(seed);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var luma = bgLuma + (gradient * x ~/ width);
      if (noise > 0 && rnd.nextDouble() < noise) luma = inkLuma;
      pixels[y * width + x] = luma.clamp(0, 255);
    }
  }
  void fill(int x0, int y0, int x1, int y1) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        pixels[y * width + x] = inkLuma;
      }
    }
  }

  var cx = margin;
  for (final ch in text.split('')) {
    if (ch == '.') {
      fill(cx, margin + dh - t, cx + t, margin + dh);
      cx += t + spacing;
      continue;
    }
    final mask = segments[ch]!;
    final top = margin;
    const mid = dh ~/ 2;
    if (mask & 0x01 != 0) fill(cx + t + gap, top, cx + dw - t - gap, top + t);
    if (mask & 0x40 != 0) {
      fill(cx + t + gap, top + mid - t ~/ 2, cx + dw - t - gap, top + mid + t ~/ 2);
    }
    if (mask & 0x08 != 0) {
      fill(cx + t + gap, top + dh - t, cx + dw - t - gap, top + dh);
    }
    if (mask & 0x20 != 0) fill(cx, top + t + gap, cx + t, top + mid - t ~/ 2 - gap);
    if (mask & 0x02 != 0) {
      fill(cx + dw - t, top + t + gap, cx + dw, top + mid - t ~/ 2 - gap);
    }
    if (mask & 0x10 != 0) {
      fill(cx, top + mid + t ~/ 2 + gap, cx + t, top + dh - t - gap);
    }
    if (mask & 0x04 != 0) {
      fill(cx + dw - t, top + mid + t ~/ 2 + gap, cx + dw, top + dh - t - gap);
    }
    cx += dw + spacing;
  }
  if (batteryIcon) {
    // Small solid icon at the display edge, vertically centered (real
    // annunciators sit at the LCD edge, clear of the digits) — must be
    // ignored, not decoded and not a frame reject.
    fill(0, margin + dh ~/ 2 - 8, 9, margin + dh ~/ 2 + 8);
  }
  return GrayImage(pixels, width, height);
}

void main() {
  group('decodeSevenSegment', () {
    test('decodes typical checker readouts', () {
      for (final text in [
        '0.30', // the HI774 example
        '0.09',
        '2.50',
        '8.88',
        '7.71',
        '20.0',
        '12.5',
        '125',
        '300',
        '456',
        '1800', // 4-digit magnesium
        '93',
        '0',
        '1.00',
        '10.1',
      ]) {
        final result = decodeSevenSegment(renderLcd(text));
        expect(result?.text, text, reason: 'render of "$text"');
      }
    });

    test('reports value and decimal count', () {
      final r = decodeSevenSegment(renderLcd('0.30'))!;
      expect(r.value, 0.30);
      expect(r.decimals, 2);
      final i = decodeSevenSegment(renderLcd('125'))!;
      expect(i.value, 125);
      expect(i.decimals, 0);
    });

    test('survives speckle noise', () {
      final r = decodeSevenSegment(renderLcd('0.30', noise: 0.002));
      expect(r?.text, '0.30');
    });

    test('survives a lighting gradient', () {
      final r = decodeSevenSegment(renderLcd('4.56', gradient: 40));
      expect(r?.text, '4.56');
    });

    test('survives low contrast', () {
      final r = decodeSevenSegment(
        renderLcd('0.30', inkLuma: 110, bgLuma: 165),
      );
      expect(r?.text, '0.30');
    });

    test('ignores annunciator icons', () {
      final r = decodeSevenSegment(renderLcd('0.30', batteryIcon: true));
      expect(r?.text, '0.30');
    });

    test('strips a bezel band entering from the border', () {
      // A dark band along the crop edge (display bezel, case, shadow) used
      // to decode as a lone "1" on real scenes. Border-connected dark
      // regions must be ignored.
      final img = renderLcd('0.30');
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < 13; x++) {
          img.pixels[y * img.width + x] = 50;
        }
      }
      expect(decodeSevenSegment(img)?.text, '0.30');
    });

    test('finds digits when something darker is in frame (two-level)', () {
      // Green case in the crop is darker than the LCD: the first Otsu split
      // separates case vs LCD and the mid-gray digits vanish into the
      // bright class — the second-level split must recover them.
      final img = renderLcd('0.30', inkLuma: 110, bgLuma: 170);
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          if (x < 20 || x >= img.width - 20) {
            img.pixels[y * img.width + x] = 25;
          }
        }
      }
      expect(decodeSevenSegment(img)?.text, '0.30');
    });

    test('rejects a blank frame', () {
      final pixels = Uint8List(200 * 100)..fillRange(0, 200 * 100, 180);
      expect(decodeSevenSegment(GrayImage(pixels, 200, 100)), isNull);
    });

    test('rejects an all-dark frame', () {
      final pixels = Uint8List(200 * 100)..fillRange(0, 200 * 100, 10);
      expect(decodeSevenSegment(GrayImage(pixels, 200, 100)), isNull);
    });

    test('rejects an invalid segment pattern', () {
      // A lone top bar is no known digit — the frame must be rejected, not
      // guessed at.
      final img = renderLcd('8');
      // Erase everything except rows of segment a by lifting all dark
      // pixels below the top fifth back to background.
      for (var y = 44; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          if (img.pixels[y * img.width + x] < 128) {
            img.pixels[y * img.width + x] = 180;
          }
        }
      }
      expect(decodeSevenSegment(img), isNull);
    });

    test('rejects a trailing or leading dot', () {
      expect(decodeSevenSegment(renderLcd('.30')), isNull);
      // Trailing dot: rendered "30." ends with the dot slice.
      expect(decodeSevenSegment(renderLcd('30.')), isNull);
    });
  });

  group('SevenSegmentVote', () {
    test('accepts after the required consecutive agreement', () {
      final vote = SevenSegmentVote(required: 3);
      const a = SevenSegmentReading('0.30');
      const b = SevenSegmentReading('0.80');
      vote.add(a);
      vote.add(b); // disagreement resets the streak
      vote.add(a);
      vote.add(null); // unreadable frames don't break a streak
      vote.add(a);
      expect(vote.winner, isNull);
      vote.add(a);
      expect(vote.winner, a);
      // Further frames don't change an accepted winner.
      vote.add(b);
      expect(vote.winner, a);
    });

    test('reset starts over', () {
      final vote = SevenSegmentVote(required: 2);
      const a = SevenSegmentReading('1.23');
      vote.add(a);
      vote.add(a);
      expect(vote.winner, a);
      vote.reset();
      expect(vote.winner, isNull);
    });
  });
}
