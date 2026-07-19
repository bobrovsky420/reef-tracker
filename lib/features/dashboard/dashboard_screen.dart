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
import '../../domain/trend.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/env_pill.dart';
import '../../widgets/free_ammonia_view.dart';
import '../../widgets/insights_card.dart';
import '../../widgets/param_gauge.dart';
import '../../widgets/ratio_row.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tank_health_badge.dart';
import '../../widgets/trend_view.dart';
import '../../widgets/zone_visuals.dart';
import '../micro/micro_summary_tile.dart';

/// One dashboard item built for both layouts in a single pass (see
/// [DashboardBody]): [groupedKey] orders the sectioned layout (#6), [flatOrder]
/// the original single user-ordered grid. Each layout gets its own widget —
/// [tile] is the classic flat-grid card (frozen pre-redesign look), [grouped]
/// the grouped-layout form (#7 gauge dial / #9 env pill / #8 ratio *row* —
/// assembled into one card per section — falling back to the flat tile where
/// no richer form applies).
typedef _DashEntry = ({
  DashboardSection section,
  DashboardSortKey groupedKey,
  double flatOrder,
  Widget tile,
  Widget grouped,
});

/// Grid of parameter status tiles for the active tank. Hosted by `HomeShell`,
/// which owns the surrounding `Scaffold`, app bar, bottom navigation and FAB.
class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trackedAsync = ref.watch(trackedParametersProvider);
    // Head of each parameter's history (newest kRecentReadingsPerParam rows,
    // T1) — plenty for the tiles: latest value + change needs 2, and the ratio
    // headline reads only the last two merged series points, which can only
    // ever carry forward each parameter's latest readings. Full series live
    // on the history/ratio screens.
    final readingsAsync = ref.watch(recentReadingsProvider);

    return trackedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
      data: (tracked) {
        final readings = readingsAsync.value ?? const [];
        final prefs = ref.watch(unitPrefsProvider);
        final trends = ref.watch(tankTrendsProvider);
        final trendHorizon =
            ref.watch(trendHorizonProvider).value ?? kTrendDefaultHorizon;
        final ratioSettings =
            ref.watch(ratioSettingsProvider).value ?? const {};

        // Latest readings per parameter (for value + trend).
        final byParam = <String, List<Reading>>{};
        for (final r in readings) {
          (byParam[r.paramKey] ??= []).add(r); // already newest-first
        }

        // Build every dashboard card once — a measurement tile per enabled
        // core param, a tile per visible ratio — carrying BOTH ordering keys:
        // the grouped composite key (#6) and the flat shared display order
        // (the pre-#6 model). The dashboard-layout setting then picks which to
        // use, so the two layouts share one tile-construction pass.
        // Core parameters only: microelements (U17) live behind the summary
        // tile appended below, not as individual dashboard tiles.
        final entries = <_DashEntry>[];
        for (final param in tracked.where(
          (t) => t.enabled && isCoreParam(t.paramKey),
        )) {
          final section = sectionOfParam(param.paramKey);
          final history = byParam[param.paramKey] ?? const <Reading>[];
          final tile = _ParameterTile(
            param: param,
            history: history,
            prefs: prefs,
            trend: trends[param.paramKey],
            trendHorizon: trendHorizon,
          );
          entries.add((
            section: section,
            groupedKey: paramSortKey(param.paramKey, param.displayOrder),
            flatOrder: param.displayOrder.toDouble(),
            tile: tile,
            grouped: _groupedParamTile(
              context,
              l,
              section,
              param,
              history,
              prefs,
              trends[param.paramKey],
              trendHorizon,
              fallback: tile,
            ),
          ));
        }
        for (final kind in RatioKind.values) {
          final row = ratioSettings[kind.name];
          if (!ratioRowVisible(row)) continue;
          // Keep visible ratio cards on the dashboard even with no computable
          // value yet — the tile shows "No readings" (the series is empty when a
          // measurement is missing or the denominator is zero), matching how
          // measurement tiles render before their first reading.
          final numHist =
              (byParam[kind.numeratorKey] ?? const []).ratioReadings;
          final denHist =
              (byParam[kind.denominatorKey] ?? const []).ratioReadings;
          final series = computeRatioSeries(
            numHist.reversed.toList(),
            denHist.reversed.toList(),
          );
          // The headline pairs the latest reading of each parameter; when they
          // lie further apart than kRatioMaxSkew (or the latest pair is
          // undefined) the "current" ratio is half stale — render it muted
          // instead of confidently zone-colored (#32).
          final stale =
              series.isNotEmpty && latestRatio(numHist, denHist) == null;
          final bounds = ratioBounds(kind, row);
          entries.add((
            section: DashboardSection.ratios,
            groupedKey: ratioSortKey(kind, row),
            flatOrder: ratioRowOrder(kind, row),
            tile: _RatioTile(
              kind: kind,
              points: series,
              bounds: bounds,
              stale: stale,
            ),
            // The grouped layout collapses the section into one card of rows
            // (#8); `_appendGrouped` interleaves the hairline dividers.
            grouped: RatioRow(
              kind: kind,
              points: series,
              bounds: bounds,
              stale: stale,
              onTap: () => context.push('/ratio/${kind.name}'),
            ),
          ));
        }

        // Free (toxic) ammonia (NH₃): a derived value shown in the Ratios area,
        // pinned first. Gated on the ammonia parameter being tracked + enabled
        // (so disabling ammonia hides it automatically) and the per-tank
        // visibility preference. Computed from each input's latest readings.
        final ammoniaEnabled = tracked.any(
          (t) => t.paramKey == kAmmoniaKey && t.enabled,
        );
        if (ammoniaEnabled && ref.watch(freeAmmoniaVisibleProvider)) {
          List<AmmoniaInput> inputsFor(String key) => [
            for (final r in byParam[key] ?? const <Reading>[])
              (takenAt: r.takenAt, value: r.value),
          ];
          final fa = computeFreeAmmonia(
            ammonia: inputsFor(kAmmoniaKey),
            ph: inputsFor(kPhKey),
            temperature: inputsFor(kTemperatureKey),
            salinity: inputsFor(kSalinityKey),
          );
          entries.add((
            section: DashboardSection.ratios,
            // Pinned ahead of the ratio rows (order ≥ 1000) in both layouts.
            groupedKey: const DashboardSortKey(DashboardSection.ratios, -1, -1),
            flatOrder: 999.5,
            tile: FreeAmmoniaTile(data: fa, prefs: prefs),
            grouped: FreeAmmoniaRow(data: fa, prefs: prefs),
          ));
        }

        if (entries.isEmpty) return const _NoParamsView();

        final layout =
            ref.watch(dashboardLayoutProvider).value ?? DashboardLayout.grouped;
        final microEnabled = ref.watch(microEnabledProvider).value ?? true;
        final display =
            ref.watch(healthDisplayProvider).value ?? HealthDisplay.both;

        // One scroll view so the health card scrolls together with the tiles.
        // The Insights card (U28) rides the same visibility setting as the
        // health header: both are derived summaries of the same readings.
        final slivers = <Widget>[
          if (display.showCard) ...[
            const SliverToBoxAdapter(child: TankHealthHeader()),
            const SliverToBoxAdapter(child: InsightsCard()),
          ],
        ];

        if (layout == DashboardLayout.classic) {
          _appendClassic(context, slivers, entries, microEnabled: microEnabled);
        } else {
          _appendGrouped(
            context,
            l,
            slivers,
            entries,
            microEnabled: microEnabled,
          );
        }

        // The bottom inset keeps the last row scrollable past the translucent
        // tab bar (`extendBody` — a CustomScrollView gets no automatic
        // MediaQuery inset).
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
          ),
        );

        return CustomScrollView(slivers: slivers);
      },
    );
  }

  /// The grouped-layout form of one core parameter's card: a gauge dial for
  /// the core-chemistry (L) and nutrients (S) sections (#7), a compact pill
  /// for environment (#9). Falls back to [fallback] — the flat classic tile —
  /// for the `other` bucket (unknown keys have no catalog axis data) and
  /// whenever `gaugeAxis` can't produce an honest span (missing/invalid
  /// bounds must never render as a misleading arc).
  Widget _groupedParamTile(
    BuildContext context,
    AppLocalizations l,
    DashboardSection section,
    TrackedParameter param,
    List<Reading> history,
    UnitPrefs prefs,
    TrendResult? trend,
    int trendHorizon, {
    required Widget fallback,
  }) {
    final latest = history.isNotEmpty ? history.first : null;
    final previous = history.length > 1 ? history[1] : null;
    switch (section) {
      case DashboardSection.coreChemistry:
      case DashboardSection.nutrients:
        final bounds = boundsOf(param);
        final def = kParameterByKey[param.paramKey];
        final axis = gaugeAxis(
          bounds,
          fallbackLow: def?.plausibleMin,
          fallbackHigh: def?.plausibleMax,
        );
        if (axis == null) return fallback;
        return ParamGaugeCard(
          title: l.paramShortName(param.paramKey),
          pres: presentationOf(param, prefs),
          bounds: bounds,
          axis: axis,
          large: section == DashboardSection.coreChemistry,
          latest: latest?.value,
          previous: previous?.value,
          takenAt: latest?.takenAt,
          trend: trend,
          horizonDays: trendHorizon,
          onTap: () => context.push('/history/${param.paramKey}'),
        );
      case DashboardSection.environment:
        return EnvPill(
          title: l.paramShortName(param.paramKey),
          pres: presentationOf(param, prefs),
          zone: latest != null
              ? boundsOf(param).classify(latest.value)
              : Zone.unknown,
          latest: latest?.value,
          previous: previous?.value,
          trend: trend,
          horizonDays: trendHorizon,
          onTap: () => context.push('/history/${param.paramKey}'),
        );
      case DashboardSection.ratios:
      case DashboardSection.other:
        return fallback;
    }
  }

  /// Classic layout: the original single grid mixing measurements and ratios
  /// in one user-managed order, with the Microelements tile (U17) pinned as
  /// the last cell. Frozen pre-redesign look — the gauge/pill/row forms
  /// (#7–#10) target the grouped layout only.
  void _appendClassic(
    BuildContext context,
    List<Widget> slivers,
    List<_DashEntry> entries, {
    required bool microEnabled,
  }) {
    final sorted = [...entries]
      ..sort((a, b) => a.flatOrder.compareTo(b.flatOrder));
    final tiles = [
      for (final e in sorted) e.tile,
      if (microEnabled) const MicroSummaryTile(grid: true),
    ];
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        sliver: _tileGrid(
          context,
          tiles,
          height: MediaQuery.textScalerOf(context).scale(143),
        ),
      ),
    );
  }

  /// Grouped layout (#6–#10): one section per non-empty group, each under its
  /// header, in the enum's fixed order; a section with nothing to show renders
  /// nothing at all, header included. Core chemistry and nutrients are gauge
  /// grids (#7), Ratios one card of band rows (#8), Environment a pill row
  /// (#9); the `other` bucket (unknown legacy keys) stays a headerless flat
  /// grid. The Microelements list-card (#10) is pinned last.
  void _appendGrouped(
    BuildContext context,
    AppLocalizations l,
    List<Widget> slivers,
    List<_DashEntry> entries, {
    required bool microEnabled,
  }) {
    final tokens = ReefTokens.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    // Sorting by the composite key (section rank first) then partitioning keeps
    // each section's tiles in their within-section display order.
    final sorted = [...entries]
      ..sort((a, b) => a.groupedKey.compareTo(b.groupedKey));
    final bySection = <DashboardSection, List<Widget>>{};
    for (final e in sorted) {
      (bySection[e.section] ??= []).add(e.grouped);
    }
    for (final section in DashboardSection.values) {
      final tiles = bySection[section];
      if (tiles == null) continue;
      final label = l.dashSectionLabel(section);
      if (label != null) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverToBoxAdapter(child: SectionHeader(label)),
          ),
        );
      }
      // Per-section geometry: dial cards are dominated by their fixed-size
      // dial, so only the text portion under it scales with the font setting;
      // the flat tiles and pills are all stacked text and scale wholesale
      // (#44).
      final Widget sliver = switch (section) {
        DashboardSection.coreChemistry => _tileGrid(
          context,
          tiles,
          height: 176 + textScaler.scale(52),
        ),
        DashboardSection.nutrients => _tileGrid(
          context,
          tiles,
          height: 124 + textScaler.scale(30),
        ),
        // All visible ratio rows collapse into one card with hairline
        // dividers (#8).
        DashboardSection.ratios => SliverToBoxAdapter(
          child: ReefCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: tokens.surfaceBorder,
                    ),
                  tiles[i],
                ],
              ],
            ),
          ),
        ),
        // Compact pills, 3 per row on a phone (§A.5), wrapping beyond that.
        DashboardSection.environment => _tileGrid(
          context,
          tiles,
          maxExtent: 140,
          spacing: 10,
          height: textScaler.scale(112),
        ),
        DashboardSection.other => _tileGrid(
          context,
          tiles,
          height: textScaler.scale(143),
        ),
      };
      slivers.add(
        SliverPadding(
          // Headerless sections carry their own top gap (a header brings its
          // 16 px margin).
          padding: EdgeInsets.fromLTRB(12, label == null ? 12 : 0, 12, 0),
          sliver: sliver,
        ),
      );
    }
    // The Microelements front door (U17): the #10 list-card pinned after
    // every section, full-width, under its own "Microelements" header — the
    // header keeps its footing among the sections and separates it from
    // Environment. Gated here (not inside the tile) so the Settings switch
    // removes the whole section, not just its content; measurements stay
    // stored.
    if (microEnabled) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(child: SectionHeader(l.microTitle)),
        ),
      );
      slivers.add(
        const SliverPadding(
          // The header brings its own 16 px top margin.
          padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
          sliver: SliverToBoxAdapter(child: MicroSummaryTile()),
        ),
      );
    }
  }

  /// One section's tile grid: fixed-size tiles laid out left-to-right, with the
  /// last row **centered when it isn't full** — including a section that is a
  /// single lone tile (an odd 3rd gauge in a 2-column phone grid, or a
  /// non-full last row on a wide tablet). Full rows consume the width exactly,
  /// so `WrapAlignment.center` leaves them flush left, aligned with the
  /// section header.
  ///
  /// Column count and tile width mirror the Material max-extent grid delegate
  /// (`SliverGridDelegateWithMaxCrossAxisExtent`), so full rows keep the exact
  /// geometry a `SliverGrid` would produce. A `Wrap` (rather than a
  /// `SliverGrid`) is what makes per-row centering possible; each section is
  /// small, so building it eagerly costs nothing. [height] is uniform within a
  /// section — a flat fallback tile in a gauge section simply stretches.
  Widget _tileGrid(
    BuildContext context,
    List<Widget> tiles, {
    double maxExtent = 219,
    double spacing = 12,
    required double height,
  }) {
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Same column formula as SliverGridDelegateWithMaxCrossAxisExtent:
          // ceil so tiles never exceed maxExtent, floored at 1, then split the
          // remaining width evenly. Full rows then total exactly `width`, so
          // centering is a no-op for them and only a short last row shifts.
          var columns = (width / (maxExtent + spacing)).ceil();
          if (columns < 1) columns = 1;
          final tileWidth = (width - spacing * (columns - 1)) / columns;
          // Force the Wrap to the full width so `WrapAlignment.center` centers
          // every partial run against the section, not against its own
          // shrink-wrapped width — otherwise a lone tile would collapse to
          // tile width and sit left-aligned.
          return SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: [
                for (final tile in tiles)
                  SizedBox(width: tileWidth, height: height, child: tile),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dashboard tile for a [RatioKind], laid out identically to [_ParameterTile]:
/// title, the latest ratio value colored by its health zone, a trend indicator,
/// and a relative timestamp. Tapping it opens that ratio's history graph.
class _RatioTile extends StatelessWidget {
  const _RatioTile({
    required this.kind,
    required this.points,
    required this.bounds,
    this.stale = false,
  });

  final RatioKind kind;

  /// Ratio series (oldest first). Empty when the ratio can't be computed yet —
  /// a measurement is missing or the denominator is zero — in which case the
  /// tile shows "No readings".
  final List<RatioPoint> points;
  final ZoneBounds bounds;

  /// True when the latest pair of readings doesn't describe a current tank
  /// state (its halves are further apart than [kRatioMaxSkew]): the value is
  /// shown muted instead of zone-colored.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final latest = points.isNotEmpty ? points.last : null;

    // No margin: the grid's padding/spacing fully define the layout.
    return ReefCard(
      onTap: () => context.push('/ratio/${kind.name}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.ratioCardLabel(kind),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          if (latest == null)
            Text(l.noReadings, style: TextStyle(color: hint))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatRatioValue(kind, latest.ratio),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: stale
                        ? hint
                        : ratioZone(
                            kind,
                            bounds,
                            latest.ratio,
                          ).colorOf(context),
                  ),
                ),
                const Spacer(),
                _RatioChangeIndicator(kind: kind, points: points),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            latest == null ? '—' : relativeTimeLabel(l, latest.time),
            style: TextStyle(fontSize: 11, color: hint),
          ),
        ],
      ),
    );
  }
}

