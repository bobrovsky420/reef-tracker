import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/auto_backup.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/data/cloud_sync.dart' as cloud;
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

import 'fakes/fake_cloud_backup_store.dart';

/// Routes path_provider to a throwaway temp folder — the U35 restore path
/// writes a local safety backup and `importBackup` rehearses into a temp
/// database, both of which need a real filesystem under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

// --- Drive-shaped compatibility wrappers -------------------------------------
//
// Most of this suite predates the U44 generalization (one engine, per-provider
// [CloudSyncState]). These wrappers keep its call sites on the original Drive
// shapes while driving the real provider-neutral functions with the same
// [GDriveSyncState] production wires up on Android — the local declarations
// shadow the imported names; the `cloud.` prefix reaches the real ones.

GDriveSyncState _gdrive(AppDatabase db) => GDriveSyncState(AppSettings(db));

Future<CloudSyncOutcome> runGDriveSyncIfDirty(
  AppDatabase db, {
  required CloudBackupStore store,
}) => cloud.runCloudSyncIfDirty(db, store: store, state: _gdrive(db));

Future<CloudRestoreProposal?> checkCloudNewerBackup(
  AppDatabase db, {
  required CloudBackupStore store,
}) => cloud.checkCloudNewerBackup(db, store: store, state: _gdrive(db));

Future<void> dismissCloudRestore(AppDatabase db, String fileName) =>
    cloud.dismissCloudRestore(_gdrive(db), fileName);

Future<void> restoreCloudBackup(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudBackupFile file,
  String? contents,
}) => cloud.restoreCloudBackup(
  db,
  store: store,
  state: _gdrive(db),
  file: file,
  contents: contents,
);

Future<void> recordRestoredCloudBackup(
  AppDatabase db,
  String json, {
  String? fileName,
}) => cloud.recordRestoredCloudBackup(
  json,
  state: _gdrive(db),
  fileName: fileName,
);

