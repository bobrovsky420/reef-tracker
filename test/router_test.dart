import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/hanna_import.dart';
import 'package:reeftracker/domain/icp_import.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/actions/schedule_screen.dart';
import 'package:reeftracker/features/add_reading/add_reading_screen.dart';
import 'package:reeftracker/features/calculator/salinity_calculator_screen.dart';
import 'package:reeftracker/features/calculator/water_change_planner_screen.dart';
import 'package:reeftracker/features/dashboard/dashboard_screen.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/features/dosing/dose_calculator_screen.dart';
import 'package:reeftracker/features/dosing/dosing_edit_screen.dart';
import 'package:reeftracker/features/dosing/dosing_history_screen.dart';
import 'package:reeftracker/features/history/history_screen.dart';
import 'package:reeftracker/features/home/home_shell.dart';
import 'package:reeftracker/features/import/hanna_import_screen.dart';
import 'package:reeftracker/features/manage_parameters/manage_parameters_screen.dart';
import 'package:reeftracker/features/micro/icp_import_screen.dart';
import 'package:reeftracker/features/micro/micro_screen.dart';
import 'package:reeftracker/features/ratio/ratio_edit_screen.dart';
import 'package:reeftracker/features/ratio/ratio_screen.dart';
import 'package:reeftracker/features/settings/backups_screen.dart';
import 'package:reeftracker/features/settings/reminders_screen.dart';
import 'package:reeftracker/features/settings/settings_screen.dart';
import 'package:reeftracker/features/tanks/tanks_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so
/// screens that touch the backup directory can build under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// Regression tests for TODO #1/#2: the `/tanks/:id/edit` and
/// `/parameters/:id/edit` routes must work from the URL alone (deep link,
/// state restoration) — `state.extra` is only an in-app fast path.
/// Plus the T13 coverage: every route builds, in every supported locale.
void main() {
  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-router-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  /// Pumps a bounded amount of fake time in small steps.
  ///
  /// Deliberately NOT [WidgetTester.pumpAndSettle]: the app legitimately shows
  /// a `CircularProgressIndicator` while drift streams load, and its endless
  /// animation keeps scheduling frames, so `pumpAndSettle` never settles and
  /// the test hangs until the 10-minute watchdog (this hung CI too). Stepping
  /// fake time forward fires drift's zero-duration stream timers and lets the
  /// UI rebuild with data, without ever waiting for "no scheduled frames".
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app and flushes the timers that drift's watched queries keep
  /// pending, *inside* the test body — the binding's "A Timer is still
  /// pending" invariant check runs before `addTearDown` callbacks, so a
  /// teardown-time unmount is too late. Call as the last step of every test.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// A fresh in-memory database, ready to seed before the app is pumped.
  Future<AppDatabase> newDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // These tests exercise routing, not the first-run feature tour. Left
    // unseen, the tour fires once a tank exists and its delayed showcase
    // overlay insertions land after navigation/teardown, failing the test.
    await AppSettings(db).setTourSeen(true);
    // Router coverage visits every screen, including grandfathered Pro
    // routes. Use the Founder marker so this routing test exercises those
    // screens; locked direct navigation has dedicated coverage in
    // pro_gate_test.dart (#137).
    await db.setSetting(kLegacyFreeSinceKey, '0.26.0');
    return db;
  }

  /// Boots the real [appRouter] over [db] **without settling** — the caller
  /// decides how much time passes, which is what the cold-start test needs.
  Future<void> pumpRouterAppWith(
    WidgetTester tester,
    AppDatabase db, {
    Locale? locale,
  }) async {
    // The router singleton keeps its location across tests; park it at home
    // so the next test starts from a known state.
    addTearDown(() => appRouter.go('/'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter,
        ),
      ),
    );
  }

  /// Boots the real [appRouter] against an in-memory database and returns the
  /// database for seeding.
  Future<AppDatabase> pumpRouterApp(
    WidgetTester tester, {
    Locale? locale,
  }) async {
    final db = await newDb();
    await pumpRouterAppWith(tester, db, locale: locale);
    await settle(tester);
    return db;
  }

  /// Every static route with the screen it must build (T13). The parameterized
  /// edit routes are covered by their dedicated tests above/below; the list
  /// ends at home so the router singleton is parked for the next iteration.
  final allRoutes = <(String, Type)>[
    ('/tanks', TanksScreen),
    ('/tanks/new', TankEditScreen),
    ('/parameters', ManageParametersScreen),
    ('/add-reading', AddReadingScreen),
    ('/history/alkalinity', HistoryScreen),
    ('/ratio/po4no3/edit', RatioEditScreen),
    ('/dosing/edit', DosingEditScreen),
    ('/dosing/calculator', DoseCalculatorScreen),
    ('/dosing/history', DosingHistoryScreen),
    ('/settings', SettingsScreen),
    ('/settings/backups', BackupsScreen),
    ('/settings/reminders', RemindersScreen),
    ('/schedule', MaintenanceScheduleScreen),
    ('/calculator/salinity', SalinityCalculatorScreen),
    ('/calculator/water-change', WaterChangePlannerScreen),
    ('/', HomeShell),
  ];

  Future<void> visitAllRoutes(WidgetTester tester) async {
    for (final (location, screen) in allRoutes) {
      appRouter.go(location);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: location);
      expect(find.byType(screen), findsOneWidget, reason: location);
    }
  }

  testWidgets(
    '/parameters/:id/edit without extra resolves the param from the DB',
    (tester) async {
      final db = await pumpRouterApp(tester);
      final tankId = await db.createTankWithPreset(
        name: 'A',
        type: SetupType.mixed,
      );
      // A plain get, not `watchTrackedParameters(...).first`: awaiting a drift
      // *stream* inside testWidgets' FakeAsync zone deadlocks — the emission is
      // scheduled on a zero-duration timer that only fires while pumping.
      final params = await db.getTrackedParameters(tankId);
      expect(params, isNotEmpty, reason: 'preset must track parameters');

      appRouter.go('/parameters/${params.first.id}/edit');
      await settle(tester);

      expect(find.byType(ParameterEditScreen), findsOneWidget);
      await unmountApp(tester);
    },
  );

  // Seam S4. The in-app case above navigates from a settled app, so it can
  // never see the load window; this one starts *in* it. `trackedParameters`
  // used to synthesise `data([])` while the tank list was still loading, and
  // `_ResolveById` reads a landed empty list as "no such id" — so the very
  // first frame scheduled a `context.go('/')` and the screen the user asked
  // for never appeared. Reachable from a notification/deep link on a cold
  // start and, in-app, from the microelement bounds editor
  // (`micro_configure_screen.dart`), which pushes this route by id right
  // after creating the tracked row.
  testWidgets('/parameters/:id/edit survives a cold start: no bounce home '
      'before the tracked list lands', (tester) async {
    final db = await newDb();
    final tankId = await db.createTankWithPreset(
      name: 'A',
      type: SetupType.mixed,
    );
    final params = await db.getTrackedParameters(tankId);
    expect(params, isNotEmpty, reason: 'preset must track parameters');

    // Point the router at the deep link BEFORE the app is pumped, so the
    // route builds against providers that have never emitted.
    appRouter.go('/parameters/${params.first.id}/edit');
    await pumpRouterAppWith(tester, db);

    // First frame: nothing has loaded, so the resolver must wait rather than
    // conclude the id is unknown.
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await settle(tester);
    expect(find.byType(ParameterEditScreen), findsOneWidget);
    expect(
      find.byType(HomeShell),
      findsNothing,
      reason: 'the load window must never wipe the requested screen',
    );
    await unmountApp(tester);
  });

  testWidgets('/tanks/:id/edit without extra opens the edit form, not create', (
    tester,
  ) async {
    final db = await pumpRouterApp(tester);
    final tankId = await db.createTankWithPreset(
      name: 'Reef One',
      type: SetupType.mixed,
    );

    appRouter.go('/tanks/$tankId/edit');
    await settle(tester);

    expect(find.byType(TankEditScreen), findsOneWidget);
    // The form is pre-filled with the existing tank, not a blank create form.
    expect(find.text('Reef One'), findsWidgets);
    await unmountApp(tester);
  });

  testWidgets('an unknown :id redirects home instead of crashing', (
    tester,
  ) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/parameters/424242/edit');
    await settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('an unknown route shows the localized error screen with a way '
      'home (T8)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/no/such/route');
    await settle(tester);

    // The localized screen, not go_router's built-in English error page.
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go to home screen'));
    await settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('a garbage ratio type redirects home instead of opening '
      'po4no3 (T8)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    appRouter.go('/ratio/garbage');
    await settle(tester);
    expect(find.byType(RatioScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    // A valid type still opens the ratio screen through the same route.
    appRouter.go('/ratio/po4no3');
    await settle(tester);
    expect(find.byType(RatioScreen), findsOneWidget);
    await unmountApp(tester);
  });

  // The two import previews are the only routes whose builder downcasts
  // `state.extra` onto a *non-nullable* type, so the redirect above them is
  // the entire guard — `/dosing/edit` and `/paywall` cast to nullables and
  // survive a bare link on their own. The identical ratio-route guard is
  // tested right above; this is the missing half of that pattern.
  testWidgets('the import previews redirect without a parsed report in tow '
      '(T8)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

    Future<void> expectBounced(
      String location, {
      Object? extra,
      required Type landsOn,
    }) async {
      appRouter.go(location, extra: extra);
      await settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '$location with extra=$extra',
      );
      expect(find.byType(landsOn), findsOneWidget, reason: location);
    }

    // A bare deep link (notification, restored URL, mistyped link): nothing to
    // preview, so /micro/import falls back to the Microelements screen.
    await expectBounced('/micro/import', landsOn: MicroScreen);
    // A wrong-typed extra is the same case, and the one a refactor produces:
    // pushing the route with the *other* importer's result, or with a raw
    // path string.
    await expectBounced(
      '/micro/import',
      extra: 'C:/reports/icp.csv',
      landsOn: MicroScreen,
    );
    await expectBounced(
      '/micro/import',
      extra: const HannaImportResult(
        meter: 'HI97115',
        location: null,
        rows: [],
        skipped: [],
      ),
      landsOn: MicroScreen,
    );

    // The Hanna preview has no list screen of its own, so it goes home.
    await expectBounced('/import/hanna', landsOn: HomeShell);
    await expectBounced('/import/hanna', extra: 42, landsOn: HomeShell);
    await expectBounced(
      '/import/hanna',
      extra: const IcpImportResult(
        format: IcpImportFormat.faunaMarin,
        values: {},
        skipped: [],
      ),
      landsOn: HomeShell,
    );

    // Positive control: with the right payload both routes open, so the
    // assertions above are about the guard and not about a broken route.
    appRouter.go(
      '/micro/import',
      extra: const IcpImportResult(
        format: IcpImportFormat.faunaMarin,
        values: {'zinc': 0.005},
        skipped: [],
      ),
    );
    await settle(tester);
    expect(find.byType(IcpImportScreen), findsOneWidget);

    appRouter.go(
      '/import/hanna',
      extra: HannaImportResult(
        meter: 'HI97115',
        location: 'Reef',
        rows: [
          HannaReading(
            paramKey: 'alkalinity',
            value: 8.2,
            takenAt: DateTime(2026, 7, 1, 9),
          ),
        ],
        skipped: const [],
      ),
    );
    await settle(tester);
    expect(find.byType(HannaImportScreen), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('U33: the Settings tab opens from the bottom bar and the '
      '?tab=settings deep link, with no app bar and no FAB', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    await settle(tester);

    // Fourth destination present; tapping it shows the settings body inline
    // (no route push — HomeShell stays mounted).
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    // No app bar and no FAB on the Settings tab — only the inline title.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Switching back restores the shared app bar and the per-tab FAB.
    // Exactly ONE here: the checker-scan mini-FAB (U34) shows only for
    // entitled installs, and this bare test install carries no Founder
    // marker — the hidden-when-locked rule is part of what this pins.
    await tester.tap(find.byIcon(Icons.speed_outlined));
    await settle(tester);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // The notification-URL form selects the tab too.
    appRouter.go('/?tab=settings');
    await settle(tester);
    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('U42: the Devices tab appears only with experimental features '
      'on, and hosts the page inline', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    await settle(tester);

    // Off (the default): four destinations and no antenna — the experimental
    // master switch hides every surface, and a permanent tab would be the
    // loudest one.
    expect(find.byIcon(Icons.settings_input_antenna), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(4),
    );

    await AppSettings(db).setExperimentalEnabled(true);
    await settle(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(5),
    );
    await tester.tap(find.byIcon(Icons.settings_input_antenna));
    await settle(tester);

    // Inline in the shell — no route push — with the shared app bar (devices
    // are tank-scoped, so the tank selector stays), which carries the
    // add-device action; the FAB slot holds the bulk read/save actions, and
    // with no devices (and no entitlement) it stays empty.
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(DevicesBody), findsOneWidget);
    expect(find.byType(DevicesScreen), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Add device'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add device'),
      findsNothing,
    );

    // The deep-link form selects it too.
    appRouter.go('/?tab=measurements');
    await settle(tester);
    expect(find.byType(DashboardBody), findsOneWidget);
    appRouter.go('/?tab=devices');
    await settle(tester);
    expect(find.byType(DevicesBody), findsOneWidget);

    // Switching the master switch back off must not leave the bar selecting a
    // destination it no longer shows.
    await AppSettings(db).setExperimentalEnabled(false);
    await settle(tester);
    expect(find.byIcon(Icons.settings_input_antenna), findsNothing);
    expect(find.byType(DashboardBody), findsOneWidget);
    await unmountApp(tester);
  });

  // U42: the fifth destination cut every label's share of the bar by a fifth.
  // At the authored size all seven languages still fit down to a 320 dp phone,
  // but with the system font enlarged the longest ones don't, and `Text`
  // answers that by breaking the word across two lines — which shoves that
  // destination's icon out of line with its four neighbours. So the bar pins
  // its labels to one fixed size and cuts what still cannot fit.
  //
  // The cut is applied to the string, because `NavigationDestination` takes a
  // `String` and `NavigationBar`'s internal `Material` overrides any ambient
  // `DefaultTextStyle` — see `_navBarFixedLabels`. That makes the rule a pure
  // function, testable without laying out the bar (which would prove nothing
  // anyway: widget tests draw every glyph as a square of the font size).
  group('U42: nav-bar label fit', () {
    // Which is exactly what makes the arithmetic below predictable: in the
    // test font every character is `fontSize` wide.
    const style = TextStyle(fontSize: 10);
    String fit(String label, double maxWidth) => fitNavBarLabel(
      label,
      maxWidth: maxWidth,
      style: style,
      direction: TextDirection.ltr,
    );

    test('a label that fits is left alone', () {
      expect(fit('Geräte', 100), 'Geräte');
      // Exactly filling the slot still counts as fitting.
      expect(fit('Geräte', 60), 'Geräte');
    });

    test('a label too long for its slot is cut, not wrapped or ellipsized', () {
      // 45 logical pixels holds four 10-wide characters.
      expect(fit('Einstellungen', 45), 'Eins');
      expect(fit('Einstellungen', 45), isNot(contains('…')));
      expect(fit('Einstellungen', 45), isNot(contains('\n')));
    });

    test('the cut lands on whole characters', () {
      // A slot too narrow for even one character yields nothing rather than
      // half a glyph.
      expect(fit('Dosierung', 4), isEmpty);
      // Two 10-wide characters fit in 25; the third would not, and no part of
      // it is kept.
      expect(fit('Zařízení', 25), 'Za');
      // A character built from a surrogate pair is kept or dropped whole — a
      // half-pair would render as a replacement box.
      final cut = fit('🐟🐟', 15);
      expect(cut.characters, hasLength(1));
      expect(cut.length, 2, reason: 'the pair survives intact');
    });
  });

  testWidgets('U33: with no tanks the welcome screen links the standalone '
      'settings route', (tester) async {
    await pumpRouterApp(tester);

    // No tanks: no bottom bar, so no Settings tab — the welcome view offers
    // its own button that pushes `/settings` (backup restore must stay
    // reachable on a fresh install).
    expect(find.byType(NavigationBar), findsNothing);
    final settingsButton = find.byIcon(Icons.settings_outlined);
    await tester.ensureVisible(settingsButton);
    await tester.tap(settingsButton);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    // The pushed route keeps a back affordance.
    expect(find.byType(BackButton), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('every route builds its screen (T13)', (tester) async {
    final db = await pumpRouterApp(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    await visitAllRoutes(tester);
    await unmountApp(tester);
  });

  testWidgets('every route builds in every supported locale (T13)', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final db = await pumpRouterApp(tester, locale: locale);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await visitAllRoutes(tester);
      await unmountApp(tester);
    }
  });
}
