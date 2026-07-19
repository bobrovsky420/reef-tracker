import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../domain/insights.dart';
import '../domain/pro_features.dart';
import '../domain/zones.dart';
import '../features/ai_summary/ai_summary_sheet.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'pro_feature_dialog.dart';
import 'reef_card.dart';
import 'reef_sheet.dart';
import 'zone_visuals.dart';

/// How many insights the dashboard card previews; the rest live in the sheet.
const int _kCardMaxRows = 3;

/// Dashboard "Insights" card (U28, Pro): the top rule-based observations for
/// the active tank, under the health header. Pro-gated like the stability
/// half of the header (U26): entitled installs see the insight rows and tap
/// through to the full sheet; anyone else sees a compact Pro teaser whose tap
/// explains the gate. [tankInsightsProvider] computes regardless of
/// entitlement — only presentation is gated.
class InsightsCard extends ConsumerWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final unlocked = ref.watch(proFeatureProvider(ProFeature.smartInsights));

    if (!unlocked) {
      // Teaser: same slim-card footprint as a one-row insights card, so the
      // upgrade doesn't reflow the dashboard.
      return ReefCard(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Semantics(
          button: true,
          label: '${l.insightsTitle}: ${l.proFeatureTitle}',
          child: InkWell(
            onTap: () =>
                showProFeatureDialog(context, ProFeature.smartInsights),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 22,
                    color: tokens.textDim,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.insightsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textDim,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: tokens.textDim),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final insights = ref.watch(tankInsightsProvider);
    // Nothing to say — no card. (All parameters in range, fresh, and holding
    // steady is exactly the state that needs no banner.)
    if (insights.isEmpty) return const SizedBox.shrink();

    final visible = insights.take(_kCardMaxRows).toList();
    final more = insights.length - visible.length;

    return ReefCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: InkWell(
        onTap: () => showInsightsSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: tokens.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.insightsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.text,
                      ),
                    ),
                  ),
                  if (more > 0)
                    Text(
                      l.insightsMore(more),
                      style: TextStyle(fontSize: 12, color: tokens.textDim),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final (index, i) in visible.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                  child: _InsightLine(insight: i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + color for an insight: color follows severity (the app-wide zone
/// palette; notice-level rows render faint per the mockup's trend rows), the
/// icon follows the rule kind.
(IconData, Color) _insightVisual(Insight i, BuildContext context) {
  final color = switch (i.severity) {
    InsightSeverity.critical => Zone.red.colorOf(context),
    InsightSeverity.warning => Zone.amber.colorOf(context),
    InsightSeverity.notice => ReefTokens.of(context).textFaint,
    InsightSeverity.positive => Zone.green.colorOf(context),
  };
  final icon = switch (i.kind) {
    InsightKind.outOfRange =>
      i.severity == InsightSeverity.critical ? Zone.red.icon : Zone.amber.icon,
    // Forecast points the way the value is drifting; recovering points back
    // toward the range.
    InsightKind.forecast =>
      (i.isLow ?? false) ? Icons.trending_down : Icons.trending_up,
    InsightKind.recovering =>
      (i.isLow ?? true) ? Icons.trending_up : Icons.trending_down,
    InsightKind.staleTest => Icons.schedule,
  };
  return (icon, color);
}

/// One compact insight row on the card (no tap target of its own — the whole
/// card opens the sheet).
class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final (icon, color) = _insightVisual(insight, context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.insightLabel(insight),
            style: TextStyle(fontSize: 12.5, height: 1.4, color: tokens.text),
          ),
        ),
      ],
    );
  }
}

/// Opens the full insights list as a modal bottom sheet; rows tap through to
/// the parameter's history graph (the health/stability sheet idiom).
Future<void> showInsightsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _InsightsSheet(),
  );
}

class _InsightsSheet extends ConsumerWidget {
  const _InsightsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final insights = ref.watch(tankInsightsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ReefSheetHeader(
              l.insightsTitle,
              leading: Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: ReefTokens.of(context).text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.insightsIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ReefTokens.of(context).textDim,
              ),
            ),
            const SizedBox(height: 8),
            for (final i in insights) _InsightRow(insight: i),
            // The rules cover the routine reading of the data; for the
            // open-ended "why?" the U27 summary export is the escape hatch —
            // this is the natural moment to offer it.
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  unawaited(showAiSummarySheet(nav.context));
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l.aiSummaryInsightsFooter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One insight line in the sheet: kind icon in severity color, the localized
/// message, tapping through to the parameter's history graph.
class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, color) = _insightVisual(insight, context);

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        unawaited(context.push('/history/${insight.paramKey}'));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.insightLabel(insight),
                style: theme.textTheme.bodyLarge,
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
