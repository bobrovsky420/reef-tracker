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
  String get settings => 'Einstellungen';

  @override
  String get manageParameters => 'Parameter verwalten';

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
  String get volumeOptional => 'Volumen (Liter, optional)';

  @override
  String get createAquarium => 'Aquarium erstellen';

  @override
  String litersSuffix(Object value) {
    return '$value l';
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
  String get measuredAt => 'Gemessen am';

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
  String get editValue => 'Wert bearbeiten';

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
  String get unitUsedAcrossApp => 'In der gesamten App verwendete Einheit';

  @override
  String get salinityCalculator => 'Salinitäts-Rechner';

  @override
  String get salinityCalculatorSubtitle =>
      'Umrechnung ppt ↔ spezifisches Gewicht (SG)';

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
