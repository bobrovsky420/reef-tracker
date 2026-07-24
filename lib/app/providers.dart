import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/cloud_auth.dart';
import '../data/cloud_auth_google.dart';
import '../data/cloud_backup_store.dart';
import '../data/database.dart';
import '../data/hanna_meter_link.dart';
import '../data/hanna_meter_link_ble.dart';
import '../data/notifications.dart';
import '../data/reminder_scheduler.dart';
import '../data/rf_device_link.dart';
import '../data/settings.dart';
import '../domain/clock.dart';
import '../domain/health_score.dart';
import '../domain/insights.dart';
import '../domain/micro.dart';
import '../domain/parameter_catalog.dart';
import '../domain/pro_features.dart';
import '../domain/ratio.dart';
import '../domain/reminders.dart';
import '../domain/ro.dart';
import '../domain/stability_score.dart';
import '../domain/trend.dart';
import '../domain/units.dart';
import '../domain/zones.dart';

// The settings keys, the [HealthDisplay] enum, and the typed [Settings] facade
// live in `data/settings.dart`. Re-export the symbols widgets reach through this
// file so their imports are unchanged.
export '../data/settings.dart'
    show
        HealthDisplay,
        DashboardLayout,
        AppEdition,
        AppThemeMode,
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

/// Platform wrapper for reminder notifications (U1/U2/U12).
final reminderNotificationsProvider = Provider<ReminderNotifications>(
  (ref) => ReminderNotifications(),
);

/// The background reminder scheduler; started (and resynced) from
/// `main.dart`'s post-first-frame hook and on resume.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(
    ref.watch(dbProvider),
    ref.watch(reminderNotificationsProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
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

/// Measurement-import state rows (U32): the location → tank mappings and
/// dedupe watermarks, one per (tank, source) that ever imported. Drives the
/// Settings "Measurement import" surface (hidden while empty).
final importSourcesProvider = StreamProvider<List<ImportSource>>(
  (ref) => ref.watch(dbProvider).watchImportSources(),
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

/// Live zone of each element targeted by an active dosing entry (REDESIGN
/// #13), keyed by paramKey — the Dosing tab colors an entry's element tag with
/// it. Single-layer derivation from the stream wrappers, like
/// [tankHealthProvider].
///
/// A key is *absent* when its zone can't be honestly stated — no reading yet,
/// no usable bounds, or a reading older than [kHealthFreshnessDays] (health's
/// staleness rule; ICP-cadence microelements are naturally always stale) —
/// and the tag renders neutral. Bounds resolve like the micro panel's: the
/// tracked row's when present, else the catalog's micro defaults (core
/// elements always have a row — the preset seeds one).
final dosingElementZonesProvider = Provider<Map<String, Zone>>((ref) {
  final entries = ref.watch(dosingEntriesProvider).value ?? const [];
  final keys = {
    for (final e in entries)
      if (e.elementKey != null) e.elementKey!,
  };
  if (keys.isEmpty) return const {};
  final tracked = ref.watch(trackedParametersProvider).value ?? const [];
  final readings = ref.watch(recentReadingsProvider).value ?? const [];

  final rowByKey = {for (final t in tracked) t.paramKey: t};
  // Latest reading per parameter (readings arrive newest-first).
  final latest = <String, Reading>{};
  for (final r in readings) {
    latest.putIfAbsent(r.paramKey, () => r);
  }

  final now = DateTime.now();
  final zones = <String, Zone>{};
  for (final key in keys) {
    final reading = latest[key];
    if (reading == null ||
        daysSince(reading.takenAt, now: now) > kHealthFreshnessDays) {
      continue;
    }
    final bounds = switch (rowByKey[key]) {
      final row? => boundsOf(row),
      null => microDefaultBounds(key),
    };
    final zone = bounds.classify(reading.value);
    if (zone != Zone.unknown) zones[key] = zone;
  }
  return zones;
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

final _manualDosesFamily = StreamProvider.autoDispose
    .family<List<ManualDose>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchManualDoses(tankId)),
    );

/// Logged one-off manual doses for the active tank (newest first).
final manualDosesProvider = Provider<AsyncValue<List<ManualDose>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_manualDosesFamily(tank.id));
});

