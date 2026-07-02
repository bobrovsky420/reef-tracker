import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// The Dosing tab body: the active tank's information-only supplement-dosing
/// plan, newest/ordered first, with tap-to-edit and swipe-to-delete. Hosted by
/// `HomeShell`, which owns the scaffold, app bar, bottom nav and the
/// add-supplement FAB.
class DosingBody extends ConsumerWidget {
  const DosingBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(dosingEntriesProvider).value ?? const [];

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l.noDosing,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l.noDosingHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final reordered = [...entries];
        reordered.insert(newIndex, reordered.removeAt(oldIndex));
        ref
            .read(dbProvider)
            .reorderDosingEntries([for (final e in reordered) e.id]);
      },
      itemBuilder: (context, i) => _tile(context, ref, l, entries[i], i),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    DosingEntry e,
    int index,
  ) {
    // Resolve vendor/program/product live from the catalog (via productKey),
    // falling back to the stored snapshot for custom/orphaned entries.
    final names = resolveSupplementNames(
      productKey: e.productKey,
      storedVendor: e.vendor,
      storedProgram: e.program,
      storedProduct: e.product,
    );
    final source = [names.vendor, names.program]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    final detail = dosingDetailLine(context, l, e);
    final lines = [
      if (source.isNotEmpty) source,
      detail,
    ].join('\n');

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.stop_circle_outlined, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmStop(context, ref, l, e),
      child: ListTile(
        // Center the icon over the full tile height (title + detail lines),
        // matching the Actions tiles; otherwise isThreeLine top-aligns it.
        titleAlignment: ListTileTitleAlignment.center,
        leading: const Icon(Icons.science_outlined),
        title: Row(
          children: [
            Expanded(child: Text(names.product)),
            if (e.elementKey != null) ...[
              const SizedBox(width: 8),
              _ElementChip(label: l.paramName(e.elementKey!)),
            ],
          ],
        ),
        subtitle: Text(lines),
        isThreeLine: source.isNotEmpty,
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        onTap: () => context.push('/dosing/edit', extra: e),
      ),
    );
  }

  Future<bool> _confirmStop(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    DosingEntry e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stopDosingTitle),
        content: Text(l.stopDosingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.stop),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await ref.read(dbProvider).stopDosingEntry(e.id);
    return true;
  }
}

/// Builds the localized "dosage • schedule" summary for an entry, falling back
/// to "No dosage set" when neither dosage nor schedule is recorded.
String dosingDetailLine(
  BuildContext context,
  AppLocalizations l,
  DosingEntry e,
) {
  final parts = <String>[];

  if (e.amount != null) {
    final unit = DoseUnit.fromName(e.amountUnit);
    var amount = '${formatDoseAmount(e.amount!)} ${unit.symbol}';
    final basis = DoseBasis.fromName(e.basis);
    if (basis == DoseBasis.perDay) amount = '$amount ${l.dosingPerDay}';
    if (basis == DoseBasis.perDose) amount = '$amount ${l.dosingPerDose}';
    parts.add(amount);
  }

  final freq = DoseFrequency.fromName(e.frequency);
  switch (freq) {
    case DoseFrequency.daily:
      parts.add(l.dosingFreqDaily);
    case DoseFrequency.everyNDays:
      parts.add(l.dosingEveryDaysN(e.intervalDays ?? 0));
    case DoseFrequency.weekly:
      final days = parseWeekdays(e.weekdays);
      if (days.isNotEmpty) parts.add(formatWeekdays(context, days));
    case null:
      break;
  }

  if (e.doseTime != null && e.doseTime!.isNotEmpty) {
    parts.add(formatDoseTime(context, e.doseTime!));
  }

  if (parts.isEmpty) return l.dosingNoDosage;
  return parts.join(' · ');
}

/// Formats a dose amount without a trailing `.0` (e.g. `5`, `2.5`).
String formatDoseAmount(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Parses the stored comma-separated weekday list (1=Mon … 7=Sun).
List<int> parseWeekdays(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final days = raw
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .where((d) => d >= 1 && d <= 7)
      .toList()
    ..sort();
  return days;
}

/// Localized short weekday names (e.g. "Mon, Thu") for [days] (1=Mon … 7=Sun).
String formatWeekdays(BuildContext context, List<int> days) {
  // 2024-01-01 is a Monday; offset by (weekday-1) to reach each day.
  // `narrowWeekdays` is Sunday-first (index 0 = Sun) while DateTime.weekday is
  // 1 = Mon … 7 = Sun, so `% 7` folds Sunday (7) onto index 0.
  final base = DateTime(2024, 1, 1);
  return days
      .map((d) => MaterialLocalizations.of(context)
          .narrowWeekdays[base.add(Duration(days: d - 1)).weekday % 7])
      .join(', ');
}

/// Renders a stored `HH:mm` time using the device's 12/24-hour preference.
String formatDoseTime(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay(hour: h, minute: m));
}

class _ElementChip extends StatelessWidget {
  const _ElementChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
      ),
    );
  }
}
