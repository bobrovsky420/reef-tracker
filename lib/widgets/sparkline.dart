import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// One (time, value) point of a [Sparkline], oldest-first in the list.
typedef SparkPoint = ({DateTime time, double value});

/// One (time, min, max) range point of a [Sparkline]'s band, oldest-first —
/// the per-bucket min/max the wall display's sample rows carry (U49 §12m).
typedef SparkBandPoint = ({DateTime time, double min, double max});

/// Minimal recent-history polyline for dashboard cards (the flat-with-graphs
/// layout) and the wall display's tiles (U49): the value's shape over a fixed
/// trailing time window, no axes, labels or touch — the card's value text and
/// its history screen carry the numbers. The x axis is time-scaled across the
/// window (so measurement gaps show as gaps in slope, and the newest reading
/// sits at its true position, not glued to the right edge), the y axis spans
/// the in-window value range.
///
/// Two optional layers for the wall's sample-fed tiles:
/// - [band] — a translucent min/max range fill behind the line, one entry per
///   sample bucket; it is where an overnight temperature swing actually shows
///   up on a 5-minute-bucketed line.
/// - [markers] — hollow rings on hand-measured readings inside the window
///   (the history chart's marker convention), so a Hanna test and the probe
///   read as the same story.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    // Two weeks so a parameter tested only weekly still shows a line
    // (two-plus points), not a lone dot.
    this.window = const Duration(days: 14),
    this.color,
    this.band = const [],
    this.markers = const [],
    this.endAt,
  });

  /// History points, oldest first. Points outside [window] (and non-finite
  /// values) are ignored; with nothing left in the window the widget renders
  /// empty space.
  final List<SparkPoint> points;

  /// Trailing time window ending at [endAt] (defaults to now).
  final Duration window;

  /// Window end. A parameter so the wall display can pin one instant for a
  /// whole rebuilt page; null means `DateTime.now()` at build.
  final DateTime? endAt;

  /// Line color; defaults to the theme's primary — the same hue the full
  /// history charts plot their line in. Deliberately not zone-colored: status
  /// color stays reserved for the value text, the line only carries shape.
  final Color? color;

  /// Optional per-bucket min/max range, oldest first, drawn as a translucent
  /// fill behind the line in the line's own hue.
  final List<SparkBandPoint> band;

  /// Optional marker points (hand measurements), drawn as hollow rings on top
  /// of the line.
  final List<SparkPoint> markers;

  @override
  Widget build(BuildContext context) {
    final end = endAt ?? DateTime.now();
    final start = end.subtract(window);
    bool inWindow(DateTime t) => !t.isBefore(start) && !t.isAfter(end);
    final visible = [
      for (final p in points)
        if (p.value.isFinite && inWindow(p.time)) p,
    ];
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(
        points: visible,
        band: [
          for (final b in band)
            if (b.min.isFinite && b.max.isFinite && inWindow(b.time)) b,
        ],
        markers: [
          for (final m in markers)
            if (m.value.isFinite && inWindow(m.time)) m,
        ],
        start: start,
        end: end,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.band,
    required this.markers,
    required this.start,
    required this.end,
    required this.color,
  });

  final List<SparkPoint> points;
  final List<SparkBandPoint> band;
  final List<SparkPoint> markers;
  final DateTime start;
  final DateTime end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && markers.isEmpty) return;

    // Inset so the 2 px stroke and the end dot never clip at the edges.
    const dotRadius = 2.5;
    const inset = dotRadius + 1;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    if (w <= 0 || h <= 0) return;

    // The y range spans everything drawn — line, band and markers — so the
    // band can never spill outside the tile.
    double? min, max;
    void grow(double v) {
      min = (min == null || v < min!) ? v : min;
      max = (max == null || v > max!) ? v : max;
    }

    for (final p in points) {
      grow(p.value);
    }
    for (final b in band) {
      grow(b.min);
      grow(b.max);
    }
    for (final m in markers) {
      grow(m.value);
    }

    final spanMs = end.difference(start).inMilliseconds;
    final range = max! - min!;

    Offset at(DateTime time, double value) {
      final x = time.difference(start).inMilliseconds / spanMs;
      // A flat series (or single point) draws as a centered horizontal line.
      final y = range == 0 ? 0.5 : 1 - (value - min!) / range;
      return Offset(inset + x * w, inset + y * h);
    }

    // Band first, behind everything.
    if (band.length > 1) {
      final path = Path()
        ..moveTo(
          at(band.first.time, band.first.max).dx,
          at(band.first.time, band.first.max).dy,
        );
      for (final b in band.skip(1)) {
        final o = at(b.time, b.max);
        path.lineTo(o.dx, o.dy);
      }
      for (final b in band.reversed) {
        final o = at(b.time, b.min);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (points.length > 1) {
      final path = Path()
        ..moveTo(
          at(points.first.time, points.first.value).dx,
          at(points.first.time, points.first.value).dy,
        );
      for (final p in points.skip(1)) {
        final o = at(p.time, p.value);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, line);
    }
    // Dot on the newest reading, so a lone in-window point is still visible.
    if (points.isNotEmpty) {
      canvas.drawCircle(
        at(points.last.time, points.last.value),
        dotRadius,
        Paint()..color = color,
      );
    }
    // Hollow rings for hand measurements, over the line.
    if (markers.isNotEmpty) {
      final ring = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final m in markers) {
        canvas.drawCircle(at(m.time, m.value), dotRadius + 1, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.start != start ||
      old.end != end ||
      !listEquals(old.points, points) ||
      !listEquals(old.band, band) ||
      !listEquals(old.markers, markers);
}
