import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_card.dart';
import '../maintenance/maintenance_events.dart';

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

    final items = maintenanceEventAdapters.adaptAll(
      <Object>[...entries, ...manual],
      MaintenanceEventContext(
        context: context,
        l: l,
        units: ref.watch(unitPrefsProvider),
      ),
      actionsFor: (record) {
        final actions = maintenancePersistenceActions(
          ref.read(dbProvider),
          record,
        );
        return record is ManualDose
            ? actions.withEdit(
                () => context.push('/dosing/manual', extra: record),
              )
            : actions;
      },
    );

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
                        final event = items[i];
                        return _DosingEventRow(
                          event: event,
                          allPlans: entries,
                          isLast: isLast,
                        );
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

/// A single history renderer consumes normalized maintenance events. The only
/// record-specific check left here preserves the established warning when an
/// older dosing-plan segment is deleted.
class _DosingEventRow extends StatelessWidget {
  const _DosingEventRow({
    required this.event,
    required this.allPlans,
    required this.isLast,
  });

  final MaintenanceEvent event;
  final List<DosingEntry> allPlans;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return _TimelineRow(
      icon: event.icon,
      title: event.title,
      tags: [for (final tag in event.tags) _Tag(label: tag)],
      lines: [
        if (event.sourceLabel case final source? when source.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(source, style: TextStyle(fontSize: 12.5, color: tokens.textDim)),
        ],
        const SizedBox(height: 3),
        Text(
          event.summary,
          style: ReefTokens.monoTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        if (event.timelineDetail case final detail?) ...[
          const SizedBox(height: 3),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              color: event.detailHighlighted ? tokens.primary : tokens.textDim,
            ),
          ),
        ],
        if (event.note case final note? when note.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(note, style: TextStyle(fontSize: 12, color: tokens.textDim)),
        ],
      ],
      onTap: event.actions.edit,
      onDelete: () => _confirmDelete(context),
      isLast: isLast,
    );
  }

  bool get _notLatestForElement {
    final source = event.source;
    if (source is! DosingEntry || source.elementKey == null) return false;
    final mine = source.startedAt ?? source.createdAt;
    return allPlans.any(
      (entry) =>
          entry.id != source.id &&
          entry.elementKey == source.elementKey &&
          (entry.startedAt ?? entry.createdAt).isAfter(mine),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final action = event.actions.delete;
    if (action == null) return;
    final l = AppLocalizations.of(context);
    final baseBody = event.deleteBody ?? '';
    final body = _notLatestForElement
        ? '$baseBody\n\n${l.deleteDosingRecordNotLatest}'
        : baseBody;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(event.deleteTitle ?? l.delete),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) await action();
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
