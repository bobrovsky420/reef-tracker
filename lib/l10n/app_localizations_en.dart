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
  String get moreOptions => 'More options';

  @override
  String get tourTankTitle => 'Your aquariums';

  @override
  String get tourTankDesc =>
      'Tap here to switch between aquariums or add a new one.';

  @override
  String get tourCompareTitle => 'Compare view';

  @override
  String get tourCompareDesc =>
      'Switch between the parameter cards and stacked comparison graphs.';

  @override
  String get tourParamsTitle => 'Manage parameters';

  @override
  String get tourParamsDesc =>
      'Choose which water parameters to track and set their target ranges.';

  @override
  String get tourDosingHistoryTitle => 'Dosing history';

  @override
  String get tourDosingHistoryDesc =>
      'Review every past and current dose period, and remove a record entered by mistake.';

  @override
  String get tourDoseCalcTitle => 'Dose calculator';

  @override
  String get tourDoseCalcDesc =>
      'On the Dosing tab, open the calculator to estimate the daily dose that keeps an element steady.';

  @override
  String get tourNext => 'Next';

  @override
  String get tourDone => 'Got it';

  @override
  String get tourSkip => 'Skip';

  @override
  String get replayTour => 'Replay tour';

  @override
  String get replayTourSubtitle => 'Show the top-bar tips again';

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
  String get stop => 'Stop';

  @override
  String get apply => 'Apply';

  @override
  String get change => 'Change';

  @override
  String get undo => 'Undo';

  @override
  String get itemDeleted => 'Deleted';

  @override
  String get reorder => 'Reorder';

  @override
  String errorWith(Object message) {
    return 'Error: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Couldn\'t save: $error';
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
  String get dashSectionCoreChemistry => 'Core chemistry';

  @override
  String get dashSectionNutrients => 'Nutrients';

  @override
  String get dashSectionRatios => 'Ratios';

  @override
  String get dashSectionEnvironment => 'Environment';

  @override
  String gaugeIdealRange(String min, String max) {
    return 'ideal $min–$max';
  }

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
  String get active => 'Active';

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
  String tankDeleted(Object name) {
    return 'Deleted \"$name\"';
  }

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
  String get vendorOptional => 'Vendor (optional)';

  @override
  String get modelOptional => 'Model (optional)';

  @override
  String get notesOptional => 'Notes (optional)';

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
      'This overwrites the green/amber/red boundaries of all tracked parameters: dashboard parameters get the aquarium-type preset values, microelements their built-in defaults. Your readings are kept.';

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
  String get sectionSafeRanges => 'Safe ranges';

  @override
  String get sectionDose => 'Dose';

  @override
  String get boundsOrderError =>
      'Boundaries must increase: amber low ≤ green low ≤ green high ≤ amber high.';

  @override
  String get boundsPairError =>
      'Each amber boundary needs its matching green boundary on the same side.';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get saveReadings => 'Save readings';

  @override
  String invalidNumberFor(Object name) {
    return 'Invalid number for $name';
  }

  @override
  String get invalidVolume => 'Enter a valid positive volume.';

  @override
  String get invalidPositiveNumber => 'Enter a positive number.';

  @override
  String get invalidIntervalDays => 'Enter a whole number of days (1 or more).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: this value is not physically possible.';
  }

  @override
  String get impossibleValue => 'This value is not physically possible.';

  @override
  String get implausibleTitle => 'Unusual values';

  @override
  String get implausibleIntro =>
      'The following is outside the typical range. Check for a typo before saving.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (typical $min–$max)';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get enterAtLeastOneValue => 'Enter at least one value.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count readings.',
      one: 'Saved 1 reading.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'No tracked parameters to record.';

  @override
  String get testSetAll => 'All';

  @override
  String get newTestSet => 'New test set';

  @override
  String get editTestSet => 'Edit test set';

  @override
  String get manageTestSets => 'Manage test sets';

  @override
  String get testSetNameHint => 'e.g. Weekly big test';

  @override
  String get testSetNeedParam => 'Select at least one parameter.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteTestSetBody =>
      'This removes the test set. Your readings are kept.';

  @override
  String get testSetEmptyHint =>
      'This test set has no enabled parameters. Edit it, or switch to All.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parameters',
      one: '1 parameter',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'No test sets yet. A test set records just the parameters you test together.';

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
  String get recordFirstReading => 'Record your first reading';

  @override
  String get statMin => 'Min';

  @override
  String get statAvg => 'Avg';

  @override
  String get statMax => 'Max';

  @override
  String get statTests => 'Tests';

  @override
  String get editMeasurement => 'Edit measurement';

  @override
  String get deleteTogetherTitle => 'Delete measurement';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This value was entered together with $count other measurements. Delete only this value, or all values entered together?',
      one:
          'This value was entered together with 1 other measurement. Delete only this value, or all values entered together?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Only this value';

  @override
  String get deleteAllTogether => 'All together';

  @override
  String get editTogetherTitle => 'Update measurement time';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This value was entered together with $count other measurements. Update the time for only this value, or all values entered together?',
      one:
          'This value was entered together with 1 other measurement. Update the time for only this value, or all values entered together?',
    );
    return '$_temp0';
  }

  @override
  String get freeAmmoniaLabel => 'Free ammonia (NH₃)';

  @override
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp) {
    return '$percent% toxic · pH $ph · $temp';
  }

  @override
  String freeAmmoniaPercent(Object percent) {
    return '$percent% toxic';
  }

  @override
  String get freeAmmoniaExplain =>
      'An ammonia test measures total ammonia, but only the un-ionized part (NH₃) is toxic. Its share rises with pH and temperature, so a reef tank turns more of it into the toxic form than a low-pH tank. This estimate splits your latest total-ammonia reading using the latest pH, temperature and salinity.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Toxic free ammonia: $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return '$percent% of your $total ppm total ammonia is in the toxic NH₃ form.';
  }

  @override
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity) {
    return 'Based on pH $ph, $temp and $salinity.';
  }

  @override
  String freeAmmoniaSalinityAssumed(Object value) {
    return '$value (assumed)';
  }

  @override
  String get freeAmmoniaOutdatedWarning =>
      'pH or temperature was last measured more than a week from this ammonia reading, so the toxic fraction may be inaccurate.';

  @override
  String get freeAmmoniaShowTitle => 'Show free ammonia (NH₃)';

  @override
  String get freeAmmoniaShowSubtitle =>
      'Adds a card estimating the toxic un-ionized fraction from pH, temperature and salinity.';

  @override
  String get freeAmmoniaNeedsAmmonia => 'Enable ammonia to show this.';

  @override
  String get close => 'Close';

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'PO₄ : NO₃ ratio';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Mg : Ca ratio';

  @override
  String get ratioCaAlkLabel => 'Ca : Alk';

  @override
  String get ratioCaAlkTitle => 'Ca : Alk ratio';

  @override
  String get ratioMgAlkLabel => 'Mg : Alk';

  @override
  String get ratioMgAlkTitle => 'Mg : Alk ratio';

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
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Equipment cleaning';

  @override
  String get recordEquipmentCleaning => 'Record equipment cleaning';

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
  String get supplementStopped => 'Supplement stopped';

  @override
  String get dosingHistoryTitle => 'Dosing history';

  @override
  String get dosingHistoryEmpty => 'No dosing history yet.';

  @override
  String get dosingHistoryCurrent => 'Current';

  @override
  String dosingHistorySince(Object date) {
    return 'Since $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Delete this record?';

  @override
  String get deleteDosingRecordBody =>
      'This permanently removes this dosing record from history and the dose calculation. It can\'t be undone.';

  @override
  String get deleteDosingRecordNotLatest =>
      'This isn\'t the most recent record for this element; deleting it won\'t change later records.';

  @override
  String get dosingHistoryManual => 'Manual';

  @override
  String get manualDoseNew => 'Log manual dose';

  @override
  String get manualDoseEdit => 'Edit manual dose';

  @override
  String get deleteManualDoseTitle => 'Delete manual dose?';

  @override
  String get deleteManualDoseBody =>
      'This permanently removes this logged dose from history and the dose calculation. It can\'t be undone.';

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
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n days',
      one: 'Every day',
    );
    return '$_temp0';
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
  String get appearanceSection => 'Appearance';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

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
  String get backupNow => 'Back up now';

  @override
  String backupLastRun(String when) {
    return 'Last backup: $when';
  }

  @override
  String get backupNeverRun => 'No backup yet';

  @override
  String backupLastFailed(String when) {
    return 'Last backup failed on $when';
  }

  @override
  String get backupDone => 'Backup saved';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupExportSubtitle =>
      'Save all aquariums and readings to a file';

  @override
  String get csvExportTitle => 'Export measurements (CSV)';

  @override
  String get csvExportSubtitle =>
      'Share the active aquarium\'s measurements as a spreadsheet file';

  @override
  String get csvExportNoData => 'No measurements to export yet';

  @override
  String get csvExportFailed => 'Could not export the measurements';

  @override
  String get backupImport => 'Restore from backup';

  @override
  String get backupImportSubtitle => 'Replace all data with a backup file';

  @override
  String get backupRestoreConfirmTitle => 'Restore backup?';

  @override
  String get backupRestoreConfirmBody =>
      'This replaces ALL your aquarium data — every aquarium, parameter, and reading — with the contents of the backup file. Your settings on this device (language, units, and preferences) are kept. This cannot be undone.';

  @override
  String get restore => 'Restore';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupNowFailed => 'Could not save the backup';

  @override
  String get backupShareFailed => 'Could not share the backup';

  @override
  String get backupExportFailed => 'Could not export the backup';

  @override
  String get backupImportFailed => 'Could not restore the backup';

  @override
  String get backupInvalidFile => 'That file isn\'t a valid ReefTracker backup';

  @override
  String get backupTooNew =>
      'This backup was made by a newer version of the app and can\'t be restored here';

  @override
  String get backupCorrupted => 'The backup file is damaged or incomplete';

  @override
  String get backupInconsistent =>
      'The backup is inconsistent and can\'t be restored';

  @override
  String get dataLoadFailed =>
      'Some data failed to load. If this keeps happening, restart the app or restore a backup.';

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
  String sizeBytes(Object size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(Object size) {
    return '$size KB';
  }

  @override
  String sizeMegabytes(Object size) {
    return '$size MB';
  }

  @override
  String get syncGdriveTitle => 'Google Drive sync';

  @override
  String get syncGdriveSubtitle => 'Back up automatically to your Google Drive';

  @override
  String syncGdriveLastPush(String when) {
    return 'Last upload: $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Nothing uploaded yet';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'Backups will sync to the Google Drive of $email';
  }

  @override
  String get syncGdriveConnectFailed => 'Couldn\'t connect to Google Drive';

  @override
  String syncGdriveDialogBody(String email) {
    return 'Backups are uploaded to the \"ReefTracker\" folder in the Google Drive of $email. You can browse and download them at drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Disconnect';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Drive disconnected. Backups already uploaded stay in your Drive.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Google Drive upload failed on $when';
  }

  @override
  String get backupsLocalSection => 'On this device';

  @override
  String get backupsDriveSection => 'Google Drive';

  @override
  String get backupsDriveEmpty => 'No backups in Google Drive yet';

  @override
  String get backupsDriveLoadFailed =>
      'Couldn\'t load backups from Google Drive';

  @override
  String backupsDriveTooLarge(Object size) {
    return '$size — too large to restore';
  }

  @override
  String get aboutAppName => 'About ReefTracker';

  @override
  String get aboutDescription =>
      'Offline reef aquarium parameter tracker with history, time graphs, and green/amber/red health zones.';

  @override
  String get editionLabel => 'Edition';

  @override
  String get editionFounder => 'Founder\'s Edition';

  @override
  String get editionStandard => 'Standard';

  @override
  String get founderInfoBody =>
      'You\'ve been with ReefTracker since its early days. As a thank-you, every feature available today stays free for you — forever.';

  @override
  String get standardInfoBody =>
      'You\'re using the standard edition of ReefTracker.';

  @override
  String get proFeatureTitle => 'Pro feature';

  @override
  String proFeatureBody(Object feature) {
    return '$feature is part of ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Unlimited aquariums';

  @override
  String tankLimitBody(Object limit) {
    return 'The standard edition includes up to $limit aquariums — for example a display tank and a quarantine tank. Unlimited aquariums are part of ReefTracker Pro.';
  }

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
  String get languageFrench => 'Français';

  @override
  String get languageItalian => 'Italiano';

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
  String get doseCalcTitle => 'Dose calculator';

  @override
  String get doseCalcIntro =>
      'Estimate how fast your tank consumes an element and the daily dose that holds it steady. Water changes are not considered.';

  @override
  String get doseCalcElement => 'Element';

  @override
  String get doseCalcWindow => 'Measurement window';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings in range',
      one: '1 reading in range',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dose changed on $date; readings before then reflect a different dose.';
  }

  @override
  String get doseCalcVolume => 'Tank volume';

  @override
  String get doseCalcCurrentDose => 'Current daily dose';

  @override
  String get doseCalcManualDose => 'Manual dose in window';

  @override
  String get doseCalcManualDoseHelp =>
      'Optional: total of one-time or extra doses given during the measurement window. When empty, logged manual doses are used.';

  @override
  String get doseCalcManualInput => 'Manual doses add';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logged doses in window: $total',
      one: '1 logged dose in window: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logged doses use a different unit and are not included.',
      one: '1 logged dose uses a different unit and is not included.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Some logged doses are a different product — their strength may differ from the one entered above.';

  @override
  String get doseCalcPerDay => 'day';

  @override
  String get doseCalcPotencyTitle => 'Supplement strength';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Using the catalog\'s strength for this product.';

  @override
  String get doseCalcEnterManually => 'Enter manually';

  @override
  String get doseCalcUseCatalog => 'Use catalog value';

  @override
  String get doseCalcRefAmount => 'Dose';

  @override
  String get doseCalcRefVolume => 'Per volume';

  @override
  String get doseCalcRise => 'Raises by';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Result';

  @override
  String get doseCalcObservedChange => 'Measured change';

  @override
  String get doseCalcConsumption => 'Consumption';

  @override
  String get doseCalcCurrentInput => 'Current dosing adds';

  @override
  String get doseCalcSuggestedDose => 'Suggested daily dose';

  @override
  String get doseCalcAdjustment => 'Adjustment';

  @override
  String get doseCalcStable =>
      'Your current dose holds this element steady — keep it.';

  @override
  String get doseCalcIncrease =>
      'Increase the dose to keep this element steady.';

  @override
  String get doseCalcDecrease =>
      'You can lower the dose and still hold this element steady.';

  @override
  String get doseCalcOverdosing =>
      'This element is rising — reduce or pause dosing.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Nothing is dosed and this element isn\'t falling — no dose is needed.';

  @override
  String get doseCalcNeedsPotency =>
      'Enter the supplement strength to get a dose recommendation.';

  @override
  String get doseCalcInsufficient =>
      'Add at least two measurements on different days and a tank volume to calculate.';

  @override
  String get doseCalcModeMaintenance => 'Daily dose';

  @override
  String get doseCalcModeCorrection => 'Correction';

  @override
  String get doseCalcCorrIntro =>
      'Calculate a one-time dose that raises an element from its current value to your target. When a fast rise would be unsafe, the dose is split over several days.';

  @override
  String get doseCalcCurrentValue => 'Current value';

  @override
  String get doseCalcCurrentValueHelp => 'Empty = your latest measurement.';

  @override
  String get doseCalcTargetValue => 'Target value';

  @override
  String get doseCalcTargetValueHelp =>
      'Empty = this parameter\'s correction target, or the middle of its OK range.';

  @override
  String get doseCalcNeededRise => 'Needed rise';

  @override
  String get doseCalcOneTimeDose => 'One-time dose';

  @override
  String get doseCalcTotalDose => 'Total dose';

  @override
  String get doseCalcDosePerDay => 'Dose per day';

  @override
  String get doseCalcSpreadDays => 'Days to spread over';

  @override
  String get doseCalcCorrMissing =>
      'Enter the current value, target and tank volume to calculate.';

  @override
  String get doseCalcCorrAtTarget =>
      'Already at or above the target — nothing to dose.';

  @override
  String get doseCalcCorrSingle => 'Safe to give as a single dose.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Raising faster than $limit per day is risky — give the correction as $days daily doses instead.';
  }

  @override
  String get doseCalcLogDose => 'Log this dose';

  @override
  String get correctionCta => 'Below range — calculate a correction dose';

  @override
  String get targetValueLabel => 'Correction target';

  @override
  String get targetValueHelp =>
      'Pre-fills the dose calculator\'s correction mode. Empty = the middle of the OK range.';

  @override
  String get trendSection => 'Trends';

  @override
  String get trendShowTitle => 'Show trends';

  @override
  String get trendShowSubtitle =>
      'Project where each parameter is heading and when it will leave its range';

  @override
  String get trendWindow => 'Readings used';

  @override
  String trendWindowSubtitle(int days) {
    return 'How many recent readings define the trend; widened to cover at least $days days when you measure more often';
  }

  @override
  String get trendTitle => 'Recent trend';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/day';
  }

  @override
  String get trendFlat => 'Holding steady';

  @override
  String get trendWithinRange => 'Staying within range at this rate';

  @override
  String trendAmberInDays(int days) {
    return 'Reaches attention zone in ~$days d';
  }

  @override
  String trendRedInDays(int days) {
    return 'Reaches critical zone in ~$days d';
  }

  @override
  String trendChipAmber(int days) {
    return 'Attention ~$days d';
  }

  @override
  String trendChipRed(int days) {
    return 'Act now ~$days d';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Recovering — back in range in ~$days d';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Recovering ~$days d';
  }

  @override
  String get trendHorizon => 'Alert horizon';

  @override
  String get trendHorizonSubtitle =>
      'Flag a parameter only when it will leave its range within this time';

  @override
  String trendHorizonDays(int days) {
    return '$days days';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Attention';

  @override
  String get zoneActNow => 'Act now';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Fish only';

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
  String get paramAlkalinityShort => 'KH';

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
  String get paramPotassium => 'Potassium (K)';

  @override
  String get paramStrontium => 'Strontium (Sr)';

  @override
  String get paramIodine => 'Iodine (I)';

  @override
  String get paramIron => 'Iron (Fe)';

  @override
  String get paramSodium => 'Sodium (Na)';

  @override
  String get paramSulfur => 'Sulfur (S)';

  @override
  String get paramBoron => 'Boron (B)';

  @override
  String get paramBromine => 'Bromine (Br)';

  @override
  String get paramSilicon => 'Silicon (Si)';

  @override
  String get paramZinc => 'Zinc (Zn)';

  @override
  String get paramVanadium => 'Vanadium (V)';

  @override
  String get paramCopper => 'Copper (Cu)';

  @override
  String get paramNickel => 'Nickel (Ni)';

  @override
  String get paramManganese => 'Manganese (Mn)';

  @override
  String get paramMolybdenum => 'Molybdenum (Mo)';

  @override
  String get paramChromium => 'Chromium (Cr)';

  @override
  String get paramCobalt => 'Cobalt (Co)';

  @override
  String get paramLithium => 'Lithium (Li)';

  @override
  String get paramBarium => 'Barium (Ba)';

  @override
  String get paramSelenium => 'Selenium (Se)';

  @override
  String get paramAluminium => 'Aluminium (Al)';

  @override
  String get paramAntimony => 'Antimony (Sb)';

  @override
  String get paramTin => 'Tin (Sn)';

  @override
  String get paramBeryllium => 'Beryllium (Be)';

  @override
  String get paramSilver => 'Silver (Ag)';

  @override
  String get paramTungsten => 'Tungsten (W)';

  @override
  String get paramLanthanum => 'Lanthanum (La)';

  @override
  String get paramTitanium => 'Titanium (Ti)';

  @override
  String get paramZirconium => 'Zirconium (Zr)';

  @override
  String get paramArsenic => 'Arsenic (As)';

  @override
  String get paramCadmium => 'Cadmium (Cd)';

  @override
  String get paramMercury => 'Mercury (Hg)';

  @override
  String get paramLead => 'Lead (Pb)';

  @override
  String get microTitle => 'Microelements';

  @override
  String get microSectionMajor => 'Major elements';

  @override
  String get microSectionTrace => 'Trace elements';

  @override
  String get microSectionContaminants => 'Contaminants';

  @override
  String get microNotMeasured => 'Not measured';

  @override
  String get microEmptyHint =>
      'Track trace elements from home test kits or ICP lab reports.';

  @override
  String get microAllOk => 'All within range';

  @override
  String microOutOfRangeN(int count) {
    return '$count out of range';
  }

  @override
  String microLastMeasured(String date) {
    return 'Last measured $date';
  }

  @override
  String get microAddMeasurements => 'Add measurements';

  @override
  String get microAddTitle => 'Microelement measurements';

  @override
  String get microChipHobby => 'Hobby kit';

  @override
  String get microChipFullIcp => 'Full ICP';

  @override
  String get microReminderTooltip => 'Test reminder';

  @override
  String get microReminderTitle => 'Microelement test reminder';

  @override
  String get microReminderHint =>
      'Adds a maintenance task reminding you to test microelements regularly.';

  @override
  String get microReminderCreated =>
      'Reminder added to the maintenance schedule';

  @override
  String get microIcpTaskTitle => 'Microelement test (ICP)';

  @override
  String get microToggleSubtitle =>
      'Show on the Measurements tab, with test reminders. Hiding keeps your measurements.';

  @override
  String get microViewFull => 'Full list';

  @override
  String get microViewNew => 'New view';

  @override
  String get microViewEdit => 'Edit view';

  @override
  String get microViewManage => 'Manage views';

  @override
  String get microConfigureTitle => 'Element settings';

  @override
  String get microViewNone =>
      'No custom views yet. A view shows just the elements your lab reports.';

  @override
  String get microViewNameHint => 'e.g. My lab\'s panel';

  @override
  String get microViewNeedElement => 'Select at least one element.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elements',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get microViewDeleteBody =>
      'This removes the view. Your measurements are kept.';

  @override
  String get microHideUndetectable => 'Hide undetectable (zero)';

  @override
  String get microAttentionOnly => 'Only elements needing attention';

  @override
  String get microFilterAllHidden => 'No elements match the current filters.';

  @override
  String get icpImportTitle => 'Import ICP report';

  @override
  String get icpImportFormatHint => 'Choose the export format of the file.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'CSV export from the Fauna Marin lab portal';

  @override
  String get icpImportFormatZimsHint =>
      'Universal measurement CSV (date, measurement, value, unit)';

  @override
  String get icpImportUnreadable => 'The file could not be read.';

  @override
  String icpImportWrongFormat(String format) {
    return 'This does not look like a $format export.';
  }

  @override
  String get icpImportNoValues =>
      'No importable values were found in the file.';

  @override
  String get icpImportSampleDateHint =>
      'Prefilled with the analysis date from the report. Change it to the day you took the water sample.';

  @override
  String get icpImportSectionCore => 'Core parameters';

  @override
  String icpImportSkipped(String list) {
    return 'Not imported (no matching parameter): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count values',
      one: 'Import 1 value',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Sample already imported?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Existing readings already mention sample $id. Import it again anyway?';
  }

  @override
  String get icpImportAnyway => 'Import anyway';

  @override
  String icpImportNotePrefill(String id) {
    return 'ICP sample $id';
  }

  @override
  String get unitFixedNote => 'This parameter always uses this unit.';

  @override
  String get measurementImportTitle => 'Import measurements';

  @override
  String get measurementImportSourceHint =>
      'Choose the app or meter the file comes from.';

  @override
  String get measurementImportHannaHint =>
      'CSV history shared from the Hanna Lab app';

  @override
  String get hannaImportTitle => 'Hanna Lab import';

  @override
  String get hannaImportIntoTank => 'Import into tank';

  @override
  String get hannaImportFirstFrom => 'Import history from';

  @override
  String get hannaImportEverything => 'Everything';

  @override
  String get hannaImportFirstFromHint =>
      'First import into this tank: choose how far back to import. Older readings are ignored for good — useful when you already typed them in by hand.';

  @override
  String hannaImportNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new readings',
      one: '1 new reading',
    );
    return '$_temp0';
  }

  @override
  String hannaImportAlreadyCount(int count) {
    return 'Already imported: $count';
  }

  @override
  String hannaImportBeforeCutoffCount(int count) {
    return 'Before the start date: $count';
  }

  @override
  String get hannaImportSkippedTitle => 'Not imported';

  @override
  String get hannaImportSkipRange => 'outside the test range';

  @override
  String get hannaImportSkipUnknown => 'test not tracked by the app';

  @override
  String get hannaImportSkipValue => 'unreadable value';

  @override
  String get hannaImportUpToDate =>
      'Everything in this file is already imported.';

  @override
  String hannaImportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count readings',
      one: 'Import 1 reading',
    );
    return '$_temp0';
  }

  @override
  String hannaImportDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count readings',
      one: 'Imported 1 reading',
    );
    return '$_temp0';
  }

  @override
  String get hannaImportUndone => 'Import undone.';

  @override
  String get hannaImportWrongTankTitle => 'Different tank?';

  @override
  String hannaImportWrongTankBody(String location, String tank, String other) {
    return '“$location” was last imported into $tank. Import into $other instead?';
  }

  @override
  String get measurementImportSettingsTitle => 'Measurement import';

  @override
  String get measurementImportSettingsSubtitle =>
      'Hanna Lab import status per tank';

  @override
  String hannaImportImportedUpTo(String date) {
    return 'Imported up to $date';
  }

  @override
  String get hannaImportNeverImported => 'Not imported yet';

  @override
  String get hannaImportChangeDate => 'Change date…';

  @override
  String get hannaImportReset => 'Reset';

  @override
  String get hannaImportResetTitle => 'Reset Hanna Lab import?';

  @override
  String get hannaImportResetBody =>
      'The next import will ask again from which date to start. Already-imported readings stay; the tank assignment is remembered.';

  @override
  String get hannaConnectTitle => 'Hanna checker';

  @override
  String get hannaConnectSubtitle =>
      'Measure parameters over Bluetooth (HI97115)';

  @override
  String get hannaMeasureAction => 'Measure with Hanna checker';

  @override
  String get hannaScanTitle => 'Scan checker display';

  @override
  String get hannaScanSubtitle =>
      'Read a pocket checker\'s display with the camera';

  @override
  String get hannaScanPickHint =>
      'Reads the value straight from the checker\'s display. First pick your model — the HI number is printed on the front of the checker.';

  @override
  String get hannaScanPickTitle => 'Checker model';

  @override
  String get hannaScanGuide => 'Fit the display into the frame';

  @override
  String get hannaScanGlareHint => 'tilt slightly to avoid glare';

  @override
  String get hannaScanRescan => 'Rescan';

  @override
  String get hannaScanNoCamera => 'This device has no camera.';

  @override
  String get hannaScanCameraDenied =>
      'Camera access was denied. Allow camera access in the system settings to scan the display.';

  @override
  String get hannaScanCameraFailed => 'The camera couldn\'t be started.';

  @override
  String get hannaScanImpossibleNote =>
      'This value is impossible for this parameter and can\'t be saved. Rescan, or check that the right model is selected.';

  @override
  String get hannaScanImplausibleNote =>
      'This value is outside the plausible range — double-check it before saving.';

  @override
  String get experimentalBadge => 'Experimental';

  @override
  String get hannaExperimentalNote =>
      'Experimental feature: it uses an unofficial Bluetooth protocol and may stop working after a meter firmware update.';

  @override
  String get hannaScanning => 'Looking for the meter…';

  @override
  String get hannaScanHint =>
      'Turn the meter on and keep it close to your phone.';

  @override
  String get hannaReadingSetup => 'Connected — reading meter setup…';

  @override
  String get hannaErrUnsupported =>
      'Bluetooth LE is not available on this device.';

  @override
  String get hannaErrBluetoothOff =>
      'Bluetooth is off. Turn it on and try again.';

  @override
  String get hannaErrNotFound =>
      'No meter found. Make sure it is turned on and within range.';

  @override
  String get hannaErrConnectionFailed => 'Couldn\'t connect to the meter.';

  @override
  String get hannaErrConnectionLost => 'The connection to the meter was lost.';

  @override
  String get hannaTryAgain => 'Try again';

  @override
  String hannaMeterStatus(int percent, String firmware) {
    return 'Battery $percent % · firmware $firmware';
  }

  @override
  String get hannaAquarium => 'Aquarium';

  @override
  String get hannaSetsTitle => 'Test sets';

  @override
  String hannaSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count methods',
      one: '1 method',
    );
    return '$_temp0';
  }

  @override
  String get hannaSaveSet => 'Save selection as set';

  @override
  String get hannaSetName => 'Set name';

  @override
  String get hannaSetUpdate => 'Update from current selection';

  @override
  String get hannaAllMethods => 'All methods';

  @override
  String hannaMethodLowRange(String name) {
    return '$name (low range)';
  }

  @override
  String get hannaStartMeasurements => 'Start measurements';

  @override
  String get hannaFollowMeter => 'Follow the instructions on the meter.';

  @override
  String hannaStepN(int step) {
    return 'step $step';
  }

  @override
  String get hannaStatusSkipped => 'Skipped';

  @override
  String get hannaSkip => 'Skip';

  @override
  String get hannaFinishNow => 'Finish now';

  @override
  String get hannaResultsTitle => 'Measurement results';

  @override
  String get hannaResultsDisconnected =>
      'The connection was lost — the results captured so far are kept.';

  @override
  String get hannaNoResults => 'No measurements were captured.';

  @override
  String get hannaSaveTo => 'Save to aquarium';

  @override
  String hannaSaveButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count readings',
      one: 'Save 1 reading',
    );
    return '$_temp0';
  }

  @override
  String hannaSavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings saved',
      one: '1 reading saved',
    );
    return '$_temp0';
  }

  @override
  String get hannaDiscardTitle => 'Discard measurements?';

  @override
  String get hannaDiscardBody =>
      'The captured values haven\'t been saved and will be lost.';

  @override
  String get hannaDiscard => 'Discard';

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

  @override
  String get healthTitle => 'Tank health';

  @override
  String get healthGradeExcellent => 'Excellent';

  @override
  String get healthGradeGood => 'Good';

  @override
  String get healthGradeCaution => 'Caution';

  @override
  String get healthGradeCritical => 'Critical';

  @override
  String get healthGradeUnknown => 'No data';

  @override
  String get healthAllOnTarget => 'All parameters on target';

  @override
  String healthParamsToWatch(int count) {
    return '$count to watch';
  }

  @override
  String get healthSectionAttention => 'Needs attention';

  @override
  String get healthSectionGood => 'Looking good';

  @override
  String get healthSectionStale => 'Not tested recently';

  @override
  String healthNotTestedDays(int count) {
    return 'Not tested in $count d';
  }

  @override
  String get healthNeverTested => 'Not tested yet';

  @override
  String get healthNoReadingsYet => 'No readings yet';

  @override
  String healthScoreOf(int score) {
    return '$score of 100';
  }

  @override
  String get stabilityTitle => 'Stability';

  @override
  String get stabilityScoreProName => 'Stability score';

  @override
  String get stabilityGradeRockSolid => 'Rock solid';

  @override
  String get stabilityGradeSteady => 'Steady';

  @override
  String get stabilityGradeVariable => 'Variable';

  @override
  String get stabilityGradeUnstable => 'Unstable';

  @override
  String get stabilityGradeUnknown => 'No data';

  @override
  String stabilityIntro(int days) {
    return 'How steadily each parameter has held over the last $days days.';
  }

  @override
  String get stabilitySectionVariable => 'Most variable';

  @override
  String get stabilitySectionSteady => 'Holding steady';

  @override
  String get stabilitySectionInsufficient => 'Not enough data';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tests in the last $days days',
      one: '1 test in the last $days days',
      zero: 'No tests in the last $days days',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Stability window';

  @override
  String get stabilityWindowSubtitle => 'Period the stability score looks at';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsProName => 'Smart insights';

  @override
  String get insightsIntro =>
      'What your recent readings suggest to keep an eye on.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param is below its target range';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param is low and still falling';
  }

  @override
  String insightHigh(Object param) {
    return '$param is above its target range';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param is high and still rising';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param is outside its target range';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param is heading low — may leave its range in ~$days d';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param is heading high — may leave its range in ~$days d';
  }

  @override
  String insightRecovering(Object param) {
    return '$param is recovering toward its range';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param is recovering — back in range in ~$days d';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param not tested in $days d';
  }

  @override
  String get aiSummaryAction => 'Ask your AI';

  @override
  String get aiSummaryPrivacyNote =>
      'This is a ready-made prompt with your tank\'s data. Paste it into ChatGPT, Claude, Gemini or any other AI tool — everything is prepared on your device, nothing is sent anywhere.';

  @override
  String get aiSummaryPromptPreview => 'Prompt preview';

  @override
  String get aiSummaryCopyPrompt => 'Copy prompt';

  @override
  String aiSummaryWeeksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get aiSummaryCopied => 'Copied — paste it into your AI chat.';

  @override
  String get aiSummaryEmpty => 'No readings yet — nothing to summarize.';

  @override
  String get aiSummaryInsightsFooter => 'Want a deeper look? Ask your AI';

  @override
  String aiSummaryPreamble(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other:
          'I keep a saltwater reef aquarium and track it with an app. Below is my tank\'s data from the last $weeks weeks. Please analyze it, point out risks or trends I should address, and suggest what to check or adjust.',
      one:
          'I keep a saltwater reef aquarium and track it with an app. Below is my tank\'s data from the last week. Please analyze it, point out risks or trends I should address, and suggest what to check or adjust.',
    );
    return '$_temp0';
  }

  @override
  String aiSummaryDocTitle(Object tank) {
    return '$tank — saltwater aquarium summary';
  }

  @override
  String aiSummaryRunningSince(Object date) {
    return 'running since $date';
  }

  @override
  String aiSummaryExportedLine(Object date) {
    return 'Exported $date.';
  }

  @override
  String get aiSummaryStatusHeading => 'Status';

  @override
  String aiSummaryHealthLine(int score, Object grade) {
    return 'Health score: $score of 100 ($grade)';
  }

  @override
  String aiSummaryStabilityLine(int score, Object grade, int days) {
    return 'Stability score: $score of 100 ($grade) over the last $days days';
  }

  @override
  String get aiSummaryObservationsLead => 'The app\'s rule-based observations:';

  @override
  String get aiSummaryParamsHeading => 'Parameters';

  @override
  String aiSummaryTestedOn(Object date) {
    return 'last tested $date';
  }

  @override
  String aiSummaryTargetRange(Object range) {
    return 'Target $range';
  }

  @override
  String aiSummaryAcceptableRange(Object range) {
    return 'acceptable $range';
  }

  @override
  String get aiSummaryColDate => 'Date';

  @override
  String get aiSummaryColValue => 'Value';

  @override
  String get aiSummaryColNote => 'Note';

  @override
  String get aiSummaryColElement => 'Element';

  @override
  String get aiSummaryColStatus => 'Status';

  @override
  String aiSummaryShowingTests(int shown, int total) {
    return 'Showing the $shown most recent of $total tests.';
  }

  @override
  String get aiSummaryDosingHeading => 'Dosing plan';

  @override
  String aiSummaryDailyEquivalent(Object amount) {
    return '≈$amount per day';
  }

  @override
  String aiSummarySinceDate(Object date) {
    return 'since $date';
  }

  @override
  String get aiSummaryOneOff => 'one-off dose';

  @override
  String get aiSummaryActionsHeading => 'Maintenance in this period';

  @override
  String get aiSummaryMicroHeading => 'Trace elements (latest measured values)';

  @override
  String get dashboardSection => 'Dashboard';

  @override
  String get dashboardLayoutTitle => 'Dashboard layout';

  @override
  String get dashboardLayoutSubtitle =>
      'How the Measurements tab arranges cards';

  @override
  String get dashboardLayoutGrouped => 'Grouped';

  @override
  String get dashboardLayoutFlat => 'Flat';

  @override
  String get healthDisplayTitle => 'Tank health';

  @override
  String get healthDisplaySubtitle => 'Where to show the health summary';

  @override
  String get healthDisplayBoth => 'Badge & card';

  @override
  String get healthDisplayBadge => 'Badge only';

  @override
  String get healthDisplayOff => 'Hidden';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundBody =>
      'This link doesn\'t lead anywhere in the app.';

  @override
  String get routeNotFoundGoHome => 'Go to home screen';

  @override
  String get notifChannelTesting => 'Testing reminders';

  @override
  String get notifChannelDosing => 'Dosing reminders';

  @override
  String get notifChannelMaintenance => 'Maintenance reminders';

  @override
  String get notifTestingTitle => 'Time to test';

  @override
  String get notifDosingTitle => 'Dosing due';

  @override
  String get notifMaintenanceTitle => 'Maintenance due';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersSubtitle =>
      'Testing, dosing and maintenance notifications';

  @override
  String get remindersTestingSubtitle => 'When a parameter\'s test is due';

  @override
  String get remindersDosingSubtitle => 'At each supplement\'s dose time';

  @override
  String get remindersMaintenanceSubtitle =>
      'When scheduled maintenance is due';

  @override
  String get reminderTimeTitle => 'Reminder time';

  @override
  String get reminderTimeSubtitle =>
      'Delivery time for testing and maintenance reminders';

  @override
  String get remindersPermissionDenied =>
      'Notifications are blocked in system settings, so reminders can\'t be shown.';

  @override
  String get remindToTest => 'Remind to test';

  @override
  String get cadenceOff => 'Off';

  @override
  String daysShortN(int count) {
    return '$count d';
  }

  @override
  String get cadenceCustom => 'Custom';

  @override
  String get customDaysLabel => 'Days';

  @override
  String get remindMe => 'Remind me';

  @override
  String get remindMeNeedsTime => 'Set a time of day to enable reminders';

  @override
  String get maintenanceSchedule => 'Maintenance schedule';

  @override
  String get addMaintenanceTask => 'Add task';

  @override
  String get editMaintenanceTask => 'Edit task';

  @override
  String get taskTypeLabel => 'Type';

  @override
  String get customTask => 'Custom task';

  @override
  String get taskTitleLabel => 'Title';

  @override
  String get taskTitleRequired => 'Enter a title';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get oneOff => 'One-off';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get dueDateRequired => 'Pick a due date';

  @override
  String get dueToday => 'Due today';

  @override
  String dueInDaysN(int count) {
    return 'Due in $count d';
  }

  @override
  String overdueDaysN(int count) {
    return '$count d overdue';
  }

  @override
  String get markDone => 'Mark done';

  @override
  String get taskMarkedDone => 'Marked as done';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get scheduleEmptyBody =>
      'No maintenance tasks yet. Plan water changes or custom tasks to get due chips and reminders.';

  @override
  String get repeatModeLabel => 'Repeats';

  @override
  String get repeatEveryDays => 'Every X days';

  @override
  String get repeatEveryWeeks => 'Every X weeks';

  @override
  String get repeatEveryMonths => 'Every X months';

  @override
  String get repeatOnWeekdays => 'Days of the week';

  @override
  String get repeatOnMonthDay => 'Day of the month';

  @override
  String get weeksLabel => 'Weeks';

  @override
  String get monthsLabel => 'Months';

  @override
  String get monthDayLabel => 'Day of the month (1–31)';

  @override
  String get invalidInterval => 'Enter a whole number (1 or more).';

  @override
  String get invalidMonthDay => 'Enter a day between 1 and 31.';

  @override
  String get weekdaysRequired => 'Pick at least one day.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'Every $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Monthly on day $n';
  }

  @override
  String get roUnitTitle => 'Reverse osmosis unit';

  @override
  String get roStageSediment => 'Sediment filter';

  @override
  String get roStageCarbonBlock => 'Carbon block';

  @override
  String get roStageMembrane => 'RO membrane';

  @override
  String get roStageDiResin => 'DI resin';

  @override
  String get roCustomStage => 'Custom part';

  @override
  String get roAddStage => 'Add part';

  @override
  String get roEditStage => 'Edit part';

  @override
  String get roLifespanLabel => 'Replace every';

  @override
  String get roUnitDays => 'days';

  @override
  String get roUnitWeeks => 'weeks';

  @override
  String get roUnitMonths => 'months';

  @override
  String get roPartOfUnit => 'Part of my unit';

  @override
  String get roPartOfUnitHint =>
      'Turn off if your unit doesn\'t have this stage';

  @override
  String get roHiddenStages => 'Not on my unit';

  @override
  String get roMarkReplaced => 'Mark replaced';

  @override
  String get roReplacedRecorded => 'Replacement recorded';

  @override
  String roLastReplaced(String date) {
    return 'Replaced $date';
  }

  @override
  String get roNoReplacementYet => 'No replacement recorded yet';

  @override
  String get roDeleteStageTitle => 'Delete part?';

  @override
  String get roDeleteStageBody =>
      'This removes the part and its replacement history. This cannot be undone.';

  @override
  String get roEmptyBody => 'No parts. Add your RO unit\'s filters with +.';

  @override
  String get roSetupPrompt => 'Track filter and membrane replacements';

  @override
  String get roUnitToggleSubtitle =>
      'Show on the Actions tab, with filter-replacement reminders';

  @override
  String get roAllOk => 'All parts OK';

  @override
  String get notifRoTitle => 'Replace RO filters';
}
