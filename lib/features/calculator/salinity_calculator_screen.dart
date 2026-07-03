import 'package:flutter/material.dart';

import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';

/// Two-way salinity converter: ppt <-> specific gravity (SG).
/// Editing either field updates the other live.
class SalinityCalculatorScreen extends StatefulWidget {
  const SalinityCalculatorScreen({super.key});

  @override
  State<SalinityCalculatorScreen> createState() =>
      _SalinityCalculatorScreenState();
}

class _SalinityCalculatorScreenState extends State<SalinityCalculatorScreen> {
  // Seed the fields through the locale formatter so a cs/de user sees "35,0"
  // from the start, matching what the fields echo while typing (#39).
  late final _pptCtrl = TextEditingController(text: formatLocaleNumber(35, 1));
  late final _sgCtrl = TextEditingController(
    text: formatLocaleNumber(1.0264, 4),
  );
  bool _updating = false;

  @override
  void dispose() {
    _pptCtrl.dispose();
    _sgCtrl.dispose();
    super.dispose();
  }

  double? _parse(String s) => parseUserDouble(s);

  void _onPptChanged(String text) {
    if (_updating) return;
    final ppt = _parse(text);
    if (ppt == null) return;
    _updating = true;
    _sgCtrl.text = formatLocaleNumber(pptToSg(ppt), 4);
    _updating = false;
  }

  void _onSgChanged(String text) {
    if (_updating) return;
    final sg = _parse(text);
    if (sg == null) return;
    _updating = true;
    _pptCtrl.text = formatLocaleNumber(sgToPpt(sg), 1);
    _updating = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.salinityCalculator)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.calculatorIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pptCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.salinity,
              suffixText: 'ppt',
              border: const OutlineInputBorder(),
            ),
            onChanged: _onPptChanged,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: Icon(Icons.swap_vert, size: 28)),
          ),
          TextField(
            controller: _sgCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.specificGravity,
              suffixText: 'SG',
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSgChanged,
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.referencePoints,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l.refSeawater),
                  Text(l.refReefTarget),
                  const SizedBox(height: 8),
                  Text(
                    l.refFormulaNote,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
