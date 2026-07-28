import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/icp_import_file.dart';
import '../../domain/icp_import.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_sheet.dart';

/// ICP report import (U17 phase 2): format choice → file picker → parse →
/// preview screen. The format is the user's explicit choice, never sniffed —
/// a mismatch fails loudly with a format-specific message.
///
/// Shared by both entry points: the microelement panel's app-bar button and
/// the Measurements tab's overflow menu (a lab report carries core parameters
/// too, so it must not be reachable only from the micro panel).
/// Callers own the Pro gate ([ProFeature.icpImport]).
Future<void> runIcpImportFlow(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final format = await showModalBottomSheet<IcpImportFormat>(
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
            child: ReefSheetHeader(l.icpImportTitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.icpImportFormatHint,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            // Lab/product names — proper nouns, deliberately not localized.
            title: Text(icpFormatDisplayName(IcpImportFormat.faunaMarin)),
            subtitle: Text(l.icpImportFormatFaunaMarinHint),
            onTap: () => Navigator.pop(ctx, IcpImportFormat.faunaMarin),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(icpFormatDisplayName(IcpImportFormat.zims)),
            subtitle: Text(l.icpImportFormatZimsHint),
            onTap: () => Navigator.pop(ctx, IcpImportFormat.zims),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (format == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  IcpImportResult result;
  try {
    final content = await pickIcpCsvContent();
    if (content == null) return; // Picker cancelled.
    result = parseIcpCsv(content, format);
  } on IcpImportException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (e.reason) {
          IcpImportRejection.unreadable => l.icpImportUnreadable,
          IcpImportRejection.wrongFormat => l.icpImportWrongFormat(
            icpFormatDisplayName(format),
          ),
          IcpImportRejection.noValues => l.icpImportNoValues,
        }),
      ),
    );
    return;
  } catch (_) {
    // Picker/platform failure — same user-facing story as unreadable.
    messenger.showSnackBar(SnackBar(content: Text(l.icpImportUnreadable)));
    return;
  }
  if (context.mounted) {
    await context.push('/micro/import', extra: result);
  }
}
