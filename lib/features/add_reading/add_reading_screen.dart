import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/zone_chip.dart';
import 'test_set_sheets.dart';

/// Lets the user enter values for any subset of tracked parameters at one time.
///
/// Layout per REDESIGN #20: date/time as a `ReefCard` value row (#12 style),
/// §A.6 test-set selector chips, and the parameter rows grouped into one
/// `ReefCard` with hairline dividers — label, mono value field, live
/// `ZoneChip`. This is the batch-entry row recipe #24 reuses.
class AddReadingScreen extends ConsumerStatefulWidget {
  const AddReadingScreen({super.key});

  @override
  ConsumerState<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends ConsumerState<AddReadingScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final _noteCtrl = TextEditingController();
  DateTime _takenAt = DateTime.now();
  bool _saving = false;

  /// Test-set chip selection (U9). Until the user taps a chip this session,
  /// the effective selection comes from the persisted last-used set — computed
  /// in build, so no state is mutated while providers are still loading (#18).
  int? _pickedTemplateId;
  bool _templatePicked = false;

  // No listener here: only the row's zone chip depends on the typed text, and
  // it listens to its own controller (T14) — a keystroke must not rebuild the
  // whole form.
  TextEditingController _controllerFor(int id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickPastDateTime(context, _takenAt);
    if (picked == null || !mounted) return;
    setState(() => _takenAt = picked);
  }

  /// Selects a test-set chip (null = All) and persists it as the tank's
  /// last-used set. Purely a view filter: values already typed into rows the
  /// new selection hides are kept and still saved.
  void _selectTemplate(int? id) {
    setState(() {
      _templatePicked = true;
      _pickedTemplateId = id;
    });
    final tank = ref.read(activeTankProvider);
    if (tank != null) {
      unawaited(ref.read(settingsProvider).setLastReadingTemplate(tank.id, id));
    }
  }

