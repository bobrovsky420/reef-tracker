import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/install_id.dart';
import 'package:reeftracker/data/settings.dart';

import 'sync_test_helpers.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder so
/// the fingerprint-file logic can run under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Simulates the documents directory being unresolvable (platform-channel
/// failure): `getApplicationDocumentsDirectory()` throws on a null path.
class _BrokenPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-installid-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    resetInstallFingerprintForTest();
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  AppDatabase newDb() => AppDatabase(NativeDatabase.memory());
  File idFile() => File(p.join(docsDir.path, kInstallIdFileName));

  /// A fully populated sync identity: **every** `sync_gdrive_*` and
  /// `sync_icloud_*` key, plus the device name that must survive. Naming only
  /// some of them is what let #74 hide — the U35 filename keys were set
  /// nowhere, so nothing noticed the reconcile leaving them behind. (A real
  /// device only ever runs one provider; populating both here is what proves
  /// each gets its own clearing rule.)
  Future<void> connectSync(AppSettings settings) async {
    await settings.setSyncGdriveAccount('reef@example.com');
    await settings.setSyncGdriveFolderId('folder-1');
    await settings.setSyncGdriveLastPushedHash('hash-1');
    await settings.setSyncGdriveLastPushedName('reeftracker-20260701.json');
    await settings.setSyncGdriveDismissedName('reeftracker-20260601.json');
    await settings.setSyncGdriveLastPushAt(DateTime(2026, 7, 1));
    await settings.setSyncGdriveLastErrorAt(DateTime(2026, 7, 2));
    await settings.setSyncIcloudEnabled(true);
    await settings.setSyncIcloudLastPushedHash('hash-1');
    await settings.setSyncIcloudLastPushedName('reeftracker-20260701.json');
    await settings.setSyncIcloudDismissedName('reeftracker-20260601.json');
    await settings.setSyncIcloudLastPushAt(DateTime(2026, 7, 1));
    await settings.setSyncIcloudLastErrorAt(DateTime(2026, 7, 2));
    await settings.setSyncDeviceName('Old phone');
  }

  test(
    'fresh install: seeds matching fingerprint in file and database',
    () async {
      final db = newDb();
      addTearDown(db.close);

      await reconcileInstallFingerprint(db);

      final fileId = (await idFile().readAsString()).trim();
      final dbId = await AppSettings(db).readInstallFingerprint();
      expect(fileId, isNotEmpty);
      expect(dbId, fileId);
    },
  );

  test('applies the iOS backup-exclusion attribute on write and re-applies '
      'it on the all-quiet launch (#96)', () async {
    // Without the attribute the iOS fingerprint rides iCloud backup together
    // with the database and the #62 restore detection reads "all quiet"
    // forever — the file must go through `excludeFromDeviceBackup` like
    // `.device_secrets` does.
    const channel = MethodChannel('cz.reeftracker/file_backup');
    final excluded = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'exclude');
          excluded.add((call.arguments as Map)['path'] as String);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final db = newDb();
    addTearDown(db.close);

    // Fresh install: the attribute lands on the just-renamed file.
    await reconcileInstallFingerprint(db);
    expect(excluded, [idFile().path]);

    // The normal all-quiet launch re-applies it, healing installs whose
    // file predates the fix.
    excluded.clear();
    resetInstallFingerprintForTest();
    await reconcileInstallFingerprint(db);
    expect(excluded, [idFile().path]);
  });

  test('matching fingerprint: sync identity untouched', () async {
    final db = newDb();
    addTearDown(db.close);
    final settings = AppSettings(db);
    await connectSync(settings);

    await reconcileInstallFingerprint(db);
    resetInstallFingerprintForTest();
    await reconcileInstallFingerprint(db); // The normal every-launch run.

    expect(await settings.readSyncGdriveAccount(), 'reef@example.com');
    expect(await settings.readSyncGdriveFolderId(), 'folder-1');
    expect(await settings.readSyncGdriveLastPushedHash(), 'hash-1');
  });

  test('database fingerprint without file (OS restore onto fresh install) '
      'clears the sync identity and reseeds', () async {
    final db = newDb();
    addTearDown(db.close);
    final settings = AppSettings(db);
    // The restored database: the old device's fingerprint + sync identity,
    // while this install has no .install_id file (excluded from OS backup).
    await settings.setInstallFingerprint('old-device-fingerprint');
    await connectSync(settings);
    await expectEverySyncKeySet(db, fixture: 'connectSync');

    await reconcileInstallFingerprint(db);

    // Every `sync_gdrive_*` key, enumerated rather than named (#74): the
    // hand-written list missed the two U35 keys for a whole release, and a
    // hand-written assertion would have missed them with it. In particular
    // `sync_gdrive_last_pushed_name` — left behind, it makes the newest
    // cloud file look like *this* device's own upload on reconnect, so the
    // restore proposal is suppressed on the phone that just arrived.
    for (final key in SettingKey.gdriveSyncKeys) {
      expect(
        await db.getSetting(key.storageKey),
        isNull,
        reason: '${key.storageKey} survived the device transfer',
      );
    }
    // iCloud (U44): the lineage stamps are cleared like the Drive keys, but
    // the enabled flag deliberately SURVIVES — the identity behind iCloud
    // sync is the Apple ID, which an OS restore legitimately carries, and
    // silently turning backup off after a phone migration is the worse
    // failure. The cleared stamps self-heal via the U35 silent-adopt path.
    for (final key in SettingKey.icloudSyncKeys) {
      if (key == SettingKey.syncIcloudEnabled) continue;
      expect(
        await db.getSetting(key.storageKey),
        isNull,
        reason: '${key.storageKey} survived the device transfer',
      );
    }
    expect(
      await settings.readSyncIcloudEnabled(),
      isTrue,
      reason: 'the iCloud enabled flag must survive an OS restore (U44)',
    );
    // The device's own label is not part of the account relationship, so it
    // survives here exactly as it does across a disconnect.
    expect(await settings.readSyncDeviceName(), 'Old phone');
    // Reseeded with a fresh identity, consistent on both sides.
    final fileId = (await idFile().readAsString()).trim();
    expect(fileId, isNot('old-device-fingerprint'));
    expect(await settings.readInstallFingerprint(), fileId);
  });

  test('database fingerprint differing from the file adopts the file id '
      'and clears the sync identity', () async {
    final db = newDb();
    addTearDown(db.close);
    final settings = AppSettings(db);
    await idFile().writeAsString('this-device-id');
    await settings.setInstallFingerprint('old-device-fingerprint');
    await connectSync(settings);

    await reconcileInstallFingerprint(db);

    expect(await settings.readSyncGdriveAccount(), isNull);
    expect(await settings.readInstallFingerprint(), 'this-device-id');
    expect((await idFile().readAsString()).trim(), 'this-device-id');
  });

  test('no database fingerprint (upgrade from a pre-fingerprint version) '
      'seeds without clearing an existing connection', () async {
    final db = newDb();
    addTearDown(db.close);
    final settings = AppSettings(db);
    await connectSync(settings);

    await reconcileInstallFingerprint(db);

    // Indistinguishable from an OS restore of a pre-fingerprint database,
    // so it must never clear — only start fingerprinting from here on.
    expect(await settings.readSyncGdriveAccount(), 'reef@example.com');
    expect(await settings.readInstallFingerprint(), isNotNull);
  });

  test(
    'no database fingerprint but file present: adopts the file id',
    () async {
      final db = newDb();
      addTearDown(db.close);
      await idFile().writeAsString('this-device-id\n');

      await reconcileInstallFingerprint(db);

      expect(await AppSettings(db).readInstallFingerprint(), 'this-device-id');
    },
  );

  test('memoized per process: second call does not re-run the check', () async {
    final db = newDb();
    addTearDown(db.close);
    await reconcileInstallFingerprint(db);
    final seeded = await AppSettings(db).readInstallFingerprint();

    // Simulate the file changing under a running process; the memoized run
    // must not observe it (an OS restore cannot happen while the app runs).
    await idFile().writeAsString('changed-under-running-process');
    await reconcileInstallFingerprint(db);

    expect(await AppSettings(db).readInstallFingerprint(), seeded);
  });

  test('I/O failure propagates without touching the sync identity', () async {
    final db = newDb();
    addTearDown(db.close);
    final settings = AppSettings(db);
    await settings.setInstallFingerprint('old-device-fingerprint');
    await connectSync(settings);
    PathProviderPlatform.instance = _BrokenPathProvider();

    await expectLater(
      reconcileInstallFingerprint(db),
      throwsA(isA<Exception>()),
    );
    // Fail open: the caller logs and syncs as before; nothing was cleared.
    expect(await settings.readSyncGdriveAccount(), 'reef@example.com');

    // The failed run is not cached — a later call retries (and now detects
    // the missing file and clears).
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    await reconcileInstallFingerprint(db);
    expect(await settings.readSyncGdriveAccount(), isNull);
  });
}
