import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// The Hanna checker's Devices-page card (U43): once the measurement flow has
/// recorded the checker, the page shows it as its own vendor section — serial,
/// last-measurement time, and the entry point for a new measurement — without
/// any of the LAN vendors' read/save machinery.
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

  Future<AppDatabase> seed({bool experimental = true}) async {
    final db = AppDatabase(NativeDatabase.memory());
    // The founder marker entitles the page's Pro actions; the experimental
    // switch is what surfaces the checker's measure entry points (U33).
    await AppSettings(db).seedLegacyFreeSince('0.0.0-test');
    if (experimental) await AppSettings(db).setExperimentalEnabled(true);
    // What the measurement flow records on first BLE connect.
    await db.ensureHannaDevice(
      identifier: 'HI97115 06150128',
      model: 'HI97115',
    );
    return db;
  }

  Future<void> pumpDevices(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          // `flutter test` has no BLE plugin, which would report unsupported
          // and hide the measure button — the card must be tested as a
          // BLE-capable phone shows it.
          hannaBleSupportedProvider.overrideWith((ref) async => true),
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

  testWidgets('the recorded checker gets a card: serial, last measurement, '
      'measure button', (tester) async {
    final db = await seed();
    addTearDown(db.close);

    await pumpDevices(tester, db);

    // Named by its model (ensureHannaDevice stores no user name), with the
    // serial split out of the advertised identifier.
    expect(find.text('HI97115'), findsOneWidget);
    expect(find.text('Serial number'), findsOneWidget);
    expect(find.text('06150128'), findsOneWidget);
    // `lastSeenAt` was stamped by ensureHannaDevice just now — the row shows
    // a time, not the null dash.
    expect(find.text('Last measurement'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.text('New measurement'), findsOneWidget);

    // None of the LAN machinery: a single Hanna device means no refreshable
    // and no meter-capable devices, so the FAB slot stays empty.
    expect(find.byType(FloatingActionButton), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('with experimental features off the card stays, the measure '
      'button hides', (tester) async {
    final db = await seed(experimental: false);
    addTearDown(db.close);

    await pumpDevices(tester, db);

    // The inventory the keeper already earned is not hidden…
    expect(find.text('HI97115'), findsOneWidget);
    expect(find.text('06150128'), findsOneWidget);
    // …but every entry point of the experimental feature is (U33).
    expect(find.text('New measurement'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('the checker joins the vendor chips next to a LAN vendor', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    // An empty address keeps the on-open auto-read from opening a socket.
    await db.upsertReefBeatDevice(
      identifier: 'RB-1',
      model: 'RSDOSE4',
      address: '',
      name: 'My pump',
    );

    await pumpDevices(tester, db);

    // Two vendors present → chips appear, the checker's included.
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.textContaining('Hanna checker'), findsWidgets);
    // Both sections render under the All view.
    expect(find.text('My pump'), findsOneWidget);
    expect(find.text('HI97115'), findsOneWidget);
    await unmountApp(tester);
  });
}
