import 'dart:convert';

import '../domain/reminders.dart';
import '../domain/trend.dart';
import '../domain/units.dart';
import 'database.dart';
import 'setting_keys.dart';

export 'setting_keys.dart';

/// Single source of truth for the `Settings` key/value store: every persisted
/// key, its default, its typed accessor, and whether it is a **device-local
/// preference** (see [SettingKey.deviceLocal]).
///
/// Before this facade, settings were read/written stringly-typed and scattered
/// (`db.getSetting(k) == 'true'`, `int.tryParse(...) ?? default`) with the
/// default duplicated at every call site. Route all settings access through
/// [Settings] so keys, decoding, and defaults live in exactly one place (TODO
/// T4) — which also makes excluding device preferences from a backup restore a
/// one-liner (TODO #18, [SettingKey.deviceLocalKeys]).

// The persisted key strings live in `setting_keys.dart` (re-exported above) so
// `database.dart` can share them without an import cycle (#55).

// --- Non-key defaults --------------------------------------------------------

/// Locale setting sentinel meaning "follow the system locale".
const kDefaultLocaleCode = 'system';

/// Default history-chart range label when none has been chosen.
const kDefaultChartRange = '30d';

/// Defaults applied when the corresponding auto-backup setting is unset.
const bool kAutoBackupDefaultEnabled = true;
const int kAutoBackupDefaultKeep = 5;

/// Default delivery time for testing/maintenance reminder notifications.
const kDefaultReminderTime = (hour: 9, minute: 0);

/// How often an automatic backup is taken (opportunistically, on app launch
/// or resume — see `runAutoBackupIfDue`).
enum AutoBackupInterval {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7));

  const AutoBackupInterval(this.period);

  /// Minimum time that must elapse between two automatic backups.
  final Duration period;

  static AutoBackupInterval fromName(String? name) =>
      AutoBackupInterval.values.firstWhere(
        (e) => e.name == name,
        orElse: () => AutoBackupInterval.daily,
      );
}

/// How much of the tank-health feature to surface on the dashboard.
enum HealthDisplay {
  /// Hide both the dashboard card and the app-bar badge.
  off,

  /// Show only the compact app-bar badge, no dashboard card.
  badge,

  /// Show both the app-bar badge and the dashboard card (default).
  both;

  /// Parses a stored setting value, defaulting to [both] when missing/unknown.
  static HealthDisplay fromName(String? name) {
    for (final v in HealthDisplay.values) {
      if (v.name == name) return v;
    }
    return HealthDisplay.both;
  }

  bool get showBadge => this != HealthDisplay.off;
  bool get showCard => this == HealthDisplay.both;
}

