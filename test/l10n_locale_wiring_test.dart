import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/notifications.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/calculator/salinity_calculator_screen.dart';
import 'package:reeftracker/main.dart';

import 'fakes/fake_cloud_backup_store.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder —
/// the real app touches it at launch (install fingerprint, auto-backup).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// The notification plugin is the one launch dependency that cannot run under
/// `flutter test` at all (`resolvePlatformSpecificImplementation` throws on an
/// unregistered plugin), and `main.dart` funnels its failures into
/// `FlutterError.reportError`, which fails the test. Swapped for a no-op so the
/// rest of the real launch sequence still runs.
class _SilentNotifications extends ReminderNotifications {
  @override
  Future<void> init({required void Function(String payload) onTap}) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areEnabled() async => true;
}

/// The locale→`Intl.defaultLocale` wiring, asserted through the real app.
///
/// `main.dart` sets `Intl.defaultLocale` in exactly one place — the
/// `MaterialApp.builder` now named [reefAppBuilder] — and everything the user
/// reads as a number goes through it: `formatLocaleNumber`/`formatDoseAmount`
/// read `Intl.defaultLocale` to pick the decimal separator, so in cs/de/fr a
/// dose must render `8,5` and a salinity `35,0`, not `8.5`/`35.0`.
///
/// These tests therefore pump the **real [ReefTrackerApp]** (not `pumpApp`):
/// a harness `MaterialApp` would have to re-declare that builder, and would
/// then only prove the harness right. The launch sequence's platform-only
/// pieces (notifications, the cloud store, `PackageInfo`) are stubbed; the
/// locale path itself — stored setting → `localeProvider` → `MaterialApp` →
/// `reefAppBuilder` → `Intl.defaultLocale` → the rendered digits — is
/// untouched.
void main() {
  late Directory docsDir;
  String? savedIntlLocale;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-locale-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    // `_seedEdition()` reads the running version from the platform channel.
    PackageInfo.setMockInitialValues(
      appName: 'ReefTracker',
      packageName: 'cz.reeftracker.reeftracker',
      version: '0.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    savedIntlLocale = Intl.defaultLocale;
  });

  tearDown(() async {
    // `Intl.defaultLocale` is process-global: leaving it on 'de' would silently
    // re-format every number in every test that runs after this file.
    Intl.defaultLocale = savedIntlLocale;
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  /// Bounded fake-time stepping, never `pumpAndSettle`: the app legitimately
  /// shows a `CircularProgressIndicator` while drift streams load, whose
  /// endless animation keeps scheduling frames (see `router_test.dart`).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app *inside* the test body — the binding's pending-timer
  /// check runs before `addTearDown`, and drift's watched queries plus the
  /// reminder scheduler's debounce keep timers alive until the scope disposes.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Seeds an in-memory database with the stored language set to [localeCode]
  /// and boots the real [ReefTrackerApp] on it.
  Future<AppDatabase> pumpRealApp(
    WidgetTester tester, {
    required String localeCode,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = AppSettings(db);
    // The first-run tour's delayed showcase overlays land after teardown.
    await settings.setTourSeen(true);
    await settings.setLocaleCode(localeCode);
    // `appRouter` is a singleton that keeps its location across pumps, so park
    // it at home — which is also where a real cold start begins. It matters
    // here beyond tidiness: the stored locale arrives from the database one
    // frame *after* the first one, and `main()` covers that by pre-warming
    // `settingsMapProvider` before `runApp` (#24). A test that booted straight
    // onto a locale-sensitive screen would build it in the system language and
    // measure the missing pre-warm rather than the builder.
    appRouter.go('/');
    addTearDown(() => appRouter.go('/'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          reminderNotificationsProvider.overrideWithValue(
            _SilentNotifications(),
          ),
          // Without this the launch backup reaches for `google_sign_in`.
          cloudBackupStoreProvider.overrideWithValue(FakeCloudBackupStore()),
        ],
        child: const ReefTrackerApp(),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    return db;
  }

  /// Opens the salinity calculator, which seeds both of its fields through
  /// `formatLocaleNumber` in `initState` — i.e. it reads `Intl.defaultLocale`
  /// on the first build of the route, which is only correct because the
  /// builder runs above the Navigator.
  Future<void> openSalinityCalculator(WidgetTester tester) async {
    appRouter.go('/calculator/salinity');
    await settle(tester);
    expect(find.byType(SalinityCalculatorScreen), findsOneWidget);
  }

  testWidgets('a stored non-English language reaches the rendered digits '
      '(cs: 35,0 not 35.0)', (tester) async {
    await pumpRealApp(tester, localeCode: 'cs');

    // The builder ran, below the localization delegates.
    expect(Intl.defaultLocale, 'cs');

    await openSalinityCalculator(tester);
    expect(find.text('35,0'), findsOneWidget);
    expect(find.text('35.0'), findsNothing);
    // The derived SG seed too — four decimals, same separator.
    expect(find.text('1,0264'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('English is the control: the same screen renders a dot', (
    tester,
  ) async {
    await pumpRealApp(tester, localeCode: 'en');
    expect(Intl.defaultLocale, 'en');

    await openSalinityCalculator(tester);
    expect(find.text('35.0'), findsOneWidget);
    expect(find.text('35,0'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('every comma-decimal language the app ships renders a comma', (
    tester,
  ) async {
    // The three the row names plus the two remaining comma locales; `en` is
    // covered above as the control.
    for (final code in ['de', 'fr', 'pl', 'ru', 'it']) {
      await pumpRealApp(tester, localeCode: code);
      expect(Intl.defaultLocale, code, reason: code);

      await openSalinityCalculator(tester);
      expect(find.text('35,0'), findsOneWidget, reason: code);
      expect(find.text('35.0'), findsNothing, reason: code);

      await unmountApp(tester);
    }
  });

  testWidgets('a dosing amount on the Dosing tab follows the app language', (
    tester,
  ) async {
    final db = await pumpRealApp(tester, localeCode: 'de');
    final tankId = await db.createTankWithPreset(
      name: 'Reef One',
      type: SetupType.mixed,
    );
    await db.insertDosingEntry(
      DosingEntriesCompanion.insert(
        tankId: tankId,
        product: 'Balling A',
        amount: const Value(8.5),
        amountUnit: const Value('ml'),
        frequency: const Value('daily'),
      ),
    );
    await settle(tester);

    appRouter.go('/?tab=dosing');
    await settle(tester);

    expect(find.text('Balling A'), findsOneWidget);
    expect(find.textContaining('8,5 ml'), findsOneWidget);
    expect(find.textContaining('8.5 ml'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('changing the language at runtime re-runs the builder', (
    tester,
  ) async {
    final db = await pumpRealApp(tester, localeCode: 'en');
    await openSalinityCalculator(tester);
    expect(find.text('35.0'), findsOneWidget);

    // Exactly what the Settings language picker does.
    await AppSettings(db).setLocaleCode('de');
    await settle(tester);
    expect(Intl.defaultLocale, 'de');

    // Re-entering the screen rebuilds its controllers, now in German.
    appRouter.go('/');
    await settle(tester);
    await openSalinityCalculator(tester);
    expect(find.text('35,0'), findsOneWidget);
    expect(find.text('35.0'), findsNothing);

    await unmountApp(tester);
  });
}
