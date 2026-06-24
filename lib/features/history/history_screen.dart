import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_chip.dart';
import '../water_change/water_change_markers.dart';

enum _Range {
  week('7d', 7),
  month('30d', 30),
  quarter('90d', 90),
  all('All', null);

  const _Range(this.label, this.days);
  final String label;
  final int? days;
}

String _rangeLabel(AppLocalizations l, _Range r) {
  switch (r) {
    case _Range.week:
      return l.rangeWeek;
    case _Range.month:
      return l.rangeMonth;
    case _Range.quarter:
      return l.rangeQuarter;
    case _Range.all:
      return l.rangeAll;
  }
}

/// Resolves a stored range label back to its [_Range], defaulting to month.
_Range _rangeFromLabel(String? label) {
  for (final r in _Range.values) {
    if (r.label == label) return r;
  }
  return _Range.month;
}

/// Time-series history + readings list for one parameter of the active tank.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.paramKey});

  final String paramKey;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final range = _rangeFromLabel(ref.watch(chartRangeProvider).value);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final TrackedParameter? param = tracked
        .where((t) => t.paramKey == widget.paramKey)
        .cast<TrackedParameter?>()
        .firstWhere((t) => true, orElse: () => null);
    final readingsAsync = ref.watch(paramReadingsProvider(widget.paramKey));
    final waterChanges = ref.watch(waterChangesProvider).value ?? const [];
    final prefs = ref.watch(unitPrefsProvider);
    final pres = param != null
        ? presentationOf(param, prefs)
        : presentationForKey(
            widget.paramKey, kParameterByKey[widget.paramKey]?.unit ?? '',
            prefs);

    return Scaffold(
      appBar: AppBar(title: Text(l.paramName(widget.paramKey))),
      body: readingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (all) {
          final cutoff = range.days == null
              ? null
              : DateTime.now().subtract(Duration(days: range.days!));
          final data = cutoff == null
              ? all
              : all.where((r) => r.takenAt.isAfter(cutoff)).toList();

          return Column(
            children: [
              _rangeSelector(range),
              Expanded(
                child: data.isEmpty
                    ? Center(child: Text(l.noReadingsInRange))
                    : ListView(
                        children: [
                          SizedBox(
                            height: 280,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                              child: _Chart(
                                  readings: data,
                                  param: param,
                                  pres: pres,
                                  waterChanges: waterChanges),
                            ),
                          ),
                          const Divider(),
                          ..._readingsList(context, data, param, pres),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rangeSelector(_Range range) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SegmentedButton<_Range>(
        segments: [
          for (final r in _Range.values)
            ButtonSegment(value: r, label: Text(_rangeLabel(l, r))),
        ],
        selected: {range},
        // Persist the choice so it carries over to every graph and session.
        onSelectionChanged: (s) =>
            ref.read(dbProvider).setSetting(kChartRangeKey, s.first.label),
      ),
    );
  }

  List<Widget> _readingsList(BuildContext context, List<Reading> data,
      TrackedParameter? param, ParamPresentation pres) {
    final bounds = param != null ? boundsOf(param) : const ZoneBounds();
    final reversed = data.reversed.toList(); // newest first
    return [
      for (final r in reversed)
        Dismissible(
          key: ValueKey(r.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(context, r),
          child: ListTile(
            leading: ZoneChip(bounds.classify(r.value), compact: true),
            title: Text('${pres.format(r.value)} ${pres.unitLabel}'),
            subtitle: Text(
              DateFormat.yMMMEd().add_jm().format(r.takenAt) +
                  (r.note != null ? '\n${r.note}' : ''),
            ),
            isThreeLine: r.note != null,
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editReading(context, r, pres),
            ),
          ),
        ),
    ];
  }

  Future<void> _editReading(
      BuildContext context, Reading r, ParamPresentation pres) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: pres.format(r.value));
    final newValue = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editValue),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(suffixText: pres.unitLabel),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v == null ? null : pres.toCanonical(v));
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (newValue != null) {
      await ref.read(dbProvider).updateReading(r.copyWith(value: newValue));
    }
  }

  /// Handles a swipe-to-delete. When the reading was saved together with other
  /// measurements (same timestamp), asks whether to delete just this value or
  /// the whole batch. Returns true if the swiped row should be dismissed.
  Future<bool> _confirmDelete(BuildContext context, Reading r) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return false;

    final siblings = await db.readingsAt(tank.id, r.takenAt);
    final others = siblings.length - 1;
    if (!context.mounted) return false;

    if (others <= 0) {
      // A standalone measurement: simple confirmation.
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteMeasurementTitle),
          content: Text(l.deleteMeasurementBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.delete)),
          ],
        ),
      );
      if (ok == true) {
        await db.deleteReading(r.id);
        return true;
      }
      return false;
    }

    // Saved together with other measurements: offer a choice.
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTogetherTitle),
        content: Text(l.deleteTogetherBody(others)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.cancel),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.one),
              child: Text(l.deleteOnlyThis)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.all),
              child: Text(l.deleteAllTogether)),
        ],
      ),
    );
    switch (choice) {
      case _DeleteChoice.one:
        await db.deleteReading(r.id);
        return true;
      case _DeleteChoice.all:
        await db.deleteReadingsAt(tank.id, r.takenAt);
        return true;
      case _DeleteChoice.cancel:
      case null:
        return false;
    }
  }
}

enum _DeleteChoice { one, all, cancel }

class _Chart extends StatelessWidget {
  const _Chart(
      {required this.readings,
      required this.param,
      required this.pres,
      required this.waterChanges});

  final List<Reading> readings;
  final TrackedParameter? param;
  final ParamPresentation pres;
  final List<WaterChange> waterChanges;

  @override
  Widget build(BuildContext context) {
    // Plot everything in the user's display unit.
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
    for (final b in [bounds.amberLow, bounds.greenLow, bounds.greenHigh, bounds.amberHigh]) {
      if (b != null) {
        minY = b < minY ? b : minY;
        maxY = b > maxY ? b : maxY;
      }
    }
    final pad = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    final isSingle = spots.length == 1;
    final double minX;
    final double maxX;
    if (isSingle) {
      // Center a lone measurement instead of pinning it to the left edge.
      const halfWindowMs = 12 * 60 * 60 * 1000; // 12h either side
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
        extraLinesData: ExtraLinesData(
          verticalLines: waterChangeLines(
            changes: waterChanges,
            minX: minX,
            maxX: maxX,
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
              showTitles: true,
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
                  final atEdge =
                      (v - minX).abs() < 1 || (maxX - v).abs() < 1;
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

  List<HorizontalRangeAnnotation> _zoneBands(
      ZoneBounds b, double minY, double maxY) {
    final bands = <HorizontalRangeAnnotation>[];
    Color c(Zone z) => z.color.withValues(alpha: 0.10);
    // Green band.
    if (b.greenLow != null || b.greenHigh != null) {
      bands.add(HorizontalRangeAnnotation(
        y1: b.greenLow ?? minY,
        y2: b.greenHigh ?? maxY,
        color: c(Zone.green),
      ));
    }
    // Amber bands (between amber and green bounds).
    if (b.amberLow != null && b.greenLow != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.amberLow!, y2: b.greenLow!, color: c(Zone.amber)));
    }
    if (b.amberHigh != null && b.greenHigh != null) {
      bands.add(HorizontalRangeAnnotation(
          y1: b.greenHigh!, y2: b.amberHigh!, color: c(Zone.amber)));
    }
    // Red bands (beyond amber bounds).
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
