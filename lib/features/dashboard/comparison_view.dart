import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/zone_visuals.dart';

/// Stacked-graph comparison view for the Measurements tab. Renders one compact
/// line chart per enabled tracked parameter — in the same `displayOrder` as the
/// dashboard grid — with all charts pinned to a single, shared time window so
/// their X axes align. Reading a vertical time-slice across the stack reveals
/// how parameters move together. Tapping a chart opens its history screen.
class ComparisonBody extends ConsumerWidget {
  const ComparisonBody({super.key});

  /// Height of each parameter's chart area (excluding its header).
  static const double _chartHeight = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trackedAsync = ref.watch(trackedParametersProvider);
    final readingsAsync = ref.watch(tankReadingsProvider);

    return trackedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
      data: (tracked) {
        final readings = readingsAsync.value ?? const <Reading>[];
        final prefs = ref.watch(unitPrefsProvider);
        final waterChanges = ref.watch(waterChangesProvider).value ?? const [];
        final range = chartRangeFromLabel(ref.watch(chartRangeProvider).value);

        // Enabled params in dashboard order.
        final params = tracked.where((t) => t.enabled).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        if (params.isEmpty) return Center(child: Text(l.noParamsTracked));

        // Group readings (already newest-first) per parameter.
        final byParam = <String, List<Reading>>{};
        for (final r in readings) {
          (byParam[r.paramKey] ??= []).add(r);
        }

        // One shared time window for every chart so the X axes align. The end
        // is "now"; the start is the range cutoff, or — for "All" — the oldest
        // reading across all enabled params (falling back to 30 days).
        final now = DateTime.now();
        final cutoff =
            range.days == null ? null : now.subtract(Duration(days: range.days!));
        DateTime windowStart;
        if (cutoff != null) {
          windowStart = cutoff;
        } else {
          DateTime? oldest;
          for (final p in params) {
            final list = byParam[p.paramKey];
            if (list == null || list.isEmpty) continue;
            final t = list.last.takenAt; // newest-first → last is oldest
            if (oldest == null || t.isBefore(oldest)) oldest = t;
          }
          windowStart = oldest ?? now.subtract(const Duration(days: 30));
        }
        final minX = windowStart.millisecondsSinceEpoch.toDouble();
        final maxX = now.millisecondsSinceEpoch.toDouble();

        return Column(
          children: [
            const ChartRangeSelector(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 16),
                itemCount: params.length,
                itemBuilder: (context, i) {
                  final param = params[i];
                  final history = byParam[param.paramKey] ?? const [];
                  // Oldest→newest for the chart (fl_chart expects ascending X).
                  final inRange = [
                    for (final r in history.reversed)
                      if (cutoff == null || r.takenAt.isAfter(cutoff)) r,
                  ];
                  // Only the last chart draws date labels; alignment is governed
                  // by the fixed left-axis width, so the others can omit them.
                  final isLast = i == params.length - 1;
                  return _ParamChartCard(
                    param: param,
                    inRange: inRange,
                    prefs: prefs,
                    waterChanges: waterChanges,
                    minX: minX,
                    maxX: maxX,
                    showBottomTitles: isLast,
                    chartHeight: _chartHeight,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single parameter's header (name + zone-colored latest in-range value) above
/// its aligned trend chart, or a muted placeholder when it has no data in range.
class _ParamChartCard extends StatelessWidget {
  const _ParamChartCard({
    required this.param,
    required this.inRange,
    required this.prefs,
    required this.waterChanges,
    required this.minX,
    required this.maxX,
    required this.showBottomTitles,
    required this.chartHeight,
  });

  final TrackedParameter param;
  final List<Reading> inRange;
  final UnitPrefs prefs;
  final List<WaterChange> waterChanges;
  final double minX;
  final double maxX;
  final bool showBottomTitles;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pres = presentationOf(param, prefs);
    final bounds = boundsOf(param);
    // Header value tracks the chart: the newest reading *in range* (inRange is
    // ascending), not the newest overall — otherwise a zone-colored value would
    // sit above a "No readings in range" chart and imply in-range data (#22).
    final latest = inRange.isNotEmpty ? inRange.last : null;
    final zone = latest != null ? bounds.classify(latest.value) : Zone.unknown;
    final hint = Theme.of(context).hintColor;

    return InkWell(
      onTap: () => context.push('/history/${param.paramKey}'),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.paramName(param.paramKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (latest != null) ...[
                    Text(
                      pres.format(latest.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: zone.color,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(pres.unitLabel,
                        style: TextStyle(fontSize: 12, color: hint)),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: chartHeight,
              child: inRange.isEmpty
                  ? Center(
                      child: Text(l.noReadingsInRange,
                          style: TextStyle(fontSize: 12, color: hint)),
                    )
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, 8, 12, showBottomTitles ? 4 : 8),
                      child: TrendChart(
                        readings: inRange,
                        param: param,
                        pres: pres,
                        waterChanges: waterChanges,
                        minX: minX,
                        maxX: maxX,
                        showBottomTitles: showBottomTitles,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
