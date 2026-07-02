import 'package:flutter/material.dart';

import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

/// A small colored pill showing a zone's status (OK / Attention / Act now).
class ZoneChip extends StatelessWidget {
  const ZoneChip(this.zone, {super.key, this.compact = false});

  final Zone zone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = zone.color;
    // In compact mode the chip is a bare colored icon; the explicit label keeps
    // it readable for screen readers (#46). The full mode already shows text.
    return Semantics(
      label: compact ? AppLocalizations.of(context).zoneLabel(zone) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(zone.icon, size: compact ? 12 : 16, color: color),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).zoneLabel(zone),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
