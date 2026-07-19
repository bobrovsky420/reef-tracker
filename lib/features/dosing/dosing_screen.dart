import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/zone_visuals.dart';

/// The Dosing tab body: the active tank's information-only supplement-dosing
/// plan, newest/ordered first, with tap-to-edit and swipe-to-delete. Hosted by
/// `HomeShell`, which owns the scaffold, app bar, bottom nav and the
/// add-supplement FAB.
///
/// Layout per REDESIGN #13: the entries collapse into one `ReefSliverCard` of
/// hairline-divided rows (flask icon, title + element tag, "vendor · program"
/// sub, mono dose line, drag handle); the element tag is colored by the
/// target element's *live zone* ([dosingElementZonesProvider]).
class DosingBody extends ConsumerWidget {
  const DosingBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(dosingEntriesProvider).value ?? const [];

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l.noDosing,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l.noDosingHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final zones = ref.watch(dosingElementZonesProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          // The bottom inset keeps the last row scrollable past the
          // translucent tab bar (`extendBody` — a CustomScrollView gets no
          // automatic MediaQuery inset).
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: ReefSliverCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            sliver: SliverReorderableList(
              itemCount: entries.length,
              onReorderItem: (oldIndex, newIndex) {
                final reordered = [...entries];
                reordered.insert(newIndex, reordered.removeAt(oldIndex));
                unawaited(
                  ref.read(dbProvider).reorderDosingEntries([
                    for (final e in reordered) e.id,
                  ]),
                );
              },
              // The dragged row leaves the card, so give it an opaque lifted
              // surface (the dark-theme card fill is translucent — rows
              // underneath would show through the bare row).
              proxyDecorator: (child, index, animation) => Material(
                elevation: 3,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (context, i) => _row(
                context,
                ref,
                l,
                entries[i],
                i,
                zones,
                isLast: i == entries.length - 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    DosingEntry e,
    int index,
    Map<String, Zone> zones, {
    required bool isLast,
  }) {
    // Resolve vendor/program/product live from the catalog (via productKey),
    // falling back to the stored snapshot for custom/orphaned entries.
    final names = resolveSupplementNames(
      productKey: e.productKey,
      storedVendor: e.vendor,
      storedProgram: e.program,
      storedProduct: e.product,
    );
    final source = [
      names.vendor,
      names.program,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    final detail = dosingDetailLine(context, l, e);
    final tokens = ReefTokens.of(context);

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.stop_circle_outlined,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) => stopDosingWithUndo(context, ref, e),
      // The rows sit inside the sliver card, whose fill paints over the
      // scaffold Material — each row brings a transparent Material so its ink
      // ripples above the card.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.push('/dosing/edit', extra: e),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.surfaceBorder),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: tokens.textDim,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              names.product,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: tokens.text,
                              ),
                            ),
                          ),
                          if (e.elementKey != null) ...[
                            const SizedBox(width: 8),
                            _ElementTag(
                              label: l.paramName(e.elementKey!),
                              zone: zones[e.elementKey!] ?? Zone.unknown,
                            ),
                          ],
                        ],
                      ),
                      if (source.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          source,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.textDim,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: ReefTokens.monoTextStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ReorderableDragStartListener(
                  index: index,
                  // The padding keeps the 16 px glyph draggable with a finger.
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: tokens.textFaint,
                      semanticLabel: l.reorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stops the supplement immediately and shows an "Undo" SnackBar that writes
/// the captured pre-stop row back (U10 — no confirm dialog: the stop is a
/// soft state change and cheap to restore, so it follows the readings/actions
/// undo pattern). Shared by the swipe gesture on the Dosing tab and the edit
/// screen's Stop button — the latter is the accessible, non-swipe path (#45)
/// and pops right after; `ScaffoldMessenger.of` resolves to the app-level
/// messenger, so the SnackBar survives the pop. Returns true (the row should
/// dismiss).
Future<bool> stopDosingWithUndo(
  BuildContext context,
  WidgetRef ref,
  DosingEntry e,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  await db.stopDosingEntry(e.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.supplementStopped),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => db.restoreDosingEntry(e),
        ),
      ),
    );
  return true;
}

/// Builds the localized "dosage • schedule" summary for an entry, falling back
/// to "No dosage set" when neither dosage nor schedule is recorded.
String dosingDetailLine(
  BuildContext context,
  AppLocalizations l,
  DosingEntry e,
) {
  final parts = <String>[];

  if (e.amount != null) {
    final unit = DoseUnit.fromName(e.amountUnit);
    var amount = '${formatDoseAmount(e.amount!)} ${unit.symbol}';
    final basis = DoseBasis.fromName(e.basis);
    if (basis == DoseBasis.perDay) amount = '$amount ${l.dosingPerDay}';
    if (basis == DoseBasis.perDose) amount = '$amount ${l.dosingPerDose}';
    parts.add(amount);
  }

  final freq = DoseFrequency.fromName(e.frequency);
  switch (freq) {
    case DoseFrequency.daily:
      parts.add(l.dosingFreqDaily);
    case DoseFrequency.everyNDays:
      parts.add(l.dosingEveryDaysN(e.intervalDays ?? 0));
    case DoseFrequency.weekly:
      final days = parseWeekdays(e.weekdays);
      if (days.isNotEmpty) parts.add(formatWeekdays(context, days));
    case null:
      break;
  }

  if (e.doseTime != null && e.doseTime!.isNotEmpty) {
    parts.add(formatDoseTime(context, e.doseTime!));
  }

  if (parts.isEmpty) return l.dosingNoDosage;
  return parts.join(' · ');
}

/// Formats a dose amount without a trailing zero fraction, using the active
/// locale's decimal separator (e.g. `5`, `2.5`, cs/de `2,5`).
String formatDoseAmount(double v) => formatLocaleNumberTrim(v);

/// Parses the stored comma-separated weekday list (1=Mon … 7=Sun).
List<int> parseWeekdays(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final days =
      raw
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .toList()
        ..sort();
  return days;
}

/// Renders a stored `HH:mm` time using the device's 12/24-hour preference.
String formatDoseTime(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
}

/// The element tag on a dosing row, colored by the element's live zone
/// (REDESIGN #13): soft zone fill + solid zone text. [Zone.unknown] is the
/// neutral tag (`track` fill, `textDim` text) — no fresh reading, no usable
/// bounds, or an ICP-cadence element whose last sample is naturally stale.
class _ElementTag extends StatelessWidget {
  const _ElementTag({required this.label, required this.zone});

  final String label;
  final Zone zone;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: zone.softColorOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: zone == Zone.unknown
              ? tokens.textDim
              : zone.colorOf(context),
        ),
      ),
    );
  }
}
