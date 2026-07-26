import 'package:flutter/material.dart';

import '../app/theme.dart';

/// App-bar "mini-card" icon button (REDESIGN #3, §A.6): a 32 px `surface`
/// card with a 1 px `surfaceBorder` — r9 squircle on the iOS dialect, circle
/// on Android — around a 16 px `textDim` icon. Only the visual is compact;
/// the gesture target keeps the 48 px Material minimum.
class ReefIconButton extends StatelessWidget {
  const ReefIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: reefIconButtonStyle(context),
    );
  }
}

/// A card's primary action as an icon alone, for when a labelled button would
/// cost a whole extra row — e.g. **Save** sitting inline with a device's live
/// readings. Keeps the primary-action colours so it still reads as the main
/// action, on a true circle (both dialects) rather than the rounded rectangle
/// of the labelled primary buttons: at 36 px square there is no label to line a
/// silhouette up with, and a circle is unmistakably one round icon target.
/// 36 px visual, 48 px gesture target.
///
/// [tooltip] carries the label the button no longer shows, so it stays the
/// button's accessible name — never construct one without it.
class ReefFilledIconButton extends StatelessWidget {
  const ReefFilledIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        iconSize: 18,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

/// The mini-card [ButtonStyle], exposed for app-bar buttons that can't be a
/// plain [IconButton] — e.g. `ReefMenuButton`, which forwards it to its
/// icon-button anchor.
ButtonStyle reefIconButtonStyle(BuildContext context) {
  final tokens = ReefTokens.of(context);
  return IconButton.styleFrom(
    backgroundColor: tokens.surface,
    foregroundColor: tokens.textDim,
    side: BorderSide(color: tokens.surfaceBorder),
    shape: reefIconButtonShape(Theme.of(context).platform),
    fixedSize: const Size.square(32),
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    iconSize: 16,
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}
