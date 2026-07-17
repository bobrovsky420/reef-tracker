import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The app-wide scaffold background (REDESIGN §2.1): a vertical gradient that
/// fades `scaffoldTop` → `scaffoldBody` within the top 14% of the screen and
/// stays flat below — a subtle glow behind the status-bar/app-bar area, not a
/// full-screen gradient. Mounted once in [MaterialApp]'s `builder` (behind the
/// Navigator), with every `Scaffold` transparent over it — never per-screen
/// copies. The chart PNG export needs an opaque backdrop and uses the solid
/// `scaffoldBody` token instead.
class ReefBackground extends StatelessWidget {
  const ReefBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.14],
          colors: [tokens.scaffoldTop, tokens.scaffoldBody],
        ),
      ),
      child: child,
    );
  }
}
