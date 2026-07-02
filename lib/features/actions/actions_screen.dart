import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Combined log of tank actions (water changes and activated-carbon changes)
/// for the active tank, newest first, with edit/delete. Hosted by `HomeShell`,
/// which owns the surrounding `Scaffold`, app bar, bottom navigation and the
/// add-action FAB (see `showAddActionSheet`).
class ActionsBody extends ConsumerWidget {
  const ActionsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final water = ref.watch(waterChangesProvider).value ?? const [];
    final carbon = ref.watch(carbonChangesProvider).value ?? const [];
    final equipment = ref.watch(equipmentCleaningsProvider).value ?? const [];
    final unit = ref.watch(unitPrefsProvider).volume;

    final entries = <_Entry>[
      ...water.map(_WaterEntry.new),
      ...carbon.map(_CarbonEntry.new),
      ...equipment.map(_EquipmentEntry.new),
    ]..sort((a, b) => b.time.compareTo(a.time));

    if (entries.isEmpty) return Center(child: Text(l.noActions));
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) => _tile(context, ref, l, entries[i], unit),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    _Entry e,
    VolumeUnit unit,
  ) {
    final IconData icon;
    final String title;
    final String? value;
    final String? note;
    switch (e) {
      case _WaterEntry(:final data):
        icon = Icons.format_color_fill;
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
      case _EquipmentEntry(:final data):
        icon = Icons.cleaning_services_outlined;
        title = l.equipmentCleaning;
        value = null;
        note = data.note;
    }
    final hasNote = note != null && note.isNotEmpty;
    final date = formatDateTime(context, e.time);
    final subtitle = value == null ? date : '$value • $date';

    return Dismissible(
      key: ValueKey(e.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _deleteWithUndo(context, ref, l, e),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$subtitle${hasNote ? '\n$note' : ''}'),
        isThreeLine: hasNote,
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.outline,
        ),
        onTap: () => _edit(context, ref, e),
      ),
    );
  }
}

/// Shows the add-action chooser sheet, then opens the editor for the chosen
/// action type. Driven by `HomeShell`'s FAB on the Actions tab.
Future<void> showAddActionSheet(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final kind = await showModalBottomSheet<_Kind>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.format_color_fill),
            title: Text(l.recordWaterChange),
            onTap: () => Navigator.pop(ctx, _Kind.water),
          ),
          ListTile(
            leading: const Icon(Icons.grain),
            title: Text(l.recordCarbonChange),
            onTap: () => Navigator.pop(ctx, _Kind.carbon),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l.recordEquipmentCleaning),
            onTap: () => Navigator.pop(ctx, _Kind.equipment),
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
    case _Kind.equipment:
      await _editEquipment(context, ref, null);
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, _Entry e) {
  switch (e) {
    case _WaterEntry(:final data):
      return _editWater(context, ref, data);
    case _CarbonEntry(:final data):
      return _editCarbon(context, ref, data);
    case _EquipmentEntry(:final data):
      return _editEquipment(context, ref, data);
  }
}

Future<void> _editWater(
  BuildContext context,
  WidgetRef ref,
  WaterChange? existing,
) async {
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
  final amount = result.value == null
      ? null
      : volumeToCanonical(result.value!, unit);
  final db = ref.read(dbProvider);
  if (existing == null) {
    await db.insertWaterChange(
      tankId: tank.id,
      changedAt: result.time,
      amountLiters: amount,
      note: result.note,
    );
  } else {
    await db.updateWaterChange(
      existing.copyWith(
        changedAt: result.time,
        amountLiters: Value(amount),
        note: Value(result.note),
      ),
    );
  }
}

Future<void> _editCarbon(
  BuildContext context,
  WidgetRef ref,
  CarbonChange? existing,
) async {
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
      initialValue: existing?.grams == null
          ? ''
          : _formatGrams(existing!.grams!),
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
    await db.updateCarbonChange(
      existing.copyWith(
        changedAt: result.time,
        grams: Value(result.value),
        note: Value(result.note),
      ),
    );
  }
}

