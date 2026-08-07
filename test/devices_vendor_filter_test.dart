import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/device_vendors.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_device_secrets.dart';

/// The Devices screen's vendor chip selection is persisted (device-local, see
/// `settings_test.dart`) and must survive a restart. The regression pinned
/// here: the restore used to judge the stored vendor against the device lists
/// of whatever build it first ran in — and the settings map usually loads
/// before the four device streams, so it judged against still-loading (empty)
/// lists, latched, and silently reset the selection to All on every cold
/// start.
void main() {
  /// Pumps fake time in small steps — never `pumpAndSettle`, which would hang
  /// on the drift-loading spinner (see the router-test note).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('stored vendor selection survives the settings map loading '
      'before the device lists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: kRfTempControllerModel,
      address: '10.0.0.1',
      name: 'RF controller',
      tankId: tankId,
    );
    await db.upsertApexDevice(
      identifier: 'AC5:1',
      model: 'Apex',
      address: '10.0.0.2',
      username: 'admin',
      name: 'Apex',
      tankId: tankId,
    );
    // What the screen wrote when the user last tapped the Neptune Apex chip.
    await AppSettings(db).setDeviceVendorFilter(kDeviceKindApex);
    final all = await db.getAllDevices();
    List<DeviceRecord> ofKind(String kind) => [
      for (final d in all)
        if (d.kind == kind) d,
    ];

    // Device streams the test releases by hand, so the settings map (read
    // straight from the DB) is guaranteed to win the load race — the ordering
    // that used to reset the selection.
    final rf = StreamController<List<DeviceRecord>>();
    final rb = StreamController<List<DeviceRecord>>();
    final ap = StreamController<List<DeviceRecord>>();
    final ha = StreamController<List<DeviceRecord>>();
    addTearDown(() async {
      await rf.close();
      await rb.close();
      await ap.close();
      await ha.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          deviceSecretsProvider.overrideWithValue(FakeDeviceSecrets({})),
          reefFactoryDevicesProvider.overrideWith((ref) => rf.stream),
          reefBeatDevicesProvider.overrideWith((ref) => rb.stream),
          apexDevicesProvider.overrideWith((ref) => ap.stream),
          hannaDevicesProvider.overrideWith((ref) => ha.stream),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicesScreen(),
        ),
      ),
    );
    // Settings are loaded by now; all four device lists are still silent.
    await settle(tester);

    rf.add(ofKind(kDeviceKindReefFactory));
    rb.add(const []);
    ap.add(ofKind(kDeviceKindApex));
    ha.add(const []);
    await settle(tester);

    ChoiceChip chip(String labelPrefix) => tester.widget<ChoiceChip>(
      find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            ((w.label as Text).data ?? '').startsWith(labelPrefix),
      ),
    );
    expect(chip('Neptune Apex').selected, isTrue);
    expect(chip('All').selected, isFalse);
    await unmountApp(tester);
  });

  testWidgets('a horizontal swipe steps the vendor selection one chip and '
      'stops at both ends', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: kRfTempControllerModel,
      address: '10.0.0.1',
      name: 'RF controller',
      tankId: tankId,
    );
    await db.upsertApexDevice(
      identifier: 'AC5:1',
      model: 'Apex',
      address: '10.0.0.2',
      username: 'admin',
      name: 'Apex',
      tankId: tankId,
    );
    final all = await db.getAllDevices();
    List<DeviceRecord> ofKind(String kind) => [
      for (final d in all)
        if (d.kind == kind) d,
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          deviceSecretsProvider.overrideWithValue(FakeDeviceSecrets({})),
          reefFactoryDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindReefFactory)),
          ),
          reefBeatDevicesProvider.overrideWith((ref) => Stream.value(const [])),
          apexDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindApex)),
          ),
          hannaDevicesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicesScreen(),
        ),
      ),
    );
    await settle(tester);

    ChoiceChip chip(String labelPrefix) => tester.widget<ChoiceChip>(
      find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            ((w.label as Text).data ?? '').startsWith(labelPrefix),
      ),
    );
    // The stops, left to right: All, ReefFactory, Neptune Apex.
    void expectSelected(String labelPrefix) {
      for (final name in ['All', 'ReefFactory', 'Neptune Apex']) {
        expect(
          chip(name).selected,
          name == labelPrefix,
          reason: '$name chip while $labelPrefix should be selected',
        );
      }
    }

    /// A deliberate drag rather than a fling: the synthetic pointer stream
    /// carries no velocity, so this exercises the distance half of the
    /// threshold (300 px against the 800 px test surface's 20%).
    Future<void> swipe(double dx) async {
      await tester.drag(find.byType(CustomScrollView), Offset(dx, 0));
      await settle(tester);
    }

    expectSelected('All');
    await swipe(-300); // left → the chip to the right
    expectSelected('ReefFactory');
    await swipe(-300);
    expectSelected('Neptune Apex');
    // The right-hand end: no wrap, no move, no complaint.
    await swipe(-300);
    expectSelected('Neptune Apex');
    // The selection is persisted by the swipe exactly as a chip tap persists
    // it. Read as a Future, never as a stream: awaiting a stream inside
    // `testWidgets` hangs on the fake clock (see the router-test note).
    expect(
      await db.getSetting(SettingKey.deviceVendorFilter.storageKey),
      'apex',
    );

    await swipe(300); // right → back the way it came
    expectSelected('ReefFactory');
    await swipe(300);
    expectSelected('All');
    // And the left-hand end, where All is the last stop.
    await swipe(300);
    expectSelected('All');
    expect(await db.getSetting(SettingKey.deviceVendorFilter.storageKey), '');

    // A drag too short to mean anything leaves the selection alone.
    await swipe(-80);
    expectSelected('All');
    await unmountApp(tester);
  });

  testWidgets('swiping to a vendor whose chip has scrolled out of the bar '
      'brings that chip back into view', (tester) async {
    // The hole the reveal fills: a tap can only ever select a chip already on
    // screen, but a swipe can land on one the strip has scrolled past — and the
    // bar would then show every chip unselected, which is exactly the question
    // the swipe leaves open.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: kRfTempControllerModel,
      address: '10.0.0.1',
      name: 'RF controller',
      tankId: tankId,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSDOSE4-1',
      model: 'RSDOSE4',
      address: '10.0.0.3',
      name: 'ReefDose 4',
      tankId: tankId,
    );
    await db.upsertApexDevice(
      identifier: 'AC5:1',
      model: 'Apex',
      address: '10.0.0.2',
      username: 'admin',
      name: 'Apex',
      tankId: tankId,
    );
    await db.ensureHannaDevice(identifier: 'HI97115 0001', model: 'HI97115');
    final all = await db.getAllDevices();
    List<DeviceRecord> ofKind(String kind) => [
      for (final d in all)
        if (d.kind == kind) d,
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          deviceSecretsProvider.overrideWithValue(FakeDeviceSecrets({})),
          reefFactoryDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindReefFactory)),
          ),
          reefBeatDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindReefBeat)),
          ),
          apexDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindApex)),
          ),
          hannaDevicesProvider.overrideWith(
            (ref) => Stream.value(ofKind(kDeviceKindHanna)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicesScreen(),
        ),
      ),
    );
    await settle(tester);

    // The bar is the page's only horizontal scroller.
    ScrollableState bar() => tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    // Five stops on an 800 px surface: the last chips are off the end, which is
    // the precondition the whole test rests on.
    expect(
      bar().position.maxScrollExtent,
      greaterThan(0),
      reason: 'the chips must overflow for this test to mean anything',
    );
    expect(bar().position.pixels, 0);

    // All → ReefFactory → Red Sea → Neptune Apex → Hanna, the far end.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(-300, 0));
      await settle(tester);
    }
    final hannaChip = find.byWidgetPredicate(
      (w) => w is ChoiceChip && ((w.label as Text).data ?? '').startsWith('Han'),
    );
    expect(tester.widget<ChoiceChip>(hannaChip).selected, isTrue);
    expect(bar().position.pixels, greaterThan(0));
    // Visible, not merely scrolled towards: the chip sits inside the surface.
    final chipRect = tester.getRect(hannaChip);
    expect(chipRect.left, greaterThanOrEqualTo(0));
    expect(chipRect.right, lessThanOrEqualTo(800));

    // And back: All is at the other end, so the strip returns to its start.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(300, 0));
      await settle(tester);
    }
    expect(bar().position.pixels, 0);
    await unmountApp(tester);
  });
}
