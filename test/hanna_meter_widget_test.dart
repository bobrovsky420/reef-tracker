import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/hanna/hanna_meter_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fake_hanna_link.dart';

/// Widget tests for the live-measurement confirm step (U33): dropping a value
/// the user doesn't trust, and sending it back to the meter for another pass.
/// The session's own paths are covered in `hanna_meter_session_test.dart`;
/// these pin what actually reaches the database.
/// Pump discipline (bounded settle, in-body unmount) per router_test.dart.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('reeftracker_hanna_meter');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    // audioplayers has no implementation under `flutter test`: constructing a
    // player throws on its global event channel, asynchronously, past the
    // screen's own try/catch. Silence the channels so the per-result beep is
    // a no-op here instead of a test failure.
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers/events/$kHannaBeepPlayerId',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  tearDown(() async {
    // Best-effort: Windows can still hold a handle in the just-torn-down
    // test, and a locked scratch directory is no reason to fail one — the
    // OS reclaims %TEMP% regardless.
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// Bounded settle. The session mixes both clocks — real stream deliveries
  /// and reply waits, plus timers (the tank-list collector's 1200 ms quiet
  /// window) created inside FakeAsync — so this pumps to mount and start the
  /// work, opens a real window, then pumps past the longest fake timer.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Hosts the screen behind a pushed route so its post-save `context.pop()`
  /// has somewhere to go.
  Future<(AppDatabase, FakeHannaMeterLink)> pumpMeter(
    WidgetTester tester,
  ) async {
    // Tall phone-like viewport: the whole results step fits without scrolling.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    final link = FakeHannaMeterLink();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(path: '/meter', builder: (_, _) => const HannaMeterScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          hannaMeterLinkFactoryProvider.overrideWithValue(() => link),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    unawaited(router.push('/meter'));
    await settle(tester);
    return (db, link);
  }

  /// Runs alkalinity + calcium through to the confirm step. Calcium is the
  /// later of the two readings — the watermark assertions lean on that.
  Future<void> measureTwo(WidgetTester tester, FakeHannaMeterLink link) async {
    await tester.tap(find.text('Alkalinity'));
    await tester.tap(find.text('Calcium (Ca)'));
    await settle(tester);
    await tester.tap(find.text('Start measurements'));
    await settle(tester);
    link.emit(hannaResultFrame(2002, '8.1', '20260721101500'));
    await settle(tester);
    link.emit(hannaResultFrame(2011, '417', '20260721103000'));
    await settle(tester);
  }

  testWidgets('an unchecked result is left out of the save, but the watermark '
      'still covers it', (tester) async {
    try {
      final (db, link) = await pumpMeter(tester);
      await measureTwo(tester, link);
      expect(find.text('8.1 dKH'), findsOneWidget);
      expect(find.text('417 ppm'), findsOneWidget);
      expect(find.text('Save 2 readings'), findsOneWidget);

      // The calcium cuvette was contaminated — drop that value.
      await tester.tap(find.text('Calcium (Ca)'));
      await settle(tester);
      expect(find.text('Save 1 reading'), findsOneWidget);

      await tester.tap(find.text('Save 1 reading'));
      await settle(tester);

      final readings = await db.getAllReadings();
      expect(readings, hasLength(1));
      expect(readings.single.paramKey, 'alkalinity');
      expect(readings.single.value, closeTo(8.1, 1e-9));
      // The rejected calcium reading is still in the meter's own log, so the
      // watermark has to cover it or a later CSV import brings it back.
      final source = (await db.getAllImportSources()).single;
      expect(source.importedUpTo, DateTime(2026, 7, 21, 10, 30));
      expect(find.text('home'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a marked result goes back to the meter and its new value '
      'replaces the old one', (tester) async {
    try {
      final (db, link) = await pumpMeter(tester);
      await measureTwo(tester, link);

      // ↻ on the calcium row only.
      final calciumRow = find
          .ancestor(of: find.text('Calcium (Ca)'), matching: find.byType(InkWell))
          .first;
      await tester.tap(
        find.descendant(
          of: calciumRow,
          matching: find.byTooltip('Measure again'),
        ),
      );
      await settle(tester);
      expect(find.text('Will be measured again'), findsOneWidget);
      // Marking excludes it, so only alkalinity is left to save.
      expect(find.text('Save 1 reading'), findsOneWidget);

      await tester.tap(find.text('Measure 1 again'));
      await settle(tester);
      // The runner lists the pass, not the whole session.
      expect(find.text('Measuring the selected parameters again.'),
          findsOneWidget);
      expect(find.text('Calcium (Ca)'), findsOneWidget);
      expect(find.text('Alkalinity'), findsNothing);

      link.emit(hannaResultFrame(2011, '430', '20260721110000'));
      await settle(tester);

      // Back on the confirm step: the new value, what it replaced, and the
      // row checked again without the user having to do it.
      expect(find.text('430 ppm'), findsOneWidget);
      expect(find.textContaining('was 417 ppm'), findsOneWidget);
      expect(find.text('Save 2 readings'), findsOneWidget);

      await tester.tap(find.text('Save 2 readings'));
      await settle(tester);

      final readings = await db.getAllReadings();
      expect(readings, hasLength(2));
      final calcium = readings.firstWhere((r) => r.paramKey == 'calcium');
      expect(calcium.value, closeTo(430, 1e-9));
      expect(calcium.takenAt, DateTime(2026, 7, 21, 11));
      final source = (await db.getAllImportSources()).single;
      expect(source.importedUpTo, DateTime(2026, 7, 21, 11));
    } finally {
      await unmountApp(tester);
    }
  });
}
