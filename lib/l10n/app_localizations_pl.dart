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
  String get apply => 'Zastosuj';

  @override
  String get change => 'Zmień';

  @override
  String errorWith(Object message) {
    return 'Błąd: $message';
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
  String get edit => 'Edytuj';

  @override
  String deleteTankTitle(Object name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get deleteTankBody =>
      'Spowoduje to trwałe usunięcie akwarium i wszystkich jego pomiarów.';

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
      'Spowoduje to nadpisanie granic zielona/pomarańczowa/czerwona wszystkich śledzonych parametrów domyślnymi wartościami presetu. Twoje pomiary zostaną zachowane.';

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
  String get noteOptional => 'Notatka (opcjonalnie)';

  @override
  String get saveReadings => 'Zapisz pomiary';

  @override
  String invalidNumberFor(Object name) {
    return 'Nieprawidłowa liczba dla $name';
  }

  @override
  String get enterAtLeastOneValue => 'Wpisz co najmniej jedną wartość.';

  @override
  String savedReadings(int count) {
    return 'Zapisano pomiarów: $count.';
  }

  @override
  String get noTrackedToRecord => 'Brak śledzonych parametrów do zapisania.';

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
  String get deleteMeasurementTitle => 'Usunąć pomiar?';

  @override
  String get deleteMeasurementBody =>
      'Spowoduje to trwałe usunięcie tej wartości.';

  @override
  String get deleteTogetherTitle => 'Usuń pomiar';

  @override
  String deleteTogetherBody(int count) {
    return 'Ta wartość została wprowadzona razem z $count innymi pomiarami. Usunąć tylko tę wartość, czy wszystkie wprowadzone razem?';
  }

  @override
  String get deleteOnlyThis => 'Tylko tę wartość';

  @override
  String get deleteAllTogether => 'Wszystkie razem';

  @override
  String get editTogetherTitle => 'Zmień czas pomiaru';

  @override
  String editTogetherBody(int count) {
    return 'Ta wartość została wprowadzona razem z $count innymi pomiarami. Zmienić czas tylko dla tej wartości, czy dla wszystkich wprowadzonych razem?';
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
  String get deleteWaterChangeTitle => 'Usunąć podmianę wody?';

  @override
  String get deleteWaterChangeBody =>
      'Spowoduje to trwałe usunięcie tej podmiany wody.';

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
  String get deleteCarbonChangeTitle => 'Usunąć wymianę węgla?';

  @override
  String get deleteCarbonChangeBody =>
      'Spowoduje to trwałe usunięcie tej wymiany węgla.';

  @override
  String get equipmentCleaning => 'Czyszczenie sprzętu';

  @override
  String get recordEquipmentCleaning => 'Zapisz czyszczenie sprzętu';

  @override
  String get deleteEquipmentCleaningTitle => 'Usunąć czyszczenie sprzętu?';

  @override
  String get deleteEquipmentCleaningBody =>
      'Spowoduje to trwałe usunięcie tego czyszczenia sprzętu.';

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
  String get deleteDosingTitle => 'Usunąć preparat?';

  @override
  String get deleteDosingBody =>
      'Spowoduje to usunięcie tego preparatu z planu dozowania.';

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
  String dosingEveryDaysN(Object n) {
    return 'Co $n dni';
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
  String get backupExport => 'Eksportuj kopię';

  @override
  String get backupExportSubtitle =>
      'Zapisz wszystkie akwaria i pomiary do pliku';

  @override
  String get backupImport => 'Przywróć z kopii';

  @override
  String get backupImportSubtitle =>
      'Zastąp wszystkie dane plikiem kopii zapasowej';

  @override
  String get backupRestoreConfirmTitle => 'Przywrócić kopię zapasową?';

  @override
  String get backupRestoreConfirmBody =>
      'Spowoduje to zastąpienie wszystkich obecnych akwariów, parametrów i pomiarów zawartością pliku kopii zapasowej. Tej operacji nie można cofnąć.';

  @override
  String get restore => 'Przywróć';

  @override
  String get backupRestored => 'Kopia zapasowa przywrócona';

  @override
  String get backupExportFailed => 'Nie udało się wyeksportować kopii';

  @override
  String get backupImportFailed => 'Nie udało się przywrócić kopii';

  @override
  String get backupInvalidFile =>
      'Ten plik nie jest prawidłową kopią zapasową ReefTracker';

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
  String doseCalcReadings(Object count) {
    return 'Pomiary w okresie: $count';
  }

  @override
  String get doseCalcVolume => 'Objętość zbiornika';

  @override
  String get doseCalcCurrentDose => 'Obecna dawka dzienna';

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
  String get doseCalcNeedsPotency =>
      'Podaj moc preparatu, aby otrzymać zalecenie dawki.';

  @override
  String get doseCalcInsufficient =>
      'Aby obliczyć, dodaj co najmniej dwa pomiary z różnych dni i objętość zbiornika.';

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
  String get paramPotassium => 'Potas';

  @override
  String get paramStrontium => 'Stront';

  @override
  String get paramIodine => 'Jod';

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
}
