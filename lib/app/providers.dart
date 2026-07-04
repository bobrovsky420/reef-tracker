import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/database.dart';
import '../data/settings.dart';
import '../domain/health_score.dart';
import '../domain/ratio.dart';
import '../domain/trend.dart';
import '../domain/units.dart';

// The settings keys, the [HealthDisplay] enum, and the typed [Settings] facade
// live in `data/settings.dart`. Re-export the symbols widgets reach through this
// file so their imports are unchanged.
export '../data/settings.dart'
    show
        HealthDisplay,
        AppSettings,
        SettingKey,
        kTourSeenKey,
        kChartRangeKey,
        kLocaleKey,
        kTempUnitKey,
        kSalinityUnitKey,
        kVolumeUnitKey,
        kHealthDisplayKey,
        kTrendEnabledKey,
        kTrendWindowKey,
        kTrendHorizonKey;

/// Typed facade over the settings key/value store — the single place that
/// encodes/decodes settings and owns their defaults (see [Settings]).
final settingsProvider = Provider<AppSettings>(
  (ref) => AppSettings(ref.watch(dbProvider)),
);

/// The app's version + build number from the running package (e.g. "0.3.1+4"),
/// so the About box always reflects the actual installed build.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// The singleton app database.
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Drift query streams re-emit a freshly built list on *any* write to a
/// watched table — invalidation is table-level, so a write for another tank
/// (or an unrelated column) re-emits an identical result. The list is a new
/// object each time, and `AsyncData` compares its payload with `==` (identity
/// for lists), so every re-emission would fan out as widget rebuilds. Rows are
/// drift-generated value types, so dropping consecutive equal emissions here
/// stops the fan-out at the source (T2).
Stream<List<T>> _dedup<T>(Stream<List<T>> s) => s.distinct(listEquals);

/// All tanks, reactive.
final tanksProvider = StreamProvider<List<Tank>>(
  (ref) => _dedup(ref.watch(dbProvider).watchTanks()),
);

/// The id of the currently selected tank (persisted in settings).
final activeTankIdProvider = StreamProvider<int?>(
  (ref) => ref.watch(dbProvider).watchActiveTankId(),
);

/// The currently selected tank, resolving the active id against the tank list.
/// Falls back to the first tank when none is explicitly selected.
final activeTankProvider = Provider<Tank?>((ref) {
  final tanks = ref.watch(tanksProvider).value ?? const [];
  if (tanks.isEmpty) return null;
  final activeId = ref.watch(activeTankIdProvider).value;
  for (final t in tanks) {
    if (t.id == activeId) return t;
  }
  return tanks.first;
});

// --- Tank-scoped data --------------------------------------------------------
//
// Each public provider below is a plain `Provider<AsyncValue<...>>` delegating
// to a private autoDispose StreamProvider *family keyed by tank id* (#20).
// Switching the active tank switches to a fresh family instance, so consumers
// briefly see loading/empty instead of the previous tank's rows flashing under
// the new tank's name (a rebuilt non-family StreamProvider keeps its previous
// value while the new stream loads). The wrapper permanently keeps the active
// tank's instance alive (same liveness as before); the previous tank's
// instance loses its only listener and its live query is disposed.

final _trackedParametersFamily = StreamProvider.autoDispose
    .family<List<TrackedParameter>, int>(
      (ref, tankId) =>
          _dedup(ref.watch(dbProvider).watchTrackedParameters(tankId)),
    );

/// Tracked parameters for the active tank.
final trackedParametersProvider = Provider<AsyncValue<List<TrackedParameter>>>((
  ref,
) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_trackedParametersFamily(tank.id));
});

final _tankReadingsFamily = StreamProvider.autoDispose
    .family<List<Reading>, int>(
      (ref, tankId) =>
          _dedup(ref.watch(dbProvider).watchReadingsForTank(tankId)),
    );

/// All readings for the active tank (newest first). This is the *unbounded*
/// full-table stream — its only remaining consumer is the comparison view's
/// charts, so unlike the other tank-scoped wrappers this one is autoDispose:
/// the full query lives only while a chart screen watches it instead of
/// re-materializing every row on each write for the whole session (T1).
/// Everything that needs just the head of each parameter's history watches
/// [recentReadingsProvider] instead.
final tankReadingsProvider = Provider.autoDispose<AsyncValue<List<Reading>>>((
  ref,
) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_tankReadingsFamily(tank.id));
});

