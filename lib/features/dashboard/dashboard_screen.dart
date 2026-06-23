import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_chip.dart';

/// Home screen: active-tank selector + grid of parameter status tiles.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _TankSelector(),
        actions: [
          IconButton(
            tooltip: l.manageParameters,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/parameters'),
          ),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: tanksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tanks) {
          if (tanks.isEmpty) return const _NoTanksView();
          return const _DashboardBody();
        },
      ),
      floatingActionButton: tanksAsync.value?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/add-reading'),
              icon: const Icon(Icons.add),
              label: Text(l.addReading),
            ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trackedAsync = ref.watch(trackedParametersProvider);
    final readingsAsync = ref.watch(tankReadingsProvider);

    return trackedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
      data: (tracked) {
        final enabled = tracked.where((t) => t.enabled).toList();
        if (enabled.isEmpty) return const _NoParamsView();
        final readings = readingsAsync.value ?? const [];
        final prefs = ref.watch(unitPrefsProvider);

        // Latest readings per parameter (for value + trend).
        final byParam = <String, List<Reading>>{};
        for (final r in readings) {
          (byParam[r.paramKey] ??= []).add(r); // already newest-first
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            mainAxisExtent: 150,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: enabled.length,
          itemBuilder: (context, i) {
            final param = enabled[i];
            final history = byParam[param.paramKey] ?? const [];
            return _ParameterTile(
                param: param, history: history, prefs: prefs);
          },
        );
      },
    );
  }
}

class _ParameterTile extends StatelessWidget {
  const _ParameterTile(
      {required this.param, required this.history, required this.prefs});

  final TrackedParameter param;
  final List<Reading> history;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = l.paramName(param.paramKey);
    final latest = history.isNotEmpty ? history.first : null;
    final bounds = boundsOf(param);
    final zone = latest != null ? bounds.classify(latest.value) : Zone.unknown;
    final pres = presentationOf(param, prefs);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${param.paramKey}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  ZoneChip(zone, compact: true),
                ],
              ),
              const Spacer(),
              if (latest == null)
                Text(l.noReadings,
                    style: TextStyle(color: Theme.of(context).hintColor))
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
                          color: zone.color),
                    ),
                    const SizedBox(width: 4),
                    Text(pres.unitLabel,
                        style: TextStyle(color: Theme.of(context).hintColor)),
                    const Spacer(),
                    _TrendIcon(history: history),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                latest == null ? '—' : _relativeTime(l, latest.takenAt),
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({required this.history});
  final List<Reading> history;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();
    final diff = history[0].value - history[1].value;
    if (diff.abs() < 1e-9) {
      return Icon(Icons.trending_flat,
          size: 18, color: Theme.of(context).hintColor);
    }
    return Icon(diff > 0 ? Icons.trending_up : Icons.trending_down,
        size: 18, color: Theme.of(context).hintColor);
  }
}

String _relativeTime(AppLocalizations l, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l.timeJustNow;
  if (d.inMinutes < 60) return l.timeMinAgo(d.inMinutes);
  if (d.inHours < 24) return l.timeHoursAgo(d.inHours);
  if (d.inDays < 7) return l.timeDaysAgo(d.inDays);
  return DateFormat.yMMMd().format(t);
}

/// App-bar widget that shows the active tank and lets the user switch / add.
class _TankSelector extends ConsumerWidget {
  const _TankSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final active = ref.watch(activeTankProvider);
    if (tanks.isEmpty) return Text(l.appTitle);

    return PopupMenuButton<int>(
      onSelected: (id) {
        if (id == -1) {
          context.push('/tanks');
        } else {
          ref.read(dbProvider).setActiveTank(id);
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
          child: Row(children: [
            const Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text(l.manageTanks),
          ]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(active?.name ?? l.appTitle,
                overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _NoTanksView extends StatelessWidget {
  const _NoTanksView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water, size: 64),
            const SizedBox(height: 16),
            Text(l.welcomeTitle,
                style: Theme.of(context).textTheme.titleLarge),
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
