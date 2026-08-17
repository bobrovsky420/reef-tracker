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
}) => showDialog<String>(
  context: context,
  builder: (context) => _DeviceRenameDialog(
    title: title,
    fieldLabel: fieldLabel,
    initial: initial,
  ),
);

class _DeviceRenameDialog extends StatefulWidget {
  const _DeviceRenameDialog({
    required this.title,
    required this.fieldLabel,
    required this.initial,
  });

  final String title;
  final String fieldLabel;
  final String initial;

  @override
  State<_DeviceRenameDialog> createState() => _DeviceRenameDialogState();
}

class _DeviceRenameDialogState extends State<_DeviceRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.fieldLabel),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}
