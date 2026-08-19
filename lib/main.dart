import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/app_builder.dart';
import 'app/cloud_restore_dialog.dart';
import 'app/provider_errors.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/app_update.dart';
import 'data/cloud_restore_flow.dart';
import 'data/diagnostics_log.dart';
import 'data/entitlement.dart';
import 'data/reminder_scheduler.dart';
import 'domain/pro_features.dart';
import 'features/settings/pro_test_rig.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_helpers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    observers: [ProviderErrorObserver(showError: _warnDataLoadFailed)],
    overrides: [
      // The only place a purchase store other than [NoPurchaseStore] is ever
      // installed, and only in a `REEF_PRO_TEST` build (P0-6). Phase 1 adds
      // the plugin-backed store here on the same line.
      if (kProTestRig)
        purchaseStoreProvider.overrideWithValue(proTestPurchaseStore),
      // The U48 emulator rig: a store that always offers an update, so the
      // notice SnackBar can be seen on a sideloaded build (a real Play check
      // refuses those). Never in a store build — same rule as REEF_PRO_TEST.
      if (kUpdateTestRig)
        appUpdateCheckerProvider.overrideWithValue(FakeStoreUpdateChecker()),
    ],
  );
  // Route every FlutterError.reportError (the observer above included) and
  // every unhandled async error into the on-device diagnostics log (#107),
  // shared from Settings → About. Before the settings pre-warm below so even
  // a failing database open on a broken device leaves a trace.
  installDiagnosticsHooks(container.read(diagnosticsLogProvider));
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
    final settingsMap = await container
        .read(settingsMapProvider.future)
        .timeout(const Duration(seconds: 3));
    // Wall-display auto-start (U49 §12f): arm the router's cold-start-only
    // redirect so a rebooted wall tablet lands straight back in the mode.
    // The stored flag is read before entitlement I/O: the `/wall` capability
    // boundary prevents constructing the resource-owning screen while locked,
    // and post-restore reconciliation clears a stale flag. Verifying
    // the purchase here would need
    // the entitlement store's pre-first-frame platform-channel read, exactly
    // the call class that hangs before the first frame on some devices
    // (flutter/flutter#72872, the pre-warm note above).
    wallAutoStartRequested = AppSettings.decodeWallAutoStart(
      settingsMap[SettingKey.wallAutoStart.storageKey],
    );
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

class ReefTrackerApp extends ConsumerStatefulWidget {
  const ReefTrackerApp({super.key});

  @override
  ConsumerState<ReefTrackerApp> createState() => _ReefTrackerAppState();
}

