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
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/apex/apex_screen.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/features/reefbeat/reefbeat_screen.dart';
import 'package:reeftracker/features/reeffactory/reeffactory_screen.dart';
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
        ap: _FakeApLink(ph: 8.1),
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

  /// The other guard on the same page: which installs the page is allowed to
  /// put on the LAN by itself.
  ///
  /// Opening Devices fires an automatic read of everything in the current
  /// selection — traffic nobody asked for, aimed at hardware the app has no
  /// licence to talk to on a Standard install. And a Standard install can
  /// easily be carrying devices: restore *merges* device rows (they survive a
  /// tank delete with `tankId` nulled, and a backup taken on a Founder's phone
  /// restores onto any install), so "no entitlement" and "no devices" are
  /// independent facts. One `entitled &&` is the whole guard, and it gates
  /// three vendors at once.
  group('the on-open read is gated (U19 / connectedDevices)', () {
    /// A tank carrying one device of every pollable vendor — the shape a
    /// restore onto a fresh phone produces. [pro] decides only whether the
    /// install carries the grandfathering marker; the rows are identical.
    Future<AppDatabase> seedFleet({required bool pro}) async {
      final db = AppDatabase(NativeDatabase.memory());
      if (pro) await AppSettings(db).seedLegacyFreeSince('0.0.0-test');
      final tankId = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db.upsertReefFactoryDevice(
        identifier: 'RF-1',
        model: kRfTempControllerModel,
        address: '10.0.0.1',
        name: 'RF meter',
        tankId: tankId,
      );
      await db.upsertReefBeatDevice(
        identifier: 'RB-1',
        model: 'RSDOSE4',
        address: '10.0.0.3',
        name: 'ReefDose',
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

    /// The three transports, each counting how often it was asked. Held per
    /// test so the counts survive a re-pump of the body.
    late _FakeRfLink rf;
    late _CountingRbLink rb;
    late _FakeApLink ap;

    setUp(() {
      rf = _FakeRfLink.temperature([25]);
      rb = _CountingRbLink();
      ap = _FakeApLink(ph: 8.1);
    });

    /// Pumps [DevicesBody] itself rather than [DevicesScreen]: `active` is a
    /// body-level flag (the home shell keeps every tab built inside an
    /// `IndexedStack`) and the standalone screen has no way to pass it.
    Future<void> pumpBody(
      WidgetTester tester,
      AppDatabase db, {
      bool active = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            deviceSecretsProvider.overrideWithValue(secrets),
            rfDeviceLinkProvider.overrideWithValue(rf),
            rbDeviceLinkProvider.overrideWithValue(rb),
            apDeviceLinkProvider.overrideWithValue(ap),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DevicesBody(active: active)),
          ),
        ),
      );
      await settle(tester);
    }

    /// Asserts every vendor's transport was asked exactly [n] times — one
    /// matcher per vendor, because the guard covers all three and a rewrite
    /// that gates only the one it was written against must fail here.
    void expectReads(int n) {
      expect(rf.reads, n, reason: 'ReefFactory');
      expect(rb.reads, n, reason: 'ReefBeat');
      expect(ap.reads, n, reason: 'Apex');
    }

    /// Every device's `lastSeenAt` — a successful read of any vendor bumps it
    /// via `touchDeviceSeen`, so it is a second, DB-side witness of whether
    /// anything actually went out on the wire.
    Future<Map<String, DateTime?>> lastSeen(AppDatabase db) async => {
      for (final d in await db.getAllDevices()) d.identifier: d.lastSeenAt,
    };

    testWidgets('a Standard install with a full fleet performs zero reads', (
      tester,
    ) async {
      final db = await seedFleet(pro: false);
      addTearDown(db.close);
      final before = await lastSeen(db);
      await pumpBody(tester, db);

      expectReads(0);
      expect(await lastSeen(db), before, reason: 'nothing was ever seen');
      // Not vacuous: the page itself is ungated, so all three sections are on
      // screen with their cards — the inventory a keeper must always be able
      // to see. Zero reads is a decision, not an empty list.
      expect(find.byType(RfDeviceSection), findsOneWidget);
      expect(find.byType(RbDeviceSection), findsOneWidget);
      expect(find.byType(ApDeviceSection), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('an entitled install reads every vendor exactly once', (
      tester,
    ) async {
      final db = await seedFleet(pro: true);
      addTearDown(db.close);
      await pumpBody(tester, db);

      // The positive control for the test above: same fleet, same fakes, same
      // page — only the entitlement differs.
      expectReads(1);
      await unmountApp(tester);
    });

    testWidgets('pulling past the top refreshes every device in scope', (
      tester,
    ) async {
      final db = await seedFleet(pro: true);
      addTearDown(db.close);
      await pumpBody(tester, db);
      expectReads(1); // The ordinary on-open read.

      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await settle(tester);

      expectReads(2);
      await unmountApp(tester);
    });

    testWidgets('a Devices tab nobody is looking at reads nothing until it '
        'is', (tester) async {
      final db = await seedFleet(pro: true);
      addTearDown(db.close);
      // The home shell builds every tab up front; without the `active` half of
      // the guard, every app launch would poll the whole fleet for a page the
      // keeper never opened.
      await pumpBody(tester, db, active: false);
      expectReads(0);

      // Same widget, same position, so the state (and its `_autoRead` set)
      // survives — exactly what switching to the tab does.
      await pumpBody(tester, db);
      expectReads(1);

      // Switching away and back must not re-poll: the on-open read is once
      // per device per session, and Refresh is what asks again.
      await pumpBody(tester, db, active: false);
      await pumpBody(tester, db);
      expectReads(1);
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
/// declined temperature can be seen not to take it down with it. Counts its
/// reads for the on-open-read gate.
class _FakeApLink implements ApDeviceLink {
  _FakeApLink({required this.ph});
  final double ph;
  int reads = 0;

  @override
  Future<ApStatus> readOnce(String host, ApCredentials credentials) async {
    reads++;
    return ApStatus(
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
}

/// A ReefBeat pump that is simply not on the network — the on-open-read gate
/// only cares *whether* the transport was reached, and a device that answers
/// nothing keeps the fake free of a whole snapshot's worth of fixture.
class _CountingRbLink implements RbDeviceLink {
  int reads = 0;

  @override
  Future<RbSnapshot> readOnce(String host) async {
    reads++;
    throw const RbLinkException(RbLinkError.unreachable, 'off the LAN');
  }

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async =>
      throw const RbLinkException(RbLinkError.unreachable, 'off the LAN');
}
