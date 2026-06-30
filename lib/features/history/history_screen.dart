import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/trend_view.dart';
import '../../widgets/zone_chip.dart';

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
    final range = chartRangeFromLabel(ref.watch(chartRangeProvider).value);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final TrackedParameter? param = tracked
        .where((t) => t.paramKey == widget.paramKey)
        .cast<TrackedParameter?>()
        .firstWhere((t) => true, orElse: () => null);
    final readingsAsync = ref.watch(paramReadingsProvider(widget.paramKey));
    final trend = ref.watch(tankTrendsProvider)[widget.paramKey];
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
              const ChartRangeSelector(),
              Expanded(
                child: data.isEmpty
                    ? Center(child: Text(l.noReadingsInRange))
                    : ListView(
                        children: [
                          SizedBox(
                            height: 280,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                              child: TrendChart(
                                  readings: data,
                                  param: param,
                                  pres: pres,
                                  waterChanges: waterChanges),
                            ),
                          ),
                          if (trend != null) ...[
                            const Divider(),
                            TrendCard(trend: trend, pres: pres),
                          ],
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
              formatDateTime(context, r.takenAt) +
                  (r.note != null ? '\n${r.note}' : ''),
            ),
            isThreeLine: r.note != null,
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
            onTap: () => _editReading(context, r, pres),
          ),
        ),
    ];
  }

  /// Edits a reading's value and/or its date/time. When the timestamp is moved
  /// and the reading was saved together with others (same moment), asks whether
  /// to re-time just this value or the whole batch — mirroring delete's choice.
  Future<void> _editReading(
      BuildContext context, Reading r, ParamPresentation pres) async {
    final db = ref.read(dbProvider);
    final tank = ref.read(activeTankProvider);
    final edit = await showDialog<_ReadingEdit>(
      context: context,
      builder: (ctx) => _ReadingDialog(
        pres: pres,
        initialValue: r.value,
        initialTime: r.takenAt,
      ),
    );
    if (edit == null) return;

    final timeChanged = !edit.time.isAtSameMomentAs(r.takenAt);
    bool applyTimeToAll = false;
    if (timeChanged && tank != null) {
      final siblings = await db.readingsAt(tank.id, r.takenAt);
      final others = siblings.length - 1;
      if (others > 0) {
        if (!context.mounted) return;
        final choice = await _askEditScope(context, others);
        switch (choice) {
          case _EditChoice.one:
            applyTimeToAll = false;
          case _EditChoice.all:
            applyTimeToAll = true;
          case _EditChoice.cancel:
          case null:
            return;
        }
      }
    }

    if (applyTimeToAll) {
      await db.updateReadingsTimeAt(tank!.id, r.takenAt, edit.time);
    }
    await db.updateReading(r.copyWith(value: edit.value, takenAt: edit.time));
  }

  /// Asks whether a re-timing should affect only this reading or all [others]+1
  /// readings entered together at the same moment.
  Future<_EditChoice?> _askEditScope(BuildContext context, int others) {
    final l = AppLocalizations.of(context);
    return showDialog<_EditChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editTogetherTitle),
        content: Text(l.editTogetherBody(others)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, _EditChoice.cancel),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _EditChoice.one),
              child: Text(l.deleteOnlyThis)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _EditChoice.all),
              child: Text(l.deleteAllTogether)),
        ],
      ),
    );
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

enum _EditChoice { one, all, cancel }

/// Result of [_ReadingDialog]: the edited canonical value and timestamp.
class _ReadingEdit {
  const _ReadingEdit(this.time, this.value);
  final DateTime time;
  final double value;
}

/// Edits one reading's value (in the user's display unit) and its date/time.
/// The date/time picker mirrors the actions log's `_ActionDialog`.
class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    required this.pres,
    required this.initialValue,
    required this.initialTime,
  });

  final ParamPresentation pres;

  /// Canonical value to seed the field (shown converted to the display unit).
  final double initialValue;
  final DateTime initialTime;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  late DateTime _time = widget.initialTime;
  late final TextEditingController _valueCtrl =
      TextEditingController(text: widget.pres.format(widget.initialValue));

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (!mounted) return;
    setState(() {
      _time = DateTime(
        date.year,
        date.month,
        date.day,
        picked?.hour ?? 0,
        picked?.minute ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.editMeasurement),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formatDateTime(context, _time, weekday: false),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l.change,
                onPressed: _pickDateTime,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: InputDecoration(
              suffixText: widget.pres.unitLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final v = parseUserDouble(_valueCtrl.text);
            // Keep the original value if the field is empty or unparseable.
            final canonical = v == null
                ? widget.initialValue
                : widget.pres.toCanonical(v);
            Navigator.pop(context, _ReadingEdit(_time, canonical));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
