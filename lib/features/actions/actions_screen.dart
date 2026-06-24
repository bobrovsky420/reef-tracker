import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Combined log of tank actions (water changes and activated-carbon changes)
/// for the active tank, newest first, with add/edit/delete.
class ActionsScreen extends ConsumerWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final water = ref.watch(waterChangesProvider).value ?? const [];
    final carbon = ref.watch(carbonChangesProvider).value ?? const [];
    final unit = ref.watch(unitPrefsProvider).volume;
    final hasTank = ref.watch(activeTankProvider) != null;

    final entries = <_Entry>[
      ...water.map(_WaterEntry.new),
      ...carbon.map(_CarbonEntry.new),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      appBar: AppBar(title: Text(l.actions)),
      body: entries.isEmpty
          ? Center(child: Text(l.noActions))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) =>
                  _tile(context, ref, l, entries[i], unit),
            ),
      floatingActionButton: hasTank
          ? FloatingActionButton.extended(
              onPressed: () => _chooseAndAdd(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.addAction),
            )
          : null,
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AppLocalizations l,
      _Entry e, VolumeUnit unit) {
    final IconData icon;
    final String title;
    final String value;
    final String? note;
    switch (e) {
      case _WaterEntry(:final data):
        icon = Icons.water_drop_outlined;
        title = l.waterChange;
        value = data.amountLiters != null
            ? l.volumeWithUnit(data.amountLiters!, unit)
            : l.amountNotRecorded;
        note = data.note;
      case _CarbonEntry(:final data):
        icon = Icons.grain;
        title = l.carbonChange;
        value = data.grams != null
            ? l.gramsSuffix(_formatGrams(data.grams!))
            : l.weightNotRecorded;
        note = data.note;
    }
    final hasNote = note != null && note.isNotEmpty;
    final date = DateFormat.yMMMEd().add_jm().format(e.time);

    return Dismissible(
      key: ValueKey(e.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref, l, e),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$value • $date${hasNote ? '\n$note' : ''}'),
        isThreeLine: hasNote,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _edit(context, ref, e),
        ),
      ),
    );
  }

  Future<void> _chooseAndAdd(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final kind = await showModalBottomSheet<_Kind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: Text(l.recordWaterChange),
              onTap: () => Navigator.pop(ctx, _Kind.water),
            ),
            ListTile(
              leading: const Icon(Icons.grain),
              title: Text(l.recordCarbonChange),
              onTap: () => Navigator.pop(ctx, _Kind.carbon),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    switch (kind) {
      case _Kind.water:
        await _editWater(context, ref, null);
      case _Kind.carbon:
        await _editCarbon(context, ref, null);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, _Entry e) {
    switch (e) {
      case _WaterEntry(:final data):
        return _editWater(context, ref, data);
      case _CarbonEntry(:final data):
        return _editCarbon(context, ref, data);
    }
  }

  Future<void> _editWater(
      BuildContext context, WidgetRef ref, WaterChange? existing) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final l = AppLocalizations.of(context);
    final unit = ref.read(unitPrefsProvider).volume;
    final result = await showDialog<_ActionResult>(
      context: context,
      builder: (ctx) => _ActionDialog(
        title: l.recordWaterChange,
        valueLabel: l.amountLitersOptional,
        valueSuffix: unit.symbol,
        initialTime: existing?.changedAt ?? DateTime.now(),
        initialValue: existing?.amountLiters == null
            ? ''
            : formatVolume(existing!.amountLiters!, unit),
        initialNote: existing?.note,
      ),
    );
    if (result == null) return;
    final amount =
        result.value == null ? null : volumeToCanonical(result.value!, unit);
    final db = ref.read(dbProvider);
    if (existing == null) {
      await db.insertWaterChange(
        tankId: tank.id,
        changedAt: result.time,
        amountLiters: amount,
        note: result.note,
      );
    } else {
      await db.updateWaterChange(existing.copyWith(
        changedAt: result.time,
        amountLiters: Value(amount),
        note: Value(result.note),
      ));
    }
  }

  Future<void> _editCarbon(
      BuildContext context, WidgetRef ref, CarbonChange? existing) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final l = AppLocalizations.of(context);
    final result = await showDialog<_ActionResult>(
      context: context,
      builder: (ctx) => _ActionDialog(
        title: l.recordCarbonChange,
        valueLabel: l.weightOptional,
        valueSuffix: 'g',
        initialTime: existing?.changedAt ?? DateTime.now(),
        initialValue:
            existing?.grams == null ? '' : _formatGrams(existing!.grams!),
        initialNote: existing?.note,
      ),
    );
    if (result == null) return;
    final db = ref.read(dbProvider);
    if (existing == null) {
      await db.insertCarbonChange(
        tankId: tank.id,
        changedAt: result.time,
        grams: result.value,
        note: result.note,
      );
    } else {
      await db.updateCarbonChange(existing.copyWith(
        changedAt: result.time,
        grams: Value(result.value),
        note: Value(result.note),
      ));
    }
  }

  Future<bool> _confirmDelete(
      BuildContext context, WidgetRef ref, AppLocalizations l, _Entry e) async {
    final (String titleText, String bodyText) = switch (e) {
      _WaterEntry() => (l.deleteWaterChangeTitle, l.deleteWaterChangeBody),
      _CarbonEntry() => (l.deleteCarbonChangeTitle, l.deleteCarbonChangeBody),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titleText),
        content: Text(bodyText),
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
    if (ok != true) return false;
    final db = ref.read(dbProvider);
    switch (e) {
      case _WaterEntry(:final data):
        await db.deleteWaterChange(data.id);
      case _CarbonEntry(:final data):
        await db.deleteCarbonChange(data.id);
    }
    return true;
  }
}