/// Registry of every settings key together with whether it is a device-local
/// preference. **Device-local** keys (units, language, chart range, trend /
/// health display, the tour flag, auto-backup config and its timestamp, and the
/// active-tank selection) describe *this device/user*, not the aquarium data, so
/// they are preserved — never overwritten — when a backup is restored (#18).
enum SettingKey {
  activeTank(kActiveTankKey, deviceLocal: true),
  tempUnit(kTempUnitKey, deviceLocal: true),
  salinityUnit(kSalinityUnitKey, deviceLocal: true),
  volumeUnit(kVolumeUnitKey, deviceLocal: true),
  locale(kLocaleKey, deviceLocal: true),
  chartRange(kChartRangeKey, deviceLocal: true),
  trendEnabled(kTrendEnabledKey, deviceLocal: true),
  trendWindow(kTrendWindowKey, deviceLocal: true),
  trendHorizon(kTrendHorizonKey, deviceLocal: true),
  healthDisplay(kHealthDisplayKey, deviceLocal: true),
  tourSeen(kTourSeenKey, deviceLocal: true),
  autoBackupEnabled(kAutoBackupEnabledKey, deviceLocal: true),
  autoBackupInterval(kAutoBackupIntervalKey, deviceLocal: true),
  autoBackupKeep(kAutoBackupKeepKey, deviceLocal: true),
  lastAutoBackupAt(kLastAutoBackupAtKey, deviceLocal: true),
  lastBackupErrorAt(kLastBackupErrorAtKey, deviceLocal: true),
  lastReadingTemplate(kLastReadingTemplateKey, deviceLocal: true),
  // Notification prefs are per-device by nature: restoring another device's
  // backup must not silently start (or stop) notifications on this one.
  remindersTesting(kRemindersTestingKey, deviceLocal: true),
  remindersDosing(kRemindersDosingKey, deviceLocal: true),
  remindersMaintenance(kRemindersMaintenanceKey, deviceLocal: true),
  reminderTime(kReminderTimeKey, deviceLocal: true),
  // NOT device-local: the flag travels with the RO stages it describes (both
  // ride the backup), so a restore either brings stages + flag together or
  // clears both — the next RO-screen visit then re-seeds the defaults.
  roSeeded(kRoSeededKey, deviceLocal: false),
  // The RO-unit feature switch (U16) is an ordinary display preference like
  // trendEnabled: device-local, default on.
  roUnitEnabled(kRoUnitEnabledKey, deviceLocal: true),
  // The microelements feature switch (U17): same shape as roUnitEnabled —
  // off only *hides* the panel (dashboard tile + micro test reminders); the
  // stored measurements are untouched and reappear when re-enabled.
  microEnabled(kMicroEnabledKey, deviceLocal: true),
  // The active microelement view per tank (U17) — a display selection like
  // lastReadingTemplate: device-local, the custom views themselves ride the
  // backup in the MicroViews table.
  microView(kMicroViewKey, deviceLocal: true),
  // The Microelements-screen quick filters (U17): plain display preferences
  // like trendEnabled — device-local, default off.
  microHideUndetectable(kMicroHideUndetectableKey, deviceLocal: true),
  microAttentionOnly(kMicroAttentionOnlyKey, deviceLocal: true),
  // Cloud folder sync (U20) — all device-local by necessity, not just
  // preference: the SAF tree uri and its permission grant only exist on the
  // device that picked the folder, and the sync stamps/hash describe what
  // *this* device last pushed. A restore importing another device's uri
  // would leave sync pointing at a folder this device cannot open.
  cloudSyncEnabled(kCloudSyncEnabledKey, deviceLocal: true),
  cloudSyncFolderUri(kCloudSyncFolderUriKey, deviceLocal: true),
  cloudSyncFolderName(kCloudSyncFolderNameKey, deviceLocal: true),
  lastCloudSyncAt(kLastCloudSyncAtKey, deviceLocal: true),
  lastCloudSyncErrorAt(kLastCloudSyncErrorAtKey, deviceLocal: true),
  lastCloudSyncHash(kLastCloudSyncHashKey, deviceLocal: true);

  const SettingKey(this.storageKey, {required this.deviceLocal});

  /// The string used as the primary key in the `Settings` table.
  final String storageKey;

  /// Whether this key describes the device/user rather than the aquarium data,
  /// and so must survive a backup restore untouched.
  final bool deviceLocal;

  /// The storage keys of every device-local preference — restore preserves
  /// exactly these (see [AppDatabase.restoreFromBackup]).
  static Set<String> get deviceLocalKeys => {
    for (final k in values)
      if (k.deviceLocal) k.storageKey,
  };
}

/// Typed facade over the [AppDatabase] key/value `Settings` store. Cheap to
/// construct (just wraps the db), so screens can `Settings(db)` inline while
/// providers use the shared `settingsProvider`.
class AppSettings {
  const AppSettings(this._db);

  final AppDatabase _db;

  // --- generic primitives ----------------------------------------------------

  Stream<String?> _watch(SettingKey key) => _db.watchSetting(key.storageKey);
  Future<String?> _read(SettingKey key) => _db.getSetting(key.storageKey);
  Future<void> _write(SettingKey key, String? value) =>
      _db.setSetting(key.storageKey, value);

  /// The whole settings store as one live key/value map (T4). The settings
  /// providers derive every individual setting from this single query (via the
  /// static `decode*` functions below) instead of holding one
  /// `watchSingleOrNull` per key — a settings write re-runs one query, not ~14.
  Stream<Map<String, String?>> watchAll() => _db.watchAllSettings();

  // Each setting's raw-string decoding (including its default) lives in one
  // static `decode*` function, shared by the per-key `watch*` stream and the
  // map-based provider path — the two can't drift apart.

  // --- units -----------------------------------------------------------------

  static TempUnit decodeTempUnit(String? raw) => TempUnit.fromName(raw);
  Stream<TempUnit> watchTempUnit() =>
      _watch(SettingKey.tempUnit).map(decodeTempUnit);
  Future<void> setTempUnit(TempUnit unit) =>
      _write(SettingKey.tempUnit, unit.name);

