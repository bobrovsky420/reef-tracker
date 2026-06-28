import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  /// instead of the tile grid. Kept here so it survives tab switches.
  bool _compare = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);
    final hasTanks = tanksAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        // The tank selector stays on both tabs — the actions log is tank-scoped
        // too, and the bottom-nav label already names the current screen.
        title: const TankSelector(),
        actions: [
          // Toggle the Measurements tab between the tile grid and the stacked
          // comparison graphs.
          if (hasTanks && _index == 0)
            IconButton(
              tooltip: _compare ? l.gridView : l.compareView,
              icon: Icon(_compare ? Icons.grid_view : Icons.stacked_line_chart),
              onPressed: () => setState(() => _compare = !_compare),
            ),
          // Dose calculator, contextual to the Dosing tab.
          if (hasTanks && _index == 2)
            IconButton(
              tooltip: l.doseCalcTitle,
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => context.push('/dosing/calculator'),
            ),
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
