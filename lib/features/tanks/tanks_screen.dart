import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/setup_type.dart';

/// Lists all aquariums with add / edit / delete / switch actions.
class TanksScreen extends ConsumerWidget {
  const TanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanksAsync = ref.watch(tanksProvider);
    final active = ref.watch(activeTankProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aquariums')),
      body: tanksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tanks) {
          if (tanks.isEmpty) {
            return const Center(child: Text('No aquariums yet.'));
          }
          return ListView.builder(
            itemCount: tanks.length,
            itemBuilder: (context, i) {
              final t = tanks[i];
              final type = SetupType.fromName(t.setupType);
              final isActive = t.id == active?.id;
              return ListTile(
                leading: Icon(isActive ? Icons.water_drop : Icons.water_drop_outlined,
                    color: isActive ? Theme.of(context).colorScheme.primary : null),
                title: Text(t.name),
                subtitle: Text(
                  '${type.label}${t.volumeLiters != null ? ' • ${t.volumeLiters!.toStringAsFixed(0)} L' : ''}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'activate':
                        ref.read(dbProvider).setActiveTank(t.id);
                      case 'edit':
                        context.push('/tanks/${t.id}/edit', extra: t);
                      case 'delete':
                        await _confirmDelete(context, ref, t);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isActive)
                      const PopupMenuItem(
                          value: 'activate', child: Text('Make active')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => ref.read(dbProvider).setActiveTank(t.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tanks/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add aquarium'),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Tank tank) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${tank.name}"?'),
        content: const Text(
            'This permanently deletes the aquarium and all of its readings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(dbProvider).deleteTank(tank.id);
    }
  }
}

/// Create or edit a tank. Pass an existing [Tank] as `extra` to edit.
class TankEditScreen extends ConsumerStatefulWidget {
  const TankEditScreen({super.key, this.tank});

  final Tank? tank;

  @override
  ConsumerState<TankEditScreen> createState() => _TankEditScreenState();
}

class _TankEditScreenState extends ConsumerState<TankEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.tank?.name ?? '');
  late final TextEditingController _volume = TextEditingController(
      text: widget.tank?.volumeLiters?.toStringAsFixed(0) ?? '');
  late SetupType _type =
      widget.tank != null ? SetupType.fromName(widget.tank!.setupType) : SetupType.mixed;
  bool _saving = false;

  bool get _isEdit => widget.tank != null;

  @override
  void dispose() {
    _name.dispose();
    _volume.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final volume = double.tryParse(_volume.text.replaceAll(',', '.'));
    if (_isEdit) {
      await db.updateTank(widget.tank!.copyWith(
        name: _name.text.trim(),
        setupType: _type.name,
        volumeLiters: Value(volume),
      ));
    } else {
      await db.createTankWithPreset(
        name: _name.text.trim(),
        type: _type,
        volumeLiters: volume,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit aquarium' : 'New aquarium')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'e.g. Living room reef'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SetupType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Setup type'),
              items: [
                for (final t in SetupType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 8),
            if (!_isEdit)
              Text(
                'Default parameters and zone boundaries will be set up for this '
                'setup type. You can fine-tune them anytime.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volume,
              decoration: const InputDecoration(
                  labelText: 'Volume (litres, optional)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Save' : 'Create aquarium'),
            ),
          ],
        ),
      ),
    );
  }
}
