import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
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

  TextEditingController _controllerFor(int id) =>
      _controllers.putIfAbsent(id, () {
        final c = TextEditingController();
        c.addListener(() => setState(() {}));
        return c;
      });

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_takenAt),
    );
    if (!mounted) return;
    setState(() {
      _takenAt = DateTime(date.year, date.month, date.day, time?.hour ?? 0,
          time?.minute ?? 0);
    });
  }

  Future<void> _save(List<TrackedParameter> params) async {
    final l = AppLocalizations.of(context);
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final prefs = ref.read(unitPrefsProvider);
    final entries = <TrackedParameter, double>{};
    for (final p in params) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.invalidNumberFor(l.paramName(p.paramKey)))));
        return;
      }
      // Store canonically (e.g. °C, SG) regardless of the display unit.
      entries[p] = presentationOf(p, prefs).toCanonical(value);
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.enterAtLeastOneValue)));
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    for (final e in entries.entries) {
      await db.insertReading(
        tankId: tank.id,
        paramKey: e.key.paramKey,
        value: e.value,
        takenAt: _takenAt,
        note: note,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.savedReadings(entries.length))));
      context.pop();
    }
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
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l.measuredAt),
                  subtitle:
                      Text(DateFormat.yMMMEd().add_jm().format(_takenAt)),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: Text(l.change),
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
                        child: CircularProgressIndicator(strokeWidth: 2))
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
    final text = ctrl.text.trim();
    final value = double.tryParse(text.replaceAll(',', '.'));
    final zone = value != null
        ? boundsOf(p).classify(pres.toCanonical(value))
        : Zone.unknown;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(l.paramName(p.paramKey),
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
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
            child: value != null
                ? ZoneChip(zone, compact: true)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
