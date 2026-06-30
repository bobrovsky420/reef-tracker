import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';

/// Identifies a ReefTracker backup document and guards against importing
/// arbitrary JSON files.
const String kBackupFormat = 'reeftracker-backup';

/// The backup document layout version. Bump (and handle older values in
/// [decodeBackup]) when the JSON shape changes incompatibly.
const int kBackupVersion = 1;

/// Why a backup file was rejected. Each value maps to a distinct user-facing
/// (localized) message so the user learns *what* is wrong, instead of a single
/// catch-all "corrupted".
enum BackupRejection {
  /// The file is not valid JSON, or not a ReefTracker backup at all.
  notBackupFile,

  /// The backup was produced by a newer app/schema than this one can read.
  newerVersion,

  /// Recognized as a backup, but the row shape is broken/incomplete.
  corrupted,

  /// Structurally valid but internally inconsistent: a child row references a
  /// missing aquarium, or primary keys are duplicated.
  inconsistent,
}

/// Raised when a file is not a recognizable or restorable ReefTracker backup.
///
/// [reason] drives the localized message shown to the user; [detail] carries
/// developer-facing context (which section/id failed) for logs.
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.reason, [this.detail]);
  final BackupRejection reason;
  final String? detail;
  @override
  String toString() =>
      'InvalidBackupException(${reason.name})${detail == null ? '' : ': $detail'}';
}

/// The decoded contents of a backup, ready to hand to
/// [AppDatabase.restoreFromBackup].
class BackupData {
  const BackupData({
    required this.schemaVersion,
    required this.tanks,
    required this.params,
    required this.readings,
    required this.waterChanges,
    required this.carbonChanges,
    required this.equipmentCleanings,
    required this.ratioVisibilities,
    required this.dosingEntries,
    required this.settings,
  });

  /// The database schema version the backup was written against (0 if the file
  /// predates this field). Compared to the app's schema in [validateBackup].
  final int schemaVersion;

  final List<TanksCompanion> tanks;
  final List<TrackedParametersCompanion> params;
  final List<ReadingsCompanion> readings;
  final List<WaterChangesCompanion> waterChanges;
  final List<CarbonChangesCompanion> carbonChanges;
  final List<EquipmentCleaningsCompanion> equipmentCleanings;
  final List<RatioVisibilitiesCompanion> ratioVisibilities;
  final List<DosingEntriesCompanion> dosingEntries;
  final List<SettingsCompanion> settings;
}