  static SalinityUnit decodeSalinityUnit(String? raw) =>
      SalinityUnit.fromName(raw);
  Stream<SalinityUnit> watchSalinityUnit() =>
      _watch(SettingKey.salinityUnit).map(decodeSalinityUnit);
  Future<void> setSalinityUnit(SalinityUnit unit) =>
      _write(SettingKey.salinityUnit, unit.name);

  static VolumeUnit decodeVolumeUnit(String? raw) => VolumeUnit.fromName(raw);
  Stream<VolumeUnit> watchVolumeUnit() =>
      _watch(SettingKey.volumeUnit).map(decodeVolumeUnit);
  Future<void> setVolumeUnit(VolumeUnit unit) =>
      _write(SettingKey.volumeUnit, unit.name);

  // --- language --------------------------------------------------------------

  /// The stored language code ('system' / 'en' / 'cs' / …), defaulting to
  /// [kDefaultLocaleCode].
  static String decodeLocaleCode(String? raw) => raw ?? kDefaultLocaleCode;
  Stream<String> watchLocaleCode() =>
      _watch(SettingKey.locale).map(decodeLocaleCode);
  Future<void> setLocaleCode(String? code) => _write(SettingKey.locale, code);

  // --- chart range -----------------------------------------------------------

  static String decodeChartRange(String? raw) => raw ?? kDefaultChartRange;
  Stream<String> watchChartRange() =>
      _watch(SettingKey.chartRange).map(decodeChartRange);
  Future<void> setChartRange(String label) =>
      _write(SettingKey.chartRange, label);

  // --- trend -----------------------------------------------------------------

  static bool decodeTrendEnabled(String? raw) =>
      raw == null ? kTrendDefaultEnabled : raw == 'true';
  Stream<bool> watchTrendEnabled() =>
      _watch(SettingKey.trendEnabled).map(decodeTrendEnabled);
  Future<void> setTrendEnabled(bool enabled) =>
      _write(SettingKey.trendEnabled, enabled.toString());

  // Clamped: the settings dropdown only offers 3..10, but a hand-edited value
  // outside that range would crash the dropdown and — since T1 caps the
  // dashboard's readings feed per parameter — could silently starve
  // computeTrend of points.
  static int decodeTrendWindow(String? raw) =>
      (int.tryParse(raw ?? '') ?? kTrendDefaultWindow).clamp(
        kTrendMinWindow,
        kTrendMaxWindow,
      );
  Stream<int> watchTrendWindow() =>
      _watch(SettingKey.trendWindow).map(decodeTrendWindow);
  Future<void> setTrendWindow(int window) =>
      _write(SettingKey.trendWindow, window.toString());

  static int decodeTrendHorizon(String? raw) =>
      int.tryParse(raw ?? '') ?? kTrendDefaultHorizon;
  Stream<int> watchTrendHorizon() =>
      _watch(SettingKey.trendHorizon).map(decodeTrendHorizon);
  Future<void> setTrendHorizon(int days) =>
      _write(SettingKey.trendHorizon, days.toString());

  // --- health display --------------------------------------------------------

  static HealthDisplay decodeHealthDisplay(String? raw) =>
      HealthDisplay.fromName(raw);
  Stream<HealthDisplay> watchHealthDisplay() =>
      _watch(SettingKey.healthDisplay).map(decodeHealthDisplay);
  Future<void> setHealthDisplay(HealthDisplay display) =>
      _write(SettingKey.healthDisplay, display.name);

  // --- RO unit (U16) -----------------------------------------------------------

  /// Whether the reverse-osmosis unit feature is shown at all (default on):
  /// off hides the Actions-tab summary row and silences RO reminders. Purely
  /// a visibility preference — the stages and their history stay stored.
  static bool decodeRoUnitEnabled(String? raw) => raw == null || raw == 'true';
  Stream<bool> watchRoUnitEnabled() =>
      _watch(SettingKey.roUnitEnabled).map(decodeRoUnitEnabled);
  Future<bool> readRoUnitEnabled() async =>
      decodeRoUnitEnabled(await _read(SettingKey.roUnitEnabled));
  Future<void> setRoUnitEnabled(bool enabled) =>
      _write(SettingKey.roUnitEnabled, enabled.toString());

  static bool decodeMicroEnabled(String? raw) => raw == null || raw == 'true';

  /// The Microelements-screen quick filters (U17): hide zero readings
  /// (undetectable — unless zero is abnormal for the element) and show only
  /// elements needing attention. Both default off.
  static bool decodeMicroHideUndetectable(String? raw) => raw == 'true';
  Stream<bool> watchMicroHideUndetectable() =>
      _watch(SettingKey.microHideUndetectable).map(decodeMicroHideUndetectable);
  Future<void> setMicroHideUndetectable(bool enabled) =>
      _write(SettingKey.microHideUndetectable, enabled.toString());

