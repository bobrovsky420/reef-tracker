/// The persisted `Settings` key strings — never change without a migration.
///
/// Lives in its own leaf file (no imports) so both [Settings]-facade code
/// (`settings.dart`) and `database.dart` (whose active-tank helpers predate the
/// facade) can share one definition without an import cycle: `settings.dart`
/// imports `database.dart`, so the constants can't live in either (#55).
/// `settings.dart` re-exports everything here; import that instead unless you
/// are inside `database.dart` itself.
library;

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
const kLastReadingTemplateKey = 'last_reading_template';
const kRemindersTestingKey = 'reminders_testing';
const kRemindersDosingKey = 'reminders_dosing';
const kRemindersMaintenanceKey = 'reminders_maintenance';
const kReminderTimeKey = 'reminder_time';
const kRoSeededKey = 'ro_stages_seeded';
const kRoUnitEnabledKey = 'ro_unit_enabled';
const kMicroEnabledKey = 'micro_enabled';
