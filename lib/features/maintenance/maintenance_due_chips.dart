import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/reminders.dart';
import '../../l10n/app_localizations.dart';
import 'maintenance_schedule_presentation.dart';

typedef LogDueMaintenanceAction =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      MaintenanceActionType type,
    );

/// Completes a custom task: stamps it done (or, for a one-off, retires the
/// row), with an Undo SnackBar restoring the captured row verbatim.
Future<void> markMaintenanceDoneWithUndo(
  BuildContext context,
  WidgetRef ref,
  MaintenanceSchedule task,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  if (!maintenanceRepeats(task)) {
    await db.deleteMaintenanceSchedule(task.id);
  } else {
    await db.markMaintenanceDone(task.id, DateTime.now());
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.taskMarkedDone),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => db.restoreMaintenanceSchedule(task),
        ),
      ),
    );
}

/// Horizontally scrollable due chips shown above the Actions log. The caller
/// supplies the typed-action editor so this shared presentation has no screen
/// dependency; custom tasks complete directly through the shared action above.
class MaintenanceDueChips extends ConsumerWidget {
  const MaintenanceDueChips({required this.onTypedDue, super.key});

  final LogDueMaintenanceAction onTypedDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dues = [...ref.watch(maintenanceDueProvider)]
      ..sort((a, b) => a.due.daysLeft.compareTo(b.due.daysLeft));
    if (dues.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          for (final due in dues)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _DueChip(due: due, onTypedDue: onTypedDue),
            ),
        ],
      ),
    );
  }
}

class _DueChip extends ConsumerWidget {
  const _DueChip({required this.due, required this.onTypedDue});

  final MaintenanceDue due;
  final LogDueMaintenanceAction onTypedDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final overdue = due.due.daysLeft < 0;
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final type = MaintenanceActionType.fromName(
              due.schedule.actionType,
            );
            if (type != null) {
              await onTypedDue(context, ref, type);
            } else {
              await markMaintenanceDoneWithUndo(context, ref, due.schedule);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  maintenanceIcon(due.schedule),
                  size: 14,
                  color: overdue ? tokens.critical : tokens.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${maintenanceName(l, due.schedule)}'
                  ' · ${dueText(l, due.due)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: overdue ? tokens.critical : tokens.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
