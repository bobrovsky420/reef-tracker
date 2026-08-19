import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/icp_import.dart';
import 'package:reeftracker/domain/pro_features.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/micro/icp_import_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Widget tests for the ICP report import preview (U17 phase 2) — the screen
/// half of the importer. The parsing half lives in `icp_import_test.dart`, so
/// every fixture here is a hand-built [IcpImportResult]: what is under test is
/// the wiring from a parsed report to the rows that land in the database.
///
/// The load-bearing detail is the sample id: it is prefilled into the note,
/// and the re-import duplicate guard keys on finding it there. Both halves are
/// asserted end-to-end (import, come back with the same file, get warned)
/// rather than by looking at the text field alone.
///
/// Pump discipline (bounded settle, in-body unmount, never `pumpAndSettle`
/// while the drift streams are still loading) per `router_test.dart`.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// A three-value Fauna Marin report: one core parameter, one major and one
  /// trace element, so all three section cards render.
  IcpImportResult report({
    DateTime? reportDate,
    String? sampleId = 'FM-4711',
  }) => IcpImportResult(
    format: IcpImportFormat.faunaMarin,
    values: const {'calcium': 420.0, 'sodium': 10800.0, 'iron': 0.002},
    skipped: const [],
    reportDate: reportDate,
    sampleId: sampleId,
  );

  /// Hosts the preview behind a pushed route so its post-import
  /// `context.pop()` has somewhere to go, and returns the router so a second
  /// import of the same file can be driven through the same screen.
  Future<(AppDatabase, GoRouter, int)> pumpPreview(
    WidgetTester tester,
    IcpImportResult result, {
    bool entitled = true,
  }) async {
    // The import button sits at the bottom of the list — a phone-like tall
    // viewport keeps the whole preview on-screen without scrolling.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/preview',
          builder: (_, _) => IcpImportScreen(result: result),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          proCapabilityProvider(
            ProCapabilityBoundary.icpImportCommit,
          ).overrideWithValue(entitled),
        ],
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
    return (db, router, tankId);
  }

  testWidgets('the report date is the default sample date and the sample id '
      'is prefilled into the note', (tester) async {
    try {
      final at = DateTime(2026, 3, 14, 9, 30);
      await pumpPreview(tester, report(reportDate: at));

      // The date row offers the analysis date from the file, with the hint
      // that it is only a default.
      expect(
        find.textContaining(DateFormat.yMMMd().format(at)),
        findsOneWidget,
      );
      expect(
        find.textContaining('Change it to the day you took'),
        findsOneWidget,
      );
      // The note carries the sample id — this is what the duplicate guard
      // later keys on.
      expect(find.text('ICP sample FM-4711'), findsOneWidget);
      // All three sections rendered, one per category present in the report.
      expect(find.text('CORE PARAMETERS'), findsOneWidget);
      expect(find.text('MAJOR ELEMENTS'), findsOneWidget);
      expect(find.text('TRACE ELEMENTS'), findsOneWidget);
      expect(find.text('CONTAMINANTS'), findsNothing);
      expect(find.text('Import 3 values'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a report dated in the future falls back to now', (tester) async {
    try {
      final now = DateTime.now();
      final future = now.add(const Duration(days: 400));
      await pumpPreview(tester, report(reportDate: future));

      expect(
        find.textContaining(DateFormat.yMMMd().format(future)),
        findsNothing,
        reason: 'a lab date in the future must never seed the sample date',
      );
      expect(
        find.textContaining(DateFormat.yMMMd().format(now)),
        findsOneWidget,
      );
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a report with no date at all falls back to now', (tester) async {
    try {
      await pumpPreview(tester, report());
      expect(
        find.textContaining(DateFormat.yMMMd().format(DateTime.now())),
        findsOneWidget,
      );
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('importing writes one reading group at the chosen date, tracks '
      'every parameter, and carries the note', (tester) async {
    try {
      final at = DateTime(2026, 3, 14, 9, 30);
      final (db, _, tankId) = await pumpPreview(tester, report(reportDate: at));

      await tester.tap(find.text('Import 3 values'));
      await settle(tester);

      final readings = await db.getAllReadings();
      expect(readings, hasLength(3));
      expect(
        {for (final r in readings) r.groupId},
        hasLength(1),
        reason: 'a report is one reading group, like one manual entry',
      );
      expect(readings.every((r) => r.groupId != null), isTrue);
      expect(readings.every((r) => r.tankId == tankId), isTrue);
      expect(readings.every((r) => r.takenAt == at), isTrue);
      expect(readings.every((r) => r.note == 'ICP sample FM-4711'), isTrue);
      expect(
        {for (final r in readings) r.paramKey: r.value},
        {'calcium': 420.0, 'sodium': 10800.0, 'iron': 0.002},
      );

      // Every imported parameter is now tracked, so the values have somewhere
      // to show up (the same step the manual micro form takes).
      final tracked = await db.getTrackedParameters(tankId);
      expect({
        for (final t in tracked) t.paramKey,
      }, containsAll(<String>['calcium', 'sodium', 'iron']));

      expect(find.text('Saved 3 readings.'), findsOneWidget);
      // The screen popped back after the save.
      expect(find.text('home'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a valid direct payload cannot commit for Standard', (
    tester,
  ) async {
    try {
      final (db, _, _) = await pumpPreview(tester, report(), entitled: false);

      await tester.tap(find.text('Import 3 values'));
      await settle(tester);

      expect(find.text('Pro feature'), findsOneWidget);
      expect(await db.getAllReadings(), isEmpty);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('re-importing the same report is caught by the sample id in the '
      'note, and cancelling writes nothing', (tester) async {
    try {
      final result = report(reportDate: DateTime(2026, 3, 14, 9, 30));
      final (db, router, _) = await pumpPreview(tester, result);

      await tester.tap(find.text('Import 3 values'));
      await settle(tester);
      expect((await db.getAllReadings()), hasLength(3));

      // Same file again — the note written by the first import is the only
      // trace of it, and the guard has to find the sample id in there.
      unawaited(router.push('/preview'));
      await settle(tester);
      await tester.tap(find.text('Import 3 values'));
      await settle(tester);

      expect(find.text('Sample already imported?'), findsOneWidget);
      expect(find.textContaining('FM-4711'), findsWidgets);
      expect(
        (await db.getAllReadings()),
        hasLength(3),
        reason: 'nothing is written while the question is open',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(
        (await db.getAllReadings()),
        hasLength(3),
        reason: 'cancelling the duplicate warning abandons the import',
      );

      // Overriding it is possible — a lab does re-issue a report — and then
      // every value is duplicated, which is exactly what the guard exists to
      // make deliberate.
      await tester.tap(find.text('Import 3 values'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Import anyway'));
      await settle(tester);
      expect((await db.getAllReadings()), hasLength(6));
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a report without a sample id (ZIMS) has no duplicate guard', (
    tester,
  ) async {
    try {
      final result = IcpImportResult(
        format: IcpImportFormat.zims,
        values: const {'calcium': 420.0},
        skipped: const [],
        reportDate: DateTime(2026, 3, 14, 9, 30),
      );
      final (db, router, _) = await pumpPreview(tester, result);

      // No sample id → no note to prefill.
      expect(find.text('Import 1 value'), findsOneWidget);
      await tester.tap(find.text('Import 1 value'));
      await settle(tester);
      final first = await db.getAllReadings();
      expect(first, hasLength(1));
      expect(first.single.note, isNull);

      unawaited(router.push('/preview'));
      await settle(tester);
      await tester.tap(find.text('Import 1 value'));
      await settle(tester);
      expect(find.text('Sample already imported?'), findsNothing);
      expect((await db.getAllReadings()), hasLength(2));
    } finally {
      await unmountApp(tester);
    }
  });
}
