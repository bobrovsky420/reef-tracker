import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/reminders.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_segmented.dart';
import '../../widgets/reef_sheet.dart';
import 'actions_screen.dart';

/// The user-maintained maintenance schedule (U12), route `/schedule`: recurring
/// or one-off plans for the three logged action types plus custom-titled
/// tasks. Rows reorder by drag; tap edits; delete and "Mark done" act
/// immediately with an Undo SnackBar (the U10 cheap-to-restore convention).
class MaintenanceScheduleScreen extends ConsumerWidget {
  const MaintenanceScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final schedules =
        ref.watch(maintenanceSchedulesProvider).value ??
        const <MaintenanceSchedule>[];
    final dues = {
      for (final d in ref.watch(maintenanceDueProvider)) d.schedule.id: d.due,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.maintenanceSchedule)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.addMaintenanceTask,
        onPressed: () => showMaintenanceTaskSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: schedules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.scheduleEmptyBody, textAlign: TextAlign.center),
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: schedules.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = schedules.map((s) => s.id).toList();
                ids.insert(newIndex, ids.removeAt(oldIndex));
                unawaited(
                  ref.read(dbProvider).reorderMaintenanceSchedules(ids),
                );
              },
              itemBuilder: (context, i) {
                final s = schedules[i];
                return ListTile(
                  key: ValueKey(s.id),
                  leading: Icon(maintenanceIcon(s)),
                  title: Text(maintenanceName(l, s)),
                  subtitle: Text(_subtitle(context, l, s, dues[s.id])),
                  onTap: () => showMaintenanceTaskSheet(context, ref, task: s),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dues[s.id] != null &&
                          MaintenanceActionType.fromName(s.actionType) == null)
                        IconButton(
                          tooltip: l.markDone,
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () =>
                              markMaintenanceDoneWithUndo(context, ref, s),
                        ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: l.reorder,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _subtitle(
    BuildContext context,
    AppLocalizations l,
    MaintenanceSchedule s,
    DueStatus? due,
  ) {
    final repeat = maintenanceRepeatText(context, l, s);
    if (due == null) return repeat;
    return '$repeat • ${dueText(l, due)}';
  }
}

/// Whether a plan repeats at all (any of the three repeat fields set); a
/// non-repeating plan is a one-off, retired once done.
bool maintenanceRepeats(MaintenanceSchedule s) =>
    s.cadenceDays != null ||
    s.monthDay != null ||
    parseWeekdays(s.weekdays).isNotEmpty;

/// Human-readable repeat line for a plan row: "Every 2 weeks", "Every Mon,
/// Thu", "Monthly on day 1", … or "One-off". Mirrors [nextMaintenanceDue]'s
/// field priority (weekdays > monthDay > cadence).
String maintenanceRepeatText(
  BuildContext context,
  AppLocalizations l,
  MaintenanceSchedule s,
) {
  final days = parseWeekdays(s.weekdays);
  if (days.isNotEmpty) return l.everyWeekdays(formatWeekdays(context, days));
  if (s.monthDay != null) return l.monthlyOnDayN(s.monthDay!);
  final n = s.cadenceDays;
  if (n == null) return l.oneOff;
  return switch (MaintenanceCadenceUnit.fromName(s.cadenceUnit)) {
    MaintenanceCadenceUnit.weeks => l.everyWeeksN(n),
    MaintenanceCadenceUnit.months => l.everyMonthsN(n),
    _ => l.dosingEveryDaysN(n),
  };
}

/// Icon for a plan row/chip: the action-log glyphs for typed plans, a generic
/// task glyph for custom ones.
IconData maintenanceIcon(MaintenanceSchedule s) =>
    switch (MaintenanceActionType.fromName(s.actionType)) {
      MaintenanceActionType.waterChange => Icons.format_color_fill,
      MaintenanceActionType.carbonChange => Icons.grain,
      MaintenanceActionType.equipmentCleaning =>
        Icons.cleaning_services_outlined,
      null => Icons.task_alt,
    };

/// Display name for a plan: the localized action name, or the custom title.
String maintenanceName(AppLocalizations l, MaintenanceSchedule s) =>
    switch (MaintenanceActionType.fromName(s.actionType)) {
      MaintenanceActionType.waterChange => l.waterChange,
      MaintenanceActionType.carbonChange => l.carbonChange,
      MaintenanceActionType.equipmentCleaning => l.equipmentCleaning,
      null => s.title ?? '',
    };

/// "Due today" / "Due in N d" / "N d overdue".
String dueText(AppLocalizations l, DueStatus due) => due.daysLeft > 0
    ? l.dueInDaysN(due.daysLeft)
    : due.daysLeft == 0
    ? l.dueToday
    : l.overdueDaysN(-due.daysLeft);

/// Completes a custom task: stamps it done (or, for a one-off, retires the
/// row), with an Undo SnackBar restoring the captured row verbatim.
Future<void> markMaintenanceDoneWithUndo(
  BuildContext context,
  WidgetRef ref,
  MaintenanceSchedule task,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  if (!maintenanceRepeats(task)) {
    // A finished one-off has no next occurrence: retire the row.
    await db.deleteMaintenanceSchedule(task.id);
  } else {
    await db.markMaintenanceDone(task.id, DateTime.now());
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.taskMarkedDone),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => db.restoreMaintenanceSchedule(task),
        ),
      ),
    );
}

