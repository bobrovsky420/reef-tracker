import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../actions/actions_screen.dart';
import '../dashboard/dashboard_screen.dart';

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
            children: const [DashboardBody(), ActionsBody()],
          );
        },
      ),
      bottomNavigationBar: hasTanks
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_outlined),
                  selectedIcon: const Icon(Icons.grid_view),
                  label: l.measurements,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history),
                  label: l.actions,
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
    return FloatingActionButton.extended(
      onPressed: () => showAddActionSheet(context, ref),
      icon: const Icon(Icons.add),
      label: Text(l.addAction),
    );
  }
}
