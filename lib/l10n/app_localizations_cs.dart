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
  String get measurements => 'Měření';

  @override
  String get settings => 'Nastavení';

  @override
  String get manageParameters => 'Spravovat parametry';

  @override
  String get moreOptions => 'Další možnosti';

  @override
  String get tourTankTitle => 'Vaše akvária';

  @override
  String get tourTankDesc =>
      'Klepnutím přepnete mezi akvárii nebo přidáte nové.';

  @override
  String get tourCompareTitle => 'Porovnání';

  @override
  String get tourCompareDesc =>
      'Přepínejte mezi kartami parametrů a souhrnnými grafy.';

  @override
  String get tourParamsTitle => 'Správa parametrů';

  @override
  String get tourParamsDesc =>
      'Vyberte, které parametry vody sledovat, a nastavte jejich cílové rozsahy.';

  @override
  String get tourDosingHistoryTitle => 'Historie dávkování';

  @override
  String get tourDosingHistoryDesc =>
      'Prohlédněte si všechna minulá i současná období dávkování a odeberte omylem zadaný záznam.';

  @override
  String get tourDoseCalcTitle => 'Kalkulačka dávkování';

  @override
  String get tourDoseCalcDesc =>
      'Na kartě Dávkování otevřete kalkulačku pro odhad denní dávky, která udrží prvek stabilní.';

  @override
  String get tourNext => 'Další';

  @override
  String get tourDone => 'Rozumím';

  @override
  String get tourSkip => 'Přeskočit';

  @override
  String get replayTour => 'Spustit prohlídku znovu';

  @override
  String get replayTourSubtitle => 'Znovu zobrazit tipy k horní liště';

  @override
  String get compareView => 'Porovnat grafy';

  @override
  String get gridView => 'Mřížka';

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
  String get stop => 'Zastavit';

  @override
  String get apply => 'Použít';

  @override
  String get change => 'Změnit';

  @override
  String get undo => 'Zpět';

  @override
  String get itemDeleted => 'Smazáno';

  @override
  String get reorder => 'Změnit pořadí';

  @override
  String errorWith(Object message) {
    return 'Chyba: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Nepodařilo se uložit: $error';
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
  String get dashSectionCoreChemistry => 'Základní chemie';

  @override
  String get dashSectionNutrients => 'Živiny';

  @override
  String get dashSectionRatios => 'Poměry';

  @override
  String get dashSectionEnvironment => 'Prostředí';

  @override
  String gaugeIdealRange(String min, String max) {
    return 'ideálně $min–$max';
  }

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
  String get active => 'Aktivní';

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
  String tankDeleted(Object name) {
    return 'Akvárium „$name“ smazáno';
  }

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
  String get volumeOptional => 'Objem (nepovinné)';

  @override
  String get vendorOptional => 'Výrobce (nepovinné)';

  @override
  String get modelOptional => 'Model (nepovinné)';

  @override
  String get notesOptional => 'Poznámky (nepovinné)';

  @override
  String get createAquarium => 'Vytvořit akvárium';

  @override
  String litersSuffix(Object value) {
    return '$value l';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Datum spuštění';

  @override
  String get notSet => 'Nenastaveno';

  @override
  String get setDate => 'Nastavit';

  @override
  String get clear => 'Vymazat';

  @override
  String sinceDate(Object date) {
    return 'od $date';
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
      'Tím se hranice zelená/oranžová/červená u všech sledovaných parametrů přepíší výchozími hodnotami: parametry na přehledu podle přednastavení typu akvária, mikroprvky podle vestavěných výchozích hodnot. Vaše měření zůstanou zachována.';

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
  String get sectionSafeRanges => 'Bezpečná rozmezí';

  @override
  String get sectionDose => 'Dávka';

  @override
  String get boundsOrderError =>
      'Hranice musí narůstat: oranžová dolní ≤ zelená dolní ≤ zelená horní ≤ oranžová horní.';

  @override
  String get boundsPairError =>
      'Každá oranžová hranice vyžaduje odpovídající zelenou hranici na téže straně.';

  @override
  String get noteOptional => 'Poznámka (nepovinné)';

  @override
  String get saveReadings => 'Uložit měření';

  @override
  String invalidNumberFor(Object name) {
    return 'Neplatné číslo pro $name';
  }

  @override
  String get invalidVolume => 'Zadejte platný kladný objem.';

  @override
  String get invalidPositiveNumber => 'Zadejte kladné číslo.';

  @override
  String get invalidIntervalDays => 'Zadejte celý počet dní (alespoň 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: tato hodnota není fyzikálně možná.';
  }

  @override
  String get impossibleValue => 'Tato hodnota není fyzikálně možná.';

  @override
  String get implausibleTitle => 'Neobvyklé hodnoty';

  @override
  String get implausibleIntro =>
      'Následující hodnota je mimo obvyklý rozsah. Před uložením zkontrolujte překlepy.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (obvykle $min–$max)';
  }

  @override
  String get saveAnyway => 'Přesto uložit';

  @override
  String get enterAtLeastOneValue => 'Zadejte alespoň jednu hodnotu.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uloženo $count měření.',
      few: 'Uložena $count měření.',
      one: 'Uloženo 1 měření.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Žádné sledované parametry k zaznamenání.';

  @override
  String get testSetAll => 'Vše';

  @override
  String get newTestSet => 'Nová testovací sada';

  @override
  String get editTestSet => 'Upravit testovací sadu';

  @override
  String get manageTestSets => 'Spravovat testovací sady';

  @override
  String get testSetNameHint => 'např. Velký týdenní test';

  @override
  String get testSetNeedParam => 'Vyberte alespoň jeden parametr.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Smazat „$name“?';
  }

  @override
  String get deleteTestSetBody =>
      'Testovací sada bude odstraněna. Vaše měření zůstanou zachována.';

  @override
  String get testSetEmptyHint =>
      'Tato sada neobsahuje žádné aktivní parametry. Upravte ji, nebo přepněte na Vše.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parametrů',
      few: '$count parametry',
      one: '1 parametr',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Zatím žádné testovací sady. Sada umožní zaznamenat jen parametry, které testujete společně.';

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
  String get recordFirstReading => 'Zaznamenat první měření';

  @override
  String get statMin => 'Min';

  @override
  String get statAvg => 'Průměr';

  @override
  String get statMax => 'Max';

  @override
  String get statTests => 'Testy';

  @override
  String get editMeasurement => 'Upravit měření';

  @override
  String get deleteTogetherTitle => 'Smazat měření';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tato hodnota byla zadána společně s $count dalšími měřeními. Smazat pouze tuto hodnotu, nebo všechny hodnoty zadané společně?',
      one:
          'Tato hodnota byla zadána společně s 1 dalším měřením. Smazat pouze tuto hodnotu, nebo všechny hodnoty zadané společně?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Pouze tuto hodnotu';

  @override
  String get deleteAllTogether => 'Vše společně';

  @override
  String get editTogetherTitle => 'Změnit čas měření';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tato hodnota byla zadána společně s $count dalšími měřeními. Změnit čas pouze pro tuto hodnotu, nebo pro všechny hodnoty zadané společně?',
      one:
          'Tato hodnota byla zadána společně s 1 dalším měřením. Změnit čas pouze pro tuto hodnotu, nebo pro všechny hodnoty zadané společně?',
    );
    return '$_temp0';
  }

  @override
  String get freeAmmoniaLabel => 'Volný amoniak (NH₃)';

  @override
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp) {
    return '$percent % toxických · pH $ph · $temp';
  }

  @override
  String freeAmmoniaPercent(Object percent) {
    return '$percent % toxických';
  }

  @override
  String get freeAmmoniaExplain =>
      'Test amoniaku měří celkový amoniak, ale toxická je jen neionizovaná část (NH₃). Její podíl roste s pH a teplotou, takže rifové akvárium přeměňuje na toxickou formu více amoniaku než nádrž s nízkým pH. Tento odhad rozdělí poslední naměřený celkový amoniak podle posledního pH, teploty a salinity.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Toxický volný amoniak: $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return '$percent % z vašich $total ppm celkového amoniaku je v toxické formě NH₃.';
  }

  @override
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity) {
    return 'Na základě pH $ph, $temp a $salinity.';
  }

  @override
  String freeAmmoniaSalinityAssumed(Object value) {
    return '$value (předpoklad)';
  }

  @override
  String get freeAmmoniaOutdatedWarning =>
      'pH nebo teplota byly naposledy měřeny více než týden od tohoto měření amoniaku, takže podíl toxické formy může být nepřesný.';

  @override
  String get freeAmmoniaShowTitle => 'Zobrazit volný amoniak (NH₃)';

  @override
  String get freeAmmoniaShowSubtitle =>
      'Přidá kartu odhadující toxický neionizovaný podíl z pH, teploty a salinity.';

  @override
  String get freeAmmoniaNeedsAmmonia => 'Zobrazí se po zapnutí amoniaku.';

  @override
  String get close => 'Zavřít';

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Poměr PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Poměr Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : Alk';

  @override
  String get ratioCaAlkTitle => 'Poměr Ca : Alk';

  @override
  String get ratioMgAlkLabel => 'Mg : Alk';

  @override
  String get ratioMgAlkTitle => 'Poměr Mg : Alk';

  @override
  String get ratioNoData =>
      'Zaznamenejte oba parametry, abyste viděli jejich poměr.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Hranice zón používají $metric, hodnotu zobrazenou na kartě.';
  }

  @override
  String get waterChanges => 'Výměny vody';

  @override
  String get recordWaterChange => 'Zaznamenat výměnu vody';

  @override
  String get amountLitersOptional => 'Množství (volitelné)';

  @override
  String get noWaterChanges => 'Zatím žádné výměny vody.';

  @override
  String get amountNotRecorded => 'Množství nezaznamenáno';

  @override
  String get actions => 'Úkony';

  @override
  String get noActions => 'Zatím žádné úkony.';

  @override
  String get addAction => 'Přidat úkon';

  @override
  String get waterChange => 'Výměna vody';

  @override
  String get carbonChange => 'Výměna uhlí';

  @override
  String get recordCarbonChange => 'Zaznamenat výměnu uhlí';

  @override
  String get weightOptional => 'Hmotnost (volitelné)';

  @override
  String get weightNotRecorded => 'Hmotnost nezaznamenána';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Čištění vybavení';

  @override
  String get recordEquipmentCleaning => 'Zaznamenat čištění vybavení';

  @override
  String get dosing => 'Dávkování';

  @override
  String get addSupplement => 'Přidat přípravek';

  @override
  String get noDosing => 'Zatím žádné přípravky.';

  @override
  String get noDosingHint =>
      'Přidejte přípravky, které do této nádrže dávkujete – výrobce, produkt a volitelně dávku a rozvrh.';

  @override
  String get dosingNoDosage => 'Dávka nezadána';

  @override
  String get supplementStopped => 'Přípravek zastaven';

  @override
  String get dosingHistoryTitle => 'Historie dávkování';

  @override
  String get dosingHistoryEmpty => 'Zatím žádná historie dávkování.';

  @override
  String get dosingHistoryCurrent => 'Aktuální';

  @override
  String dosingHistorySince(Object date) {
    return 'Od $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Smazat tento záznam?';

  @override
  String get deleteDosingRecordBody =>
      'Tímto trvale odstraníte tento záznam dávkování z historie i z výpočtu dávky. Akci nelze vrátit zpět.';

  @override
  String get deleteDosingRecordNotLatest =>
      'Toto není nejnovější záznam pro tento prvek; jeho smazání neovlivní pozdější záznamy.';

  @override
  String get dosingHistoryManual => 'Ruční';

  @override
  String get manualDoseNew => 'Zaznamenat ruční dávku';

  @override
  String get manualDoseEdit => 'Upravit ruční dávku';

  @override
  String get deleteManualDoseTitle => 'Smazat ruční dávku?';

  @override
  String get deleteManualDoseBody =>
      'Tím se tato zaznamenaná dávka trvale odstraní z historie i z výpočtu dávkování. Nelze to vrátit zpět.';

  @override
  String get dosingNew => 'Přidat přípravek';

  @override
  String get dosingEdit => 'Upravit přípravek';

  @override
  String get dosingVendor => 'Výrobce';

  @override
  String get dosingVendorName => 'Název výrobce';

  @override
  String get dosingProduct => 'Produkt';

  @override
  String get dosingProductName => 'Název produktu';

  @override
  String get dosingElement => 'Prvek';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Jiné…';

  @override
  String get dosingDosageOptional => 'Dávkování (volitelné)';

  @override
  String get dosingAmount => 'Množství';

  @override
  String get dosingUnit => 'Jednotka';

  @override
  String get dosingBasis => 'Základ';

  @override
  String get dosingPerDay => 'za den';

  @override
  String get dosingPerDose => 'na dávku';

  @override
  String get dosingSchedule => 'Rozvrh';

  @override
  String get dosingFrequency => 'Frekvence';

  @override
  String get dosingFreqNone => 'Žádná';

  @override
  String get dosingFreqDaily => 'Denně';

  @override
  String get dosingFreqEveryNDays => 'Každých N dní';

  @override
  String get dosingFreqWeekly => 'Týdně';

  @override
  String get dosingIntervalDays => 'Interval (dny)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Každých $n dní',
      few: 'Každé $n dny',
      one: 'Každý den',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Čas (volitelné)';

  @override
  String get unitsSection => 'Jednotky';

  @override
  String get toolsSection => 'Nástroje';

  @override
  String get aboutSection => 'O aplikaci';

  @override
  String get languageSection => 'Jazyk';

  @override
  String get appearanceSection => 'Vzhled';

  @override
  String get themeTitle => 'Motiv';

  @override
  String get themeSystem => 'Systém';

  @override
  String get themeLight => 'Světlý';

  @override
  String get themeDark => 'Tmavý';

  @override
  String get temperature => 'Teplota';

  @override
  String get salinity => 'Salinita';

  @override
  String get volume => 'Objem';

  @override
  String get unitUsedAcrossApp => 'Jednotka používaná v celé aplikaci';

  @override
  String get salinityCalculator => 'Kalkulačka salinity';

  @override
  String get salinityCalculatorSubtitle =>
      'Převod ppt ↔ specifická hustota (SG)';

  @override
  String get backupSection => 'Záloha';

  @override
  String get backupNow => 'Zálohovat nyní';

  @override
  String backupLastRun(String when) {
    return 'Poslední záloha: $when';
  }

  @override
  String get backupNeverRun => 'Zatím žádná záloha';

  @override
  String backupLastFailed(String when) {
    return 'Poslední záloha se nezdařila $when';
  }

  @override
  String get backupDone => 'Záloha uložena';

  @override
  String get backupExport => 'Exportovat zálohu';

  @override
  String get backupExportSubtitle =>
      'Uložit všechna akvária a měření do souboru';

  @override
  String get csvExportTitle => 'Export měření (CSV)';

  @override
  String get csvExportSubtitle =>
      'Sdílet měření aktivního akvária jako tabulkový soubor';

  @override
  String get csvExportNoData => 'Zatím žádná měření k exportu';

  @override
  String get csvExportFailed => 'Měření se nepodařilo exportovat';

  @override
  String get backupImport => 'Obnovit ze zálohy';

  @override
  String get backupImportSubtitle => 'Nahradit všechna data souborem zálohy';

  @override
  String get backupRestoreConfirmTitle => 'Obnovit zálohu?';

  @override
  String get backupRestoreConfirmBody =>
      'Tímto se VŠECHNA data akvárií — všechna akvária, parametry a měření — nahradí obsahem souboru zálohy. Nastavení v tomto zařízení (jazyk, jednotky a předvolby) zůstane zachováno. Tuto akci nelze vrátit zpět.';

  @override
  String get restore => 'Obnovit';

  @override
  String get backupRestored => 'Záloha obnovena';

  @override
  String get backupNowFailed => 'Zálohu se nepodařilo uložit';

  @override
  String get backupShareFailed => 'Zálohu se nepodařilo sdílet';

  @override
  String get backupExportFailed => 'Zálohu se nepodařilo exportovat';

  @override
  String get backupImportFailed => 'Zálohu se nepodařilo obnovit';

  @override
  String get backupInvalidFile => 'Tento soubor není platná záloha ReefTracker';

  @override
  String get backupTooNew =>
      'Tato záloha byla vytvořena novější verzí aplikace a nelze ji zde obnovit';

  @override
  String get backupCorrupted => 'Soubor zálohy je poškozený nebo neúplný';

  @override
  String get backupInconsistent =>
      'Záloha je nekonzistentní a nelze ji obnovit';

  @override
  String get dataLoadFailed =>
      'Některá data se nepodařilo načíst. Pokud se to opakuje, restartujte aplikaci nebo obnovte zálohu.';

  @override
  String get autoBackupTitle => 'Automatická záloha';

  @override
  String get autoBackupSubtitle =>
      'Uchovávat nedávné kopie dat v tomto zařízení';

  @override
  String get autoBackupFrequency => 'Četnost';

  @override
  String get autoBackupDaily => 'Denně';

  @override
  String get autoBackupWeekly => 'Týdně';

  @override
  String get manageBackups => 'Spravovat zálohy';

  @override
  String get manageBackupsSubtitle =>
      'Zobrazit, obnovit nebo sdílet automatické zálohy';

  @override
  String get backupsScreenTitle => 'Automatické zálohy';

  @override
  String get noAutoBackups => 'Zatím žádné automatické zálohy';

  @override
  String get noAutoBackupsHint =>
      'Záloha se ukládá automaticky během používání aplikace.';

  @override
  String get share => 'Sdílet';

  @override
  String get backupDeleteConfirmTitle => 'Smazat zálohu?';

  @override
  String get backupDeleteConfirmBody =>
      'Tímto trvale odstraníte tento záložní soubor ze zařízení.';

  @override
  String sizeBytes(Object size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(Object size) {
    return '$size kB';
  }

  @override
  String sizeMegabytes(Object size) {
    return '$size MB';
  }

  @override
  String get syncGdriveTitle => 'Synchronizace s Google Diskem';

  @override
  String get syncGdriveSubtitle => 'Automaticky zálohovat na váš Google Disk';

  @override
  String syncGdriveLastPush(String when) {
    return 'Poslední nahrání: $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Zatím nic nenahráno';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'Zálohy se budou synchronizovat na Google Disk účtu $email';
  }

  @override
  String get syncGdriveConnectFailed =>
      'Připojení ke Google Disku se nezdařilo';

  @override
  String syncGdriveDialogBody(String email) {
    return 'Zálohy se nahrávají do složky „ReefTracker“ na Google Disku účtu $email. Můžete si je prohlédnout a stáhnout na drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Odpojit';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Disk odpojen. Již nahrané zálohy zůstávají na vašem Disku.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Nahrání na Google Disk selhalo $when';
  }

  @override
  String get backupsLocalSection => 'V tomto zařízení';

  @override
  String get backupsDriveSection => 'Google Disk';

  @override
  String get backupsDriveEmpty => 'Na Google Disku zatím nejsou žádné zálohy';

  @override
  String get backupsDriveLoadFailed =>
      'Zálohy z Google Disku se nepodařilo načíst';

  @override
  String get aboutAppName => 'O aplikaci ReefTracker';

  @override
  String get aboutDescription =>
      'Offline sledování parametrů mořského akvária s historií, časovými grafy a zónami zdraví zelená/oranžová/červená.';

  @override
  String get editionLabel => 'Edice';

  @override
  String get editionFounder => 'Zakladatelská edice';

  @override
  String get editionStandard => 'Standardní';

  @override
  String get founderInfoBody =>
      'Používáte ReefTracker od jeho začátků. Jako poděkování pro vás všechny dnes dostupné funkce zůstanou navždy zdarma.';

  @override
  String get standardInfoBody =>
      'Používáte standardní edici aplikace ReefTracker.';

  @override
  String get proFeatureTitle => 'Funkce Pro';

  @override
  String proFeatureBody(Object feature) {
    return '$feature je součástí ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Neomezený počet akvárií';

  @override
  String tankLimitBody(Object limit) {
    return 'Standardní edice zahrnuje až $limit akvária — například hlavní nádrž a karanténu. Neomezený počet akvárií je součástí ReefTracker Pro.';
  }

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
  String get languageFrench => 'Français';

  @override
  String get languageItalian => 'Italiano';

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
  String get doseCalcTitle => 'Kalkulačka dávkování';

  @override
  String get doseCalcIntro =>
      'Odhadne, jak rychle nádrž spotřebovává prvek, a denní dávku, která ho udrží stabilní. Výměny vody se neuvažují.';

  @override
  String get doseCalcElement => 'Prvek';

  @override
  String get doseCalcWindow => 'Období měření';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count měření v období',
      one: '1 měření v období',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dávka byla změněna $date; měření před tímto datem odpovídají jiné dávce.';
  }

  @override
  String get doseCalcVolume => 'Objem nádrže';

  @override
  String get doseCalcCurrentDose => 'Aktuální denní dávka';

  @override
  String get doseCalcManualDose => 'Ruční dávka v okně';

  @override
  String get doseCalcManualDoseHelp =>
      'Volitelné: součet jednorázových či mimořádných dávek podaných během měřicího okna. Je-li pole prázdné, použijí se zaznamenané ruční dávky.';

  @override
  String get doseCalcManualInput => 'Ruční dávky přidávají';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaznamenaných dávek v okně: $total',
      few: '$count zaznamenané dávky v okně: $total',
      one: '1 zaznamenaná dávka v okně: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count zaznamenaných dávek používá jinou jednotku a není započteno.',
      few:
          '$count zaznamenané dávky používají jinou jednotku a nejsou započteny.',
      one: '1 zaznamenaná dávka používá jinou jednotku a není započtena.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Některé zaznamenané dávky jsou jiný přípravek — jejich síla se může lišit od zadané výše.';

  @override
  String get doseCalcPerDay => 'den';

  @override
  String get doseCalcPotencyTitle => 'Síla přípravku';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Používá se síla tohoto produktu z katalogu.';

  @override
  String get doseCalcEnterManually => 'Zadat ručně';

  @override
  String get doseCalcUseCatalog => 'Použít hodnotu z katalogu';

  @override
  String get doseCalcRefAmount => 'Dávka';

  @override
  String get doseCalcRefVolume => 'Na objem';

  @override
  String get doseCalcRise => 'Zvýší o';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Výsledek';

  @override
  String get doseCalcObservedChange => 'Naměřená změna';

  @override
  String get doseCalcConsumption => 'Spotřeba';

  @override
  String get doseCalcCurrentInput => 'Současné dávkování přidává';

  @override
  String get doseCalcSuggestedDose => 'Doporučená denní dávka';

  @override
  String get doseCalcAdjustment => 'Úprava';

  @override
  String get doseCalcStable =>
      'Vaše dávka udržuje tento prvek stabilní – ponechte ji.';

  @override
  String get doseCalcIncrease => 'Zvyšte dávku, aby prvek zůstal stabilní.';

  @override
  String get doseCalcDecrease =>
      'Dávku můžete snížit a prvek přesto udržíte stabilní.';

  @override
  String get doseCalcOverdosing =>
      'Tento prvek roste – snižte nebo pozastavte dávkování.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Nic se nedávkuje a tento prvek neklesá – dávkování není potřeba.';

  @override
  String get doseCalcNeedsPotency =>
      'Pro doporučení dávky zadejte sílu přípravku.';

  @override
  String get doseCalcInsufficient =>
      'Pro výpočet přidejte alespoň dvě měření z různých dnů a objem nádrže.';

  @override
  String get doseCalcModeMaintenance => 'Denní dávka';

  @override
  String get doseCalcModeCorrection => 'Korekce';

  @override
  String get doseCalcCorrIntro =>
      'Spočítejte jednorázovou dávku, která zvedne prvek ze současné hodnoty na cílovou. Pokud by byl rychlý nárůst nebezpečný, dávka se rozloží do několika dnů.';

  @override
  String get doseCalcCurrentValue => 'Aktuální hodnota';

  @override
  String get doseCalcCurrentValueHelp => 'Prázdné = vaše poslední měření.';

  @override
  String get doseCalcTargetValue => 'Cílová hodnota';

  @override
  String get doseCalcTargetValueHelp =>
      'Prázdné = korekční cíl parametru, nebo střed jeho bezpečného rozsahu.';

  @override
  String get doseCalcNeededRise => 'Potřebný nárůst';

  @override
  String get doseCalcOneTimeDose => 'Jednorázová dávka';

  @override
  String get doseCalcTotalDose => 'Celková dávka';

  @override
  String get doseCalcDosePerDay => 'Dávka na den';

  @override
  String get doseCalcSpreadDays => 'Rozložit do dnů';

  @override
  String get doseCalcCorrMissing =>
      'Pro výpočet zadejte aktuální hodnotu, cíl a objem nádrže.';

  @override
  String get doseCalcCorrAtTarget =>
      'Hodnota už je na cíli nebo nad ním – není co dávkovat.';

  @override
  String get doseCalcCorrSingle => 'Lze bezpečně podat jako jednu dávku.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Zvyšovat rychleji než o $limit za den je riskantní – podejte korekci raději jako $days denních dávek.';
  }

  @override
  String get doseCalcLogDose => 'Zaznamenat dávku';

  @override
  String get correctionCta => 'Pod rozsahem – spočítat korekční dávku';

  @override
  String get targetValueLabel => 'Korekční cíl';

  @override
  String get targetValueHelp =>
      'Předvyplní korekční režim kalkulačky dávkování. Prázdné = střed bezpečného rozsahu.';

  @override
  String get trendSection => 'Trendy';

  @override
  String get trendShowTitle => 'Zobrazovat trendy';

  @override
  String get trendShowSubtitle =>
      'Předpovídá, kam každý parametr směřuje a kdy opustí svůj rozsah';

  @override
  String get trendWindow => 'Použitá měření';

  @override
  String trendWindowSubtitle(int days) {
    return 'Kolik posledních měření určuje trend; při častějším měření se rozšíří tak, aby pokrylo alespoň $days dní';
  }

  @override
  String get trendTitle => 'Aktuální trend';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/den';
  }

  @override
  String get trendFlat => 'Drží se stabilně';

  @override
  String get trendWithinRange => 'Při tomto tempu zůstává v rozsahu';

  @override
  String trendAmberInDays(int days) {
    return 'Dosáhne zóny pozor za ~$days d';
  }

  @override
  String trendRedInDays(int days) {
    return 'Dosáhne kritické zóny za ~$days d';
  }

  @override
  String trendChipAmber(int days) {
    return 'Pozor ~$days d';
  }

  @override
  String trendChipRed(int days) {
    return 'Jednat ~$days d';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Zlepšuje se — zpět v rozsahu za ~$days d';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Zlepšuje se ~$days d';
  }

  @override
  String get trendHorizon => 'Horizont upozornění';

  @override
  String get trendHorizonSubtitle =>
      'Upozornit na parametr, jen když opustí svůj rozsah do této doby';

  @override
  String trendHorizonDays(int days) {
    return '$days dní';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Pozor';

  @override
  String get zoneActNow => 'Jednat ihned';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Pouze ryby';

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
  String get paramAlkalinity => 'Alkalita';

  @override
  String get paramAlkalinityShort => 'KH';

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
  String get paramPotassium => 'Draslík (K)';

  @override
  String get paramStrontium => 'Stroncium (Sr)';

  @override
  String get paramIodine => 'Jód (I)';

  @override
  String get paramIron => 'Železo (Fe)';

  @override
  String get paramSodium => 'Sodík (Na)';

  @override
  String get paramSulfur => 'Síra (S)';

  @override
  String get paramBoron => 'Bor (B)';

  @override
  String get paramBromine => 'Brom (Br)';

  @override
  String get paramSilicon => 'Křemík (Si)';

  @override
  String get paramZinc => 'Zinek (Zn)';

  @override
  String get paramVanadium => 'Vanad (V)';

  @override
  String get paramCopper => 'Měď (Cu)';

  @override
  String get paramNickel => 'Nikl (Ni)';

  @override
  String get paramManganese => 'Mangan (Mn)';

  @override
  String get paramMolybdenum => 'Molybden (Mo)';

  @override
  String get paramChromium => 'Chrom (Cr)';

  @override
  String get paramCobalt => 'Kobalt (Co)';

  @override
  String get paramLithium => 'Lithium (Li)';

  @override
  String get paramBarium => 'Baryum (Ba)';

  @override
  String get paramSelenium => 'Selen (Se)';

  @override
  String get paramAluminium => 'Hliník (Al)';

  @override
  String get paramAntimony => 'Antimon (Sb)';

  @override
  String get paramTin => 'Cín (Sn)';

  @override
  String get paramBeryllium => 'Beryllium (Be)';

  @override
  String get paramSilver => 'Stříbro (Ag)';

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
  String get paramCadmium => 'Kadmium (Cd)';

  @override
  String get paramMercury => 'Rtuť (Hg)';

  @override
  String get paramLead => 'Olovo (Pb)';

  @override
  String get microTitle => 'Mikroprvky';

  @override
  String get microSectionMajor => 'Hlavní prvky';

  @override
  String get microSectionTrace => 'Stopové prvky';

  @override
  String get microSectionContaminants => 'Kontaminanty';

  @override
  String get microNotMeasured => 'Neměřeno';

  @override
  String get microEmptyHint =>
      'Sledujte stopové prvky z domácích testů nebo laboratorních ICP rozborů.';

  @override
  String get microAllOk => 'Vše v rozmezí';

  @override
  String microOutOfRangeN(int count) {
    return '$count mimo rozmezí';
  }

  @override
  String microLastMeasured(String date) {
    return 'Naposledy měřeno $date';
  }

  @override
  String get microAddMeasurements => 'Přidat měření';

  @override
  String get microAddTitle => 'Měření mikroprvků';

  @override
  String get microChipHobby => 'Domácí testy';

  @override
  String get microChipFullIcp => 'Kompletní ICP';

  @override
  String get microReminderTooltip => 'Připomínka testu';

  @override
  String get microReminderTitle => 'Připomínka testu mikroprvků';

  @override
  String get microReminderHint =>
      'Přidá do plánu údržby úkol připomínající pravidelný test mikroprvků.';

  @override
  String get microReminderCreated => 'Připomínka přidána do plánu údržby';

  @override
  String get microIcpTaskTitle => 'Test mikroprvků (ICP)';

  @override
  String get microToggleSubtitle =>
      'Zobrazit na kartě Měření, s připomínkami testů. Skrytí zachová naměřené hodnoty.';

  @override
  String get microViewFull => 'Úplný seznam';

  @override
  String get microViewNew => 'Nový pohled';

  @override
  String get microViewEdit => 'Upravit pohled';

  @override
  String get microViewManage => 'Spravovat pohledy';

  @override
  String get microConfigureTitle => 'Nastavení prvků';

  @override
  String get microViewNone =>
      'Zatím žádné vlastní pohledy. Pohled zobrazuje jen prvky, které vaše laboratoř měří.';

  @override
  String get microViewNameHint => 'např. Panel mé laboratoře';

  @override
  String get microViewNeedElement => 'Vyberte alespoň jeden prvek.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prvků',
      many: '$count prvku',
      few: '$count prvky',
      one: '1 prvek',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Smazat „$name“?';
  }

  @override
  String get microViewDeleteBody =>
      'Odstraní pouze pohled. Naměřené hodnoty zůstanou zachovány.';

  @override
  String get microHideUndetectable => 'Skrýt nedetekovatelné (nula)';

  @override
  String get microAttentionOnly => 'Jen prvky vyžadující pozornost';

  @override
  String get microFilterAllHidden =>
      'Aktuálním filtrům neodpovídají žádné prvky.';

  @override
  String get icpImportTitle => 'Import ICP analýzy';

  @override
  String get icpImportFormatHint => 'Zvolte formát exportovaného souboru.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'CSV export z laboratorního portálu Fauna Marin';

  @override
  String get icpImportFormatZimsHint =>
      'Univerzální CSV s měřeními (datum, měření, hodnota, jednotka)';

  @override
  String get icpImportUnreadable => 'Soubor se nepodařilo přečíst.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Toto nevypadá jako export $format.';
  }

  @override
  String get icpImportNoValues =>
      'V souboru nebyly nalezeny žádné importovatelné hodnoty.';

  @override
  String get icpImportSampleDateHint =>
      'Předvyplněno datem analýzy z reportu. Změňte je na den, kdy jste odebrali vzorek vody.';

  @override
  String get icpImportSectionCore => 'Základní parametry';

  @override
  String icpImportSkipped(String list) {
    return 'Neimportováno (bez odpovídajícího parametru): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importovat $count hodnot',
      few: 'Importovat $count hodnoty',
      one: 'Importovat 1 hodnotu',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Vzorek už byl importován?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Existující měření už zmiňují vzorek $id. Přesto importovat znovu?';
  }

  @override
  String get icpImportAnyway => 'Přesto importovat';

  @override
  String icpImportNotePrefill(String id) {
    return 'ICP vzorek $id';
  }

  @override
  String get unitFixedNote => 'Tento parametr vždy používá tuto jednotku.';

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

  @override
  String get healthTitle => 'Zdraví nádrže';

  @override
  String get healthGradeExcellent => 'Výborné';

  @override
  String get healthGradeGood => 'Dobré';

  @override
  String get healthGradeCaution => 'Pozor';

  @override
  String get healthGradeCritical => 'Kritické';

  @override
  String get healthGradeUnknown => 'Bez dat';

  @override
  String get healthAllOnTarget => 'Všechny parametry v normě';

  @override
  String healthParamsToWatch(int count) {
    return '$count ke sledování';
  }

  @override
  String get healthSectionAttention => 'Vyžaduje pozornost';

  @override
  String get healthSectionGood => 'V pořádku';

  @override
  String get healthSectionStale => 'Dlouho neměřeno';

  @override
  String healthNotTestedDays(int count) {
    return 'Neměřeno $count d';
  }

  @override
  String get healthNeverTested => 'Zatím neměřeno';

  @override
  String get healthNoReadingsYet => 'Zatím žádná měření';

  @override
  String healthScoreOf(int score) {
    return '$score ze 100';
  }

  @override
  String get stabilityTitle => 'Stabilita';

  @override
  String get stabilityScoreProName => 'Skóre stability';

  @override
  String get stabilityGradeRockSolid => 'Naprosto stabilní';

  @override
  String get stabilityGradeSteady => 'Stabilní';

  @override
  String get stabilityGradeVariable => 'Kolísavá';

  @override
  String get stabilityGradeUnstable => 'Nestabilní';

  @override
  String get stabilityGradeUnknown => 'Bez dat';

  @override
  String stabilityIntro(int days) {
    return 'Jak vyrovnaně se jednotlivé parametry držely za posledních $days dní.';
  }

  @override
  String get stabilitySectionVariable => 'Nejvíce kolísá';

  @override
  String get stabilitySectionSteady => 'Drží se stabilně';

  @override
  String get stabilitySectionInsufficient => 'Málo dat';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count měření za posledních $days dní',
      few: '$count měření za posledních $days dní',
      one: '1 měření za posledních $days dní',
      zero: 'Žádné měření za posledních $days dní',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Okno stability';

  @override
  String get stabilityWindowSubtitle => 'Období, které skóre stability hodnotí';

  @override
  String get insightsTitle => 'Postřehy';

  @override
  String get insightsProName => 'Chytré postřehy';

  @override
  String get insightsIntro => 'Na co se podle posledních měření zaměřit.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count dalších',
      few: '+$count další',
      one: '+1 další',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param je pod cílovým rozsahem';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param je nízko a dál klesá';
  }

  @override
  String insightHigh(Object param) {
    return '$param je nad cílovým rozsahem';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param je vysoko a dál stoupá';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param je mimo cílový rozsah';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param klesá — může opustit rozsah za ~$days d';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param stoupá — může opustit rozsah za ~$days d';
  }

  @override
  String insightRecovering(Object param) {
    return '$param se vrací do rozsahu';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param se zlepšuje — zpět v rozsahu za ~$days d';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param: neměřeno $days d';
  }

  @override
  String get aiSummaryAction => 'Zeptejte se své AI';

  @override
  String get aiSummaryPrivacyNote =>
      'Toto je připravený prompt s daty vaší nádrže. Vložte ho do ChatGPT, Claude, Gemini nebo jiného AI nástroje — vše se připraví ve vašem zařízení, nic se nikam neodesílá.';

  @override
  String get aiSummaryPromptPreview => 'Náhled promptu';

  @override
  String get aiSummaryCopyPrompt => 'Kopírovat prompt';

  @override
  String aiSummaryWeeksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count týdnů',
      few: '$count týdny',
      one: '1 týden',
    );
    return '$_temp0';
  }

  @override
  String get aiSummaryCopied => 'Zkopírováno — vložte do chatu s vaší AI.';

  @override
  String get aiSummaryEmpty => 'Zatím žádná měření — není co shrnout.';

  @override
  String get aiSummaryInsightsFooter =>
      'Chcete hlubší rozbor? Zeptejte se své AI';

  @override
  String aiSummaryPreamble(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other:
          'Mám mořské útesové akvárium a sleduji ho v aplikaci. Níže jsou data mé nádrže za posledních $weeks týdnů. Prosím analyzuj je, upozorni na rizika či trendy, které je třeba řešit, a doporuč, co zkontrolovat nebo upravit.',
      few:
          'Mám mořské útesové akvárium a sleduji ho v aplikaci. Níže jsou data mé nádrže za poslední $weeks týdny. Prosím analyzuj je, upozorni na rizika či trendy, které je třeba řešit, a doporuč, co zkontrolovat nebo upravit.',
      one:
          'Mám mořské útesové akvárium a sleduji ho v aplikaci. Níže jsou data mé nádrže za poslední týden. Prosím analyzuj je, upozorni na rizika či trendy, které je třeba řešit, a doporuč, co zkontrolovat nebo upravit.',
    );
    return '$_temp0';
  }

  @override
  String aiSummaryDocTitle(Object tank) {
    return '$tank — shrnutí mořského akvária';
  }

  @override
  String aiSummaryRunningSince(Object date) {
    return 'v provozu od $date';
  }

  @override
  String aiSummaryExportedLine(Object date) {
    return 'Exportováno $date.';
  }

  @override
  String get aiSummaryStatusHeading => 'Stav';

  @override
  String aiSummaryHealthLine(int score, Object grade) {
    return 'Skóre zdraví: $score ze 100 ($grade)';
  }

  @override
  String aiSummaryStabilityLine(int score, Object grade, int days) {
    return 'Skóre stability: $score ze 100 ($grade) za posledních $days dní';
  }

  @override
  String get aiSummaryObservationsLead => 'Postřehy aplikace (podle pravidel):';

  @override
  String get aiSummaryParamsHeading => 'Parametry';

  @override
  String aiSummaryTestedOn(Object date) {
    return 'naposledy měřeno $date';
  }

  @override
  String aiSummaryTargetRange(Object range) {
    return 'Cíl $range';
  }

  @override
  String aiSummaryAcceptableRange(Object range) {
    return 'přijatelné $range';
  }

  @override
  String get aiSummaryColDate => 'Datum';

  @override
  String get aiSummaryColValue => 'Hodnota';

  @override
  String get aiSummaryColNote => 'Poznámka';

  @override
  String get aiSummaryColElement => 'Prvek';

  @override
  String get aiSummaryColStatus => 'Stav';

  @override
  String aiSummaryShowingTests(int shown, int total) {
    return 'Zobrazeno $shown nejnovějších z $total měření.';
  }

  @override
  String get aiSummaryDosingHeading => 'Dávkovací plán';

  @override
  String aiSummaryDailyEquivalent(Object amount) {
    return '≈$amount denně';
  }

  @override
  String aiSummarySinceDate(Object date) {
    return 'od $date';
  }

  @override
  String get aiSummaryOneOff => 'jednorázová dávka';

  @override
  String get aiSummaryActionsHeading => 'Údržba v tomto období';

  @override
  String get aiSummaryMicroHeading =>
      'Stopové prvky (poslední naměřené hodnoty)';

  @override
  String get dashboardSection => 'Přehled';

  @override
  String get dashboardLayoutTitle => 'Rozvržení přehledu';

  @override
  String get dashboardLayoutSubtitle => 'Jak karty uspořádat na kartě Měření';

  @override
  String get dashboardLayoutGrouped => 'Skupiny';

  @override
  String get dashboardLayoutClassic => 'Klasické';

  @override
  String get healthDisplayTitle => 'Zdraví nádrže';

  @override
  String get healthDisplaySubtitle => 'Kde zobrazit souhrn zdraví';

  @override
  String get healthDisplayBoth => 'Odznak a karta';

  @override
  String get healthDisplayBadge => 'Jen odznak';

  @override
  String get healthDisplayOff => 'Skryté';

  @override
  String get routeNotFoundTitle => 'Stránka nenalezena';

  @override
  String get routeNotFoundBody => 'Tento odkaz v aplikaci nikam nevede.';

  @override
  String get routeNotFoundGoHome => 'Přejít na hlavní obrazovku';

  @override
  String get notifChannelTesting => 'Připomínky měření';

  @override
  String get notifChannelDosing => 'Připomínky dávkování';

  @override
  String get notifChannelMaintenance => 'Připomínky údržby';

  @override
  String get notifTestingTitle => 'Čas na měření';

  @override
  String get notifDosingTitle => 'Čas na dávkování';

  @override
  String get notifMaintenanceTitle => 'Čas na údržbu';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Připomínky';

  @override
  String get remindersSubtitle => 'Oznámení pro měření, dávkování a údržbu';

  @override
  String get remindersTestingSubtitle => 'Když je čas na test parametru';

  @override
  String get remindersDosingSubtitle => 'V čase dávkování každého přípravku';

  @override
  String get remindersMaintenanceSubtitle => 'Když je na řadě plánovaná údržba';

  @override
  String get reminderTimeTitle => 'Čas připomínek';

  @override
  String get reminderTimeSubtitle => 'Kdy chodí připomínky měření a údržby';

  @override
  String get remindersPermissionDenied =>
      'Oznámení jsou v nastavení systému blokovaná, připomínky se nezobrazí.';

  @override
  String get remindToTest => 'Připomínat testování';

  @override
  String get cadenceOff => 'Vypnuto';

  @override
  String daysShortN(int count) {
    return '$count d';
  }

  @override
  String get cadenceCustom => 'Vlastní';

  @override
  String get customDaysLabel => 'Dny';

  @override
  String get remindMe => 'Připomínat';

  @override
  String get remindMeNeedsTime => 'Pro připomínky nastavte čas dávkování';

  @override
  String get maintenanceSchedule => 'Plán údržby';

  @override
  String get addMaintenanceTask => 'Přidat úkol';

  @override
  String get editMaintenanceTask => 'Upravit úkol';

  @override
  String get taskTypeLabel => 'Typ';

  @override
  String get customTask => 'Vlastní úkol';

  @override
  String get taskTitleLabel => 'Název';

  @override
  String get taskTitleRequired => 'Zadejte název';

  @override
  String get repeatLabel => 'Opakování';

  @override
  String get oneOff => 'Jednorázově';

  @override
  String get dueDateLabel => 'Termín';

  @override
  String get dueDateRequired => 'Vyberte termín';

  @override
  String get dueToday => 'Dnes';

  @override
  String dueInDaysN(int count) {
    return 'Za $count d';
  }

  @override
  String overdueDaysN(int count) {
    return '$count d po termínu';
  }

  @override
  String get markDone => 'Hotovo';

  @override
  String get taskMarkedDone => 'Označeno jako hotové';

  @override
  String get taskDeleted => 'Úkol smazán';

  @override
  String get scheduleEmptyBody =>
      'Zatím žádné úkoly údržby. Naplánujte výměny vody nebo vlastní úkoly a získáte štítky termínů a připomínky.';

  @override
  String get repeatModeLabel => 'Opakování';

  @override
  String get repeatEveryDays => 'Každých X dní';

  @override
  String get repeatEveryWeeks => 'Každých X týdnů';

  @override
  String get repeatEveryMonths => 'Každých X měsíců';

  @override
  String get repeatOnWeekdays => 'Dny v týdnu';

  @override
  String get repeatOnMonthDay => 'Den v měsíci';

  @override
  String get weeksLabel => 'Týdny';

  @override
  String get monthsLabel => 'Měsíce';

  @override
  String get monthDayLabel => 'Den v měsíci (1–31)';

  @override
  String get invalidInterval => 'Zadejte celé číslo (1 nebo více).';

  @override
  String get invalidMonthDay => 'Zadejte den mezi 1 a 31.';

  @override
  String get weekdaysRequired => 'Vyberte alespoň jeden den.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Každých $n týdnů',
      few: 'Každé $n týdny',
      one: 'Každý týden',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Každých $n měsíců',
      few: 'Každé $n měsíce',
      one: 'Každý měsíc',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'Vždy v $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Každý měsíc $n. den';
  }

  @override
  String get roUnitTitle => 'Reverzní osmóza';

  @override
  String get roStageSediment => 'Sedimentový filtr';

  @override
  String get roStageCarbonBlock => 'Uhlíkový blok';

  @override
  String get roStageMembrane => 'Membrána RO';

  @override
  String get roStageDiResin => 'DI pryskyřice';

  @override
  String get roCustomStage => 'Vlastní díl';

  @override
  String get roAddStage => 'Přidat díl';

  @override
  String get roEditStage => 'Upravit díl';

  @override
  String get roLifespanLabel => 'Vyměnit každých';

  @override
  String get roUnitDays => 'dní';

  @override
  String get roUnitWeeks => 'týdnů';

  @override
  String get roUnitMonths => 'měsíců';

  @override
  String get roPartOfUnit => 'Součást mé jednotky';

  @override
  String get roPartOfUnitHint =>
      'Vypněte, pokud vaše jednotka tento stupeň nemá';

  @override
  String get roHiddenStages => 'Není na mé jednotce';

  @override
  String get roMarkReplaced => 'Vyměněno';

  @override
  String get roReplacedRecorded => 'Výměna zaznamenána';

  @override
  String roLastReplaced(String date) {
    return 'Vyměněno $date';
  }

  @override
  String get roNoReplacementYet => 'Zatím žádná zaznamenaná výměna';

  @override
  String get roDeleteStageTitle => 'Smazat díl?';

  @override
  String get roDeleteStageBody =>
      'Odstraní díl i historii jeho výměn. Nelze vzít zpět.';

  @override
  String get roEmptyBody =>
      'Žádné díly. Přidejte filtry své RO jednotky tlačítkem +.';

  @override
  String get roSetupPrompt => 'Sledujte výměny filtrů a membrány';

  @override
  String get roUnitToggleSubtitle =>
      'Zobrazit na kartě Úkony, s připomínkami výměn filtrů';

  @override
  String get roAllOk => 'Všechny díly v pořádku';

  @override
  String get notifRoTitle => 'Vyměňte filtry reverzní osmózy';
}
