import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/cloud_restore_dialog.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';
import 'package:reeftracker/data/cloud_restore_flow.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// T17: the launch restore-proposal dialog's choice surface. "Keep mine" is
/// the difference between "fast-forward to the newer backup" and "discard
/// local changes" — offering it on the wrong proposal kind (or resolving a
/// barrier dismiss to the wrong choice) is exactly the class of silent wiring
/// bug the audit flagged.
void main() {
  CloudRestoreProposal proposal({required bool diverged}) =>
      CloudRestoreProposal(
        file: const CloudBackupFile(
          id: 'f1',
          name: 'reeftracker-auto-20260801T120000000Z.json',
          modifiedAt: null,
          sizeBytes: 1234,
          metadata: {},
        ),
        deviceName: 'Other phone',
        diverged: diverged,
      );

  /// Pumps a host app and opens the dialog; returns a future of the choice.
  Future<Future<CloudRestoreChoice>> open(
    WidgetTester tester, {
    required bool diverged,
  }) async {
    late Future<CloudRestoreChoice> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = showCloudRestoreDialog(
                context,
                proposal(diverged: diverged),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AlertDialog)));

  testWidgets('plain (non-diverged) proposal offers no "Keep mine"', (
    tester,
  ) async {
    final choice = await open(tester, diverged: false);
    final l = l10n(tester);
    expect(find.text(l.syncRestoreNotNow), findsOneWidget);
    expect(find.text(l.restore), findsOneWidget);
    expect(find.text(l.syncRestoreKeepMine), findsNothing);

    await tester.tap(find.text(l.restore));
    await tester.pumpAndSettle();
    expect(await choice, CloudRestoreChoice.restore);
  });

  testWidgets('diverged proposal offers "Keep mine", and it resolves', (
    tester,
  ) async {
    final choice = await open(tester, diverged: true);
    final l = l10n(tester);
    expect(find.text(l.syncRestoreKeepMine), findsOneWidget);

    await tester.tap(find.text(l.syncRestoreKeepMine));
    await tester.pumpAndSettle();
    expect(await choice, CloudRestoreChoice.keepMine);
  });

  testWidgets('barrier dismiss resolves to notNow — never null, which the '
      'flow reserves for "dialog never shown"', (tester) async {
    final choice = await open(tester, diverged: true);
    l10n(tester); // asserts the dialog is up

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(await choice, CloudRestoreChoice.notNow);
  });

  testWidgets('"Not now" button resolves to notNow', (tester) async {
    final choice = await open(tester, diverged: false);
    final l = l10n(tester);

    await tester.tap(find.text(l.syncRestoreNotNow));
    await tester.pumpAndSettle();
    expect(await choice, CloudRestoreChoice.notNow);
  });
}
