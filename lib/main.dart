import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'data/auto_backup.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: ReefTrackerApp()));
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
  void _maybeBackUp() {
    runAutoBackupIfDue(ref.read(dbProvider)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0277BD); // reef blue
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
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