class _ReefTrackerAppState extends ConsumerState<ReefTrackerApp>
    with WidgetsBindingObserver {
  /// Periodic housekeeping for a process that never backgrounds (#118): the
  /// auto-backup check and the reminder resync used to hang exclusively off
  /// `AppLifecycleState.resumed`, but a wall tablet (U49) never resumes — so
  /// backups would run exactly once and the 14-day reminder horizon would
  /// silently run out after two weeks of uptime. The tick runs the same
  /// maintenance the resume path does; both are cheap no-ops when nothing is
  /// due. Six-hourly bounds the drift well under the daily backup cadence.
  Timer? _housekeeping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchCapabilityRevocation();
    // Opportunistic housekeeping + backup: run once at launch, after the
    // first frame so they never block startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedEdition();
      _initEntitlement();
      _purgeDeletedTanks();
      _maybeBackUp();
      _initReminders();
      _autoStartWallFallback();
      _checkAppUpdate();
    });
    _housekeeping = Timer.periodic(const Duration(hours: 6), (_) {
      _maybeBackUp();
      unawaited(
        ref.read(reminderSchedulerProvider).resync().catchError((_) {}),
      );
    });
  }

  @override
  void dispose() {
    _housekeeping?.cancel();
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
        // Fires long after run()'s own catchError has settled, so it needs
        // its own handler (#99) — a bad payload must not become an unhandled
        // async error.
        onTap: (payload) => unawaited(
          handleReminderPayload(db, payload, appRouter.go).catchError((
            Object e,
            StackTrace s,
          ) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: e,
                stack: s,
                library: 'reminders',
                context: ErrorSummary('handling a notification tap'),
              ),
            );
          }),
        ),
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

  /// Seeds the early-adopter marker (U19): every launch of a pre-activation
  /// build stamps `legacy_free_since` with the current app version unless it
  /// is already set — these installs keep today's features free forever once
  /// the paid tier ships. After the first frame because
  /// [PackageInfo.fromPlatform] is a platform-channel call (see the pre-warm
  /// note in [main]).
  ///
  /// **This method is not deleted at activation** — it stops by itself, via
  /// [shouldSeedFounderMarker], the moment `kActivationVersion` is set. That
  /// keeps the activation edit to a single constant and makes the dangerous
  /// half-state (sale live, seeder still minting Founders) unrepresentable.
  void _seedEdition() {
    Future<void> run() async {
      if (!shouldSeedFounderMarker(activationVersion: kActivationVersion)) {
        return;
      }
      final settings = ref.read(settingsProvider);
      // The rig's seeder-off switch (P0-6), so Standard and Pro can be reached
      // on a device. Guarded by the compile-time constant, so a build without
      // the define never even reads the key — production behaviour is
      // bit-identical to before.
      if (kProTestRig && await settings.readProSeederOff()) return;
      final info = await PackageInfo.fromPlatform();
      await settings.seedLegacyFreeSince(info.version);
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

  /// Brings up the Pro purchase listener and reconciles the cached unlock
  /// (U19).
  ///
  /// The listener must be up at launch, not only when the paywall opens: the
  /// app can be killed between paying and acknowledging, and both stores
  /// re-deliver that transaction on the next start — iOS indefinitely, while
  /// refusing a re-purchase of the same product until it is finished.
  ///
  /// **Inert in every build shipped so far.** The only store compiled in is
  /// `NoPurchaseStore`: the stream is empty and `restoreAtStartup` returns
  /// immediately because the store reports itself unavailable, which is also
  /// the rule that stops a store that *cannot be asked* from clearing a real
  /// unlock. Phase 1 changes the store, not this call.
  void _initEntitlement() {
    final service = ref.read(proEntitlementServiceProvider);
    service.start();
    Future<void> run() async {
      // Rig only: a real store account remembers what it sold across
      // restarts, so the fake has to be told before the reconciliation below
      // asks it (see seedProTestStoreFromDisk).
      if (kProTestRig) {
        await seedProTestStoreFromDisk(ref.read(proEntitlementStoreProvider));
      }
      await service.restoreAtStartup();
      await _reconcileRevokedCapabilities();
    }

    unawaited(
      run().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'entitlement',
            context: ErrorSummary('reconciling the Pro unlock at startup'),
          ),
        );
      }),
    );
  }

  /// Applies the small amount of persistent cleanup required when a live
  /// entitlement disappears. User-owned data and cloud connections stay in
  /// place for recovery/export; only an automation that would launch a paid
  /// resource without an explicit action is disarmed.
  void _watchCapabilityRevocation() {
    ref.listenManual(entitlementProvider, (previous, next) {
      if (!lostProCapability(
        previous,
        next,
        ProCapabilityBoundary.wallDisplayAutoStart,
      )) {
        return;
      }
      _disarmWallAutoStart();
    });
  }

  void _disarmWallAutoStart() {
    unawaited(
      ref.read(settingsProvider).setWallAutoStart(false).catchError((
        Object e,
        StackTrace s,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'entitlement',
            context: ErrorSummary(
              'disarming Wall auto-start after entitlement loss',
            ),
          ),
        );
      }),
    );
  }

  /// Startup has no trustworthy `previous` entitlement for the transition
  /// listener above. Reconcile after the store/file check completes so a paid
  /// user's flag is not cleared during the fail-closed loading window, while
  /// a genuinely revoked install is still disarmed.
  Future<void> _reconcileRevokedCapabilities() async {
    final entitlement = await readEntitlement(
      ref.read(dbProvider),
      entitlement: ref.read(proEntitlementStoreProvider),
    );
    if (!entitlement.allows(ProCapabilityBoundary.wallDisplayAutoStart)) {
      await ref.read(settingsProvider).setWallAutoStart(false);
    }
  }

  /// The wall-display autostart's slow-boot fallback (U49 §12f). The primary
  /// path is `main()`'s pre-frame arming of the router redirect, but that
  /// rides the settings pre-warm's bounded wait — a cold start slow enough to
  /// blow the 3 s cap would silently strand a wall tablet on the home screen
  /// until someone walks over. This post-frame check re-reads the flag once
  /// the database is warm and jumps only while the app is still sitting on
  /// the initial route, so it can never fight navigation the user (or a
  /// notification tap) has already performed.
  void _autoStartWallFallback() {
    if (wallAutoStartRequested) return; // The redirect already handled it.
    Future<void> run() async {
      final on = await ref.read(settingsProvider).readWallAutoStart();
      if (!on ||
          !mounted ||
          !ref.read(
            proCapabilityProvider(ProCapabilityBoundary.wallDisplayAutoStart),
          )) {
        return;
      }
      final location = appRouter.routerDelegate.currentConfiguration.uri.path;
      if (location == '/') appRouter.go('/wall');
    }

    unawaited(
      run().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'wall',
            context: ErrorSummary('arming the wall-display autostart'),
          ),
        );
      }),
    );
  }

  /// The update-available check (U48) — launch only, never on resume or the
  /// housekeeping tick: one glance at the store per app start is polite, and
  /// the flow's own once-per-version marker already keeps repeat launches
  /// quiet. Everything store-shaped lives behind [appUpdateCheckerProvider]
  /// (Play in-app updates / iTunes lookup); this wiring only supplies the two
  /// SnackBar notices. Both are duration-bounded (never `persist`): a launch
  /// notice nobody asked for must not sit over the UI or dam the messenger
  /// queue ahead of real feedback like "Backup done".
  void _checkAppUpdate() {
    final checker = ref.read(appUpdateCheckerProvider);
    final flow = AppUpdateFlow(
      checker: checker,
      settings: ref.read(settingsProvider),
      // iOS (and the rig): the store page is the only way to the update.
      notifyStorePage: (storeUri) => _updateSnack(
        (l) => l.updateAvailableSnack,
        actionLabel: (l) => l.updateAction,
        onAction: () => unawaited(
          launchUrl(
            storeUri,
            mode: LaunchMode.externalApplication,
          ).catchError((_) => false),
        ),
      ),
      // Android: the flexible download is on the device; offer the restart
      // that installs it. Declining costs nothing — the next launch's check
      // finds the downloaded state and offers again.
      notifyRestartReady: () => _updateSnack(
        (l) => l.updateReadySnack,
        actionLabel: (l) => l.updateRestartAction,
        onAction: () => unawaited(checker.install()),
      ),
    );
    Future<void> run() async {
      // The notice races the stored-locale apply: this callback fires right
      // after the first frame, and when the pre-warm in [main] hit its 3 s
      // cap the tree is still in the system language — a SnackBar shown that
      // early would keep the wrong language forever (its Text is built once).
      // Wait for the settings map (which carries the locale) and one more
      // frame for the rebuild, then check the store.
      await ref.read(settingsMapProvider.future);
      await WidgetsBinding.instance.endOfFrame;
      await flow.run();
    }

    unawaited(
      run().catchError((Object e, StackTrace s) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'app_update',
            context: ErrorSummary('checking the store for a newer version'),
          ),
        );
      }),
    );
  }

  /// Localized update-notice SnackBar, tolerant of the app shutting down
  /// while the store check ran (the [_restoreSnack] shape, plus an action).
  void _updateSnack(
    String Function(AppLocalizations l) message, {
    required String Function(AppLocalizations l) actionLabel,
    required VoidCallback onAction,
  }) {
    final messenger = _messengerKey.currentState;
    final context = _messengerKey.currentContext;
    if (messenger == null || context == null) return;
    final l = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message(l)),
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(label: actionLabel(l), onPressed: onAction),
      ),
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

  /// One flow instance per process: its internal latch is what makes the
  /// U35 pull-check launch-only (resumes never re-list the cloud folder or
  /// pop a dialog mid-use). The flow itself — choice handling, the parked
  /// push, the once-per-process latch — lives in `cloud_restore_flow.dart`
  /// and is pinned by `cloud_restore_flow_test.dart` (T17); this wiring only
  /// supplies the Flutter pieces.
  late final CloudRestoreFlow _restoreFlow = CloudRestoreFlow(
    authorizer: ref.read(proCapabilityAuthorizerProvider),
    prompt: (proposal) async {
      final context = rootNavigatorKey.currentContext;
      // Never shown → null: the flow records nothing and the next launch
      // proposes again.
      if (context == null || !context.mounted) return null;
      return showCloudRestoreDialog(context, proposal);
    },
    notify: (notice) => _restoreSnack(
      (l) => switch (notice) {
        CloudRestoreRestored() => l.backupRestored,
        CloudRestoreRejected(:final reason) => l.backupRejection(reason),
        CloudRestoreFailed() => l.backupImportFailed,
      },
    ),
    report: (e, s, library, context) => FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: s,
        library: library,
        context: ErrorSummary(context),
      ),
    ),
  );

  Future<void> _backupAndSync() => runLaunchBackupAndSync(
    ref.read(dbProvider),
    store: ref.read(cloudBackupStoreProvider),
    state: ref.read(cloudSyncStateProvider),
    flow: _restoreFlow,
  );

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
      // Locale→intl wiring and the shared ReefBackground; named so a test can
      // exercise it through the real app (see [reefAppBuilder]).
      builder: reefAppBuilder,
      theme: buildReefTheme(Brightness.light, defaultTargetPlatform),
      darkTheme: buildReefTheme(Brightness.dark, defaultTargetPlatform),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
