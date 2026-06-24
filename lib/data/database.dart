import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/parameter_catalog.dart';
import '../domain/presets.dart';
import '../domain/setup_type.dart';
import '../domain/units.dart';
import '../domain/zones.dart';

/// Re-export drift's [Value] wrapper so UI code building companions/copyWith
/// calls can use it without importing all of drift.
export 'package:drift/drift.dart' show Value;

part 'database.g.dart';

/// One aquarium.
class Tanks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Stored as [SetupType.name].
  TextColumn get setupType => text()();
  RealColumn get volumeLiters => real().nullable()();

  /// When the aquarium was set up/started (optional, user-editable).
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A parameter the user tracks for a specific tank, plus its zone boundaries.
class TrackedParameters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get paramKey => text()();
  TextColumn get unit => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  RealColumn get amberLow => real().nullable()();
  RealColumn get greenLow => real().nullable()();
  RealColumn get greenHigh => real().nullable()();
  RealColumn get amberHigh => real().nullable()();
}

/// A single logged measurement.
class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get paramKey => text()();
  RealColumn get value => real()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get note => text().nullable()();
}

/// A logged water change for a tank (date/time + optional volume + note).
class WaterChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get changedAt => dateTime()();

  /// Volume of water exchanged, in litres. Optional.
  RealColumn get amountLiters => real().nullable()();

  /// Free-text note (e.g. salt brand). Optional.
  TextColumn get note => text().nullable()();
}

/// A logged activated-carbon change for a tank (date/time + optional weight
/// in grams + note, e.g. the brand).
class CarbonChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get changedAt => dateTime()();

  /// Weight of carbon used, in grams. Optional.
  RealColumn get grams => real().nullable()();

  /// Free-text note (e.g. brand). Optional.
  TextColumn get note => text().nullable()();
}

/// Simple key/value store for app-wide settings (e.g. active tank).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

const _kActiveTankKey = 'active_tank_id';

