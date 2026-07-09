import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/database.dart';

/// Not a test — a seeding helper run via `flutter test` that turns a real
/// backup JSON export into a fully migrated (current-schema)
/// `reeftracker.sqlite`, which is then `run-as`-pushed into the emulator's
/// app_flutter/ dir (same flow as `seed_sample_data.dart`).
///
/// Paths come from dart-defines:
///   --dart-define=BACKUP_IN=<backup json>   (required)
///   --dart-define=SEED_OUT=<sqlite out>     (default C:\Android\reefbuild\seed.sqlite)
const _in = String.fromEnvironment('BACKUP_IN');
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed.sqlite',
);

void main() {
  test('generate database from backup', () async {
    expect(_in, isNotEmpty, reason: 'pass --dart-define=BACKUP_IN=<path>');
    final data = decodeBackup(await File(_in).readAsString());

    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    validateBackup(data, appSchemaVersion: db.schemaVersion);
    // Direct restore (not importBackup): no rehearsal DB — that path needs
    // path_provider — and no preserved device-local keys, so the backup's
    // own settings (active tank, tour seen, units) land in the seed too.
    await db.restoreFromBackup(
      tankRows: data.tanks,
      paramRows: data.params,
      readingRows: data.readings,
      waterChangeRows: data.waterChanges,
      carbonChangeRows: data.carbonChanges,
      equipmentCleaningRows: data.equipmentCleanings,
      ratioVisibilityRows: data.ratioVisibilities,
      dosingEntryRows: data.dosingEntries,
      readingTemplateRows: data.readingTemplates,
      microViewRows: data.microViews,
      maintenanceScheduleRows: data.maintenanceSchedules,
      roStageRows: data.roStages,
      roStageReplacementRows: data.roStageReplacements,
      settingRows: data.settings,
    );
    final tanks = await db.getAllTanks();
    await db.close();

    expect(await file.exists(), isTrue);
    expect(tanks, isNotEmpty);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path} tanks=${tanks.length}');
  });
}
