import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/setup_type.dart';
import '../domain/supplement_catalog.dart';
import 'database.dart';
import 'export_share.dart';
import 'settings.dart';

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
    this.readingTemplates = const [],
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

  /// Test sets (U9). Defaults to empty: pre-U9 backups have no section, and
  /// the round-trip test pins that new backups carry it.
  final List<ReadingTemplatesCompanion> readingTemplates;
  final List<SettingsCompanion> settings;
}

/// Serializes the whole database to a compact JSON string.
///
/// Deliberately *not* pretty-printed (T5): indentation roughly doubles both
/// the encode work and the file size of every backup in the rotation (which
/// also counts against the ~25 MB Android cloud-backup quota), and
/// [decodeBackup] is whitespace-agnostic, so nothing reads the indentation.
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
  List<ReadingTemplate> readingTemplates = const [],
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
    'equipmentCleanings': equipmentCleanings
        .map(_equipmentCleaningToJson)
        .toList(),
    'ratioVisibilities': ratioVisibilities.map(_ratioVisibilityToJson).toList(),
    'dosingEntries': dosingEntries.map(_dosingEntryToJson).toList(),
    'readingTemplates': readingTemplates.map(_readingTemplateToJson).toList(),
    'settings': settings.map(_settingToJson).toList(),
  };
  final payload = jsonEncode(map);
  // Integrity checksum (T7): sha256 over the compact JSON of the document
  // without the `checksum` key. Catches in-field corruption that keeps the
  // JSON parseable — truncation already fails jsonDecode. Spliced into the
  // encoded string rather than re-encoding the (potentially large) map with
  // the key added; a compact-encoded non-empty map always ends in `}`.
  final checksum = sha256.convert(utf8.encode(payload)).toString();
  return '${payload.substring(0, payload.length - 1)},'
      '"checksum":"$checksum"}';
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
      BackupRejection.notBackupFile,
      'not valid JSON',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const InvalidBackupException(
      BackupRejection.notBackupFile,
      'top level is not an object',
    );
  }
  if (decoded['format'] != kBackupFormat) {
    throw const InvalidBackupException(
      BackupRejection.notBackupFile,
      'wrong format marker',
    );
  }
  // Distinguish the version failures (#38): only a genuinely newer document
  // may claim "backup from a newer app" — a missing version means this isn't
  // one of our documents, and a non-int one is a damaged/hand-edited file.
  final version = decoded['version'];
  if (version == null) {
    throw const InvalidBackupException(
      BackupRejection.notBackupFile,
      'missing version',
    );
  }
  if (version is! int) {
    throw InvalidBackupException(
      BackupRejection.corrupted,
      'non-integer version "$version"',
    );
  }
  if (version > kBackupVersion) {
    throw const InvalidBackupException(
      BackupRejection.newerVersion,
      'document version too new',
    );
  }
  // Integrity checksum (T7): sha256 over the compact JSON of the document
  // without the `checksum` key. jsonDecode preserves key order and Dart's
  // number encoding round-trips, so re-encoding the remaining map reproduces
  // the exact bytes hashed at encode time. Absent in backups written before
  // the checksum existed — those are accepted unverified. A hand-edited (e.g.
  // pretty-printed) file no longer matches its checksum by design: it is not
  // the document the app wrote.
  final storedChecksum = decoded.remove('checksum');
  if (storedChecksum != null) {
    if (storedChecksum is! String) {
      throw InvalidBackupException(
        BackupRejection.corrupted,
        'non-string checksum "$storedChecksum"',
      );
    }
    final actual = sha256.convert(utf8.encode(jsonEncode(decoded))).toString();
    if (actual != storedChecksum) {
      throw const InvalidBackupException(
        BackupRejection.corrupted,
        'checksum mismatch',
      );
    }
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
    String key,
    T Function(Map<String, dynamic>) fromJson, {
    bool required = true,
  }) {
    final raw = decoded[key];
    if (raw == null) {
      if (required) {
        throw InvalidBackupException(
          BackupRejection.corrupted,
          'missing section "$key"',
        );
      }
      return <T>[];
    }
    try {
      return _listOfMaps(raw).map(fromJson).toList();
    } catch (e) {
      throw InvalidBackupException(
        BackupRejection.corrupted,
        'section "$key": $e',
      );
    }
  }

  return BackupData(
    schemaVersion: schemaVersion,
    tanks: section('tanks', _tankFromJson),
    params: section('trackedParameters', _paramFromJson),
    readings: section('readings', _readingFromJson),
    waterChanges: section(
      'waterChanges',
      _waterChangeFromJson,
      required: false,
    ),
    carbonChanges: section(
      'carbonChanges',
      _carbonChangeFromJson,
      required: false,
    ),
    equipmentCleanings: section(
      'equipmentCleanings',
      _equipmentCleaningFromJson,
      required: false,
    ),
    ratioVisibilities: section(
      'ratioVisibilities',
      _ratioVisibilityFromJson,
      required: false,
    ),
    dosingEntries: section(
      'dosingEntries',
      _dosingEntryFromJson,
      required: false,
    ),
    readingTemplates: section(
      'readingTemplates',
      _readingTemplateFromJson,
      required: false,
    ),
    settings: section('settings', _settingFromJson),
  );
}

