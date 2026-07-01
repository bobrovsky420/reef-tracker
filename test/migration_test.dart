import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// These tests guard the recurring Drift migration pitfall (see the project
/// memory `drift-migration-createtable-pitfall`): `createTable`/`addColumn`
/// build from the CURRENT schema, so on a multi-version upgrade they can target
/// objects that already exist and throw "duplicate column/table". Every
/// migration step from v3 onward is guarded by `_tableExists`/`_columnExists`;
/// we prove that idempotency by running those steps against a schema that
/// already contains everything.
///
/// We can't synthesize the *original* v1/v2 schemas without historical Drift
/// schema dumps, so we don't exercise the (unguarded) `from < 2`/`from < 3`
/// steps here — those only ever run on a genuinely old database.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reeftracker-mig-');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Creates a complete current-schema database in a temp file, then rewinds
  /// its recorded version to [fromVersion] so the next open replays the
  /// migration steps for `from >= fromVersion`.
  Future<File> seedFullSchemaAt(int fromVersion) async {
    final file = File('${tempDir.path}/from$fromVersion.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    // Force the lazy database open so onCreate builds the full v$schemaVersion
    // schema, then pretend the file is older.
    await db.getAllTanks();
    await db.customStatement('PRAGMA user_version = $fromVersion');
    await db.close();
    return file;
  }

  /// The secondary indexes added in schema v12 for the hot read paths.
  const expectedIndexes = {
    'idx_readings_tank_param_taken',
    'idx_readings_tank_taken',
    'idx_water_changes_tank_changed',
    'idx_carbon_changes_tank_changed',
    'idx_equipment_cleanings_tank_cleaned',
    'idx_dosing_entries_tank',
  };

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_%'")
        .map((r) => r.read<String>('name'))
        .get();
    return rows.toSet();
  }

  test('current onCreate schema is usable end to end', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id =
        await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    expect(await db.getTrackedParameters(id), isNotEmpty);
  });

  test('onCreate builds the hot-path indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Force the lazy open so onCreate/createAll runs.
    await db.getAllTanks();
    expect(await indexNames(db), containsAll(expectedIndexes));
  });

  test('upgrading from v11 creates the hot-path indexes', () async {
    // seedFullSchemaAt builds the *current* schema, so createAll already made
    // the v12 indexes. Drop them and rewind to v11 so the migration must
    // genuinely re-create them (not just no-op on IF NOT EXISTS).
    final file = File('${tempDir.path}/from11-noindexes.sqlite');
    final seed = AppDatabase(NativeDatabase(file));
    await seed.getAllTanks();
    for (final name in expectedIndexes) {
      await seed.customStatement('DROP INDEX IF EXISTS $name');
    }
    expect(await indexNames(seed), isNot(containsAll(expectedIndexes)),
        reason: 'sanity: indexes were dropped before the upgrade');
    await seed.customStatement('PRAGMA user_version = 11');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    // Forcing a query runs beforeOpen -> onUpgrade(11, schemaVersion).
    await db.customSelect('SELECT 1').get();
    expect(await indexNames(db), containsAll(expectedIndexes));
  });

  group('guarded migration steps are idempotent', () {
    // v3..(schemaVersion-1): re-running each upgrade against a schema that
    // already has every table/column must not throw.
    for (var from = 3; from < AppDatabase(NativeDatabase.memory()).schemaVersion;
        from++) {
      test('upgrading from a (faux) v$from completes without error', () async {
        final file = await seedFullSchemaAt(from);
        final db = AppDatabase(NativeDatabase(file));
        addTearDown(db.close);

        // Forcing a query runs beforeOpen -> onUpgrade(from, schemaVersion).
        // A failed migration throws here.
        await db.customSelect('SELECT 1').get();

        // Schema is still complete & functional after the replayed migration.
        final id =
            await db.createTankWithPreset(name: 'M', type: SetupType.lps);
        expect(await db.getTrackedParameters(id), isNotEmpty);

        // The version is bumped to current after a successful migration.
        final ver = await db
            .customSelect('PRAGMA user_version')
            .map((r) => r.read<int>('user_version'))
            .getSingle();
        expect(ver, db.schemaVersion);
      });
    }
  });
}
