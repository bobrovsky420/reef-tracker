import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The app's card container (REDESIGN #2): flat `surface` with a 1 px
/// `surfaceBorder` at the platform radius, plus the two-layer `cardShadow`
/// (empty in dark, where the border carries the structure). Use this instead
/// of [Card] for the primary content cards; plain [Card]s get the same
/// surface/border/radius from the theme's `CardThemeData` but not the shadow.
///
/// No default margin or padding — callers own their spacing (the dashboard
/// grid, list gaps), matching how the converted call sites already worked.
class ReefCard extends StatelessWidget {
  const ReefCard({
    super.key,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.radius,
    required this.child,
  });

  /// Makes the whole card one tap target (ink clipped to the card shape).
  /// Cards with several internal tap targets leave this null and place their
  /// own [InkWell]s in [child] — they ripple on this card's [Material].
  final VoidCallback? onTap;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Overrides for the alert-card variants (e.g. `criticalSoft` background +
  /// `criticalBorder` border, REDESIGN #11). Default: `surface`/`surfaceBorder`.
  final Color? color;
  final Color? borderColor;

  /// Corner radius override; default is the platform card radius
  /// (`reefCardRadius`). The iOS-dialect settings group card uses r14 (§A.7).
  final double? radius;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final radius = BorderRadius.circular(
      this.radius ?? reefCardRadius(Theme.of(context).platform),
    );

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    // The shadow lives on an outer box so the translucent dark `surface`
    // doesn't have to be composited over it; the Material paints the fill and
    // border and clips ink ripples to the rounded shape.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        color: color ?? tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor ?? tokens.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// [ReefCard]'s sliver counterpart: paints the same card (fill + 1 px border +
/// light shadow, platform radius) *behind a lazy sliver*, for the list cards
/// that collapse a whole scrolling list into one card (REDESIGN #11/#13). A
/// box `ReefCard` around such a list would force it to build eagerly;
/// [DecoratedSliver] keeps builder laziness and extends the painted card over
/// the scrolled-away extent.
///
/// The decoration paints *behind* the rows, so rows that ripple or expose a
/// swipe background must bring their own transparent [Material] (the scaffold
/// Material sits below the card fill). With [padding] ≥ the card radius'
/// sagitta (the defaults callers use, ≥ 4×8), row rectangles stay inside the
/// rounded shape and need no corner clipping.
class ReefSliverCard extends StatelessWidget {
  const ReefSliverCard({super.key, this.padding, required this.sliver});

  /// Inner padding between the card edge and the rows.
  final EdgeInsetsGeometry? padding;

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final radius = BorderRadius.circular(
      reefCardRadius(Theme.of(context).platform),
    );
    Widget content = sliver;
    if (padding != null) {
      content = SliverPadding(padding: padding!, sliver: content);
    }
    return DecoratedSliver(
      decoration: ShapeDecoration(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        shadows: tokens.cardShadow,
      ),
      sliver: content,
    );
  }
}
