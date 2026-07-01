import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../features/actions/water_change_markers.dart';
import '../l10n/app_localizations.dart';

/// The shared chart time range, stored as its [label] ('7d', '30d', '90d',
/// 'All') via [chartRangeProvider]. Applied to every parameter graph.
enum ChartRange {
  week('7d', 7),
  month('30d', 30),
  quarter('90d', 90),
  all('All', null);

  const ChartRange(this.label, this.days);
  final String label;
  final int? days;
}

String chartRangeLabel(AppLocalizations l, ChartRange r) {
  switch (r) {
    case ChartRange.week:
      return l.rangeWeek;
    case ChartRange.month:
      return l.rangeMonth;
    case ChartRange.quarter:
      return l.rangeQuarter;
    case ChartRange.all:
      return l.rangeAll;
  }
}

/// Resolves a stored range label back to its [ChartRange], defaulting to month.
ChartRange chartRangeFromLabel(String? label) {
  for (final r in ChartRange.values) {
    if (r.label == label) return r;
  }
  return ChartRange.month;
}

/// Segmented selector for the shared [chartRangeProvider]. Persisting the choice
/// makes it carry over to every graph and session.
class ChartRangeSelector extends ConsumerWidget {
  const ChartRangeSelector({super.key, this.padding = const EdgeInsets.all(8)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final range = chartRangeFromLabel(ref.watch(chartRangeProvider).value);
    return Padding(
      padding: padding,
      child: SegmentedButton<ChartRange>(
        segments: [
          for (final r in ChartRange.values)
            ButtonSegment(value: r, label: Text(chartRangeLabel(l, r))),
        ],
        selected: {range},
        onSelectionChanged: (s) =>
            ref.read(settingsProvider).setChartRange(s.first.label),
      ),
    );
  }
}

/// Reusable `fl_chart` line chart for one parameter's time series, with zone
/// bands and water-change marker lines. Plots everything in the user's display
/// unit while keeping zone bounds canonical→display converted.
///
/// When [minX]/[maxX] are supplied the chart is pinned to that exact time
/// window (used by the comparison view so multiple stacked charts share an
/// aligned time axis); otherwise the window is derived from the data — a single
/// reading is centered in a 24h window.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.readings,
    required this.param,
    required this.pres,
    required this.waterChanges,
    this.minX,
    this.maxX,
    this.showBottomTitles = true,
  });

  final List<Reading> readings;
  final TrackedParameter? param;
  final ParamPresentation pres;
  final List<WaterChange> waterChanges;

  /// Optional explicit time window (epoch millis). When both are set the chart
  /// uses them verbatim so several charts can share one aligned X axis.
  final double? minX;
  final double? maxX;

  /// Whether to draw the bottom date labels. The plot area's horizontal extent
  /// is governed by the fixed left-axis width, so hiding these does not affect
  /// alignment between stacked charts — only the last chart need show dates.
  final bool showBottomTitles;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final r in readings)
        FlSpot(r.takenAt.millisecondsSinceEpoch.toDouble(),
            pres.toDisplay(r.value)),
    ];
    final p = param;
    final canonical = p != null ? boundsOf(p) : const ZoneBounds();
    double? d(double? v) => v == null ? null : pres.toDisplay(v);
    final bounds = ZoneBounds(
      amberLow: d(canonical.amberLow),
      greenLow: d(canonical.greenLow),
      greenHigh: d(canonical.greenHigh),
      amberHigh: d(canonical.amberHigh),
    );

    final values = spots.map((s) => s.y).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    // Include bounds in the visible range so zone bands are meaningful.
    for (final b in [
      bounds.amberLow,
      bounds.greenLow,
      bounds.greenHigh,
      bounds.amberHigh
    ]) {
      if (b != null) {
        minY = b < minY ? b : minY;
        maxY = b > maxY ? b : maxY;
      }
    }
    final pad = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    final hasWindow = minX != null && maxX != null;
    final isSingle = !hasWindow && spots.length == 1;
    final double loX;
    final double hiX;
    if (hasWindow) {
      loX = minX!;
      hiX = maxX!;
    } else if (isSingle) {
      // Center a lone measurement instead of pinning it to the left edge.
      const halfWindowMs = 12 * 60 * 60 * 1000; // 12h either side
      loX = spots.first.x - halfWindowMs;
      hiX = spots.first.x + halfWindowMs;
    } else {
      loX = spots.first.x;
      hiX = spots.last.x;
    }
    final spanMs = (hiX - loX).abs();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: loX,
        maxX: hiX,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: _zoneBands(bounds, minY, maxY),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: waterChangeLines(
            changes: waterChanges,
            minX: loX,
            maxX: hiX,
            color: waterChangeMarkerColor(context),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(
                v.toStringAsFixed(pres.decimals.clamp(0, 2)),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showBottomTitles,
              reservedSize: 28,
              // For a single reading, emit exactly one centered label;
              // otherwise label both ends plus well-spaced interior ticks.
              minIncluded: !isSingle,
              maxIncluded: !isSingle,
              interval: isSingle ? spanMs : spanMs / 4,
              getTitlesWidget: (v, meta) {
                if (!isSingle) {
                  // Drop interval ticks that crowd (and visually duplicate)
                  // the fixed first/last date labels at the edges.
                  final atEdge = (v - loX).abs() < 1 || (hiX - v).abs() < 1;
                  if (!atEdge) {
                    final gap = spanMs * 0.15;
                    if ((v - loX) < gap || (hiX - v) < gap) {
                      return const SizedBox.shrink();
                    }
                  }
                }
                final dt = DateTime.fromMillisecondsSinceEpoch(
                    isSingle ? spots.first.x.toInt() : v.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat.Md().format(dt),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
            dotData: FlDotData(show: spots.length <= 40),
          ),
        ],
      ),
    );
  }

  List<HorizontalRangeAnnotation> _zoneBands(
      ZoneBounds b, double minY, double maxY) {
    Color c(Zone z) => z.color.withValues(alpha: 0.10);
    // Band geometry (fallbacks, overlap/inversion dropping) lives in the pure,
    // unit-tested `zoneBands`; here we only map it onto fl_chart annotations.
    return [
      for (final band in zoneBands(b, minY, maxY))
        HorizontalRangeAnnotation(
            y1: band.y1, y2: band.y2, color: c(band.zone)),
    ];
  }
}
