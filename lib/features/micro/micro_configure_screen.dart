import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// Configuration list for the microelement panel (U17): every catalog element
/// in report order (major ions / trace elements / contaminants), each row
/// showing its *effective* zone bounds. Tapping a row opens the standard
/// `ParameterEditScreen` (zones, test cadence), creating the element's
/// tracked row on demand — the same lazy-row rule as the panel itself.
/// Deliberately unfiltered by the active view: bounds are configurable for
/// any element, not just the ones the current lab reports.
class MicroConfigureScreen extends ConsumerWidget {
  const MicroConfigureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    if (tank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.microConfigureTitle)),
        body: Center(child: Text(l.noActiveAquarium)),
      );
    }
    final elements = ref.watch(microElementsProvider);
    final prefs = ref.watch(unitPrefsProvider);

    final sections = <(String, ParamCategory)>[
      (l.microSectionMajor, ParamCategory.major),
      (l.microSectionTrace, ParamCategory.trace),
      (l.microSectionContaminants, ParamCategory.contaminant),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.microConfigureTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (title, category) in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final e in elements)
              if (e.def.category == category)
                _ConfigureRow(element: e, prefs: prefs),
          ],
        ],
      ),
    );
  }
}

class _ConfigureRow extends ConsumerWidget {
  const _ConfigureRow({required this.element, required this.prefs});

  final MicroElementStatus element;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final def = element.def;
    final pres = presentationForKey(
      def.key,
      element.row?.unit ?? def.unit,
      prefs,
    );
    return ListTile(
      title: Text(l.paramName(def.key)),
      subtitle: Text(_boundsSummary(l, element.bounds, pres)),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        tooltip: l.editZones,
        onPressed: () => _editBounds(context, ref),
      ),
    );
  }

  /// Opens the standard bounds editor, creating the element's tracked row
  /// first when it doesn't exist yet (seeded with the catalog defaults by
  /// `addTrackedParameter`).
  Future<void> _editBounds(BuildContext context, WidgetRef ref) async {
    final tank = ref.read(activeTankProvider);
    if (tank == null) return;
    var row = element.row;
    if (row == null) {
      final db = ref.read(dbProvider);
      await db.addTrackedParameter(
        tank.id,
        element.def.key,
        SetupType.fromName(tank.setupType),
      );
      for (final t in await db.getTrackedParameters(tank.id)) {
        if (t.paramKey == element.def.key) {
          row = t;
          break;
        }
      }
    }
    if (row != null && context.mounted) {
      await context.push('/parameters/${row.id}/edit', extra: row);
    }
  }
}

String _boundsSummary(
  AppLocalizations l,
  ZoneBounds b,
  ParamPresentation pres,
) {
  if (b.isEmpty) return l.noBoundariesSet;
  String f(double? v) => v == null ? '∞' : pres.format(v);
  return l.boundsSummary(
    f(b.greenLow),
    f(b.greenHigh),
    pres.unitLabel,
    f(b.amberLow),
    f(b.amberHigh),
  );
}
