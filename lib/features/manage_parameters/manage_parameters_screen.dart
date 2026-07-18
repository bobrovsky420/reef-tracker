import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/dashboard_sections.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/ratio.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_bounds_editor.dart';

/// Per-tank parameter management: enable/disable, reorder, edit zones, add from
/// the catalog, and re-apply the setup-type preset.
class ManageParametersScreen extends ConsumerWidget {
  const ManageParametersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    final trackedAsync = ref.watch(trackedParametersProvider);

    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.parameters)),
        body: Center(child: Text(l.noActiveAquarium)),
      );
    }
    final type = SetupType.fromName(tank.setupType);
    final prefs = ref.watch(unitPrefsProvider);
    final ratioSettings = ref.watch(ratioSettingsProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l.parameters),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.moreOptions,
            onSelected: (v) async {
              if (v == 'preset') {
                await _confirmApplyPreset(context, ref, tank.id, type);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'preset',
                child: Text(l.reapplyPreset(l.setupLabel(type))),
              ),
            ],
          ),
        ],
      ),
      body: trackedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tracked) {
          // One reorderable list holding both measurements and ratio cards.
          // The dashboard-layout setting decides its order and captions so the
          // list always mirrors the dashboard: grouped → the composite key
          // (#6) with a per-row section caption; classic → the flat shared
          // display order with no captions. Core parameters only: microelement
          // rows (U17) are managed from the Microelements screen, and listing
          // ~30 of them here would bury the dashboard set.
          final grouped =
              (ref.watch(dashboardLayoutProvider).value ??
                  DashboardLayout.grouped) ==
              DashboardLayout.grouped;
          final items =
              <_DashItem>[
                for (final p in tracked)
                  if (isCoreParam(p.paramKey)) _ParamItem(p),
                for (final kind in RatioKind.values)
                  _RatioItem(kind, ratioSettings[kind.name]),
              ]..sort(
                (a, b) => grouped
                    ? a.key.compareTo(b.key)
                    : a.flatOrder.compareTo(b.flatOrder),
              );

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final reordered = [...items];
              reordered.insert(newIndex, reordered.removeAt(oldIndex));
              final paramOrders = <({int id, int order})>[];
              final ratioOrders = <({String key, int order})>[];
              for (var i = 0; i < reordered.length; i++) {
                final it = reordered[i];
                switch (it) {
                  case _ParamItem():
                    paramOrders.add((id: it.param.id, order: i));
                  case _RatioItem():
                    ratioOrders.add((key: it.kind.name, order: i));
                }
              }
              unawaited(
                ref
                    .read(dbProvider)
                    .applyDashboardOrder(
                      tank.id,
                      paramOrders: paramOrders,
                      ratioOrders: ratioOrders,
                    ),
              );
            },
            itemBuilder: (context, i) {
              final item = items[i];
              return switch (item) {
                _ParamItem() => _paramRow(
                  context,
                  ref,
                  item.param,
                  prefs,
                  i,
                  grouped: grouped,
                ),
                _RatioItem() => _ratioRow(
                  context,
                  ref,
                  tank.id,
                  item,
                  i,
                  grouped: grouped,
                ),
              };
            },
          );
        },
      ),
      // Disabled until the tracked list has loaded (#19): with an empty
      // fallback the sheet would offer already-tracked parameters.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: trackedAsync.hasValue
            ? () => _addParameter(
                context,
                ref,
                tank.id,
                type,
                trackedAsync.value!,
              )
            : null,
        icon: const Icon(Icons.add),
        label: Text(l.addParameter),
      ),
    );
  }

  Widget _paramRow(
    BuildContext context,
    WidgetRef ref,
    TrackedParameter param,
    UnitPrefs prefs,
    int index, {
    required bool grouped,
  }) {
    final l = AppLocalizations.of(context);
    final pres = presentationOf(param, prefs);
    return ListTile(
      key: ValueKey('p${param.id}'),
      title: _titleWithGroup(
        context,
        l.paramName(param.paramKey),
        // No section caption in the classic (flat) layout — there are no
        // sections to belong to.
        grouped ? l.dashSectionLabel(sectionOfParam(param.paramKey)) : null,
      ),
      subtitle: Text(_boundsSummary(l, boundsOf(param), pres)),
      // Name the switch after its row so screen readers don't announce an
      // anonymous switch (#48).
      leading: Semantics(
        label: l.paramName(param.paramKey),
        child: Switch.adaptive(
          value: param.enabled,
          onChanged: (v) => ref
              .read(dbProvider)
              .updateTrackedParameter(param.copyWith(enabled: v)),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l.editZones,
            onPressed: () =>
                context.push('/parameters/${param.id}/edit', extra: param),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, semanticLabel: l.reorder),
          ),
        ],
      ),
    );
  }

  Widget _ratioRow(
    BuildContext context,
    WidgetRef ref,
    int tankId,
    _RatioItem item,
    int index, {
    required bool grouped,
  }) {
    final l = AppLocalizations.of(context);
    final kind = item.kind;
    final bounds = ratioBounds(kind, item.settings);
    return ListTile(
      key: ValueKey('r${kind.name}'),
      title: _titleWithGroup(
        context,
        l.ratioCardLabel(kind),
        grouped ? l.dashSectionLabel(DashboardSection.ratios) : null,
      ),
      subtitle: Text(_ratioBoundsSummary(l, kind, bounds)),
      leading: Semantics(
        label: l.ratioCardLabel(kind),
        child: Switch.adaptive(
          value: ratioRowVisible(item.settings),
          onChanged: (v) =>
              ref.read(dbProvider).setRatioVisible(tankId, kind.name, v),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l.editZones,
            onPressed: () => context.push('/ratio/${kind.name}/edit'),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, semanticLabel: l.reorder),
          ),
        ],
      ),
    );
  }

  Future<void> _addParameter(
    BuildContext context,
    WidgetRef ref,
    int tankId,
    SetupType type,
    List<TrackedParameter> tracked,
  ) async {
    final l = AppLocalizations.of(context);
    final existing = tracked.map((e) => e.paramKey).toSet();
    final available = kReefParameters
        .where((p) => !existing.contains(p.key) && !p.isMicro)
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.allParametersAdded)));
      return;
    }
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in available)
              ListTile(
                title: Text(l.paramName(p.key)),
                trailing: Text(
                  p.unit,
                  style: TextStyle(color: Theme.of(ctx).hintColor),
                ),
                onTap: () => Navigator.pop(ctx, p.key),
              ),
          ],
        ),
      ),
    );
    if (key != null) {
      await ref.read(dbProvider).addTrackedParameter(tankId, key, type);
    }
  }

  Future<void> _confirmApplyPreset(
    BuildContext context,
    WidgetRef ref,
    int tankId,
    SetupType type,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reapplyPresetTitle(l.setupLabel(type))),
        content: Text(l.reapplyPresetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.apply),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(dbProvider).applyPreset(tankId, type);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.presetApplied)));
      }
    }
  }
}

