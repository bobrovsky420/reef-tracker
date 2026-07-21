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
const kThemeModeKey = 'theme_mode';
const kTempUnitKey = 'temp_unit';
const kSalinityUnitKey = 'salinity_unit';
const kVolumeUnitKey = 'volume_unit';
const kLocaleKey = 'locale';
const kChartRangeKey = 'chart_range';
const kTrendEnabledKey = 'trend_enabled';
const kTrendWindowKey = 'trend_window';
const kTrendHorizonKey = 'trend_horizon';
const kHealthDisplayKey = 'health_display';
const kDashboardLayoutKey = 'dashboard_layout';
const kStabilityWindowKey = 'stability_window';
const kAiSummaryWeeksKey = 'ai_summary_weeks';
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
const kMicroViewKey = 'micro_view';
const kMicroHideUndetectableKey = 'micro_hide_undetectable';
const kMicroAttentionOnlyKey = 'micro_attention_only';
const kFreeAmmoniaHiddenKey = 'free_ammonia_hidden';
const kLegacyFreeSinceKey = 'legacy_free_since';
// Google Drive sync (U24). Deliberately NOT the removed U20 feature's
// `cloud_sync_*` names: 0.25.0 devices in the wild carry inert orphan rows
// under those keys, and reusing them could resurrect stale values. The
// `sync_<provider>_` shape leaves room for `sync_onedrive_*` etc. later.
const kSyncGdriveAccountKey = 'sync_gdrive_account';
// Hanna checker direct BLE (U33): the user's named method pre-selections
// ("Daily test", …), one JSON value.
const kHannaMethodSetsKey = 'hanna_method_sets';
const kSyncGdriveFolderIdKey = 'sync_gdrive_folder_id';
const kSyncGdriveLastPushedHashKey = 'sync_gdrive_last_pushed_hash';
const kSyncGdriveLastPushAtKey = 'sync_gdrive_last_push_at';
const kSyncGdriveLastErrorAtKey = 'sync_gdrive_last_error_at';
