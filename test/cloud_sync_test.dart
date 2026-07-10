import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/auto_backup.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/cloud_folder.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// In-memory [CloudFolder]: the test seam the SAF channel implementation
/// hides behind in production.
class FakeCloudFolder implements CloudFolder {
  final files = <String, Uint8List>{};
  final modifiedAt = <String, DateTime>{};
  bool failWrites = false;
  int writeCount = 0;
  var _clock = DateTime(2026, 1, 1);

  @override
  Future<CloudFolderSelection?> pickFolder() async =>
      const CloudFolderSelection(uri: 'fake://folder', name: 'Fake');

  @override
  Future<bool> checkAccess(String uri) async => true;

  @override
  Future<List<CloudFileInfo>> list(String uri) async => [
    for (final e in files.entries)
      CloudFileInfo(
        name: e.key,
        modified: modifiedAt[e.key]!,
        size: e.value.length,
      ),
  ];

  @override
  Future<Uint8List> read(String uri, String name) async => files[name]!;

  @override
  Future<void> write(String uri, String name, Uint8List bytes) async {
    if (failWrites) throw Exception('provider refused the write');
    writeCount++;
    files[name] = bytes;
    modifiedAt[name] = _clock;
    _clock = _clock.add(const Duration(minutes: 1));
  }