/// Trend arrow + change of the displayed ratio versus the previous point,
/// mirroring [_ChangeIndicator] for measurements.
class _RatioChangeIndicator extends StatelessWidget {
  const _RatioChangeIndicator({required this.kind, required this.points});
  final RatioKind kind;
  final List<RatioPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final hint = Theme.of(context).hintColor;
    final now = ratioChartY(kind, points.last.ratio);
    final prev = ratioChartY(kind, points[points.length - 2].ratio);
    if (!now.isFinite || !prev.isFinite) return const SizedBox.shrink();
    final diff = now - prev;
    final icon = diff.abs() < 1e-9
        ? Icons.trending_flat
        : (diff > 0 ? Icons.trending_up : Icons.trending_down);
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: hint),
        const SizedBox(width: 2),
        Text(
          '$sign${formatRatioN(diff.abs())}',
          style: TextStyle(fontSize: 12, color: hint),
        ),
      ],
    );
  }
}

class _ParameterTile extends StatelessWidget {
  const _ParameterTile({
    required this.param,
    required this.history,
    required this.prefs,
    this.trend,
    this.trendHorizon = kTrendDefaultHorizon,
  });

  final TrackedParameter param;
  final List<Reading> history;
  final UnitPrefs prefs;
  final TrendResult? trend;
  final int trendHorizon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = l.paramName(param.paramKey);
    final latest = history.isNotEmpty ? history.first : null;
    final bounds = boundsOf(param);
    final zone = latest != null ? bounds.classify(latest.value) : Zone.unknown;
    final pres = presentationOf(param, prefs);

