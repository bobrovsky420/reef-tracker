import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('de'),
    Locale('en'),
    Locale('pl'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ReefTracker'**
  String get appTitle;

  /// No description provided for @measurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @manageParameters.
  ///
  /// In en, this message translates to:
  /// **'Manage parameters'**
  String get manageParameters;

  /// No description provided for @compareView.
  ///
  /// In en, this message translates to:
  /// **'Compare graphs'**
  String get compareView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @addReading.
  ///
  /// In en, this message translates to:
  /// **'Add reading'**
  String get addReading;

  /// No description provided for @addAquarium.
  ///
  /// In en, this message translates to:
  /// **'Add aquarium'**
  String get addAquarium;

  /// No description provided for @manageTanks.
  ///
  /// In en, this message translates to:
  /// **'Manage tanks'**
  String get manageTanks;

  /// No description provided for @chooseParameters.
  ///
  /// In en, this message translates to:
  /// **'Choose parameters'**
  String get chooseParameters;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @errorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWith(Object message);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ReefTracker'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first aquarium to start tracking water parameters.'**
  String get welcomeBody;

  /// No description provided for @noParamsTracked.
  ///
  /// In en, this message translates to:
  /// **'No parameters are being tracked for this tank.'**
  String get noParamsTracked;

  /// No description provided for @noReadings.
  ///
  /// In en, this message translates to:
  /// **'No readings'**
  String get noReadings;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @aquariums.
  ///
  /// In en, this message translates to:
  /// **'Aquariums'**
  String get aquariums;

  /// No description provided for @noAquariumsYet.
  ///
  /// In en, this message translates to:
  /// **'No aquariums yet.'**
  String get noAquariumsYet;

  /// No description provided for @makeActive.
  ///
  /// In en, this message translates to:
  /// **'Make active'**
  String get makeActive;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteTankTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteTankTitle(Object name);

  /// No description provided for @deleteTankBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the aquarium and all of its readings.'**
  String get deleteTankBody;

  /// No description provided for @newAquarium.
  ///
  /// In en, this message translates to:
  /// **'New aquarium'**
  String get newAquarium;

  /// No description provided for @editAquarium.
  ///
  /// In en, this message translates to:
  /// **'Edit aquarium'**
  String get editAquarium;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Living room reef'**
  String get nameHint;

  /// No description provided for @enterAName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterAName;

  /// No description provided for @setupType.
  ///
  /// In en, this message translates to:
  /// **'Setup type'**
  String get setupType;

  /// No description provided for @presetSeedNote.
  ///
  /// In en, this message translates to:
  /// **'Default parameters and zone boundaries will be set up for this setup type. You can fine-tune them anytime.'**
  String get presetSeedNote;

  /// No description provided for @volumeOptional.
  ///
  /// In en, this message translates to:
  /// **'Volume (optional)'**
  String get volumeOptional;

  /// No description provided for @vendorOptional.
  ///
  /// In en, this message translates to:
  /// **'Vendor (optional)'**
  String get vendorOptional;

  /// No description provided for @modelOptional.
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get modelOptional;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @createAquarium.
  ///
  /// In en, this message translates to:
  /// **'Create aquarium'**
  String get createAquarium;

  /// No description provided for @litersSuffix.
  ///
  /// In en, this message translates to:
  /// **'{value} L'**
  String litersSuffix(Object value);

  /// No description provided for @gallonsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{value} gal'**
  String gallonsSuffix(Object value);

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @setDate.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setDate;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @sinceDate.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String sinceDate(Object date);

  /// No description provided for @parameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get parameters;

  /// No description provided for @noActiveAquarium.
  ///
  /// In en, this message translates to:
  /// **'No active aquarium.'**
  String get noActiveAquarium;

  /// No description provided for @reapplyPreset.
  ///
  /// In en, this message translates to:
  /// **'Re-apply {type} preset'**
  String reapplyPreset(Object type);

  /// No description provided for @reapplyPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-apply {type} preset?'**
  String reapplyPresetTitle(Object type);

  /// No description provided for @reapplyPresetBody.
  ///
  /// In en, this message translates to:
  /// **'This overwrites the green/amber/red boundaries of all tracked parameters with the preset defaults. Your readings are kept.'**
  String get reapplyPresetBody;

  /// No description provided for @presetApplied.
  ///
  /// In en, this message translates to:
  /// **'Preset applied.'**
  String get presetApplied;

  /// No description provided for @noBoundariesSet.
  ///
  /// In en, this message translates to:
  /// **'No boundaries set'**
  String get noBoundariesSet;

  /// No description provided for @boundsSummary.
  ///
  /// In en, this message translates to:
  /// **'OK {greenLow}–{greenHigh} {unit}  •  red <{amberLow} / >{amberHigh}'**
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  );

  /// No description provided for @editZones.
  ///
  /// In en, this message translates to:
  /// **'Edit zones'**
  String get editZones;

  /// No description provided for @addParameter.
  ///
  /// In en, this message translates to:
  /// **'Add parameter'**
  String get addParameter;

  /// No description provided for @allParametersAdded.
  ///
  /// In en, this message translates to:
  /// **'All parameters are already added.'**
  String get allParametersAdded;

  /// No description provided for @unitWithValue.
  ///
  /// In en, this message translates to:
  /// **'Unit: {unit}'**
  String unitWithValue(Object unit);

  /// No description provided for @unitFromSettingsNote.
  ///
  /// In en, this message translates to:
  /// **'Set in Settings. Boundaries below use this unit.'**
  String get unitFromSettingsNote;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @boundAmberLow.
  ///
  /// In en, this message translates to:
  /// **'Red below (amber low)'**
  String get boundAmberLow;

  /// No description provided for @boundGreenLow.
  ///
  /// In en, this message translates to:
  /// **'Green from (OK low)'**
  String get boundGreenLow;

  /// No description provided for @boundGreenHigh.
  ///
  /// In en, this message translates to:
  /// **'Green to (OK high)'**
  String get boundGreenHigh;

  /// No description provided for @boundAmberHigh.
  ///
  /// In en, this message translates to:
  /// **'Red above (amber high)'**
  String get boundAmberHigh;

  /// No description provided for @boundsUnitNote.
  ///
  /// In en, this message translates to:
  /// **'Values are in {unit}. Leave a field blank to mean \"no limit on that side\".'**
  String boundsUnitNote(Object unit);

  /// No description provided for @enterANumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterANumber;

  /// No description provided for @boundsOrderError.
  ///
  /// In en, this message translates to:
  /// **'Boundaries must increase: amber low ≤ green low ≤ green high ≤ amber high.'**
  String get boundsOrderError;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @saveReadings.
  ///
  /// In en, this message translates to:
  /// **'Save readings'**
  String get saveReadings;

  /// No description provided for @invalidNumberFor.
  ///
  /// In en, this message translates to:
  /// **'Invalid number for {name}'**
  String invalidNumberFor(Object name);

  /// No description provided for @enterAtLeastOneValue.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one value.'**
  String get enterAtLeastOneValue;

  /// No description provided for @savedReadings.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} reading(s).'**
  String savedReadings(int count);

  /// No description provided for @noTrackedToRecord.
  ///
  /// In en, this message translates to:
  /// **'No tracked parameters to record.'**
  String get noTrackedToRecord;

  /// No description provided for @rangeWeek.
  ///
  /// In en, this message translates to:
  /// **'7d'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In en, this message translates to:
  /// **'30d'**
  String get rangeMonth;

  /// No description provided for @rangeQuarter.
  ///
  /// In en, this message translates to:
  /// **'90d'**
  String get rangeQuarter;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rangeAll;

  /// No description provided for @noReadingsInRange.
  ///
  /// In en, this message translates to:
  /// **'No readings in this range.'**
  String get noReadingsInRange;

  /// No description provided for @editMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Edit measurement'**
  String get editMeasurement;

  /// No description provided for @deleteMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement?'**
  String get deleteMeasurementTitle;

  /// No description provided for @deleteMeasurementBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes this value.'**
  String get deleteMeasurementBody;

  /// No description provided for @deleteTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement'**
  String get deleteTogetherTitle;

  /// No description provided for @deleteTogetherBody.
  ///
  /// In en, this message translates to:
  /// **'This value was entered together with {count} other measurement(s). Delete only this value, or all values entered together?'**
  String deleteTogetherBody(int count);

  /// No description provided for @deleteOnlyThis.
  ///
  /// In en, this message translates to:
  /// **'Only this value'**
  String get deleteOnlyThis;

  /// No description provided for @deleteAllTogether.
  ///
  /// In en, this message translates to:
  /// **'All together'**
  String get deleteAllTogether;

  /// No description provided for @editTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Update measurement time'**
  String get editTogetherTitle;

  /// No description provided for @editTogetherBody.
  ///
  /// In en, this message translates to:
  /// **'This value was entered together with {count} other measurement(s). Update the time for only this value, or all values entered together?'**
  String editTogetherBody(int count);

  /// No description provided for @ratioPo4No3Label.
  ///
  /// In en, this message translates to:
  /// **'PO₄ : NO₃'**
  String get ratioPo4No3Label;

  /// No description provided for @ratioPo4No3Title.
  ///
  /// In en, this message translates to:
  /// **'PO₄ : NO₃ ratio'**
  String get ratioPo4No3Title;

  /// No description provided for @ratioMgCaLabel.
  ///
  /// In en, this message translates to:
  /// **'Mg : Ca'**
  String get ratioMgCaLabel;

  /// No description provided for @ratioMgCaTitle.
  ///
  /// In en, this message translates to:
  /// **'Mg : Ca ratio'**
  String get ratioMgCaTitle;

  /// No description provided for @ratioCaAlkLabel.
  ///
  /// In en, this message translates to:
  /// **'Ca : Alk'**
  String get ratioCaAlkLabel;

  /// No description provided for @ratioCaAlkTitle.
  ///
  /// In en, this message translates to:
  /// **'Ca : Alk ratio'**
  String get ratioCaAlkTitle;

  /// No description provided for @ratioMgAlkLabel.
  ///
  /// In en, this message translates to:
  /// **'Mg : Alk'**
  String get ratioMgAlkLabel;

  /// No description provided for @ratioMgAlkTitle.
  ///
  /// In en, this message translates to:
  /// **'Mg : Alk ratio'**
  String get ratioMgAlkTitle;

  /// No description provided for @ratioNoData.
  ///
  /// In en, this message translates to:
  /// **'Record both parameters to see their ratio.'**
  String get ratioNoData;

  /// No description provided for @ratioBoundsNote.
  ///
  /// In en, this message translates to:
  /// **'Zone limits use {metric}, the value shown on the card.'**
  String ratioBoundsNote(Object metric);

  /// No description provided for @waterChanges.
  ///
  /// In en, this message translates to:
  /// **'Water changes'**
  String get waterChanges;

  /// No description provided for @recordWaterChange.
  ///
  /// In en, this message translates to:
  /// **'Record water change'**
  String get recordWaterChange;

  /// No description provided for @amountLitersOptional.
  ///
  /// In en, this message translates to:
  /// **'Amount (optional)'**
  String get amountLitersOptional;

  /// No description provided for @noWaterChanges.
  ///
  /// In en, this message translates to:
  /// **'No water changes yet.'**
  String get noWaterChanges;

  /// No description provided for @amountNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Amount not recorded'**
  String get amountNotRecorded;

  /// No description provided for @deleteWaterChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete water change?'**
  String get deleteWaterChangeTitle;

  /// No description provided for @deleteWaterChangeBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes this water change.'**
  String get deleteWaterChangeBody;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @noActions.
  ///
  /// In en, this message translates to:
  /// **'No actions yet.'**
  String get noActions;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get addAction;

  /// No description provided for @waterChange.
  ///
  /// In en, this message translates to:
  /// **'Water change'**
  String get waterChange;

  /// No description provided for @carbonChange.
  ///
  /// In en, this message translates to:
  /// **'Carbon change'**
  String get carbonChange;

  /// No description provided for @recordCarbonChange.
  ///
  /// In en, this message translates to:
  /// **'Record carbon change'**
  String get recordCarbonChange;

  /// No description provided for @weightOptional.
  ///
  /// In en, this message translates to:
  /// **'Weight (optional)'**
  String get weightOptional;

  /// No description provided for @weightNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Weight not recorded'**
  String get weightNotRecorded;

  /// No description provided for @gramsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String gramsSuffix(Object value);

  /// No description provided for @deleteCarbonChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete carbon change?'**
  String get deleteCarbonChangeTitle;

  /// No description provided for @deleteCarbonChangeBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes this carbon change.'**
  String get deleteCarbonChangeBody;

  /// No description provided for @equipmentCleaning.
  ///
  /// In en, this message translates to:
  /// **'Equipment cleaning'**
  String get equipmentCleaning;

  /// No description provided for @recordEquipmentCleaning.
  ///
  /// In en, this message translates to:
  /// **'Record equipment cleaning'**
  String get recordEquipmentCleaning;

  /// No description provided for @deleteEquipmentCleaningTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete equipment cleaning?'**
  String get deleteEquipmentCleaningTitle;

  /// No description provided for @deleteEquipmentCleaningBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes this equipment cleaning.'**
  String get deleteEquipmentCleaningBody;

  /// No description provided for @dosing.
  ///
  /// In en, this message translates to:
  /// **'Dosing'**
  String get dosing;

  /// No description provided for @addSupplement.
  ///
  /// In en, this message translates to:
  /// **'Add supplement'**
  String get addSupplement;

  /// No description provided for @noDosing.
  ///
  /// In en, this message translates to:
  /// **'No supplements yet.'**
  String get noDosing;

  /// No description provided for @noDosingHint.
  ///
  /// In en, this message translates to:
  /// **'Add the supplements you dose this tank — vendor, product, and optionally dosage and schedule.'**
  String get noDosingHint;

  /// No description provided for @dosingNoDosage.
  ///
  /// In en, this message translates to:
  /// **'No dosage set'**
  String get dosingNoDosage;

  /// No description provided for @deleteDosingTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove supplement?'**
  String get deleteDosingTitle;

  /// No description provided for @deleteDosingBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this supplement from the dosing plan.'**
  String get deleteDosingBody;

  /// No description provided for @dosingNew.
  ///
  /// In en, this message translates to:
  /// **'Add supplement'**
  String get dosingNew;

  /// No description provided for @dosingEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit supplement'**
  String get dosingEdit;

  /// No description provided for @dosingVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get dosingVendor;

  /// No description provided for @dosingVendorName.
  ///
  /// In en, this message translates to:
  /// **'Vendor name'**
  String get dosingVendorName;

  /// No description provided for @dosingProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get dosingProduct;

  /// No description provided for @dosingProductName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get dosingProductName;

  /// No description provided for @dosingElement.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get dosingElement;

  /// No description provided for @dosingElementNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get dosingElementNone;

  /// No description provided for @dosingCustom.
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get dosingCustom;

  /// No description provided for @dosingDosageOptional.
  ///
  /// In en, this message translates to:
  /// **'Dosage (optional)'**
  String get dosingDosageOptional;

  /// No description provided for @dosingAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get dosingAmount;

  /// No description provided for @dosingUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get dosingUnit;

  /// No description provided for @dosingBasis.
  ///
  /// In en, this message translates to:
  /// **'Basis'**
  String get dosingBasis;

  /// No description provided for @dosingPerDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get dosingPerDay;

  /// No description provided for @dosingPerDose.
  ///
  /// In en, this message translates to:
  /// **'per dose'**
  String get dosingPerDose;

  /// No description provided for @dosingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get dosingSchedule;

  /// No description provided for @dosingFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get dosingFrequency;

  /// No description provided for @dosingFreqNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get dosingFreqNone;

  /// No description provided for @dosingFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dosingFreqDaily;

  /// No description provided for @dosingFreqEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get dosingFreqEveryNDays;

  /// No description provided for @dosingFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get dosingFreqWeekly;

  /// No description provided for @dosingIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'Interval (days)'**
  String get dosingIntervalDays;

  /// No description provided for @dosingEveryDaysN.
  ///
  /// In en, this message translates to:
  /// **'Every {n} days'**
  String dosingEveryDaysN(Object n);

  /// No description provided for @dosingTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get dosingTimeOptional;

  /// No description provided for @unitsSection.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitsSection;

  /// No description provided for @toolsSection.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsSection;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @salinity.
  ///
  /// In en, this message translates to:
  /// **'Salinity'**
  String get salinity;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @unitUsedAcrossApp.
  ///
  /// In en, this message translates to:
  /// **'Unit used across the app'**
  String get unitUsedAcrossApp;

  /// No description provided for @salinityCalculator.
  ///
  /// In en, this message translates to:
  /// **'Salinity calculator'**
  String get salinityCalculator;

  /// No description provided for @salinityCalculatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert ppt ↔ specific gravity (SG)'**
  String get salinityCalculatorSubtitle;

  /// No description provided for @backupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupSection;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExport;

  /// No description provided for @backupExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save all aquariums and readings to a file'**
  String get backupExportSubtitle;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupImport;

  /// No description provided for @backupImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all data with a backup file'**
  String get backupImportSubtitle;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces all current aquariums, parameters, and readings with the contents of the backup file. This cannot be undone.'**
  String get backupRestoreConfirmBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the backup'**
  String get backupExportFailed;

  /// No description provided for @backupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the backup'**
  String get backupImportFailed;

  /// No description provided for @backupInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a valid ReefTracker backup'**
  String get backupInvalidFile;

  /// No description provided for @autoBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get autoBackupTitle;

  /// No description provided for @autoBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep recent copies of your data on this device'**
  String get autoBackupSubtitle;

  /// No description provided for @autoBackupFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get autoBackupFrequency;

  /// No description provided for @autoBackupDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get autoBackupDaily;

  /// No description provided for @autoBackupWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get autoBackupWeekly;

  /// No description provided for @manageBackups.
  ///
  /// In en, this message translates to:
  /// **'Manage backups'**
  String get manageBackups;

  /// No description provided for @manageBackupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View, restore, or share automatic backups'**
  String get manageBackupsSubtitle;

  /// No description provided for @backupsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get backupsScreenTitle;

  /// No description provided for @noAutoBackups.
  ///
  /// In en, this message translates to:
  /// **'No automatic backups yet'**
  String get noAutoBackups;

  /// No description provided for @noAutoBackupsHint.
  ///
  /// In en, this message translates to:
  /// **'A backup is saved automatically while you use the app.'**
  String get noAutoBackupsHint;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @backupDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backup?'**
  String get backupDeleteConfirmTitle;

  /// No description provided for @backupDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes this backup file from your device.'**
  String get backupDeleteConfirmBody;

  /// No description provided for @aboutAppName.
  ///
  /// In en, this message translates to:
  /// **'About ReefTracker'**
  String get aboutAppName;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Offline reef aquarium parameter tracker with history, time graphs, and green/amber/red health zones.'**
  String get aboutDescription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageCzech.
  ///
  /// In en, this message translates to:
  /// **'Čeština'**
  String get languageCzech;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polski'**
  String get languagePolish;

  /// No description provided for @calculatorIntro.
  ///
  /// In en, this message translates to:
  /// **'Convert between practical salinity (ppt) and specific gravity (SG). Type in either field.'**
  String get calculatorIntro;

  /// No description provided for @specificGravity.
  ///
  /// In en, this message translates to:
  /// **'Specific gravity'**
  String get specificGravity;

  /// No description provided for @referencePoints.
  ///
  /// In en, this message translates to:
  /// **'Reference points'**
  String get referencePoints;

  /// No description provided for @refSeawater.
  ///
  /// In en, this message translates to:
  /// **'• Natural seawater ≈ 35 ppt ≈ 1.0264 SG'**
  String get refSeawater;

  /// No description provided for @refReefTarget.
  ///
  /// In en, this message translates to:
  /// **'• Typical reef target ≈ 35 ppt (1.025–1.027 SG)'**
  String get refReefTarget;

  /// No description provided for @refFormulaNote.
  ///
  /// In en, this message translates to:
  /// **'SG is referenced at 25 °C. Conversion is a linear approximation: SG = 1 + ppt × 0.0264/35.'**
  String get refFormulaNote;

  /// No description provided for @doseCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Dose calculator'**
  String get doseCalcTitle;

  /// No description provided for @doseCalcIntro.
  ///
  /// In en, this message translates to:
  /// **'Estimate how fast your tank consumes an element and the daily dose that holds it steady. Water changes are not considered.'**
  String get doseCalcIntro;

  /// No description provided for @doseCalcElement.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get doseCalcElement;

  /// No description provided for @doseCalcWindow.
  ///
  /// In en, this message translates to:
  /// **'Measurement window'**
  String get doseCalcWindow;

  /// No description provided for @doseCalcReadings.
  ///
  /// In en, this message translates to:
  /// **'{count} readings in range'**
  String doseCalcReadings(Object count);

  /// No description provided for @doseCalcVolume.
  ///
  /// In en, this message translates to:
  /// **'Tank volume'**
  String get doseCalcVolume;

  /// No description provided for @doseCalcCurrentDose.
  ///
  /// In en, this message translates to:
  /// **'Current daily dose'**
  String get doseCalcCurrentDose;

  /// No description provided for @doseCalcPerDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get doseCalcPerDay;

  /// No description provided for @doseCalcPotencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplement strength'**
  String get doseCalcPotencyTitle;

  /// No description provided for @doseCalcPotencyFromCatalog.
  ///
  /// In en, this message translates to:
  /// **'Using the catalog\'s strength for this product.'**
  String get doseCalcPotencyFromCatalog;

  /// No description provided for @doseCalcEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get doseCalcEnterManually;

  /// No description provided for @doseCalcUseCatalog.
  ///
  /// In en, this message translates to:
  /// **'Use catalog value'**
  String get doseCalcUseCatalog;

  /// No description provided for @doseCalcRefAmount.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get doseCalcRefAmount;

  /// No description provided for @doseCalcRefVolume.
  ///
  /// In en, this message translates to:
  /// **'Per volume'**
  String get doseCalcRefVolume;

  /// No description provided for @doseCalcRise.
  ///
  /// In en, this message translates to:
  /// **'Raises by'**
  String get doseCalcRise;

  /// No description provided for @doseCalcRaises.
  ///
  /// In en, this message translates to:
  /// **'≈ {detail}'**
  String doseCalcRaises(Object detail);

  /// No description provided for @doseCalcResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get doseCalcResultsTitle;

  /// No description provided for @doseCalcObservedChange.
  ///
  /// In en, this message translates to:
  /// **'Measured change'**
  String get doseCalcObservedChange;

  /// No description provided for @doseCalcConsumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get doseCalcConsumption;

  /// No description provided for @doseCalcCurrentInput.
  ///
  /// In en, this message translates to:
  /// **'Current dosing adds'**
  String get doseCalcCurrentInput;

  /// No description provided for @doseCalcSuggestedDose.
  ///
  /// In en, this message translates to:
  /// **'Suggested daily dose'**
  String get doseCalcSuggestedDose;

  /// No description provided for @doseCalcAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get doseCalcAdjustment;

  /// No description provided for @doseCalcStable.
  ///
  /// In en, this message translates to:
  /// **'Your current dose holds this element steady — keep it.'**
  String get doseCalcStable;

  /// No description provided for @doseCalcIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase the dose to keep this element steady.'**
  String get doseCalcIncrease;

  /// No description provided for @doseCalcDecrease.
  ///
  /// In en, this message translates to:
  /// **'You can lower the dose and still hold this element steady.'**
  String get doseCalcDecrease;

  /// No description provided for @doseCalcOverdosing.
  ///
  /// In en, this message translates to:
  /// **'This element is rising — reduce or pause dosing.'**
  String get doseCalcOverdosing;

  /// No description provided for @doseCalcNeedsPotency.
  ///
  /// In en, this message translates to:
  /// **'Enter the supplement strength to get a dose recommendation.'**
  String get doseCalcNeedsPotency;

  /// No description provided for @doseCalcInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Add at least two measurements on different days and a tank volume to calculate.'**
  String get doseCalcInsufficient;

  /// No description provided for @trendSection.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendSection;

  /// No description provided for @trendShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show trends'**
  String get trendShowTitle;

  /// No description provided for @trendShowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project where each parameter is heading and when it will leave its range'**
  String get trendShowSubtitle;

  /// No description provided for @trendWindow.
  ///
  /// In en, this message translates to:
  /// **'Readings used'**
  String get trendWindow;

  /// No description provided for @trendWindowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many recent readings define the trend'**
  String get trendWindowSubtitle;

  /// No description provided for @trendTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent trend'**
  String get trendTitle;

  /// No description provided for @trendRatePerDay.
  ///
  /// In en, this message translates to:
  /// **'{rate}/day'**
  String trendRatePerDay(Object rate);

  /// No description provided for @trendFlat.
  ///
  /// In en, this message translates to:
  /// **'Holding steady'**
  String get trendFlat;

  /// No description provided for @trendWithinRange.
  ///
  /// In en, this message translates to:
  /// **'Staying within range at this rate'**
  String get trendWithinRange;

  /// No description provided for @trendAmberInDays.
  ///
  /// In en, this message translates to:
  /// **'Reaches attention zone in ~{days} d'**
  String trendAmberInDays(int days);

  /// No description provided for @trendRedInDays.
  ///
  /// In en, this message translates to:
  /// **'Reaches critical zone in ~{days} d'**
  String trendRedInDays(int days);

  /// No description provided for @trendChipAmber.
  ///
  /// In en, this message translates to:
  /// **'Attention ~{days} d'**
  String trendChipAmber(int days);

  /// No description provided for @trendChipRed.
  ///
  /// In en, this message translates to:
  /// **'Act now ~{days} d'**
  String trendChipRed(int days);

  /// No description provided for @trendHorizon.
  ///
  /// In en, this message translates to:
  /// **'Alert horizon'**
  String get trendHorizon;

  /// No description provided for @trendHorizonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flag a parameter only when it will leave its range within this time'**
  String get trendHorizonSubtitle;

  /// No description provided for @trendHorizonDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String trendHorizonDays(int days);

  /// No description provided for @zoneOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get zoneOk;

  /// No description provided for @zoneAttention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get zoneAttention;

  /// No description provided for @zoneActNow.
  ///
  /// In en, this message translates to:
  /// **'Act now'**
  String get zoneActNow;

  /// No description provided for @zoneUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get zoneUnknown;

  /// No description provided for @setupFishOnly.
  ///
  /// In en, this message translates to:
  /// **'Fish-only / FOWLR'**
  String get setupFishOnly;

  /// No description provided for @setupSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft coral'**
  String get setupSoft;

  /// No description provided for @setupLps.
  ///
  /// In en, this message translates to:
  /// **'LPS'**
  String get setupLps;

  /// No description provided for @setupSps.
  ///
  /// In en, this message translates to:
  /// **'SPS'**
  String get setupSps;

  /// No description provided for @setupMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed reef'**
  String get setupMixed;

  /// No description provided for @paramTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get paramTemperature;

  /// No description provided for @paramPh.
  ///
  /// In en, this message translates to:
  /// **'pH'**
  String get paramPh;

  /// No description provided for @paramSalinity.
  ///
  /// In en, this message translates to:
  /// **'Salinity'**
  String get paramSalinity;

  /// No description provided for @paramAlkalinity.
  ///
  /// In en, this message translates to:
  /// **'Alkalinity'**
  String get paramAlkalinity;

  /// No description provided for @paramCalcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium (Ca)'**
  String get paramCalcium;

  /// No description provided for @paramMagnesium.
  ///
  /// In en, this message translates to:
  /// **'Magnesium (Mg)'**
  String get paramMagnesium;

  /// No description provided for @paramNitrate.
  ///
  /// In en, this message translates to:
  /// **'Nitrate (NO₃)'**
  String get paramNitrate;

  /// No description provided for @paramPhosphate.
  ///
  /// In en, this message translates to:
  /// **'Phosphate (PO₄)'**
  String get paramPhosphate;

  /// No description provided for @paramAmmonia.
  ///
  /// In en, this message translates to:
  /// **'Ammonia (NH₃/₄)'**
  String get paramAmmonia;

  /// No description provided for @paramNitrite.
  ///
  /// In en, this message translates to:
  /// **'Nitrite (NO₂)'**
  String get paramNitrite;

  /// No description provided for @paramOrp.
  ///
  /// In en, this message translates to:
  /// **'ORP'**
  String get paramOrp;

  /// No description provided for @paramPotassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get paramPotassium;

  /// No description provided for @paramStrontium.
  ///
  /// In en, this message translates to:
  /// **'Strontium'**
  String get paramStrontium;

  /// No description provided for @paramIodine.
  ///
  /// In en, this message translates to:
  /// **'Iodine'**
  String get paramIodine;

  /// No description provided for @helpTemperature.
  ///
  /// In en, this message translates to:
  /// **'Water temperature. Stability matters more than the exact value.'**
  String get helpTemperature;

  /// No description provided for @helpSalinity.
  ///
  /// In en, this message translates to:
  /// **'Specific gravity. ~1.026 SG ≈ 35 ppt.'**
  String get helpSalinity;

  /// No description provided for @helpAlkalinity.
  ///
  /// In en, this message translates to:
  /// **'Carbonate hardness. Keep stable — avoid swings.'**
  String get helpAlkalinity;

  /// No description provided for @helpNitrate.
  ///
  /// In en, this message translates to:
  /// **'A nutrient. Corals need a little; too much fuels algae.'**
  String get helpNitrate;

  /// No description provided for @helpAmmonia.
  ///
  /// In en, this message translates to:
  /// **'Toxic. Should read effectively zero in a cycled tank.'**
  String get helpAmmonia;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'de', 'en', 'pl', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
