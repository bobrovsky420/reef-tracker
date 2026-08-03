import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// One (time, value) point of a [Sparkline], oldest-first in the list.
typedef SparkPoint = ({DateTime time, double value});

/// Minimal recent-history polyline for dashboard cards (the flat-with-graphs
/// layout): the value's shape over a fixed trailing time window, no axes,
/// labels or touch — the card's value text and its history screen carry the
/// numbers. The x axis is time-scaled across the window (so measurement gaps
/// show as gaps in slope, and the newest reading sits at its true position,
/// not glued to the right edge), the y axis spans the in-window value range.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    this.window = const Duration(days: 7),
    this.color,
  });

  /// History points, oldest first. Points outside [window] (and non-finite
  /// values) are ignored; with nothing left in the window the widget renders
  /// empty space.
  final List<SparkPoint> points;

  /// Trailing time window ending now.
  final Duration window;

  /// Line color; defaults to the theme's primary — the same hue the full
  /// history charts plot their line in. Deliberately not zone-colored: status
  /// color stays reserved for the value text, the line only carries shape.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final end = DateTime.now();
    final start = end.subtract(window);
    final visible = [
      for (final p in points)
        if (p.value.isFinite && !p.time.isBefore(start) && !p.time.isAfter(end))
          p,
    ];
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(
        points: visible,
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
    required this.start,
    required this.end,
    required this.color,
  });

  final List<SparkPoint> points;
  final DateTime start;
  final DateTime end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Inset so the 2 px stroke and the end dot never clip at the edges.
    const dotRadius = 2.5;
    const inset = dotRadius + 1;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    if (w <= 0 || h <= 0) return;

    var min = points.first.value, max = points.first.value;
    for (final p in points) {
      if (p.value < min) min = p.value;
      if (p.value > max) max = p.value;
    }
    final spanMs = end.difference(start).inMilliseconds;
    final range = max - min;

    Offset at(SparkPoint p) {
      final x = p.time.difference(start).inMilliseconds / spanMs;
      // A flat series (or single point) draws as a centered horizontal line.
      final y = range == 0 ? 0.5 : 1 - (p.value - min) / range;
      return Offset(inset + x * w, inset + y * h);
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (points.length > 1) {
      final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
      for (final p in points.skip(1)) {
        final o = at(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, line);
    }
    // Dot on the newest reading, so a lone in-window point is still visible.
    canvas.drawCircle(at(points.last), dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.start != start ||
      old.end != end ||
      !listEquals(old.points, points);
}
