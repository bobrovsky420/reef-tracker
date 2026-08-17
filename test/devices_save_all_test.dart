import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/ap_device_link.dart';
import 'package:reeftracker/data/ap_protocol.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/device_vendors.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_device_secrets.dart';

/// Save all's cross-vendor merge on the unified Devices screen (U41): when a
/// meter and a controller report the same parameter for the same tank, the one
/// **displayed first** must win — vendor order (the "Reorder brands" sheet)
/// first, card order within a vendor second. The reorder sheet promises exactly
/// this, so a test that only covers each vendor's own save filter (as
/// `reeffactory_save_rule_test` / `apex_save_rule_test` do) never sees it break.
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

  /// The Apex password lives beside the database, not in it (#68), so the
  /// screen only reads a controller whose sidecar holds one.
  final secrets = FakeDeviceSecrets({'AC5:1': 'hunter2'});

  /// A tank with one ReefFactory temperature controller and one Apex, both
  /// assigned to it and both about to report a *different* temperature.
  Future<AppDatabase> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    // Reading and saving devices is Pro (grandfathered): without the founder
    // marker the page renders the lock notice instead of the action buttons.
    await AppSettings(db).seedLegacyFreeSince('0.0.0-test');
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
    return db;
  }

  Future<void> pumpDevices(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          deviceSecretsProvider.overrideWithValue(secrets),
          rfDeviceLinkProvider.overrideWithValue(const _FakeRfLink(25)),
          rbDeviceLinkProvider.overrideWithValue(const _FakeRbLink()),
          apDeviceLinkProvider.overrideWithValue(const _FakeApLink(26)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicesScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  /// The temperatures the screen actually persisted.
  Future<List<double>> savedTemperatures(AppDatabase db) async => [
    for (final r in await db.getAllReadings())
      if (r.paramKey == 'temperature') r.value,
  ];

  Future<void> tapSaveAll(WidgetTester tester) async {
    // Both devices report the same tank parameter, so first-displayed-wins
    // leaves one value for the FAB to count. Per-card Save actions carry no
    // such count.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Save all (1)'));
    await settle(tester);
  }

  Finder cardMenu(String deviceName) => find.descendant(
    of: find.ancestor(of: find.text(deviceName), matching: find.byType(Card)),
    matching: find.byIcon(Icons.more_vert),
  );

  Future<void> tapCardSave(WidgetTester tester, String deviceName) async {
    await tester.ensureVisible(find.text(deviceName));
    await settle(tester);
    expect(find.byTooltip('Save'), findsNothing);
    expect(cardMenu(deviceName), findsOneWidget);
    await tester.tap(cardMenu(deviceName));
    await settle(tester);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  testWidgets('the default vendor order gives the meter the temperature', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);

    await pumpDevices(tester, db);
    await tapSaveAll(tester);

    // ReefFactory sits above Apex by default, so its 25.0 is the one stored —
    // once, not twice.
    expect(await savedTemperatures(db), [25.0]);
    await unmountApp(tester);
  });

  testWidgets('a reordered vendor list moves the win to the Apex', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    // What the "Reorder brands" sheet writes when Apex is dragged to the top.
    await AppSettings(db).setDeviceVendorOrder([
      kDeviceKindApex,
      kDeviceKindReefFactory,
      kDeviceKindReefBeat,
    ]);

    await pumpDevices(tester, db);
    // The page really does render Apex first — the order the save must follow.
    expect(
      tester.getTopLeft(find.text('Apex')).dy,
      lessThan(tester.getTopLeft(find.text('RF controller')).dy),
    );

    await tapSaveAll(tester);

    expect(await savedTemperatures(db), [26.0]);
    await unmountApp(tester);
  });

  testWidgets('ReefFactory card saves from its overflow menu', (tester) async {
    final db = await seed();
    addTearDown(db.close);

    await pumpDevices(tester, db);
    await tapCardSave(tester, 'RF controller');

    expect(await savedTemperatures(db), [25.0]);
    await unmountApp(tester);
  });

  testWidgets('Apex card saves from its overflow menu', (tester) async {
    final db = await seed();
    addTearDown(db.close);

    await pumpDevices(tester, db);
    await tapCardSave(tester, 'Apex');

    expect(await savedTemperatures(db), [26.0]);
    await unmountApp(tester);
  });

  testWidgets('ReefControl card and Save all expose its probe measurements', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AppSettings(db).seedLegacyFreeSince('0.0.0-test');
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RB-CONTROL-1',
      model: 'RSCONTROLPRO',
      address: '10.0.0.3',
      name: 'ReefControl',
      tankId: tankId,
    );

    await pumpDevices(tester, db);

    // ReefControl is the one meter inside the mixed ReefBeat vendor. Its three
    // primary probe parameters and the first supplementary temperature are
    // all counted; the second temperature is not because it would not save.
    // A ReefDose/ReefWave would contribute no values and expose no Save.
    expect(
      find.widgetWithText(FloatingActionButton, 'Save all (4)'),
      findsOneWidget,
    );
    await tapCardSave(tester, 'ReefControl');

    final readings = await db.getAllReadings();
    expect(readings.map((r) => r.paramKey).toSet(), {
      'salinity',
      'temperature',
      'orp',
      'ph',
    });
    expect(
      readings.singleWhere((r) => r.paramKey == 'temperature').value,
      25.1,
    );
    await unmountApp(tester);
  });
}

/// A meter that always reports [celsius], with no socket involved.
class _FakeRfLink implements RfDeviceLink {
  const _FakeRfLink(this.celsius);
  final double celsius;

  @override
  Future<RfSnapshot> readOnce(String host) async => RfSnapshot(
    serial: 'RFTC012110010070',
    modelPrefix: kRfTempControllerModel,
    modelName: 'temperature',
    modelDisplayName: 'Temperature Controller',
    readings: [RfReading('temperature', celsius, '°C')],
  );
}

/// A controller whose single probe always reports [celsius].
class _FakeApLink implements ApDeviceLink {
  const _FakeApLink(this.celsius);
  final double celsius;

  @override
  Future<ApStatus> readOnce(String host, ApCredentials credentials) async =>
      ApStatus(
        info: const ApDeviceInfo(
          serial: 'AC5:1',
          hostname: 'apex',
          software: '5.04_7A18',
          hardware: '1.0',
          firmware: ApFirmware.aos5,
        ),
        probes: [
          ApProbe(did: 'base_Temp', name: 'Tmp', type: 'Temp', value: celsius),
        ],
        outlets: const [],
      );
}

class _FakeRbLink implements RbDeviceLink {
  const _FakeRbLink();

  @override
  Future<RbSnapshot> readOnce(String host) async => const RbControlSnapshot(
    info: RbDeviceInfo(
      hwType: kRbControlHwType,
      hwModel: 'RSCONTROLPRO',
      hwid: 'RB-CONTROL-1',
    ),
    status: RbControlStatus(
      probes: [
        RbControlProbe(type: 'ec', ppt: 35, temperatureC: 25.1),
        RbControlProbe(type: 'orp', value: 410),
        RbControlProbe(type: 'ph', value: 8.2, temperatureC: 26.3),
      ],
    ),
  );

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async => const [];
}
