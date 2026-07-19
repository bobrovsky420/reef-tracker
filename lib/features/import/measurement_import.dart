import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/icp_import_file.dart';
import '../../domain/hanna_import.dart';
import '../../domain/icp_import.dart' show IcpImportException;
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_sheet.dart';

/// Measurement import entry (U32): source choice → file picker → parse →
/// preview screen. The source is the user's explicit choice, never sniffed —
/// the ICP import's policy. Hanna Lab is the only source today; future
/// apps/meters join the same sheet.
Future<void> runMeasurementImportFlow(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // No top inset — the sheet's drag handle already provides it.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: ReefSheetHeader(l.measurementImportTitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.measurementImportSourceHint,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            // Product name — a proper noun, deliberately not localized.
            title: const Text('Hanna Lab'),
            subtitle: Text(l.measurementImportHannaHint),
            onTap: () => Navigator.pop(ctx, kHannaImportSource),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source != kHannaImportSource || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  HannaImportResult result;
  try {
    // The picker is format-agnostic (any CSV); its unreadable-file failure is
    // typed as the ICP exception, mapped onto the same user-facing message.
    final content = await pickIcpCsvContent();
    if (content == null) return; // Picker cancelled.
    result = parseHannaCsv(content);
  } on HannaImportException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (e.reason) {
          HannaImportRejection.unreadable => l.icpImportUnreadable,
          HannaImportRejection.wrongFormat => l.icpImportWrongFormat(
            'Hanna Lab',
          ),
          HannaImportRejection.noValues => l.icpImportNoValues,
        }),
      ),
    );
    return;
  } on IcpImportException {
    messenger.showSnackBar(SnackBar(content: Text(l.icpImportUnreadable)));
    return;
  } catch (_) {
    // Picker/platform failure — same user-facing story as unreadable.
    messenger.showSnackBar(SnackBar(content: Text(l.icpImportUnreadable)));
    return;
  }
  if (context.mounted) {
    await context.push('/import/hanna', extra: result);
  }
}
