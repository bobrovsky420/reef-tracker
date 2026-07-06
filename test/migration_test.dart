import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// These tests guard the recurring Drift migration pitfall (see the project
/// memory `drift-migration-createtable-pitfall`): `createTable`/`addColumn`
/// build from the CURRENT schema, so on a multi-version upgrade they can target
/// objects that already exist and throw "duplicate column/table". Every
/// migration step from v3 onward is guarded by `_tableExists`/`_columnExists`;
/// we prove that idempotency by running those steps against a schema that
/// already contains everything.
///
/// The unguarded `from < 2`/`from < 3` steps (and the v11 backfill against
/// rows that genuinely predate the segment columns) are exercised in the
/// "genuine legacy schemas" group below by hand-crafting the old table shapes
/// with raw SQL — migrations only ever ADD to those tables, so an
/// SQL-compatible reconstruction is sufficient even without historical Drift
/// schema dumps.
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
          "AND name LIKE 'idx_%'",
        )
        .map((r) => r.read<String>('name'))
        .get();
    return rows.toSet();
  }

  test('current onCreate schema is usable end to end', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
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
    expect(
      await indexNames(seed),
      isNot(containsAll(expectedIndexes)),
      reason: 'sanity: indexes were dropped before the upgrade',
    );
    await seed.customStatement('PRAGMA user_version = 11');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    // Forcing a query runs beforeOpen -> onUpgrade(11, schemaVersion).
    await db.customSelect('SELECT 1').get();
    expect(await indexNames(db), containsAll(expectedIndexes));
  });

  group('genuine legacy schemas', () {
    /// Rebuilds the real v1 (or v2) schema in a temp file: the four original
    /// tables only, without any column added by a later migration. Starts from
    /// a normally created database, then swaps the current tables for the old
    /// shapes via raw SQL and rewinds the recorded version.
    Future<File> seedGenuineLegacy(int version) async {
      assert(version == 1 || version == 2);
      final file = File('${tempDir.path}/genuine-v$version.sqlite');
      final seed = AppDatabase(NativeDatabase(file));
      // Drop everything onCreate built (children before parents for the FKs).
      for (final table in const [
        'readings',
        'water_changes',
        'carbon_changes',
        'equipment_cleanings',
        'ratio_visibilities',
        'dosing_entries',
        'tracked_parameters',
        'settings',
        'tanks',
      ]) {
        await seed.customStatement('DROP TABLE IF EXISTS $table');
      }
      // v2 = v1 plus the nullable tanks.start_date column.
      final startDate = version >= 2 ? 'start_date INTEGER, ' : '';
      await seed.customStatement(
        'CREATE TABLE tanks ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'setup_type TEXT NOT NULL, '
        'volume_liters REAL, '
        '$startDate'
        "created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')))",
      );
      await seed.customStatement(
        'CREATE TABLE tracked_parameters ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'tank_id INTEGER NOT NULL REFERENCES tanks (id) ON DELETE CASCADE, '
        'param_key TEXT NOT NULL, '
        'unit TEXT NOT NULL, '
        'enabled INTEGER NOT NULL DEFAULT 1, '
        'display_order INTEGER NOT NULL DEFAULT 0, '
        'amber_low REAL, green_low REAL, green_high REAL, amber_high REAL)',
      );
      await seed.customStatement(
        'CREATE TABLE readings ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'tank_id INTEGER NOT NULL REFERENCES tanks (id) ON DELETE CASCADE, '
        'param_key TEXT NOT NULL, '
        'value REAL NOT NULL, '
        'taken_at INTEGER NOT NULL, '
        'note TEXT)',
      );
      await seed.customStatement(
        'CREATE TABLE settings ("key" TEXT NOT NULL PRIMARY KEY, value TEXT)',
      );
      // Pre-existing data that must survive the upgrade (drift stores
      // DateTimes as unix seconds).
      await seed.customStatement(
        "INSERT INTO tanks (id, name, setup_type, volume_liters, created_at) "
        "VALUES (1, 'Old reef', 'mixed', 180, 1600000000)",
      );
      await seed.customStatement(
        "INSERT INTO tracked_parameters (tank_id, param_key, unit) "
        "VALUES (1, 'alkalinity', 'dKH')",
      );
      await seed.customStatement(
        'INSERT INTO readings (tank_id, param_key, value, taken_at) '
        'VALUES (1, \'alkalinity\', 8.2, 1600000100)',
      );
      await seed.customStatement(
        'INSERT INTO settings ("key", value) VALUES (\'active_tank_id\', \'1\')',
      );
      await seed.customStatement('PRAGMA user_version = $version');
      await seed.close();
      return file;
    }

    // v1 exercises the unguarded `from < 2` addColumn(start_date); v2 starts
    // at the unguarded `from < 3` createTable(water_changes), whose
    // current-definition table already contains `note` — so the `from < 4`
    // guard must skip the addColumn instead of throwing "duplicate column".
    for (final from in const [1, 2]) {
      test(
        'a genuine v$from database upgrades to the current schema intact',
        () async {
          final file = await seedGenuineLegacy(from);
          final db = AppDatabase(NativeDatabase(file));
          addTearDown(db.close);

          // Pre-existing rows survive and map through the full current shape.
          final tank = (await db.getAllTanks()).single;
          expect(tank.name, 'Old reef');
          expect(tank.startDate, isNull); // added by v2, null-backfilled
          expect(tank.notes, isNull); // added by v10
          final reading = (await db.getAllReadings()).single;
          expect(reading.value, 8.2);
          expect(
            reading.groupId,
            isNull,
            reason: 'pre-v13 rows keep timestamp grouping (#15)',
          );
          expect(
            (await db.getTrackedParameters(tank.id)).single.paramKey,
            'alkalinity',
          );

          // Tables that did not exist at v$from were created and are usable.
          await db.insertWaterChange(
            tankId: tank.id,
            changedAt: DateTime(2026, 1, 2),
            amountLiters: 20,
          );
          expect((await db.getAllWaterChanges()).single.amountLiters, 20);
          expect(await db.getAllDosingEntries(), isEmpty);
          expect(await indexNames(db), containsAll(expectedIndexes));

          final ver = await db
              .customSelect('PRAGMA user_version')
              .map((r) => r.read<int>('user_version'))
              .getSingle();
          expect(ver, db.schemaVersion);
        },
      );
    }

    test(
      'v10 dosing rows get started_at backfilled and an active state',
      () async {
        final file = File('${tempDir.path}/genuine-v10.sqlite');
        final seed = AppDatabase(NativeDatabase(file));
        final tankId = await seed.createTankWithPreset(
          name: 'T',
          type: SetupType.mixed,
        );
        // Swap dosing_entries for its real v9/v10 shape (no segment columns).
        await seed.customStatement('DROP TABLE dosing_entries');
        await seed.customStatement(
          'CREATE TABLE dosing_entries ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'tank_id INTEGER NOT NULL REFERENCES tanks (id) ON DELETE CASCADE, '
          'product_key TEXT, vendor TEXT, program TEXT, product TEXT NOT NULL, '
          'element_key TEXT, amount REAL, amount_unit TEXT, basis TEXT, '
          'frequency TEXT, interval_days INTEGER, weekdays TEXT, '
          'dose_time TEXT, note TEXT, '
          'display_order INTEGER NOT NULL DEFAULT 0, '
          "created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')))",
        );
        await seed.customStatement(
          'INSERT INTO dosing_entries (tank_id, product, created_at) VALUES '
          "($tankId, 'Kalk', 1600000000), ($tankId, 'All-For-Reef', 1600100000)",
        );
        await seed.customStatement('PRAGMA user_version = 10');
        await seed.close();

        final db = AppDatabase(NativeDatabase(file));
        addTearDown(db.close);

        final entries = await db.getAllDosingEntries();
        expect(entries, hasLength(2));
        for (final e in entries) {
          expect(
            e.startedAt,
            e.createdAt,
            reason: 'pre-history rows start when they were created',
          );
          expect(e.endedAt, isNull);
          expect(e.state, DosingState.active.name);
        }
      },
    );

    test('combined v8 upgrade: dosing table created by from<9, then the v11 '
        'segment steps no-op cleanly', () async {
      final file = File('${tempDir.path}/genuine-v8.sqlite');
      final seed = AppDatabase(NativeDatabase(file));
      final tankId = await seed.createTankWithPreset(
        name: 'T',
        type: SetupType.mixed,
      );
      // v8 shape: no dosing_entries at all, no tank detail columns yet.
      await seed.customStatement('DROP TABLE dosing_entries');
      for (final col in const ['notes', 'vendor', 'model']) {
        await seed.customStatement('ALTER TABLE tanks DROP COLUMN $col');
      }
      await seed.customStatement('PRAGMA user_version = 8');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final tank = (await db.getAllTanks()).single;
      expect(tank.id, tankId);
      expect(tank.notes, isNull); // re-added by the from<10 step
      // from<9 created dosing_entries from the CURRENT definition (segment
      // columns included), so the from<11 guards must skip and the backfill
      // must no-op; a fresh insert gets its segment fields.
      await db.insertDosingEntry(
        DosingEntriesCompanion.insert(tankId: tank.id, product: 'Kalk'),
      );
      final entry = (await db.getAllDosingEntries()).single;
      expect(entry.state, DosingState.active.name);
      expect(entry.startedAt, isNotNull);
    });
  });

  test('upgrading from v13 creates the reading_templates table (U9)', () async {
    // seedFullSchemaAt builds the current schema, so drop the table (and
    // its index) to reconstruct a genuine v13 file where the from<14 step
    // must actually create both.
    final file = File('${tempDir.path}/from13-notemplates.sqlite');
    final seed = AppDatabase(NativeDatabase(file));
    await seed.getAllTanks();
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_reading_templates_tank',
    );
    await seed.customStatement('DROP TABLE reading_templates');
    await seed.customStatement('PRAGMA user_version = 13');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    final id = await db.insertReadingTemplate(
      tankId: tankId,
      name: 'Weekly',
      paramKeys: ['alkalinity', 'calcium'],
    );
    expect(id, greaterThan(0));
    expect(await indexNames(db), contains('idx_reading_templates_tank'));
  });

  test('upgrading from v14 adds the tanks.deleted_at column (U10)', () async {
    // seedFullSchemaAt builds the current schema, so drop the column to
    // reconstruct a genuine v14 file where the from<15 step must add it.
    final file = File('${tempDir.path}/from14-nodeletedat.sqlite');
    final seed = AppDatabase(NativeDatabase(file));
    await seed.getAllTanks();
    await seed.customStatement('ALTER TABLE tanks DROP COLUMN deleted_at');
    await seed.customStatement('PRAGMA user_version = 14');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final id = await db.createTankWithPreset(name: 'R', type: SetupType.mixed);
    // Exercises the new column on both the write and the filtered read path.
    await db.softDeleteTank(id);
    expect(await db.getTanks(), isEmpty);
    expect(await db.restoreTank(id), isTrue);
    expect((await db.getTanks()).single.id, id);
  });

  test('upgrading from v15 adds the reminders schema (U1/U2/U12)', () async {
    // seedFullSchemaAt builds the current schema, so drop everything v16
    // added to reconstruct a genuine v15 file where the from<16 step must
    // add the two columns and create the table + index.
    final file = File('${tempDir.path}/from15-noreminders.sqlite');
    final seed = AppDatabase(NativeDatabase(file));
    await seed.getAllTanks();
    await seed.customStatement(
      'ALTER TABLE tracked_parameters DROP COLUMN test_cadence_days',
    );
    await seed.customStatement(
      'ALTER TABLE dosing_entries DROP COLUMN remind_enabled',
    );
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_maintenance_schedules_tank',
    );
    await seed.customStatement('DROP TABLE maintenance_schedules');
    await seed.customStatement('PRAGMA user_version = 15');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    // Exercise all three additions on real write + read paths.
    final param = (await db.getTrackedParameters(tankId)).first;
    await db.setTestCadence(param.id, 7);
    expect(
      (await db.getTrackedParameters(
        tankId,
      )).firstWhere((p) => p.id == param.id).testCadenceDays,
      7,
    );
    final scheduleId = await db.insertMaintenanceSchedule(
      tankId: tankId,
      actionType: 'waterChange',
      cadenceDays: 14,
    );
    expect(scheduleId, greaterThan(0));
    expect(await indexNames(db), contains('idx_maintenance_schedules_tank'));
    final entryId = await db.insertDosingEntry(
      DosingEntriesCompanion.insert(tankId: tankId, product: 'Kalk'),
    );
    expect(
      (await db.getAllDosingEntries())
          .firstWhere((d) => d.id == entryId)
          .remindEnabled,
      isFalse,
    );
  });

  group('guarded migration steps are idempotent', () {
    // v3..(schemaVersion-1): re-running each upgrade against a schema that
    // already has every table/column must not throw.
    for (
      var from = 3;
      from < AppDatabase(NativeDatabase.memory()).schemaVersion;
      from++
    ) {
      test('upgrading from a (faux) v$from completes without error', () async {
        final file = await seedFullSchemaAt(from);
        final db = AppDatabase(NativeDatabase(file));
        addTearDown(db.close);

        // Forcing a query runs beforeOpen -> onUpgrade(from, schemaVersion).
        // A failed migration throws here.
        await db.customSelect('SELECT 1').get();

        // Schema is still complete & functional after the replayed migration.
        final id = await db.createTankWithPreset(
          name: 'M',
          type: SetupType.lps,
        );
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
