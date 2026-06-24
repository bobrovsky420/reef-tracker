import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Lists the active tank's water changes and lets the user add, edit, or
/// delete them.
class WaterChangeScreen extends ConsumerWidget {
  const WaterChangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final changesAsync = ref.watch(waterChangesProvider);
    final hasTank = ref.watch(activeTankProvider) != null;
    final unit = ref.watch(unitPrefsProvider).volume;

    return Scaffold(
      appBar: AppBar(title: Text(l.waterChanges)),
      body: changesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (changes) {
          if (changes.isEmpty) {
            return Center(child: Text(l.noWaterChanges));
          }
          return ListView(
            children: [
              for (final c in changes) _tile(context, ref, l, c, unit),
            ],
          );
        },
      ),
      floatingActionButton: hasTank
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.recordWaterChange),
            )
          : null,
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AppLocalizations l,
      WaterChange c, VolumeUnit unit) {
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref, l, c),
      child: ListTile(
        leading: const Icon(Icons.water_drop_outlined),
        title: Text(c.amountLiters != null
            ? l.volumeWithUnit(c.amountLiters!, unit)
            : l.amountNotRecorded),
        subtitle: Text(DateFormat.yMMMEd().add_jm().format(c.changedAt)),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _edit(context, ref, existing: c),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref,
      AppLocalizations l, WaterChange c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteWaterChangeTitle),
        content: Text(l.deleteWaterChangeBody),
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
      await ref.read(dbProvider).deleteWaterChange(c.id);
      return true;
    }
    return false;
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {WaterChange? existing}) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final unit = ref.read(unitPrefsProvider).volume;
    final result = await showDialog<_WaterChangeResult>(
      context: context,
      builder: (ctx) => _WaterChangeDialog(existing: existing, unit: unit),
    );
    if (result == null) return;
    final db = ref.read(dbProvider);
    if (existing == null) {
      await db.insertWaterChange(
        tankId: tank.id,
        changedAt: result.changedAt,
        amountLiters: result.amountLiters,
      );
    } else {
      await db.updateWaterChange(existing.copyWith(
        changedAt: result.changedAt,
        amountLiters: Value(result.amountLiters),
      ));
    }
  }
}

class _WaterChangeResult {
  const _WaterChangeResult(this.changedAt, this.amountLiters);
  final DateTime changedAt;
  final double? amountLiters;
}

/// Date/time + optional litres entry for a water change.
class _WaterChangeDialog extends StatefulWidget {
  const _WaterChangeDialog({this.existing, required this.unit});

  final WaterChange? existing;
  final VolumeUnit unit;

  @override
  State<_WaterChangeDialog> createState() => _WaterChangeDialogState();
}

class _WaterChangeDialogState extends State<_WaterChangeDialog> {
  late DateTime _changedAt;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _changedAt = widget.existing?.changedAt ?? DateTime.now();
    final amount = widget.existing?.amountLiters;
    _amountCtrl = TextEditingController(
        text: amount == null ? '' : formatVolume(amount, widget.unit));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _changedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_changedAt),
    );
    if (!mounted) return;
    setState(() {
      _changedAt = DateTime(date.year, date.month, date.day, time?.hour ?? 0,
          time?.minute ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.recordWaterChange),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l.changedAt),
            subtitle: Text(DateFormat.yMMMEd().add_jm().format(_changedAt)),
            trailing: TextButton(
              onPressed: _pickDateTime,
              child: Text(l.change),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.amountLitersOptional,
              suffixText: widget.unit.symbol,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final text = _amountCtrl.text.trim().replaceAll(',', '.');
            final typed = text.isEmpty ? null : double.tryParse(text);
            final amount =
                typed == null ? null : volumeToCanonical(typed, widget.unit);
            Navigator.pop(context, _WaterChangeResult(_changedAt, amount));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
