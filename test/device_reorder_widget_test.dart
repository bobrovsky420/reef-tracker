import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/devices/device_card_reorder.dart';
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
    final rows =
        (await db.getAllDevices()).where((d) => d.kind == kind).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return rows.map(deviceDisplayName).toList();
  }

  /// Holds [target] until its card lifts, then drags it past the card below.
  Future<void> longPressDragDown(
    WidgetTester tester,
    Finder target, {
    bool inspectIndicator = false,
  }) async {
    final card = find.ancestor(of: target, matching: find.byType(Card)).first;
    final restingCardRect = tester.getRect(card);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 600));

    final indicator = find.byKey(deviceCardDragIndicatorKey);
    expect(indicator, findsOneWidget);
    if (inspectIndicator) {
      // The only visible reorder affordance is the active drag badge: a 40 dp
      // circle centered across, and centered vertically on, the card's top
      // edge. Allow a little movement for the proxy's lift/scale animation.
      expect(tester.getSize(indicator), const Size.square(40));
      expect(
        tester.getCenter(indicator).dx,
        moreOrLessEquals(restingCardRect.center.dx, epsilon: 1),
      );
      expect(
        tester.getCenter(indicator).dy,
        moreOrLessEquals(restingCardRect.top, epsilon: 4),
      );
      final badge = tester.widget<Material>(indicator);
      expect(badge.shape, isA<CircleBorder>());
      final iconFinder = find.descendant(
        of: indicator,
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(iconFinder, findsOneWidget);
      expect(tester.widget<Icon>(iconFinder).semanticLabel, 'Reorder');
    }

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
    // Resting cards have no permanent reorder affordance.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await longPressDragDown(
      tester,
      find.text('A meter'),
      inspectIndicator: true,
    );

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

    await longPressDragDown(tester, find.text('A pump'));

    expect(await orderOf(db, 'reefbeat'), ['B pump', 'A pump']);
    await unmountApp(tester);
  });

  testWidgets('a single device has no active drag listener', (tester) async {
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
    final listener = tester.widget<ReorderableDelayedDragStartListener>(
      find.byType(ReorderableDelayedDragStartListener),
    );
    expect(listener.enabled, isFalse);
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

    // Matched on the vendor name rather than the whole localized chip label
    // ("ReefFactory · 1"), so a change to the separator can't quietly break
    // this. Only one chip starts with the brand, and `tap` would throw on
    // more than one anyway.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            ((w.label as Text).data ?? '').startsWith('ReefFactory'),
      ),
    );
    await settle(tester);

    // Filtered: the other vendor's card is gone, the chips stay.
    expect(find.text('My meter'), findsOneWidget);
    expect(find.text('My pump'), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await unmountApp(tester);
  });

  testWidgets('the brand-reorder sheet\'s handles are labelled for TalkBack', (
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
    // One device per vendor, so the cards carry no handles of their own and
    // every handle counted below belongs to the sheet.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await tester.tap(find.byIcon(Icons.swap_vert));
    await settle(tester);

    expect(find.text('Reorder brands'), findsOneWidget);
    // The sheet's only affordance: it must name itself, or the ordering that
    // decides Save-all precedence is unreachable without sight. Counted as
    // "all of them", not a fixed number — the sheet lists every known brand,
    // so a new vendor must not be able to slip in unlabelled either.
    final handles = find.byIcon(Icons.drag_handle);
    final labelled = find.byWidgetPredicate(
      (w) =>
          w is Icon &&
          w.icon == Icons.drag_handle &&
          w.semanticLabel == 'Reorder',
    );
    expect(handles, findsAtLeastNWidgets(2));
    expect(labelled.evaluate().length, handles.evaluate().length);

    await unmountApp(tester);
  });

  testWidgets('an empty inventory offers the app-bar add action, nothing '
      'else', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpDevices(tester, db);

    expect(find.text('No devices yet'), findsOneWidget);
    // No chips, no scope line, no read-only disclaimer — there is nothing yet
    // to be read-only about.
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.textContaining('Refresh all'), findsNothing);
    // Adding sits in the host's app bar, which stays put whether the page is
    // empty or full; the FAB slot holds the bulk actions, and an empty
    // inventory has nothing for them to act on.
    expect(find.byTooltip('Add device'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await unmountApp(tester);
  });
}
