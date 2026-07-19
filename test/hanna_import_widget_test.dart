import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/app/router.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/hanna_import.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/import/hanna_import_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the Hanna Lab import (U32): the preview screen's
/// first-import/up-to-date states, the import + undo round-trip against a
/// real database, and the Pro gate on the Measurements-tab overflow entry.
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

/// A one-session export (four tests on 19 Jul) plus one older reading.
const _csv =
    'Meter,HI97115\n'
    'Sample Location,200G2\n'
    'Reading,Unit,Method,Date,Status,Note\n'
    '0.18,ppm PO4,Phosphate Marine ULR,19/07/2026 13:38:13,,\n'
    '11.9,ppm NO3,Nitrate Marine HR,19/07/2026 13:32:45,,\n'
    '417,ppm Ca,Calcium Marine,19/07/2026 13:15:36,,\n'
    '7.6,dKH,Alkalinity Marine,19/07/2026 13:08:57,,\n'
    '8.1,pH,pH Marine,17/07/2026 10:26:57,,\n';

void main() {
  final result = parseHannaCsv(_csv);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  group('preview screen', () {
    /// Hosts the preview behind a pushed route so its post-import
    /// `context.pop()` has somewhere to go.
    Future<(AppDatabase, GoRouter)> pumpPreview(WidgetTester tester) async {
      // The import button sits at the bottom of the lazy list — a phone-like
      // tall viewport keeps the whole preview on-screen without scrolling.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/preview',
            builder: (_, _) => HannaImportScreen(result: result),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      unawaited(router.push('/preview'));
      await settle(tester);
      return (db, router);
    }

    testWidgets('first import shows the file header, the cutoff row and all '
        'sessions', (tester) async {
      try {
        await pumpPreview(tester);
        expect(find.text('HI97115 · “200G2”'), findsOneWidget);
        // First import → the start-date row defaults to everything.
        expect(find.text('Everything'), findsOneWidget);
        // SectionHeader renders its label uppercased.
        expect(find.text('5 NEW READINGS'), findsOneWidget);
        expect(find.text('Import 5 readings'), findsOneWidget);
        // Session values render formatted.
        expect(find.text('417 ppm'), findsOneWidget);
        expect(find.text('7.6 dKH'), findsOneWidget);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('import inserts session groups, writes the watermark, and '
        'undo restores everything', (tester) async {
      try {
        final (db, _) = await pumpPreview(tester);
        await tester.tap(find.text('Import 5 readings'));
        await settle(tester);

        // Rows landed with their file timestamps, one group per session.
        final readings = await db.getAllReadings();
        expect(readings, hasLength(5));
        final groups = {for (final r in readings) r.groupId};
        expect(groups, hasLength(2), reason: 'two sessions → two groups');
        expect(
          readings.map((r) => r.takenAt),
          contains(DateTime(2026, 7, 19, 13, 38, 13)),
        );
        final source = (await db.getAllImportSources()).single;
        expect(source.location, '200G2');
        expect(source.importedUpTo, DateTime(2026, 7, 19, 13, 38, 13));

        // The result sheet is up; Undo rolls the whole import back.
        expect(find.text('Imported 5 readings'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await settle(tester);
        expect(await db.getAllReadings(), isEmpty);
        expect(await db.getAllImportSources(), isEmpty);
        // The screen popped back home after the sheet closed.
        expect(find.text('home'), findsOneWidget);
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('an up-to-date file short-circuits to the all-imported state', (
      tester,
    ) async {
      try {
        final (db, router) = await pumpPreview(tester);
        // Import once, close the sheet.
        await tester.tap(find.text('Import 5 readings'));
        await settle(tester);
        await tester.tap(find.text('Close'));
        await settle(tester);
        expect((await db.getAllReadings()).length, 5);

        // Re-open the same file: nothing new.
        unawaited(router.push('/preview'));
        await settle(tester);
        expect(
          find.text('Everything in this file is already imported.'),
          findsOneWidget,
        );
        expect(find.text('Already imported: 5'), findsOneWidget);
        expect(find.textContaining('Import 5'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });
  });

  group('overflow-menu gate (U19)', () {
    late Directory docsDir;
    setUp(() async {
      docsDir = await Directory.systemTemp.createTemp('reeftracker-hanna-');
      PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    });
    tearDown(() async {
      if (await docsDir.exists()) await docsDir.delete(recursive: true);
    });

    /// Boots the real app shell (the entry lives in HomeShell's overflow
    /// menu on the Measurements tab) — the pro_gate_test recipe.
    Future<void> pumpShellAndOpenMenu(
      WidgetTester tester, {
      String? legacyFreeSince,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      if (legacyFreeSince != null) {
        await db.setSetting(kLegacyFreeSinceKey, legacyFreeSince);
      }
      await AppSettings(db).setTourSeen(true);
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      addTearDown(() => appRouter.go('/'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Import measurements'));
      await settle(tester);
    }

    testWidgets('a non-entitled install gets the Pro dialog, not the source '
        'sheet', (tester) async {
      try {
        await pumpShellAndOpenMenu(tester); // no marker -> standard edition
        expect(find.text('Pro feature'), findsOneWidget);
        expect(
          find.text('Choose the app or meter the file comes from.'),
          findsNothing,
        );
      } finally {
        await unmountApp(tester);
      }
    });

    testWidgets('a Founder install reaches the source picker '
        '(grandfathered)', (tester) async {
      try {
        await pumpShellAndOpenMenu(tester, legacyFreeSince: '0.26.0');
        expect(
          find.text('Choose the app or meter the file comes from.'),
          findsOneWidget,
        );
        expect(find.text('Pro feature'), findsNothing);
      } finally {
        await unmountApp(tester);
      }
    });
  });
}