final _readingTemplatesFamily = StreamProvider.autoDispose
    .family<List<ReadingTemplate>, int>(
      (ref, tankId) =>
          _dedup(ref.watch(dbProvider).watchReadingTemplates(tankId)),
    );

/// Test sets (named parameter subsets for the Add Reading screen, U9) for the
/// active tank, in user chip order.
final readingTemplatesProvider = Provider<AsyncValue<List<ReadingTemplate>>>((
  ref,
) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_readingTemplatesFamily(tank.id));
});

final _microViewsFamily = StreamProvider.autoDispose
    .family<List<MicroView>, int>(
      (ref, tankId) => _dedup(ref.watch(dbProvider).watchMicroViews(tankId)),
    );

/// Custom microelement views (U17) for the active tank, in user chip order.
final microViewsProvider = Provider<AsyncValue<List<MicroView>>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return const AsyncValue.data([]);
  return ref.watch(_microViewsFamily(tank.id));
});

final _maintenanceSchedulesFamily = StreamProvider.autoDispose
    .family<List<MaintenanceSchedule>, int>(
      (ref, tankId) =>
          _dedup(ref.watch(dbProvider).watchMaintenanceSchedules(tankId)),
    );

/// Maintenance plans (U12) for the active tank, in user order.
final maintenanceSchedulesProvider =
    Provider<AsyncValue<List<MaintenanceSchedule>>>((ref) {
      final tank = ref.watch(activeTankProvider);
      if (tank == null) return const AsyncValue.data([]);
      return ref.watch(_maintenanceSchedulesFamily(tank.id));
    });

/// One due chip on the Actions tab: the plan row plus its current due status
/// (null [DueStatus] = not due-able, e.g. a finished one-off — those rows are
/// filtered out here).
typedef MaintenanceDue = ({MaintenanceSchedule schedule, DueStatus due});

/// Due status for every plan of the active tank, in plan order. Derived from
/// the schedule list + the three action logs (their newest rows are the
/// elastic anchors for typed plans), so logging an action updates the chips
/// live. Time-dependent ("due in N d") but cheap: it recomputes whenever any
/// input stream emits, and screens rebuild on resume/navigation anyway.
final maintenanceDueProvider = Provider<List<MaintenanceDue>>((ref) {
  final schedules =
      ref.watch(maintenanceSchedulesProvider).value ??
      const <MaintenanceSchedule>[];
  if (schedules.isEmpty) return const [];
  DateTime? newest(Iterable<DateTime> times) =>
      times.isEmpty ? null : times.reduce((a, b) => a.isAfter(b) ? a : b);
  final lastByType = {
    MaintenanceActionType.waterChange: newest(
      (ref.watch(waterChangesProvider).value ?? const []).map(
        (w) => w.changedAt,
      ),
    ),
    MaintenanceActionType.carbonChange: newest(
      (ref.watch(carbonChangesProvider).value ?? const []).map(
        (c) => c.changedAt,
      ),
    ),
    MaintenanceActionType.equipmentCleaning: newest(
      (ref.watch(equipmentCleaningsProvider).value ?? const []).map(
        (c) => c.cleanedAt,
      ),
    ),
  };
  final now = DateTime.now();
  return [
    for (final s in schedules)
      if (nextMaintenanceDue(
            lastDone: switch (MaintenanceActionType.fromName(s.actionType)) {
              final type? => lastByType[type],
              null => s.lastDoneAt,
            },
            cadenceDays: s.cadenceDays,
            cadenceUnit: s.cadenceUnit,
            weekdays: s.weekdays,
            monthDay: s.monthDay,
            scheduledAt: s.scheduledAt,
            now: now,
          )
          case final due?)
        (schedule: s, due: dueStatus(due, now: now)),
  ];
});

