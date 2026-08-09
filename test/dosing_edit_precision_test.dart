import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';
import 'package:reeftracker/features/dosing/dosing_edit_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Editing a dosing plan must not change the plan by accident (Phase 3, S8).
///
/// Two failures lived on the same save path:
/// * the amount was seeded into the edit field through the **display**
///   formatter (one decimal), so re-saving a fraction plan round-tripped
///   `0.25 → 0.3` — which then looked dose-affecting and forked a history
///   segment carrying a 20 % too high dose;
/// * a rename of a custom vendor is *not* dose-affecting, so it takes the
///   in-place branch — which wrote only four fields and dropped the new name.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Unmounts the app so drift's pending stream timers are flushed before the
  // binding's timer check (see router_test.dart / widget-test-pitfalls).
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Boots an in-memory database with one tank and pushes the edit screen for
  /// [entryOf]'s row on top of a host route, so `_save`'s `pop()` has somewhere
  /// to go.
  Future<AppDatabase> pumpEditScreen(
    WidgetTester tester,
    Future<void> Function(AppDatabase db, int tankId) seed,
  ) async {
    // Phone width, but tall enough for the whole form (product / dosage /
    // schedule cards, note and Save) to be laid out without scrolling — a
    // `ListView` only builds its visible children.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await seed(db, tankId);
    final entry = (await db.getAllDosingEntries()).single;

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          navigatorKey: nav,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The host route watches the active tank, as the Dosing tab under
          // the real edit route does: `_save` *reads* the provider, and a
          // provider nobody has subscribed to yet answers a cold read with
          // "loading" — i.e. no tank, and a silently skipped save.
          home: Consumer(
            builder: (_, ref, _) {
              ref.watch(activeTankProvider);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await settle(tester);
    // Not awaited: the route's future only completes when the screen pops.
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => DosingEditScreen(entry: entry)),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('a note-only edit preserves 0.25 ml and does not fork a history '
      'segment', (tester) async {
    final db = await pumpEditScreen(tester, (db, tankId) async {
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(tankId),
          vendor: const Value('Fauna Marin'),
          product: const Value('Trace B'),
          elementKey: const Value('iron'),
          amount: const Value(0.25),
          amountUnit: Value(DoseUnit.ml.name),
          basis: Value(DoseBasis.perDay.name),
          frequency: Value(DoseFrequency.daily.name),
        ),
      );
    });

    // Observed while mounted, asserted after the unmount (see unmountApp): the
    // field is seeded from the stored value, not from the one-decimal display
    // format that would show — and re-parse as — "0.3".
    final seededExact = find.text('0.25').evaluate().isNotEmpty;
    final seededRounded = find.text('0.3').evaluate().isNotEmpty;

    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'switched to the 5 ml syringe',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    final rows = await db.getAllDosingEntries();
    await unmountApp(tester);

    // One row still: a cosmetic edit is saved in place, so the plan keeps its
    // single active segment and its exact dose. A rounded round trip would
    // instead end this segment and open a second one holding 0.3 ml.
    expect(rows, hasLength(1));
    expect(rows.single.amount, 0.25);
    expect(rows.single.state, DosingState.active.name);
    expect(rows.single.endedAt, isNull);
    expect(rows.single.note, 'switched to the 5 ml syringe');
    expect(seededExact, isTrue, reason: 'the exact dose is offered for edit');
    expect(seededRounded, isFalse, reason: 'no display rounding in the field');
  });

  testWidgets('a custom-vendor rename survives the in-place save path', (
    tester,
  ) async {
    final db = await pumpEditScreen(tester, (db, tankId) async {
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(tankId),
          vendor: const Value('Reef Suplements'), // typo the user fixes below
          product: const Value('Trace A'),
          elementKey: const Value('iodine'),
          amount: const Value(5),
          amountUnit: Value(DoseUnit.ml.name),
          basis: Value(DoseBasis.perDay.name),
        ),
      );
    });

    await tester.enterText(
      find.widgetWithText(TextField, 'Vendor name'),
      'Reef Supplements',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    final rows = await db.getAllDosingEntries();
    await unmountApp(tester);

    // A rename doesn't change the dose, so it stays one segment — but it must
    // actually be written.
    expect(rows, hasLength(1));
    expect(rows.single.vendor, 'Reef Supplements');
    expect(rows.single.amount, 5);
    expect(rows.single.state, DosingState.active.name);
  });

  group('doseAffectingChanged', () {
    late AppDatabase db;
    late DosingEntry entry;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final tankId = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(tankId),
          vendor: const Value('Reef Suplements'),
          product: const Value('Trace A'),
          elementKey: const Value('iodine'),
          amount: const Value(0.25),
          amountUnit: Value(DoseUnit.ml.name),
          basis: Value(DoseBasis.perDay.name),
          frequency: Value(DoseFrequency.daily.name),
        ),
      );
      entry = (await db.getAllDosingEntries()).single;
    });
    tearDown(() => db.close());

    DosingEntriesCompanion companionFrom(DosingEntry e) =>
        DosingEntriesCompanion(
          productKey: Value(e.productKey),
          vendor: Value(e.vendor),
          product: Value(e.product),
          elementKey: Value(e.elementKey),
          amount: Value(e.amount),
          amountUnit: Value(e.amountUnit),
          basis: Value(e.basis),
          frequency: Value(e.frequency),
          intervalDays: Value(e.intervalDays),
          weekdays: Value(e.weekdays),
          doseTime: Value(e.doseTime),
          note: Value(e.note),
        );

    test('cosmetic fields — name, vendor, note, time — are not dose '
        'affecting', () {
      final next = companionFrom(entry).copyWith(
        product: const Value('Trace A (bottle 2)'),
        vendor: const Value('Reef Supplements'),
        note: const Value('renamed'),
        doseTime: const Value('20:00'),
      );
      expect(doseAffectingChanged(entry, next), isFalse);
    });

    test('a re-saved amount that survives the round trip is not a change', () {
      expect(doseAffectingChanged(entry, companionFrom(entry)), isFalse);
    });

    test('a real dose change is dose affecting', () {
      expect(
        doseAffectingChanged(
          entry,
          companionFrom(entry).copyWith(amount: const Value(0.3)),
        ),
        isTrue,
      );
      expect(
        doseAffectingChanged(
          entry,
          companionFrom(entry).copyWith(basis: Value(DoseBasis.perDose.name)),
        ),
        isTrue,
      );
    });
  });
}
