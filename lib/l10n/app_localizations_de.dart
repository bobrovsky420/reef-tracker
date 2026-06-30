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
  String get apply => 'Anwenden';

  @override
  String get change => 'Ändern';

  @override
  String errorWith(Object message) {
    return 'Fehler: $message';
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
  String get edit => 'Bearbeiten';

  @override
  String deleteTankTitle(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteTankBody =>
      'Dadurch werden das Aquarium und alle seine Messungen dauerhaft gelöscht.';

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
      'Dadurch werden die grün/orange/rot-Grenzen aller verfolgten Parameter mit den Standardwerten der Voreinstellung überschrieben. Deine Messungen bleiben erhalten.';

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
  String get noteOptional => 'Notiz (optional)';

  @override
  String get saveReadings => 'Messungen speichern';

  @override
  String invalidNumberFor(Object name) {
    return 'Ungültige Zahl für $name';
  }

  @override
  String get enterAtLeastOneValue => 'Gib mindestens einen Wert ein.';

  @override
  String savedReadings(int count) {
    return '$count Messung(en) gespeichert.';
  }

  @override
  String get noTrackedToRecord => 'Keine verfolgten Parameter zum Erfassen.';

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
  String get deleteMeasurementTitle => 'Messung löschen?';

  @override
  String get deleteMeasurementBody =>
      'Dadurch wird dieser Wert dauerhaft gelöscht.';

  @override
  String get deleteTogetherTitle => 'Messung löschen';

  @override
  String deleteTogetherBody(int count) {
    return 'Dieser Wert wurde zusammen mit $count weiteren Messungen erfasst. Nur diesen Wert oder alle zusammen erfassten Werte löschen?';
  }

  @override
  String get deleteOnlyThis => 'Nur diesen Wert';

  @override
  String get deleteAllTogether => 'Alle zusammen';

  @override
  String get editTogetherTitle => 'Messzeitpunkt ändern';

  @override
  String editTogetherBody(int count) {
    return 'Dieser Wert wurde zusammen mit $count weiteren Messungen erfasst. Den Zeitpunkt nur für diesen Wert oder für alle zusammen erfassten Werte ändern?';
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
  String get deleteWaterChangeTitle => 'Wasserwechsel löschen?';

  @override
  String get deleteWaterChangeBody =>
      'Dadurch wird dieser Wasserwechsel dauerhaft gelöscht.';

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
  String get deleteCarbonChangeTitle => 'Kohlewechsel löschen?';

  @override
  String get deleteCarbonChangeBody =>
      'Dadurch wird dieser Kohlewechsel dauerhaft gelöscht.';

  @override
  String get equipmentCleaning => 'Gerätereinigung';

  @override
  String get recordEquipmentCleaning => 'Gerätereinigung erfassen';

  @override
  String get deleteEquipmentCleaningTitle => 'Gerätereinigung löschen?';

  @override
  String get deleteEquipmentCleaningBody =>
      'Dadurch wird diese Gerätereinigung dauerhaft gelöscht.';

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
  String get deleteDosingTitle => 'Präparat entfernen?';

  @override
  String get deleteDosingBody =>
      'Dadurch wird dieses Präparat aus dem Dosierplan entfernt.';

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
  String dosingEveryDaysN(Object n) {
    return 'Alle $n Tage';
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
  String get backupExport => 'Sicherung exportieren';

  @override
  String get backupExportSubtitle =>
      'Alle Aquarien und Messwerte in eine Datei speichern';

  @override
  String get backupImport => 'Aus Sicherung wiederherstellen';

  @override
  String get backupImportSubtitle =>
      'Alle Daten durch eine Sicherungsdatei ersetzen';

  @override
  String get backupRestoreConfirmTitle => 'Sicherung wiederherstellen?';

  @override
  String get backupRestoreConfirmBody =>
      'Dadurch werden alle aktuellen Aquarien, Parameter und Messwerte durch den Inhalt der Sicherungsdatei ersetzt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get backupRestored => 'Sicherung wiederhergestellt';

  @override
  String get backupExportFailed => 'Sicherung konnte nicht exportiert werden';

  @override
  String get backupImportFailed =>
      'Sicherung konnte nicht wiederhergestellt werden';

  @override
  String get backupInvalidFile =>
      'Diese Datei ist keine gültige ReefTracker-Sicherung';

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
  String get aboutAppName => 'Über ReefTracker';

  @override
  String get aboutDescription =>
      'Offline-Tracker für Meerwasseraquarium-Parameter mit Verlauf, Zeitdiagrammen und grün/orange/rot-Gesundheitszonen.';

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
  String doseCalcReadings(Object count) {
    return '$count Messungen im Zeitraum';
  }

  @override
  String get doseCalcVolume => 'Beckenvolumen';

  @override
  String get doseCalcCurrentDose => 'Aktuelle Tagesdosis';

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
  String get trendWindowSubtitle =>
      'Wie viele der letzten Messwerte den Trend bestimmen';

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
  String get setupFishOnly => 'Nur Fische / FOWLR';

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
  String get paramPotassium => 'Kalium';

  @override
  String get paramStrontium => 'Strontium';

  @override
  String get paramIodine => 'Jod';

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
}
