// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Pomiary';

  @override
  String get settings => 'Ustawienia';

  @override
  String get manageParameters => 'Zarządzaj parametrami';

  @override
  String get moreOptions => 'Więcej opcji';

  @override
  String get tourTankTitle => 'Twoje akwaria';

  @override
  String get tourTankDesc =>
      'Dotknij tutaj, aby przełączać akwaria lub dodać nowe.';

  @override
  String get tourCompareTitle => 'Porównanie';

  @override
  String get tourCompareDesc =>
      'Przełączaj między kartami parametrów a zbiorczymi wykresami.';

  @override
  String get tourParamsTitle => 'Zarządzanie parametrami';

  @override
  String get tourParamsDesc =>
      'Wybierz, które parametry wody śledzić, i ustaw ich docelowe zakresy.';

  @override
  String get tourDosingHistoryTitle => 'Historia dozowania';

  @override
  String get tourDosingHistoryDesc =>
      'Przejrzyj wszystkie dawne i bieżące okresy dozowania oraz usuń wpis dodany przez pomyłkę.';

  @override
  String get tourDoseCalcTitle => 'Kalkulator dawkowania';

  @override
  String get tourDoseCalcDesc =>
      'Na karcie Dozowanie otwórz kalkulator, aby oszacować dzienną dawkę utrzymującą stabilny poziom pierwiastka.';

  @override
  String get tourNext => 'Dalej';

  @override
  String get tourDone => 'Rozumiem';

  @override
  String get tourSkip => 'Pomiń';

  @override
  String get replayTour => 'Powtórz przewodnik';

  @override
  String get replayTourSubtitle =>
      'Pokaż ponownie wskazówki dotyczące górnego paska';

  @override
  String get compareView => 'Porównaj wykresy';

  @override
  String get gridView => 'Widok siatki';

  @override
  String get addReading => 'Dodaj pomiar';

  @override
  String get addAquarium => 'Dodaj akwarium';

  @override
  String get manageTanks => 'Zarządzaj akwariami';

  @override
  String get chooseParameters => 'Wybierz parametry';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get delete => 'Usuń';

  @override
  String get stop => 'Zatrzymaj';

  @override
  String get apply => 'Zastosuj';

  @override
  String get change => 'Zmień';

  @override
  String get undo => 'Cofnij';

  @override
  String get itemDeleted => 'Usunięto';

  @override
  String get reorder => 'Zmień kolejność';

  @override
  String errorWith(Object message) {
    return 'Błąd: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Nie udało się zapisać: $error';
  }

  @override
  String get welcomeTitle => 'Witamy w ReefTracker';

  @override
  String get welcomeBody =>
      'Utwórz swoje pierwsze akwarium, aby rozpocząć śledzenie parametrów wody.';

  @override
  String get noParamsTracked =>
      'Dla tego akwarium nie są śledzone żadne parametry.';

  @override
  String get noReadings => 'Brak pomiarów';

  @override
  String get timeJustNow => 'przed chwilą';

  @override
  String timeMinAgo(int count) {
    return '$count min temu';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count godz. temu';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count dni temu';
  }

  @override
  String get aquariums => 'Akwaria';

  @override
  String get noAquariumsYet => 'Brak akwariów.';

  @override
  String get makeActive => 'Ustaw jako aktywne';

  @override
  String get active => 'Aktywne';

  @override
  String get edit => 'Edytuj';

  @override
  String deleteTankTitle(Object name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get deleteTankBody =>
      'Spowoduje to trwałe usunięcie akwarium i wszystkich jego pomiarów.';

  @override
  String tankDeleted(Object name) {
    return 'Usunięto akwarium „$name”';
  }

  @override
  String get newAquarium => 'Nowe akwarium';

  @override
  String get editAquarium => 'Edytuj akwarium';

  @override
  String get name => 'Nazwa';

  @override
  String get nameHint => 'np. Rafa w salonie';

  @override
  String get enterAName => 'Wpisz nazwę';

  @override
  String get setupType => 'Typ zbiornika';

  @override
  String get presetSeedNote =>
      'Dla tego typu zbiornika zostaną ustawione domyślne parametry i granice stref. Możesz je dostroić w dowolnym momencie.';

  @override
  String get volumeOptional => 'Objętość (opcjonalnie)';

  @override
  String get vendorOptional => 'Producent (opcjonalnie)';

  @override
  String get modelOptional => 'Model (opcjonalnie)';

  @override
  String get notesOptional => 'Notatki (opcjonalnie)';

  @override
  String get createAquarium => 'Utwórz akwarium';

  @override
  String litersSuffix(Object value) {
    return '$value l';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Data uruchomienia';

  @override
  String get notSet => 'Nie ustawiono';

  @override
  String get setDate => 'Ustaw';

  @override
  String get clear => 'Wyczyść';

  @override
  String sinceDate(Object date) {
    return 'od $date';
  }

  @override
  String get parameters => 'Parametry';

  @override
  String get noActiveAquarium => 'Brak aktywnego akwarium.';

  @override
  String reapplyPreset(Object type) {
    return 'Zastosuj ponownie preset $type';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Zastosować ponownie preset $type?';
  }

  @override
  String get reapplyPresetBody =>
      'Spowoduje to nadpisanie granic zielona/pomarańczowa/czerwona wszystkich śledzonych parametrów wartościami domyślnymi: parametry pulpitu według presetu typu akwarium, mikroelementy według wbudowanych wartości domyślnych. Twoje pomiary zostaną zachowane.';

  @override
  String get presetApplied => 'Preset zastosowany.';

  @override
  String get noBoundariesSet => 'Nie ustawiono granic';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  czerwona <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Edytuj strefy';

  @override
  String get addParameter => 'Dodaj parametr';

  @override
  String get allParametersAdded => 'Wszystkie parametry są już dodane.';

  @override
  String unitWithValue(Object unit) {
    return 'Jednostka: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Ustawiane w Ustawieniach. Poniższe granice używają tej jednostki.';

  @override
  String get unit => 'Jednostka';

  @override
  String get boundAmberLow => 'Czerwona poniżej (pomarańczowa dolna)';

  @override
  String get boundGreenLow => 'Zielona od (OK dolna)';

  @override
  String get boundGreenHigh => 'Zielona do (OK górna)';

  @override
  String get boundAmberHigh => 'Czerwona powyżej (pomarańczowa górna)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Wartości w $unit. Puste pole oznacza „brak limitu po tej stronie”.';
  }

  @override
  String get enterANumber => 'Wpisz liczbę';

  @override
  String get boundsOrderError =>
      'Granice muszą rosnąć: pomarańczowa dolna ≤ zielona dolna ≤ zielona górna ≤ pomarańczowa górna.';

  @override
  String get boundsPairError =>
      'Każda pomarańczowa granica wymaga odpowiadającej zielonej granicy po tej samej stronie.';

  @override
  String get noteOptional => 'Notatka (opcjonalnie)';

  @override
  String get saveReadings => 'Zapisz pomiary';

  @override
  String invalidNumberFor(Object name) {
    return 'Nieprawidłowa liczba dla $name';
  }

  @override
  String get invalidVolume => 'Wprowadź prawidłową dodatnią objętość.';

  @override
  String get invalidPositiveNumber => 'Wpisz liczbę dodatnią.';

  @override
  String get invalidIntervalDays =>
      'Wpisz całkowitą liczbę dni (co najmniej 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: ta wartość jest fizycznie niemożliwa.';
  }

  @override
  String get impossibleValue => 'Ta wartość jest fizycznie niemożliwa.';

  @override
  String get implausibleTitle => 'Nietypowe wartości';

  @override
  String get implausibleIntro =>
      'Poniższa wartość wykracza poza typowy zakres. Sprawdź, czy nie ma literówki, zanim zapiszesz.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (typowo $min–$max)';
  }

  @override
  String get saveAnyway => 'Zapisz mimo to';

  @override
  String get enterAtLeastOneValue => 'Wpisz co najmniej jedną wartość.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zapisano $count pomiaru.',
      many: 'Zapisano $count pomiarów.',
      few: 'Zapisano $count pomiary.',
      one: 'Zapisano 1 pomiar.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Brak śledzonych parametrów do zapisania.';

  @override
  String get testSetAll => 'Wszystkie';

  @override
  String get newTestSet => 'Nowy zestaw testów';

  @override
  String get editTestSet => 'Edytuj zestaw testów';

  @override
  String get manageTestSets => 'Zarządzaj zestawami testów';

  @override
  String get testSetNameHint => 'np. Duży cotygodniowy test';

  @override
  String get testSetNeedParam => 'Wybierz co najmniej jeden parametr.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get deleteTestSetBody =>
      'Zestaw testów zostanie usunięty. Twoje pomiary pozostaną.';

  @override
  String get testSetEmptyHint =>
      'Ten zestaw nie zawiera żadnych aktywnych parametrów. Edytuj go lub przełącz na Wszystkie.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parametru',
      many: '$count parametrów',
      few: '$count parametry',
      one: '1 parametr',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Brak zestawów testów. Zestaw pozwala zapisywać tylko te parametry, które testujesz razem.';

  @override
  String get rangeWeek => '7 dni';

  @override
  String get rangeMonth => '30 dni';

  @override
  String get rangeQuarter => '90 dni';

  @override
  String get rangeAll => 'Wszystko';

  @override
  String get noReadingsInRange => 'Brak pomiarów w tym zakresie.';

  @override
  String get editMeasurement => 'Edytuj pomiar';

  @override
  String get deleteTogetherTitle => 'Usuń pomiar';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ta wartość została wprowadzona razem z $count innymi pomiarami. Usunąć tylko tę wartość, czy wszystkie wprowadzone razem?',
      one:
          'Ta wartość została wprowadzona razem z 1 innym pomiarem. Usunąć tylko tę wartość, czy wszystkie wprowadzone razem?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Tylko tę wartość';

  @override
  String get deleteAllTogether => 'Wszystkie razem';

  @override
  String get editTogetherTitle => 'Zmień czas pomiaru';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ta wartość została wprowadzona razem z $count innymi pomiarami. Zmienić czas tylko dla tej wartości, czy dla wszystkich wprowadzonych razem?',
      one:
          'Ta wartość została wprowadzona razem z 1 innym pomiarem. Zmienić czas tylko dla tej wartości, czy dla wszystkich wprowadzonych razem?',
    );
    return '$_temp0';
  }

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Stosunek PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Stosunek Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : Alk';

  @override
  String get ratioCaAlkTitle => 'Stosunek Ca : Alk';

  @override
  String get ratioMgAlkLabel => 'Mg : Alk';

  @override
  String get ratioMgAlkTitle => 'Stosunek Mg : Alk';

  @override
  String get ratioNoData => 'Zapisz oba parametry, aby zobaczyć ich stosunek.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Granice stref używają $metric, wartości pokazanej na karcie.';
  }

  @override
  String get waterChanges => 'Podmiany wody';

  @override
  String get recordWaterChange => 'Zapisz podmianę wody';

  @override
  String get amountLitersOptional => 'Ilość (opcjonalnie)';

  @override
  String get noWaterChanges => 'Brak podmian wody.';

  @override
  String get amountNotRecorded => 'Ilość nie zapisana';

  @override
  String get actions => 'Czynności';

  @override
  String get noActions => 'Brak czynności.';

  @override
  String get addAction => 'Dodaj czynność';

  @override
  String get waterChange => 'Podmiana wody';

  @override
  String get carbonChange => 'Wymiana węgla';

  @override
  String get recordCarbonChange => 'Zapisz wymianę węgla';

  @override
  String get weightOptional => 'Waga (opcjonalnie)';

  @override
  String get weightNotRecorded => 'Waga nie zapisana';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Czyszczenie sprzętu';

  @override
  String get recordEquipmentCleaning => 'Zapisz czyszczenie sprzętu';

  @override
  String get dosing => 'Dozowanie';

  @override
  String get addSupplement => 'Dodaj preparat';

  @override
  String get noDosing => 'Brak preparatów.';

  @override
  String get noDosingHint =>
      'Dodaj preparaty dozowane do tego zbiornika — producenta, produkt oraz opcjonalnie dawkę i harmonogram.';

  @override
  String get dosingNoDosage => 'Brak dawki';

  @override
  String get supplementStopped => 'Preparat zatrzymany';

  @override
  String get dosingHistoryTitle => 'Historia dozowania';

  @override
  String get dosingHistoryEmpty => 'Brak historii dozowania.';

  @override
  String get dosingHistoryCurrent => 'Bieżąca';

  @override
  String dosingHistorySince(Object date) {
    return 'Od $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Usunąć ten wpis?';

  @override
  String get deleteDosingRecordBody =>
      'Trwale usunie to ten wpis dozowania z historii i z obliczeń dawki. Nie można tego cofnąć.';

  @override
  String get deleteDosingRecordNotLatest =>
      'To nie jest najnowszy wpis dla tego pierwiastka; jego usunięcie nie zmieni późniejszych wpisów.';

  @override
  String get dosingHistoryManual => 'Ręczna';

  @override
  String get manualDoseNew => 'Zapisz dawkę ręczną';

  @override
  String get manualDoseEdit => 'Edytuj dawkę ręczną';

  @override
  String get deleteManualDoseTitle => 'Usunąć dawkę ręczną?';

  @override
  String get deleteManualDoseBody =>
      'Ta zapisana dawka zostanie trwale usunięta z historii i z obliczeń dawkowania. Nie można tego cofnąć.';

  @override
  String get dosingNew => 'Dodaj preparat';

  @override
  String get dosingEdit => 'Edytuj preparat';

  @override
  String get dosingVendor => 'Producent';

  @override
  String get dosingVendorName => 'Nazwa producenta';

  @override
  String get dosingProduct => 'Produkt';

  @override
  String get dosingProductName => 'Nazwa produktu';

  @override
  String get dosingElement => 'Pierwiastek';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Inne…';

  @override
  String get dosingDosageOptional => 'Dawkowanie (opcjonalnie)';

  @override
  String get dosingAmount => 'Ilość';

  @override
  String get dosingUnit => 'Jednostka';

  @override
  String get dosingBasis => 'Podstawa';

  @override
  String get dosingPerDay => 'dziennie';

  @override
  String get dosingPerDose => 'na dawkę';

  @override
  String get dosingSchedule => 'Harmonogram';

  @override
  String get dosingFrequency => 'Częstotliwość';

  @override
  String get dosingFreqNone => 'Brak';

  @override
  String get dosingFreqDaily => 'Codziennie';

  @override
  String get dosingFreqEveryNDays => 'Co N dni';

  @override
  String get dosingFreqWeekly => 'Co tydzień';

  @override
  String get dosingIntervalDays => 'Odstęp (dni)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Co $n dnia',
      many: 'Co $n dni',
      few: 'Co $n dni',
      one: 'Co dzień',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Godzina (opcjonalnie)';

  @override
  String get unitsSection => 'Jednostki';

  @override
  String get toolsSection => 'Narzędzia';

  @override
  String get aboutSection => 'O aplikacji';

  @override
  String get languageSection => 'Język';

  @override
  String get temperature => 'Temperatura';

  @override
  String get salinity => 'Zasolenie';

  @override
  String get volume => 'Objętość';

  @override
  String get unitUsedAcrossApp => 'Jednostka używana w całej aplikacji';

  @override
  String get salinityCalculator => 'Kalkulator zasolenia';

  @override
  String get salinityCalculatorSubtitle =>
      'Przelicz ppt ↔ gęstość względna (SG)';

  @override
  String get backupSection => 'Kopia zapasowa';

  @override
  String get backupNow => 'Utwórz kopię teraz';

  @override
  String backupLastRun(String when) {
    return 'Ostatnia kopia: $when';
  }

  @override
  String get backupNeverRun => 'Brak kopii zapasowej';

  @override
  String backupLastFailed(String when) {
    return 'Ostatnia kopia nie powiodła się $when';
  }

  @override
  String get backupDone => 'Kopia zapisana';

  @override
  String get backupExport => 'Eksportuj kopię';

  @override
  String get backupExportSubtitle =>
      'Zapisz wszystkie akwaria i pomiary do pliku';

  @override
  String get csvExportTitle => 'Eksport pomiarów (CSV)';

  @override
  String get csvExportSubtitle =>
      'Udostępnij pomiary aktywnego akwarium jako plik arkusza kalkulacyjnego';

  @override
  String get csvExportNoData => 'Brak pomiarów do wyeksportowania';

  @override
  String get csvExportFailed => 'Nie udało się wyeksportować pomiarów';

  @override
  String get backupImport => 'Przywróć z kopii';

  @override
  String get backupImportSubtitle =>
      'Zastąp wszystkie dane plikiem kopii zapasowej';

  @override
  String get backupRestoreConfirmTitle => 'Przywrócić kopię zapasową?';

  @override
  String get backupRestoreConfirmBody =>
      'Spowoduje to zastąpienie WSZYSTKICH danych akwariów — wszystkich akwariów, parametrów i pomiarów — zawartością pliku kopii zapasowej. Ustawienia na tym urządzeniu (język, jednostki i preferencje) zostaną zachowane. Tej operacji nie można cofnąć.';

  @override
  String get restore => 'Przywróć';

  @override
  String get backupRestored => 'Kopia zapasowa przywrócona';

  @override
  String get backupNowFailed => 'Nie udało się zapisać kopii zapasowej';

  @override
  String get backupShareFailed => 'Nie udało się udostępnić kopii zapasowej';

  @override
  String get backupExportFailed => 'Nie udało się wyeksportować kopii';

  @override
  String get backupImportFailed => 'Nie udało się przywrócić kopii';

  @override
  String get backupInvalidFile =>
      'Ten plik nie jest prawidłową kopią zapasową ReefTracker';

  @override
  String get backupTooNew =>
      'Ta kopia zapasowa została utworzona przez nowszą wersję aplikacji i nie można jej tu przywrócić';

  @override
  String get backupCorrupted =>
      'Plik kopii zapasowej jest uszkodzony lub niekompletny';

  @override
  String get backupInconsistent =>
      'Kopia zapasowa jest niespójna i nie można jej przywrócić';

  @override
  String get dataLoadFailed =>
      'Nie udało się wczytać części danych. Jeśli problem się powtarza, uruchom aplikację ponownie lub przywróć kopię zapasową.';

  @override
  String get autoBackupTitle => 'Automatyczna kopia zapasowa';

  @override
  String get autoBackupSubtitle =>
      'Przechowuj najnowsze kopie danych na tym urządzeniu';

  @override
  String get autoBackupFrequency => 'Częstotliwość';

  @override
  String get autoBackupDaily => 'Codziennie';

  @override
  String get autoBackupWeekly => 'Co tydzień';

  @override
  String get manageBackups => 'Zarządzaj kopiami';

  @override
  String get manageBackupsSubtitle =>
      'Wyświetl, przywróć lub udostępnij automatyczne kopie';

  @override
  String get backupsScreenTitle => 'Kopie automatyczne';

  @override
  String get noAutoBackups => 'Brak automatycznych kopii zapasowych';

  @override
  String get noAutoBackupsHint =>
      'Kopia zapasowa jest zapisywana automatycznie podczas korzystania z aplikacji.';

  @override
  String get share => 'Udostępnij';

  @override
  String get backupDeleteConfirmTitle => 'Usunąć kopię zapasową?';

  @override
  String get backupDeleteConfirmBody =>
      'Spowoduje to trwałe usunięcie tego pliku kopii zapasowej z urządzenia.';

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
  String get cloudSyncTitle => 'Synchronizacja z folderem w chmurze';

  @override
  String get cloudSyncSubtitle =>
      'Kopiuje każdą kopię zapasową do wybranego folderu (np. Google Drive), aby inne urządzenia mogły ją przywrócić';

  @override
  String get cloudSyncFolder => 'Synchronizowany folder';

  @override
  String get cloudSyncNoFolder => 'Nie wybrano folderu';

  @override
  String cloudSyncLastSynced(Object when) {
    return 'Ostatnia synchronizacja: $when';
  }

  @override
  String get cloudSyncNeverSynced => 'Jeszcze nie synchronizowano';

  @override
  String cloudSyncLastFailed(Object when) {
    return 'Synchronizacja nie powiodła się: $when';
  }

  @override
  String get cloudSyncRestoreTitle => 'Przywróć z synchronizowanego folderu';

  @override
  String get cloudSyncRestoreSubtitle =>
      'Zastępuje wszystkie dane kopią zapasową z synchronizowanego folderu';

  @override
  String get cloudSyncChooseBackup => 'Wybierz kopię zapasową do przywrócenia';

  @override
  String get cloudSyncNoBackups =>
      'W synchronizowanym folderze nie ma jeszcze kopii zapasowych';

  @override
  String get cloudSyncListFailed =>
      'Nie udało się odczytać synchronizowanego folderu';

  @override
  String get cloudSyncPickFailed => 'Nie udało się wybrać folderu';

  @override
  String get aboutAppName => 'O aplikacji ReefTracker';

  @override
  String get aboutDescription =>
      'Offline\'owy tracker parametrów akwarium morskiego z historią, wykresami czasowymi i strefami zdrowia zielona/pomarańczowa/czerwona.';

  @override
  String get language => 'Język';

  @override
  String get languageSystem => 'Domyślny systemu';

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
      'Przelicz między praktycznym zasoleniem (ppt) a gęstością względną (SG). Wpisuj w dowolne pole.';

  @override
  String get specificGravity => 'Gęstość względna';

  @override
  String get referencePoints => 'Punkty odniesienia';

  @override
  String get refSeawater => '• Naturalna woda morska ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget => '• Typowy cel dla rafy ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG odniesione do 25 °C. Przeliczenie to przybliżenie liniowe: SG = 1 + ppt × 0,0264/35.';

  @override
  String get doseCalcTitle => 'Kalkulator dawkowania';

  @override
  String get doseCalcIntro =>
      'Szacuje, jak szybko zbiornik zużywa pierwiastek, oraz dawkę dzienną, która utrzyma go na stałym poziomie. Podmiany wody nie są uwzględniane.';

  @override
  String get doseCalcElement => 'Pierwiastek';

  @override
  String get doseCalcWindow => 'Okres pomiarów';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pomiaru w okresie',
      many: '$count pomiarów w okresie',
      few: '$count pomiary w okresie',
      one: '1 pomiar w okresie',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dawka zmieniona $date; pomiary sprzed tej daty odzwierciedlają inną dawkę.';
  }

  @override
  String get doseCalcVolume => 'Objętość zbiornika';

  @override
  String get doseCalcCurrentDose => 'Obecna dawka dzienna';

  @override
  String get doseCalcManualDose => 'Dawka ręczna w oknie';

  @override
  String get doseCalcManualDoseHelp =>
      'Opcjonalnie: suma jednorazowych lub dodatkowych dawek podanych w oknie pomiarowym. Gdy pole jest puste, używane są zapisane dawki ręczne.';

  @override
  String get doseCalcManualInput => 'Dawki ręczne dodają';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zapisanej dawki w oknie: $total',
      many: '$count zapisanych dawek w oknie: $total',
      few: '$count zapisane dawki w oknie: $total',
      one: '1 zapisana dawka w oknie: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count zapisanej dawki używa innej jednostki i nie jest uwzględnione.',
      many:
          '$count zapisanych dawek używa innej jednostki i nie jest uwzględnionych.',
      few:
          '$count zapisane dawki używają innej jednostki i nie są uwzględnione.',
      one: '1 zapisana dawka używa innej jednostki i nie jest uwzględniona.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Niektóre zapisane dawki to inny preparat — ich siła może różnić się od podanej powyżej.';

  @override
  String get doseCalcPerDay => 'dzień';

  @override
  String get doseCalcPotencyTitle => 'Moc preparatu';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Używana jest moc tego produktu z katalogu.';

  @override
  String get doseCalcEnterManually => 'Wpisz ręcznie';

  @override
  String get doseCalcUseCatalog => 'Użyj wartości z katalogu';

  @override
  String get doseCalcRefAmount => 'Dawka';

  @override
  String get doseCalcRefVolume => 'Na objętość';

  @override
  String get doseCalcRise => 'Podnosi o';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Wynik';

  @override
  String get doseCalcObservedChange => 'Zmierzona zmiana';

  @override
  String get doseCalcConsumption => 'Zużycie';

  @override
  String get doseCalcCurrentInput => 'Obecne dawkowanie dodaje';

  @override
  String get doseCalcSuggestedDose => 'Sugerowana dawka dzienna';

  @override
  String get doseCalcAdjustment => 'Korekta';

  @override
  String get doseCalcStable =>
      'Twoja dawka utrzymuje ten pierwiastek na stałym poziomie — zostaw ją.';

  @override
  String get doseCalcIncrease =>
      'Zwiększ dawkę, aby utrzymać ten pierwiastek na stałym poziomie.';

  @override
  String get doseCalcDecrease =>
      'Możesz zmniejszyć dawkę i nadal utrzymać ten pierwiastek na stałym poziomie.';

  @override
  String get doseCalcOverdosing =>
      'Ten pierwiastek rośnie — zmniejsz lub wstrzymaj dawkowanie.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Nic nie jest dozowane, a ten pierwiastek nie spada — dawkowanie nie jest potrzebne.';

  @override
  String get doseCalcNeedsPotency =>
      'Podaj moc preparatu, aby otrzymać zalecenie dawki.';

  @override
  String get doseCalcInsufficient =>
      'Aby obliczyć, dodaj co najmniej dwa pomiary z różnych dni i objętość zbiornika.';

  @override
  String get trendSection => 'Trendy';

  @override
  String get trendShowTitle => 'Pokazuj trendy';

  @override
  String get trendShowSubtitle =>
      'Przewiduje, dokąd zmierza każdy parametr i kiedy opuści swój zakres';

  @override
  String get trendWindow => 'Użyte pomiary';

  @override
  String trendWindowSubtitle(int days) {
    return 'Ile ostatnich pomiarów wyznacza trend; przy częstszych pomiarach okno obejmuje co najmniej $days dni';
  }

  @override
  String get trendTitle => 'Bieżący trend';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/dzień';
  }

  @override
  String get trendFlat => 'Utrzymuje się stabilnie';

  @override
  String get trendWithinRange => 'Przy tym tempie pozostaje w zakresie';

  @override
  String trendAmberInDays(int days) {
    return 'Osiągnie strefę uwagi za ~$days dni';
  }

  @override
  String trendRedInDays(int days) {
    return 'Osiągnie strefę krytyczną za ~$days dni';
  }

  @override
  String trendChipAmber(int days) {
    return 'Uwaga ~$days dni';
  }

  @override
  String trendChipRed(int days) {
    return 'Działaj ~$days dni';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Poprawia się — wróci do zakresu za ~$days dni';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Poprawia się ~$days dni';
  }

  @override
  String get trendHorizon => 'Horyzont alertu';

  @override
  String get trendHorizonSubtitle =>
      'Oznaczaj parametr tylko, gdy opuści swój zakres w tym czasie';

  @override
  String trendHorizonDays(int days) {
    return '$days dni';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Uwaga';

  @override
  String get zoneActNow => 'Działaj teraz';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Tylko ryby / FOWLR';

  @override
  String get setupSoft => 'Koralowce miękkie';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Rafa mieszana';

  @override
  String get paramTemperature => 'Temperatura';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Zasolenie';

  @override
  String get paramAlkalinity => 'Zasadowość (KH)';

  @override
  String get paramCalcium => 'Wapń (Ca)';

  @override
  String get paramMagnesium => 'Magnez (Mg)';

  @override
  String get paramNitrate => 'Azotan (NO₃)';

  @override
  String get paramPhosphate => 'Fosforan (PO₄)';

  @override
  String get paramAmmonia => 'Amoniak (NH₃/₄)';

  @override
  String get paramNitrite => 'Azotyn (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Potas (K)';

  @override
  String get paramStrontium => 'Stront (Sr)';

  @override
  String get paramIodine => 'Jod (I)';

  @override
  String get paramIron => 'Żelazo (Fe)';

  @override
  String get paramSodium => 'Sód (Na)';

  @override
  String get paramSulfur => 'Siarka (S)';

  @override
  String get paramBoron => 'Bor (B)';

  @override
  String get paramBromine => 'Brom (Br)';

  @override
  String get paramSilicon => 'Krzem (Si)';

  @override
  String get paramZinc => 'Cynk (Zn)';

  @override
  String get paramVanadium => 'Wanad (V)';

  @override
  String get paramCopper => 'Miedź (Cu)';

  @override
  String get paramNickel => 'Nikiel (Ni)';

  @override
  String get paramManganese => 'Mangan (Mn)';

  @override
  String get paramMolybdenum => 'Molibden (Mo)';

  @override
  String get paramChromium => 'Chrom (Cr)';

  @override
  String get paramCobalt => 'Kobalt (Co)';

  @override
  String get paramLithium => 'Lit (Li)';

  @override
  String get paramBarium => 'Bar (Ba)';

  @override
  String get paramSelenium => 'Selen (Se)';

  @override
  String get paramAluminium => 'Glin (Al)';

  @override
  String get paramAntimony => 'Antymon (Sb)';

  @override
  String get paramTin => 'Cyna (Sn)';

  @override
  String get paramBeryllium => 'Beryl (Be)';

  @override
  String get paramSilver => 'Srebro (Ag)';

  @override
  String get paramTungsten => 'Wolfram (W)';

  @override
  String get paramLanthanum => 'Lantan (La)';

  @override
  String get paramTitanium => 'Tytan (Ti)';

  @override
  String get paramZirconium => 'Cyrkon (Zr)';

  @override
  String get paramArsenic => 'Arsen (As)';

  @override
  String get paramCadmium => 'Kadm (Cd)';

  @override
  String get paramMercury => 'Rtęć (Hg)';

  @override
  String get paramLead => 'Ołów (Pb)';

  @override
  String get microTitle => 'Mikroelementy';

  @override
  String get microSectionMajor => 'Pierwiastki główne';

  @override
  String get microSectionTrace => 'Pierwiastki śladowe';

  @override
  String get microSectionContaminants => 'Zanieczyszczenia';

  @override
  String get microNotMeasured => 'Nie zmierzono';

  @override
  String get microEmptyHint =>
      'Śledź pierwiastki śladowe z testów domowych lub raportów ICP.';

  @override
  String get microAllOk => 'Wszystko w zakresie';

  @override
  String microOutOfRangeN(int count) {
    return '$count poza zakresem';
  }

  @override
  String microLastMeasured(String date) {
    return 'Ostatni pomiar $date';
  }

  @override
  String get microAddMeasurements => 'Dodaj pomiary';

  @override
  String get microAddTitle => 'Pomiary mikroelementów';

  @override
  String get microChipHobby => 'Testy domowe';

  @override
  String get microChipFullIcp => 'Pełne ICP';

  @override
  String get microReminderTooltip => 'Przypomnienie o teście';

  @override
  String get microReminderTitle => 'Przypomnienie o teście mikroelementów';

  @override
  String get microReminderHint =>
      'Dodaje do harmonogramu konserwacji zadanie przypominające o regularnym testowaniu mikroelementów.';

  @override
  String get microReminderCreated =>
      'Przypomnienie dodano do harmonogramu konserwacji';

  @override
  String get microIcpTaskTitle => 'Test mikroelementów (ICP)';

  @override
  String get microToggleSubtitle =>
      'Pokazuj na karcie Pomiary, z przypomnieniami o testach. Ukrycie nie usuwa pomiarów.';

  @override
  String get microViewFull => 'Pełna lista';

  @override
  String get microViewNew => 'Nowy widok';

  @override
  String get microViewEdit => 'Edytuj widok';

  @override
  String get microViewManage => 'Zarządzaj widokami';

  @override
  String get microConfigureTitle => 'Ustawienia pierwiastków';

  @override
  String get microViewNone =>
      'Brak własnych widoków. Widok pokazuje tylko pierwiastki raportowane przez Twoje laboratorium.';

  @override
  String get microViewNameHint => 'np. Panel mojego laboratorium';

  @override
  String get microViewNeedElement => 'Wybierz co najmniej jeden pierwiastek.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pierwiastka',
      many: '$count pierwiastków',
      few: '$count pierwiastki',
      one: '1 pierwiastek',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get microViewDeleteBody =>
      'Usuwa tylko widok. Pomiary zostaną zachowane.';

  @override
  String get microHideUndetectable => 'Ukryj niewykrywalne (zero)';

  @override
  String get microAttentionOnly => 'Tylko pierwiastki wymagające uwagi';

  @override
  String get microFilterAllHidden =>
      'Żadne pierwiastki nie pasują do bieżących filtrów.';

  @override
  String get icpImportTitle => 'Import raportu ICP';

  @override
  String get icpImportFormatHint => 'Wybierz format wyeksportowanego pliku.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'Eksport CSV z portalu laboratorium Fauna Marin';

  @override
  String get icpImportFormatZimsHint =>
      'Uniwersalny CSV z pomiarami (data, pomiar, wartość, jednostka)';

  @override
  String get icpImportUnreadable => 'Nie udało się odczytać pliku.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Ten plik nie wygląda na eksport $format.';
  }

  @override
  String get icpImportNoValues =>
      'Nie znaleziono w pliku wartości do zaimportowania.';

  @override
  String get icpImportSampleDateHint =>
      'Wstępnie wypełniono datą analizy z raportu. Zmień ją na dzień pobrania próbki wody.';

  @override
  String get icpImportSectionCore => 'Parametry podstawowe';

  @override
  String icpImportSkipped(String list) {
    return 'Nie zaimportowano (brak pasującego parametru): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importuj $count wartości',
      many: 'Importuj $count wartości',
      few: 'Importuj $count wartości',
      one: 'Importuj 1 wartość',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Próbka już zaimportowana?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Istniejące pomiary już wspominają próbkę $id. Mimo to zaimportować ponownie?';
  }

  @override
  String get icpImportAnyway => 'Importuj mimo to';

  @override
  String icpImportNotePrefill(String id) {
    return 'Próbka ICP $id';
  }

  @override
  String get unitFixedNote => 'Ten parametr zawsze używa tej jednostki.';

  @override
  String get helpTemperature =>
      'Temperatura wody. Stabilność jest ważniejsza niż dokładna wartość.';

  @override
  String get helpSalinity => 'Gęstość względna. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Twardość węglanowa. Utrzymuj stabilną — unikaj wahań.';

  @override
  String get helpNitrate =>
      'Składnik odżywczy. Koralowce potrzebują go trochę; nadmiar sprzyja glonom.';

  @override
  String get helpAmmonia =>
      'Toksyczny. W dojrzałym akwarium powinien być praktycznie zerowy.';

  @override
  String get healthTitle => 'Kondycja zbiornika';

  @override
  String get healthGradeExcellent => 'Doskonała';

  @override
  String get healthGradeGood => 'Dobra';

  @override
  String get healthGradeCaution => 'Uwaga';

  @override
  String get healthGradeCritical => 'Krytyczna';

  @override
  String get healthGradeUnknown => 'Brak danych';

  @override
  String get healthAllOnTarget => 'Wszystkie parametry w normie';

  @override
  String healthParamsToWatch(int count) {
    return '$count do obserwacji';
  }

  @override
  String get healthSectionAttention => 'Wymaga uwagi';

  @override
  String get healthSectionGood => 'W porządku';

  @override
  String get healthSectionStale => 'Dawno nie mierzone';

  @override
  String healthNotTestedDays(int count) {
    return 'Nie mierzone od $count d';
  }

  @override
  String get healthNeverTested => 'Jeszcze nie mierzone';

  @override
  String get healthNoReadingsYet => 'Brak pomiarów';

  @override
  String healthScoreOf(int score) {
    return '$score ze 100';
  }

  @override
  String get dashboardSection => 'Pulpit';

  @override
  String get healthDisplayTitle => 'Kondycja zbiornika';

  @override
  String get healthDisplaySubtitle => 'Gdzie pokazać podsumowanie kondycji';

  @override
  String get healthDisplayBoth => 'Odznaka i karta';

  @override
  String get healthDisplayBadge => 'Tylko odznaka';

  @override
  String get healthDisplayOff => 'Ukryte';

  @override
  String get routeNotFoundTitle => 'Nie znaleziono strony';

  @override
  String get routeNotFoundBody => 'Ten link nigdzie nie prowadzi w aplikacji.';

  @override
  String get routeNotFoundGoHome => 'Przejdź do ekranu głównego';

  @override
  String get notifChannelTesting => 'Przypomnienia o testach';

  @override
  String get notifChannelDosing => 'Przypomnienia o dawkowaniu';

  @override
  String get notifChannelMaintenance => 'Przypomnienia o konserwacji';

  @override
  String get notifTestingTitle => 'Czas na test';

  @override
  String get notifDosingTitle => 'Czas na dawkowanie';

  @override
  String get notifMaintenanceTitle => 'Czas na konserwację';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Przypomnienia';

  @override
  String get remindersSubtitle =>
      'Powiadomienia o testach, dawkowaniu i konserwacji';

  @override
  String get remindersTestingSubtitle =>
      'Gdy zbliża się termin testu parametru';

  @override
  String get remindersDosingSubtitle => 'O porze dawkowania każdego preparatu';

  @override
  String get remindersMaintenanceSubtitle =>
      'Gdy przypada zaplanowana konserwacja';

  @override
  String get reminderTimeTitle => 'Godzina przypomnień';

  @override
  String get reminderTimeSubtitle =>
      'O której przychodzą przypomnienia o testach i konserwacji';

  @override
  String get remindersPermissionDenied =>
      'Powiadomienia są zablokowane w ustawieniach systemu — przypomnienia nie będą wyświetlane.';

  @override
  String get remindToTest => 'Przypominaj o teście';

  @override
  String get cadenceOff => 'Wył.';

  @override
  String daysShortN(int count) {
    return '$count d';
  }

  @override
  String get cadenceCustom => 'Własny';

  @override
  String get customDaysLabel => 'Dni';

  @override
  String get remindMe => 'Przypominaj';

  @override
  String get remindMeNeedsTime =>
      'Ustaw porę dawkowania, aby włączyć przypomnienia';

  @override
  String get maintenanceSchedule => 'Harmonogram konserwacji';

  @override
  String get addMaintenanceTask => 'Dodaj zadanie';

  @override
  String get editMaintenanceTask => 'Edytuj zadanie';

  @override
  String get taskTypeLabel => 'Typ';

  @override
  String get customTask => 'Własne zadanie';

  @override
  String get taskTitleLabel => 'Nazwa';

  @override
  String get taskTitleRequired => 'Podaj nazwę';

  @override
  String get repeatLabel => 'Powtarzanie';

  @override
  String get oneOff => 'Jednorazowo';

  @override
  String get dueDateLabel => 'Termin';

  @override
  String get dueDateRequired => 'Wybierz termin';

  @override
  String get dueToday => 'Dziś';

  @override
  String dueInDaysN(int count) {
    return 'Za $count d';
  }

  @override
  String overdueDaysN(int count) {
    return '$count d po terminie';
  }

  @override
  String get markDone => 'Zrobione';

  @override
  String get taskMarkedDone => 'Oznaczono jako zrobione';

  @override
  String get taskDeleted => 'Zadanie usunięte';

  @override
  String get scheduleEmptyBody =>
      'Brak zadań konserwacji. Zaplanuj podmiany wody lub własne zadania, aby widzieć terminy i otrzymywać przypomnienia.';

  @override
  String get repeatModeLabel => 'Powtarzanie';

  @override
  String get repeatEveryDays => 'Co X dni';

  @override
  String get repeatEveryWeeks => 'Co X tygodni';

  @override
  String get repeatEveryMonths => 'Co X miesięcy';

  @override
  String get repeatOnWeekdays => 'Dni tygodnia';

  @override
  String get repeatOnMonthDay => 'Dzień miesiąca';

  @override
  String get weeksLabel => 'Tygodnie';

  @override
  String get monthsLabel => 'Miesiące';

  @override
  String get monthDayLabel => 'Dzień miesiąca (1–31)';

  @override
  String get invalidInterval => 'Podaj liczbę całkowitą (co najmniej 1).';

  @override
  String get invalidMonthDay => 'Podaj dzień od 1 do 31.';

  @override
  String get weekdaysRequired => 'Wybierz co najmniej jeden dzień.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Co $n tygodnia',
      many: 'Co $n tygodni',
      few: 'Co $n tygodnie',
      one: 'Co tydzień',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Co $n miesiąca',
      many: 'Co $n miesięcy',
      few: 'Co $n miesiące',
      one: 'Co miesiąc',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'W $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Co miesiąc $n. dnia';
  }

  @override
  String get roUnitTitle => 'Odwrócona osmoza';

  @override
  String get roStageSediment => 'Wkład sedymentacyjny';

  @override
  String get roStageCarbonBlock => 'Wkład węglowy';

  @override
  String get roStageMembrane => 'Membrana RO';

  @override
  String get roStageDiResin => 'Żywica DI';

  @override
  String get roCustomStage => 'Własny element';

  @override
  String get roAddStage => 'Dodaj element';

  @override
  String get roEditStage => 'Edytuj element';

  @override
  String get roLifespanLabel => 'Wymieniaj co';

  @override
  String get roUnitDays => 'dni';

  @override
  String get roUnitWeeks => 'tygodni';

  @override
  String get roUnitMonths => 'miesięcy';

  @override
  String get roPartOfUnit => 'Część mojego zestawu';

  @override
  String get roPartOfUnitHint =>
      'Wyłącz, jeśli twój zestaw nie ma tego stopnia';

  @override
  String get roHiddenStages => 'Nie ma w moim zestawie';

  @override
  String get roMarkReplaced => 'Wymieniono';

  @override
  String get roReplacedRecorded => 'Zapisano wymianę';

  @override
  String roLastReplaced(String date) {
    return 'Wymieniono $date';
  }

  @override
  String get roNoReplacementYet => 'Nie zapisano jeszcze żadnej wymiany';

  @override
  String get roDeleteStageTitle => 'Usunąć element?';

  @override
  String get roDeleteStageBody =>
      'Usunie element wraz z historią wymian. Nie można tego cofnąć.';

  @override
  String get roEmptyBody =>
      'Brak elementów. Dodaj filtry swojego zestawu RO przyciskiem +.';

  @override
  String get roSetupPrompt => 'Śledź wymiany filtrów i membrany';

  @override
  String get roUnitToggleSubtitle =>
      'Pokazuj na karcie Akcje, z przypomnieniami o wymianie filtrów';

  @override
  String get roAllOk => 'Wszystkie elementy w porządku';

  @override
  String get notifRoTitle => 'Wymień filtry odwróconej osmozy';
}
