import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_card.dart';

/// Two-way salinity converter: ppt <-> specific gravity (SG).
/// Editing either field updates the other live.
///
/// Restyled per REDESIGN #25: mono entry in both live fields (#18 input
/// treatment) and the reference card as a `ReefCard` with token text styles.
class SalinityCalculatorScreen extends StatefulWidget {
  const SalinityCalculatorScreen({super.key});

  @override
  State<SalinityCalculatorScreen> createState() =>
      _SalinityCalculatorScreenState();
}

class _SalinityCalculatorScreenState extends State<SalinityCalculatorScreen> {
  /// Reference salinity both fields open with (natural seawater, ppt).
  static const _seedPpt = 35.0;

  // Seed the fields through the locale formatter so a cs/de user sees "35,0"
  // from the start, matching what the fields echo while typing (#39). The SG
  // seed is derived via pptToSg so the two fields agree by construction.
  late final _pptCtrl = TextEditingController(
    text: formatLocaleNumber(_seedPpt, 1),
  );
  late final _sgCtrl = TextEditingController(
    text: formatLocaleNumber(pptToSg(_seedPpt), 4),
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
    final tokens = ReefTokens.of(context);
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
            style: ReefTokens.monoInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.salinity,
              suffixText: 'ppt',
            ),
            onChanged: _onPptChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Icon(Icons.swap_vert, size: 28, color: tokens.textDim),
            ),
          ),
          TextField(
            controller: _sgCtrl,
            style: ReefTokens.monoInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.specificGravity,
              suffixText: 'SG',
            ),
            onChanged: _onSgChanged,
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
                Text(
                  l.refSeawater,
                  style: TextStyle(fontSize: 13, color: tokens.textDim),
                ),
                Text(
                  l.refReefTarget,
                  style: TextStyle(fontSize: 13, color: tokens.textDim),
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
      ),
    );
  }
}