/// Serializes the whole database to a pretty-printed JSON string.
String encodeBackup({
  required int schemaVersion,
  required List<Tank> tanks,
  required List<TrackedParameter> params,
  required List<Reading> readings,
  required List<WaterChange> waterChanges,
  required List<CarbonChange> carbonChanges,
  required List<EquipmentCleaning> equipmentCleanings,
  required List<RatioVisibility> ratioVisibilities,
  required List<DosingEntry> dosingEntries,
  required List<Setting> settings,
}) {
  final map = <String, dynamic>{
    'format': kBackupFormat,
    'version': kBackupVersion,
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'tanks': tanks.map(_tankToJson).toList(),
    'trackedParameters': params.map(_paramToJson).toList(),
    'readings': readings.map(_readingToJson).toList(),
    'waterChanges': waterChanges.map(_waterChangeToJson).toList(),
    'carbonChanges': carbonChanges.map(_carbonChangeToJson).toList(),
    'equipmentCleanings':
        equipmentCleanings.map(_equipmentCleaningToJson).toList(),
    'ratioVisibilities':
        ratioVisibilities.map(_ratioVisibilityToJson).toList(),
    'dosingEntries': dosingEntries.map(_dosingEntryToJson).toList(),
    'settings': settings.map(_settingToJson).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Parses a backup JSON string into companion rows. Throws
/// [InvalidBackupException] if the document is not a ReefTracker backup or is
/// structurally broken.
BackupData decodeBackup(String jsonString) {
  late final dynamic decoded;
  try {
    decoded = jsonDecode(jsonString);
  } on FormatException {
    throw const InvalidBackupException(
        BackupRejection.notBackupFile, 'not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const InvalidBackupException(
        BackupRejection.notBackupFile, 'top level is not an object');
  }
  if (decoded['format'] != kBackupFormat) {
    throw const InvalidBackupException(
        BackupRejection.notBackupFile, 'wrong format marker');
  }
  final version = decoded['version'];
  if (version is! int || version > kBackupVersion) {
    throw const InvalidBackupException(
        BackupRejection.newerVersion, 'document version too new');
  }
  // schemaVersion was always written from v1; treat a missing/odd value as 0
  // (an unknown-but-older schema) rather than failing here.
  final rawSchema = decoded['schemaVersion'];
  final schemaVersion = rawSchema is int ? rawSchema : 0;

  // Each section is parsed in isolation so a failure names the offending
  // collection instead of collapsing into one generic "corrupted". Tables added
  // in later app versions are absent from older backups, so a missing key
  // defaults to an empty list rather than erroring.
  List<T> section<T>(
      String key, T Function(Map<String, dynamic>) fromJson,
      {bool required = true}) {
    final raw = decoded[key];
    if (raw == null) {
      if (required) {
        throw InvalidBackupException(
            BackupRejection.corrupted, 'missing section "$key"');
      }
      return <T>[];
    }
    try {
      return _listOfMaps(raw).map(fromJson).toList();
    } catch (e) {
      throw InvalidBackupException(
          BackupRejection.corrupted, 'section "$key": $e');
    }
  }

  return BackupData(
    schemaVersion: schemaVersion,
    tanks: section('tanks', _tankFromJson),
    params: section('trackedParameters', _paramFromJson),
    readings: section('readings', _readingFromJson),
    waterChanges: section('waterChanges', _waterChangeFromJson, required: false),
    carbonChanges:
        section('carbonChanges', _carbonChangeFromJson, required: false),
    equipmentCleanings: section(
        'equipmentCleanings', _equipmentCleaningFromJson,
        required: false),
    ratioVisibilities: section(
        'ratioVisibilities', _ratioVisibilityFromJson,
        required: false),
    dosingEntries:
        section('dosingEntries', _dosingEntryFromJson, required: false),
    settings: section('settings', _settingFromJson),
  );
}

/// Validates a decoded [data] set against the running app *before* any live
/// table is touched: rejects a backup from a newer schema, and checks internal
/// consistency (no duplicate primary keys, no child row pointing at a missing
/// aquarium). Throws [InvalidBackupException] with a specific [BackupRejection].
void validateBackup(BackupData data, {required int appSchemaVersion}) {
  if (data.schemaVersion > appSchemaVersion) {
    throw InvalidBackupException(BackupRejection.newerVersion,
        'schemaVersion ${data.schemaVersion} > app $appSchemaVersion');
  }

  // Unique aquarium ids (they are the FK target for every other table).
  final tankIds = <int>{};
  for (final t in data.tanks) {
    if (!tankIds.add(t.id.value)) {
      throw InvalidBackupException(
          BackupRejection.inconsistent, 'duplicate tank id ${t.id.value}');
    }
  }

  // Every child row must reference an aquarium present in the backup.
  void requireTank(String section, Iterable<int> tankIdsUsed) {
    for (final id in tankIdsUsed) {
      if (!tankIds.contains(id)) {
        throw InvalidBackupException(BackupRejection.inconsistent,
            '$section references missing tank $id');
      }
    }
  }

  requireTank('trackedParameters', data.params.map((r) => r.tankId.value));
  requireTank('readings', data.readings.map((r) => r.tankId.value));
  requireTank('waterChanges', data.waterChanges.map((r) => r.tankId.value));
  requireTank('carbonChanges', data.carbonChanges.map((r) => r.tankId.value));
  requireTank('equipmentCleanings',
      data.equipmentCleanings.map((r) => r.tankId.value));
  requireTank(
      'ratioVisibilities', data.ratioVisibilities.map((r) => r.tankId.value));
  requireTank('dosingEntries', data.dosingEntries.map((r) => r.tankId.value));
}

/// Imports [data] into the live database safely:
///
/// 1. in-memory pre-flight validation ([validateBackup]);
/// 2. a *rehearsal* restore into a throwaway temp database, so the real SQLite
///    engine (FK, NOT NULL, uniqueness) proves the data inserts cleanly before
///    any live data is deleted;
/// 3. the actual transactional restore into [db].
///
/// If step 1 or 2 fails, the live database is never touched.
Future<void> importBackup(AppDatabase db, BackupData data) async {
  validateBackup(data, appSchemaVersion: db.schemaVersion);
  await _rehearseRestore(data);
  await _applyRestore(db, data);
}

/// Runs the restore against a fresh temp database and throws if it doesn't
/// insert cleanly. The temp database (and its -wal/-shm sidecars) is always
/// deleted afterwards.
Future<void> _rehearseRestore(BackupData data) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(
      dir.path, 'reeftracker-import-${DateTime.now().microsecondsSinceEpoch}.sqlite'));
  await _deleteDbFiles(file);
  final temp = AppDatabase(NativeDatabase(file));
  try {
    await _applyRestore(temp, data);
  } on InvalidBackupException {
    rethrow;
  } catch (e) {
    // A constraint the in-memory checks don't cover (NOT NULL, type, unique).
    throw InvalidBackupException(BackupRejection.inconsistent, 'rehearsal: $e');
  } finally {
    await temp.close();
    await _deleteDbFiles(file);
  }
}

