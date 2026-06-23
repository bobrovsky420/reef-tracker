import 'package:flutter/material.dart';

import '../domain/zones.dart';

/// A small colored pill showing a zone's status (OK / Attention / Act now).
class ZoneChip extends StatelessWidget {
  const ZoneChip(this.zone, {super.key, this.compact = false});

  final Zone zone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = zone.color;
    return Container(
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
              zone.label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
