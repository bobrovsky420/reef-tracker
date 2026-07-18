import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/dashboard_sections.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/ratio.dart';
import '../../domain/trend.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/insights_card.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tank_health_badge.dart';
import '../../widgets/trend_view.dart';
import '../../widgets/zone_visuals.dart';
import '../micro/micro_summary_tile.dart';

/// One built dashboard card plus both ordering keys, so the classic and
/// grouped layouts share a single tile-construction pass (see [DashboardBody]):
/// [groupedKey] drives the sectioned layout (#6), [flatOrder] the original
/// single user-ordered grid.
typedef _DashEntry = ({
  DashboardSection section,
  DashboardSortKey groupedKey,
  double flatOrder,
  Widget tile,
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
          entries.add((
            section: sectionOfParam(param.paramKey),
            groupedKey: paramSortKey(param.paramKey, param.displayOrder),
            flatOrder: param.displayOrder.toDouble(),
            tile: _ParameterTile(
              param: param,
              history: byParam[param.paramKey] ?? const [],
              prefs: prefs,
              trend: trends[param.paramKey],
              trendHorizon: trendHorizon,
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
          entries.add((
            section: DashboardSection.ratios,
            groupedKey: ratioSortKey(kind, row),
            flatOrder: ratioRowOrder(kind, row),
            tile: _RatioTile(
              kind: kind,
              points: series,
              bounds: ratioBounds(kind, row),
              stale: stale,
            ),
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

  /// Classic layout: the original single grid mixing measurements and ratios
  /// in one user-managed order, with the Microelements tile (U17) pinned as
  /// the last cell. All future visual work targets the grouped layout instead.
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
      if (microEnabled) const MicroSummaryTile(),
    ];
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        sliver: _tileGrid(context, tiles),
      ),
    );
  }

  /// Grouped layout (#6): one section per non-empty group, each under its
  /// header, in the enum's fixed order; a section with nothing to show renders
  /// nothing at all, header included. The `other` bucket (unknown legacy keys)
  /// and the pinned Microelements tile are headerless.
  void _appendGrouped(
    BuildContext context,
    AppLocalizations l,
    List<Widget> slivers,
    List<_DashEntry> entries, {
    required bool microEnabled,
  }) {
    // Sorting by the composite key (section rank first) then partitioning keeps
    // each section's tiles in their within-section display order.
    final sorted = [...entries]
      ..sort((a, b) => a.groupedKey.compareTo(b.groupedKey));
    final bySection = <DashboardSection, List<Widget>>{};
    for (final e in sorted) {
      (bySection[e.section] ??= []).add(e.tile);
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
      slivers.add(
        SliverPadding(
          // Headerless sections carry their own top gap (a header brings its
          // 16 px margin).
          padding: EdgeInsets.fromLTRB(12, label == null ? 12 : 0, 12, 0),
          sliver: _tileGrid(context, tiles),
        ),
      );
    }
    // The Microelements front door (U17): one summary tile pinned after every
    // section, under its own "Microelements" header. The header is visually
    // redundant (the section is always a single card) but gives it the same
    // footing as the other sections and separates it from Environment. Gated
    // here (not inside the tile) so the Settings switch removes the whole
    // section, not just its content; measurements stay stored.
    if (microEnabled) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(child: SectionHeader(l.microTitle)),
        ),
      );
      slivers.add(
        SliverPadding(
          // The header brings its own 16 px top margin.
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          sliver: _tileGrid(context, const [MicroSummaryTile()]),
        ),
      );
    }
  }

  /// One section's tile grid: fixed-size tiles laid out left-to-right, with the
  /// last row **centered when it isn't full** — including a section that is a
  /// single lone tile (e.g. the Microelements card, or an odd 3rd tile in a
  /// 2-column phone grid, or a non-full last row on a wide tablet). Full rows
  /// consume the width exactly, so `WrapAlignment.center` leaves them flush
  /// left, aligned with the section header.
  ///
  /// Column count and tile width mirror the Material max-extent grid delegate
  /// (`SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 219)`), so
  /// full rows keep the exact geometry the pre-centering `SliverGrid` produced.
  /// A `Wrap` (rather than a `SliverGrid`) is what makes per-row centering
  /// possible; each section is small (≤ ~4 tiles), so building it eagerly costs
  /// nothing. The tiles themselves are unchanged.
  Widget _tileGrid(BuildContext context, List<Widget> tiles) {
    const spacing = 12.0;
    const maxExtent = 219.0;
    // The tile is mostly stacked text, so its height must grow with the system
    // font scale or it clips at 1.3–2.0× (#44).
    final height = MediaQuery.textScalerOf(context).scale(143);
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
          // shrink-wrapped width — otherwise a lone tile (e.g. Microelements)
          // would collapse to tile width and sit left-aligned.
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