/// Validates a decoded [data] set against the running app *before* any live
/// table is touched: rejects a backup from a newer schema, and checks internal
/// consistency (no duplicate primary keys, no child row pointing at a missing
/// aquarium). Throws [InvalidBackupException] with a specific [BackupRejection].
void validateBackup(BackupData data, {required int appSchemaVersion}) {
  if (data.schemaVersion > appSchemaVersion) {
    throw InvalidBackupException(
      BackupRejection.newerVersion,
      'schemaVersion ${data.schemaVersion} > app $appSchemaVersion',
    );
  }

  // Preserved AUTOINCREMENT ids must stay in a sane range (#33): once the
  // sqlite_sequence max reaches 2^63−1 SQLite refuses *all* future inserts
  // (SQLITE_FULL), permanently breaking the table after restore. Negative and
  // zero ids are equally bogus for AUTOINCREMENT columns. 2^31 is orders of
  // magnitude beyond any real backup while leaving the id space practically
  // inexhaustible after restore.
  const maxSaneId = 1 << 31;
  void requireSaneIds(String section, Iterable<Value<int>> ids) {
    for (final id in ids) {
      // An absent id is fine — SQLite assigns the next one on insert.
      if (id.present && (id.value < 1 || id.value > maxSaneId)) {
        throw InvalidBackupException(
          BackupRejection.inconsistent,
          '$section id ${id.value} out of range',
        );
      }
    }
  }

  requireSaneIds('tanks', data.tanks.map((r) => r.id));
  requireSaneIds('trackedParameters', data.params.map((r) => r.id));
  requireSaneIds('readings', data.readings.map((r) => r.id));
  requireSaneIds('waterChanges', data.waterChanges.map((r) => r.id));
  requireSaneIds('carbonChanges', data.carbonChanges.map((r) => r.id));
  requireSaneIds(
    'equipmentCleanings',
    data.equipmentCleanings.map((r) => r.id),
  );
  requireSaneIds('dosingEntries', data.dosingEntries.map((r) => r.id));
  requireSaneIds('readingTemplates', data.readingTemplates.map((r) => r.id));

  // Unique aquarium ids (they are the FK target for every other table).
  final tankIds = <int>{};
  for (final t in data.tanks) {
    if (!tankIds.add(t.id.value)) {
      throw InvalidBackupException(
        BackupRejection.inconsistent,
        'duplicate tank id ${t.id.value}',
      );
    }
  }

  // Every child row must reference an aquarium present in the backup.
  void requireTank(String section, Iterable<int> tankIdsUsed) {
    for (final id in tankIdsUsed) {
      if (!tankIds.contains(id)) {
        throw InvalidBackupException(
          BackupRejection.inconsistent,
          '$section references missing tank $id',
        );
      }
    }
  }

  requireTank('trackedParameters', data.params.map((r) => r.tankId.value));
  requireTank('readings', data.readings.map((r) => r.tankId.value));
  requireTank('waterChanges', data.waterChanges.map((r) => r.tankId.value));
  requireTank('carbonChanges', data.carbonChanges.map((r) => r.tankId.value));
  requireTank(
    'equipmentCleanings',
    data.equipmentCleanings.map((r) => r.tankId.value),
  );
  requireTank(
    'ratioVisibilities',
    data.ratioVisibilities.map((r) => r.tankId.value),
  );
  requireTank('dosingEntries', data.dosingEntries.map((r) => r.tankId.value));
  requireTank(
    'readingTemplates',
    data.readingTemplates.map((r) => r.tankId.value),
  );

  // A test set's name is user-visible text on a chip; a whitespace-only name
  // would render an invisible, untappable-looking chip (the SQL length check
  // only catches the fully empty string).
  for (final t in data.readingTemplates) {
    if (t.name.present && t.name.value.trim().isEmpty) {
      throw const InvalidBackupException(
        BackupRejection.inconsistent,
        'readingTemplates: blank name',
      );
    }
  }

  // Enum-ish text columns must hold values the app can interpret (#34): a
  // dosing `state` outside DosingState matches neither the active-plan filter
  // nor history — an unmanageable zombie row — and a garbage setupType or
  // frequency silently degrades into fallback behavior. Nulls pass where the
  // column is nullable; only present garbage rejects.
  void requireKnown(
    String field,
    Iterable<String?> values,
    Set<String> allowed,
  ) {
    for (final v in values) {
      if (v != null && !allowed.contains(v)) {
        throw InvalidBackupException(
          BackupRejection.inconsistent,
          '$field: unknown value "$v"',
        );
      }
    }
  }

  Set<String> names(List<Enum> values) => {for (final v in values) v.name};

  requireKnown(
    'tanks.setupType',
    data.tanks.map((t) => t.setupType.present ? t.setupType.value : null),
    names(SetupType.values),
  );
  requireKnown(
    'dosingEntries.state',
    data.dosingEntries.map((d) => d.state.present ? d.state.value : null),
    names(DosingState.values),
  );
  requireKnown(
    'dosingEntries.frequency',
    data.dosingEntries.map(
      (d) => d.frequency.present ? d.frequency.value : null,
    ),
    names(DoseFrequency.values),
  );
  requireKnown(
    'dosingEntries.amountUnit',
    data.dosingEntries.map(
      (d) => d.amountUnit.present ? d.amountUnit.value : null,
    ),
    names(DoseUnit.values),
  );
  requireKnown(
    'dosingEntries.basis',
    data.dosingEntries.map((d) => d.basis.present ? d.basis.value : null),
    names(DoseBasis.values),
  );
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
  // validateBackup stays on this isolate deliberately (T5): it only builds id
  // sets — copying [data] to a worker would cost about as much as the check.
  validateBackup(data, appSchemaVersion: db.schemaVersion);
  await _rehearseRestore(data);
  await _applyRestore(db, data);
}