  @override
  Future<void> delete(String uri, String name) async {
    files.remove(name);
    modifiedAt.remove(name);
  }
}

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

  late Directory tempDir;
  late FakeCloudFolder folder;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reeftracker-cloudsync-');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    folder = FakeCloudFolder();
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

  Future<AppDatabase> seededDb() async {
    final db = newDb();
    await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    return db;
  }

  Future<void> enableSync(AppDatabase db) async {
    final settings = AppSettings(db);
    await settings.setCloudSyncFolder(uri: 'fake://folder', name: 'Fake');
    await settings.setCloudSyncEnabled(true);
  }

  /// Encodes the current DB into a file, like the auto-backup rotation does.
  var backupSeq = 0;
  Future<File> writeBackupFile(AppDatabase db) async {
    final json = await encodeBackupFromDb(db);
    final file = File(p.join(tempDir.path, 'backup-${backupSeq++}.json'));
    await file.writeAsString(json);
    return file;
  }

  group('cloudSyncContentHash', () {
    test(
      'is stable across time and per-device setting churn, changes on data',
      () async {
        final db = await seededDb();
        addTearDown(db.close);

        final first = cloudSyncContentHash(await encodeBackupFromDb(db));
        // exportedAt differs between encodes; a backup stamp (the noisiest
        // settings write — rewritten by every backup) must not matter either.
        await AppSettings(db).setLastBackupAt(DateTime.now());
        final second = cloudSyncContentHash(await encodeBackupFromDb(db));
        expect(second, first);

        // A genuine data change must change the hash.
        await db.createTankWithPreset(name: 'Frag', type: SetupType.mixed);
        final third = cloudSyncContentHash(await encodeBackupFromDb(db));
        expect(third, isNot(first));
      },
    );
  });

  group('listCloudSyncBackups', () {
    test('returns only our files, newest first by name', () async {
      await folder.write(
        'u',
        '${kCloudSyncPrefix}20260101-000000-000.json',
        Uint8List(0),
      );
      await folder.write(
        'u',
        '${kCloudSyncPrefix}20260103-000000-000.json',
        Uint8List(0),
      );
      // Foreign files (and a provider-mangled extension, which must still
      // match by prefix).
      await folder.write('u', 'holiday-photos.json', Uint8List(0));
      await folder.write(
        'u',
        '${kCloudSyncPrefix}20260102-000000-000.json.bin',
        Uint8List(0),
      );

      final files = await listCloudSyncBackups(folder, 'u');
      expect(files.map((f) => f.name).toList(), [
        '${kCloudSyncPrefix}20260103-000000-000.json',
        '${kCloudSyncPrefix}20260102-000000-000.json.bin',
        '${kCloudSyncPrefix}20260101-000000-000.json',
      ]);
    });
  });

  group('runCloudSyncPushIfEnabled', () {
    test('does nothing while disabled or without a folder', () async {
      final db = await seededDb();
      addTearDown(db.close);
      final file = await writeBackupFile(db);

      // Disabled (default).
      await runCloudSyncPushIfEnabled(db, file, folder: folder);
      expect(folder.files, isEmpty);

      // Enabled but no folder picked.
      await AppSettings(db).setCloudSyncEnabled(true);
      await runCloudSyncPushIfEnabled(db, file, folder: folder);
      expect(folder.files, isEmpty);
    });

    test('pushes, stamps success, and skips while data is unchanged', () async {
      final db = await seededDb();
      addTearDown(db.close);
      await enableSync(db);
      final settings = AppSettings(db);

      await runCloudSyncPushIfEnabled(
        db,
        await writeBackupFile(db),
        folder: folder,
      );
      expect(folder.files.keys, [
        predicate<String>((n) => n.startsWith(kCloudSyncPrefix)),
      ]);
      expect(await settings.readLastCloudSyncHash(), isNotNull);
      final syncedAt = AppSettings.decodeLastCloudSyncAt(
        await db.getSetting(kLastCloudSyncAtKey),
      );
      expect(syncedAt, isNotNull);

      // Same data, new backup file (fresh exportedAt) → the hash gate skips.
      await runCloudSyncPushIfEnabled(
        db,
        await writeBackupFile(db),
        folder: folder,
      );
      expect(folder.writeCount, 1);

      // Changed data → a second file lands.
      await db.createTankWithPreset(name: 'Frag', type: SetupType.mixed);
      await runCloudSyncPushIfEnabled(
        db,
        await writeBackupFile(db),
        folder: folder,
      );
      expect(folder.writeCount, 2);
    });

    test(
      'prunes to the keep count, oldest first, foreign files untouched',
      () async {
        final db = await seededDb();
        addTearDown(db.close);
        await enableSync(db);

        for (var i = 0; i < kCloudSyncKeep; i++) {
          await folder.write(
            'fake://folder',
            '${kCloudSyncPrefix}2020010$i-000000-000.json',
            Uint8List(0),
          );
        }
        await folder.write('fake://folder', 'unrelated.txt', Uint8List(0));
        folder.writeCount = 0;

        await runCloudSyncPushIfEnabled(
          db,
          await writeBackupFile(db),
          folder: folder,
        );

        final ours = folder.files.keys
            .where((n) => n.startsWith(kCloudSyncPrefix))
            .toList();
        expect(ours.length, kCloudSyncKeep);
        // The oldest seeded file was evicted; the new push is present.
        expect(
          ours,
          isNot(contains('${kCloudSyncPrefix}20200100-000000-000.json')),
        );
        expect(folder.files.keys, contains('unrelated.txt'));
      },
    );

    test(
      'stamps the error on failure, keeps retrying, clears on success',
      () async {
        final db = await seededDb();
        addTearDown(db.close);
        await enableSync(db);
        final settings = AppSettings(db);

        folder.failWrites = true;
        await runCloudSyncPushIfEnabled(
          db,
          await writeBackupFile(db),
          folder: folder,
        );
        expect(
          AppSettings.decodeLastCloudSyncErrorAt(
            await db.getSetting(kLastCloudSyncErrorAtKey),
          ),
          isNotNull,
        );
        // The hash is only written on success, so the next push retries.
        expect(await settings.readLastCloudSyncHash(), isNull);

        folder.failWrites = false;
        await runCloudSyncPushIfEnabled(
          db,
          await writeBackupFile(db),
          folder: folder,
        );
        expect(folder.files, isNotEmpty);
        expect(
          AppSettings.decodeLastCloudSyncErrorAt(
            await db.getSetting(kLastCloudSyncErrorAtKey),
          ),
          isNull,
        );
        expect(await settings.readLastCloudSyncHash(), isNotNull);
      },
    );

    test('a pushed file round-trips through the import pipeline', () async {
      final db = await seededDb();
      addTearDown(db.close);
      await enableSync(db);
      await runCloudSyncPushIfEnabled(
        db,
        await writeBackupFile(db),
        folder: folder,
      );

      final name = folder.files.keys.single;
      final data = decodeBackupBytes(await folder.read('fake://folder', name));
      final target = newDb();
      addTearDown(target.close);
      await importBackup(target, data);
      final tanks = await target.getTanks();
      expect(tanks.map((t) => t.name), ['Reef']);
    });
  });

  group('auto-backup integration', () {
    test('backupNow pushes through the global backend seam', () async {
      final previous = cloudFolderBackend;
      cloudFolderBackend = folder;
      addTearDown(() => cloudFolderBackend = previous);

      final db = await seededDb();
      addTearDown(db.close);
      await enableSync(db);

      await backupNow(db);

      expect(folder.files.keys.single, startsWith(kCloudSyncPrefix));
      // The pushed bytes are exactly the rotation file that was written.
      final local = await listAutoBackups();
      expect(
        utf8.decode(folder.files.values.single),
        await local.single.readAsString(),
      );
    });

    test('a failed push never fails the backup', () async {
      final previous = cloudFolderBackend;
      cloudFolderBackend = folder;
      addTearDown(() => cloudFolderBackend = previous);

      final db = await seededDb();
      addTearDown(db.close);
      await enableSync(db);
      folder.failWrites = true;

      await backupNow(db); // must not throw
      expect(await listAutoBackups(), hasLength(1));
      // Backup success stamped, push failure stamped separately.
      expect(
        AppSettings.decodeLastBackupErrorAt(
          await db.getSetting(kLastBackupErrorAtKey),
        ),
        isNull,
      );
      expect(
        AppSettings.decodeLastCloudSyncErrorAt(
          await db.getSetting(kLastCloudSyncErrorAtKey),
        ),
        isNotNull,
      );
    });
  });

  group('device-local exclusion', () {
    test('cloud sync settings never ride a restore', () {
      expect(
        SettingKey.deviceLocalKeys,
        containsAll([
          kCloudSyncEnabledKey,
          kCloudSyncFolderUriKey,
          kCloudSyncFolderNameKey,
          kLastCloudSyncAtKey,
          kLastCloudSyncErrorAtKey,
          kLastCloudSyncHashKey,
        ]),
      );
    });
  });
}
