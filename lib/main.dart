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
import 'data/cloud_sync.dart';
import 'data/reminder_scheduler.dart';
import 'l10n/app_localizations.dart';
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
  void _maybeBackUp() {
    final db = ref.read(dbProvider);
    unawaited(
      runAutoBackupIfDue(db)
          .then(
            (wrote) async {
              if (!wrote) return;
              await runGDriveSyncIfDirty(
                db,
                store: ref.read(cloudBackupStoreProvider),
              );
            },
            // A failed local backup must not suppress the cloud push — the
            // Drive copy matters most exactly when local storage misbehaves.
            onError: (Object e, StackTrace s) async {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: e,
                  stack: s,
                  library: 'auto_backup',
                  context: ErrorSummary('running the automatic backup'),
                ),
              );
              await runGDriveSyncIfDirty(
                db,
                store: ref.read(cloudBackupStoreProvider),
              );
            },
          )
          .catchError((Object e, StackTrace s) {
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

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
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
      routerConfig: appRouter,
    );
  }
}
