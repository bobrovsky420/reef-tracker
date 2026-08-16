import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Stable hook for widget tests and for inspecting the drag treatment without
/// depending on the proxy's private layout widgets.
const deviceCardDragIndicatorKey = ValueKey('device-card-drag-indicator');

/// The lifted treatment shared by every device vendor's reorderable card.
///
/// Device cards own a 12 px bottom margin, so the outline and shadow stop above
/// that gap. The reorder badge is centered on the card's top edge and only
/// exists in the drag proxy; the resting card has no permanent affordance.
Widget deviceCardDragProxyDecorator(
  BuildContext context,
  Widget child,
  int index,
  Animation<double> animation, {
  required String semanticLabel,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final radius = reefCardRadius(theme.platform);

  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final progress = Curves.easeOutCubic.transform(animation.value);
      return Transform.scale(
        scale: 1 + (0.012 * progress),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.22 * progress),
                        blurRadius: 16 * progress,
                        offset: Offset(0, 5 * progress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child!,
            Positioned.fill(
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: progress),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * progress),
                      child: Material(
                        key: deviceCardDragIndicatorKey,
                        color: colors.primary,
                        elevation: 4 * progress,
                        shape: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 40,
                          child: Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: colors.onPrimary,
                            semanticLabel: semanticLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
