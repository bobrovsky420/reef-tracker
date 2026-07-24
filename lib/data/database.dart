import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/dose_calculator.dart';
import '../domain/micro.dart';
import '../domain/parameter_catalog.dart';
import '../domain/presets.dart';
import '../domain/ratio.dart';
import '../domain/reminders.dart';
import '../domain/ro.dart';
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

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete stamp (U10). Set by [AppDatabase.softDeleteTank] — the tank
  /// vanishes from every read path but its rows survive the undo window —
  /// and cleared by [AppDatabase.restoreTank]. Non-null rows are finalized by
  /// [AppDatabase.hardDeleteTank] / [AppDatabase.purgeDeletedTanks].
  DateTimeColumn get deletedAt => dateTime().nullable()();
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

  /// "Remind to test every N days" (U1); null = no reminder for this
  /// parameter. The reminder anchors elastically on the parameter's latest
  /// reading (see `domain/reminders.dart`).
  IntColumn get testCadenceDays => integer().nullable()();

  /// Correction target for the dose calculator's correction mode, in the
  /// parameter's canonical unit. Seeded from the setup-type preset
  /// (`kPresetTargets`) where one exists; null falls back to the green-zone
  /// midpoint at use time.
  RealColumn get targetValue => real().nullable()();
}

/// A single logged measurement.
@TableIndex(
  name: 'idx_readings_tank_param_taken',
  columns: {#tankId, #paramKey, #takenAt},
)
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
  /// re-timed onto) the same second. Since schema v19 every stored row has one
  /// (pre-v13 rows get a deterministic `legacy-` id backfilled from their old
  /// tank+timestamp grouping, both on upgrade and on backup restore); a null
  /// is treated as a standalone reading.
  TextColumn get groupId => text().nullable()();
}

