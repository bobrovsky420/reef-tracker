import 'dart:typed_data';

/// Pure-Dart seven-segment LCD decoder (U34 — checker camera scan).
///
/// Decodes the digits shown on a Hanna pocket-checker LCD from a grayscale
/// crop of the display area. Deliberately not OCR: the digits are made of
/// disconnected bars that generic text recognition misreads, while a
/// segment-position decoder is deterministic — every frame either yields a
/// confident digit string or null, never a plausible-looking wrong guess
/// (an unknown segment pattern rejects the whole frame).
///
/// The pipeline expects the caller (the scan screen's viewfinder guide box)
/// to have already framed the display roughly; it tolerates margins, mild
/// tilt and uneven lighting, and relies on the caller's multi-frame
/// agreement vote to reject the occasional glare-induced misread.

/// A grayscale image: `pixels[y * width + x]` = luma 0–255.
class GrayImage {
  const GrayImage(this.pixels, this.width, this.height)
    : assert(pixels.length == width * height);

  final Uint8List pixels;
  final int width;
  final int height;
}

/// One decoded display readout, e.g. `0.30` or `125`.
class SevenSegmentReading {
  const SevenSegmentReading(this.text);

  /// The digits as shown, including any decimal point (never empty).
  final String text;

  /// Number of digits after the decimal point (0 when there is none).
  int get decimals {
    final dot = text.indexOf('.');
    return dot < 0 ? 0 : text.length - dot - 1;
  }

  double get value => double.parse(text);

  @override
  bool operator ==(Object other) =>
      other is SevenSegmentReading && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'SevenSegmentReading($text)';
}

/// Segment bitmask order: a=1, b=2, c=4, d=8, e=16, f=32, g=64 in the
/// conventional layout:
/// ```
///   ─a─
///  f   b
///   ─g─
///  e   c
///   ─d─
/// ```
const Map<int, String> _kSegmentPatterns = {
  0x3F: '0', // abcdef
  0x06: '1', // bc
  0x5B: '2', // abdeg
  0x4F: '3', // abcdg
  0x66: '4', // bcfg
  0x6D: '5', // acdfg
  0x7D: '6', // acdefg
  0x07: '7', // abc
  0x7F: '8',
  0x6F: '9', // abcdfg
};

/// Decodes the seven-segment digits in [image]. Returns null when the frame
/// does not contain a confidently readable digit string — callers treat
/// that as "skip this frame", so rejecting is always safer than guessing.
SevenSegmentReading? decodeSevenSegment(GrayImage image) {
  if (image.width < 16 || image.height < 8) return null;

  final threshold = _otsuThreshold(image);
  if (threshold == null) return null;

  // Binarize: true = dark pixel (an LCD segment).
  final w = image.width, h = image.height;
  final dark = List<bool>.filled(w * h, false);
  var darkCount = 0;
  // Otsu's split point is the highest luma of the dark class — inclusive.
  for (var i = 0; i < w * h; i++) {
    if (image.pixels[i] <= threshold) {
      dark[i] = true;
      darkCount++;
    }
  }
  // A readable display is mostly background: an almost-black or almost-empty
  // crop is a bad frame (lens covered, no display in the box).
  final darkFrac = darkCount / (w * h);
  if (darkFrac < 0.005 || darkFrac > 0.5) return null;

  // Row range of the actual content, ignoring speckle noise.
  final rowCounts = List<int>.filled(h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (dark[y * w + x]) rowCounts[y]++;
    }
  }
  final rowNoise = w ~/ 64;
  var top = -1, bottom = -1;
  for (var y = 0; y < h; y++) {
    if (rowCounts[y] > rowNoise) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  if (top < 0 || bottom - top < 8) return null;
  final digitH = bottom - top + 1;

  // Column projection inside the content rows: runs of inked columns are
  // digit slices (or the decimal point), gaps separate them.
  final colCounts = List<int>.filled(w, 0);
  for (var x = 0; x < w; x++) {
    for (var y = top; y <= bottom; y++) {
      if (dark[y * w + x]) colCounts[x]++;
    }
  }
  final colNoise = digitH ~/ 32;
  final runs = <({int x0, int x1})>[];
  var runStart = -1;
  for (var x = 0; x <= w; x++) {
    final inked = x < w && colCounts[x] > colNoise;
    if (inked && runStart < 0) runStart = x;
    if (!inked && runStart >= 0) {
      runs.add((x0: runStart, x1: x - 1));
      runStart = -1;
    }
  }
  // A digit's bars don't touch at the corners, so one glyph can span
  // several column runs. Joints are tiny next to the inter-glyph spacing —
  // merge runs whose gap is small relative to the digit height.
  final mergeGap = (digitH * 0.10).round();
  final slices = <({int x0, int x1})>[];
  for (final run in runs) {
    if (slices.isNotEmpty && run.x0 - slices.last.x1 - 1 <= mergeGap) {
      slices.last = (x0: slices.last.x0, x1: run.x1);
    } else {
      slices.add(run);
    }
  }
  if (slices.isEmpty || slices.length > 8) return null;

  final buffer = StringBuffer();
  var digitCount = 0;
  var dotCount = 0;
  for (final slice in slices) {
    final glyph = _decodeSlice(dark, w, slice.x0, slice.x1, top, bottom);
    switch (glyph) {
      case null:
        return null; // unreadable digit-sized slice → reject the whole frame
      case '':
        continue; // non-digit annunciator icon → ignore
      case '.':
        // A leading or double dot is never a valid readout.
        if (digitCount == 0 || buffer.toString().endsWith('.')) return null;
        dotCount++;
        buffer.write('.');
      default:
        digitCount++;
        buffer.write(glyph);
    }
  }
  if (digitCount == 0 || digitCount > 4 || dotCount > 1) return null;
  final text = buffer.toString();
  if (text.endsWith('.')) return null;
  return SevenSegmentReading(text);
}

