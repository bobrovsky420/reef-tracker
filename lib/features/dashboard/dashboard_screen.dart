import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/ratio.dart';
import '../../domain/trend.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/tank_health_badge.dart';
import '../../widgets/trend_view.dart';
import '../../widgets/zone_visuals.dart';
import '../micro/micro_summary_tile.dart';

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

        // Build all dashboard cards — measurement tiles and ratio tiles — into
        // one list sharing a single display order, then render them together so
        // ratios look and reorder exactly like measurements.
        final items = <({double order, Widget tile})>[];
        // Core parameters only: microelements (U17) live behind the summary
        // tile appended below, not as individual dashboard tiles.
        for (final param in tracked.where(
          (t) => t.enabled && isCoreParam(t.paramKey),
        )) {
          items.add((
            order: param.displayOrder.toDouble(),
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
          items.add((
            order: ratioRowOrder(kind, row),
            tile: _RatioTile(
              kind: kind,
              points: series,
              bounds: ratioBounds(kind, row),
              stale: stale,
            ),
          ));
        }
        items.sort((a, b) => a.order.compareTo(b.order));

        if (items.isEmpty) return const _NoParamsView();

        // The Microelements front door (U17): one summary tile pinned after
        // the reorderable cards — it advertises the panel; before any
        // measurement it reads "No readings". Gated here (not inside the
        // tile) so the Settings switch removes the grid *cell*, not just its
        // content; measurements stay stored while hidden.
        if (ref.watch(microEnabledProvider).value ?? true) {
          items.add((order: double.infinity, tile: const MicroSummaryTile()));
        }

        final display =
            ref.watch(healthDisplayProvider).value ?? HealthDisplay.both;

        // One scroll view so the health card scrolls together with the tiles.
        return CustomScrollView(
          slivers: [
            if (display.showCard)
              const SliverToBoxAdapter(child: TankHealthHeader()),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 219,
                  // The tile is mostly stacked text, so its height must grow
                  // with the system font scale or it clips at 1.3–2.0× (#44).
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(143),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => items[i].tile,
              ),
            ),
          ],
        );
      },
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

    return Card(
      // The grid's padding/spacing fully define the layout; the default Card
      // margin would inset tiles 4px inside their cells, leaving the row of
      // tiles narrower than the health header card above.
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/ratio/${kind.name}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.ratioCardLabel(kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
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
                            : ratioZone(kind, bounds, latest.ratio).color,
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
        ),
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

    return Card(
      // Same as _RatioTile: let the grid own all spacing.
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${param.paramKey}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
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
                        color: zone.color,
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
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(height: 2),
                TrendChip(trend: trend!, horizonDays: trendHorizon),
              ],
            ],
          ),
        ),
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
    if (tanks.isEmpty) return Text(l.appTitle);

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
            ),
          ),
          const Icon(Icons.arrow_drop_down),
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
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l.languageEnglish),
                    ),
                    DropdownMenuItem(value: 'cs', child: Text(l.languageCzech)),
                    DropdownMenuItem(
                      value: 'de',
                      child: Text(l.languageGerman),
                    ),
                    DropdownMenuItem(
                      value: 'ru',
                      child: Text(l.languageRussian),
                    ),
                    DropdownMenuItem(
                      value: 'pl',
                      child: Text(l.languagePolish),
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
