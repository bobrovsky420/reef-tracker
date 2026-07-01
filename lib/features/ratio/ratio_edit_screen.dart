import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/ratio.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Editor for a ratio card's four zone boundaries, per tank. Values are in the
/// ratio's displayed-metric space (e.g. NO₃ ÷ PO₄, Mg ÷ Ca) — there is no unit
/// conversion. Saving writes the bounds to the tank's `RatioVisibilities` row.
class RatioEditScreen extends ConsumerStatefulWidget {
  const RatioEditScreen({super.key, required this.kind});

  final RatioKind kind;

  @override
  ConsumerState<RatioEditScreen> createState() => _RatioEditScreenState();
}

class _RatioEditScreenState extends ConsumerState<RatioEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amberLow;
  late final TextEditingController _greenLow;
  late final TextEditingController _greenHigh;
  late final TextEditingController _amberHigh;
  bool _initialized = false;

  @override
  void dispose() {
    if (_initialized) {
      _amberLow.dispose();
      _greenLow.dispose();
      _greenHigh.dispose();
      _amberHigh.dispose();
    }
    super.dispose();
  }

  void _initFrom(ZoneBounds bounds) {
    _amberLow = TextEditingController(text: _fmt(bounds.amberLow));
    _greenLow = TextEditingController(text: _fmt(bounds.greenLow));
    _greenHigh = TextEditingController(text: _fmt(bounds.greenHigh));
    _amberHigh = TextEditingController(text: _fmt(bounds.amberHigh));
    _initialized = true;
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  }

  double? _parse(TextEditingController c) => parseUserDouble(c.text);

  bool _orderOk() {
    final seq = [
      _parse(_amberLow),
      _parse(_greenLow),
      _parse(_greenHigh),
      _parse(_amberHigh),
    ].whereType<double>().toList();
    for (var i = 1; i < seq.length; i++) {
      if (seq[i] < seq[i - 1]) return false;
    }
    return true;
  }

  /// An amber bound is meaningless without its matching green bound on the
  /// same side: it would leave the chart zone bands overlapping (see #15).
  bool _pairsOk() {
    if (_parse(_amberLow) != null && _parse(_greenLow) == null) return false;
    if (_parse(_amberHigh) != null && _parse(_greenHigh) == null) return false;
    return true;
  }

  Future<void> _save(int tankId) async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (!_orderOk()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.boundsOrderError)));
      return;
    }
    if (!_pairsOk()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.boundsPairError)));
      return;
    }
    await ref.read(dbProvider).setRatioBounds(
          tankId,
          widget.kind.name,
          amberLow: _parse(_amberLow),
          greenLow: _parse(_greenLow),
          greenHigh: _parse(_greenHigh),
          amberHigh: _parse(_amberHigh),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final kind = widget.kind;
    final tank = ref.watch(activeTankProvider);

    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.ratioCardLabel(kind))),
        body: Center(child: Text(l.noActiveAquarium)),
      );
    }

    // Initialize controllers once from the tank's current effective bounds.
    if (!_initialized) {
      final row = ref.read(ratioSettingsProvider).value?[kind.name];
      _initFrom(ratioBounds(kind, row));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.ratioCardLabel(kind))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.ratioBoundsNote(ratioMetricLabel(kind)),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            const _ZoneLegendRow(),
            const SizedBox(height: 8),
            _boundField(_amberLow, l.boundAmberLow, Zone.red),
            _boundField(_greenLow, l.boundGreenLow, Zone.green),
            _boundField(_greenHigh, l.boundGreenHigh, Zone.green),
            _boundField(_amberHigh, l.boundAmberHigh, Zone.red),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _save(tank.id),
              icon: const Icon(Icons.save),
              label: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundField(TextEditingController c, String label, Zone zone) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.circle, color: zone.color, size: 14),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 0),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          return parseUserDouble(v) == null ? l.enterANumber : null;
        },
      ),
    );
  }
}

class _ZoneLegendRow extends StatelessWidget {
  const _ZoneLegendRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget dot(Zone z, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: z.color, size: 12),
            const SizedBox(width: 4),
            Text(label),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        dot(Zone.green, l.zoneOk),
        dot(Zone.amber, l.zoneAttention),
        dot(Zone.red, l.zoneActNow),
      ],
    );
  }
}
