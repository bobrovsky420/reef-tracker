import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/trend.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';

/// Beyond this many days a forecast isn't actionable enough to clutter a small
/// dashboard tile with; the full history card still shows it.
const double kTrendTileHorizonDays = 60;

IconData _directionIcon(TrendDirection d) {
  switch (d) {
    case TrendDirection.rising:
      return Icons.trending_up;
    case TrendDirection.falling:
      return Icons.trending_down;
    case TrendDirection.flat:
      return Icons.trending_flat;
  }
}

/// Rounds a positive day estimate to a whole number, never below 1 ("~1 d").
int _days(double v) => math.max(1, v.round());

/// The slope in the user's display unit per day, signed (e.g. "+0.25"). The
/// conversion is affine so the per-day delta is `toDisplay(slope) -
/// toDisplay(0)`, independent of the current value.
String _signedRate(TrendResult t, ParamPresentation pres) {
  final disp = pres.toDisplay(t.slopePerDay) - pres.toDisplay(0);
  final s = disp.abs().toStringAsFixed(pres.decimals);
  if (disp > 0) return '+$s';
  if (disp < 0) return '−$s';
  return s;
}

/// Full recent-trend block shown under the history chart: the per-day rate plus
/// any projected amber/red crossings, or a "holding steady / within range" note.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.trend, required this.pres});

  final TrendResult trend;
  final ParamPresentation pres;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.hintColor;
    final rate = l.trendRatePerDay('${_signedRate(trend, pres)} ${pres.unitLabel}');

    final lines = <Widget>[];
    if (trend.daysToAmber != null) {
      lines.add(_forecastLine(
          l.trendAmberInDays(_days(trend.daysToAmber!)), Zone.amber.color));
    }
    if (trend.daysToRed != null) {
      lines.add(_forecastLine(
          l.trendRedInDays(_days(trend.daysToRed!)), Zone.red.color));
    }
    if (lines.isEmpty) {
      lines.add(Text(
        trend.direction == TrendDirection.flat
            ? l.trendFlat
            : l.trendWithinRange,
        style: TextStyle(color: hint),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_directionIcon(trend.direction), color: hint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.trendTitle,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(rate, style: TextStyle(color: hint)),
                ...lines,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _forecastLine(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      );
}

/// Compact dashboard-tile forecast: the soonest threshold the value is heading
/// for, within the actionable horizon. Renders nothing otherwise.
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.trend});

  final TrendResult trend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final String text;
    final Color color;
    if (trend.daysToAmber != null && trend.daysToAmber! <= kTrendTileHorizonDays) {
      text = l.trendChipAmber(_days(trend.daysToAmber!));
      color = Zone.amber.color;
    } else if (trend.daysToRed != null &&
        trend.daysToRed! <= kTrendTileHorizonDays) {
      text = l.trendChipRed(_days(trend.daysToRed!));
      color = Zone.red.color;
    } else {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_directionIcon(trend.direction), size: 13, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
