import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is only exposed as a public type through misc.dart in
// riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../domain/hanna_import.dart';
import '../domain/icp_import.dart';
import '../domain/ratio.dart';
import '../domain/supplement_catalog.dart';
import '../features/actions/schedule_screen.dart';
import '../features/add_reading/add_reading_screen.dart';
import '../features/calculator/salinity_calculator_screen.dart';
import '../features/dosing/dose_calculator_screen.dart';
import '../features/dosing/dosing_edit_screen.dart';
import '../features/dosing/dosing_history_screen.dart';
import '../features/dosing/manual_dose_edit_screen.dart';
import '../features/hanna/hanna_meter_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_shell.dart';
import '../features/import/hanna_import_screen.dart';
import '../features/import/import_sources_screen.dart';
import '../features/manage_parameters/manage_parameters_screen.dart';
import '../features/micro/icp_import_screen.dart';
import '../features/micro/micro_add_screen.dart';
import '../features/micro/micro_configure_screen.dart';
import '../features/micro/micro_screen.dart';
import '../features/ratio/ratio_edit_screen.dart';
import '../features/ratio/ratio_screen.dart';
import '../features/ro/ro_screen.dart';
import '../features/scan/checker_scan_screen.dart';
import '../features/settings/backups_screen.dart';
import '../features/settings/reminders_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tanks/tanks_screen.dart';
import '../l10n/app_localizations.dart';
import '../widgets/reef_card.dart';
import 'providers.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      // `?tab=measurements|actions|dosing|settings` selects a bottom-nav
      // tab — used by reminder notification taps, which can only carry a URL.
      builder: (context, state) =>
          HomeShell(tab: state.uri.queryParameters['tab']),
    ),
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
      redirect: _unknownRatioTypeToHome,
      builder: (context, state) =>
          RatioScreen(kind: _ratioKind(state.pathParameters['type'])!),
    ),
    GoRoute(
      path: '/ratio/:type/edit',
      redirect: _unknownRatioTypeToHome,
      builder: (context, state) =>
          RatioEditScreen(kind: _ratioKind(state.pathParameters['type'])!),
    ),
    GoRoute(
      path: '/dosing/edit',
      builder: (context, state) =>
          DosingEditScreen(entry: state.extra as DosingEntry?),
    ),
    GoRoute(
      path: '/dosing/calculator',
      // `?element=<key>` opens on that element (history-screen entry point);
      // `?mode=correction` starts in correction mode. Unknown element keys
      // are dropped rather than crashing on a garbage deep link (T8).
      builder: (context, state) {
        final element = state.uri.queryParameters['element'];
        return DoseCalculatorScreen(
          initialElement: kDosingElementKeys.contains(element) ? element : null,
          startInCorrection: state.uri.queryParameters['mode'] == 'correction',
        );
      },
    ),
    GoRoute(
      path: '/dosing/history',
      builder: (context, state) => const DosingHistoryScreen(),
    ),
    GoRoute(
      path: '/dosing/manual',
      // `extra` is either an existing row to edit or a prefill draft from the
      // dose calculator's correction mode.
      builder: (context, state) {
        final extra = state.extra;
        return ManualDoseEditScreen(
          dose: extra is ManualDose ? extra : null,
          draft: extra is ManualDoseDraft ? extra : null,
        );
      },
    ),
    GoRoute(
      // Standalone pushed Settings, used only from the no-tanks welcome
      // screen; with tanks present Settings is the home shell's fourth tab
      // (U33, `/?tab=settings`).
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/backups',
      builder: (context, state) => const BackupsScreen(),
    ),
    GoRoute(
      path: '/settings/reminders',
      builder: (context, state) => const RemindersScreen(),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const MaintenanceScheduleScreen(),
    ),
    GoRoute(path: '/ro', builder: (context, state) => const RoScreen()),
    GoRoute(path: '/micro', builder: (context, state) => const MicroScreen()),
    GoRoute(
      path: '/micro/add',
      builder: (context, state) => const MicroAddScreen(),
    ),
    GoRoute(
      path: '/micro/configure',
      builder: (context, state) => const MicroConfigureScreen(),
    ),
    GoRoute(
      path: '/micro/import',
      // Only reachable with a parsed report in tow — a bare deep link has
      // nothing to preview (same guard style as the ratio routes, T8).
      redirect: (context, state) =>
          state.extra is IcpImportResult ? null : '/micro',
      builder: (context, state) =>
          IcpImportScreen(result: state.extra as IcpImportResult),
    ),
    GoRoute(
      path: '/import/hanna',
      // Only reachable with a parsed file in tow — a bare deep link has
      // nothing to preview (same guard style as /micro/import, T8).
      redirect: (context, state) =>
          state.extra is HannaImportResult ? null : '/',
      builder: (context, state) =>
          HannaImportScreen(result: state.extra as HannaImportResult),
    ),
    GoRoute(
      path: '/settings/import',
      builder: (context, state) => const ImportSourcesScreen(),
    ),
    GoRoute(
      // Hanna checker live measurement (U33, experimental): connect →
      // select → run → save, all inside one screen so the BLE session
      // survives every step.
      path: '/hanna/measure',
      builder: (context, state) => const HannaMeterScreen(),
    ),
    GoRoute(
      // Checker camera scan (U34, experimental): model picker → viewfinder
      // → confirm, all inside one screen so the camera session survives
      // every step.
      path: '/hanna/scan',
      builder: (context, state) => const CheckerScanScreen(),
    ),
    GoRoute(
      path: '/calculator/salinity',
      builder: (context, state) => const SalinityCalculatorScreen(),
    ),
  ],
  // Unknown routes (a stale or mistyped deep link) land on a localized error
  // screen instead of go_router's built-in English-only page (T8).
  errorBuilder: (context, state) => const _RouteNotFoundScreen(),
);

/// Resolves a `:type` path segment to a [RatioKind], or null when the segment
/// names no known ratio (a garbage deep link) — the route then redirects home
/// instead of silently opening po4no3 (T8).
RatioKind? _ratioKind(String? type) {
  for (final k in RatioKind.values) {
    if (k.name == type) return k;
  }
  return null;
}

String? _unknownRatioTypeToHome(BuildContext context, GoRouterState state) =>
    _ratioKind(state.pathParameters['type']) == null ? '/' : null;

/// Localized "page not found" screen for unknown routes, with a way back —
/// the error page is otherwise a navigational dead end on a bad deep link.
class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Content in a `ReefCard`, button on the #18 FilledButton theme
    // (REDESIGN #25 rider).
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ReefCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.routeNotFoundBody, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: Text(l10n.routeNotFoundGoHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    for (final row in async.value ?? const <Never>[]) {
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
