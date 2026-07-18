import 'dart:convert';

import '../domain/reminders.dart';
import '../domain/stability_score.dart';
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

/// "Ask your AI" summary window (U27): the week counts the pre-share sheet
/// offers, and the default. Bounded on purpose — an unbounded history dump
/// would blow past chat context limits and drown the signal.
const List<int> kAiSummaryWeekChoices = [4, 8, 12];
const int kAiSummaryDefaultWeeks = 8;

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

/// How the main dashboard (Measurements tab) organizes its parameter/ratio
/// cards. [grouped] is the redesign's categorized layout with fixed section
/// headers (REDESIGN #6) and is where all future dashboard enhancements land;
/// [classic] is the original single user-ordered grid mixing measurements and
/// ratios. The choice also drives the ordering (and section captions) of the
/// compare view and the Manage Parameters list, so the whole tab stays
/// coherent.
enum DashboardLayout {
  /// The original flat, fully user-ordered grid (pre-#6 behavior).
  classic,

  /// The categorized layout with Core chemistry / Nutrients / Ratios /
  /// Environment sections (the default, and the target of future work).
  grouped;

  /// Parses a stored setting value, defaulting to [grouped] when
  /// missing/unknown.
  static DashboardLayout fromName(String? name) {
    for (final v in DashboardLayout.values) {
      if (v.name == name) return v;
    }
    return DashboardLayout.grouped;
  }
}

/// Which edition of the app this install is entitled to (U19 phase 0).
/// Derived from [SettingKey.legacyFreeSince]; a `pro` value joins when the
/// paid tier ships.
enum AppEdition {
  /// The regular edition — reachable only once the Pro build has shipped
  /// (until then every install is seeded as [founder]).
  standard,

  /// Early adopter: installed while everything was free; the features
  /// available at the monetization cutoff stay free for them forever.
  founder,
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
  // The dashboard layout (grouped vs classic, REDESIGN #6) is a display
  // preference like healthDisplay: device-local, default grouped.
  dashboardLayout(kDashboardLayoutKey, deviceLocal: true),
  stabilityWindow(kStabilityWindowKey, deviceLocal: true),
  aiSummaryWeeks(kAiSummaryWeeksKey, deviceLocal: true),
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
  // The early-adopter ("Founder's Edition") marker for the future paid tier
  // (U19 phase 0): presence ⇒ this user installed while everything was free
  // and keeps today's features free forever. NOT device-local — the status
  // must travel with the aquarium data to a new device via backup restore.
  // It is additionally *sticky* on restore (see [AppDatabase.restoreFromBackup]
  // `stickySettingKeys`): a restore may add the status, never remove it —
  // once the seeding stops shipping, nothing could ever re-seed a wiped
  // marker. Seeded by every pre-Pro version on launch (`seedLegacyFreeSince`);
  // the Pro build must delete the seeder and only read the key.
  legacyFreeSince(kLegacyFreeSinceKey, deviceLocal: false),
  // Google Drive sync state (U24) — all device-local: sync identity is
  // per-device by nature (restoring another device's backup must not
  // silently start pushing to, or claim the push history of, that device's
  // account), and the pushed-hash/echo-suppression bookkeeping describes
  // *this* device's relationship to the cloud folder.
  syncGdriveAccount(kSyncGdriveAccountKey, deviceLocal: true),
  syncGdriveFolderId(kSyncGdriveFolderIdKey, deviceLocal: true),
  syncGdriveLastPushedHash(kSyncGdriveLastPushedHashKey, deviceLocal: true),
  syncGdriveLastPushAt(kSyncGdriveLastPushAtKey, deviceLocal: true),
  syncGdriveLastErrorAt(kSyncGdriveLastErrorAtKey, deviceLocal: true);

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

  // --- stability window (U26) -------------------------------------------------

  /// Whitelisted to [kStabilityWindowChoices] (not clamped): the settings
  /// dropdown crashes on a value it doesn't offer, so a hand-edited "45"
  /// falls back to the default rather than crashing Settings.
  static int decodeStabilityWindow(String? raw) {
    final v = int.tryParse(raw ?? '');
    return kStabilityWindowChoices.contains(v) ? v! : kStabilityWindowDays;
  }

  Stream<int> watchStabilityWindow() =>
      _watch(SettingKey.stabilityWindow).map(decodeStabilityWindow);
  Future<void> setStabilityWindow(int days) =>
      _write(SettingKey.stabilityWindow, days.toString());

  // --- AI summary window (U27) -------------------------------------------------

  /// Whitelisted like [decodeStabilityWindow]: the pre-share sheet's chips
  /// only offer [kAiSummaryWeekChoices], so an unknown stored value falls
  /// back to the default instead of selecting nothing.
  static int decodeAiSummaryWeeks(String? raw) {
    final v = int.tryParse(raw ?? '');
    return kAiSummaryWeekChoices.contains(v) ? v! : kAiSummaryDefaultWeeks;
  }

  Stream<int> watchAiSummaryWeeks() =>
      _watch(SettingKey.aiSummaryWeeks).map(decodeAiSummaryWeeks);
  Future<void> setAiSummaryWeeks(int weeks) =>
      _write(SettingKey.aiSummaryWeeks, weeks.toString());