  static bool decodeMicroAttentionOnly(String? raw) => raw == 'true';
  Stream<bool> watchMicroAttentionOnly() =>
      _watch(SettingKey.microAttentionOnly).map(decodeMicroAttentionOnly);
  Future<void> setMicroAttentionOnly(bool enabled) =>
      _write(SettingKey.microAttentionOnly, enabled.toString());

  Stream<bool> watchMicroEnabled() =>
      _watch(SettingKey.microEnabled).map(decodeMicroEnabled);
  Future<bool> readMicroEnabled() async =>
      decodeMicroEnabled(await _read(SettingKey.microEnabled));
  Future<void> setMicroEnabled(bool enabled) =>
      _write(SettingKey.microEnabled, enabled.toString());

  // --- feature tour ----------------------------------------------------------

  /// Whether the one-time top-bar tour has already been shown; unset reads as
  /// `false` so the tour runs once on a fresh install.
  static bool decodeTourSeen(String? raw) => raw == 'true';
  Stream<bool> watchTourSeen() =>
      _watch(SettingKey.tourSeen).map(decodeTourSeen);
  Future<void> setTourSeen(bool seen) =>
      _write(SettingKey.tourSeen, seen.toString());

  // --- automatic backup ------------------------------------------------------

  static bool decodeAutoBackupEnabled(String? raw) =>
      raw == null ? kAutoBackupDefaultEnabled : raw == 'true';
  Stream<bool> watchAutoBackupEnabled() =>
      _watch(SettingKey.autoBackupEnabled).map(decodeAutoBackupEnabled);
  Future<bool> readAutoBackupEnabled() async =>
      decodeAutoBackupEnabled(await _read(SettingKey.autoBackupEnabled));

  Future<void> setAutoBackupEnabled(bool enabled) =>
      _write(SettingKey.autoBackupEnabled, enabled.toString());

  static AutoBackupInterval decodeAutoBackupInterval(String? raw) =>
      AutoBackupInterval.fromName(raw);
  Stream<AutoBackupInterval> watchAutoBackupInterval() =>
      _watch(SettingKey.autoBackupInterval).map(decodeAutoBackupInterval);
  Future<AutoBackupInterval> readAutoBackupInterval() async =>
      decodeAutoBackupInterval(await _read(SettingKey.autoBackupInterval));
  Future<void> setAutoBackupInterval(AutoBackupInterval interval) =>
      _write(SettingKey.autoBackupInterval, interval.name);

  Future<int> readAutoBackupKeep() async =>
      int.tryParse(await _read(SettingKey.autoBackupKeep) ?? '') ??
      kAutoBackupDefaultKeep;

  /// When the most recent automatic or manual backup completed, or null if
  /// none has run yet (or the stored value is unparseable).
  static DateTime? decodeLastBackupAt(String? raw) => _parseEpochMillis(raw);
  Stream<DateTime?> watchLastBackupAt() =>
      _watch(SettingKey.lastAutoBackupAt).map(decodeLastBackupAt);
  Future<DateTime?> readLastBackupAt() async =>
      _parseEpochMillis(await _read(SettingKey.lastAutoBackupAt));
  Future<void> setLastBackupAt(DateTime when) => _write(
    SettingKey.lastAutoBackupAt,
    when.millisecondsSinceEpoch.toString(),
  );

  /// When the most recent backup attempt (automatic or manual) failed, or null
  /// if the latest attempt succeeded / none has failed yet. Cleared by every
  /// successful backup, so a non-null value always means "the backup you are
  /// counting on is not being written" (TODO #22).
  static DateTime? decodeLastBackupErrorAt(String? raw) =>
      _parseEpochMillis(raw);
  Stream<DateTime?> watchLastBackupErrorAt() =>
      _watch(SettingKey.lastBackupErrorAt).map(decodeLastBackupErrorAt);
  Future<void> setLastBackupErrorAt(DateTime? when) => _write(
    SettingKey.lastBackupErrorAt,
    when?.millisecondsSinceEpoch.toString(),
  );

  // --- cloud folder sync (U20) -------------------------------------------------