    // Same as _RatioTile: no margin, the grid owns all spacing.
    return ReefCard(
      onTap: () => context.push('/history/${param.paramKey}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          if (latest == null)
            Text(
              l.noReadings,
              style: TextStyle(color: Theme.of(context).hintColor),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  pres.format(latest.value),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: zone.colorOf(context),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  pres.unitLabel,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                const Spacer(),
                _ChangeIndicator(history: history, pres: pres),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            latest == null ? '—' : relativeTimeLabel(l, latest.takenAt),
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
          if (trend != null) ...[
            const SizedBox(height: 2),
            TrendChip(trend: trend!, horizonDays: trendHorizon),
          ],
        ],
      ),
    );
  }
}

/// Shows the trend direction and numeric change versus the previous reading.
class _ChangeIndicator extends StatelessWidget {
  const _ChangeIndicator({required this.history, required this.pres});
  final List<Reading> history;
  final ParamPresentation pres;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();
    final hint = Theme.of(context).hintColor;
    final diff = history[0].value - history[1].value;
    final IconData icon = diff.abs() < 1e-9
        ? Icons.trending_flat
        : (diff > 0 ? Icons.trending_up : Icons.trending_down);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: hint),
        const SizedBox(width: 2),
        Text(
          pres.formatChange(history[0].value, history[1].value),
          style: TextStyle(fontSize: 12, color: hint),
        ),
      ],
    );
  }
}

