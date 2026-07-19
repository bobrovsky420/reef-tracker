import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/ammonia_toxicity.dart';
import '../../domain/dashboard_sections.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/ratio.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_sheet.dart';
import '../../widgets/section_header.dart';
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
          // Free ammonia is a derived value of the ammonia parameter: its
          // visibility row only appears when ammonia is tracked, and its
          // toggle is disabled while ammonia is disabled (matching the
          // dashboard gate that hides the card when ammonia is off).
          final hasAmmonia = tracked.any((p) => p.paramKey == kAmmoniaKey);
          final ammoniaEnabled = tracked.any(
            (p) => p.paramKey == kAmmoniaKey && p.enabled,
          );
          final items =
              <_DashItem>[
                for (final p in tracked)
                  if (isCoreParam(p.paramKey)) _ParamItem(p),
                for (final kind in RatioKind.values)
                  _RatioItem(kind, ratioSettings[kind.name]),
                if (hasAmmonia) _FreeAmmoniaItem(),
              ]..sort(
                (a, b) => grouped
                    ? a.key.compareTo(b.key)
                    : a.flatOrder.compareTo(b.flatOrder),
              );

          // One `ReefSliverCard` of hairline-divided reorderable rows —
          // exactly the #13 dosing-list pattern (REDESIGN #19).
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                sliver: ReefSliverCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 10,
                  ),
                  sliver: SliverReorderableList(
                    itemCount: items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      // The free-ammonia row is pinned (a derived value): it
                      // has no drag handle, and it is skipped when writing
                      // back the param/ratio orders.
                      if (items[oldIndex] is _FreeAmmoniaItem) return;
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
                          case _FreeAmmoniaItem():
                            break; // not user-orderable
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
                    // The dragged row leaves the card, so give it an opaque
                    // lifted surface (the dark-theme card fill is translucent
                    // — rows underneath would show through the bare row).
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 3,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    ),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final isLast = i == items.length - 1;
                      return switch (item) {
                        _ParamItem() => _paramRow(
                          context,
                          ref,
                          item.param,
                          prefs,
                          i,
                          grouped: grouped,
                          isLast: isLast,
                        ),
                        _RatioItem() => _ratioRow(
                          context,
                          ref,
                          tank.id,
                          item,
                          i,
                          grouped: grouped,
                          isLast: isLast,
                        ),
                        _FreeAmmoniaItem() => _freeAmmoniaRow(
                          context,
                          ref,
                          tank.id,
                          ammoniaEnabled: ammoniaEnabled,
                          grouped: grouped,
                          isLast: isLast,
                        ),
                      };
                    },
                  ),
                ),
              ),
            ],
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

  /// Shared row shell (#13 row pattern): adaptive switch, title + sub column,
  /// optional edit icon + drag handle, hairline divider between rows. The
  /// rows sit inside the sliver card, whose fill paints over the scaffold
  /// Material — each row brings a transparent Material so its ink ripples
  /// above the card. [subMono] renders the sub line in the mono family
  /// (bounds summaries are numerals-heavy).
  Widget _manageRow(
    BuildContext context, {
    required Key key,
    required Widget leading,
    required Widget title,
    required String sub,
    bool subMono = true,
    List<Widget> trailing = const [],
    required bool isLast,
  }) {
    final tokens = ReefTokens.of(context);
    return Material(
      key: key,
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.surfaceBorder)),
              ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: subMono
                        ? ReefTokens.monoTextStyle.copyWith(
                            fontSize: 12,
                            color: tokens.textDim,
                          )
                        : TextStyle(fontSize: 12, color: tokens.textDim),
                  ),
                ],
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }

  Widget _editIcon(BuildContext context, String tooltip, VoidCallback onTap) =>
      IconButton(
        icon: Icon(
          Icons.edit_outlined,
          size: 18,
          color: ReefTokens.of(context).textDim,
        ),
        tooltip: tooltip,
        onPressed: onTap,
      );

  Widget _dragHandle(BuildContext context, AppLocalizations l, int index) =>
      ReorderableDragStartListener(
        index: index,
        // The padding keeps the 16 px glyph draggable with a finger.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.drag_handle,
            size: 16,
            color: ReefTokens.of(context).textFaint,
            semanticLabel: l.reorder,
          ),
        ),
      );

  Widget _paramRow(
    BuildContext context,
    WidgetRef ref,
    TrackedParameter param,
    UnitPrefs prefs,
    int index, {
    required bool grouped,
    required bool isLast,
  }) {
    final l = AppLocalizations.of(context);
    final pres = presentationOf(param, prefs);
    return _manageRow(
      context,
      key: ValueKey('p${param.id}'),
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
      title: _titleWithGroup(
        context,
        l.paramName(param.paramKey),
        // No section caption in the classic (flat) layout — there are no
        // sections to belong to.
        grouped ? l.dashSectionLabel(sectionOfParam(param.paramKey)) : null,
      ),
      sub: _boundsSummary(l, boundsOf(param), pres),
      trailing: [
        _editIcon(
          context,
          l.editZones,
          () => context.push('/parameters/${param.id}/edit', extra: param),
        ),
        _dragHandle(context, l, index),
      ],
      isLast: isLast,
    );
  }

  Widget _ratioRow(
    BuildContext context,
    WidgetRef ref,
    int tankId,
    _RatioItem item,
    int index, {
    required bool grouped,
    required bool isLast,
  }) {
    final l = AppLocalizations.of(context);
    final kind = item.kind;
    final bounds = ratioBounds(kind, item.settings);
    return _manageRow(
      context,
      key: ValueKey('r${kind.name}'),
      leading: Semantics(
        label: l.ratioCardLabel(kind),
        child: Switch.adaptive(
          value: ratioRowVisible(item.settings),
          onChanged: (v) =>
              ref.read(dbProvider).setRatioVisible(tankId, kind.name, v),
        ),
      ),
      title: _titleWithGroup(
        context,
        l.ratioCardLabel(kind),
        grouped ? l.dashSectionLabel(DashboardSection.ratios) : null,
      ),
      sub: _ratioBoundsSummary(l, kind, bounds),
      trailing: [
        _editIcon(
          context,
          l.editZones,
          () => context.push('/ratio/${kind.name}/edit'),
        ),
        _dragHandle(context, l, index),
      ],
      isLast: isLast,
    );
  }

  /// The free (toxic) ammonia visibility row — a derived value shown in the
  /// Ratios area. No zone editor (fixed toxicity thresholds in v1) and no drag
  /// handle (pinned first among ratios). The switch is disabled while the
  /// ammonia parameter is off, since the dashboard card is gated on it.
  Widget _freeAmmoniaRow(
    BuildContext context,
    WidgetRef ref,
    int tankId, {
    required bool ammoniaEnabled,
    required bool grouped,
    required bool isLast,
  }) {
    final l = AppLocalizations.of(context);
    final visible = ref.watch(freeAmmoniaVisibleProvider);
    return _manageRow(
      context,
      key: const ValueKey('free-ammonia'),
      leading: Semantics(
        label: l.freeAmmoniaLabel,
        child: Switch.adaptive(
          value: ammoniaEnabled && visible,
          onChanged: ammoniaEnabled
              ? (v) =>
                    ref.read(settingsProvider).setFreeAmmoniaVisible(tankId, v)
              : null,
        ),
      ),
      title: _titleWithGroup(
        context,
        l.freeAmmoniaLabel,
        grouped ? l.dashSectionLabel(DashboardSection.ratios) : null,
      ),
      sub: ammoniaEnabled
          ? l.freeAmmoniaShowSubtitle
          : l.freeAmmoniaNeedsAmmonia,
      subMono: false,
      isLast: isLast,
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
          // No top inset — the sheet's drag handle already provides it.
          padding: const EdgeInsets.only(top: 0, bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ReefSheetHeader(l.addParameter),
            ),
            for (final p in available)
              ListTile(
                title: Text(l.paramName(p.key)),
                trailing: Text(
                  p.unit,
                  style: TextStyle(color: ReefTokens.of(ctx).textFaint),
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
  final tokens = ReefTokens.of(context);
  final titleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: tokens.text,
  );
  if (group == null) return Text(name, style: titleStyle);
  return Row(
    children: [
      Flexible(
        child: Text(name, overflow: TextOverflow.ellipsis, style: titleStyle),
      ),
      const SizedBox(width: 8),
      Text(group, style: TextStyle(fontSize: 11, color: tokens.textFaint)),
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

/// The free-ammonia visibility row — pinned first in the Ratios area in both
/// layouts (matching the dashboard's fixed placement), not user-orderable.
class _FreeAmmoniaItem extends _DashItem {
  @override
  DashboardSortKey get key =>
      const DashboardSortKey(DashboardSection.ratios, -1.0, -1.0);
  @override
  double get flatOrder => 999.5;
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
  late final TextEditingController _target;
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
    final target = widget.param.targetValue;
    _target = TextEditingController(
      text: target == null
          ? ''
          : formatLocaleNumber(_pres.toDisplay(target), _pres.decimals),
    );
    _cadence = widget.param.testCadenceDays;
    _customCadence = _cadence != null && !_cadencePresets.contains(_cadence);
    _customDays = TextEditingController(
      text: _customCadence ? '$_cadence' : '',
    );
  }

  @override
  void dispose() {
    _unit.dispose();
    _target.dispose();
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
            targetValue: Value(canon(parseUserDouble(_target.text))),
          ),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final help = l.paramHelp(widget.param.paramKey);
    // Form grouped into card sections (REDESIGN #19): Unit / Safe ranges /
    // Testing reminder.
    return Scaffold(
      appBar: AppBar(title: Text(l.paramName(widget.param.paramKey))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (help != null)
              Text(
                help,
                style: TextStyle(fontSize: 12.5, color: tokens.textDim),
              ),
            SectionHeader(l.unit),
            ReefCard(
              padding: const EdgeInsets.all(16),
              child: _pres.unitFollowsSettings || _pres.unitFixed
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.straighten, size: 18, color: tokens.textDim),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.unitWithValue(_pres.unitLabel),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Microelements: the unit is fixed by the
                              // catalog (the stored unit field is ignored),
                              // not driven by app settings.
                              Text(
                                _pres.unitFollowsSettings
                                    ? l.unitFromSettingsNote
                                    : l.unitFixedNote,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(labelText: l.unit),
                    ),
            ),
            SectionHeader(l.sectionSafeRanges),
            ReefCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZoneBoundsEditor(
                    key: _editorKey,
                    initial: _displayBounds,
                    format: (v) => formatLocaleNumber(v, _pres.decimals),
                  ),
                  const SizedBox(height: 12),
                  // Correction target for the dose calculator (in the same
                  // display space as the bounds above). Empty = the middle of
                  // the green zone at use time.
                  TextFormField(
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    style: ReefTokens.monoInputStyle,
                    decoration: InputDecoration(
                      labelText: l.targetValueLabel,
                      helperText: l.targetValueHelp,
                      helperMaxLines: 3,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return parseUserDouble(v) == null ? l.enterANumber : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // The unit note now closes the card so it covers the target
                  // field too (it used to ride the bounds editor).
                  Text(
                    l.boundsUnitNote(_pres.unitLabel),
                    style: TextStyle(fontSize: 12, color: tokens.textDim),
                  ),
                ],
              ),
            ),
            // "Remind to test" cadence (U1). The reminder anchors on the
            // parameter's latest reading, so logging a test resets the timer.
            SectionHeader(l.remindToTest),
            ReefCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        onSelected: (_) =>
                            setState(() => _customCadence = true),
                      ),
                    ],
                  ),
                  if (_customCadence) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customDays,
                      keyboardType: TextInputType.number,
                      style: ReefTokens.monoInputStyle,
                      decoration: InputDecoration(labelText: l.customDaysLabel),
                      validator: (v) {
                        final parsed = int.tryParse((v ?? '').trim());
                        return (parsed == null || parsed < 1)
                            ? l.invalidIntervalDays
                            : null;
                      },
                    ),
                  ],
                ],
              ),
            ),
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
