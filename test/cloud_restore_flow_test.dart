import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

/// One call to [CloudRestoreFlow.report] — the funnel `main.dart` wires to
/// `FlutterError.reportError`. Recorded rather than failed for the cases where
/// a report is the *expected* outcome (a local backup that could not be
/// written must be reported and then survived).
class _Report {
  _Report(this.error, this.library, this.context);
  final Object error;
  final String library;
  final String context;
  @override
  String toString() => '$library: $context: $error';
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
  /// `FlutterError.reportError`) — unless [reports] is supplied, in which case
  /// they are recorded instead, for the paths whose whole point is that they
  /// report a failure and carry on.
  CloudRestoreFlow flowWith({
    required Future<CloudRestoreChoice?> Function(CloudRestoreProposal) answer,
    required List<CloudRestoreProposal> prompts,
    required List<CloudRestoreNotice> notices,
    List<_Report>? reports,
  }) => CloudRestoreFlow(
    prompt: (proposal) {
      prompts.add(proposal);
      return answer(proposal);
    },
    notify: notices.add,
    report: (e, s, library, context) => reports == null
        ? fail('$library: $context: $e')
        : reports.add(_Report(e, library, context)),
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

    test('after "keep mine" the OTHER device gets a plain fast-forward '
        '(diverged == false) and the two converge — no ping-pong', () async {
      final store = FakeCloudBackupStore();

      // Device A: holds "Reef" and pushed it, so its lineage stamps match the
      // cloud exactly.
      final deviceA = AppDatabase(NativeDatabase.memory());
      addTearDown(deviceA.close);
      await AppSettings(deviceA).setSyncGdriveAccount('reef@test.dev');
      await AppSettings(deviceA).setSyncDeviceName('Phone A');
      await deviceA.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
      expect(
        await runCloudSyncIfDirty(deviceA, store: store, state: state(deviceA)),
        CloudSyncOutcome.pushed,
      );

      // Device B: same account, its own data, no sync lineage at all.
      final deviceB = AppDatabase(NativeDatabase.memory());
      addTearDown(deviceB.close);
      await AppSettings(deviceB).setSyncGdriveAccount('reef@test.dev');
      await AppSettings(deviceB).setSyncDeviceName('Phone B');
      await deviceB.createTankWithPreset(name: 'Nano', type: SetupType.mixed);

      // B is the diverged side: it has changes of its own, so the destructive
      // choice is the one worth offering — and it keeps them.
      final promptsB = <CloudRestoreProposal>[];
      final flowB = flowWith(
        answer: (_) async => CloudRestoreChoice.keepMine,
        prompts: promptsB,
        notices: [],
      );
      expect(
        await flowB.maybePropose(deviceB, store: store, state: state(deviceB)),
        isTrue,
      );
      await flowB.settled;
      expect(promptsB.single.diverged, isTrue);
      expect(promptsB.single.deviceName, 'Phone A');
      final pushedByB = await AppSettings(
        deviceB,
      ).readSyncGdriveLastPushedName();
      expect(pushedByB, isNotNull);

      // A now finds B's push. Nothing changed on A since its own last push, so
      // there is nothing of A's to keep: a plain fast-forward, NOT a conflict.
      final proposalA = await checkCloudNewerBackup(
        deviceA,
        store: store,
        state: state(deviceA),
      );
      expect(proposalA, isNotNull);
      expect(proposalA!.file.name, pushedByB);
      expect(proposalA.deviceName, 'Phone B');
      expect(
        proposalA.diverged,
        isFalse,
        reason: 'A holds no changes the cloud does not already have',
      );

      // Accepting the fast-forward converges the two devices…
      final noticesA = <CloudRestoreNotice>[];
      final flowA = flowWith(
        answer: (_) async => CloudRestoreChoice.restore,
        prompts: [],
        notices: noticesA,
      );
      expect(
        await flowA.maybePropose(deviceA, store: store, state: state(deviceA)),
        isTrue,
      );
      await flowA.settled;
      expect(noticesA, [isA<CloudRestoreRestored>()]);
      expect((await deviceA.getTanks()).map((t) => t.name), ['Nano']);
      expect((await deviceB.getTanks()).map((t) => t.name), ['Nano']);

      // …and settles there: A adopts B's file as its own synced state, so it
      // neither re-uploads the data it just downloaded nor re-proposes it, and
      // B still sees its own push as the newest.
      expect(
        await runCloudSyncIfDirty(deviceA, store: store, state: state(deviceA)),
        CloudSyncOutcome.skippedClean,
      );
      expect(
        await checkCloudNewerBackup(
          deviceA,
          store: store,
          state: state(deviceA),
        ),
        isNull,
      );
      expect(
        await checkCloudNewerBackup(
          deviceB,
          store: store,
          state: state(deviceB),
        ),
        isNull,
      );
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

    test('a FAILING local auto-backup still pushes to the cloud — the cloud '
        'copy matters most exactly when local storage misbehaves', () async {
      final store = FakeCloudBackupStore();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await AppSettings(db).setSyncGdriveAccount('reef@test.dev');
      await db.createTankWithPreset(name: 'Solo', type: SetupType.mixed);
      // Block the backups folder with a plain file, so every local write fails
      // the way a full or read-only disk would (same trick as
      // `auto_backup_test.dart`).
      final blocker = File(p.join(docsDir.path, 'backups'));
      await blocker.writeAsString('not a directory');

      final reports = <_Report>[];
      final flow = flowWith(
        answer: (_) async => fail('empty cloud must not propose'),
        prompts: [],
        notices: [],
        reports: reports,
      );

      await runLaunchBackupAndSync(
        db,
        store: store,
        state: state(db),
        flow: flow,
      );

      // The failure is reported (the user's local safety net is broken)…
      expect(reports.map((r) => r.library), ['auto_backup']);
      expect(reports.single.error, isA<FileSystemException>());
      expect(await db.getSetting(kLastBackupErrorAtKey), isNotNull);
      // …and it is NOT allowed to suppress the push.
      expect(
        store.writeCalls,
        1,
        reason: 'a broken local disk must not also cost the cloud copy',
      );
      expect(await AppSettings(db).readSyncGdriveLastPushedName(), isNotNull);
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
