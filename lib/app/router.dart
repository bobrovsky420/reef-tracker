import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../features/add_reading/add_reading_screen.dart';
import '../features/calculator/salinity_calculator_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/history/history_screen.dart';
import '../features/manage_parameters/manage_parameters_screen.dart';
import '../features/ratio/ratio_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tanks/tanks_screen.dart';
import '../features/water_change/water_change_screen.dart';

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
      path: '/ratio',
      builder: (context, state) => const RatioScreen(),
    ),
    GoRoute(
      path: '/water-changes',
      builder: (context, state) => const WaterChangeScreen(),
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
