import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../actions/actions_screen.dart';
import '../dashboard/comparison_view.dart';
import '../dashboard/dashboard_screen.dart';
import '../dosing/dosing_screen.dart';

/// Home screen hosting the app's two primary peer destinations — Measurements
/// and Actions — behind a bottom [NavigationBar]. Owns the shared app bar
/// (tank selector + manage-parameters + settings, visible on both tabs) and a
/// per-tab FAB. Tab bodies are kept alive via [IndexedStack] so each preserves
/// its scroll position and state when switching.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  /// On the Measurements tab, whether to show the stacked-graph comparison view
  /// instead of the card grid. Kept here so it survives tab switches.
  bool _compare = false;

  // First-run feature tour (showcaseview). Each key tags a top-bar element the
  // tour spotlights. The dose-calculator icon only exists on the Dosing tab, so
  // the tour runs in two phases: phase 1 (tank → compare → manage params) on the
  // Measurements tab, then it switches to the Dosing tab for phase 2 (the dose
  // calculator) as the final step.
  final GlobalKey _tankTourKey = GlobalKey();
  final GlobalKey _compareTourKey = GlobalKey();
  final GlobalKey _paramsTourKey = GlobalKey();
  final GlobalKey _doseCalcTourKey = GlobalKey();

  /// Guards against re-triggering the tour on every rebuild within a session.
  /// Reset when the "seen" flag flips back to false (a replay request).
  bool _tourStarted = false;

  /// Which leg of the tour is running: 0 = idle, 1 = Measurements-tab steps,
  /// 2 = the dose-calculator step on the Dosing tab. Drives the tab switch in
  /// [onFinish] and the return to Measurements when the tour ends.
  int _tourPhase = 0;

  @override
  void initState() {
    super.initState();
    // Register the showcase controller for this screen's scope. Localized
    // tooltip text/buttons are supplied per-Showcase in build (where
    // AppLocalizations is available).
    ShowcaseView.register(
      blurValue: 1,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        actionGap: 16,
      ),
      // Completing phase 1 switches to the Dosing tab and showcases the dose
      // calculator; completing phase 2 ends the tour and returns to Measurements.
      onFinish: () {
        if (!mounted) return;
        if (_tourPhase == 1) {
          _tourPhase = 2;
          setState(() => _index = 2);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ShowcaseView.get().startShowCase(
              [_doseCalcTourKey],
              delay: const Duration(milliseconds: 350),
            );
          });
        } else {
          _tourPhase = 0;
          _markTourSeen();
          setState(() => _index = 0);
        }
      },
      // Skipping returns to Measurements if we'd already switched to Dosing.
      onDismiss: (_) {
        if (!mounted) return;
        _markTourSeen();
        if (_tourPhase == 2) setState(() => _index = 0);
        _tourPhase = 0;
      },
    );
  }

  @override
  void dispose() {
    ShowcaseView.get().unregister();
    super.dispose();
  }

  /// Persists the "tour seen" flag. Called only when the tour actually ends —
  /// its final phase finishes or it is dismissed — never at start, so a tour
  /// interrupted by a background/rotate/kill still replays on next launch (#16).
  /// The in-session [_tourStarted] guard prevents a duplicate start meanwhile.
  void _markTourSeen() => ref.read(dbProvider).setSetting(kTourSeenKey, 'true');

  /// Starts the top-bar tour once a tank exists. The seen flag is persisted when
  /// the tour ends (see [_markTourSeen]), not here. Phase-1 targets (the compare
  /// toggle) only exist on the Measurements tab, so we force [_index] back to it
  /// before starting — this also makes "Replay tour" work no matter which tab
  /// was last open.
  void _maybeStartTour(bool hasTanks) {
    final seen = ref.watch(tourSeenProvider).value ?? true;
    // A replay resets the flag to false; allow the tour to fire again.
    ref.listen(tourSeenProvider, (_, next) {
      if (next.value == false) _tourStarted = false;
    });
    if (seen || !hasTanks || _tourStarted) return;
    _tourStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tourPhase = 1;
      if (_index != 0) setState(() => _index = 0);
      ShowcaseView.get().startShowCase(
        [_tankTourKey, _compareTourKey, _paramsTourKey],
        delay: const Duration(milliseconds: 300),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);
    final hasTanks = tanksAsync.value?.isNotEmpty ?? false;
    _maybeStartTour(hasTanks);

    final cs = Theme.of(context).colorScheme;
    final skipAction = TooltipActionButton(
      type: TooltipDefaultActionType.skip,
      name: l.tourSkip,
      backgroundColor: Colors.transparent,
      textStyle: TextStyle(color: cs.onSurfaceVariant),
    );
    TooltipActionButton nextAction(String name) => TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: name,
          backgroundColor: cs.primary,
          textStyle: TextStyle(color: cs.onPrimary),
        );
    Widget tourStep(
      GlobalKey key,
      String title,
      String description,
      String nextLabel,
      Widget child,
    ) =>
        Showcase(
          key: key,
          title: title,
          description: description,
          tooltipActions: [skipAction, nextAction(nextLabel)],
          tooltipBackgroundColor: cs.surfaceContainerHighest,
          textColor: cs.onSurface,
          titleTextStyle: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
          child: child,
        );

    return Scaffold(
      appBar: AppBar(
        // The tank selector stays on both tabs — the actions log is tank-scoped
        // too, and the bottom-nav label already names the current screen.
        title: tourStep(
          _tankTourKey,
          l.tourTankTitle,
          l.tourTankDesc,
          l.tourNext,
          const TankSelector(),
        ),
        actions: [
          // Toggle the Measurements tab between the card grid and the stacked
          // comparison graphs.
          if (hasTanks && _index == 0)
            tourStep(
              _compareTourKey,
              l.tourCompareTitle,
              l.tourCompareDesc,
              l.tourNext,
              IconButton(
                tooltip: _compare ? l.gridView : l.compareView,
                icon:
                    Icon(_compare ? Icons.grid_view : Icons.stacked_line_chart),
                onPressed: () => setState(() => _compare = !_compare),
              ),
            ),
          // Dose calculator, contextual to the Dosing tab. The tour switches to
          // this tab to spotlight it as its final step.
          if (hasTanks && _index == 2)
            tourStep(
              _doseCalcTourKey,
              l.tourDoseCalcTitle,
              l.tourDoseCalcDesc,
              l.tourDone,
              IconButton(
                tooltip: l.doseCalcTitle,
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () => context.push('/dosing/calculator'),
              ),
            ),
          tourStep(
            _paramsTourKey,
            l.tourParamsTitle,
            l.tourParamsDesc,
            l.tourNext,
            IconButton(
              tooltip: l.manageParameters,
              icon: const Icon(Icons.tune),
              onPressed: () => context.push('/parameters'),
            ),
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
          if (tanks.isEmpty) return const NoTanksView();
          return IndexedStack(
            index: _index,
            children: [
              _compare ? const ComparisonBody() : const DashboardBody(),
              const ActionsBody(),
              const DosingBody(),
            ],
          );
        },
      ),
      bottomNavigationBar: hasTanks
          ? NavigationBar(
              // Default M3 height is 80; trim it down for a more compact bar
              // while still leaving room for the always-visible labels.
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.speed_outlined),
                  selectedIcon: const Icon(Icons.speed),
                  label: l.measurements,
                ),
                NavigationDestination(
                  // Keep the outlined glyph even when selected.
                  icon: const Icon(Icons.fact_check_outlined),
                  selectedIcon: const Icon(Icons.fact_check_outlined),
                  label: l.actions,
                ),
                NavigationDestination(
                  // Keep the outlined glyph even when selected.
                  icon: const Icon(Icons.science_outlined),
                  selectedIcon: const Icon(Icons.science_outlined),
                  label: l.dosing,
                ),
              ],
            )
          : null,
      floatingActionButton: hasTanks ? _buildFab(context, l) : null,
    );
  }

  Widget _buildFab(BuildContext context, AppLocalizations l) {
    if (_index == 0) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/add-reading'),
        icon: const Icon(Icons.add),
        label: Text(l.addReading),
      );
    }
    if (_index == 1) {
      return FloatingActionButton.extended(
        onPressed: () => showAddActionSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.addAction),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => context.push('/dosing/edit'),
      icon: const Icon(Icons.add),
      label: Text(l.addSupplement),
    );
  }
}
