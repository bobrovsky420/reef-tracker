import 'package:flutter/material.dart';

import '../domain/zones.dart';

/// How each [Zone] renders in the UI: its color and icon. Lives in the widget
/// layer so the domain's `zones.dart` stays Flutter-free (#53) — the zone
/// *logic* (classification, chart bands) knows nothing about presentation.
///
/// The colors are deliberately fixed (not theme-derived): zone semantics must
/// read identically in light and dark mode.
extension ZoneVisuals on Zone {
  Color get color {
    switch (this) {
      case Zone.green:
        return const Color(0xFF2E9E5B);
      case Zone.amber:
        return const Color(0xFFE6A100);
      case Zone.red:
        return const Color(0xFFD93838);
      case Zone.unknown:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get icon {
    switch (this) {
      case Zone.green:
        return Icons.check_circle;
      case Zone.amber:
        return Icons.warning_amber_rounded;
      case Zone.red:
        return Icons.error;
      case Zone.unknown:
        return Icons.help_outline;
    }
  }
}
