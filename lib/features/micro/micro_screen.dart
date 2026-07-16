import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/icp_import_file.dart';
import '../../domain/icp_import.dart';
import '../../domain/micro.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/pro_features.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/zone_visuals.dart';
import 'micro_view_sheets.dart';

/// The microelement panel (U17) for the active tank: every ICP element in
/// catalog order, sectioned the way lab reports group them (major ions /
/// trace elements / contaminants). Each row shows the latest value colored by
/// its zone and links to the standard parameter history; zone bounds are
/// configured from the app-bar's element-settings action (`/micro/configure`).
/// Elements without a reading render muted, advertising what can be tracked.
class MicroScreen extends ConsumerWidget {
  const MicroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.microTitle)),
        body: Center(child: Text(l.noActiveAquarium)),
      );
    }
    final elements = ref.watch(microElementsProvider);
    final status = ref.watch(microStatusProvider);
    final prefs = ref.watch(unitPrefsProvider);
    final selection = ref.watch(microViewSelectionProvider);
    final views = ref.watch(microViewsProvider).value ?? const <MicroView>[];

    final hideUndetectable =
        ref.watch(microHideUndetectableProvider).value ?? false;
    final attentionOnly = ref.watch(microAttentionOnlyProvider).value ?? false;

    // The active view (U17) filters which elements are listed; null keys =
    // full list. The status card above already follows the same selection
    // (microStatusProvider). The two quick-filter switches only trim this
    // list — the status card deliberately keeps counting hidden elements.
    final keys = selection.keys;
    final visible = [
      for (final e in elements)
        if ((keys == null || keys.contains(e.def.key)) &&
            !(hideUndetectable &&
                microHiddenAsUndetectable(e.bounds, e.latest?.value)) &&
            (!attentionOnly || microNeedsAttention(e.bounds, e.latest?.value)))
          e,
    ];
    final sections = <(String, List<MicroElementStatus>)>[
      (
        l.microSectionMajor,
        [
          for (final e in visible)
            if (e.def.category == ParamCategory.major) e,
        ],
      ),
      (
        l.microSectionTrace,
        [
          for (final e in visible)
            if (e.def.category == ParamCategory.trace) e,
        ],
      ),
      (
        l.microSectionContaminants,
        [
          for (final e in visible)
            if (e.def.category == ParamCategory.contaminant) e,
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.microTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: l.icpImportTitle,
            // Pro-gated (U19): founders (and, later, Pro purchasers) import;
            // anyone else gets the explanation dialog instead of the picker.
            onPressed: ref.watch(proFeatureProvider(ProFeature.icpImport))
                ? () => _importReport(context)
                : () => showProFeatureDialog(context, ProFeature.icpImport),
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l.microViewManage,
            onPressed: () => showMicroViewsManageSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l.microConfigureTitle,
            onPressed: () => context.push('/micro/configure'),
          ),
          IconButton(
            icon: const Icon(Icons.alarm_add),
            tooltip: l.microReminderTooltip,
            onPressed: () => _createReminder(context, ref, tank.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _SummaryCard(status: status),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
            child: _ViewChips(
              tankId: tank.id,
              selection: selection,
              views: views,
            ),
          ),
          SwitchListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l.microHideUndetectable),
            value: hideUndetectable,
            onChanged: (v) => unawaited(
              ref.read(settingsProvider).setMicroHideUndetectable(v),
            ),
          ),
          SwitchListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l.microAttentionOnly),
            value: attentionOnly,
            onChanged: (v) =>
                unawaited(ref.read(settingsProvider).setMicroAttentionOnly(v)),
          ),
          if (visible.isEmpty && (hideUndetectable || attentionOnly))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(
                l.microFilterAllHidden,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          for (final (title, items) in sections)
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final e in items) _ElementRow(element: e, prefs: prefs),
            ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/micro/add'),
        icon: const Icon(Icons.add),
        label: Text(l.microAddMeasurements),
      ),
    );
  }

  /// ICP report import (U17 phase 2): format choice → file picker → parse →
  /// preview screen. The format is the user's explicit choice, never sniffed —
  /// a mismatch fails loudly with a format-specific message.
  Future<void> _importReport(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final format = await showModalBottomSheet<IcpImportFormat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l.icpImportTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
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

  /// Creates a custom maintenance plan reminding the user to test
  /// microelements every N days — reusing the whole maintenance/notification
  /// machinery (U12) instead of a parallel reminder path. The plan appears on
  /// the maintenance schedule like any other task.
  Future<void> _createReminder(
    BuildContext context,
    WidgetRef ref,
    int tankId,
  ) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: '90');
    final formKey = GlobalKey<FormState>();
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.microReminderTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.microReminderHint),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.customDaysLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed = int.tryParse((v ?? '').trim());
                  return (parsed == null || parsed < 1)
                      ? l.invalidIntervalDays
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(ctrl.text.trim()));
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (days == null || !context.mounted) return;
    await ref
        .read(dbProvider)
        .insertMaintenanceSchedule(
          tankId: tankId,
          title: l.microIcpTaskTitle,
          cadenceDays: days,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.microReminderCreated)));
    }
  }
}

