import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/export_share.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/pro_features.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/trend_view.dart';
import '../../widgets/zone_chip.dart';
import '../actions/action_markers.dart';

/// Time-series history + readings list for one parameter of the active tank.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.paramKey});

  final String paramKey;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Marks the exact chart area captured by the share-as-image action (U14).
  final GlobalKey _chartBoundaryKey = GlobalKey();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final range = chartRangeFromLabel(ref.watch(chartRangeProvider).value);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    // "firstWhereOrNull" without package:collection — the param may have been
    // untracked/deleted while this screen is open; null falls back to the
    // catalog-based presentation below instead of crashing.
    final TrackedParameter? param = tracked
        .where((t) => t.paramKey == widget.paramKey)
        .cast<TrackedParameter?>()
        .firstWhere((t) => true, orElse: () => null);
    final readingsAsync = ref.watch(paramReadingsProvider(widget.paramKey));
    // select + TrendResult's value equality: another parameter's trend
    // changing doesn't rebuild this screen (T2).
    final trend = ref.watch(
      tankTrendsProvider.select((trends) => trends[widget.paramKey]),
    );
    final markers = actionMarkers(
      waterChanges: ref.watch(waterChangesProvider).value ?? const [],
      carbonChanges: ref.watch(carbonChangesProvider).value ?? const [],
      cleanings: ref.watch(equipmentCleaningsProvider).value ?? const [],
    );
    final prefs = ref.watch(unitPrefsProvider);
    final pres = param != null
        ? presentationOf(param, prefs)
        : presentationForKey(
            widget.paramKey,
            kParameterByKey[widget.paramKey]?.unit ?? '',
            prefs,
          );

    final cutoff = range.days == null
        ? null
        : DateTime.now().subtract(Duration(days: range.days!));
    List<Reading> inRange(List<Reading> all) => cutoff == null
        ? all
        : all.where((r) => r.takenAt.isAfter(cutoff)).toList();
    final hasChart = inRange(readingsAsync.value ?? const []).isNotEmpty;

    // Dose-calculator entry points (this parameter is a dosable element):
    // always the app-bar shortcut; additionally an inline CTA when the latest
    // reading sits below the green zone — a correction dose can only raise.
    final dosable = kDosingElementKeys.contains(widget.paramKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.paramName(widget.paramKey)),
        actions: [
          if (dosable)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: l.doseCalcTitle,
              onPressed: () => _openCalculator(correction: false),
            ),
          if (hasChart)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l.share,
              onPressed: _shareChart,
            ),
        ],
      ),
      // Quick-add without leaving the screen (U30). Hidden while the empty
      // state is showing — its centered CTA is the same action.
      floatingActionButton: hasChart
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l.addReading),
              onPressed: () => _addReading(pres),
            )
          : null,
      body: readingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (all) {
          final data = inRange(all);

          return Column(
            children: [
              const ChartRangeSelector(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 4),
              ),
              Expanded(
                // Builder-based slivers (T14): only visible reading rows are
                // instantiated — on "All" the old ListView(children:) built
                // hundreds of Dismissible tiles per rebuild.
                child: data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.noReadingsInRange),
                            const SizedBox(height: 16),
                            // A never-tested parameter used to dead-end here
                            // (reached via the health sheet's "never tested"
                            // rows) — offer the first reading in place (U30).
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(
                                all.isEmpty
                                    ? l.recordFirstReading
                                    : l.addReading,
                              ),
                              onPressed: () => _addReading(pres),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollCtrl,
                        slivers: [
                          SliverToBoxAdapter(
                            // The boundary wraps backdrop + card so the shared
                            // PNG comes out as "chart card on solid background"
                            // (REDESIGN #17). The ColoredBox keeps the capture
                            // opaque — a bare capture would be transparent and
                            // unreadable on forum dark/light themes, and the
                            // dark card fill is itself translucent. Must be the
                            // solid body token: scaffoldBackgroundColor is
                            // transparent over the ReefBackground gradient.
                            child: RepaintBoundary(
                              key: _chartBoundaryKey,
                              child: ColoredBox(
                                color: ReefTokens.of(context).scaffoldBody,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    12,
                                  ),
                                  child: ReefCard(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      14,
                                      8,
                                      12,
                                    ),
                                    child: SizedBox(
                                      height: 280,
                                      child: TrendChart(
                                        readings: data,
                                        param: param,
                                        pres: pres,
                                        markers: markers,
                                        zoomable: true,
                                        showMarkerLegend: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (trend != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  12,
                                ),
                                child: TrendCard(trend: trend, pres: pres),
                              ),
                            ),
                          if (dosable && _belowGreen(param, data))
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  12,
                                ),
                                child: _CorrectionCta(
                                  onTap: () =>
                                      _openCalculator(correction: true),
                                ),
                              ),
                            ),
                          // Numeric summary of the plotted range (U31): the
                          // swing and center the user would otherwise eyeball
                          // off the line or scroll the list for.
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _RangeStats(data: data, pres: pres),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: _readingsSliver(context, data, param, pres),
                          ),
                          // Keeps the last row tappable under the FAB.
                          const SliverToBoxAdapter(child: SizedBox(height: 88)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// True when the newest reading in range classifies below the green zone —
  /// the case a correction dose can fix (values above range are water-change
  /// territory, so no CTA there).
  bool _belowGreen(TrackedParameter? param, List<Reading> data) {
    if (param == null || data.isEmpty) return false;
    final greenLow = boundsOf(param).greenLow;
    return greenLow != null && data.last.value < greenLow;
  }

  /// Opens the dose calculator on this parameter — Pro-gated with the same
  /// teaser dialog as the Dosing tab's calculator tile.
  void _openCalculator({required bool correction}) {
    if (ref.read(proFeatureProvider(ProFeature.doseCalculator))) {
      final mode = correction ? '&mode=correction' : '';
      unawaited(
        context.push('/dosing/calculator?element=${widget.paramKey}$mode'),
      );
    } else {
      unawaited(showProFeatureDialog(context, ProFeature.doseCalculator));
    }
  }

  /// Captures the chart's [RepaintBoundary] as a PNG and hands it to the OS
  /// share sheet (U14) — reef forums live on parameter-graph screenshots.
  Future<void> _shareChart() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // At least 2× so the image survives forum re-compression; higher-density
    // screens capture at their native ratio.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pixelRatio = dpr < 2.0 ? 2.0 : dpr;
    try {
      // The chart sliver is only painted while on screen — if the user
      // scrolled down to the readings list, bring it back first.
      if (_scrollCtrl.hasClients && _scrollCtrl.offset > 0) {
        _scrollCtrl.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      final boundary = _chartBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? png;
      try {
        png = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (png == null) throw StateError('PNG encoding failed');

      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      await shareExportBytes(
        fileName: '$kChartExportPrefix$stamp-${widget.paramKey}.png',
        bytes: png.buffer.asUint8List(),
        mimeType: 'image/png',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWith('$e'))));
    }
  }

  /// Quick-adds a reading for this parameter right from its history (U30) —
  /// reuses [_ReadingDialog] in new-reading mode, so the #31 plausibility
  /// validation applies unchanged.
  Future<void> _addReading(ParamPresentation pres) async {
    final db = ref.read(dbProvider);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final result = await showDialog<_ReadingDialogResult>(
      context: context,
      builder: (ctx) => _ReadingDialog(
        paramKey: widget.paramKey,
        pres: pres,
        initialTime: DateTime.now(),
        isNew: true,
      ),
    );
    if (result is! _ReadingEdit) return;
    await db.insertReading(
      tankId: tank.id,
      paramKey: widget.paramKey,
      value: result.value,
      takenAt: result.time,
    );
  }

  Widget _readingsSliver(
    BuildContext context,
    List<Reading> data,
    TrackedParameter? param,
    ParamPresentation pres,
  ) {
    final bounds = param != null ? boundsOf(param) : const ZoneBounds();
    final tokens = ReefTokens.of(context);
    return ReefSliverCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      sliver: SliverList.builder(
        itemCount: data.length,
        itemBuilder: (context, i) {
          final r = data[data.length - 1 - i]; // newest first
          return Dismissible(
            key: ValueKey(r.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            confirmDismiss: (_) => _confirmDelete(context, r),
            // Rows sit inside the sliver card, whose fill paints over the
            // scaffold Material — each row brings a transparent Material so
            // ink and the swipe background render above the card (#11
            // pattern).
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _editReading(context, r, pres),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: i == data.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.surfaceBorder),
                          ),
                        ),
                  child: Row(
                    children: [
                      ZoneBadge(bounds.classify(r.value)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pres.format(r.value)} ${pres.unitLabel}',
                              style: ReefTokens.monoTextStyle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: tokens.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDateTime(context, r.takenAt) +
                                  (r.note != null ? '\n${r.note}' : ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: tokens.textFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Edits a reading's value and/or its date/time. When the timestamp is moved
  /// and the reading was saved together with others (same batch), asks whether
  /// to re-time just this value or the whole batch — mirroring delete's choice.
  Future<void> _editReading(
    BuildContext context,
    Reading r,
    ParamPresentation pres,
  ) async {
    final db = ref.read(dbProvider);
    final tank = ref.read(activeTankProvider);
    final result = await showDialog<_ReadingDialogResult>(
      context: context,
      builder: (ctx) => _ReadingDialog(
        paramKey: r.paramKey,
        pres: pres,
        initialValue: r.value,
        initialTime: r.takenAt,
      ),
    );
    if (result == null) return;
    // Delete requested from the dialog — the accessible, non-swipe path (#45).
    // Reuses the swipe flow's group-aware confirm + undo.
    if (result is _ReadingDelete) {
      if (context.mounted) await _confirmDelete(context, r);
      return;
    }
    final edit = result as _ReadingEdit;

    final timeChanged = !edit.time.isAtSameMomentAs(r.takenAt);
    bool applyTimeToAll = false;
    var hadSiblings = false;
    if (timeChanged && tank != null) {
      final siblings = await db.readingGroup(r);
      final others = siblings.length - 1;
      hadSiblings = others > 0;
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
      await db.updateReadingGroupTime(r, edit.time);
    }
    // Re-timing only this value detaches it from its batch (#15): it gets a
    // fresh group id of its own, so group delete/edit can't drag it along —
    // and, unlike a null, it can never be re-absorbed into a legacy cluster
    // by the restore-time group-id backfill.
    final detach = timeChanged && !applyTimeToAll && hadSiblings;
    await db.updateReading(
      r.copyWith(
        value: edit.value,
        takenAt: edit.time,
        groupId: detach ? Value(newReadingGroupId()) : Value(r.groupId),
      ),
    );
  }

  /// Asks whether a re-timing should affect only this reading or all [others]+1
  /// readings entered together as one batch.
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
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _EditChoice.one),
            child: Text(l.deleteOnlyThis),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _EditChoice.all),
            child: Text(l.deleteAllTogether),
          ),
        ],
      ),
    );
  }

  /// Handles a swipe-to-delete. A standalone measurement is deleted immediately
  /// with an "Undo" SnackBar; one saved together with other measurements (same
  /// batch id) still prompts whether to delete just this value or the whole
  /// batch, then offers the same undo. Returns true if the row should dismiss.
  Future<bool> _confirmDelete(BuildContext context, Reading r) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return false;

    final siblings = await db.readingGroup(r);
    final others = siblings.length - 1;
    if (!context.mounted) return false;

    // The readings to restore if the user taps Undo.
    final List<Reading> removed;
    if (others <= 0) {
      // A standalone measurement: delete straight away, offer undo.
      await db.deleteReading(r.id);
      removed = [r];
    } else {
      // Saved together with other measurements: offer a choice first.
      final choice = await showDialog<_DeleteChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteTogetherTitle),
          content: Text(l.deleteTogetherBody(others)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.cancel),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.one),
              child: Text(l.deleteOnlyThis),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.all),
              child: Text(l.deleteAllTogether),
            ),
          ],
        ),
      );
      switch (choice) {
        case _DeleteChoice.one:
          await db.deleteReading(r.id);
          removed = [r];
        case _DeleteChoice.all:
          await db.deleteReadingGroup(r);
          removed = siblings;
        case _DeleteChoice.cancel:
        case null:
          return false;
      }
    }

    if (context.mounted) _showUndo(context, l, removed);
    return true;
  }

  /// Shows a "Deleted — Undo" SnackBar that re-inserts [removed] readings,
  /// preserving each reading's own value, timestamp and note.
  void _showUndo(
    BuildContext context,
    AppLocalizations l,
    List<Reading> removed,
  ) {
    final db = ref.read(dbProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l.itemDeleted),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              for (final r in removed) {
                await db.insertReading(
                  tankId: r.tankId,
                  paramKey: r.paramKey,
                  value: r.value,
                  takenAt: r.takenAt,
                  note: r.note,
                  // Keep the batch identity so a restored group can still be
                  // edited/deleted together (#15).
                  groupId: r.groupId,
                );
              }
            },
          ),
        ),
      );
  }
}

