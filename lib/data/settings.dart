import '../domain/trend.dart';
import '../domain/units.dart';
import 'database.dart';

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

// --- Key strings (the persisted names; never change without a migration) -----

const kActiveTankKey = 'active_tank_id';
const kTempUnitKey = 'temp_unit';
const kSalinityUnitKey = 'salinity_unit';
const kVolumeUnitKey = 'volume_unit';
const kLocaleKey = 'locale';
const kChartRangeKey = 'chart_range';
const kTrendEnabledKey = 'trend_enabled';
const kTrendWindowKey = 'trend_window';
const kTrendHorizonKey = 'trend_horizon';
const kHealthDisplayKey = 'health_display';
const kTourSeenKey = 'tour_v1_seen';
const kAutoBackupEnabledKey = 'auto_backup_enabled';
const kAutoBackupIntervalKey = 'auto_backup_interval';
const kAutoBackupKeepKey = 'auto_backup_keep';
const kLastAutoBackupAtKey = 'last_auto_backup_at';
const kLastBackupErrorAtKey = 'last_backup_error_at';

// --- Non-key defaults --------------------------------------------------------

/// Locale setting sentinel meaning "follow the system locale".
const kDefaultLocaleCode = 'system';

/// Default history-chart range label when none has been chosen.
const kDefaultChartRange = '30d';

/// Defaults applied when the corresponding auto-backup setting is unset.
const bool kAutoBackupDefaultEnabled = true;
const int kAutoBackupDefaultKeep = 5;

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
  lastBackupErrorAt(kLastBackupErrorAtKey, deviceLocal: true);

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

  // --- units -----------------------------------------------------------------

  Stream<TempUnit> watchTempUnit() =>
      _watch(SettingKey.tempUnit).map(TempUnit.fromName);
  Future<void> setTempUnit(TempUnit unit) =>
      _write(SettingKey.tempUnit, unit.name);

  Stream<SalinityUnit> watchSalinityUnit() =>
      _watch(SettingKey.salinityUnit).map(SalinityUnit.fromName);
  Future<void> setSalinityUnit(SalinityUnit unit) =>
      _write(SettingKey.salinityUnit, unit.name);

  Stream<VolumeUnit> watchVolumeUnit() =>
      _watch(SettingKey.volumeUnit).map(VolumeUnit.fromName);
  Future<void> setVolumeUnit(VolumeUnit unit) =>
      _write(SettingKey.volumeUnit, unit.name);

  // --- language --------------------------------------------------------------

  /// The stored language code ('system' / 'en' / 'cs' / …), defaulting to
  /// [kDefaultLocaleCode].
  Stream<String> watchLocaleCode() =>
      _watch(SettingKey.locale).map((v) => v ?? kDefaultLocaleCode);
  Future<void> setLocaleCode(String? code) =>
      _write(SettingKey.locale, code);

  // --- chart range -----------------------------------------------------------

  Stream<String> watchChartRange() =>
      _watch(SettingKey.chartRange).map((v) => v ?? kDefaultChartRange);
  Future<void> setChartRange(String label) =>
      _write(SettingKey.chartRange, label);

  // --- trend -----------------------------------------------------------------

  Stream<bool> watchTrendEnabled() => _watch(SettingKey.trendEnabled)
      .map((v) => v == null ? kTrendDefaultEnabled : v == 'true');
  Future<void> setTrendEnabled(bool enabled) =>
      _write(SettingKey.trendEnabled, enabled.toString());

  Stream<int> watchTrendWindow() => _watch(SettingKey.trendWindow)
      .map((v) => int.tryParse(v ?? '') ?? kTrendDefaultWindow);
  Future<void> setTrendWindow(int window) =>
      _write(SettingKey.trendWindow, window.toString());

  Stream<int> watchTrendHorizon() => _watch(SettingKey.trendHorizon)
      .map((v) => int.tryParse(v ?? '') ?? kTrendDefaultHorizon);
  Future<void> setTrendHorizon(int days) =>
      _write(SettingKey.trendHorizon, days.toString());

  // --- health display --------------------------------------------------------

  Stream<HealthDisplay> watchHealthDisplay() =>
      _watch(SettingKey.healthDisplay).map(HealthDisplay.fromName);
  Future<void> setHealthDisplay(HealthDisplay display) =>
      _write(SettingKey.healthDisplay, display.name);

  // --- feature tour ----------------------------------------------------------

  /// Whether the one-time top-bar tour has already been shown; unset reads as
  /// `false` so the tour runs once on a fresh install.
  Stream<bool> watchTourSeen() =>
      _watch(SettingKey.tourSeen).map((v) => v == 'true');
  Future<void> setTourSeen(bool seen) =>
      _write(SettingKey.tourSeen, seen.toString());

  // --- automatic backup ------------------------------------------------------

  Stream<bool> watchAutoBackupEnabled() => _watch(SettingKey.autoBackupEnabled)
      .map((v) => v == null ? kAutoBackupDefaultEnabled : v == 'true');
  Future<bool> readAutoBackupEnabled() async {
    final v = await _read(SettingKey.autoBackupEnabled);
    return v == null ? kAutoBackupDefaultEnabled : v == 'true';
  }

  Future<void> setAutoBackupEnabled(bool enabled) =>
      _write(SettingKey.autoBackupEnabled, enabled.toString());

  Stream<AutoBackupInterval> watchAutoBackupInterval() =>
      _watch(SettingKey.autoBackupInterval).map(AutoBackupInterval.fromName);
  Future<AutoBackupInterval> readAutoBackupInterval() async =>
      AutoBackupInterval.fromName(await _read(SettingKey.autoBackupInterval));
  Future<void> setAutoBackupInterval(AutoBackupInterval interval) =>
      _write(SettingKey.autoBackupInterval, interval.name);

  Future<int> readAutoBackupKeep() async =>
      int.tryParse(await _read(SettingKey.autoBackupKeep) ?? '') ??
      kAutoBackupDefaultKeep;

  /// When the most recent automatic or manual backup completed, or null if
  /// none has run yet (or the stored value is unparseable).
  Stream<DateTime?> watchLastBackupAt() =>
      _watch(SettingKey.lastAutoBackupAt).map(_parseEpochMillis);
  Future<DateTime?> readLastBackupAt() async =>
      _parseEpochMillis(await _read(SettingKey.lastAutoBackupAt));
  Future<void> setLastBackupAt(DateTime when) => _write(
      SettingKey.lastAutoBackupAt, when.millisecondsSinceEpoch.toString());

  /// When the most recent backup attempt (automatic or manual) failed, or null
  /// if the latest attempt succeeded / none has failed yet. Cleared by every
  /// successful backup, so a non-null value always means "the backup you are
  /// counting on is not being written" (TODO #22).
  Stream<DateTime?> watchLastBackupErrorAt() =>
      _watch(SettingKey.lastBackupErrorAt).map(_parseEpochMillis);
  Future<void> setLastBackupErrorAt(DateTime? when) => _write(
      SettingKey.lastBackupErrorAt, when?.millisecondsSinceEpoch.toString());
}

DateTime? _parseEpochMillis(String? v) {
  final ms = int.tryParse(v ?? '');
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}