/// The view-switcher chip row (U17): `[Full list] [Fauna Marin ICP]
/// [custom views…] [+ new]`. Selecting persists the token per tank; a custom
/// chip's long-press is an edit shortcut (the app-bar manage sheet is the
/// accessible path, #45 precedent).
class _ViewChips extends ConsumerWidget {
  const _ViewChips({
    required this.tankId,
    required this.selection,
    required this.views,
  });

  final int tankId;
  final MicroViewSelection selection;
  final List<MicroView> views;

  void _select(WidgetRef ref, String? token) {
    unawaited(ref.read(settingsProvider).setMicroView(tankId, token));
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final catalogKeys = {for (final d in kMicroParameters) d.key};
    final id = await showMicroViewEditSheet(
      context,
      db: ref.read(dbProvider),
      tankId: tankId,
      // Start from what is currently shown.
      initialKeys: selection.keys ?? catalogKeys,
    );
    if (id != null) _select(ref, '$kMicroViewCustomPrefix$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l.microViewFull),
            selected: selection.token == kMicroViewFullToken,
            onSelected: (_) => _select(ref, null),
          ),
          // Lab presets from micro_views.yaml — names are proper nouns,
          // deliberately not localized.
          for (final preset in kMicroViewPresets)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(preset.name),
                selected: selection.token == preset.token,
                onSelected: (_) => _select(ref, preset.token),
              ),
            ),
          for (final v in views)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onLongPress: () => showMicroViewEditSheet(
                  context,
                  db: ref.read(dbProvider),
                  tankId: tankId,
                  view: v,
                ),
                child: ChoiceChip(
                  label: Text(v.name),
                  selected: selection.custom?.id == v.id,
                  onSelected: (_) =>
                      _select(ref, '$kMicroViewCustomPrefix${v.id}'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l.microViewNew),
              onPressed: () => _create(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel status header: worst-zone icon, out-of-range headline, newest sample
/// date — the micro panel's own freshness framing (deliberately outside the
/// 30-day core health model; see `domain/micro.dart`).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status});

  final MicroStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final measured = status.measured > 0;
    final color = measured ? status.worstZone.color : hint;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !measured
                        ? l.microEmptyHint
                        : status.outOfRange > 0
                        ? l.microOutOfRangeN(status.outOfRange)
                        : l.microAllOk,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: measured ? color : null,
                      fontWeight: measured ? FontWeight.w600 : null,
                    ),
                  ),
                  if (status.lastMeasuredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.microLastMeasured(formatDate(status.lastMeasuredAt!)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementRow extends StatelessWidget {
  const _ElementRow({required this.element, required this.prefs});

  final MicroElementStatus element;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final def = element.def;
    final latest = element.latest;
    final pres = presentationForKey(
      def.key,
      element.row?.unit ?? def.unit,
      prefs,
    );
    final zone = latest != null
        ? element.bounds.classify(latest.value)
        : Zone.unknown;

    return ListTile(
      // Localized names carry the element symbol ("Zinc (Zn)") so rows match
      // the symbols on an ICP report.
      title: Text(l.paramName(def.key)),
      subtitle: Text(
        latest == null
            ? l.microNotMeasured
            : relativeTimeLabel(l, latest.takenAt),
        style: TextStyle(color: hint),
      ),
      trailing: latest == null
          ? null
          : Text(
              '${pres.format(latest.value)} ${pres.unitLabel}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                // An unclassifiable value (empty/invalid bounds) renders in
                // the default color, not painted as any zone.
                color: zone == Zone.unknown ? null : zone.color,
              ),
            ),
      onTap: () => context.push('/history/${def.key}'),
    );
  }
}
