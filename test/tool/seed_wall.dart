import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/device_secrets.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Not a test — a seeding helper (the `seed_devices.dart` pattern) for
/// exercising the **wall display** (U49) on the emulator: one tank with a
/// realistic measurement history plus a full set of live fake devices, all
/// pointing at the host's emulators on 10.0.2.2. Start these first:
///
///     dart run tool/apex_emulator.dart --port 8080
///     dart run tool/reeffactory_emulator.dart --model salinity --port 8081
///     dart run tool/reeffactory_emulator.dart --model ph --port 8082
///     dart run tool/reeffactory_emulator.dart --model temperature --port 8083
///     dart run tool/reefbeat_emulator.dart --type ato --port 8090
///     dart run tool/reefbeat_emulator.dart --type run --port 8091
///     dart run tool/reefbeat_emulator.dart --type dose --port 8092
///     dart run tool/reefbeat_emulator.dart --type control --port 8093
///
/// The history matters here: alkalinity/calcium/magnesium have readings but
/// no reporting device (stored-readings cards with the 14-day line), while
/// recent temperature and pH hand readings land inside the 24 h sample window
/// (markers on the live lines). The refresh interval is pre-set to 30 s so
/// sample graphs build up while you watch.
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed_wall.sqlite',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate a wall-display database', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    final settings = AppSettings(db);

    final tank = await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
      volumeLiters: 300,
      startDate: DateTime.now().subtract(const Duration(days: 300)),
    );
    await db.setActiveTank(tank);

    // Two weeks of hand measurements: the no-device cards' 14-day lines, and
    // in-window markers for the sampled parameters.
    final now = DateTime.now();
    Future<void> series(String key, double base, double step) async {
      for (var d = 14; d >= 0; d -= 2) {
        await db.insertReadingGroup(
          tankId: tank,
          takenAt: now.subtract(Duration(days: d, hours: 3)),
          values: [(paramKey: key, value: base + step * (14 - d) / 14)],
        );
      }
    }

    await series('alkalinity', 7.8, 0.5);
    await series('calcium', 415, 10);
    await series('magnesium', 1290, 30);
    await series('nitrate', 8, -2);
    // A tracked microelement with history: the wall must ignore it entirely
    // (wall_parameters.yaml — microelements are excluded by design), so no
    // iodine card may appear on the board or in the Settings card list.
    await db.addTrackedParameter(tank, 'iodine');
    await series('iodine', 0.05, 0.02);
    // An RO stage well past its lifespan: the wall shows no RO tile (the RO
    // unit was removed from the wall display), so nothing here may surface it
    // however overdue it is — same prove-absence idea as the iodine series.
    final roStage = await db.insertRoStage(
      stageType: 'sediment',
      lifespanDays: 90,
    );
    await db.insertRoReplacement(
      stageId: roStage,
      replacedAt: now.subtract(const Duration(days: 120)),
    );
    // Recent hand tests inside the 24 h window — markers on the live lines.
    await db.insertReadingGroup(
      tankId: tank,
      takenAt: now.subtract(const Duration(hours: 5)),
      values: const [
        (paramKey: 'temperature', value: 25.3),
        (paramKey: 'ph', value: 8.15),
      ],
    );

    await db.upsertReefFactoryDevice(
      identifier: 'RFSG01-EMU',
      model: 'RFSG01',
      address: '10.0.2.2:8081',
      name: 'Salinity Guardian',
      tankId: tank,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFPM01-EMU',
      model: 'RFPM01',
      address: '10.0.2.2:8082',
      name: 'pH Monitor',
      tankId: tank,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFTC01-EMU',
      model: 'RFTC01',
      address: '10.0.2.2:8083',
      name: 'Temperature Controller',
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
    await db.upsertReefBeatDevice(
      identifier: 'RSDOSE-EMU',
      model: 'RSDOSE4',
      address: '10.0.2.2:8092',
      name: 'ReefDose 4',
      tankId: tank,
    );
    await db.upsertReefBeatDevice(
      identifier: 'RSCONTROL-EMU',
      model: 'RSCONTROLPRO',
      address: '10.0.2.2:8093',
      name: 'ReefControl Pro',
      tankId: tank,
    );
    await db.upsertApexDevice(
      identifier: 'AC5:12345',
      model: 'Apex',
      address: '10.0.2.2:8080',
      username: 'admin',
      name: 'Apex',
      tankId: tank,
    );
    // The Apex password lives in the backup-excluded sidecar (#68), written
    // beside the .sqlite so the same run-as push installs both.
    await DeviceSecrets(
      directory: () async => file.parent,
    ).write('AC5:12345', '1234');

    await settings.setTourSeen(true);
    await settings.setExperimentalEnabled(true);
    await settings.seedLegacyFreeSince('0.0.0-seed');
    await settings.setWallAutoStart(true);
    // Fast cycles so the 24 h sample lines visibly build during verification.
    await settings.setWallRefreshInterval(const Duration(seconds: 30));

    await db.close();
    stdout.writeln('Wrote $_out');
  });
}
