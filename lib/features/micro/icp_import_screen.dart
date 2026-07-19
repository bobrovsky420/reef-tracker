import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/icp_import.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/zone_chip.dart';

/// Preview + confirm step of the ICP report import (U17 phase 2). Shows the
/// parsed values grouped the way the app groups parameters, with zone chips
/// against the tank's effective bounds, lets the user set the **sample date**
/// (the report's analysis date is only the default — the water sample is
/// typically taken days earlier), and saves everything as one reading group,
/// exactly like the manual micro entry form.
class IcpImportScreen extends ConsumerStatefulWidget {
  const IcpImportScreen({super.key, required this.result});

  final IcpImportResult result;

  @override
  ConsumerState<IcpImportScreen> createState() => _IcpImportScreenState();
}

class _IcpImportScreenState extends ConsumerState<IcpImportScreen> {
  final _noteCtrl = TextEditingController();
  late DateTime _takenAt;
  bool _noteSeeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reported = widget.result.reportDate;
    final now = DateTime.now();
    _takenAt = reported == null || reported.isAfter(now) ? now : reported;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickPastDateTime(context, _takenAt);
    if (picked == null || !mounted) return;
    setState(() => _takenAt = picked);
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefs = ref.read(unitPrefsProvider);
    final db = ref.read(dbProvider);
    final values = widget.result.values;

    // The same canonical sanity gate as manual entry (#31) — a lab report can
    // carry an outlier (or the user picked the wrong format for a homonymous
    // column) just like a typo can.
    final implausible = <ParameterDef>[];
    for (final e in values.entries) {
      final def = kParameterByKey[e.key];
      if (def == null) continue;
      switch (checkParamValue(e.key, e.value)) {
        case ParamValueCheck.impossible:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.impossibleValueFor(l.paramName(e.key)))),
          );
          return;
        case ParamValueCheck.implausible:
          implausible.add(def);
        case ParamValueCheck.ok:
          break;
      }
    }
    if (implausible.isNotEmpty) {
      final proceed = await _confirmImplausible(l, [
        for (final d in implausible) (d, values[d.key]!),
      ], prefs);
      if (proceed != true || !mounted) return;
    }

    // Re-import guard: the Fauna Marin sample id travels in the reading note,
    // so a second import of the same report is detectable.
    final sampleId = widget.result.sampleId;
    if (sampleId != null) {
      final readings = await db.getAllReadings();
      final duplicate = readings.any(
        (r) => r.tankId == tank.id && (r.note?.contains(sampleId) ?? false),
      );
      if (!mounted) return;
      if (duplicate) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.icpImportDuplicateTitle),
            content: Text(l.icpImportDuplicateBody(sampleId)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.icpImportAnyway),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      // Same mechanics as the manual micro form: ensure each parameter has
      // its tracked row (idempotent; seeds catalog default bounds), then
      // insert the whole report as one atomic reading group.
      final type = SetupType.fromName(tank.setupType);
      for (final key in values.keys) {
        await db.addTrackedParameter(tank.id, key, type);
      }
      await db.insertReadingGroup(
        tankId: tank.id,
        takenAt: _takenAt,
        note: note,
        values: [
          for (final e in values.entries) (paramKey: e.key, value: e.value),
        ],
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.savedReadings(values.length))),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Mirrors the Add Reading / micro-entry implausible-value confirmation.
  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    List<(ParameterDef, double)> values,
    UnitPrefs prefs,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.implausibleTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.implausibleIntro),
            const SizedBox(height: 12),
            for (final (def, canonical) in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Builder(
                  builder: (_) {
                    final pres = presentationForKey(def.key, def.unit, prefs);
                    return Text(
                      l.implausibleValueLine(
                        l.paramName(def.key),
                        '${pres.format(canonical)} ${pres.unitLabel}',
                        pres.format(def.plausibleMin!),
                        '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_noteSeeded) {
      _noteSeeded = true;
      final id = widget.result.sampleId;
      if (id != null) _noteCtrl.text = l.icpImportNotePrefill(id);
    }
    final prefs = ref.watch(unitPrefsProvider);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final micro = ref.watch(microElementsProvider);
    final rowByKey = {for (final t in tracked) t.paramKey: t};
    final microBounds = {for (final e in micro) e.def.key: e.bounds};

    final result = widget.result;
    final groups = <(String, ParamCategory)>[
      (l.icpImportSectionCore, ParamCategory.core),
      (l.microSectionMajor, ParamCategory.major),
      (l.microSectionTrace, ParamCategory.trace),
      (l.microSectionContaminants, ParamCategory.contaminant),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.icpImportTitle)),
      // Layout per REDESIGN #24: the #20 entry recipe — date `ReefCard` value
      // row, then the parsed values grouped into one hairline-divided card per
      // report section under `SectionHeader`s.
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReefCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: ReefValueRow(
              leading: const ReefIconChip(Icons.schedule),
              value: formatDateTime(context, _takenAt, weekday: false),
              valueStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ReefTokens.of(context).text,
              ),
              actions: [
                ReefInlineButton(l.change, onPressed: _pickDateTime),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              l.icpImportSampleDateHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final (title, category) in groups)
            if (result.values.keys.any(
              (k) => kParameterByKey[k]?.category == category,
            )) ...[
              SectionHeader(title),
              _sectionCard(category, prefs, rowByKey, microBounds),
            ],
          if (result.skipped.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l.icpImportSkipped(result.skipped.join(', ')),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(labelText: l.noteOptional),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _import,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done),
            label: Text(l.icpImportValueCount(result.values.length)),
          ),
        ],
      ),
    );
  }

  /// One `ReefCard` of hairline-divided value rows for [category].
  Widget _sectionCard(
    ParamCategory category,
    UnitPrefs prefs,
    Map<String, TrackedParameter> rowByKey,
    Map<String, ZoneBounds> microBounds,
  ) {
    final entries = [
      for (final e in widget.result.values.entries)
        if (kParameterByKey[e.key]?.category == category) e,
    ];
    return ReefCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _valueRow(
              entries[i].key,
              entries[i].value,
              prefs,
              rowByKey[entries[i].key],
              microBounds[entries[i].key],
              isLast: i == entries.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _valueRow(
    String key,
    double canonical,
    UnitPrefs prefs,
    TrackedParameter? row,
    ZoneBounds? microBoundsFor, {
    required bool isLast,
  }) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final def = kParameterByKey[key];
    final pres = presentationForKey(key, row?.unit ?? def?.unit ?? '', prefs);
    // Effective bounds: the micro panel's (row's or catalog default) for
    // elements, the tracked row's for core parameters. A core parameter
    // without a tracked row shows no chip — there is nothing to classify by.
    final bounds = microBoundsFor ?? (row != null ? boundsOf(row) : null);
    final zone = bounds?.classify(canonical) ?? Zone.unknown;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.surfaceBorder)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.paramName(key),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.text,
              ),
            ),
          ),
          Text(
            '${pres.format(canonical)} ${pres.unitLabel}',
            style: ReefTokens.monoTextStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: zone == Zone.unknown
                ? const SizedBox.shrink()
                : ZoneChip(zone, compact: true),
          ),
        ],
      ),
    );
  }
}
