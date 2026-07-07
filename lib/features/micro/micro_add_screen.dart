import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/micro.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_chip.dart';

/// Batch entry form for microelement measurements (U17) — the Add Reading
/// mechanics (one timestamp, locale parsing, sanity confirmation, atomic
/// group insert) scoped to the ICP panel. Two fixed filters instead of test
/// sets: **Hobby kit** (the elements home test kits exist for) and **Full
/// ICP** (the whole panel, for typing in a lab report). Like the test-set
/// chips, the filter only narrows what is *shown* — a typed value hidden by
/// the current chip is still saved.
class MicroAddScreen extends ConsumerStatefulWidget {
  const MicroAddScreen({super.key});

  @override
  ConsumerState<MicroAddScreen> createState() => _MicroAddScreenState();
}

class _MicroAddScreenState extends ConsumerState<MicroAddScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final _noteCtrl = TextEditingController();
  DateTime _takenAt = DateTime.now();
  bool _saving = false;
  bool _fullPanel = false;

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickPastDateTime(context, _takenAt);
    if (picked == null || !mounted) return;
    setState(() => _takenAt = picked);
  }

  Future<void> _save(List<MicroElementStatus> elements) async {
    final l = AppLocalizations.of(context);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefs = ref.read(unitPrefsProvider);
    final entries = <String, double>{};
    final implausible = <ParameterDef>[];
    for (final e in elements) {
      final text = _controllers[e.def.key]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = parseUserDouble(text);
      final name = l.paramName(e.def.key);
      if (value == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.invalidNumberFor(name))));
        return;
      }
      // Typed in the display unit (µg/L for most elements); store canonical.
      final canonical = _presFor(e, prefs).toCanonical(value);
      switch (checkParamValue(e.def.key, canonical)) {
        case ParamValueCheck.impossible:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.impossibleValueFor(name))));
          return;
        case ParamValueCheck.implausible:
          implausible.add(e.def);
        case ParamValueCheck.ok:
          break;
      }
      entries[e.def.key] = canonical;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.enterAtLeastOneValue)));
      return;
    }
    if (implausible.isNotEmpty) {
      final proceed = await _confirmImplausible(l, [
        for (final d in implausible) (d, entries[d.key]!),
      ], prefs);
      if (proceed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      // Ensure each element has its tracked row (idempotent; seeds the
      // catalog default bounds) so history/bounds editing have a home, then
      // insert the whole batch as one reading group.
      final type = SetupType.fromName(tank.setupType);
      for (final key in entries.keys) {
        await db.addTrackedParameter(tank.id, key, type);
      }
      await db.insertReadingGroup(
        tankId: tank.id,
        takenAt: _takenAt,
        note: note,
        values: [
          for (final e in entries.entries) (paramKey: e.key, value: e.value),
        ],
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.savedReadings(entries.length))),
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

  /// Mirrors Add Reading's implausible-value confirmation (#31).
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

  ParamPresentation _presFor(MicroElementStatus e, UnitPrefs prefs) =>
      presentationForKey(e.def.key, e.row?.unit ?? e.def.unit, prefs);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final elements = ref.watch(microElementsProvider);
    final prefs = ref.watch(unitPrefsProvider);

    // The active view (U17) scopes the "Full ICP" list — typing in a lab
    // report only offers the elements that lab actually reports.
    final viewKeys = ref.watch(microViewSelectionProvider).keys;
    final inView = [
      for (final e in elements)
        if (viewKeys == null || viewKeys.contains(e.def.key)) e,
    ];
    final hobby = [
      for (final key in kMicroHobbyKitKeys)
        for (final e in inView)
          if (e.def.key == key) e,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.microAddTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      formatDateTime(context, _takenAt, weekday: false),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l.change,
                    onPressed: _pickDateTime,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: Text(l.microChipHobby),
                selected: !_fullPanel,
                onSelected: (_) => setState(() => _fullPanel = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l.microChipFullIcp),
                selected: _fullPanel,
                onSelected: (_) => setState(() => _fullPanel = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_fullPanel)
            for (final e in hobby) _elementRow(e, prefs)
          else
            for (final (title, category) in [
              (l.microSectionMajor, ParamCategory.major),
              (l.microSectionTrace, ParamCategory.trace),
              (l.microSectionContaminants, ParamCategory.contaminant),
            ])
              if (inView.any((e) => e.def.category == category)) ...[
                _sectionHeader(title),
                for (final e in inView)
                  if (e.def.category == category) _elementRow(e, prefs),
              ],
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: l.noteOptional,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(elements),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(l.saveReadings),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _elementRow(MicroElementStatus e, UnitPrefs prefs) {
    final l = AppLocalizations.of(context);
    final pres = _presFor(e, prefs);
    final ctrl = _controllerFor(e.def.key);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l.paramName(e.def.key),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: pres.unitLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, text, _) {
                final value = parseUserDouble(text.text);
                if (value == null) return const SizedBox.shrink();
                final zone = e.bounds.classify(pres.toCanonical(value));
                return ZoneChip(zone, compact: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
