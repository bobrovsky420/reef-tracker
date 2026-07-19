import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/hanna_import.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// DB-side mechanics of the Hanna Lab import (U32): the import-source
/// watermark rows and the batch insert/undo of imported readings. The pure
/// parsing/planning logic lives in `hanna_import_test.dart`; the backup
/// ride-along is pinned in `backup_test.dart`'s full round-trip.
void main() {
  late AppDatabase db;
  late int tankId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tankId = await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
  });
  tearDown(() => db.close());

  group('import-source rows', () {
    test('upsert inserts then replaces on the composite key', () async {
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tankId,
          source: kHannaImportSource,
          location: const Value('200G2'),
          importedUpTo: Value(DateTime(2026, 7, 1)),
        ),
      );
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tankId,
          source: kHannaImportSource,
          location: const Value('200G2'),
          importedUpTo: Value(DateTime(2026, 7, 19, 13, 38, 13)),
          rewound: const Value(false),
        ),
      );
      final row = await db.getImportSource(tankId, kHannaImportSource);
      expect(row, isNotNull);
      expect(row!.importedUpTo, DateTime(2026, 7, 19, 13, 38, 13));
      expect((await db.getAllImportSources()).length, 1);
    });

    test('a settings reset (null watermark + rewound) round-trips', () async {
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tankId,
          source: kHannaImportSource,
          location: const Value('200G2'),
          importedUpTo: const Value(null),
          rewound: const Value(true),
        ),
      );
      final row = (await db.getImportSource(tankId, kHannaImportSource))!;
      expect(row.importedUpTo, isNull);
      expect(row.rewound, isTrue);
      expect(row.location, '200G2');
    });

    test('deleting the tank cascades its import-source row', () async {
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tankId,
          source: kHannaImportSource,
        ),
      );
      await db.softDeleteTank(tankId);
      await db.hardDeleteTank(tankId);
      expect(await db.getAllImportSources(), isEmpty);
    });
  });

  group('imported readings', () {
    test('keep per-row timestamps and session groups; undo removes exactly '
        'the imported groups', () async {
      // A pre-existing manual reading that must survive the undo.
      await db.insertReading(
        tankId: tankId,
        paramKey: 'ph',
        value: 8.0,
        takenAt: DateTime(2026, 7, 1, 9),
        groupId: 'manual-group',
      );
      final rows = [
        (
          paramKey: 'alkalinity',
          value: 7.6,
          takenAt: DateTime(2026, 7, 19, 13, 8, 57),
          groupId: 'import-a',
        ),
        (
          paramKey: 'calcium',
          value: 417.0,
          takenAt: DateTime(2026, 7, 19, 13, 15, 36),
          groupId: 'import-a',
        ),
        (
          paramKey: 'ph',
          value: 8.1,
          takenAt: DateTime(2026, 7, 17, 10, 26, 57),
          groupId: 'import-b',
        ),
      ];
      await db.insertImportedReadings(tankId, rows);

      final all = await db.getAllReadings();
      expect(all, hasLength(4));
      final alk = all.singleWhere((r) => r.paramKey == 'alkalinity');
      expect(alk.takenAt, DateTime(2026, 7, 19, 13, 8, 57));
      expect(alk.groupId, 'import-a');

      final removed = await db.deleteReadingsByGroupIds(tankId, [
        'import-a',
        'import-b',
      ]);
      expect(removed, 3);
      final left = (await db.getAllReadings()).single;
      expect(left.groupId, 'manual-group');
    });
  });

  group('backup validation', () {
    test('rejects an import source referencing a missing tank', () {
      final data = BackupData(
        schemaVersion: 23,
        tanks: [
          TanksCompanion(
            id: const Value(1),
            name: const Value('Reef'),
            setupType: const Value('mixed'),
            createdAt: Value(DateTime(2026)),
          ),
        ],
        params: const [],
        readings: const [],
        waterChanges: const [],
        carbonChanges: const [],
        equipmentCleanings: const [],
        ratioVisibilities: const [],
        dosingEntries: const [],
        importSources: [
          ImportSourcesCompanion.insert(tankId: 2, source: 'hannaLab'),
        ],
        settings: const [],
      );
      expect(
        () => validateBackup(data, appSchemaVersion: 23),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.inconsistent,
          ),
        ),
      );
    });

    test('a backup without the section decodes to empty (pre-U32 file)', () {
      final json = encodeBackup(
        schemaVersion: 22,
        tanks: const [],
        params: const [],
        readings: const [],
        waterChanges: const [],
        carbonChanges: const [],
        equipmentCleanings: const [],
        ratioVisibilities: const [],
        dosingEntries: const [],
        settings: const [],
      );
      // Strip the section the current encoder writes, as an old file wouldn't
      // have it (and the checksum, which covered it).
      final map = jsonDecode(json) as Map<String, dynamic>
        ..remove('importSources')
        ..remove('checksum');
      expect(decodeBackup(jsonEncode(map)).importSources, isEmpty);
    });
  });
}