/// Runs the restore against a fresh temp database and throws if it doesn't
/// insert cleanly. The temp database (and its -wal/-shm sidecars) is always
/// deleted afterwards.
Future<void> _rehearseRestore(BackupData data) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(
      dir.path,
      'reeftracker-import-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ),
  );
  await _deleteDbFiles(file);
  // createInBackground, not NativeDatabase(file): the synchronous executor
  // would run every rehearsal insert's SQLite C call on the calling (UI)
  // isolate — for a large backup that is a bigger import-path stall than the
  // JSON decode itself (T5).
  final temp = AppDatabase(NativeDatabase.createInBackground(file));
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

Future<void> _applyRestore(AppDatabase db, BackupData data) =>
    db.restoreFromBackup(
      tankRows: data.tanks,
      paramRows: data.params,
      readingRows: data.readings,
      waterChangeRows: data.waterChanges,
      carbonChangeRows: data.carbonChanges,
      equipmentCleaningRows: data.equipmentCleanings,
      ratioVisibilityRows: data.ratioVisibilities,
      dosingEntryRows: data.dosingEntries,
      readingTemplateRows: data.readingTemplates,
      settingRows: data.settings,
      // Never overwrite this device's own preferences with the backup's (#18).
      preserveSettingKeys: SettingKey.deviceLocalKeys,
    );

/// Serializes the entire database to a backup JSON string by reading every
/// table. Shared by manual export and the automatic backup service.
///
/// The table reads go through drift's background executor as usual; the JSON
/// string building — the CPU-heavy part for a years-old database — runs in a
/// short-lived worker isolate (T5) so a backup never janks the UI. That
/// matters because auto-backup fires right after the first frame and on
/// resume. The row lists are plain value objects (cheap to send); the result
/// string comes back via `Isolate.exit`, without a copy.
Future<String> encodeBackupFromDb(AppDatabase db) async {
  final schemaVersion = db.schemaVersion;
  final tanks = await db.getAllTanks();
  final params = await db.getAllTrackedParameters();
  final readings = await db.getAllReadings();
  final waterChanges = await db.getAllWaterChanges();
  final carbonChanges = await db.getAllCarbonChanges();
  final equipmentCleanings = await db.getAllEquipmentCleanings();
  final ratioVisibilities = await db.getAllRatioVisibilities();
  final dosingEntries = await db.getAllDosingEntries();
  final readingTemplates = await db.getAllReadingTemplates();
  final settings = await db.getAllSettings();
  // The closure must capture only sendable plain data — never [db]: an open
  // database (ports, native handles) cannot cross the isolate boundary.
  return Isolate.run(
    () => encodeBackup(
      schemaVersion: schemaVersion,
      tanks: tanks,
      params: params,
      readings: readings,
      waterChanges: waterChanges,
      carbonChanges: carbonChanges,
      equipmentCleanings: equipmentCleanings,
      ratioVisibilities: ratioVisibilities,
      dosingEntries: dosingEntries,
      readingTemplates: readingTemplates,
      settings: settings,
    ),
  );
}