/// Min / Avg / Max / test-count summary card for the readings in the selected
/// range (U31), derived from the same in-memory list the chart plots. Stats
/// are computed on canonical values: the display conversion is an increasing
/// affine map, so min/max/mean commute with it.
///
/// Styling per REDESIGN §A.8: four equal columns divided by 1 px hairlines,
/// uppercase faint labels over mono w700 values. Values keep the unit suffix
/// and the `FittedBox` down-scaling — the mock's bare numbers don't survive
/// `350 µg/L`-class value+unit widths.
class _RangeStats extends StatelessWidget {
  const _RangeStats({required this.data, required this.pres});

  /// Non-empty — the enclosing branch only renders when the range has data.
  final List<Reading> data;
  final ParamPresentation pres;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    var min = data.first.value;
    var max = min;
    var sum = 0.0;
    for (final r in data) {
      if (r.value < min) min = r.value;
      if (r.value > max) max = r.value;
      sum += r.value;
    }
    String fmt(double v) => '${pres.format(v)} ${pres.unitLabel}';

    Widget cell(String label, String value, {bool last = false}) => Expanded(
      child: Container(
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(right: BorderSide(color: tokens.surfaceBorder)),
              ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.33,
                color: tokens.textFaint,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: ReefTokens.monoTextStyle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ReefCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(l.statMin, fmt(min)),
            cell(l.statAvg, fmt(sum / data.length)),
            cell(l.statMax, fmt(max)),
            cell(l.statTests, '${data.length}', last: true),
          ],
        ),
      ),
    );
  }
}

