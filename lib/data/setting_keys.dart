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
const kDoseCalcSalinityAdjustKey = 'dose_calc_salinity_adjust';
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
// Multi-device via cloud backups (U35): the filename of the last document
// this device pushed to — or restored from — the cloud (the cheap "is the
// newest cloud file ours?" lineage check), the newest foreign filename the
// user declined to restore (so the launch prompt doesn't nag every start),
// and the user-chosen name identifying this device on its uploads.
const kSyncGdriveLastPushedNameKey = 'sync_gdrive_last_pushed_name';
const kSyncGdriveDismissedNameKey = 'sync_gdrive_dismissed_name';
const kSyncDeviceNameKey = 'sync_device_name';
// Random id identifying the install that wrote this database (#62); paired
// with the backup-excluded `.install_id` file — see `install_id.dart`.
const kInstallFingerprintKey = 'install_fingerprint';
// Experimental-features master switch (U33/U34): off (the default) hides
// every experimental surface — settings rows, overflow-menu entries, FAB.
const kExperimentalEnabledKey = 'experimental_enabled';
// Opt-in quick camera-scan button above "Add reading" (U34): most users
// don't own a pocket checker, so the FAB space is off by default.
const kHannaScanFabKey = 'hanna_scan_fab';
