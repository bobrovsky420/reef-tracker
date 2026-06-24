import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/database.dart';

/// Builds dashed vertical chart lines marking each water change that falls
/// within the visible time window [minX]..[maxX] (milliseconds since epoch).
/// Shared by every time-series graph so water changes are shown consistently.
List<VerticalLine> waterChangeLines({
  required List<WaterChange> changes,
  required double minX,
  required double maxX,
  required Color color,
}) {
  final lines = <VerticalLine>[];
  for (final c in changes) {
    final x = c.changedAt.millisecondsSinceEpoch.toDouble();
    if (x < minX || x > maxX) continue;
    lines.add(VerticalLine(
      x: x,
      color: color,
      strokeWidth: 1.5,
      dashArray: const [5, 4],
    ));
  }
  return lines;
}

/// The colour used for water-change markers across all graphs.
Color waterChangeMarkerColor(BuildContext context) =>
    Colors.lightBlue.shade400;
