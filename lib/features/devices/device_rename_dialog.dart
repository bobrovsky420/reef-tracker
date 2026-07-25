import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Asks for a new device name, prefilled with [initial].
///
/// Shared by the ReefBeat and ReefFactory dashboards — the two cards differ in
/// what they show but not in how a device is renamed. Returns the trimmed name,
/// `null` when cancelled, and an **empty string** when the field was cleared:
/// callers store that as no name, so the card falls back to the model.
Future<String?> showDeviceRenameDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String initial,
}) async {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: fieldLabel),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