Future<void> _deleteDbFiles(File db) async {
  for (final path in [db.path, '${db.path}-wal', '${db.path}-shm']) {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

Future<void> _applyRestore(AppDatabase db, BackupData data) => db.restoreFromBackup(
      tankRows: data.tanks,
      paramRows: data.params,
      readingRows: data.readings,
      waterChangeRows: data.waterChanges,
      carbonChangeRows: data.carbonChanges,
      equipmentCleaningRows: data.equipmentCleanings,
      ratioVisibilityRows: data.ratioVisibilities,
      dosingEntryRows: data.dosingEntries,
      settingRows: data.settings,
    );

/// Serializes the entire database to a backup JSON string by reading every
/// table. Shared by manual export and the automatic backup service.
Future<String> encodeBackupFromDb(AppDatabase db) async => encodeBackup(
      schemaVersion: db.schemaVersion,
      tanks: await db.getAllTanks(),
      params: await db.getAllTrackedParameters(),
      readings: await db.getAllReadings(),
      waterChanges: await db.getAllWaterChanges(),
      carbonChanges: await db.getAllCarbonChanges(),
      equipmentCleanings: await db.getAllEquipmentCleanings(),
      ratioVisibilities: await db.getAllRatioVisibilities(),
      dosingEntries: await db.getAllDosingEntries(),
      settings: await db.getAllSettings(),
    );

/// Filename prefix for the plaintext JSON the share sheet receives. Used to
/// recognize (and sweep) our own leftovers in the temp directory.
const String _kExportPrefix = 'reeftracker-backup-';

/// Exports the database and hands the JSON file to the OS share sheet.
///
/// The exported JSON is a full plaintext copy of the database, so the temp file
/// is deleted as soon as the share sheet returns. Any leftovers from earlier
/// runs (e.g. an older app version, or a process killed mid-share) are swept
/// first, so plaintext exports can't accumulate in temp storage.
Future<void> exportBackup(AppDatabase db) async {
  final json = await encodeBackupFromDb(db);

  final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final fileName = '$_kExportPrefix$stamp.json';
  final dir = await getTemporaryDirectory();
  await _sweepStaleExports(dir);
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(json);

  try {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: fileName,
    );
  } finally {
    if (await file.exists()) await file.delete();
  }
}

/// Best-effort deletion of stale plaintext export files left in [dir] by
/// earlier exports. Never throws — a failed sweep must not block a new export.
Future<void> _sweepStaleExports(Directory dir) async {
  try {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith(_kExportPrefix) && name.endsWith('.json')) {
        try {
          await entity.delete();
        } catch (_) {
          // Ignore; another export may be sharing it right now.
        }
      }
    }
  } catch (_) {
    // Temp dir unreadable; nothing to sweep.
  }
}

