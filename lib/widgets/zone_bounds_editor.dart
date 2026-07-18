import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import 'zone_visuals.dart';

/// Shared editor for a set of four zone boundaries
/// (`amberLow` ≤ `greenLow` ≤ `greenHigh` ≤ `amberHigh`), used by both the
/// per-parameter and the per-ratio bound editors.
///
/// The widget owns the four text controllers and renders the legend, the four
/// bound fields (each with its zone-colored dot) and an optional [trailingNote].
/// It does **not** decide what the values mean or where they are saved: the
/// parent seeds the fields via [initial] + [format] (values are in whatever
/// display space the parent uses), reads the parsed [ZoneBoundsEditorState.values]
/// on save, and checks [ZoneBoundsEditorState.orderOk] / `pairsOk` to surface its
/// own localized errors. Wrap it in the parent's [Form] so the per-field
/// number validators participate in `Form.validate()`.
class ZoneBoundsEditor extends StatefulWidget {
  const ZoneBoundsEditor({
    super.key,
    required this.initial,
    required this.format,
    this.trailingNote,
  });

  /// Seed values, already expressed in the parent's display space.
  final ZoneBounds initial;

  /// Formats a seed value into the field's initial text (parents differ: the
  /// parameter editor uses fixed decimals, the ratio editor trims integers).
  final String Function(double) format;

  /// Optional note rendered below the fields (e.g. the unit reminder).
  final Widget? trailingNote;

  @override
  ZoneBoundsEditorState createState() => ZoneBoundsEditorState();
}

class ZoneBoundsEditorState extends State<ZoneBoundsEditor> {
  late final TextEditingController _amberLow;
  late final TextEditingController _greenLow;
  late final TextEditingController _greenHigh;
  late final TextEditingController _amberHigh;

  @override
  void initState() {
    super.initState();
    _amberLow = _ctrl(widget.initial.amberLow);
    _greenLow = _ctrl(widget.initial.greenLow);
    _greenHigh = _ctrl(widget.initial.greenHigh);
    _amberHigh = _ctrl(widget.initial.amberHigh);
  }

  TextEditingController _ctrl(double? v) =>
      TextEditingController(text: v == null ? '' : widget.format(v));

  @override
  void dispose() {
    _amberLow.dispose();
    _greenLow.dispose();
    _greenHigh.dispose();
    _amberHigh.dispose();
    super.dispose();
  }

  static double? _parse(TextEditingController c) => parseUserDouble(c.text);

  /// The four parsed bounds in the parent's display space (null where blank).
  ZoneBounds get values => ZoneBounds(
    amberLow: _parse(_amberLow),
    greenLow: _parse(_greenLow),
    greenHigh: _parse(_greenHigh),
    amberHigh: _parse(_amberHigh),
  );

  /// True when the present bounds are monotonically non-decreasing.
  bool get orderOk {
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
  /// same side: it would leave the chart zone bands overlapping (see #15/#17).
  bool get pairsOk {
    if (_parse(_amberLow) != null && _parse(_greenLow) == null) return false;
    if (_parse(_amberHigh) != null && _parse(_greenHigh) == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ZoneLegendRow(),
        const SizedBox(height: 8),
        _boundField(_amberLow, l.boundAmberLow, Zone.red),
        _boundField(_greenLow, l.boundGreenLow, Zone.green),
        _boundField(_greenHigh, l.boundGreenHigh, Zone.green),
        _boundField(_amberHigh, l.boundAmberHigh, Zone.red),
        if (widget.trailingNote != null) ...[
          const SizedBox(height: 8),
          widget.trailingNote!,
        ],
      ],
    );
  }

  Widget _boundField(TextEditingController c, String label, Zone zone) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        // Numeric entry in the mono family (REDESIGN #18/#19).
        style: ReefTokens.monoInputStyle,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.circle, color: zone.colorOf(context), size: 14),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 0,
          ),
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
        Icon(Icons.circle, color: z.colorOf(context), size: 12),
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
