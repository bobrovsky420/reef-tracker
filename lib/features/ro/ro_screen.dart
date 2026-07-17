import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/ro.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_visuals.dart';
import '../actions/schedule_screen.dart' show dueText;

/// The shared reverse-osmosis unit (U16), route `/ro` — the one screen in the
/// app that is **not tank-scoped**: one RO unit serves every aquarium.
///
/// Overview of every enabled stage (filter/membrane/resin) with its remaining
/// life as a zone-colored progress bar and a "Mark replaced" action; disabled
/// stages ("not on my unit") sit in a collapsed section below and can be
/// re-enabled with one switch. The default 4-stage set is seeded on first
/// open.
class RoScreen extends ConsumerStatefulWidget {
  const RoScreen({super.key});

  @override
  ConsumerState<RoScreen> createState() => _RoScreenState();
}

class _RoScreenState extends ConsumerState<RoScreen> {
  @override
  void initState() {
    super.initState();
    // First visit seeds the typical 4-stage unit; a one-time settings flag
    // (not the row count) guards it, so deleting every stage sticks.
    unawaited(ref.read(dbProvider).seedDefaultRoStages());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statuses = ref.watch(roStageStatusProvider);
    final enabled = [
      for (final s in statuses)
        if (s.stage.enabled) s,
    ];
    final hidden = [
      for (final s in statuses)
        if (!s.stage.enabled) s,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.roUnitTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.roAddStage,
        onPressed: () => _showStageSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: statuses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.roEmptyBody, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              children: [
                for (final s in enabled) _StageCard(status: s),
                if (hidden.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text(
                      l.roHiddenStages,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  for (final s in hidden)
                    ListTile(
                      leading: Icon(
                        roStageIcon(RoStageType.fromName(s.stage.stageType)),
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(
                        l.roStageName(s.stage.stageType, s.stage.title),
                      ),
                      subtitle: Text(roLifespanText(l, s.stage.lifespanDays)),
                      trailing: Switch(
                        value: false,
                        onChanged: (_) => ref
                            .read(dbProvider)
                            .setRoStageEnabled(s.stage.id, true),
                      ),
                      onTap: () =>
                          _showStageSheet(context, ref, stage: s.stage),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Icon for a stage row: one glyph per typed stage, a generic part glyph for
/// custom (and unknown restored) types.
IconData roStageIcon(RoStageType? type) => switch (type) {
  RoStageType.sediment => Icons.filter_alt_outlined,
  RoStageType.carbonBlock => Icons.grain,
  RoStageType.membrane => Icons.layers_outlined,
  RoStageType.diResin => Icons.science_outlined,
  RoStageType.custom || null => Icons.build_outlined,
};

/// Human-readable lifespan ("Every 6 months" / "Every 2 weeks" / "Every 45
/// days"): lifespans are stored in plain days, so decompose to the largest
/// whole unit for display — the mirror image of the edit sheet's value × unit
/// input.
String roLifespanText(AppLocalizations l, int days) {
  if (days % 30 == 0) return l.everyMonthsN(days ~/ 30);
  if (days % 7 == 0) return l.everyWeeksN(days ~/ 7);
  return l.dosingEveryDaysN(days);
}

/// One enabled stage: name, lifespan, last replacement, remaining-life bar
/// (zone-colored), and the "Mark replaced" action. Tap opens the edit sheet.
class _StageCard extends ConsumerWidget {
  const _StageCard({required this.status});

  final RoStageStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stage = status.stage;
    final due = status.due;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStageSheet(context, ref, stage: stage),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(roStageIcon(RoStageType.fromName(stage.stageType))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.roStageName(stage.stageType, stage.title),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                status.lastReplacedAt == null
                    ? '${roLifespanText(l, stage.lifespanDays)} • '
                          '${l.roNoReplacementYet}'
                    : '${roLifespanText(l, stage.lifespanDays)} • '
                          '${l.roLastReplaced(formatDate(status.lastReplacedAt!))}',
                style: theme.textTheme.bodySmall,
              ),
              if (due != null) ...[
                const SizedBox(height: 8),
                _RemainingBar(due: due, lifespanDays: stage.lifespanDays),
              ],
              Row(
                children: [
                  if (due != null)
                    Text(
                      dueText(l, due),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: roStageZone(
                          daysLeft: due.daysLeft,
                          lifespanDays: stage.lifespanDays,
                        ).colorOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l.roMarkReplaced),
                    onPressed: () => _markReplaced(context, ref, stage),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The remaining-life bar: full and green right after a replacement, draining
/// toward amber inside the warning window and red once overdue.
class _RemainingBar extends StatelessWidget {
  const _RemainingBar({required this.due, required this.lifespanDays});

  final ({DateTime dueAt, int daysLeft}) due;
  final int lifespanDays;

  @override
  Widget build(BuildContext context) {
    final zone = roStageZone(
      daysLeft: due.daysLeft,
      lifespanDays: lifespanDays,
    );
    return LinearProgressIndicator(
      value: roRemainingFraction(
        daysLeft: due.daysLeft,
        lifespanDays: lifespanDays,
      ),
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
      color: zone.colorOf(context),
      backgroundColor: zone.softColorOf(context),
    );
  }
}

/// Records a replacement (date defaults to now, backdatable — the filters may
/// have been changed before the user reached the phone) with an Undo SnackBar
/// deleting the freshly inserted log row (U10 conventions).
Future<void> _markReplaced(
  BuildContext context,
  WidgetRef ref,
  RoStage stage,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final result = await showDialog<({DateTime time, String? note})>(
    context: context,
    builder: (ctx) =>
        _ReplaceDialog(title: l.roStageName(stage.stageType, stage.title)),
  );
  if (result == null) return;
  final id = await db.insertRoReplacement(
    stageId: stage.id,
    replacedAt: result.time,
    note: result.note,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.roReplacedRecorded),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => db.deleteRoReplacement(id),
        ),
      ),
    );
}

/// Date (+ optional note) confirmation for "Mark replaced" — the same shape
/// as the action-log dialog, minus the numeric value field.
class _ReplaceDialog extends StatefulWidget {
  const _ReplaceDialog({required this.title});

  final String title;

  @override
  State<_ReplaceDialog> createState() => _ReplaceDialogState();
}

class _ReplaceDialogState extends State<_ReplaceDialog> {
  DateTime _time = DateTime.now();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
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
                onPressed: () async {
                  final picked = await pickPastDateTime(context, _time);
                  if (picked == null || !mounted) return;
                  setState(() => _time = picked);
                },
              ),
            ],
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
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final note = _noteCtrl.text.trim();
            Navigator.pop(context, (
              time: _time,
              note: note.isEmpty ? null : note,
            ));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// The lifespan input's unit choices. Stored flattened to days (30/month —
/// RO lifespans are approximate by nature), decomposed back for display.
enum _LifespanUnit {
  days(1),
  weeks(7),
  months(30);

  const _LifespanUnit(this.inDays);
  final int inDays;
}

sealed class _StageOutcome {
  const _StageOutcome();
}

class _StageDelete extends _StageOutcome {
  const _StageDelete();
}

class _StageResult extends _StageOutcome {
  const _StageResult({
    required this.stageType,
    required this.title,
    required this.lifespanDays,
    required this.enabled,
    required this.remindEnabled,
    required this.note,
  });

  final String stageType;
  final String? title;
  final int lifespanDays;
  final bool enabled;
  final bool remindEnabled;
  final String? note;
}

/// Add/edit form for a stage. Deleting a stage also deletes its replacement
/// history (FK cascade) — irreversible, so it confirms instead of offering
/// Undo (U10 conventions).
Future<void> _showStageSheet(
  BuildContext context,
  WidgetRef ref, {
  RoStage? stage,
}) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);

  final outcome = await showModalBottomSheet<_StageOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _StageSheet(stage: stage),
    ),
  );
  if (outcome == null) return;

  if (outcome is _StageDelete) {
    final existing = stage;
    if (existing == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.roDeleteStageTitle),
        content: Text(l.roDeleteStageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await db.deleteRoStage(existing.id);
    return;
  }

  final result = outcome as _StageResult;
  if (stage == null) {
    await db.insertRoStage(
      stageType: result.stageType,
      title: result.title,
      lifespanDays: result.lifespanDays,
      enabled: result.enabled,
      remindEnabled: result.remindEnabled,
      note: result.note,
    );
  } else {
    await db.updateRoStage(
      stage.copyWith(
        stageType: result.stageType,
        title: Value(result.title),
        lifespanDays: result.lifespanDays,
        enabled: result.enabled,
        remindEnabled: result.remindEnabled,
        note: Value(result.note),
      ),
    );
  }
}

class _StageSheet extends StatefulWidget {
  const _StageSheet({this.stage});

  final RoStage? stage;

  @override
  State<_StageSheet> createState() => _StageSheetState();
}

class _StageSheetState extends State<_StageSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _note;

  RoStageType _type = RoStageType.sediment;
  _LifespanUnit _unit = _LifespanUnit.months;
  bool _enabled = true;
  bool _remind = true;

  /// Largest whole unit representing [days] exactly.
  static (_LifespanUnit, int) _decompose(int days) {
    if (days % 30 == 0) return (_LifespanUnit.months, days ~/ 30);
    if (days % 7 == 0) return (_LifespanUnit.weeks, days ~/ 7);
    return (_LifespanUnit.days, days);
  }

  @override
  void initState() {
    super.initState();
    final s = widget.stage;
    _type = s == null
        ? RoStageType.sediment
        : (RoStageType.fromName(s.stageType) ?? RoStageType.custom);
    final (unit, value) = _decompose(
      s?.lifespanDays ?? kRoDefaultLifespanDays[_type]!,
    );
    _unit = unit;
    _title = TextEditingController(text: s?.title ?? '');
    _value = TextEditingController(text: '$value');
    _note = TextEditingController(text: s?.note ?? '');
    _enabled = s?.enabled ?? true;
    _remind = s?.remindEnabled ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final title = _title.text.trim();
    Navigator.pop(
      context,
      _StageResult(
        stageType: _type.name,
        title: _type == RoStageType.custom ? title : null,
        lifespanDays: int.parse(_value.text.trim()) * _unit.inDays,
        enabled: _enabled,
        remindEnabled: _remind,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.stage != null;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              editing ? l.roEditStage : l.roAddStage,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RoStageType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l.taskTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final t in RoStageType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(
                      t == RoStageType.custom
                          ? l.roCustomStage
                          : l.roStageName(t.name, null),
                    ),
                  ),
              ],
              onChanged: (t) {
                if (t == null) return;
                setState(() {
                  // Adding a stage: re-seed the lifespan with the new type's
                  // typical value while the user hasn't typed their own.
                  final (oldUnit, oldValue) = _decompose(
                    kRoDefaultLifespanDays[_type] ??
                        kRoDefaultLifespanDays[RoStageType.diResin]!,
                  );
                  if (!editing &&
                      _unit == oldUnit &&
                      _value.text.trim() == '$oldValue') {
                    final (unit, value) = _decompose(
                      kRoDefaultLifespanDays[t] ??
                          kRoDefaultLifespanDays[RoStageType.diResin]!,
                    );
                    _unit = unit;
                    _value.text = '$value';
                  }
                  _type = t;
                });
              },
            ),
            if (_type == RoStageType.custom) ...[
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.roLifespanLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final parsed = int.tryParse((v ?? '').trim());
                      return (parsed == null || parsed < 1)
                          ? l.invalidInterval
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<_LifespanUnit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in _LifespanUnit.values)
                        DropdownMenuItem(
                          value: u,
                          child: Text(switch (u) {
                            _LifespanUnit.days => l.roUnitDays,
                            _LifespanUnit.weeks => l.roUnitWeeks,
                            _LifespanUnit.months => l.roUnitMonths,
                          }),
                        ),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: Text(l.roPartOfUnit),
              subtitle: Text(l.roPartOfUnitHint),
            ),
            SwitchListTile(
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
                        Navigator.pop(context, const _StageDelete()),
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