/// Inline "below range → calculate a correction dose" call-to-action shown
/// under the trend card when the latest reading sits under the green zone.
/// Mirrors the TrendCard's icon-chip row so the two read as one family.
class _CorrectionCta extends StatelessWidget {
  const _CorrectionCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    return ReefCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.track,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calculate_outlined,
              size: 16,
              color: tokens.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.correctionCta,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 16, color: tokens.textFaint),
        ],
      ),
    );
  }
}

enum _DeleteChoice { one, all, cancel }

enum _EditChoice { one, all, cancel }

/// What [_ReadingDialog] produced: an edit payload or a delete request (the
/// non-swipe delete path, #45).
sealed class _ReadingDialogResult {
  const _ReadingDialogResult();
}

class _ReadingDelete extends _ReadingDialogResult {
  const _ReadingDelete();
}

/// The edited canonical value and timestamp.
class _ReadingEdit extends _ReadingDialogResult {
  const _ReadingEdit(this.time, this.value);
  final DateTime time;
  final double value;
}

/// Edits one reading's value (in the user's display unit) and its date/time,
/// or — with [isNew] — records a fresh one (U30: quick-add from history).
/// The date/time picker mirrors the actions log's `_ActionDialog`.
class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    required this.paramKey,
    required this.pres,
    this.initialValue,
    required this.initialTime,
    this.isNew = false,
  });

  final String paramKey;
  final ParamPresentation pres;

  /// Canonical value to seed the field (shown converted to the display unit);
  /// null starts the field empty (new-reading mode).
  final double? initialValue;
  final DateTime initialTime;

  /// New-reading mode: "Add reading" title, no Delete action, empty value.
  final bool isNew;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _time = widget.initialTime;
  late final TextEditingController _valueCtrl = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : widget.pres.format(widget.initialValue!),
  );

  @override
  void dispose() {
    _valueCtrl.dispose();
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
      title: Text(widget.isNew ? l.addReading : l.editMeasurement),
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
            const SizedBox(height: 8),
            TextFormField(
              controller: _valueCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                suffixText: widget.pres.unitLabel,
                border: const OutlineInputBorder(),
              ),
              // Reject a blank, unparseable, or physically impossible value
              // instead of silently reverting to the original on save (#31).
              validator: (_) {
                final v = parseUserDouble(_valueCtrl.text);
                if (v == null) return l.enterANumber;
                final canonical = widget.pres.toCanonical(v);
                return checkParamValue(widget.paramKey, canonical) ==
                        ParamValueCheck.impossible
                    ? l.impossibleValue
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.isNew)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, const _ReadingDelete()),
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final v = parseUserDouble(_valueCtrl.text)!;
            final canonical = widget.pres.toCanonical(v);
            // A value outside the plausible range needs explicit confirmation
            // before it replaces the stored one (#31).
            if (checkParamValue(widget.paramKey, canonical) ==
                ParamValueCheck.implausible) {
              final proceed = await _confirmImplausible(l, canonical);
              if (proceed != true) return;
            }
            if (!context.mounted) return;
            Navigator.pop(context, _ReadingEdit(_time, canonical));
          },
          child: Text(l.save),
        ),
      ],
    );
  }

  /// Asks the user to confirm a value outside the plausible range, echoing the
  /// value as the app understood it (which is what exposes a locale mis-parse).
  Future<bool?> _confirmImplausible(AppLocalizations l, double canonical) {
    // `implausible` implies the catalog defines the range.
    final def = kParameterByKey[widget.paramKey]!;
    final pres = widget.pres;
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
            Text(
              l.implausibleValueLine(
                l.paramName(widget.paramKey),
                '${pres.format(canonical)} ${pres.unitLabel}',
                pres.format(def.plausibleMin!),
                '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
              ),
              style: const TextStyle(fontWeight: FontWeight.w500),
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
}
