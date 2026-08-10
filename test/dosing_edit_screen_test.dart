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
import 'package:reeftracker/features/dosing/manual_dose_edit_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The element dropdown of both dosing edit forms must survive whatever
/// `_elementKey` holds.
///
/// Both forms cascade Vendor → Product → Element: choosing a product assigns
/// `product.elementKey`, and editing an existing row seeds the stored one —
/// neither is checked against the picker's own item list. A value with no
/// matching item asserts on the very next frame in debug ("There should be
/// exactly one item with [DropdownButton]'s value") and, in release, leaves the
/// field showing the *previous* element while `_save()` writes the stranger.
///
/// The live case is the Fauna Marin "Elementals Trace" line: 12 bottles target
/// trace elements (barium, vanadium, zinc…). Phase 1 closed the catalog half by
/// extending [kDosingElementKeys]; this file pins the UI half — the product
/// cascade for the whole catalog, and the stored-value door, which is the one
/// still open (a restored/synced row can carry any element key at all).
///
/// Note for anyone extending this file: assert **after** unmounting. A failed
/// expectation with the app still mounted leaves drift's stream subscription
/// live, and the tear-down `db.close()` then never returns — the run hangs
/// instead of reporting the failure.
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

  /// Boots an in-memory database with one tank, runs [seed] against it and
  /// pushes `build(db)` on top of a host route, so `_save`'s `pop()` has
  /// somewhere to go.
  Future<AppDatabase> pumpScreen(
    WidgetTester tester,
    Widget Function(AppDatabase db) build, {
    Future<void> Function(AppDatabase db, int tankId)? seed,
  }) async {
    // Phone width, but tall enough for the whole form to be laid out without
    // scrolling (a `ListView` only builds its visible children) and for the
    // vendor/product menus to open at full height.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await seed?.call(db, tankId);

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          navigatorKey: nav,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The host route watches the active tank, as the Dosing tab under the
          // real edit route does: `_save` *reads* the provider, and a provider
          // nobody has subscribed to yet answers a cold read with "loading" —
          // i.e. no tank, and a silently skipped save.
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
        MaterialPageRoute<void>(builder: (_) => build(db)),
      ),
    );
    await settle(tester);
    return db;
  }

  /// The form field carrying [label], identified by its decoration so the
  /// vendor and product dropdowns (same type argument) stay distinguishable.
  Finder dropdownFinder(String label) => find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> && w.decoration.labelText == label,
  );

  /// Opens the [label] dropdown and taps the entry reading [option], scrolling
  /// the menu to it first — the vendor and product menus are longer than the
  /// viewport. Drives the real gesture path, assertions and all.
  Future<void> pick(WidgetTester tester, String label, String option) async {
    await tester.tap(dropdownFinder(label));
    await settle(tester);
    // `.last` skips the closed button's copy of the currently selected item,
    // which stays in the tree behind the menu route.
    final item = find.text(option).last;
    await tester.ensureVisible(item);
    await settle(tester);
    await tester.tap(item);
    await settle(tester);
  }

  testWidgets('picking a Fauna Marin trace product sets the plan element and '
      'saves it', (tester) async {
    final db = await pumpScreen(tester, (_) => const DosingEditScreen());

    await pick(tester, 'Vendor', 'Fauna Marin');
    await pick(tester, 'Product', 'Elementals Trace Ba — Barium');

    // The whole point: the frame after the selection builds without the
    // dropdown assertion, and the field shows the product's element.
    final crash = tester.takeException();
    final shownElement = find.text('Barium (Ba)').evaluate().isNotEmpty;

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    final rows = await db.getAllDosingEntries();
    await unmountApp(tester);

    expect(crash, isNull);
    expect(shownElement, isTrue, reason: 'element dropdown shows Barium');
    expect(rows, hasLength(1));
    expect(rows.single.productKey, 'faunamarin.trace_ba');
    expect(rows.single.elementKey, 'barium');
  });

  testWidgets('picking a Fauna Marin trace product sets the manual-dose '
      'element and saves it', (tester) async {
    final db = await pumpScreen(tester, (_) => const ManualDoseEditScreen());

    await pick(tester, 'Vendor', 'Fauna Marin');
    await pick(tester, 'Product', 'Elementals Trace Zn — Zinc');

    final crash = tester.takeException();
    final shownElement = find.text('Zinc (Zn)').evaluate().isNotEmpty;

    // Unlike the plan form's optional dosage, a logged dose needs an amount.
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1.5');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    final rows = await db.getAllManualDoses();
    await unmountApp(tester);

    expect(crash, isNull);
    expect(shownElement, isTrue, reason: 'element dropdown shows Zinc');
    expect(rows, hasLength(1));
    expect(rows.single.productKey, 'faunamarin.trace_zn');
    expect(rows.single.elementKey, 'zinc');
    expect(rows.single.amount, 1.5);
  });

  testWidgets('a plan whose stored element is not in the picker still opens, '
      'and keeps that element', (tester) async {
    // The same dropdown by the other door: `_initFromEntry` seeds `_elementKey`
    // straight from the row, and rows are not written only by this picker — a
    // restored backup or a synced device can carry any element key.
    expect(kDosingElementKeys, isNot(contains('aluminium')));
    DosingEntry? seeded;
    final db = await pumpScreen(
      tester,
      (_) => DosingEditScreen(entry: seeded!),
      seed: (db, tankId) async {
        await db.insertDosingEntry(
          DosingEntriesCompanion(
            tankId: Value(tankId),
            vendor: const Value('Fauna Marin'),
            product: const Value('Elementals Trace Al'),
            elementKey: const Value('aluminium'),
            amount: const Value(1),
            amountUnit: Value(DoseUnit.ml.name),
            basis: Value(DoseBasis.perDay.name),
          ),
        );
        seeded = (await db.getAllDosingEntries()).single;
      },
    );
    final crash = tester.takeException();

    // Saving an untouched form must not quietly swap the element for whatever
    // the dropdown happened to fall back to.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    final rows = await db.getAllDosingEntries();
    await unmountApp(tester);

    expect(crash, isNull, reason: 'the form builds with an unlisted element');
    expect(rows, hasLength(1));
    expect(rows.single.elementKey, 'aluminium');
  });

  testWidgets('a logged dose whose stored element is not in the picker still '
      'opens, and keeps that element', (tester) async {
    ManualDose? seeded;
    final db = await pumpScreen(
      tester,
      (_) => ManualDoseEditScreen(dose: seeded!),
      seed: (db, tankId) async {
        await db.insertManualDose(
          ManualDosesCompanion(
            tankId: Value(tankId),
            dosedAt: Value(DateTime(2026, 3, 4, 9)),
            vendor: const Value('Fauna Marin'),
            product: const Value('Elementals Trace Al'),
            elementKey: const Value('aluminium'),
            amount: const Value(2),
            amountUnit: Value(DoseUnit.ml.name),
          ),
        );
        seeded = (await db.getAllManualDoses()).single;
      },
    );
    final crash = tester.takeException();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    final rows = await db.getAllManualDoses();
    await unmountApp(tester);

    expect(crash, isNull, reason: 'the form builds with an unlisted element');
    expect(rows, hasLength(1));
    expect(rows.single.elementKey, 'aluminium');
  });

  /// Sweeps the whole catalog through one screen's vendor → product cascade, so
  /// a product added later fails here rather than in a user's hands. Each
  /// product must both leave the form standing and land its own element in the
  /// picker — a value the items do not carry would be dropped by the field
  /// instead of shown. Selections go through the dropdowns' own `onChanged`
  /// (the callback a tap invokes): the assertion under test fires on the
  /// rebuild, not on the gesture, and this keeps the sweep to two frames per
  /// product. Returns the products that came out wrong.
  Future<List<String>> sweepCatalog(WidgetTester tester) async {
    final wrong = <String>[];
    ValueChanged<String?> onChangedOf(String label) => tester
        .widget<DropdownButtonFormField<String>>(dropdownFinder(label))
        .onChanged!;
    for (final vendor in kSupplementVendors) {
      final products = vendor.allProducts
          .where((p) => p.elementKey != null)
          .toList();
      if (products.isEmpty) continue;
      onChangedOf('Vendor')(vendor.key);
      await tester.pump();
      for (final product in products) {
        onChangedOf('Product')(product.key);
        await tester.pump();
        if (tester.takeException() != null) {
          wrong.add('${product.name} (${product.elementKey}): threw');
          continue;
        }
        // The element field's current value, read off the form field itself.
        final shown = tester
            .widget<DropdownButtonFormField<String?>>(
              find.byType(DropdownButtonFormField<String?>),
            )
            .initialValue;
        if (shown != product.elementKey) {
          wrong.add('${product.name}: shows $shown, not ${product.elementKey}');
        }
      }
    }
    return wrong;
  }

  testWidgets('every catalog product survives selection in the plan editor', (
    tester,
  ) async {
    await pumpScreen(tester, (_) => const DosingEditScreen());
    final wrong = await sweepCatalog(tester);
    await unmountApp(tester);
    expect(
      wrong,
      isEmpty,
      reason: 'these products did not reach the element dropdown intact',
    );
  });

  testWidgets('every catalog product survives selection in the manual-dose '
      'editor', (tester) async {
    await pumpScreen(tester, (_) => const ManualDoseEditScreen());
    final wrong = await sweepCatalog(tester);
    await unmountApp(tester);
    expect(wrong, isEmpty, reason: 'see the plan-editor sweep');
  });

  group('dosingElementChoices', () {
    test('offers the catalog list unchanged for a known element', () {
      expect(dosingElementChoices('barium'), same(kDosingElementKeys));
      expect(dosingElementChoices(null), same(kDosingElementKeys));
    });

    test('appends an element the list does not offer', () {
      final choices = dosingElementChoices('aluminium');
      expect(choices, containsAll(kDosingElementKeys));
      expect(choices.last, 'aluminium');
      // Exactly one item per value — the dropdown asserts on duplicates too.
      expect(choices.toSet(), hasLength(choices.length));
    });
  });
}
