// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Messwerte';

  @override
  String get settings => 'Einstellungen';

  @override
  String get manageParameters => 'Parameter verwalten';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get tourTankTitle => 'Deine Aquarien';

  @override
  String get tourTankDesc =>
      'Tippe hier, um zwischen Aquarien zu wechseln oder ein neues hinzuzufügen.';

  @override
  String get tourCompareTitle => 'Vergleichsansicht';

  @override
  String get tourCompareDesc =>
      'Wechsle zwischen den Parameter-Karten und gestapelten Vergleichsgraphen.';

  @override
  String get tourParamsTitle => 'Parameter verwalten';

  @override
  String get tourParamsDesc =>
      'Wähle, welche Wasserparameter verfolgt werden, und lege ihre Zielbereiche fest.';

  @override
  String get tourDosingHistoryTitle => 'Dosierverlauf';

  @override
  String get tourDosingHistoryDesc =>
      'Sieh dir alle vergangenen und aktuellen Dosierzeiträume an und entferne einen versehentlich erstellten Eintrag.';

  @override
  String get tourDoseCalcTitle => 'Dosierungsrechner';

  @override
  String get tourDoseCalcDesc =>
      'Öffne im Tab „Dosierung“ den Rechner, um die Tagesdosis zu schätzen, die ein Element stabil hält.';

  @override
  String get tourNext => 'Weiter';

  @override
  String get tourDone => 'Verstanden';

  @override
  String get tourSkip => 'Überspringen';

  @override
  String get replayTour => 'Tour wiederholen';

  @override
  String get replayTourSubtitle =>
      'Die Tipps zur oberen Leiste erneut anzeigen';

  @override
  String get compareView => 'Diagramme vergleichen';

  @override
  String get gridView => 'Rasteransicht';

  @override
  String get addReading => 'Messung hinzufügen';

  @override
  String get addAquarium => 'Aquarium hinzufügen';

  @override
  String get manageTanks => 'Aquarien verwalten';

  @override
  String get chooseParameters => 'Parameter auswählen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get stop => 'Stoppen';

  @override
  String get apply => 'Anwenden';

  @override
  String get change => 'Ändern';

  @override
  String get undo => 'Rückgängig';

  @override
  String get itemDeleted => 'Gelöscht';

  @override
  String get reorder => 'Neu anordnen';

  @override
  String errorWith(Object message) {
    return 'Fehler: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get welcomeTitle => 'Willkommen bei ReefTracker';

  @override
  String get welcomeBody =>
      'Erstelle dein erstes Aquarium, um Wasserparameter zu verfolgen.';

  @override
  String get noParamsTracked =>
      'Für dieses Aquarium werden keine Parameter verfolgt.';

  @override
  String get noReadings => 'Keine Messungen';

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String timeHoursAgo(int count) {
    return 'vor $count Std.';
  }

  @override
  String timeDaysAgo(int count) {
    return 'vor $count T.';
  }

  @override
  String get aquariums => 'Aquarien';

  @override
  String get noAquariumsYet => 'Noch keine Aquarien.';

  @override
  String get makeActive => 'Als aktiv festlegen';

  @override
  String get active => 'Aktiv';

  @override
  String get edit => 'Bearbeiten';

  @override
  String deleteTankTitle(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteTankBody =>
      'Dadurch werden das Aquarium und alle seine Messungen dauerhaft gelöscht.';

  @override
  String tankDeleted(Object name) {
    return 'Aquarium „$name“ gelöscht';
  }

  @override
  String get newAquarium => 'Neues Aquarium';

  @override
  String get editAquarium => 'Aquarium bearbeiten';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'z. B. Riff im Wohnzimmer';

  @override
  String get enterAName => 'Namen eingeben';

  @override
  String get setupType => 'Beckentyp';

  @override
  String get presetSeedNote =>
      'Für diesen Beckentyp werden Standardparameter und Zonengrenzen eingerichtet. Du kannst sie jederzeit anpassen.';

  @override
  String get volumeOptional => 'Volumen (optional)';

  @override
  String get vendorOptional => 'Hersteller (optional)';

  @override
  String get modelOptional => 'Modell (optional)';

  @override
  String get notesOptional => 'Notizen (optional)';

  @override
  String get createAquarium => 'Aquarium erstellen';

  @override
  String litersSuffix(Object value) {
    return '$value l';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Startdatum';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get setDate => 'Festlegen';

  @override
  String get clear => 'Entfernen';

  @override
  String sinceDate(Object date) {
    return 'seit $date';
  }

  @override
  String get parameters => 'Parameter';

  @override
  String get noActiveAquarium => 'Kein aktives Aquarium.';

  @override
  String reapplyPreset(Object type) {
    return 'Voreinstellung $type erneut anwenden';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Voreinstellung $type erneut anwenden?';
  }

  @override
  String get reapplyPresetBody =>
      'Dadurch werden die grün/orange/rot-Grenzen aller verfolgten Parameter mit den Standardwerten überschrieben: Dashboard-Parameter mit der Voreinstellung des Aquarientyps, Spurenelemente mit ihren eingebauten Standardwerten. Deine Messungen bleiben erhalten.';

  @override
  String get presetApplied => 'Voreinstellung angewendet.';

  @override
  String get noBoundariesSet => 'Keine Grenzen festgelegt';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  rot <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Zonen bearbeiten';

  @override
  String get addParameter => 'Parameter hinzufügen';

  @override
  String get allParametersAdded => 'Alle Parameter sind bereits hinzugefügt.';

  @override
  String unitWithValue(Object unit) {
    return 'Einheit: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'In den Einstellungen festgelegt. Die Grenzen unten verwenden diese Einheit.';

  @override
  String get unit => 'Einheit';

  @override
  String get boundAmberLow => 'Rot unter (orange unten)';

  @override
  String get boundGreenLow => 'Grün ab (OK unten)';

  @override
  String get boundGreenHigh => 'Grün bis (OK oben)';

  @override
  String get boundAmberHigh => 'Rot über (orange oben)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Werte sind in $unit. Ein leeres Feld bedeutet „keine Grenze auf dieser Seite“.';
  }

  @override
  String get enterANumber => 'Zahl eingeben';

  @override
  String get boundsOrderError =>
      'Grenzen müssen ansteigen: orange unten ≤ grün unten ≤ grün oben ≤ orange oben.';

  @override
  String get boundsPairError =>
      'Jede orange Grenze benötigt ihre passende grüne Grenze auf derselben Seite.';

  @override
  String get noteOptional => 'Notiz (optional)';

  @override
  String get saveReadings => 'Messungen speichern';

  @override
  String invalidNumberFor(Object name) {
    return 'Ungültige Zahl für $name';
  }

  @override
  String get invalidVolume => 'Geben Sie ein gültiges positives Volumen ein.';

  @override
  String get invalidPositiveNumber => 'Geben Sie eine positive Zahl ein.';

  @override
  String get invalidIntervalDays =>
      'Geben Sie eine ganze Anzahl von Tagen ein (mindestens 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: Dieser Wert ist physikalisch nicht möglich.';
  }

  @override
  String get impossibleValue => 'Dieser Wert ist physikalisch nicht möglich.';

  @override
  String get implausibleTitle => 'Ungewöhnliche Werte';

  @override
  String get implausibleIntro =>
      'Der folgende Wert liegt außerhalb des üblichen Bereichs. Prüfen Sie vor dem Speichern auf Tippfehler.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (üblich $min–$max)';
  }

  @override
  String get saveAnyway => 'Trotzdem speichern';

  @override
  String get enterAtLeastOneValue => 'Gib mindestens einen Wert ein.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Messungen gespeichert.',
      one: '1 Messung gespeichert.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Keine verfolgten Parameter zum Erfassen.';

  @override
  String get testSetAll => 'Alle';

  @override
  String get newTestSet => 'Neues Test-Set';

  @override
  String get editTestSet => 'Test-Set bearbeiten';

  @override
  String get manageTestSets => 'Test-Sets verwalten';

  @override
  String get testSetNameHint => 'z. B. Großer Wochentest';

  @override
  String get testSetNeedParam => 'Mindestens einen Parameter auswählen.';

  @override
  String deleteTestSetTitle(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteTestSetBody =>
      'Das Test-Set wird entfernt. Deine Messwerte bleiben erhalten.';

  @override
  String get testSetEmptyHint =>
      'Dieses Test-Set enthält keine aktiven Parameter. Bearbeite es oder wechsle zu Alle.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Parameter',
      one: '1 Parameter',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Noch keine Test-Sets. Ein Test-Set erfasst nur die Parameter, die du gemeinsam testest.';

  @override
  String get rangeWeek => '7 T';

  @override
  String get rangeMonth => '30 T';

  @override
  String get rangeQuarter => '90 T';

  @override
  String get rangeAll => 'Alle';

  @override
  String get noReadingsInRange => 'Keine Messungen in diesem Zeitraum.';

  @override
  String get editMeasurement => 'Messung bearbeiten';

  @override
  String get deleteTogetherTitle => 'Messung löschen';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dieser Wert wurde zusammen mit $count weiteren Messungen erfasst. Nur diesen Wert oder alle zusammen erfassten Werte löschen?',
      one:
          'Dieser Wert wurde zusammen mit 1 weiteren Messung erfasst. Nur diesen Wert oder alle zusammen erfassten Werte löschen?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Nur diesen Wert';

  @override
  String get deleteAllTogether => 'Alle zusammen';

  @override
  String get editTogetherTitle => 'Messzeitpunkt ändern';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dieser Wert wurde zusammen mit $count weiteren Messungen erfasst. Den Zeitpunkt nur für diesen Wert oder für alle zusammen erfassten Werte ändern?',
      one:
          'Dieser Wert wurde zusammen mit 1 weiteren Messung erfasst. Den Zeitpunkt nur für diesen Wert oder für alle zusammen erfassten Werte ändern?',
    );
    return '$_temp0';
  }

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'PO₄ : NO₃-Verhältnis';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Mg : Ca-Verhältnis';

  @override
  String get ratioCaAlkLabel => 'Ca : Alk';

  @override
  String get ratioCaAlkTitle => 'Ca : Alk-Verhältnis';

  @override
  String get ratioMgAlkLabel => 'Mg : Alk';

  @override
  String get ratioMgAlkTitle => 'Mg : Alk-Verhältnis';

  @override
  String get ratioNoData =>
      'Erfasse beide Parameter, um ihr Verhältnis zu sehen.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Die Zonengrenzen verwenden $metric, den auf der Karte angezeigten Wert.';
  }

  @override
  String get waterChanges => 'Wasserwechsel';

  @override
  String get recordWaterChange => 'Wasserwechsel erfassen';

  @override
  String get amountLitersOptional => 'Menge (optional)';

  @override
  String get noWaterChanges => 'Noch keine Wasserwechsel.';

  @override
  String get amountNotRecorded => 'Menge nicht erfasst';

  @override
  String get actions => 'Maßnahmen';

  @override
  String get noActions => 'Noch keine Maßnahmen.';

  @override
  String get addAction => 'Maßnahme hinzufügen';

  @override
  String get waterChange => 'Wasserwechsel';

  @override
  String get carbonChange => 'Kohlewechsel';

  @override
  String get recordCarbonChange => 'Kohlewechsel erfassen';

  @override
  String get weightOptional => 'Gewicht (optional)';

  @override
  String get weightNotRecorded => 'Gewicht nicht erfasst';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Gerätereinigung';

  @override
  String get recordEquipmentCleaning => 'Gerätereinigung erfassen';

  @override
  String get dosing => 'Dosierung';

  @override
  String get addSupplement => 'Präparat hinzufügen';

  @override
  String get noDosing => 'Noch keine Präparate.';

  @override
  String get noDosingHint =>
      'Füge die Präparate hinzu, die du in diesem Becken dosierst – Hersteller, Produkt und optional Dosierung und Zeitplan.';

  @override
  String get dosingNoDosage => 'Keine Dosierung angegeben';

  @override
  String get supplementStopped => 'Präparat gestoppt';

  @override
  String get dosingHistoryTitle => 'Dosierverlauf';

  @override
  String get dosingHistoryEmpty => 'Noch kein Dosierverlauf.';

  @override
  String get dosingHistoryCurrent => 'Aktuell';

  @override
  String dosingHistorySince(Object date) {
    return 'Seit $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Diesen Eintrag löschen?';

  @override
  String get deleteDosingRecordBody =>
      'Dadurch wird dieser Dosiereintrag dauerhaft aus dem Verlauf und der Dosisberechnung entfernt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get deleteDosingRecordNotLatest =>
      'Dies ist nicht der neueste Eintrag für dieses Element; das Löschen ändert spätere Einträge nicht.';

  @override
  String get dosingHistoryManual => 'Manuell';

  @override
  String get manualDoseNew => 'Manuelle Dosis erfassen';

  @override
  String get manualDoseEdit => 'Manuelle Dosis bearbeiten';

  @override
  String get deleteManualDoseTitle => 'Manuelle Dosis löschen?';

  @override
  String get deleteManualDoseBody =>
      'Diese erfasste Dosis wird dauerhaft aus dem Verlauf und der Dosisberechnung entfernt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get dosingNew => 'Präparat hinzufügen';

  @override
  String get dosingEdit => 'Präparat bearbeiten';

  @override
  String get dosingVendor => 'Hersteller';

  @override
  String get dosingVendorName => 'Herstellername';

  @override
  String get dosingProduct => 'Produkt';

  @override
  String get dosingProductName => 'Produktname';

  @override
  String get dosingElement => 'Element';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Andere…';

  @override
  String get dosingDosageOptional => 'Dosierung (optional)';

  @override
  String get dosingAmount => 'Menge';

  @override
  String get dosingUnit => 'Einheit';

  @override
  String get dosingBasis => 'Basis';

  @override
  String get dosingPerDay => 'pro Tag';

  @override
  String get dosingPerDose => 'pro Dosis';

  @override
  String get dosingSchedule => 'Zeitplan';

  @override
  String get dosingFrequency => 'Häufigkeit';

  @override
  String get dosingFreqNone => 'Keine';

  @override
  String get dosingFreqDaily => 'Täglich';

  @override
  String get dosingFreqEveryNDays => 'Alle N Tage';

  @override
  String get dosingFreqWeekly => 'Wöchentlich';

  @override
  String get dosingIntervalDays => 'Intervall (Tage)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Alle $n Tage',
      one: 'Jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Uhrzeit (optional)';

  @override
  String get unitsSection => 'Einheiten';

  @override
  String get toolsSection => 'Werkzeuge';

  @override
  String get aboutSection => 'Über';

  @override
  String get languageSection => 'Sprache';

  @override
  String get temperature => 'Temperatur';

  @override
  String get salinity => 'Salinität';

  @override
  String get volume => 'Volumen';

  @override
  String get unitUsedAcrossApp => 'In der gesamten App verwendete Einheit';

  @override
  String get salinityCalculator => 'Salinitäts-Rechner';

  @override
  String get salinityCalculatorSubtitle =>
      'Umrechnung ppt ↔ spezifisches Gewicht (SG)';

  @override
  String get backupSection => 'Sicherung';

  @override
  String get backupNow => 'Jetzt sichern';

  @override
  String backupLastRun(String when) {
    return 'Letzte Sicherung: $when';
  }

  @override
  String get backupNeverRun => 'Noch keine Sicherung';

  @override
  String backupLastFailed(String when) {
    return 'Letzte Sicherung fehlgeschlagen am $when';
  }

  @override
  String get backupDone => 'Sicherung gespeichert';

  @override
  String get backupExport => 'Sicherung exportieren';

  @override
  String get backupExportSubtitle =>
      'Alle Aquarien und Messwerte in eine Datei speichern';

  @override
  String get csvExportTitle => 'Messwerte exportieren (CSV)';

  @override
  String get csvExportSubtitle =>
      'Messwerte des aktiven Aquariums als Tabellendatei teilen';

  @override
  String get csvExportNoData => 'Noch keine Messwerte zum Exportieren';

  @override
  String get csvExportFailed => 'Messwerte konnten nicht exportiert werden';

  @override
  String get backupImport => 'Aus Sicherung wiederherstellen';

  @override
  String get backupImportSubtitle =>
      'Alle Daten durch eine Sicherungsdatei ersetzen';

  @override
  String get backupRestoreConfirmTitle => 'Sicherung wiederherstellen?';

  @override
  String get backupRestoreConfirmBody =>
      'Dadurch werden ALLE Ihre Aquariendaten — alle Aquarien, Parameter und Messwerte — durch den Inhalt der Sicherungsdatei ersetzt. Ihre Einstellungen auf diesem Gerät (Sprache, Einheiten und Präferenzen) bleiben erhalten. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get backupRestored => 'Sicherung wiederhergestellt';

  @override
  String get backupNowFailed => 'Die Sicherung konnte nicht gespeichert werden';

  @override
  String get backupShareFailed => 'Die Sicherung konnte nicht geteilt werden';

  @override
  String get backupExportFailed => 'Sicherung konnte nicht exportiert werden';

  @override
  String get backupImportFailed =>
      'Sicherung konnte nicht wiederhergestellt werden';

  @override
  String get backupInvalidFile =>
      'Diese Datei ist keine gültige ReefTracker-Sicherung';

  @override
  String get backupTooNew =>
      'Diese Sicherung wurde mit einer neueren App-Version erstellt und kann hier nicht wiederhergestellt werden';

  @override
  String get backupCorrupted =>
      'Die Sicherungsdatei ist beschädigt oder unvollständig';

  @override
  String get backupInconsistent =>
      'Die Sicherung ist inkonsistent und kann nicht wiederhergestellt werden';

  @override
  String get dataLoadFailed =>
      'Einige Daten konnten nicht geladen werden. Falls das wiederholt auftritt, starte die App neu oder stelle eine Sicherung wieder her.';

  @override
  String get autoBackupTitle => 'Automatische Sicherung';

  @override
  String get autoBackupSubtitle =>
      'Aktuelle Kopien deiner Daten auf diesem Gerät behalten';

  @override
  String get autoBackupFrequency => 'Häufigkeit';

  @override
  String get autoBackupDaily => 'Täglich';

  @override
  String get autoBackupWeekly => 'Wöchentlich';

  @override
  String get manageBackups => 'Sicherungen verwalten';

  @override
  String get manageBackupsSubtitle =>
      'Automatische Sicherungen ansehen, wiederherstellen oder teilen';

  @override
  String get backupsScreenTitle => 'Automatische Sicherungen';

  @override
  String get noAutoBackups => 'Noch keine automatischen Sicherungen';

  @override
  String get noAutoBackupsHint =>
      'Eine Sicherung wird automatisch erstellt, während du die App nutzt.';

  @override
  String get share => 'Teilen';

  @override
  String get backupDeleteConfirmTitle => 'Sicherung löschen?';

  @override
  String get backupDeleteConfirmBody =>
      'Dadurch wird diese Sicherungsdatei dauerhaft von deinem Gerät entfernt.';

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
  String get syncGdriveTitle => 'Google Drive-Synchronisierung';

  @override
  String get syncGdriveSubtitle => 'Automatisch in Ihr Google Drive sichern';

  @override
  String syncGdriveLastPush(String when) {
    return 'Letzter Upload: $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Noch nichts hochgeladen';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'Backups werden in das Google Drive von $email synchronisiert';
  }

  @override
  String get syncGdriveConnectFailed =>
      'Verbindung mit Google Drive fehlgeschlagen';

  @override
  String syncGdriveDialogBody(String email) {
    return 'Backups werden in den Ordner „ReefTracker“ im Google Drive von $email hochgeladen. Sie können sie unter drive.google.com ansehen und herunterladen.';
  }

  @override
  String get syncGdriveDisconnect => 'Trennen';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Drive getrennt. Bereits hochgeladene Backups bleiben in Ihrem Drive erhalten.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Upload zu Google Drive fehlgeschlagen am $when';
  }

  @override
  String get backupsLocalSection => 'Auf diesem Gerät';

  @override
  String get backupsDriveSection => 'Google Drive';

  @override
  String get backupsDriveEmpty => 'Noch keine Backups in Google Drive';

  @override
  String get backupsDriveLoadFailed =>
      'Backups konnten nicht aus Google Drive geladen werden';

  @override
  String get aboutAppName => 'Über ReefTracker';

  @override
  String get aboutDescription =>
      'Offline-Tracker für Meerwasseraquarium-Parameter mit Verlauf, Zeitdiagrammen und grün/orange/rot-Gesundheitszonen.';

  @override
  String get editionLabel => 'Edition';

  @override
  String get editionFounder => 'Gründer-Edition';

  @override
  String get editionStandard => 'Standard';

  @override
  String get founderInfoBody =>
      'Du bist seit den Anfängen bei ReefTracker dabei. Als Dankeschön bleiben alle heute verfügbaren Funktionen für dich für immer kostenlos.';

  @override
  String get standardInfoBody =>
      'Du verwendest die Standard-Edition von ReefTracker.';

  @override
  String get proFeatureTitle => 'Pro-Funktion';

  @override
  String proFeatureBody(Object feature) {
    return '$feature ist Teil von ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Unbegrenzte Aquarien';

  @override
  String tankLimitBody(Object limit) {
    return 'Die Standard-Edition umfasst bis zu $limit Aquarien — zum Beispiel ein Hauptbecken und ein Quarantänebecken. Unbegrenzte Aquarien sind Teil von ReefTracker Pro.';
  }

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

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
      'Umrechnung zwischen praktischer Salinität (ppt) und spezifischem Gewicht (SG). Tippe in eines der Felder.';

  @override
  String get specificGravity => 'Spezifisches Gewicht';

  @override
  String get referencePoints => 'Referenzwerte';

  @override
  String get refSeawater => '• Natürliches Meerwasser ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget => '• Typisches Riff-Ziel ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG bezieht sich auf 25 °C. Die Umrechnung ist eine lineare Näherung: SG = 1 + ppt × 0,0264/35.';

  @override
  String get doseCalcTitle => 'Dosierungsrechner';

  @override
  String get doseCalcIntro =>
      'Schätzt, wie schnell dein Becken ein Element verbraucht, und die Tagesdosis, die es stabil hält. Wasserwechsel werden nicht berücksichtigt.';

  @override
  String get doseCalcElement => 'Element';

  @override
  String get doseCalcWindow => 'Messzeitraum';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Messungen im Zeitraum',
      one: '1 Messung im Zeitraum',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dosis am $date geändert; Messungen davor spiegeln eine andere Dosis wider.';
  }

  @override
  String get doseCalcVolume => 'Beckenvolumen';

  @override
  String get doseCalcCurrentDose => 'Aktuelle Tagesdosis';

  @override
  String get doseCalcManualDose => 'Manuelle Dosis im Zeitraum';

  @override
  String get doseCalcManualDoseHelp =>
      'Optional: Summe der einmaligen oder zusätzlichen Dosen, die im Messzeitraum gegeben wurden. Bleibt das Feld leer, werden die erfassten manuellen Dosen verwendet.';

  @override
  String get doseCalcManualInput => 'Manuelle Dosen erhöhen um';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erfasste Dosen im Zeitraum: $total',
      one: '1 erfasste Dosis im Zeitraum: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count erfasste Dosen verwenden eine andere Einheit und werden nicht mitgezählt.',
      one:
          '1 erfasste Dosis verwendet eine andere Einheit und wird nicht mitgezählt.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Einige erfasste Dosen sind ein anderes Produkt — ihre Stärke kann von der oben angegebenen abweichen.';

  @override
  String get doseCalcPerDay => 'Tag';

  @override
  String get doseCalcPotencyTitle => 'Stärke des Präparats';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Es wird die Katalogstärke für dieses Produkt verwendet.';

  @override
  String get doseCalcEnterManually => 'Manuell eingeben';

  @override
  String get doseCalcUseCatalog => 'Katalogwert verwenden';

  @override
  String get doseCalcRefAmount => 'Dosis';

  @override
  String get doseCalcRefVolume => 'Pro Volumen';

  @override
  String get doseCalcRise => 'Erhöht um';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Ergebnis';

  @override
  String get doseCalcObservedChange => 'Gemessene Änderung';

  @override
  String get doseCalcConsumption => 'Verbrauch';

  @override
  String get doseCalcCurrentInput => 'Aktuelle Dosierung liefert';

  @override
  String get doseCalcSuggestedDose => 'Empfohlene Tagesdosis';

  @override
  String get doseCalcAdjustment => 'Anpassung';

  @override
  String get doseCalcStable =>
      'Deine aktuelle Dosis hält dieses Element stabil – beibehalten.';

  @override
  String get doseCalcIncrease =>
      'Erhöhe die Dosis, um dieses Element stabil zu halten.';

  @override
  String get doseCalcDecrease =>
      'Du kannst die Dosis senken und das Element trotzdem stabil halten.';

  @override
  String get doseCalcOverdosing =>
      'Dieses Element steigt – Dosierung reduzieren oder pausieren.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Es wird nichts dosiert und dieses Element fällt nicht – keine Dosierung nötig.';

  @override
  String get doseCalcNeedsPotency =>
      'Gib die Stärke des Präparats ein, um eine Dosisempfehlung zu erhalten.';

  @override
  String get doseCalcInsufficient =>
      'Füge mindestens zwei Messungen an verschiedenen Tagen und ein Beckenvolumen hinzu, um zu rechnen.';

  @override
  String get trendSection => 'Trends';

  @override
  String get trendShowTitle => 'Trends anzeigen';

  @override
  String get trendShowSubtitle =>
      'Sagt voraus, wohin sich jeder Parameter entwickelt und wann er seinen Bereich verlässt';

  @override
  String get trendWindow => 'Verwendete Messwerte';

  @override
  String trendWindowSubtitle(int days) {
    return 'Wie viele der letzten Messwerte den Trend bestimmen; bei häufigeren Messungen erweitert auf mindestens $days Tage';
  }

  @override
  String get trendTitle => 'Aktueller Trend';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/Tag';
  }

  @override
  String get trendFlat => 'Bleibt stabil';

  @override
  String get trendWithinRange => 'Bleibt bei diesem Tempo im Bereich';

  @override
  String trendAmberInDays(int days) {
    return 'Erreicht die Achtung-Zone in ~$days T';
  }

  @override
  String trendRedInDays(int days) {
    return 'Erreicht die kritische Zone in ~$days T';
  }

  @override
  String trendChipAmber(int days) {
    return 'Achtung ~$days T';
  }

  @override
  String trendChipRed(int days) {
    return 'Handeln ~$days T';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Erholt sich — wieder im Bereich in ~$days T';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Erholt sich ~$days T';
  }

  @override
  String get trendHorizon => 'Warnhorizont';

  @override
  String get trendHorizonSubtitle =>
      'Parameter nur markieren, wenn er innerhalb dieser Zeit seinen Bereich verlässt';

  @override
  String trendHorizonDays(int days) {
    return '$days Tage';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Achtung';

  @override
  String get zoneActNow => 'Sofort handeln';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Nur Fische';

  @override
  String get setupSoft => 'Weichkorallen';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Gemischtes Riff';

  @override
  String get paramTemperature => 'Temperatur';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Salinität';

  @override
  String get paramAlkalinity => 'Alkalinität (KH)';

  @override
  String get paramCalcium => 'Kalzium (Ca)';

  @override
  String get paramMagnesium => 'Magnesium (Mg)';

  @override
  String get paramNitrate => 'Nitrat (NO₃)';

  @override
  String get paramPhosphate => 'Phosphat (PO₄)';

  @override
  String get paramAmmonia => 'Ammoniak (NH₃/₄)';

  @override
  String get paramNitrite => 'Nitrit (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Kalium (K)';

  @override
  String get paramStrontium => 'Strontium (Sr)';

  @override
  String get paramIodine => 'Jod (I)';

  @override
  String get paramIron => 'Eisen (Fe)';

  @override
  String get paramSodium => 'Natrium (Na)';

  @override
  String get paramSulfur => 'Schwefel (S)';

  @override
  String get paramBoron => 'Bor (B)';

  @override
  String get paramBromine => 'Brom (Br)';

  @override
  String get paramSilicon => 'Silizium (Si)';

  @override
  String get paramZinc => 'Zink (Zn)';

  @override
  String get paramVanadium => 'Vanadium (V)';

  @override
  String get paramCopper => 'Kupfer (Cu)';

  @override
  String get paramNickel => 'Nickel (Ni)';

  @override
  String get paramManganese => 'Mangan (Mn)';

  @override
  String get paramMolybdenum => 'Molybdän (Mo)';

  @override
  String get paramChromium => 'Chrom (Cr)';

  @override
  String get paramCobalt => 'Cobalt (Co)';

  @override
  String get paramLithium => 'Lithium (Li)';

  @override
  String get paramBarium => 'Barium (Ba)';

  @override
  String get paramSelenium => 'Selen (Se)';

  @override
  String get paramAluminium => 'Aluminium (Al)';

  @override
  String get paramAntimony => 'Antimon (Sb)';

  @override
  String get paramTin => 'Zinn (Sn)';

  @override
  String get paramBeryllium => 'Beryllium (Be)';

  @override
  String get paramSilver => 'Silber (Ag)';

  @override
  String get paramTungsten => 'Wolfram (W)';

  @override
  String get paramLanthanum => 'Lanthan (La)';

  @override
  String get paramTitanium => 'Titan (Ti)';

  @override
  String get paramZirconium => 'Zirkonium (Zr)';

  @override
  String get paramArsenic => 'Arsen (As)';

  @override
  String get paramCadmium => 'Cadmium (Cd)';

  @override
  String get paramMercury => 'Quecksilber (Hg)';

  @override
  String get paramLead => 'Blei (Pb)';

  @override
  String get microTitle => 'Spurenelemente';

  @override
  String get microSectionMajor => 'Hauptelemente';

  @override
  String get microSectionTrace => 'Spurenelemente';

  @override
  String get microSectionContaminants => 'Schadstoffe';

  @override
  String get microNotMeasured => 'Nicht gemessen';

  @override
  String get microEmptyHint =>
      'Spurenelemente aus Heimtests oder ICP-Laborberichten verfolgen.';

  @override
  String get microAllOk => 'Alles im Bereich';

  @override
  String microOutOfRangeN(int count) {
    return '$count außerhalb des Bereichs';
  }

  @override
  String microLastMeasured(String date) {
    return 'Zuletzt gemessen am $date';
  }

  @override
  String get microAddMeasurements => 'Messwerte erfassen';

  @override
  String get microAddTitle => 'Spurenelement-Messwerte';

  @override
  String get microChipHobby => 'Heimtests';

  @override
  String get microChipFullIcp => 'Komplettes ICP';

  @override
  String get microReminderTooltip => 'Test-Erinnerung';

  @override
  String get microReminderTitle => 'Erinnerung an Spurenelement-Test';

  @override
  String get microReminderHint =>
      'Fügt dem Wartungsplan eine Aufgabe hinzu, die regelmäßig an den Spurenelement-Test erinnert.';

  @override
  String get microReminderCreated => 'Erinnerung zum Wartungsplan hinzugefügt';

  @override
  String get microIcpTaskTitle => 'Spurenelement-Test (ICP)';

  @override
  String get microToggleSubtitle =>
      'Im Messwerte-Tab anzeigen, mit Test-Erinnerungen. Beim Ausblenden bleiben die Messwerte erhalten.';

  @override
  String get microViewFull => 'Vollständige Liste';

  @override
  String get microViewNew => 'Neue Ansicht';

  @override
  String get microViewEdit => 'Ansicht bearbeiten';

  @override
  String get microViewManage => 'Ansichten verwalten';

  @override
  String get microConfigureTitle => 'Element-Einstellungen';

  @override
  String get microViewNone =>
      'Noch keine eigenen Ansichten. Eine Ansicht zeigt nur die Elemente, die Ihr Labor misst.';

  @override
  String get microViewNameHint => 'z. B. Panel meines Labors';

  @override
  String get microViewNeedElement => 'Mindestens ein Element auswählen.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get microViewDeleteBody =>
      'Entfernt nur die Ansicht. Die Messwerte bleiben erhalten.';

  @override
  String get microHideUndetectable => 'Nicht nachweisbare ausblenden (null)';

  @override
  String get microAttentionOnly => 'Nur Elemente, die Aufmerksamkeit brauchen';

  @override
  String get microFilterAllHidden =>
      'Keine Elemente entsprechen den aktuellen Filtern.';

  @override
  String get icpImportTitle => 'ICP-Bericht importieren';

  @override
  String get icpImportFormatHint => 'Wählen Sie das Exportformat der Datei.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'CSV-Export aus dem Fauna-Marin-Laborportal';

  @override
  String get icpImportFormatZimsHint =>
      'Universelles Mess-CSV (Datum, Messung, Wert, Einheit)';

  @override
  String get icpImportUnreadable => 'Die Datei konnte nicht gelesen werden.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Dies sieht nicht nach einem $format-Export aus.';
  }

  @override
  String get icpImportNoValues =>
      'In der Datei wurden keine importierbaren Werte gefunden.';

  @override
  String get icpImportSampleDateHint =>
      'Vorausgefüllt mit dem Analysedatum aus dem Bericht. Ändern Sie es auf den Tag der Probenentnahme.';

  @override
  String get icpImportSectionCore => 'Basisparameter';

  @override
  String icpImportSkipped(String list) {
    return 'Nicht importiert (kein passender Parameter): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werte importieren',
      one: '1 Wert importieren',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Probe bereits importiert?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Vorhandene Messungen erwähnen bereits Probe $id. Trotzdem erneut importieren?';
  }

  @override
  String get icpImportAnyway => 'Trotzdem importieren';

  @override
  String icpImportNotePrefill(String id) {
    return 'ICP-Probe $id';
  }

  @override
  String get unitFixedNote => 'Dieser Parameter verwendet immer diese Einheit.';

  @override
  String get helpTemperature =>
      'Wassertemperatur. Stabilität ist wichtiger als der exakte Wert.';

  @override
  String get helpSalinity => 'Spezifisches Gewicht. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Karbonathärte. Stabil halten — Schwankungen vermeiden.';

  @override
  String get helpNitrate =>
      'Ein Nährstoff. Korallen brauchen etwas davon; zu viel fördert Algen.';

  @override
  String get helpAmmonia =>
      'Giftig. Sollte in einem eingefahrenen Becken praktisch null sein.';

  @override
  String get healthTitle => 'Beckenzustand';

  @override
  String get healthGradeExcellent => 'Ausgezeichnet';

  @override
  String get healthGradeGood => 'Gut';

  @override
  String get healthGradeCaution => 'Achtung';

  @override
  String get healthGradeCritical => 'Kritisch';

  @override
  String get healthGradeUnknown => 'Keine Daten';

  @override
  String get healthAllOnTarget => 'Alle Parameter im Zielbereich';

  @override
  String healthParamsToWatch(int count) {
    return '$count zu beobachten';
  }

  @override
  String get healthSectionAttention => 'Braucht Aufmerksamkeit';

  @override
  String get healthSectionGood => 'Alles gut';

  @override
  String get healthSectionStale => 'Länger nicht gemessen';

  @override
  String healthNotTestedDays(int count) {
    return 'Seit $count d nicht gemessen';
  }

  @override
  String get healthNeverTested => 'Noch nicht gemessen';

  @override
  String get healthNoReadingsYet => 'Noch keine Messwerte';

  @override
  String healthScoreOf(int score) {
    return '$score von 100';
  }

  @override
  String get stabilityTitle => 'Stabilität';

  @override
  String get stabilityScoreProName => 'Stabilitätswert';

  @override
  String get stabilityGradeRockSolid => 'Felsenfest';

  @override
  String get stabilityGradeSteady => 'Stabil';

  @override
  String get stabilityGradeVariable => 'Schwankend';

  @override
  String get stabilityGradeUnstable => 'Instabil';

  @override
  String get stabilityGradeUnknown => 'Keine Daten';

  @override
  String stabilityIntro(int days) {
    return 'Wie gleichmäßig sich die Parameter in den letzten $days Tagen gehalten haben.';
  }

  @override
  String get stabilitySectionVariable => 'Schwankt am stärksten';

  @override
  String get stabilitySectionSteady => 'Hält stabil';

  @override
  String get stabilitySectionInsufficient => 'Zu wenig Daten';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Messungen in den letzten $days Tagen',
      one: '1 Messung in den letzten $days Tagen',
      zero: 'Keine Messungen in den letzten $days Tagen',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Stabilitätsfenster';

  @override
  String get stabilityWindowSubtitle =>
      'Zeitraum, den der Stabilitätswert betrachtet';

  @override
  String get insightsTitle => 'Hinweise';

  @override
  String get insightsProName => 'Smarte Hinweise';

  @override
  String get insightsIntro => 'Worauf die letzten Messungen hindeuten.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count weitere',
      one: '+1 weiterer',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param liegt unter dem Zielbereich';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param ist niedrig und fällt weiter';
  }

  @override
  String insightHigh(Object param) {
    return '$param liegt über dem Zielbereich';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param ist hoch und steigt weiter';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param liegt außerhalb des Zielbereichs';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param sinkt — verlässt den Bereich evtl. in ~$days T';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param steigt — verlässt den Bereich evtl. in ~$days T';
  }

  @override
  String insightRecovering(Object param) {
    return '$param erholt sich Richtung Zielbereich';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param erholt sich — wieder im Bereich in ~$days T';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param seit $days d nicht gemessen';
  }

  @override
  String get dashboardSection => 'Dashboard';

  @override
  String get healthDisplayTitle => 'Beckenzustand';

  @override
  String get healthDisplaySubtitle => 'Wo die Zustandsübersicht erscheint';

  @override
  String get healthDisplayBoth => 'Abzeichen & Karte';

  @override
  String get healthDisplayBadge => 'Nur Abzeichen';

  @override
  String get healthDisplayOff => 'Verborgen';

  @override
  String get routeNotFoundTitle => 'Seite nicht gefunden';

  @override
  String get routeNotFoundBody => 'Dieser Link führt in der App nirgendwohin.';

  @override
  String get routeNotFoundGoHome => 'Zum Startbildschirm';

  @override
  String get notifChannelTesting => 'Test-Erinnerungen';

  @override
  String get notifChannelDosing => 'Dosier-Erinnerungen';

  @override
  String get notifChannelMaintenance => 'Wartungs-Erinnerungen';

  @override
  String get notifTestingTitle => 'Zeit zum Testen';

  @override
  String get notifDosingTitle => 'Dosierung fällig';

  @override
  String get notifMaintenanceTitle => 'Wartung fällig';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Erinnerungen';

  @override
  String get remindersSubtitle =>
      'Benachrichtigungen für Tests, Dosierung und Wartung';

  @override
  String get remindersTestingSubtitle => 'Wenn ein Parametertest fällig ist';

  @override
  String get remindersDosingSubtitle => 'Zur Dosierzeit jedes Präparats';

  @override
  String get remindersMaintenanceSubtitle => 'Wenn geplante Wartung fällig ist';

  @override
  String get reminderTimeTitle => 'Erinnerungszeit';

  @override
  String get reminderTimeSubtitle =>
      'Uhrzeit für Test- und Wartungserinnerungen';

  @override
  String get remindersPermissionDenied =>
      'Benachrichtigungen sind in den Systemeinstellungen blockiert – Erinnerungen können nicht angezeigt werden.';

  @override
  String get remindToTest => 'An Tests erinnern';

  @override
  String get cadenceOff => 'Aus';

  @override
  String daysShortN(int count) {
    return '$count T.';
  }

  @override
  String get cadenceCustom => 'Eigene';

  @override
  String get customDaysLabel => 'Tage';

  @override
  String get remindMe => 'Erinnern';

  @override
  String get remindMeNeedsTime => 'Für Erinnerungen eine Uhrzeit festlegen';

  @override
  String get maintenanceSchedule => 'Wartungsplan';

  @override
  String get addMaintenanceTask => 'Aufgabe hinzufügen';

  @override
  String get editMaintenanceTask => 'Aufgabe bearbeiten';

  @override
  String get taskTypeLabel => 'Typ';

  @override
  String get customTask => 'Eigene Aufgabe';

  @override
  String get taskTitleLabel => 'Titel';

  @override
  String get taskTitleRequired => 'Titel eingeben';

  @override
  String get repeatLabel => 'Wiederholung';

  @override
  String get oneOff => 'Einmalig';

  @override
  String get dueDateLabel => 'Fälligkeitsdatum';

  @override
  String get dueDateRequired => 'Fälligkeitsdatum wählen';

  @override
  String get dueToday => 'Heute fällig';

  @override
  String dueInDaysN(int count) {
    return 'Fällig in $count T.';
  }

  @override
  String overdueDaysN(int count) {
    return '$count T. überfällig';
  }

  @override
  String get markDone => 'Erledigt';

  @override
  String get taskMarkedDone => 'Als erledigt markiert';

  @override
  String get taskDeleted => 'Aufgabe gelöscht';

  @override
  String get scheduleEmptyBody =>
      'Noch keine Wartungsaufgaben. Plane Wasserwechsel oder eigene Aufgaben für Fälligkeits-Chips und Erinnerungen.';

  @override
  String get repeatModeLabel => 'Wiederholung';

  @override
  String get repeatEveryDays => 'Alle X Tage';

  @override
  String get repeatEveryWeeks => 'Alle X Wochen';

  @override
  String get repeatEveryMonths => 'Alle X Monate';

  @override
  String get repeatOnWeekdays => 'Wochentage';

  @override
  String get repeatOnMonthDay => 'Tag im Monat';

  @override
  String get weeksLabel => 'Wochen';

  @override
  String get monthsLabel => 'Monate';

  @override
  String get monthDayLabel => 'Tag im Monat (1–31)';

  @override
  String get invalidInterval => 'Ganze Zahl eingeben (mindestens 1).';

  @override
  String get invalidMonthDay => 'Tag zwischen 1 und 31 eingeben.';

  @override
  String get weekdaysRequired => 'Mindestens einen Tag auswählen.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Alle $n Wochen',
      one: 'Jede Woche',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Alle $n Monate',
      one: 'Jeden Monat',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'Jeden $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Monatlich am $n.';
  }

  @override
  String get roUnitTitle => 'Umkehrosmoseanlage';

  @override
  String get roStageSediment => 'Sedimentfilter';

  @override
  String get roStageCarbonBlock => 'Kohleblock';

  @override
  String get roStageMembrane => 'RO-Membran';

  @override
  String get roStageDiResin => 'DI-Harz';

  @override
  String get roCustomStage => 'Eigenes Teil';

  @override
  String get roAddStage => 'Teil hinzufügen';

  @override
  String get roEditStage => 'Teil bearbeiten';

  @override
  String get roLifespanLabel => 'Wechseln alle';

  @override
  String get roUnitDays => 'Tage';

  @override
  String get roUnitWeeks => 'Wochen';

  @override
  String get roUnitMonths => 'Monate';

  @override
  String get roPartOfUnit => 'Teil meiner Anlage';

  @override
  String get roPartOfUnitHint =>
      'Ausschalten, wenn Ihre Anlage diese Stufe nicht hat';

  @override
  String get roHiddenStages => 'Nicht an meiner Anlage';

  @override
  String get roMarkReplaced => 'Gewechselt';

  @override
  String get roReplacedRecorded => 'Wechsel erfasst';

  @override
  String roLastReplaced(String date) {
    return 'Gewechselt am $date';
  }

  @override
  String get roNoReplacementYet => 'Noch kein Wechsel erfasst';

  @override
  String get roDeleteStageTitle => 'Teil löschen?';

  @override
  String get roDeleteStageBody =>
      'Entfernt das Teil samt Wechselverlauf. Kann nicht rückgängig gemacht werden.';

  @override
  String get roEmptyBody =>
      'Keine Teile. Fügen Sie die Filter Ihrer Osmoseanlage mit + hinzu.';

  @override
  String get roSetupPrompt => 'Filter- und Membranwechsel im Blick behalten';

  @override
  String get roUnitToggleSubtitle =>
      'Im Aktionen-Tab anzeigen, mit Erinnerungen an Filterwechsel';

  @override
  String get roAllOk => 'Alle Teile in Ordnung';

  @override
  String get notifRoTitle => 'Osmose-Filter wechseln';
}
