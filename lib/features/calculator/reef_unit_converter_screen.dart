import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_card.dart';

/// A compact, deliberately standalone reference converter. It never reads or
/// stores tank data: its values are useful while interpreting a test, label or
/// equipment manual, not measurements to add to the aquarium history.
class ReefUnitConverterScreen extends StatelessWidget {
  const ReefUnitConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.reefUnitConverter)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.reefUnitConverterIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _ConversionCard(
            title: l.alkalinity,
            sourceUnitLabel: l.converterSourceUnit,
            valueLabel: l.converterValue,
            equivalentLabel: l.converterEquivalent,
            units: [
              _ConversionUnit('dKH', 8, (v) => v, (v) => v, 2),
              _ConversionUnit('meq/L', 8 * meqPerDkh, meqToDkh, dkhToMeq, 3),
              _ConversionUnit(
                'ppm CaCO₃',
                8 * ppmCaco3PerDkh,
                ppmCaco3ToDkh,
                dkhToPpmCaco3,
                1,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ConversionCard(
            title: l.temperature,
            sourceUnitLabel: l.converterSourceUnit,
            valueLabel: l.converterValue,
            equivalentLabel: l.converterEquivalent,
            units: [
              _ConversionUnit('°C', 25, (v) => v, (v) => v, 1),
              _ConversionUnit('°F', 77, fToCelsius, celsiusToF, 1),
            ],
          ),
          const SizedBox(height: 16),
          _ConversionCard(
            title: l.volume,
            sourceUnitLabel: l.converterSourceUnit,
            valueLabel: l.converterValue,
            equivalentLabel: l.converterEquivalent,
            units: [
              _ConversionUnit('L', 100, (v) => v, (v) => v, 1),
              _ConversionUnit(
                'US gal',
                100 / litersPerUsGallon,
                gallonsToLiters,
                litersToGallons,
                2,
              ),
              _ConversionUnit(
                'Imp gal',
                100 / litersPerImperialGallon,
                imperialGallonsToLiters,
                litersToImperialGallons,
                2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversionUnit {
  const _ConversionUnit(
    this.label,
    this.seed,
    this.toCanonical,
    this.fromCanonical,
    this.decimals,
  );

  final String label;
  final double seed;
  final double Function(double value) toCanonical;
  final double Function(double canonical) fromCanonical;
  final int decimals;

  @override
  bool operator ==(Object other) =>
      other is _ConversionUnit && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

class _ConversionCard extends StatefulWidget {
  const _ConversionCard({
    required this.title,
    required this.sourceUnitLabel,
    required this.valueLabel,
    required this.equivalentLabel,
    required this.units,
  });

  final String title;
  final String sourceUnitLabel;
  final String valueLabel;
  final String equivalentLabel;
  final List<_ConversionUnit> units;

  @override
  State<_ConversionCard> createState() => _ConversionCardState();
}

class _ConversionCardState extends State<_ConversionCard> {
  late _ConversionUnit _source = widget.units.first;
  late final TextEditingController _controller = TextEditingController(
    text: formatLocaleNumber(_source.seed, _source.decimals),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeSource(_ConversionUnit? unit) {
    if (unit == null || unit == _source) return;
    final value = parseUserDouble(_controller.text);
    final canonical = value == null ? null : _source.toCanonical(value);
    setState(() {
      _source = unit;
      _controller.text = canonical == null
          ? ''
          : formatLocaleNumber(
              _source.fromCanonical(canonical),
              _source.decimals,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final sourceValue = parseUserDouble(_controller.text);
    final canonical = sourceValue == null
        ? null
        : _source.toCanonical(sourceValue);
    return ReefCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_ConversionUnit>(
            initialValue: _source,
            decoration: InputDecoration(labelText: widget.sourceUnitLabel),
            items: widget.units
                .map(
                  (unit) =>
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                )
                .toList(),
            onChanged: _changeSource,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            style: ReefTokens.monoInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.valueLabel,
              suffixText: _source.label,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            widget.equivalentLabel,
            style: TextStyle(fontSize: 13, color: tokens.textDim),
          ),
          const SizedBox(height: 4),
          for (final unit in widget.units.where((unit) => unit != _source))
            _EquivalentRow(
              value: canonical == null
                  ? '—'
                  : formatLocaleNumber(
                      unit.fromCanonical(canonical),
                      unit.decimals,
                    ),
              unit: unit.label,
            ),
        ],
      ),
    );
  }
}

class _EquivalentRow extends StatelessWidget {
  const _EquivalentRow({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value,
            style: ReefTokens.monoInputStyle.copyWith(fontSize: 18),
          ),
        ),
        Text(unit, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
