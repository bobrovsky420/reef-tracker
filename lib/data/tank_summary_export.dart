import '../domain/dose_calculator.dart';
import '../domain/health_score.dart';
import '../domain/insights.dart';
import '../domain/micro.dart';
import '../domain/parameter_catalog.dart';
import '../domain/setup_type.dart';
import '../domain/stability_score.dart';
import '../domain/supplement_catalog.dart';
import '../domain/trend.dart';
import '../domain/units.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'database.dart';
import 'settings.dart';

/// "Ask your AI" tank summary export (U27): renders the active tank's recent
/// state as a markdown document the user pastes into their own AI chat
/// (ChatGPT/Claude/…). The app does the data-assembly half; the user's AI
/// does the inference half — zero network, zero inference cost, fully
/// offline.
///
/// Split like the CSV export (U3): an async [collectTankSummary] that
/// gathers one-shot snapshots from the DB and re-runs the domain math
/// (health, stability, trends, U28 insights — the same pure functions the
/// providers use), and a synchronous [encodeTankSummary] that renders it.
/// Unlike the CSV export there is deliberately **no `Isolate.run`**: the
/// document is windowed and capped, so encoding is microseconds (T5 applied
/// only to the unbounded full-history export).
///
/// The encoder takes [AppLocalizations] directly (a plain class, usable
/// off-context) so the document localizes through the normal ARB pipeline —
/// display names read naturally in the user's language, with the stable
/// catalog key in parens so the text stays machine-anchored. Dates are ISO
/// `yyyy-MM-dd` (locale-proof for the reading AI); numbers use the locale's
/// decimal separator like everywhere else in the app.

/// Per-parameter cap on the history table. Caps are announced in the
/// document ("showing N of M"), never silent. (The window choices —
/// [kAiSummaryWeekChoices] — live in `settings.dart` with their decoder.)
const int kAiSummaryMaxRowsPerParam = 20;

/// Matches `kRecentReadingsPerParam` (app layer): the bounded head used for
/// latest values, health, trends and insights — same feed the dashboard uses.
const int _kRecentPerParam = 40;

/// One core parameter's slice of the summary.
typedef SummaryParam = ({
  TrackedParameter param,
  Reading? latest,

  /// Window-filtered readings, newest first.
  List<Reading> windowed,
  TrendResult? trend,
});

/// One micro element's latest measurement (the panel semantics — deliberately
/// not "the latest ICP group": a lone hobby-kit retest would make group
/// membership misleading).
typedef SummaryMicro = ({
  String paramKey,
  TrackedParameter? row,
  Reading latest,
});

/// Everything [encodeTankSummary] needs, pre-assembled.
class TankSummaryData {
  const TankSummaryData({
    required this.tank,
    required this.weeks,
    required this.exportedAt,
    required this.params,
    required this.health,
    required this.stability,
    required this.stabilityWindowDays,
    required this.insights,
    required this.dosingActive,
    required this.manualDoses,
    required this.waterChanges,
    required this.carbonChanges,
    required this.equipmentCleanings,
    required this.micro,
  });

  final Tank tank;
  final int weeks;
  final DateTime exportedAt;
  final List<SummaryParam> params;
  final TankHealth health;
  final TankStability stability;
  final int stabilityWindowDays;
  final List<Insight> insights;
  final List<DosingEntry> dosingActive;
  final List<ManualDose> manualDoses;
  final List<WaterChange> waterChanges;
  final List<CarbonChange> carbonChanges;
  final List<EquipmentCleaning> equipmentCleanings;
  final List<SummaryMicro> micro;
}

