import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/zone_visuals.dart';

/// Dashboard grid tile summarizing the microelement panel (U17) — the
/// feature's front door, laid out like the measurement/ratio tiles (title,
/// headline, timestamp) and pinned after them. Headline: "N out of range"
/// in the dominant deviation zone's color (see `computeMicroStatus`), or
/// "All within range"; "No readings" before the first measurement. Tapping
/// opens `/micro`.
class MicroSummaryTile extends ConsumerWidget {
  const MicroSummaryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final status = ref.watch(microStatusProvider);

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
