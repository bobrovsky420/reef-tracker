import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/setup_type.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Lists all aquariums with add / edit / delete / switch actions.
class TanksScreen extends ConsumerWidget {
  const TanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);
    final active = ref.watch(activeTankProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.aquariums)),
      body: tanksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tanks) {
          if (tanks.isEmpty) {
            return Center(child: Text(l.noAquariumsYet));
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
                subtitle: Text([
                  l.setupLabel(type),
                  if (t.volumeLiters != null)
                    l.litersSuffix(t.volumeLiters!.toStringAsFixed(0)),
                  if (t.startDate != null)
                    l.sinceDate(DateFormat.yMMMd().format(t.startDate!)),
                ].join(' • ')),
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
                      PopupMenuItem(
                          value: 'activate', child: Text(l.makeActive)),
                    PopupMenuItem(value: 'edit', child: Text(l.edit)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
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
        label: Text(l.addAquarium),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Tank tank) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTankTitle(tank.name)),
        content: Text(l.deleteTankBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
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
  late DateTime? _startDate = widget.tank?.startDate;
  bool _saving = false;

  bool get _isEdit => widget.tank != null;

  @override
  void dispose() {
    _name.dispose();
    _volume.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
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
        startDate: Value(_startDate),
      ));
    } else {
      await db.createTankWithPreset(
        name: _name.text.trim(),
        type: _type,
        volumeLiters: volume,
        startDate: _startDate,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l.editAquarium : l.newAquarium)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: l.name, hintText: l.nameHint),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.enterAName : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SetupType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l.setupType),
              items: [
                for (final t in SetupType.values)
                  DropdownMenuItem(value: t, child: Text(l.setupLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 8),
            if (!_isEdit)
              Text(l.presetSeedNote,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volume,
              decoration: InputDecoration(labelText: l.volumeOptional),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.startDate),
              subtitle: Text(_startDate == null
                  ? l.notSet
                  : DateFormat.yMMMd().format(_startDate!)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_startDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l.clear,
                      onPressed: () => setState(() => _startDate = null),
                    ),
                  TextButton(
                    onPressed: _pickStartDate,
                    child: Text(_startDate == null ? l.setDate : l.change),
                  ),
                ],
              ),
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
              label: Text(_isEdit ? l.save : l.createAquarium),
            ),
          ],
        ),
      ),
    );
  }
}
