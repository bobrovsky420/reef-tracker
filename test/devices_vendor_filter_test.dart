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
}
