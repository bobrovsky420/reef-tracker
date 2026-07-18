import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/ratio.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_segmented.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/zone_visuals.dart';

/// Time-series graph of a [RatioKind] for the active tank.
class RatioScreen extends ConsumerWidget {
  const RatioScreen({super.key, required this.kind});

  final RatioKind kind;

  /// Time ranges mirroring the parameter history screen.
  static const _ranges = <(String, int?)>[
    ('7d', 7),
    ('30d', 30),
    ('90d', 90),
    ('All', null),
  ];

  String _rangeLabel(AppLocalizations l, String key) {
    switch (key) {
      case '7d':
        return l.rangeWeek;
      case '30d':
        return l.rangeMonth;
      case '90d':
        return l.rangeQuarter;
      default:
        return l.rangeAll;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rangeKey = ref.watch(chartRangeProvider).value ?? '30d';
    final days = _ranges
        .firstWhere((r) => r.$1 == rangeKey, orElse: () => _ranges[1])
        .$2;

    final numeratorAsync = ref.watch(paramReadingsProvider(kind.numeratorKey));
    final denominatorAsync = ref.watch(
      paramReadingsProvider(kind.denominatorKey),
    );
    final bounds = ratioBounds(
      kind,
      ref.watch(ratioSettingsProvider).value?[kind.name],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.ratioScreenTitle(kind))),
      body: (numeratorAsync.isLoading || denominatorAsync.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final numerator =
                    (numeratorAsync.value ?? const []).ratioReadings;
                final denominator =
                    (denominatorAsync.value ?? const []).ratioReadings;
                final all = computeRatioSeries(numerator, denominator);
                final cutoff = days == null
                    ? null
                    : DateTime.now().subtract(Duration(days: days));
                final data = cutoff == null
                    ? all
                    : all.where((p) => p.time.isAfter(cutoff)).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                      child: ReefSegmented<String>(
                        options: [
                          for (final r in _ranges) (r.$1, _rangeLabel(l, r.$1)),
                        ],
                        selected: rangeKey,
                        onChanged: (r) =>
                            ref.read(settingsProvider).setChartRange(r),
                      ),
                    ),
                    Expanded(
                      // Builder-based slivers (T14): only visible rows are
                      // instantiated — the old ListView(children:) built the
                      // whole series' tiles per rebuild on "All".
                      child: data.isEmpty
                          ? Center(child: Text(l.ratioNoData))
                          : CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      12,
                                    ),
                                    child: ReefCard(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        14,
                                        8,
                                        12,
                                      ),
                                      child: SizedBox(
                                        height: 280,
                                        child: _RatioChart(
                                          kind: kind,
                                          points: data,
                                          bounds: bounds,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    12 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  sliver: _pointsSliver(context, data),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// The computed ratio points as one card of hairline-divided rows
  /// (REDESIGN #17 rider): value mono w700, component breakdown sub, date
  /// trailing. Rows have no tap/swipe behavior (derived data, unchanged).
  Widget _pointsSliver(BuildContext context, List<RatioPoint> data) {
    final tokens = ReefTokens.of(context);
    return ReefSliverCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      sliver: SliverList.builder(
        itemCount: data.length,
        itemBuilder: (context, i) {
          final p = data[data.length - 1 - i]; // newest first
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: i == data.length - 1
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.surfaceBorder),
                    ),
                  ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatRatioValue(kind, p.ratio),
                        style: ReefTokens.monoTextStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ratioBreakdown(kind, p),
                        style: TextStyle(fontSize: 12, color: tokens.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat.yMMMEd().format(p.time),
                  style: TextStyle(fontSize: 12, color: tokens.textDim),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RatioChart extends StatelessWidget {
  const _RatioChart({
    required this.kind,
    required this.points,
    required this.bounds,
  });

  final RatioKind kind;
  final List<RatioPoint> points;
  final ZoneBounds bounds;

  @override
  Widget build(BuildContext context) {
    // Plot the value implied by the display form (e.g. the `N` of `1 : N`).
    final spots = [
      for (final p in points)
        if (ratioChartY(kind, p.ratio).isFinite)
          FlSpot(
            p.time.millisecondsSinceEpoch.toDouble(),
            ratioChartY(kind, p.ratio),
          ),
    ];

    if (spots.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).ratioNoData));
    }

    final values = spots.map((s) => s.y).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    // Include the zone bounds in the visible range so the bands are meaningful.
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
    final pad = (maxY - minY).abs() < 1e-9
        ? (maxY.abs() * 0.1 + 0.01)
        : (maxY - minY) * 0.12;
    minY = (minY - pad).clamp(0, double.infinity);
    maxY += pad;

    final isSingle = spots.length == 1;
    final double minX;
    final double maxX;
    if (isSingle) {
      const halfWindowMs = 12 * 60 * 60 * 1000;
      minX = spots.first.x - halfWindowMs;
      maxX = spots.first.x + halfWindowMs;
    } else {
      minX = spots.first.x;
      maxX = spots.last.x;
    }
    final spanMs = (maxX - minX).abs();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: minX,
        maxX: maxX,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: _zoneBands(context, bounds, minY, maxY),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        // Label the touched value in the kind's display form: the chart Y is
        // the `N` of `1 : N` for oneToN kinds, the plain quotient otherwise.
        lineTouchData: chartLineTouchData(
          context,
          formatValue: (s) => switch (kind.display) {
            RatioDisplay.oneToN => '1 : ${formatRatioN(s.y)}',
            RatioDisplay.decimal => formatLocaleNumber(s.y, 1),
          },
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
              reservedSize: 48,
              getTitlesWidget: (v, meta) =>
                  Text(formatRatioN(v), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              minIncluded: !isSingle,
              maxIncluded: !isSingle,
              interval: isSingle ? spanMs : spanMs / 4,
              getTitlesWidget: (v, meta) {
                if (!isSingle) {
                  final atEdge = (v - minX).abs() < 1 || (maxX - v).abs() < 1;
                  if (!atEdge) {
                    final gap = spanMs * 0.15;
                    if ((v - minX) < gap || (maxX - v) < gap) {
                      return const SizedBox.shrink();
                    }
                  }
                }
                final d = DateTime.fromMillisecondsSinceEpoch(
                  isSingle ? spots.first.x.toInt() : v.toInt(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(d),
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
            color: Theme.of(context).colorScheme.primary,
            // Hollow dots like the parameter chart (REDESIGN #17): the opaque
            // scheme surface masks the line under the dot.
            dotData: FlDotData(
              show: spots.length <= 40,
              getDotPainter: (spot, xPct, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: Theme.of(context).colorScheme.surface,
                strokeWidth: 2,
                strokeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Green/amber/red bands from the kind's recommended bounds (chart-Y space).
  List<HorizontalRangeAnnotation> _zoneBands(
    BuildContext context,
    ZoneBounds b,
    double minY,
    double maxY,
  ) {
    final bands = <HorizontalRangeAnnotation>[];
    Color c(Zone z) => z.softColorOf(context);
    if (b.greenLow != null || b.greenHigh != null) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: b.greenLow ?? minY,
          y2: b.greenHigh ?? maxY,
          color: c(Zone.green),
        ),
      );
    }
    if (b.amberLow != null && b.greenLow != null) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: b.amberLow!,
          y2: b.greenLow!,
          color: c(Zone.amber),
        ),
      );
    }
    if (b.amberHigh != null && b.greenHigh != null) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: b.greenHigh!,
          y2: b.amberHigh!,
          color: c(Zone.amber),
        ),
      );
    }
    if (b.amberLow != null) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: minY,
          y2: b.amberLow!,
          color: c(Zone.red),
        ),
      );
    }
    if (b.amberHigh != null) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: b.amberHigh!,
          y2: maxY,
          color: c(Zone.red),
        ),
      );
    }
    return bands;
  }
}