/// Row title plus the faint dashboard-section caption (#6). The list is
/// mirror-sorted to the grouped dashboard, and the caption tells the user
/// which fixed section a row belongs to — a drag past a section boundary
/// clamps to the row's own section, and this makes that legible. Null group
/// (unknown legacy keys, the headerless `other` bucket) renders no caption.
Widget _titleWithGroup(BuildContext context, String name, String? group) {
  if (group == null) return Text(name);
  return Row(
    children: [
      Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text(
        group,
        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
      ),
    ],
  );
}

/// An item in the unified manage list: either a tracked parameter or a ratio
/// card. Both expose the dashboard's composite sort [key] (grouped layout, #6)
/// and the [flatOrder] (classic layout) so the list can mirror whichever the
/// dashboard-layout setting selects. In the grouped layout the flat-index
/// reorder writeback (`applyDashboardOrder`) converges saved orders to
/// group-clustered values, and a drag past a section boundary clamps to the
/// item's own section; in the classic layout the list is one freely-ordered
/// flat sequence.
sealed class _DashItem {
  DashboardSortKey get key;
  double get flatOrder;
}

class _ParamItem extends _DashItem {
  _ParamItem(this.param);
  final TrackedParameter param;
  @override
  DashboardSortKey get key => paramSortKey(param.paramKey, param.displayOrder);
  @override
  double get flatOrder => param.displayOrder.toDouble();
}

class _RatioItem extends _DashItem {
  _RatioItem(this.kind, this.settings);
  final RatioKind kind;
  final RatioSettings? settings;
  @override
  DashboardSortKey get key => ratioSortKey(kind, settings);
  @override
  double get flatOrder => ratioRowOrder(kind, settings);
}

String _boundsSummary(
  AppLocalizations l,
  ZoneBounds b,
  ParamPresentation pres,
) {
  if (b.isEmpty) return l.noBoundariesSet;
  String f(double? v) => v == null ? '∞' : pres.format(v);
  return l.boundsSummary(
    f(b.greenLow),
    f(b.greenHigh),
    pres.unitLabel,
    f(b.amberLow),
    f(b.amberHigh),
  );
}

/// Bounds summary for a ratio card, formatted in the kind's displayed metric.
String _ratioBoundsSummary(AppLocalizations l, RatioKind kind, ZoneBounds b) {
  if (b.isEmpty) return l.noBoundariesSet;
  String f(double? v) => v == null ? '∞' : formatRatioBound(kind, v);
  return l.boundsSummary(
    f(b.greenLow),
    f(b.greenHigh),
    '',
    f(b.amberLow),
    f(b.amberHigh),
  );
}

/// Editor for a single tracked parameter's unit + four zone boundaries.
class ParameterEditScreen extends ConsumerStatefulWidget {
  const ParameterEditScreen({super.key, required this.param});

