import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is only exposed as a public type through misc.dart in
// riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../domain/ratio.dart';
import 'providers.dart';
import '../features/add_reading/add_reading_screen.dart';
import '../features/calculator/salinity_calculator_screen.dart';
import '../features/dosing/dose_calculator_screen.dart';
import '../features/dosing/dosing_edit_screen.dart';
import '../features/dosing/dosing_history_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_shell.dart';
import '../features/manage_parameters/manage_parameters_screen.dart';
import '../features/ratio/ratio_edit_screen.dart';
import '../features/ratio/ratio_screen.dart';
import '../features/settings/backups_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tanks/tanks_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    GoRoute(path: '/tanks', builder: (context, state) => const TanksScreen()),
    GoRoute(
      path: '/tanks/new',
      builder: (context, state) => const TankEditScreen(),
    ),
    GoRoute(
      path: '/tanks/:id/edit',
      builder: (context, state) {
        // `extra` is the fast path used by in-app navigation; deep links and
        // state restoration carry only the URL, so fall back to resolving the
        // tank by its `:id`.
        final tank = state.extra;
        if (tank is Tank) return TankEditScreen(tank: tank);
        return _ResolveById<Tank>(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
          listenable: tanksProvider,
          idOf: (t) => t.id,
          builder: (t) => TankEditScreen(tank: t),
        );
      },
    ),
    GoRoute(
      path: '/parameters',
      builder: (context, state) => const ManageParametersScreen(),
    ),
    GoRoute(
      path: '/parameters/:id/edit',
      builder: (context, state) {
        final param = state.extra;
        if (param is TrackedParameter) return ParameterEditScreen(param: param);
        return _ResolveById<TrackedParameter>(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
          listenable: trackedParametersProvider,
          idOf: (p) => p.id,
          builder: (p) => ParameterEditScreen(param: p),
        );
      },
    ),
    GoRoute(
      path: '/add-reading',
      builder: (context, state) => const AddReadingScreen(),
    ),
    GoRoute(
      path: '/history/:paramKey',
      builder: (context, state) =>
          HistoryScreen(paramKey: state.pathParameters['paramKey']!),
    ),
    GoRoute(
      path: '/ratio/:type',
      builder: (context, state) =>
          RatioScreen(kind: _ratioKind(state.pathParameters['type'])),
    ),
    GoRoute(
      path: '/ratio/:type/edit',
      builder: (context, state) =>
          RatioEditScreen(kind: _ratioKind(state.pathParameters['type'])),
    ),
    GoRoute(
      path: '/dosing/edit',
      builder: (context, state) =>
          DosingEditScreen(entry: state.extra as DosingEntry?),
    ),
    GoRoute(
      path: '/dosing/calculator',
      builder: (context, state) => const DoseCalculatorScreen(),
    ),
    GoRoute(
      path: '/dosing/history',
      builder: (context, state) => const DosingHistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/backups',
      builder: (context, state) => const BackupsScreen(),
    ),
    GoRoute(
      path: '/calculator/salinity',
      builder: (context, state) => const SalinityCalculatorScreen(),
    ),
  ],
);

/// Resolves a `:type` path segment to a [RatioKind], defaulting to po4no3.
RatioKind _ratioKind(String? type) {
  for (final k in RatioKind.values) {
    if (k.name == type) return k;
  }
  return RatioKind.po4no3;
}

/// Resolves an edit route's target row by its `:id` path parameter when the
/// in-app fast path (`state.extra`) is missing — deep links, state
/// restoration. Shows a spinner while the backing list loads and leaves to
/// the home screen when the id cannot be found.
class _ResolveById<T> extends ConsumerWidget {
  const _ResolveById({
    required this.id,
    required this.listenable,
    required this.idOf,
    required this.builder,
  });

  final int? id;
  final ProviderListenable<AsyncValue<List<T>>> listenable;
  final int Function(T row) idOf;
  final Widget Function(T row) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listenable);
    if (async.isLoading && !async.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    for (final row in async.value ?? const []) {
      if (idOf(row) == id) return builder(row);
    }
    // Unknown id (or a load error surfaced as an empty list): navigating to
    // home beats crashing or opening a form for the wrong target.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/');
    });
    return const Scaffold(body: SizedBox.shrink());
  }
}