  /// Whether each backup is also pushed into the user-picked synced folder
  /// (default **off** — the feature needs a folder pick to be useful).
  static bool decodeCloudSyncEnabled(String? raw) => raw == 'true';
  Stream<bool> watchCloudSyncEnabled() =>
      _watch(SettingKey.cloudSyncEnabled).map(decodeCloudSyncEnabled);
  Future<bool> readCloudSyncEnabled() async =>
      decodeCloudSyncEnabled(await _read(SettingKey.cloudSyncEnabled));
  Future<void> setCloudSyncEnabled(bool enabled) =>
      _write(SettingKey.cloudSyncEnabled, enabled.toString());

  /// The picked folder's SAF tree uri (null = never picked). Opaque: only
  /// ever handed back to [CloudFolder] methods, never shown to the user.
  Future<String?> readCloudSyncFolderUri() =>
      _read(SettingKey.cloudSyncFolderUri);

  /// The picked folder's display name, for the Settings row.
  static String? decodeCloudSyncFolderName(String? raw) => raw;
  Stream<String?> watchCloudSyncFolderName() =>
      _watch(SettingKey.cloudSyncFolderName).map(decodeCloudSyncFolderName);

  /// Records a (re)picked folder. Clears the last-pushed hash so the next
  /// backup pushes unconditionally — the new folder starts empty of our
  /// files even when the data hasn't changed — and clears the stale
  /// stamps, which described the previous folder.
  Future<void> setCloudSyncFolder({
    required String uri,
    required String name,
  }) async {
    await _write(SettingKey.cloudSyncFolderUri, uri);
    await _write(SettingKey.cloudSyncFolderName, name);
    await _write(SettingKey.lastCloudSyncHash, null);
    await _write(SettingKey.lastCloudSyncAt, null);
    await _write(SettingKey.lastCloudSyncErrorAt, null);
  }

  /// When this device last successfully pushed a backup into the synced
  /// folder (null = never, or the folder was since re-picked).
  static DateTime? decodeLastCloudSyncAt(String? raw) => _parseEpochMillis(raw);
  Stream<DateTime?> watchLastCloudSyncAt() =>
      _watch(SettingKey.lastCloudSyncAt).map(decodeLastCloudSyncAt);
  Future<void> setLastCloudSyncAt(DateTime? when) => _write(
    SettingKey.lastCloudSyncAt,
    when?.millisecondsSinceEpoch.toString(),
  );

  /// When the most recent push attempt failed; cleared by the next
  /// successful push (same contract as [decodeLastBackupErrorAt]).
  static DateTime? decodeLastCloudSyncErrorAt(String? raw) =>
      _parseEpochMillis(raw);
  Stream<DateTime?> watchLastCloudSyncErrorAt() =>
      _watch(SettingKey.lastCloudSyncErrorAt).map(decodeLastCloudSyncErrorAt);
  Future<void> setLastCloudSyncErrorAt(DateTime? when) => _write(
    SettingKey.lastCloudSyncErrorAt,
    when?.millisecondsSinceEpoch.toString(),
  );

  /// Content hash of the last backup this device successfully pushed — the
  /// dirty-check that keeps an unchanged device from re-uploading (and from
  /// burying another device's genuinely newer file under an identical copy).
  /// Only ever written on a successful push, so a failed push retries on
  /// every subsequent backup until one succeeds.
  Future<String?> readLastCloudSyncHash() =>
      _read(SettingKey.lastCloudSyncHash);
  Future<void> setLastCloudSyncHash(String? hash) =>
      _write(SettingKey.lastCloudSyncHash, hash);

  // --- test sets (U9) ----------------------------------------------------------