/// Exports the database and hands the JSON file to the OS share sheet.
///
/// The exported JSON is a full plaintext copy of the database; see
/// [shareExportFile] for the staging/sweep lifecycle that keeps such copies
/// from lingering.
Future<void> exportBackup(AppDatabase db) async {
  final json = await encodeBackupFromDb(db);
  final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  await shareExportFile(
    fileName: '$kBackupExportPrefix$stamp.json',
    content: json,
    mimeType: 'application/json',
  );
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

  // Decoding parses the whole file (jsonDecode + companion mapping) — run it
  // in a worker isolate (T5) so a big import doesn't freeze the picker UI.
  // [InvalidBackupException] is plain data (enum + string), so Isolate.run
  // rethrows it here typed, keeping the rejection-message contract (#37).
  final picked = result.files.single;
  final bytes = picked.bytes;
  if (bytes != null) return Isolate.run(() => decodeBackupBytes(bytes));
  if (picked.path != null) {
    String contents;
    try {
      contents = await File(picked.path!).readAsString();
    } on FileSystemException catch (e) {
      // Unreadable file, or dart:io's readAsString failing to decode non-UTF-8
      // content — keep the InvalidBackupException contract (#37) so the user
      // gets the specific rejection message instead of a generic failure.
      throw InvalidBackupException(
        BackupRejection.notBackupFile,
        'unreadable file: ${e.message}',
      );
    }
    return Isolate.run(() => decodeBackup(contents));
  }
  throw const InvalidBackupException(
    BackupRejection.notBackupFile,
    'could not read the selected file',
  );
}

/// Decodes raw backup-file [bytes], keeping the [InvalidBackupException]
/// contract for non-UTF-8 content (#37): a binary file renamed `.json` is
/// reported as "not a backup file", not as a generic import failure.
BackupData decodeBackupBytes(List<int> bytes) {
  String contents;
  try {
    contents = utf8.decode(bytes);
  } on FormatException catch (e) {
    throw InvalidBackupException(
      BackupRejection.notBackupFile,
      'not UTF-8 text: ${e.message}',
    );
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
  'groupId': r.groupId,
};

ReadingsCompanion _readingFromJson(Map<String, dynamic> m) => ReadingsCompanion(
  id: Value(m['id'] as int),
  tankId: Value(m['tankId'] as int),
  paramKey: Value(m['paramKey'] as String),
  value: Value((m['value'] as num).toDouble()),
  takenAt: Value(_date(m['takenAt'])),
  note: Value(m['note'] as String?),
  // Absent in pre-v13 backups; such rows keep timestamp grouping (#15).
  groupId: Value(m['groupId'] as String?),
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
  Map<String, dynamic> m,
) => EquipmentCleaningsCompanion(
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
  'startedAt': d.startedAt?.millisecondsSinceEpoch,
  'endedAt': d.endedAt?.millisecondsSinceEpoch,
  'state': d.state,
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
      // Forward-tolerant: pre-history backups have no segment fields, so a
      // restored entry starts when it was created and is active.
      startedAt: Value(_dateOrNull(m['startedAt']) ?? _date(m['createdAt'])),
      endedAt: Value(_dateOrNull(m['endedAt'])),
      state: Value((m['state'] as String?) ?? DosingState.active.name),
    );

Map<String, dynamic> _readingTemplateToJson(ReadingTemplate t) => {
  'id': t.id,
  'tankId': t.tankId,
  'name': t.name,
  // Stored as a JSON string in the DB; embedded as a real JSON array in the
  // backup so the file stays hand-readable and the list shape is validated on
  // import by the cast below.
  'paramKeys': decodeTemplateParamKeys(t.paramKeys),
  'displayOrder': t.displayOrder,
};

ReadingTemplatesCompanion _readingTemplateFromJson(Map<String, dynamic> m) =>
    ReadingTemplatesCompanion(
      id: Value(m['id'] as int),
      tankId: Value(m['tankId'] as int),
      name: Value(m['name'] as String),
      // List.from checks every element eagerly: a non-string key throws here,
      // inside section(), and reports as a corrupted readingTemplates section.
      paramKeys: Value(
        encodeTemplateParamKeys(List<String>.from(m['paramKeys'] as List)),
      ),
      displayOrder: Value(m['displayOrder'] as int),
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
