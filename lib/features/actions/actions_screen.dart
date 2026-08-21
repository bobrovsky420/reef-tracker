import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/reminders.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_sheet.dart';
import '../../widgets/reef_value_row.dart';
import '../maintenance/maintenance_due_chips.dart';
import '../maintenance/maintenance_events.dart';
import '../ro/ro_summary_tile.dart';

/// Combined log of tank actions (water changes and activated-carbon changes)
/// for the active tank, newest first, with edit/delete. Hosted by `HomeShell`,
/// which owns the surrounding `Scaffold`, app bar, bottom navigation and the
/// add-action FAB (see `showAddActionSheet`).
///
/// Layout per REDESIGN #11: the RO summary card, the due chips, and the
/// history collapsed into one `ReefSliverCard` of hairline-divided rows — all
/// in a single scroll view (the mockup scrolls the whole tab, not just the
/// log).
class ActionsBody extends ConsumerWidget {
  const ActionsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final water = ref.watch(waterChangesProvider).value ?? const [];
    final carbon = ref.watch(carbonChangesProvider).value ?? const [];
    final equipment = ref.watch(equipmentCleaningsProvider).value ?? const [];
    final db = ref.read(dbProvider);
    final entries = maintenanceEventAdapters.adaptAll(
      <Object>[...water, ...carbon, ...equipment],
      MaintenanceEventContext(
        context: context,
        l: l,
        units: ref.watch(unitPrefsProvider),
      ),
      actionsFor: (record) => maintenancePersistenceActions(
        db,
        record,
      ).withEdit(() => _edit(context, ref, record)),
    );

