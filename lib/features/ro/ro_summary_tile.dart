import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/ro.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/zone_visuals.dart';
import '../actions/schedule_screen.dart' show dueText;

/// One-line summary of the shared RO unit, shown on every tank's Actions tab
/// (the unit serves all aquariums, so it is legitimately relevant on each) —
/// the feature's front door. Tapping opens `/ro`.
///
/// Subtitle priority: the most urgent amber/red stage → "no replacement
/// recorded yet" while any enabled stage lacks its anchor → "all parts OK" →
/// the set-up prompt when the feature is untouched or every stage is hidden.
class RoSummaryTile extends ConsumerWidget {
  const RoSummaryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Feature switch (Settings): hidden entirely when the user has no RO
    // unit to track. Data stays; re-enabling brings everything back.
    if (!(ref.watch(roUnitEnabledProvider).value ?? true)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final statuses = ref.watch(roStageStatusProvider);
    final enabled = [
      for (final s in statuses)
        if (s.stage.enabled) s,
    ];

    String subtitle;
    Color? color;
    if (enabled.isEmpty) {
      subtitle = l.roSetupPrompt;
    } else {
      RoStageStatus? worst;
      var missingAnchor = false;
      for (final s in enabled) {
        final due = s.due;
        if (due == null) {
          missingAnchor = true;
        } else if (worst == null || due.daysLeft < worst.due!.daysLeft) {
          worst = s;
        }
      }
      if (worst == null) {
        subtitle = l.roNoReplacementYet;
      } else {
        final zone = roStageZone(
          daysLeft: worst.due!.daysLeft,
          lifespanDays: worst.stage.lifespanDays,
        );
        if (zone == Zone.green) {
          subtitle = missingAnchor ? l.roNoReplacementYet : l.roAllOk;
        } else {
          subtitle =
              '${l.roStageName(worst.stage.stageType, worst.stage.title)}'
              ' • ${dueText(l, worst.due!)}';
          color = zone == Zone.red ? zone.color : null;
        }
      }
    }

    return ListTile(
      leading: Icon(Icons.water_drop_outlined, color: color),
      title: Text(l.roUnitTitle),
      subtitle: Text(
        subtitle,
        style: color == null ? null : TextStyle(color: color),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: () => context.push('/ro'),
    );
  }
}
