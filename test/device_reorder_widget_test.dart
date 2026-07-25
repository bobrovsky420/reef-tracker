import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/reefbeat/reefbeat_screen.dart';
import 'package:reeftracker/features/reeffactory/reeffactory_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Drag-to-reorder on the two device dashboards. The seeded devices carry an
/// **empty address**, so the screens' on-open auto-refresh returns immediately
/// and no socket is opened under `flutter test`.
void main() {
  /// Pumps fake time in small steps — never `pumpAndSettle`, which would hang
  /// on the drift-loading spinner (see the router-test note).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app inside the test body so drift's watched-query timers are
  /// flushed before the binding's pending-timer check.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    AppDatabase db,
    Widget screen,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  /// Device names in persisted card order.
  Future<List<String>> orderOf(AppDatabase db, String kind) async {
    final rows = (await db.getAllDevices()).where((d) => d.kind == kind).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return rows.map(deviceDisplayName).toList();
  }

  /// Drags [handle] down past the card below it and lets the reorder settle.
  Future<void> dragDown(WidgetTester tester, Finder handle) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    // Move in steps: the reorderable list tracks the pointer per frame.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  testWidgets('ReefFactory cards reorder by drag and the order persists', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final n in ['A meter', 'B meter']) {
      await db.upsertReefFactoryDevice(
        identifier: 'RF-$n',
        model: 'RFPM01',
        address: '',
        name: n,
      );
    }

    await pumpScreen(tester, db, const ReefFactoryScreen());
    expect(await orderOf(db, 'reeffactory'), ['A meter', 'B meter']);
    // One handle per card, and only because there are two cards.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

    await dragDown(tester, find.byIcon(Icons.drag_handle).first);

    expect(await orderOf(db, 'reeffactory'), ['B meter', 'A meter']);
    await unmountApp(tester);
  });

  testWidgets('ReefBeat cards reorder by drag and the order persists', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final n in ['A pump', 'B pump']) {
      await db.upsertReefBeatDevice(
        identifier: 'RB-$n',
        model: 'RSDOSE4',
        address: '',
        name: n,
      );
    }

    await pumpScreen(tester, db, const ReefBeatScreen());
    expect(await orderOf(db, 'reefbeat'), ['A pump', 'B pump']);

    await dragDown(tester, find.byIcon(Icons.drag_handle).first);

    expect(await orderOf(db, 'reefbeat'), ['B pump', 'A pump']);
    await unmountApp(tester);
  });

  testWidgets('a single device gets no drag handle', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertReefBeatDevice(
      identifier: 'RB-only',
      model: 'RSDOSE4',
      address: '',
      name: 'Only pump',
    );

    await pumpScreen(tester, db, const ReefBeatScreen());

    expect(find.text('Only pump'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    await unmountApp(tester);
  });
}