Future<void> _editEquipment(
  BuildContext context,
  WidgetRef ref,
  EquipmentCleaning? existing,
) async {
  final tank = ref.read(activeTankProvider);
  if (tank == null) return;
  final l = AppLocalizations.of(context);
  final result = await showDialog<_ActionResult>(
    context: context,
    builder: (ctx) => _ActionDialog(
      title: l.recordEquipmentCleaning,
      initialTime: existing?.cleanedAt ?? DateTime.now(),
      initialNote: existing?.note,
    ),
  );
  if (result == null) return;
  final db = ref.read(dbProvider);
  if (existing == null) {
    await db.insertEquipmentCleaning(
      tankId: tank.id,
      cleanedAt: result.time,
      note: result.note,
    );
  } else {
    await db.updateEquipmentCleaning(
      existing.copyWith(cleanedAt: result.time, note: Value(result.note)),
    );
  }
}

/// Deletes the swiped action immediately and offers an "Undo" SnackBar that
/// re-inserts it, replacing the old confirm dialog (faster for the common case
/// and safe against accidental swipes).
Future<bool> _deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  _Entry e,
) async {
  final db = ref.read(dbProvider);
  switch (e) {
    case _WaterEntry(:final data):
      await db.deleteWaterChange(data.id);
    case _CarbonEntry(:final data):
      await db.deleteCarbonChange(data.id);
    case _EquipmentEntry(:final data):
      await db.deleteEquipmentCleaning(data.id);
  }
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.itemDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            switch (e) {
              case _WaterEntry(:final data):
                await db.insertWaterChange(
                  tankId: data.tankId,
                  changedAt: data.changedAt,
                  amountLiters: data.amountLiters,
                  note: data.note,
                );
              case _CarbonEntry(:final data):
                await db.insertCarbonChange(
                  tankId: data.tankId,
                  changedAt: data.changedAt,
                  grams: data.grams,
                  note: data.note,
                );
              case _EquipmentEntry(:final data):
                await db.insertEquipmentCleaning(
                  tankId: data.tankId,
                  cleanedAt: data.cleanedAt,
                  note: data.note,
                );
            }
          },
        ),
      ),
    );
  return true;
}

String _formatGrams(double g) =>
    g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1);

enum _Kind { water, carbon, equipment }

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

class _EquipmentEntry extends _Entry {
  _EquipmentEntry(this.data);
  final EquipmentCleaning data;
  @override
  DateTime get time => data.cleanedAt;
  @override
  String get key => 'e${data.id}';
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
    this.valueLabel,
    this.valueSuffix,
    required this.initialTime,
    this.initialValue = '',
    required this.initialNote,
  });

  final String title;

  /// Label for the optional numeric value field. When null the value field is
  /// hidden entirely (e.g. equipment cleaning records only a date + note).
  final String? valueLabel;
  final String? valueSuffix;
  final DateTime initialTime;
  final String initialValue;
  final String? initialNote;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _time = widget.initialTime;
  late final TextEditingController _valueCtrl = TextEditingController(
    text: widget.initialValue,
  );
  late final TextEditingController _noteCtrl = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickPastDateTime(context, _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
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
            if (widget.valueLabel != null) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.valueLabel,
                  suffixText: widget.valueSuffix,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  // Optional field: blank means "amount not recorded", but a
                  // non-empty entry must be a positive number (#7).
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = parseUserDouble(v);
                  return (parsed == null || parsed <= 0)
                      ? l.invalidPositiveNumber
                      : null;
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              autofocus: widget.valueLabel == null,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final value = parseUserDouble(_valueCtrl.text);
            final note = _noteCtrl.text.trim();
            Navigator.pop(
              context,
              _ActionResult(_time, value, note.isEmpty ? null : note),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
