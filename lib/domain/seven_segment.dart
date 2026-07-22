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
SevenSegmentReading? decodeSevenSegment(GrayImage rawImage) {
  // Normalize scale: the noise floors, merge gaps and glyph proportions
  // below are tuned for crops ~80–150 px tall. A high-resolution crop (a
  // zoomed camera frame, a photo) behaves differently at native scale —
  // box-average it down, which also smooths sensor noise and reflections.
  var image = rawImage;
  if (image.height > 160) {
    image = _downscale(image, (image.height / 120).ceil());
  }
  if (image.width < 16 || image.height < 8) return null;

  // Threshold ladder: real crops contain regions much darker than the LCD
  // itself (case, bezel, shadows), so the first Otsu split often separates
  // those from the LCD and the digits — mid-gray on the bright LCD —
  // vanish into the bright class. Re-split the bright class and retry, a
  // few levels deep.
  int? threshold;
  for (var level = 0; level < 4; level++) {
    final next = _otsuThreshold(image.pixels, above: threshold);
    if (next == null || (threshold != null && next <= threshold)) return null;
    threshold = next;
    final reading = _decodeAtThreshold(image, threshold);
    if (reading != null) return reading;
  }
  return null;
}
// NOTE: an erosion fallback (retry each level with a 1-px eroded mask, to
// break blur bridges between digits and the window outline) was tried here
// and removed: it never rescued a fixture, but twice fabricated confident
// wrong readouts by eroding real digits away and by detaching border blobs
// into digit-shaped bars. Prefer refusing a frame over guessing.

GrayImage _downscale(GrayImage src, int f) {
  final w = src.width ~/ f, h = src.height ~/ f;
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var sum = 0;
      for (var yy = 0; yy < f; yy++) {
        final row = (y * f + yy) * src.width + x * f;
        for (var xx = 0; xx < f; xx++) {
          sum += src.pixels[row + xx];
        }
      }
      out[y * w + x] = sum ~/ (f * f);
    }
  }
  return GrayImage(out, w, h);
}