    // The shared RO unit's summary (U16) and the maintenance due chips (U12)
    // sit above the log; logging the matching action (or Mark done) resets a
    // chip's timer.
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: RoSummaryTile()),
        SliverToBoxAdapter(
          child: MaintenanceDueChips(
            onTypedDue: (context, ref, type) =>
                showAddActionSheet(context, ref, preset: type),
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(l.noActions)),
          )
        else
          SliverPadding(
            // The bottom inset keeps the last row scrollable past the
            // translucent tab bar (`extendBody` — a CustomScrollView gets no
            // automatic MediaQuery inset).
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: ReefSliverCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) => _row(
                  context,
                  ref,
                  l,
                  entries[i],
                  isLast: i == entries.length - 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    MaintenanceEvent event, {
    required bool isLast,
  }) {
    final hasNote = event.note != null && event.note!.isNotEmpty;
    final date = formatDateTime(context, event.timestamp);
    final subtitle = event.summary.isEmpty ? date : '${event.summary} · $date';
    final tokens = ReefTokens.of(context);

    return Dismissible(
      key: ValueKey(event.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (_) => _deleteWithUndo(context, l, event),
      // The rows sit inside the sliver card, whose fill paints over the
      // scaffold Material — each row brings a transparent Material so its ink
      // ripples above the card.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: event.actions.edit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.surfaceBorder),
                    ),
                  ),
            child: Row(
              children: [
                Icon(event.icon, size: 18, color: tokens.textDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$subtitle${hasNote ? '\n${event.note}' : ''}',
                        style: TextStyle(fontSize: 12, color: tokens.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right, size: 15, color: tokens.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the add-action chooser sheet, then opens the editor for the chosen
/// action type. Driven by `HomeShell`'s FAB on the Actions tab.
Future<void> showAddActionSheet(
  BuildContext context,
  WidgetRef ref, {
  MaintenanceActionType? preset,
}) async {
  final l = AppLocalizations.of(context);
  // A due chip already names the action — skip the kind sheet (U12).
  if (preset != null) {
    switch (preset) {
      case MaintenanceActionType.waterChange:
        await showRecordWaterChangeDialog(context, ref);
      case MaintenanceActionType.carbonChange:
        await _editCarbon(context, ref, null);
      case MaintenanceActionType.equipmentCleaning:
        await _editEquipment(context, ref, null);
    }
    return;
  }
  final kind = await showModalBottomSheet<_Kind>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // No top inset — the sheet's drag handle already provides it.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: ReefSheetHeader(l.addAction),
          ),
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
      await showRecordWaterChangeDialog(context, ref);
    case _Kind.carbon:
      await _editCarbon(context, ref, null);
    case _Kind.equipment:
      await _editEquipment(context, ref, null);
  }
}

/// Opens the existing water-change editor, optionally seeded by a completed
/// calculator result. The row is still written only when the keeper presses
/// Save in the dialog.
Future<void> showRecordWaterChangeDialog(
  BuildContext context,
  WidgetRef ref, {
  double? amountLiters,
  String? note,
}) => _editWater(
  context,
  ref,
  null,
  initialAmountLiters: amountLiters,
  initialNote: note,
);

Future<void> _edit(BuildContext context, WidgetRef ref, Object record) {
  switch (record) {
    case final WaterChange change:
      return _editWater(context, ref, change);
    case final CarbonChange change:
      return _editCarbon(context, ref, change);
    case final EquipmentCleaning cleaning:
      return _editEquipment(context, ref, cleaning);
    default:
      return Future.value();
  }
}

Future<void> _editWater(
  BuildContext context,
  WidgetRef ref,
  WaterChange? existing, {
  double? initialAmountLiters,
  String? initialNote,
}) async {
  final tank = ref.read(activeTankProvider);
  if (tank == null) return;
  final l = AppLocalizations.of(context);
  final unit = ref.read(unitPrefsProvider).volume;
  final outcome = await showDialog<_ActionOutcome>(
    context: context,
    builder: (ctx) => _ActionDialog(
      title: l.recordWaterChange,
      valueLabel: l.amountLitersOptional,
      valueSuffix: unit.symbol,
      initialTime: existing?.changedAt ?? DateTime.now(),
      initialValue: (existing?.amountLiters ?? initialAmountLiters) == null
          ? ''
          : formatVolume(existing?.amountLiters ?? initialAmountLiters!, unit),
      initialNote: existing?.note ?? initialNote,
      showDelete: existing != null,
    ),
  );
  if (outcome == null) return;
  if (outcome is _ActionDelete) {
    if (existing != null && context.mounted) {
      final event = maintenanceEventAdapters.tryAdapt(
        existing,
        MaintenanceEventContext(
          context: context,
          l: l,
          units: ref.read(unitPrefsProvider),
        ),
        actions: maintenancePersistenceActions(ref.read(dbProvider), existing),
      );
      if (event != null) await _deleteWithUndo(context, l, event);
    }
    return;
  }
  final result = outcome as _ActionResult;
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
  final outcome = await showDialog<_ActionOutcome>(
    context: context,
    builder: (ctx) => _ActionDialog(
      title: l.recordCarbonChange,
      valueLabel: l.weightOptional,
      valueSuffix: l.gramSymbol,
      initialTime: existing?.changedAt ?? DateTime.now(),
      initialValue: existing?.grams == null
          ? ''
          : _formatGrams(existing!.grams!),
      initialNote: existing?.note,
      showDelete: existing != null,
    ),
  );
  if (outcome == null) return;
  if (outcome is _ActionDelete) {
    if (existing != null && context.mounted) {
      final event = maintenanceEventAdapters.tryAdapt(
        existing,
        MaintenanceEventContext(
          context: context,
          l: l,
          units: ref.read(unitPrefsProvider),
        ),
        actions: maintenancePersistenceActions(ref.read(dbProvider), existing),
      );
      if (event != null) await _deleteWithUndo(context, l, event);
    }
    return;
  }
  final result = outcome as _ActionResult;
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
  final outcome = await showDialog<_ActionOutcome>(
    context: context,
    builder: (ctx) => _ActionDialog(
      title: l.recordEquipmentCleaning,
      initialTime: existing?.cleanedAt ?? DateTime.now(),
      initialNote: existing?.note,
      showDelete: existing != null,
    ),
  );
  if (outcome == null) return;
  if (outcome is _ActionDelete) {
    if (existing != null && context.mounted) {
      final event = maintenanceEventAdapters.tryAdapt(
        existing,
        MaintenanceEventContext(
          context: context,
          l: l,
          units: ref.read(unitPrefsProvider),
        ),
        actions: maintenancePersistenceActions(ref.read(dbProvider), existing),
      );
      if (event != null) await _deleteWithUndo(context, l, event);
    }
    return;
  }
  final result = outcome as _ActionResult;
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
  AppLocalizations l,
  MaintenanceEvent event,
) async {
  await event.actions.delete?.call();
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.itemDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => event.actions.undo?.call(),
        ),
      ),
    );
  return true;
}

String _formatGrams(double g) => formatLocaleNumberTrim(g);

enum _Kind { water, carbon, equipment }

/// What the action dialog produced: a save payload or a delete request. The
/// delete branch exists so screen-reader/switch-access users have a non-swipe
/// way to remove an entry (#45).
sealed class _ActionOutcome {
  const _ActionOutcome();
}

class _ActionDelete extends _ActionOutcome {
  const _ActionDelete();
}

class _ActionResult extends _ActionOutcome {
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
    this.showDelete = false,
  });

  final String title;

  /// Label for the optional numeric value field. When null the value field is
  /// hidden entirely (e.g. equipment cleaning records only a date + note).
  final String? valueLabel;
  final String? valueSuffix;
  final DateTime initialTime;
  final String initialValue;
  final String? initialNote;

  /// Whether to offer a Delete action (editing an existing entry). This is the
  /// accessible alternative to swipe-to-delete (#45).
  final bool showDelete;

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
            ReefValueRow(
              leading: const ReefIconChip(Icons.schedule),
              value: formatDateTime(context, _time, weekday: false),
              valueStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ReefTokens.of(context).text,
              ),
              actions: [ReefInlineButton(l.change, onPressed: _pickDateTime)],
            ),
            if (widget.valueLabel != null) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueCtrl,
                autofocus: true,
                style: ReefTokens.monoInputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.valueLabel,
                  suffixText: widget.valueSuffix,
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
              decoration: InputDecoration(labelText: l.noteOptional),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.showDelete)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, const _ActionDelete()),
            child: Text(l.delete),
          ),
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
