import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import 'dosing_screen.dart' show dosingDetailLine, formatDoseAmount;

/// Timeline of every dosing event for the active tank — plan segments (current
/// and past) merged with logged one-off manual doses, newest first. Manual
/// doses are logged from the FAB, can be edited by tapping, and each record
/// can be permanently deleted if it was entered by mistake (distinct from
/// stopping a supplement, which soft-ends and is kept as history).
///
/// Layout per REDESIGN #21: the timeline collapses into one `ReefSliverCard`
/// of hairline-divided rows (#11 pattern) — type icon, title +
/// "Current"/"Manual" tag (neutral `track`/`textDim` fill: lifecycle markers,
/// not zone status), mono dose line, trailing delete.
class DosingHistoryScreen extends ConsumerWidget {
  const DosingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(dosingHistoryProvider).value ?? const [];
    final manual = ref.watch(manualDosesProvider).value ?? const [];

    // One date-sorted timeline: segments key on when they began, manual doses
    // on when they were given. Both source lists arrive newest-first.
    final items = <_TimelineItem>[
      for (final e in entries) _SegmentItem(e),
      for (final d in manual) _ManualItem(d),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(title: Text(l.dosingHistoryTitle)),
      body: items.isEmpty
          ? _EmptyState(l: l)
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  sliver: ReefSliverCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 10,
                    ),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final isLast = i == items.length - 1;
                        return switch (items[i]) {
                          _SegmentItem(entry: final e) => _HistoryRow(
                            entry: e,
                            all: entries,
                            isLast: isLast,
                          ),
                          _ManualItem(dose: final d) => _ManualDoseRow(
                            dose: d,
                            isLast: isLast,
                          ),
                        };
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.manualDoseNew),
        onPressed: () => context.push('/dosing/manual'),
      ),
    );
  }
}

/// One row of the merged timeline, ordered by [timestamp] (newest first).
sealed class _TimelineItem {
  DateTime get timestamp;
}

class _SegmentItem extends _TimelineItem {
  _SegmentItem(this.entry);
  final DosingEntry entry;
  @override
  DateTime get timestamp => entry.startedAt ?? entry.createdAt;
}

class _ManualItem extends _TimelineItem {
  _ManualItem(this.dose);
  final ManualDose dose;
  @override
  DateTime get timestamp => dose.dosedAt;
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
            Icon(
              Icons.history,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
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

/// Shared row shell for both timeline row kinds (#11 pattern): top-aligned
/// type icon, content column, trailing delete — with the hairline divider and
/// the transparent [Material] the sliver card's rows need for ink.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.tags,
    required this.lines,
    required this.onDelete,
    this.onTap,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final List<Widget> tags;
  final List<Widget> lines;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: tokens.surfaceBorder),
                  ),
                ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 18, color: tokens.textDim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.text,
                            ),
                          ),
                        ),
                        for (final tag in tags) ...[
                          const SizedBox(width: 8),
                          tag,
                        ],
                      ],
                    ),
                    ...lines,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: tokens.textDim,
                ),
                tooltip: l.delete,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.entry,
    required this.all,
    required this.isLast,
  });

  final DosingEntry entry;

  /// The full history list, used to decide whether this is the most recent
  /// segment for its element (drives the delete warning).
  final List<DosingEntry> all;

  final bool isLast;

  bool get _active => DosingState.fromName(entry.state) == DosingState.active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final names = resolveSupplementNames(
      productKey: entry.productKey,
      storedVendor: entry.vendor,
      storedProgram: entry.program,
      storedProduct: entry.product,
    );
    final source = [
      names.vendor,
      names.program,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return _TimelineRow(
      icon: _active ? Icons.play_circle_outline : Icons.history,
      title: names.product,
      tags: [
        if (entry.elementKey != null)
          _Tag(label: l.paramName(entry.elementKey!)),
        if (_active) _Tag(label: l.dosingHistoryCurrent),
      ],
      lines: [
        if (source.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            source,
            style: TextStyle(fontSize: 12.5, color: tokens.textDim),
          ),
        ],
        const SizedBox(height: 3),
        Text(
          dosingDetailLine(context, l, entry),
          style: ReefTokens.monoTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _period(context, l),
          style: TextStyle(
            fontSize: 12,
            color: _active ? tokens.primary : tokens.textDim,
          ),
        ),
      ],
      onDelete: () => _confirmDelete(context, ref, l),
      isLast: isLast,
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
    return all.any(
      (e) =>
          e.id != entry.id &&
          e.elementKey == key &&
          (e.startedAt ?? e.createdAt).isAfter(mine),
    );
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

/// Timeline row for a logged one-off manual dose. Tap to edit; the trailing
/// icon permanently deletes (no soft-end — events don't chain like segments).
class _ManualDoseRow extends ConsumerWidget {
  const _ManualDoseRow({required this.dose, required this.isLast});

  final ManualDose dose;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final loc = MaterialLocalizations.of(context);
    final names = resolveSupplementNames(
      productKey: dose.productKey,
      storedVendor: dose.vendor,
      storedProgram: dose.program,
      storedProduct: dose.product,
    );
    final source = [
      names.vendor,
      names.program,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    final unit = DoseUnit.fromName(dose.amountUnit);
    final when =
        '${loc.formatMediumDate(dose.dosedAt)} '
        '${TimeOfDay.fromDateTime(dose.dosedAt).format(context)}';

    return _TimelineRow(
      icon: Icons.vaccines_outlined,
      title: names.product,
      tags: [
        if (dose.elementKey != null)
          _Tag(label: l.paramName(dose.elementKey!)),
        _Tag(label: l.dosingHistoryManual),
      ],
      lines: [
        if (source.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            source,
            style: TextStyle(fontSize: 12.5, color: tokens.textDim),
          ),
        ],
        const SizedBox(height: 3),
        Text(
          '${formatDoseAmount(dose.amount)} ${unit.symbol} · $when',
          style: ReefTokens.monoTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        if (dose.note != null && dose.note!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            dose.note!,
            style: TextStyle(fontSize: 12, color: tokens.textDim),
          ),
        ],
      ],
      onTap: () => context.push('/dosing/manual', extra: dose),
      onDelete: () => _confirmDelete(context, ref, l),
      isLast: isLast,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteManualDoseTitle),
        content: Text(l.deleteManualDoseBody),
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
    if (ok == true) await ref.read(dbProvider).deleteManualDose(dose.id);
  }
}

/// Lifecycle/element tag on a timeline row (§A.6 tag geometry: 11 w600,
/// padding 4·10, r10). Deliberately neutral — `track` fill, `textDim` text —
/// these mark record kinds, not zone status (REDESIGN #21).
class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.textDim,
        ),
      ),
    );
  }
}
