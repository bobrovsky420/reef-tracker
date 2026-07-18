import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/trend.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'reef_card.dart';
import 'trend_view.dart';
import 'zone_visuals.dart';

/// Geometry/typography of the two dial variants (REDESIGN §A.1): L for the
/// core-chemistry section, S for nutrients. Stroke/tick sizes scale from the
/// dial size inside the painter (`s = size / 148`); the overlay font sizes
/// come from this table.
class _GaugeSpec {
  const _GaugeSpec({
    required this.size,
    required this.label,
    required this.labelGap,
    required this.value,
    required this.unit,
    required this.ideal,
    required this.idealGap,
    required this.padding,
    required this.radius,
  });

  final double size;
  final double label;
  final double labelGap;
  final double value;
  final double unit;
  final double ideal;
  final double idealGap;
  final EdgeInsets padding;

  /// Cupertino-dialect card radius (§2.3: dials r22, small dials r18); the
  /// M3 dialect keeps the standard r16 card radius.
  final double radius;

  static const large = _GaugeSpec(
    size: 148,
    label: 12,
    labelGap: 4,
    value: 23,
    unit: 12,
    ideal: 10.5,
    idealGap: 5,
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    radius: 22,
  );

  static const small = _GaugeSpec(
    size: 104,
    label: 9.5,
    labelGap: 2,
    value: 16,
    unit: 9.5,
    ideal: 8.5,
    idealGap: 3,
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    radius: 18,
  );
}

/// Dashboard gauge card for one core-chemistry/nutrient parameter (REDESIGN
/// #7): a 270° dial (track + ideal-range band + zone-colored marker) with the
/// label/value/ideal overlay, a delta + timestamp footer (L only) and the
/// existing [TrendChip] forecast as the urgency line.
///
/// Pure widget: callers map DB rows to plain values and precompute [axis] via
/// `gaugeAxis` — when that returns null (unboundable/invalid bounds) they
/// must render the flat tile instead of this card, never a misleading arc.
class ParamGaugeCard extends StatelessWidget {
  const ParamGaugeCard({
    super.key,
    required this.title,
    required this.pres,
    required this.bounds,
    required this.axis,
    required this.large,
    this.latest,
    this.previous,
    this.takenAt,
    this.trend,
    this.horizonDays = kTrendDefaultHorizon,
    this.onTap,
  });

  /// Localized parameter name (rendered uppercase in the dial).
  final String title;

  final ParamPresentation pres;

  /// Effective zone bounds in canonical units — used for the marker's zone
  /// color and the band placement, exactly `zones.dart#classify`'s source.
  final ZoneBounds bounds;

  /// Rendered axis (canonical), from `gaugeAxis`.
  final GaugeAxis axis;

  /// L (core chemistry) vs S (nutrients) variant.
  final bool large;

  /// Latest / previous reading values (canonical); null = no readings yet
  /// (track + band only, muted overlay, no marker).
  final double? latest;
  final double? previous;

  /// Timestamp of [latest], for the footer's relative time (L only).
  final DateTime? takenAt;

  final TrendResult? trend;
  final int horizonDays;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final spec = large ? _GaugeSpec.large : _GaugeSpec.small;
    final zone = latest != null ? bounds.classify(latest!) : Zone.unknown;

    // The ideal line shows the effective green range (classify's behavior:
    // a missing green bound extends green to the amber bound on that side).
    // Visually it is the bare trimmed-zero range ("7.5–9", "0.02–0.08") —
    // the localized "ideal …" phrase plus full-precision bounds outgrows the
    // S dial in several languages, and the green band already carries the
    // meaning; the phrase stays as the screen-reader label.
    final idealLow = bounds.greenLow ?? bounds.amberLow;
    final idealHigh = bounds.greenHigh ?? bounds.amberHigh;
    String? ideal;
    String? idealSemantics;
    if (idealLow != null && idealHigh != null) {
      final lo = formatLocaleNumberTrim(
        pres.toDisplay(idealLow),
        decimals: pres.decimals,
      );
      final hi = formatLocaleNumberTrim(
        pres.toDisplay(idealHigh),
        decimals: pres.decimals,
      );
      ideal = '$lo–$hi';
      idealSemantics = l.gaugeIdealRange(lo, hi);
    }

    final footerStyle = ReefTokens.monoTextStyle.copyWith(
      fontSize: 10.5,
      color: tokens.textFaint,
    );

    return ReefCard(
      onTap: onTap,
      radius: reefCupertinoDialect(Theme.of(context).platform)
          ? spec.radius
          : null,
      padding: spec.padding,
      child: Column(
        children: [
          // The dial shrinks below its spec size on narrow tiles (2 columns on
          // a small phone) instead of overflowing.
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth.isFinite
                  ? math.min(spec.size, constraints.maxWidth)
                  : spec.size;
              return _GaugeDial(
                size: size,
                spec: spec,
                title: title,
                valueText: latest != null ? pres.format(latest!) : '—',
                unitText: latest != null ? pres.unitLabel : '',
                idealText: ideal,
                idealSemanticsLabel: idealSemantics,
                valueColor: zone.colorOf(context),
                bounds: bounds,
                axis: axis,
                value: latest,
                markerColor: zone.colorOf(context),
              );
            },
          ),
          if (large) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  previous != null && latest != null
                      ? pres.formatChange(latest!, previous!)
                      : '',
                  style: footerStyle,
                ),
                const Spacer(),
                Text(
                  takenAt != null ? relativeTimeLabel(l, takenAt!) : '—',
                  style: footerStyle,
                ),
              ],
            ),
          ],
          if (trend != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TrendChip(trend: trend!, horizonDays: horizonDays),
            ),
        ],
      ),
    );
  }
}

