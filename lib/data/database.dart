import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/dose_calculator.dart';
import '../domain/parameter_catalog.dart';
import '../domain/presets.dart';
import '../domain/ratio.dart';
import '../domain/setup_type.dart';
import '../domain/supplement_catalog.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import 'setting_keys.dart';

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

  /// Free-text, multi-line notes about the aquarium (optional).
  TextColumn get notes => text().nullable()();

  /// Hardware vendor/manufacturer of the tank (optional, single line).
  TextColumn get vendor => text().nullable()();

  /// Tank model/name (optional, single line).
  TextColumn get model => text().nullable()();

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
@TableIndex(
    name: 'idx_readings_tank_param_taken',
    columns: {#tankId, #paramKey, #takenAt})
@TableIndex(name: 'idx_readings_tank_taken', columns: {#tankId, #takenAt})
class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get paramKey => text()();
  RealColumn get value => real()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get note => text().nullable()();

  /// Identifies readings entered together as one batch on the add-reading
  /// screen (#15). Group edit/delete keys on this instead of the second-level
  /// `takenAt` timestamp, which silently merged distinct groups saved (or
  /// re-timed onto) the same second. Null for rows from before schema v13,
  /// which fall back to timestamp grouping.
  TextColumn get groupId => text().nullable()();
}

/// A logged water change for a tank (date/time + optional volume + note).
@TableIndex(name: 'idx_water_changes_tank_changed', columns: {#tankId, #changedAt})
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
@TableIndex(
    name: 'idx_carbon_changes_tank_changed', columns: {#tankId, #changedAt})
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

/// A logged equipment cleaning for a tank (date/time + optional note, e.g.
/// which piece of equipment was cleaned).
@TableIndex(
    name: 'idx_equipment_cleanings_tank_cleaned',
    columns: {#tankId, #cleanedAt})
class EquipmentCleanings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get cleanedAt => dateTime()();

  /// Free-text note (e.g. the equipment cleaned). Optional.
  TextColumn get note => text().nullable()();
}

/// Per-tank visibility of a dashboard ratio card, keyed by [RatioKind.name]
/// (e.g. `po4no3`, `mgca`). A missing row means the card is visible (default),
/// so only explicit hide/show choices are stored.
@DataClassName('RatioVisibility')
class RatioVisibilities extends Table {
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get ratioKey => text()();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();

  /// Dashboard position, shared with `TrackedParameters.displayOrder`. Defaults
  /// high so ratio cards sit after measurements until the user reorders them.
  IntColumn get displayOrder => integer().withDefault(const Constant(1000))();

  /// Per-tank zone bounds (in the displayed-metric space). Null on all four =
  /// fall back to the kind's recommended defaults.
  RealColumn get amberLow => real().nullable()();
  RealColumn get greenLow => real().nullable()();
  RealColumn get greenHigh => real().nullable()();
  RealColumn get amberHigh => real().nullable()();

  @override
  Set<Column> get primaryKey => {tankId, ratioKey};
}

/// A supplement-dosing plan entry for a tank — an information-only record of
/// what the tank is dosed (vendor/program/product + target element), with an
/// optional dosage and a descriptive schedule. Catalog identity is kept via the
/// stable [productKey] (null for custom entries) so a future dose log and
/// consumption calculator can resolve the product and its potency; display
/// names are denormalized so an entry survives catalog changes.
@TableIndex(name: 'idx_dosing_entries_tank', columns: {#tankId})
class DosingEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();

  /// Stable `SupplementProduct.key` from the catalog, or null for a custom
  /// (free-text) entry.
  TextColumn get productKey => text().nullable()();

  /// Denormalized display names (the catalog values at entry time, or the
  /// user's free text for a custom entry).
  TextColumn get vendor => text().nullable()();
  TextColumn get program => text().nullable()();
  TextColumn get product => text()();

  /// Target element as a real `Readings.paramKey` (e.g. `alkalinity`), or null
  /// for trace/multi-element products.
  TextColumn get elementKey => text().nullable()();

  /// Dosage amount in its canonical unit (ml or g), optional.
  RealColumn get amount => real().nullable()();

  /// Amount unit, stored as [DoseUnit.name] (`ml`/`g`). Optional.
  TextColumn get amountUnit => text().nullable()();

  /// Whether [amount] is per day or per dose, stored as [DoseBasis.name].
  TextColumn get basis => text().nullable()();

  /// Schedule frequency, stored as [DoseFrequency.name]. Optional/descriptive.
  TextColumn get frequency => text().nullable()();

  /// Interval in days when [frequency] is `everyNDays`.
  IntColumn get intervalDays => integer().nullable()();

  /// Comma-separated weekday numbers (1=Mon … 7=Sun) when [frequency] is
  /// `weekly`.
  TextColumn get weekdays => text().nullable()();

  /// Time of day as `HH:mm`, optional.
  TextColumn get doseTime => text().nullable()();

  TextColumn get note => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When this dose segment became active. A dosing plan is a chain of dated
  /// segments: editing a dose-affecting field ends the current segment and
  /// starts a new one. Nullable only so the migration can backfill it from
  /// [createdAt] for pre-history rows; new inserts always set it.
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// When this segment stopped being active — set when it is superseded by an
  /// edit or the supplement is stopped. Null = current/active.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Lifecycle state, stored as [DosingState.name] (`active`/`ended`/`paused`).
  /// Only `active` rows show in the Dosing tab and feed the calculator.
  TextColumn get state =>
      text().withDefault(Constant(DosingState.active.name))();
}

/// Simple key/value store for app-wide settings (e.g. active tank).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Tanks,
  TrackedParameters,
  Readings,
  WaterChanges,
  CarbonChanges,
  EquipmentCleanings,
  RatioVisibilities,
  DosingEntries,
  Settings
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 13;

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
          if (from < 5) {
            if (!await _tableExists('equipment_cleanings')) {
              await m.createTable(equipmentCleanings);
            }
          }
          if (from < 6) {
            if (!await _tableExists('ratio_visibilities')) {
              await m.createTable(ratioVisibilities);
            }
          }
          if (from < 7) {
            if (!await _columnExists('ratio_visibilities', 'display_order')) {
              await m.addColumn(
                  ratioVisibilities, ratioVisibilities.displayOrder);
            }
          }
          if (from < 8) {
            for (final col in {
              'amber_low': ratioVisibilities.amberLow,
              'green_low': ratioVisibilities.greenLow,
              'green_high': ratioVisibilities.greenHigh,
              'amber_high': ratioVisibilities.amberHigh,
            }.entries) {
              if (!await _columnExists('ratio_visibilities', col.key)) {
                await m.addColumn(ratioVisibilities, col.value);
              }
            }
          }
          if (from < 9) {
            if (!await _tableExists('dosing_entries')) {
              await m.createTable(dosingEntries);
            }
          }
          if (from < 10) {
            for (final col in {
              'notes': tanks.notes,
              'vendor': tanks.vendor,
              'model': tanks.model,
            }.entries) {
              if (!await _columnExists('tanks', col.key)) {
                await m.addColumn(tanks, col.value);
              }
            }
          }
          if (from < 11) {
            for (final col in {
              'started_at': dosingEntries.startedAt,
              'ended_at': dosingEntries.endedAt,
              'state': dosingEntries.state,
            }.entries) {
              if (!await _columnExists('dosing_entries', col.key)) {
                await m.addColumn(dosingEntries, col.value);
              }
            }
            // Backfill: pre-history rows start when they were created.
            await customStatement(
              'UPDATE dosing_entries SET started_at = created_at '
              'WHERE started_at IS NULL',
            );
          }
          if (from < 12) {
            // Secondary indexes for the hot reactive read paths (tankId +
            // timestamp/paramKey). Declared as `@TableIndex` so fresh installs
            // get them via `createAll`; created here for existing databases.
            // `IF NOT EXISTS` keeps this idempotent, matching the guarded
            // migration convention above.
            for (final sql in const [
              'CREATE INDEX IF NOT EXISTS idx_readings_tank_param_taken '
                  'ON readings (tank_id, param_key, taken_at)',
              'CREATE INDEX IF NOT EXISTS idx_readings_tank_taken '
                  'ON readings (tank_id, taken_at)',
              'CREATE INDEX IF NOT EXISTS idx_water_changes_tank_changed '
                  'ON water_changes (tank_id, changed_at)',
              'CREATE INDEX IF NOT EXISTS idx_carbon_changes_tank_changed '
                  'ON carbon_changes (tank_id, changed_at)',
              'CREATE INDEX IF NOT EXISTS idx_equipment_cleanings_tank_cleaned '
                  'ON equipment_cleanings (tank_id, cleaned_at)',
              'CREATE INDEX IF NOT EXISTS idx_dosing_entries_tank '
                  'ON dosing_entries (tank_id)',
            ]) {
              await customStatement(sql);
            }
          }
          if (from < 13) {
            // Reading batches get a stable group id (#15); pre-existing rows
            // stay null and keep the legacy timestamp-based grouping.
            if (!await _columnExists('readings', 'group_id')) {
              await m.addColumn(readings, readings.groupId);
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
    // Use the parameterized `pragma_table_info()` table-valued function rather
    // than interpolating the table name into a `PRAGMA table_info('...')`
    // string, so the identifier is bound, not concatenated into SQL.
    final rows = await customSelect(
      'SELECT name FROM pragma_table_info(?)',
      variables: [Variable<String>(table)],
    ).get();
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
    String? notes,
    String? vendor,
    String? model,
  }) async {
    return transaction(() async {
      final tankId = await into(tanks).insert(TanksCompanion.insert(
        name: name,
        setupType: type.name,
        volumeLiters: Value(volumeLiters),
        startDate: Value(startDate),
        notes: Value(notes),
        vendor: Value(vendor),
        model: Value(model),
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
  /// The exists-check and insert run in one transaction (#10) so a double-fire
  /// (double-tap, launch/resume race) can't insert the parameter twice.
  Future<void> addTrackedParameter(
      int tankId, String paramKey, SetupType type) async {
    await transaction(() async {
      final existing = await (select(trackedParameters)
            ..where(
                (t) => t.tankId.equals(tankId) & t.paramKey.equals(paramKey)))
          .get();
      if (existing.isNotEmpty) return;
      final def = kParameterByKey[paramKey];
      final bounds = presetBounds(type, paramKey);
      // max(displayOrder) + 1, not the row count: after removing a middle
      // parameter the count could collide with an existing order (same fix as
      // insertDosingEntry).
      final order = (await getTrackedParameters(tankId))
              .fold<int>(
                  -1, (m, p) => p.displayOrder > m ? p.displayOrder : m) +
          1;
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
    });
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
    String? groupId,
  }) =>
      into(readings).insert(ReadingsCompanion.insert(
        tankId: tankId,
        paramKey: paramKey,
        value: value,
        takenAt: takenAt,
        note: Value(note),
        groupId: Value(groupId),
      ));

  /// Inserts a group of readings entered together in one atomic batch, so a
  /// failure partway through cannot leave a partial group behind. All rows share
  /// the same [tankId], [takenAt], [note] and a freshly generated [Readings.groupId]
  /// (#15), so later group edit/delete can't bleed into an unrelated batch that
  /// happens to share the same second.
  Future<void> insertReadingGroup({
    required int tankId,
    required DateTime takenAt,
    String? note,
    required List<({String paramKey, double value})> values,
  }) {
    final groupId = newReadingGroupId();
    return batch((b) => b.insertAll(
          readings,
          [
            for (final v in values)
              ReadingsCompanion.insert(
                tankId: tankId,
                paramKey: v.paramKey,
                value: v.value,
                takenAt: takenAt,
                note: Value(note),
                groupId: Value(groupId),
              ),
          ],
        ));
  }

  Future<void> updateReading(Reading reading) =>
      update(readings).replace(reading);

  Future<void> deleteReading(int id) =>
      (delete(readings)..where((r) => r.id.equals(id))).go();

  /// Predicate matching every reading saved together with [r] (#15): rows
  /// sharing its group id when it has one, otherwise (pre-v13 rows) the legacy
  /// same-timestamp rule — restricted to other ungrouped rows so a legacy group
  /// can't swallow a new batch that lands on the same second.
  Expression<bool> _sameGroupAs(Readings tbl, Reading r) {
    final gid = r.groupId;
    if (gid != null) return tbl.groupId.equals(gid);
    return tbl.tankId.equals(r.tankId) &
        tbl.takenAt.equals(r.takenAt) &
        tbl.groupId.isNull();
  }

  /// Readings saved together with [r] (entered in one go on the add-reading
  /// screen), including [r] itself.
  Future<List<Reading>> readingGroup(Reading r) =>
      (select(readings)..where((tbl) => _sameGroupAs(tbl, r))).get();

  /// Deletes every reading saved together with [r] (including [r]).
  /// Returns the number of rows removed.
  Future<int> deleteReadingGroup(Reading r) =>
      (delete(readings)..where((tbl) => _sameGroupAs(tbl, r))).go();

  /// Re-timestamps every reading saved together with [r] to [to] (i.e. moves a
  /// whole group entered in one go). Returns the rows changed.
  Future<int> updateReadingGroupTime(Reading r, DateTime to) =>
      (update(readings)..where((tbl) => _sameGroupAs(tbl, r)))
          .write(ReadingsCompanion(takenAt: Value(to)));

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

  // --- Equipment cleanings -------------------------------------------------

  /// Equipment cleanings for a tank, newest first.
  Stream<List<EquipmentCleaning>> watchEquipmentCleanings(int tankId) =>
      (select(equipmentCleanings)
            ..where((c) => c.tankId.equals(tankId))
            ..orderBy([
              (c) => OrderingTerm(
                  expression: c.cleanedAt, mode: OrderingMode.desc)
            ]))
          .watch();

  Future<void> insertEquipmentCleaning({
    required int tankId,
    required DateTime cleanedAt,
    String? note,
  }) =>
      into(equipmentCleanings).insert(EquipmentCleaningsCompanion.insert(
        tankId: tankId,
        cleanedAt: cleanedAt,
        note: Value(note),
      ));

  Future<void> updateEquipmentCleaning(EquipmentCleaning cleaning) =>
      update(equipmentCleanings).replace(cleaning);

  Future<void> deleteEquipmentCleaning(int id) =>
      (delete(equipmentCleanings)..where((c) => c.id.equals(id))).go();

  // --- Ratio cards ---------------------------------------------------------

  /// Stored per-tank ratio-card settings (visibility + dashboard order). Rows
  /// are absent for ratios left at their defaults (visible, ordered last).
  Stream<List<RatioVisibility>> watchRatioVisibilities(int tankId) =>
      (select(ratioVisibilities)..where((r) => r.tankId.equals(tankId)))
          .watch();

  Future<RatioVisibility?> _ratioRow(int tankId, String ratioKey) =>
      (select(ratioVisibilities)
            ..where((r) =>
                r.tankId.equals(tankId) & r.ratioKey.equals(ratioKey)))
          .getSingleOrNull();

  /// Sets whether a ratio card is shown for [tankId], leaving its order intact.
  ///
  /// A single upsert on the composite `(tankId, ratioKey)` primary key (#10):
  /// only the columns present in the companion are written on conflict, so a
  /// concurrent double-fire can neither duplicate the row nor throw a PK
  /// conflict, and existing order/bounds stay untouched.
  Future<void> setRatioVisible(int tankId, String ratioKey, bool visible) =>
      into(ratioVisibilities)
          .insertOnConflictUpdate(RatioVisibilitiesCompanion.insert(
        tankId: tankId,
        ratioKey: ratioKey,
        visible: Value(visible),
      ));

  /// Sets the per-tank zone bounds for a ratio card (creating the row if
  /// needed), leaving visibility and order intact. Same upsert shape as
  /// [setRatioVisible] (#10).
  Future<void> setRatioBounds(
    int tankId,
    String ratioKey, {
    required double? amberLow,
    required double? greenLow,
    required double? greenHigh,
    required double? amberHigh,
  }) =>
      into(ratioVisibilities)
          .insertOnConflictUpdate(RatioVisibilitiesCompanion.insert(
        tankId: tankId,
        ratioKey: ratioKey,
        amberLow: Value(amberLow),
        greenLow: Value(greenLow),
        greenHigh: Value(greenHigh),
        amberHigh: Value(amberHigh),
      ));

  /// Persists a new combined dashboard order across measurements and ratio
  /// cards (they share one order space). [paramOrders] gives tracked-parameter
  /// id → order; [ratioOrders] gives ratio key → order.
  Future<void> applyDashboardOrder(
    int tankId, {
    required List<({int id, int order})> paramOrders,
    required List<({String key, int order})> ratioOrders,
  }) async {
    await transaction(() async {
      await batch((b) {
        for (final p in paramOrders) {
          b.update(
            trackedParameters,
            TrackedParametersCompanion(displayOrder: Value(p.order)),
            where: (t) => t.id.equals(p.id),
          );
        }
      });
      for (final r in ratioOrders) {
        final existing = await _ratioRow(tankId, r.key);
        if (existing == null) {
          await into(ratioVisibilities).insert(
            RatioVisibilitiesCompanion.insert(
              tankId: tankId,
              ratioKey: r.key,
              displayOrder: Value(r.order),
            ),
          );
        } else {
          await (update(ratioVisibilities)
                ..where((t) =>
                    t.tankId.equals(tankId) & t.ratioKey.equals(r.key)))
              .write(
                  RatioVisibilitiesCompanion(displayOrder: Value(r.order)));
        }
      }
    });
  }

  // --- Dosing entries ------------------------------------------------------

  /// Active dosing-plan entries for a tank, in dashboard order then newest
  /// first. Ended (superseded/stopped) segments are retained as history but
  /// excluded here.
  Stream<List<DosingEntry>> watchDosingEntries(int tankId) =>
      (select(dosingEntries)
            ..where((d) =>
                d.tankId.equals(tankId) &
                d.state.equals(DosingState.active.name))
            ..orderBy([
              (d) => OrderingTerm(expression: d.displayOrder),
              (d) => OrderingTerm(
                  expression: d.createdAt, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Every dosing segment for a tank — active **and** ended (superseded/stopped)
  /// — newest first, for the history timeline. Ordered by when each segment
  /// began (`startedAt`, falling back to `createdAt` for any un-backfilled row).
  Stream<List<DosingEntry>> watchDosingHistory(int tankId) =>
      (select(dosingEntries)
            ..where((d) => d.tankId.equals(tankId))
            ..orderBy([
              (d) => OrderingTerm(
                  expression: coalesce([d.startedAt, d.createdAt]),
                  mode: OrderingMode.desc),
              (d) => OrderingTerm(
                  expression: d.createdAt, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<int> insertDosingEntry(DosingEntriesCompanion entry) async {
    // The max-order read and the insert run in one transaction (#10) so two
    // concurrent inserts can't be assigned the same displayOrder.
    return transaction(() async {
      final existing = await (select(dosingEntries)
            ..where((d) => d.tankId.equals(entry.tankId.value)))
          .get();
      // max(displayOrder) + 1, not the row count: after deleting a middle entry
      // the count could collide with an existing order and make rows jump (#21).
      final order = existing.fold<int>(
              -1, (m, d) => d.displayOrder > m ? d.displayOrder : m) +
          1;
      return into(dosingEntries).insert(
        entry.copyWith(
          displayOrder: Value(order),
          // A freshly added supplement starts a new active segment now.
          startedAt: entry.startedAt.present
              ? entry.startedAt
              : Value(DateTime.now()),
          state: entry.state.present
              ? entry.state
              : Value(DosingState.active.name),
        ),
      );
    });
  }

  /// In-place update for **cosmetic** changes only (display name, note, time) —
  /// anything that doesn't alter the dosed amount. Dose-affecting edits must go
  /// through [supersedeDosingEntry] so the old dose is retained as history.
  Future<void> updateDosingEntry(DosingEntry entry) =>
      update(dosingEntries).replace(entry);

  /// Records a dose change: ends the current [old] segment and starts a new
  /// active one carrying [next], keeping the same [DosingEntry.displayOrder] so
  /// the entry stays in place. Runs in one transaction.
  Future<void> supersedeDosingEntry(
    DosingEntry old,
    DosingEntriesCompanion next,
  ) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(dosingEntries)..where((d) => d.id.equals(old.id))).write(
        DosingEntriesCompanion(
          state: Value(DosingState.ended.name),
          endedAt: Value(now),
        ),
      );
      await into(dosingEntries).insert(
        next.copyWith(
          tankId: Value(old.tankId),
          displayOrder: Value(old.displayOrder),
          startedAt: Value(now),
          state: Value(DosingState.active.name),
        ),
      );
    });
  }

  /// Soft-ends a dosing entry (the "stop" action): keeps the row as history but
  /// removes it from the active plan.
  Future<void> stopDosingEntry(int id) =>
      (update(dosingEntries)..where((d) => d.id.equals(id))).write(
        DosingEntriesCompanion(
          state: Value(DosingState.ended.name),
          endedAt: Value(DateTime.now()),
        ),
      );

  /// Permanently removes a dosing segment — the history screen's "delete a record
  /// entered by mistake". Unlike [stopDosingEntry] this is irreversible and leaves
  /// no history; use it only for erroneous records, not to stop dosing.
  Future<void> deleteDosingEntry(int id) =>
      (delete(dosingEntries)..where((d) => d.id.equals(id))).go();

  /// Persists a new manual ordering of a tank's dosing entries, given their ids
  /// in the desired top-to-bottom order.
  Future<void> reorderDosingEntries(List<int> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          dosingEntries,
          DosingEntriesCompanion(displayOrder: Value(i)),
          where: (d) => d.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // --- Settings ------------------------------------------------------------

  Future<void> setActiveTank(int? tankId) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
        key: kActiveTankKey,
        value: Value(tankId?.toString()),
      ));

  Future<int?> getActiveTankId() async {
    final row = await (select(settings)
          ..where((s) => s.key.equals(kActiveTankKey)))
        .getSingleOrNull();
    final v = row?.value;
    return v == null ? null : int.tryParse(v);
  }

  Stream<int?> watchActiveTankId() => (select(settings)
        ..where((s) => s.key.equals(kActiveTankKey)))
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

  /// One-shot read of a settings value (null if the key is unset).
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

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

  /// Every equipment cleaning, across all tanks.
  Future<List<EquipmentCleaning>> getAllEquipmentCleanings() =>
      select(equipmentCleanings).get();

  /// Every ratio-visibility override, across all tanks.
  Future<List<RatioVisibility>> getAllRatioVisibilities() =>
      select(ratioVisibilities).get();

  /// Every dosing-plan entry, across all tanks.
  Future<List<DosingEntry>> getAllDosingEntries() =>
      select(dosingEntries).get();

  /// Every settings key/value pair.
  Future<List<Setting>> getAllSettings() => select(settings).get();

  /// Replaces the entire database contents with the supplied rows, preserving
  /// the original primary keys (so foreign-key links stay intact). Runs in a
  /// single transaction: on any error nothing is changed.
  ///
  /// [preserveSettingKeys] are settings that describe *this* device/user rather
  /// than the aquarium data (units, language, the active-tank selection, …).
  /// Their current values are left untouched and any matching rows in
  /// [settingRows] are dropped, so restoring a backup from another device never
  /// silently overwrites the local preferences (#18). Callers pass
  /// `SettingKey.deviceLocalKeys`.
  Future<void> restoreFromBackup({
    required List<TanksCompanion> tankRows,
    required List<TrackedParametersCompanion> paramRows,
    required List<ReadingsCompanion> readingRows,
    required List<WaterChangesCompanion> waterChangeRows,
    required List<CarbonChangesCompanion> carbonChangeRows,
    required List<EquipmentCleaningsCompanion> equipmentCleaningRows,
    required List<RatioVisibilitiesCompanion> ratioVisibilityRows,
    required List<DosingEntriesCompanion> dosingEntryRows,
    required List<SettingsCompanion> settingRows,
    Set<String> preserveSettingKeys = const {},
  }) async {
    final incomingSettings = settingRows
        .where((r) => !preserveSettingKeys.contains(r.key.value))
        .toList();
    await transaction(() async {
      // Delete children before parents to satisfy foreign keys.
      await delete(readings).go();
      await delete(waterChanges).go();
      await delete(carbonChanges).go();
      await delete(equipmentCleanings).go();
      await delete(ratioVisibilities).go();
      await delete(dosingEntries).go();
      await delete(trackedParameters).go();
      // Preserve device-local preferences: wipe only the settings the restore
      // is allowed to replace.
      if (preserveSettingKeys.isEmpty) {
        await delete(settings).go();
      } else {
        await (delete(settings)
              ..where((s) => s.key.isNotIn(preserveSettingKeys.toList())))
            .go();
      }
      await delete(tanks).go();
      // Insert parents before children, preserving ids.
      await batch((b) {
        b.insertAll(tanks, tankRows);
        b.insertAll(trackedParameters, paramRows);
        b.insertAll(readings, readingRows);
        b.insertAll(waterChanges, waterChangeRows);
        b.insertAll(carbonChanges, carbonChangeRows);
        b.insertAll(equipmentCleanings, equipmentCleaningRows);
        b.insertAll(ratioVisibilities, ratioVisibilityRows);
        b.insertAll(dosingEntries, dosingEntryRows);
        b.insertAll(settings, incomingSettings);
      });
    });
  }
}

final Random _groupIdRandom = Random();

/// A practically-unique id for a batch of readings entered together (#15):
/// microsecond timestamp + random suffix, no external uuid dependency needed
/// for the collision odds that matter here (ids only need to differ between
/// batches of one tank).
String newReadingGroupId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '-${_groupIdRandom.nextInt(1 << 30).toRadixString(36)}';

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

// --- Domain mappers ----------------------------------------------------------
// The pure math in `lib/domain/` takes plain records instead of drift rows
// (#52); these bridge from the rows at the data boundary.

extension ReadingDomain on Reading {
  /// This reading as the record the ratio math consumes.
  RatioReading get ratioReading => (takenAt: takenAt, value: value);
}

extension ReadingListDomain on Iterable<Reading> {
  /// These readings as the records the ratio math consumes, order preserved.
  List<RatioReading> get ratioReadings =>
      [for (final r in this) r.ratioReading];
}

extension DosingEntryDomain on DosingEntry {
  /// The schedule fields [dailyEquivalentDose] reads.
  DoseSchedule get schedule => (
        amount: amount,
        frequency: frequency,
        intervalDays: intervalDays,
        weekdays: weekdays,
      );
}

extension RatioVisibilityDomain on RatioVisibility {
  /// This row as the settings record the ratio helpers consume.
  RatioSettings get settings => (
        visible: visible,
        displayOrder: displayOrder,
        bounds: ZoneBounds(
          amberLow: amberLow,
          greenLow: greenLow,
          greenHigh: greenHigh,
          amberHigh: amberHigh,
        ),
      );
}
