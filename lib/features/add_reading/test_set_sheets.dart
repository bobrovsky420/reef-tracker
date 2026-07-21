import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_sheet.dart';

/// Bottom sheets for creating, editing and managing test sets (U9) — the named
/// parameter subsets whose chips filter the Add Reading form.

/// Opens the create/edit sheet for a test set. Pass [template] to edit an
/// existing set; otherwise a new one is created with [initialKeys] pre-checked
/// (the Add Reading screen passes the parameters that currently hold typed
/// values — "save what I just tested as a set"). Returns the saved set's id,
/// or null if the sheet was dismissed.
Future<int?> showTestSetEditSheet(
  BuildContext context, {
  required AppDatabase db,
  required int tankId,
  required List<TrackedParameter> params,
  ReadingTemplate? template,
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
      child: _TestSetEditSheet(
        db: db,
        tankId: tankId,
        params: params,
        template: template,
        initialKeys: initialKeys,
      ),
    ),
  );
}

/// Opens the management sheet listing every test set of the active tank with
/// edit / delete / drag-reorder, plus a create entry. This is the accessible
/// path to editing (the chip long-press is only a shortcut, #45 precedent).
Future<void> showTestSetsManageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => const _TestSetsManageSheet(),
  );
}

class _TestSetEditSheet extends StatefulWidget {
  const _TestSetEditSheet({
    required this.db,
    required this.tankId,
    required this.params,
    this.template,
    this.initialKeys = const {},
  });

  final AppDatabase db;
  final int tankId;

  /// The tank's *enabled* tracked parameters, in display order — the checkbox
  /// list. Keys of [template] outside this list (disabled/untracked meanwhile)
  /// are not shown but are preserved on save, so a set survives parameter
  /// churn (see [ReadingTemplates]).
  final List<TrackedParameter> params;
  final ReadingTemplate? template;
  final Set<String> initialKeys;

  @override
  State<_TestSetEditSheet> createState() => _TestSetEditSheetState();
}

class _TestSetEditSheetState extends State<_TestSetEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final Set<String> _checked;
  bool _needParam = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    final enabledKeys = {for (final p in widget.params) p.paramKey};
    _checked = widget.template == null
        ? widget.initialKeys.intersection(enabledKeys)
        : widget.template!.keys.toSet().intersection(enabledKeys);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    final needParam = _checked.isEmpty;
    setState(() => _needParam = needParam);
    if (!valid || needParam) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final name = _nameCtrl.text.trim();
    // Checked keys in the tank's display order, plus the edited set's unshown
    // (disabled/untracked) keys so they are preserved, not silently dropped.
    final enabledKeys = {for (final p in widget.params) p.paramKey};
    final keys = [
      for (final p in widget.params)
        if (_checked.contains(p.paramKey)) p.paramKey,
      ...?widget.template?.keys.where((k) => !enabledKeys.contains(k)),
    ];
    try {
      final int id;
      if (widget.template == null) {
        id = await widget.db.insertReadingTemplate(
          tankId: widget.tankId,
          name: name,
          paramKeys: keys,
        );
      } else {
        id = widget.template!.id;
        await widget.db.updateReadingTemplate(id, name: name, paramKeys: keys);
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ReefSheetHeader(
                widget.template == null ? l.newTestSet : l.editTestSet,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.name,
                  hintText: l.testSetNameHint,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.enterAName : null,
              ),
              const SizedBox(height: 8),
              for (final p in widget.params)
                // Adaptive + explicit token accent (REDESIGN #18): the
                // Cupertino-shaped checkbox ignores Material theming and
                // would fall back to iOS system blue; passing the tokens is
                // dialect-free (on M3 they equal the ColorScheme defaults).
                CheckboxListTile.adaptive(
                  value: _checked.contains(p.paramKey),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: ReefTokens.of(context).primary,
                  checkColor: ReefTokens.of(context).onPrimary,
                  title: Text(l.paramName(p.paramKey)),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _checked.add(p.paramKey);
                      _needParam = false;
                    } else {
                      _checked.remove(p.paramKey);
                    }
                  }),
                ),
              if (_needParam)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.testSetNeedParam,
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

class _TestSetsManageSheet extends ConsumerWidget {
  const _TestSetsManageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tank = ref.watch(activeTankProvider);
    final templates =
        ref.watch(readingTemplatesProvider).value ?? const <ReadingTemplate>[];
    final tracked =
        ref.watch(trackedParametersProvider).value ??
        const <TrackedParameter>[];
    final params = [
      for (final p in tracked)
        if (p.enabled) p,
    ];
    final enabledKeys = {for (final p in params) p.paramKey};

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
            child: ReefSheetHeader(l.manageTestSets),
          ),
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.noTestSets, style: theme.textTheme.bodyMedium),
            )
          else
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                onReorderItem: (oldIndex, newIndex) {
                  final ids = [for (final t in templates) t.id];
                  ids.insert(newIndex, ids.removeAt(oldIndex));
                  unawaited(ref.read(dbProvider).reorderReadingTemplates(ids));
                },
                itemBuilder: (context, i) {
                  final t = templates[i];
                  final tokens = ReefTokens.of(context);
                  // Count what the chip will actually show: keys still
                  // tracked+enabled (a set may carry keys disabled meanwhile).
                  final count = t.keys.where(enabledKeys.contains).length;
                  // #11 row pattern (REDESIGN #20): title + count sub,
                  // inline edit/delete icons, 16 px drag handle, hairline
                  // dividers between rows.
                  return Container(
                    key: ValueKey(t.id),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    decoration: i == templates.length - 1
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
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.testSetParamCount(count),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: tokens.textDim,
                          ),
                          tooltip: l.edit,
                          onPressed: tank == null
                              ? null
                              : () => showTestSetEditSheet(
                                  context,
                                  db: ref.read(dbProvider),
                                  tankId: tank.id,
                                  params: params,
                                  template: t,
                                ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: tokens.textDim,
                          ),
                          tooltip: l.delete,
                          onPressed: () => _confirmDelete(context, ref, t),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          // The padding keeps the 16 px glyph draggable
                          // with a finger.
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: tokens.textFaint,
                              semanticLabel: l.reorder,
                            ),
                          ),
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
              title: Text(l.newTestSet),
              onTap: tank == null
                  ? null
                  : () => showTestSetEditSheet(
                      context,
                      db: ref.read(dbProvider),
                      tankId: tank.id,
                      params: params,
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
    ReadingTemplate t,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTestSetTitle(t.name)),
        content: Text(l.deleteTestSetBody),
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
      await ref.read(dbProvider).deleteReadingTemplate(t.id);
    }
  }
}
