import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/ratio.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
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
    final denominatorAsync =
        ref.watch(paramReadingsProvider(kind.denominatorKey));
    final bounds =
        ratioBounds(kind, ref.watch(ratioSettingsProvider).value?[kind.name]);

    return Scaffold(
      appBar: AppBar(title: Text(l.ratioScreenTitle(kind))),
      body: (numeratorAsync.isLoading || denominatorAsync.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
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
                    padding: const EdgeInsets.all(8),
                    child: SegmentedButton<String>(
                      segments: [
                        for (final r in _ranges)
                          ButtonSegment(
                              value: r.$1, label: Text(_rangeLabel(l, r.$1))),
                      ],
                      selected: {rangeKey},
                      onSelectionChanged: (s) => ref
                          .read(settingsProvider)
                          .setChartRange(s.first),
                    ),
                  ),
                  Expanded(
                    child: data.isEmpty
                        ? Center(child: Text(l.ratioNoData))
                        : ListView(
                            children: [
                              SizedBox(
                                height: 280,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 16, 16, 8),
                                  child: _RatioChart(
                                      kind: kind,
                                      points: data,
                                      bounds: bounds),
                                ),
                              ),
                              const Divider(),
                              ..._pointsList(context, data),
                            ],
                          ),
                  ),
                ],
              );
            }),
    );
  }

  List<Widget> _pointsList(BuildContext context, List<RatioPoint> data) {
    final reversed = data.reversed.toList(); // newest first
    return [
      for (final p in reversed)
        ListTile(
          title: Text(formatRatioValue(kind, p.ratio)),
          subtitle: Text(ratioBreakdown(kind, p)),
          trailing: Text(
            DateFormat.yMMMEd().format(p.time),
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ),
    ];
  }
}

class _RatioChart extends StatelessWidget {
  const _RatioChart(
      {required this.kind, required this.points, required this.bounds});

  final RatioKind kind;
  final List<RatioPoint> points;
  final ZoneBounds bounds;

  @override
  Widget build(BuildContext context) {
    // Plot the value implied by the display form (e.g. the `N` of `1 : N`).
    final spots = [
      for (final p in points)
        if (ratioChartY(kind, p.ratio).isFinite)
          FlSpot(p.time.millisecondsSinceEpoch.toDouble(),
              ratioChartY(kind, p.ratio)),
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
      bounds.amberHigh
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
          horizontalRangeAnnotations: _zoneBands(bounds, minY, maxY),
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
              reservedSize: 48,
              getTitlesWidget: (v, meta) => Text(
                formatRatioN(v),
                style: const TextStyle(fontSize: 10),
              ),
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
                    isSingle ? spots.first.x.toInt() : v.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat.Md().format(d),
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

  /// Green/amber/red bands from the kind's recommended bounds (chart-Y space).
  List<HorizontalRangeAnnotation> _zoneBands(
      ZoneBounds b, double minY, double maxY) {
    final bands = <HorizontalRangeAnnotation>[];
    Color c(Zone z) => z.color.withValues(alpha: 0.10);
    if (b.greenLow != null || b.greenHigh != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.greenLow ?? minY, y2: b.greenHigh ?? maxY, color: c(Zone.green)));
    }
    if (b.amberLow != null && b.greenLow != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.amberLow!, y2: b.greenLow!, color: c(Zone.amber)));
    }
    if (b.amberHigh != null && b.greenHigh != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.greenHigh!, y2: b.amberHigh!, color: c(Zone.amber)));
    }
    if (b.amberLow != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: minY, y2: b.amberLow!, color: c(Zone.red)));
    }
    if (b.amberHigh != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.amberHigh!, y2: maxY, color: c(Zone.red)));
    }
    return bands;
  }
}
