// Screenshot harness for the user guide (docs/guide/).
// Seeds the on-device DB with the showcase dataset (test/tool/showcase_data.dart),
// then drives the app to each screen documented in the guide and captures a
// screenshot. Unlike the store harness (screenshots_test.dart) this one visits
// many more secondary screens (forms, settings sub-pages, calculators).
//
// Run via:
//   flutter drive --driver=test_driver/guide_screenshot_driver.dart \
//     --target=integration_test/guide_screenshots_test.dart -d <device>
// Raw captures land in build/guide_shots/; resize into docs/img before
// publishing via scripts/resize_guide_shots.ps1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/main.dart';

import '../test/tool/showcase_data.dart';

Future<void> _seedDatabase() async {
  final db = AppDatabase();
  await seedShowcaseData(db);
  await db.close();
}

/// Scripted ReefFactory meters answering at the showcase-seeded addresses, so
/// the `/reeffactory` cards fill with live-looking values without hardware.
class _FakeRfLink implements RfDeviceLink {
  @override
  Future<RfSnapshot> readOnce(String host) async => switch (host) {
    '192.168.1.21' => const RfSnapshot(
      serial: 'RFSG012351184',
      modelPrefix: 'RFSG01',
      modelName: 'salinity',
      modelDisplayName: 'Salinity Guardian',
      readings: [
        RfReading('salinity', 35.1, 'ppt'),
        RfReading('temperature', 25.8, '°C'),
      ],
    ),
    '192.168.1.22' => const RfSnapshot(
      serial: 'RFPM012348027',
      modelPrefix: 'RFPM01',
      modelName: 'pH',
      modelDisplayName: 'pH Monitor',
      readings: [RfReading('ph', 8.24, '')],
    ),
    _ => throw const RfLinkException(RfLinkError.unreachable),
  };
}

/// Scripted ReefBeat devices (a ReefDose 4 mid-afternoon through its schedule
/// and a healthy ReefATO+) for the `/reefbeat` cards.
class _FakeRbLink implements RbDeviceLink {
  @override
  Future<RbSnapshot> readOnce(String host) async => switch (host) {
    '192.168.1.31' => const RbDoseSnapshot(
      info: RbDeviceInfo(
        hwType: 'reef-dosing',
        hwModel: 'RSDOSE4',
        hwid: 'ec62609ab3f0',
      ),
      status: RbDoseStatus(
        batteryLevel: 'high',
        heads: [
          RbDoseHead(
            number: 1,
            supplement: 'Foundation A (Ca)',
            autoDosedToday: 10.4,
            dosesToday: 16,
            dailyDoses: 24,
            dailyDose: 15,
            remainingDays: 21,
          ),
          RbDoseHead(
            number: 2,
            supplement: 'Foundation B (KH)',
            autoDosedToday: 17.1,
            dosesToday: 16,
            dailyDoses: 24,
            dailyDose: 25,
            remainingDays: 12,
          ),
          RbDoseHead(
            number: 3,
            supplement: 'Foundation C (Mg)',
            autoDosedToday: 3.4,
            dosesToday: 8,
            dailyDoses: 12,
            dailyDose: 5,
            remainingDays: 48,
          ),
          RbDoseHead(
            number: 4,
            supplement: 'NO3:PO4-X',
            enabled: false,
            dailyDoses: 0,
          ),
        ],
      ),
    ),
    '192.168.1.32' => const RbAtoSnapshot(
      info: RbDeviceInfo(
        hwType: 'reef-ato',
        hwModel: 'RSATO+',
        hwid: 'ec626089c144',
      ),
      status: RbAtoStatus(
        waterLevelRaw: 'desired_level_2',
        todayFills: 4,
        todayVolumeMl: 620,
        dailyVolumeAvgMl: 1450,
        volumeLeftMl: 16000,
        daysTillEmpty: 11,
        temperatureC: 25.6,
      ),
    ),
    '192.168.1.33' => const RbControlSnapshot(
      info: RbDeviceInfo(
        hwType: 'reef-control',
        hwModel: 'RSCONTROLPRO',
        hwid: 'ec6260control',
      ),
      status: RbControlStatus(
        mode: 'auto',
        isInternetConnected: true,
        cableConnected: true,
        probes: [
          RbControlProbe(
            type: 'ec',
            name: 'ReefSense EC',
            status: 'ok',
            ppt: 35.0,
            sg: 1.0264,
            temperatureC: 25.5,
          ),
          RbControlProbe(
            type: 'ph',
            name: 'ReefSense pH',
            status: 'ok',
            value: 8.18,
            measurementUnit: 'pH',
            temperatureC: 25.4,
          ),
          RbControlProbe(
            type: 'orp',
            name: 'ReefSense ORP',
            status: 'ok',
            value: 378,
            measurementUnit: 'mV',
          ),
          RbControlProbe(
            type: 'leak',
            name: 'Leak detector',
            status: 'ok',
            detected: false,
          ),
        ],
      ),
    ),
    _ => throw const RbLinkException(RbLinkError.unreachable),
  };

