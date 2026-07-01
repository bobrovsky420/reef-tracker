import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is only exposed as a public type through misc.dart in riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Pumps [child] inside the minimum scaffolding every ReefTracker widget needs:
/// a Riverpod [ProviderScope], a [MaterialApp] carrying the app's localization
/// delegates, and a [Scaffold] body. This is the shared entry point for
/// widget-level tests; pass [overrides] to stub providers a widget reads.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
