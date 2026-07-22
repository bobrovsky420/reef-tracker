import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reeftracker/domain/hanna_checker.dart';
import 'package:reeftracker/domain/seven_segment.dart';
import 'package:reeftracker/features/scan/scan_frame.dart';

/// Photo regression tests for the seven-segment decoder: real checker
/// photos, decoded exactly like a camera frame. Fixtures live in
/// `test/fixtures/hanna_photos/`, named `<MODEL>_<expected>.jpg`
/// (e.g. `HI774_0.50.jpg`).
///
/// - `catalog/` — Hanna's product photos (full checker in frame, studio
///   light); decoded with a shared display-region crop that deliberately
///   includes the bezel and some case, which is what a casually framed
///   viewfinder sees. A `hard_` prefix marks a fixture the decoder is not
///   expected to read (low-res shots whose digits are bridged to the window
///   outline by JPEG blur, or barely darker than the LCD) — for those the
///   requirement flips: refusing is fine, a *wrong* readout is the failure
///   (a refused frame just doesn't win the viewfinder vote).
/// - `user/` — phone photos taken like the viewfinder guide box: the
///   display filling most of the frame. Drop new photos in with the naming
///   convention and they become test cases automatically.

GrayImage _grayFromFile(File file) {
  final decoded = img.decodeImage(file.readAsBytesSync())!;
  final pixels = Uint8List(decoded.width * decoded.height);
  var i = 0;
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final p = decoded.getPixel(x, y);
      // Same luma weighting as the live BGRA path (scan_frame.dart).
      pixels[i++] = ((p.r.toInt() + 2 * p.g.toInt() + p.b.toInt()) >> 2)
          .clamp(0, 255);
    }
  }
  return GrayImage(pixels, decoded.width, decoded.height);
}

GrayImage _cropFrac(GrayImage src, double l, double t, double r, double b) {
  final x0 = (src.width * l).round();
  final y0 = (src.height * t).round();
  final x1 = (src.width * r).round();
  final y1 = (src.height * b).round();
  final w = x1 - x0, h = y1 - y0;
  final pixels = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    pixels.setRange(
      y * w,
      (y + 1) * w,
      src.pixels,
      (y0 + y) * src.width + x0,
    );
  }
  return GrayImage(pixels, w, h);
}

({String model, String expected, bool hard})? _parseName(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final m = RegExp(r'^(hard_)?(HI\d+)_([\d.]+)\.(jpe?g|png)$').firstMatch(name);
  if (m == null) return null;
  return (
    model: m.group(2)!,
    expected: m.group(3)!,
    hard: m.group(1) != null,
  );
}

void main() {
  void run(String subdir, GrayImage Function(GrayImage) crop) {
    final dir = Directory('test/fixtures/hanna_photos/$subdir');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => _parseName(f.path) != null)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final spec = _parseName(file.path)!;
      test('$subdir/${file.uri.pathSegments.last}', () {
        final gray = crop(_grayFromFile(file));
        final reading = decodeSevenSegment(gray);
        if (spec.hard) {
          // Known-hard photo: the decoder may refuse, but must never
          // return a different value than what the display shows.
          expect(
            reading == null || reading.text == spec.expected,
            isTrue,
            reason:
                'misread as "${reading?.text}" (expected ${spec.expected} '
                'or refusal)',
          );
          return;
        }
        expect(reading?.text, spec.expected);
        // The registry's display format must agree with what the real
        // device shows — a mismatch means wrong decimals/range in
        // hanna_methods.yaml.
        final checker = hannaCheckerByModel(spec.model);
        expect(checker, isNotNull, reason: '${spec.model} not in registry');
        expect(
          checker!.matches(reading!),
          isTrue,
          reason:
              '${spec.model} format (decimals ${checker.decimals}, '
              '${checker.min}–${checker.max}) rejects "${reading.text}"',
        );
      });
    }
  }

  group('catalog product photos', () {
    // The display region of Hanna's uniformly framed product shots, with
    // the window outline and its shadows deliberately included.
    run('catalog', (g) => _cropFrac(g, 0.24, 0.44, 0.76, 0.65));
  });

  group('user photos', () {
    // Framed like the viewfinder: display fills most of the frame. Phone
    // photos arrive in any orientation, so every rotation is tried — the
    // upright one must decode the expected value, and (just as important)
    // no sideways orientation may *misread*: rotated digit bars must
    // refuse, exactly like a badly held viewfinder.
    final dir = Directory('test/fixtures/hanna_photos/user');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => _parseName(f.path) != null)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final spec = _parseName(file.path)!;
      test('user/${file.uri.pathSegments.last}', () {
        final gray = _grayFromFile(file);
        final decoded = <String>[];
        for (var turns = 0; turns < 4; turns++) {
          final reading = decodeSevenSegment(rotateGrayCw(gray, turns));
          if (reading != null) decoded.add(reading.text);
        }
        expect(
          decoded,
          isNotEmpty,
          reason: 'no orientation decoded (expected ${spec.expected})',
        );
        for (final text in decoded) {
          expect(text, spec.expected, reason: 'misread as "$text"');
        }
      });
    }
  });
}
