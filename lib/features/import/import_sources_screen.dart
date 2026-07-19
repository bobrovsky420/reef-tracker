import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../domain/hanna_import.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_settings.dart';

/// Settings surface of the measurement import (U32): per tank+source, the
/// remembered location mapping and the dedupe watermark, with the two rewind
/// actions — *Change date…* (earlier only) and *Reset* (ask the first-import
/// cutoff question again). Both set the one-shot `rewound` flag so the next
/// import diffs the re-covered range instead of duplicating it.
class ImportSourcesScreen extends ConsumerWidget {
  const ImportSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sources = ref.watch(importSourcesProvider).value ?? const [];
    final tanks = ref.watch(tanksProvider).value ?? const [];
    final tankById = {for (final t in tanks) t.id: t};
    final rows = [
      for (final s in sources)
        if (s.source == kHannaImportSource && tankById.containsKey(s.tankId)) s,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.measurementImportSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // One section per source format; only Hanna Lab exists today. The
          // header is the product's proper noun, deliberately not localized.
          ReefSettingsSection(
            label: 'Hanna Lab',
            children: [
              for (final s in rows)
                ReefSettingsRow(
                  icon: Icons.science_outlined,
                  title: tankById[s.tankId]!.name,
                  description: [
                    if (s.location != null) '“${s.location}”',
                    if (s.importedUpTo case final upTo?)
                      l.hannaImportImportedUpTo(
                        formatDateTime(context, upTo, weekday: false),
                      )
                    else
                      l.hannaImportNeverImported,
                  ].join(' · '),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'change' => _changeDate(context, ref, l, s),
                      _ => _reset(context, ref, l, s),
                    },
                    itemBuilder: (ctx) => [
                      if (s.importedUpTo != null)
                        PopupMenuItem(
                          value: 'change',
                          child: Text(l.hannaImportChangeDate),
                        ),
                      PopupMenuItem(
                        value: 'reset',
                        child: Text(l.hannaImportReset),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rewinds the watermark to an EARLIER date only — moving it forward would
  /// silently swallow future readings, so the picker cannot go past it.
  Future<void> _changeDate(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    ImportSource s,
  ) async {
    final upTo = s.importedUpTo!;
    final picked = await showDatePicker(
      context: context,
      initialDate: upTo,
      firstDate: DateTime(2000),
      lastDate: upTo,
    );
    if (picked == null || !context.mounted) return;
    // Midnight of the chosen day, strict-greater filter: readings ON the day
    // become candidates again.
    await ref
        .read(dbProvider)
        .upsertImportSource(
          ImportSourcesCompanion.insert(
            tankId: s.tankId,
            source: s.source,
            location: Value(s.location),
            importedUpTo: Value(DateTime(picked.year, picked.month, picked.day)),
            rewound: const Value(true),
          ),
        );
  }

  /// Clears the watermark (the next import asks the first-import cutoff
  /// question again); the location → tank mapping is kept.
  Future<void> _reset(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    ImportSource s,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.hannaImportResetTitle),
        content: Text(l.hannaImportResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.hannaImportReset),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    await ref
        .read(dbProvider)
        .upsertImportSource(
          ImportSourcesCompanion.insert(
            tankId: s.tankId,
            source: s.source,
            location: Value(s.location),
            importedUpTo: const Value(null),
            rewound: const Value(true),
          ),
        );
  }
}