/// Prompts the user to pick a backup file and decodes it. Returns null if the
/// user cancels the picker. Throws [InvalidBackupException] on a bad file.
Future<BackupData?> pickBackupData() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  String contents;
  final bytes = picked.bytes;
  if (bytes != null) {
    contents = utf8.decode(bytes);
  } else if (picked.path != null) {
    contents = await File(picked.path!).readAsString();
  } else {
    throw const InvalidBackupException(
        BackupRejection.notBackupFile, 'could not read the selected file');
  }
  return decodeBackup(contents);
}

// --- JSON mapping (DateTimes stored as epoch milliseconds) -----------------

Map<String, dynamic> _tankToJson(Tank t) => {
      'id': t.id,
      'name': t.name,
      'setupType': t.setupType,
      'volumeLiters': t.volumeLiters,
      'startDate': t.startDate?.millisecondsSinceEpoch,
      'notes': t.notes,
      'vendor': t.vendor,
      'model': t.model,
      'createdAt': t.createdAt.millisecondsSinceEpoch,
    };

TanksCompanion _tankFromJson(Map<String, dynamic> m) => TanksCompanion(
      id: Value(m['id'] as int),
      name: Value(m['name'] as String),
      setupType: Value(m['setupType'] as String),
      volumeLiters: Value((m['volumeLiters'] as num?)?.toDouble()),
      startDate: Value(_dateOrNull(m['startDate'])),
      notes: Value(m['notes'] as String?),
      vendor: Value(m['vendor'] as String?),
      model: Value(m['model'] as String?),
      createdAt: Value(_date(m['createdAt'])),
    );

Map<String, dynamic> _paramToJson(TrackedParameter t) => {
      'id': t.id,
      'tankId': t.tankId,
      'paramKey': t.paramKey,
      'unit': t.unit,
      'enabled': t.enabled,
      'displayOrder': t.displayOrder,
      'amberLow': t.amberLow,
      'greenLow': t.greenLow,
      'greenHigh': t.greenHigh,
      'amberHigh': t.amberHigh,
    };

TrackedParametersCompanion _paramFromJson(Map<String, dynamic> m) =>
    TrackedParametersCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      paramKey: Value(m['paramKey'] as String),
      unit: Value(m['unit'] as String),
      enabled: Value(m['enabled'] as bool),
      displayOrder: Value(m['displayOrder'] as int),
      amberLow: Value((m['amberLow'] as num?)?.toDouble()),
      greenLow: Value((m['greenLow'] as num?)?.toDouble()),
      greenHigh: Value((m['greenHigh'] as num?)?.toDouble()),
      amberHigh: Value((m['amberHigh'] as num?)?.toDouble()),
    );

Map<String, dynamic> _readingToJson(Reading r) => {
      'id': r.id,
      'tankId': r.tankId,
      'paramKey': r.paramKey,
      'value': r.value,
      'takenAt': r.takenAt.millisecondsSinceEpoch,
      'note': r.note,
    };

ReadingsCompanion _readingFromJson(Map<String, dynamic> m) => ReadingsCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      paramKey: Value(m['paramKey'] as String),
      value: Value((m['value'] as num).toDouble()),
      takenAt: Value(_date(m['takenAt'])),
      note: Value(m['note'] as String?),
    );

Map<String, dynamic> _waterChangeToJson(WaterChange w) => {
      'id': w.id,
      'tankId': w.tankId,
      'changedAt': w.changedAt.millisecondsSinceEpoch,
      'amountLiters': w.amountLiters,
      'note': w.note,
    };

WaterChangesCompanion _waterChangeFromJson(Map<String, dynamic> m) =>
    WaterChangesCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      changedAt: Value(_date(m['changedAt'])),
      amountLiters: Value((m['amountLiters'] as num?)?.toDouble()),
      note: Value(m['note'] as String?),
    );

Map<String, dynamic> _carbonChangeToJson(CarbonChange c) => {
      'id': c.id,
      'tankId': c.tankId,
      'changedAt': c.changedAt.millisecondsSinceEpoch,
      'grams': c.grams,
      'note': c.note,
    };