Future<bool> completeWelcomeRestore(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudBackupFile file,
  required String accountEmail,
}) => cloud.completeWelcomeRestore(
  db,
  store: store,
  state: _gdrive(db),
  file: file,
  enableSync: () => AppSettings(db).setSyncGdriveAccount(accountEmail),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-cloudsync-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

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

    test('ignores exportedAt, device, checksum, and device-local settings '
        'rows (#93: the section itself is hashed now)', () {
      final a = doc();
      final b = doc()
        ..['exportedAt'] = '2026-07-16T09:30:00.000'
        // The writing device's name (U35) is provenance, not data: restoring
        // device A's backup on device B must still hash clean on B.
        ..['device'] = 'Aquarium phone'
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

    test('a data-bearing settings row dirties the hash; row order, pre-#69 '
        'device-local rows and the founder marker do not (#93)', () {
      final a = doc()
        ..['settings'] = [
          {'key': 'device_vendor_order', 'value': 'apex,reefbeat'},
          {'key': 'hanna_method_sets', 'value': '{"alkalinity":"hi97115"}'},
        ];
      // The same data-bearing rows in the other order, plus rows a pre-#69
      // cloud file still carries: device-local bookkeeping, and the sticky
      // founder marker (a restore plants it locally, so the restoring
      // device's next encode would otherwise differ from the file it just
      // pulled).
      final b = doc()
        ..['settings'] = [
          {'key': 'sync_gdrive_account', 'value': 'reefkeeper@gmail.com'},
          {'key': 'legacy_free_since', 'value': '0.26.0'},
          {'key': 'hanna_method_sets', 'value': '{"alkalinity":"hi97115"}'},
          {'key': 'device_vendor_order', 'value': 'apex,reefbeat'},
        ];
      expect(
        backupContentHash(jsonEncode(a)),
        backupContentHash(jsonEncode(b)),
      );

      // An edited method set is a data change: it must read dirty — the old
      // whole-section strip made it sync-invisible (#93).
      final c = doc()
        ..['settings'] = [
          {'key': 'device_vendor_order', 'value': 'apex,reefbeat'},
          {'key': 'hanna_method_sets', 'value': '{"alkalinity":"hi97104"}'},
        ];
      expect(
        backupContentHash(jsonEncode(a)),
        isNot(backupContentHash(jsonEncode(c))),
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

    test('a settings-only data change (a method-set edit) reads dirty '
        '(#93)', () async {
      await connectAndSeed();
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      // A Hanna method-set edit is aquarium data even though it lives in the
      // settings table: it must push, not skip clean.
      await db.setSetting('hanna_method_sets', '{"alkalinity":"hi97115"}');
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      expect(store.writeCalls, 2);
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

    test('push records the uploaded filename and attaches device/hash '
        'metadata (U35)', () async {
      await connectAndSeed();
      await settings.setSyncDeviceName('Aquarium phone');
      await runGDriveSyncIfDirty(db, store: store);

      final name = store.files.keys.single;
      expect(await settings.readSyncGdriveLastPushedName(), name);
      expect(store.fileMetadata[name]?[kCloudMetaDevice], 'Aquarium phone');
      expect(
        store.fileMetadata[name]?[kCloudMetaContentHash],
        await settings.readSyncGdriveLastPushedHash(),
      );
      // The document itself carries the name too (provenance that survives
      // even providers without metadata support).
      expect(
        backupDeviceName(utf8.decode(store.files.values.single)),
        'Aquarium phone',
      );
    });

    test('renameSyncDevice dirties the gate so the label reaches the cloud '
        'without a data change (device is hash-excluded)', () async {
      await connectAndSeed();
      await runGDriveSyncIfDirty(db, store: store);
      expect(store.writeCalls, 1);
      // A pre-name upload carries no device metadata — the state every
      // pre-prompt connect is stuck in.
      expect(
        store.fileMetadata[store.files.keys.single],
        isNot(contains(kCloudMetaDevice)),
      );

      // Whitespace normalizes to "still no name": nothing changed, and the
      // next run must stay clean.
      expect(await renameSyncDevice(db, '  '), isFalse);
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedClean,
      );

      // A real (first) name pushes immediately, labeled.
      expect(await renameSyncDevice(db, 'Aquarium phone'), isTrue);
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.pushed,
      );
      final newest = (store.files.keys.toList()..sort()).last;
      expect(store.fileMetadata[newest]?[kCloudMetaDevice], 'Aquarium phone');

      // Re-saving the same name (modulo trim) is not a change — no re-upload.
      expect(await renameSyncDevice(db, ' Aquarium phone '), isFalse);
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.skippedClean,
      );
      expect(store.writeCalls, 2);
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

    test('a throw before the upload (DB dead during pre-flight/encode) is a '
        'failure, not an escaped exception (#95)', () async {
      await connectAndSeed();
      // Closing the database makes every read throw — including the
      // pre-flight account/tank reads and the encode, which used to sit
      // *before* the try and escaped the "Never throws" contract straight
      // into the fire-and-forget callers.
      await db.close();
      expect(
        await runGDriveSyncIfDirty(db, store: store),
        CloudSyncOutcome.failed,
      );
      expect(store.writeCalls, 0);
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

    test('disconnect clears every sync_gdrive_* key but keeps the device '
        'name', () async {
      final auth = FakeCloudAuth();
      await connectGDrive(db, auth);
      await settings.setSyncGdriveFolderId('folder-1');
      await settings.setSyncGdriveLastPushedHash('abc');
      await settings.setSyncGdriveLastPushedName('reeftracker-auto-x.json');
      await settings.setSyncGdriveDismissedName('reeftracker-auto-y.json');
      await settings.setSyncGdriveLastPushAt(DateTime(2026, 7, 15));
      await settings.setSyncGdriveLastErrorAt(DateTime(2026, 7, 15));
      await settings.setSyncDeviceName('Aquarium phone');

      await disconnectGDrive(db, auth);

      expect(auth.disconnectCalls, 1);
      // Enumerated, so the test's title stays true as keys are added (#74) —
      // the hand-written version of this list is what drifted.
      for (final key in SettingKey.gdriveSyncKeys) {
        expect(
          await db.getSetting(key.storageKey),
          isNull,
          reason: '${key.storageKey} survived the disconnect',
        );
      }
      // The device's own label survives a disconnect: it names the device,
      // not the account relationship.
      expect(await settings.readSyncDeviceName(), 'Aquarium phone');
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

  group('checkCloudNewerBackup (U35)', () {
    late AppDatabase writer; // device A — pushes backups
    late AppDatabase reader; // device B — runs the launch pull-check
    late FakeCloudBackupStore store;

    setUp(() async {
      writer = AppDatabase(NativeDatabase.memory());
      reader = AppDatabase(NativeDatabase.memory());
      store = FakeCloudBackupStore();
      await AppSettings(writer).setSyncGdriveAccount('reef@test.dev');
      await AppSettings(writer).setSyncDeviceName('Aquarium phone');
      await AppSettings(reader).setSyncGdriveAccount('reef@test.dev');
    });
    tearDown(() async {
      await writer.close();
      await reader.close();
    });

    Future<void> seedAndPush() async {
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await runGDriveSyncIfDirty(writer, store: store),
        CloudSyncOutcome.pushed,
      );
    }

    /// A second, newer push from the writer (a real data change; the small
    /// delay keeps the millisecond filename stamps strictly ordered).
    Future<void> pushNewer() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await writer.insertReadingGroup(
        tankId: 1,
        takenAt: DateTime(2026, 7, 23, 8),
        note: null,
        values: const [(paramKey: 'ph', value: 8.1)],
      );
      expect(
        await runGDriveSyncIfDirty(writer, store: store),
        CloudSyncOutcome.pushed,
      );
    }

    test('null when not connected', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(await checkCloudNewerBackup(db, store: store), isNull);
    });

    test('null when the cloud folder is empty', () async {
      expect(await checkCloudNewerBackup(reader, store: store), isNull);
    });

    test('null when the newest file is this device\'s own push', () async {
      await seedAndPush();
      expect(await checkCloudNewerBackup(writer, store: store), isNull);
    });

    test('offline is quiet (retried next launch)', () async {
      await seedAndPush();
      store.offline = true;
      expect(await checkCloudNewerBackup(reader, store: store), isNull);
    });

    test('fresh device: proposes the foreign backup as a fast-forward, '
        'device name straight from the listing metadata', () async {
      await seedAndPush();
      final proposal = await checkCloudNewerBackup(reader, store: store);
      expect(proposal, isNotNull);
      expect(proposal!.diverged, isFalse);
      expect(proposal.deviceName, 'Aquarium phone');
      expect(proposal.file.name, store.files.keys.single);
      // Metadata made the download unnecessary.
      expect(proposal.contents, isNull);
    });

    test(
      'diverged when this device also holds data that never synced',
      () async {
        await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
        await seedAndPush();
        final proposal = await checkCloudNewerBackup(reader, store: store);
        expect(proposal, isNotNull);
        expect(proposal!.diverged, isTrue);
      },
    );

    test(
      'a dismissed file stays quiet until an even newer one appears',
      () async {
        await seedAndPush();
        final proposal = await checkCloudNewerBackup(reader, store: store);
        await dismissCloudRestore(reader, proposal!.file.name);
        expect(await checkCloudNewerBackup(reader, store: store), isNull);

        await pushNewer();
        final again = await checkCloudNewerBackup(reader, store: store);
        expect(again, isNotNull);
        expect(again!.file.name, isNot(proposal.file.name));
      },
    );

    test('content identical to local data is adopted silently (no proposal, '
        'lineage backfilled)', () async {
      await seedAndPush();
      // The reader independently holds the exact same aquarium data (e.g. it
      // imported the same backup file by hand).
      final doc = utf8.decode(store.files.values.single);
      await importBackup(reader, decodeBackup(doc));

      expect(await checkCloudNewerBackup(reader, store: store), isNull);
      final readerSettings = AppSettings(reader);
      expect(
        await readerSettings.readSyncGdriveLastPushedName(),
        store.files.keys.single,
      );
      // Dirty gate settled too: the adopted state is not re-uploaded.
      expect(
        await runGDriveSyncIfDirty(reader, store: store),
        CloudSyncOutcome.skippedClean,
      );
    });

    test('pre-metadata upload: identified by downloading once, device name '
        'read from the document body', () async {
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      final json = await encodeBackupFromDb(writer);
      // Seeded directly — no appProperties, like an upload from an older app.
      store.files['reeftracker-auto-20260723-000000-000.json'] = utf8.encode(
        json,
      );

      final proposal = await checkCloudNewerBackup(reader, store: store);
      expect(proposal, isNotNull);
      expect(proposal!.contents, isNotNull);
      expect(proposal.deviceName, 'Aquarium phone');
    });

    test('an own pre-name upload is recognized by hash and the filename '
        'backfilled', () async {
      await seedAndPush();
      final writerSettings = AppSettings(writer);
      // Simulate a device that pushed before filenames were recorded.
      await writerSettings.setSyncGdriveLastPushedName(null);

      expect(await checkCloudNewerBackup(writer, store: store), isNull);
      expect(
        await writerSettings.readSyncGdriveLastPushedName(),
        store.files.keys.single,
      );
    });
  });

  group('restoreCloudBackup (U35)', () {
    late AppDatabase writer;
    late AppDatabase reader;
    late FakeCloudBackupStore store;

    setUp(() async {
      writer = AppDatabase(NativeDatabase.memory());
      reader = AppDatabase(NativeDatabase.memory());
      store = FakeCloudBackupStore();
      await AppSettings(writer).setSyncGdriveAccount('reef@test.dev');
      await AppSettings(reader).setSyncGdriveAccount('reef@test.dev');
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await runGDriveSyncIfDirty(writer, store: store),
        CloudSyncOutcome.pushed,
      );
    });
    tearDown(() async {
      await writer.close();
      await reader.close();
    });

    test('diverged device: safety backup first, data replaced, echo '
        'suppressed, dismissal cleared', () async {
      await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
      final proposal = await checkCloudNewerBackup(reader, store: store);
      expect(proposal!.diverged, isTrue);
      // A prior "not now" must not survive an actual restore.
      await dismissCloudRestore(reader, proposal.file.name);

      await restoreCloudBackup(
        reader,
        store: store,
        file: proposal.file,
        contents: proposal.contents,
      );

      // The cloud data replaced the local set…
      expect((await reader.getTanks()).map((t) => t.name), ['Reef']);
      // …but a local safety copy of the pre-restore data was written first.
      final safety = await listAutoBackups();
      expect(safety, hasLength(1));
      final saved = decodeBackup(await safety.single.readAsString());
      expect(saved.tanks.single.name.value, 'Nano');
      // Echo suppression: the restored state is neither re-uploaded nor
      // re-proposed, and the dismissal marker is gone.
      expect(
        await runGDriveSyncIfDirty(reader, store: store),
        CloudSyncOutcome.skippedClean,
      );
      expect(await checkCloudNewerBackup(reader, store: store), isNull);
      expect(await AppSettings(reader).readSyncGdriveDismissedName(), isNull);
    });

    test('empty device (onboarding): restores without writing a pointless '
        'safety backup', () async {
      final proposal = await checkCloudNewerBackup(reader, store: store);
      expect(proposal!.diverged, isFalse);

      await restoreCloudBackup(reader, store: store, file: proposal.file);

      expect((await reader.getTanks()).map((t) => t.name), ['Reef']);
      expect(await listAutoBackups(), isEmpty);
    });
  });

  group('welcome restore (U35)', () {
    late AppDatabase writer;
    late AppDatabase reader;
    late FakeCloudBackupStore store;

    setUp(() {
      writer = AppDatabase(NativeDatabase.memory());
      reader = AppDatabase(NativeDatabase.memory());
      store = FakeCloudBackupStore();
    });
    tearDown(() async {
      await writer.close();
      await reader.close();
    });

    Future<void> seedAndPush() async {
      await AppSettings(writer).setSyncGdriveAccount('reef@test.dev');
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await runGDriveSyncIfDirty(writer, store: store),
        CloudSyncOutcome.pushed,
      );
    }

    test('fetchNewestCloudBackup: null on an empty folder', () async {
      expect(await fetchNewestCloudBackup(store), isNull);
    });

    test(
      'fetchNewestCloudBackup: newest backup, foreign files ignored',
      () async {
        store.files['reeftracker-auto-20260101-000000-000.json'] = [1];
        store.files['reeftracker-auto-20260201-000000-000.json'] = [2];
        store.files['holiday-photo.jpg'] = [3];

        final newest = await fetchNewestCloudBackup(store);
        expect(newest?.name, 'reeftracker-auto-20260201-000000-000.json');
      },
    );

    test('founder backup: data restored AND push sync connected (the founder '
        'marker rides the backup)', () async {
      await writer.setSetting(kLegacyFreeSinceKey, '0.28.0');
      await seedAndPush();

      final newest = await fetchNewestCloudBackup(store);
      final synced = await completeWelcomeRestore(
        reader,
        store: store,
        file: newest!,
        accountEmail: 'reef@test.dev',
      );

      expect(synced, isTrue);
      expect((await reader.getTanks()).map((t) => t.name), ['Reef']);
      expect(
        await AppSettings(reader).readSyncGdriveAccount(),
        'reef@test.dev',
      );
      // Echo suppression carried over: the adopted state neither re-uploads
      // nor re-prompts.
      expect(
        await runGDriveSyncIfDirty(reader, store: store),
        CloudSyncOutcome.skippedClean,
      );
      expect(await checkCloudNewerBackup(reader, store: store), isNull);
    });

    test('marker-less (Standard) backup: data restored but sync NOT '
        'connected — the ungated action is the one-shot pull only', () async {
      await seedAndPush();

      final newest = await fetchNewestCloudBackup(store);
      final synced = await completeWelcomeRestore(
        reader,
        store: store,
        file: newest!,
        accountEmail: 'reef@test.dev',
      );

      expect(synced, isFalse);
      expect((await reader.getTanks()).map((t) => t.name), ['Reef']);
      expect(await AppSettings(reader).readSyncGdriveAccount(), isNull);
    });
  });

  group('iCloud state pack (U44)', () {
    late AppDatabase db;
    late AppSettings settings;
    late FakeCloudBackupStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settings = AppSettings(db);
      store = FakeCloudBackupStore();
    });
    tearDown(() => db.close());

    ICloudSyncState icloud(AppDatabase d) => ICloudSyncState(AppSettings(d));

    test('the enabled toggle is the on-state; a push stamps only the '
        'sync_icloud_* keys', () async {
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db)),
        CloudSyncOutcome.skippedDisabled,
      );

      await settings.setSyncIcloudEnabled(true);
      expect(
        await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db)),
        CloudSyncOutcome.pushed,
      );
      expect(store.files, hasLength(1));
      expect(await settings.readSyncIcloudLastPushedHash(), isNotNull);
      expect(await settings.readSyncIcloudLastPushedName(), isNotNull);
      // The Drive keys stay untouched — the packs are disjoint by prefix.
      expect(await settings.readSyncGdriveLastPushedHash(), isNull);
      expect(await settings.readSyncGdriveFolderId(), isNull);

      expect(
        await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db)),
        CloudSyncOutcome.skippedClean,
      );
      expect(store.writeCalls, 1);
    });

    test('no cached folder id: ensureFolder is called on every run', () async {
      await settings.setSyncIcloudEnabled(true);
      await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db));
      final callsAfterFirst = store.ensureFolderCalls;
      expect(callsAfterFirst, greaterThan(0));
      await db.createTankWithPreset(name: 'Frag', type: SetupType.mixed);
      await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db));
      expect(store.ensureFolderCalls, greaterThan(callsAfterFirst));
    });

    test('metadata-less provider: the U35 check identifies a foreign file '
        'through the download path and reads the device name from the '
        'document', () async {
      store.dropMetadata = true; // iCloud has no appProperties analog.
      final writer = AppDatabase(NativeDatabase.memory());
      addTearDown(writer.close);
      final writerSettings = AppSettings(writer);
      await writerSettings.setSyncIcloudEnabled(true);
      await writerSettings.setSyncDeviceName('Kitchen iPad');
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await cloud.runCloudSyncIfDirty(
          writer,
          store: store,
          state: icloud(writer),
        ),
        CloudSyncOutcome.pushed,
      );

      await settings.setSyncIcloudEnabled(true);
      final proposal = await cloud.checkCloudNewerBackup(
        db,
        store: store,
        state: icloud(db),
      );
      expect(proposal, isNotNull);
      // No listing metadata — the name came out of the downloaded document,
      // which the proposal carries along so the restore won't re-download.
      expect(proposal!.deviceName, 'Kitchen iPad');
      expect(proposal.contents, isNotNull);

      await cloud.restoreCloudBackup(
        db,
        store: store,
        state: icloud(db),
        file: proposal.file,
        contents: proposal.contents,
      );
      expect((await db.getTanks()).map((t) => t.name), ['Reef']);
      // Echo suppression landed in the iCloud keys.
      expect(
        await cloud.runCloudSyncIfDirty(db, store: store, state: icloud(db)),
        CloudSyncOutcome.skippedClean,
      );
      expect(
        await cloud.checkCloudNewerBackup(db, store: store, state: icloud(db)),
        isNull,
      );
    });

    test('welcome restore turns the toggle on for an entitled install and '
        'not for a Standard one', () async {
      store.dropMetadata = true;
      final writer = AppDatabase(NativeDatabase.memory());
      addTearDown(writer.close);
      await AppSettings(writer).setSyncIcloudEnabled(true);
      await writer.setSetting(kLegacyFreeSinceKey, '0.28.0');
      await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      await cloud.runCloudSyncIfDirty(
        writer,
        store: store,
        state: icloud(writer),
      );

      final newest = await fetchNewestCloudBackup(store);
      final synced = await cloud.completeWelcomeRestore(
        db,
        store: store,
        state: icloud(db),
        file: newest!,
        enableSync: () => settings.setSyncIcloudEnabled(true),
      );
      expect(synced, isTrue);
      expect(await settings.readSyncIcloudEnabled(), isTrue);
      expect((await db.getTanks()).map((t) => t.name), ['Reef']);
    });
  });
}

class _ThrowingDisconnectAuth extends FakeCloudAuth {
  @override
  Future<void> disconnect() async => throw Exception('offline');
}
