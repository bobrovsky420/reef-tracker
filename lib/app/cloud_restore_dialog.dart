import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:reeftracker/data/cloud_restore_flow.dart';
import 'package:reeftracker/data/cloud_sync.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/l10n/l10n_helpers.dart';

/// The launch restore-proposal dialog (U35), extracted from `main.dart`
/// (T17) so its choice surface is widget-testable: "Keep mine" is offered
/// only for a diverged proposal, and a barrier dismiss resolves to
/// [CloudRestoreChoice.notNow] — never `null`, which [CloudRestoreFlow]
/// reserves for "the dialog was never shown".
Future<CloudRestoreChoice> showCloudRestoreDialog(
  BuildContext context,
  CloudRestoreProposal proposal,
) async {
  final choice = await showDialog<CloudRestoreChoice>(
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
      // Same dialog, provider-appropriate wording: the U35 check now runs
      // on both platforms (U44), and "your Google Drive" would be a lie on
      // an iPhone.
      final isIcloud = defaultTargetPlatform == TargetPlatform.iOS;
      return AlertDialog(
        icon: const Icon(Icons.cloud_download_outlined),
        title: Text(l.syncRestoreTitle),
        content: Text(
          proposal.diverged
              ? (isIcloud
                    ? l.syncRestoreDivergedBodyIcloud(device, when)
                    : l.syncRestoreDivergedBody(device, when))
              : (isIcloud
                    ? l.syncRestoreBodyIcloud(device, when)
                    : l.syncRestoreBody(device, when)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, CloudRestoreChoice.notNow),
            child: Text(l.syncRestoreNotNow),
          ),
          if (proposal.diverged)
            TextButton(
              onPressed: () => Navigator.pop(ctx, CloudRestoreChoice.keepMine),
              child: Text(l.syncRestoreKeepMine),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, CloudRestoreChoice.restore),
            child: Text(AppLocalizations.of(ctx).restore),
          ),
        ],
      );
    },
  );
  // Barrier dismiss counts as "not now": quiet until a newer file shows.
  return choice ?? CloudRestoreChoice.notNow;
}
