import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/ammonia_toxicity.dart' show kSalinityKey;
import '../../domain/dose_calculator.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_segmented.dart';
import '../../widgets/trend_chart.dart';
import 'dosing_screen.dart' show formatDoseAmount;
import 'manual_dose_edit_screen.dart' show ManualDoseDraft;

/// The calculator's two modes: the consumption-based daily-dose adjustment,
/// and the one-off correction ("emergency") dose toward a target value.
enum _CalcMode { maintenance, correction }

/// Dose calculator (Dosing tab → calculator; also reachable from a
/// parameter's history screen).
///
/// **Daily dose** mode pulls the active tank's stored readings, dosing plan
/// and volume to estimate how fast an element is consumed and what daily dose
/// holds it steady. **Correction** mode computes the one-off dose that raises
/// the element from its current value to a target, splitting it over several
/// days when the rise would exceed the element's safe daily limit
/// (`kMaxDailyRiseByElement`). All inputs are editable. Water changes are
/// intentionally ignored. The math lives in `domain/dose_calculator.dart`.
class DoseCalculatorScreen extends ConsumerStatefulWidget {
  const DoseCalculatorScreen({
    super.key,
    this.initialElement,
    this.startInCorrection = false,
  });

  /// Element to open with (already validated against `kDosingElementKeys` by
  /// the router); null derives the default from the dosing plan.
  final String? initialElement;

  /// Opens in correction mode (the history screen's below-range CTA).
  final bool startInCorrection;

  @override
  ConsumerState<DoseCalculatorScreen> createState() =>
      _DoseCalculatorScreenState();
}

class _DoseCalculatorScreenState extends ConsumerState<DoseCalculatorScreen> {
  String? _element;
  ChartRange _range = ChartRange.month;
  late _CalcMode _mode = widget.startInCorrection
      ? _CalcMode.correction
      : _CalcMode.maintenance;

  final _volumeCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  // Optional total of one-off manual doses given inside the window. Spread
  // over the window's span it joins the input side of the consumption math.
  // Later this can be pre-filled from a manual dosing log.
  final _manualDoseCtrl = TextEditingController();
  // Correction mode: empty fields fall back to live defaults (the latest
  // reading / the stored target) shown as hints — no async prefill needed,
  // and an element switch updates the defaults automatically.
  final _currentCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  DoseUnit _doseUnit = DoseUnit.ml;

