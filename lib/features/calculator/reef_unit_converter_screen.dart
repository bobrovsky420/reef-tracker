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
            id: 'alkalinity',
            title: l.alkalinity,
            units: [
              _ConversionUnit('dkh', 'dKH', 8, (v) => v, (v) => v, 2),
              _ConversionUnit(
                'meq',
                'meq/L',
                8 * meqPerDkh,
                meqToDkh,
                dkhToMeq,
                3,
              ),
              _ConversionUnit(
                'ppm-caco3',
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
            id: 'temperature',
            title: l.temperature,
            units: [
              _ConversionUnit('celsius', '°C', 25, (v) => v, (v) => v, 1),
              _ConversionUnit(
                'fahrenheit',
                '°F',
                77,
                fToCelsius,
                celsiusToF,
                1,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ConversionCard(
            id: 'volume',
            title: l.volume,
            units: [
              _ConversionUnit('liters', 'L', 100, (v) => v, (v) => v, 1),
              _ConversionUnit(
                'us-gallons',
                'US gal',
                100 / litersPerUsGallon,
                gallonsToLiters,
                litersToGallons,
                2,
              ),
              _ConversionUnit(
                'imperial-gallons',
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
    this.id,
    this.label,
    this.seed,
    this.toCanonical,
    this.fromCanonical,
    this.decimals,
  );

  final String id;
  final String label;
  final double seed;
  final double Function(double value) toCanonical;
  final double Function(double canonical) fromCanonical;
  final int decimals;
}

class _ConversionCard extends StatefulWidget {
  const _ConversionCard({
    required this.id,
    required this.title,
    required this.units,
  });

  final String id;
  final String title;
  final List<_ConversionUnit> units;

  @override
  State<_ConversionCard> createState() => _ConversionCardState();
}

class _ConversionCardState extends State<_ConversionCard> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final unit in widget.units)
        unit.id: TextEditingController(
          text: formatLocaleNumber(unit.seed, unit.decimals),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(_ConversionUnit source, String text) {
    final value = parseUserDouble(text);
    final canonical = value == null ? null : source.toCanonical(value);

    for (final unit in widget.units) {
      if (unit.id == source.id) continue;
      final converted = canonical == null || !canonical.isFinite
          ? null
          : unit.fromCanonical(canonical);
      _controllers[unit.id]!.text = converted == null || !converted.isFinite
          ? ''
          : formatLocaleNumber(converted, unit.decimals);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          for (var index = 0; index < widget.units.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final unit = widget.units[index];
                return TextField(
                  key: Key('reef-unit-${widget.id}-${unit.id}'),
                  controller: _controllers[unit.id],
                  style: ReefTokens.monoInputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: index == widget.units.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: InputDecoration(labelText: unit.label),
                  onChanged: (text) => _onChanged(unit, text),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
