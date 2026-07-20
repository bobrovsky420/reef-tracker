import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// ReefMenu — the app's anchored menu (menu redesign, replacing the stock
/// Material [PopupMenuButton] look everywhere):
///
/// - a frosted floating card: `tabBarBg` tint over a backdrop blur (the tab
///   bar's translucency language), 1 px `surfaceBorder`, the platform menu
///   shape from [reefMenuShape] (r16 squircle iOS / r14 rect Android), and
///   the token `cardShadow` (empty in dark — the border carries structure);
/// - items as inset pill rows: 15 px `text` labels, 18 px `textDim` leading
///   icons, the selected item on a `healthySoft` pill with a trailing
///   checkmark (the chip/segmented selection language), destructive items in
///   `ColorScheme.error` per the #1 slot rules;
/// - a ~150 ms fade + scale-from-anchor open animation instead of Material's
///   top-down grow.
///
/// Built on [RawMenuAnchor] so the panel is fully custom; the Android back
/// button is intercepted via a [PopScope] around the anchor (the overlay is
/// not a route, so back would otherwise pop the screen under an open menu).

/// One entry of a [ReefMenuButton]: either a [ReefMenuItem] or a
/// [ReefMenuDivider].
sealed class ReefMenuEntry<T> {
  const ReefMenuEntry();
}

/// A selectable menu row.
class ReefMenuItem<T> extends ReefMenuEntry<T> {
  const ReefMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
    this.destructive = false,
  });

  final T value;
  final String label;

  /// Optional 18 px leading icon (`textDim`; `error` when [destructive]).
  final IconData? icon;

  /// Marks the current choice: `healthySoft` pill + trailing checkmark.
  final bool selected;

  /// Renders label and icon in `ColorScheme.error` (destructive actions).
  final bool destructive;
}

/// A full-width hairline separator between item groups.
class ReefMenuDivider<T> extends ReefMenuEntry<T> {
  const ReefMenuDivider();
}

/// Anchor button that opens a [ReefMenu]. The anchor is either an icon button
/// ([icon], styled via [iconStyle] — pass `reefIconButtonStyle` for the
/// app-bar mini-card look, or leave null for the plain 18 px `textDim` glyph
/// used on list rows) or an arbitrary [child] (wrapped in an [InkWell]).
class ReefMenuButton<T> extends StatefulWidget {
  const ReefMenuButton({
    super.key,
    required this.entries,
    required this.onSelected,
    this.icon,
    this.iconStyle,
    this.child,
    this.tooltip,
    this.enabled = true,
  }) : assert(
         (icon == null) != (child == null),
         'Provide exactly one of icon or child as the anchor.',
       );

  /// Menu content, rebuilt each time the parent rebuilds.
  final List<ReefMenuEntry<T>> entries;

  final ValueChanged<T> onSelected;

  /// Icon-button anchor glyph.
  final IconData? icon;

  /// Style for the [icon] anchor; null = plain 18 px `textDim` icon button.
  final ButtonStyle? iconStyle;

  /// Custom anchor widget (e.g. the tank switcher's title + chevron).
  final Widget? child;

  /// Tooltip for the [icon] anchor; defaults to the localized "show menu".
  final String? tooltip;

  /// When false the anchor is inert (and an icon anchor renders disabled).
  final bool enabled;

  @override
  State<ReefMenuButton<T>> createState() => _ReefMenuButtonState<T>();
}