/// Assembles the summary snapshot for [tankId] over the last [weeks] weeks,
/// or null when the tank doesn't exist or has no readings at all (nothing to
/// summarize). One-shot `.first` reads on the existing live queries — no new
/// DB surface.
Future<TankSummaryData?> collectTankSummary(
  AppDatabase db, {
  required int tankId,
  required int weeks,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final cutoff = clock.subtract(Duration(days: weeks * 7));

  Tank? tank;
  for (final t in await db.getTanks()) {
    if (t.id == tankId) tank = t;
  }
  if (tank == null) return null;

  final recent = await db.getRecentReadingsPerParam(tankId, _kRecentPerParam);
  if (recent.isEmpty) return null;

  final tracked = await db.getTrackedParameters(tankId);
  final settings = {for (final s in await db.getAllSettings()) s.key: s.value};
  String? raw(SettingKey k) => settings[k.storageKey];
  final trendEnabled = AppSettings.decodeTrendEnabled(
    raw(SettingKey.trendEnabled),
  );
  final trendWindow = AppSettings.decodeTrendWindow(
    raw(SettingKey.trendWindow),
  );
  final stabilityWindowDays = AppSettings.decodeStabilityWindow(
    raw(SettingKey.stabilityWindow),
  );

  final windowed = await db.getReadingsSince(tankId, cutoff);
  final stabilityReadings = await db.getReadingsSince(
    tankId,
    clock.subtract(Duration(days: stabilityWindowDays)),
  );

  // Latest per parameter (recent arrives newest-first) and oldest-first
  // series — the same groupings the dashboard providers build.
  final latest = <String, Reading>{};
  for (final r in recent) {
    latest.putIfAbsent(r.paramKey, () => r);
  }
  final recentSeries = <String, List<DosePoint>>{};
  for (final r in recent.reversed) {
    (recentSeries[r.paramKey] ??= []).add((t: r.takenAt, value: r.value));
  }
  final windowedByParam = <String, List<Reading>>{};
  for (final r in windowed) {
    (windowedByParam[r.paramKey] ??= []).add(r);
  }
  final stabilitySeries = <String, List<DosePoint>>{};
  for (final r in stabilityReadings) {
    (stabilitySeries[r.paramKey] ??= []).add((t: r.takenAt, value: r.value));
  }

  final core = tracked
      .where((t) => t.enabled && isCoreParam(t.paramKey))
      .toList();
  final bounds = {for (final p in core) p.paramKey: boundsOf(p)};

  final trends = <String, TrendResult>{};
  if (trendEnabled) {
    for (final p in core) {
      final pts = recentSeries[p.paramKey];
      if (pts == null) continue;
      final t = computeTrend(
        points: pts,
        bounds: bounds[p.paramKey]!,
        window: trendWindow,
      );
      if (t != null) trends[p.paramKey] = t;
    }
  }

  final health = computeTankHealth([
    for (final p in core)
      (
        paramKey: p.paramKey,
        bounds: bounds[p.paramKey]!,
        latest: latest[p.paramKey]?.value,
        takenAt: latest[p.paramKey]?.takenAt,
      ),
  ], now: clock);

  final stability = computeTankStability(
    [
      for (final p in core)
        (
          paramKey: p.paramKey,
          bounds: bounds[p.paramKey]!,
          points: stabilitySeries[p.paramKey] ?? const [],
        ),
    ],
    now: clock,
    windowDays: stabilityWindowDays,
  );

  final insights = computeInsights(
    health: health,
    trends: trends,
    bounds: bounds,
    horizonDays: AppSettings.decodeTrendHorizon(raw(SettingKey.trendHorizon)),
    now: clock,
  );

  // Micro elements: latest value per measured element, catalog (ICP report)
  // order. Included regardless of the window — the newest ICP is the newest
  // there is; each row carries its own date.
  final rowByKey = {for (final t in tracked) t.paramKey: t};
  final micro = <SummaryMicro>[
    for (final def in kMicroParameters)
      if (latest[def.key] case final r?)
        (paramKey: def.key, row: rowByKey[def.key], latest: r),
  ];

  bool inWindow(DateTime t) => !t.isBefore(cutoff);
  final manualDoses = (await db.getManualDoses(
    tankId,
  )).where((d) => inWindow(d.dosedAt)).toList();
  final waterChanges = (await db.getWaterChanges(
    tankId,
  )).where((w) => inWindow(w.changedAt)).toList();
  final carbonChanges = (await db.getCarbonChanges(
    tankId,
  )).where((c) => inWindow(c.changedAt)).toList();
  final cleanings = (await db.getEquipmentCleanings(
    tankId,
  )).where((c) => inWindow(c.cleanedAt)).toList();

  return TankSummaryData(
    tank: tank,
    weeks: weeks,
    exportedAt: clock,
    params: [
      for (final p in core)
        (
          param: p,
          latest: latest[p.paramKey],
          windowed: (windowedByParam[p.paramKey] ?? const [])
              .where((r) => inWindow(r.takenAt))
              .toList()
              .reversed
              .toList(),
          trend: trends[p.paramKey],
        ),
    ],
    health: health,
    stability: stability,
    stabilityWindowDays: stabilityWindowDays,
    insights: insights,
    dosingActive: await db.getDosingEntries(tankId),
    manualDoses: manualDoses,
    waterChanges: waterChanges,
    carbonChanges: carbonChanges,
    equipmentCleanings: cleanings,
    micro: micro,
  );
}

/// ISO `yyyy-MM-dd`, locale-independent (the CSV export's `_timestamp`
/// rationale, date-only).
String _date(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}';
}

