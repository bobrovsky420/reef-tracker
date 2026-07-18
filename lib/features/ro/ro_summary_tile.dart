import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/ro.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/zone_visuals.dart';
import '../actions/schedule_screen.dart' show dueText;

/// Summary card of the shared RO unit, shown on every tank's Actions tab
/// (the unit serves all aquariums, so it is legitimately relevant on each) —
/// the feature's front door. Tapping opens `/ro`.
///
/// Subtitle priority: the most urgent amber/red stage → "no replacement
/// recorded yet" while any enabled stage lacks its anchor → "all parts OK" →
/// the set-up prompt when the feature is untouched or every stage is hidden.
///
/// Rendered per REDESIGN #11: when the worst stage is amber/red the card is
/// the mockup's equipment alert (soft status fill + status border, status-
/// colored icon chip and subtitle); otherwise a normal quiet card.
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
    // Green/unknown render the quiet card; amber/red the alert variant.
    var zone = Zone.unknown;
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
        final worstZone = roStageZone(
          daysLeft: worst.due!.daysLeft,
          lifespanDays: worst.stage.lifespanDays,
        );
        if (worstZone == Zone.green) {
          subtitle = missingAnchor ? l.roNoReplacementYet : l.roAllOk;
        } else {
          subtitle =
              '${l.roStageName(worst.stage.stageType, worst.stage.title)}'
              ' · ${dueText(l, worst.due!)}';
          zone = worstZone;
        }
      }
    }

    final tokens = ReefTokens.of(context);
    final alert = zone == Zone.amber || zone == Zone.red;
    final statusColor = zone.colorOf(context);
    final softColor = zone.softColorOf(context);

    return ReefCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      color: alert ? softColor : null,
      borderColor: switch (zone) {
        Zone.red => tokens.criticalBorder,
        Zone.amber => tokens.cautionBorder,
        _ => null,
      },
      onTap: () => context.push('/ro'),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: alert ? softColor : tokens.track,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.water_drop_outlined,
              size: 17,
              color: alert ? statusColor : tokens.textDim,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.roUnitTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: alert
                      ? TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        )
                      : TextStyle(fontSize: 12.5, color: tokens.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right, size: 16, color: tokens.textFaint),
        ],
      ),
    );
  }
}