  /// Last-used test set per tank, as tank id → [ReadingTemplate] id. A missing
  /// entry means "All"; a dangling id (the set was deleted, or ids changed in a
  /// restore) is simply not found by the UI and also falls back to "All".
  /// Stored as one JSON object (`{"1": 5}`) rather than one key per tank so the
  /// [SettingKey] registry stays a closed list.
  static Map<int, int> decodeLastReadingTemplates(String? raw) {
    if (raw == null) return const {};
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return {
          for (final e in v.entries)
            if (int.tryParse(e.key) != null && e.value is int)
              int.parse(e.key): e.value as int,
        };
      }
    } on FormatException {
      // Malformed stored value — treat as "no selections".
    }
    return const {};
  }

  Stream<Map<int, int>> watchLastReadingTemplates() =>
      _watch(SettingKey.lastReadingTemplate).map(decodeLastReadingTemplates);

  // --- reminders (U1/U2/U12) ---------------------------------------------------

  /// All three category switches default **off**: notifications are opt-in,
  /// and the first enable is what triggers the permission request.
  static bool decodeRemindersTesting(String? raw) => raw == 'true';
  Stream<bool> watchRemindersTesting() =>
      _watch(SettingKey.remindersTesting).map(decodeRemindersTesting);
  Future<bool> readRemindersTesting() async =>
      decodeRemindersTesting(await _read(SettingKey.remindersTesting));
  Future<void> setRemindersTesting(bool enabled) =>
      _write(SettingKey.remindersTesting, enabled.toString());

  static bool decodeRemindersDosing(String? raw) => raw == 'true';
  Stream<bool> watchRemindersDosing() =>
      _watch(SettingKey.remindersDosing).map(decodeRemindersDosing);
  Future<bool> readRemindersDosing() async =>
      decodeRemindersDosing(await _read(SettingKey.remindersDosing));
  Future<void> setRemindersDosing(bool enabled) =>
      _write(SettingKey.remindersDosing, enabled.toString());

  static bool decodeRemindersMaintenance(String? raw) => raw == 'true';
  Stream<bool> watchRemindersMaintenance() =>
      _watch(SettingKey.remindersMaintenance).map(decodeRemindersMaintenance);
  Future<bool> readRemindersMaintenance() async =>
      decodeRemindersMaintenance(await _read(SettingKey.remindersMaintenance));
  Future<void> setRemindersMaintenance(bool enabled) =>
      _write(SettingKey.remindersMaintenance, enabled.toString());

  /// Delivery time of day for testing/maintenance reminders (dosing reminders
  /// use each entry's own `doseTime`). Stored as `HH:mm`; malformed/unset
  /// values decode to the 09:00 default via the same strict parser the dosing
  /// schedule uses.
  static ({int hour, int minute}) decodeReminderTime(String? raw) =>
      parseDoseTime(raw) ?? kDefaultReminderTime;
  Stream<({int hour, int minute})> watchReminderTime() =>
      _watch(SettingKey.reminderTime).map(decodeReminderTime);
  Future<({int hour, int minute})> readReminderTime() async =>
      decodeReminderTime(await _read(SettingKey.reminderTime));
  Future<void> setReminderTime(int hour, int minute) => _write(
    SettingKey.reminderTime,
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  );

  // --- microelement views (U17) --------------------------------------------

  /// Active microelement view per tank, as tank id → view *token*
  /// (`preset:full`, `preset:faunaMarin`, or `view:<MicroViews id>`; see
  /// `domain/micro.dart`). A missing entry means the full list; a dangling
  /// custom-view token (view deleted, ids replaced by a restore) is simply
  /// not found by the UI and falls back to the full list too. Same
  /// one-JSON-object storage shape as [decodeLastReadingTemplates].
  static Map<int, String> decodeMicroViewSelections(String? raw) {
    if (raw == null) return const {};
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return {
          for (final e in v.entries)
            if (int.tryParse(e.key) != null && e.value is String)
              int.parse(e.key): e.value as String,
        };
      }
    } on FormatException {
      // Malformed stored value — treat as "no selections".
    }
    return const {};
  }

  Stream<Map<int, String>> watchMicroViewSelections() =>
      _watch(SettingKey.microView).map(decodeMicroViewSelections);

  /// Records [token] as the active micro view for [tankId]; null selects the
  /// full list (removes the entry).
  Future<void> setMicroView(int tankId, String? token) async {
    final map = Map<int, String>.of(
      decodeMicroViewSelections(await _read(SettingKey.microView)),
    );
    if (token == null) {
      map.remove(tankId);
    } else {
      map[tankId] = token;
    }
    await _write(
      SettingKey.microView,
      jsonEncode({for (final e in map.entries) '${e.key}': e.value}),
    );
  }

  /// Records [templateId] as the last-used test set for [tankId]; null selects
  /// "All" (removes the entry).
  Future<void> setLastReadingTemplate(int tankId, int? templateId) async {
    final map = Map<int, int>.of(
      decodeLastReadingTemplates(await _read(SettingKey.lastReadingTemplate)),
    );
    if (templateId == null) {
      map.remove(tankId);
    } else {
      map[tankId] = templateId;
    }
    await _write(
      SettingKey.lastReadingTemplate,
      jsonEncode({for (final e in map.entries) '${e.key}': e.value}),
    );
  }
}

DateTime? _parseEpochMillis(String? v) {
  final ms = int.tryParse(v ?? '');
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}
