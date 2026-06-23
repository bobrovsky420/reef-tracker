import 'package:flutter/material.dart';

import '../../domain/units.dart';

/// Two-way salinity converter: ppt <-> specific gravity (SG).
/// Editing either field updates the other live.
class SalinityCalculatorScreen extends StatefulWidget {
  const SalinityCalculatorScreen({super.key});

  @override
  State<SalinityCalculatorScreen> createState() =>
      _SalinityCalculatorScreenState();
}

class _SalinityCalculatorScreenState extends State<SalinityCalculatorScreen> {
  final _pptCtrl = TextEditingController(text: '35.0');
  final _sgCtrl = TextEditingController(text: '1.0264');
  bool _updating = false;

  @override
  void dispose() {
    _pptCtrl.dispose();
    _sgCtrl.dispose();
    super.dispose();
  }

  double? _parse(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));

  void _onPptChanged(String text) {
    if (_updating) return;
    final ppt = _parse(text);
    if (ppt == null) return;
    _updating = true;
    _sgCtrl.text = pptToSg(ppt).toStringAsFixed(4);
    _updating = false;
  }

  void _onSgChanged(String text) {
    if (_updating) return;
    final sg = _parse(text);
    if (sg == null) return;
    _updating = true;
    _pptCtrl.text = sgToPpt(sg).toStringAsFixed(1);
    _updating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salinity calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Convert between practical salinity (ppt) and specific gravity (SG). '
            'Type in either field.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pptCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Salinity',
              suffixText: 'ppt',
              border: OutlineInputBorder(),
            ),
            onChanged: _onPptChanged,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: Icon(Icons.swap_vert, size: 28)),
          ),
          TextField(
            controller: _sgCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Specific gravity',
              suffixText: 'SG',
              border: OutlineInputBorder(),
            ),
            onChanged: _onSgChanged,
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reference points',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Natural seawater ≈ 35 ppt ≈ 1.0264 SG'),
                  Text('• Typical reef target ≈ 35 ppt (1.025–1.027 SG)'),
                  SizedBox(height: 8),
                  Text(
                    'SG is referenced at 25 °C. Conversion is a linear '
                    'approximation: SG = 1 + ppt × 0.0264/35.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
