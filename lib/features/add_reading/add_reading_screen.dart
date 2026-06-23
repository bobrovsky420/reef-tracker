import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/zones.dart';
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
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    final entries = <TrackedParameter, double>{};
    for (final p in params) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Invalid number for ${kParameterByKey[p.paramKey]?.name ?? p.paramKey}')));
        return;
      }
      entries[p] = value;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter at least one value.')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved ${entries.length} reading(s).')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackedAsync = ref.watch(trackedParametersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add reading')),
      body: trackedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracked) {
          final params = tracked.where((t) => t.enabled).toList();
          if (params.isEmpty) {
            return const Center(
                child: Text('No tracked parameters to record.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Measured at'),
                  subtitle:
                      Text(DateFormat.yMMMEd().add_jm().format(_takenAt)),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final p in params) _paramRow(p),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
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
                label: const Text('Save readings'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _paramRow(TrackedParameter p) {
    final def = kParameterByKey[p.paramKey];
    final ctrl = _controllerFor(p.id);
    final text = ctrl.text.trim();
    final value = double.tryParse(text.replaceAll(',', '.'));
    final zone =
        value != null ? boundsOf(p).classify(value) : Zone.unknown;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(def?.name ?? p.paramKey,
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
                suffixText: p.unit,
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