/// Add/edit form for a maintenance plan. Editing offers Delete (immediate,
/// with Undo — recreating a plan is cheap).
Future<void> showMaintenanceTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  MaintenanceSchedule? task,
}) async {
  final tank = ref.read(activeTankProvider);
  if (tank == null) return;
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);

  final outcome = await showModalBottomSheet<_TaskOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _TaskSheet(task: task),
    ),
  );
  if (outcome == null) return;

  if (outcome is _TaskDelete) {
    final existing = task;
    if (existing == null) return;
    await db.deleteMaintenanceSchedule(existing.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l.taskDeleted),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => db.restoreMaintenanceSchedule(existing),
          ),
        ),
      );
    return;
  }

  final result = outcome as _TaskResult;
  if (task == null) {
    await db.insertMaintenanceSchedule(
      tankId: tank.id,
      actionType: result.actionType,
      title: result.title,
      cadenceDays: result.cadenceDays,
      cadenceUnit: result.cadenceUnit,
      weekdays: result.weekdays,
      monthDay: result.monthDay,
      scheduledAt: result.scheduledAt,
      remindEnabled: result.remindEnabled,
      note: result.note,
    );
  } else {
    await db.updateMaintenanceSchedule(
      task.id,
      actionType: result.actionType,
      title: result.title,
      cadenceDays: result.cadenceDays,
      cadenceUnit: result.cadenceUnit,
      weekdays: result.weekdays,
      monthDay: result.monthDay,
      scheduledAt: result.scheduledAt,
      remindEnabled: result.remindEnabled,
      note: result.note,
    );
  }
}

sealed class _TaskOutcome {
  const _TaskOutcome();
}

class _TaskDelete extends _TaskOutcome {
  const _TaskDelete();
}

class _TaskResult extends _TaskOutcome {
  const _TaskResult({
    required this.actionType,
    required this.title,
    required this.cadenceDays,
    required this.cadenceUnit,
    required this.weekdays,
    required this.monthDay,
    required this.scheduledAt,
    required this.remindEnabled,
    required this.note,
  });

  final String? actionType;
  final String? title;
  final int? cadenceDays;
  final String? cadenceUnit;
  final String? weekdays;
  final int? monthDay;
  final DateTime? scheduledAt;
  final bool remindEnabled;
  final String? note;
}