String _formatGrams(double g) =>
    g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1);

enum _Kind { water, carbon }

sealed class _Entry {
  DateTime get time;
  String get key;
}

class _WaterEntry extends _Entry {
  _WaterEntry(this.data);
  final WaterChange data;
  @override
  DateTime get time => data.changedAt;
  @override
  String get key => 'w${data.id}';
}

class _CarbonEntry extends _Entry {
  _CarbonEntry(this.data);
  final CarbonChange data;
  @override
  DateTime get time => data.changedAt;
  @override
  String get key => 'c${data.id}';
}

class _ActionResult {
  const _ActionResult(this.time, this.value, this.note);
  final DateTime time;
  final double? value;
  final String? note;
}

/// Date/time + optional numeric value + optional note entry, shared by the
/// water-change and carbon-change flows.
class _ActionDialog extends StatefulWidget {
  const _ActionDialog({
    required this.title,
    required this.valueLabel,
    required this.valueSuffix,
    required this.initialTime,
    required this.initialValue,
    required this.initialNote,
  });

  final String title;
  final String valueLabel;
  final String valueSuffix;
  final DateTime initialTime;
  final String initialValue;
  final String? initialNote;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  late DateTime _time = widget.initialTime;
  late final TextEditingController _valueCtrl =
      TextEditingController(text: widget.initialValue);
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
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
      _time = DateTime(date.year, date.month, date.day, picked?.hour ?? 0,
          picked?.minute ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l.changedAt),
            subtitle: Text(DateFormat.yMMMEd().add_jm().format(_time)),
            trailing: TextButton(
              onPressed: _pickDateTime,
              child: Text(l.change),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.valueLabel,
              suffixText: widget.valueSuffix,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: l.noteOptional,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final text = _valueCtrl.text.trim().replaceAll(',', '.');
            final value = text.isEmpty ? null : double.tryParse(text);
            final note = _noteCtrl.text.trim();
            Navigator.pop(context,
                _ActionResult(_time, value, note.isEmpty ? null : note));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
