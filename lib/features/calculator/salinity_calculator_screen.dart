import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/salinity_planner.dart';
import '../../domain/salt_mix_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_segmented.dart';
import '../actions/actions_screen.dart';

enum _SalinityToolMode { convert, mix, correct }

enum _ConverterSource { ppt, sg, density }

class _MixResult {
  const _MixResult(this.massG);
  final double massG;
}

class _CorrectionResult {
  const _CorrectionResult({
    required this.exchangeLiters,
    required this.highSalinity,
    this.batchMassG,
    this.additionalEquivalentG,
  });

  final double exchangeLiters;
  final bool highSalinity;
  final double? batchMassG;
  final double? additionalEquivalentG;
}

/// The Standard salinity tool: the original live ppt/SG converter plus salt
/// preparation and tank-aware correction planning. Calculation code remains
/// DB-free in `domain/salinity_planner.dart`; this screen owns only unit
/// conversion, persisted form context, validation and presentation.
class SalinityCalculatorScreen extends ConsumerStatefulWidget {
  const SalinityCalculatorScreen({super.key});

  @override
  ConsumerState<SalinityCalculatorScreen> createState() =>
      _SalinityCalculatorScreenState();
}

class _SalinityCalculatorScreenState
    extends ConsumerState<SalinityCalculatorScreen> {
  static const _seedPpt = 35.0;
  static const _staleAfter = Duration(days: 14);

  _SalinityToolMode _mode = _SalinityToolMode.convert;

  late final _pptCtrl = TextEditingController(
    text: formatLocaleNumber(_seedPpt, 1),
  );
  late final _sgCtrl = TextEditingController(
    text: formatLocaleNumber(pptToSg(_seedPpt), 4),
  );
  late final _densityCtrl = TextEditingController(
    text: formatLocaleNumber(hydrometerReadingForSalinity(_seedPpt, 25), 4),
  );
  final _densityTempCtrl = TextEditingController();
  bool _updatingConverter = false;
  double _measurementTempC = 25;
  TempUnit? _densityTempDisplayUnit;
  _ConverterSource _converterSource = _ConverterSource.ppt;

  final _mixFormKey = GlobalKey<FormState>();
  final _correctionFormKey = GlobalKey<FormState>();
  final _mixVolumeCtrl = TextEditingController();
  final _mixTargetCtrl = TextEditingController();
  final _saltNameCtrl = TextEditingController();
  final _factorCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _calMassCtrl = TextEditingController();
  final _calVolumeCtrl = TextEditingController();
  final _calMeasuredCtrl = TextEditingController();
  final _tankVolumeCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _replacementCtrl = TextEditingController();

  _MixResult? _mixResult;
  _CorrectionResult? _correctionResult;
  Reading? _sourceReading;
  bool _currentStillFromReading = false;
  String _selectedProductKey = kCustomSaltMixKey;
  bool _calibrationIsMeasured = true;
  int _productLoadToken = 0;

  @override
  void dispose() {
    for (final controller in [
      _pptCtrl,
      _sgCtrl,
      _densityCtrl,
      _densityTempCtrl,
      _mixVolumeCtrl,
      _mixTargetCtrl,
      _saltNameCtrl,
      _factorCtrl,
      _referenceCtrl,
      _calMassCtrl,
      _calVolumeCtrl,
      _calMeasuredCtrl,
      _tankVolumeCtrl,
      _currentCtrl,
      _targetCtrl,
      _replacementCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPptChanged(String text) {
    if (_updatingConverter) return;
    final ppt = parseUserDouble(text);
    if (ppt == null) return;
    _converterSource = _ConverterSource.ppt;
    _updatingConverter = true;
    final sg = pptToSg(ppt);
    _sgCtrl.text = formatLocaleNumber(sg, 4);
    final density = hydrometerReadingForSalinity(ppt, _measurementTempC);
    if (density.isFinite) {
      _densityCtrl.text = formatLocaleNumber(density, 4);
    }
    _updatingConverter = false;
  }

  void _onSgChanged(String text) {
    if (_updatingConverter) return;
    final sg = parseUserDouble(text);
    if (sg == null) return;
    _converterSource = _ConverterSource.sg;
    _updatingConverter = true;
    final ppt = sgToPpt(sg);
    _pptCtrl.text = formatLocaleNumber(ppt, 1);
    final density = hydrometerReadingForSalinity(ppt, _measurementTempC);
    if (density.isFinite) {
      _densityCtrl.text = formatLocaleNumber(density, 4);
    }
    _updatingConverter = false;
  }

  void _onDensityChanged(String text) {
    if (_updatingConverter) return;
    final density = parseUserDouble(text);
    if (density == null) return;
    _converterSource = _ConverterSource.density;
    final ppt = salinityFromHydrometerReading(density, _measurementTempC);
    if (ppt == null) return;
    _updatingConverter = true;
    _pptCtrl.text = formatLocaleNumber(ppt, 1);
    _sgCtrl.text = formatLocaleNumber(pptToSg(ppt), 4);
    _updatingConverter = false;
  }

  void _onMeasurementTempChanged(String text, TempUnit unit) {
    if (_updatingConverter) return;
    final displayTemp = parseUserDouble(text);
    if (displayTemp == null) return;
    final tempC = unit == TempUnit.fahrenheit
        ? fToCelsius(displayTemp)
        : displayTemp;
    _measurementTempC = tempC;
    if (tempC < -2 || tempC > 40) return;

    switch (_converterSource) {
      case _ConverterSource.ppt:
        _onPptChanged(_pptCtrl.text);
        break;
      case _ConverterSource.sg:
        _onSgChanged(_sgCtrl.text);
        break;
      case _ConverterSource.density:
        _onDensityChanged(_densityCtrl.text);
        break;
    }
  }

  String _formatPptForInput(double ppt, SalinityUnit unit) =>
      unit == SalinityUnit.ppt
      ? formatLocaleNumber(ppt, 1)
      : formatLocaleNumber(pptToSg(ppt), 4);

  double? _parsePpt(TextEditingController controller, SalinityUnit unit) {
    final value = parseUserDouble(controller.text);
    if (value == null || !value.isFinite) return null;
    return unit == SalinityUnit.ppt ? value : sgToPpt(value);
  }

  double? _tankTargetPpt() {
    final tracked = ref.read(trackedParametersProvider).value ?? const [];
    for (final parameter in tracked) {
      if (parameter.paramKey != 'salinity') continue;
      final low = parameter.bounds.greenLow;
      final high = parameter.bounds.greenHigh;
      if (low != null && high != null) return sgToPpt((low + high) / 2);
    }
    return null;
  }

  Reading? _latestSalinityReading() {
    final readings = ref.read(recentReadingsProvider).value ?? const [];
    for (final reading in readings) {
      if (reading.paramKey == 'salinity') return reading;
    }
    return null;
  }

  void _selectMode(_SalinityToolMode mode) {
    if (_mode == mode) return;
    final prefs = ref.read(unitPrefsProvider);
    final tank = ref.read(activeTankProvider);
    final target = _tankTargetPpt() ?? _seedPpt;
    final storedProductKey = tank?.saltMixProductKey;
    final productKey =
        storedProductKey != null &&
            kSaltMixProductByKey.containsKey(storedProductKey)
        ? storedProductKey
        : kCustomSaltMixKey;
    _selectedProductKey = productKey;

    if (_mixTargetCtrl.text.isEmpty) {
      _mixTargetCtrl.text = _formatPptForInput(target, prefs.salinity);
    }
    if (_referenceCtrl.text.isEmpty) {
      final reference = tank?.saltMixReferencePpt ?? _seedPpt;
      _referenceCtrl.text = _formatPptForInput(reference, prefs.salinity);
    }
    if (_factorCtrl.text.isEmpty && tank?.saltMixGramsPerLiter != null) {
      _factorCtrl.text = formatLocaleNumberTrim(
        tank!.saltMixGramsPerLiter!,
        decimals: 2,
      );
    }
    if (_saltNameCtrl.text.isEmpty && tank?.saltMixName != null) {
      _saltNameCtrl.text = tank!.saltMixName!;
    }

    if (_tankVolumeCtrl.text.isEmpty && tank?.volumeLiters != null) {
      _tankVolumeCtrl.text = formatVolume(tank!.volumeLiters!, prefs.volume);
    }
    if (_targetCtrl.text.isEmpty) {
      _targetCtrl.text = _formatPptForInput(target, prefs.salinity);
    }
    if (_currentCtrl.text.isEmpty) {
      _sourceReading = _latestSalinityReading();
      if (_sourceReading != null) {
        _currentCtrl.text = _formatPptForInput(
          sgToPpt(_sourceReading!.value),
          prefs.salinity,
        );
        _currentStillFromReading = true;
      }
    }

    setState(() {
      _mode = mode;
      _mixResult = null;
      _correctionResult = null;
    });
    unawaited(_loadSaltProduct(productKey));
  }

  Future<void> _selectSaltProduct(String productKey) async {
    if (_selectedProductKey == productKey) return;
    setState(() {
      _selectedProductKey = productKey;
      _mixResult = null;
      _correctionResult = null;
    });
    await _loadSaltProduct(productKey);
  }

  Future<void> _loadSaltProduct(String productKey) async {
    final token = ++_productLoadToken;
    final tank = ref.read(activeTankProvider);
    final stored = tank == null
        ? null
        : await ref
              .read(dbProvider)
              .getSaltMixCalibrationForProduct(tank.id, productKey);
    if (!mounted || token != _productLoadToken) return;

    final product = kSaltMixProductByKey[productKey];
    final prefs = ref.read(unitPrefsProvider);
    if (stored != null) {
      _saltNameCtrl.text = stored.displayName;
      _factorCtrl.text = formatLocaleNumberTrim(
        stored.gramsPerLiter,
        decimals: 2,
      );
      _referenceCtrl.text = _formatPptForInput(
        stored.referencePpt,
        prefs.salinity,
      );
      setState(() => _calibrationIsMeasured = stored.measured);
      await _rememberCalibration(
        SaltMixCalibration(
          name: stored.displayName.isEmpty ? null : stored.displayName,
          gramsPerLiter: stored.gramsPerLiter,
          referencePpt: stored.referencePpt,
        ),
      );
      return;
    }

    if (product == null) {
      _saltNameCtrl.clear();
      _factorCtrl.clear();
      _referenceCtrl.text = _formatPptForInput(_seedPpt, prefs.salinity);
      setState(() => _calibrationIsMeasured = true);
      return;
    }

    final seed = product.initialCalibration;
    _saltNameCtrl.text = product.displayName;
    _factorCtrl.text = formatLocaleNumberTrim(seed.gramsPerLiter, decimals: 2);
    _referenceCtrl.text = _formatPptForInput(seed.referencePpt, prefs.salinity);
    setState(() => _calibrationIsMeasured = false);
    // Persist the first-use seed immediately. A future catalogue revision must
    // not silently change an aquarium/product value the keeper has already
    // started using.
    await _rememberCalibration(seed);
  }

  String? _positiveValidator(AppLocalizations l, String? text) {
    final value = parseUserDouble(text);
    return value == null || value <= 0 ? l.invalidPositiveNumber : null;
  }

  String? _salinityValidator(
    AppLocalizations l,
    String? text,
    SalinityUnit unit,
  ) {
    final raw = parseUserDouble(text);
    if (raw == null) return l.invalidPositiveNumber;
    final ppt = unit == SalinityUnit.ppt ? raw : sgToPpt(raw);
    return ppt.isFinite && ppt > 0 ? null : l.invalidPositiveNumber;
  }

  SaltMixCalibration? _calibration(SalinityUnit unit) {
    final factor = parseUserDouble(_factorCtrl.text);
    final reference = _parsePpt(_referenceCtrl, unit);
    if (factor == null || reference == null) return null;
    final name = _saltNameCtrl.text.trim();
    final calibration = SaltMixCalibration(
      name: name.isEmpty ? null : name,
      gramsPerLiter: factor,
      referencePpt: reference,
    );
    return calibration.isValid ? calibration : null;
  }

  Future<void> _rememberCalibration(SaltMixCalibration calibration) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    await ref
        .read(dbProvider)
        .updateTankSaltCalibration(
          tankId: tank.id,
          name: calibration.name,
          gramsPerLiter: calibration.gramsPerLiter,
          referencePpt: calibration.referencePpt,
          productKey: _selectedProductKey,
          measured: _calibrationIsMeasured,
        );
  }

  Future<void> _deriveCalibration() async {
    final l = AppLocalizations.of(context);
    final prefs = ref.read(unitPrefsProvider);
    final mass = parseUserDouble(_calMassCtrl.text);
    final volume = parseUserDouble(_calVolumeCtrl.text);
    final measured = _parsePpt(_calMeasuredCtrl, prefs.salinity);
    final reference = _parsePpt(_referenceCtrl, prefs.salinity);
    if (mass == null ||
        mass <= 0 ||
        volume == null ||
        volume <= 0 ||
        measured == null ||
        measured <= 0 ||
        reference == null ||
        reference <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.invalidPositiveNumber)));
      return;
    }
    final factor = calibrateSaltMixGramsPerLiter(
      dryMassG: mass,
      finalVolumeLiters: volumeToCanonical(volume, prefs.volume),
      measuredPpt: measured,
      referencePpt: reference,
    );
    setState(() {
      _factorCtrl.text = formatLocaleNumberTrim(factor, decimals: 2);
      _calibrationIsMeasured = true;
      _mixResult = null;
      _correctionResult = null;
    });
    final calibration = _calibration(prefs.salinity);
    if (calibration != null) await _rememberCalibration(calibration);
  }

  Future<void> _calculateMix() async {
    if (!(_mixFormKey.currentState?.validate() ?? false)) return;
    final prefs = ref.read(unitPrefsProvider);
    final volume = volumeToCanonical(
      parseUserDouble(_mixVolumeCtrl.text)!,
      prefs.volume,
    );
    final target = _parsePpt(_mixTargetCtrl, prefs.salinity)!;
    final calibration = _calibration(prefs.salinity)!;
    final result = saltMixMassGrams(
      finalVolumeLiters: volume,
      targetPpt: target,
      calibration: calibration,
    );
    await _rememberCalibration(calibration);
    if (!mounted) return;
    setState(() => _mixResult = _MixResult(result));
  }

  Future<void> _calculateCorrection() async {
    if (!(_correctionFormKey.currentState?.validate() ?? false)) return;
    final prefs = ref.read(unitPrefsProvider);
    final volume = volumeToCanonical(
      parseUserDouble(_tankVolumeCtrl.text)!,
      prefs.volume,
    );
    final current = _parsePpt(_currentCtrl, prefs.salinity)!;
    final target = _parsePpt(_targetCtrl, prefs.salinity)!;
    if (current == target) {
      setState(
        () => _correctionResult = const _CorrectionResult(
          exchangeLiters: 0,
          highSalinity: false,
        ),
      );
      return;
    }

    final high = current > target;
    final replacement = high
        ? 0.0
        : _parsePpt(_replacementCtrl, prefs.salinity)!;
    if (!high && replacement <= target) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).salinityReplacementError),
        ),
      );
      return;
    }

    final exchange = salinityCorrectionExchangeLiters(
      tankVolumeLiters: volume,
      currentPpt: current,
      targetPpt: target,
      replacementPpt: replacement,
    );
    double? batchMass;
    double? additional;
    if (!high) {
      final calibration = _calibration(prefs.salinity)!;
      batchMass = saltMixMassGrams(
        finalVolumeLiters: exchange,
        targetPpt: replacement,
        calibration: calibration,
      );
      additional = additionalSaltEquivalentGrams(
        tankVolumeLiters: volume,
        currentPpt: current,
        targetPpt: target,
        calibration: calibration,
      );
      await _rememberCalibration(calibration);
    }
    if (!mounted) return;
    setState(
      () => _correctionResult = _CorrectionResult(
        exchangeLiters: exchange,
        highSalinity: high,
        batchMassG: batchMass,
        additionalEquivalentG: additional,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Keep the tank context warm while the converter mode is visible. The
    // planner modes are selected by a synchronous tap; without these watches
    // a cold `read(activeTankProvider)` sees the backing Drift streams in
    // their initial loading state and cannot prefill the first visit.
    ref.watch(activeTankProvider);
    ref.watch(trackedParametersProvider);
    ref.watch(recentReadingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.salinityCalculator)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ReefSegmented<_SalinityToolMode>(
                options: [
                  (_SalinityToolMode.convert, l.salinityToolConvert),
                  (_SalinityToolMode.mix, l.salinityToolMix),
                  (_SalinityToolMode.correct, l.salinityToolCorrect),
                ],
                selected: _mode,
                onChanged: _selectMode,
                optionKeys: const {
                  _SalinityToolMode.convert: Key('salinity-mode-convert'),
                  _SalinityToolMode.mix: Key('salinity-mode-mix'),
                  _SalinityToolMode.correct: Key('salinity-mode-correct'),
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          switch (_mode) {
            _SalinityToolMode.convert => _converter(l),
            _SalinityToolMode.mix => _mixPlanner(l),
            _SalinityToolMode.correct => _correctionPlanner(l),
          },
        ],
      ),
    );
  }

  Widget _converter(AppLocalizations l) {
    final tokens = ReefTokens.of(context);
    final tempUnit = ref.watch(unitPrefsProvider).temp;
    if (_densityTempDisplayUnit != tempUnit) {
      _densityTempDisplayUnit = tempUnit;
      final displayTemp = tempUnit == TempUnit.fahrenheit
          ? celsiusToF(_measurementTempC)
          : _measurementTempC;
      _densityTempCtrl.text = formatLocaleNumber(displayTemp, 1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.calculatorIntro, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        TextField(
          key: const Key('salinity-converter-ppt'),
          controller: _pptCtrl,
          style: ReefTokens.monoInputStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.salinity, suffixText: 'ppt'),
          onChanged: _onPptChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Icon(Icons.swap_vert, size: 28, color: tokens.textDim),
          ),
        ),
        TextField(
          key: const Key('salinity-converter-sg'),
          controller: _sgCtrl,
          style: ReefTokens.monoInputStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.specificGravity,
            suffixText: 'SG',
          ),
          onChanged: _onSgChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Icon(Icons.swap_vert, size: 28, color: tokens.textDim),
          ),
        ),
        TextField(
          key: const Key('salinity-converter-density-temperature'),
          controller: _densityTempCtrl,
          style: ReefTokens.monoInputStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.measurementTemperature,
            suffixText: tempUnit.symbol,
            helperText: l.densityTemperatureHelp,
            helperMaxLines: 2,
          ),
          onChanged: (text) => _onMeasurementTempChanged(text, tempUnit),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('salinity-converter-density'),
          controller: _densityCtrl,
          style: ReefTokens.monoInputStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.hydrometerDensityReading,
            suffixText: 'g/cm³',
          ),
          onChanged: _onDensityChanged,
        ),
        const SizedBox(height: 24),
        ReefCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.referencePoints,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(l.refSeawater, style: TextStyle(color: tokens.textDim)),
              Text(l.refReefTarget, style: TextStyle(color: tokens.textDim)),
              const SizedBox(height: 8),
              Text(
                l.densityHydrometerNote,
                style: TextStyle(color: tokens.textDim),
              ),
              const SizedBox(height: 8),
              Text(
                l.refFormulaNote,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: tokens.textFaint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mixPlanner(AppLocalizations l) {
    final prefs = ref.watch(unitPrefsProvider);
    return Form(
      key: _mixFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.saltMixIntro),
          const SizedBox(height: 16),
          ReefCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  key: const Key('salt-mix-volume'),
                  controller: _mixVolumeCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.saltMixFinalVolume,
                    suffixText: prefs.volume.symbol,
                  ),
                  validator: (v) => _positiveValidator(l, v),
                  onChanged: (_) => setState(() => _mixResult = null),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('salt-mix-target'),
                  controller: _mixTargetCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.saltMixTarget,
                    suffixText: prefs.salinity.symbol,
                  ),
                  validator: (v) => _salinityValidator(l, v, prefs.salinity),
                  onChanged: (_) => setState(() => _mixResult = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _saltProfileCard(l, prefs),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculateMix,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l.saltMixCalculate),
          ),
          if (_mixResult != null) ...[
            const SizedBox(height: 16),
            ReefCard(
              key: const Key('salt-mix-result'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resultTitle(l.salinityPlannerResult),
                  const SizedBox(height: 10),
                  _resultRow(
                    l.saltMixDrySalt,
                    _formatMass(_mixResult!.massG),
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  Text(l.saltMixResultHelp),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _saltProfileCard(AppLocalizations l, UnitPrefs prefs) {
    final product = kSaltMixProductByKey[_selectedProductKey];
    final profileHelp = _selectedProductKey == kCustomSaltMixKey
        ? l.saltMixCustomHelp
        : _calibrationIsMeasured
        ? l.saltMixMeasuredCalibration
        : product?.isSourceWaterEstimate == true
        ? l.saltMixCatalogEstimate
        : l.saltMixCatalogManufacturer;
    return ReefCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resultTitle(l.saltMixProfileTitle),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: const Key('salt-mix-product'),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_selectedProductKey),
              initialValue: _selectedProductKey,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.saltMixProductLabel),
              items: [
                DropdownMenuItem(
                  value: kCustomSaltMixKey,
                  child: Text(l.saltMixCustomProduct),
                ),
                for (final product in kSaltMixProducts)
                  DropdownMenuItem(
                    value: product.key,
                    child: Text(product.displayName),
                  ),
              ],
              onChanged: (key) {
                if (key != null) unawaited(_selectSaltProduct(key));
              },
            ),
          ),
          if (_selectedProductKey == kCustomSaltMixKey) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _saltNameCtrl,
              decoration: InputDecoration(labelText: l.saltMixNameOptional),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            profileHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ReefTokens.of(context).textDim,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('salt-mix-factor'),
            controller: _factorCtrl,
            style: ReefTokens.monoInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.saltMixFactor,
              suffixText: 'g/L',
              helperText: l.saltMixFactorHelp,
              helperMaxLines: 4,
            ),
            validator: (v) => _positiveValidator(l, v),
            onChanged: (_) => setState(() {
              _calibrationIsMeasured = true;
              _mixResult = null;
              _correctionResult = null;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _referenceCtrl,
            style: ReefTokens.monoInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.saltMixReferenceSalinity,
              suffixText: prefs.salinity.symbol,
            ),
            validator: (v) => _salinityValidator(l, v, prefs.salinity),
            onChanged: (_) => setState(() {
              _calibrationIsMeasured = true;
              _mixResult = null;
              _correctionResult = null;
            }),
          ),
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(l.saltMixCalibrateTitle),
            children: [
              TextFormField(
                key: const Key('salt-mix-calibration-mass'),
                controller: _calMassCtrl,
                style: ReefTokens.monoInputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.saltMixDryMass,
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('salt-mix-calibration-volume'),
                controller: _calVolumeCtrl,
                style: ReefTokens.monoInputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.saltMixMeasuredVolume,
                  suffixText: prefs.volume.symbol,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('salt-mix-calibration-salinity'),
                controller: _calMeasuredCtrl,
                style: ReefTokens.monoInputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.saltMixMeasuredSalinity,
                  suffixText: prefs.salinity.symbol,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _deriveCalibration,
                  child: Text(l.saltMixUseCalibration),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _correctionPlanner(AppLocalizations l) {
    final prefs = ref.watch(unitPrefsProvider);
    final current = _parsePpt(_currentCtrl, prefs.salinity);
    final target = _parsePpt(_targetCtrl, prefs.salinity);
    final isLow = current != null && target != null && current < target;
    final isHigh = current != null && target != null && current > target;
    final source = _sourceReading;
    String? sourceLabel;
    if (_currentStillFromReading && source != null) {
      sourceLabel = l.salinityPlannerLatestReading(
        formatDateTime(context, source.takenAt, weekday: false),
      );
      final age = DateTime.now().difference(source.takenAt).inDays;
      if (DateTime.now().difference(source.takenAt) > _staleAfter) {
        sourceLabel = '$sourceLabel ${l.doseCalcSalinityStale(age)}';
      }
    }

    return Form(
      key: _correctionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.salinityCorrectionIntro),
          const SizedBox(height: 16),
          ReefCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  key: const Key('salinity-correction-volume'),
                  controller: _tankVolumeCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.salinityCorrectionTankVolume,
                    suffixText: prefs.volume.symbol,
                  ),
                  validator: (v) => _positiveValidator(l, v),
                  onChanged: (_) => setState(() => _correctionResult = null),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('salinity-correction-current'),
                  controller: _currentCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.salinityCorrectionCurrent,
                    suffixText: prefs.salinity.symbol,
                    helperText: sourceLabel,
                    helperMaxLines: 3,
                  ),
                  validator: (v) => _salinityValidator(l, v, prefs.salinity),
                  onChanged: (_) => setState(() {
                    _currentStillFromReading = false;
                    _correctionResult = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('salinity-correction-target'),
                  controller: _targetCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.salinityCorrectionTarget,
                    suffixText: prefs.salinity.symbol,
                  ),
                  validator: (v) => _salinityValidator(l, v, prefs.salinity),
                  onChanged: (_) => setState(() => _correctionResult = null),
                ),
                if (isLow) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('salinity-correction-replacement'),
                    controller: _replacementCtrl,
                    style: ReefTokens.monoInputStyle,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.salinityCorrectionReplacement,
                      suffixText: prefs.salinity.symbol,
                      helperText: l.salinityCorrectionReplacementHelp,
                      helperMaxLines: 3,
                    ),
                    validator: (v) => _salinityValidator(l, v, prefs.salinity),
                    onChanged: (_) => setState(() => _correctionResult = null),
                  ),
                ],
              ],
            ),
          ),
          if (isHigh || isLow) ...[
            const SizedBox(height: 12),
            Text(
              isHigh
                  ? l.salinityCorrectionHighMethod
                  : l.salinityCorrectionLowMethod,
            ),
          ],
          if (isLow) ...[
            const SizedBox(height: 16),
            _saltProfileCard(l, prefs),
          ],
          const SizedBox(height: 16),
          _safetyCard(l),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculateCorrection,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l.salinityCorrectionCalculate),
          ),
          if (_correctionResult != null) ...[
            const SizedBox(height: 16),
            _correctionResultCard(l, prefs, _correctionResult!),
          ],
        ],
      ),
    );
  }

  Widget _safetyCard(AppLocalizations l) => ReefCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultTitle(l.salinityPlannerAssumptionsTitle),
        const SizedBox(height: 8),
        Text(l.salinityPlannerAssumptions),
        const SizedBox(height: 8),
        Text(l.salinityPlannerSafety),
      ],
    ),
  );

  Widget _correctionResultCard(
    AppLocalizations l,
    UnitPrefs prefs,
    _CorrectionResult result,
  ) {
    final volume = _formatVolumePrecise(result.exchangeLiters, prefs.volume);
    final tankVolume = volumeToCanonical(
      parseUserDouble(_tankVolumeCtrl.text)!,
      prefs.volume,
    );
    final percent = tankVolume <= 0
        ? 0.0
        : result.exchangeLiters / tankVolume * 100;
    return ReefCard(
      key: const Key('salinity-correction-result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resultTitle(l.salinityPlannerResult),
          const SizedBox(height: 10),
          if (result.exchangeLiters == 0)
            Text(l.salinityCorrectionNoChange)
          else ...[
            _resultRow(l.salinityCorrectionExchange, volume, emphasize: true),
            _resultRow(
              l.salinityCorrectionTankPercent,
              '${formatLocaleNumberTrim(percent, decimals: 1)} %',
            ),
            if (result.batchMassG != null)
              _resultRow(
                l.salinityCorrectionBatchSalt,
                _formatMass(result.batchMassG!),
              ),
            if (result.additionalEquivalentG != null)
              _resultRow(
                l.salinityCorrectionExtraEquivalent,
                _formatMass(result.additionalEquivalentG!),
              ),
            const SizedBox(height: 12),
            Text(
              result.highSalinity
                  ? l.salinityCorrectionHighResultHelp
                  : l.salinityCorrectionLowResultHelp,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showRecordWaterChangeDialog(
                context,
                ref,
                amountLiters: result.exchangeLiters,
                note: l.salinityCorrectionLogNote,
              ),
              icon: const Icon(Icons.playlist_add_check),
              label: Text(l.salinityCorrectionRecord),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMass(double grams) =>
      '${formatLocaleNumberTrim(grams, decimals: 2)} g · '
      '${formatLocaleNumberTrim(grams / 1000, decimals: 3)} kg';

  String _formatVolumePrecise(double liters, VolumeUnit unit) =>
      '${formatLocaleNumberTrim(volumeToDisplay(liters, unit), decimals: 2)} '
      '${unit.symbol}';

  Widget _resultTitle(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _resultRow(String label, String value, {bool emphasize = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Text(
              value,
              textAlign: TextAlign.end,
              style: ReefTokens.monoInputStyle.copyWith(
                fontSize: emphasize ? 17 : 14,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
