import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app/provider_errors.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'data/auto_backup.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    observers: [ProviderErrorObserver(showError: _warnDataLoadFailed)],
  );
  // Pre-warm the stored locale override before the first frame (#24): without
  // this the app renders its first frame(s) in the system language and then
  // snaps to the chosen one. Also front-loads the database open/migration.
  // On failure fall back to the system locale — the observer above already
  // surfaces database errors to the user.
  try {
    await container.read(localeCodeProvider.future);
  } catch (_) {}
  runApp(UncontrolledProviderScope(
    container: container,
    child: const ReefTrackerApp(),
  ));
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
    messenger.showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).dataLoadFailed),
      duration: const Duration(seconds: 6),
    ));
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
    // Opportunistic backup: run once at launch, after the first frame so it
    // never blocks startup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBackUp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeBackUp();
  }

  /// Fire-and-forget automatic backup; failures must never disrupt the app.
  /// The backup layer persists a failure as `last_backup_error_at` (surfaced
  /// in Settings), so here it only needs to be logged, not swallowed silently.
  void _maybeBackUp() {
    runAutoBackupIfDue(ref.read(dbProvider))
        .catchError((Object e, StackTrace s) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: s,
        library: 'auto_backup',
        context: ErrorSummary('running the automatic backup'),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0277BD); // reef blue
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Keep intl date/number formatting in sync with the resolved app locale
      // so DateFormat(...) renders dates in the selected language.
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child ?? const SizedBox.shrink();
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
