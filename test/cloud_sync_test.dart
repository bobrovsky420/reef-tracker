import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

import 'fakes/fake_cloud_backup_store.dart';

void main() {
  group('backupContentHash', () {
    Map<String, dynamic> doc() => {
      'format': 'reeftracker-backup',
      'version': 1,
      'schemaVersion': 20,
      'exportedAt': '2026-07-15T08:00:00.000',
      'tanks': [
        {'id': 1, 'name': 'Reef'},
      ],
      'settings': [
        {'key': 'last_auto_backup_at', 'value': '1'},
      ],
    };

    test('ignores exportedAt, checksum, and the whole settings section', () {
      final a = doc();
      final b = doc()
        ..['exportedAt'] = '2026-07-16T09:30:00.000'
        ..['checksum'] = 'deadbeef'
        ..['settings'] = [
          {'key': 'sync_gdrive_last_push_at', 'value': '999'},
          {'key': 'temp_unit', 'value': 'f'},
        ];
      expect(
        backupContentHash(jsonEncode(a)),
        backupContentHash(jsonEncode(b)),
      );
    });

    test('changes when aquarium data changes', () {
      final a = doc();
      final b = doc()
        ..['tanks'] = [
          {'id': 1, 'name': 'Nano'},
        ];
      expect(
        backupContentHash(jsonEncode(a)),
        isNot(backupContentHash(jsonEncode(b))),
      );
    });

    test('two real encodes of the same data hash identically', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      final first = await encodeBackupFromDb(db);
      // A per-device settings stamp between encodes must not dirty the hash.
      await AppSettings(db).setLastBackupAt(DateTime(2026, 7, 15));
      final second = await encodeBackupFromDb(db);
      expect(backupContentHash(first), backupContentHash(second));
    });

    test('rejects a non-JSON document', () {
      expect(
        () => backupContentHash('not json'),
        throwsA(isA<InvalidBackupException>()),
      );
      expect(
        () => backupContentHash('[1, 2]'),
        throwsA(isA<InvalidBackupException>()),
      );
    });
  });

  group('runGDriveSyncIfDirty', () {
    late AppDatabase db;
    late AppSettings settings;
    late FakeCloudBackupStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      settings = AppSettings(db);
      store = FakeCloudBackupStore();
    });

    tearDown(() => db.close());

    Future<void> connectAndSeed() async {
      await settings.setSyncGdriveAccount('reef@test.dev');
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    }

    test('skips when no account is connected', () async {
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedDisabled,
      );
      expect(store.writeCalls, 0);
    });

    test('skips when there is nothing to protect (no tanks)', () async {
      await settings.setSyncGdriveAccount('reef@test.dev');
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedDisabled,
      );
      expect(store.writeCalls, 0);
    });

    test('pushes when dirty, then skips clean until data changes', () async {
      await connectAndSeed();

      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(store.files, hasLength(1));
      expect(await settings.readSyncGdriveFolderId(), isNotNull);
      expect(await settings.readSyncGdriveLastPushedHash(), isNotNull);

      // Unchanged data — and a fresh per-device settings stamp — stays clean.
      await settings.setLastBackupAt(DateTime(2026, 7, 15));
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedClean,
      );
      expect(store.writeCalls, 1);

      // Real data change → dirty again.
      await db.insertReadingGroup(
        tankId: 1,
        takenAt: DateTime(2026, 7, 15, 8),
        note: null,
        values: const [(paramKey: 'ph', value: 8.1)],
      );
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(store.files, hasLength(2));
    });

    test('pushed document round-trips through decodeBackup', () async {
      await connectAndSeed();
      await runGDriveSyncIfDirty(db, store: store);
      final data = decodeBackup(utf8.decode(store.files.values.single));
      expect(data.tanks, hasLength(1));
    });

    test('offline is silent: no error stamp, retried next run', () async {
      await connectAndSeed();
      store.offline = true;
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.offline,
      );
      expect(
        AppSettings.decodeSyncGdriveLastErrorAt(
          await db.getSetting(kSyncGdriveLastErrorAtKey),
        ),
        isNull,
      );

      store.offline = false;
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
    });

    test('provider failure stamps the error; next success clears it', () async {
      await connectAndSeed();
      store.failWrites = true;
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.failed,
      );
      expect(
        AppSettings.decodeSyncGdriveLastErrorAt(
          await db.getSetting(kSyncGdriveLastErrorAtKey),
        ),
        isNotNull,
      );
      // The failed run must not record the hash — the data is still unsynced.
      expect(await settings.readSyncGdriveLastPushedHash(), isNull);

      store.failWrites = false;
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(
        AppSettings.decodeSyncGdriveLastErrorAt(
          await db.getSetting(kSyncGdriveLastErrorAtKey),
        ),
        isNull,
      );
    });

    test(
      'dead grant (no token → CloudAuthRequiredException) is a failure',
      () async {
        await connectAndSeed();
        // The real store throws CloudAuthRequiredException when the token
        // provider returns null; simulate via a store-level failure of the
        // same non-IOException kind.
        store.failWrites = true;
        expect(
          await runGDriveSyncIfDirty(db, store: store),
          CloudSyncOutcome.failed,
        );
      },
    );

    test('recreates the folder when the cached id went stale', () async {
      await connectAndSeed();
      await runGDriveSyncIfDirty(db, store: store);
      final firstFolder = await settings.readSyncGdriveFolderId();

      store.invalidateFolder();
      await db.insertReadingGroup(
        tankId: 1,
        takenAt: DateTime(2026, 7, 15, 9),
        note: null,
        values: const [(paramKey: 'ph', value: 8.2)],
      );
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(await settings.readSyncGdriveFolderId(), isNot(firstFolder));
    });

    test('prunes the cloud folder to the keep count, oldest first', () async {
      await connectAndSeed();
      await db.setSetting(kAutoBackupKeepKey, '2');
      // Pre-existing older files (lexically before any real UTC stamp).
      store.files['reeftracker-auto-20200101-000000-000.json'] = [1];
      store.files['reeftracker-auto-20200102-000000-000.json'] = [2];
      // A foreign file must never be pruned.
      store.files['holiday-photo.jpg'] = [3];

      await runGDriveSyncIfDirty(db, store: store);

      expect(store.files.keys, contains('holiday-photo.jpg'));
      final backups = store.files.keys
          .where((n) => n.startsWith('reeftracker-auto-'))
          .toList();
      expect(backups, hasLength(2));
      expect(
        backups,
        isNot(contains('reeftracker-auto-20200101-000000-000.json')),
      );
    });

    test('a prune-only failure after a confirmed upload still records the '
        'push (#63)', () async {
      await connectAndSeed();
      // The connection dies between the successful write and the prune's
      // list() round-trip. The backup is durable on Drive, so the run must
      // still count as pushed and settle the dirty gate.
      store.listError = const SocketException('dropped after upload');
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(store.files, hasLength(1));
      expect(await settings.readSyncGdriveLastPushedHash(), isNotNull);
      expect(
        AppSettings.decodeSyncGdriveLastErrorAt(
          await db.getSetting(kSyncGdriveLastErrorAtKey),
        ),
        isNull,
      );

      // Gate settled: the next run must not re-upload the identical DB.
      store.listError = null;
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedClean,
      );
      expect(store.writeCalls, 1);

      // A non-IO prune failure (5xx) must not stamp a false "sync failed"
      // either — the upload it follows succeeded.
      await db.insertReadingGroup(
        tankId: 1,
        takenAt: DateTime(2026, 7, 21, 8),
        note: null,
        values: const [(paramKey: 'ph', value: 8.0)],
      );
      store.listError = const CloudApiException(500, 'server error');
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(
        AppSettings.decodeSyncGdriveLastErrorAt(
          await db.getSetting(kSyncGdriveLastErrorAtKey),
        ),
        isNull,
      );
    });

    test(
      'echo suppression: a cloud-restored document is not re-pushed',
      () async {
        await connectAndSeed();
        final json = await encodeBackupFromDb(db);
        await recordRestoredCloudBackup(db, json);
        expect(
          await runGDriveSyncIfDirty(db, store: store),
          CloudSyncOutcome.skippedClean,
        );
        expect(store.writeCalls, 0);
      },
    );
  });

  group('connect / disconnect', () {
    late AppDatabase db;
    late AppSettings settings;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settings = AppSettings(db);
    });

    tearDown(() => db.close());

    test('connect persists the account; cancel persists nothing', () async {
      final auth = FakeCloudAuth();
      final account = await connectGDrive(db, auth);
      expect(account?.email, 'reef@test.dev');
      expect(await settings.readSyncGdriveAccount(), 'reef@test.dev');

      final cancelled = FakeCloudAuth(account: null);
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      expect(await connectGDrive(db2, cancelled), isNull);
      expect(await AppSettings(db2).readSyncGdriveAccount(), isNull);
    });

    test('disconnect clears every sync_gdrive_* key', () async {
      final auth = FakeCloudAuth();
      await connectGDrive(db, auth);
      await settings.setSyncGdriveFolderId('folder-1');
      await settings.setSyncGdriveLastPushedHash('abc');
      await settings.setSyncGdriveLastPushAt(DateTime(2026, 7, 15));
      await settings.setSyncGdriveLastErrorAt(DateTime(2026, 7, 15));

      await disconnectGDrive(db, auth);

      expect(auth.disconnectCalls, 1);
      expect(await settings.readSyncGdriveAccount(), isNull);
      expect(await settings.readSyncGdriveFolderId(), isNull);
      expect(await settings.readSyncGdriveLastPushedHash(), isNull);
      expect(await db.getSetting(kSyncGdriveLastPushAtKey), isNull);
      expect(await db.getSetting(kSyncGdriveLastErrorAtKey), isNull);
    });

    test(
      'disconnect still clears local state when revocation throws',
      () async {
        final auth = FakeCloudAuth()..connectThrows = false;
        await connectGDrive(db, auth);
        final throwing = _ThrowingDisconnectAuth();
        await disconnectGDrive(db, throwing);
        expect(await settings.readSyncGdriveAccount(), isNull);
      },
    );
  });
}

class _ThrowingDisconnectAuth extends FakeCloudAuth {
  @override
  Future<void> disconnect() async => throw Exception('offline');
}
