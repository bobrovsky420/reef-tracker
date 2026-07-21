// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Misurazioni';

  @override
  String get settings => 'Impostazioni';

  @override
  String get manageParameters => 'Gestisci parametri';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get tourTankTitle => 'I tuoi acquari';

  @override
  String get tourTankDesc =>
      'Tocca qui per passare da un acquario all\'altro o aggiungerne uno nuovo.';

  @override
  String get tourCompareTitle => 'Vista di confronto';

  @override
  String get tourCompareDesc =>
      'Passa dalle schede dei parametri ai grafici di confronto sovrapposti.';

  @override
  String get tourParamsTitle => 'Gestisci parametri';

  @override
  String get tourParamsDesc =>
      'Scegli quali parametri dell\'acqua monitorare e imposta i loro intervalli target.';

  @override
  String get tourDosingHistoryTitle => 'Cronologia dosaggi';

  @override
  String get tourDosingHistoryDesc =>
      'Consulta tutti i periodi di dosaggio passati e attuali ed elimina una voce inserita per errore.';

  @override
  String get tourDoseCalcTitle => 'Calcolatore di dosaggio';

  @override
  String get tourDoseCalcDesc =>
      'Nella scheda Dosaggio, apri il calcolatore per stimare la dose giornaliera che mantiene stabile un elemento.';

  @override
  String get tourNext => 'Avanti';

  @override
  String get tourDone => 'Capito';

  @override
  String get tourSkip => 'Salta';

  @override
  String get replayTour => 'Rivedi il tour';

  @override
  String get replayTourSubtitle =>
      'Mostra di nuovo i suggerimenti della barra superiore';

  @override
  String get compareView => 'Confronta grafici';

  @override
  String get gridView => 'Vista griglia';

  @override
  String get addReading => 'Aggiungi misurazione';

  @override
  String get addAquarium => 'Aggiungi acquario';

  @override
  String get manageTanks => 'Gestisci acquari';

  @override
  String get chooseParameters => 'Scegli parametri';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get stop => 'Interrompi';

  @override
  String get apply => 'Applica';

  @override
  String get change => 'Modifica';

  @override
  String get undo => 'Annulla';

  @override
  String get itemDeleted => 'Eliminato';

  @override
  String get reorder => 'Riordina';

  @override
  String errorWith(Object message) {
    return 'Errore: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String get welcomeTitle => 'Benvenuto in ReefTracker';

  @override
  String get welcomeBody =>
      'Crea il tuo primo acquario per iniziare a monitorare i parametri dell\'acqua.';

  @override
  String get noParamsTracked => 'Nessun parametro monitorato per questa vasca.';

  @override
  String get noReadings => 'Nessuna misurazione';

  @override
  String get dashSectionCoreChemistry => 'Chimica di base';

  @override
  String get dashSectionNutrients => 'Nutrienti';

  @override
  String get dashSectionRatios => 'Rapporti';

  @override
  String get dashSectionEnvironment => 'Ambiente';

  @override
  String gaugeIdealRange(String min, String max) {
    return 'ideale $min–$max';
  }

  @override
  String get timeJustNow => 'proprio ora';

  @override
  String timeMinAgo(int count) {
    return '$count min fa';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count h fa';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count gg fa';
  }

  @override
  String get aquariums => 'Acquari';

  @override
  String get noAquariumsYet => 'Ancora nessun acquario.';

  @override
  String get makeActive => 'Imposta come attivo';

  @override
  String get active => 'Attivo';

  @override
  String get edit => 'Modifica';

  @override
  String deleteTankTitle(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get deleteTankBody =>
      'L\'acquario e tutte le sue misurazioni verranno eliminati definitivamente.';

  @override
  String tankDeleted(Object name) {
    return 'Acquario \"$name\" eliminato';
  }

  @override
  String get newAquarium => 'Nuovo acquario';

  @override
  String get editAquarium => 'Modifica acquario';

  @override
  String get name => 'Nome';

  @override
  String get nameHint => 'es. Reef del soggiorno';

  @override
  String get enterAName => 'Inserisci un nome';

  @override
  String get setupType => 'Tipo di vasca';

  @override
  String get presetSeedNote =>
      'Per questo tipo di vasca verranno impostati i parametri predefiniti e i limiti delle zone. Potrai regolarli in qualsiasi momento.';

  @override
  String get volumeOptional => 'Volume (facoltativo)';

  @override
  String get vendorOptional => 'Produttore (facoltativo)';

  @override
  String get modelOptional => 'Modello (facoltativo)';

  @override
  String get notesOptional => 'Note (facoltativo)';

  @override
  String get createAquarium => 'Crea acquario';

  @override
  String litersSuffix(Object value) {
    return '$value L';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Data di avvio';

  @override
  String get notSet => 'Non impostata';

  @override
  String get setDate => 'Imposta';

  @override
  String get clear => 'Cancella';

  @override
  String sinceDate(Object date) {
    return 'dal $date';
  }

  @override
  String get parameters => 'Parametri';

  @override
  String get noActiveAquarium => 'Nessun acquario attivo.';

  @override
  String reapplyPreset(Object type) {
    return 'Riapplica il preset $type';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Riapplicare il preset $type?';
  }

  @override
  String get reapplyPresetBody =>
      'I limiti verde/arancione/rosso di tutti i parametri monitorati verranno sovrascritti con i valori predefiniti: quelli del preset del tipo di vasca per i parametri della dashboard, i valori integrati per gli oligoelementi. Le tue misurazioni vengono conservate.';

  @override
  String get presetApplied => 'Preset applicato.';

  @override
  String get noBoundariesSet => 'Nessun limite impostato';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  rosso <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Modifica zone';

  @override
  String get addParameter => 'Aggiungi parametro';

  @override
  String get allParametersAdded => 'Tutti i parametri sono già stati aggiunti.';

  @override
  String unitWithValue(Object unit) {
    return 'Unità: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Impostata nelle Impostazioni. I limiti qui sotto usano questa unità.';

  @override
  String get unit => 'Unità';

  @override
  String get boundAmberLow => 'Rosso sotto (arancione basso)';

  @override
  String get boundGreenLow => 'Verde da (OK basso)';

  @override
  String get boundGreenHigh => 'Verde fino a (OK alto)';

  @override
  String get boundAmberHigh => 'Rosso sopra (arancione alto)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Valori in $unit. Lascia un campo vuoto per \"nessun limite su quel lato\".';
  }

  @override
  String get enterANumber => 'Inserisci un numero';

  @override
  String get sectionSafeRanges => 'Intervalli sicuri';

  @override
  String get sectionDose => 'Dose';

  @override
  String get boundsOrderError =>
      'I limiti devono crescere: arancione basso ≤ verde basso ≤ verde alto ≤ arancione alto.';

  @override
  String get boundsPairError =>
      'Ogni limite arancione richiede il corrispondente limite verde sullo stesso lato.';

  @override
  String get noteOptional => 'Nota (facoltativo)';

  @override
  String get saveReadings => 'Salva misurazioni';

  @override
  String invalidNumberFor(Object name) {
    return 'Numero non valido per $name';
  }

  @override
  String get invalidVolume => 'Inserisci un volume positivo valido.';

  @override
  String get invalidPositiveNumber => 'Inserisci un numero positivo.';

  @override
  String get invalidIntervalDays =>
      'Inserisci un numero intero di giorni (almeno 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: questo valore è fisicamente impossibile.';
  }

  @override
  String get impossibleValue => 'Questo valore è fisicamente impossibile.';

  @override
  String get implausibleTitle => 'Valori insoliti';

  @override
  String get implausibleIntro =>
      'Il valore seguente è fuori dall\'intervallo tipico. Controlla che non sia un errore di battitura prima di salvare.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (tipico $min–$max)';
  }

  @override
  String get saveAnyway => 'Salva comunque';

  @override
  String get enterAtLeastOneValue => 'Inserisci almeno un valore.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misurazioni salvate.',
      one: '1 misurazione salvata.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Nessun parametro monitorato da registrare.';

  @override
  String get testSetAll => 'Tutti';

  @override
  String get newTestSet => 'Nuovo set di test';

  @override
  String get editTestSet => 'Modifica set di test';

  @override
  String get manageTestSets => 'Gestisci set di test';

  @override
  String get testSetNameHint => 'es. Grande test settimanale';

  @override
  String get testSetNeedParam => 'Seleziona almeno un parametro.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get deleteTestSetBody =>
      'Il set di test verrà rimosso. Le tue misurazioni vengono conservate.';

  @override
  String get testSetEmptyHint =>
      'Questo set di test non contiene parametri attivi. Modificalo o passa a Tutti.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parametri',
      one: '1 parametro',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Ancora nessun set di test. Un set registra solo i parametri che testi insieme.';

  @override
  String get rangeWeek => '7 gg';

  @override
  String get rangeMonth => '30 gg';

  @override
  String get rangeQuarter => '90 gg';

  @override
  String get rangeAll => 'Tutto';

  @override
  String get noReadingsInRange => 'Nessuna misurazione in questo intervallo.';

  @override
  String get recordFirstReading => 'Registra la tua prima misurazione';

  @override
  String get statMin => 'Min';

  @override
  String get statAvg => 'Media';

  @override
  String get statMax => 'Max';

  @override
  String get statTests => 'Test';

  @override
  String get editMeasurement => 'Modifica misurazione';

  @override
  String get deleteTogetherTitle => 'Elimina misurazione';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Questo valore è stato inserito insieme ad altre $count misurazioni. Eliminare solo questo valore o tutti i valori inseriti insieme?',
      one:
          'Questo valore è stato inserito insieme a 1 altra misurazione. Eliminare solo questo valore o tutti i valori inseriti insieme?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Solo questo valore';

  @override
  String get deleteAllTogether => 'Tutti insieme';

  @override
  String get editTogetherTitle => 'Modifica l\'ora della misurazione';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Questo valore è stato inserito insieme ad altre $count misurazioni. Modificare l\'ora solo per questo valore o per tutti i valori inseriti insieme?',
      one:
          'Questo valore è stato inserito insieme a 1 altra misurazione. Modificare l\'ora solo per questo valore o per tutti i valori inseriti insieme?',
    );
    return '$_temp0';
  }

  @override
  String get freeAmmoniaLabel => 'Ammoniaca libera (NH₃)';

  @override
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp) {
    return '$percent% tossica · pH $ph · $temp';
  }

  @override
  String freeAmmoniaPercent(Object percent) {
    return '$percent% tossica';
  }

  @override
  String get freeAmmoniaExplain =>
      'Un test dell\'ammoniaca misura l\'ammoniaca totale, ma solo la parte non ionizzata (NH₃) è tossica. La sua quota aumenta con pH e temperatura, quindi un acquario di barriera ne converte una parte maggiore nella forma tossica rispetto a una vasca a pH basso. Questa stima suddivide l\'ultima misura di ammoniaca totale usando gli ultimi valori di pH, temperatura e salinità.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Ammoniaca libera tossica: $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return 'Il $percent% dei tuoi $total ppm di ammoniaca totale è nella forma tossica NH₃.';
  }

  @override
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity) {
    return 'In base a pH $ph, $temp e $salinity.';
  }

  @override
  String freeAmmoniaSalinityAssumed(Object value) {
    return '$value (presunta)';
  }

  @override
  String get freeAmmoniaOutdatedWarning =>
      'pH o temperatura sono stati misurati l\'ultima volta più di una settimana prima di questa misura dell\'ammoniaca, quindi la frazione tossica potrebbe essere imprecisa.';

  @override
  String get freeAmmoniaShowTitle => 'Mostra ammoniaca libera (NH₃)';

  @override
  String get freeAmmoniaShowSubtitle =>
      'Aggiunge una scheda che stima la frazione tossica non ionizzata da pH, temperatura e salinità.';

  @override
  String get freeAmmoniaNeedsAmmonia => 'Attiva l\'ammoniaca per mostrarlo.';

  @override
  String get close => 'Chiudi';

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Rapporto PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Rapporto Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : Alc';

  @override
  String get ratioCaAlkTitle => 'Rapporto Ca : Alc';

  @override
  String get ratioMgAlkLabel => 'Mg : Alc';

  @override
  String get ratioMgAlkTitle => 'Rapporto Mg : Alc';

  @override
  String get ratioNoData =>
      'Registra entrambi i parametri per vedere il loro rapporto.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'I limiti delle zone usano $metric, il valore mostrato sulla scheda.';
  }

  @override
  String get waterChanges => 'Cambi d\'acqua';

  @override
  String get recordWaterChange => 'Registra cambio d\'acqua';

  @override
  String get amountLitersOptional => 'Quantità (facoltativo)';

  @override
  String get noWaterChanges => 'Ancora nessun cambio d\'acqua.';

  @override
  String get amountNotRecorded => 'Quantità non registrata';

  @override
  String get actions => 'Interventi';

  @override
  String get noActions => 'Ancora nessun intervento.';

  @override
  String get addAction => 'Aggiungi intervento';

  @override
  String get waterChange => 'Cambio d\'acqua';

  @override
  String get carbonChange => 'Cambio carbone attivo';

  @override
  String get recordCarbonChange => 'Registra cambio carbone attivo';

  @override
  String get weightOptional => 'Peso (facoltativo)';

  @override
  String get weightNotRecorded => 'Peso non registrato';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Pulizia attrezzatura';

  @override
  String get recordEquipmentCleaning => 'Registra pulizia attrezzatura';

  @override
  String get dosing => 'Dosaggio';

  @override
  String get addSupplement => 'Aggiungi integratore';

  @override
  String get noDosing => 'Ancora nessun integratore.';

  @override
  String get noDosingHint =>
      'Aggiungi gli integratori che dosi in questa vasca — produttore, prodotto e, se vuoi, dose e programma.';

  @override
  String get dosingNoDosage => 'Nessuna dose impostata';

  @override
  String get supplementStopped => 'Integratore interrotto';

  @override
  String get dosingHistoryTitle => 'Cronologia dosaggi';

  @override
  String get dosingHistoryEmpty => 'Ancora nessuna cronologia dosaggi.';

  @override
  String get dosingHistoryCurrent => 'In corso';

  @override
  String dosingHistorySince(Object date) {
    return 'Dal $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Eliminare questa voce?';

  @override
  String get deleteDosingRecordBody =>
      'Questa voce di dosaggio verrà rimossa definitivamente dalla cronologia e dal calcolo della dose. Non è possibile annullare.';

  @override
  String get deleteDosingRecordNotLatest =>
      'Questa non è la voce più recente per questo elemento; eliminarla non modificherà le voci successive.';

  @override
  String get dosingHistoryManual => 'Manuale';

  @override
  String get manualDoseNew => 'Registra dose manuale';

  @override
  String get manualDoseEdit => 'Modifica dose manuale';

  @override
  String get deleteManualDoseTitle => 'Eliminare la dose manuale?';

  @override
  String get deleteManualDoseBody =>
      'Questa dose registrata verrà rimossa definitivamente dalla cronologia e dal calcolo del dosaggio. Non è possibile annullare.';

  @override
  String get dosingNew => 'Aggiungi integratore';

  @override
  String get dosingEdit => 'Modifica integratore';

  @override
  String get dosingVendor => 'Produttore';

  @override
  String get dosingVendorName => 'Nome del produttore';

  @override
  String get dosingProduct => 'Prodotto';

  @override
  String get dosingProductName => 'Nome del prodotto';

  @override
  String get dosingElement => 'Elemento';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Altro…';

  @override
  String get dosingDosageOptional => 'Dosaggio (facoltativo)';

  @override
  String get dosingAmount => 'Quantità';

  @override
  String get dosingUnit => 'Unità';

  @override
  String get dosingBasis => 'Base';

  @override
  String get dosingPerDay => 'al giorno';

  @override
  String get dosingPerDose => 'per dose';

  @override
  String get dosingSchedule => 'Programma';

  @override
  String get dosingFrequency => 'Frequenza';

  @override
  String get dosingFreqNone => 'Nessuna';

  @override
  String get dosingFreqDaily => 'Giornaliera';

  @override
  String get dosingFreqEveryNDays => 'Ogni N giorni';

  @override
  String get dosingFreqWeekly => 'Settimanale';

  @override
  String get dosingIntervalDays => 'Intervallo (giorni)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ogni $n giorni',
      one: 'Ogni giorno',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Ora (facoltativo)';

  @override
  String get unitsSection => 'Unità';

  @override
  String get toolsSection => 'Strumenti';

  @override
  String get aboutSection => 'Informazioni';

  @override
  String get languageSection => 'Lingua';

  @override
  String get appearanceSection => 'Aspetto';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get temperature => 'Temperatura';

  @override
  String get salinity => 'Salinità';

  @override
  String get volume => 'Volume';

  @override
  String get unitUsedAcrossApp => 'Unità usata in tutta l\'app';

  @override
  String get salinityCalculator => 'Calcolatore di salinità';

  @override
  String get salinityCalculatorSubtitle => 'Conversione ppt ↔ densità (SG)';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupNow => 'Esegui backup ora';

  @override
  String backupLastRun(String when) {
    return 'Ultimo backup: $when';
  }

  @override
  String get backupNeverRun => 'Ancora nessun backup';

  @override
  String backupLastFailed(String when) {
    return 'Ultimo backup non riuscito il $when';
  }

  @override
  String get backupDone => 'Backup salvato';

  @override
  String get backupExport => 'Esporta backup';

  @override
  String get backupExportSubtitle =>
      'Salva tutti gli acquari e le misurazioni in un file';

  @override
  String get csvExportTitle => 'Esporta misurazioni (CSV)';

  @override
  String get csvExportSubtitle =>
      'Condividi le misurazioni dell\'acquario attivo come file di foglio di calcolo';

  @override
  String get csvExportNoData => 'Ancora nessuna misurazione da esportare';

  @override
  String get csvExportFailed => 'Impossibile esportare le misurazioni';

  @override
  String get backupImport => 'Ripristina da backup';

  @override
  String get backupImportSubtitle =>
      'Sostituisci tutti i dati con un file di backup';

  @override
  String get backupRestoreConfirmTitle => 'Ripristinare il backup?';

  @override
  String get backupRestoreConfirmBody =>
      'TUTTI i dati dei tuoi acquari — ogni acquario, parametro e misurazione — verranno sostituiti con il contenuto del file di backup. Le impostazioni su questo dispositivo (lingua, unità e preferenze) vengono conservate. Non è possibile annullare.';

  @override
  String get restore => 'Ripristina';

  @override
  String get backupRestored => 'Backup ripristinato';

  @override
  String get backupNowFailed => 'Impossibile salvare il backup';

  @override
  String get backupShareFailed => 'Impossibile condividere il backup';

  @override
  String get backupExportFailed => 'Impossibile esportare il backup';

  @override
  String get backupImportFailed => 'Impossibile ripristinare il backup';

  @override
  String get backupInvalidFile =>
      'Questo file non è un backup ReefTracker valido';

  @override
  String get backupTooNew =>
      'Questo backup è stato creato da una versione più recente dell\'app e non può essere ripristinato qui';

  @override
  String get backupCorrupted => 'Il file di backup è danneggiato o incompleto';

  @override
  String get backupInconsistent =>
      'Il backup è incoerente e non può essere ripristinato';

  @override
  String get dataLoadFailed =>
      'Alcuni dati non sono stati caricati. Se il problema persiste, riavvia l\'app o ripristina un backup.';

  @override
  String get autoBackupTitle => 'Backup automatico';

  @override
  String get autoBackupSubtitle =>
      'Conserva copie recenti dei tuoi dati su questo dispositivo';

  @override
  String get autoBackupFrequency => 'Frequenza';

  @override
  String get autoBackupDaily => 'Giornaliera';

  @override
  String get autoBackupWeekly => 'Settimanale';

  @override
  String get manageBackups => 'Gestisci backup';

  @override
  String get manageBackupsSubtitle =>
      'Visualizza, ripristina o condividi i backup automatici';

  @override
  String get backupsScreenTitle => 'Backup automatici';

  @override
  String get noAutoBackups => 'Ancora nessun backup automatico';

  @override
  String get noAutoBackupsHint =>
      'Un backup viene salvato automaticamente mentre usi l\'app.';

  @override
  String get share => 'Condividi';

  @override
  String get backupDeleteConfirmTitle => 'Eliminare il backup?';

  @override
  String get backupDeleteConfirmBody =>
      'Questo file di backup verrà rimosso definitivamente dal dispositivo.';

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
  String get syncGdriveTitle => 'Sincronizzazione Google Drive';

  @override
  String get syncGdriveSubtitle =>
      'Esegui il backup automaticamente sul tuo Google Drive';

  @override
  String syncGdriveLastPush(String when) {
    return 'Ultimo caricamento: $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Ancora nessun caricamento';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'I backup verranno sincronizzati sul Google Drive di $email';
  }

  @override
  String get syncGdriveConnectFailed =>
      'Impossibile connettersi a Google Drive';

  @override
  String syncGdriveDialogBody(String email) {
    return 'I backup vengono caricati nella cartella \"ReefTracker\" del Google Drive di $email. Puoi consultarli e scaricarli su drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Disconnetti';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Drive disconnesso. I backup già caricati restano sul tuo Drive.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Caricamento su Google Drive non riuscito il $when';
  }

  @override
  String get backupsLocalSection => 'Su questo dispositivo';

  @override
  String get backupsDriveSection => 'Google Drive';

  @override
  String get backupsDriveEmpty => 'Ancora nessun backup su Google Drive';

  @override
  String get backupsDriveLoadFailed =>
      'Impossibile caricare i backup da Google Drive';

  @override
  String backupsDriveTooLarge(Object size) {
    return '$size — troppo grande per essere ripristinato';
  }

  @override
  String get aboutAppName => 'Informazioni su ReefTracker';

  @override
  String get aboutDescription =>
      'Tracker offline dei parametri dell\'acquario di barriera con cronologia, grafici temporali e zone di salute verde/arancione/rossa.';

  @override
  String get editionLabel => 'Edizione';

  @override
  String get editionFounder => 'Edizione Fondatore';

  @override
  String get editionStandard => 'Standard';

  @override
  String get founderInfoBody =>
      'Usi ReefTracker fin dai suoi primi giorni. Come ringraziamento, tutte le funzionalità disponibili oggi restano gratuite per te — per sempre.';

  @override
  String get standardInfoBody =>
      'Stai usando l\'edizione standard di ReefTracker.';

  @override
  String get proFeatureTitle => 'Funzionalità Pro';

  @override
  String proFeatureBody(Object feature) {
    return '$feature fa parte di ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Acquari illimitati';

  @override
  String tankLimitBody(Object limit) {
    return 'L\'edizione standard include fino a $limit acquari — ad esempio una vasca principale e una di quarantena. Gli acquari illimitati fanno parte di ReefTracker Pro.';
  }

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Predefinita di sistema';

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
      'Conversione tra salinità pratica (ppt) e densità (SG). Scrivi in uno dei due campi.';

  @override
  String get specificGravity => 'Densità (SG)';

  @override
  String get referencePoints => 'Valori di riferimento';

  @override
  String get refSeawater => '• Acqua marina naturale ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget =>
      '• Target tipico per il reef ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG riferita a 25 °C. La conversione è un\'approssimazione lineare: SG = 1 + ppt × 0,0264/35.';

  @override
  String get doseCalcTitle => 'Calcolatore di dosaggio';

  @override
  String get doseCalcIntro =>
      'Stima quanto velocemente la vasca consuma un elemento e la dose giornaliera che lo mantiene stabile. I cambi d\'acqua non vengono considerati.';

  @override
  String get doseCalcElement => 'Elemento';

  @override
  String get doseCalcWindow => 'Periodo di misurazione';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count misurazioni nel periodo',
      one: '1 misurazione nel periodo',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dose modificata il $date; le misurazioni precedenti riflettono una dose diversa.';
  }

  @override
  String get doseCalcVolume => 'Volume della vasca';

  @override
  String get doseCalcCurrentDose => 'Dose giornaliera attuale';

  @override
  String get doseCalcManualDose => 'Dosi manuali nel periodo';

  @override
  String get doseCalcManualDoseHelp =>
      'Facoltativo: totale delle dosi una tantum o extra somministrate nel periodo di misurazione. Se vuoto, vengono usate le dosi manuali registrate.';

  @override
  String get doseCalcManualInput => 'Le dosi manuali aggiungono';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosi registrate nel periodo: $total',
      one: '1 dose registrata nel periodo: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dosi registrate usano un\'unità diversa e non vengono conteggiate.',
      one: '1 dose registrata usa un\'unità diversa e non viene conteggiata.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Alcune dosi registrate riguardano un prodotto diverso — la loro concentrazione può differire da quella inserita sopra.';

  @override
  String get doseCalcPerDay => 'giorno';

  @override
  String get doseCalcPotencyTitle => 'Concentrazione dell\'integratore';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Viene usata la concentrazione del catalogo per questo prodotto.';

  @override
  String get doseCalcEnterManually => 'Inserisci manualmente';

  @override
  String get doseCalcUseCatalog => 'Usa il valore del catalogo';

  @override
  String get doseCalcRefAmount => 'Dose';

  @override
  String get doseCalcRefVolume => 'Per volume';

  @override
  String get doseCalcRise => 'Aumenta di';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Risultato';

  @override
  String get doseCalcObservedChange => 'Variazione misurata';

  @override
  String get doseCalcConsumption => 'Consumo';

  @override
  String get doseCalcCurrentInput => 'Il dosaggio attuale apporta';

  @override
  String get doseCalcSuggestedDose => 'Dose giornaliera consigliata';

  @override
  String get doseCalcAdjustment => 'Correzione';

  @override
  String get doseCalcStable =>
      'La dose attuale mantiene stabile questo elemento — mantienila.';

  @override
  String get doseCalcIncrease =>
      'Aumenta la dose per mantenere stabile questo elemento.';

  @override
  String get doseCalcDecrease =>
      'Puoi ridurre la dose e mantenere comunque stabile questo elemento.';

  @override
  String get doseCalcOverdosing =>
      'Questo elemento sta salendo — riduci o sospendi il dosaggio.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Non viene dosato nulla e questo elemento non scende — nessuna dose necessaria.';

  @override
  String get doseCalcNeedsPotency =>
      'Inserisci la concentrazione dell\'integratore per ottenere una dose consigliata.';

  @override
  String get doseCalcInsufficient =>
      'Aggiungi almeno due misurazioni in giorni diversi e il volume della vasca per calcolare.';

  @override
  String get doseCalcModeMaintenance => 'Dose giornaliera';

  @override
  String get doseCalcModeCorrection => 'Correzione';

  @override
  String get doseCalcCorrIntro =>
      'Calcola una dose una tantum che porta un elemento dal valore attuale al tuo obiettivo. Se un aumento rapido fosse rischioso, la dose viene distribuita su più giorni.';

  @override
  String get doseCalcCurrentValue => 'Valore attuale';

  @override
  String get doseCalcCurrentValueHelp => 'Vuoto = la tua ultima misurazione.';

  @override
  String get doseCalcTargetValue => 'Valore obiettivo';

  @override
  String get doseCalcTargetValueHelp =>
      'Vuoto = l\'obiettivo di correzione del parametro, o il centro del suo intervallo sicuro.';

  @override
  String get doseCalcNeededRise => 'Aumento necessario';

  @override
  String get doseCalcOneTimeDose => 'Dose una tantum';

  @override
  String get doseCalcTotalDose => 'Dose totale';

  @override
  String get doseCalcDosePerDay => 'Dose al giorno';

  @override
  String get doseCalcSpreadDays => 'Da distribuire su (giorni)';

  @override
  String get doseCalcCorrMissing =>
      'Inserisci il valore attuale, l\'obiettivo e il volume della vasca per calcolare.';

  @override
  String get doseCalcCorrAtTarget =>
      'Già al livello dell\'obiettivo o oltre — niente da dosare.';

  @override
  String get doseCalcCorrSingle =>
      'Può essere somministrata in un\'unica dose in sicurezza.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Aumentare più di $limit al giorno è rischioso — somministra la correzione in $days dosi giornaliere.';
  }

  @override
  String get doseCalcLogDose => 'Registra questa dose';

  @override
  String get correctionCta =>
      'Sotto l\'intervallo — calcola una dose di correzione';

  @override
  String get targetValueLabel => 'Obiettivo di correzione';

  @override
  String get targetValueHelp =>
      'Precompila la modalità correzione del calcolatore di dosaggio. Vuoto = il centro dell\'intervallo sicuro.';

  @override
  String get trendSection => 'Tendenze';

  @override
  String get trendShowTitle => 'Mostra tendenze';

  @override
  String get trendShowSubtitle =>
      'Prevede dove sta andando ogni parametro e quando uscirà dal suo intervallo';

  @override
  String get trendWindow => 'Misurazioni usate';

  @override
  String trendWindowSubtitle(int days) {
    return 'Quante misurazioni recenti definiscono la tendenza; ampliato per coprire almeno $days giorni se misuri più spesso';
  }

  @override
  String get trendTitle => 'Tendenza recente';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/giorno';
  }

  @override
  String get trendFlat => 'Si mantiene stabile';

  @override
  String get trendWithinRange => 'A questo ritmo resta nell\'intervallo';

  @override
  String trendAmberInDays(int days) {
    return 'Raggiunge la zona di attenzione tra ~$days gg';
  }

  @override
  String trendRedInDays(int days) {
    return 'Raggiunge la zona critica tra ~$days gg';
  }

  @override
  String trendChipAmber(int days) {
    return 'Attenzione ~$days gg';
  }

  @override
  String trendChipRed(int days) {
    return 'Agisci ~$days gg';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'In ripresa — di nuovo nell\'intervallo tra ~$days gg';
  }

  @override
  String trendChipRecovering(int days) {
    return 'In ripresa ~$days gg';
  }

  @override
  String get trendHorizon => 'Orizzonte di avviso';

  @override
  String get trendHorizonSubtitle =>
      'Segnala un parametro solo se uscirà dal suo intervallo entro questo tempo';

  @override
  String trendHorizonDays(int days) {
    return '$days giorni';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Attenzione';

  @override
  String get zoneActNow => 'Agisci subito';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Solo pesci';

  @override
  String get setupSoft => 'Coralli molli';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Reef misto';

  @override
  String get paramTemperature => 'Temperatura';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Salinità';

  @override
  String get paramAlkalinity => 'Alcalinità';

  @override
  String get paramAlkalinityShort => 'KH';

  @override
  String get paramCalcium => 'Calcio (Ca)';

  @override
  String get paramMagnesium => 'Magnesio (Mg)';

  @override
  String get paramNitrate => 'Nitrato (NO₃)';

  @override
  String get paramPhosphate => 'Fosfato (PO₄)';

  @override
  String get paramAmmonia => 'Ammoniaca (NH₃/₄)';

  @override
  String get paramNitrite => 'Nitrito (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Potassio (K)';

  @override
  String get paramStrontium => 'Stronzio (Sr)';

  @override
  String get paramIodine => 'Iodio (I)';

  @override
  String get paramIron => 'Ferro (Fe)';

  @override
  String get paramSodium => 'Sodio (Na)';

  @override
  String get paramSulfur => 'Zolfo (S)';

  @override
  String get paramBoron => 'Boro (B)';

  @override
  String get paramBromine => 'Bromo (Br)';

  @override
  String get paramSilicon => 'Silicio (Si)';

  @override
  String get paramZinc => 'Zinco (Zn)';

  @override
  String get paramVanadium => 'Vanadio (V)';

  @override
  String get paramCopper => 'Rame (Cu)';

  @override
  String get paramNickel => 'Nichel (Ni)';

  @override
  String get paramManganese => 'Manganese (Mn)';

  @override
  String get paramMolybdenum => 'Molibdeno (Mo)';

  @override
  String get paramChromium => 'Cromo (Cr)';

  @override
  String get paramCobalt => 'Cobalto (Co)';

  @override
  String get paramLithium => 'Litio (Li)';

  @override
  String get paramBarium => 'Bario (Ba)';

  @override
  String get paramSelenium => 'Selenio (Se)';

  @override
  String get paramAluminium => 'Alluminio (Al)';

  @override
  String get paramAntimony => 'Antimonio (Sb)';

  @override
  String get paramTin => 'Stagno (Sn)';

  @override
  String get paramBeryllium => 'Berillio (Be)';

  @override
  String get paramSilver => 'Argento (Ag)';

  @override
  String get paramTungsten => 'Tungsteno (W)';

  @override
  String get paramLanthanum => 'Lantanio (La)';

  @override
  String get paramTitanium => 'Titanio (Ti)';

  @override
  String get paramZirconium => 'Zirconio (Zr)';

  @override
  String get paramArsenic => 'Arsenico (As)';

  @override
  String get paramCadmium => 'Cadmio (Cd)';

  @override
  String get paramMercury => 'Mercurio (Hg)';

  @override
  String get paramLead => 'Piombo (Pb)';

  @override
  String get microTitle => 'Oligoelementi';

  @override
  String get microSectionMajor => 'Elementi principali';

  @override
  String get microSectionTrace => 'Elementi in traccia';

  @override
  String get microSectionContaminants => 'Contaminanti';

  @override
  String get microNotMeasured => 'Non misurato';

  @override
  String get microEmptyHint =>
      'Monitora gli oligoelementi con test casalinghi o analisi ICP di laboratorio.';

  @override
  String get microAllOk => 'Tutto nell\'intervallo';

  @override
  String microOutOfRangeN(int count) {
    return '$count fuori intervallo';
  }

  @override
  String microLastMeasured(String date) {
    return 'Ultima misurazione $date';
  }

  @override
  String get microAddMeasurements => 'Aggiungi misurazioni';

  @override
  String get microAddTitle => 'Misurazioni degli oligoelementi';

  @override
  String get microChipHobby => 'Test casalinghi';

  @override
  String get microChipFullIcp => 'ICP completo';

  @override
  String get microReminderTooltip => 'Promemoria test';

  @override
  String get microReminderTitle => 'Promemoria test oligoelementi';

  @override
  String get microReminderHint =>
      'Aggiunge un\'attività di manutenzione che ti ricorda di testare regolarmente gli oligoelementi.';

  @override
  String get microReminderCreated =>
      'Promemoria aggiunto al programma di manutenzione';

  @override
  String get microIcpTaskTitle => 'Test oligoelementi (ICP)';

  @override
  String get microToggleSubtitle =>
      'Mostra nella scheda Misurazioni, con promemoria dei test. Nascondendola le misurazioni restano salvate.';

  @override
  String get microViewFull => 'Elenco completo';

  @override
  String get microViewNew => 'Nuova vista';

  @override
  String get microViewEdit => 'Modifica vista';

  @override
  String get microViewManage => 'Gestisci viste';

  @override
  String get microConfigureTitle => 'Impostazioni elementi';

  @override
  String get microViewNone =>
      'Ancora nessuna vista personalizzata. Una vista mostra solo gli elementi analizzati dal tuo laboratorio.';

  @override
  String get microViewNameHint => 'es. Pannello del mio laboratorio';

  @override
  String get microViewNeedElement => 'Seleziona almeno un elemento.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get microViewDeleteBody =>
      'Rimuove solo la vista. Le misurazioni vengono conservate.';

  @override
  String get microHideUndetectable => 'Nascondi non rilevabili (zero)';

  @override
  String get microAttentionOnly => 'Solo elementi che richiedono attenzione';

  @override
  String get microFilterAllHidden =>
      'Nessun elemento corrisponde ai filtri attuali.';

  @override
  String get icpImportTitle => 'Importa analisi ICP';

  @override
  String get icpImportFormatHint =>
      'Scegli il formato di esportazione del file.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'Esportazione CSV dal portale del laboratorio Fauna Marin';

  @override
  String get icpImportFormatZimsHint =>
      'CSV universale di misurazioni (data, misurazione, valore, unità)';

  @override
  String get icpImportUnreadable => 'Impossibile leggere il file.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Questo non sembra un\'esportazione $format.';
  }

  @override
  String get icpImportNoValues => 'Nessun valore importabile trovato nel file.';

  @override
  String get icpImportSampleDateHint =>
      'Precompilato con la data di analisi del report. Cambiala nel giorno in cui hai prelevato il campione d\'acqua.';

  @override
  String get icpImportSectionCore => 'Parametri principali';

  @override
  String icpImportSkipped(String list) {
    return 'Non importato (nessun parametro corrispondente): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importa $count valori',
      one: 'Importa 1 valore',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Campione già importato?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Misurazioni esistenti menzionano già il campione $id. Importarlo comunque di nuovo?';
  }

  @override
  String get icpImportAnyway => 'Importa comunque';

  @override
  String icpImportNotePrefill(String id) {
    return 'Campione ICP $id';
  }

  @override
  String get unitFixedNote => 'Questo parametro usa sempre questa unità.';

  @override
  String get measurementImportTitle => 'Importa misurazioni';

  @override
  String get measurementImportSourceHint =>
      'Scegli l\'app o lo strumento da cui proviene il file.';

  @override
  String get measurementImportHannaHint =>
      'Storico CSV condiviso dall\'app Hanna Lab';

  @override
  String get hannaImportTitle => 'Import Hanna Lab';

  @override
  String get hannaImportIntoTank => 'Importa nell\'acquario';

  @override
  String get hannaImportFirstFrom => 'Importa lo storico da';

  @override
  String get hannaImportEverything => 'Tutto';

  @override
  String get hannaImportFirstFromHint =>
      'Primo import in questo acquario: scegli da quando importare. Le misurazioni più vecchie verranno ignorate per sempre — utile se le hai già inserite a mano.';

  @override
  String hannaImportNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuove misurazioni',
      one: '1 nuova misurazione',
    );
    return '$_temp0';
  }

  @override
  String hannaImportAlreadyCount(int count) {
    return 'Già importate: $count';
  }

  @override
  String hannaImportBeforeCutoffCount(int count) {
    return 'Prima della data di inizio: $count';
  }

  @override
  String get hannaImportSkippedTitle => 'Non importate';

  @override
  String get hannaImportSkipRange => 'fuori dall\'intervallo del test';

  @override
  String get hannaImportSkipUnknown => 'test non tracciato dall\'app';

  @override
  String get hannaImportSkipValue => 'valore illeggibile';

  @override
  String get hannaImportUpToDate =>
      'Tutto il contenuto di questo file è già stato importato.';

  @override
  String hannaImportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importa $count misurazioni',
      one: 'Importa 1 misurazione',
    );
    return '$_temp0';
  }

  @override
  String hannaImportDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importate $count misurazioni',
      one: 'Importata 1 misurazione',
    );
    return '$_temp0';
  }

  @override
  String get hannaImportUndone => 'Import annullato.';

  @override
  String get hannaImportWrongTankTitle => 'Un altro acquario?';

  @override
  String hannaImportWrongTankBody(String location, String tank, String other) {
    return '“$location” è stato importato l\'ultima volta in $tank. Importare invece in $other?';
  }

  @override
  String get measurementImportSettingsTitle => 'Import misurazioni';

  @override
  String get measurementImportSettingsSubtitle =>
      'Stato dell\'import Hanna Lab per acquario';

  @override
  String hannaImportImportedUpTo(String date) {
    return 'Importato fino al $date';
  }

  @override
  String get hannaImportNeverImported => 'Non ancora importato';

  @override
  String get hannaImportChangeDate => 'Cambia data…';

  @override
  String get hannaImportReset => 'Ripristina';

  @override
  String get hannaImportResetTitle => 'Ripristinare l\'import Hanna Lab?';

  @override
  String get hannaImportResetBody =>
      'Il prossimo import chiederà di nuovo da quale data iniziare. Le misurazioni già importate restano; l\'abbinamento dell\'acquario viene ricordato.';

  @override
  String get helpTemperature =>
      'Temperatura dell\'acqua. La stabilità conta più del valore esatto.';

  @override
  String get helpSalinity => 'Densità. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Durezza carbonatica. Mantienila stabile — evita gli sbalzi.';

  @override
  String get helpNitrate =>
      'Un nutriente. Ai coralli ne serve un po\'; troppo alimenta le alghe.';

  @override
  String get helpAmmonia =>
      'Tossica. In una vasca matura dovrebbe essere praticamente zero.';

  @override
  String get healthTitle => 'Salute della vasca';

  @override
  String get healthGradeExcellent => 'Eccellente';

  @override
  String get healthGradeGood => 'Buona';

  @override
  String get healthGradeCaution => 'Attenzione';

  @override
  String get healthGradeCritical => 'Critica';

  @override
  String get healthGradeUnknown => 'Nessun dato';

  @override
  String get healthAllOnTarget => 'Tutti i parametri in target';

  @override
  String healthParamsToWatch(int count) {
    return '$count da tenere d\'occhio';
  }

  @override
  String get healthSectionAttention => 'Richiede attenzione';

  @override
  String get healthSectionGood => 'Tutto bene';

  @override
  String get healthSectionStale => 'Non testato di recente';

  @override
  String healthNotTestedDays(int count) {
    return 'Non testato da $count gg';
  }

  @override
  String get healthNeverTested => 'Mai testato';

  @override
  String get healthNoReadingsYet => 'Ancora nessuna misurazione';

  @override
  String healthScoreOf(int score) {
    return '$score su 100';
  }

  @override
  String get stabilityTitle => 'Stabilità';

  @override
  String get stabilityScoreProName => 'Punteggio di stabilità';

  @override
  String get stabilityGradeRockSolid => 'Solidissima';

  @override
  String get stabilityGradeSteady => 'Stabile';

  @override
  String get stabilityGradeVariable => 'Variabile';

  @override
  String get stabilityGradeUnstable => 'Instabile';

  @override
  String get stabilityGradeUnknown => 'Nessun dato';

  @override
  String stabilityIntro(int days) {
    return 'Quanto stabilmente si è mantenuto ogni parametro negli ultimi $days giorni.';
  }

  @override
  String get stabilitySectionVariable => 'I più variabili';

  @override
  String get stabilitySectionSteady => 'Si mantengono stabili';

  @override
  String get stabilitySectionInsufficient => 'Dati insufficienti';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count test negli ultimi $days giorni',
      one: '1 test negli ultimi $days giorni',
      zero: 'Nessun test negli ultimi $days giorni',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Finestra di stabilità';

  @override
  String get stabilityWindowSubtitle =>
      'Periodo considerato dal punteggio di stabilità';

  @override
  String get insightsTitle => 'Osservazioni';

  @override
  String get insightsProName => 'Osservazioni intelligenti';

  @override
  String get insightsIntro =>
      'Cosa suggeriscono di tenere d\'occhio le tue misurazioni recenti.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count altre',
      one: '+1 altra',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param è sotto l\'intervallo target';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param è basso e continua a scendere';
  }

  @override
  String insightHigh(Object param) {
    return '$param è sopra l\'intervallo target';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param è alto e continua a salire';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param è fuori dall\'intervallo target';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param sta scendendo — potrebbe uscire dall\'intervallo tra ~$days gg';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param sta salendo — potrebbe uscire dall\'intervallo tra ~$days gg';
  }

  @override
  String insightRecovering(Object param) {
    return '$param sta tornando verso l\'intervallo';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param è in ripresa — di nuovo nell\'intervallo tra ~$days gg';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param: non testato da $days gg';
  }

  @override
  String get aiSummaryAction => 'Chiedi alla tua IA';

  @override
  String get aiSummaryPrivacyNote =>
      'Questo è un prompt pronto all\'uso con i dati della tua vasca. Incollalo in ChatGPT, Claude, Gemini o un altro strumento di IA — tutto viene preparato sul tuo dispositivo, nulla viene inviato da nessuna parte.';

  @override
  String get aiSummaryPromptPreview => 'Anteprima del prompt';

  @override
  String get aiSummaryCopyPrompt => 'Copia prompt';

  @override
  String aiSummaryWeeksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settimane',
      one: '1 settimana',
    );
    return '$_temp0';
  }

  @override
  String get aiSummaryCopied => 'Copiato — incollalo nella chat con la tua IA.';

  @override
  String get aiSummaryEmpty =>
      'Ancora nessuna misurazione — niente da riepilogare.';

  @override
  String get aiSummaryInsightsFooter =>
      'Vuoi un\'analisi più approfondita? Chiedi alla tua IA';

  @override
  String aiSummaryPreamble(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other:
          'Ho un acquario marino di barriera e lo monitoro con un\'app. Qui sotto ci sono i dati della mia vasca delle ultime $weeks settimane. Analizzali, segnala rischi o tendenze da affrontare e suggerisci cosa controllare o correggere.',
      one:
          'Ho un acquario marino di barriera e lo monitoro con un\'app. Qui sotto ci sono i dati della mia vasca dell\'ultima settimana. Analizzali, segnala rischi o tendenze da affrontare e suggerisci cosa controllare o correggere.',
    );
    return '$_temp0';
  }

  @override
  String aiSummaryDocTitle(Object tank) {
    return '$tank — riepilogo dell\'acquario marino';
  }

  @override
  String aiSummaryRunningSince(Object date) {
    return 'avviato il $date';
  }

  @override
  String aiSummaryExportedLine(Object date) {
    return 'Esportato il $date.';
  }

  @override
  String get aiSummaryStatusHeading => 'Stato';

  @override
  String aiSummaryHealthLine(int score, Object grade) {
    return 'Punteggio di salute: $score su 100 ($grade)';
  }

  @override
  String aiSummaryStabilityLine(int score, Object grade, int days) {
    return 'Punteggio di stabilità: $score su 100 ($grade) negli ultimi $days giorni';
  }

  @override
  String get aiSummaryObservationsLead =>
      'Osservazioni dell\'app (basate su regole):';

  @override
  String get aiSummaryParamsHeading => 'Parametri';

  @override
  String aiSummaryTestedOn(Object date) {
    return 'ultimo test $date';
  }

  @override
  String aiSummaryTargetRange(Object range) {
    return 'Target $range';
  }

  @override
  String aiSummaryAcceptableRange(Object range) {
    return 'accettabile $range';
  }

  @override
  String get aiSummaryColDate => 'Data';

  @override
  String get aiSummaryColValue => 'Valore';

  @override
  String get aiSummaryColNote => 'Nota';

  @override
  String get aiSummaryColElement => 'Elemento';

  @override
  String get aiSummaryColStatus => 'Stato';

  @override
  String aiSummaryShowingTests(int shown, int total) {
    return 'Mostrati i $shown test più recenti su $total.';
  }

  @override
  String get aiSummaryDosingHeading => 'Piano di dosaggio';

  @override
  String aiSummaryDailyEquivalent(Object amount) {
    return '≈$amount al giorno';
  }

  @override
  String aiSummarySinceDate(Object date) {
    return 'dal $date';
  }

  @override
  String get aiSummaryOneOff => 'dose una tantum';

  @override
  String get aiSummaryActionsHeading => 'Manutenzione in questo periodo';

  @override
  String get aiSummaryMicroHeading => 'Oligoelementi (ultimi valori misurati)';

  @override
  String get dashboardSection => 'Dashboard';

  @override
  String get dashboardLayoutTitle => 'Layout dashboard';

  @override
  String get dashboardLayoutSubtitle =>
      'Come sono disposte le schede nella scheda Misurazioni';

  @override
  String get dashboardLayoutGrouped => 'Raggruppato';

  @override
  String get dashboardLayoutFlat => 'Piatto';

  @override
  String get healthDisplayTitle => 'Salute della vasca';

  @override
  String get healthDisplaySubtitle => 'Dove mostrare il riepilogo della salute';

  @override
  String get healthDisplayBoth => 'Badge e scheda';

  @override
  String get healthDisplayBadge => 'Solo badge';

  @override
  String get healthDisplayOff => 'Nascosto';

  @override
  String get routeNotFoundTitle => 'Pagina non trovata';

  @override
  String get routeNotFoundBody =>
      'Questo collegamento non porta da nessuna parte nell\'app.';

  @override
  String get routeNotFoundGoHome => 'Vai alla schermata principale';

  @override
  String get notifChannelTesting => 'Promemoria test';

  @override
  String get notifChannelDosing => 'Promemoria dosaggi';

  @override
  String get notifChannelMaintenance => 'Promemoria manutenzione';

  @override
  String get notifTestingTitle => 'È ora di testare';

  @override
  String get notifDosingTitle => 'Dosaggio in scadenza';

  @override
  String get notifMaintenanceTitle => 'Manutenzione in scadenza';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Promemoria';

  @override
  String get remindersSubtitle => 'Notifiche per test, dosaggi e manutenzione';

  @override
  String get remindersTestingSubtitle => 'Quando è ora di testare un parametro';

  @override
  String get remindersDosingSubtitle =>
      'All\'ora di dosaggio di ogni integratore';

  @override
  String get remindersMaintenanceSubtitle =>
      'Quando è in scadenza la manutenzione programmata';

  @override
  String get reminderTimeTitle => 'Ora dei promemoria';

  @override
  String get reminderTimeSubtitle =>
      'Ora di consegna dei promemoria di test e manutenzione';

  @override
  String get remindersPermissionDenied =>
      'Le notifiche sono bloccate nelle impostazioni di sistema; i promemoria non possono essere mostrati.';

  @override
  String get remindToTest => 'Ricorda di testare';

  @override
  String get cadenceOff => 'Disattivato';

  @override
  String daysShortN(int count) {
    return '$count gg';
  }

  @override
  String get cadenceCustom => 'Personalizzata';

  @override
  String get customDaysLabel => 'Giorni';

  @override
  String get remindMe => 'Ricordamelo';

  @override
  String get remindMeNeedsTime =>
      'Imposta un\'ora di dosaggio per attivare i promemoria';

  @override
  String get maintenanceSchedule => 'Programma di manutenzione';

  @override
  String get addMaintenanceTask => 'Aggiungi attività';

  @override
  String get editMaintenanceTask => 'Modifica attività';

  @override
  String get taskTypeLabel => 'Tipo';

  @override
  String get customTask => 'Attività personalizzata';

  @override
  String get taskTitleLabel => 'Titolo';

  @override
  String get taskTitleRequired => 'Inserisci un titolo';

  @override
  String get repeatLabel => 'Ripetizione';

  @override
  String get oneOff => 'Una tantum';

  @override
  String get dueDateLabel => 'Scadenza';

  @override
  String get dueDateRequired => 'Scegli una scadenza';

  @override
  String get dueToday => 'Scade oggi';

  @override
  String dueInDaysN(int count) {
    return 'Tra $count gg';
  }

  @override
  String overdueDaysN(int count) {
    return 'In ritardo di $count gg';
  }

  @override
  String get markDone => 'Segna come fatta';

  @override
  String get taskMarkedDone => 'Segnata come fatta';

  @override
  String get taskDeleted => 'Attività eliminata';

  @override
  String get scheduleEmptyBody =>
      'Ancora nessuna attività di manutenzione. Pianifica cambi d\'acqua o attività personalizzate per avere scadenze e promemoria.';

  @override
  String get repeatModeLabel => 'Ripetizione';

  @override
  String get repeatEveryDays => 'Ogni X giorni';

  @override
  String get repeatEveryWeeks => 'Ogni X settimane';

  @override
  String get repeatEveryMonths => 'Ogni X mesi';

  @override
  String get repeatOnWeekdays => 'Giorni della settimana';

  @override
  String get repeatOnMonthDay => 'Giorno del mese';

  @override
  String get weeksLabel => 'Settimane';

  @override
  String get monthsLabel => 'Mesi';

  @override
  String get monthDayLabel => 'Giorno del mese (1–31)';

  @override
  String get invalidInterval => 'Inserisci un numero intero (almeno 1).';

  @override
  String get invalidMonthDay => 'Inserisci un giorno tra 1 e 31.';

  @override
  String get weekdaysRequired => 'Scegli almeno un giorno.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ogni $n settimane',
      one: 'Ogni settimana',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ogni $n mesi',
      one: 'Ogni mese',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'Ogni $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Ogni mese il giorno $n';
  }

  @override
  String get roUnitTitle => 'Impianto di osmosi inversa';

  @override
  String get roStageSediment => 'Filtro sedimenti';

  @override
  String get roStageCarbonBlock => 'Blocco di carbone';

  @override
  String get roStageMembrane => 'Membrana osmotica';

  @override
  String get roStageDiResin => 'Resina DI';

  @override
  String get roCustomStage => 'Componente personalizzato';

  @override
  String get roAddStage => 'Aggiungi componente';

  @override
  String get roEditStage => 'Modifica componente';

  @override
  String get roLifespanLabel => 'Sostituisci ogni';

  @override
  String get roUnitDays => 'giorni';

  @override
  String get roUnitWeeks => 'settimane';

  @override
  String get roUnitMonths => 'mesi';

  @override
  String get roPartOfUnit => 'Presente nel mio impianto';

  @override
  String get roPartOfUnitHint =>
      'Disattiva se il tuo impianto non ha questo stadio';

  @override
  String get roHiddenStages => 'Non presente nel mio impianto';

  @override
  String get roMarkReplaced => 'Sostituito';

  @override
  String get roReplacedRecorded => 'Sostituzione registrata';

  @override
  String roLastReplaced(String date) {
    return 'Sostituito il $date';
  }

  @override
  String get roNoReplacementYet => 'Ancora nessuna sostituzione registrata';

  @override
  String get roDeleteStageTitle => 'Eliminare il componente?';

  @override
  String get roDeleteStageBody =>
      'Rimuove il componente e la cronologia delle sue sostituzioni. Non è possibile annullare.';

  @override
  String get roEmptyBody =>
      'Nessun componente. Aggiungi i filtri del tuo impianto di osmosi con +.';

  @override
  String get roSetupPrompt =>
      'Tieni traccia delle sostituzioni di filtri e membrana';

  @override
  String get roUnitToggleSubtitle =>
      'Mostra nella scheda Interventi, con promemoria di sostituzione dei filtri';

  @override
  String get roAllOk => 'Tutti i componenti OK';

  @override
  String get notifRoTitle => 'Sostituisci i filtri dell\'osmosi';
}