@DriftDatabase(tables: [
  Tanks,
  TrackedParameters,
  Readings,
  WaterChanges,
  CarbonChanges,
  Settings
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tanks, tanks.startDate);
          }
          if (from < 3) {
            await m.createTable(waterChanges);
          }
          if (from < 4) {
            // `createTable` builds a table from its CURRENT definition. When
            // upgrading straight from a schema before v3, the createTable above
            // already creates water_changes WITH the `note` column, so adding
            // it again would throw "duplicate column name: note". Guard against
            // that (and any partially-applied state) by checking first.
            if (!await _columnExists('water_changes', 'note')) {
              await m.addColumn(waterChanges, waterChanges.note);
            }
            if (!await _tableExists('carbon_changes')) {
              await m.createTable(carbonChanges);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Whether a table with [name] currently exists (used to keep migrations
  /// idempotent across multi-version upgrades).
  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Whether [table] currently has a column named [column].
  Future<bool> _columnExists(String table, String column) async {
    if (!await _tableExists(table)) return false;
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  // --- Tanks ---------------------------------------------------------------

  Stream<List<Tank>> watchTanks() =>
      (select(tanks)..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  Future<List<Tank>> getTanks() =>
      (select(tanks)..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();

  Future<Tank> getTank(int id) =>
      (select(tanks)..where((t) => t.id.equals(id))).getSingle();

  /// Creates a tank, seeds its default tracked parameters from the setup-type
  /// preset, and makes it the active tank. Returns the new tank id.
  Future<int> createTankWithPreset({
    required String name,
    required SetupType type,
    double? volumeLiters,
    DateTime? startDate,
  }) async {
    return transaction(() async {
      final tankId = await into(tanks).insert(TanksCompanion.insert(
        name: name,
        setupType: type.name,
        volumeLiters: Value(volumeLiters),
        startDate: Value(startDate),
      ));
      await _seedTrackedParameters(tankId, type);
      await setActiveTank(tankId);
      return tankId;
    });
  }

  Future<void> updateTank(Tank tank) => update(tanks).replace(tank);

  Future<void> deleteTank(int id) async {
    await transaction(() async {
      await (delete(tanks)..where((t) => t.id.equals(id))).go();
      final remaining = await getTanks();
      final active = await getActiveTankId();
      if (active == id) {
        await setActiveTank(remaining.isEmpty ? null : remaining.first.id);
      }
    });
  }

  Future<void> _seedTrackedParameters(int tankId, SetupType type) async {
    final keys = defaultTrackedKeys(type);
    await batch((b) {
      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        final def = kParameterByKey[key];
        final bounds = presetBounds(type, key);
        b.insert(
          trackedParameters,
          TrackedParametersCompanion.insert(
            tankId: tankId,
            paramKey: key,
            unit: def?.unit ?? '',
            displayOrder: Value(i),
            amberLow: Value(bounds.amberLow),
            greenLow: Value(bounds.greenLow),
            greenHigh: Value(bounds.greenHigh),
            amberHigh: Value(bounds.amberHigh),
          ),
        );
      }
    });
  }

  // --- Tracked parameters --------------------------------------------------

  Stream<List<TrackedParameter>> watchTrackedParameters(int tankId) =>
      (select(trackedParameters)
            ..where((t) => t.tankId.equals(tankId))
            ..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]))
          .watch();

  Future<List<TrackedParameter>> getTrackedParameters(int tankId) =>
      (select(trackedParameters)
            ..where((t) => t.tankId.equals(tankId))
            ..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]))
          .get();

  /// Adds a parameter to a tank if not already present (seeding preset bounds).
  Future<void> addTrackedParameter(
      int tankId, String paramKey, SetupType type) async {
    final existing = await (select(trackedParameters)
          ..where(
              (t) => t.tankId.equals(tankId) & t.paramKey.equals(paramKey)))
        .get();
    if (existing.isNotEmpty) return;
    final def = kParameterByKey[paramKey];
    final bounds = presetBounds(type, paramKey);
    final order = (await getTrackedParameters(tankId)).length;
    await into(trackedParameters).insert(TrackedParametersCompanion.insert(
      tankId: tankId,
      paramKey: paramKey,
      unit: def?.unit ?? '',
      displayOrder: Value(order),
      amberLow: Value(bounds.amberLow),
      greenLow: Value(bounds.greenLow),
      greenHigh: Value(bounds.greenHigh),
      amberHigh: Value(bounds.amberHigh),
    ));
  }

  Future<void> updateTrackedParameter(TrackedParameter param) =>
      update(trackedParameters).replace(param);

  Future<void> removeTrackedParameter(int id) =>
      (delete(trackedParameters)..where((t) => t.id.equals(id))).go();

  Future<void> reorderTrackedParameters(List<int> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          trackedParameters,
          TrackedParametersCompanion(displayOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  /// Re-applies the setup-type preset bounds to every tracked parameter of a
  /// tank that the preset knows about. Does not add/remove parameters.
  Future<void> applyPreset(int tankId, SetupType type) async {
    final params = await getTrackedParameters(tankId);
    await batch((b) {
      for (final param in params) {
        final bounds = kPresets[type]?[param.paramKey];
        if (bounds == null) continue;
        b.update(
          trackedParameters,
          TrackedParametersCompanion(
            amberLow: Value(bounds.amberLow),
            greenLow: Value(bounds.greenLow),
            greenHigh: Value(bounds.greenHigh),
            amberHigh: Value(bounds.amberHigh),
          ),
          where: (t) => t.id.equals(param.id),
        );
      }
    });
  }

  // --- Readings ------------------------------------------------------------

  /// All readings for a tank, newest first.
  Stream<List<Reading>> watchReadingsForTank(int tankId) =>
      (select(readings)
            ..where((r) => r.tankId.equals(tankId))
            ..orderBy([
              (r) => OrderingTerm(
                  expression: r.takenAt, mode: OrderingMode.desc)
            ]))
          .watch();

  /// Readings for a single parameter, oldest first (chart-friendly order).
  Stream<List<Reading>> watchParamReadings(int tankId, String paramKey) =>
      (select(readings)
            ..where(
                (r) => r.tankId.equals(tankId) & r.paramKey.equals(paramKey))
            ..orderBy([(r) => OrderingTerm(expression: r.takenAt)]))
          .watch();

  Future<void> insertReading({
    required int tankId,
    required String paramKey,
    required double value,
    required DateTime takenAt,
    String? note,
  }) =>
      into(readings).insert(ReadingsCompanion.insert(
        tankId: tankId,
        paramKey: paramKey,
        value: value,
        takenAt: takenAt,
        note: Value(note),
      ));

  Future<void> updateReading(Reading reading) =>
      update(readings).replace(reading);

  Future<void> deleteReading(int id) =>
      (delete(readings)..where((r) => r.id.equals(id))).go();

  /// Readings saved together with the same timestamp for a tank (i.e. entered
  /// in one go on the add-reading screen), including the one being inspected.
  Future<List<Reading>> readingsAt(int tankId, DateTime takenAt) =>
      (select(readings)
            ..where((r) => r.tankId.equals(tankId) & r.takenAt.equals(takenAt)))
          .get();

  /// Deletes every reading saved together at [takenAt] for [tankId].
  /// Returns the number of rows removed.
  Future<int> deleteReadingsAt(int tankId, DateTime takenAt) =>
      (delete(readings)
            ..where((r) => r.tankId.equals(tankId) & r.takenAt.equals(takenAt)))
          .go();

  // --- Water changes -------------------------------------------------------

  /// Water changes for a tank, newest first.
  Stream<List<WaterChange>> watchWaterChanges(int tankId) =>
      (select(waterChanges)
            ..where((w) => w.tankId.equals(tankId))
            ..orderBy([
              (w) => OrderingTerm(
                  expression: w.changedAt, mode: OrderingMode.desc)
            ]))
          .watch();

  Future<void> insertWaterChange({
    required int tankId,
    required DateTime changedAt,
    double? amountLiters,
    String? note,
  }) =>
      into(waterChanges).insert(WaterChangesCompanion.insert(
        tankId: tankId,
        changedAt: changedAt,
        amountLiters: Value(amountLiters),
        note: Value(note),
      ));

  Future<void> updateWaterChange(WaterChange change) =>
      update(waterChanges).replace(change);

  Future<void> deleteWaterChange(int id) =>
      (delete(waterChanges)..where((w) => w.id.equals(id))).go();

  // --- Carbon changes ------------------------------------------------------

  /// Activated-carbon changes for a tank, newest first.
  Stream<List<CarbonChange>> watchCarbonChanges(int tankId) =>
      (select(carbonChanges)
            ..where((c) => c.tankId.equals(tankId))
            ..orderBy([
              (c) => OrderingTerm(
                  expression: c.changedAt, mode: OrderingMode.desc)
            ]))
          .watch();

  Future<void> insertCarbonChange({
    required int tankId,
    required DateTime changedAt,
    double? grams,
    String? note,
  }) =>
      into(carbonChanges).insert(CarbonChangesCompanion.insert(
        tankId: tankId,
        changedAt: changedAt,
        grams: Value(grams),
        note: Value(note),
      ));

  Future<void> updateCarbonChange(CarbonChange change) =>
      update(carbonChanges).replace(change);

  Future<void> deleteCarbonChange(int id) =>
      (delete(carbonChanges)..where((c) => c.id.equals(id))).go();

  // --- Settings ------------------------------------------------------------

  Future<void> setActiveTank(int? tankId) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
        key: _kActiveTankKey,
        value: Value(tankId?.toString()),
      ));

  Future<int?> getActiveTankId() async {
    final row = await (select(settings)
          ..where((s) => s.key.equals(_kActiveTankKey)))
        .getSingleOrNull();
    final v = row?.value;
    return v == null ? null : int.tryParse(v);
  }

  Stream<int?> watchActiveTankId() => (select(settings)
        ..where((s) => s.key.equals(_kActiveTankKey)))
      .watchSingleOrNull()
      .map((row) => row?.value == null ? null : int.tryParse(row!.value!));

  /// Generic settings access (used for unit preferences, etc.).
  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> setSetting(String key, String? value) =>
      into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: Value(value)));

  // --- Backup --------------------------------------------------------------

  /// All tanks across the database (insertion order).
  Future<List<Tank>> getAllTanks() => select(tanks).get();

  /// Every tracked parameter row, across all tanks.
  Future<List<TrackedParameter>> getAllTrackedParameters() =>
      select(trackedParameters).get();

  /// Every reading, across all tanks.
  Future<List<Reading>> getAllReadings() => select(readings).get();

  /// Every water change, across all tanks.
  Future<List<WaterChange>> getAllWaterChanges() => select(waterChanges).get();

  /// Every activated-carbon change, across all tanks.
  Future<List<CarbonChange>> getAllCarbonChanges() =>
      select(carbonChanges).get();

  /// Every settings key/value pair.
  Future<List<Setting>> getAllSettings() => select(settings).get();

  /// Replaces the entire database contents with the supplied rows, preserving
  /// the original primary keys (so foreign-key links stay intact). Runs in a
  /// single transaction: on any error nothing is changed.
  Future<void> restoreFromBackup({
    required List<TanksCompanion> tankRows,
    required List<TrackedParametersCompanion> paramRows,
    required List<ReadingsCompanion> readingRows,
    required List<WaterChangesCompanion> waterChangeRows,
    required List<CarbonChangesCompanion> carbonChangeRows,
    required List<SettingsCompanion> settingRows,
  }) async {
    await transaction(() async {
      // Delete children before parents to satisfy foreign keys.
      await delete(readings).go();
      await delete(waterChanges).go();
      await delete(carbonChanges).go();
      await delete(trackedParameters).go();
      await delete(settings).go();
      await delete(tanks).go();
      // Insert parents before children, preserving ids.
      await batch((b) {
        b.insertAll(tanks, tankRows);
        b.insertAll(trackedParameters, paramRows);
        b.insertAll(readings, readingRows);
        b.insertAll(waterChanges, waterChangeRows);
        b.insertAll(carbonChanges, carbonChangeRows);
        b.insertAll(settings, settingRows);
      });
    });
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'reeftracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Convenience: build [ZoneBounds] from a tracked-parameter row.
ZoneBounds boundsOf(TrackedParameter p) => ZoneBounds(
      amberLow: p.amberLow,
      greenLow: p.greenLow,
      greenHigh: p.greenHigh,
      amberHigh: p.amberHigh,
    );

/// Convenience: resolve how to present a tracked parameter's values given the
/// user's unit preferences.
ParamPresentation presentationOf(TrackedParameter p, UnitPrefs prefs) =>
    presentationForKey(p.paramKey, p.unit, prefs);