/// The square dial: painter + centered text overlay. Each overlay line
/// renders at the spec's font size and scales *down* (never up), per line,
/// when it doesn't fit the dial's center — long names, wide values, or large
/// system font scales; the readings list and history screen carry the
/// full-size text.
class _GaugeDial extends StatelessWidget {
  const _GaugeDial({
    required this.size,
    required this.spec,
    required this.title,
    required this.valueText,
    required this.unitText,
    required this.idealText,
    required this.idealSemanticsLabel,
    required this.valueColor,
    required this.bounds,
    required this.axis,
    required this.value,
    required this.markerColor,
  });

  final double size;
  final _GaugeSpec spec;
  final String title;
  final String valueText;
  final String unitText;
  final String? idealText;

  /// Spoken form of [idealText] ("ideal 7.5–9") — the visual line is bare
  /// numbers to fit the dial, but a screen reader should still say what the
  /// range means.
  final String? idealSemanticsLabel;

  final Color valueColor;
  final ZoneBounds bounds;
  final GaugeAxis axis;
  final double? value;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    // The band is the green zone's slice of the axis; zoneBands already
    // handles one-sided green ranges (band to the gauge edge) and amber-only
    // bounds, so reuse it and keep the fallback logic in one tested place.
    final green = zoneBands(bounds, axis.min, axis.max)
        .where((b) => b.zone == Zone.green)
        .toList();

    double fraction(double v) =>
        ((v - axis.min) / (axis.max - axis.min)).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DialPainter(
                trackColor: tokens.track,
                bandColor: tokens.band,
                tickColor: tokens.tick,
                markerColor: markerColor,
                markerRingColor: tokens.markerRing,
                bandStart: green.isNotEmpty ? fraction(green.first.y1) : null,
                bandEnd: green.isNotEmpty ? fraction(green.first.y2) : null,
                valueFraction: value != null ? fraction(value!) : null,
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.16),
                // Each line fits the dial's center *independently* (scale-down
                // only): an overlong label — or a wide value under a large
                // system font scale — shrinks itself without dragging the
                // other lines down with it. One shared FittedBox would render
                // the value smaller on every card whose name is long.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: spec.label,
                          fontWeight: FontWeight.w600,
                          letterSpacing: spec.label * 0.04,
                          color: tokens.textDim,
                        ),
                      ),
                    ),
                    SizedBox(height: spec.labelGap),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            valueText,
                            style: ReefTokens.monoTextStyle.copyWith(
                              fontSize: spec.value,
                              fontWeight: FontWeight.w700,
                              color: valueColor,
                            ),
                          ),
                          if (unitText.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(
                              unitText,
                              style: TextStyle(
                                fontSize: spec.unit,
                                fontWeight: FontWeight.w500,
                                color: tokens.textDim,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (idealText != null) ...[
                      SizedBox(height: spec.idealGap),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          idealText!,
                          semanticsLabel: idealSemanticsLabel,
                          style: ReefTokens.monoTextStyle.copyWith(
                            fontSize: spec.ideal,
                            color: tokens.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the §A.1 dial: 19 ticks (major every 3rd) outside a 270° `track`
/// arc, the `band` arc over the ideal range, and the ringed marker dot.
/// All positions are fractions of the axis (0..1); geometry scales with
/// `s = size / 148`.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.trackColor,
    required this.bandColor,
    required this.tickColor,
    required this.markerColor,
    required this.markerRingColor,
    this.bandStart,
    this.bandEnd,
    this.valueFraction,
  });

  final Color trackColor;
  final Color bandColor;
  final Color tickColor;
  final Color markerColor;
  final Color markerRingColor;
  final double? bandStart;
  final double? bandEnd;
  final double? valueFraction;

  /// Sweep: 270°, from −135° to +135° with 0° at 12 o'clock, clockwise. In
  /// canvas terms (0 rad = 3 o'clock) the start sits at −225°.
  static const double _startDeg = -225;
  static const double _sweepDeg = 270;

  double _angle(double fraction) =>
      (_startDeg + _sweepDeg * fraction) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final s = side / 148;
    final center = Offset(size.width / 2, size.height / 2);
    final r = 0.39 * side;
    final arcRect = Rect.fromCircle(center: center, radius: r);

    // Ticks: radial lines just outside the arc, every 3rd one longer/heavier.
    for (var i = 0; i <= 18; i++) {
      final major = i % 3 == 0;
      final a = _angle(i / 18);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (r + 5 * s),
        center + dir * (r + (major ? 11 : 8) * s),
        Paint()
          ..color = tickColor
          ..strokeWidth = (major ? 1.6 : 0.9) * s
          ..strokeCap = StrokeCap.round,
      );
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(
      arcRect,
      _angle(0),
      _sweepDeg * math.pi / 180,
      false,
      arcPaint,
    );

    if (bandStart != null && bandEnd != null && bandEnd! > bandStart!) {
      canvas.drawArc(
        arcRect,
        _angle(bandStart!),
        (bandEnd! - bandStart!) * _sweepDeg * math.pi / 180,
        false,
        arcPaint..color = bandColor,
      );
    }

    if (valueFraction != null) {
      final a = _angle(valueFraction!);
      final pos = center + Offset(math.cos(a), math.sin(a)) * r;
      final mr = math.max(3.5, 6 * s);
      // Solid ring under the dot (a stroked circle would straddle the edge).
      canvas.drawCircle(pos, mr + 2.5 * s, Paint()..color = markerRingColor);
      canvas.drawCircle(pos, mr, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.trackColor != trackColor ||
      old.bandColor != bandColor ||
      old.tickColor != tickColor ||
      old.markerColor != markerColor ||
      old.markerRingColor != markerRingColor ||
      old.bandStart != bandStart ||
      old.bandEnd != bandEnd ||
      old.valueFraction != valueFraction;
}