SevenSegmentReading? _decodeAtThreshold(GrayImage image, int threshold) {
  // Binarize: true = dark pixel (an LCD segment). Otsu's split point is the
  // highest luma of the dark class — inclusive.
  final w = image.width, h = image.height;
  final dark = List<bool>.filled(w * h, false);
  for (var i = 0; i < w * h; i++) {
    if (image.pixels[i] <= threshold) dark[i] = true;
  }

  // Not every dark region is a digit: case/bezel/shadow intrusions enter
  // from the crop border, and the display window's dark outline forms a
  // frame *around* the digits when the crop is wider than the window.
  // Digits are interior islands that span only a fraction of the crop —
  // drop everything else, or segmentation collapses. Interior drops (flat
  // dashes, slivers) may be fragments of half-captured digits, so their
  // ink stays visible to the acceptance guards below.
  final strayInk = _cleanMask(dark, w, h);

  // A readable display is mostly background: an almost-black or almost-empty
  // crop is a bad frame (lens covered, no display in the box).
  var darkCount = 0;
  for (final d in dark) {
    if (d) darkCount++;
  }
  final darkFrac = darkCount / (w * h);
  if (darkFrac < 0.005 || darkFrac > 0.5) return null;

  // The digit row band: expand from the row with the most ink (digits
  // dominate a readable crop) instead of spanning first-to-last inked row —
  // residual shadow lines or printed case text above the display would
  // inflate the band and bridge the column projection. Small row gaps are
  // bridged (a lone "1" has a mid-height joint gap); big ones end the band.
  final rowCounts = List<int>.filled(h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (dark[y * w + x]) rowCounts[y]++;
    }
  }
  final rowNoise = w ~/ 64;
  // Pick the anchor row by a window-summed score, not a single row's ink:
  // a thin, wide shadow line can out-ink any one digit row, but digits
  // dominate over a digit-height window.
  final k = h ~/ 8;
  var argmax = 0;
  var bestScore = -1;
  for (var y = 0; y < h; y++) {
    var score = 0;
    for (var yy = y - k; yy <= y + k; yy++) {
      if (yy >= 0 && yy < h) score += rowCounts[yy];
    }
    if (score > bestScore) {
      bestScore = score;
      argmax = y;
    }
  }
  // Anchor on an actually inked row near the smoothed peak.
  var anchor = -1;
  for (var d = 0; d <= k && anchor < 0; d++) {
    if (argmax - d >= 0 && rowCounts[argmax - d] > rowNoise) {
      anchor = argmax - d;
    } else if (argmax + d < h && rowCounts[argmax + d] > rowNoise) {
      anchor = argmax + d;
    }
  }
  if (anchor < 0) return null;
  final gapAllow = (h * 0.18).round();
  int expand(int from, int dir) {
    var edge = from;
    var gap = 0;
    for (var y = from + dir; y >= 0 && y < h && gap <= gapAllow; y += dir) {
      if (rowCounts[y] > rowNoise) {
        edge = y;
        gap = 0;
      } else {
        gap++;
      }
    }
    return edge;
  }

  final top = expand(anchor, -1);
  final bottom = expand(anchor, 1);
  if (bottom - top < 8) return null;
  final digitH = bottom - top + 1;

  // Decimal points are lifted out of the mask before any slicing: a dot is
  // a small squarish component seated deep in the bottom band of the line.
  // Isolating dots first keeps them from fusing digit slices together or
  // silently vanishing into a digit — a lost dot changes the value
  // ten-fold. At most one dot is ever shown.
  final dotXs = _extractDots(dark, w, top, bottom);
  if (dotXs.length > 1) return null;

  // Column projection inside the content rows: runs of inked columns are
  // digit slices, gaps separate them.
  final colCounts = List<int>.filled(w, 0);
  for (var x = 0; x < w; x++) {
    for (var y = top; y <= bottom; y++) {
      if (dark[y * w + x]) colCounts[x]++;
    }
  }
  // A real digit column carries at least a segment bar (~12% of the digit
  // height) — a couple of stray pixels from a window-edge residue must not
  // become a run that merges into a digit and skews its sampling.
  final colNoise = digitH ~/ 16;
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
  // merge runs whose gap is small relative to the digit height, but never
  // into something wider than one glyph (a digit is ~0.6× its height):
  // when the decimal point fills the whole inter-digit gap, two digits
  // would otherwise fuse through it.
  final mergeGap = (digitH * 0.10).round();
  final maxGlyphW = (digitH * 0.8).round();
  // A hairline run (window-edge residue) never merges — glued onto a digit
  // it would shift the digit's sampling zones. It stays a slice of its own
  // and is skipped by classification.
  final minRun = (digitH * 0.04).round().clamp(2, 1 << 30);
  final slices = <({int x0, int x1})>[];
  var lastMergeable = false;
  for (final run in runs) {
    final mergeable = run.x1 - run.x0 + 1 >= minRun;
    if (mergeable &&
        lastMergeable &&
        run.x0 - slices.last.x1 - 1 <= mergeGap &&
        run.x1 - slices.last.x0 + 1 <= maxGlyphW) {
      slices.last = (x0: slices.last.x0, x1: run.x1);
    } else {
      slices.add(run);
      lastMergeable = mergeable;
    }
  }
  if (slices.isEmpty || slices.length > 8) return null;

  final glyphs = <({int x0, int x1, String ch})>[];
  var digitInk = 0;
  var skippedInk = strayInk;
  int sliceInk(int x0, int x1) {
    var ink = 0;
    for (var x = x0; x <= x1; x++) {
      ink += colCounts[x];
    }
    return ink;
  }

  for (final slice in slices) {
    final glyph = _decodeSlice(dark, w, slice.x0, slice.x1, top, bottom);
    switch (glyph) {
      case null:
        return null; // unreadable digit-sized slice → reject the whole frame
      case '':
        // Non-digit blob (annunciator icon) — ignored, but tallied: see
        // the guard below.
        skippedInk += sliceInk(slice.x0, slice.x1);
        continue;
      default:
        digitInk += sliceInk(slice.x0, slice.x1);
        glyphs.add((x0: slice.x0, x1: slice.x1, ch: glyph));
    }
  }
  final digitCount = glyphs.length;
  if (digitCount == 0 || digitCount > 4) return null;
  // When the skipped blobs and dropped residue carry ink comparable to the
  // digits we kept, they were almost certainly half-captured digits (a
  // threshold level that only caught part of the display) — the surviving
  // fragment would read as a confident wrong value, e.g. a lone "1".
  // Single-digit readouts get a much stricter ratio: a legit lone-digit
  // display (a ppb checker showing "5") has only faint window residue
  // around it, while a lone surviving "1" sits among digit-sized leftovers.
  if (skippedInk * 2 > digitInk) return null;
  if (digitCount == 1 && skippedInk * 4 > digitInk) return null;

  // Re-insert the dot by position. It must sit in the gap between two
  // digits: a "dot" overlapping a digit's own columns is a stray fragment
  // (accepting it would invent a decimal), and a dot before the first or
  // after the last digit is never a valid readout.
  final buffer = StringBuffer();
  if (dotXs.isEmpty) {
    for (final g in glyphs) {
      buffer.write(g.ch);
    }
  } else {
    final dotX = dotXs.first;
    for (final g in glyphs) {
      if (dotX >= g.x0 && dotX <= g.x1) return null;
    }
    final idx = glyphs.indexWhere((g) => g.x0 > dotX);
    if (idx <= 0) return null;
    for (var i = 0; i < glyphs.length; i++) {
      if (i == idx) buffer.write('.');
      buffer.write(glyphs[i].ch);
    }
  }
  final text = buffer.toString();
  // A lone "1" is never accepted: two bare bars are the easiest glyph to
  // fabricate (a window edge, a leftover digit fragment — every misread
  // this decoder has ever produced was a lone "1"), and the guards above
  // can't see fragments swallowed by the border-connected frame. The cost
  // is refusing a genuine reading of exactly 1, which the user can type.
  if (text == '1') return null;
  return SevenSegmentReading(text);
}

