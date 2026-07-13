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

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @tourTankTitle.
  ///
  /// In en, this message translates to:
  /// **'Your aquariums'**
  String get tourTankTitle;

  /// No description provided for @tourTankDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap here to switch between aquariums or add a new one.'**
  String get tourTankDesc;

  /// No description provided for @tourCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare view'**
  String get tourCompareTitle;

  /// No description provided for @tourCompareDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch between the parameter cards and stacked comparison graphs.'**
  String get tourCompareDesc;

  /// No description provided for @tourParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage parameters'**
  String get tourParamsTitle;

  /// No description provided for @tourParamsDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose which water parameters to track and set their target ranges.'**
  String get tourParamsDesc;

  /// No description provided for @tourDosingHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Dosing history'**
  String get tourDosingHistoryTitle;

  /// No description provided for @tourDosingHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Review every past and current dose period, and remove a record entered by mistake.'**
  String get tourDosingHistoryDesc;

  /// No description provided for @tourDoseCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Dose calculator'**
  String get tourDoseCalcTitle;

  /// No description provided for @tourDoseCalcDesc.
  ///
  /// In en, this message translates to:
  /// **'On the Dosing tab, open the calculator to estimate the daily dose that keeps an element steady.'**
  String get tourDoseCalcDesc;

  /// No description provided for @tourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// No description provided for @tourDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tourDone;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// No description provided for @replayTour.
  ///
  /// In en, this message translates to:
  /// **'Replay tour'**
  String get replayTour;

  /// No description provided for @replayTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the top-bar tips again'**
  String get replayTourSubtitle;

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

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

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

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @itemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get itemDeleted;

  /// Semantic label for list drag handles (screen readers).
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @errorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWith(Object message);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String saveFailed(Object error);

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

  /// Badge label marking the currently active aquarium in the list.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

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

  /// SnackBar shown after deleting an aquarium; paired with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String tankDeleted(Object name);

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
  /// **'This overwrites the green/amber/red boundaries of all tracked parameters: dashboard parameters get the aquarium-type preset values, microelements their built-in defaults. Your readings are kept.'**
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

  /// No description provided for @boundsPairError.
  ///
  /// In en, this message translates to:
  /// **'Each amber boundary needs its matching green boundary on the same side.'**
  String get boundsPairError;

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

  /// No description provided for @invalidVolume.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid positive volume.'**
  String get invalidVolume;

  /// No description provided for @invalidPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number.'**
  String get invalidPositiveNumber;

  /// No description provided for @invalidIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of days (1 or more).'**
  String get invalidIntervalDays;

  /// SnackBar shown when a reading is below the parameter's hard physical floor (e.g. a negative concentration).
  ///
  /// In en, this message translates to:
  /// **'{name}: this value is not physically possible.'**
  String impossibleValueFor(Object name);

  /// No description provided for @impossibleValue.
  ///
  /// In en, this message translates to:
  /// **'This value is not physically possible.'**
  String get impossibleValue;

  /// No description provided for @implausibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Unusual values'**
  String get implausibleTitle;

  /// No description provided for @implausibleIntro.
  ///
  /// In en, this message translates to:
  /// **'The following is outside the typical range. Check for a typo before saving.'**
  String get implausibleIntro;

  /// One line per suspicious reading in the confirmation dialog. value/max include the unit label, min is a bare number.
  ///
  /// In en, this message translates to:
  /// **'{name}: {value} (typical {min}–{max})'**
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  );

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @enterAtLeastOneValue.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one value.'**
  String get enterAtLeastOneValue;

  /// No description provided for @savedReadings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Saved 1 reading.} other{Saved {count} readings.}}'**
  String savedReadings(int count);

  /// No description provided for @noTrackedToRecord.
  ///
  /// In en, this message translates to:
  /// **'No tracked parameters to record.'**
  String get noTrackedToRecord;

  /// Chip on the Add Reading screen that shows every enabled parameter (no test-set filter).
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get testSetAll;

  /// No description provided for @newTestSet.
  ///
  /// In en, this message translates to:
  /// **'New test set'**
  String get newTestSet;

  /// No description provided for @editTestSet.
  ///
  /// In en, this message translates to:
  /// **'Edit test set'**
  String get editTestSet;

  /// No description provided for @manageTestSets.
  ///
  /// In en, this message translates to:
  /// **'Manage test sets'**
  String get manageTestSets;

  /// Hint text for the test-set name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Weekly big test'**
  String get testSetNameHint;

  /// No description provided for @testSetNeedParam.
  ///
  /// In en, this message translates to:
  /// **'Select at least one parameter.'**
  String get testSetNeedParam;

  /// No description provided for @deleteTestSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteTestSetTitle(Object name);

  /// No description provided for @deleteTestSetBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the test set. Your readings are kept.'**
  String get deleteTestSetBody;

  /// No description provided for @testSetEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'This test set has no enabled parameters. Edit it, or switch to All.'**
  String get testSetEmptyHint;

  /// Subtitle in the manage sheet: how many enabled parameters a test set shows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 parameter} other{{count} parameters}}'**
  String testSetParamCount(int count);

  /// No description provided for @noTestSets.
  ///
  /// In en, this message translates to:
  /// **'No test sets yet. A test set records just the parameters you test together.'**
  String get noTestSets;

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

  /// No description provided for @deleteTogetherTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement'**
  String get deleteTogetherTitle;

  /// No description provided for @deleteTogetherBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{This value was entered together with 1 other measurement. Delete only this value, or all values entered together?} other{This value was entered together with {count} other measurements. Delete only this value, or all values entered together?}}'**
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
  /// **'{count, plural, one{This value was entered together with 1 other measurement. Update the time for only this value, or all values entered together?} other{This value was entered together with {count} other measurements. Update the time for only this value, or all values entered together?}}'**
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

  /// Bare unit symbol for grams, used as an input-field suffix.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get gramSymbol;

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

  /// SnackBar shown after stopping a supplement; paired with an Undo action. The entry moves to dosing history.
  ///
  /// In en, this message translates to:
  /// **'Supplement stopped'**
  String get supplementStopped;

  /// No description provided for @dosingHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Dosing history'**
  String get dosingHistoryTitle;

  /// No description provided for @dosingHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No dosing history yet.'**
  String get dosingHistoryEmpty;

  /// No description provided for @dosingHistoryCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get dosingHistoryCurrent;

  /// No description provided for @dosingHistorySince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String dosingHistorySince(Object date);

  /// No description provided for @dosingHistoryPeriod.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String dosingHistoryPeriod(Object from, Object to);

  /// No description provided for @deleteDosingRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get deleteDosingRecordTitle;

  /// No description provided for @deleteDosingRecordBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes this dosing record from history and the dose calculation. It can\'t be undone.'**
  String get deleteDosingRecordBody;

  /// No description provided for @deleteDosingRecordNotLatest.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t the most recent record for this element; deleting it won\'t change later records.'**
  String get deleteDosingRecordNotLatest;

  /// Chip on a dosing-history tile marking a logged one-off manual dose.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get dosingHistoryManual;

  /// No description provided for @manualDoseNew.
  ///
  /// In en, this message translates to:
  /// **'Log manual dose'**
  String get manualDoseNew;

  /// No description provided for @manualDoseEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit manual dose'**
  String get manualDoseEdit;

  /// No description provided for @deleteManualDoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete manual dose?'**
  String get deleteManualDoseTitle;

  /// No description provided for @deleteManualDoseBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes this logged dose from history and the dose calculation. It can\'t be undone.'**
  String get deleteManualDoseBody;

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
  /// **'{n, plural, one{Every day} other{Every {n} days}}'**
  String dosingEveryDaysN(int n);

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

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// Subtitle showing when the most recent backup completed.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {when}'**
  String backupLastRun(String when);

  /// No description provided for @backupNeverRun.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupNeverRun;

  /// Warning row in Settings shown while the most recent backup attempt (automatic or manual) failed; cleared by the next successful backup.
  ///
  /// In en, this message translates to:
  /// **'Last backup failed on {when}'**
  String backupLastFailed(String when);

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupDone;

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

  /// No description provided for @csvExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export measurements (CSV)'**
  String get csvExportTitle;

  /// No description provided for @csvExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the active aquarium\'s measurements as a spreadsheet file'**
  String get csvExportSubtitle;

  /// Shown when the CSV export is tapped but the active aquarium has no measurements (or no aquarium exists).
  ///
  /// In en, this message translates to:
  /// **'No measurements to export yet'**
  String get csvExportNoData;

  /// No description provided for @csvExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the measurements'**
  String get csvExportFailed;

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
  /// **'This replaces ALL your aquarium data — every aquarium, parameter, and reading — with the contents of the backup file. Your settings on this device (language, units, and preferences) are kept. This cannot be undone.'**
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

  /// Shown when the local "Back up now" write fails (distinct from a failed export/share).
  ///
  /// In en, this message translates to:
  /// **'Could not save the backup'**
  String get backupNowFailed;

  /// No description provided for @backupShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share the backup'**
  String get backupShareFailed;

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

  /// No description provided for @backupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of the app and can\'t be restored here'**
  String get backupTooNew;

  /// No description provided for @backupCorrupted.
  ///
  /// In en, this message translates to:
  /// **'The backup file is damaged or incomplete'**
  String get backupCorrupted;

  /// No description provided for @backupInconsistent.
  ///
  /// In en, this message translates to:
  /// **'The backup is inconsistent and can\'t be restored'**
  String get backupInconsistent;

  /// SnackBar shown when a database query fails; without it the affected screen would just look empty.
  ///
  /// In en, this message translates to:
  /// **'Some data failed to load. If this keeps happening, restart the app or restore a backup.'**
  String get dataLoadFailed;

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

  /// File size in bytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String sizeBytes(Object size);

  /// File size in kilobytes; size is already locale-formatted.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(Object size);

  /// File size in megabytes; size is already locale-formatted.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(Object size);

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
  /// **'{count, plural, one{1 reading in range} other{{count} readings in range}}'**
  String doseCalcReadings(int count);

  /// No description provided for @doseCalcDoseChanged.
  ///
  /// In en, this message translates to:
  /// **'Dose changed on {date}; readings before then reflect a different dose.'**
  String doseCalcDoseChanged(Object date);

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

  /// Optional input: total amount of one-time/extra manual doses of the supplement given during the measurement window.
  ///
  /// In en, this message translates to:
  /// **'Manual dose in window'**
  String get doseCalcManualDose;

  /// No description provided for @doseCalcManualDoseHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional: total of one-time or extra doses given during the measurement window. When empty, logged manual doses are used.'**
  String get doseCalcManualDoseHelp;

  /// Result row label: element rise per day contributed by the one-off manual doses.
  ///
  /// In en, this message translates to:
  /// **'Manual doses add'**
  String get doseCalcManualInput;

  /// Caption under the manual-dose field: how many logged doses fall in the window and their total.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 logged dose in window: {total}} other{{count} logged doses in window: {total}}}'**
  String doseCalcLoggedDoses(int count, Object total);

  /// No description provided for @doseCalcLoggedUnitMismatch.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 logged dose uses a different unit and is not included.} other{{count} logged doses use a different unit and are not included.}}'**
  String doseCalcLoggedUnitMismatch(int count);

  /// No description provided for @doseCalcLoggedProductMismatch.
  ///
  /// In en, this message translates to:
  /// **'Some logged doses are a different product — their strength may differ from the one entered above.'**
  String get doseCalcLoggedProductMismatch;

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

  /// No description provided for @doseCalcNoDoseNeeded.
  ///
  /// In en, this message translates to:
  /// **'Nothing is dosed and this element isn\'t falling — no dose is needed.'**
  String get doseCalcNoDoseNeeded;

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

  /// Settings subtitle for the trend window size. {days} is kTrendMinSpanDays, the minimum time span the fitted readings cover.
  ///
  /// In en, this message translates to:
  /// **'How many recent readings define the trend; widened to cover at least {days} days when you measure more often'**
  String trendWindowSubtitle(int days);

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

  /// Positive history-card trend line for a value that is out of range but heading back toward its green range.
  ///
  /// In en, this message translates to:
  /// **'Recovering — back in range in ~{days} d'**
  String trendBackInRangeDays(int days);

  /// Compact dashboard chip for a recovering value; {days} is the estimate until it is back in its green range.
  ///
  /// In en, this message translates to:
  /// **'Recovering ~{days} d'**
  String trendChipRecovering(int days);

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
  /// **'Potassium (K)'**
  String get paramPotassium;

  /// No description provided for @paramStrontium.
  ///
  /// In en, this message translates to:
  /// **'Strontium (Sr)'**
  String get paramStrontium;

  /// No description provided for @paramIodine.
  ///
  /// In en, this message translates to:
  /// **'Iodine (I)'**
  String get paramIodine;

  /// No description provided for @paramIron.
  ///
  /// In en, this message translates to:
  /// **'Iron (Fe)'**
  String get paramIron;

  /// No description provided for @paramSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium (Na)'**
  String get paramSodium;

  /// No description provided for @paramSulfur.
  ///
  /// In en, this message translates to:
  /// **'Sulfur (S)'**
  String get paramSulfur;

  /// No description provided for @paramBoron.
  ///
  /// In en, this message translates to:
  /// **'Boron (B)'**
  String get paramBoron;

  /// No description provided for @paramBromine.
  ///
  /// In en, this message translates to:
  /// **'Bromine (Br)'**
  String get paramBromine;

  /// No description provided for @paramSilicon.
  ///
  /// In en, this message translates to:
  /// **'Silicon (Si)'**
  String get paramSilicon;

  /// No description provided for @paramZinc.
  ///
  /// In en, this message translates to:
  /// **'Zinc (Zn)'**
  String get paramZinc;

  /// No description provided for @paramVanadium.
  ///
  /// In en, this message translates to:
  /// **'Vanadium (V)'**
  String get paramVanadium;

  /// No description provided for @paramCopper.
  ///
  /// In en, this message translates to:
  /// **'Copper (Cu)'**
  String get paramCopper;

  /// No description provided for @paramNickel.
  ///
  /// In en, this message translates to:
  /// **'Nickel (Ni)'**
  String get paramNickel;

  /// No description provided for @paramManganese.
  ///
  /// In en, this message translates to:
  /// **'Manganese (Mn)'**
  String get paramManganese;

  /// No description provided for @paramMolybdenum.
  ///
  /// In en, this message translates to:
  /// **'Molybdenum (Mo)'**
  String get paramMolybdenum;

  /// No description provided for @paramChromium.
  ///
  /// In en, this message translates to:
  /// **'Chromium (Cr)'**
  String get paramChromium;

  /// No description provided for @paramCobalt.
  ///
  /// In en, this message translates to:
  /// **'Cobalt (Co)'**
  String get paramCobalt;

  /// No description provided for @paramLithium.
  ///
  /// In en, this message translates to:
  /// **'Lithium (Li)'**
  String get paramLithium;

  /// No description provided for @paramBarium.
  ///
  /// In en, this message translates to:
  /// **'Barium (Ba)'**
  String get paramBarium;

  /// No description provided for @paramSelenium.
  ///
  /// In en, this message translates to:
  /// **'Selenium (Se)'**
  String get paramSelenium;

  /// No description provided for @paramAluminium.
  ///
  /// In en, this message translates to:
  /// **'Aluminium (Al)'**
  String get paramAluminium;

  /// No description provided for @paramAntimony.
  ///
  /// In en, this message translates to:
  /// **'Antimony (Sb)'**
  String get paramAntimony;

  /// No description provided for @paramTin.
  ///
  /// In en, this message translates to:
  /// **'Tin (Sn)'**
  String get paramTin;

  /// No description provided for @paramBeryllium.
  ///
  /// In en, this message translates to:
  /// **'Beryllium (Be)'**
  String get paramBeryllium;

  /// No description provided for @paramSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver (Ag)'**
  String get paramSilver;

  /// No description provided for @paramTungsten.
  ///
  /// In en, this message translates to:
  /// **'Tungsten (W)'**
  String get paramTungsten;

  /// No description provided for @paramLanthanum.
  ///
  /// In en, this message translates to:
  /// **'Lanthanum (La)'**
  String get paramLanthanum;

  /// No description provided for @paramTitanium.
  ///
  /// In en, this message translates to:
  /// **'Titanium (Ti)'**
  String get paramTitanium;

  /// No description provided for @paramZirconium.
  ///
  /// In en, this message translates to:
  /// **'Zirconium (Zr)'**
  String get paramZirconium;

  /// No description provided for @paramArsenic.
  ///
  /// In en, this message translates to:
  /// **'Arsenic (As)'**
  String get paramArsenic;

  /// No description provided for @paramCadmium.
  ///
  /// In en, this message translates to:
  /// **'Cadmium (Cd)'**
  String get paramCadmium;

  /// No description provided for @paramMercury.
  ///
  /// In en, this message translates to:
  /// **'Mercury (Hg)'**
  String get paramMercury;

  /// No description provided for @paramLead.
  ///
  /// In en, this message translates to:
  /// **'Lead (Pb)'**
  String get paramLead;

  /// Title of the microelement (ICP trace element) panel screen and its dashboard tile (U17).
  ///
  /// In en, this message translates to:
  /// **'Microelements'**
  String get microTitle;

  /// No description provided for @microSectionMajor.
  ///
  /// In en, this message translates to:
  /// **'Major elements'**
  String get microSectionMajor;

  /// No description provided for @microSectionTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace elements'**
  String get microSectionTrace;

  /// No description provided for @microSectionContaminants.
  ///
  /// In en, this message translates to:
  /// **'Contaminants'**
  String get microSectionContaminants;

  /// Subtitle of a microelement row that has no reading yet.
  ///
  /// In en, this message translates to:
  /// **'Not measured'**
  String get microNotMeasured;

  /// No description provided for @microEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Track trace elements from home test kits or ICP lab reports.'**
  String get microEmptyHint;

  /// No description provided for @microAllOk.
  ///
  /// In en, this message translates to:
  /// **'All within range'**
  String get microAllOk;

  /// Headline when some measured microelements are outside their green range.
  ///
  /// In en, this message translates to:
  /// **'{count} out of range'**
  String microOutOfRangeN(int count);

  /// Newest microelement sample date on the panel header.
  ///
  /// In en, this message translates to:
  /// **'Last measured {date}'**
  String microLastMeasured(String date);

  /// No description provided for @microAddMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Add measurements'**
  String get microAddMeasurements;

  /// No description provided for @microAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Microelement measurements'**
  String get microAddTitle;

  /// Entry-form filter chip: only the elements home test kits exist for (iodine, iron, strontium).
  ///
  /// In en, this message translates to:
  /// **'Hobby kit'**
  String get microChipHobby;

  /// Entry-form filter chip: the whole ICP element panel, for typing in a lab report.
  ///
  /// In en, this message translates to:
  /// **'Full ICP'**
  String get microChipFullIcp;

  /// No description provided for @microReminderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test reminder'**
  String get microReminderTooltip;

  /// No description provided for @microReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Microelement test reminder'**
  String get microReminderTitle;

  /// No description provided for @microReminderHint.
  ///
  /// In en, this message translates to:
  /// **'Adds a maintenance task reminding you to test microelements regularly.'**
  String get microReminderHint;

  /// No description provided for @microReminderCreated.
  ///
  /// In en, this message translates to:
  /// **'Reminder added to the maintenance schedule'**
  String get microReminderCreated;

  /// Title of the maintenance task created by the microelement test reminder shortcut (stored as the task's name).
  ///
  /// In en, this message translates to:
  /// **'Microelement test (ICP)'**
  String get microIcpTaskTitle;

  /// Subtitle of the Settings switch for the microelements feature (U17). Off only hides the panel; stored measurements are untouched.
  ///
  /// In en, this message translates to:
  /// **'Show on the Measurements tab, with test reminders. Hiding keeps your measurements.'**
  String get microToggleSubtitle;

  /// Chip label of the built-in microelement view showing every catalog element. Lab preset names (Fauna Marin ICP) are proper nouns and not localized.
  ///
  /// In en, this message translates to:
  /// **'Full list'**
  String get microViewFull;

  /// No description provided for @microViewNew.
  ///
  /// In en, this message translates to:
  /// **'New view'**
  String get microViewNew;

  /// No description provided for @microViewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit view'**
  String get microViewEdit;

  /// No description provided for @microViewManage.
  ///
  /// In en, this message translates to:
  /// **'Manage views'**
  String get microViewManage;

  /// App-bar action tooltip on the Microelements screen and title of the screen it opens: the list of all catalog elements where each row opens the standard zone-bounds editor.
  ///
  /// In en, this message translates to:
  /// **'Element settings'**
  String get microConfigureTitle;

  /// No description provided for @microViewNone.
  ///
  /// In en, this message translates to:
  /// **'No custom views yet. A view shows just the elements your lab reports.'**
  String get microViewNone;

  /// Hint text for the microelement-view name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. My lab\'s panel'**
  String get microViewNameHint;

  /// No description provided for @microViewNeedElement.
  ///
  /// In en, this message translates to:
  /// **'Select at least one element.'**
  String get microViewNeedElement;

  /// Subtitle in the manage sheet: how many elements a view shows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 element} other{{count} elements}}'**
  String microViewElementCount(int count);

  /// No description provided for @microViewDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String microViewDeleteTitle(Object name);

  /// No description provided for @microViewDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the view. Your measurements are kept.'**
  String get microViewDeleteBody;

  /// Filter switch on the Microelements screen: hides elements whose latest reading is 0 (ICP labs report undetectable elements as zero). Elements for which zero is abnormal (a deficiency) stay visible.
  ///
  /// In en, this message translates to:
  /// **'Hide undetectable (zero)'**
  String get microHideUndetectable;

  /// Filter switch on the Microelements screen: shows only elements whose latest reading is outside the green range (amber or red).
  ///
  /// In en, this message translates to:
  /// **'Only elements needing attention'**
  String get microAttentionOnly;

  /// Placeholder shown on the Microelements screen when the filter switches hide every element.
  ///
  /// In en, this message translates to:
  /// **'No elements match the current filters.'**
  String get microFilterAllHidden;

  /// Title of the ICP report CSV import: the Microelements app-bar action, the format-choice sheet and the preview screen (U17 phase 2).
  ///
  /// In en, this message translates to:
  /// **'Import ICP report'**
  String get icpImportTitle;

  /// No description provided for @icpImportFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the export format of the file.'**
  String get icpImportFormatHint;

  /// Subtitle of the Fauna Marin option in the import format sheet. Format names themselves (Fauna Marin ICP, ZIMS) are proper nouns and not localized.
  ///
  /// In en, this message translates to:
  /// **'CSV export from the Fauna Marin lab portal'**
  String get icpImportFormatFaunaMarinHint;

  /// No description provided for @icpImportFormatZimsHint.
  ///
  /// In en, this message translates to:
  /// **'Universal measurement CSV (date, measurement, value, unit)'**
  String get icpImportFormatZimsHint;

  /// No description provided for @icpImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read.'**
  String get icpImportUnreadable;

  /// Import rejection: the CSV header does not match the chosen format.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a {format} export.'**
  String icpImportWrongFormat(String format);

  /// No description provided for @icpImportNoValues.
  ///
  /// In en, this message translates to:
  /// **'No importable values were found in the file.'**
  String get icpImportNoValues;

  /// Hint under the date card on the import preview: the water sample predates the lab's analysis date.
  ///
  /// In en, this message translates to:
  /// **'Prefilled with the analysis date from the report. Change it to the day you took the water sample.'**
  String get icpImportSampleDateHint;

  /// Import-preview section header for dashboard (non-microelement) parameters the report carries (Ca, Mg, K, PO4, ...).
  ///
  /// In en, this message translates to:
  /// **'Core parameters'**
  String get icpImportSectionCore;

  /// Import-preview footnote listing report fields the app tracks no parameter for.
  ///
  /// In en, this message translates to:
  /// **'Not imported (no matching parameter): {list}'**
  String icpImportSkipped(String list);

  /// Confirm button of the import preview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Import 1 value} other{Import {count} values}}'**
  String icpImportValueCount(int count);

  /// No description provided for @icpImportDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sample already imported?'**
  String get icpImportDuplicateTitle;

  /// Re-import warning body; {id} is the lab's sample identifier.
  ///
  /// In en, this message translates to:
  /// **'Existing readings already mention sample {id}. Import it again anyway?'**
  String icpImportDuplicateBody(String id);

  /// No description provided for @icpImportAnyway.
  ///
  /// In en, this message translates to:
  /// **'Import anyway'**
  String get icpImportAnyway;

  /// Default note attached to imported readings; carries the lab sample id, which the re-import warning looks for.
  ///
  /// In en, this message translates to:
  /// **'ICP sample {id}'**
  String icpImportNotePrefill(String id);

  /// Shown in the parameter editor instead of the unit field for microelements, whose display unit (mg/L or µg/L, as on an ICP report) is fixed by the catalog.
  ///
  /// In en, this message translates to:
  /// **'This parameter always uses this unit.'**
  String get unitFixedNote;

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

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Tank health'**
  String get healthTitle;

  /// No description provided for @healthGradeExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get healthGradeExcellent;

  /// No description provided for @healthGradeGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get healthGradeGood;

  /// No description provided for @healthGradeCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get healthGradeCaution;

  /// No description provided for @healthGradeCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get healthGradeCritical;

  /// No description provided for @healthGradeUnknown.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get healthGradeUnknown;

  /// No description provided for @healthAllOnTarget.
  ///
  /// In en, this message translates to:
  /// **'All parameters on target'**
  String get healthAllOnTarget;

  /// No description provided for @healthParamsToWatch.
  ///
  /// In en, this message translates to:
  /// **'{count} to watch'**
  String healthParamsToWatch(int count);

  /// No description provided for @healthSectionAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get healthSectionAttention;

  /// No description provided for @healthSectionGood.
  ///
  /// In en, this message translates to:
  /// **'Looking good'**
  String get healthSectionGood;

  /// No description provided for @healthSectionStale.
  ///
  /// In en, this message translates to:
  /// **'Not tested recently'**
  String get healthSectionStale;

  /// No description provided for @healthNotTestedDays.
  ///
  /// In en, this message translates to:
  /// **'Not tested in {count} d'**
  String healthNotTestedDays(int count);

  /// No description provided for @healthNeverTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested yet'**
  String get healthNeverTested;

  /// No description provided for @healthNoReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get healthNoReadingsYet;

  /// No description provided for @healthScoreOf.
  ///
  /// In en, this message translates to:
  /// **'{score} of 100'**
  String healthScoreOf(int score);

  /// No description provided for @dashboardSection.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardSection;

  /// No description provided for @healthDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Tank health'**
  String get healthDisplayTitle;

  /// No description provided for @healthDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where to show the health summary'**
  String get healthDisplaySubtitle;

  /// No description provided for @healthDisplayBoth.
  ///
  /// In en, this message translates to:
  /// **'Badge & card'**
  String get healthDisplayBoth;

  /// No description provided for @healthDisplayBadge.
  ///
  /// In en, this message translates to:
  /// **'Badge only'**
  String get healthDisplayBadge;

  /// No description provided for @healthDisplayOff.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get healthDisplayOff;

  /// Title of the error screen shown when a navigation link or deep link points to a screen that doesn't exist.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// No description provided for @routeNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t lead anywhere in the app.'**
  String get routeNotFoundBody;

  /// No description provided for @routeNotFoundGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home screen'**
  String get routeNotFoundGoHome;

  /// User-visible name of the Android notification channel for water-testing reminders (shown in system notification settings).
  ///
  /// In en, this message translates to:
  /// **'Testing reminders'**
  String get notifChannelTesting;

  /// User-visible name of the Android notification channel for supplement-dosing reminders.
  ///
  /// In en, this message translates to:
  /// **'Dosing reminders'**
  String get notifChannelDosing;

  /// User-visible name of the Android notification channel for maintenance-schedule reminders.
  ///
  /// In en, this message translates to:
  /// **'Maintenance reminders'**
  String get notifChannelMaintenance;

  /// Notification title for a testing reminder; the body lists the parameter names due for testing.
  ///
  /// In en, this message translates to:
  /// **'Time to test'**
  String get notifTestingTitle;

  /// Notification title for a dosing reminder; the body lists the supplement product names.
  ///
  /// In en, this message translates to:
  /// **'Dosing due'**
  String get notifDosingTitle;

  /// Notification title for a maintenance reminder; the body lists the due tasks.
  ///
  /// In en, this message translates to:
  /// **'Maintenance due'**
  String get notifMaintenanceTitle;

  /// Combines a notification title with the tank name when more than one tank exists.
  ///
  /// In en, this message translates to:
  /// **'{title} — {tank}'**
  String notifTitleWithTank(String title, String tank);

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Testing, dosing and maintenance notifications'**
  String get remindersSubtitle;

  /// No description provided for @remindersTestingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When a parameter\'s test is due'**
  String get remindersTestingSubtitle;

  /// No description provided for @remindersDosingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At each supplement\'s dose time'**
  String get remindersDosingSubtitle;

  /// No description provided for @remindersMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When scheduled maintenance is due'**
  String get remindersMaintenanceSubtitle;

  /// No description provided for @reminderTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTimeTitle;

  /// No description provided for @reminderTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery time for testing and maintenance reminders'**
  String get reminderTimeSubtitle;

  /// No description provided for @remindersPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in system settings, so reminders can\'t be shown.'**
  String get remindersPermissionDenied;

  /// No description provided for @remindToTest.
  ///
  /// In en, this message translates to:
  /// **'Remind to test'**
  String get remindToTest;

  /// No description provided for @cadenceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get cadenceOff;

  /// Compact day count used on cadence preset chips (e.g. "7 d").
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String daysShortN(int count);

  /// No description provided for @cadenceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get cadenceCustom;

  /// No description provided for @customDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get customDaysLabel;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @remindMeNeedsTime.
  ///
  /// In en, this message translates to:
  /// **'Set a time of day to enable reminders'**
  String get remindMeNeedsTime;

  /// No description provided for @maintenanceSchedule.
  ///
  /// In en, this message translates to:
  /// **'Maintenance schedule'**
  String get maintenanceSchedule;

  /// No description provided for @addMaintenanceTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addMaintenanceTask;

  /// No description provided for @editMaintenanceTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editMaintenanceTask;

  /// No description provided for @taskTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get taskTypeLabel;

  /// No description provided for @customTask.
  ///
  /// In en, this message translates to:
  /// **'Custom task'**
  String get customTask;

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitleLabel;

  /// No description provided for @taskTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get taskTitleRequired;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatLabel;

  /// No description provided for @oneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get oneOff;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDateLabel;

  /// No description provided for @dueDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a due date'**
  String get dueDateRequired;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// Due chip: the task is due in {count} days (compact d abbreviation).
  ///
  /// In en, this message translates to:
  /// **'Due in {count} d'**
  String dueInDaysN(int count);

  /// Due chip: the task is {count} days past its due date (compact d abbreviation).
  ///
  /// In en, this message translates to:
  /// **'{count} d overdue'**
  String overdueDaysN(int count);

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get markDone;

  /// No description provided for @taskMarkedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as done'**
  String get taskMarkedDone;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @scheduleEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No maintenance tasks yet. Plan water changes or custom tasks to get due chips and reminders.'**
  String get scheduleEmptyBody;

  /// No description provided for @repeatModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeatModeLabel;

  /// No description provided for @repeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Every X days'**
  String get repeatEveryDays;

  /// No description provided for @repeatEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every X weeks'**
  String get repeatEveryWeeks;

  /// No description provided for @repeatEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'Every X months'**
  String get repeatEveryMonths;

  /// No description provided for @repeatOnWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Days of the week'**
  String get repeatOnWeekdays;

  /// No description provided for @repeatOnMonthDay.
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get repeatOnMonthDay;

  /// No description provided for @weeksLabel.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get weeksLabel;

  /// No description provided for @monthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get monthsLabel;

  /// No description provided for @monthDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of the month (1–31)'**
  String get monthDayLabel;

  /// No description provided for @invalidInterval.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number (1 or more).'**
  String get invalidInterval;

  /// No description provided for @invalidMonthDay.
  ///
  /// In en, this message translates to:
  /// **'Enter a day between 1 and 31.'**
  String get invalidMonthDay;

  /// No description provided for @weekdaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get weekdaysRequired;

  /// Schedule subtitle: the task repeats every {n} weeks.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Every week} other{Every {n} weeks}}'**
  String everyWeeksN(int n);

  /// Schedule subtitle: the task repeats every {n} months.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Every month} other{Every {n} months}}'**
  String everyMonthsN(int n);

  /// Schedule subtitle: the task repeats on fixed weekdays; {days} is a localized list of short weekday names (e.g. "Mon, Thu").
  ///
  /// In en, this message translates to:
  /// **'Every {days}'**
  String everyWeekdays(String days);

  /// Schedule subtitle: the task repeats every month on day {n} (1–31, clamped to short months).
  ///
  /// In en, this message translates to:
  /// **'Monthly on day {n}'**
  String monthlyOnDayN(int n);

  /// No description provided for @roUnitTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse osmosis unit'**
  String get roUnitTitle;

  /// No description provided for @roStageSediment.
  ///
  /// In en, this message translates to:
  /// **'Sediment filter'**
  String get roStageSediment;

  /// No description provided for @roStageCarbonBlock.
  ///
  /// In en, this message translates to:
  /// **'Carbon block'**
  String get roStageCarbonBlock;

  /// No description provided for @roStageMembrane.
  ///
  /// In en, this message translates to:
  /// **'RO membrane'**
  String get roStageMembrane;

  /// No description provided for @roStageDiResin.
  ///
  /// In en, this message translates to:
  /// **'DI resin'**
  String get roStageDiResin;

  /// No description provided for @roCustomStage.
  ///
  /// In en, this message translates to:
  /// **'Custom part'**
  String get roCustomStage;

  /// No description provided for @roAddStage.
  ///
  /// In en, this message translates to:
  /// **'Add part'**
  String get roAddStage;

  /// No description provided for @roEditStage.
  ///
  /// In en, this message translates to:
  /// **'Edit part'**
  String get roEditStage;

  /// No description provided for @roLifespanLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace every'**
  String get roLifespanLabel;

  /// No description provided for @roUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get roUnitDays;

  /// No description provided for @roUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get roUnitWeeks;

  /// No description provided for @roUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get roUnitMonths;

  /// No description provided for @roPartOfUnit.
  ///
  /// In en, this message translates to:
  /// **'Part of my unit'**
  String get roPartOfUnit;

  /// No description provided for @roPartOfUnitHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off if your unit doesn\'t have this stage'**
  String get roPartOfUnitHint;

  /// No description provided for @roHiddenStages.
  ///
  /// In en, this message translates to:
  /// **'Not on my unit'**
  String get roHiddenStages;

  /// No description provided for @roMarkReplaced.
  ///
  /// In en, this message translates to:
  /// **'Mark replaced'**
  String get roMarkReplaced;

  /// No description provided for @roReplacedRecorded.
  ///
  /// In en, this message translates to:
  /// **'Replacement recorded'**
  String get roReplacedRecorded;

  /// RO stage subtitle: when the stage was last replaced; {date} is a localized date.
  ///
  /// In en, this message translates to:
  /// **'Replaced {date}'**
  String roLastReplaced(String date);

  /// No description provided for @roNoReplacementYet.
  ///
  /// In en, this message translates to:
  /// **'No replacement recorded yet'**
  String get roNoReplacementYet;

  /// No description provided for @roDeleteStageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete part?'**
  String get roDeleteStageTitle;

  /// No description provided for @roDeleteStageBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the part and its replacement history. This cannot be undone.'**
  String get roDeleteStageBody;

  /// No description provided for @roEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No parts. Add your RO unit\'s filters with +.'**
  String get roEmptyBody;

  /// No description provided for @roSetupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Track filter and membrane replacements'**
  String get roSetupPrompt;

  /// No description provided for @roUnitToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show on the Actions tab, with filter-replacement reminders'**
  String get roUnitToggleSubtitle;

  /// No description provided for @roAllOk.
  ///
  /// In en, this message translates to:
  /// **'All parts OK'**
  String get roAllOk;

  /// No description provided for @notifRoTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace RO filters'**
  String get notifRoTitle;
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
