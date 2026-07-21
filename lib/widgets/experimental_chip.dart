import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';

/// The small amber "Experimental" badge shown beside a screen title — a
/// feature ships behind it until it has proven stable in the field (the
/// Hanna BLE protocol, the checker camera scan).
class ExperimentalChip extends StatelessWidget {
  const ExperimentalChip({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.caution),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l.experimentalBadge,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: tokens.caution,
        ),
      ),
    );
  }
}
