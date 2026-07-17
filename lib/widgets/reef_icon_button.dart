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

/// The mini-card [ButtonStyle], exposed for app-bar buttons that can't be a
/// plain [IconButton] — e.g. [PopupMenuButton], which forwards `style` to its
/// internal icon button.
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
