import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The unified Devices screen (U41): drag-to-reorder within a vendor, and the
/// vendor selector scoping what is shown. The seeded devices carry an **empty
/// address**, so the screen's on-open auto-refresh returns immediately and no
/// socket is opened under `flutter test`.
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

  Future<void> pumpDevices(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicesScreen(),
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

    await pumpDevices(tester, db);
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

    await pumpDevices(tester, db);
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

    await pumpDevices(tester, db);

    expect(find.text('Only pump'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('one vendor means no selector at all', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertReefFactoryDevice(
      identifier: 'RF-solo',
      model: 'RFPM01',
      address: '',
      name: 'Lone meter',
    );

    await pumpDevices(tester, db);

    // A one-choice selector is noise: no All chip, no vendor chip, and no
    // section header either — the page is just the card.
    expect(find.text('All'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Lone meter'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('the vendor selector scopes the page to one brand', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: 'RFPM01',
      address: '',
      name: 'My meter',
    );
    await db.upsertReefBeatDevice(
      identifier: 'RB-1',
      model: 'RSDOSE4',
      address: '',
      name: 'My pump',
    );

    await pumpDevices(tester, db);

    // All: both vendors' cards, each under its own header.
    expect(find.text('My meter'), findsOneWidget);
    expect(find.text('My pump'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3)); // All + two vendors

    await tester.tap(find.widgetWithText(ChoiceChip, 'ReefFactory  1'));
    await settle(tester);

    // Filtered: the other vendor's card is gone, the chips stay.
    expect(find.text('My meter'), findsOneWidget);
    expect(find.text('My pump'), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await unmountApp(tester);
  });

  testWidgets('an empty inventory offers the Add FAB, nothing else', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpDevices(tester, db);

    expect(find.text('No devices yet'), findsOneWidget);
    // No chips, no scope bar, no read-only disclaimer — there is nothing yet
    // to be read-only about.
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.textContaining('Refresh all'), findsNothing);
    // Adding is the host's FAB (U42), which stays put whether the page is
    // empty or full — the empty state no longer carries a button of its own.
    expect(
      find.widgetWithText(FloatingActionButton, 'Add device'),
      findsOneWidget,
    );
    await unmountApp(tester);
  });
}