/// Finds decimal-point components inside the digit band — small, squarish,
/// seated deep in the bottom of the line — removes them from the mask and
/// returns their x-centers. Everything else (digit bars, icons, residue)
/// stays untouched.
List<int> _extractDots(List<bool> dark, int w, int top, int bottom) {
  final bandH = bottom - top + 1;
  // Lower bound in ink: a dot is roughly segment-thickness squared
  // (~0.05·bandH per side — the band may be inflated by residue above the
  // digits, so this must not assume digits fill it).
  final minSize = (0.0025 * bandH * bandH).round().clamp(4, 1 << 30);
  // A dot is segment-thickness sized — well under a digit's b/c bar height
  // (~0.3 of the line), which must never qualify.
  final maxDim = (0.22 * bandH).round();
  final dots = <int>[];
  final visited = <int, bool>{};
  final stack = <int>[];
  final member = <int>[];
  for (var yy = top; yy <= bottom; yy++) {
    for (var xx = 0; xx < w; xx++) {
      final start = yy * w + xx;
      if (!dark[start] || (visited[start] ?? false)) continue;
      visited[start] = true;
      stack.add(start);
      member.clear();
      var minX = w, maxX = 0, minY = bottom, maxY = top;
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        member.add(i);
        final x = i % w, y = i ~/ w;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        void push(int j) {
          final jy = j ~/ w;
          if (jy >= top && jy <= bottom && dark[j] && !(visited[j] ?? false)) {
            visited[j] = true;
            stack.add(j);
          }
        }

        if (x > 0) push(i - 1);
        if (x < w - 1) push(i + 1);
        if (y > 0) push(i - w);
        if (i + w < dark.length) push(i + w);
      }
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      final squarish = bw <= 2 * bh + 2 && bh <= 2 * bw + 2;
      final isDot =
          member.length >= minSize &&
          bw <= maxDim &&
          bh <= maxDim &&
          squarish &&
          minY >= top + (0.55 * bandH).round();
      if (isDot) {
        for (final i in member) {
          dark[i] = false;
        }
        dots.add((minX + maxX) ~/ 2);
      }
    }
  }
  return dots;
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
  // For hairline slices any ink counts — requiring >1 px per row would make
  // a 1-px column unclassifiable (null) and veto the whole frame.
  final rowThresh = w >= 16 ? w ~/ 8 : (w >= 3 ? 1 : 0);
  final rowInk = List<int>.filled(contentBottom - contentTop + 1, 0);
  var top = -1, bottom = -1;
  var maxRowInk = 0;
  for (var y = contentTop; y <= contentBottom; y++) {
    var ink = 0;
    for (var x = x0; x <= x1; x++) {
      if (dark[y * imageW + x]) ink++;
    }
    rowInk[y - contentTop] = ink;
    if (ink > maxRowInk) maxRowInk = ink;
    if (ink > rowThresh) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  if (top < 0) return null;
  // Trim weak boundary rows: anti-aliasing remnants of the window's shadow
  // lines carry a fraction of the ink of real segment rows, and a junk row
  // at the slice's bottom edge reads as a fake `d` segment. Bounded, so a
  // digit's own thinner rows (a lone stem) can't be eaten.
  final trimLimit = ((bottom - top + 1) * 0.15).round();
  final weak = maxRowInk * 0.25;
  var trimmed = 0;
  while (trimmed < trimLimit &&
      top < bottom &&
      rowInk[top - contentTop] < weak) {
    top++;
    trimmed++;
  }
  trimmed = 0;
  while (trimmed < trimLimit &&
      bottom > top &&
      rowInk[bottom - contentTop] < weak) {
    bottom--;
    trimmed++;
  }
  final h = bottom - top + 1;
  final contentH = contentBottom - contentTop + 1;

  // Anything that doesn't span most of the line height is not a digit
  // (annunciator icons, leftover dot-like blobs — real decimal points were
  // already extracted before slicing) — skip it rather than reject the
  // frame.
  if (h < contentH * 0.6) return '';

  // Digit 1 renders as just the two right-hand bars: a narrow slice that
  // spans the full height. Segment sampling can't tell b+c from e+f on a
  // bare bar, so classify by aspect ratio instead.
  if (w < h * 0.36) return '1';

  // A digit is taller than wide. A wide, flat-ish blob (a chunk of shadow
  // line that survived cleanup) would light every sampled zone and read as
  // a fake "8" — skip it instead.
  if (w > h * 0.9) return '';

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
  const on = 0.28;
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

/// Clears dark components that cannot be digits: those touching the crop
/// border (bezel bands, case edges, shadows entering from outside), those
/// whose bounding box spans nearly the whole crop (the display window's
/// dark outline — a frame around the digits, dragging every column
/// together), and flat/hairline residue. Digits and the decimal point are
/// compact interior islands and survive.
///
/// Returns the total ink of the dropped *interior* residue (flat dashes,
/// slivers): those may equally be fragments of a half-captured digit, so
/// the caller counts them as skipped ink — a lone surviving digit next to
/// dropped fragments must not read as a confident value.
int _cleanMask(List<bool> dark, int w, int h) {
  final visited = List<bool>.filled(w * h, false);
  final stack = <int>[];
  final member = <int>[];
  var strayInk = 0;
  for (var start = 0; start < w * h; start++) {
    if (!dark[start] || visited[start]) continue;
    visited[start] = true;
    stack.add(start);
    member.clear();
    var minX = w, maxX = 0, minY = h, maxY = 0;
    var touchesBorder = false;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      member.add(i);
      final x = i % w, y = i ~/ w;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x == 0 || x == w - 1 || y == 0 || y == h - 1) touchesBorder = true;
      void push(int j) {
        if (dark[j] && !visited[j]) {
          visited[j] = true;
          stack.add(j);
        }
      }

      if (x > 0) push(i - 1);
      if (x < w - 1) push(i + 1);
      if (y > 0) push(i - w);
      if (y < h - 1) push(i + w);
    }
    final bw = maxX - minX + 1, bh = maxY - minY + 1;
    // Nothing glyph-shaped is ever wider than a third of the crop (a digit
    // is ~0.6× its height, and the crop is ~2.3:1) — anything wider is the
    // window outline, a shadow line, or printed case text on one streak.
    final isWide = bw > 0.35 * w;
    // A hairline vertical sliver (the window's side-edge shadow) is far
    // thinner than any real segment bar (~8% of the crop height).
    final isSliver = bw < 0.06 * h && bh > 0.2 * h;
    // A flat dash (the window's top/bottom shadow broken into pieces) is
    // shorter than any segment bar's thickness AND elongated — a decimal
    // point is equally short but squarish, and must survive.
    final isFlat = bh < 0.065 * h && bw > 2 * bh;
    if (touchesBorder || isWide || isSliver || isFlat) {
      // Interior residue counts as stray ink (see doc comment); structural
      // drops (border-connected, crop-wide) don't — they are the window and
      // its surroundings, present in every well-framed crop.
      if (!touchesBorder && !isWide) strayInk += member.length;
      for (final i in member) {
        dark[i] = false;
      }
    }
  }
  return strayInk;
}

/// Otsu's method over the luma histogram; null when the image has no
/// contrast worth thresholding (blank wall, lens cap). With [above], only
/// pixels strictly brighter than it participate — the second-level split
/// that finds digits on the LCD when something darker is also in frame.
int? _otsuThreshold(Uint8List pixels, {int? above}) {
  final hist = List<int>.filled(256, 0);
  var total = 0;
  for (final p in pixels) {
    if (above == null || p > above) {
      hist[p]++;
      total++;
    }
  }
  if (total < 256) return null;
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
  // Guard against a contrast-free frame — but only on the full image: the
  // threshold ladder's deeper levels legitimately split ever-weaker
  // contrasts (digits barely darker than the LCD background), and a junk
  // split decodes to nothing anyway.
  final spread = maxVar / (total.toDouble() * total.toDouble());
  if (above == null && spread < 8 * 8) return null;
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
