import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/reef_icon_button.dart';
import '../../widgets/reef_menu.dart';
import '../actions/actions_screen.dart';
import '../ai_summary/ai_summary_sheet.dart';
import '../dashboard/comparison_view.dart';
import '../dashboard/dashboard_screen.dart';
import '../dosing/dosing_screen.dart';
import '../import/measurement_import.dart';
import '../settings/settings_screen.dart';

/// Home screen hosting the app's primary peer destinations — Measurements,
/// Actions, Dosing, and Settings (U33) — behind a bottom [NavigationBar].
/// Owns the shared app bar (tank selector + contextual actions, shown on the
/// three content tabs; the Settings tab renders no app bar, only an inline
/// title) and a per-tab FAB. Tab bodies are kept alive via [IndexedStack] so
/// each preserves its scroll position and state when switching.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.tab});

  /// Optional tab request from a deep link (`/?tab=actions|dosing|settings`),
  /// e.g. a
  /// reminder-notification tap. Null (or an unknown value) leaves the current
  /// tab alone.
  final String? tab;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// The instance currently owning the ShowcaseView registration. During a
  /// route swap the incoming HomeShell mounts (and registers) *before* the
  /// outgoing one disposes, so an unguarded dispose-time unregister would tear
  /// down the new instance's registration — the showcase overlay then throws
  /// "No ShowcaseView registered" on its next rebuild (hit by the unknown-id
  /// redirect-home path).
  static _HomeShellState? _showcaseOwner;

  int _index = 0;

  /// Maps the deep-link `tab` value to a bottom-nav index; null = no change.
  static int? _tabIndex(String? tab) => switch (tab) {
    'measurements' => 0,
    'actions' => 1,
    'dosing' => 2,
    'settings' => 3,
    _ => null,
  };

  /// On the Measurements tab, whether to show the stacked-graph comparison view
  /// instead of the card grid. Kept here so it survives tab switches.
  bool _compare = false;

  /// Whether the previous build supplied a FAB to the Scaffold. Null until the
  /// first build. A false→true flip (returning from the FAB-less Settings tab,
  /// or the first tank appearing) is the moment the FAB *appears* — the one
  /// transition that plays the appear animation (see [_FabEntrance]); content
  /// tab switches swap FABs in place with no animation, and the very first
  /// build shows the FAB full-size.
  bool? _hadFab;

  // First-run feature tour (showcaseview). Each key tags a top-bar element the
  // tour spotlights. The dosing-history and dose-calculator icons only exist on
  // the Dosing tab, so the tour runs in two phases: phase 1 (tank → compare →
  // manage params) on the Measurements tab, then it switches to the Dosing tab
  // for phase 2 (dosing history → dose calculator) as its final steps.
  final GlobalKey _tankTourKey = GlobalKey();
  final GlobalKey _compareTourKey = GlobalKey();
  final GlobalKey _paramsTourKey = GlobalKey();
  final GlobalKey _dosingHistoryTourKey = GlobalKey();
  final GlobalKey _doseCalcTourKey = GlobalKey();

  /// Guards against re-triggering the tour on every rebuild within a session.
  /// Reset when the "seen" flag flips back to false (a replay request).
  bool _tourStarted = false;

  /// Which leg of the tour is running: 0 = idle, 1 = Measurements-tab steps,
  /// 2 = the Dosing-tab steps (dosing history, then dose calculator). Drives the
  /// tab switch in [onFinish] and the return to Measurements when the tour ends.
  int _tourPhase = 0;

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A repeat navigation to '/' with a tab query (notification tap while the
    // shell is already mounted) re-runs the route builder on this same state.
    final requested = _tabIndex(widget.tab);
    if (widget.tab != oldWidget.tab && requested != null) {
      setState(() => _index = requested);
    }
  }

  @override
  void initState() {
    super.initState();
    _index = _tabIndex(widget.tab) ?? 0;
    // Register the showcase controller for this screen's scope. Localized
    // tooltip text/buttons are supplied per-Showcase in build (where
    // AppLocalizations is available).
    _showcaseOwner = this;
    ShowcaseView.register(
      blurValue: 1,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        actionGap: 16,
      ),
      // Completing phase 1 switches to the Dosing tab and showcases the dosing
      // history then the dose calculator; completing phase 2 ends the tour and
      // returns to Measurements.
      onFinish: () {
        if (!mounted) return;
        if (_tourPhase == 1) {
          _tourPhase = 2;
          setState(() => _index = 2);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ShowcaseView.get().startShowCase([
              _dosingHistoryTourKey,
              _doseCalcTourKey,
            ], delay: const Duration(milliseconds: 350));
          });
        } else {
          _tourPhase = 0;
          _markTourSeen();
          setState(() => _index = 0);
        }
      },
      // Skipping returns to Measurements if we'd already switched to Dosing.
      onDismiss: (_) {
        if (!mounted) return;
        _markTourSeen();
        if (_tourPhase == 2) setState(() => _index = 0);
        _tourPhase = 0;
      },
    );
  }

  @override
  void dispose() {
    // Only the owning instance may unregister — see [_showcaseOwner].
    if (identical(_showcaseOwner, this)) {
      ShowcaseView.get().unregister();
      _showcaseOwner = null;
    }
    super.dispose();
  }

  /// Persists the "tour seen" flag. Called only when the tour actually ends —
  /// its final phase finishes or it is dismissed — never at start, so a tour
  /// interrupted by a background/rotate/kill still replays on next launch (#16).
  /// The in-session [_tourStarted] guard prevents a duplicate start meanwhile.
  void _markTourSeen() => ref.read(settingsProvider).setTourSeen(true);

  /// Starts the top-bar tour once a tank exists. The seen flag is persisted when
  /// the tour ends (see [_markTourSeen]), not here. Phase-1 targets (the compare
  /// toggle) only exist on the Measurements tab, so we force [_index] back to it
  /// before starting — this also makes "Replay tour" work no matter which tab
  /// was last open.
  void _maybeStartTour(bool hasTanks) {
    final seen = ref.watch(tourSeenProvider).value ?? true;
    // A replay resets the flag to false; allow the tour to fire again.
    ref.listen(tourSeenProvider, (_, next) {
      if (next.value == false) _tourStarted = false;
    });
    if (seen || !hasTanks || _tourStarted) return;
    _tourStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tourPhase = 1;
      if (_index != 0) setState(() => _index = 0);
      ShowcaseView.get().startShowCase([
        _tankTourKey,
        _compareTourKey,
        _paramsTourKey,
      ], delay: const Duration(milliseconds: 300));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tanksAsync = ref.watch(tanksProvider);
    final hasTanks = tanksAsync.value?.isNotEmpty ?? false;
    _maybeStartTour(hasTanks);

    final cs = Theme.of(context).colorScheme;
    final skipAction = TooltipActionButton(
      type: TooltipDefaultActionType.skip,
      name: l.tourSkip,
      backgroundColor: Colors.transparent,
      textStyle: TextStyle(color: cs.onSurfaceVariant),
    );
    TooltipActionButton nextAction(String name) => TooltipActionButton(
      type: TooltipDefaultActionType.next,
      name: name,
      backgroundColor: cs.primary,
      textStyle: TextStyle(color: cs.onPrimary),
    );
    Widget tourStep(
      GlobalKey key,
      String title,
      String description,
      String nextLabel,
      Widget child, {
      // IconButton targets carry their own tap-target padding; bare widgets
      // like the tank selector need explicit breathing room in the spotlight.
      EdgeInsets targetPadding = EdgeInsets.zero,
    }) => Showcase(
      key: key,
      title: title,
      description: description,
      targetPadding: targetPadding,
      tooltipActions: [skipAction, nextAction(nextLabel)],
      tooltipBackgroundColor: cs.surfaceContainerHighest,
      textColor: cs.onSurface,
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      child: child,
    );

    // The Settings tab lives behind the bottom bar, which is hidden with no
    // tanks — render Measurements then, so the welcome view keeps the shared
    // app bar (NoTanksView carries its own settings button, U33).
    final index = hasTanks ? _index : 0;

    // The FAB appear animation plays only when the FAB shows up after a build
    // that had none; `_hadFab == null` is the very first build, where the FAB
    // is shown full-size without any animation.
    final showFab = hasTanks && index != 3;
    final fabEntering = showFab && _hadFab == false;
    _hadFab = showFab;

    return Scaffold(
      // The Settings tab has no app bar — its body renders a plain inline
      // title instead (U33); every shared app-bar element is contextual to
      // the content tabs.
      appBar: index == 3
          ? null
          : AppBar(
              // The tank selector stays on all content tabs — every one of them is
              // tank-scoped, and the bottom-nav label already names the current
              // screen.
              title: tourStep(
                _tankTourKey,
                l.tourTankTitle,
                l.tourTankDesc,
                l.tourNext,
                const TankSelector(),
                targetPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              actions: [
                // Toggle the Measurements tab between the card grid and the stacked
                // comparison graphs.
                if (hasTanks && _index == 0)
                  tourStep(
                    _compareTourKey,
                    l.tourCompareTitle,
                    l.tourCompareDesc,
                    l.tourNext,
                    ReefIconButton(
                      tooltip: _compare ? l.gridView : l.compareView,
                      icon: _compare
                          ? Icons.grid_view
                          : Icons.stacked_line_chart,
                      onPressed: () => setState(() => _compare = !_compare),
                    ),
                  ),
                // Maintenance schedule (U12), contextual to the Actions tab.
                if (hasTanks && _index == 1)
                  ReefIconButton(
                    tooltip: l.maintenanceSchedule,
                    icon: Icons.event_repeat,
                    onPressed: () => context.push('/schedule'),
                  ),
                // Dosing history, contextual to the Dosing tab. First step of phase 2.
                if (hasTanks && _index == 2)
                  tourStep(
                    _dosingHistoryTourKey,
                    l.tourDosingHistoryTitle,
                    l.tourDosingHistoryDesc,
                    l.tourNext,
                    ReefIconButton(
                      tooltip: l.dosingHistoryTitle,
                      icon: Icons.history,
                      onPressed: () => context.push('/dosing/history'),
                    ),
                  ),
                // Dose calculator, contextual to the Dosing tab. The tour switches to
                // this tab to spotlight it as its final step.
                if (hasTanks && _index == 2)
                  tourStep(
                    _doseCalcTourKey,
                    l.tourDoseCalcTitle,
                    l.tourDoseCalcDesc,
                    l.tourDone,
                    ReefIconButton(
                      tooltip: l.doseCalcTitle,
                      icon: Icons.calculate_outlined,
                      // Pro-gated (U19): founders (and, later, Pro purchasers) open
                      // the calculator; anyone else gets the explanation dialog.
                      onPressed:
                          ref.watch(
                            proFeatureProvider(ProFeature.doseCalculator),
                          )
                          ? () => context.push('/dosing/calculator')
                          : () => showProFeatureDialog(
                              context,
                              ProFeature.doseCalculator,
                            ),
                    ),
                  ),
                tourStep(
                  _paramsTourKey,
                  l.tourParamsTitle,
                  l.tourParamsDesc,
                  l.tourNext,
                  ReefIconButton(
                    tooltip: l.manageParameters,
                    icon: Icons.tune,
                    onPressed: () => context.push('/parameters'),
                  ),
                ),
                // Overflow menu, contextual to the Measurements tab (the bar is at
                // icon capacity): the "Ask your AI" summary export (U27) and the
                // measurement import (U32); future share-ish actions join here.
                if (hasTanks && _index == 0)
                  ReefMenuButton<String>(
                    // Same mini-card look as the ReefIconButtons.
                    icon: Icons.more_vert,
                    iconStyle: reefIconButtonStyle(context),
                    onSelected: (v) {
                      if (v == 'ai-summary') {
                        unawaited(showAiSummarySheet(context));
                      }
                      if (v == 'import-measurements') {
                        // Pro-gated (U19): founders (and, later, Pro purchasers)
                        // import; anyone else gets the explanation dialog.
                        if (ref.read(
                          proFeatureProvider(ProFeature.hannaImport),
                        )) {
                          unawaited(runMeasurementImportFlow(context));
                        } else {
                          unawaited(
                            showProFeatureDialog(
                              context,
                              ProFeature.hannaImport,
                            ),
                          );
                        }
                      }
                      if (v == 'hanna-measure') {
                        // Hanna checker live measurement (U33, experimental),
                        // same gate idiom.
                        if (ref.read(
                          proFeatureProvider(ProFeature.hannaConnect),
                        )) {
                          unawaited(context.push('/hanna/measure'));
                        } else {
                          unawaited(
                            showProFeatureDialog(
                              context,
                              ProFeature.hannaConnect,
                            ),
                          );
                        }
                      }
                      if (v == 'hanna-scan') {
                        // Checker camera scan (U34): this menu entry is the
                        // *teaser* surface — it only shows for non-entitled
                        // installs (entitled ones get the scan FAB instead),
                        // so the normal outcome is the Pro dialog.
                        if (ref.read(
                          proFeatureProvider(ProFeature.hannaScan),
                        )) {
                          unawaited(context.push('/hanna/scan'));
                        } else {
                          unawaited(
                            showProFeatureDialog(
                              context,
                              ProFeature.hannaScan,
                            ),
                          );
                        }
                      }
                    },
                    entries: [
                      ReefMenuItem(
                        value: 'ai-summary',
                        icon: Icons.auto_awesome_outlined,
                        label: l.aiSummaryAction,
                      ),
                      ReefMenuItem(
                        value: 'import-measurements',
                        icon: Icons.move_to_inbox_outlined,
                        label: l.measurementImportTitle,
                      ),
                      // The Hanna entries only exist while experimental
                      // features are opted into (Settings → Experimental);
                      // the BLE one is additionally hidden on devices without
                      // a BLE stack — the manifest keeps Bluetooth optional
                      // so Play doesn't filter the app there.
                      if ((ref.watch(experimentalEnabledProvider).value ??
                              false) &&
                          (ref.watch(hannaBleSupportedProvider).value ?? true))
                        ReefMenuItem(
                          value: 'hanna-measure',
                          icon: Icons.bluetooth,
                          label: l.hannaMeasureAction,
                        ),
                      // Shown whenever the scan FAB isn't: the teaser for
                      // non-entitled installs, and the regular entry point
                      // for entitled ones who keep the opt-in quick button
                      // (Settings → Experimental) off.
                      if ((ref.watch(experimentalEnabledProvider).value ??
                              false) &&
                          !(ref.watch(
                                proFeatureProvider(ProFeature.hannaScan),
                              ) &&
                              (ref.watch(hannaScanFabProvider).value ??
                                  false)))
                        ReefMenuItem(
                          value: 'hanna-scan',
                          icon: Icons.photo_camera_outlined,
                          label: l.hannaScanTitle,
                        ),
                    ],
                  ),
              ],
            ),
      body: tanksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e.toString()))),
        data: (tanks) {
          if (tanks.isEmpty) return const NoTanksView();
          return IndexedStack(
            index: index,
            children: [
              _compare ? const ComparisonBody() : const DashboardBody(),
              const ActionsBody(),
              const DosingBody(),
              const _SettingsTab(),
            ],
          );
        },
      ),
      // Tab content extends behind the translucent tab bar so the backdrop
      // blur has something to frost; scrollables inside the tabs take the
      // bar's height as MediaQuery bottom padding.
      extendBody: true,
      bottomNavigationBar: hasTanks
          // The mockup's tab bar is translucent `tabBarBg` over a blur. The
          // ClipRect bounds the BackdropFilter to the bar; the foreground
          // DecoratedBox paints the 1 px hairline *over* the bar's own
          // translucent background (NavigationBar has no border slot).
          // Open question #5: if the blur regresses frame times on low-end
          // devices, drop the ClipRect+BackdropFilter and make `tabBarBg`
          // opaque.
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: ReefTokens.of(context).surfaceBorder,
                      ),
                    ),
                  ),
                  child: _buildNavigationBar(l),
                ),
              ),
            )
          : null,
      // No FAB on the Settings tab — there is nothing to add there.
      floatingActionButton: showFab ? _buildFab(context, l, fabEntering) : null,
      // The stock entrance (scale + ~45° turn, pivoting on the whole child)
      // is replaced by [_FabEntrance] so every tab animates identically.
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
    );
  }

  NavigationBar _buildNavigationBar(AppLocalizations l) {
    return NavigationBar(
      // Height (64 — compact vs the 80 M3 default), label behavior, colors
      // and the per-platform active-tab treatment come from
      // `navigationBarTheme` in theme.dart.
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.speed_outlined),
          selectedIcon: const Icon(Icons.speed),
          label: l.measurements,
        ),
        NavigationDestination(
          // Keep the outlined glyph even when selected.
          icon: const Icon(Icons.fact_check_outlined),
          selectedIcon: const Icon(Icons.fact_check_outlined),
          label: l.actions,
        ),
        NavigationDestination(
          // Keep the outlined glyph even when selected.
          icon: const Icon(Icons.science_outlined),
          selectedIcon: const Icon(Icons.science_outlined),
          label: l.dosing,
        ),
        NavigationDestination(
          // Keep the outlined glyph even when selected.
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_outlined),
          label: l.settings,
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context, AppLocalizations l, bool entering) {
    return _FabEntrance(
      entering: entering,
      builder: (scale) {
        if (_index == 0) {
          // Manual entry stays the primary FAB; the checker camera scan (U34)
          // rides above it as a small sibling — it is the same action done
          // faster, and it must be thumb-reachable while the other hand holds
          // the checker (which rules out the already-full top bar). Triple
          // opt-in: experimental features on, the quick-button preference on
          // (both Settings → Experimental — most users don't own a pocket
          // checker, so the space is off by default), and the install entitled
          // (a locked FAB would be prime-real-estate frustration). Everyone
          // else keeps the overflow-menu entry instead.
          final showScanFab =
              (ref.watch(experimentalEnabledProvider).value ?? false) &&
              (ref.watch(hannaScanFabProvider).value ?? false) &&
              ref.watch(proFeatureProvider(ProFeature.hannaScan));
          // Each button scales about itself (the Column keeps its layout box)
          // so the appear animation matches the single-FAB tabs exactly.
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showScanFab) ...[
                ScaleTransition(
                  scale: scale,
                  child: FloatingActionButton.small(
                    heroTag: 'hanna-scan-fab',
                    tooltip: l.hannaScanTitle,
                    onPressed: () => unawaited(context.push('/hanna/scan')),
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ScaleTransition(
                scale: scale,
                child: FloatingActionButton.extended(
                  onPressed: () => context.push('/add-reading'),
                  icon: const Icon(Icons.add),
                  label: Text(l.addReading),
                ),
              ),
            ],
          );
        }
        if (_index == 1) {
          return ScaleTransition(
            scale: scale,
            child: FloatingActionButton.extended(
              onPressed: () => showAddActionSheet(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.addAction),
            ),
          );
        }
        return ScaleTransition(
          scale: scale,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/dosing/edit'),
            icon: const Icon(Icons.add),
            label: Text(l.addSupplement),
          ),
        );
      },
    );
  }
}

