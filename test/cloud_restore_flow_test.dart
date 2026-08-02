import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/cloud_restore_flow.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

import 'fakes/fake_cloud_backup_store.dart';

/// Routes path_provider to a throwaway temp folder — the restore path writes
/// a local safety backup and the launch sequence runs the local auto-backup.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// [FakeCloudBackupStore] whose [read] can be scripted to fail — the
/// offline-mid-restore case ([CloudRestoreFailed]).
class _ReadFailingStore extends FakeCloudBackupStore {
  bool failReads = false;
  @override
  Future<List<int>> read(String fileId) {
    if (failReads) throw const SocketException('offline mid-download');
    return super.read(fileId);
  }
}

/// T17: the launch cloud-restore proposal flow — the only launch-time logic
/// that replaces the whole database. Pins the choice switch (notNow /
/// keepMine / restore and their exact side effects), the never-shown case,
/// the once-per-process latch, and the push-parked-while-proposal-shown
/// ordering of [runLaunchBackupAndSync].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;
  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-restoreflow-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  GDriveSyncState state(AppDatabase db) => GDriveSyncState(AppSettings(db));

  /// A recording harness around [CloudRestoreFlow]: [answer] scripts the
  /// dialog, [prompts] and [notices] record what the flow did, and errors
  /// funneled to [report] fail the test (production sends them to
  /// `FlutterError.reportError`).
  CloudRestoreFlow flowWith({
    required Future<CloudRestoreChoice?> Function(CloudRestoreProposal) answer,
    required List<CloudRestoreProposal> prompts,
    required List<CloudRestoreNotice> notices,
  }) => CloudRestoreFlow(
    prompt: (proposal) {
      prompts.add(proposal);
      return answer(proposal);
    },
    notify: notices.add,
    report: (e, s, library, context) => fail('$library: $context: $e'),
  );

  /// Device A pushed a backup ("Reef" tank) into [store]; the returned
  /// reader db is device B, connected to the same account.
  Future<AppDatabase> seedCloud(FakeCloudBackupStore store) async {
    final writer = AppDatabase(NativeDatabase.memory());
    addTearDown(writer.close);
    await AppSettings(writer).setSyncGdriveAccount('reef@test.dev');
    await AppSettings(writer).setSyncDeviceName('Writer phone');
    await writer.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    expect(
      await runCloudSyncIfDirty(writer, store: store, state: state(writer)),
      CloudSyncOutcome.pushed,
    );
    final reader = AppDatabase(NativeDatabase.memory());
    addTearDown(reader.close);
    await AppSettings(reader).setSyncGdriveAccount('reef@test.dev');
    return reader;
  }

  group('CloudRestoreFlow.maybePropose', () {
    test(
      'nothing newer in the cloud: returns false, prompts nothing',
      () async {
        final store = FakeCloudBackupStore();
        final prompts = <CloudRestoreProposal>[];
        final notices = <CloudRestoreNotice>[];
        final flow = flowWith(
          answer: (_) async => fail('must not prompt'),
          prompts: prompts,
          notices: notices,
        );
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await AppSettings(db).setSyncGdriveAccount('reef@test.dev');

        expect(
          await flow.maybePropose(db, store: store, state: state(db)),
          isFalse,
        );
        expect(prompts, isEmpty);
        expect(notices, isEmpty);
      },
    );

    test('once-per-process latch: the second call returns false without '
        're-listing or re-prompting, even while the first dialog is still '
        'open', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      final prompts = <CloudRestoreProposal>[];
      final notices = <CloudRestoreNotice>[];
      final answer = Completer<CloudRestoreChoice?>();
      final flow = flowWith(
        answer: (_) => answer.future,
        prompts: prompts,
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      expect(prompts, hasLength(1));

      // A resume while the dialog is open (or any later call): no new check.
      store.listError = StateError('latch failed: cloud re-listed');
      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isFalse,
      );
      expect(prompts, hasLength(1));

      answer.complete(CloudRestoreChoice.notNow);
      await flow.settled;
    });

    test('"not now" (incl. barrier dismiss, mapped by the dialog helper): '
        'dismissal recorded, nothing restored, nothing pushed', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
      final writesBefore = store.writeCalls;
      final prompts = <CloudRestoreProposal>[];
      final notices = <CloudRestoreNotice>[];
      final flow = flowWith(
        answer: (_) async => CloudRestoreChoice.notNow,
        prompts: prompts,
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      await flow.settled;

      expect(
        await AppSettings(reader).readSyncGdriveDismissedName(),
        prompts.single.file.name,
      );
      expect((await reader.getTanks()).map((t) => t.name), ['Nano']);
      expect(store.writeCalls, writesBefore);
      expect(notices, isEmpty);

      // And the dismissal holds: a fresh flow (next launch) stays quiet for
      // the same file.
      final flow2 = flowWith(
        answer: (_) async => fail('dismissed file must not re-propose'),
        prompts: [],
        notices: [],
      );
      expect(
        await flow2.maybePropose(reader, store: store, state: state(reader)),
        isFalse,
      );
    });

    test('dialog never shown (prompt resolves null): NOTHING recorded — the '
        'next launch proposes again', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      final prompts = <CloudRestoreProposal>[];
      final notices = <CloudRestoreNotice>[];
      final flow = flowWith(
        answer: (_) async => null,
        prompts: prompts,
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      await flow.settled;

      expect(await AppSettings(reader).readSyncGdriveDismissedName(), isNull);
      // Next launch (fresh flow, fresh latch): the same file is proposed.
      final prompts2 = <CloudRestoreProposal>[];
      final flow2 = flowWith(
        answer: (_) async => CloudRestoreChoice.notNow,
        prompts: prompts2,
        notices: [],
      );
      expect(
        await flow2.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      expect(prompts2, hasLength(1));
      await flow2.settled;
    });

    test('keepMine: dismissal recorded AND this device\'s data pushed as the '
        'newest cloud state; the declined file survives', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
      final prompts = <CloudRestoreProposal>[];
      final notices = <CloudRestoreNotice>[];
      final flow = flowWith(
        answer: (_) async => CloudRestoreChoice.keepMine,
        prompts: prompts,
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      await flow.settled;

      // Local data untouched…
      expect((await reader.getTanks()).map((t) => t.name), ['Nano']);
      // …the declined file is still in the cloud (never destructive)…
      expect(store.files.keys, contains(prompts.single.file.name));
      // …and this device's own push arrived beside it, recorded as its
      // synced state.
      expect(store.files.length, 2);
      final pushedName = await AppSettings(
        reader,
      ).readSyncGdriveLastPushedName();
      expect(pushedName, isNotNull);
      final pushed = decodeBackup(utf8.decode(store.files[pushedName]!));
      expect(pushed.tanks.single.name.value, 'Nano');
      expect(notices, isEmpty);
    });

    test(
      'restore: cloud data replaces the local set, restored notice',
      () async {
        final store = FakeCloudBackupStore();
        final reader = await seedCloud(store);
        await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
        final notices = <CloudRestoreNotice>[];
        final flow = flowWith(
          answer: (_) async => CloudRestoreChoice.restore,
          prompts: [],
          notices: notices,
        );

        expect(
          await flow.maybePropose(reader, store: store, state: state(reader)),
          isTrue,
        );
        await flow.settled;

        expect((await reader.getTanks()).map((t) => t.name), ['Reef']);
        expect(notices, [isA<CloudRestoreRestored>()]);
      },
    );

    test('restore of an invalid file: rejected notice with the reason, local '
        'data survives', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      // Overwrite the cloud file with garbage, keeping its metadata — the
      // pull-check trusts the advisory hash and never downloads, so the
      // proposal is made and only the restore's decode discovers the rot.
      final name = store.files.keys.single;
      store.files[name] = utf8.encode('not a backup at all');
      final notices = <CloudRestoreNotice>[];
      final flow = flowWith(
        answer: (_) async => CloudRestoreChoice.restore,
        prompts: [],
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      await flow.settled;

      expect(notices, hasLength(1));
      expect(
        (notices.single as CloudRestoreRejected).reason,
        BackupRejection.notBackupFile,
      );
      expect(await reader.getTanks(), isEmpty);
    });

    test('restore when the download fails: failed notice, local data '
        'survives', () async {
      final store = _ReadFailingStore();
      final reader = await seedCloud(store);
      store.failReads = true; // goes offline after the pull-check listed
      final notices = <CloudRestoreNotice>[];
      final flow = flowWith(
        answer: (_) async => CloudRestoreChoice.restore,
        prompts: [],
        notices: notices,
      );

      expect(
        await flow.maybePropose(reader, store: store, state: state(reader)),
        isTrue,
      );
      await flow.settled;

      expect(notices, [isA<CloudRestoreFailed>()]);
      expect(await reader.getTanks(), isEmpty);
    });
  });

  group('runLaunchBackupAndSync', () {
    test('no proposal: local backup runs and the push follows', () async {
      final store = FakeCloudBackupStore();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await AppSettings(db).setSyncGdriveAccount('reef@test.dev');
      await db.createTankWithPreset(name: 'Solo', type: SetupType.mixed);
      final flow = flowWith(
        answer: (_) async => fail('empty cloud must not propose'),
        prompts: [],
        notices: [],
      );

      await runLaunchBackupAndSync(
        db,
        store: store,
        state: state(db),
        flow: flow,
      );

      expect(store.writeCalls, 1);
    });

    test('push stays PARKED while the proposal dialog is open; declining '
        'delays it to the next launch', () async {
      final store = FakeCloudBackupStore();
      final reader = await seedCloud(store);
      await reader.createTankWithPreset(name: 'Nano', type: SetupType.mixed);
      final writesBefore = store.writeCalls;
      final answer = Completer<CloudRestoreChoice?>();
      final flow = flowWith(
        answer: (_) => answer.future,
        prompts: [],
        notices: [],
      );

      await runLaunchBackupAndSync(
        reader,
        store: store,
        state: state(reader),
        flow: flow,
      );

      // The local auto-backup ran (there is data and no last-backup stamp) —
      // but with the dialog still open, NO push happened: uploading would
      // race the user's decision and bury the file the dialog is about.
      expect(store.writeCalls, writesBefore);

      answer.complete(CloudRestoreChoice.notNow);
      await flow.settled;
      // Declining doesn't push either — the push waits for the next
      // launch/resume (where no proposal shows and the sync runs dirty).
      expect(store.writeCalls, writesBefore);
      // Next launch: make the local backup due again (the push is coupled to
      // local backup events), same flow instance so the latch holds.
      await AppSettings(reader).setLastBackupAt(DateTime(2020));
      await runLaunchBackupAndSync(
        reader,
        store: store,
        state: state(reader),
        flow: flow,
      );
      expect(store.writeCalls, writesBefore + 1);
    });
  });
}