  // The guide screenshots never open the dosing-queue sheet, so this only has
  // to exist — an empty day is the honest answer for a scripted device.
  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async => const [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture guide screenshots', (tester) async {
    // Render one frame before any platform-channel work: channel replies can
    // be queued until the first frame on Android (flutter#72872), and the
    // seeder's path_provider lookup otherwise risks awaiting forever.
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF000000)));
    await tester.pump();
    debugPrint('guide: seeding…');
    await _seedDatabase();
    debugPrint('guide: seeded, starting app');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rfDeviceLinkProvider.overrideWithValue(_FakeRfLink()),
          rbDeviceLinkProvider.overrideWithValue(_FakeRbLink()),
        ],
        child: const ReefTrackerApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('guide: app settled, converting surface');
    await binding.convertFlutterSurfaceToImage();
    debugPrint('guide: surface converted');

    // Bounded settle: a stuck animation on one screen must not eat the
    // 10-minute default timeout and kill the whole run.
    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 600),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );
      } catch (_) {}
    }

    Future<void> shot(String name) async {
      await settle();
      debugPrint('guide: capturing $name');
      await binding.takeScreenshot(name);
      debugPrint('guide: captured $name');
    }

    Future<void> tapIcon(IconData icon) async {
      final f = find.byIcon(icon);
      expect(f, findsWidgets, reason: 'icon $icon not found');
      await tester.tap(f.first);
      await settle();
    }

    // Keep secondary screens on a real navigation stack so their back affordance
    // matches the in-app path. Explicit target assertions and an extra stable
    // frame prevent a raced push from leaving a stale shot of the parent tab.
    Future<void> locationShot({
      required String path,
      required String name,
      required String visibleText,
      required String returnPath,
    }) async {
      debugPrint('guide: pushing $path');
      final pushed = appRouter.push(path);
      await tester.pump();
      await settle();
      await tester.pump(const Duration(seconds: 1));
      await settle();
      expect(find.text(visibleText), findsWidgets);
      await binding.takeScreenshot(name);
      debugPrint('guide: captured $name');
      appRouter.pop();
      await tester.pump();
      await settle();
      await pushed;
      if (appRouter.routeInformationProvider.value.uri.toString() !=
          returnPath) {
        appRouter.go(returnPath);
      }
      await settle();
    }

    // --- Measurements tab ---------------------------------------------------
    await shot('dashboard');

    // Dark-theme variant of the dashboard, shown in the guide's Settings &
    // personalization section. Flipped through the app's own provider so the
    // watching settings stream rebuilds MaterialApp, then reverted.
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(ReefTrackerApp)),
      listen: false,
    ).read(settingsProvider);
    await settings.setThemeMode(AppThemeMode.dark);
    await shot('dashboard-dark');
    await settings.setThemeMode(AppThemeMode.system);
    await settle();

    await tapIcon(Icons.stacked_line_chart); // compare view
    await shot('compare');
    await tapIcon(Icons.grid_view); // back to the grid

    await locationShot(
      path: '/add-reading',
      name: 'add-reading',
      visibleText: 'Add reading',
      returnPath: '/',
    );
    await locationShot(
      path: '/history/alkalinity',
      name: 'history',
      visibleText: 'Alkalinity',
      returnPath: '/',
    );
    await locationShot(
      path: '/ratio/po4no3',
      name: 'ratio',
      visibleText: 'PO₄ : NO₃ ratio',
      returnPath: '/',
    );
    await locationShot(
      path: '/micro',
      name: 'micro',
      visibleText: 'Microelements',
      returnPath: '/',
    );
    await locationShot(
      path: '/micro/add',
      name: 'micro-add',
      visibleText: 'Microelement measurements',
      returnPath: '/',
    );
    await locationShot(
      path: '/tanks',
      name: 'tanks',
      visibleText: 'Aquariums',
      returnPath: '/',
    );
    await locationShot(
      path: '/parameters',
      name: 'parameters',
      visibleText: 'Parameters',
      returnPath: '/',
    );

    // --- Devices tab -------------------------------------------------------
    // Experimental is enabled by the showcase seed, so capture the real
    // bottom-nav destination rather than the legacy pushed /devices route.
    await tapIcon(Icons.settings_input_antenna);
    await shot('devices');

    await tester.tap(find.textContaining('ReefFactory').first);
    await settle();
    await shot('reeffactory');

    await tester.tap(find.textContaining('Red Sea').first);
    await settle();
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 1200),
      1600,
    );
    await settle();
    await shot('reefbeat');
    final reefControl = find.text('ReefControl Pro');
    for (var swipe = 0; swipe < 3 && reefControl.evaluate().isEmpty; swipe++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -700),
      );
      await settle();
    }
    expect(reefControl, findsWidgets);
    await settle();
    await shot('reefcontrol');

    // --- Actions tab --------------------------------------------------------
    await tapIcon(Icons.fact_check_outlined);
    await shot('actions');
    await locationShot(
      path: '/schedule',
      name: 'schedule',
      visibleText: 'Maintenance schedule',
      returnPath: '/?tab=actions',
    );
    await locationShot(
      path: '/ro',
      name: 'ro',
      visibleText: 'Reverse osmosis unit',
      returnPath: '/?tab=actions',
    );

    // --- Dosing tab ---------------------------------------------------------
    await tapIcon(Icons.science_outlined);
    await shot('dosing');
    await locationShot(
      path: '/dosing/history',
      name: 'dosing-history',
      visibleText: 'Dosing history',
      returnPath: '/?tab=dosing',
    );
    await locationShot(
      path: '/dosing/calculator',
      name: 'dose-calculator',
      visibleText: 'Dose calculator',
      returnPath: '/?tab=dosing',
    );
    await locationShot(
      path: '/dosing/calculator?mode=correction',
      name: 'dose-correction',
      visibleText: 'Dose calculator',
      returnPath: '/?tab=dosing',
    );
    await locationShot(
      path: '/calculator/salinity',
      name: 'salinity',
      visibleText: 'Salinity calculator',
      returnPath: '/?tab=dosing',
    );

    // --- Settings tab -------------------------------------------------------
    await tapIcon(Icons.settings_outlined);
    await shot('settings');
    await locationShot(
      path: '/settings/wall',
      name: 'wall-settings',
      visibleText: 'Wall display',
      returnPath: '/?tab=settings',
    );
    await settings.setThemeMode(AppThemeMode.light);
    await settle();
    await locationShot(
      path: '/wall',
      name: 'wall',
      visibleText: 'Hold anywhere to exit',
      returnPath: '/?tab=settings',
    );
    await settings.setThemeMode(AppThemeMode.dark);
    await settle();
    await locationShot(
      path: '/wall',
      name: 'wall-dark',
      visibleText: 'Hold anywhere to exit',
      returnPath: '/?tab=settings',
    );
    await settings.setThemeMode(AppThemeMode.system);
    await settle();
    await locationShot(
      path: '/settings/backups',
      name: 'backups',
      visibleText: 'Automatic backups',
      returnPath: '/?tab=settings',
    );
    await locationShot(
      path: '/settings/reminders',
      name: 'reminders',
      visibleText: 'Reminders',
      returnPath: '/?tab=settings',
    );
    await locationShot(
      path: '/settings/import',
      name: 'import-sources',
      visibleText: 'Measurement import',
      returnPath: '/?tab=settings',
    );

    // Leave the app on the Measurements tab so the emulator is demo-ready.
    await tapIcon(Icons.speed_outlined);
  });
}
