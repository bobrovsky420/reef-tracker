/// Registry-driven measurement import sources.
///
/// Descriptors own source presentation, persisted-settings identity, parser
/// invocation, error mapping and preview navigation. The picker remains a
/// shared bounded CSV utility; another source adds one descriptor and registry
/// entry without changing the source sheets.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/icp_import_file.dart';
import '../../domain/hanna_import.dart';
import '../../domain/icp_import.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_sheet.dart';

enum MeasurementImportGroup { appHistory, icpReport }

typedef MeasurementFilePicker = Future<String?> Function();

abstract class MeasurementImportSourceDescriptor {
  const MeasurementImportSourceDescriptor();

  String get id;
  MeasurementImportGroup get group;
  IconData get icon;

  /// Null for sources without a persisted dedupe/location watermark.
  String? get settingsSourceId;

  bool isAvailable();
  String label(AppLocalizations l);
  String hint(AppLocalizations l);
  Object parse(String content);
  String errorText(AppLocalizations l, Object error);
  Future<void> openPreview(BuildContext context, Object result);

  Iterable<ImportSource> settingsRows(Iterable<ImportSource> rows) {
    final sourceId = settingsSourceId;
    return sourceId == null
        ? const <ImportSource>[]
        : rows.where((row) => row.source == sourceId);
  }
}

class HannaLabImportSource extends MeasurementImportSourceDescriptor {
  const HannaLabImportSource();

  @override
  String get id => kHannaImportSource;

  @override
  MeasurementImportGroup get group => MeasurementImportGroup.appHistory;

  @override
  IconData get icon => Icons.science_outlined;

  @override
  String? get settingsSourceId => kHannaImportSource;

  @override
  bool isAvailable() => true;

  @override
  String label(AppLocalizations l) => 'Hanna Lab';

  @override
  String hint(AppLocalizations l) => l.measurementImportHannaHint;

  @override
  Object parse(String content) => parseHannaCsv(content);

  @override
  String errorText(AppLocalizations l, Object error) => switch (error) {
    HannaImportException(:final reason) => switch (reason) {
      HannaImportRejection.unreadable => l.icpImportUnreadable,
      HannaImportRejection.wrongFormat => l.icpImportWrongFormat(label(l)),
      HannaImportRejection.noValues => l.icpImportNoValues,
    },
    _ => l.icpImportUnreadable,
  };

  @override
  Future<void> openPreview(BuildContext context, Object result) =>
      context.push('/import/hanna', extra: result as HannaImportResult);
}

class IcpCsvImportSource extends MeasurementImportSourceDescriptor {
  const IcpCsvImportSource(this.format, this.icon);

  final IcpImportFormat format;

  @override
  final IconData icon;

  @override
  String get id => 'icp-${format.name}';

  @override
  MeasurementImportGroup get group => MeasurementImportGroup.icpReport;

  @override
  String? get settingsSourceId => null;

  @override
  bool isAvailable() => true;

  @override
  String label(AppLocalizations l) => icpFormatDisplayName(format);

  @override
  String hint(AppLocalizations l) => switch (format) {
    IcpImportFormat.faunaMarin => l.icpImportFormatFaunaMarinHint,
    IcpImportFormat.zims => l.icpImportFormatZimsHint,
  };

  @override
  Object parse(String content) => parseIcpCsv(content, format);

  @override
  String errorText(AppLocalizations l, Object error) => switch (error) {
    IcpImportException(:final reason) => switch (reason) {
      IcpImportRejection.unreadable => l.icpImportUnreadable,
      IcpImportRejection.wrongFormat => l.icpImportWrongFormat(label(l)),
      IcpImportRejection.noValues => l.icpImportNoValues,
    },
    _ => l.icpImportUnreadable,
  };

  @override
  Future<void> openPreview(BuildContext context, Object result) =>
      context.push('/micro/import', extra: result as IcpImportResult);
}

class MeasurementImportSourceRegistry {
  MeasurementImportSourceRegistry(
    Iterable<MeasurementImportSourceDescriptor> sources,
  ) : _sources = List.unmodifiable(sources) {
    final ids = <String>{};
    for (final source in _sources) {
      if (!ids.add(source.id)) {
        throw ArgumentError(
          'Duplicate measurement import source: ${source.id}',
        );
      }
    }
  }

  final List<MeasurementImportSourceDescriptor> _sources;

  List<MeasurementImportSourceDescriptor> get sources => _sources;

  List<MeasurementImportSourceDescriptor> availableFor(
    MeasurementImportGroup group,
  ) => [
    for (final source in _sources)
      if (source.group == group && source.isAvailable()) source,
  ];

  List<MeasurementImportSourceDescriptor> get settingsSources => [
    for (final source in _sources)
      if (source.settingsSourceId != null && source.isAvailable()) source,
  ];
}

final measurementImportSources = MeasurementImportSourceRegistry(const [
  HannaLabImportSource(),
  IcpCsvImportSource(IcpImportFormat.faunaMarin, Icons.science_outlined),
  IcpCsvImportSource(IcpImportFormat.zims, Icons.table_chart_outlined),
]);

Future<void> runMeasurementImportSourceFlow(
  BuildContext context,
  MeasurementImportGroup group, {
  MeasurementImportSourceRegistry? registry,
  MeasurementFilePicker picker = pickIcpCsvContent,
}) async {
  final l = AppLocalizations.of(context);
  final sources = (registry ?? measurementImportSources).availableFor(group);
  final source = await showModalBottomSheet<MeasurementImportSourceDescriptor>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: ReefSheetHeader(
              group == MeasurementImportGroup.appHistory
                  ? l.measurementImportTitle
                  : l.icpImportTitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              group == MeasurementImportGroup.appHistory
                  ? l.measurementImportSourceHint
                  : l.icpImportFormatHint,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          for (final item in sources)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label(l)),
              subtitle: Text(item.hint(l)),
              onTap: () => Navigator.pop(ctx, item),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final content = await picker();
    if (content == null) return;
    final result = source.parse(content);
    if (context.mounted) await source.openPreview(context, result);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(source.errorText(l, error))));
  }
}
