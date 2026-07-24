import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/provider_errors.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/auto_backup.dart';
import 'data/backup.dart' show InvalidBackupException;
import 'data/cloud_sync.dart';
import 'data/database.dart';
import 'data/install_id.dart';
import 'data/reminder_scheduler.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_helpers.dart';
import 'widgets/reef_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    observers: [ProviderErrorObserver(showError: _warnDataLoadFailed)],
  );
  // Pre-warm the settings map — which carries the stored locale override —
  // before the first frame (#24): without this the app renders its first
  // frame(s) in the system language and then snaps to the chosen one. Also
  // front-loads the database open/migration.
  // The wait MUST be bounded: on some devices a platform-channel call made
  // before the first frame never answers (flutter/flutter#72872), which froze
  // startup on the splash screen forever. On timeout (or failure) the app
  // starts in the system locale and the database open recovers post-frame
  // (see `_documentsDir` in database.dart); the observer above already
  // surfaces database errors to the user.
  try {
    await container
        .read(settingsMapProvider.future)
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ReefTrackerApp(),
    ),
  );
}

/// Attached to [MaterialApp.router] so provider failures can be surfaced from
/// outside the widget tree (see [ProviderErrorObserver]).
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows the localized "data failed to load" SnackBar (#21). A failure can
/// fire before the first frame (e.g. the database failing to open during the
/// initial build), when no ScaffoldMessenger exists yet — in that case retry
/// once after the frame instead of dropping the warning.
void _warnDataLoadFailed() {
  void show() {
    final messenger = _messengerKey.currentState;
    final context = _messengerKey.currentContext;
    if (messenger == null || context == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).dataLoadFailed),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  if (_messengerKey.currentState != null) {
    show();
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }
}

/// The user's decision on a launch cloud-restore proposal (U35).
enum _CloudRestoreChoice { notNow, keepMine, restore }

class ReefTrackerApp extends ConsumerStatefulWidget {
  const ReefTrackerApp({super.key});

  @override
  ConsumerState<ReefTrackerApp> createState() => _ReefTrackerAppState();
}

class _ReefTrackerAppState extends ConsumerState<ReefTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Opportunistic housekeeping + backup: run once at launch, after the
    // first frame so they never block startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedEdition();
      _purgeDeletedTanks();
      _maybeBackUp();
      _initReminders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeBackUp();
      // Re-plan reminders on every resume: the 14-day scheduling horizon is
      // only refreshed while the app runs, and a resume is also when a DST
      // shift or a long background stretch would have drifted the schedule.
      unawaited(
        ref.read(reminderSchedulerProvider).resync().catchError((_) {}),
      );
    }
  }

  /// One-time reminder wiring (U1/U2/U12), deliberately after the first frame:
  /// the notification plugin's init is a platform-channel call, and those can
  /// hang forever before the first frame (flutter/flutter#72872 — see the
  /// pre-warm note in [main]). Initializes the plugin with the tap handler,
  /// starts the write-triggered scheduler, plans the initial set, and replays
  /// the payload of a notification that cold-started the app.
  void _initReminders() {
    Future<void> run() async {
      final notifications = ref.read(reminderNotificationsProvider);
      final db = ref.read(dbProvider);
      await notifications.init(
        onTap: (payload) =>
            unawaited(handleReminderPayload(db, payload, appRouter.go)),
      );
      final scheduler = ref.read(reminderSchedulerProvider)..start();
      await scheduler.resync();
      final launch = await notifications.launchPayload();
      if (launch != null) {
        await handleReminderPayload(db, launch, appRouter.go);
      }
    }

    unawaited(
      run().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'reminders',
            context: ErrorSummary('initializing reminder notifications'),
          ),
        );
      }),
    );
  }

  /// Seeds the early-adopter marker (U19 phase 0): every launch of a pre-Pro
  /// build stamps `legacy_free_since` with the current app version unless it
  /// is already set — these installs keep today's features free forever once
  /// the paid tier ships. The Pro build must remove this call (it only reads
  /// the marker). After the first frame because [PackageInfo.fromPlatform] is
  /// a platform-channel call (see the pre-warm note in [main]).
  void _seedEdition() {
    Future<void> run() async {
      final info = await PackageInfo.fromPlatform();
      await ref.read(settingsProvider).seedLegacyFreeSince(info.version);
    }

    unawaited(
      run().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'edition',
            context: ErrorSummary('seeding the early-adopter marker'),
          ),
        );
      }),
    );
  }

  /// Finalizes tanks soft-deleted in a previous session (U10). Normally a
  /// delete is finalized when its undo SnackBar closes; a process kill during
  /// that window leaves the row stamped — invisible everywhere, so
  /// effectively deleted — and this sweep collects it. Fire-and-forget: the
  /// backup encode already excludes soft-deleted tanks, so ordering against
  /// [_maybeBackUp] doesn't matter.
  void _purgeDeletedTanks() {
    unawaited(
      ref.read(dbProvider).purgeDeletedTanks().catchError((
        Object e,
        StackTrace s,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'tanks',
            context: ErrorSummary('purging soft-deleted tanks'),
          ),
        );
      }),
    );
  }

  /// Fire-and-forget automatic backup; failures must never disrupt the app.
  /// The backup layer persists a failure as `last_backup_error_at` (surfaced
  /// in Settings), so here it only needs to be logged, not swallowed silently.
  /// The Drive push (U24) is coupled to local backup *events*: it runs only
  /// when the scheduled local backup actually wrote (or attempted and failed
  /// — see below), strictly after it settles, so Drive uploads follow the
  /// daily/weekly cadence instead of firing on every launch/resume with
  /// changed data. (The other backup events — manual Back-up-now and the
  /// initial connect — chain their own push in `settings_screen.dart`.) Push
  /// failures are persisted by the engine (`sync_gdrive_last_error_at`), so
  /// they too are only logged here.
  ///
  /// Before anything cloud-related, the install fingerprint is reconciled
  /// (#62): if the database arrived via Android OS restore/device transfer,
  /// the previous device's Drive sync identity is cleared so Settings can't
  /// claim a connected state no live sign-in backs. Once per process
  /// (memoized inside); on failure the sync still runs — a broken filesystem
  /// must not disconnect a working sync (fail open).
  ///
  /// Between the reconcile and the push sits the U35 pull-check (launch only,
  /// not on resume): if another device left a newer backup in the cloud, the
  /// user is offered a restore *before* this device pushes anything — a
  /// stale-but-dirty device that pushed first would bury the newer file.
  void _maybeBackUp() {
    unawaited(
      _backupAndSync().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'cloud_sync',
            context: ErrorSummary('running the Drive backup sync'),
          ),
        );
      }),
    );
  }

  Future<void> _backupAndSync() async {
    final db = ref.read(dbProvider);
    try {
      await reconcileInstallFingerprint(db);
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'install_id',
          context: ErrorSummary('reconciling the install fingerprint'),
        ),
      );
    }
    var proposalShown = false;
    try {
      proposalShown = await _maybeProposeCloudRestore(db);
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'cloud_sync',
          context: ErrorSummary('checking the cloud for a newer backup'),
        ),
      );
    }
    var wrote = false;
    try {
      wrote = await runAutoBackupIfDue(db);
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'auto_backup',
          context: ErrorSummary('running the automatic backup'),
        ),
      );
      // A failed local backup must not suppress the cloud push — the Drive
      // copy matters most exactly when local storage misbehaves.
      wrote = true;
    }
    // While a restore proposal is on screen the push stays parked: uploading
    // would race the user's decision (and bury the newer file the dialog is
    // about). Declining just delays the push to the next launch/resume.
    if (wrote && !proposalShown) {
      await runGDriveSyncIfDirty(db, store: ref.read(cloudBackupStoreProvider));
    }
  }

  /// Set once the launch pull-check ran: resumes must not re-list the cloud
  /// folder or pop a dialog mid-use — U35 is deliberately a launch-only check.
  bool _cloudRestoreChecked = false;

  /// Runs the U35 pull-check once per process. Returns whether a restore
  /// proposal was surfaced (the dialog itself is fire-and-forget).
  Future<bool> _maybeProposeCloudRestore(AppDatabase db) async {
    if (_cloudRestoreChecked) return false;
    _cloudRestoreChecked = true;
    final proposal = await checkCloudNewerBackup(
      db,
      store: ref.read(cloudBackupStoreProvider),
    );
    if (proposal == null) return false;
    unawaited(
      _showCloudRestoreDialog(db, proposal).catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'cloud_sync',
            context: ErrorSummary('proposing a cloud backup restore'),
          ),
        );
      }),
    );
    return true;
  }

  Future<void> _showCloudRestoreDialog(
    AppDatabase db,
    CloudRestoreProposal proposal,
  ) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final choice = await showDialog<_CloudRestoreChoice>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        final device = proposal.deviceName ?? l.syncRestoreUnknownDevice;
        final when = switch (proposal.file.modifiedAt) {
          final at? => formatDateTime(ctx, at.toLocal(), weekday: false),
          // Drive always reports modifiedTime; the raw name is the fallback
          // for a store that somehow didn't.
          null => proposal.file.name,
        };
        return AlertDialog(
          icon: const Icon(Icons.cloud_download_outlined),
          title: Text(l.syncRestoreTitle),
          content: Text(
            proposal.diverged
                ? l.syncRestoreDivergedBody(device, when)
                : l.syncRestoreBody(device, when),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _CloudRestoreChoice.notNow),
              child: Text(l.syncRestoreNotNow),
            ),
            if (proposal.diverged)
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _CloudRestoreChoice.keepMine),
                child: Text(l.syncRestoreKeepMine),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _CloudRestoreChoice.restore),
              child: Text(AppLocalizations.of(ctx).restore),
            ),
          ],
        );
      },
    );
    switch (choice) {
      // Barrier dismiss counts as "not now": quiet until a newer file shows.
      case null || _CloudRestoreChoice.notNow:
        await dismissCloudRestore(db, proposal.file.name);
      case _CloudRestoreChoice.keepMine:
        // The user chose this device's data: push it now so it becomes the
        // newest cloud state (the other device gets the mirror proposal).
        // Never destructive — the declined file stays in the cloud rotation.
        await dismissCloudRestore(db, proposal.file.name);
        await runGDriveSyncIfDirty(
          db,
          store: ref.read(cloudBackupStoreProvider),
        );
      case _CloudRestoreChoice.restore:
        try {
          await restoreCloudBackup(
            db,
            store: ref.read(cloudBackupStoreProvider),
            file: proposal.file,
            contents: proposal.contents,
          );
          _restoreSnack((l) => l.backupRestored);
        } on InvalidBackupException catch (e) {
          _restoreSnack((l) => l.backupRejection(e.reason));
        } catch (_) {
          // Download failed (offline, revoked grant) or the import itself.
          _restoreSnack((l) => l.backupImportFailed);
        }
    }
  }

  /// Localized SnackBar for the launch-restore outcome, tolerant of the app
  /// shutting down while the restore ran.
  void _restoreSnack(String Function(AppLocalizations l) message) {
    final messenger = _messengerKey.currentState;
    final context = _messengerKey.currentContext;
    if (messenger == null || context == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(message(AppLocalizations.of(context)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    // The stored theme choice (REDESIGN #16) maps onto Flutter's ThemeMode
    // here — the setting enum is Flutter-free by design.
    final themeMode = switch (ref.watch(themeModeProvider).value ??
        AppThemeMode.system) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Keep intl date/number formatting in sync with the resolved app locale
      // so DateFormat(...) renders dates in the selected language. The
      // ReefBackground gradient sits here, behind the Navigator, so every
      // screen (scaffolds are transparent) shares one background.
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return ReefBackground(child: child ?? const SizedBox.shrink());
      },
      theme: buildReefTheme(Brightness.light, defaultTargetPlatform),
      darkTheme: buildReefTheme(Brightness.dark, defaultTargetPlatform),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