  final TrackedParameter param;

  @override
  ConsumerState<ParameterEditScreen> createState() =>
      _ParameterEditScreenState();
}

class _ParameterEditScreenState extends ConsumerState<ParameterEditScreen> {
  /// Preset "remind to test" cadences (U1); anything else is Custom.
  static const _cadencePresets = [3, 7, 14, 30];

  final _formKey = GlobalKey<FormState>();
  final _editorKey = GlobalKey<ZoneBoundsEditorState>();
  late final TextEditingController _unit;
  late final ParamPresentation _pres;

  int? _cadence;
  bool _customCadence = false;
  late final TextEditingController _customDays;

  @override
  void initState() {
    super.initState();
    // Edit boundaries in the user's display unit; values are stored canonically.
    _pres = presentationOf(widget.param, ref.read(unitPrefsProvider));
    _unit = TextEditingController(text: widget.param.unit);
    _cadence = widget.param.testCadenceDays;
    _customCadence = _cadence != null && !_cadencePresets.contains(_cadence);
    _customDays = TextEditingController(
      text: _customCadence ? '$_cadence' : '',
    );
  }

  @override
  void dispose() {
    _unit.dispose();
    _customDays.dispose();
    super.dispose();
  }

  /// The parameter's stored (canonical) bounds converted into the display space
  /// the editor edits in.
  ZoneBounds get _displayBounds => ZoneBounds(
    amberLow: _toDisplay(widget.param.amberLow),
    greenLow: _toDisplay(widget.param.greenLow),
    greenHigh: _toDisplay(widget.param.greenHigh),
    amberHigh: _toDisplay(widget.param.amberHigh),
  );

  double? _toDisplay(double? canonical) =>
      canonical == null ? null : _pres.toDisplay(canonical);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final editor = _editorKey.currentState!;
    if (!editor.orderOk) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.boundsOrderError)));
      return;
    }
    if (!editor.pairsOk) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.boundsPairError)));
      return;
    }
    // Editor values are in display space; convert back to canonical storage.
    final b = editor.values;
    double? canon(double? v) => v == null ? null : _pres.toCanonical(v);
    final cadence = _customCadence
        ? int.parse(_customDays.text.trim())
        : _cadence;
    await ref
        .read(dbProvider)
        .updateTrackedParameter(
          widget.param.copyWith(
            // Temp/salinity unit follows app settings, microelement units
            // are fixed by the catalog; keep the stored unit either way.
            unit: _pres.unitFollowsSettings || _pres.unitFixed
                ? widget.param.unit
                : _unit.text.trim(),
            amberLow: Value(canon(b.amberLow)),
            greenLow: Value(canon(b.greenLow)),
            greenHigh: Value(canon(b.greenHigh)),
            amberHigh: Value(canon(b.amberHigh)),
            testCadenceDays: Value(cadence),
          ),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final help = l.paramHelp(widget.param.paramKey);
    return Scaffold(
      appBar: AppBar(title: Text(l.paramName(widget.param.paramKey))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (help != null) ...[
              Text(help, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            if (_pres.unitFollowsSettings || _pres.unitFixed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.straighten),
                title: Text(l.unitWithValue(_pres.unitLabel)),
                // Microelements: the unit is fixed by the catalog (the
                // stored unit field is ignored), not driven by app settings.
                subtitle: Text(
                  _pres.unitFollowsSettings
                      ? l.unitFromSettingsNote
                      : l.unitFixedNote,
                ),
              )
            else
              TextFormField(
                controller: _unit,
                decoration: InputDecoration(labelText: l.unit),
              ),
            const SizedBox(height: 24),
            ZoneBoundsEditor(
              key: _editorKey,
              initial: _displayBounds,
              format: (v) => formatLocaleNumber(v, _pres.decimals),
              trailingNote: Text(
                l.boundsUnitNote(_pres.unitLabel),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            // "Remind to test" cadence (U1). The reminder anchors on the
            // parameter's latest reading, so logging a test resets the timer.
            Text(l.remindToTest, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l.cadenceOff),
                  selected: !_customCadence && _cadence == null,
                  onSelected: (_) => setState(() {
                    _cadence = null;
                    _customCadence = false;
                  }),
                ),
                for (final d in _cadencePresets)
                  ChoiceChip(
                    label: Text(l.daysShortN(d)),
                    selected: !_customCadence && _cadence == d,
                    onSelected: (_) => setState(() {
                      _cadence = d;
                      _customCadence = false;
                    }),
                  ),
                ChoiceChip(
                  label: Text(l.cadenceCustom),
                  selected: _customCadence,
                  onSelected: (_) => setState(() => _customCadence = true),
                ),
              ],
            ),
            if (_customCadence) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customDays,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.customDaysLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed = int.tryParse((v ?? '').trim());
                  return (parsed == null || parsed < 1)
                      ? l.invalidIntervalDays
                      : null;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
