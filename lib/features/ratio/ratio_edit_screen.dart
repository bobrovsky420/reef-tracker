import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/ratio.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/zone_bounds_editor.dart';

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
  final _editorKey = GlobalKey<ZoneBoundsEditorState>();

  // Up to 4 decimals: ratio bounds can be small fractions (e.g. 0.025).
  static String _fmt(double v) => formatLocaleNumberTrim(v, decimals: 4);

  Future<void> _save(int tankId) async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final editor = _editorKey.currentState!;
    if (!editor.orderOk) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.boundsOrderError)));
      return;
    }
    if (!editor.pairsOk) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.boundsPairError)));
      return;
    }
    final bounds = editor.values;
    await ref
        .read(dbProvider)
        .setRatioBounds(
          tankId,
          widget.kind.name,
          amberLow: bounds.amberLow,
          greenLow: bounds.greenLow,
          greenHigh: bounds.greenHigh,
          amberHigh: bounds.amberHigh,
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

    // Seed the editor once from the tank's current effective bounds.
    final row = ref.read(ratioSettingsProvider).value?[kind.name];

    return Scaffold(
      appBar: AppBar(title: Text(l.ratioCardLabel(kind))),
      // Form grouped into a card section (REDESIGN #19): Safe ranges only —
      // ratios have no unit or testing reminder.
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.ratioBoundsNote(ratioMetricLabel(kind)),
              style: TextStyle(
                fontSize: 12.5,
                color: ReefTokens.of(context).textDim,
              ),
            ),
            SectionHeader(l.sectionSafeRanges),
            ReefCard(
              padding: const EdgeInsets.all(16),
              child: ZoneBoundsEditor(
                key: _editorKey,
                initial: ratioBounds(kind, row),
                format: _fmt,
              ),
            ),
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
}