/// Decodes one column slice: a digit, a decimal point ('.'), or null when
/// it is neither.
String? _decodeSlice(
  List<bool> dark,
  int imageW,
  int x0,
  int x1,
  int contentTop,
  int contentBottom,
) {
  // Tight row range of this slice. A row only counts when it has real ink,
  // not a lone speckle — otherwise one noise pixel above the decimal point
  // stretches its bounding box to digit height.
  final w = x1 - x0 + 1;
  final rowThresh = w >= 16 ? w ~/ 8 : 1;
  var top = -1, bottom = -1;
  for (var y = contentTop; y <= contentBottom; y++) {
    var ink = 0;
    for (var x = x0; x <= x1; x++) {
      if (dark[y * imageW + x]) ink++;
    }
    if (ink > rowThresh) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  if (top < 0) return null;
  final h = bottom - top + 1;
  final contentH = contentBottom - contentTop + 1;

  // Decimal point: a short blob sitting in the bottom quarter of the line.
  if (h <= contentH * 0.3 && top >= contentTop + contentH * 0.55) {
    return '.';
  }
  // Anything else that doesn't span most of the line height is not a digit
  // (annunciator icons such as the battery symbol) — skip it rather than
  // reject the frame.
  if (h < contentH * 0.6) return '';

  // Digit 1 renders as just the two right-hand bars: a narrow slice that
  // spans the full height. Segment sampling can't tell b+c from e+f on a
  // bare bar, so classify by aspect ratio instead.
  if (w < h * 0.36) return '1';

  double inkFrac(double fx0, double fy0, double fx1, double fy1) {
    final ax0 = x0 + (fx0 * w).round();
    final ax1 = x0 + (fx1 * w).round() - 1;
    final ay0 = top + (fy0 * h).round();
    final ay1 = top + (fy1 * h).round() - 1;
    var ink = 0, total = 0;
    for (var y = ay0; y <= ay1; y++) {
      for (var x = ax0; x <= ax1; x++) {
        total++;
        if (dark[y * imageW + x]) ink++;
      }
    }
    return total == 0 ? 0 : ink / total;
  }

  // Sample the seven segment zones. Horizontal segments are probed around
  // the digit's center column; vertical segments in the outer thirds of
  // the upper/lower halves, away from the horizontals' rows.
  const on = 0.32;
  var mask = 0;
  if (inkFrac(0.30, 0.00, 0.70, 0.15) > on) mask |= 0x01; // a
  if (inkFrac(0.72, 0.16, 1.00, 0.44) > on) mask |= 0x02; // b
  if (inkFrac(0.72, 0.56, 1.00, 0.84) > on) mask |= 0x04; // c
  if (inkFrac(0.30, 0.85, 0.70, 1.00) > on) mask |= 0x08; // d
  if (inkFrac(0.00, 0.56, 0.28, 0.84) > on) mask |= 0x10; // e
  if (inkFrac(0.00, 0.16, 0.28, 0.44) > on) mask |= 0x20; // f
  if (inkFrac(0.30, 0.43, 0.70, 0.57) > on) mask |= 0x40; // g

  return _kSegmentPatterns[mask];
}

/// Otsu's method over the luma histogram; null when the image has no
/// contrast worth thresholding (blank wall, lens cap).
int? _otsuThreshold(GrayImage image) {
  final hist = List<int>.filled(256, 0);
  for (final p in image.pixels) {
    hist[p]++;
  }
  final total = image.pixels.length;
  var sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0, wB = 0;
  var maxVar = 0.0;
  var best = -1;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final between = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      best = t;
    }
  }
  if (best < 0) return null;
  // Guard against a contrast-free frame: the two classes must actually be
  // separated (empirically ~12 luma levels even in poor light).
  final spread = maxVar / (total.toDouble() * total.toDouble());
  if (spread < 12 * 12) return null;
  return best;
}

/// Agreement vote over a stream of per-frame decodes: [add] frames as they
/// are decoded (null for unreadable frames is fine); [winner] becomes
/// non-null once the same readout has been seen [required] times in a row,
/// which is the scan screen's accept signal.
class SevenSegmentVote {
  SevenSegmentVote({this.required = 3});

  final int required;
  SevenSegmentReading? _candidate;
  int _streak = 0;
  SevenSegmentReading? _winner;

  SevenSegmentReading? get winner => _winner;

  void add(SevenSegmentReading? reading) {
    if (_winner != null) return;
    if (reading == null) return; // unreadable frames don't break a streak
    if (reading == _candidate) {
      _streak++;
    } else {
      _candidate = reading;
      _streak = 1;
    }
    if (_streak >= required) _winner = reading;
  }

  void reset() {
    _candidate = null;
    _streak = 0;
    _winner = null;
  }
}