class _ReefMenuButtonState<T> extends State<ReefMenuButton<T>>
    with SingleTickerProviderStateMixin {
  final MenuController _menu = MenuController();
  // Created eagerly in initState: a lazy `late final` would be first touched
  // in dispose() for menus that were never opened, and creating a ticker
  // there crashes on the deactivated-ancestor TickerMode lookup.
  late final AnimationController _animation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 110),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
  }

  void _select(T value) {
    _menu.close();
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.icon != null
        ? IconButton(
            tooltip:
                widget.tooltip ??
                MaterialLocalizations.of(context).showMenuTooltip,
            style:
                widget.iconStyle ??
                IconButton.styleFrom(
                  foregroundColor: ReefTokens.of(context).textDim,
                  iconSize: 18,
                ),
            onPressed: widget.enabled ? _toggle : null,
            icon: Icon(widget.icon),
          )
        : InkWell(
            onTap: widget.enabled ? _toggle : null,
            borderRadius: BorderRadius.circular(8),
            // No gray press flash on custom anchors (tank switcher, settings
            // values) — the opening panel itself is the feedback.
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: widget.child,
          );
    // Back must close an open menu, not pop the screen under it: the overlay
    // is not a route, so without this Android's back button (and gesture)
    // would navigate away while the menu stays visually on top.
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _menu.close();
      },
      child: RawMenuAnchor(
        controller: _menu,
        consumeOutsideTaps: true,
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        onOpenRequested: (position, showOverlay) {
          showOverlay();
          unawaited(_animation.forward());
        },
        onCloseRequested: (hideOverlay) {
          // If the menu reopens mid-close, forward() redirects the ticker and
          // this future never completes — the overlay correctly stays up.
          unawaited(_animation.reverse().whenComplete(hideOverlay));
        },
        overlayBuilder: _buildOverlay,
        child: anchor,
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final tokens = ReefTokens.of(context);
    final theme = Theme.of(context);
    final shape = reefMenuShape(theme.platform);
    // Menus opened from the right half (overflow buttons, row menus, settings
    // selectors) hang from the anchor's right edge; left-half anchors (the
    // tank switcher) from the left. The scale animation grows from the same
    // corner so the panel appears to unfold from its anchor.
    final rightAligned = info.anchorRect.center.dx > info.overlaySize.width / 2;

    final curved = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final rows = <Widget>[
      for (final entry in widget.entries)
        switch (entry) {
          ReefMenuItem<T>() => _ReefMenuRow(
            item: entry,
            onTap: () => _select(entry.value),
          ),
          ReefMenuDivider<T>() => Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
            color: tokens.surfaceBorder,
          ),
        },
    ];

    final panel = DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: tokens.cardShadow),
      child: ClipPath.shape(
        shape: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: tokens.tabBarBg,
              shape: shape.copyWith(
                side: BorderSide(color: tokens.surfaceBorder),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _ReefMenuLayout(
          anchorRect: info.anchorRect,
          rightAligned: rightAligned,
        ),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          onTapOutside: (_) => _menu.close(),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              alignment: rightAligned
                  ? Alignment.topRight
                  : Alignment.topLeft,
              child: panel,
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable menu row: inset 6 px from the panel edge, r10 ink pill,
/// selected = `healthySoft` fill + trailing check.
class _ReefMenuRow extends StatelessWidget {
  const _ReefMenuRow({required this.item, required this.onTap});

  final ReefMenuItem<Object?> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final error = Theme.of(context).colorScheme.error;
    final labelColor = item.destructive ? error : tokens.text;
    final iconColor = item.destructive ? error : tokens.textDim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: item.selected ? tokens.healthySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          // No Material ripple/highlight: the tap closes the menu anyway, so
          // the gray flash reads as glitch rather than feedback.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                if (item.selected) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check, size: 16, color: tokens.text),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions the panel below the anchor (6 px gap), right- or left-aligned to
/// it, clamped 8 px inside the overlay; flips above the anchor when there is
/// no room below.
class _ReefMenuLayout extends SingleChildLayoutDelegate {
  const _ReefMenuLayout({required this.anchorRect, required this.rightAligned});

  final Rect anchorRect;
  final bool rightAligned;

  static const double _margin = 8;
  static const double _gap = 6;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: 180,
      maxWidth: (constraints.maxWidth - 2 * _margin).clamp(180.0, 320.0),
      maxHeight: constraints.maxHeight - 2 * _margin,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = rightAligned
        ? anchorRect.right - childSize.width
        : anchorRect.left;
    x = x.clamp(_margin, size.width - childSize.width - _margin);
    var y = anchorRect.bottom + _gap;
    if (y + childSize.height > size.height - _margin) {
      final above = anchorRect.top - _gap - childSize.height;
      y = above >= _margin
          ? above
          : size.height - _margin - childSize.height;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_ReefMenuLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      rightAligned != oldDelegate.rightAligned;
}
