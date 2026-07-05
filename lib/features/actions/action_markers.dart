import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';

/// The maintenance-action types drawn as vertical marker lines on graphs (U6).
enum ActionMarkerKind { waterChange, carbonChange, equipmentCleaning }

/// One logged action occurrence to mark on a chart's time axis.
@immutable
class ActionMarker {
  const ActionMarker(this.time, this.kind);

  final DateTime time;
  final ActionMarkerKind kind;
}

/// Flattens the three action logs into one chart-marker list.
List<ActionMarker> actionMarkers({
  required List<WaterChange> waterChanges,
  required List<CarbonChange> carbonChanges,
  required List<EquipmentCleaning> cleanings,
}) => [
  for (final w in waterChanges)
    ActionMarker(w.changedAt, ActionMarkerKind.waterChange),
  for (final c in carbonChanges)
    ActionMarker(c.changedAt, ActionMarkerKind.carbonChange),
  for (final e in cleanings)
    ActionMarker(e.cleanedAt, ActionMarkerKind.equipmentCleaning),
];

/// Dash pattern per kind — distinct patterns keep the marker types apart for
/// color-blind users, not just by hue.
List<int> actionMarkerDash(ActionMarkerKind kind) => switch (kind) {
  ActionMarkerKind.waterChange => const [5, 4],
  ActionMarkerKind.carbonChange => const [2, 3],
  ActionMarkerKind.equipmentCleaning => const [10, 4],
};

/// Theme-derived marker color per kind (#47: never fixed colors): water stays
/// on tertiary, carbon on secondary, cleaning on the neutral outline — all
/// distinct from the primary-colored series line on both brightnesses.
Color actionMarkerColor(BuildContext context, ActionMarkerKind kind) {
  final scheme = Theme.of(context).colorScheme;
  return switch (kind) {
    ActionMarkerKind.waterChange => scheme.tertiary,
    ActionMarkerKind.carbonChange => scheme.secondary,
    ActionMarkerKind.equipmentCleaning => scheme.outline,
  };
}

/// Localized marker name, reusing the action-log row titles.
String actionMarkerLabel(AppLocalizations l, ActionMarkerKind kind) =>
    switch (kind) {
      ActionMarkerKind.waterChange => l.waterChange,
      ActionMarkerKind.carbonChange => l.carbonChange,
      ActionMarkerKind.equipmentCleaning => l.equipmentCleaning,
    };

/// Builds the dashed vertical chart lines for every marker inside the visible
/// time window [minX]..[maxX] (milliseconds since epoch). Shared by every
/// marker-drawing graph so actions are shown consistently.
List<VerticalLine> actionMarkerLines({
  required List<ActionMarker> markers,
  required double minX,
  required double maxX,
  required Color Function(ActionMarkerKind kind) color,
}) {
  final lines = <VerticalLine>[];
  for (final m in markers) {
    final x = m.time.millisecondsSinceEpoch.toDouble();
    if (x < minX || x > maxX) continue;
    lines.add(
      VerticalLine(
        x: x,
        color: color(m.kind),
        strokeWidth: 1.5,
        dashArray: actionMarkerDash(m.kind),
      ),
    );
  }
  return lines;
}

/// The kinds that fall within [minX]..[maxX] — drives the legend so it only
/// names line styles actually visible on the chart above.
Set<ActionMarkerKind> actionMarkerKindsInWindow(
  List<ActionMarker> markers,
  double minX,
  double maxX,
) => {
  for (final m in markers)
    if (m.time.millisecondsSinceEpoch >= minX &&
        m.time.millisecondsSinceEpoch <= maxX)
      m.kind,
};

/// Small legend naming the marker lines on the chart(s) above: a dash-style
/// swatch plus the localized action name per kind. Renders nothing when
/// [kinds] is empty.
class ActionMarkerLegend extends StatelessWidget {
  const ActionMarkerLegend({super.key, required this.kinds});

  final Set<ActionMarkerKind> kinds;

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Iterate the enum, not `kinds`, for a stable display order.
          for (final k in ActionMarkerKind.values)
            if (kinds.contains(k))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(18, 12),
                    painter: _DashSwatchPainter(
                      color: actionMarkerColor(context, k),
                      dash: actionMarkerDash(k),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(actionMarkerLabel(l, k), style: style),
                ],
              ),
        ],
      ),
    );
  }
}

/// A short horizontal sample of a marker line's dash pattern.
class _DashSwatchPainter extends CustomPainter {
  const _DashSwatchPainter({required this.color, required this.dash});

  final Color color;
  final List<int> dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final seg = dash[i % dash.length].toDouble();
      if (i.isEven) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + seg).clamp(0, size.width), y),
          paint,
        );
      }
      x += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(_DashSwatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dash != dash;
}