/// Row cap per parameter for [recentReadingsProvider]. Must fit the widened
/// trend window — [kTrendMaxWindow] readings *or* everything within
/// [kTrendMinSpanDays], whichever is more — so it allows for several
/// measurements a day (40 ≈ 8/day over the 5-day span) while still bounding
/// the per-write re-query cost (T1). Denser data than the cap degrades
/// gracefully: the trend simply fits over the newest rows available.
const int kRecentReadingsPerParam = 40;

final _recentReadingsFamily = StreamProvider.autoDispose
    .family<List<Reading>, int>(
      (ref, tankId) => _dedup(
        ref
            .watch(dbProvider)
            .watchRecentReadingsPerParam(tankId, kRecentReadingsPerParam),
      ),
    );

/// The newest [kRecentReadingsPerParam] readings per parameter for the active
/// tank, newest first (T1). Bounded feed for the dashboard tiles (latest
/// value + change), [tankHealthProvider] (latest per parameter) and
/// [tankTrendsProvider] (the widened trend window per parameter); its
/// per-write cost is independent of the total history size. Full series stay
/// on [tankReadingsProvider]/[paramReadingsProvider].
final recentReadingsProvider = Provider<AsyncValue<List<Reading>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_recentReadingsFamily(tank.id));
});

final _waterChangesFamily = StreamProvider.autoDispose
    .family<List<WaterChange>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchWaterChanges(tankId)),
    );

/// Water changes for the active tank (newest first).
final waterChangesProvider = Provider<AsyncValue<List<WaterChange>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_waterChangesFamily(tank.id));
});

final _carbonChangesFamily = StreamProvider.autoDispose
    .family<List<CarbonChange>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchCarbonChanges(tankId)),
    );

/// Activated-carbon changes for the active tank (newest first).
final carbonChangesProvider = Provider<AsyncValue<List<CarbonChange>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_carbonChangesFamily(tank.id));
});

final _equipmentCleaningsFamily = StreamProvider.autoDispose
    .family<List<EquipmentCleaning>, int>(
      (ref, tankId) =>
          _dedup(ref.watch(dbProvider).watchEquipmentCleanings(tankId)),
    );

/// Equipment cleanings for the active tank (newest first).
final equipmentCleaningsProvider =
    Provider<AsyncValue<List<EquipmentCleaning>>>((ref) {
      final tank = ref.watch(activeTankProvider);
      if (tank == null) return const AsyncValue.data([]);
      return ref.watch(_equipmentCleaningsFamily(tank.id));
    });

final _dosingEntriesFamily = StreamProvider.autoDispose
    .family<List<DosingEntry>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchDosingEntries(tankId)),
    );

/// Supplement-dosing plan entries for the active tank (dashboard order).
final dosingEntriesProvider = Provider<AsyncValue<List<DosingEntry>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_dosingEntriesFamily(tank.id));
});

final _dosingHistoryFamily = StreamProvider.autoDispose
    .family<List<DosingEntry>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchDosingHistory(tankId)),
    );

/// Every dosing segment (active + ended) for the active tank, newest first —
/// the source for the dosing history timeline.
final dosingHistoryProvider = Provider<AsyncValue<List<DosingEntry>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_dosingHistoryFamily(tank.id));
});

final _paramReadingsFamily = StreamProvider.autoDispose
    .family<List<Reading>, ({int tankId, String paramKey})>(
      (ref, key) => _dedup(
        ref.watch(dbProvider).watchParamReadings(key.tankId, key.paramKey),
      ),
    );

/// Readings for a single parameter of the active tank (oldest first).
/// autoDispose (T3): each instance is a full-series live query, and consumers
/// (history, ratio, dose-calculator screens) all re-watch on entry — without
/// it every paramKey ever visited would keep re-querying its whole history on
/// each readings write for the rest of the session.
final paramReadingsProvider = Provider.autoDispose
    .family<AsyncValue<List<Reading>>, String>((ref, paramKey) {
      final tank = ref.watch(activeTankProvider);
      if (tank == null) return const AsyncValue.data([]);
      return ref.watch(
        _paramReadingsFamily((tankId: tank.id, paramKey: paramKey)),
      );
    });

// --- Settings ---------------------------------------------------------------