/// App-bar widget that shows the active tank and lets the user switch / add.
class TankSelector extends ConsumerWidget {
  const TankSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final active = ref.watch(activeTankProvider);
    // Mockup tank-switcher type (§A.6): 19 px bold + compact chevron, in the
    // `text` token rather than the app bar's default title style.
    final tokens = ReefTokens.of(context);
    final titleStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: tokens.text,
    );
    if (tanks.isEmpty) return Text(l.appTitle, style: titleStyle);

    final selector = PopupMenuButton<int>(
      onSelected: (id) {
        if (id == -1) {
          unawaited(context.push('/tanks'));
        } else {
          unawaited(ref.read(dbProvider).setActiveTank(id));
        }
      },
      itemBuilder: (context) => [
        for (final t in tanks)
          PopupMenuItem(
            value: t.id,
            child: Row(
              children: [
                if (t.id == active?.id)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(t.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: Row(
            children: [
              const Icon(Icons.edit, size: 18),
              const SizedBox(width: 8),
              Text(l.manageTanks),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              active?.name ?? l.appTitle,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 18, color: tokens.text),
        ],
      ),
    );

    // The compact health badge sits beside the selector as its own tap target
    // (inside the popup's child it would be swallowed by the menu gesture).
    final showBadge =
        (ref.watch(healthDisplayProvider).value ?? HealthDisplay.both)
            .showBadge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBadge) ...[
          const TankHealthBadgeCompact(),
          const SizedBox(width: 4),
        ],
        Flexible(child: selector),
      ],
    );
  }
}

