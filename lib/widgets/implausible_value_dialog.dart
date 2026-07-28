import 'package:flutter/material.dart';

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

/// Why a value is being questioned before it is stored.
enum SuspectReason {
  /// Physically possible but outside the catalog's plausible range (#31) —
  /// the classic order-of-magnitude slip or mis-parsed decimal separator.
  implausible,

  /// The value sits exactly on the parameter's floor, where that floor is also
  /// the bottom of the plausible range (0 dKH, 0 ppt of salt). Nothing in
  /// [checkParamValue] can flag it — it is a legal reading — but from a probe
  /// it is the classic "no signal" rail, so device paths question it.
  rail,
}

/// Why a **device-sourced** value should be put to the user before it is
/// stored, or null when it may be saved without asking.
///
/// Two tiers, in the order they can fire: outside the plausible range (what
/// manual entry has always confirmed), then sitting on the sensor's rail (see
/// [isRailValue]). Impossible values never reach here — every device path
/// drops them at its own filter, silently, as it always has.
SuspectReason? deviceSuspectReason(String paramKey, double value) =>
    switch (checkParamValue(paramKey, value)) {
      ParamValueCheck.implausible => SuspectReason.implausible,
      ParamValueCheck.impossible => null,
      ParamValueCheck.ok => isRailValue(paramKey, value)
          ? SuspectReason.rail
          : null,
    };

/// One value put to the user before saving.
///
/// [pres] is how to render it; when null the catalog's own unit is used under
/// the user's preferences, which is what every path except the history editor
/// (whose parameter carries a per-tank unit) wants.
class SuspectValue {
  const SuspectValue(
    this.paramKey,
    this.canonical, {
    this.pres,
    this.reason = SuspectReason.implausible,
  });

  final String paramKey;
  final double canonical;
  final ParamPresentation? pres;
  final SuspectReason reason;
}

/// What the user decided.
enum SuspectChoice {
  /// Store the questioned values as they are.
  save,

  /// Leave the questioned values out but carry on with the rest of the save.
  /// Only reachable when the caller passes `allowSkip` — the bulk device save,
  /// where one bad probe must not cost the keeper every other reading.
  skip,

  /// Abandon the save (also what dismissing the dialog means).
  cancel,
}

/// The one confirmation for values that are savable but suspicious.
///
/// Every write path in the app funnels through this: manual entry, the history
/// editor, the micro/ICP forms, both Hanna paths and — since #71 — the device
/// dashboards. Each used to carry its own copy of this dialog, which is how the
/// device paths ended up with none.
///
/// Values are echoed **as the app understood them**, in the display unit, next
/// to the typical range: that is what exposes a locale mis-parse (`1,300` read
/// as 1.3) or a probe reporting a unit the app guessed wrong.
///
/// Entries whose parameter defines no plausible range are dropped; if that
/// leaves nothing to ask about, no dialog is shown and the answer is
/// [SuspectChoice.save].
Future<SuspectChoice> showImplausibleValuesDialog(
  BuildContext context, {
  required List<SuspectValue> values,
  UnitPrefs? prefs,
  String? intro,
  bool allowSkip = false,
}) async {
  final shown = [
    for (final v in values)
      if (kParameterByKey[v.paramKey] case final def?)
        if (def.plausibleMin != null && def.plausibleMax != null) (v, def),
  ];
  if (shown.isEmpty) return SuspectChoice.save;
  final l = AppLocalizations.of(context);

  // A caller that supplies a presentation for every entry (the history editor,
  // whose parameter carries a per-tank unit) needs no preferences at all.
  ParamPresentation presOf(SuspectValue v, ParameterDef def) =>
      v.pres ?? presentationForKey(def.key, def.unit, prefs ?? const UnitPrefs());

  final choice = await showDialog<SuspectChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.implausibleTitle),
      // Scrolls: a bulk save (an ICP report, a Save all across a fleet) can
      // question more values than a phone dialog is tall.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intro ?? l.implausibleIntro),
            const SizedBox(height: 12),
            for (final (v, def) in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Builder(
                  builder: (_) {
                    final pres = presOf(v, def);
                    final value =
                        '${pres.format(v.canonical)} ${pres.unitLabel}';
                    return Text(
                      switch (v.reason) {
                        SuspectReason.rail => l.implausibleRailLine(
                          l.paramName(def.key),
                          value,
                        ),
                        SuspectReason.implausible => l.implausibleValueLine(
                          l.paramName(def.key),
                          value,
                          pres.format(def.plausibleMin!),
                          '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
                        ),
                      },
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            ctx,
            allowSkip ? SuspectChoice.skip : SuspectChoice.cancel,
          ),
          child: Text(allowSkip ? l.implausibleSkip : l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, SuspectChoice.save),
          child: Text(l.saveAnyway),
        ),
      ],
    ),
  );
  return choice ?? SuspectChoice.cancel;
}
