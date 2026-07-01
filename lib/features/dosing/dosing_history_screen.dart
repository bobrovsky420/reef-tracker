import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import 'dosing_screen.dart' show dosingDetailLine;

/// Read-only timeline of every dosing segment for the active tank — current and
/// past (superseded/stopped) — reached from the Dosing tab's app bar. Each
/// record can be permanently deleted if it was entered by mistake (distinct from
/// stopping a supplement, which soft-ends and is kept as history).
class DosingHistoryScreen extends ConsumerWidget {
  const DosingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(dosingHistoryProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l.dosingHistoryTitle)),
      body: entries.isEmpty
          ? _EmptyState(l: l)
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _HistoryTile(entry: entries[i], all: entries),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              l.dosingHistoryEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry, required this.all});

  final DosingEntry entry;

  /// The full history list, used to decide whether this is the most recent
  /// segment for its element (drives the delete warning).
  final List<DosingEntry> all;

  bool get _active => DosingState.fromName(entry.state) == DosingState.active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final names = resolveSupplementNames(
      productKey: entry.productKey,
      storedVendor: entry.vendor,
      storedProgram: entry.program,
      storedProduct: entry.product,
    );
    final source = [names.vendor, names.program]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: Icon(_active ? Icons.play_circle_outline : Icons.history),
      title: Text(names.product),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (entry.elementKey != null)
                _Chip(label: l.paramName(entry.elementKey!)),
              if (_active)
                _Chip(label: l.dosingHistoryCurrent, highlight: true),
            ],
          ),
          if (source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(source,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      )),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(dosingDetailLine(context, l, entry)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _period(context, l),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _active ? scheme.primary : scheme.outline,
                  ),
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l.delete,
        onPressed: () => _confirmDelete(context, ref, l),
      ),
    );
  }

  String _period(BuildContext context, AppLocalizations l) {
    final loc = MaterialLocalizations.of(context);
    final from = entry.startedAt ?? entry.createdAt;
    final fromStr = loc.formatMediumDate(from);
    if (_active || entry.endedAt == null) return l.dosingHistorySince(fromStr);
    return l.dosingHistoryPeriod(fromStr, loc.formatMediumDate(entry.endedAt!));
  }

  /// Whether another segment for the same element started later than this one.
  bool get _notLatestForElement {
    final key = entry.elementKey;
    if (key == null) return false;
    final mine = entry.startedAt ?? entry.createdAt;
    return all.any((e) =>
        e.id != entry.id &&
        e.elementKey == key &&
        (e.startedAt ?? e.createdAt).isAfter(mine));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final body = _notLatestForElement
        ? '${l.deleteDosingRecordBody}\n\n${l.deleteDosingRecordNotLatest}'
        : l.deleteDosingRecordBody;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteDosingRecordTitle),
        content: Text(body),
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
    if (ok == true) await ref.read(dbProvider).deleteDosingEntry(entry.id);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.highlight = false});
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight ? scheme.primaryContainer : scheme.secondaryContainer;
    final fg =
        highlight ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
