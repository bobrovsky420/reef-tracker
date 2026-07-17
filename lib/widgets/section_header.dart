import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Uppercase faint section header between card groups (REDESIGN §2.2/A.6):
/// 12 px w700, wide letter-spacing, `textFaint`, 16 above · 10 below. Used by
/// the grouped dashboard (#6) and restyled Settings (#14); callers supply any
/// horizontal inset so the label aligns with their cards' edges.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  /// Localized label; kept to short words — uppercased via [String.toUpperCase],
  /// which is safe for the shipped languages.
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.84, // 0.07 em of 12 px
          color: tokens.textFaint,
        ),
      ),
    );
  }
}