/// Plays the FAB appear animation, identically on every tab.
///
/// The [Scaffold]'s stock entrance (a scale-in plus a ~45° turn, both pivoting
/// on the center of the whole `floatingActionButton` child) is disabled via
/// [FloatingActionButtonAnimator.noAnimation]: on the Measurements tab the FAB
/// can be a two-button column, and pivoting on the *column's* center makes the
/// buttons swing and slide into place — visibly different from the single-pill
/// tabs. Instead, this wrapper drives one shared scale animation (the stock
/// [kFloatingActionButtonSegue] timing and ease-in curve, no turn) that
/// [builder] applies per button, each pivoting on itself.
///
/// [entering] is read once at mount: true plays the scale-in (the FAB slot was
/// empty — coming from the FAB-less Settings tab), false shows the child
/// full-size immediately (content-tab switches swap FABs in place, which the
/// framework does not animate either).
class _FabEntrance extends StatefulWidget {
  const _FabEntrance({required this.entering, required this.builder});

  final bool entering;

  final Widget Function(Animation<double> scale) builder;

  @override
  State<_FabEntrance> createState() => _FabEntranceState();
}

class _FabEntranceState extends State<_FabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kFloatingActionButtonSegue,
    value: widget.entering ? 0.0 : 1.0,
  );

  late final CurvedAnimation _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    if (widget.entering) unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _scale.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_scale);
}

/// The Settings tab body (U33): no app bar, only an inline title above the
/// shared [SettingsBody]. The [SafeArea] eats the status-bar inset the other
/// tabs get from the shared app bar; `bottom: false` keeps the translucent
/// tab bar's height in the ambient `MediaQuery` padding so the settings list
/// scrolls behind the frosted bar like every other tab.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Mirrors the app-bar title position/style on the content tabs.
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              l.settings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Expanded(child: SettingsBody()),
        ],
      ),
    );
  }
}
