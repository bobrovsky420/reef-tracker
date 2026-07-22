import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/features/scan/scan_frame.dart';

void main() {
  group('mapUprightRectToImage', () {
    test('identity at 0 turns', () {
      final r = mapUprightRectToImage(0.25, 0.5, 0.75, 1.0, 200, 100, 0);
      expect(r, (x: 50, y: 50, w: 100, h: 50));
    });

    test('90° cw sensor (the common portrait case)', () {
      // 640×480 landscape buffer shown upright as 480×640. The full upright
      // frame must map onto the full buffer.
      final full = mapUprightRectToImage(0, 0, 1, 1, 640, 480, 1);
      expect(full, (x: 0, y: 0, w: 640, h: 480));
      // Lower-middle band of the upright view → right-middle band of the
      // buffer (rotating cw put the buffer's right edge at the bottom).
      final band = mapUprightRectToImage(0.25, 0.5, 0.75, 1.0, 640, 480, 1);
      expect(band, (x: 320, y: 120, w: 320, h: 240));
    });

    test('180° flip', () {
      final r = mapUprightRectToImage(0, 0, 0.5, 0.5, 200, 100, 2);
      expect(r, (x: 100, y: 50, w: 100, h: 50));
    });

    test('270° cw sensor', () {
      final full = mapUprightRectToImage(0, 0, 1, 1, 640, 480, 3);
      expect(full, (x: 0, y: 0, w: 640, h: 480));
      final top = mapUprightRectToImage(0, 0, 1, 0.5, 640, 480, 3);
      // Upright top half → buffer left half, mirrored to x 320..640? No:
      // 270° cw means the buffer's left edge is the upright top.
      expect(top, (x: 320, y: 0, w: 320, h: 480));
    });

    test('clamps to the buffer', () {
      final r = mapUprightRectToImage(-0.5, -0.5, 1.5, 1.5, 100, 50, 0);
      expect(r, (x: 0, y: 0, w: 100, h: 50));
    });
  });

  group('adjustForAnalysisAspect', () {
    const rect = (left: 0.08, top: 0.36, right: 0.92, bottom: 0.52);

    test('identity when aspects match', () {
      expect(adjustForAnalysisAspect(rect, 0.75, 0.75), rect);
    });

    test('wider analysis field compresses x toward the center', () {
      // Preview 9:16, analysis 3:4 — the preview is a centered horizontal
      // band of the analysis field.
      final r = adjustForAnalysisAspect(rect, 9 / 16, 3 / 4);
      expect(r.left, closeTo(0.5 - 0.42 * 0.75, 1e-9));
      expect(r.right, closeTo(0.5 + 0.42 * 0.75, 1e-9));
      expect(r.top, rect.top);
      expect(r.bottom, rect.bottom);
    });

    test('taller analysis field compresses y toward the center', () {
      final r = adjustForAnalysisAspect(rect, 3 / 4, 9 / 16);
      expect(r.left, rect.left);
      expect(r.right, rect.right);
      expect(r.top, closeTo(0.5 - 0.14 * 0.75, 1e-9));
      expect(r.bottom, closeTo(0.5 + 0.02 * 0.75, 1e-9));
    });
  });

  group('gray extraction', () {
    test('luma plane crop honors row stride', () {
      // 4 rows, 6 px wide, stride 8 (2 bytes padding per row).
      final plane = Uint8List(4 * 8);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 6; x++) {
          plane[y * 8 + x] = (10 * y + x);
        }
      }
      final g = grayFromLumaPlane(plane, 8, (x: 2, y: 1, w: 3, h: 2));
      expect(g.width, 3);
      expect(g.height, 2);
      expect(g.pixels, [12, 13, 14, 22, 23, 24]);
    });

    test('bgra crop computes luma', () {
      // One row of two BGRA pixels: (b,g,r) = (40,80,120) and (0,0,0).
      final plane = Uint8List.fromList([40, 80, 120, 255, 0, 0, 0, 255]);
      final g = grayFromBgraPlane(plane, 8, (x: 0, y: 0, w: 2, h: 1));
      // (r + 2g + b) >> 2 = (120 + 160 + 40) / 4 = 80.
      expect(g.pixels, [80, 0]);
    });
  });
}