// --- RO unit (U16) — device-scoped, shared across tanks ----------------------
//
// Deliberately *not* tank-family providers: the RO unit serves the whole
// household, so these streams are plain app-lifetime StreamProviders like
// [tanksProvider].

/// Every RO stage (enabled and disabled), in overview order.
final roStagesProvider = StreamProvider<List<RoStage>>(
  (ref) => _dedup(ref.watch(dbProvider).watchRoStages()),
);

/// The full RO replacement log, newest first (small by nature).
final roReplacementsProvider = StreamProvider<List<RoStageReplacement>>(
  (ref) => _dedup(ref.watch(dbProvider).watchRoReplacements()),
);

/// One RO overview row: the stage, its latest replacement, and its due status.
/// [due] is null when it cannot be computed — no replacement logged yet
/// (unknown filter age, never guessed) or an invalid stored lifespan.
typedef RoStageStatus = ({
  RoStage stage,
  DateTime? lastReplacedAt,
  DueStatus? due,
});

/// Status for every RO stage (disabled ones included — the overview shows
/// them in its hidden section; due-driven surfaces filter on
/// `stage.enabled`). Derived like [maintenanceDueProvider]: recomputes when
/// the stages or the replacement log change.
final roStageStatusProvider = Provider<List<RoStageStatus>>((ref) {
  final stages = ref.watch(roStagesProvider).value ?? const <RoStage>[];
  if (stages.isEmpty) return const [];
  final replacements =
      ref.watch(roReplacementsProvider).value ?? const <RoStageReplacement>[];
  // Log arrives newest-first, so the first row seen per stage is its latest.
  final latest = <int, DateTime>{};
  for (final r in replacements) {
    latest.putIfAbsent(r.stageId, () => r.replacedAt);
  }
  final now = DateTime.now();
  return [
    for (final s in stages)
      (
        stage: s,
        lastReplacedAt: latest[s.id],
        due: switch (roStageDue(
          lastReplacedAt: latest[s.id],
          lifespanDays: s.lifespanDays,
          now: now,
        )) {
          final d? => dueStatus(d, now: now),
          null => null,
        },
      ),
  ];
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

/// The stored light/dark theme choice (REDESIGN #16), defaulting to
/// "follow the system". `main.dart` maps it onto `MaterialApp.themeMode`
/// (the data layer stays Flutter-free, so the mapping can't live here).
final themeModeProvider = _setting(
  SettingKey.themeMode,
  AppSettings.decodeThemeMode,
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

/// Reminder master switches (U1/U2/U12), all default **off** (opt-in).
final remindersTestingProvider = _setting(
  SettingKey.remindersTesting,
  AppSettings.decodeRemindersTesting,
);
final remindersDosingProvider = _setting(
  SettingKey.remindersDosing,
  AppSettings.decodeRemindersDosing,
);
final remindersMaintenanceProvider = _setting(
  SettingKey.remindersMaintenance,
  AppSettings.decodeRemindersMaintenance,
);

/// Delivery time for testing/maintenance reminders (default 09:00).
final reminderTimeProvider = _setting(
  SettingKey.reminderTime,
  AppSettings.decodeReminderTime,
);

/// Whether the RO-unit feature is surfaced at all (U16, default on): gates
/// the Actions-tab summary row (and, in the scheduler, RO reminders).
final roUnitEnabledProvider = _setting(
  SettingKey.roUnitEnabled,
  AppSettings.decodeRoUnitEnabled,
);

/// Whether the microelements panel is surfaced at all (U17, default on):
/// gates the dashboard summary tile (and, in the scheduler, micro test
/// reminders). Off only hides — measurements stay stored and reappear when
/// re-enabled.
final microEnabledProvider = _setting(
  SettingKey.microEnabled,
  AppSettings.decodeMicroEnabled,
);

/// Whether experimental features (Hanna checker Bluetooth connection U33 and
/// checker camera scan U34) are surfaced at all (default off): gates every
/// entry point — the Settings rows, the Measurements-tab overflow items and
/// the scan FAB.
final experimentalEnabledProvider = _setting(
  SettingKey.experimentalEnabled,
  AppSettings.decodeExperimentalEnabled,
);

/// Whether the checker camera scan shows its quick button above "Add
/// reading" on the Measurements tab (default off). Only effective while
/// [experimentalEnabledProvider] is on and the install is entitled to
/// [ProFeature.hannaScan].
final hannaScanFabProvider = _setting(
  SettingKey.hannaScanFab,
  AppSettings.decodeHannaScanFab,
);

/// The Microelements-screen quick filters (U17, both default off): hide
/// undetectable (zero) readings — except where zero is abnormal — and show
/// only elements needing attention. Display-only: neither affects
/// [microStatusProvider]'s counts.
final microHideUndetectableProvider = _setting(
  SettingKey.microHideUndetectable,
  AppSettings.decodeMicroHideUndetectable,
);

final microAttentionOnlyProvider = _setting(
  SettingKey.microAttentionOnly,
  AppSettings.decodeMicroAttentionOnly,
);

/// Which edition this install is entitled to (U19 phase 0):
/// [AppEdition.founder] when the early-adopter marker is present (seeded on
/// launch by every pre-Pro version — so, until a Pro build exists, every
/// install), [AppEdition.standard] otherwise. Drives the Edition row in
/// Settings.
final editionProvider = _setting(
  SettingKey.legacyFreeSince,
  AppSettings.decodeEdition,
);

/// Whether this install may use [ProFeature] (U19): a purchased Pro unlock
/// (no purchase mechanism exists yet — always false today) or a Founder's
/// Edition install using a grandfathered feature. While the settings map is
/// still loading (only possible before `main`'s pre-warm completes) the gate
/// stays open — never flash a lock at a founder.
final proFeatureProvider = Provider.family<bool, ProFeature>((ref, feature) {
  final edition = ref.watch(editionProvider).value ?? AppEdition.founder;
  return hasProFeature(
    feature,
    purchased: false,
    legacyFree: edition == AppEdition.founder,
  );
});

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

/// Google auth for Drive sync (U24). A provider so tests (and any future
/// platform without the Google path) can override it with a fake — nothing
/// else in the app touches the `google_sign_in` plugin.
final cloudAuthProvider = Provider<CloudAuth>((ref) => GoogleDriveAuth());

/// The Drive-backed [CloudBackupStore] the sync engine and the Manage-backups
/// Drive section talk to. Same override story as [cloudAuthProvider].
final cloudBackupStoreProvider = Provider<CloudBackupStore>(
  (ref) => DriveBackupStore(ref.watch(cloudAuthProvider).accessToken),
);

/// The Google account Drive sync pushes to, or null when not connected
/// (U24) — presence is the "sync on" state. Drives the Settings row and the
/// Drive section in Manage backups.
final syncGdriveAccountProvider = _setting(
  SettingKey.syncGdriveAccount,
  AppSettings.decodeSyncGdriveAccount,
);

/// When the most recent Drive push completed, or null before the first one.
final syncGdriveLastPushAtProvider = _setting(
  SettingKey.syncGdriveLastPushAt,
  AppSettings.decodeSyncGdriveLastPushAt,
);

/// When the most recent Drive push attempt failed (offline doesn't count),
/// or null if the latest attempt succeeded. Non-null drives the warning row
/// in Settings → Backup, same idiom as [lastBackupErrorAtProvider].
final syncGdriveLastErrorAtProvider = _setting(
  SettingKey.syncGdriveLastErrorAt,
  AppSettings.decodeSyncGdriveLastErrorAt,
);

/// The user's named Hanna-checker method pre-selections (U33), e.g.
/// "Daily test". Rides backups (not device-local).
final hannaMethodSetsProvider = _setting(
  SettingKey.hannaMethodSets,
  AppSettings.decodeHannaMethodSets,
);

/// Factory for the Hanna checker transport (U33). A provider — same override
/// story as [cloudAuthProvider] — so tests drive the session with a scripted
/// fake instead of real BLE hardware; each measurement session constructs a
/// fresh link per connection attempt.
final hannaMeterLinkFactoryProvider = Provider<HannaMeterLink Function()>(
  (ref) => BleHannaMeterLink.new,
);

// --- ReefFactory local devices (U36) — household-scoped, shared across tanks -

/// The transport for reading ReefFactory meters over the LAN. A provider — same
/// override story as [hannaMeterLinkFactoryProvider] — so widget tests drive the
/// dashboard with a scripted fake instead of a real WebSocket.
final rfDeviceLinkProvider = Provider<RfDeviceLink>(
  (ref) => const RfWebSocketLink(),
);

/// The registered ReefFactory devices (dashboard cards). Household-scoped, so a
/// plain app-lifetime [StreamProvider] like [roStagesProvider], not a
/// tank-family one.
final reefFactoryDevicesProvider = StreamProvider<List<DeviceRecord>>(
  (ref) => _dedup(ref.watch(dbProvider).watchDevicesOfKind('reeffactory')),
);

/// Every connected device (ReefFactory meters + the Hanna checker once used) —
/// the read-only Settings "Connected devices" inventory.
final allDevicesProvider = StreamProvider<List<DeviceRecord>>(
  (ref) => _dedup(ref.watch(dbProvider).watchDevices()),
);

/// Whether this device has Bluetooth LE at all (U33). The manifest marks the
/// Bluetooth/location hardware features `required="false"` so Play doesn't
/// filter the app off devices without them; this is the runtime counterpart
/// that hides the Hanna checker entry points there. While resolving it
/// defaults to *shown* (no flash for the overwhelmingly common BLE-capable
/// case); the connect screen's "unsupported" state remains the backstop for
/// a deep link racing the check.
final hannaBleSupportedProvider = FutureProvider<bool>(
  (ref) => BleHannaMeterLink.isSupported(),
);

/// Last-used test set per tank id (device-local UI state, U9). A missing or
/// dangling entry means "All parameters".
final lastReadingTemplatesProvider = _setting(
  SettingKey.lastReadingTemplate,
  AppSettings.decodeLastReadingTemplates,
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

/// How the main dashboard organizes its cards — grouped sections (REDESIGN #6)
/// vs the original flat grid. Also drives the compare view's ordering and the
/// Manage Parameters list. Defaults to [DashboardLayout.grouped].
final dashboardLayoutProvider = _setting(
  SettingKey.dashboardLayout,
  AppSettings.decodeDashboardLayout,
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
    // Core parameters only: microelements (U17) are measured on an ICP
    // cadence (months), which the 30-day freshness rule would permanently
    // read as stale — the micro panel carries its own status summary instead
    // ([microStatusProvider]).
    for (final p in tracked.where((t) => t.enabled && isCoreParam(t.paramKey)))
      (
        paramKey: p.paramKey,
        bounds: boundsOf(p),
        latest: latest[p.paramKey]?.value,
        takenAt: latest[p.paramKey]?.takenAt,
      ),
  ];
  return computeTankHealth(inputs);
});

/// Weeks the "Ask your AI" summary export covers (4/8/12, default
/// [kAiSummaryDefaultWeeks] — U27). Device-local UI preference, persisted so
/// the pre-share sheet reopens on the last-used window.
final aiSummaryWeeksProvider = _setting(
  SettingKey.aiSummaryWeeks,
  AppSettings.decodeAiSummaryWeeks,
);

/// Days of history the stability score examines (30/60/90, default
/// [kStabilityWindowDays] = 30 — matching health's freshness horizon). The
/// longer windows exist for relaxed testing cadences that can't accumulate
/// three tests in 30 days.
final stabilityWindowProvider = _setting(
  SettingKey.stabilityWindow,
  AppSettings.decodeStabilityWindow,
);

/// Time-bounded readings feed for the stability score (U26), keyed by
/// (tank, window). A *time* window rather than [kRecentReadingsPerParam]'s
/// count cap — a 90-day window under a per-parameter row limit would silently
/// truncate for a daily tester. The cutoff is fixed at stream creation, which
/// is safe in the conservative direction: real time only moves the true
/// window start *forward*, so the feed is always a superset of the window and
/// [computeTankStability] re-filters precisely with its own clock.
final _stabilityReadingsFamily = StreamProvider.autoDispose
    .family<List<Reading>, ({int tankId, int days})>(
      (ref, key) => _dedup(
        ref
            .watch(dbProvider)
            .watchReadingsSince(
              key.tankId,
              DateTime.now().subtract(Duration(days: key.days)),
            ),
      ),
    );

/// Overall stability score for the active tank (U26, Pro): how much each core
/// parameter has been oscillating over the configured window
/// ([stabilityWindowProvider]). Same memoized single-layer derivation as
/// [tankHealthProvider]; [TankStability] is value-equal (T2). Changing the
/// window or the active tank switches to a fresh family instance (#20), so a
/// brief no-data state replaces stale-window flashes.
final tankStabilityProvider = Provider<TankStability>((ref) {
  final tracked = ref.watch(trackedParametersProvider).value ?? const [];
  final windowDays =
      ref.watch(stabilityWindowProvider).value ?? kStabilityWindowDays;
  final tank = ref.watch(activeTankProvider);
  final readings = tank == null
      ? const <Reading>[]
      : ref
                .watch(
                  _stabilityReadingsFamily((tankId: tank.id, days: windowDays)),
                )
                .value ??
            const <Reading>[];

  // Per-parameter series (order is irrelevant — the domain sorts and
  // window-filters).
  final byParam = <String, List<DosePoint>>{};
  for (final r in readings) {
    (byParam[r.paramKey] ??= []).add((t: r.takenAt, value: r.value));
  }

  final inputs = <StabilityInput>[
    // Core parameters only, matching the health score: microelements are
    // measured on an ICP cadence (months) — a 30-day oscillation window can
    // never hold enough of their samples to mean anything.
    for (final p in tracked.where((t) => t.enabled && isCoreParam(t.paramKey)))
      (
        paramKey: p.paramKey,
        bounds: boundsOf(p),
        points: byParam[p.paramKey] ?? const [],
      ),
  ];
  return computeTankStability(inputs, windowDays: windowDays);
});

/// Rule-based insights for the active tank (U28, Pro): the prioritized
/// observations list behind the dashboard Insights card. Computed regardless
/// of entitlement (the U26 split — only presentation is gated).
///
/// Deliberately a **single-layer derivation** from the stream wrappers and
/// settings, re-running the (cheap) health/trend math instead of watching
/// [tankHealthProvider]/[tankTrendsProvider]: chaining plain providers can
/// self-invalidate mid-build when the inner one is lazily recomputed during a
/// widget build (see [_microElements]).
final tankInsightsProvider = Provider<List<Insight>>((ref) {
  final tracked = ref.watch(trackedParametersProvider).value ?? const [];
  final readings = ref.watch(recentReadingsProvider).value ?? const [];
  final horizon = ref.watch(trendHorizonProvider).value ?? kTrendDefaultHorizon;
  final trendsOn =
      ref.watch(trendEnabledProvider).value ?? kTrendDefaultEnabled;
  final window = ref.watch(trendWindowProvider).value ?? kTrendDefaultWindow;

  // Same groupings as [tankHealthProvider] / [tankTrendsProvider]: latest
  // reading per parameter (arrives newest-first) and oldest-first series.
  final latest = <String, Reading>{};
  for (final r in readings) {
    latest.putIfAbsent(r.paramKey, () => r);
  }
  final byParam = <String, List<DosePoint>>{};
  for (final r in readings.reversed) {
    (byParam[r.paramKey] ??= []).add((t: r.takenAt, value: r.value));
  }

  final core = tracked.where((t) => t.enabled && isCoreParam(t.paramKey));
  final bounds = {for (final p in core) p.paramKey: boundsOf(p)};

  final health = computeTankHealth([
    for (final p in core)
      (
        paramKey: p.paramKey,
        bounds: bounds[p.paramKey]!,
        latest: latest[p.paramKey]?.value,
        takenAt: latest[p.paramKey]?.takenAt,
      ),
  ]);

  final trends = <String, TrendResult>{};
  if (trendsOn) {
    for (final p in core) {
      final pts = byParam[p.paramKey];
      if (pts == null) continue;
      final t = computeTrend(
        points: pts,
        bounds: bounds[p.paramKey]!,
        window: window,
      );
      if (t != null) trends[p.paramKey] = t;
    }
  }

  return computeInsights(
    health: health,
    trends: trends,
    bounds: bounds,
    horizonDays: horizon,
  );
});

// --- Microelements (U17) ------------------------------------------------------

/// One Microelements-screen row: the catalog element, its tracked row when one
/// exists (created lazily on first save/bounds-edit), the latest reading, and
/// the *effective* bounds — the row's when present, else the catalog defaults.
typedef MicroElementStatus = ({
  ParameterDef def,
  TrackedParameter? row,
  Reading? latest,
  ZoneBounds bounds,
});

/// Builds the panel rows from the two source streams. Shared by
/// [microElementsProvider] and [microStatusProvider], which each derive
/// **directly** from the stream wrappers — deliberately not chained on each
/// other: a plain Provider watching another plain Provider gets notified
/// synchronously when the inner one is lazily recomputed during a widget
/// build, and the resulting self-invalidation schedules a scope refresh
/// mid-build (setState-during-build crash). Single-layer derivation is the
/// same proven shape as [tankHealthProvider].
List<MicroElementStatus> _microElements(
  List<TrackedParameter> tracked,
  List<Reading> readings,
) {
  final rowByKey = {for (final t in tracked) t.paramKey: t};
  // Latest reading per parameter (readings arrive newest-first).
  final latest = <String, Reading>{};
  for (final r in readings) {
    latest.putIfAbsent(r.paramKey, () => r);
  }
  return [
    for (final def in kMicroParameters)
      (
        def: def,
        row: rowByKey[def.key],
        latest: latest[def.key],
        bounds: switch (rowByKey[def.key]) {
          final row? => boundsOf(row),
          null => microDefaultBounds(def.key),
        },
      ),
  ];
}

/// Status for every microelement of the active tank, in catalog order (the
/// order ICP reports list them). Derived from the same bounded streams as the
/// dashboard, so a saved measurement updates the panel live.
final microElementsProvider = Provider<List<MicroElementStatus>>(
  (ref) => _microElements(
    ref.watch(trackedParametersProvider).value ?? const [],
    ref.watch(recentReadingsProvider).value ?? const [],
  ),
);

/// The active microelement view (U17): its selection token, display info and
/// the element-key filter (null keys = full list, no filtering). A stored
/// token naming a deleted custom view falls back to the full list.
typedef MicroViewSelection = ({
  String token,
  MicroView? custom,
  Set<String>? keys,
});

/// Resolves the active view for [tankId] from the stored per-tank token and
/// the tank's custom views. Pure helper shared by [microViewSelectionProvider]
/// and [microStatusProvider] — the status provider deliberately re-derives
/// instead of watching the selection provider (see [_microElements] on why
/// plain providers aren't chained here).
MicroViewSelection _resolveMicroView(
  String? rawSetting,
  int? tankId,
  List<MicroView> views,
) {
  const full = (token: kMicroViewFullToken, custom: null, keys: null);
  if (tankId == null) return full;
  final token = AppSettings.decodeMicroViewSelections(rawSetting)[tankId];
  if (token == null || token == kMicroViewFullToken) return full;
  final presetKeys = microPresetKeys(token);
  if (presetKeys != null) return (token: token, custom: null, keys: presetKeys);
  if (token.startsWith(kMicroViewCustomPrefix)) {
    final id = int.tryParse(token.substring(kMicroViewCustomPrefix.length));
    for (final v in views) {
      if (v.id == id) {
        return (token: token, custom: v, keys: v.keys.toSet());
      }
    }
  }
  // Unknown/dangling token — never guess a subset.
  return full;
}

/// The active tank's current microelement view selection.
final microViewSelectionProvider = Provider<MicroViewSelection>((ref) {
  final tank = ref.watch(activeTankProvider);
  final raw = ref.watch(
    settingsMapProvider.select(
      (async) => async.value?[SettingKey.microView.storageKey],
    ),
  );
  final views = ref.watch(microViewsProvider).value ?? const [];
  return _resolveMicroView(raw, tank?.id, views);
});

/// Panel summary (measured / out-of-range counts, worst zone, newest sample
/// date) for the dashboard tile and the Microelements screen header —
/// **scoped to the active view**: an element outside the view doesn't count
/// toward "out of range" (hiding it is the user's explicit choice, like
/// untracking a core parameter). [MicroStatus] is a record (value-equal), so
/// a write that doesn't change the summary doesn't rebuild the tile (T2).
final microStatusProvider = Provider<MicroStatus>((ref) {
  final elements = _microElements(
    ref.watch(trackedParametersProvider).value ?? const [],
    ref.watch(recentReadingsProvider).value ?? const [],
  );
  final selection = _resolveMicroView(
    ref.watch(
      settingsMapProvider.select(
        (async) => async.value?[SettingKey.microView.storageKey],
      ),
    ),
    ref.watch(activeTankProvider)?.id,
    ref.watch(microViewsProvider).value ?? const [],
  );
  final keys = selection.keys;
  return computeMicroStatus([
    for (final e in elements)
      if (keys == null || keys.contains(e.def.key))
        (
          paramKey: e.def.key,
          bounds: e.bounds,
          latest: e.latest?.value,
          takenAt: e.latest?.takenAt,
        ),
  ]);
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

/// Whether the free (toxic) ammonia visualization is shown for the active tank
/// (default on). A per-tank display preference; the dashboard additionally
/// gates the card on the `ammonia` parameter being tracked + enabled, so
/// turning ammonia off automatically hides it. Selecting the raw setting string
/// keeps this from re-notifying on unrelated settings writes.
final freeAmmoniaVisibleProvider = Provider<bool>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return true;
  final raw = ref.watch(
    settingsMapProvider.select(
      (async) => async.value?[SettingKey.freeAmmoniaHidden.storageKey],
    ),
  );
  return !AppSettings.decodeFreeAmmoniaHidden(raw).contains(tank.id);
});

/// Whether the dose calculator's correction target is scaled to the active
/// tank's measured salinity (default off). A per-tank preference like
/// [freeAmmoniaVisibleProvider], with the same raw-string `select` so it only
/// re-notifies on its own settings key.
final doseCalcSalinityAdjustProvider = Provider<bool>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return false;
  final raw = ref.watch(
    settingsMapProvider.select(
      (async) => async.value?[SettingKey.doseCalcSalinityAdjust.storageKey],
    ),
  );
  return AppSettings.decodeDoseCalcSalinityAdjust(raw).contains(tank.id);
});