  // Potency: either pulled from the catalog or entered as a reference dose.
  double? _catalogPotency;
  bool _useCatalogPotency = false;
  final _refAmountCtrl = TextEditingController();
  final _refVolCtrl = TextEditingController();
  final _riseCtrl = TextEditingController();

  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // An element handed in by the entry point (history screen) wins over the
    // plan-derived default the listener below would pick.
    _element = widget.initialElement;
    // Prefill from a provider listener, not from build() (#18): a late stream
    // emission used to overwrite whatever the user had typed meanwhile. The
    // one-shot `_prefilled` guard plus `onlyIfEmpty` keeps user input intact.
    var inInitState = true;
    ref.listenManual(dosingEntriesProvider, fireImmediately: true, (_, next) {
      if (_prefilled || !next.hasValue) return;
      _prefilled = true;
      final entries = next.value ?? const <DosingEntry>[];
      _element ??= _defaultElement(entries);
      _applyPrefill(
        element: _element!,
        tank: ref.read(activeTankProvider),
        entries: entries,
        volUnit: ref.read(unitPrefsProvider).volume,
        prefillVolume: true,
        onlyIfEmpty: true,
      );
      // When the entries arrive asynchronously the widget is already built and
      // needs a rebuild; during initState the first build is still ahead.
      if (!inInitState) setState(() {});
    });
    inInitState = false;
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _doseCtrl.dispose();
    _manualDoseCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    _refAmountCtrl.dispose();
    _refVolCtrl.dispose();
    _riseCtrl.dispose();
    super.dispose();
  }

  double? _parse(String s) => parseUserDouble(s);

  String _defaultElement(List<DosingEntry> entries) {
    for (final e in entries) {
      final k = e.elementKey;
      if (k != null && kDosingElementKeys.contains(k)) return k;
    }
    return kDosingElementKeys.first;
  }

  /// Fills the dose, dose-unit and potency fields for [element]; optionally also
  /// the tank volume. Reads the plan entries for this element. With
  /// [onlyIfEmpty] (the initial async prefill) text the user has already typed
  /// is never overwritten (#18); an explicit element change overwrites.
  void _applyPrefill({
    required String element,
    required Tank? tank,
    required List<DosingEntry> entries,
    required VolumeUnit volUnit,
    required bool prefillVolume,
    bool onlyIfEmpty = false,
  }) {
    if (prefillVolume && !(onlyIfEmpty && _volumeCtrl.text.isNotEmpty)) {
      final v = tank?.volumeLiters;
      _volumeCtrl.text = v == null ? '' : formatVolume(v, volUnit);
    }

    var sum = 0.0;
    DoseUnit? unit;
    double? catalog;
    for (final e in entries.where((e) => e.elementKey == element)) {
      sum += dailyEquivalentDose(e.schedule);
      if (e.amount != null) unit ??= DoseUnit.fromName(e.amountUnit);
      final key = e.productKey;
      if (key != null) {
        catalog ??= kSupplementProductByKey[key]?.strength?[element];
      }
    }
    if (!(onlyIfEmpty && _doseCtrl.text.isNotEmpty)) {
      _doseUnit = unit ?? DoseUnit.ml;
      _doseCtrl.text = sum > 0 ? formatDoseAmount(sum) : '';
    }
    _catalogPotency = catalog;
    _useCatalogPotency = catalog != null;
    if (catalog == null) {
      if (_refAmountCtrl.text.isEmpty) _refAmountCtrl.text = '10';
      if (_refVolCtrl.text.isEmpty) {
        _refVolCtrl.text = formatVolume(100, volUnit);
      }
    }
  }

  double? _effectivePotency(VolumeUnit volUnit) {
    if (_useCatalogPotency && _catalogPotency != null) return _catalogPotency;
    final a = _parse(_refAmountCtrl.text);
    final rv = _parse(_refVolCtrl.text);
    final rise = _parse(_riseCtrl.text);
    if (a == null || rv == null || rise == null) return null;
    return potencyFromReference(
      doseAmount: a,
      refVolumeLiters: volumeToCanonical(rv, volUnit),
      rise: rise,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(unitPrefsProvider);
    final volUnit = prefs.volume;
    final tank = ref.watch(activeTankProvider);
    final entriesAsync = ref.watch(dosingEntriesProvider);
    final entries = entriesAsync.value ?? const <DosingEntry>[];
    final element = _element ?? kDosingElementKeys.first;

    final readings =
        ref.watch(paramReadingsProvider(element)).value ?? const [];
    final windowStart = _range.days == null
        ? null
        : DateTime.now().subtract(Duration(days: _range.days!));
    final points = <DosePoint>[
      for (final r in readings)
        if (windowStart == null || r.takenAt.isAfter(windowStart))
          (t: r.takenAt, value: r.value),
    ];

    final slope = slopePerDay(points);
    final dose = _parse(_doseCtrl.text) ?? 0;
    final volDisp = _parse(_volumeCtrl.text);
    final volLiters = volDisp == null
        ? null
        : volumeToCanonical(volDisp, volUnit);
    final potency = _effectivePotency(volUnit);

    // Logged one-off doses inside the fitted span (first → last reading, same
    // element). Doses in the plan's other unit can't join the sum — they are
    // counted and warned about instead. Doses of a *different catalog product*
    // still count but may not share the potency below; warn (phase 1).
    final allManual = ref.watch(manualDosesProvider).value ?? const [];
    var logged = const <ManualDose>[];
    var unitMismatch = 0;
    if (points.length >= 2) {
      final inWindow = manualDosesInWindow(
        allManual.where((d) => d.elementKey == element),
        time: (d) => d.dosedAt,
        from: points.first.t,
        to: points.last.t,
      );
      logged = [
        for (final d in inWindow)
          if (DoseUnit.fromName(d.amountUnit) == _doseUnit) d,
      ];
      unitMismatch = inWindow.length - logged.length;
    }
    final loggedTotal = logged.fold(0.0, (sum, d) => sum + d.amount);
    final productMismatch =
        potency != null &&
        logged.any((d) {
          final strength =
              kSupplementProductByKey[d.productKey]?.strength?[element];
          return strength != null &&
              (strength - potency).abs() > 0.005 * potency;
        });

    // A one-off manual total is averaged over the span the slope was fitted
    // on (first → last reading), so both sides of the math cover the same
    // period. With fewer than two readings the slope is null anyway. An empty
    // field defaults to the logged total; typing overrides it.
    final spanDays = points.length < 2
        ? 0.0
        : points.last.t.difference(points.first.t).inMilliseconds / 86400000.0;
    final manualTotal = _parse(_manualDoseCtrl.text) ?? loggedTotal;
    final manualDaily = spanDays > 0 ? manualTotal / spanDays : 0.0;

    final result = computeDoseCalc(
      slopePerDay: slope,
      currentDailyDose: dose,
      manualDailyDose: manualDaily,
      potency: potency,
      volumeLiters: volLiters,
    );

    // The active plan assumes the current dose held for the whole window. If a
    // dose segment for this element started mid-window (there are readings
    // before it), warn that the slope mixes two dose regimes.
    final doseChangedAt = _doseChangedInWindow(entries, element, points);

    // Correction mode: current value defaults to the latest stored reading,
    // target to the tracked parameter's stored target (falling back to the
    // middle of its green zone). Typing in a field overrides the default.
    final latestReading = readings.isEmpty ? null : readings.last.value;
    final trackedRow = (ref.watch(trackedParametersProvider).value ?? const [])
        .where((t) => t.paramKey == element)
        .cast<TrackedParameter?>()
        .firstWhere((t) => true, orElse: () => null);
    final defaultTarget = trackedRow == null
        ? null
        : trackedRow.targetValue ?? _greenMid(boundsOf(trackedRow));
    // Salinity-adjusted target: when the per-tank switch is on, the
    // 35 ppt-referenced target — typed or default, both are "book" values —
    // is scaled to the tank's measured salinity. The target *field* keeps
    // showing 35 ppt values (hint included) so a typed value and the
    // empty-field default run through the same scaling; the switch tile
    // displays the base → adjusted mapping.
    final salReadings =
        ref.watch(paramReadingsProvider(kSalinityKey)).value ?? const [];
    final tankSal = resolveTankSalinity([
      for (final r in salReadings) (t: r.takenAt, value: r.value),
    ], now: DateTime.now());
    final adjustStored = ref.watch(doseCalcSalinityAdjustProvider);
    final baseTarget = _parse(_targetCtrl.text) ?? defaultTarget;
    final target = adjustStored && tankSal != null && baseTarget != null
        ? adjustTargetForSalinity(baseTarget, tankSal.ppt)
        : baseTarget;
    final adjustActive = adjustStored && tankSal != null;
    final maxRise = kMaxDailyRiseByElement[element];
    final correction = computeCorrectionDose(
      current: _parse(_currentCtrl.text) ?? latestReading,
      target: target,
      potency: potency,
      volumeLiters: volLiters,
      maxDailyRise: maxRise,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.doseCalcTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ReefSegmented<_CalcMode>(
              options: [
                (_CalcMode.maintenance, l.doseCalcModeMaintenance),
                (_CalcMode.correction, l.doseCalcModeCorrection),
              ],
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _mode == _CalcMode.maintenance
                ? l.doseCalcIntro
                : l.doseCalcCorrIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _elementField(l, tank, entries, volUnit),
          const SizedBox(height: 16),
          if (_mode == _CalcMode.maintenance) ...[
            _windowField(l, points.length),
            const Divider(height: 32),
            _volumeField(l, volUnit),
            const SizedBox(height: 16),
            _doseField(l),
            const SizedBox(height: 16),
            _manualDoseField(
              l,
              loggedCount: logged.length,
              loggedTotal: loggedTotal,
              unitMismatch: unitMismatch,
              productMismatch: productMismatch,
            ),
            const Divider(height: 32),
            _potencySection(l, element, volUnit, volLiters, potency),
            const Divider(height: 32),
            if (doseChangedAt != null) ...[
              _doseChangedWarning(l, doseChangedAt),
              const SizedBox(height: 12),
            ],
            _resultCard(l, element, result),
          ] else ...[
            _volumeField(l, volUnit),
            const SizedBox(height: 16),
            _correctionFields(l, element, latestReading, defaultTarget),
            const SizedBox(height: 4),
            _salinityAdjustTile(
              l,
              prefs,
              element,
              tank,
              tankSal,
              stored: adjustStored,
              baseTarget: baseTarget,
              adjustedTarget: adjustActive ? target : null,
            ),
            const Divider(height: 32),
            _potencySection(l, element, volUnit, volLiters, potency),
            const Divider(height: 32),
            _correctionResultCard(
              l,
              element,
              correction,
              maxRise,
              adjustedTarget: adjustActive ? target : null,
            ),
          ],
        ],
      ),
    );
  }

  /// The midpoint of the green zone (or its only bound when one side is
  /// unbounded) — the correction-target fallback when no explicit target is
  /// stored.
  double? _greenMid(ZoneBounds b) {
    final lo = b.greenLow;
    final hi = b.greenHigh;
    if (lo != null && hi != null) return (lo + hi) / 2;
    return lo ?? hi;
  }

  /// The most recent dose-segment start for [element] that falls inside the
  /// measurement [points] (i.e. some readings predate it), or null when the
  /// dose held for the whole window. Single-element only in this phase.
  DateTime? _doseChangedInWindow(
    List<DosingEntry> entries,
    String element,
    List<DosePoint> points,
  ) {
    DateTime? boundary;
    for (final e in entries.where((e) => e.elementKey == element)) {
      final s = e.startedAt;
      if (s != null && (boundary == null || s.isAfter(boundary))) boundary = s;
    }
    if (boundary == null) return null;
    return points.any((p) => p.t.isBefore(boundary!)) ? boundary : null;
  }

  Widget _doseChangedWarning(AppLocalizations l, DateTime changedAt) {
    final scheme = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(context).formatMediumDate(changedAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 20, color: scheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.doseCalcDoseChanged(date),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.tertiary),
          ),
        ),
      ],
    );
  }

  Widget _elementField(
    AppLocalizations l,
    Tank? tank,
    List<DosingEntry> entries,
    VolumeUnit volUnit,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: _element,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.doseCalcElement),
      items: [
        for (final key in kDosingElementKeys)
          DropdownMenuItem(value: key, child: Text(l.paramName(key))),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _element = v;
          _applyPrefill(
            element: v,
            tank: tank,
            entries: entries,
            volUnit: volUnit,
            prefillVolume: false,
          );
        });
      },
    );
  }

  Widget _windowField(AppLocalizations l, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ChartRange>(
          initialValue: _range,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.doseCalcWindow),
          items: [
            for (final r in ChartRange.values)
              DropdownMenuItem(value: r, child: Text(chartRangeLabel(l, r))),
          ],
          onChanged: (v) => setState(() => _range = v ?? _range),
        ),
        const SizedBox(height: 6),
        Text(
          l.doseCalcReadings(count),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _volumeField(AppLocalizations l, VolumeUnit volUnit) {
    return TextField(
      controller: _volumeCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: ReefTokens.monoInputStyle,
      decoration: InputDecoration(
        labelText: l.doseCalcVolume,
        suffixText: volUnit.symbol,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _doseField(AppLocalizations l) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _doseCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: ReefTokens.monoInputStyle,
            decoration: InputDecoration(
              labelText: l.doseCalcCurrentDose,
              suffixText: '${_doseUnit.symbol} / ${l.doseCalcPerDay}',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _manualDoseField(
    AppLocalizations l, {
    required int loggedCount,
    required double loggedTotal,
    required int unitMismatch,
    required bool productMismatch,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _manualDoseCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: ReefTokens.monoInputStyle,
          decoration: InputDecoration(
            labelText: l.doseCalcManualDose,
            helperText: l.doseCalcManualDoseHelp,
            helperMaxLines: 3,
            // The logged total shows in place while the field is empty — it
            // is what the calculation uses until the user overrides it.
            hintText: loggedCount > 0 ? formatDoseAmount(loggedTotal) : null,
            suffixText: _doseUnit.symbol,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (loggedCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            l.doseCalcLoggedDoses(
              loggedCount,
              '${formatDoseAmount(loggedTotal)} ${_doseUnit.symbol}',
            ),
            style: small?.copyWith(color: scheme.outline),
          ),
        ],
        if (unitMismatch > 0) ...[
          const SizedBox(height: 6),
          Text(
            l.doseCalcLoggedUnitMismatch(unitMismatch),
            style: small?.copyWith(color: scheme.error),
          ),
        ],
        if (productMismatch) ...[
          const SizedBox(height: 6),
          Text(
            l.doseCalcLoggedProductMismatch,
            style: small?.copyWith(color: scheme.tertiary),
          ),
        ],
      ],
    );
  }

  Widget _potencySection(
    AppLocalizations l,
    String element,
    VolumeUnit volUnit,
    double? volLiters,
    double? potency,
  ) {
    final unitStr = kParameterByKey[element]?.unit ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.doseCalcPotencyTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_catalogPotency != null)
              TextButton(
                onPressed: () =>
                    setState(() => _useCatalogPotency = !_useCatalogPotency),
                child: Text(
                  _useCatalogPotency
                      ? l.doseCalcEnterManually
                      : l.doseCalcUseCatalog,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_useCatalogPotency && _catalogPotency != null)
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l.doseCalcPotencyFromCatalog)),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: ReefTokens.monoInputStyle,
                  decoration: InputDecoration(
                    labelText: l.doseCalcRefAmount,
                    suffixText: _doseUnit.symbol,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _refVolCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: ReefTokens.monoInputStyle,
                  decoration: InputDecoration(
                    labelText: l.doseCalcRefVolume,
                    suffixText: volUnit.symbol,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _riseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: ReefTokens.monoInputStyle,
                  decoration: InputDecoration(
                    labelText: l.doseCalcRise,
                    suffixText: unitStr,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        if (potency != null && volLiters != null && volLiters > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.doseCalcRaises(
              '${_trim(potency / volLiters)} $unitStr / ${_doseUnit.symbol}',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultCard(AppLocalizations l, String element, DoseCalcResult r) {
    final tokens = ReefTokens.of(context);
    final unitStr = kParameterByKey[element]?.unit ?? '';

    String rate(double? v) =>
        v == null ? '—' : '${_signed(v)} $unitStr / ${l.doseCalcPerDay}';
    String addRate(double? v) =>
        v == null ? '—' : '${_trim(v)} $unitStr / ${l.doseCalcPerDay}';

    final rows = <Widget>[];
    if (r.observedChangePerDay != null) {
      rows.add(
        _resultRow(l.doseCalcObservedChange, rate(r.observedChangePerDay)),
      );
    }
    if (r.consumptionPerDay != null) {
      rows.add(_resultRow(l.doseCalcConsumption, addRate(r.consumptionPerDay)));
    }
    if ((r.dosingInputPerDay ?? 0) > 0) {
      rows.add(
        _resultRow(l.doseCalcCurrentInput, addRate(r.dosingInputPerDay)),
      );
    }
    if ((r.manualInputPerDay ?? 0) > 0) {
      rows.add(_resultRow(l.doseCalcManualInput, addRate(r.manualInputPerDay)));
    }
    if (r.suggestedDailyDose != null) {
      rows.add(
        _resultRow(
          l.doseCalcSuggestedDose,
          '${formatDoseAmount(r.suggestedDailyDose!)} ${_doseUnit.symbol} / '
          '${l.doseCalcPerDay}',
          emphasize: true,
        ),
      );
    }
    if (r.adjustment != null) {
      final adj = r.adjustment!;
      rows.add(
        _resultRow(
          l.doseCalcAdjustment,
          '${adj >= 0 ? '+' : '−'}${formatDoseAmount(adj.abs())} '
          '${_doseUnit.symbol}',
        ),
      );
    }

    // The result as a `ReefCard` with §A.8-stats-style mono values
    // (REDESIGN #21) — the old hardcoded `surfaceContainerHighest` fill is
    // retired.
    return ReefCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.doseCalcResultsTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
          if (rows.isNotEmpty) const SizedBox(height: 12),
          _statusBanner(l, r.status),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool emphasize = false}) {
    final tokens = ReefTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                color: tokens.textDim,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: ReefTokens.monoTextStyle.copyWith(
              fontSize: emphasize ? 17 : 15,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
        ],
      ),
    );
  }

  /// Current / target value fields for correction mode. Both work in the
  /// element's canonical unit (like the rest of the calculator) and show
  /// their live default as the hint while empty.
  Widget _correctionFields(
    AppLocalizations l,
    String element,
    double? latestReading,
    double? defaultTarget,
  ) {
    final def = kParameterByKey[element];
    final unitStr = def?.unit ?? '';
    String? fmt(double? v) =>
        v == null ? null : formatLocaleNumber(v, def?.decimals ?? 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _currentCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: ReefTokens.monoInputStyle,
          decoration: InputDecoration(
            labelText: l.doseCalcCurrentValue,
            helperText: l.doseCalcCurrentValueHelp,
            helperMaxLines: 2,
            hintText: fmt(latestReading),
            suffixText: unitStr,
            // Keep the label floated so the live default (the hint) stays
            // visible while the field is empty and unfocused.
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _targetCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: ReefTokens.monoInputStyle,
          decoration: InputDecoration(
            labelText: l.doseCalcTargetValue,
            helperText: l.doseCalcTargetValueHelp,
            helperMaxLines: 3,
            hintText: fmt(defaultTarget),
            suffixText: unitStr,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  /// Correction-mode switch that scales the 35 ppt-referenced target (typed
  /// or default) to the tank's measured salinity. Disabled, with the subtitle
  /// saying why, while the tank has no salinity reading at all; a lone
  /// reading older than [kSalinityAdjustWindow] still works but the subtitle
  /// flags its age.
  Widget _salinityAdjustTile(
    AppLocalizations l,
    UnitPrefs prefs,
    String element,
    Tank? tank,
    TankSalinity? tankSal, {
    required bool stored,
    required double? baseTarget,
    required double? adjustedTarget,
  }) {
    final def = kParameterByKey[element];
    String fmtT(double v) =>
        '${formatLocaleNumber(v, def?.decimals ?? 2)} ${def?.unit ?? ''}';

    String subtitle;
    if (tankSal == null) {
      subtitle = l.doseCalcSalinityNone;
    } else if (adjustedTarget == null || baseTarget == null) {
      subtitle = l.doseCalcSalinityAdjustHelp;
    } else {
      // The measured salinity rides the user's display unit (ppt or SG),
      // like everywhere else salinity is shown.
      final salPres = presentationFor(kSalinityKey, 'SG', 3, prefs);
      subtitle = l.doseCalcSalinityAdjustActive(
        '${salPres.format(pptToSg(tankSal.ppt))} ${salPres.unitLabel}',
        fmtT(adjustedTarget),
        fmtT(baseTarget),
      );
      final age = DateTime.now().difference(tankSal.measuredAt).inDays;
      if (age > kSalinityAdjustWindow.inDays) {
        subtitle = '$subtitle ${l.doseCalcSalinityStale(age)}';
      }
    }

    return SwitchListTile(
      value: stored && tankSal != null,
      onChanged: tankSal == null || tank == null
          ? null
          : (v) => unawaited(
              ref.read(settingsProvider).setDoseCalcSalinityAdjust(tank.id, v),
            ),
      title: Text(l.doseCalcSalinityAdjust),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Result card for correction mode: the needed rise, the one-time dose —
  /// or, when the rise exceeds the element's safe daily limit, the plan to
  /// spread it — plus a status banner and a "log this dose" handoff into the
  /// manual dose log. [adjustedTarget] (the salinity-scaled target actually
  /// used, when that switch is active) gets its own row so the dose is
  /// traceable to the number it aims at.
  Widget _correctionResultCard(
    AppLocalizations l,
    String element,
    CorrectionResult r,
    double? maxRise, {
    double? adjustedTarget,
  }) {
    final tokens = ReefTokens.of(context);
    final unitStr = kParameterByKey[element]?.unit ?? '';

    final rows = <Widget>[];
    if (adjustedTarget != null) {
      rows.add(
        _resultRow(l.doseCalcAdjustedTarget, '${_trim(adjustedTarget)} $unitStr'),
      );
    }
    final rise = r.rise;
    if (rise != null && rise > 0) {
      rows.add(_resultRow(l.doseCalcNeededRise, '+${_trim(rise)} $unitStr'));
    }
    switch (r.status) {
      case CorrectionStatus.singleDose:
        rows.add(
          _resultRow(
            l.doseCalcOneTimeDose,
            '${formatDoseAmount(r.totalDose!)} ${_doseUnit.symbol}',
            emphasize: true,
          ),
        );
      case CorrectionStatus.splitDose:
        rows
          ..add(
            _resultRow(
              l.doseCalcTotalDose,
              '${formatDoseAmount(r.totalDose!)} ${_doseUnit.symbol}',
            ),
          )
          ..add(
            _resultRow(
              l.doseCalcDosePerDay,
              '${formatDoseAmount(r.dailyDose!)} ${_doseUnit.symbol} / '
              '${l.doseCalcPerDay}',
              emphasize: true,
            ),
          )
          ..add(_resultRow(l.doseCalcSpreadDays, '${r.days}'));
      case CorrectionStatus.missingInputs:
      case CorrectionStatus.needsPotency:
      case CorrectionStatus.atOrAboveTarget:
        break;
    }

    final (text, icon, color) = switch (r.status) {
      CorrectionStatus.missingInputs => (
        l.doseCalcCorrMissing,
        Icons.info_outline,
        tokens.textDim,
      ),
      CorrectionStatus.needsPotency => (
        l.doseCalcNeedsPotency,
        Icons.science_outlined,
        tokens.primary,
      ),
      CorrectionStatus.atOrAboveTarget => (
        l.doseCalcCorrAtTarget,
        Icons.check_circle_outline,
        tokens.healthy,
      ),
      CorrectionStatus.singleDose => (
        l.doseCalcCorrSingle,
        Icons.check_circle_outline,
        tokens.healthy,
      ),
      CorrectionStatus.splitDose => (
        l.doseCalcCorrSplit('${_trim(maxRise ?? 0)} $unitStr', r.days!),
        Icons.warning_amber_outlined,
        tokens.critical,
      ),
    };

    final canLog =
        r.status == CorrectionStatus.singleDose ||
        r.status == CorrectionStatus.splitDose;

    return ReefCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.doseCalcResultsTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
          if (rows.isNotEmpty) const SizedBox(height: 12),
          _bannerRow(text, icon, color),
          if (canLog) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.doseCalcLogDose),
                onPressed: () => _logCorrectionDose(r),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hands the computed dose to the manual dose log, prefilled. For a split
  /// correction this logs the per-day portion — what was actually given today
  /// — so the logged history stays truthful. The product rides along only
  /// when the dose was computed with its catalog strength.
  void _logCorrectionDose(CorrectionResult r) {
    final daily = r.dailyDose;
    if (daily == null) return;
    final element = _element ?? kDosingElementKeys.first;
    String? productKey;
    if (_useCatalogPotency && _catalogPotency != null) {
      final entries = ref.read(dosingEntriesProvider).value ?? const [];
      for (final e in entries.where((e) => e.elementKey == element)) {
        final key = e.productKey;
        if (key != null &&
            kSupplementProductByKey[key]?.strength?[element] != null) {
          productKey = key;
          break;
        }
      }
    }
    unawaited(
      context.push(
        '/dosing/manual',
        extra: ManualDoseDraft(
          elementKey: element,
          amount: daily,
          unit: _doseUnit,
          productKey: productKey,
        ),
      ),
    );
  }

  /// Status colors ride the tokens (REDESIGN #1 rule: `error` is for
  /// validation, the tokens carry status) — healthy for the good outcomes,
  /// `critical` for overdosing.
  Widget _statusBanner(AppLocalizations l, DoseCalcStatus status) {
    final tokens = ReefTokens.of(context);
    final (text, icon, color) = switch (status) {
      DoseCalcStatus.insufficientData => (
        l.doseCalcInsufficient,
        Icons.info_outline,
        tokens.textDim,
      ),
      DoseCalcStatus.needsPotency => (
        l.doseCalcNeedsPotency,
        Icons.science_outlined,
        tokens.primary,
      ),
      DoseCalcStatus.stable => (
        l.doseCalcStable,
        Icons.check_circle_outline,
        tokens.healthy,
      ),
      DoseCalcStatus.increase => (
        l.doseCalcIncrease,
        Icons.arrow_upward,
        tokens.primary,
      ),
      DoseCalcStatus.decrease => (
        l.doseCalcDecrease,
        Icons.arrow_downward,
        tokens.primary,
      ),
      DoseCalcStatus.overdosing => (
        l.doseCalcOverdosing,
        Icons.warning_amber_outlined,
        tokens.critical,
      ),
      DoseCalcStatus.noDoseNeeded => (
        l.doseCalcNoDoseNeeded,
        Icons.check_circle_outline,
        tokens.healthy,
      ),
    };
    return _bannerRow(text, icon, color);
  }

  /// Icon + colored text guidance row shared by both modes' result cards.
  Widget _bannerRow(String text, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  /// Trims a value to a compact locale-formatted string (up to 3 significant
  /// decimals).
  String _trim(double v) =>
      formatLocaleNumberTrim(v, decimals: v.abs() < 1 ? 3 : 2);

  String _signed(double v) => '${v >= 0 ? '+' : '−'}${_trim(v.abs())}';
}