/// A logged water change for a tank (date/time + optional volume + note).
@TableIndex(
  name: 'idx_water_changes_tank_changed',
  columns: {#tankId, #changedAt},
)
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
  name: 'idx_carbon_changes_tank_changed',
  columns: {#tankId, #changedAt},
)
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
  columns: {#tankId, #cleanedAt},
)
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

  /// Whether this entry fires dosing reminders (U2). Opt-in (default off);
  /// only effective while the entry is active, has a parsable [doseTime], and
  /// the Settings master switch for dosing reminders is on.
  BoolColumn get remindEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

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

/// A logged one-off manual dose: a supplement, vitamin or medicine given by
/// hand outside the regular plan — supplement identity + date/time + amount.
/// Feeds the dosing-history timeline and the dose calculator's "manual dose
/// in window" default. An event log like [WaterChanges], not a segment.
@TableIndex(name: 'idx_manual_doses_tank_dosed', columns: {#tankId, #dosedAt})
class ManualDoses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();

  /// When the dose was given.
  DateTimeColumn get dosedAt => dateTime()();

  /// Stable `SupplementProduct.key` from the catalog, or null for a custom
  /// (free-text) entry — same convention as [DosingEntries].
  TextColumn get productKey => text().nullable()();

  /// Denormalized display names (the catalog values at entry time, or the
  /// user's free text for a custom entry).
  TextColumn get vendor => text().nullable()();
  TextColumn get program => text().nullable()();
  TextColumn get product => text()();

  /// Target element as a real `Readings.paramKey`, or null for products with
  /// no single element (vitamins, medicines, trace mixes).
  TextColumn get elementKey => text().nullable()();

  /// Amount given, in [amountUnit]. Required — unlike the plan's optional
  /// dosage, the given volume is the point of the record.
  RealColumn get amount => real()();

  /// Amount unit, stored as [DoseUnit.name] (`ml`/`g`).
  TextColumn get amountUnit => text()();

  TextColumn get note => text().nullable()();
}

/// A named subset of a tank's parameters used to filter the Add Reading form
/// (U9, a "test set" like "weekly big test" or "daily Alk").
///
/// [paramKeys] holds stable *catalog* parameter keys as a JSON array (see
/// [encodeTemplateParamKeys]) rather than [TrackedParameters] row ids, so a set
/// survives a parameter being disabled — or untracked and re-added later.
/// Keys that aren't currently tracked+enabled are skipped at display time,
/// never removed from the set.
@TableIndex(name: 'idx_reading_templates_tank', columns: {#tankId})
@DataClassName('ReadingTemplate')
class ReadingTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// JSON array of catalog `paramKey` strings, e.g. `["alkalinity","calcium"]`.
  TextColumn get paramKeys => text()();

  /// Position of the set's chip on the Add Reading screen.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}

/// A user-created microelement view (U17): a named subset of the ICP panel
/// the Microelements screen can be filtered to — "the elements my lab
/// reports". Built-in lab presets (Full list, Fauna Marin ICP) are code-side
/// (`domain/micro.dart`), not rows; this table holds only the user's own
/// views. Like [ReadingTemplates], [paramKeys] holds stable catalog keys as a
/// JSON array, so a view survives catalog growth and bounds/row churn; keys
/// unknown to the running catalog are skipped at display, never dropped.
@TableIndex(name: 'idx_micro_views_tank', columns: {#tankId})
@DataClassName('MicroView')
class MicroViews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// JSON array of catalog `paramKey` strings, e.g. `["iodine","iron"]`.
  TextColumn get paramKeys => text()();

  /// Position of the view's chip on the Microelements screen.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}

/// A user-maintained maintenance plan (U12): a recurring or one-off task for
/// one of the logged action types — or a custom-titled task ("replace RO
/// membrane"). Typed rows derive "last done" from their action log, so logging
/// the action anywhere in the app advances the plan; custom rows carry their
/// own [lastDoneAt], stamped by "Mark done". Due math lives in
/// `domain/reminders.dart` ([nextMaintenanceDue]): interval repeats
/// ([cadenceDays] in days/weeks/months) are elastic (next due = completion +
/// cadence) while [weekdays]/[monthDay] repeats are calendar anchored (next
/// matching date after completion); [scheduledAt] only seeds the first
/// occurrence.
@TableIndex(name: 'idx_maintenance_schedules_tank', columns: {#tankId})
@DataClassName('MaintenanceSchedule')
class MaintenanceSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();

  /// [MaintenanceActionType.name] (`waterChange`/`carbonChange`/
  /// `equipmentCleaning`), or null = custom task ([title] required then).
  TextColumn get actionType => text().nullable()();

  /// Display name for a custom task; null for typed rows, which render the
  /// localized action name instead.
  TextColumn get title => text().nullable()();

  /// Repeat every N units ([cadenceUnit]) after the last completion; null =
  /// one-off (due at [scheduledAt], retired once done) unless a calendar
  /// repeat ([weekdays]/[monthDay]) is set instead.
  IntColumn get cadenceDays => integer().nullable()();

  /// Unit of [cadenceDays] (`MaintenanceCadenceUnit.name`: days/weeks/
  /// months); null = days (pre-v17 rows).
  TextColumn get cadenceUnit => text().nullable()();

  /// Comma-separated weekday numbers (1=Mon … 7=Sun) for a fixed-weekday
  /// repeat ("every Monday") — same format as `DosingEntries.weekdays`.
  /// Takes precedence over [cadenceDays]/[monthDay] when non-empty.
  TextColumn get weekdays => text().nullable()();

  /// Day of month (1–31, clamped to short months) for a fixed-date repeat
  /// ("every 1st of the month"). Takes precedence over [cadenceDays].
  IntColumn get monthDay => integer().nullable()();

  /// Planned first (or one-off) due date. Floors the computed due date while
  /// it lies after the last completion (typed rows anchor on their action
  /// log, which predates the plan); irrelevant once a completion moves past
  /// it.
  DateTimeColumn get scheduledAt => dateTime().nullable()();

  /// Completion stamp for **custom** rows only (typed rows read their action
  /// log). For a one-off custom task, non-null means finished.
  DateTimeColumn get lastDoneAt => dateTime().nullable()();

  /// Per-plan reminder opt-out; the Settings maintenance master switch still
  /// gates all of them.
  BoolColumn get remindEnabled => boolean().withDefault(const Constant(true))();

  TextColumn get note => text().nullable()();

  /// Position in the schedule list / due-chip row.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}

/// One stage (filter/part) of the reverse-osmosis unit (U16). Deliberately
/// **no tankId** — like [Settings], the RO unit is a property of the
/// household and is shared by every aquarium.
///
/// The default 4-stage set is seeded the first time the RO screen is opened
/// ([AppDatabase.seedDefaultRoStages]); a user whose unit lacks a stage (e.g.
/// no DI resin) unchecks it: [enabled] = false hides it from the overview and
/// silences its reminders, but the row and its replacement history survive.
@DataClassName('RoStage')
class RoStages extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// [RoStageType.name]; `custom` rows carry their display name in [title],
  /// typed rows render a localized name.
  TextColumn get stageType => text()();

  /// Display name for a custom stage; null for typed rows.
  TextColumn get title => text().nullable()();

  /// Replace every N days (edited as days/weeks/months in the UI). Due math
  /// is elastic on the latest logged replacement (`domain/ro.dart`).
  IntColumn get lifespanDays => integer()();

  /// Whether this stage exists on the user's unit (the "uncheck if a lower
  /// model is used" flag).
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// Per-stage reminder opt-out; the maintenance master switch still gates
  /// all RO reminders.
  BoolColumn get remindEnabled => boolean().withDefault(const Constant(true))();

  TextColumn get note => text().nullable()();

  /// Position in the overview list (the water path through the unit).
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}

/// A logged replacement of one RO stage — the elastic anchor for that stage's
/// next due date. A log (not a single `lastReplacedAt` column) so "mark
/// replaced" gets the standard undo treatment and the history stays visible.
@TableIndex(name: 'idx_ro_replacements_stage', columns: {#stageId})
@DataClassName('RoStageReplacement')
class RoStageReplacements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get stageId =>
      integer().references(RoStages, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get replacedAt => dateTime()();
  TextColumn get note => text().nullable()();
}

/// Per-(tank, source) state of the measurement import (U32): the remembered
/// external location → tank mapping and the dedupe watermark. Rides backups —
/// a restored database must keep the watermark consistent with the restored
/// readings, or the next import would duplicate them (unlike the U24
/// sync-state settings, which are identity and stay device-local).
@DataClassName('ImportSource')
class ImportSources extends Table {
  IntColumn get tankId =>
      integer().references(Tanks, #id, onDelete: KeyAction.cascade)();

  /// Import format id (e.g. `kHannaImportSource`). Persisted — never rename.
  TextColumn get source => text()();

  /// The external location/tank label the file carries (Hanna's
  /// `Sample Location`), remembered so the next import preselects this tank
  /// and a different pick gets a wrong-file confirmation.
  TextColumn get location => text().nullable()();

  /// Dedupe watermark: the newest imported reading timestamp; an import takes
  /// strictly newer rows. Null = ask the first-import cutoff question again
  /// (fresh mapping, or after a settings Reset).
  DateTimeColumn get importedUpTo => dateTime().nullable()();

  /// One-shot flag set by the settings rewind/reset actions: the next import
  /// must not trust the watermark alone (it would duplicate the re-covered
  /// range) — it diffs candidates against existing readings first, then
  /// clears this.
  BoolColumn get rewound => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {tankId, source};
}

/// Inventory of connected hardware devices (U36): ReefFactory local meters and
/// the Hanna checker once it has been used. Keyed by [identifier] (the device
/// serial / BLE id) so a meter that changes DHCP address stays the same row.
/// The ReefFactory dashboard manages `kind = 'reeffactory'` rows (add / refresh
/// / remove); the Hanna flow records its checker on first connect. The Settings
/// "Connected devices" page is a read-only union of both kinds.
@DataClassName('DeviceRecord')
class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `'reeffactory'` | `'hanna'`. Persisted — never rename.
  TextColumn get kind => text()();

  /// Stable device identity: a ReefFactory serial (e.g. `RFPM01…`) or the Hanna
  /// meter's BLE id/serial. Unique — the same physical device is one row even
  /// if its network address changes.
  TextColumn get identifier => text().unique()();

  /// User-facing label; defaults to the model/parameter name at add time.
  TextColumn get name => text().nullable()();

  /// Model code (`RFSG01`, `RFPM01`, a Hanna model), for display.
  TextColumn get model => text().nullable()();

  /// Current network address (host or IP) for ReefFactory meters. Null for
  /// Hanna (BLE, no address).
  TextColumn get address => text().nullable()();

  /// Tank the device's saved readings belong to. Null until assigned; cleared
  /// (not cascaded) if the tank is deleted so the device row survives.
  IntColumn get tankId =>
      integer().nullable().references(Tanks, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get firstSeenAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
}

/// Simple key/value store for app-wide settings (e.g. active tank).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Tanks,
    TrackedParameters,
    Readings,
    WaterChanges,
    CarbonChanges,
    EquipmentCleanings,
    RatioVisibilities,
    DosingEntries,
    ManualDoses,
    ReadingTemplates,
    MicroViews,
    MaintenanceSchedules,
    RoStages,
    RoStageReplacements,
    ImportSources,
    Devices,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 24;

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
          await m.addColumn(ratioVisibilities, ratioVisibilities.displayOrder);
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
      if (from < 14) {
        // Test sets for the Add Reading screen (U9).
        if (!await _tableExists('reading_templates')) {
          await m.createTable(readingTemplates);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_reading_templates_tank '
          'ON reading_templates (tank_id)',
        );
      }
      if (from < 15) {
        // Grace-period soft delete for tanks (U10).
        if (!await _columnExists('tanks', 'deleted_at')) {
          await m.addColumn(tanks, tanks.deletedAt);
        }
      }
      if (from < 16) {
        // Reminders & schedules (U1/U2/U12).
        if (!await _columnExists('tracked_parameters', 'test_cadence_days')) {
          await m.addColumn(
            trackedParameters,
            trackedParameters.testCadenceDays,
          );
        }
        if (!await _columnExists('dosing_entries', 'remind_enabled')) {
          await m.addColumn(dosingEntries, dosingEntries.remindEnabled);
        }
        if (!await _tableExists('maintenance_schedules')) {
          await m.createTable(maintenanceSchedules);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_tank '
          'ON maintenance_schedules (tank_id)',
        );
      }
      if (from < 17) {
        // Maintenance repeat modes beyond every-N-days: interval unit
        // (weeks/months), fixed weekdays, fixed day of month.
        if (!await _columnExists('maintenance_schedules', 'cadence_unit')) {
          await m.addColumn(
            maintenanceSchedules,
            maintenanceSchedules.cadenceUnit,
          );
        }
        if (!await _columnExists('maintenance_schedules', 'weekdays')) {
          await m.addColumn(
            maintenanceSchedules,
            maintenanceSchedules.weekdays,
          );
        }
        if (!await _columnExists('maintenance_schedules', 'month_day')) {
          await m.addColumn(
            maintenanceSchedules,
            maintenanceSchedules.monthDay,
          );
        }
      }
      if (from < 18) {
        // Shared reverse-osmosis unit (U16): stages + replacement log.
        if (!await _tableExists('ro_stages')) {
          await m.createTable(roStages);
        }
        if (!await _tableExists('ro_stage_replacements')) {
          await m.createTable(roStageReplacements);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ro_replacements_stage '
          'ON ro_stage_replacements (stage_id)',
        );
      }
      if (from < 19) {
        // Pre-v13 rows relied on a runtime same-timestamp fallback for batch
        // grouping (#15). Freeze that rule into data: every ungrouped row
        // gets a deterministic group id derived from its legacy
        // (tank, taken_at) cluster, so all grouping now keys on group_id
        // alone. Naturally idempotent — only NULL rows are touched.
        await _backfillLegacyReadingGroupIds();
      }
      if (from < 20) {
        // Custom microelement views (U17).
        if (!await _tableExists('micro_views')) {
          await m.createTable(microViews);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_micro_views_tank '
          'ON micro_views (tank_id)',
        );
      }
      if (from < 21) {
        // Manual dose log (history timeline + calculator prefill).
        if (!await _tableExists('manual_doses')) {
          await m.createTable(manualDoses);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_manual_doses_tank_dosed '
          'ON manual_doses (tank_id, dosed_at)',
        );
      }
      if (from < 22) {
        // Correction target (dose calculator correction mode). Existing rows
        // get the setup-type default where the preset defines one; everything
        // else stays null and falls back to the green-zone midpoint at use
        // time. The IS NULL guard keeps the backfill idempotent.
        if (!await _columnExists('tracked_parameters', 'target_value')) {
          await m.addColumn(trackedParameters, trackedParameters.targetValue);
        }
        for (final MapEntry(key: type, value: targets)
            in kPresetTargets.entries) {
          for (final MapEntry(key: param, value: target) in targets.entries) {
            await customUpdate(
              'UPDATE tracked_parameters SET target_value = ? '
              'WHERE target_value IS NULL AND param_key = ? AND tank_id IN '
              '(SELECT id FROM tanks WHERE setup_type = ?)',
              variables: [
                Variable<double>(target),
                Variable<String>(param),
                Variable<String>(type.name),
              ],
              updates: {trackedParameters},
            );
          }
        }
      }
      if (from < 23) {
        // Measurement import watermark + location mapping (U32).
        if (!await _tableExists('import_sources')) {
          await m.createTable(importSources);
        }
      }
      if (from < 24) {
        // Connected-device inventory: ReefFactory meters + Hanna checker (U36).
        if (!await _tableExists('devices')) {
          await m.createTable(devices);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Gives every ungrouped reading a group id derived from its legacy
  /// (tank, timestamp) grouping cluster, so rows saved together before schema
  /// v13 — or restored from a pre-v13 backup — keep behaving as one batch now
  /// that grouping keys on [Readings.groupId] alone. The `legacy-` prefix
  /// cannot collide with [newReadingGroupId]'s ids (#15).
  Future<void> _backfillLegacyReadingGroupIds() => customStatement(
    "UPDATE readings SET group_id = 'legacy-' || tank_id || '-' || taken_at "
    'WHERE group_id IS NULL',
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
      (select(tanks)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  Future<List<Tank>> getTanks() =>
      (select(tanks)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
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
      final tankId = await into(tanks).insert(
        TanksCompanion.insert(
          name: name,
          setupType: type.name,
          volumeLiters: Value(volumeLiters),
          startDate: Value(startDate),
          notes: Value(notes),
          vendor: Value(vendor),
          model: Value(model),
        ),
      );
      await _seedTrackedParameters(tankId, type);
      await setActiveTank(tankId);
      return tankId;
    });
  }

  Future<void> updateTank(Tank tank) => update(tanks).replace(tank);

  /// Soft-deletes a tank (U10): stamps [Tanks.deletedAt], which hides it from
  /// every read path, and hands the active-tank slot to another visible tank.
  /// Reversible via [restoreTank] until [hardDeleteTank] (undo window closed)
  /// or [purgeDeletedTanks] (startup sweep) finalizes it.
  Future<void> softDeleteTank(int id) async {
    await transaction(() async {
      await (update(tanks)..where((t) => t.id.equals(id))).write(
        TanksCompanion(deletedAt: Value(DateTime.now())),
      );
      final remaining = await getTanks();
      final active = await getActiveTankId();
      if (active == id) {
        await setActiveTank(remaining.isEmpty ? null : remaining.first.id);
      }
    });
  }

  /// Clears a soft-deleted tank's [Tanks.deletedAt] — the Undo action.
  /// Returns false when the row no longer exists (purged, or wiped by a
  /// backup restore meanwhile) so callers don't re-activate a ghost id.
  Future<bool> restoreTank(int id) async {
    final n = await (update(tanks)..where((t) => t.id.equals(id))).write(
      const TanksCompanion(deletedAt: Value(null)),
    );
    return n > 0;
  }

  /// Finalizes a soft delete: irreversibly removes the tank (children
  /// cascade). Guarded to soft-deleted rows only, so a stale undo-window
  /// callback can never remove a live tank that reused the id (e.g. one
  /// re-inserted by a backup restore during the window).
  Future<void> hardDeleteTank(int id) => (delete(
    tanks,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).go();

  /// Removes every soft-deleted tank — the startup sweep collecting rows
  /// orphaned by a process kill during the undo window.
  Future<void> purgeDeletedTanks() =>
      (delete(tanks)..where((t) => t.deletedAt.isNotNull())).go();

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
            targetValue: Value(presetTarget(type, key)),
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
    int tankId,
    String paramKey,
    SetupType type,
  ) async {
    await transaction(() async {
      final existing =
          await (select(trackedParameters)..where(
                (t) => t.tankId.equals(tankId) & t.paramKey.equals(paramKey),
              ))
              .get();
      if (existing.isNotEmpty) return;
      final def = kParameterByKey[paramKey];
      // Setup-type presets cover core parameters; microelements (U17) seed
      // from their catalog defaults instead (empty for anything else).
      final preset = presetBounds(type, paramKey);
      final bounds = preset.isEmpty ? microDefaultBounds(paramKey) : preset;
      // max(displayOrder) + 1, not the row count: after removing a middle
      // parameter the count could collide with an existing order (same fix as
      // insertDosingEntry).
      final order =
          (await getTrackedParameters(
            tankId,
          )).fold<int>(-1, (m, p) => p.displayOrder > m ? p.displayOrder : m) +
          1;
      await into(trackedParameters).insert(
        TrackedParametersCompanion.insert(
          tankId: tankId,
          paramKey: paramKey,
          unit: def?.unit ?? '',
          displayOrder: Value(order),
          amberLow: Value(bounds.amberLow),
          greenLow: Value(bounds.greenLow),
          greenHigh: Value(bounds.greenHigh),
          amberHigh: Value(bounds.amberHigh),
          targetValue: Value(presetTarget(type, paramKey)),
        ),
      );
    });
  }

  Future<void> updateTrackedParameter(TrackedParameter param) =>
      update(trackedParameters).replace(param);

  Future<void> removeTrackedParameter(int id) =>
      (delete(trackedParameters)..where((t) => t.id.equals(id))).go();

  /// Sets (or clears, with null) a parameter's "remind to test every N days"
  /// cadence (U1).
  Future<void> setTestCadence(int id, int? days) =>
      (update(trackedParameters)..where((t) => t.id.equals(id))).write(
        TrackedParametersCompanion(testCadenceDays: Value(days)),
      );

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

  /// Re-applies the default zone bounds to every tracked parameter of a tank:
  /// the setup-type preset for parameters it knows about, the microelement
  /// catalog defaults otherwise (the same source rule as [addTrackedParameter]).
  /// Rows with no default from either source (core parameters outside the
  /// preset) keep their current bounds. Does not add/remove parameters.
  Future<void> applyPreset(int tankId, SetupType type) async {
    final params = await getTrackedParameters(tankId);
    await batch((b) {
      for (final param in params) {
        final preset = presetBounds(type, param.paramKey);
        final bounds = preset.isEmpty
            ? microDefaultBounds(param.paramKey)
            : preset;
        if (bounds.isEmpty) continue;
        b.update(
          trackedParameters,
          TrackedParametersCompanion(
            amberLow: Value(bounds.amberLow),
            greenLow: Value(bounds.greenLow),
            greenHigh: Value(bounds.greenHigh),
            amberHigh: Value(bounds.amberHigh),
            // Re-applying the preset resets the correction target to the
            // setup-type default too (null where none) — same semantics as
            // the bounds it sits alongside.
            targetValue: Value(presetTarget(type, param.paramKey)),
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
              (r) =>
                  OrderingTerm(expression: r.takenAt, mode: OrderingMode.desc),
            ]))
          .watch();

  /// One-shot fetch of every reading for a tank, oldest first (`id` as the
  /// same-second tiebreak) — feeds the measurement CSV export (U3). Live UI
  /// reads go through the bounded watchers instead.
  Future<List<Reading>> getReadingsForTank(int tankId) =>
      (select(readings)
            ..where((r) => r.tankId.equals(tankId))
            ..orderBy([
              (r) => OrderingTerm(expression: r.takenAt),
              (r) => OrderingTerm(expression: r.id),
            ]))
          .get();

  /// Readings for a single parameter, oldest first (chart-friendly order).
  Stream<List<Reading>> watchParamReadings(int tankId, String paramKey) =>
      (select(readings)
            ..where(
              (r) => r.tankId.equals(tankId) & r.paramKey.equals(paramKey),
            )
            ..orderBy([(r) => OrderingTerm(expression: r.takenAt)]))
          .watch();

  /// The newest [limit] readings *per parameter* for a tank, newest first (T1).
  ///
  /// This is the bounded feed for everything on the dashboard path that only
  /// needs the head of each parameter's history (latest value + change, health
  /// score, trend window) — unlike [watchReadingsForTank], its per-write
  /// re-query cost stays O(parameters × limit) no matter how many years of
  /// readings accumulate. Drift's fluent API has no window functions, hence
  /// custom SQL; the partition rides `idx_readings_tank_param_taken`. The `id`
  /// tiebreaker makes same-second readings deterministic.
  Selectable<Reading> _recentReadingsPerParam(int tankId, int limit) =>
      customSelect(
        'SELECT * FROM ('
        'SELECT r.*, ROW_NUMBER() OVER '
        '(PARTITION BY param_key ORDER BY taken_at DESC, id DESC) AS rn '
        'FROM readings r WHERE tank_id = ?'
        ') WHERE rn <= ? '
        'ORDER BY taken_at DESC, id DESC',
        variables: [Variable.withInt(tankId), Variable.withInt(limit)],
        readsFrom: {readings},
      ).asyncMap(readings.mapFromRow);

  Stream<List<Reading>> watchRecentReadingsPerParam(int tankId, int limit) =>
      _recentReadingsPerParam(tankId, limit).watch();

  /// One-shot variant of [watchRecentReadingsPerParam] (U27 collector; also
  /// the widget-test-safe form — drift stream emissions ride zero-duration
  /// timers that FakeAsync only fires during pumps, so `.first` deadlocks).
  Future<List<Reading>> getRecentReadingsPerParam(int tankId, int limit) =>
      _recentReadingsPerParam(tankId, limit).get();

  /// All of a tank's readings taken on/after [cutoff], newest first (U26).
  ///
  /// The *time*-bounded companion of [watchRecentReadingsPerParam]'s count cap:
  /// the stability score's 60/90-day windows would silently truncate for a
  /// frequent tester under a per-parameter row limit, while a time window stays
  /// exact and its per-write re-query cost is bounded by the testing cadence.
  /// Rides `idx_readings_tank_taken`; the `id` tiebreaker keeps same-second
  /// readings deterministic.
  SimpleSelectStatement<$ReadingsTable, Reading> _readingsSince(
    int tankId,
    DateTime cutoff,
  ) => select(readings)
    ..where(
      (r) => r.tankId.equals(tankId) & r.takenAt.isBiggerOrEqualValue(cutoff),
    )
    ..orderBy([
      (r) => OrderingTerm(expression: r.takenAt, mode: OrderingMode.desc),
      (r) => OrderingTerm(expression: r.id, mode: OrderingMode.desc),
    ]);

  Stream<List<Reading>> watchReadingsSince(int tankId, DateTime cutoff) =>
      _readingsSince(tankId, cutoff).watch();

  /// One-shot variant of [watchReadingsSince] (U27 collector).
  Future<List<Reading>> getReadingsSince(int tankId, DateTime cutoff) =>
      _readingsSince(tankId, cutoff).get();

  Future<void> insertReading({
    required int tankId,
    required String paramKey,
    required double value,
    required DateTime takenAt,
    String? note,
    String? groupId,
  }) => into(readings).insert(
    ReadingsCompanion.insert(
      tankId: tankId,
      paramKey: paramKey,
      value: value,
      takenAt: takenAt,
      note: Value(note),
      groupId: Value(groupId),
    ),
  );

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
    return batch(
      (b) => b.insertAll(readings, [
        for (final v in values)
          ReadingsCompanion.insert(
            tankId: tankId,
            paramKey: v.paramKey,
            value: v.value,
            takenAt: takenAt,
            note: Value(note),
            groupId: Value(groupId),
          ),
      ]),
    );
  }

  Future<void> updateReading(Reading reading) =>
      update(readings).replace(reading);

  Future<void> deleteReading(int id) =>
      (delete(readings)..where((r) => r.id.equals(id))).go();

  /// Predicate matching every reading saved together with [r] (#15): rows
  /// sharing its group id. The v19 migration (and every restore) backfills a
  /// group id onto legacy ungrouped rows, so a null here can only come from a
  /// row created outside the app flows — treated as standalone, matching
  /// nothing but [r] itself.
  Expression<bool> _sameGroupAs(Readings tbl, Reading r) {
    final gid = r.groupId;
    if (gid != null) return tbl.groupId.equals(gid);
    return tbl.id.equals(r.id);
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
      (update(readings)..where((tbl) => _sameGroupAs(tbl, r))).write(
        ReadingsCompanion(takenAt: Value(to)),
      );

  // --- Measurement import (U32) --------------------------------------------

  /// Batch-inserts externally imported readings. Unlike [insertReadingGroup]
  /// (one shared timestamp per batch), every row keeps its own file timestamp
  /// — the watermark and rewind-diff key on them — while sharing its session's
  /// [groupId] so a session edits/deletes like a manually entered batch.
  Future<void> insertImportedReadings(
    int tankId,
    List<({String paramKey, double value, DateTime takenAt, String groupId})>
    rows,
  ) => batch(
    (b) => b.insertAll(readings, [
      for (final r in rows)
        ReadingsCompanion.insert(
          tankId: tankId,
          paramKey: r.paramKey,
          value: r.value,
          takenAt: r.takenAt,
          groupId: Value(r.groupId),
        ),
    ]),
  );

  /// Deletes the reading groups created by one import (the result sheet's
  /// Undo). Returns the rows removed.
  Future<int> deleteReadingsByGroupIds(int tankId, List<String> groupIds) =>
      (delete(readings)..where(
            (r) => r.tankId.equals(tankId) & r.groupId.isIn(groupIds),
          ))
          .go();

  /// All import-source rows (few — one per tank+source that ever imported).
  Stream<List<ImportSource>> watchImportSources() =>
      select(importSources).watch();

  Future<List<ImportSource>> getAllImportSources() =>
      select(importSources).get();

  // --- Connected devices (U36) ---------------------------------------------

  /// All device rows, kind then oldest-first — the read-only Settings inventory.
  Stream<List<DeviceRecord>> watchDevices() =>
      (select(devices)..orderBy([
            (d) => OrderingTerm(expression: d.kind),
            (d) => OrderingTerm(expression: d.firstSeenAt),
          ]))
          .watch();

  /// Devices of one [kind] (e.g. `'reeffactory'` for the dashboard).
  Stream<List<DeviceRecord>> watchDevicesOfKind(String kind) =>
      (select(devices)
            ..where((d) => d.kind.equals(kind))
            ..orderBy([(d) => OrderingTerm(expression: d.firstSeenAt)]))
          .watch();

  Future<DeviceRecord?> deviceByIdentifier(String identifier) =>
      (select(devices)..where((d) => d.identifier.equals(identifier)))
          .getSingleOrNull();

  /// Adds or updates a ReefFactory device by serial (the add/edit flow). Re-adding
  /// an address whose serial already exists updates that row (the "device moved"
  /// / rename path) rather than duplicating it.
  Future<void> upsertReefFactoryDevice({
    required String identifier,
    required String model,
    required String address,
    String? name,
    int? tankId,
  }) => into(devices).insert(
    DevicesCompanion.insert(
      kind: 'reeffactory',
      identifier: identifier,
      name: Value(name),
      model: Value(model),
      address: Value(address),
      tankId: Value(tankId),
      lastSeenAt: Value(DateTime.now()),
    ),
    onConflict: DoUpdate(
      (_) => DevicesCompanion(
        model: Value(model),
        address: Value(address),
        name: Value(name),
        tankId: Value(tankId),
        lastSeenAt: Value(DateTime.now()),
      ),
      target: [devices.identifier],
    ),
  );

  /// Records the Hanna checker on first connect: inserts if absent (never
  /// clobbering a user-set name/tank on later measurements), always bumping
  /// last-seen.
  Future<void> ensureHannaDevice({
    required String identifier,
    String? name,
    String? model,
    int? tankId,
  }) async {
    await into(devices).insert(
      DevicesCompanion.insert(
        kind: 'hanna',
        identifier: identifier,
        name: Value(name),
        model: Value(model),
        tankId: Value(tankId),
        lastSeenAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await touchDeviceSeen(identifier);
  }

  /// Bumps a device's last-seen timestamp (after a successful refresh/connect).
  Future<void> touchDeviceSeen(String identifier) =>
      (update(devices)..where((d) => d.identifier.equals(identifier))).write(
        DevicesCompanion(lastSeenAt: Value(DateTime.now())),
      );

  Future<void> updateDeviceNameTank(int id, {String? name, int? tankId}) =>
      (update(devices)..where((d) => d.id.equals(id))).write(
        DevicesCompanion(name: Value(name), tankId: Value(tankId)),
      );

  Future<void> deleteDevice(int id) =>
      (delete(devices)..where((d) => d.id.equals(id))).go();

  Future<ImportSource?> getImportSource(int tankId, String source) =>
      (select(importSources)..where(
            (s) => s.tankId.equals(tankId) & s.source.equals(source),
          ))
          .getSingleOrNull();

  /// Inserts or replaces the (tank, source) row — single statement on the
  /// composite PK, same idiom as the ratio-visibility upserts (#10).
  Future<void> upsertImportSource(ImportSourcesCompanion row) =>
      into(importSources).insertOnConflictUpdate(row);

  Future<void> deleteImportSource(int tankId, String source) =>
      (delete(importSources)..where(
            (s) => s.tankId.equals(tankId) & s.source.equals(source),
          ))
          .go();

  // --- Water changes -------------------------------------------------------

  /// Water changes for a tank, newest first.
  SimpleSelectStatement<$WaterChangesTable, WaterChange> _waterChanges(
    int tankId,
  ) => select(waterChanges)
    ..where((w) => w.tankId.equals(tankId))
    ..orderBy([
      (w) => OrderingTerm(expression: w.changedAt, mode: OrderingMode.desc),
    ]);

  Stream<List<WaterChange>> watchWaterChanges(int tankId) =>
      _waterChanges(tankId).watch();

  /// One-shot variant of [watchWaterChanges] (U27 collector).
  Future<List<WaterChange>> getWaterChanges(int tankId) =>
      _waterChanges(tankId).get();

  Future<void> insertWaterChange({
    required int tankId,
    required DateTime changedAt,
    double? amountLiters,
    String? note,
  }) => into(waterChanges).insert(
    WaterChangesCompanion.insert(
      tankId: tankId,
      changedAt: changedAt,
      amountLiters: Value(amountLiters),
      note: Value(note),
    ),
  );

  Future<void> updateWaterChange(WaterChange change) =>
      update(waterChanges).replace(change);

  Future<void> deleteWaterChange(int id) =>
      (delete(waterChanges)..where((w) => w.id.equals(id))).go();

  // --- Carbon changes ------------------------------------------------------

  /// Activated-carbon changes for a tank, newest first.
  SimpleSelectStatement<$CarbonChangesTable, CarbonChange> _carbonChanges(
    int tankId,
  ) => select(carbonChanges)
    ..where((c) => c.tankId.equals(tankId))
    ..orderBy([
      (c) => OrderingTerm(expression: c.changedAt, mode: OrderingMode.desc),
    ]);

  Stream<List<CarbonChange>> watchCarbonChanges(int tankId) =>
      _carbonChanges(tankId).watch();

  /// One-shot variant of [watchCarbonChanges] (U27 collector).
  Future<List<CarbonChange>> getCarbonChanges(int tankId) =>
      _carbonChanges(tankId).get();

  Future<void> insertCarbonChange({
    required int tankId,
    required DateTime changedAt,
    double? grams,
    String? note,
  }) => into(carbonChanges).insert(
    CarbonChangesCompanion.insert(
      tankId: tankId,
      changedAt: changedAt,
      grams: Value(grams),
      note: Value(note),
    ),
  );

  Future<void> updateCarbonChange(CarbonChange change) =>
      update(carbonChanges).replace(change);

  Future<void> deleteCarbonChange(int id) =>
      (delete(carbonChanges)..where((c) => c.id.equals(id))).go();

  // --- Equipment cleanings -------------------------------------------------

  /// Equipment cleanings for a tank, newest first.
  SimpleSelectStatement<$EquipmentCleaningsTable, EquipmentCleaning>
  _equipmentCleanings(int tankId) => select(equipmentCleanings)
    ..where((c) => c.tankId.equals(tankId))
    ..orderBy([
      (c) => OrderingTerm(expression: c.cleanedAt, mode: OrderingMode.desc),
    ]);

  Stream<List<EquipmentCleaning>> watchEquipmentCleanings(int tankId) =>
      _equipmentCleanings(tankId).watch();

  /// One-shot variant of [watchEquipmentCleanings] (U27 collector).
  Future<List<EquipmentCleaning>> getEquipmentCleanings(int tankId) =>
      _equipmentCleanings(tankId).get();

  Future<void> insertEquipmentCleaning({
    required int tankId,
    required DateTime cleanedAt,
    String? note,
  }) => into(equipmentCleanings).insert(
    EquipmentCleaningsCompanion.insert(
      tankId: tankId,
      cleanedAt: cleanedAt,
      note: Value(note),
    ),
  );

  Future<void> updateEquipmentCleaning(EquipmentCleaning cleaning) =>
      update(equipmentCleanings).replace(cleaning);

  Future<void> deleteEquipmentCleaning(int id) =>
      (delete(equipmentCleanings)..where((c) => c.id.equals(id))).go();

  // --- Ratio cards ---------------------------------------------------------

  /// Stored per-tank ratio-card settings (visibility + dashboard order). Rows
  /// are absent for ratios left at their defaults (visible, ordered last).
  Stream<List<RatioVisibility>> watchRatioVisibilities(int tankId) => (select(
    ratioVisibilities,
  )..where((r) => r.tankId.equals(tankId))).watch();

  Future<RatioVisibility?> _ratioRow(int tankId, String ratioKey) =>
      (select(ratioVisibilities)..where(
            (r) => r.tankId.equals(tankId) & r.ratioKey.equals(ratioKey),
          ))
          .getSingleOrNull();

  /// Sets whether a ratio card is shown for [tankId], leaving its order intact.
  ///
  /// A single upsert on the composite `(tankId, ratioKey)` primary key (#10):
  /// only the columns present in the companion are written on conflict, so a
  /// concurrent double-fire can neither duplicate the row nor throw a PK
  /// conflict, and existing order/bounds stay untouched.
  Future<void> setRatioVisible(int tankId, String ratioKey, bool visible) =>
      into(ratioVisibilities).insertOnConflictUpdate(
        RatioVisibilitiesCompanion.insert(
          tankId: tankId,
          ratioKey: ratioKey,
          visible: Value(visible),
        ),
      );

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
  }) => into(ratioVisibilities).insertOnConflictUpdate(
    RatioVisibilitiesCompanion.insert(
      tankId: tankId,
      ratioKey: ratioKey,
      amberLow: Value(amberLow),
      greenLow: Value(greenLow),
      greenHigh: Value(greenHigh),
      amberHigh: Value(amberHigh),
    ),
  );

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
          await (update(ratioVisibilities)..where(
                (t) => t.tankId.equals(tankId) & t.ratioKey.equals(r.key),
              ))
              .write(RatioVisibilitiesCompanion(displayOrder: Value(r.order)));
        }
      }
    });
  }

  // --- Dosing entries ------------------------------------------------------

  SimpleSelectStatement<$DosingEntriesTable, DosingEntry> _activeDosingEntries(
    int tankId,
  ) => select(dosingEntries)
    ..where(
      (d) => d.tankId.equals(tankId) & d.state.equals(DosingState.active.name),
    )
    ..orderBy([
      (d) => OrderingTerm(expression: d.displayOrder),
      (d) => OrderingTerm(expression: d.createdAt, mode: OrderingMode.desc),
    ]);

  /// Active dosing-plan entries for a tank, in dashboard order then newest
  /// first. Ended (superseded/stopped) segments are retained as history but
  /// excluded here.
  Stream<List<DosingEntry>> watchDosingEntries(int tankId) =>
      _activeDosingEntries(tankId).watch();

  /// One-shot variant of [watchDosingEntries] (U27 collector).
  Future<List<DosingEntry>> getDosingEntries(int tankId) =>
      _activeDosingEntries(tankId).get();

  /// Every dosing segment for a tank — active **and** ended (superseded/stopped)
  /// — newest first, for the history timeline. Ordered by when each segment
  /// began (`startedAt`, falling back to `createdAt` for any un-backfilled row).
  Stream<List<DosingEntry>> watchDosingHistory(int tankId) =>
      (select(dosingEntries)
            ..where((d) => d.tankId.equals(tankId))
            ..orderBy([
              (d) => OrderingTerm(
                expression: coalesce([d.startedAt, d.createdAt]),
                mode: OrderingMode.desc,
              ),
              (d) => OrderingTerm(
                expression: d.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<int> insertDosingEntry(DosingEntriesCompanion entry) async {
    // The max-order read and the insert run in one transaction (#10) so two
    // concurrent inserts can't be assigned the same displayOrder.
    return transaction(() async {
      final existing = await (select(
        dosingEntries,
      )..where((d) => d.tankId.equals(entry.tankId.value))).get();
      // max(displayOrder) + 1, not the row count: after deleting a middle entry
      // the count could collide with an existing order and make rows jump (#21).
      final order =
          existing.fold<int>(
            -1,
            (m, d) => d.displayOrder > m ? d.displayOrder : m,
          ) +
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

  /// Writes a captured pre-stop row back verbatim — the Undo of
  /// [stopDosingEntry] (U10). A full row replace, so `state` and the null
  /// `endedAt` are restored exactly; a no-op if the row was deleted meanwhile.
  Future<void> restoreDosingEntry(DosingEntry entry) =>
      update(dosingEntries).replace(entry);

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

  // --- Manual doses ----------------------------------------------------------

  /// One-off manual doses for a tank, newest first.
  SimpleSelectStatement<$ManualDosesTable, ManualDose> _manualDoses(
    int tankId,
  ) => select(manualDoses)
    ..where((d) => d.tankId.equals(tankId))
    ..orderBy([
      (d) => OrderingTerm(expression: d.dosedAt, mode: OrderingMode.desc),
      (d) => OrderingTerm(expression: d.id, mode: OrderingMode.desc),
    ]);

  Stream<List<ManualDose>> watchManualDoses(int tankId) =>
      _manualDoses(tankId).watch();

  /// One-shot variant of [watchManualDoses] (U27 collector).
  Future<List<ManualDose>> getManualDoses(int tankId) =>
      _manualDoses(tankId).get();

  Future<int> insertManualDose(ManualDosesCompanion dose) =>
      into(manualDoses).insert(dose);

  Future<void> updateManualDose(ManualDose dose) =>
      update(manualDoses).replace(dose);

  Future<void> deleteManualDose(int id) =>
      (delete(manualDoses)..where((d) => d.id.equals(id))).go();

  // --- Reading templates (test sets, U9) ------------------------------------

  /// Test sets for a tank, in user (drag) order, then insertion order.
  Stream<List<ReadingTemplate>> watchReadingTemplates(int tankId) =>
      (select(readingTemplates)
            ..where((t) => t.tankId.equals(tankId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.displayOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch();

  /// Creates a test set and returns its id. The max-order read and the insert
  /// run in one transaction (#10); max(displayOrder) + 1, not the row count
  /// (same collision fix as [insertDosingEntry]).
  Future<int> insertReadingTemplate({
    required int tankId,
    required String name,
    required List<String> paramKeys,
  }) {
    return transaction(() async {
      final existing = await (select(
        readingTemplates,
      )..where((t) => t.tankId.equals(tankId))).get();
      final order =
          existing.fold<int>(
            -1,
            (m, t) => t.displayOrder > m ? t.displayOrder : m,
          ) +
          1;
      return into(readingTemplates).insert(
        ReadingTemplatesCompanion.insert(
          tankId: tankId,
          name: name,
          paramKeys: encodeTemplateParamKeys(paramKeys),
          displayOrder: Value(order),
        ),
      );
    });
  }

  /// Renames a test set and/or replaces its parameter keys.
  Future<void> updateReadingTemplate(
    int id, {
    required String name,
    required List<String> paramKeys,
  }) => (update(readingTemplates)..where((t) => t.id.equals(id))).write(
    ReadingTemplatesCompanion(
      name: Value(name),
      paramKeys: Value(encodeTemplateParamKeys(paramKeys)),
    ),
  );

  Future<void> deleteReadingTemplate(int id) =>
      (delete(readingTemplates)..where((t) => t.id.equals(id))).go();

  // --- Microelement views (U17) ----------------------------------------------

  /// Custom microelement views for a tank, in user order, then insertion
  /// order.
  Stream<List<MicroView>> watchMicroViews(int tankId) =>
      (select(microViews)
            ..where((t) => t.tankId.equals(tankId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.displayOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch();

  /// Creates a custom view and returns its id. Same transactional
  /// max-order + 1 shape as [insertReadingTemplate] (#10).
  Future<int> insertMicroView({
    required int tankId,
    required String name,
    required List<String> paramKeys,
  }) {
    return transaction(() async {
      final existing = await (select(
        microViews,
      )..where((t) => t.tankId.equals(tankId))).get();
      final order =
          existing.fold<int>(
            -1,
            (m, t) => t.displayOrder > m ? t.displayOrder : m,
          ) +
          1;
      return into(microViews).insert(
        MicroViewsCompanion.insert(
          tankId: tankId,
          name: name,
          paramKeys: encodeTemplateParamKeys(paramKeys),
          displayOrder: Value(order),
        ),
      );
    });
  }

  Future<void> updateMicroView(
    int id, {
    required String name,
    required List<String> paramKeys,
  }) => (update(microViews)..where((t) => t.id.equals(id))).write(
    MicroViewsCompanion(
      name: Value(name),
      paramKeys: Value(encodeTemplateParamKeys(paramKeys)),
    ),
  );

  Future<void> deleteMicroView(int id) =>
      (delete(microViews)..where((t) => t.id.equals(id))).go();

  /// Persists a new manual ordering of a tank's test sets, given their ids in
  /// the desired left-to-right chip order.
  Future<void> reorderReadingTemplates(List<int> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          readingTemplates,
          ReadingTemplatesCompanion(displayOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // --- Maintenance schedules (U12) -------------------------------------------

  /// A tank's maintenance plans, in user (drag) order, then insertion order.
  Stream<List<MaintenanceSchedule>> watchMaintenanceSchedules(int tankId) =>
      (select(maintenanceSchedules)
            ..where((s) => s.tankId.equals(tankId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.displayOrder),
              (s) => OrderingTerm(expression: s.id),
            ]))
          .watch();

  /// One-shot read for the background reminder scheduler.
  Future<List<MaintenanceSchedule>> getMaintenanceSchedules(int tankId) =>
      (select(maintenanceSchedules)
            ..where((s) => s.tankId.equals(tankId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.displayOrder),
              (s) => OrderingTerm(expression: s.id),
            ]))
          .get();

  /// Creates a maintenance plan and returns its id. Max-order read + insert in
  /// one transaction (#10); max(displayOrder) + 1, not the row count.
  Future<int> insertMaintenanceSchedule({
    required int tankId,
    String? actionType,
    String? title,
    int? cadenceDays,
    String? cadenceUnit,
    String? weekdays,
    int? monthDay,
    DateTime? scheduledAt,
    bool remindEnabled = true,
    String? note,
  }) {
    return transaction(() async {
      final existing = await (select(
        maintenanceSchedules,
      )..where((s) => s.tankId.equals(tankId))).get();
      final order =
          existing.fold<int>(
            -1,
            (m, s) => s.displayOrder > m ? s.displayOrder : m,
          ) +
          1;
      return into(maintenanceSchedules).insert(
        MaintenanceSchedulesCompanion.insert(
          tankId: tankId,
          actionType: Value(actionType),
          title: Value(title),
          cadenceDays: Value(cadenceDays),
          cadenceUnit: Value(cadenceUnit),
          weekdays: Value(weekdays),
          monthDay: Value(monthDay),
          scheduledAt: Value(scheduledAt),
          remindEnabled: Value(remindEnabled),
          note: Value(note),
          displayOrder: Value(order),
        ),
      );
    });
  }

  /// Rewrites a plan's editable fields (type/title/repeat/date/remind/note).
  Future<void> updateMaintenanceSchedule(
    int id, {
    String? actionType,
    String? title,
    int? cadenceDays,
    String? cadenceUnit,
    String? weekdays,
    int? monthDay,
    DateTime? scheduledAt,
    required bool remindEnabled,
    String? note,
  }) => (update(maintenanceSchedules)..where((s) => s.id.equals(id))).write(
    MaintenanceSchedulesCompanion(
      actionType: Value(actionType),
      title: Value(title),
      cadenceDays: Value(cadenceDays),
      cadenceUnit: Value(cadenceUnit),
      weekdays: Value(weekdays),
      monthDay: Value(monthDay),
      scheduledAt: Value(scheduledAt),
      remindEnabled: Value(remindEnabled),
      note: Value(note),
    ),
  );

  /// Stamps a custom task done (typed tasks advance via their action log).
  Future<void> markMaintenanceDone(int id, DateTime at) =>
      (update(maintenanceSchedules)..where((s) => s.id.equals(id))).write(
        MaintenanceSchedulesCompanion(lastDoneAt: Value(at)),
      );

  Future<void> deleteMaintenanceSchedule(int id) =>
      (delete(maintenanceSchedules)..where((s) => s.id.equals(id))).go();

  /// Writes a captured row back verbatim — the undo path for both delete
  /// (row gone → re-insert) and "Mark done" (row present → full replace).
  /// `toCompanion(false)` keeps null fields *present* so the replace clears
  /// them (a bare data-class insert maps nulls to absent, which would leave
  /// e.g. a stamped `lastDoneAt` in place).
  Future<void> restoreMaintenanceSchedule(MaintenanceSchedule row) => into(
    maintenanceSchedules,
  ).insert(row.toCompanion(false), mode: InsertMode.insertOrReplace);

  /// Persists a new manual ordering of a tank's plans, given their ids in the
  /// desired order.
  Future<void> reorderMaintenanceSchedules(List<int> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          maintenanceSchedules,
          MaintenanceSchedulesCompanion(displayOrder: Value(i)),
          where: (s) => s.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // --- RO unit (U16) — device-scoped, shared across tanks --------------------

  /// Every RO stage (enabled and disabled), in overview order.
  Stream<List<RoStage>> watchRoStages() =>
      (select(roStages)..orderBy([
            (s) => OrderingTerm(expression: s.displayOrder),
            (s) => OrderingTerm(expression: s.id),
          ]))
          .watch();

  /// One-shot read for the background reminder scheduler.
  Future<List<RoStage>> getRoStages() =>
      (select(roStages)..orderBy([
            (s) => OrderingTerm(expression: s.displayOrder),
            (s) => OrderingTerm(expression: s.id),
          ]))
          .get();

  /// Seeds the default 4-stage set on first use. Exists-check + insert run in
  /// one transaction (#10) so a double-fire can't seed twice; a user who
  /// deleted every stage on purpose is *not* re-seeded on the next visit —
  /// the guard is a dedicated settings flag, not the row count.
  Future<void> seedDefaultRoStages() async {
    await transaction(() async {
      if (await getSetting(kRoSeededKey) != null) return;
      final existing = await (selectOnly(
        roStages,
      )..addColumns([roStages.id.count()])).getSingle();
      if ((existing.read(roStages.id.count()) ?? 0) == 0) {
        await batch((b) {
          for (var i = 0; i < kRoDefaultStageOrder.length; i++) {
            final type = kRoDefaultStageOrder[i];
            b.insert(
              roStages,
              RoStagesCompanion.insert(
                stageType: type.name,
                lifespanDays: kRoDefaultLifespanDays[type]!,
                displayOrder: Value(i),
              ),
            );
          }
        });
      }
      await setSetting(kRoSeededKey, 'true');
    });
  }

  /// Creates an RO stage and returns its id. Max-order read + insert in one
  /// transaction (#10); max(displayOrder) + 1, not the row count.
  Future<int> insertRoStage({
    required String stageType,
    String? title,
    required int lifespanDays,
    bool enabled = true,
    bool remindEnabled = true,
    String? note,
  }) {
    return transaction(() async {
      final existing = await select(roStages).get();
      final order =
          existing.fold<int>(
            -1,
            (m, s) => s.displayOrder > m ? s.displayOrder : m,
          ) +
          1;
      return into(roStages).insert(
        RoStagesCompanion.insert(
          stageType: stageType,
          title: Value(title),
          lifespanDays: lifespanDays,
          enabled: Value(enabled),
          remindEnabled: Value(remindEnabled),
          note: Value(note),
          displayOrder: Value(order),
        ),
      );
    });
  }

  Future<void> updateRoStage(RoStage stage) => update(roStages).replace(stage);

  /// Shows/hides a stage without touching its other fields — the "my unit has
  /// no DI resin" toggle. History is kept either way.
  Future<void> setRoStageEnabled(int id, bool enabled) =>
      (update(roStages)..where((s) => s.id.equals(id))).write(
        RoStagesCompanion(enabled: Value(enabled)),
      );

  /// Permanently removes a stage **and its replacement history** (FK
  /// cascade). Irreversible — callers confirm first (U10 conventions).
  Future<void> deleteRoStage(int id) =>
      (delete(roStages)..where((s) => s.id.equals(id))).go();

  /// The full replacement log, newest first (small by nature: a handful of
  /// stages replaced a few times a year).
  Stream<List<RoStageReplacement>> watchRoReplacements() =>
      (select(roStageReplacements)..orderBy([
            (r) =>
                OrderingTerm(expression: r.replacedAt, mode: OrderingMode.desc),
            (r) => OrderingTerm(expression: r.id, mode: OrderingMode.desc),
          ]))
          .watch();

  /// Logs a stage replacement; returns the row id (the undo handle).
  Future<int> insertRoReplacement({
    required int stageId,
    required DateTime replacedAt,
    String? note,
  }) => into(roStageReplacements).insert(
    RoStageReplacementsCompanion.insert(
      stageId: stageId,
      replacedAt: replacedAt,
      note: Value(note),
    ),
  );

  /// Removes a logged replacement — the Undo of a just-tapped "mark
  /// replaced".
  Future<void> deleteRoReplacement(int id) =>
      (delete(roStageReplacements)..where((r) => r.id.equals(id))).go();

  /// Latest replacement time per stage id — the elastic anchor for RO
  /// reminders. One aggregate query, mirroring [latestReadingTimesPerParam].
  Future<Map<int, DateTime>> latestRoReplacementTimes() async {
    final maxReplaced = roStageReplacements.replacedAt.max();
    final query = selectOnly(roStageReplacements)
      ..addColumns([roStageReplacements.stageId, maxReplaced])
      ..groupBy([roStageReplacements.stageId]);
    final rows = await query.get();
    return {
      for (final r in rows)
        if (r.read(maxReplaced) != null)
          r.read(roStageReplacements.stageId)!: r.read(maxReplaced)!,
    };
  }

  // --- Reminder-scheduler reads (U1/U12) -------------------------------------

  /// Latest reading timestamp per parameter key — the elastic anchor for
  /// testing reminders (U1). One aggregate query; never materializes rows.
  Future<Map<String, DateTime>> latestReadingTimesPerParam(int tankId) async {
    final maxTaken = readings.takenAt.max();
    final query = selectOnly(readings)
      ..addColumns([readings.paramKey, maxTaken])
      ..where(readings.tankId.equals(tankId))
      ..groupBy([readings.paramKey]);
    final rows = await query.get();
    return {
      for (final r in rows)
        if (r.read(maxTaken) != null)
          r.read(readings.paramKey)!: r.read(maxTaken)!,
    };
  }

  /// Newest logged action per maintenance action type — the elastic anchor
  /// for typed maintenance plans (U12).
  Future<Map<MaintenanceActionType, DateTime>> latestActionTimes(
    int tankId,
  ) async {
    Future<DateTime?> newest<T extends Table, R>(
      TableInfo<T, R> table,
      GeneratedColumn<int> tankColumn,
      GeneratedColumn<DateTime> timeColumn,
    ) async {
      final maxTime = timeColumn.max();
      final query = selectOnly(table)
        ..addColumns([maxTime])
        ..where(tankColumn.equals(tankId));
      final row = await query.getSingle();
      return row.read(maxTime);
    }

    final water = await newest(
      waterChanges,
      waterChanges.tankId,
      waterChanges.changedAt,
    );
    final carbon = await newest(
      carbonChanges,
      carbonChanges.tankId,
      carbonChanges.changedAt,
    );
    final cleaning = await newest(
      equipmentCleanings,
      equipmentCleanings.tankId,
      equipmentCleanings.cleanedAt,
    );
    return {
      MaintenanceActionType.waterChange: ?water,
      MaintenanceActionType.carbonChange: ?carbon,
      MaintenanceActionType.equipmentCleaning: ?cleaning,
    };
  }

  // --- Settings ------------------------------------------------------------

  Future<void> setActiveTank(int? tankId) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: kActiveTankKey,
          value: Value(tankId?.toString()),
        ),
      );

  Future<int?> getActiveTankId() async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(kActiveTankKey))).getSingleOrNull();
    final v = row?.value;
    return v == null ? null : int.tryParse(v);
  }

  Stream<int?> watchActiveTankId() =>
      (select(settings)..where((s) => s.key.equals(kActiveTankKey)))
          .watchSingleOrNull()
          .map((row) => row?.value == null ? null : int.tryParse(row!.value!));

  /// The whole settings store as one live key/value map — the single query
  /// behind every settings provider, so a write re-runs one query instead of
  /// one per watched key (T4).
  Stream<Map<String, String?>> watchAllSettings() => select(
    settings,
  ).watch().map((rows) => {for (final r in rows) r.key: r.value});

  /// Generic settings access (used for unit preferences, etc.).
  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> setSetting(String key, String? value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: Value(value)),
      );

  /// One-shot read of a settings value (null if the key is unset).
  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
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

  /// Every logged manual dose, across all tanks.
  Future<List<ManualDose>> getAllManualDoses() => select(manualDoses).get();

  /// Every test set, across all tanks.
  Future<List<ReadingTemplate>> getAllReadingTemplates() =>
      select(readingTemplates).get();

  /// Every custom microelement view, across all tanks.
  Future<List<MicroView>> getAllMicroViews() => select(microViews).get();

  /// Every maintenance plan, across all tanks.
  Future<List<MaintenanceSchedule>> getAllMaintenanceSchedules() =>
      select(maintenanceSchedules).get();

  /// Every RO stage (device-scoped — no tank filter applies).
  Future<List<RoStage>> getAllRoStages() => select(roStages).get();

  /// Every logged RO stage replacement.
  Future<List<RoStageReplacement>> getAllRoStageReplacements() =>
      select(roStageReplacements).get();

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
  ///
  /// [stickySettingKeys] are settings a restore may *add* but never *remove*:
  /// when such a key exists locally it wins over whatever the backup carries
  /// (including its absence); when it doesn't, the backup's value (if any)
  /// applies. Used for the early-adopter marker (U19): restoring a marker-less
  /// backup — a pre-marker file, or one made by a fresh post-Pro install —
  /// must not wipe a status nothing could ever re-seed.
  Future<void> restoreFromBackup({
    required List<TanksCompanion> tankRows,
    required List<TrackedParametersCompanion> paramRows,
    required List<ReadingsCompanion> readingRows,
    required List<WaterChangesCompanion> waterChangeRows,
    required List<CarbonChangesCompanion> carbonChangeRows,
    required List<EquipmentCleaningsCompanion> equipmentCleaningRows,
    required List<RatioVisibilitiesCompanion> ratioVisibilityRows,
    required List<DosingEntriesCompanion> dosingEntryRows,
    required List<ReadingTemplatesCompanion> readingTemplateRows,
    required List<MaintenanceSchedulesCompanion> maintenanceScheduleRows,
    // Optional with empty defaults: the RO tables (U16), micro views (U17)
    // and the manual dose log postdate several callers/tests, and an absent
    // backup section decodes to empty anyway.
    List<RoStagesCompanion> roStageRows = const [],
    List<RoStageReplacementsCompanion> roStageReplacementRows = const [],
    List<MicroViewsCompanion> microViewRows = const [],
    List<ManualDosesCompanion> manualDoseRows = const [],
    List<ImportSourcesCompanion> importSourceRows = const [],
    required List<SettingsCompanion> settingRows,
    Set<String> preserveSettingKeys = const {},
    Set<String> stickySettingKeys = const {},
  }) async {
    final incomingSettings = settingRows
        .where((r) => !preserveSettingKeys.contains(r.key.value))
        .toList();
    await transaction(() async {
      // Capture locally present sticky values before anything is deleted;
      // they are written back after the insert so the local value wins.
      final stickyLocal = <String, String?>{};
      if (stickySettingKeys.isNotEmpty) {
        final rows = await (select(
          settings,
        )..where((s) => s.key.isIn(stickySettingKeys.toList()))).get();
        for (final row in rows) {
          stickyLocal[row.key] = row.value;
        }
      }
      // Delete children before parents to satisfy foreign keys.
      await delete(readings).go();
      await delete(waterChanges).go();
      await delete(carbonChanges).go();
      await delete(equipmentCleanings).go();
      await delete(ratioVisibilities).go();
      await delete(dosingEntries).go();
      await delete(manualDoses).go();
      await delete(readingTemplates).go();
      await delete(microViews).go();
      await delete(maintenanceSchedules).go();
      await delete(roStageReplacements).go();
      await delete(roStages).go();
      await delete(importSources).go();
      await delete(trackedParameters).go();
      // Preserve device-local preferences: wipe only the settings the restore
      // is allowed to replace.
      if (preserveSettingKeys.isEmpty) {
        await delete(settings).go();
      } else {
        await (delete(
          settings,
        )..where((s) => s.key.isNotIn(preserveSettingKeys.toList()))).go();
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
        b.insertAll(manualDoses, manualDoseRows);
        b.insertAll(readingTemplates, readingTemplateRows);
        b.insertAll(microViews, microViewRows);
        b.insertAll(maintenanceSchedules, maintenanceScheduleRows);
        b.insertAll(roStages, roStageRows);
        b.insertAll(roStageReplacements, roStageReplacementRows);
        b.insertAll(importSources, importSourceRows);
        b.insertAll(settings, incomingSettings);
      });
      // Sticky keys: the pre-restore local value overrides the backup's.
      for (final e in stickyLocal.entries) {
        await into(settings).insertOnConflictUpdate(
          SettingsCompanion(key: Value(e.key), value: Value(e.value)),
        );
      }
      // Pre-v13 backups carry readings without group ids; give their legacy
      // timestamp clusters real ids so grouping keys on group_id alone (#15).
      await _backfillLegacyReadingGroupIds();
    });
  }
}

/// Encodes a test set's catalog keys for [ReadingTemplates.paramKeys].
String encodeTemplateParamKeys(List<String> keys) => jsonEncode(keys);

/// Decodes [ReadingTemplates.paramKeys]. Tolerates any malformed stored value
/// (e.g. a hand-edited backup) by returning an empty list — an empty set still
/// renders and stays editable, it never crashes the Add Reading screen.
List<String> decodeTemplateParamKeys(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is List) {
      return [
        for (final k in v)
          if (k is String) k,
      ];
    }
  } on FormatException {
    // Fall through to the empty list.
  }
  return const [];
}

extension ReadingTemplateKeys on ReadingTemplate {
  /// The set's catalog parameter keys, decoded from the stored JSON array.
  List<String> get keys => decodeTemplateParamKeys(paramKeys);
}

extension MicroViewKeys on MicroView {
  /// The view's catalog element keys, decoded from the stored JSON array
  /// (same tolerant decode as test sets).
  List<String> get keys => decodeTemplateParamKeys(paramKeys);
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
    final dir = await _documentsDir();
    final file = File(p.join(dir.path, 'reeftracker.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      // WAL keeps readers and writers from blocking each other (T6): a backup
      // encode's SELECTs no longer stall user writes and vice versa. The mode
      // is persistent, but issuing it on every open is the documented way to
      // cover fresh installs and pre-WAL databases alike.
      setup: (raw) => raw.execute('pragma journal_mode = WAL;'),
    );
  });
}

/// On some devices `getApplicationDocumentsDirectory()` never answers when
/// first called before the first frame (flutter/flutter#72872) — and
/// [LazyDatabase] caches its open callback's future, so a single stalled call
/// would leave the database permanently unopenable. Bound each attempt and
/// retry: a fresh call made after the first frame answers normally. The last
/// resort waits unbounded rather than failing the open outright.
Future<Directory> _documentsDir() async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      // Retry — by now startup has likely progressed past the first frame.
    }
  }
  return getApplicationDocumentsDirectory();
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
  List<RatioReading> get ratioReadings => [
    for (final r in this) r.ratioReading,
  ];
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
