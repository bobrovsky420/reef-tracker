import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Not a test — a one-off seeding helper (like `seed_sample_data.dart`) for
/// verifying the Manage-backups device-name nudge on the emulator: a tank,
/// the tour skipped, Drive sync "connected" (account set) but NO device name,
/// which is exactly the state a pre-U35 connect is stuck in.
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed_nudge.sqlite',
);

void main() {
  test('generate gdrive nudge database', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
      volumeLiters: 300,
    );
    final settings = AppSettings(db);
    await settings.setTourSeen(true);
    await settings.setSyncGdriveAccount('demo.reefkeeper@gmail.com');
    await db.close();

    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path}');
  });
}
