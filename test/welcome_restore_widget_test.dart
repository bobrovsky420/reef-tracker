import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/dashboard/dashboard_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_cloud_backup_store.dart';

/// Widget tests for the welcome-screen "Restore from Google Drive" entry
/// (U35). The restore itself is engine-tested in cloud_sync_test.dart
/// (`completeWelcomeRestore` — worker isolates can't run under the widget
/// tester's fake async); here the concern is the wiring: the button's
/// presence (Android-only, ungated — visible even without a founder marker),
/// the account-picker → confirm-dialog chain, and the empty-folder message.
void main() {
  Future<void> settle(WidgetTester tester) async {
    // No pumpAndSettle: drift stream queries keep timers alive (see
    // router_test.dart).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  late FakeCloudAuth auth;
  late FakeCloudBackupStore store;

  Future<AppDatabase> pumpWelcome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    auth = FakeCloudAuth();
    store = FakeCloudBackupStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          cloudAuthProvider.overrideWithValue(auth),
          cloudBackupStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NoTanksView()),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('the restore entry is present on the welcome screen — ungated, '
      'no founder marker needed', (tester) async {
    try {
      await pumpWelcome(tester);
      expect(find.text('Restore from Google Drive'), findsOneWidget);
      // The Pro dialog never appears from this entry.
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('absent on iOS (Android-only Drive surface)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpWelcome(tester);
      expect(find.text('Restore from Google Drive'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await unmountApp(tester);
    }
  });

  testWidgets('tap: account picker → confirm dialog naming the writing '
      'device; cancel restores nothing', (tester) async {
    try {
      final db = await pumpWelcome(tester);
      store.files['reeftracker-auto-20260723-000000-000.json'] = [1, 2, 3];
      store.fileMetadata['reeftracker-auto-20260723-000000-000.json'] = {
        'device': 'Aquarium phone',
      };

      await tester.tap(find.text('Restore from Google Drive'));
      await settle(tester);

      expect(find.text('Newer backup found'), findsOneWidget);
      expect(find.textContaining('Aquarium phone'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(await db.getTanks(), isEmpty);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('empty cloud folder: quiet snackbar, no dialog', (tester) async {
    try {
      await pumpWelcome(tester);
      await tester.tap(find.text('Restore from Google Drive'));
      await settle(tester);

      expect(find.text('Newer backup found'), findsNothing);
      expect(
        find.text('No backups in Google Drive yet'),
        findsOneWidget,
      );
    } finally {
      await unmountApp(tester);
    }
  });
}