/// The raw settings key/value map — the *single* live query behind every
/// settings provider (T4). Previously each setting held its own
/// `watchSingleOrNull`, so any settings write (e.g. the auto-backup stamp)
/// re-ran ~14 queries; now it re-runs this one. `main()` awaits this
/// provider's first value to pre-warm the stored locale (and the database
/// open) before the first frame.
final settingsMapProvider = StreamProvider<Map<String, String?>>(
  (ref) => ref.watch(settingsProvider).watchAll().distinct(mapEquals),
);

/// A single setting derived from [settingsMapProvider]: `select` re-evaluates
/// the (cheap) decode on every map emission but only notifies watchers when
/// *this key's* decoded value actually changed — a write to one setting no
/// longer re-notifies the other settings' watchers. Decoders (and defaults)
/// are the same static [AppSettings] functions the stream facade uses.
Provider<AsyncValue<T>> _setting<T>(
  SettingKey key,
  T Function(String? raw) decode,
) => Provider<AsyncValue<T>>(
  (ref) => ref.watch(
    settingsMapProvider.select(
      (async) => async.whenData((map) => decode(map[key.storageKey])),
    ),
  ),
);

/// Preferred temperature display unit (default Celsius).
final tempUnitProvider = _setting(
  SettingKey.tempUnit,
  AppSettings.decodeTempUnit,
);

/// Preferred salinity display unit (default ppt).
final salinityUnitProvider = _setting(
  SettingKey.salinityUnit,
  AppSettings.decodeSalinityUnit,
);

/// Preferred volume display unit (default litres).
final volumeUnitProvider = _setting(
  SettingKey.volumeUnit,
  AppSettings.decodeVolumeUnit,
);

/// Combined unit preferences, reactive to settings changes.
final unitPrefsProvider = Provider<UnitPrefs>((ref) {
  final temp = ref.watch(tempUnitProvider).value ?? TempUnit.celsius;
  final salinity = ref.watch(salinityUnitProvider).value ?? SalinityUnit.ppt;
  final volume = ref.watch(volumeUnitProvider).value ?? VolumeUnit.liters;
  return UnitPrefs(temp: temp, salinity: salinity, volume: volume);
});

/// Whether the one-time top-bar feature tour has already been shown. Unset
/// (a fresh install) reads as `false` so the tour runs once; the "Replay tour"
/// settings action resets it to `'false'` to trigger it again.
final tourSeenProvider = _setting(
  SettingKey.tourSeen,
  AppSettings.decodeTourSeen,
);

/// Stored language code ('system' / 'en' / 'cs'), defaulting to 'system'.
final localeCodeProvider = _setting(
  SettingKey.locale,
  AppSettings.decodeLocaleCode,
);

/// The locale override for MaterialApp, or null to follow the system locale.
final localeProvider = Provider<Locale?>((ref) {
  final code = ref.watch(localeCodeProvider).value ?? 'system';
  return code == 'system' ? null : Locale(code);
});

/// The history-chart time range, stored as the range's label ('7d', '30d',
/// '90d', 'All'). Shared across every parameter graph. Defaults to '30d'.
final chartRangeProvider = _setting(
  SettingKey.chartRange,
  AppSettings.decodeChartRange,
);

/// Whether automatic backups are enabled (default on).
final autoBackupEnabledProvider = _setting(
  SettingKey.autoBackupEnabled,
  AppSettings.decodeAutoBackupEnabled,
);

/// The automatic-backup frequency, defaulting to daily.
final autoBackupIntervalProvider = _setting(
  SettingKey.autoBackupInterval,
  AppSettings.decodeAutoBackupInterval,
);

/// When the most recent automatic or manual backup completed, or null if none
/// has run yet. Reacts to the stored timestamp, so it refreshes as soon as a
/// backup is written.
final lastBackupAtProvider = _setting(
  SettingKey.lastAutoBackupAt,
  AppSettings.decodeLastBackupAt,
);

/// When the most recent backup attempt failed, or null if the latest attempt
/// succeeded (every successful backup clears it). Non-null drives the warning
/// row in Settings → Backup.
final lastBackupErrorAtProvider = _setting(
  SettingKey.lastBackupErrorAt,
  AppSettings.decodeLastBackupErrorAt,
);

/// Whether recent-trend detection / forecasts are shown (default on).
final trendEnabledProvider = _setting(
  SettingKey.trendEnabled,
  AppSettings.decodeTrendEnabled,
);

