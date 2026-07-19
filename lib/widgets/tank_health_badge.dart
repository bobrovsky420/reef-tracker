import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../data/database.dart';
import '../domain/clock.dart';
import '../domain/health_score.dart';
import '../domain/pro_features.dart';
import '../domain/stability_score.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'pro_feature_dialog.dart';
import 'reef_card.dart';
import 'zone_visuals.dart';

/// The mono numeral drawn inside a score ring (REDESIGN §A.2: JetBrains Mono
/// w700 at 0.28× the ring size, in the ring's score color).
TextStyle _ringNumberStyle(double ringSize, Color color) =>
    ReefTokens.monoTextStyle.copyWith(
      fontSize: ringSize * 0.28,
      fontWeight: FontWeight.w700,
      color: color,
    );

/// A circular progress ring filled to [score]/100 in [color] over a neutral
/// `track` circle (REDESIGN §A.2), with [center] drawn in the middle. Used at
/// several sizes by the health badges below.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.color,
    required this.size,
    this.stroke = 4,
    this.center,
  });

  /// 0–100, or null when there's no score (renders an empty track).
  final int? score;
  final Color color;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: (score ?? 0) / 100,
          color: color,
          trackColor: ReefTokens.of(context).track,
          stroke: stroke,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    // §A.2 ring geometry: r = 0.40·size (the stroke stays inside the canvas).
    final radius = 0.40 * math.min(size.width, size.height);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (fraction > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * fraction.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}

/// Compact health badge for the app bar: a small ring around the band icon, no
/// text. Tapping it opens the breakdown sheet. Hidden when there's no data.
class TankHealthBadgeCompact extends ConsumerWidget {
  const TankHealthBadgeCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(tankHealthProvider);
    if (!health.hasData) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final color = health.band.colorOf(context);