/// The five repeat modes offered by the sheet's "Repeats" dropdown, mapping
/// 1:1 onto how [nextMaintenanceDue] reads the stored fields.
enum _RepeatMode { everyDays, everyWeeks, everyMonths, weekdays, monthDay }

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({this.task});

  final MaintenanceSchedule? task;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _days;
  late final TextEditingController _monthDayCtrl;
  late final TextEditingController _note;

  /// null = custom task.
  MaintenanceActionType? _type = MaintenanceActionType.waterChange;
  bool _repeats = true;
  _RepeatMode _mode = _RepeatMode.everyDays;
  final Set<int> _weekdays = {};
  DateTime? _scheduledAt;
  bool _remind = true;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _type = t == null
        ? MaintenanceActionType.waterChange
        : MaintenanceActionType.fromName(t.actionType);
    _repeats = t == null || maintenanceRepeats(t);
    _weekdays.addAll(parseWeekdays(t?.weekdays));
    _mode = _weekdays.isNotEmpty
        ? _RepeatMode.weekdays
        : t?.monthDay != null
        ? _RepeatMode.monthDay
        : switch (MaintenanceCadenceUnit.fromName(t?.cadenceUnit)) {
            MaintenanceCadenceUnit.weeks => _RepeatMode.everyWeeks,
            MaintenanceCadenceUnit.months => _RepeatMode.everyMonths,
            _ => _RepeatMode.everyDays,
          };
    _title = TextEditingController(text: t?.title ?? '');
    _days = TextEditingController(text: '${t?.cadenceDays ?? 14}');
    _monthDayCtrl = TextEditingController(text: '${t?.monthDay ?? 1}');
    _note = TextEditingController(text: t?.note ?? '');
    _scheduledAt = t?.scheduledAt;
    _remind = t?.remindEnabled ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    _monthDayCtrl.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Prefill for the interval field per mode (14 days / 2 weeks / 1 month) —
  /// used to re-seed on mode switch only while the user hasn't typed a value.
  static String _intervalDefault(_RepeatMode m) => switch (m) {
    _RepeatMode.everyWeeks => '2',
    _RepeatMode.everyMonths => '1',
    _ => '14',
  };

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) setState(() => _scheduledAt = picked);
  }

  void _save() {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (!_repeats && _scheduledAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.dueDateRequired)));
      return;
    }
    if (_repeats && _mode == _RepeatMode.weekdays && _weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.weekdaysRequired)));
      return;
    }
    int? cadenceDays;
    String? cadenceUnit;
    String? weekdays;
    int? monthDay;
    if (_repeats) {
      switch (_mode) {
        case _RepeatMode.everyDays:
        case _RepeatMode.everyWeeks:
        case _RepeatMode.everyMonths:
          cadenceDays = int.parse(_days.text.trim());
          cadenceUnit = switch (_mode) {
            _RepeatMode.everyWeeks => MaintenanceCadenceUnit.weeks,
            _RepeatMode.everyMonths => MaintenanceCadenceUnit.months,
            _ => MaintenanceCadenceUnit.days,
          }.name;
        case _RepeatMode.weekdays:
          weekdays = (_weekdays.toList()..sort()).join(',');
        case _RepeatMode.monthDay:
          monthDay = int.parse(_monthDayCtrl.text.trim());
      }
    }
    final title = _title.text.trim();
    Navigator.pop(
      context,
      _TaskResult(
        actionType: _type?.name,
        title: _type == null ? title : null,
        cadenceDays: cadenceDays,
        cadenceUnit: cadenceUnit,
        weekdays: weekdays,
        monthDay: monthDay,
        scheduledAt: _scheduledAt,
        remindEnabled: _remind,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.task != null;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          // No top inset — the sheet's drag handle already provides it.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ReefSheetHeader(
              editing ? l.editMaintenanceTask : l.addMaintenanceTask,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MaintenanceActionType?>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l.taskTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final t in MaintenanceActionType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(switch (t) {
                      MaintenanceActionType.waterChange => l.waterChange,
                      MaintenanceActionType.carbonChange => l.carbonChange,
                      MaintenanceActionType.equipmentCleaning =>
                        l.equipmentCleaning,
                    }),
                  ),
                DropdownMenuItem(value: null, child: Text(l.customTask)),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            if (_type == null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l.taskTitleLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l.taskTitleRequired : null,
              ),
            ],
            const SizedBox(height: 12),
            ReefSegmented<bool>(
              options: [(true, l.repeatLabel), (false, l.oneOff)],
              selected: _repeats,
              onChanged: (v) => setState(() => _repeats = v),
            ),
            if (_repeats) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<_RepeatMode>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: l.repeatModeLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final m in _RepeatMode.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(switch (m) {
                        _RepeatMode.everyDays => l.repeatEveryDays,
                        _RepeatMode.everyWeeks => l.repeatEveryWeeks,
                        _RepeatMode.everyMonths => l.repeatEveryMonths,
                        _RepeatMode.weekdays => l.repeatOnWeekdays,
                        _RepeatMode.monthDay => l.repeatOnMonthDay,
                      }),
                    ),
                ],
                onChanged: (m) {
                  if (m == null) return;
                  setState(() {
                    // Re-seed the interval field with the new unit's typical
                    // value unless the user already typed their own.
                    if (_days.text.trim() == _intervalDefault(_mode)) {
                      _days.text = _intervalDefault(m);
                    }
                    _mode = m;
                  });
                },
              ),
              const SizedBox(height: 12),
              switch (_mode) {
                _RepeatMode.everyDays ||
                _RepeatMode.everyWeeks ||
                _RepeatMode.everyMonths => TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: switch (_mode) {
                      _RepeatMode.everyWeeks => l.weeksLabel,
                      _RepeatMode.everyMonths => l.monthsLabel,
                      _ => l.customDaysLabel,
                    },
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final parsed = int.tryParse((v ?? '').trim());
                    if (parsed != null && parsed >= 1) return null;
                    return _mode == _RepeatMode.everyDays
                        ? l.invalidIntervalDays
                        : l.invalidInterval;
                  },
                ),
                _RepeatMode.weekdays => Wrap(
                  spacing: 8,
                  children: [
                    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                      FilterChip(
                        label: Text(formatWeekdays(context, [d])),
                        selected: _weekdays.contains(d),
                        onSelected: (sel) => setState(() {
                          sel ? _weekdays.add(d) : _weekdays.remove(d);
                        }),
                      ),
                  ],
                ),
                _RepeatMode.monthDay => TextFormField(
                  controller: _monthDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.monthDayLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final parsed = int.tryParse((v ?? '').trim());
                    return (parsed == null || parsed < 1 || parsed > 31)
                        ? l.invalidMonthDay
                        : null;
                  },
                ),
              },
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.dueDateLabel),
              subtitle: Text(
                _scheduledAt == null
                    ? l.dueDateRequired
                    : formatDate(_scheduledAt!),
              ),
              onTap: _pickDueDate,
              trailing: _scheduledAt == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l.cancel,
                      onPressed: () => setState(() => _scheduledAt = null),
                    ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: Text(l.remindMe),
            ),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (editing)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, const _TaskDelete()),
                    child: Text(l.delete),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: Text(l.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrollable due chips shown above the Actions log: one chip per
/// plan with a computable due date, ordered most-urgent first. Typed chips
/// open the pre-selected add-action dialog (logging resets the timer); custom
/// chips mark the task done.
///
/// Chip style per REDESIGN #11 (§A.6): a small surface card (r14, 1 px
/// border) with a `primary`-colored icon; an overdue chip's icon and label
/// switch to the `critical` token — a *status*, not a form error, so not
/// colorScheme.error (REDESIGN #1 straggler audit).
class MaintenanceDueChips extends ConsumerWidget {
  const MaintenanceDueChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dues = [...ref.watch(maintenanceDueProvider)]
      ..sort((a, b) => a.due.daysLeft.compareTo(b.due.daysLeft));
    if (dues.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          for (final d in dues)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _DueChip(due: d),
            ),
        ],
      ),
    );
  }
}

class _DueChip extends ConsumerWidget {
  const _DueChip({required this.due});

  final MaintenanceDue due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final overdue = due.due.daysLeft < 0;
    final radius = BorderRadius.circular(14);
    // Same layering as ReefCard: the multi-layer light shadow on an outer box,
    // fill + border + ink on the Material.
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final type = MaintenanceActionType.fromName(due.schedule.actionType);
            if (type != null) {
              await showAddActionSheet(context, ref, preset: type);
            } else {
              await markMaintenanceDoneWithUndo(context, ref, due.schedule);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  maintenanceIcon(due.schedule),
                  size: 14,
                  color: overdue ? tokens.critical : tokens.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${maintenanceName(l, due.schedule)}'
                  ' · ${dueText(l, due.due)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: overdue ? tokens.critical : tokens.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
