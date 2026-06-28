// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Measurements';

  @override
  String get settings => 'Settings';

  @override
  String get manageParameters => 'Manage parameters';

  @override
  String get compareView => 'Compare graphs';

  @override
  String get gridView => 'Grid view';

  @override
  String get addReading => 'Add reading';

  @override
  String get addAquarium => 'Add aquarium';

  @override
  String get manageTanks => 'Manage tanks';

  @override
  String get chooseParameters => 'Choose parameters';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get apply => 'Apply';

  @override
  String get change => 'Change';

  @override
  String errorWith(Object message) {
    return 'Error: $message';
  }

  @override
  String get welcomeTitle => 'Welcome to ReefTracker';

  @override
  String get welcomeBody =>
      'Create your first aquarium to start tracking water parameters.';

  @override
  String get noParamsTracked =>
      'No parameters are being tracked for this tank.';

  @override
  String get noReadings => 'No readings';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinAgo(int count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get aquariums => 'Aquariums';

  @override
  String get noAquariumsYet => 'No aquariums yet.';

  @override
  String get makeActive => 'Make active';

  @override
  String get edit => 'Edit';

  @override
  String deleteTankTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteTankBody =>
      'This permanently deletes the aquarium and all of its readings.';

  @override
  String get newAquarium => 'New aquarium';

  @override
  String get editAquarium => 'Edit aquarium';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'e.g. Living room reef';

  @override
  String get enterAName => 'Enter a name';

  @override
  String get setupType => 'Setup type';

  @override
  String get presetSeedNote =>
      'Default parameters and zone boundaries will be set up for this setup type. You can fine-tune them anytime.';

  @override
  String get volumeOptional => 'Volume (optional)';

  @override
  String get createAquarium => 'Create aquarium';

  @override
  String litersSuffix(Object value) {
    return '$value L';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Start date';

  @override
  String get notSet => 'Not set';

  @override
  String get setDate => 'Set';

  @override
  String get clear => 'Clear';

  @override
  String sinceDate(Object date) {
    return 'since $date';
  }

  @override
  String get parameters => 'Parameters';

  @override
  String get noActiveAquarium => 'No active aquarium.';

  @override
  String reapplyPreset(Object type) {
    return 'Re-apply $type preset';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Re-apply $type preset?';
  }

  @override
  String get reapplyPresetBody =>
      'This overwrites the green/amber/red boundaries of all tracked parameters with the preset defaults. Your readings are kept.';

  @override
  String get presetApplied => 'Preset applied.';

  @override
  String get noBoundariesSet => 'No boundaries set';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  red <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Edit zones';

  @override
  String get addParameter => 'Add parameter';

  @override
  String get allParametersAdded => 'All parameters are already added.';

  @override
  String unitWithValue(Object unit) {
    return 'Unit: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Set in Settings. Boundaries below use this unit.';

  @override
  String get unit => 'Unit';

  @override
  String get boundAmberLow => 'Red below (amber low)';

  @override
  String get boundGreenLow => 'Green from (OK low)';

  @override
  String get boundGreenHigh => 'Green to (OK high)';

  @override
  String get boundAmberHigh => 'Red above (amber high)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Values are in $unit. Leave a field blank to mean \"no limit on that side\".';
  }

  @override
  String get enterANumber => 'Enter a number';

  @override
  String get boundsOrderError =>
      'Boundaries must increase: amber low ≤ green low ≤ green high ≤ amber high.';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get saveReadings => 'Save readings';

  @override
  String invalidNumberFor(Object name) {
    return 'Invalid number for $name';
  }

  @override
  String get enterAtLeastOneValue => 'Enter at least one value.';

  @override
  String savedReadings(int count) {
    return 'Saved $count reading(s).';
  }

  @override
  String get noTrackedToRecord => 'No tracked parameters to record.';

  @override
  String get rangeWeek => '7d';

  @override
  String get rangeMonth => '30d';

  @override
  String get rangeQuarter => '90d';

  @override
  String get rangeAll => 'All';

  @override
  String get noReadingsInRange => 'No readings in this range.';

  @override
  String get editMeasurement => 'Edit measurement';

  @override
  String get deleteMeasurementTitle => 'Delete measurement?';

  @override
  String get deleteMeasurementBody => 'This permanently deletes this value.';

  @override
  String get deleteTogetherTitle => 'Delete measurement';

  @override
  String deleteTogetherBody(int count) {
    return 'This value was entered together with $count other measurement(s). Delete only this value, or all values entered together?';
  }

  @override
  String get deleteOnlyThis => 'Only this value';

  @override
  String get deleteAllTogether => 'All together';

  @override
  String get editTogetherTitle => 'Update measurement time';

  @override
  String editTogetherBody(int count) {
    return 'This value was entered together with $count other measurement(s). Update the time for only this value, or all values entered together?';
  }

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'PO₄ : NO₃ ratio';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Mg : Ca ratio';

  @override
  String get ratioNoData => 'Record both parameters to see their ratio.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Zone limits use $metric, the value shown on the card.';
  }

  @override
  String get waterChanges => 'Water changes';

  @override
  String get recordWaterChange => 'Record water change';

  @override
  String get amountLitersOptional => 'Amount (optional)';

  @override
  String get noWaterChanges => 'No water changes yet.';

  @override
  String get amountNotRecorded => 'Amount not recorded';

  @override
  String get deleteWaterChangeTitle => 'Delete water change?';

  @override
  String get deleteWaterChangeBody =>
      'This permanently deletes this water change.';

  @override
  String get actions => 'Actions';

  @override
  String get noActions => 'No actions yet.';

  @override
  String get addAction => 'Add action';

  @override
  String get waterChange => 'Water change';

  @override
  String get carbonChange => 'Carbon change';

  @override
  String get recordCarbonChange => 'Record carbon change';

  @override
  String get weightOptional => 'Weight (optional)';

  @override
  String get weightNotRecorded => 'Weight not recorded';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get deleteCarbonChangeTitle => 'Delete carbon change?';

  @override
  String get deleteCarbonChangeBody =>
      'This permanently deletes this carbon change.';

  @override
  String get equipmentCleaning => 'Equipment cleaning';

  @override
  String get recordEquipmentCleaning => 'Record equipment cleaning';

  @override
  String get deleteEquipmentCleaningTitle => 'Delete equipment cleaning?';

  @override
  String get deleteEquipmentCleaningBody =>
      'This permanently deletes this equipment cleaning.';

  @override
  String get dosing => 'Dosing';

  @override
  String get addSupplement => 'Add supplement';

  @override
  String get noDosing => 'No supplements yet.';

  @override
  String get noDosingHint =>
      'Add the supplements you dose this tank — vendor, product, and optionally dosage and schedule.';

  @override
  String get dosingNoDosage => 'No dosage set';

  @override
  String get deleteDosingTitle => 'Remove supplement?';

  @override
  String get deleteDosingBody =>
      'This removes this supplement from the dosing plan.';

  @override
  String get dosingNew => 'Add supplement';

  @override
  String get dosingEdit => 'Edit supplement';

  @override
  String get dosingVendor => 'Vendor';

  @override
  String get dosingVendorName => 'Vendor name';

  @override
  String get dosingProduct => 'Product';

  @override
  String get dosingProductName => 'Product name';

  @override
  String get dosingElement => 'Element';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Other…';

  @override
  String get dosingDosageOptional => 'Dosage (optional)';

  @override
  String get dosingAmount => 'Amount';

  @override
  String get dosingUnit => 'Unit';

  @override
  String get dosingBasis => 'Basis';

  @override
  String get dosingPerDay => 'per day';

  @override
  String get dosingPerDose => 'per dose';

  @override
  String get dosingSchedule => 'Schedule';

  @override
  String get dosingFrequency => 'Frequency';

  @override
  String get dosingFreqNone => 'None';

  @override
  String get dosingFreqDaily => 'Daily';

  @override
  String get dosingFreqEveryNDays => 'Every N days';

  @override
  String get dosingFreqWeekly => 'Weekly';

  @override
  String get dosingIntervalDays => 'Interval (days)';

  @override
  String dosingEveryDaysN(Object n) {
    return 'Every $n days';
  }

  @override
  String get dosingTimeOptional => 'Time (optional)';

  @override
  String get unitsSection => 'Units';

  @override
  String get toolsSection => 'Tools';

  @override
  String get aboutSection => 'About';

  @override
  String get languageSection => 'Language';

  @override
  String get temperature => 'Temperature';

  @override
  String get salinity => 'Salinity';

  @override
  String get volume => 'Volume';

  @override
  String get unitUsedAcrossApp => 'Unit used across the app';

  @override
  String get salinityCalculator => 'Salinity calculator';

  @override
  String get salinityCalculatorSubtitle =>
      'Convert ppt ↔ specific gravity (SG)';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupExportSubtitle =>
      'Save all aquariums and readings to a file';

  @override
  String get backupImport => 'Restore from backup';

  @override
  String get backupImportSubtitle => 'Replace all data with a backup file';

  @override
  String get backupRestoreConfirmTitle => 'Restore backup?';

  @override
  String get backupRestoreConfirmBody =>
      'This replaces all current aquariums, parameters, and readings with the contents of the backup file. This cannot be undone.';

  @override
  String get restore => 'Restore';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupExportFailed => 'Could not export the backup';

  @override
  String get backupImportFailed => 'Could not restore the backup';

  @override
  String get backupInvalidFile => 'That file isn\'t a valid ReefTracker backup';

  @override
  String get autoBackupTitle => 'Automatic backup';

  @override
  String get autoBackupSubtitle =>
      'Keep recent copies of your data on this device';

  @override
  String get autoBackupFrequency => 'Frequency';

  @override
  String get autoBackupDaily => 'Daily';

  @override
  String get autoBackupWeekly => 'Weekly';

  @override
  String get manageBackups => 'Manage backups';

  @override
  String get manageBackupsSubtitle =>
      'View, restore, or share automatic backups';

  @override
  String get backupsScreenTitle => 'Automatic backups';

  @override
  String get noAutoBackups => 'No automatic backups yet';

  @override
  String get noAutoBackupsHint =>
      'A backup is saved automatically while you use the app.';

  @override
  String get share => 'Share';

  @override
  String get backupDeleteConfirmTitle => 'Delete backup?';

  @override
  String get backupDeleteConfirmBody =>
      'This permanently removes this backup file from your device.';

  @override
  String get aboutAppName => 'About ReefTracker';

  @override
  String get aboutDescription =>
      'Offline reef aquarium parameter tracker with history, time graphs, and green/amber/red health zones.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languagePolish => 'Polski';

  @override
  String get calculatorIntro =>
      'Convert between practical salinity (ppt) and specific gravity (SG). Type in either field.';

  @override
  String get specificGravity => 'Specific gravity';

  @override
  String get referencePoints => 'Reference points';

  @override
  String get refSeawater => '• Natural seawater ≈ 35 ppt ≈ 1.0264 SG';

  @override
  String get refReefTarget => '• Typical reef target ≈ 35 ppt (1.025–1.027 SG)';

  @override
  String get refFormulaNote =>
      'SG is referenced at 25 °C. Conversion is a linear approximation: SG = 1 + ppt × 0.0264/35.';

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Attention';

  @override
  String get zoneActNow => 'Act now';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Fish-only / FOWLR';

  @override
  String get setupSoft => 'Soft coral';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Mixed reef';

  @override
  String get paramTemperature => 'Temperature';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Salinity';

  @override
  String get paramAlkalinity => 'Alkalinity';

  @override
  String get paramCalcium => 'Calcium (Ca)';

  @override
  String get paramMagnesium => 'Magnesium (Mg)';

  @override
  String get paramNitrate => 'Nitrate (NO₃)';

  @override
  String get paramPhosphate => 'Phosphate (PO₄)';

  @override
  String get paramAmmonia => 'Ammonia (NH₃/₄)';

  @override
  String get paramNitrite => 'Nitrite (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Potassium';

  @override
  String get paramStrontium => 'Strontium';

  @override
  String get paramIodine => 'Iodine';

  @override
  String get helpTemperature =>
      'Water temperature. Stability matters more than the exact value.';

  @override
  String get helpSalinity => 'Specific gravity. ~1.026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Carbonate hardness. Keep stable — avoid swings.';

  @override
  String get helpNitrate =>
      'A nutrient. Corals need a little; too much fuels algae.';

  @override
  String get helpAmmonia =>
      'Toxic. Should read effectively zero in a cycled tank.';
}
