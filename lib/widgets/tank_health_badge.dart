import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/clock.dart';
import '../domain/health_score.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

/// A circular progress ring filled to [score]/100 in [color], with [center]
/// drawn in the middle. Used at several sizes by the health badges below.
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
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.18);
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
      old.fraction != fraction || old.color != color || old.stroke != stroke;
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
    final color = health.band.color;

    return Semantics(
      button: true,
      label: '${l.healthTitle}: ${l.healthGradeLabel(health.grade)}, '
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

/// Full-width health header for the dashboard: ring + score, grade word, and a
/// one-line summary of what needs attention. Tapping opens the breakdown sheet.
class TankHealthHeader extends ConsumerWidget {
  const TankHealthHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final health = ref.watch(tankHealthProvider);
    final color = health.band.color;
    final theme = Theme.of(context);

    final String subtitle;
    if (!health.hasData) {
      subtitle = l.healthNoReadingsYet;
    } else if (health.offenders.isEmpty) {
      subtitle = l.healthAllOnTarget;
    } else {
      subtitle = l.healthParamsToWatch(health.offenders.length);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: InkWell(
        onTap: health.hasData ? () => showTankHealthSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ScoreRing(
                score: health.score,
                color: color,
                size: 52,
                stroke: 5,
                center: Text(
                  health.hasData ? '${health.score}' : '—',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.healthGradeLabel(health.grade),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (health.hasData)
                Icon(Icons.chevron_right, color: theme.hintColor),
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
    final color = health.band.color;

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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.healthTitle, style: theme.textTheme.labelMedium),
                    Text(
                      l.healthGradeLabel(health.grade),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
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
              color: Theme.of(context).hintColor,
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
    final zoneColor = muted ? theme.hintColor : health.zone.color;

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
        context.push('/history/${health.paramKey}');
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
                  Text(l.paramName(health.paramKey),
                      style: theme.textTheme.bodyLarge),
                  if (note != null)
                    Text(note,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted ? theme.hintColor : zoneColor,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
