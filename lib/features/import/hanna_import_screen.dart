import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/hanna_import.dart';
import '../../domain/parameter_catalog.dart';
import '../../domain/setup_type.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/reef_card.dart';
import '../../widgets/reef_settings.dart';
import '../../widgets/reef_sheet.dart';
import '../../widgets/reef_value_row.dart';
import '../../widgets/section_header.dart';

/// Preview + confirm step of the Hanna Lab import (U32). Shows what the file
/// would add to the chosen tank — new readings grouped into test sessions,
/// already-imported and skipped rows accounted for — and on confirm inserts
/// the sessions as reading groups, advances the (tank, source) watermark and
/// remembers the `Sample Location` → tank mapping.
class HannaImportScreen extends ConsumerStatefulWidget {
  const HannaImportScreen({super.key, required this.result});

  final HannaImportResult result;

  @override
  ConsumerState<HannaImportScreen> createState() => _HannaImportScreenState();
}

class _HannaImportScreenState extends ConsumerState<HannaImportScreen> {
  /// All import-source rows, loaded once — the location → tank mapping and
  /// the selected tank's watermark both come from here.
  List<ImportSource>? _sources;

  /// The user's explicit tank choice; null = resolve from mapping/active.
  int? _tankIdOverride;

  /// First-import start date; null = the full history.
  DateTime? _cutoff;

  bool _saving = false;

