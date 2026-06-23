import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/zones.dart';

/// Per-tank parameter management: enable/disable, reorder, edit zones, add from
/// the catalog, and re-apply the setup-type preset.
class ManageParametersScreen extends ConsumerWidget {
  const ManageParametersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tank = ref.watch(activeTankProvider);
    final trackedAsync = ref.watch(trackedParametersProvider);

    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parameters')),
        body: const Center(child: Text('No active aquarium.')),
      );
    }
    final type = SetupType.fromName(tank.setupType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parameters'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'preset') {
                await _confirmApplyPreset(context, ref, tank.id, type);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'preset',
                  child: Text('Re-apply ${type.label} preset')),
            ],
          ),
        ],
      ),
      body: trackedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracked) {
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: tracked.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              final ids = tracked.map((e) => e.id).toList();
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              ref.read(dbProvider).reorderTrackedParameters(ids);
            },
            itemBuilder: (context, i) {
              final param = tracked[i];
              final def = kParameterByKey[param.paramKey];
              final bounds = boundsOf(param);
              return ListTile(
                key: ValueKey(param.id),
                title: Text(def?.name ?? param.paramKey),
                subtitle: Text(_boundsSummary(bounds, param.unit)),
                leading: Switch(
                  value: param.enabled,
                  onChanged: (v) => ref.read(dbProvider).updateTrackedParameter(
                      param.copyWith(enabled: v)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit zones',
                      onPressed: () => context.push(
                          '/parameters/${param.id}/edit',
                          extra: param),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addParameter(context, ref, tank.id, type,
            trackedAsync.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Add parameter'),
      ),
    );
  }

  Future<void> _addParameter(BuildContext context, WidgetRef ref, int tankId,
      SetupType type, List<TrackedParameter> tracked) async {
    final existing = tracked.map((e) => e.paramKey).toSet();
    final available =
        kReefParameters.where((p) => !existing.contains(p.key)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All parameters are already added.')),
      );
      return;
    }
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final p in available)
            ListTile(
              title: Text(p.name),
              trailing: Text(p.unit,
                  style: TextStyle(color: Theme.of(ctx).hintColor)),
              onTap: () => Navigator.pop(ctx, p.key),
            ),
        ],
      ),
    );
    if (key != null) {
      await ref.read(dbProvider).addTrackedParameter(tankId, key, type);
    }
  }

  Future<void> _confirmApplyPreset(BuildContext context, WidgetRef ref,
      int tankId, SetupType type) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Re-apply ${type.label} preset?'),
        content: const Text(
            'This overwrites the green/amber/red boundaries of all tracked '
            'parameters with the preset defaults. Your readings are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(dbProvider).applyPreset(tankId, type);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preset applied.')),
        );
      }
    }
  }
}

String _boundsSummary(ZoneBounds b, String unit) {
  if (b.isEmpty) return 'No boundaries set';
  String f(double? v) => v == null ? '∞' : v.toString();
  return 'OK ${f(b.greenLow)}–${f(b.greenHigh)} $unit  •  red <${f(b.amberLow)} / >${f(b.amberHigh)}';
}

/// Editor for a single tracked parameter's unit + four zone boundaries.
class ParameterEditScreen extends ConsumerStatefulWidget {
  const ParameterEditScreen({super.key, required this.param});

  final TrackedParameter param;

  @override
  ConsumerState<ParameterEditScreen> createState() =>
      _ParameterEditScreenState();
}

class _ParameterEditScreenState extends ConsumerState<ParameterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unit =
      TextEditingController(text: widget.param.unit);
  late final _amberLow = _ctrl(widget.param.amberLow);
  late final _greenLow = _ctrl(widget.param.greenLow);
  late final _greenHigh = _ctrl(widget.param.greenHigh);
  late final _amberHigh = _ctrl(widget.param.amberHigh);

  TextEditingController _ctrl(double? v) =>
      TextEditingController(text: v?.toString() ?? '');

  @override
  void dispose() {
    _unit.dispose();
    _amberLow.dispose();
    _greenLow.dispose();
    _greenHigh.dispose();
    _amberHigh.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.replaceAll(',', '.'));

  String? _validateOrder() {
    final a = _parse(_amberLow);
    final g = _parse(_greenLow);
    final gh = _parse(_greenHigh);
    final ah = _parse(_amberHigh);
    final seq = [a, g, gh, ah].whereType<double>().toList();
    for (var i = 1; i < seq.length; i++) {
      if (seq[i] < seq[i - 1]) {
        return 'Boundaries must increase: amber low ≤ green low ≤ green high ≤ amber high.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final orderError = _validateOrder();
    if (orderError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(orderError)));
      return;
    }
    await ref.read(dbProvider).updateTrackedParameter(widget.param.copyWith(
          unit: _unit.text.trim(),
          amberLow: Value(_parse(_amberLow)),
          greenLow: Value(_parse(_greenLow)),
          greenHigh: Value(_parse(_greenHigh)),
          amberHigh: Value(_parse(_amberHigh)),
        ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final def = kParameterByKey[widget.param.paramKey];
    return Scaffold(
      appBar: AppBar(title: Text(def?.name ?? widget.param.paramKey)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (def?.help != null) ...[
              Text(def!.help!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 24),
            _ZoneLegendRow(),
            const SizedBox(height: 8),
            _boundField(_amberLow, 'Red below (amber low)', Zone.red),
            _boundField(_greenLow, 'Green from (OK low)', Zone.green),
            _boundField(_greenHigh, 'Green to (OK high)', Zone.green),
            _boundField(_amberHigh, 'Red above (amber high)', Zone.red),
            const SizedBox(height: 8),
            Text(
              'Leave a field blank to mean "no limit on that side".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundField(TextEditingController c, String label, Zone zone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.circle, color: zone.color, size: 14),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 0),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          return double.tryParse(v.replaceAll(',', '.')) == null
              ? 'Enter a number'
              : null;
        },
      ),
    );
  }
}

class _ZoneLegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Zone z, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: z.color, size: 12),
            const SizedBox(width: 4),
            Text(label),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        dot(Zone.green, 'OK'),
        dot(Zone.amber, 'Attention'),
        dot(Zone.red, 'Act now'),
      ],
    );
  }
}