  // --- health display --------------------------------------------------------

  static HealthDisplay decodeHealthDisplay(String? raw) =>
      HealthDisplay.fromName(raw);
  Stream<HealthDisplay> watchHealthDisplay() =>
      _watch(SettingKey.healthDisplay).map(decodeHealthDisplay);
  Future<void> setHealthDisplay(HealthDisplay display) =>
      _write(SettingKey.healthDisplay, display.name);

  // --- dashboard layout (REDESIGN #6) ----------------------------------------

  static DashboardLayout decodeDashboardLayout(String? raw) =>
      DashboardLayout.fromName(raw);
  Stream<DashboardLayout> watchDashboardLayout() =>
      _watch(SettingKey.dashboardLayout).map(decodeDashboardLayout);
  Future<void> setDashboardLayout(DashboardLayout layout) =>
      _write(SettingKey.dashboardLayout, layout.name);

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

  // --- edition / early-adopter marker (U19 phase 0) ----------------------------

  /// The app version that first seeded the early-adopter marker on this
  /// install (e.g. "0.26.0"), or null when the marker is absent. Presence —
  /// not the value — is what grants [AppEdition.founder]; the version is kept
  /// as an audit trail (a version string, not a date, so a device clock can't
  /// fake early adoption once seeding stops shipping).
  static String? decodeLegacyFreeSince(String? raw) =>
      (raw == null || raw.isEmpty) ? null : raw;

  static AppEdition decodeEdition(String? raw) =>
      decodeLegacyFreeSince(raw) == null
      ? AppEdition.standard
      : AppEdition.founder;

  Stream<AppEdition> watchEdition() =>
      _watch(SettingKey.legacyFreeSince).map(decodeEdition);

  /// Stamps the early-adopter marker with [version] if — and only if — it has
  /// never been written; an existing value (even from an older version) is
  /// never overwritten. Called on every launch of a pre-Pro build; the Pro
  /// build must NOT call this.
  Future<void> seedLegacyFreeSince(String version) async {
    final existing = decodeLegacyFreeSince(
      await _read(SettingKey.legacyFreeSince),
    );
    if (existing == null) {
      await _write(SettingKey.legacyFreeSince, version);
    }
  }

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

  // --- Google Drive sync (U24) -------------------------------------------------

  /// The Google account email backups are pushed to, or null when Drive sync
  /// is not connected. Presence of the account IS the "sync enabled" state —
  /// there is no separate toggle.
  static String? decodeSyncGdriveAccount(String? raw) =>
      (raw == null || raw.isEmpty) ? null : raw;
  Stream<String?> watchSyncGdriveAccount() =>
      _watch(SettingKey.syncGdriveAccount).map(decodeSyncGdriveAccount);
  Future<String?> readSyncGdriveAccount() async =>
      decodeSyncGdriveAccount(await _read(SettingKey.syncGdriveAccount));
  Future<void> setSyncGdriveAccount(String? email) =>
      _write(SettingKey.syncGdriveAccount, email);

  /// Cached Drive id of the app's backup folder; re-resolved (and re-created
  /// if the user deleted it) by the sync engine when stale.
  Future<String?> readSyncGdriveFolderId() =>
      _read(SettingKey.syncGdriveFolderId);
  Future<void> setSyncGdriveFolderId(String? id) =>
      _write(SettingKey.syncGdriveFolderId, id);

  /// Content hash (see `backupContentHash`) of the last document pushed to —
  /// or restored from — Drive: the dirty gate that keeps an unchanged device
  /// from re-uploading, and the echo-suppression marker after a restore.
  Future<String?> readSyncGdriveLastPushedHash() =>
      _read(SettingKey.syncGdriveLastPushedHash);
  Future<void> setSyncGdriveLastPushedHash(String? hash) =>
      _write(SettingKey.syncGdriveLastPushedHash, hash);

  static DateTime? decodeSyncGdriveLastPushAt(String? raw) =>
      _parseEpochMillis(raw);
  Stream<DateTime?> watchSyncGdriveLastPushAt() =>
      _watch(SettingKey.syncGdriveLastPushAt).map(decodeSyncGdriveLastPushAt);
  Future<void> setSyncGdriveLastPushAt(DateTime? when) => _write(
    SettingKey.syncGdriveLastPushAt,
    when?.millisecondsSinceEpoch.toString(),
  );

  /// When the most recent push attempt failed (provider rejection or dead
  /// grant — being offline is not recorded), or null if the latest attempt
  /// succeeded. Same contract as [decodeLastBackupErrorAt]: cleared by every
  /// successful push.
  static DateTime? decodeSyncGdriveLastErrorAt(String? raw) =>
      _parseEpochMillis(raw);
  Stream<DateTime?> watchSyncGdriveLastErrorAt() =>
      _watch(SettingKey.syncGdriveLastErrorAt).map(decodeSyncGdriveLastErrorAt);
  Future<void> setSyncGdriveLastErrorAt(DateTime? when) => _write(
    SettingKey.syncGdriveLastErrorAt,
    when?.millisecondsSinceEpoch.toString(),
  );

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
