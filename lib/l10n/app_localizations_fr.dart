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
  String get tourTankTitle => 'Tes aquariums';

  @override
  String get tourTankDesc =>
      'Touche ici pour passer d\'un aquarium à l\'autre ou en ajouter un nouveau.';

  @override
  String get tourCompareTitle => 'Vue comparative';

  @override
  String get tourCompareDesc =>
      'Bascule entre les cartes de paramètres et les graphiques comparatifs superposés.';

  @override
  String get tourParamsTitle => 'Gérer les paramètres';

  @override
  String get tourParamsDesc =>
      'Choisis les paramètres d\'eau à suivre et définis leurs plages cibles.';

  @override
  String get tourDosingHistoryTitle => 'Historique de dosage';

  @override
  String get tourDosingHistoryDesc =>
      'Consulte toutes les périodes de dosage passées et actuelles, et supprime un enregistrement saisi par erreur.';

  @override
  String get tourDoseCalcTitle => 'Calculateur de dose';

  @override
  String get tourDoseCalcDesc =>
      'Dans l\'onglet Dosage, ouvre le calculateur pour estimer la dose quotidienne qui maintient un élément stable.';

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
  String get gridView => 'Vue en grille';

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
      'Crée ton premier aquarium pour commencer à suivre les paramètres de l\'eau.';

  @override
  String get welcomeExperimentalSubtitle =>
      'Active des fonctionnalités encore en développement et susceptibles de changer. Ce choix peut être modifié à tout moment dans les paramètres.';

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
  String get enterAName => 'Saisis un nom';

  @override
  String get setupType => 'Type de bac';

  @override
  String get presetSeedNote =>
      'Les paramètres par défaut et les limites de zones seront configurés pour ce type de bac. Tu pourras les ajuster à tout moment.';

  @override
  String get fishOnlyPresetNote =>
      'Le préréglage Fish only ne définit aucune limite pour l\'alcalinité, le calcium, le magnésium ou les phosphates – si tu suis ces paramètres, ils n\'afficheront pas de couleurs de zone tant que tu n\'auras pas défini tes propres limites.';

  @override
  String get volumeOptional => 'Volume (facultatif)';

  @override
  String get vendorOptional => 'Marque (facultative)';

  @override
  String get modelOptional => 'Modèle (facultatif)';

  @override
  String get notesOptional => 'Notes (facultatives)';

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
  String get parameters => 'Paramètres';

  @override
  String get noActiveAquarium => 'Aucun aquarium actif.';

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
  String get untrackParameter => 'Ne plus suivre';

  @override
  String get parameterUntracked =>
      'Paramètre retiré du suivi – les mesures sont conservées';

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
    return 'Valeurs en $unit. Laisse un champ vide pour « aucune limite de ce côté ».';
  }

  @override
  String get enterANumber => 'Saisis un nombre';

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
  String get noteOptional => 'Note (facultative)';

  @override
  String get saveReadings => 'Enregistrer les mesures';

  @override
  String invalidNumberFor(Object name) {
    return 'Nombre invalide pour $name';
  }

  @override
  String get invalidVolume => 'Saisis un volume positif valide.';

  @override
  String get invalidPositiveNumber => 'Saisis un nombre positif.';

  @override
  String get invalidIntervalDays =>
      'Saisis un nombre entier de jours (au moins 1).';

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
      'La valeur suivante sort de la plage habituelle. Vérifie qu\'il ne s\'agit pas d\'une faute de frappe avant d\'enregistrer.';

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
  String implausibleRailLine(Object name, Object value) {
    return '$name : $value – ne mesure rien du tout (sonde débranchée ?)';
  }

  @override
  String get implausibleIntroDevices =>
      'Un appareil connecté rapporte des valeurs qui semblent fausses. Vérifie la sonde avant d\'enregistrer.';

  @override
  String get implausibleSkip => 'Ignorer';

  @override
  String get saveAnyway => 'Enregistrer quand même';

  @override
  String get enterAtLeastOneValue => 'Saisis au moins une valeur.';

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
  String get testSetNeedParam => 'Sélectionne au moins un paramètre.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteTestSetBody =>
      'Le jeu de tests sera supprimé. Tes mesures sont conservées.';

  @override
  String get testSetEmptyHint =>
      'Ce jeu de tests ne contient aucun paramètre actif. Modifie-le ou passe à Tous.';

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
      'Pas encore de jeu de tests. Un jeu de tests n\'enregistre que les paramètres que tu testes ensemble.';

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
  String get recordFirstReading => 'Enregistrer ta première mesure';

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
      'Un test d\'ammoniac mesure l\'ammoniac total, mais seule la fraction non ionisée (NH₃) est toxique. Sa proportion augmente avec le pH et la température : dans un aquarium récifal, une plus grande part passe donc sous la forme toxique que dans un bac à pH plus bas. Cette estimation répartit ta dernière mesure d\'ammoniac total d\'après les dernières valeurs de pH, de température et de salinité.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Ammoniac libre toxique : $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return '$percent % de tes $total ppm d\'ammoniac total sont sous la forme toxique NH₃.';
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
  String get freeAmmoniaNeedsAmmonia => 'Active l\'ammoniac pour l\'afficher.';

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
  String get ratioCaAlkLabel => 'Ca : KH';

  @override
  String get ratioCaAlkTitle => 'Rapport Ca : KH';

  @override
  String get ratioMgAlkLabel => 'Mg : KH';

  @override
  String get ratioMgAlkTitle => 'Rapport Mg : KH';

  @override
  String get ratioNoData =>
      'Enregistre les deux paramètres pour voir leur rapport.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Les limites de zones utilisent $metric, la valeur affichée sur la carte.';
  }

  @override
  String get waterChanges => 'Changements d\'eau';

  @override
  String get recordWaterChange => 'Enregistrer un changement d\'eau';

  @override
  String get amountLitersOptional => 'Quantité (facultative)';

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
  String get addSupplement => 'Ajouter un additif';

  @override
  String get noDosing => 'Pas encore d\'additif.';

  @override
  String get noDosingHint =>
      'Ajoute les additifs que tu doses dans ce bac — marque, produit et, si tu le souhaites, dose et programme.';

  @override
  String get dosingNoDosage => 'Aucune dose définie';

  @override
  String get supplementStopped => 'Additif arrêté';

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
  String get dosingNew => 'Ajouter un additif';

  @override
  String get dosingEdit => 'Modifier l\'additif';

  @override
  String get dosingVendor => 'Marque';

  @override
  String get dosingVendorName => 'Nom de la marque';

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
  String get dosingTimeOptional => 'Heure (facultative)';

  @override
  String get unitsSection => 'Unités';

  @override
  String get toolsSection => 'Outils';

  @override
  String get aboutSection => 'À propos';

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
  String get salinityCalculatorSubtitle =>
      'Conversion ppt ⇄ SG ⇄ masse volumique';

  @override
  String get waterChangePlannerTitle => 'Planificateur de changement d’eau';

  @override
  String get waterChangePlannerSubtitle =>
      'Projeter les changements ponctuels ou automatiques';

  @override
  String get waterChangePlannerIntro =>
      'Vois comment un ou plusieurs changements d’eau peuvent modifier un paramètre mesuré à partir du volume et de la dernière mesure de cet aquarium.';

  @override
  String get waterChangePlannerBatch => 'Changements ponctuels';

  @override
  String get waterChangePlannerAutomatic => 'Échange automatique';

  @override
  String get waterChangePlannerBatchHelp =>
      'L’eau est retirée, remplacée, puis entièrement mélangée avant le changement suivant.';

  @override
  String get waterChangePlannerAutomaticHelp =>
      'L’ancienne et la nouvelle eau circulent en même temps dans un aquarium mélangé en continu.';

  @override
  String get waterChangePlannerNoTank =>
      'Ajoute un aquarium avant de planifier un changement d’eau.';

  @override
  String get waterChangePlannerNoParameters =>
      'Suis un paramètre dissous avant d’utiliser ce planificateur.';

  @override
  String get waterChangePlannerParameter => 'Paramètre dissous';

  @override
  String waterChangePlannerTankVolume(Object unit) {
    return 'Volume d’eau du système ($unit)';
  }

  @override
  String waterChangePlannerChangeVolume(Object unit) {
    return 'Eau changée à chaque fois ($unit)';
  }

  @override
  String waterChangePlannerCurrent(Object unit) {
    return 'Valeur actuelle ($unit)';
  }

  @override
  String waterChangePlannerReplacement(Object unit) {
    return 'Valeur de l’eau neuve ($unit)';
  }

  @override
  String waterChangePlannerTarget(Object unit) {
    return 'Valeur cible ($unit, facultatif)';
  }

  @override
  String get waterChangePlannerPlannedChanges => 'Changements à projeter';

  @override
  String get waterChangePlannerCalculate => 'Calculer la projection';

  @override
  String get waterChangePlannerNonNegativeError =>
      'Saisis zéro ou un nombre positif.';

  @override
  String get waterChangePlannerCountError =>
      'Saisis un nombre entier de 1 à 10 000.';

  @override
  String get waterChangePlannerVolumeError =>
      'Chaque changement doit rester inférieur ou égal au volume d’eau du système.';

  @override
  String waterChangePlannerReadingDate(Object date) {
    return 'Dernière mesure du $date';
  }

  @override
  String waterChangePlannerReadingStale(Object date) {
    return 'La dernière mesure du $date date de plus de 30 jours — modifie-la ou mesure à nouveau.';
  }

  @override
  String get waterChangePlannerProjection => 'Projection';

  @override
  String get waterChangePlannerAfterOne => 'Après un changement';

  @override
  String waterChangePlannerAfterPlanned(int count) {
    return 'Après $count changements';
  }

  @override
  String get waterChangePlannerEffectiveChanged => 'Changement cumulé effectif';

  @override
  String get waterChangePlannerTargetSchedule => 'Plan jusqu’à la cible';

  @override
  String get waterChangePlannerTargetOptional =>
      'Saisis une cible pour calculer un plan.';

  @override
  String get waterChangePlannerAlreadyAtTarget =>
      'La valeur actuelle correspond déjà à la cible.';

  @override
  String get waterChangePlannerTargetUnreachable =>
      'Cette eau neuve ne permet pas d’atteindre la cible. Sa valeur doit dépasser la cible dans le sens souhaité.';

  @override
  String waterChangePlannerTargetSummary(
    int count,
    Object total,
    Object effective,
  ) {
    return '$count changements · $total au total · $effective effectif';
  }

  @override
  String waterChangePlannerScheduleOmitted(int count) {
    return '… $count changements intermédiaires …';
  }

  @override
  String waterChangePlannerStep(int number) {
    return 'Changement $number';
  }

  @override
  String get waterChangePlannerAssumption =>
      'Estimation uniquement : elle suppose un volume d’eau constant, un mélange complet et aucune nouvelle production, consommation, dose, précipitation ou autre variation entre les changements d’eau. Mesure après chaque changement ; le résultat calculé n’est pas garanti.';

  @override
  String get reefUnitConverter => 'Convertisseur d’unités récifales';

  @override
  String get reefUnitConverterSubtitle => 'Alcalinité, température et volume';

  @override
  String get reefUnitConverterIntro =>
      'Convertis les unités récifales courantes. Saisis une valeur dans n’importe quel champ pour mettre automatiquement à jour toutes les unités équivalentes.';

  @override
  String get converterSourceUnit => 'Unité de départ';

  @override
  String get converterValue => 'Valeur';

  @override
  String get converterEquivalent => 'Équivalent';

  @override
  String get alkalinity => 'Alcalinité';

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
      'TOUTES les données de tes aquariums — aquariums, paramètres et mesures — seront remplacées par le contenu du fichier de sauvegarde. Tes réglages sur cet appareil (langue, unités et préférences) sont conservés. Cette action est irréversible.';

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
      'Certaines données n\'ont pas pu être chargées. Si cela se reproduit, redémarre l\'application ou restaure une sauvegarde.';

  @override
  String get autoBackupTitle => 'Sauvegarde automatique';

  @override
  String get autoBackupSubtitle =>
      'Conserver des copies récentes de tes données sur cet appareil';

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
      'Une sauvegarde est enregistrée automatiquement pendant que tu utilises l\'application.';

  @override
  String get share => 'Partager';

  @override
  String get backupDeleteConfirmTitle => 'Supprimer la sauvegarde ?';

  @override
  String get backupDeleteConfirmBody =>
      'Ce fichier de sauvegarde sera définitivement supprimé de ton appareil.';

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
      'Sauvegarder automatiquement sur ton Google Drive';

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
    return 'Les sauvegardes sont envoyées dans le dossier « ReefTracker » du Google Drive de $email. Tu peux les consulter et les télécharger sur drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Déconnecter';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Drive déconnecté. Les sauvegardes déjà envoyées restent sur ton Drive.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Échec de l\'envoi vers Google Drive le $when';
  }

  @override
  String get syncDeviceNameTitle => 'Nom de l\'appareil';

  @override
  String get syncDeviceNameBody =>
      'Affiché avec les sauvegardes envoyées depuis cet appareil, pour distinguer tes appareils.';

  @override
  String get syncDeviceNameHint => 'p. ex. Mon téléphone';

  @override
  String get syncDeviceNameAction => 'Nom de l\'appareil…';

  @override
  String get syncRestoreTitle => 'Sauvegarde plus récente trouvée';

  @override
  String syncRestoreBody(String device, String when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans ton Google Drive. La restaurer sur cet appareil ? Les réglages de cet appareil sont conservés.';
  }

  @override
  String syncRestoreDivergedBody(String device, String when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans ton Google Drive, mais cet appareil contient aussi des modifications qui n\'ont jamais été envoyées. La restauration remplace les données de cet appareil par la sauvegarde — une copie de sécurité locale est d\'abord enregistrée.';
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
  String get cloudSyncFeatureName => 'Sauvegarde cloud';

  @override
  String get syncIcloudTitle => 'Sauvegarde iCloud';

  @override
  String get syncIcloudSubtitle =>
      'Sauvegarder automatiquement sur ton iCloud Drive';

  @override
  String get syncIcloudDialogBody =>
      'Les sauvegardes sont envoyées dans le dossier « ReefTracker » de ton iCloud Drive. Tu peux les consulter dans l\'app Fichiers.';

  @override
  String get syncIcloudDisable => 'Désactiver';

  @override
  String get syncIcloudEnabledSnack =>
      'Les sauvegardes seront synchronisées sur ton iCloud Drive';

  @override
  String get syncIcloudDisabledSnack =>
      'Sauvegarde iCloud désactivée. Les sauvegardes déjà envoyées restent sur ton iCloud Drive.';

  @override
  String get syncIcloudUnavailable =>
      'iCloud n\'est pas disponible. Connecte-toi à iCloud et active iCloud Drive pour ReefTracker dans les Réglages de l\'appareil.';

  @override
  String syncIcloudLastFailed(Object when) {
    return 'Échec de l\'envoi vers iCloud le $when';
  }

  @override
  String get backupsIcloudSection => 'iCloud';

  @override
  String get backupsIcloudEmpty =>
      'Aucune sauvegarde sur iCloud pour l\'instant';

  @override
  String get backupsIcloudLoadFailed =>
      'Impossible de charger les sauvegardes depuis iCloud';

  @override
  String get welcomeRestoreIcloud => 'Restaurer depuis iCloud';

  @override
  String syncRestoreBodyIcloud(Object device, Object when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans ton iCloud Drive. La restaurer sur cet appareil ? Les réglages de cet appareil sont conservés.';
  }

  @override
  String syncRestoreDivergedBodyIcloud(Object device, Object when) {
    return 'Une sauvegarde plus récente de « $device » ($when) se trouve dans ton iCloud Drive, mais cet appareil contient aussi des modifications qui n\'ont jamais été envoyées. La restauration remplace les données de cet appareil par la sauvegarde — une copie de sécurité locale est d\'abord enregistrée.';
  }

  @override
  String get backupsDeviceNameNudge => 'Définir un nom d\'appareil';

  @override
  String get backupsDeviceNameNudgeHint =>
      'Identifie les sauvegardes envoyées depuis cet appareil';

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
  String get shareDiagnostics => 'Partager le diagnostic';

  @override
  String get shareDiagnosticsSubtitle =>
      'Envoyer le journal d\'erreurs de l\'application au support';

  @override
  String get diagnosticsEmpty => 'Aucune erreur n\'a été enregistrée';

  @override
  String get diagnosticsShareFailed => 'Impossible de partager le diagnostic';

  @override
  String get updateAvailableSnack =>
      'Une nouvelle version de ReefTracker est disponible.';

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String get updateReadySnack => 'Mise à jour téléchargée.';

  @override
  String get updateRestartAction => 'Redémarrer';

  @override
  String get editionLabel => 'Édition';

  @override
  String get editionFounder => 'Édition Fondateur';

  @override
  String get editionStandard => 'Standard';

  @override
  String get founderInfoBody =>
      'Tu utilises ReefTracker depuis ses débuts. En remerciement, toutes les fonctionnalités disponibles aujourd\'hui restent gratuites pour toi — pour toujours.';

  @override
  String get standardInfoBody =>
      'Tu utilises l\'édition standard de ReefTracker. Tout ce que tu as déjà enregistré reste à toi ; ReefTracker Pro débloque les fonctionnalités avancées.';

  @override
  String get editionUpgrade => 'Débloquer Pro';

  @override
  String get editionPro => 'Pro';

  @override
  String get editionFounderPro => 'Édition fondateur + Pro';

  @override
  String get proInfoBody =>
      'Merci ! Ton déblocage Pro est actif sur cet appareil. Toutes les fonctionnalités Pro sont à toi.';

  @override
  String get paywallTitle => 'ReefTracker Pro';

  @override
  String get paywallIntro =>
      'Un seul achat, sans abonnement ni compte — le déblocage reste lié au compte de la boutique de cet appareil.';

  @override
  String paywallBuy(Object price) {
    return 'Débloquer Pro — $price';
  }

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallWorking => 'Communication avec la boutique…';

  @override
  String get paywallPurchased => 'Pro débloqué. Merci !';

  @override
  String get paywallRestored => 'Ton déblocage Pro a été restauré.';

  @override
  String get paywallNothingToRestore =>
      'Aucun achat antérieur trouvé pour ce compte de boutique.';

  @override
  String get paywallPending =>
      'Ton paiement est en cours de confirmation. Pro se débloquera dès qu\'il sera validé.';

  @override
  String get paywallFailed =>
      'La boutique n\'a pas pu terminer l\'opération. Réessaie.';

  @override
  String get paywallUnavailable =>
      'Les achats intégrés ne sont pas disponibles sur cet appareil.';

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
      'Convertis la salinité pratique (ppt), la densité relative (SG) et la valeur d’un aréomètre étalonné à 25 °C. Indique la température de l’eau et saisis une valeur dans n’importe quel champ.';

  @override
  String get specificGravity => 'Densité relative (SG)';

  @override
  String get measurementTemperature => 'Température de mesure';

  @override
  String get densityTemperatureHelp =>
      'Utilise la température de l’eau dans l’éprouvette.';

  @override
  String get hydrometerDensityReading => 'Valeur de l’aréomètre';

  @override
  String get densityHydrometerNote =>
      'Les aréomètres européens en verre, notamment les modèles ARKA et Tropic Marin, sont généralement étalonnés à 25 °C. La correction aide pour l’eau de mer préparée mesurée près de la température ambiante.';

  @override
  String get referencePoints => 'Points de repère';

  @override
  String get refSeawater =>
      '• Eau de mer naturelle ≈ 35 ppt ≈ 1,0264 SG ≈ 1,0233 g/cm³ à 25 °C';

  @override
  String get refReefTarget =>
      '• Cible récifale typique ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'Hors de 25 °C, la correction utilise l’équation standard de densité de l’eau de mer et la dilatation nominale du verre (26 ppm/°C). Mesure à 25 °C pour une précision optimale.';

  @override
  String get salinityToolConvert => 'Convertir';

  @override
  String get salinityToolMix => 'Préparer de l’eau neuve';

  @override
  String get salinityToolCorrect => 'Corriger ce bac';

  @override
  String get saltMixIntro =>
      'Estime la quantité de sel sec pour un mélange préparé. Utilise l’étiquette du produit ou un mélange que tu as mesuré.';

  @override
  String get saltMixFinalVolume => 'Volume final souhaité';

  @override
  String get saltMixTarget => 'Salinité cible';

  @override
  String get saltMixProfileTitle => 'Ton sel marin';

  @override
  String get saltMixProductLabel => 'Sel marin';

  @override
  String get saltMixCustomProduct => 'Mélange personnalisé';

  @override
  String get saltMixCustomHelp =>
      'Saisis une valeur de l’étiquette ou calibre une préparation que tu as mesurée.';

  @override
  String get saltMixCatalogManufacturer =>
      'Valeur initiale du fabricant. Mesure une préparation pour l’adapter à cet aquarium.';

  @override
  String get saltMixCatalogEstimate =>
      'Estimation du fabricant pour l’eau de départ. Calibre un volume final mesuré avant de t’y fier.';

  @override
  String get saltMixMeasuredCalibration =>
      'Ta calibration mesurée pour cet aquarium est utilisée.';

  @override
  String get saltMixNameOptional => 'Nom du sel (facultatif)';

  @override
  String get saltMixFactor => 'Mélange sec à la salinité de référence';

  @override
  String get saltMixFactorHelp =>
      'Indique les grammes par litre d’eau salée finale. Une valeur d’étiquette par litre d’eau de départ reste une estimation tant que tu n’as pas étalonné un vrai mélange.';

  @override
  String get saltMixReferenceSalinity => 'Salinité de référence';

  @override
  String get saltMixCalibrateTitle => 'Étalonner avec un mélange mesuré';

  @override
  String get saltMixDryMass => 'Mélange sec utilisé';

  @override
  String get saltMixMeasuredVolume => 'Volume final mesuré';

  @override
  String get saltMixMeasuredSalinity => 'Salinité mesurée';

  @override
  String get saltMixUseCalibration => 'Utiliser cet étalonnage';

  @override
  String get saltMixCalculate => 'Calculer le sel';

  @override
  String get salinityPlannerResult => 'Résultat';

  @override
  String get saltMixDrySalt => 'Mélange sec estimé';

  @override
  String get saltMixResultHelp =>
      'Commence avec moins d’eau osmosée que le volume final souhaité. Mélange hors de l’aquarium, suis les consignes du produit pour la température, le brassage et l’aération, puis vérifie avec un appareil de salinité étalonné et ajuste le sel et l’eau au volume final.';

  @override
  String get salinityCorrectionIntro =>
      'Estime un échange de même volume qui fait passer la salinité actuelle de ce bac vers ta cible.';

  @override
  String get salinityCorrectionTankVolume => 'Volume d’eau net du système';

  @override
  String get salinityCorrectionCurrent => 'Salinité actuelle';

  @override
  String get salinityCorrectionTarget => 'Salinité cible';

  @override
  String salinityPlannerLatestReading(Object date) {
    return 'Prérempli avec ta mesure du $date.';
  }

  @override
  String get salinityCorrectionReplacement =>
      'Salinité de l’eau de remplacement';

  @override
  String get salinityCorrectionReplacementHelp =>
      'Elle doit dépasser la cible. Prépare et mesure ce mélange séparément.';

  @override
  String get salinityCorrectionHighMethod =>
      'Retire le volume calculé du bac et remplace-le par le même volume d’eau osmosée à 0 ppt.';

  @override
  String get salinityCorrectionHighResultHelp =>
      'Considère le résultat comme une estimation de départ. Répartis les changements importants en étapes, laisse l’eau circuler entre elles et mesure de nouveau après chaque étape.';

  @override
  String get salinityCorrectionLowResultHelp =>
      'Prépare l’eau de remplacement hors de l’aquarium. Suis les consignes du fabricant du sel pour la température, le brassage et l’aération, vérifie-la avec un appareil de salinité étalonné, puis procède par étapes avec circulation et nouvelles mesures.';

  @override
  String get salinityCorrectionLowMethod =>
      'Retire le volume calculé du bac et remplace-le par le même volume d’eau à salinité plus élevée, préparée séparément.';

  @override
  String get salinityCorrectionCalculate => 'Calculer la correction';

  @override
  String get salinityReplacementError =>
      'La salinité de remplacement doit dépasser la cible.';

  @override
  String get salinityPlannerAssumptionsTitle => 'Avant la correction';

  @override
  String get salinityPlannerAssumptions =>
      'L’estimation suppose un volume constant, une quantité de sel conservée et une eau parfaitement mélangée. Si l’évaporation a baissé le niveau, complète d’abord avec de l’eau osmosée jusqu’au niveau normal, puis mesure à nouveau.';

  @override
  String get salinityPlannerSafety =>
      'N’ajoute jamais de sel sec dans un aquarium contenant des animaux. Fractionne les grands changements, laisse circuler entre les étapes et mesure après chacune. Le calculateur ne fixe pas de variation quotidienne universellement sûre et ne garantit pas le résultat final.';

  @override
  String get salinityCorrectionNoChange =>
      'La salinité actuelle correspond déjà à la cible. Aucun échange n’est nécessaire.';

  @override
  String get salinityCorrectionExchange => 'Retirer et remplacer';

  @override
  String get salinityCorrectionTankPercent => 'De l’eau du système';

  @override
  String get salinityCorrectionBatchSalt =>
      'Sel sec pour l’eau de remplacement';

  @override
  String get salinityCorrectionExtraEquivalent =>
      'Équivalent total de sel manquant';

  @override
  String get salinityCorrectionRecord =>
      'Enregistrer le changement d’eau effectué';

  @override
  String get salinityCorrectionLogNote => 'Correction de salinité';

  @override
  String get doseCalcTitle => 'Calculateur de dose';

  @override
  String get doseCalcIntro =>
      'Estime la vitesse à laquelle ton bac consomme un élément et la dose quotidienne qui le maintient stable. Les changements d\'eau ne sont pas pris en compte.';

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
  String get doseCalcPotencyTitle => 'Concentration de l\'additif';

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
      'Ta dose actuelle maintient cet élément stable — conserve-la.';

  @override
  String get doseCalcIncrease =>
      'Augmente la dose pour maintenir cet élément stable.';

  @override
  String get doseCalcDecrease =>
      'Tu peux réduire la dose tout en maintenant cet élément stable.';

  @override
  String get doseCalcOverdosing =>
      'Cet élément augmente — réduis ou suspends le dosage.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Rien n\'est dosé et cet élément ne baisse pas — aucune dose n\'est nécessaire.';

  @override
  String get doseCalcNeedsPotency =>
      'Saisis la concentration de l\'additif pour obtenir une recommandation de dose.';

  @override
  String get doseCalcInsufficient =>
      'Ajoute au moins deux mesures sur des jours différents et un volume de bac pour calculer.';

  @override
  String get doseCalcModeMaintenance => 'Dose quotidienne';

  @override
  String get doseCalcModeCorrection => 'Correction';

  @override
  String get doseCalcCorrIntro =>
      'Calcule une dose ponctuelle qui fait monter un élément de sa valeur actuelle à ta cible. Si une hausse rapide était risquée, la dose est répartie sur plusieurs jours.';

  @override
  String get doseCalcCurrentValue => 'Valeur actuelle';

  @override
  String get doseCalcCurrentValueHelp => 'Vide = ta dernière mesure.';

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
      'Saisis la valeur actuelle, la cible et le volume du bac pour calculer.';

  @override
  String get doseCalcCorrAtTarget =>
      'Déjà au niveau de la cible ou au-dessus — rien à doser.';

  @override
  String get doseCalcCorrSingle =>
      'Peut être donnée en une seule dose sans risque.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Monter de plus de $limit par jour est risqué — donne plutôt la correction en $days doses quotidiennes.';
  }

  @override
  String get doseCalcLogDose => 'Enregistrer cette dose';

  @override
  String get doseCalcSalinityAdjust => 'Ajuster la cible à la salinité du bac';

  @override
  String get doseCalcSalinityAdjustHelp =>
      'Les valeurs cibles supposent une eau de mer à 35 ppt (1,026). Active pour ramener la cible à la salinité mesurée de ton bac.';

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
    return 'Nombre de mesures récentes qui définissent la tendance ; élargi pour couvrir au moins $days jours si tu mesures plus souvent';
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
  String get trendOscillating => 'Fluctue — pas de direction nette';

  @override
  String get trendChipOscillating => 'Fluctuant';

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
  String get setupFishOnly => 'Fish only';

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
  String get paramOrp => 'Redox (ORP)';

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
      'Suis les oligo-éléments à partir de tests en gouttes ou d\'analyses ICP en laboratoire.';

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
  String get microChipHobby => 'Tests en gouttes';

  @override
  String get microChipFullIcp => 'ICP complet';

  @override
  String get microReminderTooltip => 'Rappel de test';

  @override
  String get microReminderTitle => 'Rappel de test d\'oligo-éléments';

  @override
  String get microReminderHint =>
      'Ajoute une tâche d\'entretien te rappelant de tester régulièrement les oligo-éléments.';

  @override
  String get microReminderCreated => 'Rappel ajouté au programme d\'entretien';

  @override
  String get microIcpTaskTitle => 'Test d\'oligo-éléments (ICP)';

  @override
  String get microToggleSubtitle =>
      'Afficher dans l\'onglet Mesures, avec rappels de tests. Masquer conserve tes mesures.';

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
      'Pas encore de vue personnalisée. Une vue n\'affiche que les éléments analysés par ton laboratoire.';

  @override
  String get microViewNameHint => 'ex. Panel de mon labo';

  @override
  String get microViewNeedElement => 'Sélectionne au moins un élément.';

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
      'Seule la vue est supprimée. Tes mesures sont conservées.';

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
  String get icpImportFormatHint => 'Choisis le format d\'export du fichier.';

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
      'Prérempli avec la date d\'analyse du rapport. Remplace-la par le jour du prélèvement de l\'eau.';

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
      'Choisis l\'application ou l\'appareil d\'où provient le fichier.';

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
      'Premier import dans cet aquarium : choisis jusqu\'où remonter. Les mesures plus anciennes seront définitivement ignorées — utile si tu les as déjà saisies à la main.';

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
  String get hannaConnectTitle => 'Checker Hanna';

  @override
  String get hannaMeasureAction => 'Mesurer avec le Checker Hanna';

  @override
  String get hannaScanTitle => 'Scanner l\'écran du checker';

  @override
  String get hannaScanPickHint =>
      'Lit la valeur directement sur l\'écran du checker. Choisis d\'abord ton modèle — le numéro HI est imprimé sur l\'avant du checker.';

  @override
  String get hannaScanPickTitle => 'Modèle de checker';

  @override
  String get hannaScanGuide => 'Place l\'écran dans le cadre';

  @override
  String get hannaScanGlareHint => 'incline légèrement pour éviter les reflets';

  @override
  String get hannaScanZoomHint => 'pince pour zoomer';

  @override
  String get hannaScanRescan => 'Scanner à nouveau';

  @override
  String get hannaScanNoCamera => 'Cet appareil n\'a pas d\'appareil photo.';

  @override
  String get hannaScanCameraDenied =>
      'L\'accès à l\'appareil photo a été refusé. Autorise l\'accès à l\'appareil photo dans les réglages du système pour scanner l\'écran.';

  @override
  String get hannaScanCameraFailed =>
      'Impossible de démarrer l\'appareil photo.';

  @override
  String get hannaScanImpossibleNote =>
      'Cette valeur est impossible pour ce paramètre et ne peut pas être enregistrée. Scanne à nouveau ou vérifie que le bon modèle est sélectionné.';

  @override
  String get hannaScanImplausibleNote =>
      'Cette valeur est hors de la plage plausible — vérifie-la avant de l\'enregistrer.';

  @override
  String get experimentalBadge => 'Expérimental';

  @override
  String get experimentalSection => 'Expérimental';

  @override
  String get experimentalToggleTitle => 'Fonctions expérimentales';

  @override
  String get experimentalToggleSubtitle =>
      'Essaie des fonctions encore en test : connexion Bluetooth du Checker Hanna et scan de l\'écran';

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
      'Seules les mesures sont prises en charge. Pour modifier les réglages de l\'appareil ou mettre à jour son firmware, utilise l\'application Hanna Lab du fabricant.';

  @override
  String get hannaScanning => 'Recherche de l\'appareil…';

  @override
  String get hannaScanHint =>
      'Allume l\'appareil et garde-le près du téléphone.';

  @override
  String get hannaReadingSetup => 'Connecté — lecture de la configuration…';

  @override
  String get hannaErrUnsupported =>
      'Le Bluetooth LE n\'est pas disponible sur cet appareil.';

  @override
  String get hannaErrBluetoothOff =>
      'Le Bluetooth est désactivé. Active-le et réessaie.';

  @override
  String get hannaErrNotFound =>
      'Aucun appareil trouvé. Vérifie qu\'il est allumé et à portée.';

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
  String get hannaSetsTitle => 'Jeux de tests';

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
  String get hannaSaveSet => 'Enregistrer la sélection comme jeu de tests';

  @override
  String get hannaSetName => 'Nom du jeu de tests';

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
  String get hannaFollowMeter => 'Suis les instructions sur l\'appareil';

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
  String get hannaTimerHint => 'Minuteur du temps de réaction';

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
  String get hannaTimerDoneTitle => 'Minuteur de réactif terminé';

  @override
  String get hannaTimerDoneBody =>
      'Le temps est écoulé — poursuis la mesure sur ton appareil.';

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
  String hannaSaveButtonEnv(int count, int envCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enregistrer $count mesures',
      one: 'Enregistrer 1 mesure',
    );
    return '$_temp0 + $envCount environnement';
  }

  @override
  String get hannaIncludeInSave => 'Enregistrer cette valeur';

  @override
  String get hannaValueImpossible =>
      'Hors de la plage possible — ne sera pas enregistré';

  @override
  String get hannaNothingSelected => 'Aucune valeur sélectionnée';

  @override
  String get hannaRemeasure => 'Mesurer à nouveau';

  @override
  String hannaRemeasureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mesurer $count valeurs à nouveau',
      one: 'Mesurer 1 valeur à nouveau',
    );
    return '$_temp0';
  }

  @override
  String get hannaRemeasureQueued => 'Sera mesuré à nouveau';

  @override
  String get hannaRemeasureKept => 'Non remesuré — valeur précédente conservée';

  @override
  String hannaPreviousValue(String value) {
    return 'avant $value';
  }

  @override
  String get hannaMeasuringAgain =>
      'Nouvelle mesure des paramètres sélectionnés.';

  @override
  String get hannaRemeasureFailed =>
      'L\'appareil n\'a pas répondu — rien n\'a été remesuré et les résultats sont inchangés.';

  @override
  String get environmentTitle => 'Environnement';

  @override
  String get environmentInclude =>
      'Inclure les valeurs d\'environnement des appareils connectés';

  @override
  String get environmentJustNow => 'lu à l\'instant';

  @override
  String environmentMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'lu il y a $minutes minutes',
      one: 'lu il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get environmentUnreachable =>
      'Appareils injoignables — les mesures seront enregistrées sans les valeurs d\'environnement.';

  @override
  String get environmentAllMeasured =>
      'Toutes les valeurs d\'environnement ont déjà été mesurées dans cette session.';

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
      'Dureté carbonatée. Maintiens-la stable — évite les variations.';

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
  String lastTestedAgo(String ago) {
    return 'Dernier test $ago';
  }

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
      'Ce que tes mesures récentes suggèrent de surveiller.';

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
  String insightOscillating(Object param) {
    return '$param fluctue au lieu de dériver — aucune tendance fiable';
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
  String get aiSummaryAction => 'Demander à ton IA';

  @override
  String get aiSummaryPrivacyNote =>
      'Ceci est un prompt prêt à l\'emploi avec les données de ton bac. Colle-le dans ChatGPT, Claude, Gemini ou tout autre outil d\'IA — tout est préparé sur ton appareil, rien n\'est envoyé nulle part.';

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
  String get aiSummaryCopied => 'Copié — colle-le dans ton chat IA.';

  @override
  String get aiSummaryEmpty => 'Pas encore de mesures — rien à résumer.';

  @override
  String get aiSummaryInsightsFooter =>
      'Envie d\'une analyse plus poussée ? Demande à ton IA';

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
  String get dashboardLayoutFlatGraph => 'Plat avec graphiques';

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
      'À l\'heure de dosage de chaque additif';

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
      'Définis une heure de dosage pour activer les rappels';

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
  String get taskTitleRequired => 'Saisis un titre';

  @override
  String get repeatLabel => 'Répétition';

  @override
  String get oneOff => 'Ponctuelle';

  @override
  String get dueDateLabel => 'Échéance';

  @override
  String get dueDateRequired => 'Choisis une échéance';

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
      'Pas encore de tâche d\'entretien. Planifie des changements d\'eau ou des tâches personnalisées pour obtenir des échéances et des rappels.';

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
  String get invalidInterval => 'Saisis un nombre entier (au moins 1).';

  @override
  String get invalidMonthDay => 'Saisis un jour entre 1 et 31.';

  @override
  String get weekdaysRequired => 'Choisis au moins un jour.';

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
  String get roCustomStage => 'Cartouche personnalisée';

  @override
  String get roAddStage => 'Ajouter une cartouche';

  @override
  String get roEditStage => 'Modifier la cartouche';

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
  String get roPartOfUnitHint => 'Désactive si ton osmoseur n\'a pas cet étage';

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
  String get roDeleteStageTitle => 'Supprimer la cartouche ?';

  @override
  String get roDeleteStageBody =>
      'La cartouche et l\'historique de ses remplacements seront supprimés. Cette action est irréversible.';

  @override
  String get roEmptyBody =>
      'Aucune cartouche. Ajoute les filtres de ton osmoseur avec +.';

  @override
  String get roSetupPrompt =>
      'Suis le remplacement des filtres et de la membrane';

  @override
  String get roUnitToggleSubtitle =>
      'Afficher dans l\'onglet Actions, avec rappels de remplacement des filtres';

  @override
  String get roAllOk => 'Toutes les cartouches sont OK';

  @override
  String get roUsageTitle => 'Intensité d\'utilisation';

  @override
  String get roUsageDialogBody =>
      'Quantité d\'eau produite par ton osmoseur. Choisir un niveau réinitialise les intervalles de remplacement de toutes les cartouches standard — y compris ceux réglés manuellement — aux valeurs typiques de ce niveau ; les cartouches personnalisées restent intactes, et tu pourras ensuite ajuster chaque cartouche.';

  @override
  String get roUsageLight => 'Faible';

  @override
  String get roUsageModerate => 'Modérée';

  @override
  String get roUsageHeavy => 'Élevée';

  @override
  String get roUsageLightHint =>
      'Moins de ~300 L (80 gal) par mois — appoints et petits changements d\'eau';

  @override
  String get roUsageModerateHint =>
      'Environ 300–1000 L (80–260 gal) par mois — un bac récifal typique';

  @override
  String get roUsageHeavyHint =>
      'Plus de ~1000 L (260 gal) par mois — grand bac ou plusieurs bacs';

  @override
  String get roUsageApplied =>
      'Intervalles de remplacement réinitialisés pour les cartouches standard';

  @override
  String get notifRoTitle => 'Remplacer les filtres de l\'osmoseur';

  @override
  String get reefFactoryTitle => 'Appareils ReefFactory';

  @override
  String get reefFactoryMenu => 'Appareils ReefFactory';

  @override
  String get reefFactoryDisclaimer =>
      'Cette application lit uniquement les valeurs en direct de tes appareils ReefFactory. Elle ne peut pas modifier les réglages, étalonner ni mettre à jour le firmware — utilise l\'application ReefFactory pour cela. La lecture ne fonctionne que si ton téléphone est sur le même réseau Wi-Fi que les appareils.';

  @override
  String get reefFactoryAddDevice => 'Ajouter un appareil';

  @override
  String get reefFactoryEmptyTitle => 'Aucun appareil';

  @override
  String get reefFactoryEmptyBody =>
      'Ajoute un appareil de mesure ReefFactory par son adresse IP ou son nom d\'hôte pour lire ses valeurs en direct.';

  @override
  String get reefFactoryRefresh => 'Actualiser';

  @override
  String get reefFactorySave => 'Enregistrer';

  @override
  String get reefFactoryRefreshAll => 'Tout actualiser';

  @override
  String get reefFactorySaveAll => 'Tout enregistrer';

  @override
  String get reefFactoryNothingToSave =>
      'Rien à enregistrer pour l\'instant — touche d\'abord Tout actualiser.';

  @override
  String reefFactorySavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relevés enregistrés',
      one: '1 relevé enregistré',
    );
    return '$_temp0';
  }

  @override
  String get reefFactoryNotReadYet =>
      'Touche Tout actualiser pour lire la valeur actuelle.';

  @override
  String get reefFactoryHeating => 'Chauffage';

  @override
  String get reefFactoryCooling => 'Refroidissement';

  @override
  String get reefFactoryNoTank =>
      'Attribue d\'abord un bac pour enregistrer les relevés.';

  @override
  String get reefFactoryTankLabel => 'Bac';

  @override
  String get reefFactorySelectTank => 'Sélectionner un bac';

  @override
  String get reefFactoryMoveToTank => 'Déplacer vers un autre bac';

  @override
  String get reefFactoryRenameDevice => 'Renommer l\'appareil';

  @override
  String get reefFactoryDeviceNameLabel => 'Nom';

  @override
  String get reefFactoryRemove => 'Supprimer l\'appareil';

  @override
  String reefFactoryRemoveConfirm(Object name) {
    return 'Supprimer $name de cette liste ? Les relevés enregistrés sont conservés.';
  }

  @override
  String get reefFactoryHostLabel => 'Adresse IP ou nom d\'hôte';

  @override
  String get reefFactoryHostHint => 'ex. 192.168.1.50';

  @override
  String get reefFactoryHostHelp =>
      'Trouve-la dans l\'application ReefFactory ou ton routeur. Une réservation DHCP l\'empêche de changer. Ton téléphone doit être sur le même réseau Wi-Fi que l\'appareil.';

  @override
  String get reefFactoryCheck => 'Vérifier';

  @override
  String reefFactoryFound(Object model) {
    return 'Trouvé : $model';
  }

  @override
  String get reefFactoryErrUnreachable =>
      'Impossible de joindre cette adresse. Vérifie que l\'appareil est allumé et sur ce réseau.';

  @override
  String get reefFactoryErrTimeout =>
      'Connecté, mais aucun relevé n\'est arrivé.';

  @override
  String get reefFactoryErrUnsupported =>
      'Ce modèle d\'appareil n\'est pas encore pris en charge.';

  @override
  String get reefFactoryErrProtocol => 'Impossible de lire l\'appareil.';

  @override
  String get reefBeatTitle => 'Appareils ReefBeat';

  @override
  String get reefBeatMenu => 'Appareils ReefBeat';

  @override
  String get reefBeatSettingsSubtitle =>
      'Données en direct des appareils Red Sea ReefBeat';

  @override
  String get reefBeatDisclaimer =>
      'Cette application lit uniquement les données en direct de tes appareils Red Sea ReefBeat. Elle ne peut pas doser, modifier les programmes ni étalonner — utilise l\'application ReefBeat pour cela. La lecture ne fonctionne que si ton téléphone est sur le même réseau Wi-Fi que les appareils.';

  @override
  String get reefBeatAddDevice => 'Ajouter un appareil';

  @override
  String get reefBeatEmptyTitle => 'Aucun appareil';

  @override
  String get reefBeatEmptyBody =>
      'Analyse ton réseau Wi-Fi pour trouver tes appareils Red Sea ReefBeat — ReefDose, ReefATO, ReefMat, ReefRun, ReefLED, ReefWave et ReefControl — ou ajoute un appareil par son adresse IP.';

  @override
  String get reefBeatRefreshAll => 'Tout actualiser';

  @override
  String get reefBeatNotReadYet =>
      'Touche Tout actualiser pour lire l\'état actuel.';

  @override
  String get reefBeatTankLabel => 'Bac';

  @override
  String get reefBeatSelectTank => 'Sélectionner un bac';

  @override
  String get reefBeatMoveToTank => 'Déplacer vers un autre bac';

  @override
  String get reefBeatRenameDevice => 'Renommer l\'appareil';

  @override
  String get reefBeatDeviceNameLabel => 'Nom';

  @override
  String get reefBeatRemove => 'Supprimer l\'appareil';

  @override
  String reefBeatRemoveConfirm(Object name) {
    return 'Supprimer $name de cette liste ?';
  }

  @override
  String get reefBeatHostLabel => 'Adresse IP ou nom d\'hôte';

  @override
  String get reefBeatHostHint => 'ex. 192.168.1.3';

  @override
  String get reefBeatHostHelp =>
      'Trouve-la dans la liste des clients de ton routeur. Une réservation DHCP l\'empêche de changer. Ton téléphone doit être sur le même réseau Wi-Fi que l\'appareil.';

  @override
  String get reefBeatCheck => 'Vérifier';

  @override
  String reefBeatFound(Object model) {
    return 'Trouvé : $model';
  }

  @override
  String get reefBeatErrUnreachable =>
      'Impossible de joindre cette adresse. Vérifie que l\'appareil est allumé et sur ce réseau.';

  @override
  String get reefBeatErrTimeout =>
      'Connecté, mais aucune réponse n\'est arrivée.';

  @override
  String get reefBeatErrUnsupported =>
      'Ce type d\'appareil ReefBeat n\'est pas encore pris en charge.';

  @override
  String get reefBeatErrProtocol => 'Impossible de lire l\'appareil.';

  @override
  String reefBeatHead(int number) {
    return 'Tête $number';
  }

  @override
  String get reefBeatHeadOff => 'Arrêtée';

  @override
  String reefBeatDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours restants',
      one: '1 jour restant',
    );
    return '$_temp0';
  }

  @override
  String reefBeatDosedOfDaily(Object dosed, Object daily) {
    return '$dosed / $daily ml';
  }

  @override
  String reefBeatDosedNoDaily(Object dosed) {
    return '$dosed ml';
  }

  @override
  String reefBeatDosedManual(Object volume) {
    return '$volume ml manuel';
  }

  @override
  String reefBeatDosedManualExtra(Object volume) {
    return '+$volume ml manuel';
  }

  @override
  String reefBeatDoseDue(Object volume) {
    return '$volume ml restants';
  }

  @override
  String get reefBeatPlanComplete => 'Terminé';

  @override
  String reefBeatDoseCount(int done, int total) {
    return 'Doses $done/$total';
  }

  @override
  String reefBeatDosedSemantics(Object dosed, Object daily) {
    return '$dosed ml sur $daily ml du programme du jour dosés';
  }

  @override
  String reefBeatDosedManualSemantics(Object volume) {
    return 'plus $volume ml dosés manuellement';
  }

  @override
  String get reefBeatDosingQueue => 'File de dosage du jour';

  @override
  String get reefBeatDosingQueueEmpty => 'Plus aucune dose aujourd\'hui';

  @override
  String reefBeatDosingQueueTotal(int count, Object volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses',
      one: '1 dose',
    );
    return '$_temp0 · $volume ml';
  }

  @override
  String reefBeatDosingQueueVolume(Object volume) {
    return '$volume ml';
  }

  @override
  String get reefBeatRecalibration => 'Étalonnage requis';

  @override
  String reefBeatMissedDose(Object volume) {
    return 'Dose manquée : $volume ml';
  }

  @override
  String get reefBeatTimeError => 'Erreur d\'horloge de l\'appareil';

  @override
  String get reefBeatBatteryLow => 'Batterie de secours faible';

  @override
  String get reefBeatAtoLeak => 'Fuite détectée !';

  @override
  String get reefBeatAtoSensorError => 'Problème de capteur de niveau';

  @override
  String get reefBeatAtoFilling => 'Remplissage en cours';

  @override
  String get reefBeatAtoWaterLevel => 'Niveau d\'eau';

  @override
  String get reefBeatAtoLevelOk => 'OK';

  @override
  String get reefBeatAtoLevelLow => 'Bas';

  @override
  String get reefBeatAtoLevelAbove => 'Élevé';

  @override
  String get reefBeatAtoTemperature => 'Température';

  @override
  String get reefBeatAtoToday => 'Aujourd\'hui';

  @override
  String reefBeatAtoFills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count remplissages',
      one: '1 remplissage',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatAtoEvaporation => 'Évaporation';

  @override
  String reefBeatAtoPerDay(Object volume) {
    return '≈$volume/jour';
  }

  @override
  String get reefBeatAtoReservoir => 'Réservoir';

  @override
  String get reefBeatAtoLeakSensor => 'Capteur de fuite';

  @override
  String get reefBeatAtoLeakNotConnected => 'Non connecté';

  @override
  String get reefBeatAtoLeakNotEnabled => 'Non activé';

  @override
  String get reefBeatAtoLeakDry => 'Sec';

  @override
  String get reefBeatAtoLeakRodi => 'Fuite d\'eau RO/DI';

  @override
  String get reefBeatAtoLeakAquarium => 'Fuite d\'eau de l\'aquarium';

  @override
  String get reefBeatMatRoll => 'Rouleau';

  @override
  String get reefBeatMatRollEmpty => 'Fin du rouleau';

  @override
  String get reefBeatMatRollLow => 'Rouleau bientôt épuisé';

  @override
  String get reefBeatMatCleanSensor => 'Nettoie le capteur';

  @override
  String get reefBeatMatAutoAdvanceOff => 'Avance auto désactivée';

  @override
  String get reefBeatMatAdvancing => 'Avance en cours';

  @override
  String get reefBeatMatUsedToday => 'Utilisé aujourd\'hui';

  @override
  String get reefBeatMatAverage => 'Moyenne';

  @override
  String reefBeatMatPerDay(Object length) {
    return '≈$length/jour';
  }

  @override
  String get reefBeatMatInstalled => 'Rouleau installé';

  @override
  String reefBeatMatRollAge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatMode => 'Mode';

  @override
  String reefBeatPercent(int value) {
    return '$value %';
  }

  @override
  String reefBeatRunPump(int number) {
    return 'Pompe $number';
  }

  @override
  String get reefBeatRunScheduleOff => 'Programmation désactivée';

  @override
  String get reefBeatRunTemperature => 'Température du moteur';

  @override
  String get reefBeatRunMissingPump => 'Pompe non détectée';

  @override
  String get reefBeatRunMissingSensor => 'Capteur non détecté';

  @override
  String reefBeatRunState(Object state) {
    return 'État de la pompe : $state';
  }

  @override
  String get reefBeatRunFullCup => 'Godet plein';

  @override
  String get reefBeatRunOverSkimming => 'Sur-écumage';

  @override
  String get reefBeatRunSensorOffline => 'Capteur de niveau hors ligne';

  @override
  String get reefBeatRunSensorBadge => 'Capteur';

  @override
  String get reefBeatLightWhite => 'Blanc';

  @override
  String get reefBeatLightBlue => 'Bleu';

  @override
  String get reefBeatLightMoon => 'Lune';

  @override
  String get reefBeatLightFan => 'Ventilateur';

  @override
  String get reefBeatLightTemperature => 'Dissipateur';

  @override
  String get reefBeatLightTilt => 'Luminaire incliné';

  @override
  String reefBeatLightAcclimation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Acclimatation : $count jours restants',
      one: 'Acclimatation : 1 jour restant',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatLightAcclimationOn => 'Acclimatation en cours';

  @override
  String get reefBeatLightMoonPhase => 'Phase lunaire';

  @override
  String reefBeatLightMoonDay(Object name, int day) {
    return '$name, jour $day';
  }

  @override
  String get reefBeatWaveGroup => 'Pompes ReefWave';

  @override
  String get apexTitle => 'Neptune Apex';

  @override
  String get apexMenu => 'Neptune Apex';

  @override
  String get apexSettingsSubtitle =>
      'Valeurs des sondes et état des prises d\'un Apex';

  @override
  String get apexDisclaimer =>
      'Cette application se contente de lire ton Apex. Elle ne peut pas allumer ou éteindre les prises, lancer un cycle de nourrissage ni modifier les programmes — utilise Fusion ou la page web de l\'Apex pour cela. La lecture ne fonctionne que si ton téléphone est sur le même réseau Wi-Fi que le contrôleur.';

  @override
  String get apexAddDevice => 'Ajouter un contrôleur';

  @override
  String get apexEmptyTitle => 'Aucun contrôleur';

  @override
  String get apexEmptyBody =>
      'Ajoute ton Apex par son adresse IP et les identifiants que tu utilises sur sa page web.';

  @override
  String get apexRefreshAll => 'Tout actualiser';

  @override
  String get apexSaveAll => 'Tout enregistrer';

  @override
  String get apexSave => 'Enregistrer';

  @override
  String apexSavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relevés enregistrés',
      one: '1 relevé enregistré',
    );
    return '$_temp0';
  }

  @override
  String get apexNothingToSave => 'Rien à enregistrer pour l\'instant.';

  @override
  String get apexNoTank =>
      'Affecte ce contrôleur à un aquarium pour enregistrer ses relevés.';

  @override
  String get apexNotReadYet =>
      'Touche « Tout actualiser » pour lire les valeurs actuelles.';

  @override
  String get apexNoProbes =>
      'Ce contrôleur n\'a aucune sonde que l\'application puisse enregistrer.';

  @override
  String get apexOutlets => 'Prises';

  @override
  String apexShowAll(int count) {
    return 'Afficher $count de plus';
  }

  @override
  String get apexShowFewer => 'Afficher moins';

  @override
  String apexOverridden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prises forcées manuellement',
      one: '1 prise forcée manuellement',
    );
    return '$_temp0';
  }

  @override
  String get apexOutletOnSemantics => 'allumée';

  @override
  String get apexOutletOffSemantics => 'éteinte';

  @override
  String get apexOutletProfileSemantics => 'pilotée par un profil';

  @override
  String get apexOutletOverriddenSemantics => 'forcée manuellement';

  @override
  String apexFeedRunning(Object letter) {
    return 'Cycle de nourrissage $letter en cours';
  }

  @override
  String get apexRenameDevice => 'Renommer le contrôleur';

  @override
  String get apexDeviceNameLabel => 'Nom du contrôleur';

  @override
  String get apexCredentialsMenu => 'Se reconnecter';

  @override
  String get apexMoveToTank => 'Déplacer vers un autre aquarium';

  @override
  String get apexRemove => 'Retirer';

  @override
  String apexRemoveConfirm(Object name) {
    return 'Retirer « $name » ? Les relevés enregistrés sont conservés.';
  }

  @override
  String get apexSelectTank => 'Sélectionner un aquarium';

  @override
  String get apexHostLabel => 'Adresse IP ou nom d\'hôte';

  @override
  String get apexHostHint => '192.168.1.50';

  @override
  String get apexHostHelp =>
      'L\'adresse à laquelle tu ouvres la page web de l\'Apex. Tu la trouveras dans Fusion sous « Misc Setup » ou dans ton routeur.';

  @override
  String get apexUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get apexPasswordLabel => 'Mot de passe';

  @override
  String get apexCheck => 'Vérifier';

  @override
  String apexFound(Object model, Object serial) {
    return 'Trouvé : $model · $serial';
  }

  @override
  String get apexTankLabel => 'Aquarium';

  @override
  String get apexErrUnreachable =>
      'Cette adresse est injoignable. Vérifie que le contrôleur est allumé et sur ce réseau.';

  @override
  String get apexErrTimeout =>
      'Connecté, mais le contrôleur n\'a pas répondu à temps.';

  @override
  String get apexErrAuth =>
      'Le contrôleur a refusé ce nom d\'utilisateur ou ce mot de passe.';

  @override
  String get apexErrProtocol =>
      'Cette adresse a répondu, mais pas comme un Apex.';

  @override
  String get discoveryTitle => 'Analyser le réseau';

  @override
  String get discoverySweeping => 'Recherche d\'appareils sur ton Wi-Fi…';

  @override
  String get discoveryIdentifying => 'Vérification des appareils trouvés…';

  @override
  String get discoveryDone => 'Analyse terminée.';

  @override
  String get discoveryNoNetwork =>
      'Ton téléphone n\'est connecté à aucun réseau Wi-Fi. Connecte-toi au même Wi-Fi que tes appareils, puis relance l\'analyse.';

  @override
  String get discoveryNothingFoundHelp =>
      'Aucun appareil trouvé. Vérifie qu\'ils sont allumés et connectés à ce réseau Wi-Fi. Certains réseaux invités empêchent les appareils de se voir. Tu peux toujours ajouter un appareil en saisissant son adresse IP.';

  @override
  String get discoveryAdd => 'Ajouter';

  @override
  String get discoveryUpdate => 'Mettre à jour';

  @override
  String get discoveryAlreadyAdded => 'Ajouté';

  @override
  String discoveryAddressChanged(Object address) {
    return 'Désormais sur $address';
  }

  @override
  String get discoveryUnsupported => 'Non pris en charge';

  @override
  String get discoveryUnsupportedHelp =>
      'L\'application ne sait pas encore lire ce type d\'appareil.';

  @override
  String get discoveryRescan => 'Relancer l\'analyse';

  @override
  String get discoveryManualEntry => 'Saisir une adresse IP';

  @override
  String get discoveryFailed =>
      'L\'analyse s\'est interrompue à cause d\'une erreur inattendue. Relance l\'analyse.';

  @override
  String get discoveryPermissionDenied =>
      'ReefTracker n\'est pas autorisé à accéder à ton réseau local : ni l\'analyse ni les adresses saisies à la main ne peuvent fonctionner. Autorise l\'accès dans Réglages → Confidentialité et sécurité → Réseau local, puis relance l\'analyse.';

  @override
  String deviceAlreadyAdded(Object name) {
    return '$name est déjà ajouté. Utilise Analyser le réseau pour lui attribuer une nouvelle adresse.';
  }

  @override
  String get devicesTitle => 'Appareils connectés';

  @override
  String get devicesTab => 'Appareils';

  @override
  String get devicesAll => 'Tous';

  @override
  String devicesScopeAll(int count) {
    return 'Tous les appareils · $count';
  }

  @override
  String devicesScopeVendor(String vendor, int count) {
    return '$vendor · $count';
  }

  @override
  String devicesRefreshAll(int count) {
    return 'Tout actualiser ($count)';
  }

  @override
  String devicesSaveAll(int count) {
    return 'Tout enregistrer ($count)';
  }

  @override
  String get devicesDisclaimer =>
      'L\'application se contente de lire tes appareils. Elle ne peut pas modifier les réglages, doser, allumer ou éteindre les prises ni étalonner — utilise l\'application du fabricant pour cela. La lecture ne fonctionne que si ton téléphone est sur le même réseau Wi-Fi que les appareils.';

  @override
  String get devicesEmptyTitle => 'Aucun appareil';

  @override
  String get devicesEmptyBody =>
      'Connecte un appareil de mesure ReefFactory, un appareil Red Sea ReefBeat ou un contrôleur Neptune Apex sur ton réseau — ou mesure avec un checker Hanna en Bluetooth — pour le voir ici.';

  @override
  String get devicesAddDevice => 'Ajouter un appareil';

  @override
  String get devicesHannaDisclaimer =>
      'Le checker ne se connecte en Bluetooth que pendant une mesure — lance-la depuis sa carte. Les mesures terminées sont enregistrées dans ton journal.';

  @override
  String get devicesAddPickBrand => 'Quelle marque ?';

  @override
  String get devicesReorderBrands => 'Réorganiser les marques';

  @override
  String get devicesReorderBrandsHint =>
      'Quand deux appareils rapportent la même mesure, la marque la plus haute dans cette liste l\'emporte.';

  @override
  String devicesSourceNote(String param, String device) {
    return '$param depuis $device';
  }

  @override
  String get devicesProLocked =>
      'La lecture en direct de tes appareils fait partie de ReefTracker Pro.';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils',
      one: '1 appareil',
    );
    return '$_temp0';
  }

  @override
  String get devicesDetails => 'Détails';

  @override
  String get reefDevicesTitle => 'Appareils connectés';

  @override
  String get reefDevicesSubtitle =>
      'Appareils ReefFactory, appareils ReefBeat, contrôleurs Apex et Checker Hanna';

  @override
  String get reefDevicesEmpty => 'Aucun appareil connecté.';

  @override
  String get reefDevicesKindReefFactory => 'ReefFactory';

  @override
  String get reefDevicesKindReefBeat => 'Red Sea';

  @override
  String get reefDevicesKindApex => 'Neptune Apex';

  @override
  String get reefDevicesKindHanna => 'Hanna';

  @override
  String get reefDevicesBluetooth => 'Bluetooth';

  @override
  String reefDevicesLastSeen(Object date) {
    return 'Vu $date';
  }

  @override
  String get hannaSerialNumber => 'Numéro de série';

  @override
  String get hannaLastMeasurement => 'Dernière mesure';

  @override
  String get hannaNewMeasurement => 'Nouvelle mesure';

  @override
  String get hannaRenameDevice => 'Renommer le checker';

  @override
  String get hannaDeviceNameLabel => 'Nom du checker';

  @override
  String get hannaRemove => 'Retirer';

  @override
  String hannaRemoveConfirm(Object name) {
    return 'Retirer « $name » ? Les valeurs enregistrées sont conservées et le checker réapparaîtra après sa prochaine mesure.';
  }

  @override
  String get resetParamDefaults => 'Rétablir les valeurs par défaut';

  @override
  String get resetParamDefaultsTitle =>
      'Rétablir les valeurs par défaut de tous les paramètres ?';

  @override
  String get resetParamDefaultsBody =>
      'Chaque paramètre retrouve les limites recommandées pour ce type d\'aquarium, et les micro-éléments leurs valeurs par défaut intégrées. Les limites définies manuellement sont supprimées. Tes mesures sont conservées.';

  @override
  String get paramDefaultsRestored =>
      'Paramètres rétablis aux valeurs par défaut.';

  @override
  String get resetThisParamDefaults =>
      'Rétablir les valeurs par défaut de ce paramètre';

  @override
  String get reset => 'Rétablir';

  @override
  String get followingDefaults => 'Utilise les valeurs par défaut';

  @override
  String get wallDisplayTitle => 'Affichage mural';

  @override
  String get wallDisplaySubtitle =>
      'Tableau toujours allumé des valeurs de ton aquarium';

  @override
  String get wallSmallScreenNote =>
      'L\'affichage mural est conçu pour une tablette fixée au mur. Il fonctionne aussi sur cet écran plus petit – tu verras simplement moins de cartes par page.';

  @override
  String get wallStartNow => 'Démarrer maintenant';

  @override
  String get wallStartNowSubtitle => 'Afficher le tableau mural sur cet écran';

  @override
  String get wallAutoStartTitle => 'Démarrer au lancement';

  @override
  String get wallAutoStartSubtitle =>
      'Ouvrir l\'affichage mural à chaque lancement de l\'application sur cet appareil';

  @override
  String get wallBehaviourSection => 'Comportement';

  @override
  String get wallRefreshIntervalTitle => 'Actualiser toutes les';

  @override
  String get wallRefreshIntervalSubtitle =>
      'Fréquence de lecture des appareils connectés';

  @override
  String get wallPageSecondsTitle => 'Rotation des pages';

  @override
  String get wallPageSecondsSubtitle => 'Durée d\'affichage de chaque page';

  @override
  String get wallNightTitle => 'Atténuation nocturne';

  @override
  String get wallNightSubtitle =>
      'Atténuer l\'écran la nuit ; un appui le rallume pendant une minute';

  @override
  String get wallNightFromTitle => 'Atténuer à partir de';

  @override
  String get wallNightToTitle => 'Atténuer jusqu\'à';

  @override
  String get wallDataSection => 'Données collectées';

  @override
  String get wallClearSamplesTitle => 'Effacer les mesures collectées';

  @override
  String get wallClearSamplesSubtitle =>
      'Supprimer les mesures en ligne utilisées par les graphiques de l’affichage mural';

  @override
  String get wallClearSamplesDialogTitle => 'Effacer les mesures collectées ?';

  @override
  String get wallClearSamplesDialogBody =>
      'Choisis la quantité d’historique en ligne récent à conserver. Les mesures saisies manuellement ne sont pas supprimées.';

  @override
  String get wallClearSamplesAll => 'Tout supprimer';

  @override
  String get wallKeepSamples1h => 'Conserver la dernière heure';

  @override
  String get wallKeepSamples4h => 'Conserver les 4 dernières heures';

  @override
  String get wallKeepSamples12h => 'Conserver les 12 dernières heures';

  @override
  String get wallSamplesHistoryUpdated =>
      'L’historique des mesures collectées a été mis à jour';

  @override
  String get wallCardsSection => 'Cartes';

  @override
  String get wallCardsHint =>
      'Chaque valeur signalée par un appareil a sa propre carte. Masque les doublons inutiles et fais glisser le reste ; masque toutes les cartes d\'un appareil et le tableau cesse de le contacter.';

  @override
  String get wallStoredCard => 'Mesures manuelles';

  @override
  String wallSecondsLabel(int n) {
    return '$n s';
  }

  @override
  String wallMinutesLabel(int n) {
    return '$n min';
  }

  @override
  String get wallNoTank =>
      'Pas encore d\'aquarium. Ajoute-en un, puis démarre l\'affichage mural.';

  @override
  String get wallProLocked => 'L\'affichage mural est une fonction PRO.';

  @override
  String get wallExitHint => 'Maintiens appuyé n\'importe où pour quitter';

  @override
  String wallUpdatedAt(Object time) {
    return 'mis à jour $time';
  }

  @override
  String wallDueToday(Object items) {
    return 'À faire aujourd\'hui : $items';
  }

  @override
  String wallTestDue(Object param) {
    return 'test $param';
  }

  @override
  String get wallNoDevices => 'Aucun appareil';

  @override
  String get wallAllReachable => 'Tous les appareils joignables';

  @override
  String get wallSomeUnreachable => 'Un appareil est injoignable';

  @override
  String get wallNetworkDown => 'Aucun appareil joignable – vérifie le réseau';

  @override
  String wallMeasuredAgo(Object ago) {
    return 'mesuré $ago';
  }

  @override
  String get wallWindow24h => '24 h';

  @override
  String get wallWindow14d => '14 j';

  @override
  String wallHeadDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String wallHeadMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '1 mois',
    );
    return '$_temp0';
  }
}
