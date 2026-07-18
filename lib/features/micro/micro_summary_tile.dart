import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/micro.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/zone_visuals.dart';

/// Dashboard card summarizing the microelement panel (U17) — the feature's
/// front door. Headline: "N out of range" in the dominant deviation zone's
/// color (see `computeMicroStatus`), or "All within range"; "No readings"
/// before the first measurement. Tapping opens `/micro`.
///
/// Default form (REDESIGN #10): the mockup list-card — leading icon in a
/// dominant-zone soft rounded square, title / headline / date column,
/// trailing chevron — rendered full-width by the grouped dashboard. The
/// classic flat grid passes [grid] for the frozen pre-redesign vertical tile.
class MicroSummaryTile extends ConsumerWidget {
  const MicroSummaryTile({super.key, this.grid = false});

  /// Classic-layout grid-cell variant (title / headline / timestamp stacked
  /// to match the flat measurement tiles). The grouped layout leaves this
  /// false — redesign phases target the grouped layout only.
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = ref.watch(microStatusProvider);

    if (grid) return _gridTile(context, l, status);

    final tokens = ReefTokens.of(context);
    final zone = status.statusZone;
    final headline = status.measured == 0
        ? l.noReadings
        : status.outOfRange > 0
        ? l.microOutOfRangeN(status.outOfRange)
        : l.microAllOk;

    // §A.6 micro card: 34 px r10 icon chip in the dominant zone's soft color,
    // title 13 w700, headline 14 w700 in the dominant color, date 11 faint,
    // 16 px chevron. Unknown zone (no readings) renders neutrally via the
    // zone visuals' track/textFaint mapping.
    return ReefCard(
      onTap: () => context.push('/micro'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: zone.softColorOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.science_outlined,
              size: 16,
              color: zone.colorOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.microTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: status.measured == 0
                        ? tokens.textFaint
                        : zone.colorOf(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  status.lastMeasuredAt == null
                      ? '—'
                      : relativeTimeLabel(l, status.lastMeasuredAt!),
                  style: TextStyle(fontSize: 11, color: tokens.textFaint),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: tokens.textFaint),
        ],
      ),
    );
  }

  /// The pre-redesign vertical grid tile, unchanged (classic layout).
  Widget _gridTile(BuildContext context, AppLocalizations l, MicroStatus status) {
    final hint = Theme.of(context).hintColor;
    // Same as the other dashboard tiles: no margin, the grid owns all spacing.
    return ReefCard(
      onTap: () => context.push('/micro'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.microTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          if (status.measured == 0)
            Text(l.noReadings, style: TextStyle(color: hint))
          else
            Text(
              status.outOfRange > 0
                  ? l.microOutOfRangeN(status.outOfRange)
                  : l.microAllOk,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: status.statusZone.colorOf(context),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            status.lastMeasuredAt == null
                ? '—'
                : relativeTimeLabel(l, status.lastMeasuredAt!),
            style: TextStyle(fontSize: 11, color: hint),
          ),
        ],
      ),
    );
  }
}
