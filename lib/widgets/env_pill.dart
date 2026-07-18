import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/trend.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import 'reef_card.dart';
import 'trend_view.dart';
import 'zone_visuals.dart';

/// Compact dashboard pill for one environment parameter (REDESIGN #9, §A.5):
/// zone status dot, uppercase label, mono value+unit, small delta, and the
/// existing [TrendChip] forecast as the optional urgency line. The zone lives
/// in the dot — the value stays in the plain `text` color.
///
/// Pure widget like `ParamGaugeCard`: callers map DB rows to plain values.
/// Tap → the parameter's history, wired by the dashboard.
class EnvPill extends StatelessWidget {
  const EnvPill({
    super.key,
    required this.title,
    required this.pres,
    this.zone = Zone.unknown,
    this.latest,
    this.previous,
    this.trend,
    this.horizonDays = kTrendDefaultHorizon,
    this.onTap,
  });

  /// Localized parameter name (rendered uppercase).
  final String title;

  final ParamPresentation pres;
  final Zone zone;

  /// Latest / previous reading values (canonical); null = no readings yet.
  final double? latest;
  final double? previous;

  final TrendResult? trend;
  final int horizonDays;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return ReefCard(
      onTap: onTap,
      // §A.5: pills are r16 in the mock's iOS frame — same as the M3 card
      // radius, so one fixed radius serves both dialects.
      radius: 16,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      child: Column(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: zone.colorOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 9.5 * 0.03,
              color: tokens.textDim,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              latest != null
                  ? '${pres.format(latest!)} ${pres.unitLabel}'
                  : '—',
              style: ReefTokens.monoTextStyle.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: latest != null ? tokens.text : tokens.textFaint,
              ),
            ),
          ),
          if (latest != null && previous != null) ...[
            const SizedBox(height: 3),
            Text(
              pres.formatChange(latest!, previous!),
              style: ReefTokens.monoTextStyle.copyWith(
                fontSize: 9,
                color: tokens.textFaint,
              ),
            ),
          ],
          if (trend != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TrendChip(trend: trend!, horizonDays: horizonDays),
            ),
        ],
      ),
    );
  }
}
