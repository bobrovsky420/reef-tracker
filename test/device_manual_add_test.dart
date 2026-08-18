import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/reefbeat/reefbeat_screen.dart';
import 'package:reeftracker/features/reeffactory/reeffactory_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The manual "type an IP" add sheet refusing a device that is already on the
/// list (#75).
///
/// The sheet has no notion of an existing row — it prefills the *product* name
/// ("ReefDose 4") and the *currently active* tank — so letting a second add
/// through would silently rename a renamed card and re-point it at whatever
/// tank happens to be active. It therefore stops at the probe and says which
/// device answered; the only way on is Close. Re-pointing a moved device stays
/// the discovery sheet's job (it matches by identifier and writes the address
/// alone).
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

  /// One tank, plus the two already-registered devices the sheet must refuse.
  Future<AppDatabase> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSDOSE4-abc',
      model: 'RSDOSE4',
      address: '10.0.0.1',
      name: 'Left doser',
      tankId: tankId,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFSG012110010070',
      model: 'RFSG01',
      address: '10.0.0.2',
      name: 'Sump salinity',
      tankId: tankId,
    );
    return db;
  }

  /// Pumps a screen whose only button opens [open]'s sheet.
  Future<void> pumpSheet(
    WidgetTester tester,
    AppDatabase db, {
    RbDeviceLink? rb,
    RfDeviceLink? rf,
    required void Function(BuildContext context, WidgetRef ref) open,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          if (rb != null) rbDeviceLinkProvider.overrideWithValue(rb),
          if (rf != null) rfDeviceLinkProvider.overrideWithValue(rf),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => open(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  /// Types [host] into the address field and runs the probe.
  Future<void> check(WidgetTester tester, String host) async {
    await tester.enterText(find.byType(TextField).first, host);
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await settle(tester);
  }

  /// The row as stored, to prove a refused add changed nothing.
  Future<DeviceRecord> row(AppDatabase db, String identifier) async =>
      (await db.deviceByIdentifier(identifier))!;

  testWidgets('ReefBeat: re-adding a registered device is refused', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    final before = await row(db, 'RSDOSE4-abc');
    await pumpSheet(
      tester,
      db,
      rb: const _FakeRbLink('RSDOSE4-abc'),
      open: (context, ref) =>
          showRbManualSheet(context, ref, onSeed: (_, _) {}),
    );

    await check(tester, '10.0.0.9');

    // The stored name, not the product default, is what it names.
    expect(find.textContaining('Left doser is already added'), findsOneWidget);
    // Nothing to do but close: no name/tank fields, no way to add or re-probe.
    expect(find.widgetWithText(FilledButton, 'Close'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add device'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Check'), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    // The name and tank assignment the refusal protects are untouched.
    final after = await row(db, 'RSDOSE4-abc');
    expect(after.name, before.name);
    expect(after.tankId, before.tankId);
    expect(after.address, before.address);

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await settle(tester);
    expect(find.textContaining('is already added'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('ReefBeat: an unknown device still adds normally', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    await pumpSheet(
      tester,
      db,
      rb: const _FakeRbLink('RSDOSE4-xyz'),
      open: (context, ref) =>
          showRbManualSheet(context, ref, onSeed: (_, _) {}),
    );

    await check(tester, '10.0.0.9');

    expect(find.textContaining('is already added'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add device'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add device'));
    await settle(tester);
    expect(await db.deviceByIdentifier('RSDOSE4-xyz'), isNotNull);
    await unmountApp(tester);
  });

  testWidgets('ReefFactory: re-adding a registered meter is refused', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    final before = await row(db, 'RFSG012110010070');
    await pumpSheet(
      tester,
      db,
      rf: const _FakeRfLink('RFSG012110010070'),
      open: (context, ref) =>
          showRfManualSheet(context, ref, onSeed: (_, _) {}),
    );

    await check(tester, '10.0.0.9');

    expect(
      find.textContaining('Sump salinity is already added'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Close'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add device'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Check'), findsNothing);

    final after = await row(db, 'RFSG012110010070');
    expect(after.name, before.name);
    expect(after.tankId, before.tankId);
    expect(after.address, before.address);
    await unmountApp(tester);
  });
}

/// Answers every address with the same ReefDose identity — the "I typed the IP
/// of a device I already added" case.
class _FakeRbLink implements RbDeviceLink {
  const _FakeRbLink(this.hwid);
  final String hwid;

  @override
  Future<RbSnapshot> readOnce(String host) async => RbDoseSnapshot(
    info: RbDeviceInfo(hwType: kRbDosingHwType, hwModel: 'RSDOSE4', hwid: hwid),
    status: const RbDoseStatus(),
  );

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async => const [];
}

/// The ReefFactory equivalent: one Salinity Guardian, whatever the address.
class _FakeRfLink implements RfDeviceLink {
  const _FakeRfLink(this.serial);
  final String serial;

  @override
  Future<RfSnapshot> readOnce(String host) async => RfSnapshot(
    serial: serial,
    modelPrefix: 'RFSG01',
    modelName: 'salinity',
    modelDisplayName: 'Salinity Guardian',
    readings: const [RfReading('salinity', 35, 'ppt')],
  );
}