  /// Rewind-diff support: existing readings of the selected tank, memoized
  /// per tank so switching tanks reloads.
  Future<Set<String>>? _existingFuture;
  int? _existingTankId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSources());
  }

  Future<void> _loadSources() async {
    final sources = await ref.read(dbProvider).getAllImportSources();
    if (mounted) setState(() => _sources = sources);
  }

  ImportSource? _rowFor(int tankId) {
    for (final s in _sources ?? const <ImportSource>[]) {
      if (s.tankId == tankId && s.source == kHannaImportSource) return s;
    }
    return null;
  }

  /// The tank whose location mapping matches the file, if any.
  int? _mappedTankId() {
    final loc = widget.result.location;
    if (loc == null) return null;
    for (final s in _sources ?? const <ImportSource>[]) {
      if (s.source == kHannaImportSource && s.location == loc) return s.tankId;
    }
    return null;
  }

  Tank _resolveTank(List<Tank> tanks) {
    for (final id in [_tankIdOverride, _mappedTankId()]) {
      if (id == null) continue;
      for (final t in tanks) {
        if (t.id == id) return t;
      }
    }
    return ref.read(activeTankProvider) ?? tanks.first;
  }

  Future<Set<String>> _existingFor(int tankId, ImportSource? row) {
    if (_existingFuture == null || _existingTankId != tankId) {
      _existingTankId = tankId;
      final since =
          row?.importedUpTo ??
          _cutoff ??
          DateTime.fromMillisecondsSinceEpoch(0);
      _existingFuture = ref
          .read(dbProvider)
          .getReadingsSince(tankId, since)
          .then(
            (rows) => {
              for (final r in rows) hannaReadingKey(r.paramKey, r.takenAt),
            },
          );
    }
    return _existingFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tanks = ref.watch(tanksProvider).value ?? const [];
    if (_sources == null || tanks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.hannaImportTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final tank = _resolveTank(tanks);
    final row = _rowFor(tank.id);
    if (row?.rewound ?? false) {
      // The settings rewind/reset one-shot: the watermark alone would
      // duplicate the re-covered range, so candidates diff against the
      // tank's existing readings first.
      return FutureBuilder<Set<String>>(
        future: _existingFor(tank.id, row),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return Scaffold(
              appBar: AppBar(title: Text(l.hannaImportTitle)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return _body(l, tanks, tank, row, snap.data!);
        },
      );
    }
    return _body(l, tanks, tank, row, const {});
  }

  Widget _body(
    AppLocalizations l,
    List<Tank> tanks,
    Tank tank,
    ImportSource? row,
    Set<String> existingKeys,
  ) {
    final prefs = ref.watch(unitPrefsProvider);
    final tokens = ReefTokens.of(context);
    final result = widget.result;
    final firstImport = row?.importedUpTo == null;

    final plan = planHannaImport(
      rows: result.rows,
      importedUpTo: row?.importedUpTo,
      cutoff: firstImport ? _cutoff : null,
      rewound: row?.rewound ?? false,
      existingKeys: existingKeys,
    );
    // The manual-entry sanity gate (#31) at bulk scale: impossible values are
    // skipped outright, implausible ones import behind one batch confirm.
    final importable = <HannaReading>[];
    final implausible = <HannaReading>{};
    final impossible = <HannaReading>[];
    for (final r in plan.newRows) {
      switch (checkParamValue(r.paramKey, r.value)) {
        case ParamValueCheck.impossible:
          impossible.add(r);
        case ParamValueCheck.implausible:
          implausible.add(r);
          importable.add(r);
        case ParamValueCheck.ok:
          importable.add(r);
      }
    }
    final sessions = hannaSessions(importable).reversed.toList();

    // Skipped rows aggregate to "label — reason ×n": a long history repeats
    // the same under-range failure many times.
    final skippedCounts = <(String, String), int>{};
    for (final s in result.skipped) {
      final reason = switch (s.reason) {
        HannaSkipReason.outOfRange => l.hannaImportSkipRange,
        HannaSkipReason.unknownTest => l.hannaImportSkipUnknown,
        HannaSkipReason.badValue => l.hannaImportSkipValue,
      };
      skippedCounts.update((s.label, reason), (n) => n + 1, ifAbsent: () => 1);
    }
    for (final r in impossible) {
      skippedCounts.update(
        (l.paramName(r.paramKey), l.hannaImportSkipValue),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }

    final header = <Widget>[
      ReefCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const ReefIconChip(Icons.science_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                [
                  if (result.meter != null) result.meter!,
                  if (result.location != null) '“${result.location}”',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ReefCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.hannaImportIntoTank,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
            ),
            ReefSettingsDropdown<int>(
              value: tank.id,
              enabled: !_saving,
              items: [for (final t in tanks) (t.id, t.name)],
              onChanged: (id) => setState(() {
                _tankIdOverride = id;
                // Tank-scoped caches restart with the new target.
                _cutoff = null;
                _existingFuture = null;
              }),
            ),
          ],
        ),
      ),
      if (firstImport) ...[
        const SizedBox(height: 12),
        ReefCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: ReefValueRow(
            leading: const ReefIconChip(Icons.history),
            value: _cutoff == null
                ? l.hannaImportEverything
                : formatDate(_cutoff!),
            valueStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.text,
            ),
            actions: [
              if (_cutoff != null)
                ReefInlineButton(
                  l.hannaImportEverything,
                  onPressed: () => setState(() {
                    _cutoff = null;
                    _existingFuture = null;
                  }),
                ),
              ReefInlineButton(l.change, onPressed: _pickCutoff),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            '${l.hannaImportFirstFrom} — ${l.hannaImportFirstFromHint}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
      if (plan.alreadyImported > 0 || plan.beforeCutoff > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            [
              if (plan.alreadyImported > 0)
                l.hannaImportAlreadyCount(plan.alreadyImported),
              if (plan.beforeCutoff > 0)
                l.hannaImportBeforeCutoffCount(plan.beforeCutoff),
            ].join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
          ),
        ),
      if (importable.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
          child: Text(
            l.hannaImportUpToDate,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.textDim),
          ),
        )
      else
        SectionHeader(l.hannaImportNewCount(importable.length)),
    ];

    final footer = <Widget>[
      if (skippedCounts.isNotEmpty) ...[
        SectionHeader(l.hannaImportSkippedTitle),
        ReefCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in skippedCounts.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${e.key.$1} — ${e.key.$2}'
                    '${e.value > 1 ? ' ×${e.value}' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.textDim),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      if (importable.isNotEmpty)
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () => _import(tank, row, sessions, implausible),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_done),
          label: Text(l.hannaImportButton(importable.length)),
        ),
      const SizedBox(height: 16),
    ];

    // Sessions render lazily — a full-history first import can carry months
    // of them.
    return Scaffold(
      appBar: AppBar(title: Text(l.hannaImportTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: header,
            );
          }
          if (i == sessions.length + 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: footer,
            );
          }
          return _sessionCard(sessions[i - 1], prefs, implausible);
        },
      ),
    );
  }

  /// One test session as a card: the session's start stamp, then hairline
  /// value rows — the same recipe as the ICP preview's section cards.
  Widget _sessionCard(
    List<HannaReading> session,
    UnitPrefs prefs,
    Set<HannaReading> implausible,
  ) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ReefCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDateTime(context, session.first.takenAt, weekday: false),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (var i = 0; i < session.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: i == session.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: tokens.surfaceBorder),
                        ),
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.paramName(session[i].paramKey),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.text,
                        ),
                      ),
                    ),
                    if (implausible.contains(session[i]))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: tokens.caution,
                        ),
                      ),
                    Text(
                      _format(session[i], prefs),
                      style: ReefTokens.monoTextStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.text,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(HannaReading r, UnitPrefs prefs) {
    final def = kParameterByKey[r.paramKey];
    final pres = presentationForKey(r.paramKey, def?.unit ?? '', prefs);
    return '${pres.format(r.value)} ${pres.unitLabel}';
  }

  Future<void> _pickCutoff() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cutoff ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _cutoff = picked;
      _existingFuture = null;
    });
  }

  Future<void> _import(
    Tank tank,
    ImportSource? prior,
    List<List<HannaReading>> sessions,
    Set<HannaReading> implausible,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final result = widget.result;

    // Wrong-file guard: this location was previously imported into a
    // different tank.
    final mapped = _mappedTankId();
    if (mapped != null && mapped != tank.id) {
      final tanks = ref.read(tanksProvider).value ?? const [];
      final mappedName = [
        for (final t in tanks)
          if (t.id == mapped) t.name,
      ].firstOrNull;
      if (mappedName != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.hannaImportWrongTankTitle),
            content: Text(
              l.hannaImportWrongTankBody(
                result.location!,
                mappedName,
                tank.name,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.icpImportAnyway),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    // One batch confirm for every implausible value (#31 at bulk scale) —
    // not the per-value dialogs of manual entry.
    if (implausible.isNotEmpty) {
      final prefs = ref.read(unitPrefsProvider);
      final proceed = await _confirmImplausible(l, implausible, prefs);
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Each parameter needs its tracked row (idempotent, seeds preset
      // bounds), same as the ICP import.
      final type = SetupType.fromName(tank.setupType);
      final keys = {for (final s in sessions) ...s.map((r) => r.paramKey)};
      for (final key in keys) {
        await db.addTrackedParameter(tank.id, key, type);
      }
      // One group per session, every reading on its own file timestamp.
      final groupIds = <String>[];
      final rows =
          <({String paramKey, double value, DateTime takenAt, String groupId})>[];
      for (final session in sessions) {
        final groupId = newReadingGroupId();
        groupIds.add(groupId);
        for (final r in session) {
          rows.add((
            paramKey: r.paramKey,
            value: r.value,
            takenAt: r.takenAt,
            groupId: groupId,
          ));
        }
      }
      await db.insertImportedReadings(tank.id, rows);

      // Advance the watermark over the WHOLE file — rows excluded by the
      // cutoff are covered-by-choice, and a rewind never moves it backwards.
      var upTo = result.rows.last.takenAt;
      final priorUpTo = prior?.importedUpTo;
      if (priorUpTo != null && priorUpTo.isAfter(upTo)) upTo = priorUpTo;
      await db.upsertImportSource(
        ImportSourcesCompanion.insert(
          tankId: tank.id,
          source: kHannaImportSource,
          location: Value(result.location ?? prior?.location),
          importedUpTo: Value(upTo),
          rewound: const Value(false),
        ),
      );

      if (!mounted) return;
      final undone = await _showResultSheet(l, rows.length);
      if (undone == true) {
        await db.deleteReadingsByGroupIds(tank.id, groupIds);
        if (prior == null) {
          await db.deleteImportSource(tank.id, kHannaImportSource);
        } else {
          await db.upsertImportSource(
            ImportSourcesCompanion.insert(
              tankId: prior.tankId,
              source: prior.source,
              location: Value(prior.location),
              importedUpTo: Value(prior.importedUpTo),
              rewound: Value(prior.rewound),
            ),
          );
        }
        messenger.showSnackBar(SnackBar(content: Text(l.hannaImportUndone)));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Result sheet (not an action SnackBar — its Undo drives DB logic and must
  /// not race an auto-dismiss). Returns true when the user chose Undo.
  Future<bool?> _showResultSheet(AppLocalizations l, int count) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ReefSheetHeader(l.hannaImportDoneCount(count)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.undo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.close),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mirrors the ICP import's implausible-value confirmation.
  Future<bool?> _confirmImplausible(
    AppLocalizations l,
    Set<HannaReading> readings,
    UnitPrefs prefs,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.implausibleTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.implausibleIntro),
              const SizedBox(height: 12),
              for (final r in readings)
                if (kParameterByKey[r.paramKey] case final def?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Builder(
                      builder: (_) {
                        final pres = presentationForKey(
                          def.key,
                          def.unit,
                          prefs,
                        );
                        return Text(
                          l.implausibleValueLine(
                            l.paramName(def.key),
                            '${pres.format(r.value)} ${pres.unitLabel}',
                            pres.format(def.plausibleMin!),
                            '${pres.format(def.plausibleMax!)} ${pres.unitLabel}',
                          ),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAnyway),
          ),
        ],
      ),
    );
  }
}