  /// Opens the create sheet, pre-checking the parameters that currently hold
  /// typed values; the freshly created set becomes the active filter.
  Future<void> _createTestSet(List<TrackedParameter> params) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefill = {
      for (final p in params)
        if ((_controllers[p.id]?.text.trim() ?? '').isNotEmpty) p.paramKey,
    };
    final id = await showTestSetEditSheet(
      context,
      db: ref.read(dbProvider),
      tankId: tank.id,
      params: params,
      initialKeys: prefill,
    );
    if (id != null && mounted) _selectTemplate(id);
  }

  Future<void> _save(List<TrackedParameter> params) async {
    final l = AppLocalizations.of(context);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefs = ref.read(unitPrefsProvider);
    final entries = <TrackedParameter, double>{};
    final implausible = <TrackedParameter>[];
    for (final p in params) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = parseUserDouble(text);
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.invalidNumberFor(l.paramName(p.paramKey)))),
        );
        return;
      }
      // Store canonically (e.g. °C, SG) regardless of the display unit.
      final canonical = presentationOf(p, prefs).toCanonical(value);
      // Sanity-check the canonical value (#31): impossible measurements are
      // rejected; merely implausible ones are collected and confirmed below,
      // so a genuinely extreme reading stays recordable.
      switch (checkParamValue(p.paramKey, canonical)) {
        case ParamValueCheck.impossible:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.impossibleValueFor(l.paramName(p.paramKey))),
            ),
          );
          return;
        case ParamValueCheck.implausible:
          implausible.add(p);
        case ParamValueCheck.ok:
          break;
      }
      entries[p] = canonical;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.enterAtLeastOneValue)));
      return;
    }
    if (implausible.isNotEmpty) {
      final proceed = await _confirmImplausible(l, [
        for (final p in implausible) (p, entries[p]!),
      ], prefs);
      if (proceed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      // Insert the whole group atomically so a failure mid-group can't leave a
      // partial batch behind.
      await db.insertReadingGroup(
        tankId: tank.id,
        takenAt: _takenAt,
        note: note,
        values: [
          for (final e in entries.entries)
            (paramKey: e.key.paramKey, value: e.value),
        ],
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.savedReadings(entries.length))),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks the user to confirm values outside their plausible range before
  /// saving (#31). Shows each suspicious value as the app understood it, in
  /// the display unit, next to the typical range — which is what exposes a
  /// locale mis-parse (`1,300` read as 1.3).
  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    List<(TrackedParameter, double)> values,
    UnitPrefs prefs,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.implausibleTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.implausibleIntro),
            const SizedBox(height: 12),
            for (final (p, canonical) in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Builder(
                  builder: (_) {
                    final pres = presentationOf(p, prefs);
                    // `implausible` implies the catalog defines the range.
                    final def = kParameterByKey[p.paramKey]!;
                    return Text(
                      l.implausibleValueLine(
                        l.paramName(p.paramKey),
                        '${pres.format(canonical)} ${pres.unitLabel}',
                        pres.format(def.plausibleMin!),
                        '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final trackedAsync = ref.watch(trackedParametersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.addReading),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l.manageTestSets,
            onPressed: () => showTestSetsManageSheet(context),
          ),
        ],
      ),
      body: trackedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tracked) {
          // Core parameters only — microelement values are entered from the
          // Microelements screen's own form (U17), keeping this one compact.
          final params = tracked
              .where((t) => t.enabled && isCoreParam(t.paramKey))
              .toList();
          if (params.isEmpty) {
            return Center(child: Text(l.noTrackedToRecord));
          }
          final prefs = ref.watch(unitPrefsProvider);

          // Test-set filter (U9): the chips narrow which rows are *shown*;
          // _save always receives the full [params] list, so a typed value
          // hidden by the current selection is still saved.
          final templates =
              ref.watch(readingTemplatesProvider).value ?? const [];
          final selected = _selectedTemplate(templates);
          final keySet = selected?.keys.toSet();
          final visibleParams = keySet == null
              ? params
              : [
                  for (final p in params)
                    if (keySet.contains(p.paramKey)) p,
                ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ReefCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: ReefValueRow(
                  leading: const ReefIconChip(Icons.schedule),
                  value: formatDateTime(context, _takenAt, weekday: false),
                  valueStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ReefTokens.of(context).text,
                  ),
                  actions: [
                    ReefInlineButton(l.change, onPressed: _pickDateTime),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _testSetChips(l, templates, selected, params),
              const SizedBox(height: 12),
              if (selected != null && visibleParams.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l.testSetEmptyHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ReefCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 14,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < visibleParams.length; i++)
                        _paramRow(
                          visibleParams[i],
                          prefs,
                          isLast: i == visibleParams.length - 1,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(labelText: l.noteOptional),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(params),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(l.saveReadings),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Resolves the effective test-set selection: the chip tapped this session,
  /// else the tank's persisted last-used set. A dangling id (set deleted, or
  /// ids replaced by a restore) simply finds no match — "All".
  ReadingTemplate? _selectedTemplate(List<ReadingTemplate> templates) {
    int? effectiveId;
    if (_templatePicked) {
      effectiveId = _pickedTemplateId;
    } else {
      final tank = ref.watch(activeTankProvider);
      final lastUsed =
          ref.watch(lastReadingTemplatesProvider).value ?? const {};
      effectiveId = tank == null ? null : lastUsed[tank.id];
    }
    if (effectiveId == null) return null;
    for (final t in templates) {
      if (t.id == effectiveId) return t;
    }
    return null;
  }

  /// The horizontal single-select chip row: `[All] [set…] [+ new]`.
  Widget _testSetChips(
    AppLocalizations l,
    List<ReadingTemplate> templates,
    ReadingTemplate? selected,
    List<TrackedParameter> params,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l.testSetAll),
            selected: selected == null,
            onSelected: (_) => _selectTemplate(null),
          ),
          for (final t in templates)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              // Long-press is a power-user shortcut to edit the set; the
              // accessible path is the app-bar manage action (#45 precedent).
              child: GestureDetector(
                onLongPress: () => showTestSetEditSheet(
                  context,
                  db: ref.read(dbProvider),
                  tankId: t.tankId,
                  params: params,
                  template: t,
                ),
                child: ChoiceChip(
                  label: Text(t.name),
                  selected: t.id == selected?.id,
                  onSelected: (_) => _selectTemplate(t.id),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            // Icon size/color come from the theme's §A.6 chip treatment.
            child: ActionChip(
              avatar: const Icon(Icons.add),
              label: Text(l.newTestSet),
              onPressed: () => _createTestSet(params),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paramRow(TrackedParameter p, UnitPrefs prefs, {required bool isLast}) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final pres = presentationOf(p, prefs);
    final ctrl = _controllerFor(p.id);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.surfaceBorder)),
            ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l.paramName(p.paramKey),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.text,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              // Mono entry, `textFaint` unit suffix — both from the #18
              // input treatment.
              style: ReefTokens.monoInputStyle,
              decoration: InputDecoration(
                isDense: true,
                suffixText: pres.unitLabel,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, text, _) {
                final value = parseUserDouble(text.text);
                if (value == null) return const SizedBox.shrink();
                final zone = boundsOf(p).classify(pres.toCanonical(value));
                return ZoneChip(zone, compact: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
