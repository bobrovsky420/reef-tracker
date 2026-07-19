import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
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
import '../../widgets/reef_card.dart';
import '../../widgets/reef_icon_button.dart';
import '../../widgets/reef_sheet.dart';
import '../../widgets/section_header.dart';
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
        // Mini-card icon buttons (REDESIGN #3 chrome, applied here by #24).
        actions: [
          ReefIconButton(
            icon: Icons.upload_file_outlined,
            tooltip: l.icpImportTitle,
            // Pro-gated (U19): founders (and, later, Pro purchasers) import;
            // anyone else gets the explanation dialog instead of the picker.
            onPressed: ref.watch(proFeatureProvider(ProFeature.icpImport))
                ? () => _importReport(context)
                : () => showProFeatureDialog(context, ProFeature.icpImport),
          ),
          ReefIconButton(
            icon: Icons.checklist,
            tooltip: l.microViewManage,
            onPressed: () => showMicroViewsManageSheet(context),
          ),
          ReefIconButton(
            icon: Icons.tune,
            tooltip: l.microConfigureTitle,
            onPressed: () => context.push('/micro/configure'),
          ),
          ReefIconButton(
            icon: Icons.alarm_add,
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
          SwitchListTile.adaptive(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l.microHideUndetectable),
            value: hideUndetectable,
            onChanged: (v) => unawaited(
              ref.read(settingsProvider).setMicroHideUndetectable(v),
            ),
          ),
          SwitchListTile.adaptive(
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
                  color: ReefTokens.of(context).textDim,
                ),
              ),
            ),
          // Element rows grouped into one `ReefCard` per report section under
          // a `SectionHeader` (REDESIGN #24, #11 row pattern).
          for (final (title, items) in sections)
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title),
                    ReefCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            _ElementRow(
                              element: items[i],
                              prefs: prefs,
                              isLast: i == items.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                style: ReefTokens.monoInputStyle,
                decoration: InputDecoration(labelText: l.customDaysLabel),
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
            // Icon size/color come from the theme's §A.6 chip treatment.
            child: ActionChip(
              avatar: const Icon(Icons.add),
              label: Text(l.microViewNew),
              onPressed: () => _create(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel status header: dominant-zone icon, out-of-range headline, newest sample
/// date — the micro panel's own freshness framing (deliberately outside the
/// 30-day core health model; see `domain/micro.dart`).
///
/// Styled after the dashboard `MicroSummaryTile` (REDESIGN #10 geometry): a
/// 34 px r10 icon chip in the dominant zone's soft color, headline in the
/// dominant color, faint date line. Unknown zone (no readings) renders
/// neutrally via the zone visuals' track/textFaint mapping.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status});

  final MicroStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final measured = status.measured > 0;
    final zone = status.statusZone;
    return ReefCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: zone.softColorOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.science_outlined,
              size: 16,
              color: zone.colorOf(context),
            ),
          ),
          const SizedBox(width: 12),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: measured ? zone.colorOf(context) : tokens.textDim,
                  ),
                ),
                if (status.lastMeasuredAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.microLastMeasured(formatDate(status.lastMeasuredAt!)),
                    style: TextStyle(fontSize: 11, color: tokens.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One element row (#11 pattern) inside its section card: name, relative-time
/// sub, trailing latest value in mono w700 zone color. Tap → the standard
/// parameter history.
class _ElementRow extends StatelessWidget {
  const _ElementRow({
    required this.element,
    required this.prefs,
    required this.isLast,
  });

  final MicroElementStatus element;
  final UnitPrefs prefs;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
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

    // The rows ripple on the card's own Material (the InkWell ancestor).
    return InkWell(
      onTap: () => context.push('/history/${def.key}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.surfaceBorder),
                ),
              ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Localized names carry the element symbol ("Zinc (Zn)") so
                  // rows match the symbols on an ICP report.
                  Text(
                    l.paramName(def.key),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest == null
                        ? l.microNotMeasured
                        : relativeTimeLabel(l, latest.takenAt),
                    style: TextStyle(fontSize: 12, color: tokens.textFaint),
                  ),
                ],
              ),
            ),
            if (latest != null) ...[
              const SizedBox(width: 12),
              Text(
                '${pres.format(latest.value)} ${pres.unitLabel}',
                style: ReefTokens.monoTextStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  // An unclassifiable value (empty/invalid bounds) renders in
                  // the default color, not painted as any zone.
                  color: zone == Zone.unknown
                      ? tokens.text
                      : zone.colorOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