CarbonChangesCompanion _carbonChangeFromJson(Map<String, dynamic> m) =>
    CarbonChangesCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      changedAt: Value(_date(m['changedAt'])),
      grams: Value((m['grams'] as num?)?.toDouble()),
      note: Value(m['note'] as String?),
    );

Map<String, dynamic> _equipmentCleaningToJson(EquipmentCleaning c) => {
      'id': c.id,
      'tankId': c.tankId,
      'cleanedAt': c.cleanedAt.millisecondsSinceEpoch,
      'note': c.note,
    };

EquipmentCleaningsCompanion _equipmentCleaningFromJson(
        Map<String, dynamic> m) =>
    EquipmentCleaningsCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      cleanedAt: Value(_date(m['cleanedAt'])),
      note: Value(m['note'] as String?),
    );

Map<String, dynamic> _ratioVisibilityToJson(RatioVisibility r) => {
      'tankId': r.tankId,
      'ratioKey': r.ratioKey,
      'visible': r.visible,
      'displayOrder': r.displayOrder,
      'amberLow': r.amberLow,
      'greenLow': r.greenLow,
      'greenHigh': r.greenHigh,
      'amberHigh': r.amberHigh,
    };

RatioVisibilitiesCompanion _ratioVisibilityFromJson(Map<String, dynamic> m) =>
    RatioVisibilitiesCompanion(
      tankId: Value(m['tankId'] as int),
      ratioKey: Value(m['ratioKey'] as String),
      visible: Value(m['visible'] as bool),
      // displayOrder/bounds were added later; older backups omit them.
      displayOrder: m['displayOrder'] == null
          ? const Value.absent()
          : Value(m['displayOrder'] as int),
      amberLow: Value((m['amberLow'] as num?)?.toDouble()),
      greenLow: Value((m['greenLow'] as num?)?.toDouble()),
      greenHigh: Value((m['greenHigh'] as num?)?.toDouble()),
      amberHigh: Value((m['amberHigh'] as num?)?.toDouble()),
    );

Map<String, dynamic> _dosingEntryToJson(DosingEntry d) => {
      'id': d.id,
      'tankId': d.tankId,
      'productKey': d.productKey,
      'vendor': d.vendor,
      'program': d.program,
      'product': d.product,
      'elementKey': d.elementKey,
      'amount': d.amount,
      'amountUnit': d.amountUnit,
      'basis': d.basis,
      'frequency': d.frequency,
      'intervalDays': d.intervalDays,
      'weekdays': d.weekdays,
      'doseTime': d.doseTime,
      'note': d.note,
      'displayOrder': d.displayOrder,
      'createdAt': d.createdAt.millisecondsSinceEpoch,
    };

DosingEntriesCompanion _dosingEntryFromJson(Map<String, dynamic> m) =>
    DosingEntriesCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      productKey: Value(m['productKey'] as String?),
      vendor: Value(m['vendor'] as String?),
      program: Value(m['program'] as String?),
      product: Value(m['product'] as String),
      elementKey: Value(m['elementKey'] as String?),
      amount: Value((m['amount'] as num?)?.toDouble()),
      amountUnit: Value(m['amountUnit'] as String?),
      basis: Value(m['basis'] as String?),
      frequency: Value(m['frequency'] as String?),
      intervalDays: Value(m['intervalDays'] as int?),
      weekdays: Value(m['weekdays'] as String?),
      doseTime: Value(m['doseTime'] as String?),
      note: Value(m['note'] as String?),
      displayOrder: Value(m['displayOrder'] as int),
      createdAt: Value(_date(m['createdAt'])),
    );

Map<String, dynamic> _settingToJson(Setting s) => {
      'key': s.key,
      'value': s.value,
    };

SettingsCompanion _settingFromJson(Map<String, dynamic> m) => SettingsCompanion(
      key: Value(m['key'] as String),
      value: Value(m['value'] as String?),
    );

List<Map<String, dynamic>> _listOfMaps(dynamic v) =>
    (v as List).cast<Map<String, dynamic>>();

DateTime _date(dynamic millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis as int);

DateTime? _dateOrNull(dynamic millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);
