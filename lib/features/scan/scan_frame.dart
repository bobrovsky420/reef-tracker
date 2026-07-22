import 'dart:typed_data';

import '../../domain/seven_segment.dart';

/// Camera-frame → [GrayImage] plumbing for the checker scan (U34).
///
/// Kept as pure functions over raw plane bytes (no `camera` plugin types)
/// so the geometry and luma extraction are unit-testable without a device.

/// An axis-aligned crop in image-buffer coordinates.
typedef CropRect = ({int x, int y, int w, int h});

/// A fractional rectangle (0..1 coordinates).
typedef FracRect = ({double left, double top, double right, double bottom});

/// Corrects a fractional rect drawn over the *preview* for the analysis
/// stream's differing aspect ratio. CameraX may serve the preview and the
/// image-analysis stream at different aspects; both look at the same
/// center, with the narrower field being a centered crop of the wider one.
/// Without this, the guide box the user aligns and the region the decoder
/// reads are different parts of the scene. Aspects are upright
/// (width / height as displayed); identical aspects return the rect
/// unchanged.
FracRect adjustForAnalysisAspect(
  FracRect rect,
  double previewAspect,
  double analysisAspect,
) {
  var (left: l, top: t, right: r, bottom: b) = rect;
  if (analysisAspect > previewAspect) {
    // Analysis field is wider: the preview is a centered horizontal band
    // of it — compress x toward the center.
    final s = previewAspect / analysisAspect;
    l = 0.5 + (l - 0.5) * s;
    r = 0.5 + (r - 0.5) * s;
  } else if (analysisAspect < previewAspect) {
    // Analysis field is taller: compress y toward the center.
    final s = analysisAspect / previewAspect;
    t = 0.5 + (t - 0.5) * s;
    b = 0.5 + (b - 0.5) * s;
  }
  return (left: l, top: t, right: r, bottom: b);
}

/// Maps a rectangle given in *upright* (portrait, as-displayed) fractional
/// coordinates onto the camera buffer, whose content is rotated by
/// `quarterTurnsCw * 90°` clockwise relative to upright (the plugin's
/// `sensorOrientation / 90`). The buffer is [imageW]×[imageH].
CropRect mapUprightRectToImage(
  double left,
  double top,
  double right,
  double bottom,
  int imageW,
  int imageH,
  int quarterTurnsCw,
) {
  // Upright-space dimensions.
  final swapped = quarterTurnsCw.isOdd;
  final uw = swapped ? imageH : imageW;
  final uh = swapped ? imageW : imageH;

  (double, double) toImage(double ux, double uy) =>
      switch (quarterTurnsCw & 3) {
        0 => (ux, uy),
        1 => (uy, imageH - ux), // upright = buffer rotated 90° cw
        2 => (imageW - ux, imageH - uy),
        _ => (imageW - uy, ux), // 270° cw
      };

  final (x1, y1) = toImage(left * uw, top * uh);
  final (x2, y2) = toImage(right * uw, bottom * uh);
  final x = x1 < x2 ? x1 : x2;
  final y = y1 < y2 ? y1 : y2;
  final w = (x1 - x2).abs();
  final h = (y1 - y2).abs();
  final cx = x.round().clamp(0, imageW - 1);
  final cy = y.round().clamp(0, imageH - 1);
  return (
    x: cx,
    y: cy,
    w: w.round().clamp(1, imageW - cx),
    h: h.round().clamp(1, imageH - cy),
  );
}

/// Extracts a cropped luma image from a YUV420 Y plane (Android frames).
GrayImage grayFromLumaPlane(
  Uint8List yPlane,
  int bytesPerRow,
  CropRect crop,
) {
  final out = Uint8List(crop.w * crop.h);
  for (var y = 0; y < crop.h; y++) {
    final src = (crop.y + y) * bytesPerRow + crop.x;
    out.setRange(y * crop.w, (y + 1) * crop.w, yPlane, src);
  }
  return GrayImage(out, crop.w, crop.h);
}

/// Extracts a cropped luma image from a BGRA8888 plane (iOS frames).
GrayImage grayFromBgraPlane(
  Uint8List plane,
  int bytesPerRow,
  CropRect crop,
) {
  final out = Uint8List(crop.w * crop.h);
  for (var y = 0; y < crop.h; y++) {
    var src = (crop.y + y) * bytesPerRow + crop.x * 4;
    for (var x = 0; x < crop.w; x++) {
      final b = plane[src];
      final g = plane[src + 1];
      final r = plane[src + 2];
      out[y * crop.w + x] = (r + 2 * g + b) >> 2;
      src += 4;
    }
  }
  return GrayImage(out, crop.w, crop.h);
}
