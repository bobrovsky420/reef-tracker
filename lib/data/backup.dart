import 'dart:convert';
import 'dart:io';

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

/// Raised when a file is not a recognizable ReefTracker backup.
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);
  final String message;
  @override
  String toString() => 'InvalidBackupException: $message';
}

/// The decoded contents of a backup, ready to hand to
/// [AppDatabase.restoreFromBackup].
class BackupData {
  const BackupData({
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
    throw const InvalidBackupException('Not valid JSON.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const InvalidBackupException('Unexpected file contents.');
  }
  if (decoded['format'] != kBackupFormat) {
    throw const InvalidBackupException('Not a ReefTracker backup file.');
  }
  final version = decoded['version'];
  if (version is! int || version > kBackupVersion) {
    throw const InvalidBackupException(
        'Backup was made by a newer version of the app.');
  }

  try {
    final tanks = _listOfMaps(decoded['tanks']).map(_tankFromJson).toList();
    final params =
        _listOfMaps(decoded['trackedParameters']).map(_paramFromJson).toList();
    final readings =
        _listOfMaps(decoded['readings']).map(_readingFromJson).toList();
    // Water and carbon changes were added in later app versions; older backups
    // omit the keys entirely, so default to empty lists rather than failing.
    final waterChanges = decoded['waterChanges'] == null
        ? <WaterChangesCompanion>[]
        : _listOfMaps(decoded['waterChanges'])
            .map(_waterChangeFromJson)
            .toList();
    final carbonChanges = decoded['carbonChanges'] == null
        ? <CarbonChangesCompanion>[]
        : _listOfMaps(decoded['carbonChanges'])
            .map(_carbonChangeFromJson)
            .toList();
    final equipmentCleanings = decoded['equipmentCleanings'] == null
        ? <EquipmentCleaningsCompanion>[]
        : _listOfMaps(decoded['equipmentCleanings'])
            .map(_equipmentCleaningFromJson)
            .toList();
    // Ratio visibility was added later; older backups omit the key.
    final ratioVisibilities = decoded['ratioVisibilities'] == null
        ? <RatioVisibilitiesCompanion>[]
        : _listOfMaps(decoded['ratioVisibilities'])
            .map(_ratioVisibilityFromJson)
            .toList();
    // Dosing entries were added later; older backups omit the key.
    final dosingEntries = decoded['dosingEntries'] == null
        ? <DosingEntriesCompanion>[]
        : _listOfMaps(decoded['dosingEntries'])
            .map(_dosingEntryFromJson)
            .toList();
    final settings =
        _listOfMaps(decoded['settings']).map(_settingFromJson).toList();
    return BackupData(
      tanks: tanks,
      params: params,
      readings: readings,
      waterChanges: waterChanges,
      carbonChanges: carbonChanges,
      equipmentCleanings: equipmentCleanings,
      ratioVisibilities: ratioVisibilities,
      dosingEntries: dosingEntries,
      settings: settings,
    );
  } catch (_) {
    throw const InvalidBackupException('Backup file is corrupted.');
  }
}

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

/// Exports the database and hands the JSON file to the OS share sheet.
Future<void> exportBackup(AppDatabase db) async {
  final json = await encodeBackupFromDb(db);

  final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final fileName = 'reeftracker-backup-$stamp.json';
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(json);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json', name: fileName)],
    subject: fileName,
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

  final picked = result.files.single;
  String contents;
  final bytes = picked.bytes;
  if (bytes != null) {
    contents = utf8.decode(bytes);
  } else if (picked.path != null) {
    contents = await File(picked.path!).readAsString();
  } else {
    throw const InvalidBackupException('Could not read the selected file.');
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
