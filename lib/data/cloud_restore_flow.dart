/// The launch cloud-restore proposal flow (U35) and the launch backup+sync
/// sequence it is embedded in — extracted from `main.dart` (T17) so the only
/// launch-time logic that can replace the whole database is pinned by tests.
/// `main.dart` keeps just the Flutter glue: the dialog, the SnackBar and the
/// `FlutterError.reportError` funnel, injected here as plain callbacks.
library;

import 'dart:async';

import 'package:reeftracker/data/auto_backup.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/install_id.dart';

/// The user's answer to the launch restore proposal.
///
/// The dialog helper maps a barrier dismiss to [notNow] before it gets here —
/// a `null` from [CloudRestoreFlow.prompt] means the dialog could not be
/// shown at all (no navigator yet), which must record nothing so the next
/// launch proposes again.
enum CloudRestoreChoice { notNow, keepMine, restore }

/// What the flow wants the user to know once a restore attempt settled.
/// Deliberately a value, not a SnackBar: the mapping to localized text stays
/// in `main.dart`, the decision of *which* message is pinned here.
sealed class CloudRestoreNotice {
  const CloudRestoreNotice();
}

/// The cloud data replaced the local set.
class CloudRestoreRestored extends CloudRestoreNotice {
  const CloudRestoreRestored();
}

/// The cloud file failed validation; [reason] feeds `l.backupRejection`.
class CloudRestoreRejected extends CloudRestoreNotice {
  const CloudRestoreRejected(this.reason);
  final BackupRejection reason;
}

/// Download or import failed (offline, revoked grant, filesystem).
class CloudRestoreFailed extends CloudRestoreNotice {
  const CloudRestoreFailed();
}

/// Owns the once-per-process launch pull-check and the handling of the
/// user's choice. One instance lives for the whole app process — the latch
/// is the instance's state, so resumes never re-list the cloud folder or pop
/// a dialog mid-use (U35 is deliberately a launch-only check).
class CloudRestoreFlow {
  CloudRestoreFlow({
    required this.prompt,
    required this.notify,
    required this.report,
  });

  /// Shows the proposal dialog and resolves with the choice. Returning `null`
  /// means the dialog was never shown; a shown dialog always resolves to a
  /// concrete [CloudRestoreChoice] (barrier dismiss arrives as [CloudRestoreChoice.notNow]).
  final Future<CloudRestoreChoice?> Function(CloudRestoreProposal proposal)
  prompt;

  /// Surfaces the outcome of a restore attempt to the user.
  final void Function(CloudRestoreNotice notice) notify;

  /// The caller's error funnel (`FlutterError.reportError` in production).
  final void Function(
    Object error,
    StackTrace stack,
    String library,
    String context,
  )
  report;

  bool _checked = false;
  Future<void>? _pending;

  /// Completes when a fired proposal's dialog + choice handling has settled.
  /// Never throws (errors are already funneled to [report]). Primarily a
  /// test hook — production fire-and-forgets via [maybePropose].
  Future<void> get settled => _pending ?? Future<void>.value();

  /// Runs the U35 pull-check once per process. Returns whether a restore
  /// proposal was surfaced (the dialog itself is fire-and-forget).
  Future<bool> maybePropose(
    AppDatabase db, {
    required CloudBackupStore store,
    required CloudSyncState state,
  }) async {
    if (_checked) return false;
    _checked = true;
    final proposal = await checkCloudNewerBackup(
      db,
      store: store,
      state: state,
    );
    if (proposal == null) return false;
    _pending = _propose(db, store: store, state: state, proposal: proposal)
        .catchError((Object e, StackTrace s) {
          report(e, s, 'cloud_sync', 'proposing a cloud backup restore');
        });
    unawaited(_pending);
    return true;
  }

  Future<void> _propose(
    AppDatabase db, {
    required CloudBackupStore store,
    required CloudSyncState state,
    required CloudRestoreProposal proposal,
  }) async {
    final choice = await prompt(proposal);
    switch (choice) {
      // Dialog never shown (no navigator context): record nothing, so the
      // next launch proposes again.
      case null:
        return;
      // "Not now" (incl. barrier dismiss, mapped by the dialog helper):
      // quiet until a newer file shows.
      case CloudRestoreChoice.notNow:
        await dismissCloudRestore(state, proposal.file.name);
      case CloudRestoreChoice.keepMine:
        // The user chose this device's data: push it now so it becomes the
        // newest cloud state (the other device gets the mirror proposal).
        // Never destructive — the declined file stays in the cloud rotation.
        await dismissCloudRestore(state, proposal.file.name);
        await runCloudSyncIfDirty(db, store: store, state: state);
      case CloudRestoreChoice.restore:
        try {
          await restoreCloudBackup(
            db,
            store: store,
            state: state,
            file: proposal.file,
            contents: proposal.contents,
          );
          notify(const CloudRestoreRestored());
        } on InvalidBackupException catch (e) {
          notify(CloudRestoreRejected(e.reason));
        } catch (_) {
          // Download failed (offline, revoked grant) or the import itself.
          notify(const CloudRestoreFailed());
        }
    }
  }
}

/// The launch/resume backup + cloud-sync sequence (previously
/// `_backupAndSync` in `main.dart`): reconcile the install fingerprint
/// (#62, fail open), run the U35 pull-check, run the scheduled local backup,
/// then push to the cloud — but **never while a restore proposal is on
/// screen**: uploading would race the user's decision (and bury the newer
/// file the dialog is about). Declining just delays the push to the next
/// launch/resume.
Future<void> runLaunchBackupAndSync(
  AppDatabase db, {
  required CloudBackupStore store,
  required CloudSyncState state,
  required CloudRestoreFlow flow,
}) async {
  try {
    await reconcileInstallFingerprint(db);
  } catch (e, s) {
    flow.report(e, s, 'install_id', 'reconciling the install fingerprint');
  }
  var proposalShown = false;
  try {
    proposalShown = await flow.maybePropose(db, store: store, state: state);
  } catch (e, s) {
    flow.report(e, s, 'cloud_sync', 'checking the cloud for a newer backup');
  }
  var wrote = false;
  try {
    wrote = await runAutoBackupIfDue(db);
  } catch (e, s) {
    flow.report(e, s, 'auto_backup', 'running the automatic backup');
    // A failed local backup must not suppress the cloud push — the Drive
    // copy matters most exactly when local storage misbehaves.
    wrote = true;
  }
  if (wrote && !proposalShown) {
    await runCloudSyncIfDirty(db, store: store, state: state);
  }
}
