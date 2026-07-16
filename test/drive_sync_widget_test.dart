import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/features/settings/settings_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_cloud_backup_store.dart';

/// Widget tests for the Google Drive sync row in Settings (U24). The connect
/// flow itself is engine-tested in cloud_sync_test.dart; here the concern is
/// the row's three states (gated / disconnected / connected), the disconnect
/// dialog, and the persistent upload-error row — all against the fakes, never
/// the google_sign_in plugin (it throws under `flutter test`).
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

  Future<AppDatabase> pumpSettings(
    WidgetTester tester, {
    bool founder = true,
    String? account,
    DateTime? lastErrorAt,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // driveSync is grandfathered (explicit 2026-07-15 decision): founders
    // pass the gate, marker-less (Standard) installs see the Pro dialog.
    if (founder) await db.setSetting(kLegacyFreeSinceKey, '0.28.0');
    if (account != null) {
      await db.setSetting(kSyncGdriveAccountKey, account);
    }
    if (lastErrorAt != null) {
      await AppSettings(db).setSyncGdriveLastErrorAt(lastErrorAt);
    }
    auth = FakeCloudAuth();
    store = FakeCloudBackupStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
          cloudAuthProvider.overrideWithValue(auth),
          cloudBackupStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('non-entitled (Standard) install: the tap explains the Pro '
      'gate instead of connecting', (tester) async {
    try {
      final db = await pumpSettings(tester, founder: false);
      expect(find.text('Google Drive sync'), findsOneWidget);
      expect(
        find.text('Back up automatically to your Google Drive'),
        findsOneWidget,
      );

      await tester.tap(find.text('Google Drive sync'));
      await settle(tester);
      expect(find.text('Pro feature'), findsOneWidget);
      expect(
        find.text('Google Drive sync is part of ReefTracker Pro.'),
        findsOneWidget,
      );
      // No connect happened.
      expect(await AppSettings(db).readSyncGdriveAccount(), isNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('founder install: the tap connects (grandfathered) and the row '
      'shows the account', (tester) async {
    try {
      final db = await pumpSettings(tester);
      await tester.tap(find.text('Google Drive sync'));
      await settle(tester);

      expect(await AppSettings(db).readSyncGdriveAccount(), 'reef@test.dev');
      expect(find.textContaining('reef@test.dev'), findsWidgets);
      expect(find.text('Pro feature'), findsNothing);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('connected: shows account + status, and the dialog disconnects', (
    tester,
  ) async {
    try {
      final db = await pumpSettings(tester, account: 'reef@test.dev');
      expect(find.textContaining('reef@test.dev'), findsOneWidget);
      expect(find.textContaining('Nothing uploaded yet'), findsOneWidget);

      await tester.tap(find.text('Google Drive sync'));
      await settle(tester);
      expect(
        find.textContaining('"ReefTracker" folder in the Google Drive'),
        findsOneWidget,
      );

      await tester.tap(find.text('Disconnect'));
      await settle(tester);
      expect(auth.disconnectCalls, 1);
      expect(await AppSettings(db).readSyncGdriveAccount(), isNull);
      // Row is back to the not-connected state.
      expect(
        find.text('Back up automatically to your Google Drive'),
        findsOneWidget,
      );
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('the entire Drive UI is absent on iOS (Android-only surface)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpSettings(
        tester,
        account: 'reef@test.dev',
        lastErrorAt: DateTime(2026, 7, 15, 8, 30),
      );
      expect(find.text('Google Drive sync'), findsNothing);
      expect(find.textContaining('reef@test.dev'), findsNothing);
      expect(find.textContaining('Google Drive upload failed'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await unmountApp(tester);
    }
  });

  testWidgets('a recorded upload failure shows the persistent warning row', (
    tester,
  ) async {
    try {
      await pumpSettings(
        tester,
        account: 'reef@test.dev',
        lastErrorAt: DateTime(2026, 7, 15, 8, 30),
      );
      expect(find.textContaining('Google Drive upload failed'), findsOneWidget);
    } finally {
      await unmountApp(tester);
    }
  });
}