/// A markdown-table-safe cell: pipes escaped, line breaks flattened.
String _cell(String s) =>
    s.replaceAll('|', r'\|').replaceAll(RegExp(r'[\r\n]+'), ' ');

/// Rounds a positive day estimate like the trend chips: whole days, >= 1.
int _days(double v) {
  final r = v.round();
  return r < 1 ? 1 : r;
}

/// "lo–hi", or "≥ lo" / "≤ hi" for one-sided bounds; null when both absent.
String? _range(ParamPresentation pres, double? lo, double? hi) {
  String f(double v) => pres.format(v);
  if (lo != null && hi != null) return '${f(lo)}–${f(hi)}';
  if (lo != null) return '≥ ${f(lo)}';
  if (hi != null) return '≤ ${f(hi)}';
  return null;
}

/// Renders [data] as the shareable markdown document.
///
/// [includeStability] / [includeInsights] carry the caller's Pro
/// entitlements (U26 stability score, U28 smart insights): the exported
/// document is *presentation*, so gated computed layers must not leak into a
/// Standard-tier export the in-app teaser hides. The collector stays
/// entitlement-unaware (the U26 split) — only the rendering skips them.
/// Required (not defaulted) so no caller can forget the gate.
String encodeTankSummary(
  TankSummaryData data, {
  required AppLocalizations l,
  required UnitPrefs prefs,
  required bool includeStability,
  required bool includeInsights,
}) {
  final buf = StringBuffer();
  final tank = data.tank;

  // --- Preamble + title ------------------------------------------------------
  buf
    ..writeln(l.aiSummaryPreamble(data.weeks))
    ..writeln()
    ..writeln('# ${l.aiSummaryDocTitle(tank.name)}');

  final profile = <String>[
    l.setupLabel(SetupType.fromName(tank.setupType)),
    if (tank.volumeLiters case final v?) l.volumeWithUnit(v, prefs.volume),
    if (tank.startDate case final d?) l.aiSummaryRunningSince(_date(d)),
  ];
  buf
    ..writeln(
      '${profile.join(', ')}. '
      '${l.aiSummaryExportedLine(_date(data.exportedAt))}',
    )
    ..writeln();

  // --- Status ----------------------------------------------------------------
  final statusLines = <String>[
    if (data.health.hasData)
      '- ${l.aiSummaryHealthLine(data.health.score!, l.healthGradeLabel(data.health.grade))}',
    if (includeStability && data.stability.hasData)
      '- ${l.aiSummaryStabilityLine(data.stability.score!, l.stabilityGradeLabel(data.stability.grade), data.stabilityWindowDays)}',
  ];
  final withInsights = includeInsights && data.insights.isNotEmpty;
  if (statusLines.isNotEmpty || withInsights) {
    buf.writeln('## ${l.aiSummaryStatusHeading}');
    statusLines.forEach(buf.writeln);
    if (withInsights) {
      buf.writeln('- ${l.aiSummaryObservationsLead}');
      for (final i in data.insights) {
        buf.writeln('  - ${l.insightLabel(i)}');
      }
    }
    buf.writeln();
  }

  // --- Parameters ------------------------------------------------------------
  final withReadings = data.params.where((p) => p.latest != null).toList();
  if (withReadings.isNotEmpty) {
    buf.writeln('## ${l.aiSummaryParamsHeading}');
    for (final p in withReadings) {
      final pres = presentationOf(p.param, prefs);
      final b = boundsOf(p.param);
      final latest = p.latest!;
      buf
        ..writeln()
        ..writeln('### ${l.paramName(p.param.paramKey)} (${p.param.paramKey})');

      final zone = b.classify(latest.value);
      final ranges = <String>[
        if (_range(pres, b.greenLow, b.greenHigh) case final g?)
          l.aiSummaryTargetRange(g),
        if (_range(pres, b.amberLow, b.amberHigh) case final a?)
          l.aiSummaryAcceptableRange(a),
      ];
      buf.writeln(
        '${pres.format(latest.value)} ${pres.unitLabel} — '
        '${l.zoneLabel(zone).toLowerCase()}, '
        '${l.aiSummaryTestedOn(_date(latest.takenAt))}.'
        '${ranges.isEmpty ? '' : ' ${ranges.join('; ')}.'}',
      );

      if (p.trend case final t?) {
        // Signed rate in display units: the conversion is affine, so the
        // per-day delta is toDisplay(slope) − toDisplay(0) (trend_view.dart).
        final disp = pres.toDisplay(t.slopePerDay) - pres.toDisplay(0);
        final rate = formatLocaleNumber(disp.abs(), pres.decimals);
        final sign = disp > 0 ? '+' : (disp < 0 ? '−' : '');
        final parts = <String>[
          l.trendRatePerDay('$sign$rate ${pres.unitLabel}'),
          if (t.daysToGreen case final d?) l.trendBackInRangeDays(_days(d)),
          if (t.daysToAmber case final d?) l.trendAmberInDays(_days(d)),
          if (t.daysToRed case final d?) l.trendRedInDays(_days(d)),
        ];
        buf.writeln('${parts.join('. ')}.');
      }

      if (p.windowed.isNotEmpty) {
        final shown = p.windowed.take(kAiSummaryMaxRowsPerParam).toList();
        buf
          ..writeln(
            '| ${l.aiSummaryColDate} | ${l.aiSummaryColValue} '
            '(${pres.unitLabel}) | ${l.aiSummaryColNote} |',
          )
          ..writeln('|---|---|---|');
        for (final r in shown) {
          buf.writeln(
            '| ${_date(r.takenAt)} | ${pres.format(r.value)} '
            '| ${_cell(r.note ?? '')} |',
          );
        }
        if (p.windowed.length > shown.length) {
          buf.writeln(l.aiSummaryShowingTests(shown.length, p.windowed.length));
        }
      }
    }
    buf.writeln();
  }

  // --- Dosing ----------------------------------------------------------------
  if (data.dosingActive.isNotEmpty || data.manualDoses.isNotEmpty) {
    buf.writeln('## ${l.aiSummaryDosingHeading}');
    for (final e in data.dosingActive) {
      final unit = DoseUnit.fromName(e.amountUnit);
      final daily = dailyEquivalentDose(e.schedule);
      final parts = <String>[
        if (e.amount case final a?)
          '${formatLocaleNumberTrim(a)} ${unit.symbol} '
              '${DoseBasis.fromName(e.basis) == DoseBasis.perDose ? l.dosingPerDose : l.dosingPerDay}',
        switch (DoseFrequency.fromName(e.frequency)) {
          DoseFrequency.daily => l.dosingFreqDaily,
          DoseFrequency.everyNDays => l.dosingEveryDaysN(e.intervalDays ?? 0),
          _ => '',
        },
        if (daily > 0)
          l.aiSummaryDailyEquivalent(
            '${formatLocaleNumberTrim(daily)} ${unit.symbol}',
          ),
        if (e.startedAt case final d?) l.aiSummarySinceDate(_date(d)),
      ].where((s) => s.isNotEmpty).toList();
      final element = e.elementKey != null
          ? ' — ${l.paramName(e.elementKey!)}'
          : '';
      buf.writeln('- ${e.product}$element: ${parts.join(', ')}');
    }
    for (final d in data.manualDoses) {
      final unit = DoseUnit.fromName(d.amountUnit);
      buf.writeln(
        '- ${_date(d.dosedAt)}: ${l.aiSummaryOneOff} — ${d.product}, '
        '${formatLocaleNumberTrim(d.amount)} ${unit.symbol}',
      );
    }
    buf.writeln();
  }

  // --- Maintenance in the window ----------------------------------------------
  String note(String? n) => n == null || n.isEmpty ? '' : ' · ${_cell(n)}';
  String waterAmount(double? liters) {
    if (liters == null) return '';
    var s = ' — ${l.volumeWithUnit(liters, prefs.volume)}';
    final v = tank.volumeLiters;
    if (v != null && v > 0) {
      s = '$s (${formatLocaleNumber(liters / v * 100, 0)} %)';
    }
    return s;
  }

  final actions = <({DateTime at, String line})>[
    for (final w in data.waterChanges)
      (
        at: w.changedAt,
        line: '${l.waterChange}${waterAmount(w.amountLiters)}${note(w.note)}',
      ),
    for (final c in data.carbonChanges)
      (
        at: c.changedAt,
        line:
            '${l.carbonChange}'
            '${c.grams == null ? '' : ' — ${l.gramsSuffix(formatLocaleNumberTrim(c.grams!))}'}'
            '${note(c.note)}',
      ),
    for (final c in data.equipmentCleanings)
      (at: c.cleanedAt, line: '${l.equipmentCleaning}${note(c.note)}'),
  ]..sort((a, b) => b.at.compareTo(a.at));
  if (actions.isNotEmpty) {
    buf.writeln('## ${l.aiSummaryActionsHeading}');
    for (final a in actions) {
      buf.writeln('- ${_date(a.at)}: ${a.line}');
    }
    buf.writeln();
  }

  // --- Trace elements ----------------------------------------------------------
  if (data.micro.isNotEmpty) {
    buf
      ..writeln('## ${l.aiSummaryMicroHeading}')
      ..writeln(
        '| ${l.aiSummaryColElement} | ${l.aiSummaryColValue} '
        '| ${l.aiSummaryColStatus} | ${l.aiSummaryColDate} |',
      )
      ..writeln('|---|---|---|---|');
    for (final m in data.micro) {
      final pres = presentationForKey(
        m.paramKey,
        m.row?.unit ?? kParameterByKey[m.paramKey]?.unit ?? '',
        prefs,
      );
      final bounds = switch (m.row) {
        final row? => boundsOf(row),
        null => microDefaultBounds(m.paramKey),
      };
      final zone = bounds.classify(m.latest.value);
      buf.writeln(
        '| ${l.paramName(m.paramKey)} (${m.paramKey}) '
        '| ${pres.format(m.latest.value)} ${pres.unitLabel} '
        '| ${l.zoneLabel(zone).toLowerCase()} '
        '| ${_date(m.latest.takenAt)} |',
      );
    }
  }

  return '${buf.toString().trimRight()}\n';
}
