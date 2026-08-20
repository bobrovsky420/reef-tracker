import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/health_score.dart';
import '../../domain/units.dart';
import '../../domain/water_change_planner.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_segmented.dart';

const _nonLinearWaterChangeParameters = {'temperature', 'ph', 'orp'};

/// Tank-aware Standard planner for discrete and continuous water changes.
class WaterChangePlannerScreen extends ConsumerStatefulWidget {
  const WaterChangePlannerScreen({super.key});

  @override
  ConsumerState<WaterChangePlannerScreen> createState() =>
      _WaterChangePlannerScreenState();
}

class _WaterChangePlannerScreenState
    extends ConsumerState<WaterChangePlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tankVolumeCtrl = TextEditingController();
  final _changeVolumeCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _replacementCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');

  WaterChangeMethod _method = WaterChangeMethod.batch;
  String? _selectedParamKey;
  Reading? _sourceReading;
  WaterChangeProjection? _result;
  double? _resultTarget;
  int? _loadedTankId;
  bool _syncQueued = false;

  @override
  void dispose() {
    for (final controller in [
      _tankVolumeCtrl,
      _changeVolumeCtrl,
      _currentCtrl,
      _replacementCtrl,
      _targetCtrl,
      _countCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ResolvedParameter> _eligible(List<ResolvedParameter> parameters) => [
    for (final parameter in parameters)
      if (parameter.enabled &&
          !_nonLinearWaterChangeParameters.contains(parameter.paramKey))
        parameter,
  ];

  void _queueContextSync(
    Tank tank,
    List<ResolvedParameter> parameters,
    List<Reading> readings,
    List<WaterChange> changes,
    UnitPrefs prefs,
  ) {
    if (_syncQueued) return;
    final eligible = _eligible(parameters);
    final tankChanged = _loadedTankId != tank.id;
    final selectedMissing =
        _selectedParamKey == null ||
        !eligible.any((p) => p.paramKey == _selectedParamKey);
    if (!tankChanged && !selectedMissing) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (!mounted) return;
      setState(() {
        if (tankChanged) {
          _loadedTankId = tank.id;
          _tankVolumeCtrl.text = tank.volumeLiters == null
              ? ''
              : formatVolume(tank.volumeLiters!, prefs.volume);
          final latestAmount = changes
              .where((change) => change.amountLiters != null)
              .firstOrNull
              ?.amountLiters;
          _changeVolumeCtrl.text = latestAmount == null
              ? ''
              : formatVolume(latestAmount, prefs.volume);
          _countCtrl.text = '1';
        }
        _selectedParamKey = eligible.firstOrNull?.paramKey;
        _loadParameterContext(eligible, readings, prefs);
      });
    });
  }

  void _loadParameterContext(
    List<ResolvedParameter> parameters,
    List<Reading> readings,
    UnitPrefs prefs,
  ) {
    final parameter = parameters
        .where((p) => p.paramKey == _selectedParamKey)
        .firstOrNull;
    _sourceReading = readings
        .where((reading) => reading.paramKey == _selectedParamKey)
        .firstOrNull;
    final presentation = parameter == null
        ? null
        : presentationOf(parameter, prefs);
    _currentCtrl.text = _sourceReading == null || presentation == null
        ? ''
        : presentation.format(_sourceReading!.value);
    final target = parameter?.target ?? _greenMidpoint(parameter);
    _targetCtrl.text = target == null || presentation == null
        ? ''
        : presentation.format(target);
    // Replacement-water chemistry is a real measurement/preparation choice.
    // Never invent it from the tank target or a universal salt-water preset.
    _replacementCtrl.clear();
    _result = null;
    _resultTarget = null;
  }

  double? _greenMidpoint(ResolvedParameter? parameter) {
    final low = parameter?.bounds.greenLow;
    final high = parameter?.bounds.greenHigh;
    return low == null || high == null ? null : (low + high) / 2;
  }

  void _selectParameter(
    String? key,
    List<ResolvedParameter> parameters,
    List<Reading> readings,
    UnitPrefs prefs,
  ) {
    if (key == null || key == _selectedParamKey) return;
    setState(() {
      _selectedParamKey = key;
      _loadParameterContext(parameters, readings, prefs);
    });
  }

  String? _positiveValidator(AppLocalizations l, String? text) {
    final value = parseUserDouble(text);
    return value == null || value <= 0 ? l.invalidPositiveNumber : null;
  }

  String? _concentrationValidator(
    AppLocalizations l,
    String? text,
    ParamPresentation presentation,
  ) {
    final displayed = parseUserDouble(text);
    if (displayed == null) return l.waterChangePlannerNonNegativeError;
    final canonical = presentation.toCanonical(displayed);
    final linear = _selectedParamKey == 'salinity'
        ? sgToPpt(canonical)
        : canonical;
    return !linear.isFinite || linear < 0
        ? l.waterChangePlannerNonNegativeError
        : null;
  }

  String? _countValidator(AppLocalizations l, String? text) {
    final value = int.tryParse(text?.trim() ?? '');
    return value == null || value < 1 || value > 10000
        ? l.waterChangePlannerCountError
        : null;
  }

  double? _parsePlannerConcentration(
    TextEditingController controller,
    ParamPresentation presentation,
  ) {
    final displayed = parseUserDouble(controller.text);
    if (displayed == null || displayed < 0) return null;
    final canonical = presentation.toCanonical(displayed);
    return _selectedParamKey == 'salinity' ? sgToPpt(canonical) : canonical;
  }

  double _plannerToDisplay(double value, ParamPresentation presentation) {
    final canonical = _selectedParamKey == 'salinity' ? pptToSg(value) : value;
    return presentation.toDisplay(canonical);
  }

  void _calculate(ResolvedParameter parameter, UnitPrefs prefs) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tankVolume = volumeToCanonical(
      parseUserDouble(_tankVolumeCtrl.text)!,
      prefs.volume,
    );
    final changeVolume = volumeToCanonical(
      parseUserDouble(_changeVolumeCtrl.text)!,
      prefs.volume,
    );
    final l = AppLocalizations.of(context);
    if (changeVolume > tankVolume) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.waterChangePlannerVolumeError)));
      return;
    }
    final presentation = presentationOf(parameter, prefs);
    final current = _parsePlannerConcentration(_currentCtrl, presentation)!;
    final replacement = _parsePlannerConcentration(
      _replacementCtrl,
      presentation,
    )!;
    final target = _targetCtrl.text.trim().isEmpty
        ? null
        : _parsePlannerConcentration(_targetCtrl, presentation);
    setState(() {
      _resultTarget = target;
      _result = projectWaterChanges(
        method: _method,
        tankVolumeLiters: tankVolume,
        changeVolumeLiters: changeVolume,
        initialConcentration: current,
        replacementConcentration: replacement,
        plannedChanges: int.parse(_countCtrl.text.trim()),
        targetConcentration: target,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    final trackedAsync = ref.watch(trackedParametersProvider);
    final readingsAsync = ref.watch(recentReadingsProvider);
    final changesAsync = ref.watch(waterChangesProvider);
    final readings = readingsAsync.value ?? const [];
    final changes = changesAsync.value ?? const [];
    final prefs = ref.watch(unitPrefsProvider);
    final unitsReady =
        ref.watch(volumeUnitProvider).hasValue &&
        ref.watch(salinityUnitProvider).hasValue;
    final parameters = _eligible(trackedAsync.value ?? const []);

    if (tank != null &&
        trackedAsync.hasValue &&
        readingsAsync.hasValue &&
        changesAsync.hasValue &&
        unitsReady) {
      _queueContextSync(tank, parameters, readings, changes, prefs);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.waterChangePlannerTitle)),
      body: tank == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.waterChangePlannerNoTank,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : trackedAsync.isLoading && !trackedAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : parameters.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.waterChangePlannerNoParameters,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _plannerBody(l, parameters, readings, prefs),
    );
  }

  Widget _plannerBody(
    AppLocalizations l,
    List<ResolvedParameter> parameters,
    List<Reading> readings,
    UnitPrefs prefs,
  ) {
    final parameter = parameters
        .where((p) => p.paramKey == _selectedParamKey)
        .firstOrNull;
    if (parameter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final presentation = presentationOf(parameter, prefs);
    final source = _sourceReading;
    final stale =
        source != null &&
        DateTime.now().difference(source.takenAt) >
            const Duration(days: kHealthFreshnessDays);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.waterChangePlannerIntro),
        const SizedBox(height: 16),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ReefSegmented<WaterChangeMethod>(
              options: [
                (WaterChangeMethod.batch, l.waterChangePlannerBatch),
                (WaterChangeMethod.continuous, l.waterChangePlannerAutomatic),
              ],
              selected: _method,
              onChanged: (method) => setState(() {
                _method = method;
                _result = null;
              }),
              optionKeys: const {
                WaterChangeMethod.batch: Key('water-change-method-batch'),
                WaterChangeMethod.continuous: Key(
                  'water-change-method-automatic',
                ),
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _method == WaterChangeMethod.batch
              ? l.waterChangePlannerBatchHelp
              : l.waterChangePlannerAutomaticHelp,
          textAlign: TextAlign.center,
          style: TextStyle(color: ReefTokens.of(context).textDim, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ReefCard(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('water-change-parameter'),
                  initialValue: parameter.paramKey,
                  decoration: InputDecoration(
                    labelText: l.waterChangePlannerParameter,
                  ),
                  items: [
                    for (final p in parameters)
                      DropdownMenuItem(
                        value: p.paramKey,
                        child: Text(l.paramName(p.paramKey)),
                      ),
                  ],
                  onChanged: (key) =>
                      _selectParameter(key, parameters, readings, prefs),
                ),
                const SizedBox(height: 12),
                _numberField(
                  key: 'water-change-tank-volume',
                  controller: _tankVolumeCtrl,
                  label: l.waterChangePlannerTankVolume(prefs.volume.symbol),
                  validator: (text) => _positiveValidator(l, text),
                ),
                const SizedBox(height: 12),
                _numberField(
                  key: 'water-change-change-volume',
                  controller: _changeVolumeCtrl,
                  label: l.waterChangePlannerChangeVolume(prefs.volume.symbol),
                  validator: (text) => _positiveValidator(l, text),
                ),
                const SizedBox(height: 12),
                _numberField(
                  key: 'water-change-current',
                  controller: _currentCtrl,
                  label: l.waterChangePlannerCurrent(presentation.unitLabel),
                  validator: (text) =>
                      _concentrationValidator(l, text, presentation),
                  onChanged: (_) {
                    setState(() {
                      _sourceReading = null;
                      _result = null;
                    });
                  },
                ),
                if (source != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    stale
                        ? l.waterChangePlannerReadingStale(
                            formatDate(source.takenAt),
                          )
                        : l.waterChangePlannerReadingDate(
                            formatDate(source.takenAt),
                          ),
                    style: TextStyle(
                      color: stale
                          ? Theme.of(context).colorScheme.error
                          : ReefTokens.of(context).textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _numberField(
                  key: 'water-change-replacement',
                  controller: _replacementCtrl,
                  label: l.waterChangePlannerReplacement(
                    presentation.unitLabel,
                  ),
                  validator: (text) =>
                      _concentrationValidator(l, text, presentation),
                ),
                const SizedBox(height: 12),
                _numberField(
                  key: 'water-change-target',
                  controller: _targetCtrl,
                  label: l.waterChangePlannerTarget(presentation.unitLabel),
                  validator: (text) => text == null || text.trim().isEmpty
                      ? null
                      : _concentrationValidator(l, text, presentation),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('water-change-count'),
                  controller: _countCtrl,
                  style: ReefTokens.monoInputStyle,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.waterChangePlannerPlannedChanges,
                  ),
                  validator: (text) => _countValidator(l, text),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('water-change-calculate'),
                  onPressed: () => _calculate(parameter, prefs),
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(l.waterChangePlannerCalculate),
                ),
              ],
            ),
          ),
        ),
        if (_result case final result?) ...[
          const SizedBox(height: 16),
          _resultCard(l, result, presentation, prefs),
        ],
        const SizedBox(height: 16),
        ReefCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(l.waterChangePlannerAssumption)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String key,
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
    key: Key(key),
    controller: controller,
    style: ReefTokens.monoInputStyle,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: validator,
    onChanged: onChanged ?? (_) => setState(() => _result = null),
  );

  Widget _resultCard(
    AppLocalizations l,
    WaterChangeProjection result,
    ParamPresentation presentation,
    UnitPrefs prefs,
  ) {
    String concentration(double value) =>
        '${formatLocaleNumber(_plannerToDisplay(value, presentation), presentation.decimals)} ${presentation.unitLabel}';
    String percent(double value) =>
        '${formatLocaleNumberTrim(value * 100, decimals: 2)}%';

    final targetCount = result.changesToTarget;
    final target = _resultTarget;
    final targetRows = <int>[];
    if (targetCount != null && targetCount > 0) {
      if (targetCount <= 12) {
        targetRows.addAll([for (var n = 1; n <= targetCount; n++) n]);
      } else {
        targetRows.addAll([1, 2, 3, 4, 5, 6, targetCount]);
      }
    }

    return ReefCard(
      key: const Key('water-change-result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.waterChangePlannerProjection,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _resultLine(
            l.waterChangePlannerAfterOne,
            concentration(result.afterOne.concentration),
          ),
          if (result.plannedChanges > 1)
            _resultLine(
              l.waterChangePlannerAfterPlanned(result.plannedChanges),
              concentration(result.afterPlanned.concentration),
            ),
          _resultLine(
            l.waterChangePlannerEffectiveChanged,
            percent(result.afterPlanned.effectiveChangeFraction),
          ),
          const Divider(height: 24),
          Text(
            l.waterChangePlannerTargetSchedule,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (target == null)
            Text(l.waterChangePlannerTargetOptional)
          else if (targetCount == 0)
            Text(l.waterChangePlannerAlreadyAtTarget)
          else if (targetCount == null)
            Text(l.waterChangePlannerTargetUnreachable)
          else ...[
            Text(
              l.waterChangePlannerTargetSummary(
                targetCount,
                '${formatVolume(result.changeVolumeLiters * targetCount, prefs.volume)} ${prefs.volume.symbol}',
                percent(
                  effectiveWaterChangeFraction(
                    method: result.method,
                    tankVolumeLiters: result.tankVolumeLiters,
                    changeVolumeLiters: result.changeVolumeLiters,
                    changes: targetCount,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < targetRows.length; i++) ...[
              if (i > 0 && targetRows[i] - targetRows[i - 1] > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l.waterChangePlannerScheduleOmitted(
                      targetRows[i] - targetRows[i - 1] - 1,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ReefTokens.of(context).textDim),
                  ),
                ),
              _resultLine(
                l.waterChangePlannerStep(targetRows[i]),
                concentration(
                  projectedWaterChangeConcentration(
                    method: result.method,
                    tankVolumeLiters: result.tankVolumeLiters,
                    changeVolumeLiters: result.changeVolumeLiters,
                    initialConcentration: result.initialConcentration,
                    replacementConcentration: result.replacementConcentration,
                    changes: targetRows[i],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _resultLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: ReefTokens.monoTextStyle),
      ],
    ),
  );
}
