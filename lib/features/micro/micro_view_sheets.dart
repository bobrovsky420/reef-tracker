import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/parameter_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Bottom sheets for creating, editing and managing microelement views (U17)
/// — the named element subsets whose chips filter the Microelements screen.
/// Modeled on the test-set sheets (`test_set_sheets.dart`); built-in lab
/// presets are code-side and don't appear here.

/// Opens the create/edit sheet. Pass [view] to edit an existing custom view;
/// otherwise a new one is created with [initialKeys] pre-checked (the screen
/// passes the active view's elements — "start from what I see"). Returns the
/// saved view's id, or null if dismissed.
Future<int?> showMicroViewEditSheet(
  BuildContext context, {
  required AppDatabase db,
  required int tankId,
  MicroView? view,
  Set<String> initialKeys = const {},
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      // Keep the sheet above the soft keyboard while the name is edited.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _MicroViewEditSheet(
        db: db,
        tankId: tankId,
        view: view,
        initialKeys: initialKeys,
      ),
    ),
  );
}

/// Opens the management sheet listing the tank's custom views with edit /
/// delete plus a create entry — the accessible path to editing (the chip
/// long-press is only a shortcut, #45 precedent).
Future<void> showMicroViewsManageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => const _MicroViewsManageSheet(),
  );
}

class _MicroViewEditSheet extends StatefulWidget {
  const _MicroViewEditSheet({
    required this.db,
    required this.tankId,
    this.view,
    this.initialKeys = const {},
  });

  final AppDatabase db;
  final int tankId;
  final MicroView? view;
  final Set<String> initialKeys;

  @override
  State<_MicroViewEditSheet> createState() => _MicroViewEditSheetState();
}

class _MicroViewEditSheetState extends State<_MicroViewEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final Set<String> _checked;
  bool _needElement = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.view?.name ?? '');
    final catalogKeys = {for (final d in kMicroParameters) d.key};
    _checked = widget.view == null
        ? widget.initialKeys.intersection(catalogKeys)
        : widget.view!.keys.toSet().intersection(catalogKeys);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    final needElement = _checked.isEmpty;
    setState(() => _needElement = needElement);
    if (!valid || needElement) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final name = _nameCtrl.text.trim();
    // Checked keys in catalog order, plus any of the edited view's keys the
    // running catalog doesn't know (a backup from a newer app) — preserved,
    // never silently dropped (the test-set rule).
    final catalogKeys = {for (final d in kMicroParameters) d.key};
    final keys = [
      for (final d in kMicroParameters)
        if (_checked.contains(d.key)) d.key,
      ...?widget.view?.keys.where((k) => !catalogKeys.contains(k)),
    ];
    try {
      final int id;
      if (widget.view == null) {
        id = await widget.db.insertMicroView(
          tankId: widget.tankId,
          name: name,
          paramKeys: keys,
        );
      } else {
        id = widget.view!.id;
        await widget.db.updateMicroView(id, name: name, paramKeys: keys);
      }
      navigator.pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sections = <(String, ParamCategory)>[
      (l.microSectionMajor, ParamCategory.major),
      (l.microSectionTrace, ParamCategory.trace),
      (l.microSectionContaminants, ParamCategory.contaminant),
    ];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.view == null ? l.microViewNew : l.microViewEdit,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.name,
                  hintText: l.microViewNameHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.enterAName : null,
              ),
              const SizedBox(height: 8),
              for (final (title, category) in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                for (final d in kMicroParameters)
                  if (d.category == category)
                    CheckboxListTile(
                      value: _checked.contains(d.key),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l.paramName(d.key)),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _checked.add(d.key);
                          _needElement = false;
                        } else {
                          _checked.remove(d.key);
                        }
                      }),
                    ),
              ],
              if (_needElement)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.microViewNeedElement,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicroViewsManageSheet extends ConsumerWidget {
  const _MicroViewsManageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tank = ref.watch(activeTankProvider);
    final views = ref.watch(microViewsProvider).value ?? const <MicroView>[];
    final catalogKeys = {for (final d in kMicroParameters) d.key};

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.microViewManage, style: theme.textTheme.titleLarge),
          ),
          if (views.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.microViewNone, style: theme.textTheme.bodyMedium),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: views.length,
                itemBuilder: (context, i) {
                  final v = views[i];
                  // Count what the view will actually show: keys the running
                  // catalog knows (a view may carry keys from a newer app).
                  final count = v.keys.where(catalogKeys.contains).length;
                  return ListTile(
                    key: ValueKey(v.id),
                    title: Text(v.name),
                    subtitle: Text(l.microViewElementCount(count)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: l.edit,
                          onPressed: tank == null
                              ? null
                              : () => showMicroViewEditSheet(
                                  context,
                                  db: ref.read(dbProvider),
                                  tankId: tank.id,
                                  view: v,
                                ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l.delete,
                          onPressed: () => _confirmDelete(context, ref, v),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            child: ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.microViewNew),
              onTap: tank == null
                  ? null
                  : () => showMicroViewEditSheet(
                      context,
                      db: ref.read(dbProvider),
                      tankId: tank.id,
                      initialKeys:
                          ref.read(microViewSelectionProvider).keys ??
                          catalogKeys,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MicroView v,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.microViewDeleteTitle(v.name)),
        content: Text(l.microViewDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      // Deleting the active view: the stored token dangles and the screen
      // falls back to the full list by design (see _resolveMicroView).
      await ref.read(dbProvider).deleteMicroView(v.id);
    }
  }
}
