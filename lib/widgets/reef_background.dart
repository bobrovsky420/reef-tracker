import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The app-wide scaffold background (REDESIGN §2.1): a vertical gradient that
/// fades `scaffoldTop` → `scaffoldBody` within the top 14% of the screen and
/// stays flat below — a subtle glow behind the status-bar/app-bar area, not a
/// full-screen gradient. Mounted once in [MaterialApp]'s `builder` (behind the
/// Navigator), with every `Scaffold` transparent over it — never per-screen
/// copies (the one exception is the Cupertino-dialect page transition, which
/// paints [ReefTokens.backgroundDecoration] behind each sliding route — see
/// `theme.dart`). The chart PNG export needs an opaque backdrop and uses the
/// solid `scaffoldBody` token instead.
class ReefBackground extends StatelessWidget {
  const ReefBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ReefTokens.of(context).backgroundDecoration,
      child: child,
    );
  }
}
