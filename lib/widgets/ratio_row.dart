import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/ratio.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'zone_visuals.dart';

/// One row of the grouped dashboard's Ratios card (REDESIGN #8, §A.4): label +
/// zone-colored mono value + small delta over a 6 px linear track with the
/// ideal-range `band` segment and a ringed marker dot at the current value.
///
/// The rows live inside one `ReefCard` (assembled by the dashboard) using the
/// #11 list-row pattern: a transparent [Material] so ink ripples above the
/// card fill; the assembling card interleaves the hairline dividers.
class RatioRow extends StatelessWidget {
  const RatioRow({
    super.key,
    required this.kind,
    required this.points,
    required this.bounds,
    this.stale = false,
    this.onTap,
  });

  final RatioKind kind;

  /// Ratio series (oldest first); empty = "No readings".
  final List<RatioPoint> points;

  /// Effective bounds in the displayed metric space (`ratioBounds`).
  final ZoneBounds bounds;

  /// True when the latest pair of readings is further apart than
  /// `kRatioMaxSkew` (`latestRatio` null while the series isn't): the value
  /// renders muted and the marker is hidden — not a confident current state.
  final bool stale;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final latest = points.isNotEmpty ? points.last : null;
    // Same axis rule as the gauges, over the ratio's effective bounds. Kinds
    // always have defaultBounds, so this is only null for hand-restored
    // partial custom bounds — the row then renders without the track.
    final axis = gaugeAxis(bounds);

    final muted = stale || latest == null;
    final zone = latest != null
        ? ratioZone(kind, bounds, latest.ratio)
        : Zone.unknown;
    final y = latest != null ? ratioChartY(kind, latest.ratio) : double.nan;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l.ratioCardLabel(kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.text,
                      ),
                    ),
                  ),
                  if (latest == null)
                    Text(
                      l.noReadings,
                      style: TextStyle(fontSize: 12, color: tokens.textFaint),
                    )
                  else ...[
                    Text(
                      formatRatioValue(kind, latest.ratio),
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: muted ? tokens.textFaint : zone.colorOf(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _delta(),
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 10,
                        color: tokens.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
              if (axis != null) ...[
                const SizedBox(height: 5),
                _RatioTrack(
                  axis: axis,
                  bounds: bounds,
                  value: !muted && y.isFinite ? y : null,
                  markerColor: zone.colorOf(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Signed change of the displayed metric versus the previous point (§A.4's
  /// small delta), empty when there is no usable pair.
  String _delta() {
    if (points.length < 2) return '';
    final now = ratioChartY(kind, points.last.ratio);
    final prev = ratioChartY(kind, points[points.length - 2].ratio);
    if (!now.isFinite || !prev.isFinite) return '';
    final diff = now - prev;
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
    return '$sign${formatRatioN(diff.abs())}';
  }
}

/// The 6 px linear band track: full-width `track`, `band` segment over the
/// green range, 10 px ringed marker dot at the value's fraction of the axis.
class _RatioTrack extends StatelessWidget {
  const _RatioTrack({
    required this.axis,
    required this.bounds,
    required this.value,
    required this.markerColor,
  });

  final GaugeAxis axis;
  final ZoneBounds bounds;

  /// Displayed-metric value to mark, or null to hide the marker (no readings
  /// / stale pair).
  final double? value;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    // Reuse zoneBands for the green segment (one-sided ranges extend to the
    // track edge), like the gauge dial does.
    final green = zoneBands(bounds, axis.min, axis.max)
        .where((b) => b.zone == Zone.green)
        .toList();

    double fraction(double v) =>
        ((v - axis.min) / (axis.max - axis.min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 2,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (green.isNotEmpty)
                Positioned(
                  left: fraction(green.first.y1) * w,
                  width:
                      (fraction(green.first.y2) - fraction(green.first.y1)) * w,
                  top: 2,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.band,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (value != null)
                Positioned(
                  left: (fraction(value!) * w - 5).clamp(0.0, w - 10),
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: markerColor,
                      border: Border.all(color: tokens.markerRing, width: 2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