/// How much of the tank-health feature to show (badge + card / badge only /
/// off). Defaults to [HealthDisplay.both].
final healthDisplayProvider = _setting(
  SettingKey.healthDisplay,
  AppSettings.decodeHealthDisplay,
);

/// Number of most-recent readings that define a trend (also the minimum count
/// before a trend is shown). Defaults to [kTrendDefaultWindow].
final trendWindowProvider = _setting(
  SettingKey.trendWindow,
  AppSettings.decodeTrendWindow,
);

/// Forecast horizon in days: a projected zone crossing is shown as a dashboard
/// attention chip only when it falls within this many days. Defaults to
/// [kTrendDefaultHorizon].
final trendHorizonProvider = _setting(
  SettingKey.trendHorizon,
  AppSettings.decodeTrendHorizon,
);

/// Recent-trend forecast per parameter for the active tank, keyed by paramKey.
///
/// This is the **cache**: a plain (non-stream) provider derived from the trend
/// settings, tracked parameters, and readings. Riverpod memoizes its value and
/// only re-runs the (cheap) least-squares math when one of those inputs
/// actually changes — never on a mere widget rebuild. Empty when trends are
/// disabled or no parameter has enough readings yet.
final tankTrendsProvider = Provider<Map<String, TrendResult>>((ref) {
  final enabled = ref.watch(trendEnabledProvider).value ?? kTrendDefaultEnabled;
  if (!enabled) return const {};
  final window = ref.watch(trendWindowProvider).value ?? kTrendDefaultWindow;
  final tracked = ref.watch(trackedParametersProvider).value ?? const [];
  // Bounded head of each parameter's history — the widened trend window
  // (window readings or kTrendMinSpanDays, whichever covers more) fits inside
  // kRecentReadingsPerParam for any sane measuring cadence.
  final readings = ref.watch(recentReadingsProvider).value ?? const [];

  // Group into oldest-first per-parameter series (readings arrive newest-first).
  final byParam = <String, List<DosePoint>>{};
  for (final r in readings.reversed) {
    (byParam[r.paramKey] ??= []).add((t: r.takenAt, value: r.value));
  }

  final result = <String, TrendResult>{};
  for (final p in tracked) {
    final pts = byParam[p.paramKey];
    if (pts == null) continue;
    final t = computeTrend(points: pts, bounds: boundsOf(p), window: window);
    if (t != null) result[p.paramKey] = t;
  }
  return result;
});

/// Overall tank-health score for the active tank, derived from its tracked
/// parameters and their latest readings. Memoized like [tankTrendsProvider]:
/// the (cheap) scoring only re-runs when the parameters or readings change.
/// [TankHealth] is value-equal, so a recompute that lands on the same health
/// (e.g. a reading's note was edited) doesn't notify watchers (T2).
final tankHealthProvider = Provider<TankHealth>((ref) {
  final tracked = ref.watch(trackedParametersProvider).value ?? const [];
  final readings = ref.watch(recentReadingsProvider).value ?? const [];

  // Latest reading per parameter (readings arrive newest-first).
  final latest = <String, Reading>{};
  for (final r in readings) {
    latest.putIfAbsent(r.paramKey, () => r);
  }

  final inputs = <HealthInput>[
    for (final p in tracked.where((t) => t.enabled))
      (
        paramKey: p.paramKey,
        bounds: boundsOf(p),
        latest: latest[p.paramKey]?.value,
        takenAt: latest[p.paramKey]?.takenAt,
      ),
  ];
  return computeTankHealth(inputs);
});

final _ratioSettingsFamily = StreamProvider.autoDispose
    .family<Map<String, RatioSettings>, int>(
      (ref, tankId) => ref
          .watch(dbProvider)
          .watchRatioVisibilities(tankId)
          .map((rows) => {for (final r in rows) r.ratioKey: r.settings})
          // Same dedup as the list families ([_dedup]); RatioSettings is a
          // record, so map values are value-equal.
          .distinct(mapEquals),
    );

/// Per-tank dashboard ratio-card settings (visibility + order) for the active
/// tank, keyed by [RatioKind.name], as domain [RatioSettings] records. Missing
/// entries fall back to defaults (visible, ordered after measurements) via
/// `ratioRowVisible`/`ratioRowOrder`.
final ratioSettingsProvider = Provider<AsyncValue<Map<String, RatioSettings>>>((
  ref,
) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data({});
  return ref.watch(_ratioSettingsFamily(tank.id));
});
