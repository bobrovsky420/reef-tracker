import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/dose_calculator.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/trend_chart.dart';
import 'dosing_screen.dart' show formatDoseAmount;

/// Consumption / dose-adjustment calculator (Dosing tab → calculator).
///
/// Pulls the active tank's stored readings, dosing plan and volume to estimate
/// how fast an element is consumed and what daily dose holds it steady. All
/// inputs are editable. Water changes are intentionally ignored. The math lives
/// in `domain/dose_calculator.dart`.
class DoseCalculatorScreen extends ConsumerStatefulWidget {
  const DoseCalculatorScreen({super.key});

  @override
  ConsumerState<DoseCalculatorScreen> createState() =>
      _DoseCalculatorScreenState();
}

class _DoseCalculatorScreenState extends ConsumerState<DoseCalculatorScreen> {
  String? _element;
  ChartRange _range = ChartRange.month;

  final _volumeCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
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

    final result = computeDoseCalc(
      slopePerDay: slope,
      currentDailyDose: dose,
      potency: potency,
      volumeLiters: volLiters,
    );

    // The active plan assumes the current dose held for the whole window. If a
    // dose segment for this element started mid-window (there are readings
    // before it), warn that the slope mixes two dose regimes.
    final doseChangedAt = _doseChangedInWindow(entries, element, points);

    return Scaffold(
      appBar: AppBar(title: Text(l.doseCalcTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.doseCalcIntro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _elementField(l, tank, entries, volUnit),
          const SizedBox(height: 16),
          _windowField(l, points.length),
          const Divider(height: 32),
          _volumeField(l, volUnit),
          const SizedBox(height: 16),
          _doseField(l),
          const Divider(height: 32),
          _potencySection(l, element, volUnit, volLiters, potency),
          const Divider(height: 32),
          if (doseChangedAt != null) ...[
            _doseChangedWarning(l, doseChangedAt),
            const SizedBox(height: 12),
          ],
          _resultCard(l, element, result),
        ],
      ),
    );
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
      decoration: InputDecoration(
        labelText: l.doseCalcElement,
        border: const OutlineInputBorder(),
      ),
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
          decoration: InputDecoration(
            labelText: l.doseCalcWindow,
            border: const OutlineInputBorder(),
          ),
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
      decoration: InputDecoration(
        labelText: l.doseCalcVolume,
        suffixText: volUnit.symbol,
        border: const OutlineInputBorder(),
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
            decoration: InputDecoration(
              labelText: l.doseCalcCurrentDose,
              suffixText: '${_doseUnit.symbol} / ${l.doseCalcPerDay}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
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
                  decoration: InputDecoration(
                    labelText: l.doseCalcRefAmount,
                    suffixText: _doseUnit.symbol,
                    border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: l.doseCalcRefVolume,
                    suffixText: volUnit.symbol,
                    border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: l.doseCalcRise,
                    suffixText: unitStr,
                    border: const OutlineInputBorder(),
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
    final scheme = Theme.of(context).colorScheme;
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

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.doseCalcResultsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...rows,
            if (rows.isNotEmpty) const SizedBox(height: 12),
            _statusBanner(l, r.status, scheme),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool emphasize = false}) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _statusBanner(
    AppLocalizations l,
    DoseCalcStatus status,
    ColorScheme scheme,
  ) {
    final (text, icon, color) = switch (status) {
      DoseCalcStatus.insufficientData => (
        l.doseCalcInsufficient,
        Icons.info_outline,
        scheme.outline,
      ),
      DoseCalcStatus.needsPotency => (
        l.doseCalcNeedsPotency,
        Icons.science_outlined,
        scheme.primary,
      ),
      DoseCalcStatus.stable => (
        l.doseCalcStable,
        Icons.check_circle_outline,
        Colors.green,
      ),
      DoseCalcStatus.increase => (
        l.doseCalcIncrease,
        Icons.arrow_upward,
        scheme.primary,
      ),
      DoseCalcStatus.decrease => (
        l.doseCalcDecrease,
        Icons.arrow_downward,
        scheme.primary,
      ),
      DoseCalcStatus.overdosing => (
        l.doseCalcOverdosing,
        Icons.warning_amber_outlined,
        scheme.error,
      ),
      DoseCalcStatus.noDoseNeeded => (
        l.doseCalcNoDoseNeeded,
        Icons.check_circle_outline,
        Colors.green,
      ),
    };
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
