import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/micro.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_visuals.dart';

/// The microelement panel (U17) for the active tank: every ICP element in
/// catalog order, sectioned the way lab reports group them (major ions /
/// trace elements / contaminants). Each row shows the latest value colored by
/// its zone and links to the standard parameter history; the edit action
/// opens the standard bounds editor (creating the element's tracked row on
/// demand — rows exist only for elements the user has saved or configured).
/// Elements without a reading render muted, advertising what can be tracked.
class MicroScreen extends ConsumerWidget {
  const MicroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.microTitle)),
        body: Center(child: Text(l.noActiveAquarium)),
      );
    }
    final elements = ref.watch(microElementsProvider);
    final status = ref.watch(microStatusProvider);
    final prefs = ref.watch(unitPrefsProvider);

    final sections = <(String, List<MicroElementStatus>)>[
      (
        l.microSectionMajor,
        [
          for (final e in elements)
            if (e.def.category == ParamCategory.major) e,
        ],
      ),
      (
        l.microSectionTrace,
        [
          for (final e in elements)
            if (e.def.category == ParamCategory.trace) e,
        ],
      ),
      (
        l.microSectionContaminants,
        [
          for (final e in elements)
            if (e.def.category == ParamCategory.contaminant) e,
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.microTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_add),
            tooltip: l.microReminderTooltip,
            onPressed: () => _createReminder(context, ref, tank.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _SummaryCard(status: status),
          ),
          for (final (title, items) in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final e in items) _ElementRow(element: e, prefs: prefs),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/micro/add'),
        icon: const Icon(Icons.add),
        label: Text(l.microAddMeasurements),
      ),
    );
  }

  /// Creates a custom maintenance plan reminding the user to test
  /// microelements every N days — reusing the whole maintenance/notification
  /// machinery (U12) instead of a parallel reminder path. The plan appears on
  /// the maintenance schedule like any other task.
  Future<void> _createReminder(
    BuildContext context,
    WidgetRef ref,
    int tankId,
  ) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: '90');
    final formKey = GlobalKey<FormState>();
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.microReminderTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.microReminderHint),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.customDaysLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed = int.tryParse((v ?? '').trim());
                  return (parsed == null || parsed < 1)
                      ? l.invalidIntervalDays
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(ctrl.text.trim()));
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (days == null || !context.mounted) return;
    await ref
        .read(dbProvider)
        .insertMaintenanceSchedule(
          tankId: tankId,
          title: l.microIcpTaskTitle,
          cadenceDays: days,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.microReminderCreated)));
    }
  }
}

/// Panel status header: worst-zone icon, out-of-range headline, newest sample
/// date — the micro panel's own freshness framing (deliberately outside the
/// 30-day core health model; see `domain/micro.dart`).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status});

  final MicroStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final measured = status.measured > 0;
    final color = measured ? status.worstZone.color : hint;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !measured
                        ? l.microEmptyHint
                        : status.outOfRange > 0
                        ? l.microOutOfRangeN(status.outOfRange)
                        : l.microAllOk,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: measured ? color : null,
                      fontWeight: measured ? FontWeight.w600 : null,
                    ),
                  ),
                  if (status.lastMeasuredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.microLastMeasured(formatDate(status.lastMeasuredAt!)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementRow extends ConsumerWidget {
  const _ElementRow({required this.element, required this.prefs});

  final MicroElementStatus element;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final def = element.def;
    final latest = element.latest;
    final pres = presentationForKey(
      def.key,
      element.row?.unit ?? def.unit,
      prefs,
    );
    final zone = latest != null
        ? element.bounds.classify(latest.value)
        : Zone.unknown;

    return ListTile(
      // Localized names carry the element symbol ("Zinc (Zn)") so rows match
      // the symbols on an ICP report.
      title: Text(l.paramName(def.key)),
      subtitle: Text(
        latest == null
            ? l.microNotMeasured
            : relativeTimeLabel(l, latest.takenAt),
        style: TextStyle(color: hint),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (latest != null)
            Text(
              '${pres.format(latest.value)} ${pres.unitLabel}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                // An unclassifiable value (empty/invalid bounds) renders in
                // the default color, not painted as any zone.
                color: zone == Zone.unknown ? null : zone.color,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l.editZones,
            onPressed: () => _editBounds(context, ref),
          ),
        ],
      ),
      onTap: () => context.push('/history/${def.key}'),
    );
  }

  /// Opens the standard bounds editor, creating the element's tracked row
  /// first when it doesn't exist yet (seeded with the catalog defaults by
  /// `addTrackedParameter`).
  Future<void> _editBounds(BuildContext context, WidgetRef ref) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    var row = element.row;
    if (row == null) {
      final db = ref.read(dbProvider);
      await db.addTrackedParameter(
        tank.id,
        element.def.key,
        SetupType.fromName(tank.setupType),
      );
      for (final t in await db.getTrackedParameters(tank.id)) {
        if (t.paramKey == element.def.key) {
          row = t;
          break;
        }
      }
    }
    if (row != null && context.mounted) {
      await context.push('/parameters/${row.id}/edit', extra: row);
    }
  }
}