class NoTanksView extends ConsumerWidget {
  const NoTanksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final localeCode = ref.watch(localeCodeProvider).value ?? 'system';
    final settings = ref.read(settingsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Let first-run users pick their language before anything else,
            // since the device locale may not match what they want.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 20),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: localeCode,
                  onChanged: (v) => settings.setLocaleCode(v),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(l.languageSystem),
                    ),
                    // Sorted alphabetically by native language name (Latin
                    // scripts first), with the system default pinned on top.
                    DropdownMenuItem(value: 'cs', child: Text(l.languageCzech)),
                    DropdownMenuItem(
                      value: 'de',
                      child: Text(l.languageGerman),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l.languageEnglish),
                    ),
                    DropdownMenuItem(
                      value: 'fr',
                      child: Text(l.languageFrench),
                    ),
                    DropdownMenuItem(
                      value: 'it',
                      child: Text(l.languageItalian),
                    ),
                    DropdownMenuItem(
                      value: 'pl',
                      child: Text(l.languagePolish),
                    ),
                    DropdownMenuItem(
                      value: 'ru',
                      child: Text(l.languageRussian),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Icon(Icons.water, size: 64),
            const SizedBox(height: 16),
            Text(l.welcomeTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.welcomeBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/tanks/new'),
              icon: const Icon(Icons.add),
              label: Text(l.addAquarium),
            ),
            const SizedBox(height: 8),
            // Settings must stay reachable with zero tanks (Settings →
            // Backups → restore is the reinstall path). The bottom bar's
            // Settings tab (U33) is hidden here, so push the standalone
            // route instead.
            TextButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(l.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoParamsView extends StatelessWidget {
  const _NoParamsView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 56),
            const SizedBox(height: 16),
            Text(l.noParamsTracked, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/parameters'),
              icon: const Icon(Icons.add),
              label: Text(l.chooseParameters),
            ),
          ],
        ),
      ),
    );
  }
}
