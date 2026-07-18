import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/settings.dart';
import '../../data/tank_summary_export.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_sheet.dart';

/// Opens the "Ask your AI" pre-share sheet (U27) for the active tank.
Future<void> showAiSummarySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const AiSummarySheet(),
  );
}

/// The pre-share sheet: privacy note, window chips (4/8/12 weeks), a preview
/// of the exact markdown that will leave the app (trust: the user sees
/// everything — notes included — before pasting it into a third-party chat),
/// and Copy / Share actions. Copy is primary: chat apps are paste-first, and
/// a plain-text share lands in a compose box where a `.md` attachment would
/// not.
class AiSummarySheet extends ConsumerStatefulWidget {
  const AiSummarySheet({super.key});

  @override
  ConsumerState<AiSummarySheet> createState() => _AiSummarySheetState();
}

class _AiSummarySheetState extends ConsumerState<AiSummarySheet> {
  /// Chip override for this sheet instance; null = follow the stored setting.
  int? _weeks;

  /// Memoized summary builds per window, so flipping between chips doesn't
  /// re-query and the FutureBuilder never sees a new Future on rebuild.
  /// Keyed only once the active tank is known (build gates on it) — memoizing
  /// a still-loading tank would freeze the sheet on the empty state.
  final Map<int, Future<String?>> _builds = {};

  Future<String?> _summaryFor(int tankId, int weeks) =>
      _builds.putIfAbsent(weeks, () {
        final db = ref.read(dbProvider);
        final l = AppLocalizations.of(context);
        final prefs = ref.read(unitPrefsProvider);
        // The document is presentation: Pro-gated computed layers (stability
        // score, smart insights) must not leak into a Standard-tier export
        // that the in-app teasers hide.
        final withStability = ref.read(
          proFeatureProvider(ProFeature.stabilityScore),
        );
        final withInsights = ref.read(
          proFeatureProvider(ProFeature.smartInsights),
        );
        return collectTankSummary(db, tankId: tankId, weeks: weeks).then(
          (data) => data == null
              ? null
              : encodeTankSummary(
                  data,
                  l: l,
                  prefs: prefs,
                  includeStability: withStability,
                  includeInsights: withInsights,
                ),
        );
      });

  void _selectWeeks(int weeks) {
    setState(() => _weeks = weeks);
    // Persist as the new default; device-local preference, best-effort.
    unawaited(ref.read(settingsProvider).setAiSummaryWeeks(weeks));
  }

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l.aiSummaryCopied)));
    // Dismiss the sheet: the copy is the job done (the user's next stop is
    // their chat app), and the root-scaffold SnackBar would otherwise be
    // hidden behind the modal barrier.
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weeks =
        _weeks ??
        (ref.watch(aiSummaryWeeksProvider).value ?? kAiSummaryDefaultWeeks);
    // Gate on the active tank: while the tank stream is still loading the
    // future must not be built (a memoized null-tank result would freeze the
    // sheet on the empty state).
    final tank = ref.watch(activeTankProvider);
    final tanksLoaded = ref.watch(tanksProvider).hasValue;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReefSheetHeader(
                l.aiSummaryAction,
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: ReefTokens.of(context).textDim,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.aiSummaryPrivacyNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in kAiSummaryWeekChoices)
                    ChoiceChip(
                      label: Text(l.aiSummaryWeeksChip(w)),
                      selected: w == weeks,
                      onSelected: (_) => _selectWeeks(w),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (tank == null && !tanksLoaded)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tank == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l.aiSummaryEmpty,
                    style: TextStyle(color: theme.hintColor),
                  ),
                )
              else
                Flexible(
                  child: FutureBuilder<String?>(
                    future: _summaryFor(tank.id, weeks),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final text = snapshot.data;
                      if (text == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            l.aiSummaryEmpty,
                            style: TextStyle(color: theme.hintColor),
                          ),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.aiSummaryPromptPreview.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.hintColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: SingleChildScrollView(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => unawaited(_copy(text)),
                                  icon: const Icon(Icons.copy),
                                  label: Text(l.aiSummaryCopyPrompt),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => unawaited(Share.share(text)),
                                  icon: const Icon(Icons.share),
                                  label: Text(l.share),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
