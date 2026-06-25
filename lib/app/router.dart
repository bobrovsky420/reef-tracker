import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../domain/ratio.dart';
import '../features/actions/actions_screen.dart';
import '../features/add_reading/add_reading_screen.dart';
import '../features/calculator/salinity_calculator_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/history/history_screen.dart';
import '../features/manage_parameters/manage_parameters_screen.dart';
import '../features/ratio/ratio_edit_screen.dart';
import '../features/ratio/ratio_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tanks/tanks_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/tanks',
      builder: (context, state) => const TanksScreen(),
    ),
    GoRoute(
      path: '/tanks/new',
      builder: (context, state) => const TankEditScreen(),
    ),
    GoRoute(
      path: '/tanks/:id/edit',
      builder: (context, state) =>
          TankEditScreen(tank: state.extra as Tank?),
    ),
    GoRoute(
      path: '/parameters',
      builder: (context, state) => const ManageParametersScreen(),
    ),
    GoRoute(
      path: '/parameters/:id/edit',
      builder: (context, state) =>
          ParameterEditScreen(param: state.extra as TrackedParameter),
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
      path: '/actions',
      builder: (context, state) => const ActionsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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
