import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/device_secrets.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Not a test — a seeding helper (like `seed_sample_data.dart`) that produces a
/// current-schema `reeftracker.sqlite` holding one tank plus **one device of
/// every vendor**, so the unified Devices screen (U41) can be exercised on the
/// emulator with its selector, section headers and reorder sheet all populated.
///
/// The Apex row points at `10.0.2.2:8080` — the host's `tool/apex_emulator.dart`
/// as seen from the Android emulator — so one card reads real live values; its
/// password is written to a sibling `.device_secrets`, which has to be pushed
/// alongside the database (see [DeviceSecrets]). Two ReefBeat rows point at
/// `tool/reefbeat_emulator.dart` the same way (`--type ato` on :8090, `--type
/// run` on :8091), so the ATO's leak-sensor row and the ReefRun's full-cup
/// state can be forced and looked at. The ReefFactory rows and the third
/// ReefBeat row carry unreachable addresses on purpose: their cards render the
/// offline path, which is just as much a state worth looking at. A Hanna
/// checker row (U43) rounds out the vendor set — it has no address to reach.
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed_devices.sqlite',
);

void main() {
  // The sidecar write reaches for a platform channel (the iOS backup-exclusion
  // attribute), which needs a binding even though nothing answers it here.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate a devices database', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    final settings = AppSettings(db);

    final tank = await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
      volumeLiters: 300,
      startDate: DateTime.now().subtract(const Duration(days: 200)),
    );
    await db.setActiveTank(tank);

    await db.upsertReefFactoryDevice(
      identifier: 'RFSG01-DEMO',
      model: 'RFSG01',
      address: '192.168.99.11',
      name: 'Salinity Guardian',
      tankId: tank,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFTC01-DEMO',
      model: 'RFTC01',
      address: '192.168.99.12',
      name: 'Temperature Controller',
      tankId: tank,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSDOSE4-DEMO',
      model: 'RSDOSE4',
      address: '192.168.99.21',
      name: 'ReefDose 4',
      tankId: tank,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSATO-EMU',
      model: 'RSATO+',
      address: '10.0.2.2:8090',
      name: 'ReefATO+',
      tankId: tank,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSRUN-EMU',
      model: 'RSRUN',
      address: '10.0.2.2:8091',
      name: 'ReefRun',
      tankId: tank,
    );
    await db.ensureHannaDevice(
      identifier: 'HI97115 06150128',
      model: 'HI97115',
    );
    await db.upsertApexDevice(
      identifier: 'APEX-DEMO',
      model: 'Apex',
      address: '10.0.2.2:8080',
      username: 'admin',
      name: 'Apex',
      tankId: tank,
    );
    // The Apex password is not in the database (#68) — it lives in the
    // backup-excluded sidecar, written here beside the .sqlite so the same
    // `run-as` push that installs the database can install it too. Without it
    // the seeded card opens on an auth error instead of live values.
    await DeviceSecrets(
      directory: () async => file.parent,
    ).write('APEX-DEMO', '1234');

    // Straight to the feature: no first-run tour, experimental opted in (the
    // Devices tab only exists behind it), and the founder marker so the
    // page's Pro actions (read, save, add) are live rather than the lock
    // notice.
    await settings.setTourSeen(true);
    await settings.setExperimentalEnabled(true);
    await settings.seedLegacyFreeSince('0.0.0-seed');

    await db.close();
    stdout.writeln('Wrote $_out');
  });
}
