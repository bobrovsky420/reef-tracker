import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The #12-footer-style inline form row (REDESIGN #19–#21): leading icon (or
/// [ReefIconChip]), a value, and trailing inline [ReefInlineButton] actions
/// (set / change / clear) — replacing the old `ListTile` + `IconButton` date
/// and time rows in the editors.
class ReefValueRow extends StatelessWidget {
  const ReefValueRow({
    super.key,
    required this.leading,
    required this.value,
    this.valueStyle,
    this.actions = const [],
  });

  /// Leading visual: a bare `Icon` (18 px, `textDim`) or a [ReefIconChip].
  final Widget leading;

  /// The current value (or a localized "not set" placeholder).
  final String value;

  /// Override for the value text; default 15 px `text`.
  final TextStyle? valueStyle;

  /// Inline actions, typically [ReefInlineButton]s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? TextStyle(fontSize: 15, color: tokens.text),
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Inline text action in the #12 footer style: 12.5 w600 `primary`, compact
/// hit target (the row supplies surrounding breathing room).
class ReefInlineButton extends StatelessWidget {
  const ReefInlineButton(this.label, {super.key, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: ReefTokens.of(context).primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    );
    if (icon == null) {
      return TextButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

/// The 32 px r10 icon chip from the #12 section head (`track` fill, 16 px
/// icon), used as a row leading where the mock shows a chipped icon.
class ReefIconChip extends StatelessWidget {
  const ReefIconChip(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: tokens.text),
    );
  }
}
