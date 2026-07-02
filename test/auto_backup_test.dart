import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/auto_backup.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so the
/// file-based auto-backup logic can run under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-autobk-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

  /// Writes [count] auto-backup files with strictly increasing timestamps in
  /// their names (so newest-first sorting is well-defined).
  Future<void> seedBackupFiles(int count) async {
    final dir = await autoBackupDir();
    for (var i = 0; i < count; i++) {
      final stamp = '2026010$i-000000';
      File(p.join(dir.path, '$kAutoBackupPrefix$stamp.json'))
          .writeAsStringSync('{}');
    }
  }

  group('AutoBackupInterval.fromName', () {
    test('parses known names and defaults to daily', () {
      expect(AutoBackupInterval.fromName('daily'), AutoBackupInterval.daily);
      expect(AutoBackupInterval.fromName('weekly'), AutoBackupInterval.weekly);
      expect(AutoBackupInterval.fromName(null), AutoBackupInterval.daily);
      expect(AutoBackupInterval.fromName('bogus'), AutoBackupInterval.daily);
    });
  });

  group('listAutoBackups', () {
    test('returns only matching files, newest first', () async {
      final dir = await autoBackupDir();
      await seedBackupFiles(3);
      // Noise that must be ignored.
      File(p.join(dir.path, 'reeftracker-manual-export.json'))
          .writeAsStringSync('{}');
      File(p.join(dir.path, '${kAutoBackupPrefix}20260101-000000.txt'))
          .writeAsStringSync('x');

      final files = await listAutoBackups();
      expect(files.length, 3);
      final names = files.map((f) => p.basename(f.path)).toList();
      expect(names.first, contains('20260102')); // newest
      expect(names.last, contains('20260100')); // oldest
    });
  });

  group('pruneAutoBackups', () {
    test('keeps only the newest N', () async {
      await seedBackupFiles(5);
      await pruneAutoBackups(2);
      final remaining = await listAutoBackups();
      expect(remaining.length, 2);
      expect(p.basename(remaining.first.path), contains('20260104'));
      expect(p.basename(remaining.last.path), contains('20260103'));
    });

    test('keep of 0 removes everything; negative is treated as 0', () async {
      await seedBackupFiles(3);
      await pruneAutoBackups(-1);
      expect(await listAutoBackups(), isEmpty);
    });
  });

  group('writeAutoBackup', () {
    test('writes a valid backup file and prunes to keep', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await seedBackupFiles(4); // pre-existing older backups

      final file = await writeAutoBackup(db, keep: 3);
      expect(await file.exists(), isTrue);
      expect(p.basename(file.path), startsWith(kAutoBackupPrefix));
      // The new file plus the 2 newest old ones = 3.
      expect((await listAutoBackups()).length, 3);
    });
  });

  group('backupNow', () {
    test('writes immediately (ignoring schedule) and stamps the timestamp',
        () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // A very recent stamp would make runAutoBackupIfDue skip; backupNow must
      // still write.
      await db.setSetting(kLastAutoBackupAtKey,
          DateTime.now().millisecondsSinceEpoch.toString());

      final file = await backupNow(db);
      expect(await file.exists(), isTrue);
      expect((await listAutoBackups()).length, 1);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
    });

    test('prunes to the configured keep count', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.setSetting(kAutoBackupKeepKey, '2');
      await seedBackupFiles(4); // pre-existing older backups

      await backupNow(db);
      expect((await listAutoBackups()).length, 2);
    });
  });

  group('write failures & rotation edge cases', () {
    test('a failed write propagates and does not stamp last-backup', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Block the backups folder with a plain file so creating the directory
      // (and hence writing any backup) fails, like a full/read-only disk.
      final blocker = File(p.join(docsDir.path, 'backups'));
      await blocker.writeAsString('not a directory');

      await expectLater(
          runAutoBackupIfDue(db), throwsA(isA<FileSystemException>()));
      expect(await db.getSetting(kLastAutoBackupAtKey), isNull,
          reason: 'a failed backup must not be recorded as completed');

      // The single-flight guard is cleared after a failure, so once the
      // obstruction is gone a retry succeeds.
      await blocker.delete();
      await runAutoBackupIfDue(db);
      expect((await listAutoBackups()).length, 1);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
    });

    test('in-flight tmp files never enter the rotation (#11 fixed)', () async {
      // Writes now go tmp-file + atomic rename, so an interrupted write leaves
      // at most a `.tmp` — which must be invisible to the rotation: it neither
      // counts against keep nor evicts valid backups.
      await seedBackupFiles(2); // valid-shaped 20260100 / 20260101
      final dir = await autoBackupDir();
      File(p.join(dir.path, '${kAutoBackupPrefix}20270101-000000.json.tmp'))
          .writeAsStringSync('{"format": "reeftracker-ba'); // truncated

      await pruneAutoBackups(2);

      final names =
          (await listAutoBackups()).map((f) => p.basename(f.path)).toList();
      expect(names, hasLength(2));
      expect(names.any((n) => n.contains('20270101')), isFalse,
          reason: 'a partial tmp file must not be listed as a backup');
      expect(names.any((n) => n.contains('20260100')), isTrue,
          reason: 'no valid backup may be evicted by a partial file');
    });

    test('a completed write is a whole file under the final name', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      final file = await writeAutoBackup(db, keep: 3);
      expect(p.basename(file.path), endsWith('.json'));
      // No leftover tmp artifacts next to the finished backup.
      final leftovers = (await autoBackupDir())
          .listSync()
          .where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('two writes within the same second collide on one filename '
        '(#13 open)', () async {
      // Documents open TODO #13: the yyyyMMdd-HHmmss stamp has one-second
      // resolution, so a manual "Back up now" racing the scheduled run
      // overwrites the same file instead of producing a second backup.
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      for (var attempt = 0; attempt < 5; attempt++) {
        final first = await writeAutoBackup(db, keep: 10);
        final second = await writeAutoBackup(db, keep: 10);
        if (p.basename(first.path) == p.basename(second.path)) {
          expect(await listAutoBackups(), hasLength(1));
          return;
        }
        // The two writes straddled a second boundary; clear and try again.
        await pruneAutoBackups(0);
      }
      fail('could not land two writes in the same second after 5 attempts');
    });
  });

  group('runAutoBackupIfDue', () {
    test('does nothing when disabled', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.setSetting(kAutoBackupEnabledKey, 'false');

      await runAutoBackupIfDue(db);
      expect(await listAutoBackups(), isEmpty);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNull);
    });

    test('does nothing when there are no tanks', () async {
      final db = newDb();
      addTearDown(db.close);
      // enabled by default
      await runAutoBackupIfDue(db);
      expect(await listAutoBackups(), isEmpty);
    });

    test('writes the first backup and records the timestamp', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      await runAutoBackupIfDue(db);

      expect((await listAutoBackups()).length, 1);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
    });

    test('skips when the last backup is within the interval', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Last backup just now -> daily interval not elapsed.
      await db.setSetting(kLastAutoBackupAtKey,
          DateTime.now().millisecondsSinceEpoch.toString());

      await runAutoBackupIfDue(db);
      expect(await listAutoBackups(), isEmpty);
    });

    test('writes when the interval has elapsed', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Last backup two days ago -> daily interval elapsed.
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2));
      await db.setSetting(
          kLastAutoBackupAtKey, twoDaysAgo.millisecondsSinceEpoch.toString());

      await runAutoBackupIfDue(db);
      expect((await listAutoBackups()).length, 1);
      // Timestamp advanced past the old value.
      final recorded =
          int.parse((await db.getSetting(kLastAutoBackupAtKey))!);
      expect(recorded, greaterThan(twoDaysAgo.millisecondsSinceEpoch));
    });

    test('concurrent calls share one in-flight run (single-flight)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      // Two calls fired before the first completes must reuse the same future
      // rather than each starting (and writing) a second overlapping backup.
      final f1 = runAutoBackupIfDue(db);
      final f2 = runAutoBackupIfDue(db);
      expect(identical(f1, f2), isTrue);
      await Future.wait([f1, f2]);

      expect((await listAutoBackups()).length, 1);

      // Once the run has finished the guard is cleared, so a later call starts a
      // fresh future (it returns quickly here since a backup is no longer due).
      final f3 = runAutoBackupIfDue(db);
      expect(identical(f3, f1), isFalse);
      await f3;
    });

    test('a future-dated last-backup stamp suppresses backups (#12 open)',
        () async {
      // Documents open TODO #12: after a clock rollback the stored stamp lies
      // in the future, `now.difference(last)` is negative (always < interval),
      // and no backup is taken until the wall clock passes the stamp again.
      // Flip once a negative difference is treated as "due".
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final future = DateTime.now().add(const Duration(days: 2));
      await db.setSetting(
          kLastAutoBackupAtKey, future.millisecondsSinceEpoch.toString());

      await runAutoBackupIfDue(db);
      expect(await listAutoBackups(), isEmpty);
    });

    test('respects a weekly interval (1 day not enough)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.setSetting(kAutoBackupIntervalKey, 'weekly');
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      await db.setSetting(
          kLastAutoBackupAtKey, oneDayAgo.millisecondsSinceEpoch.toString());

      await runAutoBackupIfDue(db);
      expect(await listAutoBackups(), isEmpty);
    });
  });
}
