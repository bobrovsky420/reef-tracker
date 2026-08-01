import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/ap_device_link.dart';
import 'package:reeftracker/data/ap_protocol.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_device_secrets.dart';

/// The guards device readings pass on their way into the database (#71, #76).
///
/// Every other write path in the app — Add Reading, the history quick-add, the
/// ICP and Hanna imports, the live meter session — puts a storable-but-wrong
/// value to the user before storing it. The device dashboards were the one
/// entry point without that gate, and they are the likeliest source of one: an
/// uncalibrated probe, a disconnected sensor reporting its rail, a
/// mis-resolved unit. These tests drive the real screen against fake links.
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

  final secrets = FakeDeviceSecrets({'AC5:1': 'hunter2'});

  /// A tank with one ReefFactory meter of [rfModel] and, when [withApex] is
  /// set, an Apex beside it.
  Future<AppDatabase> seed({
    String rfModel = kRfTempControllerModel,
    bool withApex = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    // Reading and saving devices is Pro (grandfathered).
    await AppSettings(db).seedLegacyFreeSince('0.0.0-test');
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: rfModel,
      address: '10.0.0.1',
      name: 'RF meter',
      tankId: tankId,
    );
    if (withApex) {
      await db.upsertApexDevice(
        identifier: 'AC5:1',
        model: 'Apex',
        address: '10.0.0.2',
        username: 'admin',
        name: 'Apex',
        tankId: tankId,
      );
    }
    return db;
  }

  Future<void> pumpDevices(
    WidgetTester tester,
    AppDatabase db, {
    required RfDeviceLink rf,
    ApDeviceLink? ap,
    Duration staleAfter = kDeviceSnapshotStaleAfter,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          deviceSecretsProvider.overrideWithValue(secrets),
          rfDeviceLinkProvider.overrideWithValue(rf),
          if (ap != null) apDeviceLinkProvider.overrideWithValue(ap),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DevicesScreen(staleAfter: staleAfter),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapSaveAll(WidgetTester tester, int savable) async {
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Save all ($savable)'),
    );
    await settle(tester);
  }

  Future<Map<String, double>> saved(AppDatabase db) async => {
    for (final r in await db.getAllReadings()) r.paramKey: r.value,
  };

  group('suspicious device values are put to the keeper (#71)', () {
    testWidgets('an implausible reading is confirmed, then stored', (
      tester,
    ) async {
      final db = await seed();
      addTearDown(db.close);
      // 45 °C is possible to store but far outside the catalog's 10–40 band:
      // a probe out of calibration, or a Fahrenheit number taken as Celsius.
      await pumpDevices(tester, db, rf: _FakeRfLink.temperature([45]));

      await tapSaveAll(tester, 1);
      expect(find.text('Unusual values'), findsOneWidget);
      expect(
        find.textContaining('A connected device reported values'),
        findsOneWidget,
      );
      // Nothing is written while the question is open.
      expect(await saved(db), isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Save anyway'));
      await settle(tester);
      expect(await saved(db), {'temperature': 45.0});
      await unmountApp(tester);
    });

    testWidgets('declining drops that value and keeps the rest of the save', (
      tester,
    ) async {
      final db = await seed(withApex: true);
      addTearDown(db.close);
      await pumpDevices(
        tester,
        db,
        rf: _FakeRfLink.temperature([45]),
        ap: const _FakeApLink(ph: 8.1),
      );

      await tapSaveAll(tester, 2);
      // "Skip", not "Cancel": one bad probe must not cost the keeper the
      // other readings in a Save all.
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await settle(tester);

      expect(await saved(db), {'ph': 8.1});
      await unmountApp(tester);
    });

    testWidgets('a probe on its rail is questioned even though it checks ok', (
      tester,
    ) async {
      final db = await seed(rfModel: 'RFSG01');
      addTearDown(db.close);
      // A Salinity Guardian reporting 0 ppt — no salt at all. It converts to
      // SG 1.000, which is exactly `plausibleMin`, so neither tier of the
      // sanity gate can see it; only the rail rule can.
      await pumpDevices(tester, db, rf: _FakeRfLink.guardian(salinityPpt: 0));

      await tapSaveAll(tester, 1);
      expect(find.textContaining('reads as nothing at all'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await settle(tester);

      // The salinity is dropped; the same meter's temperature still saves.
      expect(await saved(db), {'temperature': 25.0});
      await unmountApp(tester);
    });

    testWidgets('an ordinary reading is saved with no question asked', (
      tester,
    ) async {
      final db = await seed();
      addTearDown(db.close);
      await pumpDevices(tester, db, rf: _FakeRfLink.temperature([25]));

      await tapSaveAll(tester, 1);

      expect(find.text('Unusual values'), findsNothing);
      expect(await saved(db), {'temperature': 25.0});
      await unmountApp(tester);
    });
  });

  group('a stale snapshot is re-read before it is saved (#76)', () {
    testWidgets('the save writes the re-read value, not the held one', (
      tester,
    ) async {
      final db = await seed();
      addTearDown(db.close);
      final rf = _FakeRfLink.temperature([25, 26.4]);
      await pumpDevices(tester, db, rf: rf, staleAfter: Duration.zero);
      // The on-open read is what the card shows.
      expect(rf.reads, 1);

      await tapSaveAll(tester, 1);

      expect(rf.reads, 2, reason: 'the save must re-read a stale snapshot');
      expect(await saved(db), {'temperature': 26.4});
      await unmountApp(tester);
    });

    testWidgets('a failed re-read falls back to the held values', (
      tester,
    ) async {
      final db = await seed();
      addTearDown(db.close);
      // Reads once, then the meter goes off the LAN — the save must not be
      // lost with it.
      final rf = _FakeRfLink.temperature([25]);
      await pumpDevices(tester, db, rf: rf, staleAfter: Duration.zero);

      await tapSaveAll(tester, 1);

      expect(rf.reads, 2);
      expect(await saved(db), {'temperature': 25.0});
      await unmountApp(tester);
    });

    testWidgets('a fresh snapshot is saved without a second round trip', (
      tester,
    ) async {
      final db = await seed();
      addTearDown(db.close);
      final rf = _FakeRfLink.temperature([25, 26.4]);
      await pumpDevices(tester, db, rf: rf);

      await tapSaveAll(tester, 1);

      expect(rf.reads, 1);
      expect(await saved(db), {'temperature': 25.0});
      await unmountApp(tester);
    });
  });
}

/// A ReefFactory meter that serves a scripted sequence of reads and then goes
/// unreachable, counting how often it was asked.
class _FakeRfLink implements RfDeviceLink {
  _FakeRfLink._(this._snapshots);

  /// A Temperature Controller reporting [celsius] on successive reads.
  factory _FakeRfLink.temperature(List<double> celsius) => _FakeRfLink._([
    for (final c in celsius)
      RfSnapshot(
        serial: 'RFTC012110010070',
        modelPrefix: kRfTempControllerModel,
        modelName: 'temperature',
        modelDisplayName: 'Temperature Controller',
        readings: [RfReading('temperature', c, '°C')],
      ),
  ]);

  /// A Salinity Guardian: salinity in ppt, plus the thermometer it carries.
  factory _FakeRfLink.guardian({required double salinityPpt}) => _FakeRfLink._([
    for (var i = 0; i < 4; i++)
      RfSnapshot(
        serial: 'RFSG012110010070',
        modelPrefix: 'RFSG01',
        modelName: 'salinity',
        modelDisplayName: 'Salinity Guardian',
        readings: [
          RfReading('salinity', salinityPpt, 'ppt'),
          RfReading('temperature', 25, '°C'),
        ],
      ),
  ]);

  final List<RfSnapshot> _snapshots;
  int reads = 0;

  @override
  Future<RfSnapshot> readOnce(String host) async {
    final i = reads++;
    if (i >= _snapshots.length) {
      throw const RfLinkException(RfLinkError.unreachable, 'off the LAN');
    }
    return _snapshots[i];
  }
}

/// A controller with a single pH probe — a second parameter for the tank, so a
/// declined temperature can be seen not to take it down with it.
class _FakeApLink implements ApDeviceLink {
  const _FakeApLink({required this.ph});
  final double ph;

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
        probes: [ApProbe(did: 'base_pH', name: 'pH', type: 'pH', value: ph)],
        outlets: const [],
      );
}
