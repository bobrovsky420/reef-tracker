import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
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
    Locale('fr'),
    Locale('it'),
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

  /// Explanation below the experimental-features switch on the first-run welcome screen.
  ///
  /// In en, this message translates to:
  /// **'Enable features that are still being developed and may change. You can update this choice anytime in Settings.'**
  String get welcomeExperimentalSubtitle;

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

  /// Dashboard section header over the alkalinity/calcium/magnesium tiles (rendered uppercase; keep short).
  ///
  /// In en, this message translates to:
  /// **'Core chemistry'**
  String get dashSectionCoreChemistry;

  /// Dashboard section header over the nitrate/phosphate/ammonia/nitrite tiles (rendered uppercase; keep short).
  ///
  /// In en, this message translates to:
  /// **'Nutrients'**
  String get dashSectionNutrients;

  /// Dashboard section header over the ratio cards (rendered uppercase; keep short).
  ///
  /// In en, this message translates to:
  /// **'Ratios'**
  String get dashSectionRatios;

  /// Dashboard section header over the temperature/pH/salinity/ORP tiles (rendered uppercase; keep short).
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get dashSectionEnvironment;

  /// Screen-reader label for the ideal-range line inside a dashboard gauge dial (visually the line shows only the bare range, e.g. "7.5–9", to fit the dial); keep short, lowercase.
  ///
  /// In en, this message translates to:
  /// **'ideal {min}–{max}'**
  String gaugeIdealRange(String min, String max);

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

  /// No description provided for @fishOnlyPresetNote.
  ///
  /// In en, this message translates to:
  /// **'The Fish only preset sets no boundaries for alkalinity, calcium, magnesium or phosphate – if you track these parameters, they show no zone colours until you set your own boundaries.'**
  String get fishOnlyPresetNote;

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

  /// Tooltip/label for removing a parameter from the tracked list (U11): swipe action on Manage Parameters and the app-bar icon on the parameter edit screen. Readings are always kept; re-adding the parameter restores its history and custom boundaries.
  ///
  /// In en, this message translates to:
  /// **'Untrack'**
  String get untrackParameter;

  /// SnackBar shown after untracking a parameter; paired with an Undo action that restores the tracked row exactly as it was.
  ///
  /// In en, this message translates to:
  /// **'Parameter untracked – readings are kept'**
  String get parameterUntracked;

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

  /// Section header above the zone-bounds editor card in the parameter and ratio editors (rendered uppercase). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Safe ranges'**
  String get sectionSafeRanges;

  /// Section header above the amount + date card in the manual-dose editor (rendered uppercase). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get sectionDose;

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

  /// Line in the confirmation dialog for a device value sitting exactly on the parameter's floor (0 dKH, no salt at all) — the reading a probe gives when it has lost its signal. value includes the unit label.
  ///
  /// In en, this message translates to:
  /// **'{name}: {value} – reads as nothing at all (probe disconnected?)'**
  String implausibleRailLine(Object name, Object value);

  /// Intro line of the confirmation dialog when the suspicious values came from a connected device rather than being typed in.
  ///
  /// In en, this message translates to:
  /// **'A connected device reported values that look wrong. Check the probe before saving.'**
  String get implausibleIntroDevices;

  /// Button that leaves the suspicious values out and saves the rest (device saves only).
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get implausibleSkip;

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

  /// No description provided for @recordFirstReading.
  ///
  /// In en, this message translates to:
  /// **'Record your first reading'**
  String get recordFirstReading;

  /// Cell labels in the compact min/average/max/test-count summary row under the history chart; values are formatted numbers with unit, the test count is a bare integer.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get statMin;

  /// No description provided for @statAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get statAvg;

  /// No description provided for @statMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get statMax;

  /// No description provided for @statTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get statTests;

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

  /// Label of the derived free/toxic ammonia card in the Ratios area (calculated from total ammonia + pH + temperature + salinity).
  ///
  /// In en, this message translates to:
  /// **'Free ammonia (NH₃)'**
  String get freeAmmoniaLabel;

  /// Compact breakdown under the free-ammonia gauge: toxic percentage, and the pH and temperature used.
  ///
  /// In en, this message translates to:
  /// **'{percent}% toxic · pH {ph} · {temp}'**
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp);

  /// Toxic-fraction note on the classic free-ammonia tile.
  ///
  /// In en, this message translates to:
  /// **'{percent}% toxic'**
  String freeAmmoniaPercent(Object percent);

  /// Explainer paragraph in the free-ammonia info dialog.
  ///
  /// In en, this message translates to:
  /// **'An ammonia test measures total ammonia, but only the un-ionized part (NH₃) is toxic. Its share rises with pH and temperature, so a reef tank turns more of it into the toxic form than a low-pH tank. This estimate splits your latest total-ammonia reading using the latest pH, temperature and salinity.'**
  String get freeAmmoniaExplain;

  /// Free-ammonia value line in the info dialog.
  ///
  /// In en, this message translates to:
  /// **'Toxic free ammonia: {value} ppm NH₃'**
  String freeAmmoniaDialogFree(Object value);

  /// Toxic-fraction sentence in the info dialog.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your {total} ppm total ammonia is in the toxic NH₃ form.'**
  String freeAmmoniaDialogFraction(Object percent, Object total);

  /// Inputs line in the info dialog: the pH, temperature and salinity used.
  ///
  /// In en, this message translates to:
  /// **'Based on pH {ph}, {temp} and {salinity}.'**
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity);

  /// Wraps the salinity value when none was measured and 35 ppt is assumed.
  ///
  /// In en, this message translates to:
  /// **'{value} (assumed)'**
  String freeAmmoniaSalinityAssumed(Object value);

  /// Shown when the pH/temperature inputs are too old relative to the ammonia reading.
  ///
  /// In en, this message translates to:
  /// **'pH or temperature was last measured more than a week from this ammonia reading, so the toxic fraction may be inaccurate.'**
  String get freeAmmoniaOutdatedWarning;

  /// Toggle title on the ammonia parameter's edit screen.
  ///
  /// In en, this message translates to:
  /// **'Show free ammonia (NH₃)'**
  String get freeAmmoniaShowTitle;

  /// Toggle subtitle on the ammonia parameter's edit screen.
  ///
  /// In en, this message translates to:
  /// **'Adds a card estimating the toxic un-ionized fraction from pH, temperature and salinity.'**
  String get freeAmmoniaShowSubtitle;

  /// Subtitle on the free-ammonia row in Manage parameters when the ammonia parameter is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enable ammonia to show this.'**
  String get freeAmmoniaNeedsAmmonia;

  /// Generic dialog dismiss button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

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

  /// Settings section label for the language, theme-mode and wall-display rows (REDESIGN #16).
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Settings row title for the light/dark theme choice.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// Theme option: follow the device's light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme option: always use the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option: always use the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

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
  /// **'Convert ppt ⇄ SG ⇄ true density'**
  String get salinityCalculatorSubtitle;

  /// No description provided for @waterChangePlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Water-change planner'**
  String get waterChangePlannerTitle;

  /// No description provided for @waterChangePlannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project batch or automatic water changes'**
  String get waterChangePlannerSubtitle;

  /// No description provided for @waterChangePlannerIntro.
  ///
  /// In en, this message translates to:
  /// **'See how one or repeated water changes may move a measured parameter, using this aquarium\'s volume and latest reading.'**
  String get waterChangePlannerIntro;

  /// No description provided for @waterChangePlannerBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch changes'**
  String get waterChangePlannerBatch;

  /// No description provided for @waterChangePlannerAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic exchange'**
  String get waterChangePlannerAutomatic;

  /// No description provided for @waterChangePlannerBatchHelp.
  ///
  /// In en, this message translates to:
  /// **'Water is removed, replaced, then fully mixed before the next change.'**
  String get waterChangePlannerBatchHelp;

  /// No description provided for @waterChangePlannerAutomaticHelp.
  ///
  /// In en, this message translates to:
  /// **'Old and new water move at the same time through a continuously mixed aquarium.'**
  String get waterChangePlannerAutomaticHelp;

  /// No description provided for @waterChangePlannerNoTank.
  ///
  /// In en, this message translates to:
  /// **'Add an aquarium before planning a water change.'**
  String get waterChangePlannerNoTank;

  /// No description provided for @waterChangePlannerNoParameters.
  ///
  /// In en, this message translates to:
  /// **'Track a dissolved water parameter before using this planner.'**
  String get waterChangePlannerNoParameters;

  /// No description provided for @waterChangePlannerParameter.
  ///
  /// In en, this message translates to:
  /// **'Dissolved parameter'**
  String get waterChangePlannerParameter;

  /// No description provided for @waterChangePlannerTankVolume.
  ///
  /// In en, this message translates to:
  /// **'System-water volume ({unit})'**
  String waterChangePlannerTankVolume(Object unit);

  /// No description provided for @waterChangePlannerChangeVolume.
  ///
  /// In en, this message translates to:
  /// **'Water changed each time ({unit})'**
  String waterChangePlannerChangeVolume(Object unit);

  /// No description provided for @waterChangePlannerCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current value ({unit})'**
  String waterChangePlannerCurrent(Object unit);

  /// No description provided for @waterChangePlannerReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement-water value ({unit})'**
  String waterChangePlannerReplacement(Object unit);

  /// No description provided for @waterChangePlannerTarget.
  ///
  /// In en, this message translates to:
  /// **'Target value ({unit}, optional)'**
  String waterChangePlannerTarget(Object unit);

  /// No description provided for @waterChangePlannerPlannedChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes to project'**
  String get waterChangePlannerPlannedChanges;

  /// No description provided for @waterChangePlannerCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate projection'**
  String get waterChangePlannerCalculate;

  /// No description provided for @waterChangePlannerNonNegativeError.
  ///
  /// In en, this message translates to:
  /// **'Enter zero or a positive number.'**
  String get waterChangePlannerNonNegativeError;

  /// No description provided for @waterChangePlannerCountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 10,000.'**
  String get waterChangePlannerCountError;

  /// No description provided for @waterChangePlannerVolumeError.
  ///
  /// In en, this message translates to:
  /// **'Each change must not exceed the system-water volume.'**
  String get waterChangePlannerVolumeError;

  /// No description provided for @waterChangePlannerReadingDate.
  ///
  /// In en, this message translates to:
  /// **'Latest reading from {date}'**
  String waterChangePlannerReadingDate(Object date);

  /// No description provided for @waterChangePlannerReadingStale.
  ///
  /// In en, this message translates to:
  /// **'Latest reading from {date} is over 30 days old — edit it or measure again.'**
  String waterChangePlannerReadingStale(Object date);

  /// No description provided for @waterChangePlannerProjection.
  ///
  /// In en, this message translates to:
  /// **'Projection'**
  String get waterChangePlannerProjection;

  /// No description provided for @waterChangePlannerAfterOne.
  ///
  /// In en, this message translates to:
  /// **'After one change'**
  String get waterChangePlannerAfterOne;

  /// No description provided for @waterChangePlannerAfterPlanned.
  ///
  /// In en, this message translates to:
  /// **'After {count} changes'**
  String waterChangePlannerAfterPlanned(int count);

  /// No description provided for @waterChangePlannerEffectiveChanged.
  ///
  /// In en, this message translates to:
  /// **'Effective cumulative change'**
  String get waterChangePlannerEffectiveChanged;

  /// No description provided for @waterChangePlannerTargetSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule to target'**
  String get waterChangePlannerTargetSchedule;

  /// No description provided for @waterChangePlannerTargetOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter a target to calculate a schedule.'**
  String get waterChangePlannerTargetOptional;

  /// No description provided for @waterChangePlannerAlreadyAtTarget.
  ///
  /// In en, this message translates to:
  /// **'The current value is already at the target.'**
  String get waterChangePlannerAlreadyAtTarget;

  /// No description provided for @waterChangePlannerTargetUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This replacement water cannot reach the target. Its value must lie beyond the target in the direction you want to move.'**
  String get waterChangePlannerTargetUnreachable;

  /// No description provided for @waterChangePlannerTargetSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 change} other{{count} changes}} · {total} total · {effective} effective'**
  String waterChangePlannerTargetSummary(
    int count,
    Object total,
    Object effective,
  );

  /// No description provided for @waterChangePlannerScheduleOmitted.
  ///
  /// In en, this message translates to:
  /// **'… {count, plural, one{1 intermediate change} other{{count} intermediate changes}} …'**
  String waterChangePlannerScheduleOmitted(int count);

  /// No description provided for @waterChangePlannerStep.
  ///
  /// In en, this message translates to:
  /// **'Change {number}'**
  String waterChangePlannerStep(int number);

  /// No description provided for @waterChangePlannerAssumption.
  ///
  /// In en, this message translates to:
  /// **'Estimate only: this assumes constant water volume, complete mixing, and no new production, consumption, dosing, precipitation, or other change between water changes. Measure after each change; the calculated endpoint is not guaranteed.'**
  String get waterChangePlannerAssumption;

  /// No description provided for @reefUnitConverter.
  ///
  /// In en, this message translates to:
  /// **'Reef unit converter'**
  String get reefUnitConverter;

  /// No description provided for @reefUnitConverterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alkalinity, temperature and volume'**
  String get reefUnitConverterSubtitle;

  /// No description provided for @reefUnitConverterIntro.
  ///
  /// In en, this message translates to:
  /// **'Convert common reef units. Enter a value in any field to update all equivalents.'**
  String get reefUnitConverterIntro;

  /// No description provided for @converterSourceUnit.
  ///
  /// In en, this message translates to:
  /// **'Source unit'**
  String get converterSourceUnit;

  /// No description provided for @converterValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get converterValue;

  /// No description provided for @converterEquivalent.
  ///
  /// In en, this message translates to:
  /// **'Equivalent'**
  String get converterEquivalent;

  /// No description provided for @alkalinity.
  ///
  /// In en, this message translates to:
  /// **'Alkalinity'**
  String get alkalinity;

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

  /// Settings row + dialog title for the Google Drive backup sync (U24); also the feature's name in the Pro dialog.
  ///
  /// In en, this message translates to:
  /// **'Google Drive sync'**
  String get syncGdriveTitle;

  /// Settings row subtitle while not connected — tapping starts the Google connect flow.
  ///
  /// In en, this message translates to:
  /// **'Back up automatically to your Google Drive'**
  String get syncGdriveSubtitle;

  /// Status line under the connected account in Settings.
  ///
  /// In en, this message translates to:
  /// **'Last upload: {when}'**
  String syncGdriveLastPush(String when);

  /// Status line under the connected account before the first upload.
  ///
  /// In en, this message translates to:
  /// **'Nothing uploaded yet'**
  String get syncGdriveNeverPushed;

  /// Snackbar after the Google connect flow succeeds.
  ///
  /// In en, this message translates to:
  /// **'Backups will sync to the Google Drive of {email}'**
  String syncGdriveConnectedSnack(String email);

  /// Snackbar when the Google connect flow fails (not when the user cancels it).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to Google Drive'**
  String get syncGdriveConnectFailed;

  /// Body of the dialog shown when tapping the connected Google Drive sync row.
  ///
  /// In en, this message translates to:
  /// **'Backups are uploaded to the \"ReefTracker\" folder in the Google Drive of {email}. You can browse and download them at drive.google.com.'**
  String syncGdriveDialogBody(String email);

  /// Dialog action that disconnects the Google account from backup sync.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get syncGdriveDisconnect;

  /// Snackbar after disconnecting; reassures that no cloud files were deleted.
  ///
  /// In en, this message translates to:
  /// **'Google Drive disconnected. Backups already uploaded stay in your Drive.'**
  String get syncGdriveDisconnectedSnack;

  /// Warning row in Settings while the most recent Drive upload attempt failed (being offline doesn't count); cleared by the next successful upload.
  ///
  /// In en, this message translates to:
  /// **'Google Drive upload failed on {when}'**
  String syncGdriveLastFailed(String when);

  /// Title of the dialog naming this device for cloud backups (U35); shown right after connecting Google Drive and from the sync options dialog.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get syncDeviceNameTitle;

  /// Explanatory text in the device-name dialog.
  ///
  /// In en, this message translates to:
  /// **'Shown with the backups this device uploads, so you can tell your devices apart.'**
  String get syncDeviceNameBody;

  /// Hint inside the device-name text field.
  ///
  /// In en, this message translates to:
  /// **'e.g. My phone'**
  String get syncDeviceNameHint;

  /// Action in the connected Google Drive dialog that opens the device-name editor.
  ///
  /// In en, this message translates to:
  /// **'Device name…'**
  String get syncDeviceNameAction;

  /// Title of the launch dialog proposing to restore a newer cloud backup another device uploaded (U35).
  ///
  /// In en, this message translates to:
  /// **'Newer backup found'**
  String get syncRestoreTitle;

  /// Body of the restore proposal when this device has no unsynced changes (safe fast-forward).
  ///
  /// In en, this message translates to:
  /// **'A newer backup from “{device}” ({when}) is in your Google Drive. Restore it to this device? Your settings on this device are kept.'**
  String syncRestoreBody(String device, String when);

  /// Body of the restore proposal when this device ALSO holds changes that never reached the cloud — restoring would discard them, so the dialog offers an explicit keep-mine choice too.
  ///
  /// In en, this message translates to:
  /// **'A newer backup from “{device}” ({when}) is in your Google Drive, but this device also has changes that were never uploaded. Restoring replaces this device\'s data with the backup — a local safety copy is saved first.'**
  String syncRestoreDivergedBody(String device, String when);

  /// Placeholder device name in the restore proposal when the backup doesn't say which device wrote it.
  ///
  /// In en, this message translates to:
  /// **'another device'**
  String get syncRestoreUnknownDevice;

  /// Restore-proposal action that declines; the dialog stays quiet until an even newer cloud backup appears.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get syncRestoreNotNow;

  /// Restore-proposal action (diverged case only) that keeps the local data and uploads it as the newest cloud backup instead.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s data'**
  String get syncRestoreKeepMine;

  /// Welcome-screen (no aquariums yet) action that signs into Google and restores the newest cloud backup — the second-device / reinstall path (U35). Deliberately not Pro-gated.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get welcomeRestoreDrive;

  /// Section header for the local backups list in Manage backups; only shown when the Google Drive section is present too.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get backupsLocalSection;

  /// Section header for the Google Drive backups list in Manage backups.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get backupsDriveSection;

  /// Shown in the Google Drive section while the app's Drive folder holds no backups.
  ///
  /// In en, this message translates to:
  /// **'No backups in Google Drive yet'**
  String get backupsDriveEmpty;

  /// Shown in the Google Drive section when listing the Drive folder fails (offline, revoked access).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load backups from Google Drive'**
  String get backupsDriveLoadFailed;

  /// Error sub-line on a cloud backup row whose file exceeds the download size cap; restore is disabled for it.
  ///
  /// In en, this message translates to:
  /// **'{size} — too large to restore'**
  String backupsDriveTooLarge(Object size);

  /// Platform-neutral name of the cloud backup sync feature in the Pro dialog / paywall listings — covers Google Drive sync on Android (U24) and iCloud sync on iOS (U44).
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudSyncFeatureName;

  /// Settings row + dialog title for the iCloud backup sync (U44, iOS only).
  ///
  /// In en, this message translates to:
  /// **'iCloud backup'**
  String get syncIcloudTitle;

  /// Settings row subtitle while iCloud sync is off — tapping turns it on.
  ///
  /// In en, this message translates to:
  /// **'Back up automatically to your iCloud Drive'**
  String get syncIcloudSubtitle;

  /// Body of the enabled iCloud row's options dialog.
  ///
  /// In en, this message translates to:
  /// **'Backups are uploaded to the \"ReefTracker\" folder in your iCloud Drive. You can browse them in the Files app.'**
  String get syncIcloudDialogBody;

  /// Dialog action that turns iCloud backup sync off (there is no account to disconnect).
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get syncIcloudDisable;

  /// Snackbar after turning iCloud backup on; also the welcome-restore confirmation when sync came on with it.
  ///
  /// In en, this message translates to:
  /// **'Backups will sync to your iCloud Drive'**
  String get syncIcloudEnabledSnack;

  /// Snackbar after turning iCloud backup off; reassures that no cloud files were deleted.
  ///
  /// In en, this message translates to:
  /// **'iCloud backup turned off. Backups already uploaded stay in your iCloud Drive.'**
  String get syncIcloudDisabledSnack;

  /// Snackbar when the iCloud container can't be reached — signed out of iCloud, or iCloud Drive disabled for the app.
  ///
  /// In en, this message translates to:
  /// **'iCloud isn\'t available. Sign in to iCloud and turn on iCloud Drive for ReefTracker in the device Settings.'**
  String get syncIcloudUnavailable;

  /// Persistent error row in Settings → Backup after a failed iCloud push, cleared by the next success (the syncGdriveLastFailed idiom).
  ///
  /// In en, this message translates to:
  /// **'iCloud upload failed on {when}'**
  String syncIcloudLastFailed(Object when);

  /// Section header for the iCloud backups list in Manage backups.
  ///
  /// In en, this message translates to:
  /// **'iCloud'**
  String get backupsIcloudSection;

  /// Shown in the iCloud section while the app's iCloud folder holds no backups; also the welcome-restore message when there is nothing to restore.
  ///
  /// In en, this message translates to:
  /// **'No backups in iCloud yet'**
  String get backupsIcloudEmpty;

  /// Shown in the iCloud section when listing the folder fails; also the welcome-restore failure message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load backups from iCloud'**
  String get backupsIcloudLoadFailed;

  /// Welcome-screen (no aquariums yet) action that restores the newest backup from iCloud Drive — the second-device / reinstall path (U44). Deliberately not Pro-gated.
  ///
  /// In en, this message translates to:
  /// **'Restore from iCloud'**
  String get welcomeRestoreIcloud;

  /// iCloud wording of syncRestoreBody — the U35 launch proposal on iOS (U44).
  ///
  /// In en, this message translates to:
  /// **'A newer backup from “{device}” ({when}) is in your iCloud Drive. Restore it to this device? Your settings on this device are kept.'**
  String syncRestoreBodyIcloud(Object device, Object when);

  /// iCloud wording of syncRestoreDivergedBody (U44).
  ///
  /// In en, this message translates to:
  /// **'A newer backup from “{device}” ({when}) is in your iCloud Drive, but this device also has changes that were never uploaded. Restoring replaces this device\'s data with the backup — a local safety copy is saved first.'**
  String syncRestoreDivergedBodyIcloud(Object device, Object when);

  /// Tappable row at the top of the Google Drive section in Manage backups, shown while Drive sync is connected but no device name is set; opens the device-name dialog so new uploads are labeled.
  ///
  /// In en, this message translates to:
  /// **'Set a device name'**
  String get backupsDeviceNameNudge;

  /// Sub-line of the device-name nudge row in Manage backups.
  ///
  /// In en, this message translates to:
  /// **'Labels the backups this device uploads'**
  String get backupsDeviceNameNudgeHint;

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

  /// Settings → About row opening the illustrated user guide on reeftracker.org in the browser.
  ///
  /// In en, this message translates to:
  /// **'User guide'**
  String get aboutUserGuide;

  /// Subtitle of the user-guide link row.
  ///
  /// In en, this message translates to:
  /// **'How to use every feature, with screenshots'**
  String get aboutUserGuideSubtitle;

  /// Settings → About row opening the support page on reeftracker.org in the browser.
  ///
  /// In en, this message translates to:
  /// **'Support & FAQ'**
  String get aboutSupport;

  /// Subtitle of the support link row.
  ///
  /// In en, this message translates to:
  /// **'Get help or report a problem'**
  String get aboutSupportSubtitle;

  /// Settings → About row opening the privacy policy on reeftracker.org in the browser.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// SnackBar shown when launching an external website link fails (no browser available).
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get linkOpenFailed;

  /// Settings → About row sharing the on-device error log as a text file (#107).
  ///
  /// In en, this message translates to:
  /// **'Share diagnostics'**
  String get shareDiagnostics;

  /// Subtitle of the share-diagnostics row.
  ///
  /// In en, this message translates to:
  /// **'Send the app\'s error log to support'**
  String get shareDiagnosticsSubtitle;

  /// SnackBar shown when the diagnostics log is empty — nothing to share.
  ///
  /// In en, this message translates to:
  /// **'No errors have been recorded'**
  String get diagnosticsEmpty;

  /// SnackBar shown when handing the diagnostics file to the OS share sheet fails.
  ///
  /// In en, this message translates to:
  /// **'Could not share the diagnostics'**
  String get diagnosticsShareFailed;

  /// Launch SnackBar (U48) shown when the store reports a newer app version; its action opens the store page. Seen on iOS — on Android, Play shows its own update sheet instead.
  ///
  /// In en, this message translates to:
  /// **'A new version of ReefTracker is available.'**
  String get updateAvailableSnack;

  /// Action of the update-available SnackBar — opens the app's store page.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// SnackBar (U48, Android) shown when Play's flexible update finished downloading; its action restarts the app to install it.
  ///
  /// In en, this message translates to:
  /// **'Update downloaded.'**
  String get updateReadySnack;

  /// Action of the update-downloaded SnackBar — restarts the app to install the downloaded update.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get updateRestartAction;

  /// Settings row label showing which edition of the app this install is entitled to.
  ///
  /// In en, this message translates to:
  /// **'Edition'**
  String get editionLabel;

  /// Edition name for early adopters who installed while the app was fully free.
  ///
  /// In en, this message translates to:
  /// **'Founder\'s Edition'**
  String get editionFounder;

  /// Edition name for regular installs (only reachable once a paid tier exists).
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get editionStandard;

  /// Dialog body explaining the Founder's Edition promise. Promise covers only features available today, never future ones.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been with ReefTracker since its early days. As a thank-you, every feature available today stays free for you — forever.'**
  String get founderInfoBody;

  /// Dialog body for the standard edition. Unreachable until the paid tier activates (every install is seeded as Founder until then). Must never suggest existing data is locked away.
  ///
  /// In en, this message translates to:
  /// **'You\'re using the standard edition of ReefTracker. Everything you\'ve already recorded stays yours; ReefTracker Pro unlocks the advanced features.'**
  String get standardInfoBody;

  /// Action on the Edition dialog that opens the paywall. Only shown once the paid tier is live and the install has not bought.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get editionUpgrade;

  /// Edition name for an install holding a Pro unlock.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get editionPro;

  /// Edition name for an early adopter who also bought the Pro unlock — the designed upgrade path, not an edge case.
  ///
  /// In en, this message translates to:
  /// **'Founder\'s Edition + Pro'**
  String get editionFounderPro;

  /// Dialog body shown to an install holding the Pro unlock.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your Pro unlock is active on this device. Every Pro feature is yours to use.'**
  String get proInfoBody;

  /// Title of the paywall screen.
  ///
  /// In en, this message translates to:
  /// **'ReefTracker Pro'**
  String get paywallTitle;

  /// Paywall lead paragraph explaining the purchase model.
  ///
  /// In en, this message translates to:
  /// **'One purchase, no subscription and no account — the unlock stays with this device\'s store account.'**
  String get paywallIntro;

  /// Paywall buy button. price is already formatted in the user's currency BY THE STORE, never by the app.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro — {price}'**
  String paywallBuy(Object price);

  /// Paywall button that re-checks the store account for an existing unlock. Apple requires this to be visible.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// Paywall busy line shown while a purchase or restore is in flight.
  ///
  /// In en, this message translates to:
  /// **'Talking to the store…'**
  String get paywallWorking;

  /// Paywall success message after a purchase.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocked. Thank you!'**
  String get paywallPurchased;

  /// Paywall success message after a restore found an existing purchase.
  ///
  /// In en, this message translates to:
  /// **'Your Pro unlock has been restored.'**
  String get paywallRestored;

  /// Paywall message when a restore completed successfully but the account owns nothing.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase was found for this store account.'**
  String get paywallNothingToRestore;

  /// Paywall message for a deferred payment method (cash, bank transfer, carrier billing) — not a purchase yet.
  ///
  /// In en, this message translates to:
  /// **'Your payment is still being confirmed. Pro unlocks as soon as it goes through.'**
  String get paywallPending;

  /// Paywall message for a failed purchase or restore.
  ///
  /// In en, this message translates to:
  /// **'The store could not complete that. Please try again.'**
  String get paywallFailed;

  /// Paywall message when the store itself cannot be reached (no store services, restricted profile).
  ///
  /// In en, this message translates to:
  /// **'In-app purchases aren\'t available on this device.'**
  String get paywallUnavailable;

  /// Title of the dialog shown when a non-entitled install taps a Pro-gated feature.
  ///
  /// In en, this message translates to:
  /// **'Pro feature'**
  String get proFeatureTitle;

  /// Body of the Pro-feature dialog; feature is the localized feature name (e.g. "Import ICP report").
  ///
  /// In en, this message translates to:
  /// **'{feature} is part of ReefTracker Pro.'**
  String proFeatureBody(Object feature);

  /// Display name of the Pro feature that lifts the free-tier aquarium cap; used in the Pro-feature dialog and future paywall listings.
  ///
  /// In en, this message translates to:
  /// **'Unlimited aquariums'**
  String get unlimitedTanksTitle;

  /// Pro-feature dialog body shown when a non-entitled install tries to create an aquarium beyond the free cap; limit is kFreeTankLimit (currently 2).
  ///
  /// In en, this message translates to:
  /// **'The standard edition includes up to {limit} aquariums — for example a display tank and a quarantine tank. Unlimited aquariums are part of ReefTracker Pro.'**
  String tankLimitBody(Object limit);

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

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @calculatorIntro.
  ///
  /// In en, this message translates to:
  /// **'Convert practical salinity (ppt), specific gravity (SG), and readings from a density hydrometer calibrated at 25 °C. Enter the water temperature and type in any value field.'**
  String get calculatorIntro;

  /// No description provided for @specificGravity.
  ///
  /// In en, this message translates to:
  /// **'Specific gravity'**
  String get specificGravity;

  /// Temperature of the water sample while its density is measured
  ///
  /// In en, this message translates to:
  /// **'Measurement temperature'**
  String get measurementTemperature;

  /// Help for the salinity converter sample-temperature field
  ///
  /// In en, this message translates to:
  /// **'Use the water temperature in the measuring cylinder.'**
  String get densityTemperatureHelp;

  /// Reading from a glass density hydrometer calibrated at 25 degrees Celsius
  ///
  /// In en, this message translates to:
  /// **'Hydrometer density reading'**
  String get hydrometerDensityReading;

  /// Explains which common aquarium instruments report true rather than relative density
  ///
  /// In en, this message translates to:
  /// **'European glass hydrometers (areometers), including ARKA and Tropic Marin models, are typically calibrated at 25 °C. Temperature correction helps with prepared saltwater measured near ambient temperature.'**
  String get densityHydrometerNote;

  /// No description provided for @referencePoints.
  ///
  /// In en, this message translates to:
  /// **'Reference points'**
  String get referencePoints;

  /// No description provided for @refSeawater.
  ///
  /// In en, this message translates to:
  /// **'• Natural seawater ≈ 35 ppt ≈ 1.0264 SG ≈ 1.0233 g/cm³ at 25 °C'**
  String get refSeawater;

  /// No description provided for @refReefTarget.
  ///
  /// In en, this message translates to:
  /// **'• Typical reef target ≈ 35 ppt (1.025–1.027 SG)'**
  String get refReefTarget;

  /// No description provided for @refFormulaNote.
  ///
  /// In en, this message translates to:
  /// **'Away from 25 °C, correction uses the standard seawater density equation and nominal hydrometer-glass expansion (26 ppm/°C). Measure at 25 °C for best accuracy.'**
  String get refFormulaNote;

  /// No description provided for @salinityToolConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get salinityToolConvert;

  /// No description provided for @salinityToolMix.
  ///
  /// In en, this message translates to:
  /// **'Mix new water'**
  String get salinityToolMix;

  /// No description provided for @salinityToolCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct this tank'**
  String get salinityToolCorrect;

  /// No description provided for @saltMixIntro.
  ///
  /// In en, this message translates to:
  /// **'Estimate the dry salt mix for a prepared batch. Use your product\'s label or a batch you measured yourself.'**
  String get saltMixIntro;

  /// No description provided for @saltMixFinalVolume.
  ///
  /// In en, this message translates to:
  /// **'Desired final volume'**
  String get saltMixFinalVolume;

  /// No description provided for @saltMixTarget.
  ///
  /// In en, this message translates to:
  /// **'Target salinity'**
  String get saltMixTarget;

  /// No description provided for @saltMixProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your salt mix'**
  String get saltMixProfileTitle;

  /// No description provided for @saltMixProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Salt mix'**
  String get saltMixProductLabel;

  /// No description provided for @saltMixCustomProduct.
  ///
  /// In en, this message translates to:
  /// **'Custom mix'**
  String get saltMixCustomProduct;

  /// No description provided for @saltMixCustomHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter a label value or calibrate a batch you measured yourself.'**
  String get saltMixCustomHelp;

  /// No description provided for @saltMixCatalogManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer starting value. Measure a prepared batch to personalize it for this aquarium.'**
  String get saltMixCatalogManufacturer;

  /// No description provided for @saltMixCatalogEstimate.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer source-water estimate. Calibrate a measured final batch before relying on it.'**
  String get saltMixCatalogEstimate;

  /// No description provided for @saltMixMeasuredCalibration.
  ///
  /// In en, this message translates to:
  /// **'Using your measured calibration for this aquarium.'**
  String get saltMixMeasuredCalibration;

  /// No description provided for @saltMixNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Salt name (optional)'**
  String get saltMixNameOptional;

  /// No description provided for @saltMixFactor.
  ///
  /// In en, this message translates to:
  /// **'Dry mix at reference salinity'**
  String get saltMixFactor;

  /// No description provided for @saltMixFactorHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter grams per litre of final prepared saltwater. A label stated per litre of source water is only an estimate until you calibrate a real batch.'**
  String get saltMixFactorHelp;

  /// No description provided for @saltMixReferenceSalinity.
  ///
  /// In en, this message translates to:
  /// **'Reference salinity'**
  String get saltMixReferenceSalinity;

  /// No description provided for @saltMixCalibrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrate from a measured batch'**
  String get saltMixCalibrateTitle;

  /// No description provided for @saltMixDryMass.
  ///
  /// In en, this message translates to:
  /// **'Dry mix used'**
  String get saltMixDryMass;

  /// No description provided for @saltMixMeasuredVolume.
  ///
  /// In en, this message translates to:
  /// **'Measured final volume'**
  String get saltMixMeasuredVolume;

  /// No description provided for @saltMixMeasuredSalinity.
  ///
  /// In en, this message translates to:
  /// **'Measured salinity'**
  String get saltMixMeasuredSalinity;

  /// No description provided for @saltMixUseCalibration.
  ///
  /// In en, this message translates to:
  /// **'Use this calibration'**
  String get saltMixUseCalibration;

  /// No description provided for @saltMixCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate salt mix'**
  String get saltMixCalculate;

  /// No description provided for @salinityPlannerResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get salinityPlannerResult;

  /// No description provided for @saltMixDrySalt.
  ///
  /// In en, this message translates to:
  /// **'Estimated dry mix'**
  String get saltMixDrySalt;

  /// No description provided for @saltMixResultHelp.
  ///
  /// In en, this message translates to:
  /// **'Start with less RO/DI water than the desired final volume. Mix outside the aquarium, follow the product\'s temperature, mixing and aeration directions, then verify with a calibrated salinity instrument and adjust salt and water to the final volume.'**
  String get saltMixResultHelp;

  /// No description provided for @salinityCorrectionIntro.
  ///
  /// In en, this message translates to:
  /// **'Estimate an equal-volume water exchange that moves this tank from its current salinity to your target.'**
  String get salinityCorrectionIntro;

  /// No description provided for @salinityCorrectionTankVolume.
  ///
  /// In en, this message translates to:
  /// **'Net system-water volume'**
  String get salinityCorrectionTankVolume;

  /// No description provided for @salinityCorrectionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current salinity'**
  String get salinityCorrectionCurrent;

  /// No description provided for @salinityCorrectionTarget.
  ///
  /// In en, this message translates to:
  /// **'Target salinity'**
  String get salinityCorrectionTarget;

  /// No description provided for @salinityPlannerLatestReading.
  ///
  /// In en, this message translates to:
  /// **'Prefilled from your reading on {date}.'**
  String salinityPlannerLatestReading(Object date);

  /// No description provided for @salinityCorrectionReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement-batch salinity'**
  String get salinityCorrectionReplacement;

  /// No description provided for @salinityCorrectionReplacementHelp.
  ///
  /// In en, this message translates to:
  /// **'It must be above the target. Prepare and measure this batch separately.'**
  String get salinityCorrectionReplacementHelp;

  /// No description provided for @salinityCorrectionHighMethod.
  ///
  /// In en, this message translates to:
  /// **'Remove the calculated tank water and replace it with the same volume of 0-ppt RO/DI water.'**
  String get salinityCorrectionHighMethod;

  /// No description provided for @salinityCorrectionHighResultHelp.
  ///
  /// In en, this message translates to:
  /// **'Treat this as a starting estimate. Make large changes in steps, circulate the tank between them, and remeasure after every step.'**
  String get salinityCorrectionHighResultHelp;

  /// No description provided for @salinityCorrectionLowResultHelp.
  ///
  /// In en, this message translates to:
  /// **'Prepare the replacement water outside the aquarium. Follow the salt product\'s temperature, mixing and aeration directions, verify it with a calibrated salinity instrument, then change the water in steps, circulate, and remeasure.'**
  String get salinityCorrectionLowResultHelp;

  /// No description provided for @salinityCorrectionLowMethod.
  ///
  /// In en, this message translates to:
  /// **'Remove the calculated tank water and replace it with the same volume of separately mixed, higher-salinity water.'**
  String get salinityCorrectionLowMethod;

  /// No description provided for @salinityCorrectionCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate correction'**
  String get salinityCorrectionCalculate;

  /// No description provided for @salinityReplacementError.
  ///
  /// In en, this message translates to:
  /// **'Replacement salinity must be above the target.'**
  String get salinityReplacementError;

  /// No description provided for @salinityPlannerAssumptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you correct'**
  String get salinityPlannerAssumptionsTitle;

  /// No description provided for @salinityPlannerAssumptions.
  ///
  /// In en, this message translates to:
  /// **'The estimate assumes the tank stays at the same volume, salt is conserved, and the water is fully mixed. If evaporation lowered the water level, restore the normal level with RO/DI and measure again first.'**
  String get salinityPlannerAssumptions;

  /// No description provided for @salinityPlannerSafety.
  ///
  /// In en, this message translates to:
  /// **'Never add dry salt mix to an aquarium containing animals. Make large changes in steps, circulate between them, and measure after every step. The calculator does not set a universally safe daily change or guarantee the endpoint.'**
  String get salinityPlannerSafety;

  /// No description provided for @salinityCorrectionNoChange.
  ///
  /// In en, this message translates to:
  /// **'The current salinity already matches the target. No exchange is needed.'**
  String get salinityCorrectionNoChange;

  /// No description provided for @salinityCorrectionExchange.
  ///
  /// In en, this message translates to:
  /// **'Remove and replace'**
  String get salinityCorrectionExchange;

  /// No description provided for @salinityCorrectionTankPercent.
  ///
  /// In en, this message translates to:
  /// **'Of system water'**
  String get salinityCorrectionTankPercent;

  /// No description provided for @salinityCorrectionBatchSalt.
  ///
  /// In en, this message translates to:
  /// **'Dry mix for replacement batch'**
  String get salinityCorrectionBatchSalt;

  /// No description provided for @salinityCorrectionExtraEquivalent.
  ///
  /// In en, this message translates to:
  /// **'Total additional-salt equivalent'**
  String get salinityCorrectionExtraEquivalent;

  /// No description provided for @salinityCorrectionRecord.
  ///
  /// In en, this message translates to:
  /// **'Record completed water change'**
  String get salinityCorrectionRecord;

  /// No description provided for @salinityCorrectionLogNote.
  ///
  /// In en, this message translates to:
  /// **'Salinity correction'**
  String get salinityCorrectionLogNote;

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

  /// Calculator mode toggle: the consumption-based daily-dose adjustment.
  ///
  /// In en, this message translates to:
  /// **'Daily dose'**
  String get doseCalcModeMaintenance;

  /// Calculator mode toggle: the one-off correction dose toward a target value.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get doseCalcModeCorrection;

  /// No description provided for @doseCalcCorrIntro.
  ///
  /// In en, this message translates to:
  /// **'Calculate a one-time dose that raises an element from its current value to your target. When a fast rise would be unsafe, the dose is split over several days.'**
  String get doseCalcCorrIntro;

  /// No description provided for @doseCalcCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value'**
  String get doseCalcCurrentValue;

  /// No description provided for @doseCalcCurrentValueHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty = your latest measurement.'**
  String get doseCalcCurrentValueHelp;

  /// No description provided for @doseCalcTargetValue.
  ///
  /// In en, this message translates to:
  /// **'Target value'**
  String get doseCalcTargetValue;

  /// No description provided for @doseCalcTargetValueHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty = this parameter\'s correction target, or the middle of its OK range.'**
  String get doseCalcTargetValueHelp;

  /// No description provided for @doseCalcNeededRise.
  ///
  /// In en, this message translates to:
  /// **'Needed rise'**
  String get doseCalcNeededRise;

  /// No description provided for @doseCalcOneTimeDose.
  ///
  /// In en, this message translates to:
  /// **'One-time dose'**
  String get doseCalcOneTimeDose;

  /// No description provided for @doseCalcTotalDose.
  ///
  /// In en, this message translates to:
  /// **'Total dose'**
  String get doseCalcTotalDose;

  /// No description provided for @doseCalcDosePerDay.
  ///
  /// In en, this message translates to:
  /// **'Dose per day'**
  String get doseCalcDosePerDay;

  /// No description provided for @doseCalcSpreadDays.
  ///
  /// In en, this message translates to:
  /// **'Days to spread over'**
  String get doseCalcSpreadDays;

  /// No description provided for @doseCalcCorrMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter the current value, target and tank volume to calculate.'**
  String get doseCalcCorrMissing;

  /// No description provided for @doseCalcCorrAtTarget.
  ///
  /// In en, this message translates to:
  /// **'Already at or above the target — nothing to dose.'**
  String get doseCalcCorrAtTarget;

  /// No description provided for @doseCalcCorrSingle.
  ///
  /// In en, this message translates to:
  /// **'Safe to give as a single dose.'**
  String get doseCalcCorrSingle;

  /// Warning under the correction result when the rise exceeds the element's safe daily limit.
  ///
  /// In en, this message translates to:
  /// **'Raising faster than {limit} per day is risky — give the correction as {days} daily doses instead.'**
  String doseCalcCorrSplit(Object limit, int days);

  /// No description provided for @doseCalcLogDose.
  ///
  /// In en, this message translates to:
  /// **'Log this dose'**
  String get doseCalcLogDose;

  /// Correction-mode switch: scale the target value (which is referenced to 35 ppt seawater) to the tank's measured salinity.
  ///
  /// In en, this message translates to:
  /// **'Adjust target to tank salinity'**
  String get doseCalcSalinityAdjust;

  /// No description provided for @doseCalcSalinityAdjustHelp.
  ///
  /// In en, this message translates to:
  /// **'Target values assume 35 ppt (1.026) seawater. Turn on to scale the target to your tank\'s measured salinity.'**
  String get doseCalcSalinityAdjustHelp;

  /// Switch subtitle while active: the measured salinity and the scaled vs. 35 ppt target, all pre-formatted with their units.
  ///
  /// In en, this message translates to:
  /// **'At {salinity}: target {adjusted} instead of {original}.'**
  String doseCalcSalinityAdjustActive(
    Object salinity,
    Object adjusted,
    Object original,
  );

  /// Switch subtitle while disabled because the tank has no stored salinity reading.
  ///
  /// In en, this message translates to:
  /// **'No salinity measurement for this tank yet.'**
  String get doseCalcSalinityNone;

  /// Appended to the switch subtitle when the newest salinity reading is older than the 14-day averaging window.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Salinity measured {days} day ago.} other{Salinity measured {days} days ago.}}'**
  String doseCalcSalinityStale(int days);

  /// Correction result row: the salinity-scaled target value the dose aims at.
  ///
  /// In en, this message translates to:
  /// **'Adjusted target'**
  String get doseCalcAdjustedTarget;

  /// Tappable card on a parameter's history screen when its latest reading is below the green zone; opens the dose calculator in correction mode.
  ///
  /// In en, this message translates to:
  /// **'Below range — calculate a correction dose'**
  String get correctionCta;

  /// No description provided for @targetValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Correction target'**
  String get targetValueLabel;

  /// No description provided for @targetValueHelp.
  ///
  /// In en, this message translates to:
  /// **'Pre-fills the dose calculator\'s correction mode. Empty = the middle of the OK range.'**
  String get targetValueHelp;

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

  /// History trend card note for a parameter whose readings scatter too much for the fitted slope to be trusted; shown instead of a forecast. The headline above it shows the typical swing ("±0.11 pH") instead of a per-day rate.
  ///
  /// In en, this message translates to:
  /// **'Swinging — no clear direction'**
  String get trendOscillating;

  /// Compact dashboard chip for a parameter that is swinging without a reliable trend. Neutral in tone — an observation about the readings, not an alarm. Keep it to one or two words; the chip is very narrow.
  ///
  /// In en, this message translates to:
  /// **'Unsettled'**
  String get trendChipOscillating;

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
  /// **'Fish only'**
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

  /// Dedicated compact name for alkalinity, shown on the dashboard gauge dial instead of the full name (rendered uppercase; keep very short). Parameters without a dedicated *Short key derive their dial label from the " (Symbol)" parenthetical of the full name, or fall back to the full name.
  ///
  /// In en, this message translates to:
  /// **'KH'**
  String get paramAlkalinityShort;

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

  /// Overflow-menu action on the Measurements tab and title of the source-picker sheet (U32).
  ///
  /// In en, this message translates to:
  /// **'Import measurements'**
  String get measurementImportTitle;

  /// No description provided for @measurementImportSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the app or meter the file comes from.'**
  String get measurementImportSourceHint;

  /// Subtitle of the Hanna Lab entry in the source picker. 'Hanna Lab' is a product name, not localized.
  ///
  /// In en, this message translates to:
  /// **'CSV history shared from the Hanna Lab app'**
  String get measurementImportHannaHint;

  /// Preview screen title and the Pro feature's display name.
  ///
  /// In en, this message translates to:
  /// **'Hanna Lab import'**
  String get hannaImportTitle;

  /// No description provided for @hannaImportIntoTank.
  ///
  /// In en, this message translates to:
  /// **'Import into tank'**
  String get hannaImportIntoTank;

  /// Label of the first-import start-date row; its value is a date or hannaImportEverything.
  ///
  /// In en, this message translates to:
  /// **'Import history from'**
  String get hannaImportFirstFrom;

  /// No description provided for @hannaImportEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get hannaImportEverything;

  /// No description provided for @hannaImportFirstFromHint.
  ///
  /// In en, this message translates to:
  /// **'First import into this tank: choose how far back to import. Older readings are ignored for good — useful when you already typed them in by hand.'**
  String get hannaImportFirstFromHint;

  /// Section header over the to-be-imported sessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new reading} other{{count} new readings}}'**
  String hannaImportNewCount(int count);

  /// No description provided for @hannaImportAlreadyCount.
  ///
  /// In en, this message translates to:
  /// **'Already imported: {count}'**
  String hannaImportAlreadyCount(int count);

  /// No description provided for @hannaImportBeforeCutoffCount.
  ///
  /// In en, this message translates to:
  /// **'Before the start date: {count}'**
  String hannaImportBeforeCutoffCount(int count);

  /// No description provided for @hannaImportSkippedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not imported'**
  String get hannaImportSkippedTitle;

  /// Skip reason: the meter flagged the reading under/over range.
  ///
  /// In en, this message translates to:
  /// **'outside the test range'**
  String get hannaImportSkipRange;

  /// No description provided for @hannaImportSkipUnknown.
  ///
  /// In en, this message translates to:
  /// **'test not tracked by the app'**
  String get hannaImportSkipUnknown;

  /// No description provided for @hannaImportSkipValue.
  ///
  /// In en, this message translates to:
  /// **'unreadable value'**
  String get hannaImportSkipValue;

  /// No description provided for @hannaImportUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything in this file is already imported.'**
  String get hannaImportUpToDate;

  /// Confirm button of the import preview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Import 1 reading} other{Import {count} readings}}'**
  String hannaImportButton(int count);

  /// Headline of the result sheet after a successful import.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Imported 1 reading} other{Imported {count} readings}}'**
  String hannaImportDoneCount(int count);

  /// No description provided for @hannaImportUndone.
  ///
  /// In en, this message translates to:
  /// **'Import undone.'**
  String get hannaImportUndone;

  /// No description provided for @hannaImportWrongTankTitle.
  ///
  /// In en, this message translates to:
  /// **'Different tank?'**
  String get hannaImportWrongTankTitle;

  /// Wrong-file guard: the file's sample location was previously mapped to another tank.
  ///
  /// In en, this message translates to:
  /// **'“{location}” was last imported into {tank}. Import into {other} instead?'**
  String hannaImportWrongTankBody(String location, String tank, String other);

  /// No description provided for @measurementImportSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement import'**
  String get measurementImportSettingsTitle;

  /// Watermark line in the import settings; {date} is a formatted date-time.
  ///
  /// In en, this message translates to:
  /// **'Imported up to {date}'**
  String hannaImportImportedUpTo(String date);

  /// No description provided for @hannaImportNeverImported.
  ///
  /// In en, this message translates to:
  /// **'Not imported yet'**
  String get hannaImportNeverImported;

  /// No description provided for @hannaImportChangeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date…'**
  String get hannaImportChangeDate;

  /// No description provided for @hannaImportReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get hannaImportReset;

  /// No description provided for @hannaImportResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Hanna Lab import?'**
  String get hannaImportResetTitle;

  /// No description provided for @hannaImportResetBody.
  ///
  /// In en, this message translates to:
  /// **'The next import will ask again from which date to start. Already-imported readings stay; the tank assignment is remembered.'**
  String get hannaImportResetBody;

  /// Direct BLE connection feature (U33): menu action, screen title, Pro-dialog feature name.
  ///
  /// In en, this message translates to:
  /// **'Hanna checker'**
  String get hannaConnectTitle;

  /// No description provided for @hannaMeasureAction.
  ///
  /// In en, this message translates to:
  /// **'Measure with Hanna checker'**
  String get hannaMeasureAction;

  /// Checker camera scan feature (U34): menu action, screen title, Pro-dialog feature name.
  ///
  /// In en, this message translates to:
  /// **'Scan checker display'**
  String get hannaScanTitle;

  /// No description provided for @hannaScanPickHint.
  ///
  /// In en, this message translates to:
  /// **'Reads the value straight from the checker\'s display. First pick your model — the HI number is printed on the front of the checker.'**
  String get hannaScanPickHint;

  /// No description provided for @hannaScanPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Checker model'**
  String get hannaScanPickTitle;

  /// No description provided for @hannaScanGuide.
  ///
  /// In en, this message translates to:
  /// **'Fit the display into the frame'**
  String get hannaScanGuide;

  /// Second half of the viewfinder hint line, appended after hannaScanGuide with a separator — starts lowercase.
  ///
  /// In en, this message translates to:
  /// **'tilt slightly to avoid glare'**
  String get hannaScanGlareHint;

  /// Third part of the viewfinder hint line, appended with a separator — starts lowercase.
  ///
  /// In en, this message translates to:
  /// **'pinch to zoom'**
  String get hannaScanZoomHint;

  /// No description provided for @hannaScanRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get hannaScanRescan;

  /// No description provided for @hannaScanNoCamera.
  ///
  /// In en, this message translates to:
  /// **'This device has no camera.'**
  String get hannaScanNoCamera;

  /// No description provided for @hannaScanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access was denied. Allow camera access in the system settings to scan the display.'**
  String get hannaScanCameraDenied;

  /// No description provided for @hannaScanCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t be started.'**
  String get hannaScanCameraFailed;

  /// No description provided for @hannaScanImpossibleNote.
  ///
  /// In en, this message translates to:
  /// **'This value is impossible for this parameter and can\'t be saved. Rescan, or check that the right model is selected.'**
  String get hannaScanImpossibleNote;

  /// No description provided for @hannaScanImplausibleNote.
  ///
  /// In en, this message translates to:
  /// **'This value is outside the plausible range — double-check it before saving.'**
  String get hannaScanImplausibleNote;

  /// No description provided for @experimentalBadge.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get experimentalBadge;

  /// Settings section header grouping the experimental-features master switch and the experimental feature rows.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get experimentalSection;

  /// Settings master switch (default off) that shows/hides all experimental features.
  ///
  /// In en, this message translates to:
  /// **'Experimental features'**
  String get experimentalToggleTitle;

  /// No description provided for @experimentalToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try features still in testing: Hanna checker Bluetooth connection and display scanning'**
  String get experimentalToggleSubtitle;

  /// Settings switch (default off) for the quick checker-scan camera button on the Measurements tab.
  ///
  /// In en, this message translates to:
  /// **'Camera scan button'**
  String get hannaScanFabTitle;

  /// No description provided for @hannaScanFabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a quick scan button above \"Add reading\"'**
  String get hannaScanFabSubtitle;

  /// No description provided for @hannaExperimentalNote.
  ///
  /// In en, this message translates to:
  /// **'Experimental feature: it uses an unofficial Bluetooth protocol and may stop working after a meter firmware update.'**
  String get hannaExperimentalNote;

  /// Scope note on the meter screen: ReefTracker only takes measurements; meter settings and firmware updates are done in the vendor's Hanna Lab app.
  ///
  /// In en, this message translates to:
  /// **'Only measurements are supported. To change the meter\'s settings or update its firmware, use Hanna\'s own Hanna Lab app.'**
  String get hannaMeasureOnlyNote;

  /// No description provided for @hannaScanning.
  ///
  /// In en, this message translates to:
  /// **'Looking for the meter…'**
  String get hannaScanning;

  /// No description provided for @hannaScanHint.
  ///
  /// In en, this message translates to:
  /// **'Turn the meter on and keep it close to your phone.'**
  String get hannaScanHint;

  /// No description provided for @hannaReadingSetup.
  ///
  /// In en, this message translates to:
  /// **'Connected — reading meter setup…'**
  String get hannaReadingSetup;

  /// No description provided for @hannaErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth LE is not available on this device.'**
  String get hannaErrUnsupported;

  /// No description provided for @hannaErrBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Turn it on and try again.'**
  String get hannaErrBluetoothOff;

  /// No description provided for @hannaErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'No meter found. Make sure it is turned on and within range.'**
  String get hannaErrNotFound;

  /// No description provided for @hannaErrConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the meter.'**
  String get hannaErrConnectionFailed;

  /// No description provided for @hannaErrConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'The connection to the meter was lost.'**
  String get hannaErrConnectionLost;

  /// No description provided for @hannaTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get hannaTryAgain;

  /// Status line of the connected-meter card.
  ///
  /// In en, this message translates to:
  /// **'Battery {percent} % · firmware {firmware}'**
  String hannaMeterStatus(int percent, String firmware);

  /// Section header for the meter-side tank/location selector.
  ///
  /// In en, this message translates to:
  /// **'Aquarium'**
  String get hannaAquarium;

  /// No description provided for @hannaSetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Test sets'**
  String get hannaSetsTitle;

  /// No description provided for @hannaSetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 method} other{{count} methods}}'**
  String hannaSetCount(int count);

  /// No description provided for @hannaSaveSet.
  ///
  /// In en, this message translates to:
  /// **'Save selection as set'**
  String get hannaSaveSet;

  /// No description provided for @hannaSetName.
  ///
  /// In en, this message translates to:
  /// **'Set name'**
  String get hannaSetName;

  /// No description provided for @hannaSetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update from current selection'**
  String get hannaSetUpdate;

  /// No description provided for @hannaAllMethods.
  ///
  /// In en, this message translates to:
  /// **'All methods'**
  String get hannaAllMethods;

  /// Display label of a low-range method variant; {name} is the parameter name.
  ///
  /// In en, this message translates to:
  /// **'{name} (low range)'**
  String hannaMethodLowRange(String name);

  /// No description provided for @hannaStartMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Start measurements'**
  String get hannaStartMeasurements;

  /// Status line under a running measurement. No terminal punctuation: it is composed with ' · ' + hannaStepN once the meter reports a step.
  ///
  /// In en, this message translates to:
  /// **'Follow the instructions on the meter'**
  String get hannaFollowMeter;

  /// Progress suffix while a measurement runs; the meter reports numbered STATUS steps.
  ///
  /// In en, this message translates to:
  /// **'step {step}'**
  String hannaStepN(int step);

  /// No description provided for @hannaStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get hannaStatusSkipped;

  /// No description provided for @hannaSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get hannaSkip;

  /// No description provided for @hannaFinishNow.
  ///
  /// In en, this message translates to:
  /// **'Finish now'**
  String get hannaFinishNow;

  /// No description provided for @hannaTimerHint.
  ///
  /// In en, this message translates to:
  /// **'Reagent reaction timer'**
  String get hannaTimerHint;

  /// No description provided for @hannaTimerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop timer'**
  String get hannaTimerStop;

  /// Mini button starting an n-second reaction timer; keep as short as possible.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String hannaTimerSec(int n);

  /// Mini button starting an n-minute reaction timer; keep as short as possible.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String hannaTimerMin(int n);

  /// Title of the system notification that stands in for the in-app timer beep when the phone is locked or the app is in the background (iOS — Android keeps the in-app beep running).
  ///
  /// In en, this message translates to:
  /// **'Reagent timer finished'**
  String get hannaTimerDoneTitle;

  /// Body of the reagent-timer notification.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up — continue the measurement on your meter.'**
  String get hannaTimerDoneBody;

  /// No description provided for @hannaResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement results'**
  String get hannaResultsTitle;

  /// No description provided for @hannaResultsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The connection was lost — the results captured so far are kept.'**
  String get hannaResultsDisconnected;

  /// No description provided for @hannaNoResults.
  ///
  /// In en, this message translates to:
  /// **'No measurements were captured.'**
  String get hannaNoResults;

  /// No description provided for @hannaSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to aquarium'**
  String get hannaSaveTo;

  /// No description provided for @hannaSaveButton.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Save 1 reading} other{Save {count} readings}}'**
  String hannaSaveButton(int count);

  /// No description provided for @hannaSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 reading saved} other{{count} readings saved}}'**
  String hannaSavedSnack(int count);

  /// Save button when environment readings from connected devices are saved along with the session results
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Save 1 reading} other{Save {count} readings}} + {envCount} environment'**
  String hannaSaveButtonEnv(int count, int envCount);

  /// Accessibility label of the checkbox on a result row of the Hanna results step.
  ///
  /// In en, this message translates to:
  /// **'Include in save'**
  String get hannaIncludeInSave;

  /// No description provided for @hannaValueImpossible.
  ///
  /// In en, this message translates to:
  /// **'Outside the possible range — won\'t be saved'**
  String get hannaValueImpossible;

  /// No description provided for @hannaNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected to save'**
  String get hannaNothingSelected;

  /// No description provided for @hannaRemeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure again'**
  String get hannaRemeasure;

  /// Button that sends the results the user marked back to the meter for another measurement pass.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Measure 1 again} other{Measure {count} again}}'**
  String hannaRemeasureCount(int count);

  /// No description provided for @hannaRemeasureQueued.
  ///
  /// In en, this message translates to:
  /// **'Will be measured again'**
  String get hannaRemeasureQueued;

  /// No description provided for @hannaRemeasureKept.
  ///
  /// In en, this message translates to:
  /// **'Not re-measured — earlier value kept'**
  String get hannaRemeasureKept;

  /// Caption on a re-measured result row, showing the value the new one replaced; {value} is already formatted with its unit.
  ///
  /// In en, this message translates to:
  /// **'was {value}'**
  String hannaPreviousValue(String value);

  /// No description provided for @hannaMeasuringAgain.
  ///
  /// In en, this message translates to:
  /// **'Measuring the selected parameters again.'**
  String get hannaMeasuringAgain;

  /// No description provided for @hannaRemeasureFailed.
  ///
  /// In en, this message translates to:
  /// **'The meter didn\'t respond — nothing was measured again and the results are unchanged.'**
  String get hannaRemeasureFailed;

  /// No description provided for @environmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentTitle;

  /// No description provided for @environmentInclude.
  ///
  /// In en, this message translates to:
  /// **'Include environment readings from connected devices'**
  String get environmentInclude;

  /// No description provided for @environmentJustNow.
  ///
  /// In en, this message translates to:
  /// **'read just now'**
  String get environmentJustNow;

  /// No description provided for @environmentMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{read 1 minute ago} other{read {minutes} minutes ago}}'**
  String environmentMinutesAgo(int minutes);

  /// No description provided for @environmentUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Devices unreachable — the measurements will be saved without environment readings.'**
  String get environmentUnreachable;

  /// No description provided for @environmentAllMeasured.
  ///
  /// In en, this message translates to:
  /// **'All environment values were already measured in this session.'**
  String get environmentAllMeasured;

  /// No description provided for @hannaDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard measurements?'**
  String get hannaDiscardTitle;

  /// No description provided for @hannaDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The captured values haven\'t been saved and will be lost.'**
  String get hannaDiscardBody;

  /// No description provided for @hannaDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get hannaDiscard;

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

  /// Freshness line on an aquarium-list row (U7). {ago} is a relative time such as "2 d ago"; older tests use healthNotTestedDays instead.
  ///
  /// In en, this message translates to:
  /// **'Last tested {ago}'**
  String lastTestedAgo(String ago);

  /// No description provided for @healthScoreOf.
  ///
  /// In en, this message translates to:
  /// **'{score} of 100'**
  String healthScoreOf(int score);

  /// No description provided for @stabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Stability'**
  String get stabilityTitle;

  /// Feature name shown by the Pro-feature dialog and future paywall listings (U26).
  ///
  /// In en, this message translates to:
  /// **'Stability score'**
  String get stabilityScoreProName;

  /// No description provided for @stabilityGradeRockSolid.
  ///
  /// In en, this message translates to:
  /// **'Rock solid'**
  String get stabilityGradeRockSolid;

  /// No description provided for @stabilityGradeSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get stabilityGradeSteady;

  /// No description provided for @stabilityGradeVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get stabilityGradeVariable;

  /// No description provided for @stabilityGradeUnstable.
  ///
  /// In en, this message translates to:
  /// **'Unstable'**
  String get stabilityGradeUnstable;

  /// No description provided for @stabilityGradeUnknown.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get stabilityGradeUnknown;

  /// No description provided for @stabilityIntro.
  ///
  /// In en, this message translates to:
  /// **'How steadily each parameter has held over the last {days} days.'**
  String stabilityIntro(int days);

  /// No description provided for @stabilitySectionVariable.
  ///
  /// In en, this message translates to:
  /// **'Most variable'**
  String get stabilitySectionVariable;

  /// No description provided for @stabilitySectionSteady.
  ///
  /// In en, this message translates to:
  /// **'Holding steady'**
  String get stabilitySectionSteady;

  /// No description provided for @stabilitySectionInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get stabilitySectionInsufficient;

  /// Why a parameter has no stability sub-score: too few tests in the window.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tests in the last {days} days} one{1 test in the last {days} days} other{{count} tests in the last {days} days}}'**
  String stabilityTestCount(int count, int days);

  /// No description provided for @stabilityWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Stability window'**
  String get stabilityWindowTitle;

  /// No description provided for @stabilityWindowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Period the stability score looks at'**
  String get stabilityWindowSubtitle;

  /// Title of the dashboard card and bottom sheet listing rule-based observations about the tank (U28).
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// Feature name shown by the Pro-feature dialog and future paywall listings (U28).
  ///
  /// In en, this message translates to:
  /// **'Smart insights'**
  String get insightsProName;

  /// One-line explanation under the insights sheet title.
  ///
  /// In en, this message translates to:
  /// **'What your recent readings suggest to keep an eye on.'**
  String get insightsIntro;

  /// Trailing note on the insights card when more insights exist than the card previews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{+1 more} other{+{count} more}}'**
  String insightsMore(int count);

  /// Insight: value in the amber/red zone on the low side, not currently falling further. {param} is the localized parameter name.
  ///
  /// In en, this message translates to:
  /// **'{param} is below its target range'**
  String insightLow(Object param);

  /// Insight: value below range and the trend still points down.
  ///
  /// In en, this message translates to:
  /// **'{param} is low and still falling'**
  String insightLowWorsening(Object param);

  /// Insight: value in the amber/red zone on the high side, not currently rising further.
  ///
  /// In en, this message translates to:
  /// **'{param} is above its target range'**
  String insightHigh(Object param);

  /// Insight: value above range and the trend still points up.
  ///
  /// In en, this message translates to:
  /// **'{param} is high and still rising'**
  String insightHighWorsening(Object param);

  /// Insight: value out of range but the side (low/high) can't be determined.
  ///
  /// In en, this message translates to:
  /// **'{param} is outside its target range'**
  String insightOutOfRange(Object param);

  /// Insight: value still in range but trending down toward a zone bound. "d" is the abbreviation for days, as in the trend chips.
  ///
  /// In en, this message translates to:
  /// **'{param} is heading low — may leave its range in ~{days} d'**
  String insightForecastLow(Object param, int days);

  /// Insight: value still in range but trending up toward a zone bound.
  ///
  /// In en, this message translates to:
  /// **'{param} is heading high — may leave its range in ~{days} d'**
  String insightForecastHigh(Object param, int days);

  /// Insight: the parameter is in range, but its readings swing too much for a trend direction to be established, so no forecast is shown.
  ///
  /// In en, this message translates to:
  /// **'{param} is swinging rather than drifting — no reliable trend'**
  String insightOscillating(Object param);

  /// Positive insight: value out of range but moving back toward it; no time estimate available.
  ///
  /// In en, this message translates to:
  /// **'{param} is recovering toward its range'**
  String insightRecovering(Object param);

  /// Positive insight: value out of range but moving back toward it, with an estimated re-entry.
  ///
  /// In en, this message translates to:
  /// **'{param} is recovering — back in range in ~{days} d'**
  String insightRecoveringDays(Object param, int days);

  /// Insight: the parameter's latest test is older than the health score's freshness window.
  ///
  /// In en, this message translates to:
  /// **'{param} not tested in {days} d'**
  String insightStale(Object param, int days);

  /// Menu action and sheet title for the tank-summary export the user pastes into their own AI chat (U27).
  ///
  /// In en, this message translates to:
  /// **'Ask your AI'**
  String get aiSummaryAction;

  /// Explainer + privacy line at the top of the pre-share sheet: makes clear the text is a prompt the user pastes into an AI chat of their choice, and that the app sends nothing itself.
  ///
  /// In en, this message translates to:
  /// **'This is a ready-made prompt with your tank\'s data. Paste it into ChatGPT, Claude, Gemini or any other AI tool — everything is prepared on your device, nothing is sent anywhere.'**
  String get aiSummaryPrivacyNote;

  /// Small label above the preview box showing the exact prompt text.
  ///
  /// In en, this message translates to:
  /// **'Prompt preview'**
  String get aiSummaryPromptPreview;

  /// Primary button copying the prompt to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy prompt'**
  String get aiSummaryCopyPrompt;

  /// Window-length chip on the pre-share sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week} other{{count} weeks}}'**
  String aiSummaryWeeksChip(int count);

  /// SnackBar after the summary was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied — paste it into your AI chat.'**
  String get aiSummaryCopied;

  /// Shown in the pre-share sheet when the tank has no readings at all.
  ///
  /// In en, this message translates to:
  /// **'No readings yet — nothing to summarize.'**
  String get aiSummaryEmpty;

  /// Footer action on the Insights sheet linking to the AI-summary export.
  ///
  /// In en, this message translates to:
  /// **'Want a deeper look? Ask your AI'**
  String get aiSummaryInsightsFooter;

  /// Instruction paragraph at the top of the exported document, addressed to the AI the user pastes it into.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, one{I keep a saltwater reef aquarium and track it with an app. Below is my tank\'s data from the last week. Please analyze it, point out risks or trends I should address, and suggest what to check or adjust.} other{I keep a saltwater reef aquarium and track it with an app. Below is my tank\'s data from the last {weeks} weeks. Please analyze it, point out risks or trends I should address, and suggest what to check or adjust.}}'**
  String aiSummaryPreamble(int weeks);

  /// Markdown H1 of the exported document.
  ///
  /// In en, this message translates to:
  /// **'{tank} — saltwater aquarium summary'**
  String aiSummaryDocTitle(Object tank);

  /// Tank-profile fragment; {date} is an ISO date.
  ///
  /// In en, this message translates to:
  /// **'running since {date}'**
  String aiSummaryRunningSince(Object date);

  /// No description provided for @aiSummaryExportedLine.
  ///
  /// In en, this message translates to:
  /// **'Exported {date}.'**
  String aiSummaryExportedLine(Object date);

  /// No description provided for @aiSummaryStatusHeading.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get aiSummaryStatusHeading;

  /// No description provided for @aiSummaryHealthLine.
  ///
  /// In en, this message translates to:
  /// **'Health score: {score} of 100 ({grade})'**
  String aiSummaryHealthLine(int score, Object grade);

  /// No description provided for @aiSummaryStabilityLine.
  ///
  /// In en, this message translates to:
  /// **'Stability score: {score} of 100 ({grade}) over the last {days} days'**
  String aiSummaryStabilityLine(int score, Object grade, int days);

  /// Lead-in line before the exported insight list.
  ///
  /// In en, this message translates to:
  /// **'The app\'s rule-based observations:'**
  String get aiSummaryObservationsLead;

  /// No description provided for @aiSummaryParamsHeading.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get aiSummaryParamsHeading;

  /// No description provided for @aiSummaryTestedOn.
  ///
  /// In en, this message translates to:
  /// **'last tested {date}'**
  String aiSummaryTestedOn(Object date);

  /// Green-range fragment, e.g. "Target 7.5–9".
  ///
  /// In en, this message translates to:
  /// **'Target {range}'**
  String aiSummaryTargetRange(Object range);

  /// Amber-range fragment, e.g. "acceptable 7–11".
  ///
  /// In en, this message translates to:
  /// **'acceptable {range}'**
  String aiSummaryAcceptableRange(Object range);

  /// No description provided for @aiSummaryColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get aiSummaryColDate;

  /// No description provided for @aiSummaryColValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get aiSummaryColValue;

  /// No description provided for @aiSummaryColNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get aiSummaryColNote;

  /// No description provided for @aiSummaryColElement.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get aiSummaryColElement;

  /// No description provided for @aiSummaryColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get aiSummaryColStatus;

  /// Cap note under a truncated per-parameter history table.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most recent of {total} tests.'**
  String aiSummaryShowingTests(int shown, int total);

  /// No description provided for @aiSummaryDosingHeading.
  ///
  /// In en, this message translates to:
  /// **'Dosing plan'**
  String get aiSummaryDosingHeading;

  /// Average daily dose fragment; {amount} carries value + unit.
  ///
  /// In en, this message translates to:
  /// **'≈{amount} per day'**
  String aiSummaryDailyEquivalent(Object amount);

  /// No description provided for @aiSummarySinceDate.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String aiSummarySinceDate(Object date);

  /// Label for a logged manual dose line in the export.
  ///
  /// In en, this message translates to:
  /// **'one-off dose'**
  String get aiSummaryOneOff;

  /// No description provided for @aiSummaryActionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Maintenance in this period'**
  String get aiSummaryActionsHeading;

  /// No description provided for @aiSummaryMicroHeading.
  ///
  /// In en, this message translates to:
  /// **'Trace elements (latest measured values)'**
  String get aiSummaryMicroHeading;

  /// No description provided for @dashboardSection.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardSection;

  /// Settings row title for choosing how the Measurements dashboard arranges its cards.
  ///
  /// In en, this message translates to:
  /// **'Dashboard layout'**
  String get dashboardLayoutTitle;

  /// No description provided for @dashboardLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How the Measurements tab arranges cards'**
  String get dashboardLayoutSubtitle;

  /// Dashboard layout option: cards organized into labelled categories (Core chemistry, Nutrients, Ratios, Environment).
  ///
  /// In en, this message translates to:
  /// **'Grouped'**
  String get dashboardLayoutGrouped;

  /// Dashboard layout option: the original single flat list of cards in one custom order.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get dashboardLayoutFlat;

  /// Dashboard layout option: the flat card grid where each card also shows a small 14-day graph of recent readings.
  ///
  /// In en, this message translates to:
  /// **'Flat with graphs'**
  String get dashboardLayoutFlatGraph;

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

  /// RO screen: title of the usage-level card and its picker dialog. Picking a level (light/moderate/heavy) applies typical replacement intervals to the standard parts.
  ///
  /// In en, this message translates to:
  /// **'Usage intensity'**
  String get roUsageTitle;

  /// RO usage dialog: body text above the three level options. Must warn before the tap that picking a level overwrites the replacement interval of every standard part (the built-in, typed ones) with the level's preset, hand-tuned intervals included; custom parts the user added are never touched and any part can still be edited afterwards. Use this file's own word for an RO part (see roCustomStage, roAddStage, roAllOk) on both sides of the standard-vs-custom contrast, and make sure the 'including any you set yourself' aside clearly attaches to the intervals, not to the parts.
  ///
  /// In en, this message translates to:
  /// **'How much water your unit makes. Picking a level resets the replacement intervals of all standard parts — including any you set yourself — to that level\'s typical values; custom parts are left alone, and you can fine-tune each part afterwards.'**
  String get roUsageDialogBody;

  /// RO usage level: little water produced per month.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get roUsageLight;

  /// RO usage level: the typical middle bracket (the default).
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get roUsageModerate;

  /// RO usage level: a lot of water produced per month.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get roUsageHeavy;

  /// No description provided for @roUsageLightHint.
  ///
  /// In en, this message translates to:
  /// **'Under ~300 L (80 gal) a month — top-offs and small water changes'**
  String get roUsageLightHint;

  /// No description provided for @roUsageModerateHint.
  ///
  /// In en, this message translates to:
  /// **'About 300–1000 L (80–260 gal) a month — a typical single reef'**
  String get roUsageModerateHint;

  /// No description provided for @roUsageHeavyHint.
  ///
  /// In en, this message translates to:
  /// **'Over ~1000 L (260 gal) a month — large or multiple tanks'**
  String get roUsageHeavyHint;

  /// SnackBar after picking a usage level: the standard parts' replacement intervals were set to the level's typical values; custom parts were left unchanged. Use the same word for an RO part as roUsageDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Replacement intervals reset for the standard parts'**
  String get roUsageApplied;

  /// No description provided for @notifRoTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace RO filters'**
  String get notifRoTitle;

  /// No description provided for @reefFactoryTitle.
  ///
  /// In en, this message translates to:
  /// **'ReefFactory devices'**
  String get reefFactoryTitle;

  /// No description provided for @reefFactoryMenu.
  ///
  /// In en, this message translates to:
  /// **'ReefFactory devices'**
  String get reefFactoryMenu;

  /// No description provided for @reefFactoryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app only reads live values from your ReefFactory devices. It can\'t change settings, calibrate, or update firmware — use the ReefFactory app for that. Reading works only while your phone is on the same Wi-Fi network as the devices.'**
  String get reefFactoryDisclaimer;

  /// No description provided for @reefFactoryAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get reefFactoryAddDevice;

  /// No description provided for @reefFactoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No devices yet'**
  String get reefFactoryEmptyTitle;

  /// No description provided for @reefFactoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a ReefFactory meter by its IP address or hostname to read its live values.'**
  String get reefFactoryEmptyBody;

  /// No description provided for @reefFactoryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get reefFactoryRefresh;

  /// No description provided for @reefFactorySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reefFactorySave;

  /// No description provided for @reefFactoryRefreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get reefFactoryRefreshAll;

  /// No description provided for @reefFactorySaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save all'**
  String get reefFactorySaveAll;

  /// No description provided for @reefFactoryNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save yet — tap Refresh all first.'**
  String get reefFactoryNothingToSave;

  /// No description provided for @reefFactorySavedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Saved 1 reading} other{Saved {count} readings}}'**
  String reefFactorySavedSnack(int count);

  /// No description provided for @reefFactoryNotReadYet.
  ///
  /// In en, this message translates to:
  /// **'Tap Refresh all to read the current value.'**
  String get reefFactoryNotReadYet;

  /// Badge on a Temperature Controller card while its heater output is running
  ///
  /// In en, this message translates to:
  /// **'Heating'**
  String get reefFactoryHeating;

  /// Badge on a Temperature Controller card while its cooling output is running
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get reefFactoryCooling;

  /// No description provided for @reefFactoryNoTank.
  ///
  /// In en, this message translates to:
  /// **'Assign a tank first to save readings.'**
  String get reefFactoryNoTank;

  /// No description provided for @reefFactoryTankLabel.
  ///
  /// In en, this message translates to:
  /// **'Tank'**
  String get reefFactoryTankLabel;

  /// No description provided for @reefFactorySelectTank.
  ///
  /// In en, this message translates to:
  /// **'Select a tank'**
  String get reefFactorySelectTank;

  /// No description provided for @reefFactoryMoveToTank.
  ///
  /// In en, this message translates to:
  /// **'Move to another tank'**
  String get reefFactoryMoveToTank;

  /// Title of the dialog opened by the device card's Edit menu item
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get reefFactoryRenameDevice;

  /// No description provided for @reefFactoryDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reefFactoryDeviceNameLabel;

  /// No description provided for @reefFactoryRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get reefFactoryRemove;

  /// No description provided for @reefFactoryRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this list? Its saved readings are kept.'**
  String reefFactoryRemoveConfirm(Object name);

  /// No description provided for @reefFactoryHostLabel.
  ///
  /// In en, this message translates to:
  /// **'IP address or hostname'**
  String get reefFactoryHostLabel;

  /// No description provided for @reefFactoryHostHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.50'**
  String get reefFactoryHostHint;

  /// No description provided for @reefFactoryHostHelp.
  ///
  /// In en, this message translates to:
  /// **'Find it in your ReefFactory app or router. A DHCP reservation keeps it from changing. Your phone must be on the same Wi-Fi network as the device.'**
  String get reefFactoryHostHelp;

  /// No description provided for @reefFactoryCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get reefFactoryCheck;

  /// No description provided for @reefFactoryFound.
  ///
  /// In en, this message translates to:
  /// **'Found: {model}'**
  String reefFactoryFound(Object model);

  /// No description provided for @reefFactoryErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach that address. Check the device is on and on this network.'**
  String get reefFactoryErrUnreachable;

  /// No description provided for @reefFactoryErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connected, but no reading arrived.'**
  String get reefFactoryErrTimeout;

  /// No description provided for @reefFactoryErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That device model isn\'t supported yet.'**
  String get reefFactoryErrUnsupported;

  /// No description provided for @reefFactoryErrProtocol.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the device.'**
  String get reefFactoryErrProtocol;

  /// No description provided for @reefBeatTitle.
  ///
  /// In en, this message translates to:
  /// **'ReefBeat devices'**
  String get reefBeatTitle;

  /// No description provided for @reefBeatMenu.
  ///
  /// In en, this message translates to:
  /// **'ReefBeat devices'**
  String get reefBeatMenu;

  /// No description provided for @reefBeatSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live data from Red Sea ReefBeat devices'**
  String get reefBeatSettingsSubtitle;

  /// No description provided for @reefBeatDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app only reads live data from your Red Sea ReefBeat devices. It can\'t dose, change schedules or calibrate — use the ReefBeat app for that. Reading works only while your phone is on the same Wi-Fi network as the devices.'**
  String get reefBeatDisclaimer;

  /// No description provided for @reefBeatAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get reefBeatAddDevice;

  /// No description provided for @reefBeatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No devices yet'**
  String get reefBeatEmptyTitle;

  /// No description provided for @reefBeatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Scan your Wi-Fi network to find your Red Sea ReefBeat devices — ReefDose, ReefATO, ReefMat, ReefRun, ReefLED, ReefWave and ReefControl — or add one by its IP address.'**
  String get reefBeatEmptyBody;

  /// No description provided for @reefBeatRefreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get reefBeatRefreshAll;

  /// No description provided for @reefBeatNotReadYet.
  ///
  /// In en, this message translates to:
  /// **'Tap Refresh all to read the current status.'**
  String get reefBeatNotReadYet;

  /// No description provided for @reefBeatTankLabel.
  ///
  /// In en, this message translates to:
  /// **'Tank'**
  String get reefBeatTankLabel;

  /// No description provided for @reefBeatSelectTank.
  ///
  /// In en, this message translates to:
  /// **'Select a tank'**
  String get reefBeatSelectTank;

  /// No description provided for @reefBeatMoveToTank.
  ///
  /// In en, this message translates to:
  /// **'Move to another tank'**
  String get reefBeatMoveToTank;

  /// Title of the dialog opened by the device card's Edit menu item
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get reefBeatRenameDevice;

  /// No description provided for @reefBeatDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reefBeatDeviceNameLabel;

  /// No description provided for @reefBeatRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get reefBeatRemove;

  /// No description provided for @reefBeatRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this list?'**
  String reefBeatRemoveConfirm(Object name);

  /// No description provided for @reefBeatHostLabel.
  ///
  /// In en, this message translates to:
  /// **'IP address or hostname'**
  String get reefBeatHostLabel;

  /// No description provided for @reefBeatHostHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.3'**
  String get reefBeatHostHint;

  /// No description provided for @reefBeatHostHelp.
  ///
  /// In en, this message translates to:
  /// **'Find it in your router\'s client list. A DHCP reservation keeps it from changing. Your phone must be on the same Wi-Fi network as the device.'**
  String get reefBeatHostHelp;

  /// No description provided for @reefBeatCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get reefBeatCheck;

  /// No description provided for @reefBeatFound.
  ///
  /// In en, this message translates to:
  /// **'Found: {model}'**
  String reefBeatFound(Object model);

  /// No description provided for @reefBeatErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach that address. Check the device is on and on this network.'**
  String get reefBeatErrUnreachable;

  /// No description provided for @reefBeatErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connected, but no answer arrived.'**
  String get reefBeatErrTimeout;

  /// No description provided for @reefBeatErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That ReefBeat device type isn\'t supported yet.'**
  String get reefBeatErrUnsupported;

  /// No description provided for @reefBeatErrProtocol.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the device.'**
  String get reefBeatErrProtocol;

  /// Fallback label for a dosing head with no supplement name
  ///
  /// In en, this message translates to:
  /// **'Head {number}'**
  String reefBeatHead(int number);

  /// No description provided for @reefBeatHeadOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reefBeatHeadOff;

  /// Days of supplement remaining in a dosing head's container
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day left} other{{count} days left}}'**
  String reefBeatDaysLeft(int count);

  /// Volume dosed today out of the scheduled daily total, both pre-formatted numbers
  ///
  /// In en, this message translates to:
  /// **'{dosed} / {daily} ml'**
  String reefBeatDosedOfDaily(Object dosed, Object daily);

  /// Volume dosed today when the pump reports no scheduled daily total
  ///
  /// In en, this message translates to:
  /// **'{dosed} ml'**
  String reefBeatDosedNoDaily(Object dosed);

  /// Value line for a head with no schedule where everything dosed today was dosed by hand
  ///
  /// In en, this message translates to:
  /// **'{volume} ml manual'**
  String reefBeatDosedManual(Object volume);

  /// Suffix under a head's gauge: volume dosed by hand today, on top of the schedule
  ///
  /// In en, this message translates to:
  /// **'+{volume} ml manual'**
  String reefBeatDosedManualExtra(Object volume);

  /// Caption under a head's gauge: scheduled volume still to be dosed today
  ///
  /// In en, this message translates to:
  /// **'{volume} ml due'**
  String reefBeatDoseDue(Object volume);

  /// Caption under a head's gauge when today's whole scheduled volume has been dosed
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get reefBeatPlanComplete;

  /// Caption under a head's gauge: scheduled doses delivered today out of the day's total
  ///
  /// In en, this message translates to:
  /// **'Doses {done}/{total}'**
  String reefBeatDoseCount(int done, int total);

  /// Screen-reader label for a head's dose gauge, spelling out what the two numbers mean
  ///
  /// In en, this message translates to:
  /// **'{dosed} of {daily} ml of today\'s schedule dosed'**
  String reefBeatDosedSemantics(Object dosed, Object daily);

  /// Screen-reader label appended to the dose gauge when the head also received manual doses today
  ///
  /// In en, this message translates to:
  /// **'plus {volume} ml dosed manually'**
  String reefBeatDosedManualSemantics(Object volume);

  /// Card menu item and sheet title: the doses a ReefDose pump still has scheduled for today
  ///
  /// In en, this message translates to:
  /// **'Today\'s dosing queue'**
  String get reefBeatDosingQueue;

  /// Shown in the dosing-queue sheet when the pump has finished every scheduled dose for today
  ///
  /// In en, this message translates to:
  /// **'No doses left today'**
  String get reefBeatDosingQueueEmpty;

  /// Summary line above the dosing queue: how many doses are still due today and their total volume
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 dose} other{{count} doses}} · {volume} ml'**
  String reefBeatDosingQueueTotal(int count, Object volume);

  /// Volume of a single queued dose; {volume} is a pre-formatted number
  ///
  /// In en, this message translates to:
  /// **'{volume} ml'**
  String reefBeatDosingQueueVolume(Object volume);

  /// No description provided for @reefBeatRecalibration.
  ///
  /// In en, this message translates to:
  /// **'Needs recalibration'**
  String get reefBeatRecalibration;

  /// No description provided for @reefBeatMissedDose.
  ///
  /// In en, this message translates to:
  /// **'Missed dose: {volume} ml'**
  String reefBeatMissedDose(Object volume);

  /// No description provided for @reefBeatTimeError.
  ///
  /// In en, this message translates to:
  /// **'Device clock error'**
  String get reefBeatTimeError;

  /// No description provided for @reefBeatBatteryLow.
  ///
  /// In en, this message translates to:
  /// **'Backup battery low'**
  String get reefBeatBatteryLow;

  /// No description provided for @reefBeatAtoLeak.
  ///
  /// In en, this message translates to:
  /// **'Leak detected!'**
  String get reefBeatAtoLeak;

  /// No description provided for @reefBeatAtoSensorError.
  ///
  /// In en, this message translates to:
  /// **'Level sensor problem'**
  String get reefBeatAtoSensorError;

  /// No description provided for @reefBeatAtoFilling.
  ///
  /// In en, this message translates to:
  /// **'Filling now'**
  String get reefBeatAtoFilling;

  /// No description provided for @reefBeatAtoWaterLevel.
  ///
  /// In en, this message translates to:
  /// **'Water level'**
  String get reefBeatAtoWaterLevel;

  /// ATO water-level value: at the desired level (firmware "desired_level_1"/"desired_level_2")
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get reefBeatAtoLevelOk;

  /// ATO water-level value: water below the desired level (firmware "below") — a warning state shown amber
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get reefBeatAtoLevelLow;

  /// ATO water-level value: water above the desired level (firmware "above") — a warning state shown amber
  ///
  /// In en, this message translates to:
  /// **'Above'**
  String get reefBeatAtoLevelAbove;

  /// No description provided for @reefBeatAtoTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get reefBeatAtoTemperature;

  /// No description provided for @reefBeatAtoToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reefBeatAtoToday;

  /// Number of auto-top-off fills the ATO ran today
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 fill} other{{count} fills}}'**
  String reefBeatAtoFills(int count);

  /// No description provided for @reefBeatAtoEvaporation.
  ///
  /// In en, this message translates to:
  /// **'Evaporation'**
  String get reefBeatAtoEvaporation;

  /// Average daily top-off volume; {volume} is pre-formatted with its unit (e.g. "3.0 L")
  ///
  /// In en, this message translates to:
  /// **'≈{volume}/day'**
  String reefBeatAtoPerDay(Object volume);

  /// No description provided for @reefBeatAtoReservoir.
  ///
  /// In en, this message translates to:
  /// **'Reservoir'**
  String get reefBeatAtoReservoir;

  /// Row label on ReefATO and ReefControl cards for a leak-detection sensor's status
  ///
  /// In en, this message translates to:
  /// **'Leak sensor'**
  String get reefBeatAtoLeakSensor;

  /// ReefATO leak-sensor status: no sensor is attached
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get reefBeatAtoLeakNotConnected;

  /// ReefATO leak-sensor status: a sensor is attached but not enabled in its settings
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get reefBeatAtoLeakNotEnabled;

  /// Leak-sensor status value: no water detected
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get reefBeatAtoLeakDry;

  /// Leak-sensor status value: the sensor detects fresh (RO/DI) water where it shouldn't be
  ///
  /// In en, this message translates to:
  /// **'RO/DI water leak'**
  String get reefBeatAtoLeakRodi;

  /// Leak-sensor status value: the sensor detects aquarium water where it shouldn't be (firmware aquarium_water_leak)
  ///
  /// In en, this message translates to:
  /// **'Aquarium water leak'**
  String get reefBeatAtoLeakAquarium;

  /// No description provided for @reefBeatMatRoll.
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get reefBeatMatRoll;

  /// Warning chip on the ReefMat card when the mat reports mode "end_of_roll" — the fleece has actually run out and the mat has stopped
  ///
  /// In en, this message translates to:
  /// **'End of roll'**
  String get reefBeatMatRollEmpty;

  /// No description provided for @reefBeatMatRollLow.
  ///
  /// In en, this message translates to:
  /// **'Roll running low'**
  String get reefBeatMatRollLow;

  /// No description provided for @reefBeatMatCleanSensor.
  ///
  /// In en, this message translates to:
  /// **'Clean the sensor'**
  String get reefBeatMatCleanSensor;

  /// No description provided for @reefBeatMatAutoAdvanceOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-advance off'**
  String get reefBeatMatAutoAdvanceOff;

  /// No description provided for @reefBeatMatAdvancing.
  ///
  /// In en, this message translates to:
  /// **'Advancing now'**
  String get reefBeatMatAdvancing;

  /// No description provided for @reefBeatMatUsedToday.
  ///
  /// In en, this message translates to:
  /// **'Used today'**
  String get reefBeatMatUsedToday;

  /// No description provided for @reefBeatMatAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get reefBeatMatAverage;

  /// Average daily fleece usage of a ReefMat; {length} is pre-formatted with its unit (e.g. "84 cm")
  ///
  /// In en, this message translates to:
  /// **'≈{length}/day'**
  String reefBeatMatPerDay(Object length);

  /// No description provided for @reefBeatMatInstalled.
  ///
  /// In en, this message translates to:
  /// **'Roll installed'**
  String get reefBeatMatInstalled;

  /// How long the mat's current fleece roll has been running, shown after its install date
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String reefBeatMatRollAge(int count);

  /// No description provided for @reefBeatMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get reefBeatMode;

  /// A percentage value on a device card (pump speed, light channel, fan duty)
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String reefBeatPercent(int value);

  /// Fallback label for a ReefRun pump socket with no user-set name
  ///
  /// In en, this message translates to:
  /// **'Pump {number}'**
  String reefBeatRunPump(int number);

  /// No description provided for @reefBeatRunScheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Schedule off'**
  String get reefBeatRunScheduleOff;

  /// No description provided for @reefBeatRunTemperature.
  ///
  /// In en, this message translates to:
  /// **'Motor temperature'**
  String get reefBeatRunTemperature;

  /// No description provided for @reefBeatRunMissingPump.
  ///
  /// In en, this message translates to:
  /// **'Pump not detected'**
  String get reefBeatRunMissingPump;

  /// No description provided for @reefBeatRunMissingSensor.
  ///
  /// In en, this message translates to:
  /// **'Sensor not detected'**
  String get reefBeatRunMissingSensor;

  /// Raw firmware state string of a ReefRun pump that isn't operational
  ///
  /// In en, this message translates to:
  /// **'Pump state: {state}'**
  String reefBeatRunState(Object state);

  /// Chip on a ReefRun skimmer pump that paused itself because its collection cup is full (firmware state "full_cup")
  ///
  /// In en, this message translates to:
  /// **'Full cup'**
  String get reefBeatRunFullCup;

  /// Chip on a ReefRun skimmer pump that paused itself because its sensor detected over-skimming (firmware state "over-skimming")
  ///
  /// In en, this message translates to:
  /// **'Over-skimming'**
  String get reefBeatRunOverSkimming;

  /// No description provided for @reefBeatRunSensorOffline.
  ///
  /// In en, this message translates to:
  /// **'Level sensor offline'**
  String get reefBeatRunSensorOffline;

  /// Badge on a ReefRun pump whose speed is driven by the overflow (water-level) sensor
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get reefBeatRunSensorBadge;

  /// No description provided for @reefBeatLightWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get reefBeatLightWhite;

  /// No description provided for @reefBeatLightBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get reefBeatLightBlue;

  /// No description provided for @reefBeatLightMoon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get reefBeatLightMoon;

  /// No description provided for @reefBeatLightFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get reefBeatLightFan;

  /// No description provided for @reefBeatLightTemperature.
  ///
  /// In en, this message translates to:
  /// **'Heatsink'**
  String get reefBeatLightTemperature;

  /// No description provided for @reefBeatLightTilt.
  ///
  /// In en, this message translates to:
  /// **'Fixture tilted'**
  String get reefBeatLightTilt;

  /// ReefLED acclimation mode is ramping intensity up over this many more days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Acclimation: 1 day left} other{Acclimation: {count} days left}}'**
  String reefBeatLightAcclimation(int count);

  /// No description provided for @reefBeatLightAcclimationOn.
  ///
  /// In en, this message translates to:
  /// **'Acclimation running'**
  String get reefBeatLightAcclimationOn;

  /// No description provided for @reefBeatLightMoonPhase.
  ///
  /// In en, this message translates to:
  /// **'Moon phase'**
  String get reefBeatLightMoonPhase;

  /// Lunar phase name and the day within the simulated lunar cycle
  ///
  /// In en, this message translates to:
  /// **'{name}, day {day}'**
  String reefBeatLightMoonDay(Object name, int day);

  /// No description provided for @reefBeatWaveGroup.
  ///
  /// In en, this message translates to:
  /// **'ReefWave pumps'**
  String get reefBeatWaveGroup;

  /// No description provided for @apexTitle.
  ///
  /// In en, this message translates to:
  /// **'Neptune Apex'**
  String get apexTitle;

  /// No description provided for @apexMenu.
  ///
  /// In en, this message translates to:
  /// **'Neptune Apex'**
  String get apexMenu;

  /// No description provided for @apexSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live probe values and outlet status from an Apex'**
  String get apexSettingsSubtitle;

  /// No description provided for @apexDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app only reads your Apex. It can\'t switch outlets, start feed cycles or change programs — use Fusion or the Apex web page for that. Reading works only while your phone is on the same Wi-Fi network as the controller.'**
  String get apexDisclaimer;

  /// No description provided for @apexAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add controller'**
  String get apexAddDevice;

  /// No description provided for @apexEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No controllers yet'**
  String get apexEmptyTitle;

  /// No description provided for @apexEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your Apex by its IP address and the login you use on its web page.'**
  String get apexEmptyBody;

  /// No description provided for @apexRefreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get apexRefreshAll;

  /// No description provided for @apexSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save all'**
  String get apexSaveAll;

  /// No description provided for @apexSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get apexSave;

  /// No description provided for @apexSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Saved 1 reading} other{Saved {count} readings}}'**
  String apexSavedSnack(int count);

  /// No description provided for @apexNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save yet.'**
  String get apexNothingToSave;

  /// No description provided for @apexNoTank.
  ///
  /// In en, this message translates to:
  /// **'Assign this controller to an aquarium to save its readings.'**
  String get apexNoTank;

  /// No description provided for @apexNotReadYet.
  ///
  /// In en, this message translates to:
  /// **'Tap Refresh all to read the current values.'**
  String get apexNotReadYet;

  /// No description provided for @apexNoProbes.
  ///
  /// In en, this message translates to:
  /// **'This controller has no probes the app can save.'**
  String get apexNoProbes;

  /// No description provided for @apexOutlets.
  ///
  /// In en, this message translates to:
  /// **'Outlets'**
  String get apexOutlets;

  /// Expands a controller card's outlet list beyond the first few
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String apexShowAll(int count);

  /// No description provided for @apexShowFewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get apexShowFewer;

  /// Outlets a person switched by hand, so they no longer follow the Apex program
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 outlet overridden} other{{count} outlets overridden}}'**
  String apexOverridden(int count);

  /// Screen-reader state of an outlet pill whose dot is filled: the outlet is powered on. Read as '<outlet name>, on'
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get apexOutletOnSemantics;

  /// Screen-reader state of an outlet pill whose ring is hollow: the outlet is powered off. Read as '<outlet name>, off'
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get apexOutletOffSemantics;

  /// Screen-reader state of an outlet pill showing a dash: a variable output (pump ramp/profile, e.g. TBL/PF1) that is neither on nor off
  ///
  /// In en, this message translates to:
  /// **'profile-driven'**
  String get apexOutletProfileSemantics;

  /// Screen-reader suffix for an outlet someone switched by hand, so it no longer follows the Apex program. Appended as '<outlet name>, on, manually overridden'
  ///
  /// In en, this message translates to:
  /// **'manually overridden'**
  String get apexOutletOverriddenSemantics;

  /// A feed cycle (A-D) is currently pausing the pumps
  ///
  /// In en, this message translates to:
  /// **'Feed cycle {letter} running'**
  String apexFeedRunning(Object letter);

  /// No description provided for @apexRenameDevice.
  ///
  /// In en, this message translates to:
  /// **'Rename controller'**
  String get apexRenameDevice;

  /// No description provided for @apexDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Controller name'**
  String get apexDeviceNameLabel;

  /// No description provided for @apexCredentialsMenu.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get apexCredentialsMenu;

  /// No description provided for @apexMoveToTank.
  ///
  /// In en, this message translates to:
  /// **'Move to another aquarium'**
  String get apexMoveToTank;

  /// No description provided for @apexRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get apexRemove;

  /// No description provided for @apexRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? Its saved readings stay.'**
  String apexRemoveConfirm(Object name);

  /// No description provided for @apexSelectTank.
  ///
  /// In en, this message translates to:
  /// **'Select aquarium'**
  String get apexSelectTank;

  /// No description provided for @apexHostLabel.
  ///
  /// In en, this message translates to:
  /// **'IP address or hostname'**
  String get apexHostLabel;

  /// No description provided for @apexHostHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.50'**
  String get apexHostHint;

  /// No description provided for @apexHostHelp.
  ///
  /// In en, this message translates to:
  /// **'The address you open the Apex web page at. Find it in Fusion under Misc Setup, or on your router.'**
  String get apexHostHelp;

  /// No description provided for @apexUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get apexUsernameLabel;

  /// No description provided for @apexPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get apexPasswordLabel;

  /// No description provided for @apexCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get apexCheck;

  /// Result of probing an address: the Apex generation and its serial number
  ///
  /// In en, this message translates to:
  /// **'Found {model} · {serial}'**
  String apexFound(Object model, Object serial);

  /// No description provided for @apexTankLabel.
  ///
  /// In en, this message translates to:
  /// **'Aquarium'**
  String get apexTankLabel;

  /// No description provided for @apexErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach that address. Check the controller is on and on this network.'**
  String get apexErrUnreachable;

  /// No description provided for @apexErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connected, but the controller didn\'t answer in time.'**
  String get apexErrTimeout;

  /// No description provided for @apexErrAuth.
  ///
  /// In en, this message translates to:
  /// **'The controller rejected that username or password.'**
  String get apexErrAuth;

  /// No description provided for @apexErrProtocol.
  ///
  /// In en, this message translates to:
  /// **'That address answered, but not like an Apex.'**
  String get apexErrProtocol;

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan network'**
  String get discoveryTitle;

  /// No description provided for @discoverySweeping.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices on your Wi-Fi…'**
  String get discoverySweeping;

  /// No description provided for @discoveryIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Checking what was found…'**
  String get discoveryIdentifying;

  /// No description provided for @discoveryDone.
  ///
  /// In en, this message translates to:
  /// **'Scan complete.'**
  String get discoveryDone;

  /// No description provided for @discoveryNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Your phone isn\'t connected to a Wi-Fi network. Connect to the same Wi-Fi as your devices and scan again.'**
  String get discoveryNoNetwork;

  /// No description provided for @discoveryNothingFoundHelp.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Check they\'re powered on and connected to this Wi-Fi network. Some guest networks stop devices from seeing each other. You can still add a device by typing its IP address.'**
  String get discoveryNothingFoundHelp;

  /// No description provided for @discoveryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get discoveryAdd;

  /// No description provided for @discoveryUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get discoveryUpdate;

  /// No description provided for @discoveryAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get discoveryAlreadyAdded;

  /// A device already on the list answered at a different IP than the stored one, usually after a DHCP lease change
  ///
  /// In en, this message translates to:
  /// **'Moved to {address}'**
  String discoveryAddressChanged(Object address);

  /// No description provided for @discoveryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get discoveryUnsupported;

  /// No description provided for @discoveryUnsupportedHelp.
  ///
  /// In en, this message translates to:
  /// **'This app can\'t read this device type yet.'**
  String get discoveryUnsupportedHelp;

  /// No description provided for @discoveryRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get discoveryRescan;

  /// No description provided for @discoveryManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Enter IP address'**
  String get discoveryManualEntry;

  /// No description provided for @discoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'The scan ran into an unexpected error and stopped. Try scanning again.'**
  String get discoveryFailed;

  /// Shown when the OS refuses local-network access outright (the iOS 14+ Local Network permission — the state doesn't exist on Android). Points at the iOS system setting.
  ///
  /// In en, this message translates to:
  /// **'ReefTracker isn\'t allowed to access your local network, so scanning and typed-in addresses can\'t work. Allow it under Settings → Privacy & Security → Local Network, then scan again.'**
  String get discoveryPermissionDenied;

  /// Shown in the manual add sheet when the probed device's identifier is already on the list, so adding it again would overwrite its name and tank
  ///
  /// In en, this message translates to:
  /// **'{name} is already added. Use Scan network to point it at a new address.'**
  String deviceAlreadyAdded(Object name);

  /// Title of the unified Devices screen (U41), which replaced the three per-vendor dashboards and the Settings inventory. Used by the standalone '/devices' route's app bar.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get devicesTitle;

  /// Label of the Devices bottom-navigation tab (U42). Short where 'devicesTitle' is not: a nav label has one line beside four siblings, and the tab bar is the context that 'Connected' otherwise supplies.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTab;

  /// The vendor selector's first chip: show every connected device regardless of brand.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get devicesAll;

  /// Scope line above the bulk actions when no vendor filter is applied.
  ///
  /// In en, this message translates to:
  /// **'All devices · {count}'**
  String devicesScopeAll(int count);

  /// Scope line above the bulk actions when one vendor is selected.
  ///
  /// In en, this message translates to:
  /// **'{vendor} · {count}'**
  String devicesScopeVendor(String vendor, int count);

  /// Reads every device currently in view — the vendor filter scopes it.
  ///
  /// In en, this message translates to:
  /// **'Refresh all ({count})'**
  String devicesRefreshAll(int count);

  /// Saves the readings of every meter in view. Count = distinct tank parameters that will be saved after duplicate readings are resolved.
  ///
  /// In en, this message translates to:
  /// **'Save all ({count})'**
  String devicesSaveAll(int count);

  /// The read-only notice shown when no vendor filter is applied; a vendor view swaps in that brand's own wording, which names its app.
  ///
  /// In en, this message translates to:
  /// **'This app only reads your devices. It can\'t change settings, dose, switch outlets or calibrate — use the manufacturer\'s own app for that. Reading works only while your phone is on the same Wi-Fi network as the devices.'**
  String get devicesDisclaimer;

  /// No description provided for @devicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No devices yet'**
  String get devicesEmptyTitle;

  /// No description provided for @devicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Connect a ReefFactory meter, a Red Sea ReefBeat device or a Neptune Apex controller on your local network — or measure with a Hanna checker over Bluetooth — to see it here.'**
  String get devicesEmptyBody;

  /// No description provided for @devicesAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get devicesAddDevice;

  /// The notice shown when the Hanna vendor filter is selected; replaces the generic Wi-Fi read-only wording, which doesn't fit a Bluetooth test kit.
  ///
  /// In en, this message translates to:
  /// **'The checker connects over Bluetooth only while a measurement runs — start one from its card. Finished measurements are saved into your log.'**
  String get devicesHannaDisclaimer;

  /// Title of the sheet asking which brand to add, shown only from the All view.
  ///
  /// In en, this message translates to:
  /// **'Which brand?'**
  String get devicesAddPickBrand;

  /// No description provided for @devicesReorderBrands.
  ///
  /// In en, this message translates to:
  /// **'Reorder brands'**
  String get devicesReorderBrands;

  /// States the save-precedence rule in the sheet that sets it: vendor order decides which device's value survives Save all.
  ///
  /// In en, this message translates to:
  /// **'When two devices report the same reading, the brand higher in this list wins.'**
  String get devicesReorderBrandsHint;

  /// Appended to the Save all confirmation when two devices reported the same parameter, naming the one whose value was kept.
  ///
  /// In en, this message translates to:
  /// **'{param} from {device}'**
  String devicesSourceNote(String param, String device);

  /// No description provided for @devicesProLocked.
  ///
  /// In en, this message translates to:
  /// **'Reading your devices live is part of ReefTracker Pro.'**
  String get devicesProLocked;

  /// How many devices a brand has, in the reorder sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 device} other{{count} devices}}'**
  String devicesCount(int count);

  /// Card menu item opening the device's model / address / last-seen facts, which used to live in the Settings inventory.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get devicesDetails;

  /// No description provided for @reefDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get reefDevicesTitle;

  /// No description provided for @reefDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ReefFactory meters, ReefBeat devices, Apex controllers and the Hanna checker'**
  String get reefDevicesSubtitle;

  /// No description provided for @reefDevicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No devices connected yet.'**
  String get reefDevicesEmpty;

  /// No description provided for @reefDevicesKindReefFactory.
  ///
  /// In en, this message translates to:
  /// **'ReefFactory'**
  String get reefDevicesKindReefFactory;

  /// No description provided for @reefDevicesKindReefBeat.
  ///
  /// In en, this message translates to:
  /// **'Red Sea'**
  String get reefDevicesKindReefBeat;

  /// No description provided for @reefDevicesKindApex.
  ///
  /// In en, this message translates to:
  /// **'Neptune Apex'**
  String get reefDevicesKindApex;

  /// No description provided for @reefDevicesKindHanna.
  ///
  /// In en, this message translates to:
  /// **'Hanna'**
  String get reefDevicesKindHanna;

  /// No description provided for @reefDevicesBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get reefDevicesBluetooth;

  /// No description provided for @reefDevicesLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {date}'**
  String reefDevicesLastSeen(Object date);

  /// Row label on the Hanna checker's device card
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get hannaSerialNumber;

  /// Row label on the Hanna checker's device card: when the checker last ran a measurement session
  ///
  /// In en, this message translates to:
  /// **'Last measurement'**
  String get hannaLastMeasurement;

  /// Button on the Hanna checker's device card starting a live Bluetooth measurement
  ///
  /// In en, this message translates to:
  /// **'New measurement'**
  String get hannaNewMeasurement;

  /// Title of the dialog opened by the Hanna card's Edit menu item
  ///
  /// In en, this message translates to:
  /// **'Rename checker'**
  String get hannaRenameDevice;

  /// No description provided for @hannaDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Checker name'**
  String get hannaDeviceNameLabel;

  /// No description provided for @hannaRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get hannaRemove;

  /// Confirmation for removing a Hanna checker from the Devices page; the row is re-created automatically on the next BLE connect
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? Its saved readings stay, and it returns after its next measurement.'**
  String hannaRemoveConfirm(Object name);

  /// Menu item on Manage parameters: drop every per-tank override.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetParamDefaults;

  /// Confirmation dialog title for resetting all parameters.
  ///
  /// In en, this message translates to:
  /// **'Reset all parameters to defaults?'**
  String get resetParamDefaultsTitle;

  /// Confirmation dialog body; warns that user-set boundaries are discarded.
  ///
  /// In en, this message translates to:
  /// **'Every parameter goes back to the recommended boundaries for this aquarium type, and microelements to their built-in defaults. Boundaries you set yourself are discarded. Your readings are kept.'**
  String get resetParamDefaultsBody;

  /// SnackBar after resetting all parameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters reset to defaults.'**
  String get paramDefaultsRestored;

  /// Action in the parameter editor: drop this parameter's override.
  ///
  /// In en, this message translates to:
  /// **'Reset this parameter to defaults'**
  String get resetThisParamDefaults;

  /// Generic confirm label for a reset action.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Editor hint shown while a parameter has no override.
  ///
  /// In en, this message translates to:
  /// **'Following the defaults'**
  String get followingDefaults;

  /// Settings row + subpage title of the wall display mode (U49): a wall-mounted tablet showing the tank's current values.
  ///
  /// In en, this message translates to:
  /// **'Wall display'**
  String get wallDisplayTitle;

  /// Settings row subtitle for the wall display.
  ///
  /// In en, this message translates to:
  /// **'An always-on board of your aquarium\'s values'**
  String get wallDisplaySubtitle;

  /// Informational banner at the top of the wall-display settings page, shown only on phone-size screens (shortest side under 600 dp). Purely advisory — nothing is gated by screen size.
  ///
  /// In en, this message translates to:
  /// **'The wall display is designed for a wall-mounted tablet. It still works on this smaller screen – you\'ll just see fewer cards per page.'**
  String get wallSmallScreenNote;

  /// Row on the wall-display settings page that enters the mode immediately.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get wallStartNow;

  /// No description provided for @wallStartNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the wall board on this screen'**
  String get wallStartNowSubtitle;

  /// Switch: boot straight into the wall display when the app starts.
  ///
  /// In en, this message translates to:
  /// **'Start on launch'**
  String get wallAutoStartTitle;

  /// No description provided for @wallAutoStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the wall display whenever the app starts on this device'**
  String get wallAutoStartSubtitle;

  /// Section label grouping the wall display's cadence and night options.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get wallBehaviourSection;

  /// Dropdown row: how often the wall polls connected devices.
  ///
  /// In en, this message translates to:
  /// **'Refresh every'**
  String get wallRefreshIntervalTitle;

  /// No description provided for @wallRefreshIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often connected devices are read'**
  String get wallRefreshIntervalSubtitle;

  /// Dropdown row: seconds each page stays when the grid paginates.
  ///
  /// In en, this message translates to:
  /// **'Page rotation'**
  String get wallPageSecondsTitle;

  /// No description provided for @wallPageSecondsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long each page stays before the next one'**
  String get wallPageSecondsSubtitle;

  /// Switch: dim the wall display during the night window.
  ///
  /// In en, this message translates to:
  /// **'Night dim'**
  String get wallNightTitle;

  /// No description provided for @wallNightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dim the screen at night; a tap lifts it for a minute'**
  String get wallNightSubtitle;

  /// Time-picker row: start of the night-dim window.
  ///
  /// In en, this message translates to:
  /// **'Dim from'**
  String get wallNightFromTitle;

  /// Time-picker row: end of the night-dim window.
  ///
  /// In en, this message translates to:
  /// **'Dim until'**
  String get wallNightToTitle;

  /// Section label for maintenance of the transient online measurements collected for wall-display graphs.
  ///
  /// In en, this message translates to:
  /// **'Collected data'**
  String get wallDataSection;

  /// Wall-display settings action that removes transient online device measurements used only by wall graphs.
  ///
  /// In en, this message translates to:
  /// **'Clear collected measurements'**
  String get wallClearSamplesTitle;

  /// No description provided for @wallClearSamplesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete online measurements used by wall graphs'**
  String get wallClearSamplesSubtitle;

  /// No description provided for @wallClearSamplesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear collected measurements?'**
  String get wallClearSamplesDialogTitle;

  /// Explains the wall-history cleanup choices and distinguishes transient device samples from the keeper's manual measurements.
  ///
  /// In en, this message translates to:
  /// **'Choose how much recent online history to keep. Manual measurements are not deleted.'**
  String get wallClearSamplesDialogBody;

  /// No description provided for @wallClearSamplesAll.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get wallClearSamplesAll;

  /// No description provided for @wallKeepSamples1h.
  ///
  /// In en, this message translates to:
  /// **'Keep the last 1 hour'**
  String get wallKeepSamples1h;

  /// No description provided for @wallKeepSamples4h.
  ///
  /// In en, this message translates to:
  /// **'Keep the last 4 hours'**
  String get wallKeepSamples4h;

  /// No description provided for @wallKeepSamples12h.
  ///
  /// In en, this message translates to:
  /// **'Keep the last 12 hours'**
  String get wallKeepSamples12h;

  /// No description provided for @wallSamplesHistoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Collected measurement history updated'**
  String get wallSamplesHistoryUpdated;

  /// Section label above the wall-card list (one card per device and parameter).
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get wallCardsSection;

  /// Explainer above the wall-card list; the traffic consequence of hiding everything is deliberate and must be stated.
  ///
  /// In en, this message translates to:
  /// **'Every value a device reports gets its own card. Hide the duplicates you don\'t want and drag the rest into place; hide all of a device\'s cards and the wall stops contacting it.'**
  String get wallCardsHint;

  /// Subtitle naming the source of a wall card fed by stored readings rather than a device.
  ///
  /// In en, this message translates to:
  /// **'Manual measurements'**
  String get wallStoredCard;

  /// Short seconds label in the interval dropdowns.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String wallSecondsLabel(int n);

  /// Short minutes label in the interval dropdowns.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String wallMinutesLabel(int n);

  /// Full-screen note when the wall display is opened with no tank.
  ///
  /// In en, this message translates to:
  /// **'No aquarium yet. Add one, then start the wall display.'**
  String get wallNoTank;

  /// Full-screen note when the wall display is opened without the entitlement.
  ///
  /// In en, this message translates to:
  /// **'The wall display is a PRO feature.'**
  String get wallProLocked;

  /// Transient hint teaching the wall display's 1.5-second exit hold.
  ///
  /// In en, this message translates to:
  /// **'Hold anywhere to exit'**
  String get wallExitHint;

  /// Header stamp: when the wall last completed a poll cycle.
  ///
  /// In en, this message translates to:
  /// **'updated {time}'**
  String wallUpdatedAt(Object time);

  /// Bottom strip listing today's due reminders as plain text.
  ///
  /// In en, this message translates to:
  /// **'Due today: {items}'**
  String wallDueToday(Object items);

  /// One due-today item: a parameter test that has reached its cadence.
  ///
  /// In en, this message translates to:
  /// **'{param} test'**
  String wallTestDue(Object param);

  /// Semantics label of the header connection dot with nothing to poll.
  ///
  /// In en, this message translates to:
  /// **'No devices'**
  String get wallNoDevices;

  /// Semantics label of the green header connection dot.
  ///
  /// In en, this message translates to:
  /// **'All devices reachable'**
  String get wallAllReachable;

  /// Semantics label of the amber header connection dot (partial failures).
  ///
  /// In en, this message translates to:
  /// **'A device is unreachable'**
  String get wallSomeUnreachable;

  /// Semantics label of the red header connection dot: every poll failing usually means the tablet lost the network, not four devices at once.
  ///
  /// In en, this message translates to:
  /// **'No device reachable — check the network'**
  String get wallNetworkDown;

  /// Provenance line of a stored-readings card: the last hand measurement and its age.
  ///
  /// In en, this message translates to:
  /// **'measured {ago}'**
  String wallMeasuredAgo(Object ago);

  /// Tile-footer label naming the 24-hour sample window of the graph.
  ///
  /// In en, this message translates to:
  /// **'24 h'**
  String get wallWindow24h;

  /// Tile-footer label naming the 14-day readings window of the fallback graph.
  ///
  /// In en, this message translates to:
  /// **'14 d'**
  String get wallWindow14d;

  /// Doser-tile head entry: days of supplement left, compact (under 100 days)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String wallHeadDays(int count);

  /// Doser-tile head entry: months of supplement left, compact (100 days and up, rounded to 30-day months)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 month} other{{count} months}}'**
  String wallHeadMonths(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'cs',
    'de',
    'en',
    'fr',
    'it',
    'pl',
    'ru',
  ].contains(locale.languageCode);

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
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
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
