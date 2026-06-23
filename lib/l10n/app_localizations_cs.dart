// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get settings => 'Nastavení';

  @override
  String get manageParameters => 'Spravovat parametry';

  @override
  String get addReading => 'Přidat měření';

  @override
  String get addAquarium => 'Přidat akvárium';

  @override
  String get manageTanks => 'Spravovat akvária';

  @override
  String get chooseParameters => 'Vybrat parametry';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get delete => 'Smazat';

  @override
  String get apply => 'Použít';

  @override
  String get change => 'Změnit';

  @override
  String errorWith(Object message) {
    return 'Chyba: $message';
  }

  @override
  String get welcomeTitle => 'Vítejte v ReefTrackeru';

  @override
  String get welcomeBody =>
      'Vytvořte své první akvárium a začněte sledovat parametry vody.';

  @override
  String get noParamsTracked =>
      'Pro toto akvárium nejsou sledovány žádné parametry.';

  @override
  String get noReadings => 'Žádná měření';

  @override
  String get timeJustNow => 'právě teď';

  @override
  String timeMinAgo(int count) {
    return 'před $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'před $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'před $count d';
  }

  @override
  String get aquariums => 'Akvária';

  @override
  String get noAquariumsYet => 'Zatím žádná akvária.';

  @override
  String get makeActive => 'Nastavit jako aktivní';

  @override
  String get edit => 'Upravit';

  @override
  String deleteTankTitle(Object name) {
    return 'Smazat „$name“?';
  }

  @override
  String get deleteTankBody =>
      'Tímto trvale smažete akvárium i všechna jeho měření.';

  @override
  String get newAquarium => 'Nové akvárium';

  @override
  String get editAquarium => 'Upravit akvárium';

  @override
  String get name => 'Název';

  @override
  String get nameHint => 'např. Útes v obýváku';

  @override
  String get enterAName => 'Zadejte název';

  @override
  String get setupType => 'Typ nádrže';

  @override
  String get presetSeedNote =>
      'Pro tento typ nádrže se nastaví výchozí parametry a hranice zón. Kdykoli je můžete doladit.';

  @override
  String get volumeOptional => 'Objem (litry, nepovinné)';

  @override
  String get createAquarium => 'Vytvořit akvárium';

  @override
  String litersSuffix(Object value) {
    return '$value l';
  }

  @override
  String get parameters => 'Parametry';

  @override
  String get noActiveAquarium => 'Žádné aktivní akvárium.';

  @override
  String reapplyPreset(Object type) {
    return 'Znovu použít přednastavení $type';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Znovu použít přednastavení $type?';
  }

  @override
  String get reapplyPresetBody =>
      'Tím se hranice zelená/oranžová/červená u všech sledovaných parametrů přepíší výchozími hodnotami přednastavení. Vaše měření zůstanou zachována.';

  @override
  String get presetApplied => 'Přednastavení použito.';

  @override
  String get noBoundariesSet => 'Hranice nenastaveny';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  červená <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Upravit zóny';

  @override
  String get addParameter => 'Přidat parametr';

  @override
  String get allParametersAdded => 'Všechny parametry už jsou přidány.';

  @override
  String unitWithValue(Object unit) {
    return 'Jednotka: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Nastaveno v Nastavení. Hranice níže používají tuto jednotku.';

  @override
  String get unit => 'Jednotka';

  @override
  String get boundAmberLow => 'Červená pod (oranžová dolní)';

  @override
  String get boundGreenLow => 'Zelená od (OK dolní)';

  @override
  String get boundGreenHigh => 'Zelená do (OK horní)';

  @override
  String get boundAmberHigh => 'Červená nad (oranžová horní)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Hodnoty jsou v $unit. Prázdné pole znamená „bez limitu na této straně“.';
  }

  @override
  String get enterANumber => 'Zadejte číslo';

  @override
  String get boundsOrderError =>
      'Hranice musí narůstat: oranžová dolní ≤ zelená dolní ≤ zelená horní ≤ oranžová horní.';

  @override
  String get measuredAt => 'Naměřeno';

  @override
  String get noteOptional => 'Poznámka (nepovinné)';

  @override
  String get saveReadings => 'Uložit měření';

  @override
  String invalidNumberFor(Object name) {
    return 'Neplatné číslo pro $name';
  }

  @override
  String get enterAtLeastOneValue => 'Zadejte alespoň jednu hodnotu.';

  @override
  String savedReadings(int count) {
    return 'Uloženo měření: $count.';
  }

  @override
  String get noTrackedToRecord => 'Žádné sledované parametry k zaznamenání.';

  @override
  String get rangeWeek => '7 d';

  @override
  String get rangeMonth => '30 d';

  @override
  String get rangeQuarter => '90 d';

  @override
  String get rangeAll => 'Vše';

  @override
  String get noReadingsInRange => 'V tomto rozsahu nejsou žádná měření.';

  @override
  String get editValue => 'Upravit hodnotu';

  @override
  String get unitsSection => 'Jednotky';

  @override
  String get toolsSection => 'Nástroje';

  @override
  String get aboutSection => 'O aplikaci';

  @override
  String get languageSection => 'Jazyk';

  @override
  String get temperature => 'Teplota';

  @override
  String get salinity => 'Salinita';

  @override
  String get unitUsedAcrossApp => 'Jednotka používaná v celé aplikaci';

  @override
  String get salinityCalculator => 'Kalkulačka salinity';

  @override
  String get salinityCalculatorSubtitle =>
      'Převod ppt ↔ specifická hustota (SG)';

  @override
  String get aboutAppName => 'O aplikaci ReefTracker';

  @override
  String get aboutDescription =>
      'Offline sledování parametrů mořského akvária s historií, časovými grafy a zónami zdraví zelená/oranžová/červená.';

  @override
  String get language => 'Jazyk';

  @override
  String get languageSystem => 'Podle systému';

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
      'Převod mezi praktickou salinitou (ppt) a specifickou hustotou (SG). Pište do kteréhokoli pole.';

  @override
  String get specificGravity => 'Specifická hustota';

  @override
  String get referencePoints => 'Referenční hodnoty';

  @override
  String get refSeawater => '• Přírodní mořská voda ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget =>
      '• Typický cíl pro útes ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG je vztaženo k 25 °C. Převod je lineární aproximace: SG = 1 + ppt × 0,0264/35.';

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Pozor';

  @override
  String get zoneActNow => 'Jednat ihned';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Pouze ryby / FOWLR';

  @override
  String get setupSoft => 'Měkké korály';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Smíšený útes';

  @override
  String get paramTemperature => 'Teplota';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Salinita';

  @override
  String get paramAlkalinity => 'Alkalita (KH)';

  @override
  String get paramCalcium => 'Vápník (Ca)';

  @override
  String get paramMagnesium => 'Hořčík (Mg)';

  @override
  String get paramNitrate => 'Dusičnany (NO₃)';

  @override
  String get paramPhosphate => 'Fosforečnany (PO₄)';

  @override
  String get paramAmmonia => 'Amoniak (NH₃/₄)';

  @override
  String get paramNitrite => 'Dusitany (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Draslík';

  @override
  String get paramStrontium => 'Stroncium';

  @override
  String get paramIodine => 'Jód';

  @override
  String get helpTemperature =>
      'Teplota vody. Stabilita je důležitější než přesná hodnota.';

  @override
  String get helpSalinity => 'Specifická hustota. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Karbonátová tvrdost. Udržujte stabilní — vyhněte se výkyvům.';

  @override
  String get helpNitrate =>
      'Živina. Korály jí potřebují trochu; příliš mnoho podporuje řasy.';

  @override
  String get helpAmmonia =>
      'Toxický. V zajetém akváriu by měl být prakticky nulový.';
}