    return Semantics(
      button: true,
      label:
          '${l.healthTitle}: ${l.healthGradeLabel(health.grade)}, '
          '${l.healthScoreOf(health.score!)}',
      child: InkResponse(
        radius: 22,
        onTap: () => showTankHealthSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _ScoreRing(
            score: health.score,
            color: color,
            size: 28,
            stroke: 3,
            center: Icon(health.band.icon, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}

/// Full-width health header for the dashboard (REDESIGN #4: the mockup score
/// card), split into two tap targets: the health half (72 px ring + grade word
/// in the grade color + one-line attention summary) and the stability half
/// (U26, Pro — a smaller 60 px ring; how much the measurements oscillate).
/// Tapping each opens its own breakdown sheet.
class TankHealthHeader extends ConsumerWidget {
  const TankHealthHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final health = ref.watch(tankHealthProvider);
    final color = health.band.colorOf(context);
    final tokens = ReefTokens.of(context);

    final String subtitle;
    if (!health.hasData) {
      subtitle = l.healthNoReadingsYet;
    } else if (health.offenders.isEmpty) {
      subtitle = l.healthAllOnTarget;
    } else {
      subtitle = l.healthParamsToWatch(health.offenders.length);
    }

    return ReefCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      // IntrinsicHeight sizes the divider and both ink surfaces to the taller
      // half, so the ripple covers each panel edge-to-edge.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: health.hasData
                    ? () => showTankHealthSheet(context)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    children: [
                      _ScoreRing(
                        score: health.score,
                        color: color,
                        size: 72,
                        stroke: 7,
                        center: Text(
                          health.hasData ? '${health.score}' : '—',
                          style: _ringNumberStyle(72, color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.healthGradeLabel(health.grade),
                              // Mock: w800 — rounded to w700 (Roboto/SF ship
                              // no 800; it risks resolving to Black).
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, color: tokens.surfaceBorder),
            const _StabilityHeaderPanel(),
          ],
        ),
      ),
    );
  }
}

/// The stability half of the dashboard header (U26). Pro-gated: entitled
/// installs see the stability ring and tap through to the breakdown sheet;
/// anyone else sees a Pro marker whose tap explains the gate.
class _StabilityHeaderPanel extends ConsumerWidget {
  const _StabilityHeaderPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final unlocked = ref.watch(proFeatureProvider(ProFeature.stabilityScore));

    final caption = TextStyle(fontSize: 12, color: tokens.textDim);
    const padding = EdgeInsets.fromLTRB(14, 16, 18, 16);

    if (!unlocked) {
      return Semantics(
        button: true,
        label: '${l.stabilityTitle}: ${l.proFeatureTitle}',
        child: InkWell(
          onTap: () => showProFeatureDialog(context, ProFeature.stabilityScore),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  size: 26,
                  color: tokens.textDim,
                ),
                const SizedBox(height: 6),
                Text(l.stabilityTitle, style: caption),
              ],
            ),
          ),
        ),
      );
    }

    final stability = ref.watch(tankStabilityProvider);
    final color = stability.band.colorOf(context);
    return Semantics(
      button: true,
      label:
          '${l.stabilityTitle}: ${l.stabilityGradeLabel(stability.grade)}'
          '${stability.hasData ? ', ${l.healthScoreOf(stability.score!)}' : ''}',
      child: InkWell(
        onTap: () => showTankStabilitySheet(context),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScoreRing(
                score: stability.score,
                color: color,
                size: 60,
                stroke: 7,
                center: Text(
                  stability.hasData ? '${stability.score}' : '—',
                  style: _ringNumberStyle(60, color),
                ),
              ),
              const SizedBox(height: 5),
              Text(l.stabilityTitle, style: caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the tank-health breakdown as a modal bottom sheet, grouping parameters
/// into "needs attention", "looking good", and "not tested recently".
Future<void> showTankHealthSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _TankHealthSheet(),
  );
}

class _TankHealthSheet extends ConsumerWidget {
  const _TankHealthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final health = ref.watch(tankHealthProvider);
    final prefs = ref.watch(unitPrefsProvider);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final byKey = {for (final p in tracked) p.paramKey: p};
    final color = health.band.colorOf(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Header: ring + grade + score.
            Row(
              children: [
                _ScoreRing(
                  score: health.score,
                  color: color,
                  size: 56,
                  stroke: 5,
                  center: Text(
                    health.hasData ? '${health.score}' : '—',
                    style: _ringNumberStyle(56, color),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.healthTitle, style: theme.textTheme.labelMedium),
                    // The #18 sheet-header scale, in the grade color (a plain
                    // ReefSheetHeader can't carry the colored grade word).
                    Semantics(
                      header: true,
                      child: Text(
                        l.healthGradeLabel(health.grade),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (health.offenders.isNotEmpty) ...[
              _SectionHeader(l.healthSectionAttention),
              for (final p in health.offenders)
                _ParamRow(health: p, param: byKey[p.paramKey], prefs: prefs),
            ],
            if (health.healthy.isNotEmpty) ...[
              _SectionHeader(l.healthSectionGood),
              for (final p in health.healthy)
                _ParamRow(health: p, param: byKey[p.paramKey], prefs: prefs),
            ],
            if (health.notScored.isNotEmpty) ...[
              _SectionHeader(l.healthSectionStale),
              for (final p in health.notScored)
                _ParamRow(
                  health: p,
                  param: byKey[p.paramKey],
                  prefs: prefs,
                  muted: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the tank-stability breakdown as a modal bottom sheet, grouping
/// parameters into "most variable", "holding steady", and "not enough data".
Future<void> showTankStabilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _TankStabilitySheet(),
  );
}

class _TankStabilitySheet extends ConsumerWidget {
  const _TankStabilitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stability = ref.watch(tankStabilityProvider);
    final windowDays =
        ref.watch(stabilityWindowProvider).value ?? kStabilityWindowDays;
    final prefs = ref.watch(unitPrefsProvider);
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final byKey = {for (final p in tracked) p.paramKey: p};
    final color = stability.band.colorOf(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Header: ring + grade + score.
            Row(
              children: [
                _ScoreRing(
                  score: stability.score,
                  color: color,
                  size: 56,
                  stroke: 5,
                  center: Text(
                    stability.hasData ? '${stability.score}' : '—',
                    style: _ringNumberStyle(56, color),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.stabilityTitle, style: theme.textTheme.labelMedium),
                    Semantics(
                      header: true,
                      child: Text(
                        l.stabilityGradeLabel(stability.grade),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.stabilityIntro(windowDays),
              style: theme.textTheme.bodySmall?.copyWith(
                color: ReefTokens.of(context).textDim,
              ),
            ),

            if (stability.mostVariable.isNotEmpty) ...[
              _SectionHeader(l.stabilitySectionVariable),
              for (final p in stability.mostVariable)
                _StabilityParamRow(
                  stability: p,
                  param: byKey[p.paramKey],
                  prefs: prefs,
                  windowDays: windowDays,
                ),
            ],
            if (stability.steady.isNotEmpty) ...[
              _SectionHeader(l.stabilitySectionSteady),
              for (final p in stability.steady)
                _StabilityParamRow(
                  stability: p,
                  param: byKey[p.paramKey],
                  prefs: prefs,
                  windowDays: windowDays,
                ),
            ],
            if (stability.insufficient.isNotEmpty) ...[
              _SectionHeader(l.stabilitySectionInsufficient),
              for (final p in stability.insufficient)
                _StabilityParamRow(
                  stability: p,
                  param: byKey[p.paramKey],
                  prefs: prefs,
                  windowDays: windowDays,
                  muted: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One parameter line in the stability breakdown: wave icon colored by the
/// sub-score band, name, and the typical swing ("±0.4 dKH") — or, for muted
/// rows, how many tests the window held. Taps through to the history graph.
class _StabilityParamRow extends StatelessWidget {
  const _StabilityParamRow({
    required this.stability,
    required this.param,
    required this.prefs,
    required this.windowDays,
    this.muted = false,
  });

  final ParameterStability stability;
  final TrackedParameter? param;
  final UnitPrefs prefs;

  /// Effective stability window, for the muted rows' "N tests in D d" note.
  final int windowDays;

  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sub = stability.subScore;
    final zone = (muted || sub == null)
        ? Zone.unknown
        : sub >= 70
        ? Zone.green
        : sub >= 40
        ? Zone.amber
        : Zone.red;
    final color = muted
        ? ReefTokens.of(context).textFaint
        : zone.colorOf(context);

    // "±σ" in display units. The σ is a *delta*, so it converts by scale only —
    // subtracting toDisplay(0) cancels an affine offset (°F) that would
    // otherwise inflate a 0.5 °C swing to "±32.9 °F".
    String trailing = '';
    if (!muted && stability.sigma != null && param != null) {
      final pres = presentationOf(param!, prefs);
      final sigmaDisplay =
          (pres.toDisplay(stability.sigma!) - pres.toDisplay(0)).abs();
      trailing =
          '±${formatLocaleNumber(sigmaDisplay, pres.decimals)} ${pres.unitLabel}';
    }

    final note = muted
        ? l.stabilityTestCount(stability.sampleCount, windowDays)
        : null;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        unawaited(context.push('/history/${stability.paramKey}'));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              muted ? Icons.remove_circle_outline : Icons.waves,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.paramName(stability.paramKey),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ReefTokens.of(context).textDim,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: ReefTokens.of(context).textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ReefTokens.of(context).textFaint,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// One parameter line in the breakdown: zone dot, name, current value (or a
/// "not tested" note for muted rows), tapping through to its history graph.
class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.health,
    required this.param,
    required this.prefs,
    this.muted = false,
  });

  final ParameterHealth health;
  final TrackedParameter? param;
  final UnitPrefs prefs;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final zoneColor = muted
        ? ReefTokens.of(context).textFaint
        : health.zone.colorOf(context);

    final String trailing;
    if (health.value != null && param != null) {
      final pres = presentationOf(param!, prefs);
      trailing = '${pres.format(health.value!)} ${pres.unitLabel}';
    } else {
      trailing = '';
    }

    // Sub-note for muted rows: stale (days since test) or never tested.
    String? note;
    if (muted) {
      if (health.takenAt == null) {
        note = l.healthNeverTested;
      } else if (health.stale) {
        note = l.healthNotTestedDays(daysSince(health.takenAt!));
      }
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        unawaited(context.push('/history/${health.paramKey}'));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              muted ? Icons.remove_circle_outline : health.zone.icon,
              size: 18,
              color: zoneColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.paramName(health.paramKey),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ReefTokens.of(context).textDim,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: zoneColor,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: ReefTokens.of(context).textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
