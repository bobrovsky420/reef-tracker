import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../features/actions/action_markers.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'zone_visuals.dart';

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

/// Shared touch behavior for the app's line charts. fl_chart's default
/// tooltip (blue text on dark grey) is barely legible; this one uses the
/// theme's inverse-surface pair for contrast in both brightnesses and shows
/// [formatValue]'s text over a localized timestamp instead of a raw y.
///
/// [noteFor] (by spot index) appends the reading's note as a third line,
/// collapsed to a single truncated line — the full text lives in the
/// history list, the tooltip is just the pointer to it.
LineTouchData chartLineTouchData(
  BuildContext context, {
  required String Function(FlSpot spot) formatValue,
  String? Function(int spotIndex)? noteFor,
}) {
  final scheme = Theme.of(context).colorScheme;
  return LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => scheme.inverseSurface,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItems: (spots) => [
        for (final s in spots)
          LineTooltipItem(
            formatValue(s),
            TextStyle(
              color: scheme.onInverseSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            children: [
              TextSpan(
                text:
                    '\n${formatDateTime(context, DateTime.fromMillisecondsSinceEpoch(s.x.toInt()), weekday: false)}',
                style: TextStyle(
                  color: scheme.onInverseSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.normal,
                  fontSize: 11,
                ),
              ),
              if (_noteExcerpt(noteFor?.call(s.spotIndex)) case final note?)
                TextSpan(
                  text: '\n$note',
                  style: TextStyle(
                    color: scheme.onInverseSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.normal,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

/// A note collapsed to one tooltip-sized line, or null when there is nothing
/// to show.
String? _noteExcerpt(String? note) {
  if (note == null) return null;
  final oneLine = note.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (oneLine.isEmpty) return null;
  return oneLine.length <= 60 ? oneLine : '${oneLine.substring(0, 59)}…';
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
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.readings,
    required this.param,
    required this.pres,
    required this.markers,
    this.minX,
    this.maxX,
    this.showBottomTitles = true,
    this.zoomable = false,
    this.showMarkerLegend = false,
  });

  final List<Reading> readings;
  final TrackedParameter? param;
  final ParamPresentation pres;

  /// Logged maintenance actions drawn as dashed vertical lines (U6); build
  /// with [actionMarkers].
  final List<ActionMarker> markers;

  /// Optional explicit time window (epoch millis). When both are set the chart
  /// uses them verbatim so several charts can share one aligned X axis.
  final double? minX;
  final double? maxX;

  /// Whether to draw the bottom date labels. The plot area's horizontal extent
  /// is governed by the fixed left-axis width, so hiding these does not affect
  /// alignment between stacked charts — only the last chart need show dates.
  final bool showBottomTitles;

  /// Enables pinch-zoom (horizontal) and pan, with double-tap to reset (U5c).
  /// Off by default: comparison-view charts must stay pinned to their shared
  /// [minX]/[maxX] window, and the small dashboard charts don't need it.
  final bool zoomable;

  /// Renders a compact [ActionMarkerLegend] under the plot for the marker
  /// kinds visible in this chart's window. Off by default: the comparison
  /// view stacks many charts and draws one shared legend itself.
  final bool showMarkerLegend;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  /// Owned here (not by fl_chart) so double-tap can reset the zoom/pan.
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readings = widget.readings;
    final pres = widget.pres;
    final spots = [
      for (final r in readings)
        FlSpot(
          r.takenAt.millisecondsSinceEpoch.toDouble(),
          pres.toDisplay(r.value),
        ),
    ];
    // Guard the widget's own contract (#17): `values.reduce` below throws on
    // an empty series. Current callers filter first, but the next one won't.
    if (spots.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noReadingsInRange,
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }
    final p = widget.param;
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
      bounds.amberHigh,
    ]) {
      if (b != null) {
        minY = b < minY ? b : minY;
        maxY = b > maxY ? b : maxY;
      }
    }
    final pad = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    final hasWindow = widget.minX != null && widget.maxX != null;
    final isSingle = !hasWindow && spots.length == 1;
    final double loX;
    final double hiX;
    if (hasWindow) {
      loX = widget.minX!;
      hiX = widget.maxX!;
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

    // Note markers (U13): noted readings keep an accent dot even on dense
    // series where regular dots are hidden. Indexed lookups work because
    // `spots` is built 1:1 from `readings` above; the x-value set only feeds
    // `checkToShowDot`, whose callback doesn't receive the spot index.
    final scheme = Theme.of(context).colorScheme;
    final hasNote = [
      for (final r in readings) r.note?.trim().isNotEmpty ?? false,
    ];
    final notedXs = <double>{
      for (var i = 0; i < spots.length; i++)
        if (hasNote[i]) spots[i].x,
    };
    final showAllDots = spots.length <= 40;

    final chart = LineChart(
      transformationConfig: widget.zoomable
          ? FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              maxScale: 10,
              transformationController: _transformation,
            )
          : const FlTransformationConfig(),
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: loX,
        maxX: hiX,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: _zoneBands(bounds, minY, maxY),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: actionMarkerLines(
            markers: widget.markers,
            minX: loX,
            maxX: hiX,
            color: (kind) => actionMarkerColor(context, kind),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: chartLineTouchData(
          context,
          formatValue: (s) =>
              '${formatLocaleNumber(s.y, pres.decimals)} ${pres.unitLabel}',
          noteFor: (i) => readings[i].note,
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(
                formatLocaleNumber(v, pres.decimals.clamp(0, 2)),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: widget.showBottomTitles,
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
                  isSingle ? spots.first.x.toInt() : v.toInt(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(dt),
                    style: const TextStyle(fontSize: 10),
                  ),
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
            color: scheme.primary,
            dotData: FlDotData(
              show: showAllDots || notedXs.isNotEmpty,
              checkToShowDot: (spot, bar) =>
                  showAllDots || notedXs.contains(spot.x),
              // Noted readings get a ringed accent dot in the same tertiary
              // "annotation" family as the water-change markers; shape keeps
              // them apart (dot vs vertical line).
              getDotPainter: (spot, xPct, bar, index) => hasNote[index]
                  ? FlDotCirclePainter(
                      radius: 4.5,
                      color: scheme.tertiary,
                      strokeWidth: 2,
                      strokeColor: scheme.surface,
                    )
                  : FlDotCirclePainter(
                      radius: 3,
                      color: scheme.primary,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
            ),
          ),
        ],
      ),
    );
    Widget result = widget.zoomable
        ? GestureDetector(
            onDoubleTap: () => _transformation.value = Matrix4.identity(),
            child: chart,
          )
        : chart;
    if (widget.showMarkerLegend) {
      final kinds = actionMarkerKindsInWindow(widget.markers, loX, hiX);
      if (kinds.isNotEmpty) {
        result = Column(
          children: [
            Expanded(child: result),
            ActionMarkerLegend(kinds: kinds),
          ],
        );
      }
    }
    return result;
  }

  List<HorizontalRangeAnnotation> _zoneBands(
    ZoneBounds b,
    double minY,
    double maxY,
  ) {
    Color c(Zone z) => z.softColorOf(context);
    // Band geometry (fallbacks, overlap/inversion dropping) lives in the pure,
    // unit-tested `zoneBands`; here we only map it onto fl_chart annotations.
    return [
      for (final band in zoneBands(b, minY, maxY))
        HorizontalRangeAnnotation(
          y1: band.y1,
          y2: band.y2,
          color: c(band.zone),
        ),
    ];
  }
}
