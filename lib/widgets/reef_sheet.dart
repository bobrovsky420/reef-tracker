import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Standard header for modal bottom sheets (REDESIGN #18): title at 17 w700
/// in the `text` token, optional leading icon and trailing action. Replaces
/// the ad-hoc `titleLarge` headers; the drag handle above it comes from the
/// sheet itself (`showModalBottomSheet(showDragHandle: true)` — the other
/// half of the #18 sheet-chrome convention). Callers own the surrounding
/// padding so the header aligns with their sheet body.
class ReefSheetHeader extends StatelessWidget {
  const ReefSheetHeader(this.title, {super.key, this.leading, this.trailing});

  /// Localized sheet title.
  final String title;

  /// Optional icon before the title (16 gap-free — pass a sized icon).
  final Widget? leading;

  /// Optional action aligned to the sheet's trailing edge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tokens.text,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
