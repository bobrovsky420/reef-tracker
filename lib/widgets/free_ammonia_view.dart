import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/ammonia_toxicity.dart';
import '../domain/units.dart';
import '../domain/zones.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'reef_card.dart';
import 'zone_visuals.dart';

/// Formats free NH₃ (small, ~0.005–0.1) with 3 decimals so 0.02/0.05 thresholds
/// read cleanly; total ammonia keeps the parameter's 2 decimals.
String _fmtFree(double ppm) => formatLocaleNumber(ppm, 3);

/// The two shared display strings for a computed [FreeAmmonia]: the temperature
/// and salinity used, in the user's units.
({String temp, String salinity}) _inputStrings(FreeAmmonia fa, UnitPrefs prefs) {
  final tempPres = presentationForKey('temperature', '°C', prefs);
  final salPres = presentationForKey('salinity', 'SG', prefs);
  return (
    temp: '${tempPres.format(fa.tempC)} ${tempPres.unitLabel}',
    salinity: '${salPres.format(pptToSg(fa.salinityPpt))} ${salPres.unitLabel}',
  );
}

/// A small amber warning glyph shown when the pH/temperature inputs are stale.
Widget _outdatedIcon(BuildContext context) => Padding(
  padding: const EdgeInsets.only(right: 4),
  child: Tooltip(
    message: AppLocalizations.of(context).freeAmmoniaOutdatedWarning,
    child: Icon(
      Icons.warning_amber_rounded,
      size: 15,
      color: ReefTokens.of(context).caution,
    ),
  ),
);

/// Grouped-dashboard row for free (toxic) ammonia (NH₃) — the [RatioRow]
/// counterpart: a label + zone-colored value over a 6 px toxicity track with
/// the safe band and a ringed marker at the current value. Tapping it opens the
/// [showFreeAmmoniaInfo] explainer. [data] is null when the value can't be
/// computed yet (no ammonia / pH / temperature reading), rendering "No data".
class FreeAmmoniaRow extends StatelessWidget {
  const FreeAmmoniaRow({super.key, required this.data, required this.prefs});

  final FreeAmmonia? data;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final fa = data;
    final zone = fa?.zone ?? Zone.unknown;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: fa == null ? null : () => showFreeAmmoniaInfo(context, fa, prefs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l.freeAmmoniaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.text,
                      ),
                    ),
                  ),
                  if (fa == null)
                    Text(
                      l.noReadings,
                      style: TextStyle(fontSize: 12, color: tokens.textFaint),
                    )
                  else ...[
                    if (fa.inputsOutdated) _outdatedIcon(context),
                    Text(
                      _fmtFree(fa.freeNh3),
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: zone.colorOf(context),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'ppm',
                      style: TextStyle(fontSize: 10, color: tokens.textFaint),
                    ),
                  ],
                ],
              ),
              if (fa != null) ...[
                const SizedBox(height: 2),
                Text(
                  l.freeAmmoniaBreakdown(
                    formatLocaleNumber(fa.fractionPercent, 0),
                    formatLocaleNumber(fa.pH, 2),
                    _inputStrings(fa, prefs).temp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tokens.textDim),
                ),
                const SizedBox(height: 5),
                _FreeAmmoniaTrack(
                  value: fa.freeNh3,
                  markerColor: zone.colorOf(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Classic-dashboard grid tile for free ammonia — laid out like the ratio /
/// measurement tiles: title, the value colored by its toxicity zone, a percent
/// note, and the reading time. Tapping opens [showFreeAmmoniaInfo].
class FreeAmmoniaTile extends StatelessWidget {
  const FreeAmmoniaTile({super.key, required this.data, required this.prefs});

  final FreeAmmonia? data;
  final UnitPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = Theme.of(context).hintColor;
    final fa = data;

    return ReefCard(
      onTap: fa == null ? null : () => showFreeAmmoniaInfo(context, fa, prefs),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.freeAmmoniaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          if (fa == null)
            Text(l.noReadings, style: TextStyle(color: hint))
          else
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          _fmtFree(fa.freeNh3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: fa.zone.colorOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('ppm', style: TextStyle(color: hint)),
                    ],
                  ),
                ),
                if (fa.inputsOutdated) _outdatedIcon(context),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            fa == null
                ? '—'
                : '${l.freeAmmoniaPercent(formatLocaleNumber(fa.fractionPercent, 0))} · ${relativeTimeLabel(l, fa.at)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: hint),
          ),
        ],
      ),
    );
  }
}

/// The 6 px toxicity track: full-width [ReefTokens.track], the safe (green)
/// segment as the ideal [ReefTokens.band], and a 10 px ringed marker at the
/// value's position on [kFreeAmmoniaAxis]. Mirrors the ratio track, but the
/// scale is one-sided from 0 (safe) → red.
class _FreeAmmoniaTrack extends StatelessWidget {
  const _FreeAmmoniaTrack({required this.value, required this.markerColor});

  final double value;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    const axis = kFreeAmmoniaAxis;
    final green = zoneBands(kFreeAmmoniaBounds, axis.min, axis.max)
        .where((b) => b.zone == Zone.green)
        .toList();

    double fraction(double v) =>
        ((v - axis.min) / (axis.max - axis.min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 2,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (green.isNotEmpty)
                Positioned(
                  left: fraction(green.first.y1) * w,
                  width:
                      (fraction(green.first.y2) - fraction(green.first.y1)) * w,
                  top: 2,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.band,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Positioned(
                left: (fraction(value) * w - 5).clamp(0.0, w - 10),
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: markerColor,
                    border: Border.all(color: tokens.markerRing, width: 2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Explains the free-ammonia estimate for [fa] in a dialog: the chemistry, the
/// computed split, the inputs it used, and the staleness warning when the
/// pH/temperature inputs are outdated.
Future<void> showFreeAmmoniaInfo(
  BuildContext context,
  FreeAmmonia fa,
  UnitPrefs prefs,
) {
  final l = AppLocalizations.of(context);
  final tokens = ReefTokens.of(context);
  final inputs = _inputStrings(fa, prefs);
  final salinity = fa.salinityMeasured
      ? inputs.salinity
      : l.freeAmmoniaSalinityAssumed(inputs.salinity);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.freeAmmoniaLabel),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.freeAmmoniaExplain),
            const SizedBox(height: 16),
            Text(
              l.freeAmmoniaDialogFree(_fmtFree(fa.freeNh3)),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: fa.zone.colorOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.freeAmmoniaDialogFraction(
                formatLocaleNumber(fa.fractionPercent, 1),
                formatLocaleNumber(fa.total, 2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.freeAmmoniaDialogInputs(
                formatLocaleNumber(fa.pH, 2),
                inputs.temp,
                salinity,
              ),
              style: TextStyle(color: tokens.textDim),
            ),
            if (fa.inputsOutdated) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: tokens.caution,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.freeAmmoniaOutdatedWarning,
                      style: TextStyle(color: tokens.caution),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    ),
  );
}
