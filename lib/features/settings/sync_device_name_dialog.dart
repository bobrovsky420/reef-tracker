import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/cloud_sync.dart';
import '../../l10n/app_localizations.dart';

/// The U35 device-name editor: names this device on the backups it uploads.
/// Shown at the end of the Drive connect flow, from the connected row's
/// options dialog (Settings), and from the Manage-backups nudge row.
/// Cancelling keeps the current name; saving an empty field clears it.
///
/// Returns whether the name actually changed — a change also cleared the
/// sync dirty gate (see [renameSyncDevice]), so callers follow up with
/// `runGDriveSyncIfDirty` to get a freshly-labeled file into the rotation
/// instead of waiting for the next data change.
Future<bool> showSyncDeviceNameDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = await ref.read(settingsProvider).readSyncDeviceName();
  // First-time only: prefill with the OS-reported device name ("Pixel 7",
  // "Alex's phone") so most users just hit Save — a stored name always wins,
  // and the field stays fully editable, so nothing is saved unseen.
  final initial = current ?? await ref.read(osDeviceNameProvider.future);
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  // Deliberately never disposed: the dialog's exit animation still paints
  // the TextField after showDialog returns, so an eager dispose here blows
  // assertions mid-transition; an unreferenced controller is simply GC'd.
  final controller = TextEditingController(text: initial ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.smartphone_outlined),
      title: Text(l.syncDeviceNameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.syncDeviceNameBody),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.syncDeviceNameHint),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(l.save),
        ),
      ],
    ),
  );
  if (name == null) return false;
  return renameSyncDevice(ref.read(dbProvider), name);
}
