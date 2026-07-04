import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_chip.dart';

/// Lets the user enter values for any subset of tracked parameters at one time.
class AddReadingScreen extends ConsumerStatefulWidget {
  const AddReadingScreen({super.key});

  @override
  ConsumerState<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends ConsumerState<AddReadingScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final _noteCtrl = TextEditingController();
  DateTime _takenAt = DateTime.now();
  bool _saving = false;

  // No listener here: only the row's zone chip depends on the typed text, and
  // it listens to its own controller (T14) — a keystroke must not rebuild the
  // whole form.
  TextEditingController _controllerFor(int id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);

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

  Future<void> _save(List<TrackedParameter> params) async {
    final l = AppLocalizations.of(context);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefs = ref.read(unitPrefsProvider);
    final entries = <TrackedParameter, double>{};
    final implausible = <TrackedParameter>[];
    for (final p in params) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = parseUserDouble(text);
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.invalidNumberFor(l.paramName(p.paramKey)))),
        );
        return;
      }
      // Store canonically (e.g. °C, SG) regardless of the display unit.
      final canonical = presentationOf(p, prefs).toCanonical(value);
      // Sanity-check the canonical value (#31): impossible measurements are
      // rejected; merely implausible ones are collected and confirmed below,
      // so a genuinely extreme reading stays recordable.
      switch (checkParamValue(p.paramKey, canonical)) {
        case ParamValueCheck.impossible:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.impossibleValueFor(l.paramName(p.paramKey))),
            ),
          );
          return;
        case ParamValueCheck.implausible:
          implausible.add(p);
        case ParamValueCheck.ok:
          break;
      }
      entries[p] = canonical;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.enterAtLeastOneValue)));
      return;
    }
    if (implausible.isNotEmpty) {
      final proceed = await _confirmImplausible(l, [
        for (final p in implausible) (p, entries[p]!),
      ], prefs);
      if (proceed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      // Insert the whole group atomically so a failure mid-group can't leave a
      // partial batch behind.
      await db.insertReadingGroup(
        tankId: tank.id,
        takenAt: _takenAt,
        note: note,
        values: [
          for (final e in entries.entries)
            (paramKey: e.key.paramKey, value: e.value),
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

  /// Asks the user to confirm values outside their plausible range before
  /// saving (#31). Shows each suspicious value as the app understood it, in
  /// the display unit, next to the typical range — which is what exposes a
  /// locale mis-parse (`1,300` read as 1.3).
  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    List<(TrackedParameter, double)> values,
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
            for (final (p, canonical) in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Builder(
                  builder: (_) {
                    final pres = presentationOf(p, prefs);
                    // `implausible` implies the catalog defines the range.
                    final def = kParameterByKey[p.paramKey]!;
                    return Text(
                      l.implausibleValueLine(
                        l.paramName(p.paramKey),
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
    final trackedAsync = ref.watch(trackedParametersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.addReading)),
      body: trackedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tracked) {
          final params = tracked.where((t) => t.enabled).toList();
          if (params.isEmpty) {
            return Center(child: Text(l.noTrackedToRecord));
          }
          final prefs = ref.watch(unitPrefsProvider);
          return ListView(
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
              for (final p in params) _paramRow(p, prefs),
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
                onPressed: _saving ? null : () => _save(params),
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
          );
        },
      ),
    );
  }

  Widget _paramRow(TrackedParameter p, UnitPrefs prefs) {
    final l = AppLocalizations.of(context);
    final pres = presentationOf(p, prefs);
    final ctrl = _controllerFor(p.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l.paramName(p.paramKey),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
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
                final zone = boundsOf(p).classify(pres.toCanonical(value));
                return ZoneChip(zone, compact: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
