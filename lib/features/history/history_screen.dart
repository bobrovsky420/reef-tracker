import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../widgets/zone_chip.dart';

enum _Range {
  week('7d', 7),
  month('30d', 30),
  quarter('90d', 90),
  all('All', null);

  const _Range(this.label, this.days);
  final String label;
  final int? days;
}

/// Time-series history + readings list for one parameter of the active tank.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.paramKey});

  final String paramKey;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final def = kParameterByKey[widget.paramKey];
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final TrackedParameter? param = tracked
        .where((t) => t.paramKey == widget.paramKey)
        .cast<TrackedParameter?>()
        .firstWhere((t) => true, orElse: () => null);
    final readingsAsync = ref.watch(paramReadingsProvider(widget.paramKey));
    final prefs = ref.watch(unitPrefsProvider);
    final pres = param != null
        ? presentationOf(param, prefs)
        : presentationForKey(
            widget.paramKey, kParameterByKey[widget.paramKey]?.unit ?? '',
            prefs);

    return Scaffold(
      appBar: AppBar(title: Text(def?.name ?? widget.paramKey)),
      body: readingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final cutoff = _range.days == null
              ? null
              : DateTime.now().subtract(Duration(days: _range.days!));
          final data = cutoff == null
              ? all
              : all.where((r) => r.takenAt.isAfter(cutoff)).toList();

          return Column(
            children: [
              _rangeSelector(),
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text('No readings in this range.'))
                    : ListView(
                        children: [
                          SizedBox(
                            height: 280,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                              child: _Chart(
                                  readings: data, param: param, pres: pres),
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

  Widget _rangeSelector() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SegmentedButton<_Range>(
        segments: [
          for (final r in _Range.values)
            ButtonSegment(value: r, label: Text(r.label)),
        ],
        selected: {_range},
        onSelectionChanged: (s) => setState(() => _range = s.first),
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
          confirmDismiss: (_) async {
            await ref.read(dbProvider).deleteReading(r.id);
            return true;
          },
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
    final ctrl = TextEditingController(text: pres.format(r.value));
    final newValue = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit value'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(suffixText: pres.unitLabel),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v == null ? null : pres.toCanonical(v));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newValue != null) {
      await ref.read(dbProvider).updateReading(r.copyWith(value: newValue));
    }
  }
}

class _Chart extends StatelessWidget {
  const _Chart(
      {required this.readings, required this.param, required this.pres});

  final List<Reading> readings;
  final TrackedParameter? param;
  final ParamPresentation pres;

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

    final minX = spots.first.x;
    final maxX = spots.last.x;
    final spanMs = (maxX - minX).abs();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: minX,
        maxX: maxX == minX ? minX + 1 : maxX,
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
              interval: maxX == minX ? null : spanMs / 3,
              getTitlesWidget: (v, meta) {
                final d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
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
