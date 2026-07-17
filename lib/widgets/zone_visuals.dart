import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/zones.dart';

/// How each [Zone] renders in the UI: its color and icon. Lives in the widget
/// layer so the domain's `zones.dart` stays Flutter-free (#53) — the zone
/// *logic* (classification, chart bands) knows nothing about presentation.
///
/// Colors come from the active theme's [ReefTokens] (REDESIGN #1): each
/// brightness has its own status palette, so the mapping needs a context.
extension ZoneVisuals on Zone {
  /// Solid status color — text, icons, rings, markers.
  Color colorOf(BuildContext context) {
    final tokens = ReefTokens.of(context);
    switch (this) {
      case Zone.green:
        return tokens.healthy;
      case Zone.amber:
        return tokens.caution;
      case Zone.red:
        return tokens.critical;
      case Zone.unknown:
        return tokens.textFaint;
    }
  }

  /// Soft translucent fill — tag/chip backgrounds and chart band fills.
  Color softColorOf(BuildContext context) {
    final tokens = ReefTokens.of(context);
    switch (this) {
      case Zone.green:
        return tokens.healthySoft;
      case Zone.amber:
        return tokens.cautionSoft;
      case Zone.red:
        return tokens.criticalSoft;
      case Zone.unknown:
        return tokens.track;
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
