// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Mesures';

  @override
  String get settings => 'Réglages';

  @override
  String get manageParameters => 'Gérer les paramètres';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get tourTankTitle => 'Vos aquariums';

  @override
  String get tourTankDesc =>
      'Touchez ici pour passer d\'un aquarium à l\'autre ou en ajouter un nouveau.';

  @override
  String get tourCompareTitle => 'Vue comparative';

  @override
  String get tourCompareDesc =>
      'Basculez entre les cartes de paramètres et les graphiques comparatifs superposés.';

  @override
  String get tourParamsTitle => 'Gérer les paramètres';

  @override
  String get tourParamsDesc =>
      'Choisissez les paramètres d\'eau à suivre et définissez leurs plages cibles.';

  @override
  String get tourDosingHistoryTitle => 'Historique de dosage';

  @override
  String get tourDosingHistoryDesc =>
      'Consultez toutes les périodes de dosage passées et actuelles, et supprimez un enregistrement saisi par erreur.';

  @override
  String get tourDoseCalcTitle => 'Calculateur de dose';

  @override
  String get tourDoseCalcDesc =>
      'Dans l\'onglet Dosage, ouvrez le calculateur pour estimer la dose quotidienne qui maintient un élément stable.';

  @override
  String get tourNext => 'Suivant';

  @override
  String get tourDone => 'Compris';

  @override
  String get tourSkip => 'Passer';

  @override
  String get replayTour => 'Revoir la visite guidée';

  @override
  String get replayTourSubtitle =>
      'Afficher à nouveau les astuces de la barre supérieure';

  @override
  String get compareView => 'Comparer les graphiques';

  @override
  String get gridView => 'Vue grille';

  @override
  String get addReading => 'Ajouter une mesure';

  @override
  String get addAquarium => 'Ajouter un aquarium';

  @override
  String get manageTanks => 'Gérer les aquariums';

  @override
  String get chooseParameters => 'Choisir les paramètres';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get stop => 'Arrêter';

  @override
  String get apply => 'Appliquer';

  @override
  String get change => 'Modifier';

  @override
  String get undo => 'Annuler';

  @override
  String get itemDeleted => 'Supprimé';

  @override
  String get reorder => 'Réorganiser';

  @override
  String errorWith(Object message) {
    return 'Erreur : $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get welcomeTitle => 'Bienvenue dans ReefTracker';

  @override
  String get welcomeBody =>
      'Créez votre premier aquarium pour commencer à suivre les paramètres de l\'eau.';

  @override
  String get noParamsTracked => 'Aucun paramètre n\'est suivi pour ce bac.';

  @override
  String get noReadings => 'Aucune mesure';

  @override
  String get dashSectionCoreChemistry => 'Chimie de base';

  @override
  String get dashSectionNutrients => 'Nutriments';

  @override
  String get dashSectionRatios => 'Ratios';

  @override
  String get dashSectionEnvironment => 'Environnement';

  @override
  String gaugeIdealRange(String min, String max) {
    return 'idéal $min–$max';
  }

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'il y a $count j';
  }

  @override
  String get aquariums => 'Aquariums';

  @override
  String get noAquariumsYet => 'Pas encore d\'aquarium.';

  @override
  String get makeActive => 'Rendre actif';

  @override
  String get active => 'Actif';

  @override
  String get edit => 'Modifier';

  @override
  String deleteTankTitle(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteTankBody =>
      'L\'aquarium et toutes ses mesures seront définitivement supprimés.';

  @override
  String tankDeleted(Object name) {
    return 'Aquarium « $name » supprimé';
  }

  @override
  String get newAquarium => 'Nouvel aquarium';

  @override
  String get editAquarium => 'Modifier l\'aquarium';

  @override
  String get name => 'Nom';

  @override
  String get nameHint => 'ex. Récif du salon';

  @override
  String get enterAName => 'Saisissez un nom';

  @override
  String get setupType => 'Type de bac';

  @override
  String get presetSeedNote =>
      'Les paramètres par défaut et les limites de zones seront configurés pour ce type de bac. Vous pourrez les ajuster à tout moment.';

  @override
  String get volumeOptional => 'Volume (facultatif)';

  @override
  String get vendorOptional => 'Fabricant (facultatif)';

  @override
  String get modelOptional => 'Modèle (facultatif)';

  @override
  String get notesOptional => 'Notes (facultatif)';

  @override
  String get createAquarium => 'Créer l\'aquarium';

  @override
  String litersSuffix(Object value) {
    return '$value L';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value gal';
  }

  @override
  String get startDate => 'Date de démarrage';

  @override
  String get notSet => 'Non définie';

  @override
  String get setDate => 'Définir';

  @override
  String get clear => 'Effacer';

  @override
  String sinceDate(Object date) {
    return 'depuis le $date';
  }

  @override
  String get parameters => 'Paramètres';

  @override
  String get noActiveAquarium => 'Aucun aquarium actif.';

  @override
  String reapplyPreset(Object type) {
    return 'Réappliquer le préréglage $type';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Réappliquer le préréglage $type ?';
  }

  @override
  String get reapplyPresetBody =>
      'Les limites verte/orange/rouge de tous les paramètres suivis seront remplacées par les valeurs par défaut : celles du préréglage du type de bac pour les paramètres du tableau de bord, les valeurs intégrées pour les oligo-éléments. Vos mesures sont conservées.';

  @override
  String get presetApplied => 'Préréglage appliqué.';

  @override
  String get noBoundariesSet => 'Aucune limite définie';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  rouge <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Modifier les zones';

  @override
  String get addParameter => 'Ajouter un paramètre';

  @override
  String get allParametersAdded => 'Tous les paramètres sont déjà ajoutés.';

  @override
  String unitWithValue(Object unit) {
    return 'Unité : $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Définie dans les Réglages. Les limites ci-dessous utilisent cette unité.';

  @override
  String get unit => 'Unité';

  @override
  String get boundAmberLow => 'Rouge en dessous de (orange bas)';

  @override
  String get boundGreenLow => 'Vert à partir de (OK bas)';

  @override
  String get boundGreenHigh => 'Vert jusqu\'à (OK haut)';

  @override
  String get boundAmberHigh => 'Rouge au-dessus de (orange haut)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Valeurs en $unit. Laissez un champ vide pour « aucune limite de ce côté ».';
  }

  @override
  String get enterANumber => 'Saisissez un nombre';

  @override
  String get sectionSafeRanges => 'Plages sûres';

  @override
  String get sectionDose => 'Dose';

  @override
  String get boundsOrderError =>
      'Les limites doivent être croissantes : orange bas ≤ vert bas ≤ vert haut ≤ orange haut.';

  @override
  String get boundsPairError =>
      'Chaque limite orange nécessite sa limite verte correspondante du même côté.';

  @override
  String get noteOptional => 'Note (facultatif)';

  @override
  String get saveReadings => 'Enregistrer les mesures';

  @override
  String invalidNumberFor(Object name) {
    return 'Nombre invalide pour $name';
  }

  @override
  String get invalidVolume => 'Saisissez un volume positif valide.';

  @override
  String get invalidPositiveNumber => 'Saisissez un nombre positif.';

  @override
  String get invalidIntervalDays =>
      'Saisissez un nombre entier de jours (au moins 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name : cette valeur est physiquement impossible.';
  }

  @override
  String get impossibleValue => 'Cette valeur est physiquement impossible.';

  @override
  String get implausibleTitle => 'Valeurs inhabituelles';

  @override
  String get implausibleIntro =>
      'La valeur suivante sort de la plage habituelle. Vérifiez qu\'il ne s\'agit pas d\'une faute de frappe avant d\'enregistrer.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name : $value (habituellement $min–$max)';
  }

  @override
  String get saveAnyway => 'Enregistrer quand même';

  @override
  String get enterAtLeastOneValue => 'Saisissez au moins une valeur.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures enregistrées.',
      one: '1 mesure enregistrée.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Aucun paramètre suivi à enregistrer.';

  @override
  String get testSetAll => 'Tous';

  @override
  String get newTestSet => 'Nouveau jeu de tests';

  @override
  String get editTestSet => 'Modifier le jeu de tests';

  @override
  String get manageTestSets => 'Gérer les jeux de tests';

  @override
  String get testSetNameHint => 'ex. Grand test hebdomadaire';

  @override
  String get testSetNeedParam => 'Sélectionnez au moins un paramètre.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteTestSetBody =>
      'Le jeu de tests sera supprimé. Vos mesures sont conservées.';

  @override
  String get testSetEmptyHint =>
      'Ce jeu de tests ne contient aucun paramètre actif. Modifiez-le ou passez à Tous.';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paramètres',
      one: '1 paramètre',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Pas encore de jeu de tests. Un jeu de tests n\'enregistre que les paramètres que vous testez ensemble.';

  @override
  String get rangeWeek => '7 j';

  @override
  String get rangeMonth => '30 j';

  @override
  String get rangeQuarter => '90 j';

  @override
  String get rangeAll => 'Tout';

  @override
  String get noReadingsInRange => 'Aucune mesure sur cette période.';

  @override
  String get recordFirstReading => 'Enregistrer votre première mesure';

  @override
  String get statMin => 'Min';

  @override
  String get statAvg => 'Moy.';

  @override
  String get statMax => 'Max';

  @override
  String get statTests => 'Tests';

  @override
  String get editMeasurement => 'Modifier la mesure';

  @override
  String get deleteTogetherTitle => 'Supprimer la mesure';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cette valeur a été saisie avec $count autres mesures. Supprimer uniquement cette valeur, ou toutes les valeurs saisies ensemble ?',
      one:
          'Cette valeur a été saisie avec 1 autre mesure. Supprimer uniquement cette valeur, ou toutes les valeurs saisies ensemble ?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Seulement cette valeur';

  @override
  String get deleteAllTogether => 'Toutes ensemble';

  @override
  String get editTogetherTitle => 'Modifier l\'heure de la mesure';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cette valeur a été saisie avec $count autres mesures. Modifier l\'heure uniquement pour cette valeur, ou pour toutes les valeurs saisies ensemble ?',
      one:
          'Cette valeur a été saisie avec 1 autre mesure. Modifier l\'heure uniquement pour cette valeur, ou pour toutes les valeurs saisies ensemble ?',
    );
    return '$_temp0';
  }

  @override
  String get freeAmmoniaLabel => 'Ammoniac libre (NH₃)';

  @override
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp) {
    return '$percent % toxique · pH $ph · $temp';
  }

  @override
  String freeAmmoniaPercent(Object percent) {
    return '$percent % toxique';
  }

  @override
  String get freeAmmoniaExplain =>
      'Un test d\'ammoniac mesure l\'ammoniac total, mais seule la partie non ionisée (NH₃) est toxique. Sa proportion augmente avec le pH et la température, si bien qu\'un aquarium récifal en convertit une plus grande part sous la forme toxique qu\'un bac à pH bas. Cette estimation répartit votre dernière mesure d\'ammoniac total à partir des dernières valeurs de pH, de température et de salinité.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Ammoniac libre toxique : $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return '$percent % de vos $total ppm d\'ammoniac total sont sous la forme toxique NH₃.';
  }

  @override
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity) {
    return 'D\'après un pH de $ph, $temp et $salinity.';
  }

  @override
  String freeAmmoniaSalinityAssumed(Object value) {
    return '$value (supposée)';
  }

  @override
  String get freeAmmoniaOutdatedWarning =>
      'Le pH ou la température ont été mesurés pour la dernière fois plus d\'une semaine avant cette mesure d\'ammoniac ; la fraction toxique peut donc être imprécise.';

  @override
  String get freeAmmoniaShowTitle => 'Afficher l\'ammoniac libre (NH₃)';

  @override
  String get freeAmmoniaShowSubtitle =>
      'Ajoute une carte estimant la fraction toxique non ionisée à partir du pH, de la température et de la salinité.';

  @override
  String get freeAmmoniaNeedsAmmonia => 'Activez l\'ammoniac pour l\'afficher.';

  @override
  String get close => 'Fermer';

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Rapport PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Rapport Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : Alc';

  @override
  String get ratioCaAlkTitle => 'Rapport Ca : Alc';

  @override
  String get ratioMgAlkLabel => 'Mg : Alc';

  @override
  String get ratioMgAlkTitle => 'Rapport Mg : Alc';

  @override
  String get ratioNoData =>
      'Enregistrez les deux paramètres pour voir leur rapport.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Les limites de zones utilisent $metric, la valeur affichée sur la carte.';
  }

  @override
  String get waterChanges => 'Changements d\'eau';

  @override
  String get recordWaterChange => 'Enregistrer un changement d\'eau';

  @override
  String get amountLitersOptional => 'Quantité (facultatif)';

  @override
  String get noWaterChanges => 'Pas encore de changement d\'eau.';

  @override
  String get amountNotRecorded => 'Quantité non renseignée';

  @override
  String get actions => 'Actions';

  @override
  String get noActions => 'Pas encore d\'action.';

  @override
  String get addAction => 'Ajouter une action';

  @override
  String get waterChange => 'Changement d\'eau';

  @override
  String get carbonChange => 'Changement de charbon actif';

  @override
  String get recordCarbonChange => 'Enregistrer un changement de charbon actif';

  @override
  String get weightOptional => 'Poids (facultatif)';

  @override
  String get weightNotRecorded => 'Poids non renseigné';

  @override
  String gramsSuffix(Object value) {
    return '$value g';
  }

  @override
  String get gramSymbol => 'g';

  @override
  String get equipmentCleaning => 'Nettoyage du matériel';

  @override
  String get recordEquipmentCleaning => 'Enregistrer un nettoyage du matériel';

  @override
  String get dosing => 'Dosage';

  @override
  String get addSupplement => 'Ajouter un supplément';

  @override
  String get noDosing => 'Pas encore de supplément.';

  @override
  String get noDosingHint =>
      'Ajoutez les suppléments que vous dosez dans ce bac — fabricant, produit et, si vous le souhaitez, dose et programme.';

  @override
  String get dosingNoDosage => 'Aucune dose définie';

  @override
  String get supplementStopped => 'Supplément arrêté';

  @override
  String get dosingHistoryTitle => 'Historique de dosage';

  @override
  String get dosingHistoryEmpty => 'Pas encore d\'historique de dosage.';

  @override
  String get dosingHistoryCurrent => 'En cours';

  @override
  String dosingHistorySince(Object date) {
    return 'Depuis le $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Supprimer cet enregistrement ?';

  @override
  String get deleteDosingRecordBody =>
      'Cet enregistrement de dosage sera définitivement supprimé de l\'historique et du calcul de dose. Cette action est irréversible.';

  @override
  String get deleteDosingRecordNotLatest =>
      'Ce n\'est pas l\'enregistrement le plus récent pour cet élément ; sa suppression ne modifiera pas les enregistrements ultérieurs.';

  @override
  String get dosingHistoryManual => 'Manuel';

  @override
  String get manualDoseNew => 'Consigner une dose manuelle';

  @override
  String get manualDoseEdit => 'Modifier la dose manuelle';

  @override
  String get deleteManualDoseTitle => 'Supprimer la dose manuelle ?';

  @override
  String get deleteManualDoseBody =>
      'Cette dose consignée sera définitivement supprimée de l\'historique et du calcul de dose. Cette action est irréversible.';

  @override
  String get dosingNew => 'Ajouter un supplément';

  @override
  String get dosingEdit => 'Modifier le supplément';

  @override
  String get dosingVendor => 'Fabricant';

  @override
  String get dosingVendorName => 'Nom du fabricant';

  @override
  String get dosingProduct => 'Produit';

  @override
  String get dosingProductName => 'Nom du produit';

  @override
  String get dosingElement => 'Élément';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Autre…';

  @override
  String get dosingDosageOptional => 'Dosage (facultatif)';

  @override
  String get dosingAmount => 'Quantité';

  @override
  String get dosingUnit => 'Unité';

  @override
  String get dosingBasis => 'Base';

  @override
  String get dosingPerDay => 'par jour';

  @override
  String get dosingPerDose => 'par dose';

  @override
  String get dosingSchedule => 'Programme';

  @override
  String get dosingFrequency => 'Fréquence';

  @override
  String get dosingFreqNone => 'Aucune';

  @override
  String get dosingFreqDaily => 'Quotidien';

  @override
  String get dosingFreqEveryNDays => 'Tous les N jours';

  @override
  String get dosingFreqWeekly => 'Hebdomadaire';

  @override
  String get dosingIntervalDays => 'Intervalle (jours)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Tous les $n jours',
      one: 'Chaque jour',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Heure (facultatif)';

  @override
  String get unitsSection => 'Unités';

  @override
  String get toolsSection => 'Outils';

  @override
  String get aboutSection => 'À propos';

  @override
  String get languageSection => 'Langue';

  @override
  String get appearanceSection => 'Apparence';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get temperature => 'Température';

  @override
  String get salinity => 'Salinité';

  @override
  String get volume => 'Volume';

  @override
  String get unitUsedAcrossApp => 'Unité utilisée dans toute l\'application';

  @override
  String get salinityCalculator => 'Calculateur de salinité';

  @override
  String get salinityCalculatorSubtitle => 'Conversion ppt ↔ densité (SG)';

  @override
  String get backupSection => 'Sauvegarde';

  @override
  String get backupNow => 'Sauvegarder maintenant';

  @override
  String backupLastRun(String when) {
    return 'Dernière sauvegarde : $when';
  }

  @override
  String get backupNeverRun => 'Aucune sauvegarde pour l\'instant';

  @override
  String backupLastFailed(String when) {
    return 'Échec de la dernière sauvegarde le $when';
  }

  @override
  String get backupDone => 'Sauvegarde enregistrée';

  @override
  String get backupExport => 'Exporter la sauvegarde';

  @override
  String get backupExportSubtitle =>
      'Enregistrer tous les aquariums et mesures dans un fichier';

  @override
  String get csvExportTitle => 'Exporter les mesures (CSV)';

  @override
  String get csvExportSubtitle =>
      'Partager les mesures de l\'aquarium actif sous forme de fichier tableur';

  @override
  String get csvExportNoData => 'Aucune mesure à exporter pour l\'instant';

  @override
  String get csvExportFailed => 'Impossible d\'exporter les mesures';

  @override
  String get backupImport => 'Restaurer une sauvegarde';

  @override
  String get backupImportSubtitle =>
      'Remplacer toutes les données par un fichier de sauvegarde';

  @override
  String get backupRestoreConfirmTitle => 'Restaurer la sauvegarde ?';

  @override
  String get backupRestoreConfirmBody =>
      'TOUTES les données de vos aquariums — aquariums, paramètres et mesures — seront remplacées par le contenu du fichier de sauvegarde. Vos réglages sur cet appareil (langue, unités et préférences) sont conservés. Cette action est irréversible.';

  @override
  String get restore => 'Restaurer';

  @override
  String get backupRestored => 'Sauvegarde restaurée';

  @override
  String get backupNowFailed => 'Impossible d\'enregistrer la sauvegarde';

  @override
  String get backupShareFailed => 'Impossible de partager la sauvegarde';

  @override
  String get backupExportFailed => 'Impossible d\'exporter la sauvegarde';

  @override
  String get backupImportFailed => 'Impossible de restaurer la sauvegarde';

  @override
  String get backupInvalidFile =>
      'Ce fichier n\'est pas une sauvegarde ReefTracker valide';

  @override
  String get backupTooNew =>
      'Cette sauvegarde a été créée par une version plus récente de l\'application et ne peut pas être restaurée ici';

  @override
  String get backupCorrupted =>
      'Le fichier de sauvegarde est endommagé ou incomplet';

  @override
  String get backupInconsistent =>
      'La sauvegarde est incohérente et ne peut pas être restaurée';

  @override
  String get dataLoadFailed =>
      'Certaines données n\'ont pas pu être chargées. Si cela se reproduit, redémarrez l\'application ou restaurez une sauvegarde.';

  @override
  String get autoBackupTitle => 'Sauvegarde automatique';

  @override
  String get autoBackupSubtitle =>
      'Conserver des copies récentes de vos données sur cet appareil';

  @override
  String get autoBackupFrequency => 'Fréquence';

  @override
  String get autoBackupDaily => 'Quotidienne';

  @override
  String get autoBackupWeekly => 'Hebdomadaire';

  @override
  String get manageBackups => 'Gérer les sauvegardes';

  @override
  String get manageBackupsSubtitle =>
      'Afficher, restaurer ou partager les sauvegardes automatiques';

  @override
  String get backupsScreenTitle => 'Sauvegardes automatiques';

  @override
  String get noAutoBackups => 'Aucune sauvegarde automatique pour l\'instant';

  @override
  String get noAutoBackupsHint =>
      'Une sauvegarde est enregistrée automatiquement pendant que vous utilisez l\'application.';

  @override
  String get share => 'Partager';

  @override
  String get backupDeleteConfirmTitle => 'Supprimer la sauvegarde ?';

  @override
  String get backupDeleteConfirmBody =>
      'Ce fichier de sauvegarde sera définitivement supprimé de votre appareil.';

  @override
  String sizeBytes(Object size) {
    return '$size o';
  }

  @override
  String sizeKilobytes(Object size) {
    return '$size Ko';
  }

  @override
  String sizeMegabytes(Object size) {
    return '$size Mo';
  }

  @override
  String get syncGdriveTitle => 'Synchronisation Google Drive';

  @override
  String get syncGdriveSubtitle =>
      'Sauvegarder automatiquement sur votre Google Drive';

  @override
  String syncGdriveLastPush(String when) {
    return 'Dernier envoi : $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Rien d\'envoyé pour l\'instant';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'Les sauvegardes seront synchronisées sur le Google Drive de $email';
  }

  @override
  String get syncGdriveConnectFailed => 'Connexion à Google Drive impossible';

  @override
  String syncGdriveDialogBody(String email) {
    return 'Les sauvegardes sont envoyées dans le dossier « ReefTracker » du Google Drive de $email. Vous pouvez les consulter et les télécharger sur drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Déconnecter';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Drive déconnecté. Les sauvegardes déjà envoyées restent sur votre Drive.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Échec de l\'envoi vers Google Drive le $when';
  }

  @override
  String get syncDeviceNameTitle => 'Nom de l\'appareil';

  @override
  String get syncDeviceNameBody =>
      'Affiché avec les sauvegardes envoyées depuis cet appareil, pour distinguer vos appareils.';

  @override
  String get syncDeviceNameHint => 'p. ex. Mon téléphone';

  @override
  String get syncDeviceNameAction => 'Nom de l\'appareil…';

  @override
  String get syncRestoreTitle => 'Sauvegarde plus récente trouvée';

  @override
  String syncRestoreBody(String device, String when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans votre Google Drive. La restaurer sur cet appareil ? Les réglages de cet appareil sont conservés.';
  }

  @override
  String syncRestoreDivergedBody(String device, String when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans votre Google Drive, mais cet appareil contient aussi des modifications qui n\'ont jamais été envoyées. La restauration remplace les données de cet appareil par la sauvegarde — une copie de sécurité locale est d\'abord enregistrée.';
  }

  @override
  String get syncRestoreUnknownDevice => 'un autre appareil';

  @override
  String get syncRestoreNotNow => 'Plus tard';

  @override
  String get syncRestoreKeepMine => 'Garder les données de cet appareil';

  @override
  String get welcomeRestoreDrive => 'Restaurer depuis Google Drive';

  @override
  String get backupsLocalSection => 'Sur cet appareil';

  @override
  String get backupsDriveSection => 'Google Drive';

  @override
  String get backupsDriveEmpty =>
      'Aucune sauvegarde sur Google Drive pour l\'instant';

  @override
  String get backupsDriveLoadFailed =>
      'Impossible de charger les sauvegardes depuis Google Drive';

  @override
  String backupsDriveTooLarge(Object size) {
    return '$size — trop volumineux pour être restauré';
  }

  @override
  String get aboutAppName => 'À propos de ReefTracker';

  @override
  String get aboutDescription =>
      'Suivi hors ligne des paramètres d\'aquarium récifal avec historique, graphiques temporels et zones de santé verte/orange/rouge.';

  @override
  String get aboutUserGuide => 'Guide d\'utilisation';

  @override
  String get aboutUserGuideSubtitle =>
      'Comment utiliser chaque fonction, avec captures d\'écran';

  @override
  String get aboutSupport => 'Assistance et FAQ';

  @override
  String get aboutSupportSubtitle =>
      'Obtenir de l\'aide ou signaler un problème';

  @override
  String get aboutPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get linkOpenFailed => 'Impossible d\'ouvrir le lien';

  @override
  String get editionLabel => 'Édition';

  @override
  String get editionFounder => 'Édition Fondateur';

  @override
  String get editionStandard => 'Standard';

  @override
  String get founderInfoBody =>
      'Vous utilisez ReefTracker depuis ses débuts. En remerciement, toutes les fonctionnalités disponibles aujourd\'hui restent gratuites pour vous — pour toujours.';

  @override
  String get standardInfoBody =>
      'Vous utilisez l\'édition standard de ReefTracker.';

  @override
  String get proFeatureTitle => 'Fonctionnalité Pro';

  @override
  String proFeatureBody(Object feature) {
    return '$feature fait partie de ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Aquariums illimités';

  @override
  String tankLimitBody(Object limit) {
    return 'L\'édition standard permet jusqu\'à $limit aquariums — par exemple un bac principal et un bac de quarantaine. Les aquariums illimités font partie de ReefTracker Pro.';
  }

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

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
      'Conversion entre salinité pratique (ppt) et densité (SG). Saisissez dans l\'un ou l\'autre champ.';

  @override
  String get specificGravity => 'Densité (SG)';

  @override
  String get referencePoints => 'Points de repère';

  @override
  String get refSeawater => '• Eau de mer naturelle ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget =>
      '• Cible récifale typique ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG référencée à 25 °C. La conversion est une approximation linéaire : SG = 1 + ppt × 0,0264/35.';

  @override
  String get doseCalcTitle => 'Calculateur de dose';

  @override
  String get doseCalcIntro =>
      'Estime la vitesse à laquelle votre bac consomme un élément et la dose quotidienne qui le maintient stable. Les changements d\'eau ne sont pas pris en compte.';

  @override
  String get doseCalcElement => 'Élément';

  @override
  String get doseCalcWindow => 'Période de mesure';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures sur la période',
      one: '1 mesure sur la période',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Dose modifiée le $date ; les mesures antérieures reflètent une autre dose.';
  }

  @override
  String get doseCalcVolume => 'Volume du bac';

  @override
  String get doseCalcCurrentDose => 'Dose quotidienne actuelle';

  @override
  String get doseCalcManualDose => 'Doses manuelles sur la période';

  @override
  String get doseCalcManualDoseHelp =>
      'Facultatif : total des doses ponctuelles ou supplémentaires ajoutées pendant la période de mesure. Si le champ est vide, les doses manuelles consignées sont utilisées.';

  @override
  String get doseCalcManualInput => 'Les doses manuelles ajoutent';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses consignées sur la période : $total',
      one: '1 dose consignée sur la période : $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count doses consignées utilisent une autre unité et ne sont pas comptées.',
      one: '1 dose consignée utilise une autre unité et n\'est pas comptée.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Certaines doses consignées concernent un autre produit — leur concentration peut différer de celle saisie ci-dessus.';

  @override
  String get doseCalcPerDay => 'jour';

  @override
  String get doseCalcPotencyTitle => 'Concentration du supplément';

  @override
  String get doseCalcPotencyFromCatalog =>
      'La concentration du catalogue est utilisée pour ce produit.';

  @override
  String get doseCalcEnterManually => 'Saisir manuellement';

  @override
  String get doseCalcUseCatalog => 'Utiliser la valeur du catalogue';

  @override
  String get doseCalcRefAmount => 'Dose';

  @override
  String get doseCalcRefVolume => 'Pour un volume de';

  @override
  String get doseCalcRise => 'Augmente de';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Résultat';

  @override
  String get doseCalcObservedChange => 'Variation mesurée';

  @override
  String get doseCalcConsumption => 'Consommation';

  @override
  String get doseCalcCurrentInput => 'Le dosage actuel apporte';

  @override
  String get doseCalcSuggestedDose => 'Dose quotidienne conseillée';

  @override
  String get doseCalcAdjustment => 'Ajustement';

  @override
  String get doseCalcStable =>
      'Votre dose actuelle maintient cet élément stable — conservez-la.';

  @override
  String get doseCalcIncrease =>
      'Augmentez la dose pour maintenir cet élément stable.';

  @override
  String get doseCalcDecrease =>
      'Vous pouvez réduire la dose tout en maintenant cet élément stable.';

  @override
  String get doseCalcOverdosing =>
      'Cet élément augmente — réduisez ou suspendez le dosage.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Rien n\'est dosé et cet élément ne baisse pas — aucune dose n\'est nécessaire.';

  @override
  String get doseCalcNeedsPotency =>
      'Saisissez la concentration du supplément pour obtenir une recommandation de dose.';

  @override
  String get doseCalcInsufficient =>
      'Ajoutez au moins deux mesures sur des jours différents et un volume de bac pour calculer.';

  @override
  String get doseCalcModeMaintenance => 'Dose quotidienne';

  @override
  String get doseCalcModeCorrection => 'Correction';

  @override
  String get doseCalcCorrIntro =>
      'Calculez une dose ponctuelle qui fait monter un élément de sa valeur actuelle à votre cible. Si une hausse rapide était risquée, la dose est répartie sur plusieurs jours.';

  @override
  String get doseCalcCurrentValue => 'Valeur actuelle';

  @override
  String get doseCalcCurrentValueHelp => 'Vide = votre dernière mesure.';

  @override
  String get doseCalcTargetValue => 'Valeur cible';

  @override
  String get doseCalcTargetValueHelp =>
      'Vide = la cible de correction du paramètre, ou le milieu de sa plage sûre.';

  @override
  String get doseCalcNeededRise => 'Hausse nécessaire';

  @override
  String get doseCalcOneTimeDose => 'Dose unique';

  @override
  String get doseCalcTotalDose => 'Dose totale';

  @override
  String get doseCalcDosePerDay => 'Dose par jour';

  @override
  String get doseCalcSpreadDays => 'À répartir sur (jours)';

  @override
  String get doseCalcCorrMissing =>
      'Saisissez la valeur actuelle, la cible et le volume du bac pour calculer.';

  @override
  String get doseCalcCorrAtTarget =>
      'Déjà au niveau de la cible ou au-dessus — rien à doser.';

  @override
  String get doseCalcCorrSingle =>
      'Peut être donnée en une seule dose sans risque.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Monter de plus de $limit par jour est risqué — donnez plutôt la correction en $days doses quotidiennes.';
  }

  @override
  String get doseCalcLogDose => 'Enregistrer cette dose';

  @override
  String get doseCalcSalinityAdjust => 'Ajuster la cible à la salinité du bac';

  @override
  String get doseCalcSalinityAdjustHelp =>
      'Les valeurs cibles supposent une eau de mer à 35 ppt (1,026). Activez pour ramener la cible à la salinité mesurée de votre bac.';

  @override
  String doseCalcSalinityAdjustActive(
    Object salinity,
    Object adjusted,
    Object original,
  ) {
    return 'À $salinity : cible $adjusted au lieu de $original.';
  }

  @override
  String get doseCalcSalinityNone =>
      'Aucune mesure de salinité pour ce bac pour l\'instant.';

  @override
  String doseCalcSalinityStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Salinité mesurée il y a $days jours.',
      one: 'Salinité mesurée il y a $days jour.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcAdjustedTarget => 'Cible ajustée';

  @override
  String get correctionCta => 'Sous la plage — calculer une dose de correction';

  @override
  String get targetValueLabel => 'Cible de correction';

  @override
  String get targetValueHelp =>
      'Pré-remplit le mode correction du calculateur de dosage. Vide = le milieu de la plage sûre.';

  @override
  String get trendSection => 'Tendances';

  @override
  String get trendShowTitle => 'Afficher les tendances';

  @override
  String get trendShowSubtitle =>
      'Projette l\'évolution de chaque paramètre et le moment où il sortira de sa plage';

  @override
  String get trendWindow => 'Mesures utilisées';

  @override
  String trendWindowSubtitle(int days) {
    return 'Nombre de mesures récentes qui définissent la tendance ; élargi pour couvrir au moins $days jours si vous mesurez plus souvent';
  }

  @override
  String get trendTitle => 'Tendance récente';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/j';
  }

  @override
  String get trendFlat => 'Reste stable';

  @override
  String get trendWithinRange => 'Reste dans la plage à ce rythme';

  @override
  String trendAmberInDays(int days) {
    return 'Atteint la zone d\'attention dans ~$days j';
  }

  @override
  String trendRedInDays(int days) {
    return 'Atteint la zone critique dans ~$days j';
  }

  @override
  String trendChipAmber(int days) {
    return 'Attention ~$days j';
  }

  @override
  String trendChipRed(int days) {
    return 'Agir ~$days j';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Se rétablit — de retour dans la plage dans ~$days j';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Se rétablit ~$days j';
  }

  @override
  String get trendHorizon => 'Horizon d\'alerte';

  @override
  String get trendHorizonSubtitle =>
      'Ne signaler un paramètre que s\'il sort de sa plage dans ce délai';

  @override
  String trendHorizonDays(int days) {
    return '$days jours';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Attention';

  @override
  String get zoneActNow => 'Agir maintenant';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Poissons uniquement';

  @override
  String get setupSoft => 'Coraux mous';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Récif mixte';

  @override
  String get paramTemperature => 'Température';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Salinité';

  @override
  String get paramAlkalinity => 'Alcalinité';

  @override
  String get paramAlkalinityShort => 'KH';

  @override
  String get paramCalcium => 'Calcium (Ca)';

  @override
  String get paramMagnesium => 'Magnésium (Mg)';

  @override
  String get paramNitrate => 'Nitrate (NO₃)';

  @override
  String get paramPhosphate => 'Phosphate (PO₄)';

  @override
  String get paramAmmonia => 'Ammoniac (NH₃/₄)';

  @override
  String get paramNitrite => 'Nitrite (NO₂)';

  @override
  String get paramOrp => 'ORP';

  @override
  String get paramPotassium => 'Potassium (K)';

  @override
  String get paramStrontium => 'Strontium (Sr)';

  @override
  String get paramIodine => 'Iode (I)';

  @override
  String get paramIron => 'Fer (Fe)';

  @override
  String get paramSodium => 'Sodium (Na)';

  @override
  String get paramSulfur => 'Soufre (S)';

  @override
  String get paramBoron => 'Bore (B)';

  @override
  String get paramBromine => 'Brome (Br)';

  @override
  String get paramSilicon => 'Silicium (Si)';

  @override
  String get paramZinc => 'Zinc (Zn)';

  @override
  String get paramVanadium => 'Vanadium (V)';

  @override
  String get paramCopper => 'Cuivre (Cu)';

  @override
  String get paramNickel => 'Nickel (Ni)';

  @override
  String get paramManganese => 'Manganèse (Mn)';

  @override
  String get paramMolybdenum => 'Molybdène (Mo)';

  @override
  String get paramChromium => 'Chrome (Cr)';

  @override
  String get paramCobalt => 'Cobalt (Co)';

  @override
  String get paramLithium => 'Lithium (Li)';

  @override
  String get paramBarium => 'Baryum (Ba)';

  @override
  String get paramSelenium => 'Sélénium (Se)';

  @override
  String get paramAluminium => 'Aluminium (Al)';

  @override
  String get paramAntimony => 'Antimoine (Sb)';

  @override
  String get paramTin => 'Étain (Sn)';

  @override
  String get paramBeryllium => 'Béryllium (Be)';

  @override
  String get paramSilver => 'Argent (Ag)';

  @override
  String get paramTungsten => 'Tungstène (W)';

  @override
  String get paramLanthanum => 'Lanthane (La)';

  @override
  String get paramTitanium => 'Titane (Ti)';

  @override
  String get paramZirconium => 'Zirconium (Zr)';

  @override
  String get paramArsenic => 'Arsenic (As)';

  @override
  String get paramCadmium => 'Cadmium (Cd)';

  @override
  String get paramMercury => 'Mercure (Hg)';

  @override
  String get paramLead => 'Plomb (Pb)';

  @override
  String get microTitle => 'Oligo-éléments';

  @override
  String get microSectionMajor => 'Éléments majeurs';

  @override
  String get microSectionTrace => 'Éléments traces';

  @override
  String get microSectionContaminants => 'Contaminants';

  @override
  String get microNotMeasured => 'Non mesuré';

  @override
  String get microEmptyHint =>
      'Suivez les oligo-éléments à partir de tests domestiques ou d\'analyses ICP en laboratoire.';

  @override
  String get microAllOk => 'Tout est dans la plage';

  @override
  String microOutOfRangeN(int count) {
    return '$count hors plage';
  }

  @override
  String microLastMeasured(String date) {
    return 'Dernière mesure le $date';
  }

  @override
  String get microAddMeasurements => 'Ajouter des mesures';

  @override
  String get microAddTitle => 'Mesures d\'oligo-éléments';

  @override
  String get microChipHobby => 'Tests domestiques';

  @override
  String get microChipFullIcp => 'ICP complet';

  @override
  String get microReminderTooltip => 'Rappel de test';

  @override
  String get microReminderTitle => 'Rappel de test d\'oligo-éléments';

  @override
  String get microReminderHint =>
      'Ajoute une tâche d\'entretien vous rappelant de tester régulièrement les oligo-éléments.';

  @override
  String get microReminderCreated => 'Rappel ajouté au programme d\'entretien';

  @override
  String get microIcpTaskTitle => 'Test d\'oligo-éléments (ICP)';

  @override
  String get microToggleSubtitle =>
      'Afficher dans l\'onglet Mesures, avec rappels de tests. Masquer conserve vos mesures.';

  @override
  String get microViewFull => 'Liste complète';

  @override
  String get microViewNew => 'Nouvelle vue';

  @override
  String get microViewEdit => 'Modifier la vue';

  @override
  String get microViewManage => 'Gérer les vues';

  @override
  String get microConfigureTitle => 'Réglages des éléments';

  @override
  String get microViewNone =>
      'Pas encore de vue personnalisée. Une vue n\'affiche que les éléments analysés par votre laboratoire.';

  @override
  String get microViewNameHint => 'ex. Panel de mon labo';

  @override
  String get microViewNeedElement => 'Sélectionnez au moins un élément.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get microViewDeleteBody =>
      'Seule la vue est supprimée. Vos mesures sont conservées.';

  @override
  String get microHideUndetectable => 'Masquer les indétectables (zéro)';

  @override
  String get microAttentionOnly => 'Seulement les éléments à surveiller';

  @override
  String get microFilterAllHidden =>
      'Aucun élément ne correspond aux filtres actuels.';

  @override
  String get icpImportTitle => 'Importer une analyse ICP';

  @override
  String get icpImportFormatHint =>
      'Choisissez le format d\'export du fichier.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'Export CSV du portail du laboratoire Fauna Marin';

  @override
  String get icpImportFormatZimsHint =>
      'CSV universel de mesures (date, mesure, valeur, unité)';

  @override
  String get icpImportUnreadable => 'Le fichier n\'a pas pu être lu.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Ceci ne ressemble pas à un export $format.';
  }

  @override
  String get icpImportNoValues =>
      'Aucune valeur importable trouvée dans le fichier.';

  @override
  String get icpImportSampleDateHint =>
      'Prérempli avec la date d\'analyse du rapport. Remplacez-la par le jour du prélèvement de l\'eau.';

  @override
  String get icpImportSectionCore => 'Paramètres principaux';

  @override
  String icpImportSkipped(String list) {
    return 'Non importé (aucun paramètre correspondant) : $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count valeurs',
      one: 'Importer 1 valeur',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Échantillon déjà importé ?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Des mesures existantes mentionnent déjà l\'échantillon $id. L\'importer quand même à nouveau ?';
  }

  @override
  String get icpImportAnyway => 'Importer quand même';

  @override
  String icpImportNotePrefill(String id) {
    return 'Échantillon ICP $id';
  }

  @override
  String get unitFixedNote => 'Ce paramètre utilise toujours cette unité.';

  @override
  String get measurementImportTitle => 'Importer des mesures';

  @override
  String get measurementImportSourceHint =>
      'Choisissez l\'application ou l\'appareil d\'où provient le fichier.';

  @override
  String get measurementImportHannaHint =>
      'Historique CSV partagé depuis l\'app Hanna Lab';

  @override
  String get hannaImportTitle => 'Import Hanna Lab';

  @override
  String get hannaImportIntoTank => 'Importer dans l\'aquarium';

  @override
  String get hannaImportFirstFrom => 'Importer l\'historique depuis';

  @override
  String get hannaImportEverything => 'Tout';

  @override
  String get hannaImportFirstFromHint =>
      'Premier import dans cet aquarium : choisissez jusqu\'où remonter. Les mesures plus anciennes seront définitivement ignorées — utile si vous les avez déjà saisies à la main.';

  @override
  String hannaImportNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles mesures',
      one: '1 nouvelle mesure',
    );
    return '$_temp0';
  }

  @override
  String hannaImportAlreadyCount(int count) {
    return 'Déjà importées : $count';
  }

  @override
  String hannaImportBeforeCutoffCount(int count) {
    return 'Avant la date de début : $count';
  }

  @override
  String get hannaImportSkippedTitle => 'Non importées';

  @override
  String get hannaImportSkipRange => 'hors de la plage du test';

  @override
  String get hannaImportSkipUnknown => 'test non suivi par l\'application';

  @override
  String get hannaImportSkipValue => 'valeur illisible';

  @override
  String get hannaImportUpToDate =>
      'Tout le contenu de ce fichier est déjà importé.';

  @override
  String hannaImportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count mesures',
      one: 'Importer 1 mesure',
    );
    return '$_temp0';
  }

  @override
  String hannaImportDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures importées',
      one: '1 mesure importée',
    );
    return '$_temp0';
  }

  @override
  String get hannaImportUndone => 'Import annulé.';

  @override
  String get hannaImportWrongTankTitle => 'Autre aquarium ?';

  @override
  String hannaImportWrongTankBody(String location, String tank, String other) {
    return '« $location » a été importé la dernière fois dans $tank. Importer plutôt dans $other ?';
  }

  @override
  String get measurementImportSettingsTitle => 'Import de mesures';

  @override
  String get measurementImportSettingsSubtitle =>
      'État de l\'import Hanna Lab par aquarium';

  @override
  String hannaImportImportedUpTo(String date) {
    return 'Importé jusqu\'au $date';
  }

  @override
  String get hannaImportNeverImported => 'Pas encore importé';

  @override
  String get hannaImportChangeDate => 'Changer la date…';

  @override
  String get hannaImportReset => 'Réinitialiser';

  @override
  String get hannaImportResetTitle => 'Réinitialiser l\'import Hanna Lab ?';

  @override
  String get hannaImportResetBody =>
      'Le prochain import redemandera à partir de quelle date commencer. Les mesures déjà importées sont conservées ; l\'association à l\'aquarium est mémorisée.';

  @override
  String get hannaConnectTitle => 'Photomètre Hanna';

  @override
  String get hannaConnectSubtitle =>
      'Mesurer les paramètres en Bluetooth (HI97115)';

  @override
  String get hannaMeasureAction => 'Mesurer avec le photomètre Hanna';

  @override
  String get hannaScanTitle => 'Scanner l\'écran du checker';

  @override
  String get hannaScanSubtitle =>
      'Lire l\'écran d\'un checker de poche avec l\'appareil photo';

  @override
  String get hannaScanPickHint =>
      'Lit la valeur directement sur l\'écran du checker. Choisissez d\'abord votre modèle — le numéro HI est imprimé sur l\'avant du checker.';

  @override
  String get hannaScanPickTitle => 'Modèle de checker';

  @override
  String get hannaScanGuide => 'Placez l\'écran dans le cadre';

  @override
  String get hannaScanGlareHint =>
      'inclinez légèrement pour éviter les reflets';

  @override
  String get hannaScanZoomHint => 'pincez pour zoomer';

  @override
  String get hannaScanRescan => 'Scanner à nouveau';

  @override
  String get hannaScanNoCamera => 'Cet appareil n\'a pas d\'appareil photo.';

  @override
  String get hannaScanCameraDenied =>
      'L\'accès à l\'appareil photo a été refusé. Autorisez l\'accès à l\'appareil photo dans les réglages du système pour scanner l\'écran.';

  @override
  String get hannaScanCameraFailed =>
      'Impossible de démarrer l\'appareil photo.';

  @override
  String get hannaScanImpossibleNote =>
      'Cette valeur est impossible pour ce paramètre et ne peut pas être enregistrée. Scannez à nouveau ou vérifiez que le bon modèle est sélectionné.';

  @override
  String get hannaScanImplausibleNote =>
      'Cette valeur est hors de la plage plausible — vérifiez-la avant de l\'enregistrer.';

  @override
  String get experimentalBadge => 'Expérimental';

  @override
  String get experimentalSection => 'Expérimental';

  @override
  String get experimentalToggleTitle => 'Fonctions expérimentales';

  @override
  String get experimentalToggleSubtitle =>
      'Essayez des fonctions encore en test : connexion Bluetooth du checker Hanna et scan de l\'écran';

  @override
  String get hannaScanFabTitle => 'Bouton de scan caméra';

  @override
  String get hannaScanFabSubtitle =>
      'Afficher un bouton de scan rapide au-dessus de « Ajouter une mesure »';

  @override
  String get hannaExperimentalNote =>
      'Fonction expérimentale : elle repose sur un protocole Bluetooth non officiel et peut cesser de fonctionner après une mise à jour du firmware de l\'appareil.';

  @override
  String get hannaMeasureOnlyNote =>
      'Seules les mesures sont prises en charge. Pour modifier les réglages de l\'appareil ou mettre à jour son firmware, utilisez l\'application Hanna Lab du fabricant.';

  @override
  String get hannaScanning => 'Recherche de l\'appareil…';

  @override
  String get hannaScanHint =>
      'Allumez l\'appareil et gardez-le près du téléphone.';

  @override
  String get hannaReadingSetup => 'Connecté — lecture de la configuration…';

  @override
  String get hannaErrUnsupported =>
      'Le Bluetooth LE n\'est pas disponible sur cet appareil.';

  @override
  String get hannaErrBluetoothOff =>
      'Le Bluetooth est désactivé. Activez-le et réessayez.';

  @override
  String get hannaErrNotFound =>
      'Aucun appareil trouvé. Vérifiez qu\'il est allumé et à portée.';

  @override
  String get hannaErrConnectionFailed =>
      'Impossible de se connecter à l\'appareil.';

  @override
  String get hannaErrConnectionLost =>
      'La connexion à l\'appareil a été perdue.';

  @override
  String get hannaTryAgain => 'Réessayer';

  @override
  String hannaMeterStatus(int percent, String firmware) {
    return 'Batterie $percent % · firmware $firmware';
  }

  @override
  String get hannaAquarium => 'Aquarium';

  @override
  String get hannaSetsTitle => 'Ensembles de tests';

  @override
  String hannaSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count méthodes',
      one: '1 méthode',
    );
    return '$_temp0';
  }

  @override
  String get hannaSaveSet => 'Enregistrer la sélection comme ensemble';

  @override
  String get hannaSetName => 'Nom de l\'ensemble';

  @override
  String get hannaSetUpdate => 'Mettre à jour depuis la sélection actuelle';

  @override
  String get hannaAllMethods => 'Toutes les méthodes';

  @override
  String hannaMethodLowRange(String name) {
    return '$name (gamme basse)';
  }

  @override
  String get hannaStartMeasurements => 'Démarrer les mesures';

  @override
  String get hannaFollowMeter => 'Suivez les instructions sur l\'appareil.';

  @override
  String hannaStepN(int step) {
    return 'étape $step';
  }

  @override
  String get hannaStatusSkipped => 'Ignorée';

  @override
  String get hannaSkip => 'Ignorer';

  @override
  String get hannaFinishNow => 'Terminer';

  @override
  String get hannaTimerHint => 'Minuteur de réaction du réactif';

  @override
  String get hannaTimerStop => 'Arrêter le minuteur';

  @override
  String hannaTimerSec(int n) {
    return '$n s';
  }

  @override
  String hannaTimerMin(int n) {
    return '$n min';
  }

  @override
  String get hannaResultsTitle => 'Résultats des mesures';

  @override
  String get hannaResultsDisconnected =>
      'La connexion a été perdue — les résultats déjà obtenus sont conservés.';

  @override
  String get hannaNoResults => 'Aucune mesure n\'a été enregistrée.';

  @override
  String get hannaSaveTo => 'Enregistrer dans l\'aquarium';

  @override
  String hannaSaveButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enregistrer $count mesures',
      one: 'Enregistrer 1 mesure',
    );
    return '$_temp0';
  }

  @override
  String hannaSavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures enregistrées',
      one: '1 mesure enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get hannaDiscardTitle => 'Abandonner les mesures ?';

  @override
  String get hannaDiscardBody =>
      'Les valeurs obtenues ne sont pas enregistrées et seront perdues.';

  @override
  String get hannaDiscard => 'Abandonner';

  @override
  String get helpTemperature =>
      'Température de l\'eau. La stabilité compte plus que la valeur exacte.';

  @override
  String get helpSalinity => 'Densité. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Dureté carbonatée. Maintenez-la stable — évitez les variations.';

  @override
  String get helpNitrate =>
      'Un nutriment. Les coraux en ont un peu besoin ; l\'excès nourrit les algues.';

  @override
  String get helpAmmonia =>
      'Toxique. Devrait être quasiment nul dans un bac rodé.';

  @override
  String get healthTitle => 'Santé du bac';

  @override
  String get healthGradeExcellent => 'Excellente';

  @override
  String get healthGradeGood => 'Bonne';

  @override
  String get healthGradeCaution => 'Vigilance';

  @override
  String get healthGradeCritical => 'Critique';

  @override
  String get healthGradeUnknown => 'Pas de données';

  @override
  String get healthAllOnTarget => 'Tous les paramètres dans la cible';

  @override
  String healthParamsToWatch(int count) {
    return '$count à surveiller';
  }

  @override
  String get healthSectionAttention => 'À surveiller';

  @override
  String get healthSectionGood => 'Tout va bien';

  @override
  String get healthSectionStale => 'Pas testé récemment';

  @override
  String healthNotTestedDays(int count) {
    return 'Pas testé depuis $count j';
  }

  @override
  String get healthNeverTested => 'Jamais testé';

  @override
  String get healthNoReadingsYet => 'Pas encore de mesures';

  @override
  String healthScoreOf(int score) {
    return '$score sur 100';
  }

  @override
  String get stabilityTitle => 'Stabilité';

  @override
  String get stabilityScoreProName => 'Score de stabilité';

  @override
  String get stabilityGradeRockSolid => 'Très stable';

  @override
  String get stabilityGradeSteady => 'Stable';

  @override
  String get stabilityGradeVariable => 'Variable';

  @override
  String get stabilityGradeUnstable => 'Instable';

  @override
  String get stabilityGradeUnknown => 'Pas de données';

  @override
  String stabilityIntro(int days) {
    return 'Régularité de chaque paramètre au cours des $days derniers jours.';
  }

  @override
  String get stabilitySectionVariable => 'Les plus variables';

  @override
  String get stabilitySectionSteady => 'Restent stables';

  @override
  String get stabilitySectionInsufficient => 'Données insuffisantes';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tests au cours des $days derniers jours',
      one: '1 test au cours des $days derniers jours',
      zero: 'Aucun test au cours des $days derniers jours',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Fenêtre de stabilité';

  @override
  String get stabilityWindowSubtitle =>
      'Période prise en compte par le score de stabilité';

  @override
  String get insightsTitle => 'Observations';

  @override
  String get insightsProName => 'Observations intelligentes';

  @override
  String get insightsIntro =>
      'Ce que vos mesures récentes suggèrent de surveiller.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count autres',
      one: '+1 autre',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param est sous sa plage cible';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param est bas et continue de baisser';
  }

  @override
  String insightHigh(Object param) {
    return '$param est au-dessus de sa plage cible';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param est haut et continue de monter';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param est hors de sa plage cible';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param baisse — pourrait sortir de sa plage dans ~$days j';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param monte — pourrait sortir de sa plage dans ~$days j';
  }

  @override
  String insightRecovering(Object param) {
    return '$param revient vers sa plage';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param se rétablit — de retour dans la plage dans ~$days j';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param : pas testé depuis $days j';
  }

  @override
  String get aiSummaryAction => 'Demandez à votre IA';

  @override
  String get aiSummaryPrivacyNote =>
      'Ceci est un prompt prêt à l\'emploi avec les données de votre bac. Collez-le dans ChatGPT, Claude, Gemini ou tout autre outil d\'IA — tout est préparé sur votre appareil, rien n\'est envoyé nulle part.';

  @override
  String get aiSummaryPromptPreview => 'Aperçu du prompt';

  @override
  String get aiSummaryCopyPrompt => 'Copier le prompt';

  @override
  String aiSummaryWeeksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get aiSummaryCopied => 'Copié — collez-le dans votre chat IA.';

  @override
  String get aiSummaryEmpty => 'Pas encore de mesures — rien à résumer.';

  @override
  String get aiSummaryInsightsFooter =>
      'Envie d\'une analyse plus poussée ? Demandez à votre IA';

  @override
  String aiSummaryPreamble(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other:
          'Je possède un aquarium récifal d\'eau de mer et je le suis avec une application. Voici les données de mon bac des $weeks dernières semaines. Analyse-les, signale les risques ou tendances à traiter et suggère ce qu\'il faut vérifier ou ajuster.',
      one:
          'Je possède un aquarium récifal d\'eau de mer et je le suis avec une application. Voici les données de mon bac de la dernière semaine. Analyse-les, signale les risques ou tendances à traiter et suggère ce qu\'il faut vérifier ou ajuster.',
    );
    return '$_temp0';
  }

  @override
  String aiSummaryDocTitle(Object tank) {
    return '$tank — synthèse d\'aquarium d\'eau de mer';
  }

  @override
  String aiSummaryRunningSince(Object date) {
    return 'en service depuis le $date';
  }

  @override
  String aiSummaryExportedLine(Object date) {
    return 'Exporté le $date.';
  }

  @override
  String get aiSummaryStatusHeading => 'État';

  @override
  String aiSummaryHealthLine(int score, Object grade) {
    return 'Score de santé : $score sur 100 ($grade)';
  }

  @override
  String aiSummaryStabilityLine(int score, Object grade, int days) {
    return 'Score de stabilité : $score sur 100 ($grade) sur les $days derniers jours';
  }

  @override
  String get aiSummaryObservationsLead =>
      'Observations de l\'application (basées sur des règles) :';

  @override
  String get aiSummaryParamsHeading => 'Paramètres';

  @override
  String aiSummaryTestedOn(Object date) {
    return 'dernier test le $date';
  }

  @override
  String aiSummaryTargetRange(Object range) {
    return 'Cible $range';
  }

  @override
  String aiSummaryAcceptableRange(Object range) {
    return 'acceptable $range';
  }

  @override
  String get aiSummaryColDate => 'Date';

  @override
  String get aiSummaryColValue => 'Valeur';

  @override
  String get aiSummaryColNote => 'Note';

  @override
  String get aiSummaryColElement => 'Élément';

  @override
  String get aiSummaryColStatus => 'État';

  @override
  String aiSummaryShowingTests(int shown, int total) {
    return 'Affichage des $shown tests les plus récents sur $total.';
  }

  @override
  String get aiSummaryDosingHeading => 'Plan de dosage';

  @override
  String aiSummaryDailyEquivalent(Object amount) {
    return '≈$amount par jour';
  }

  @override
  String aiSummarySinceDate(Object date) {
    return 'depuis le $date';
  }

  @override
  String get aiSummaryOneOff => 'dose ponctuelle';

  @override
  String get aiSummaryActionsHeading => 'Entretien sur cette période';

  @override
  String get aiSummaryMicroHeading =>
      'Oligo-éléments (dernières valeurs mesurées)';

  @override
  String get dashboardSection => 'Tableau de bord';

  @override
  String get dashboardLayoutTitle => 'Disposition du tableau de bord';

  @override
  String get dashboardLayoutSubtitle =>
      'Comment les cartes sont organisées dans l\'onglet Mesures';

  @override
  String get dashboardLayoutGrouped => 'Groupé';

  @override
  String get dashboardLayoutFlat => 'Plat';

  @override
  String get healthDisplayTitle => 'Santé du bac';

  @override
  String get healthDisplaySubtitle => 'Où afficher le résumé de santé';

  @override
  String get healthDisplayBoth => 'Badge et carte';

  @override
  String get healthDisplayBadge => 'Badge seulement';

  @override
  String get healthDisplayOff => 'Masqué';

  @override
  String get routeNotFoundTitle => 'Page introuvable';

  @override
  String get routeNotFoundBody =>
      'Ce lien ne mène nulle part dans l\'application.';

  @override
  String get routeNotFoundGoHome => 'Aller à l\'écran d\'accueil';

  @override
  String get notifChannelTesting => 'Rappels de tests';

  @override
  String get notifChannelDosing => 'Rappels de dosage';

  @override
  String get notifChannelMaintenance => 'Rappels d\'entretien';

  @override
  String get notifTestingTitle => 'C\'est l\'heure des tests';

  @override
  String get notifDosingTitle => 'Dosage à faire';

  @override
  String get notifMaintenanceTitle => 'Entretien à faire';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Rappels';

  @override
  String get remindersSubtitle =>
      'Notifications de tests, de dosage et d\'entretien';

  @override
  String get remindersTestingSubtitle =>
      'Quand le test d\'un paramètre est à faire';

  @override
  String get remindersDosingSubtitle =>
      'À l\'heure de dosage de chaque supplément';

  @override
  String get remindersMaintenanceSubtitle =>
      'Quand un entretien planifié est à faire';

  @override
  String get reminderTimeTitle => 'Heure des rappels';

  @override
  String get reminderTimeSubtitle =>
      'Heure d\'envoi des rappels de tests et d\'entretien';

  @override
  String get remindersPermissionDenied =>
      'Les notifications sont bloquées dans les réglages du système ; les rappels ne peuvent pas s\'afficher.';

  @override
  String get remindToTest => 'Rappeler de tester';

  @override
  String get cadenceOff => 'Désactivé';

  @override
  String daysShortN(int count) {
    return '$count j';
  }

  @override
  String get cadenceCustom => 'Personnalisé';

  @override
  String get customDaysLabel => 'Jours';

  @override
  String get remindMe => 'Me rappeler';

  @override
  String get remindMeNeedsTime =>
      'Définissez une heure de dosage pour activer les rappels';

  @override
  String get maintenanceSchedule => 'Programme d\'entretien';

  @override
  String get addMaintenanceTask => 'Ajouter une tâche';

  @override
  String get editMaintenanceTask => 'Modifier la tâche';

  @override
  String get taskTypeLabel => 'Type';

  @override
  String get customTask => 'Tâche personnalisée';

  @override
  String get taskTitleLabel => 'Titre';

  @override
  String get taskTitleRequired => 'Saisissez un titre';

  @override
  String get repeatLabel => 'Répétition';

  @override
  String get oneOff => 'Ponctuelle';

  @override
  String get dueDateLabel => 'Échéance';

  @override
  String get dueDateRequired => 'Choisissez une échéance';

  @override
  String get dueToday => 'À faire aujourd\'hui';

  @override
  String dueInDaysN(int count) {
    return 'Dans $count j';
  }

  @override
  String overdueDaysN(int count) {
    return 'En retard de $count j';
  }

  @override
  String get markDone => 'Marquer comme fait';

  @override
  String get taskMarkedDone => 'Marqué comme fait';

  @override
  String get taskDeleted => 'Tâche supprimée';

  @override
  String get scheduleEmptyBody =>
      'Pas encore de tâche d\'entretien. Planifiez des changements d\'eau ou des tâches personnalisées pour obtenir des échéances et des rappels.';

  @override
  String get repeatModeLabel => 'Répétition';

  @override
  String get repeatEveryDays => 'Tous les X jours';

  @override
  String get repeatEveryWeeks => 'Toutes les X semaines';

  @override
  String get repeatEveryMonths => 'Tous les X mois';

  @override
  String get repeatOnWeekdays => 'Jours de la semaine';

  @override
  String get repeatOnMonthDay => 'Jour du mois';

  @override
  String get weeksLabel => 'Semaines';

  @override
  String get monthsLabel => 'Mois';

  @override
  String get monthDayLabel => 'Jour du mois (1–31)';

  @override
  String get invalidInterval => 'Saisissez un nombre entier (au moins 1).';

  @override
  String get invalidMonthDay => 'Saisissez un jour entre 1 et 31.';

  @override
  String get weekdaysRequired => 'Choisissez au moins un jour.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Toutes les $n semaines',
      one: 'Chaque semaine',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Tous les $n mois',
      one: 'Chaque mois',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'Chaque $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Le $n de chaque mois';
  }

  @override
  String get roUnitTitle => 'Osmoseur';

  @override
  String get roStageSediment => 'Filtre à sédiments';

  @override
  String get roStageCarbonBlock => 'Bloc de charbon actif';

  @override
  String get roStageMembrane => 'Membrane osmotique';

  @override
  String get roStageDiResin => 'Résine déionisante (DI)';

  @override
  String get roCustomStage => 'Élément personnalisé';

  @override
  String get roAddStage => 'Ajouter un élément';

  @override
  String get roEditStage => 'Modifier l\'élément';

  @override
  String get roLifespanLabel => 'Remplacer tous les';

  @override
  String get roUnitDays => 'jours';

  @override
  String get roUnitWeeks => 'semaines';

  @override
  String get roUnitMonths => 'mois';

  @override
  String get roPartOfUnit => 'Présent sur mon osmoseur';

  @override
  String get roPartOfUnitHint =>
      'Désactivez si votre osmoseur n\'a pas cet étage';

  @override
  String get roHiddenStages => 'Absent de mon osmoseur';

  @override
  String get roMarkReplaced => 'Remplacé';

  @override
  String get roReplacedRecorded => 'Remplacement enregistré';

  @override
  String roLastReplaced(String date) {
    return 'Remplacé le $date';
  }

  @override
  String get roNoReplacementYet =>
      'Aucun remplacement enregistré pour l\'instant';

  @override
  String get roDeleteStageTitle => 'Supprimer l\'élément ?';

  @override
  String get roDeleteStageBody =>
      'L\'élément et l\'historique de ses remplacements seront supprimés. Cette action est irréversible.';

  @override
  String get roEmptyBody =>
      'Aucun élément. Ajoutez les filtres de votre osmoseur avec +.';

  @override
  String get roSetupPrompt =>
      'Suivez le remplacement des filtres et de la membrane';

  @override
  String get roUnitToggleSubtitle =>
      'Afficher dans l\'onglet Actions, avec rappels de remplacement des filtres';

  @override
  String get roAllOk => 'Tous les éléments sont OK';

  @override
  String get notifRoTitle => 'Remplacer les filtres de l\'osmoseur';
}
