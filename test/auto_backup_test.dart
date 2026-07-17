import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/auto_backup.dart';
import 'package:reeftracker/data/backup.dart';
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
      File(
        p.join(dir.path, '$kAutoBackupPrefix$stamp.json'),
      ).writeAsStringSync('{}');
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
      File(
        p.join(dir.path, 'reeftracker-manual-export.json'),
      ).writeAsStringSync('{}');
      File(
        p.join(dir.path, '${kAutoBackupPrefix}20260101-000000.txt'),
      ).writeAsStringSync('x');

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

    test('the written file passes checksum verification (T7)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      final file = await writeAutoBackup(db, keep: 3);
      final json = await file.readAsString();
      expect(json, contains('"checksum":"'));
      // decodeBackup verifies the checksum for documents that carry one, so a
      // clean decode proves write + verify-before-rename kept the file intact.
      expect(decodeBackup(json).tanks.length, 1);
    });
  });

  group('backupNow', () {
    test(
      'writes immediately (ignoring schedule) and stamps the timestamp',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
        // A very recent stamp would make runAutoBackupIfDue skip; backupNow must
        // still write.
        await db.setSetting(
          kLastAutoBackupAtKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );

        final file = await backupNow(db);
        expect(await file.exists(), isTrue);
        expect((await listAutoBackups()).length, 1);
        expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
      },
    );

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
    test('a failed write propagates, does not stamp last-backup, and records '
        'the failure (#22)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Block the backups folder with a plain file so creating the directory
      // (and hence writing any backup) fails, like a full/read-only disk.
      final blocker = File(p.join(docsDir.path, 'backups'));
      await blocker.writeAsString('not a directory');

      await expectLater(
        runAutoBackupIfDue(db),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await db.getSetting(kLastAutoBackupAtKey),
        isNull,
        reason: 'a failed backup must not be recorded as completed',
      );
      expect(
        await db.getSetting(kLastBackupErrorAtKey),
        isNotNull,
        reason: 'a failed backup must be recorded so the UI can warn',
      );

      // The single-flight guard is cleared after a failure, so once the
      // obstruction is gone a retry succeeds — and clears the failure stamp.
      await blocker.delete();
      await runAutoBackupIfDue(db);
      expect((await listAutoBackups()).length, 1);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
      expect(
        await db.getSetting(kLastBackupErrorAtKey),
        isNull,
        reason: 'a successful backup must clear the recorded failure',
      );
    });

    test('a failed manual backupNow also records the failure (#22)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      final blocker = File(p.join(docsDir.path, 'backups'));
      await blocker.writeAsString('not a directory');

      await expectLater(backupNow(db), throwsA(isA<FileSystemException>()));
      expect(await db.getSetting(kLastBackupErrorAtKey), isNotNull);
    });

    test('in-flight tmp files never enter the rotation (#11 fixed)', () async {
      // Writes now go tmp-file + atomic rename, so an interrupted write leaves
      // at most a `.tmp` — which must be invisible to the rotation: it neither
      // counts against keep nor evicts valid backups.
      await seedBackupFiles(2); // valid-shaped 20260100 / 20260101
      final dir = await autoBackupDir();
      File(
        p.join(dir.path, '${kAutoBackupPrefix}20270101-000000.json.tmp'),
      ).writeAsStringSync('{"format": "reeftracker-ba'); // truncated

      await pruneAutoBackups(2);

      final names = (await listAutoBackups())
          .map((f) => p.basename(f.path))
          .toList();
      expect(names, hasLength(2));
      expect(
        names.any((n) => n.contains('20270101')),
        isFalse,
        reason: 'a partial tmp file must not be listed as a backup',
      );
      expect(
        names.any((n) => n.contains('20260100')),
        isTrue,
        reason: 'no valid backup may be evicted by a partial file',
      );
    });

    test('a completed write is a whole file under the final name', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      final file = await writeAutoBackup(db, keep: 3);
      expect(p.basename(file.path), endsWith('.json'));
      // No leftover tmp artifacts next to the finished backup.
      final leftovers = (await autoBackupDir()).listSync().where(
        (e) => e.path.endsWith('.tmp'),
      );
      expect(leftovers, isEmpty);
    });

    test(
      'the filename stamp is UTC with millisecond precision (#13/#14)',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

        final before = DateTime.now().toUtc();
        final file = await writeAutoBackup(db, keep: 3);
        final after = DateTime.now().toUtc();

        final name = p.basename(file.path);
        final m = RegExp(
          r'^reeftracker-auto-(\d{8})-(\d{6})-(\d{3})\.json$',
        ).firstMatch(name);
        expect(m, isNotNull, reason: 'unexpected stamp format in $name');
        final d = m!.group(1)!;
        final t = m.group(2)!;
        final stamped = DateTime.utc(
          int.parse(d.substring(0, 4)),
          int.parse(d.substring(4, 6)),
          int.parse(d.substring(6, 8)),
          int.parse(t.substring(0, 2)),
          int.parse(t.substring(2, 4)),
          int.parse(t.substring(4, 6)),
          int.parse(m.group(3)!),
        );
        // A local-time stamp would be off by the zone offset; UTC lands between
        // the surrounding wall-clock readings (with slack for ms truncation).
        expect(
          stamped.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
          reason: '$stamped is not a UTC stamp near $before',
        );
        expect(
          stamped.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
          reason: '$stamped is not a UTC stamp near $after',
        );
      },
    );

    test('two writes within the same second get distinct filenames '
        '(#13 fixed)', () async {
      // The stamp carries milliseconds, so a manual "Back up now" racing the
      // scheduled run can no longer overwrite the same file.
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      final first = await writeAutoBackup(db, keep: 10);
      final second = await writeAutoBackup(db, keep: 10);
      expect(p.basename(first.path), isNot(p.basename(second.path)));
      expect(await listAutoBackups(), hasLength(2));
    });
  });

  group('runAutoBackupIfDue', () {
    test('does nothing when disabled', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.setSetting(kAutoBackupEnabledKey, 'false');

      expect(await runAutoBackupIfDue(db), isFalse);
      expect(await listAutoBackups(), isEmpty);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNull);
    });

    test('does nothing when there are no tanks', () async {
      final db = newDb();
      addTearDown(db.close);
      // enabled by default
      expect(await runAutoBackupIfDue(db), isFalse);
      expect(await listAutoBackups(), isEmpty);
    });

    test('writes the first backup and records the timestamp', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

      // True = "a backup event happened", the trigger for the Drive push
      // (U24 coupling): main.dart only syncs when this reports a write.
      expect(await runAutoBackupIfDue(db), isTrue);

      expect((await listAutoBackups()).length, 1);
      expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
    });

    test('skips when the last backup is within the interval', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Last backup just now -> daily interval not elapsed.
      await db.setSetting(
        kLastAutoBackupAtKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      expect(await runAutoBackupIfDue(db), isFalse);
      expect(await listAutoBackups(), isEmpty);
    });

    test('writes when the interval has elapsed', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      // Last backup two days ago -> daily interval elapsed.
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      await db.setSetting(
        kLastAutoBackupAtKey,
        twoDaysAgo.millisecondsSinceEpoch.toString(),
      );

      expect(await runAutoBackupIfDue(db), isTrue);
      expect((await listAutoBackups()).length, 1);
      // Timestamp advanced past the old value.
      final recorded = int.parse((await db.getSetting(kLastAutoBackupAtKey))!);
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

    test(
      'a future-dated last-backup stamp is treated as due (#12 fixed)',
      () async {
        // After a clock rollback the stored stamp lies in the future and
        // `now.difference(last)` is negative; that must count as "due" instead
        // of silently disabling backups until the clock catches up.
        final db = newDb();
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
        final future = DateTime.now().add(const Duration(days: 2));
        await db.setSetting(
          kLastAutoBackupAtKey,
          future.millisecondsSinceEpoch.toString(),
        );

        await runAutoBackupIfDue(db);
        expect((await listAutoBackups()).length, 1);
        // The stamp was rewritten to "now", so the rolled-back clock schedules
        // normally from here on.
        final recorded = int.parse(
          (await db.getSetting(kLastAutoBackupAtKey))!,
        );
        expect(recorded, lessThan(future.millisecondsSinceEpoch));
      },
    );

    test(
      'backupNow waits for an in-flight scheduled run (#13 fixed)',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

        // Fire the manual backup while the scheduled (due) run is in flight:
        // both must complete, serialized into two distinct backups.
        final scheduled = runAutoBackupIfDue(db);
        final manual = backupNow(db);
        await Future.wait([scheduled, manual]);

        expect((await listAutoBackups()).length, 2);
      },
    );

    test(
      'a scheduled run fired during backupNow shares its slot (#13 fixed)',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await db.createTankWithPreset(name: 'A', type: SetupType.mixed);

        final manual = backupNow(db);
        // The scheduled run sees the manual backup in flight and awaits it
        // instead of encoding a second, overlapping backup. It reports true —
        // the shared slot resolved with a backup event — so a launch racing a
        // manual backup still triggers the coupled Drive push.
        expect(await runAutoBackupIfDue(db), isTrue);
        await manual;

        expect((await listAutoBackups()).length, 1);
        expect(await db.getSetting(kLastAutoBackupAtKey), isNotNull);
      },
    );

    test('respects a weekly interval (1 day not enough)', () async {
      final db = newDb();
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
      await db.setSetting(kAutoBackupIntervalKey, 'weekly');
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      await db.setSetting(
        kLastAutoBackupAtKey,
        oneDayAgo.millisecondsSinceEpoch.toString(),
      );

      expect(await runAutoBackupIfDue(db), isFalse);
      expect(await listAutoBackups(), isEmpty);
    });
  });
}
