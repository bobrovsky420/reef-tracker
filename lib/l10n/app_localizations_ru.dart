// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'ReefTracker';

  @override
  String get measurements => 'Измерения';

  @override
  String get settings => 'Настройки';

  @override
  String get manageParameters => 'Управление параметрами';

  @override
  String get moreOptions => 'Ещё';

  @override
  String get tourTankTitle => 'Твои аквариумы';

  @override
  String get tourTankDesc =>
      'Нажми здесь, чтобы переключаться между аквариумами или добавить новый.';

  @override
  String get tourCompareTitle => 'Сравнение';

  @override
  String get tourCompareDesc =>
      'Переключайся между карточками параметров и совмещёнными графиками.';

  @override
  String get tourParamsTitle => 'Управление параметрами';

  @override
  String get tourParamsDesc =>
      'Выбери, какие параметры воды отслеживать, и задай их целевые диапазоны.';

  @override
  String get tourDosingHistoryTitle => 'История дозирования';

  @override
  String get tourDosingHistoryDesc =>
      'Просматривай все прошлые и текущие периоды дозирования и удаляй запись, добавленную по ошибке.';

  @override
  String get tourDoseCalcTitle => 'Калькулятор дозировки';

  @override
  String get tourDoseCalcDesc =>
      'На вкладке «Дозирование» открой калькулятор, чтобы оценить суточную дозу, удерживающую элемент стабильным.';

  @override
  String get tourNext => 'Далее';

  @override
  String get tourDone => 'Понятно';

  @override
  String get tourSkip => 'Пропустить';

  @override
  String get replayTour => 'Показать обзор снова';

  @override
  String get replayTourSubtitle =>
      'Повторно показать подсказки к верхней панели';

  @override
  String get compareView => 'Сравнить графики';

  @override
  String get gridView => 'Сетка';

  @override
  String get addReading => 'Добавить измерение';

  @override
  String get addAquarium => 'Добавить аквариум';

  @override
  String get manageTanks => 'Управление аквариумами';

  @override
  String get chooseParameters => 'Выбрать параметры';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get stop => 'Остановить';

  @override
  String get apply => 'Применить';

  @override
  String get change => 'Изменить';

  @override
  String get undo => 'Отменить';

  @override
  String get itemDeleted => 'Удалено';

  @override
  String get reorder => 'Изменить порядок';

  @override
  String errorWith(Object message) {
    return 'Ошибка: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get welcomeTitle => 'Добро пожаловать в ReefTracker';

  @override
  String get welcomeBody =>
      'Создай свой первый аквариум, чтобы начать отслеживать параметры воды.';

  @override
  String get noParamsTracked =>
      'Для этого аквариума не отслеживаются параметры.';

  @override
  String get noReadings => 'Нет измерений';

  @override
  String get dashSectionCoreChemistry => 'Основная химия';

  @override
  String get dashSectionNutrients => 'Биогены';

  @override
  String get dashSectionRatios => 'Соотношения';

  @override
  String get dashSectionEnvironment => 'Среда';

  @override
  String gaugeIdealRange(String min, String max) {
    return 'норма $min–$max';
  }

  @override
  String get timeJustNow => 'только что';

  @override
  String timeMinAgo(int count) {
    return '$count мин назад';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get aquariums => 'Аквариумы';

  @override
  String get noAquariumsYet => 'Пока нет аквариумов.';

  @override
  String get makeActive => 'Сделать активным';

  @override
  String get active => 'Активный';

  @override
  String get edit => 'Изменить';

  @override
  String deleteTankTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteTankBody =>
      'Это навсегда удалит аквариум и все его измерения.';

  @override
  String tankDeleted(Object name) {
    return 'Аквариум «$name» удалён';
  }

  @override
  String get newAquarium => 'Новый аквариум';

  @override
  String get editAquarium => 'Изменить аквариум';

  @override
  String get name => 'Название';

  @override
  String get nameHint => 'напр. Риф в гостиной';

  @override
  String get enterAName => 'Введи название';

  @override
  String get setupType => 'Тип аквариума';

  @override
  String get presetSeedNote =>
      'Для этого типа аквариума будут заданы параметры по умолчанию и границы зон. Их можно настроить в любой момент.';

  @override
  String get fishOnlyPresetNote =>
      'Профиль «Только рыбы» не задаёт границы для щёлочности, кальция, магния и фосфатов – если ты отслеживаешь эти параметры, у них не будет цветных зон, пока ты не задашь собственные границы.';

  @override
  String get volumeOptional => 'Объём (необязательно)';

  @override
  String get vendorOptional => 'Производитель (необязательно)';

  @override
  String get modelOptional => 'Модель (необязательно)';

  @override
  String get notesOptional => 'Заметки (необязательно)';

  @override
  String get createAquarium => 'Создать аквариум';

  @override
  String litersSuffix(Object value) {
    return '$value л';
  }

  @override
  String gallonsSuffix(Object value) {
    return '$value гал';
  }

  @override
  String get startDate => 'Дата запуска';

  @override
  String get notSet => 'Не задано';

  @override
  String get setDate => 'Задать';

  @override
  String get clear => 'Очистить';

  @override
  String get parameters => 'Параметры';

  @override
  String get noActiveAquarium => 'Нет активного аквариума.';

  @override
  String get noBoundariesSet => 'Границы не заданы';

  @override
  String boundsSummary(
    Object greenLow,
    Object greenHigh,
    Object unit,
    Object amberLow,
    Object amberHigh,
  ) {
    return 'OK $greenLow–$greenHigh $unit  •  красная <$amberLow / >$amberHigh';
  }

  @override
  String get editZones => 'Изменить зоны';

  @override
  String get addParameter => 'Добавить параметр';

  @override
  String get allParametersAdded => 'Все параметры уже добавлены.';

  @override
  String get untrackParameter => 'Не отслеживать';

  @override
  String get parameterUntracked =>
      'Параметр больше не отслеживается – измерения сохранены';

  @override
  String unitWithValue(Object unit) {
    return 'Единица: $unit';
  }

  @override
  String get unitFromSettingsNote =>
      'Задаётся в Настройках. Границы ниже используют эту единицу.';

  @override
  String get unit => 'Единица';

  @override
  String get boundAmberLow => 'Красная ниже (жёлтая нижняя)';

  @override
  String get boundGreenLow => 'Зелёная от (OK нижняя)';

  @override
  String get boundGreenHigh => 'Зелёная до (OK верхняя)';

  @override
  String get boundAmberHigh => 'Красная выше (жёлтая верхняя)';

  @override
  String boundsUnitNote(Object unit) {
    return 'Значения в $unit. Пустое поле означает «без ограничения с этой стороны».';
  }

  @override
  String get enterANumber => 'Введи число';

  @override
  String get sectionSafeRanges => 'Безопасные диапазоны';

  @override
  String get sectionDose => 'Доза';

  @override
  String get boundsOrderError =>
      'Границы должны возрастать: жёлтая нижняя ≤ зелёная нижняя ≤ зелёная верхняя ≤ жёлтая верхняя.';

  @override
  String get boundsPairError =>
      'Каждой жёлтой границе нужна соответствующая зелёная граница с той же стороны.';

  @override
  String get noteOptional => 'Заметка (необязательно)';

  @override
  String get saveReadings => 'Сохранить измерения';

  @override
  String invalidNumberFor(Object name) {
    return 'Неверное число для $name';
  }

  @override
  String get invalidVolume => 'Введи корректный положительный объём.';

  @override
  String get invalidPositiveNumber => 'Введи положительное число.';

  @override
  String get invalidIntervalDays => 'Введи целое число дней (не менее 1).';

  @override
  String impossibleValueFor(Object name) {
    return '$name: это значение физически невозможно.';
  }

  @override
  String get impossibleValue => 'Это значение физически невозможно.';

  @override
  String get implausibleTitle => 'Необычные значения';

  @override
  String get implausibleIntro =>
      'Следующее значение выходит за пределы обычного диапазона. Проверь, нет ли опечатки, прежде чем сохранять.';

  @override
  String implausibleValueLine(
    Object name,
    Object value,
    Object min,
    Object max,
  ) {
    return '$name: $value (обычно $min–$max)';
  }

  @override
  String implausibleRailLine(Object name, Object value) {
    return '$name: $value – похоже, датчик ничего не измеряет (отключён?)';
  }

  @override
  String get implausibleIntroDevices =>
      'Подключённое устройство сообщает значения, которые выглядят неверными. Проверь датчик перед сохранением.';

  @override
  String get implausibleSkip => 'Пропустить';

  @override
  String get saveAnyway => 'Всё равно сохранить';

  @override
  String get enterAtLeastOneValue => 'Введи хотя бы одно значение.';

  @override
  String savedReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранено $count измерения.',
      many: 'Сохранено $count измерений.',
      few: 'Сохранено $count измерения.',
      one: 'Сохранено $count измерение.',
    );
    return '$_temp0';
  }

  @override
  String get noTrackedToRecord => 'Нет отслеживаемых параметров для записи.';

  @override
  String get testSetAll => 'Все';

  @override
  String get newTestSet => 'Новый набор тестов';

  @override
  String get editTestSet => 'Изменить набор тестов';

  @override
  String get manageTestSets => 'Управление наборами тестов';

  @override
  String get testSetNameHint => 'напр. Большой еженедельный тест';

  @override
  String get testSetNeedParam => 'Выбери хотя бы один параметр.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteTestSetBody =>
      'Набор тестов будет удалён. Твои измерения сохранятся.';

  @override
  String get testSetEmptyHint =>
      'В этом наборе нет активных параметров. Измени его или переключись на «Все».';

  @override
  String testSetParamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count параметра',
      many: '$count параметров',
      few: '$count параметра',
      one: '$count параметр',
    );
    return '$_temp0';
  }

  @override
  String get noTestSets =>
      'Наборов тестов пока нет. Набор позволяет записывать только те параметры, которые ты тестируешь вместе.';

  @override
  String get rangeWeek => '7 дн.';

  @override
  String get rangeMonth => '30 дн.';

  @override
  String get rangeQuarter => '90 дн.';

  @override
  String get rangeAll => 'Все';

  @override
  String get noReadingsInRange => 'Нет измерений в этом диапазоне.';

  @override
  String get recordFirstReading => 'Записать первое измерение';

  @override
  String get statMin => 'Мин.';

  @override
  String get statAvg => 'Средн.';

  @override
  String get statMax => 'Макс.';

  @override
  String get statTests => 'Тесты';

  @override
  String get editMeasurement => 'Изменить измерение';

  @override
  String get deleteTogetherTitle => 'Удалить измерение';

  @override
  String deleteTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Это значение было введено вместе с ещё $count измерениями. Удалить только это значение или все значения, введённые вместе?',
      one:
          'Это значение было введено вместе с ещё $count измерением. Удалить только это значение или все значения, введённые вместе?',
    );
    return '$_temp0';
  }

  @override
  String get deleteOnlyThis => 'Только это значение';

  @override
  String get deleteAllTogether => 'Все вместе';

  @override
  String get editTogetherTitle => 'Изменить время измерения';

  @override
  String editTogetherBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Это значение было введено вместе с ещё $count измерениями. Изменить время только для этого значения или для всех значений, введённых вместе?',
      one:
          'Это значение было введено вместе с ещё $count измерением. Изменить время только для этого значения или для всех значений, введённых вместе?',
    );
    return '$_temp0';
  }

  @override
  String get freeAmmoniaLabel => 'Свободный аммиак (NH₃)';

  @override
  String freeAmmoniaBreakdown(Object percent, Object ph, Object temp) {
    return '$percent% в токсичной форме · pH $ph · $temp';
  }

  @override
  String freeAmmoniaPercent(Object percent) {
    return '$percent% в токсичной форме';
  }

  @override
  String get freeAmmoniaExplain =>
      'Тест на аммиак измеряет общий аммиак, но токсична только неионизированная часть (NH₃). Её доля растёт с pH и температурой, поэтому рифовый аквариум превращает в токсичную форму больше аммиака, чем аквариум с низким pH. Эта оценка разделяет последнее измерение общего аммиака по последним значениям pH, температуры и солёности.';

  @override
  String freeAmmoniaDialogFree(Object value) {
    return 'Токсичный свободный аммиак: $value ppm NH₃';
  }

  @override
  String freeAmmoniaDialogFraction(Object percent, Object total) {
    return '$percent% из твоих $total ppm общего аммиака находится в токсичной форме NH₃.';
  }

  @override
  String freeAmmoniaDialogInputs(Object ph, Object temp, Object salinity) {
    return 'На основе pH $ph, $temp и $salinity.';
  }

  @override
  String freeAmmoniaSalinityAssumed(Object value) {
    return '$value (предположительно)';
  }

  @override
  String get freeAmmoniaOutdatedWarning =>
      'pH или температура последний раз измерялись более чем за неделю до этого измерения аммиака, поэтому доля токсичной формы может быть неточной.';

  @override
  String get freeAmmoniaShowTitle => 'Показывать свободный аммиак (NH₃)';

  @override
  String get freeAmmoniaShowSubtitle =>
      'Добавляет карточку с оценкой токсичной неионизированной доли по pH, температуре и солёности.';

  @override
  String get freeAmmoniaNeedsAmmonia => 'Включи аммиак, чтобы показать.';

  @override
  String get close => 'Закрыть';

  @override
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Соотношение PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Соотношение Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : KH';

  @override
  String get ratioCaAlkTitle => 'Соотношение Ca : KH';

  @override
  String get ratioMgAlkLabel => 'Mg : KH';

  @override
  String get ratioMgAlkTitle => 'Соотношение Mg : KH';

  @override
  String get ratioNoData =>
      'Запиши оба параметра, чтобы увидеть их соотношение.';

  @override
  String ratioBoundsNote(Object metric) {
    return 'Границы зон используют $metric — значение, показанное на карточке.';
  }

  @override
  String get waterChanges => 'Подмены воды';

  @override
  String get recordWaterChange => 'Записать подмену воды';

  @override
  String get amountLitersOptional => 'Количество (необязательно)';

  @override
  String get noWaterChanges => 'Пока нет подмен воды.';

  @override
  String get amountNotRecorded => 'Объём не указан';

  @override
  String get actions => 'Действия';

  @override
  String get noActions => 'Пока нет действий.';

  @override
  String get addAction => 'Добавить действие';

  @override
  String get waterChange => 'Подмена воды';

  @override
  String get carbonChange => 'Замена угля';

  @override
  String get recordCarbonChange => 'Записать замену угля';

  @override
  String get weightOptional => 'Вес (необязательно)';

  @override
  String get weightNotRecorded => 'Вес не указан';

  @override
  String gramsSuffix(Object value) {
    return '$value г';
  }

  @override
  String get gramSymbol => 'г';

  @override
  String get equipmentCleaning => 'Чистка оборудования';

  @override
  String get recordEquipmentCleaning => 'Записать чистку оборудования';

  @override
  String get dosing => 'Дозирование';

  @override
  String get addSupplement => 'Добавить добавку';

  @override
  String get noDosing => 'Пока нет добавок.';

  @override
  String get noDosingHint =>
      'Добавь добавки, которые ты дозируешь в этот аквариум — производитель, продукт и при желании доза и расписание.';

  @override
  String get dosingNoDosage => 'Доза не указана';

  @override
  String get supplementStopped => 'Дозирование остановлено';

  @override
  String get dosingHistoryTitle => 'История дозирования';

  @override
  String get dosingHistoryEmpty => 'Истории дозирования пока нет.';

  @override
  String get dosingHistoryCurrent => 'Действует';

  @override
  String dosingHistorySince(Object date) {
    return 'С $date';
  }

  @override
  String dosingHistoryPeriod(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get deleteDosingRecordTitle => 'Удалить эту запись?';

  @override
  String get deleteDosingRecordBody =>
      'Эта запись дозирования будет навсегда удалена из истории и из расчёта дозы. Отменить нельзя.';

  @override
  String get deleteDosingRecordNotLatest =>
      'Это не самая последняя запись для этого элемента; её удаление не изменит более поздние записи.';

  @override
  String get dosingHistoryManual => 'Вручную';

  @override
  String get manualDoseNew => 'Записать ручную дозу';

  @override
  String get manualDoseEdit => 'Изменить ручную дозу';

  @override
  String get deleteManualDoseTitle => 'Удалить ручную дозу?';

  @override
  String get deleteManualDoseBody =>
      'Эта записанная доза будет безвозвратно удалена из истории и расчёта дозирования. Отменить это нельзя.';

  @override
  String get dosingNew => 'Добавить добавку';

  @override
  String get dosingEdit => 'Изменить добавку';

  @override
  String get dosingVendor => 'Производитель';

  @override
  String get dosingVendorName => 'Название производителя';

  @override
  String get dosingProduct => 'Продукт';

  @override
  String get dosingProductName => 'Название продукта';

  @override
  String get dosingElement => 'Элемент';

  @override
  String get dosingElementNone => '—';

  @override
  String get dosingCustom => 'Другое…';

  @override
  String get dosingDosageOptional => 'Дозировка (необязательно)';

  @override
  String get dosingAmount => 'Количество';

  @override
  String get dosingUnit => 'Единица';

  @override
  String get dosingBasis => 'Из расчёта';

  @override
  String get dosingPerDay => 'в день';

  @override
  String get dosingPerDose => 'за дозу';

  @override
  String get dosingSchedule => 'Расписание';

  @override
  String get dosingFrequency => 'Частота';

  @override
  String get dosingFreqNone => 'Нет';

  @override
  String get dosingFreqDaily => 'Ежедневно';

  @override
  String get dosingFreqEveryNDays => 'Каждые N дней';

  @override
  String get dosingFreqWeekly => 'Еженедельно';

  @override
  String get dosingIntervalDays => 'Интервал (дни)';

  @override
  String dosingEveryDaysN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Каждые $n дня',
      many: 'Каждые $n дней',
      few: 'Каждые $n дня',
      one: 'Раз в $n день',
    );
    return '$_temp0';
  }

  @override
  String get dosingTimeOptional => 'Время (необязательно)';

  @override
  String get unitsSection => 'Единицы';

  @override
  String get toolsSection => 'Инструменты';

  @override
  String get aboutSection => 'О приложении';

  @override
  String get appearanceSection => 'Внешний вид';

  @override
  String get themeTitle => 'Тема';

  @override
  String get themeSystem => 'Система';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get temperature => 'Температура';

  @override
  String get salinity => 'Солёность';

  @override
  String get volume => 'Объём';

  @override
  String get unitUsedAcrossApp => 'Единица, используемая во всём приложении';

  @override
  String get salinityCalculator => 'Калькулятор солёности';

  @override
  String get salinityCalculatorSubtitle =>
      'Перевод ppt ⇄ SG ⇄ истинная плотность';

  @override
  String get reefUnitConverter => 'Конвертер единиц рифа';

  @override
  String get reefUnitConverterSubtitle => 'Щёлочность, температура и объём';

  @override
  String get reefUnitConverterIntro =>
      'Переводи обычные рифовые единицы. Введи значение в любое поле, чтобы автоматически обновить все эквивалентные единицы.';

  @override
  String get converterSourceUnit => 'Исходная единица';

  @override
  String get converterValue => 'Значение';

  @override
  String get converterEquivalent => 'Эквивалент';

  @override
  String get alkalinity => 'Щёлочность';

  @override
  String get backupSection => 'Резервная копия';

  @override
  String get backupNow => 'Создать копию сейчас';

  @override
  String backupLastRun(String when) {
    return 'Последняя копия: $when';
  }

  @override
  String get backupNeverRun => 'Копий пока нет';

  @override
  String backupLastFailed(String when) {
    return 'Не удалось создать копию $when';
  }

  @override
  String get backupDone => 'Копия сохранена';

  @override
  String get backupExport => 'Экспортировать копию';

  @override
  String get backupExportSubtitle =>
      'Сохранить все аквариумы и измерения в файл';

  @override
  String get csvExportTitle => 'Экспорт измерений (CSV)';

  @override
  String get csvExportSubtitle =>
      'Поделиться измерениями активного аквариума в виде табличного файла';

  @override
  String get csvExportNoData => 'Пока нет измерений для экспорта';

  @override
  String get csvExportFailed => 'Не удалось экспортировать измерения';

  @override
  String get backupImport => 'Восстановить из копии';

  @override
  String get backupImportSubtitle =>
      'Заменить все данные файлом резервной копии';

  @override
  String get backupRestoreConfirmTitle => 'Восстановить копию?';

  @override
  String get backupRestoreConfirmBody =>
      'ВСЕ данные твоих аквариумов — все аквариумы, параметры и измерения — будут заменены содержимым файла резервной копии. Настройки на этом устройстве (язык, единицы измерения и предпочтения) сохранятся. Это действие нельзя отменить.';

  @override
  String get restore => 'Восстановить';

  @override
  String get backupRestored => 'Резервная копия восстановлена';

  @override
  String get backupNowFailed => 'Не удалось сохранить резервную копию';

  @override
  String get backupShareFailed => 'Не удалось поделиться резервной копией';

  @override
  String get backupExportFailed => 'Не удалось экспортировать копию';

  @override
  String get backupImportFailed => 'Не удалось восстановить копию';

  @override
  String get backupInvalidFile =>
      'Этот файл не является корректной резервной копией ReefTracker';

  @override
  String get backupTooNew =>
      'Эта резервная копия создана более новой версией приложения и не может быть восстановлена здесь';

  @override
  String get backupCorrupted => 'Файл резервной копии повреждён или неполный';

  @override
  String get backupInconsistent =>
      'Резервная копия несогласованна и не может быть восстановлена';

  @override
  String get dataLoadFailed =>
      'Не удалось загрузить часть данных. Если это повторяется, перезапусти приложение или восстанови резервную копию.';

  @override
  String get autoBackupTitle => 'Автоматическое резервное копирование';

  @override
  String get autoBackupSubtitle =>
      'Хранить недавние копии данных на этом устройстве';

  @override
  String get autoBackupFrequency => 'Частота';

  @override
  String get autoBackupDaily => 'Ежедневно';

  @override
  String get autoBackupWeekly => 'Еженедельно';

  @override
  String get manageBackups => 'Управление копиями';

  @override
  String get manageBackupsSubtitle =>
      'Просмотр, восстановление и отправка автоматических копий';

  @override
  String get backupsScreenTitle => 'Автоматические копии';

  @override
  String get noAutoBackups => 'Автоматических копий пока нет';

  @override
  String get noAutoBackupsHint =>
      'Резервная копия создаётся автоматически во время использования приложения.';

  @override
  String get share => 'Поделиться';

  @override
  String get backupDeleteConfirmTitle => 'Удалить копию?';

  @override
  String get backupDeleteConfirmBody =>
      'Этот файл резервной копии будет безвозвратно удалён с устройства.';

  @override
  String sizeBytes(Object size) {
    return '$size Б';
  }

  @override
  String sizeKilobytes(Object size) {
    return '$size КБ';
  }

  @override
  String sizeMegabytes(Object size) {
    return '$size МБ';
  }

  @override
  String get syncGdriveTitle => 'Синхронизация с Google Диском';

  @override
  String get syncGdriveSubtitle =>
      'Автоматически сохранять резервные копии на твой Google Диск';

  @override
  String syncGdriveLastPush(String when) {
    return 'Последняя загрузка: $when';
  }

  @override
  String get syncGdriveNeverPushed => 'Пока ничего не загружено';

  @override
  String syncGdriveConnectedSnack(String email) {
    return 'Резервные копии будут синхронизироваться с Google Диском аккаунта $email';
  }

  @override
  String get syncGdriveConnectFailed =>
      'Не удалось подключиться к Google Диску';

  @override
  String syncGdriveDialogBody(String email) {
    return 'Резервные копии загружаются в папку «ReefTracker» на Google Диске аккаунта $email. Их можно просмотреть и скачать на drive.google.com.';
  }

  @override
  String get syncGdriveDisconnect => 'Отключить';

  @override
  String get syncGdriveDisconnectedSnack =>
      'Google Диск отключён. Уже загруженные резервные копии останутся на твоём Диске.';

  @override
  String syncGdriveLastFailed(String when) {
    return 'Загрузка на Google Диск не удалась $when';
  }

  @override
  String get syncDeviceNameTitle => 'Название устройства';

  @override
  String get syncDeviceNameBody =>
      'Отображается у резервных копий, загруженных с этого устройства, чтобы различать твои устройства.';

  @override
  String get syncDeviceNameHint => 'например, Мой телефон';

  @override
  String get syncDeviceNameAction => 'Название устройства…';

  @override
  String get syncRestoreTitle => 'Найдена более новая резервная копия';

  @override
  String syncRestoreBody(String device, String when) {
    return 'На твоём Google Диске есть более новая резервная копия с устройства «$device» ($when). Восстановить её на этом устройстве? Настройки этого устройства сохранятся.';
  }

  @override
  String syncRestoreDivergedBody(String device, String when) {
    return 'На твоём Google Диске есть более новая резервная копия с устройства «$device» ($when), но на этом устройстве тоже есть изменения, которые не были загружены. Восстановление заменит данные этого устройства резервной копией — сначала будет сохранена локальная резервная копия.';
  }

  @override
  String get syncRestoreUnknownDevice => 'другое устройство';

  @override
  String get syncRestoreNotNow => 'Не сейчас';

  @override
  String get syncRestoreKeepMine => 'Оставить данные этого устройства';

  @override
  String get welcomeRestoreDrive => 'Восстановить из Google Диска';

  @override
  String get backupsLocalSection => 'На этом устройстве';

  @override
  String get backupsDriveSection => 'Google Диск';

  @override
  String get backupsDriveEmpty => 'На Google Диске пока нет резервных копий';

  @override
  String get backupsDriveLoadFailed =>
      'Не удалось загрузить список резервных копий с Google Диска';

  @override
  String backupsDriveTooLarge(Object size) {
    return '$size — слишком большой файл, восстановление невозможно';
  }

  @override
  String get cloudSyncFeatureName => 'Облачное резервное копирование';

  @override
  String get syncIcloudTitle => 'Резервное копирование в iCloud';

  @override
  String get syncIcloudSubtitle =>
      'Автоматически сохранять резервные копии в твой iCloud Drive';

  @override
  String get syncIcloudDialogBody =>
      'Резервные копии загружаются в папку «ReefTracker» в твоём iCloud Drive. Их можно просмотреть в приложении «Файлы».';

  @override
  String get syncIcloudDisable => 'Выключить';

  @override
  String get syncIcloudEnabledSnack =>
      'Резервные копии будут синхронизироваться с твоим iCloud Drive';

  @override
  String get syncIcloudDisabledSnack =>
      'Резервное копирование в iCloud выключено. Уже загруженные резервные копии останутся в твоём iCloud Drive.';

  @override
  String get syncIcloudUnavailable =>
      'iCloud недоступен. Войди в iCloud и включи iCloud Drive для ReefTracker в настройках устройства.';

  @override
  String syncIcloudLastFailed(Object when) {
    return 'Загрузка в iCloud не удалась $when';
  }

  @override
  String get backupsIcloudSection => 'iCloud';

  @override
  String get backupsIcloudEmpty => 'В iCloud пока нет резервных копий';

  @override
  String get backupsIcloudLoadFailed =>
      'Не удалось загрузить список резервных копий из iCloud';

  @override
  String get welcomeRestoreIcloud => 'Восстановить из iCloud';

  @override
  String syncRestoreBodyIcloud(Object device, Object when) {
    return 'В твоём iCloud Drive есть более новая резервная копия с устройства «$device» ($when). Восстановить её на этом устройстве? Настройки этого устройства сохранятся.';
  }

  @override
  String syncRestoreDivergedBodyIcloud(Object device, Object when) {
    return 'В твоём iCloud Drive есть более новая резервная копия с устройства «$device» ($when), но на этом устройстве тоже есть изменения, которые не были загружены. Восстановление заменит данные этого устройства резервной копией — сначала будет сохранена локальная резервная копия.';
  }

  @override
  String get backupsDeviceNameNudge => 'Указать имя устройства';

  @override
  String get backupsDeviceNameNudgeHint =>
      'Помечает резервные копии, загружаемые с этого устройства';

  @override
  String get aboutAppName => 'О приложении ReefTracker';

  @override
  String get aboutDescription =>
      'Офлайн-дневник параметров морского аквариума: история измерений, графики и зоны состояния — зелёная, жёлтая и красная.';

  @override
  String get aboutUserGuide => 'Руководство пользователя';

  @override
  String get aboutUserGuideSubtitle =>
      'Как пользоваться всеми функциями, со скриншотами';

  @override
  String get aboutSupport => 'Поддержка и FAQ';

  @override
  String get aboutSupportSubtitle => 'Получить помощь или сообщить о проблеме';

  @override
  String get aboutPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get linkOpenFailed => 'Не удалось открыть ссылку';

  @override
  String get shareDiagnostics => 'Поделиться диагностикой';

  @override
  String get shareDiagnosticsSubtitle =>
      'Отправить журнал ошибок приложения в поддержку';

  @override
  String get diagnosticsEmpty => 'Ошибок не зафиксировано';

  @override
  String get diagnosticsShareFailed => 'Не удалось поделиться диагностикой';

  @override
  String get updateAvailableSnack => 'Доступна новая версия ReefTracker.';

  @override
  String get updateAction => 'Обновить';

  @override
  String get updateReadySnack => 'Обновление загружено.';

  @override
  String get updateRestartAction => 'Перезапустить';

  @override
  String get editionLabel => 'Издание';

  @override
  String get editionFounder => 'Версия основателя';

  @override
  String get editionStandard => 'Стандартное';

  @override
  String get founderInfoBody =>
      'Ты с ReefTracker с самых первых дней. В знак благодарности все доступные сегодня функции останутся для тебя бесплатными навсегда.';

  @override
  String get standardInfoBody =>
      'Ты используешь стандартное издание ReefTracker. Всё, что уже записано, остаётся с тобой; ReefTracker Pro открывает расширенные возможности.';

  @override
  String get editionUpgrade => 'Разблокировать Pro';

  @override
  String get editionPro => 'Pro';

  @override
  String get editionFounderPro => 'Издание первых пользователей + Pro';

  @override
  String get proInfoBody =>
      'Спасибо! Разблокировка Pro активна на этом устройстве. Все функции Pro доступны тебе.';

  @override
  String get paywallTitle => 'ReefTracker Pro';

  @override
  String get paywallIntro =>
      'Одна покупка, без подписки и без учётной записи — разблокировка остаётся за магазинным аккаунтом этого устройства.';

  @override
  String paywallBuy(Object price) {
    return 'Разблокировать Pro — $price';
  }

  @override
  String get paywallRestore => 'Восстановить покупки';

  @override
  String get paywallWorking => 'Связь с магазином…';

  @override
  String get paywallPurchased => 'Pro разблокирован. Спасибо!';

  @override
  String get paywallRestored => 'Твоя разблокировка Pro восстановлена.';

  @override
  String get paywallNothingToRestore =>
      'Для этого магазинного аккаунта прежних покупок не найдено.';

  @override
  String get paywallPending =>
      'Платёж ещё подтверждается. Pro откроется, как только он пройдёт.';

  @override
  String get paywallFailed =>
      'Магазин не смог завершить операцию. Попробуй ещё раз.';

  @override
  String get paywallUnavailable =>
      'Встроенные покупки недоступны на этом устройстве.';

  @override
  String get proFeatureTitle => 'Функция Pro';

  @override
  String proFeatureBody(Object feature) {
    return '$feature — часть ReefTracker Pro.';
  }

  @override
  String get unlimitedTanksTitle => 'Неограниченное число аквариумов';

  @override
  String tankLimitBody(Object limit) {
    return 'Стандартная версия включает до $limit аквариумов — например, основной аквариум и карантинный. Неограниченное число аквариумов — часть ReefTracker Pro.';
  }

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

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
      'Переводи практическую солёность (ppt), относительную плотность (SG) и показание ареометра, откалиброванного при 25 °C. Укажи температуру воды и вводи значение в любое поле.';

  @override
  String get specificGravity => 'Относительная плотность (SG)';

  @override
  String get measurementTemperature => 'Температура измерения';

  @override
  String get densityTemperatureHelp =>
      'Используй температуру воды в мерном цилиндре.';

  @override
  String get hydrometerDensityReading => 'Показание плотности ареометра';

  @override
  String get densityHydrometerNote =>
      'Европейские стеклянные ареометры, в том числе модели ARKA и Tropic Marin, обычно калибруются при 25 °C. Поправка помогает измерять подготовленную морскую воду при температуре окружающей среды.';

  @override
  String get referencePoints => 'Опорные значения';

  @override
  String get refSeawater =>
      '• Природная морская вода ≈ 35 ppt ≈ 1,0264 SG ≈ 1,0233 г/см³ при 25 °C';

  @override
  String get refReefTarget =>
      '• Типичная цель для рифа ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'Вне 25 °C поправка использует стандартное уравнение плотности морской воды и номинальное расширение стекла (26 ppm/°C). Для наибольшей точности измеряй при 25 °C.';

  @override
  String get salinityToolConvert => 'Пересчёт';

  @override
  String get salinityToolMix => 'Приготовить воду';

  @override
  String get salinityToolCorrect => 'Скорректировать аквариум';

  @override
  String get saltMixIntro =>
      'Рассчитай сухую соль для готового раствора. Используй данные с упаковки или собственный измеренный замес.';

  @override
  String get saltMixFinalVolume => 'Нужный конечный объём';

  @override
  String get saltMixTarget => 'Целевая солёность';

  @override
  String get saltMixProfileTitle => 'Твоя морская соль';

  @override
  String get saltMixProductLabel => 'Морская соль';

  @override
  String get saltMixCustomProduct => 'Своя смесь';

  @override
  String get saltMixCustomHelp =>
      'Введи значение с этикетки или откалибруй самостоятельно измеренный замес.';

  @override
  String get saltMixCatalogManufacturer =>
      'Начальное значение производителя. Измерь приготовленный замес, чтобы настроить его для этого аквариума.';

  @override
  String get saltMixCatalogEstimate =>
      'Оценка производителя для исходной воды. Перед использованием откалибруй измеренный конечный объём.';

  @override
  String get saltMixMeasuredCalibration =>
      'Используется твоя измеренная калибровка для этого аквариума.';

  @override
  String get saltMixNameOptional => 'Название соли (необязательно)';

  @override
  String get saltMixFactor => 'Сухая смесь при опорной солёности';

  @override
  String get saltMixFactorHelp =>
      'Укажи граммы на литр готовой морской воды. Данные на упаковке для литра исходной воды — лишь оценка, пока реальный замес не откалиброван.';

  @override
  String get saltMixReferenceSalinity => 'Опорная солёность';

  @override
  String get saltMixCalibrateTitle => 'Калибровать по измеренному замесу';

  @override
  String get saltMixDryMass => 'Использовано сухой смеси';

  @override
  String get saltMixMeasuredVolume => 'Измеренный конечный объём';

  @override
  String get saltMixMeasuredSalinity => 'Измеренная солёность';

  @override
  String get saltMixUseCalibration => 'Использовать эту калибровку';

  @override
  String get saltMixCalculate => 'Рассчитать соль';

  @override
  String get salinityPlannerResult => 'Результат';

  @override
  String get saltMixDrySalt => 'Расчётная сухая смесь';

  @override
  String get saltMixResultHelp =>
      'Начни с меньшего объёма RO/DI-воды, чем нужный конечный объём. Смешивай вне аквариума, соблюдай указания производителя по температуре, перемешиванию и аэрации, затем проверь солёность калиброванным прибором и доведи смесь солью и водой до конечного объёма.';

  @override
  String get salinityCorrectionIntro =>
      'Рассчитай равнообъёмную подмену, которая приблизит текущую солёность аквариума к цели.';

  @override
  String get salinityCorrectionTankVolume => 'Чистый объём воды системы';

  @override
  String get salinityCorrectionCurrent => 'Текущая солёность';

  @override
  String get salinityCorrectionTarget => 'Целевая солёность';

  @override
  String salinityPlannerLatestReading(Object date) {
    return 'Подставлено измерение от $date.';
  }

  @override
  String get salinityCorrectionReplacement => 'Солёность подменной воды';

  @override
  String get salinityCorrectionReplacementHelp =>
      'Она должна быть выше цели. Приготовь и измерь этот раствор отдельно.';

  @override
  String get salinityCorrectionHighMethod =>
      'Удали рассчитанный объём аквариумной воды и замени таким же объёмом RO/DI с солёностью 0 ppt.';

  @override
  String get salinityCorrectionHighResultHelp =>
      'Считай результат начальной оценкой. Раздели большие изменения на этапы, обеспечь циркуляцию между ними и повторно измеряй солёность после каждого этапа.';

  @override
  String get salinityCorrectionLowResultHelp =>
      'Готовь воду для замены вне аквариума. Соблюдай указания производителя соли по температуре, перемешиванию и аэрации, проверь её калиброванным прибором, затем меняй воду поэтапно с циркуляцией и повторными измерениями.';

  @override
  String get salinityCorrectionLowMethod =>
      'Удали рассчитанный объём аквариумной воды и замени таким же объёмом отдельно приготовленной воды с более высокой солёностью.';

  @override
  String get salinityCorrectionCalculate => 'Рассчитать коррекцию';

  @override
  String get salinityReplacementError =>
      'Солёность подменной воды должна быть выше цели.';

  @override
  String get salinityPlannerAssumptionsTitle => 'Перед коррекцией';

  @override
  String get salinityPlannerAssumptions =>
      'Расчёт предполагает постоянный объём аквариума, сохранение соли и полное перемешивание воды. Если испарение снизило уровень, сначала долей RO/DI до обычного уровня и измерь снова.';

  @override
  String get salinityPlannerSafety =>
      'Никогда не добавляй сухую смесь в аквариум с животными. Большие изменения дели на этапы, обеспечивай циркуляцию и измеряй после каждого этапа. Калькулятор не задаёт универсально безопасное суточное изменение и не гарантирует конечное значение.';

  @override
  String get salinityCorrectionNoChange =>
      'Текущая солёность уже совпадает с целью. Подмена не нужна.';

  @override
  String get salinityCorrectionExchange => 'Удалить и заменить';

  @override
  String get salinityCorrectionTankPercent => 'От воды системы';

  @override
  String get salinityCorrectionBatchSalt => 'Сухая смесь для подменной воды';

  @override
  String get salinityCorrectionExtraEquivalent =>
      'Общий эквивалент недостающей соли';

  @override
  String get salinityCorrectionRecord => 'Записать выполненную подмену воды';

  @override
  String get salinityCorrectionLogNote => 'Коррекция солёности';

  @override
  String get doseCalcTitle => 'Калькулятор дозировки';

  @override
  String get doseCalcIntro =>
      'Оценивает, как быстро аквариум расходует элемент, и суточную дозу, удерживающую его на месте. Подмены воды не учитываются.';

  @override
  String get doseCalcElement => 'Элемент';

  @override
  String get doseCalcWindow => 'Период измерений';

  @override
  String doseCalcReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count измерения в периоде',
      many: '$count измерений в периоде',
      few: '$count измерения в периоде',
      one: '$count измерение в периоде',
    );
    return '$_temp0';
  }

  @override
  String doseCalcDoseChanged(Object date) {
    return 'Доза изменена $date; измерения до этой даты отражают другую дозу.';
  }

  @override
  String get doseCalcVolume => 'Объём аквариума';

  @override
  String get doseCalcCurrentDose => 'Текущая суточная доза';

  @override
  String get doseCalcManualDose => 'Ручная доза за период';

  @override
  String get doseCalcManualDoseHelp =>
      'Необязательно: сумма разовых или дополнительных доз, внесённых за период измерений. Если поле пустое, используются записанные ручные дозы.';

  @override
  String get doseCalcManualInput => 'Ручные дозы добавляют';

  @override
  String doseCalcLoggedDoses(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записанных доз за период: $total',
      few: '$count записанные дозы за период: $total',
      one: '1 записанная доза за период: $total',
    );
    return '$_temp0';
  }

  @override
  String doseCalcLoggedUnitMismatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count записанных доз используют другую единицу и не учитываются.',
      few: '$count записанные дозы используют другую единицу и не учитываются.',
      one: '1 записанная доза использует другую единицу и не учитывается.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcLoggedProductMismatch =>
      'Некоторые записанные дозы — другой продукт; их концентрация может отличаться от указанной выше.';

  @override
  String get doseCalcPerDay => 'сут';

  @override
  String get doseCalcPotencyTitle => 'Концентрация добавки';

  @override
  String get doseCalcPotencyFromCatalog =>
      'Используется концентрация этого продукта из каталога.';

  @override
  String get doseCalcEnterManually => 'Ввести вручную';

  @override
  String get doseCalcUseCatalog => 'Взять из каталога';

  @override
  String get doseCalcRefAmount => 'Доза';

  @override
  String get doseCalcRefVolume => 'На объём';

  @override
  String get doseCalcRise => 'Повышает на';

  @override
  String doseCalcRaises(Object detail) {
    return '≈ $detail';
  }

  @override
  String get doseCalcResultsTitle => 'Результат';

  @override
  String get doseCalcObservedChange => 'Измеренное изменение';

  @override
  String get doseCalcConsumption => 'Потребление';

  @override
  String get doseCalcCurrentInput => 'Текущая доза добавляет';

  @override
  String get doseCalcSuggestedDose => 'Рекомендуемая суточная доза';

  @override
  String get doseCalcAdjustment => 'Корректировка';

  @override
  String get doseCalcStable =>
      'Текущая доза удерживает элемент стабильным — оставь как есть.';

  @override
  String get doseCalcIncrease =>
      'Увеличь дозу, чтобы удержать элемент стабильным.';

  @override
  String get doseCalcDecrease =>
      'Дозу можно снизить и всё равно удержать элемент стабильным.';

  @override
  String get doseCalcOverdosing =>
      'Элемент растёт — снизь или приостанови дозирование.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Ничего не дозируется, и этот элемент не падает — дозирование не требуется.';

  @override
  String get doseCalcNeedsPotency =>
      'Укажи концентрацию добавки, чтобы получить рекомендацию по дозе.';

  @override
  String get doseCalcInsufficient =>
      'Для расчёта добавь не менее двух измерений в разные дни и объём аквариума.';

  @override
  String get doseCalcModeMaintenance => 'Дневная доза';

  @override
  String get doseCalcModeCorrection => 'Коррекция';

  @override
  String get doseCalcCorrIntro =>
      'Рассчитай разовую дозу, которая поднимет элемент с текущего значения до целевого. Если быстрый рост опасен, доза будет разбита на несколько дней.';

  @override
  String get doseCalcCurrentValue => 'Текущее значение';

  @override
  String get doseCalcCurrentValueHelp => 'Пусто = твоё последнее измерение.';

  @override
  String get doseCalcTargetValue => 'Целевое значение';

  @override
  String get doseCalcTargetValueHelp =>
      'Пусто = целевое значение параметра или середина его безопасного диапазона.';

  @override
  String get doseCalcNeededRise => 'Требуемый рост';

  @override
  String get doseCalcOneTimeDose => 'Разовая доза';

  @override
  String get doseCalcTotalDose => 'Общая доза';

  @override
  String get doseCalcDosePerDay => 'Доза в день';

  @override
  String get doseCalcSpreadDays => 'Растянуть на (дней)';

  @override
  String get doseCalcCorrMissing =>
      'Для расчёта укажи текущее значение, цель и объём аквариума.';

  @override
  String get doseCalcCorrAtTarget =>
      'Значение уже на уровне цели или выше — дозировать нечего.';

  @override
  String get doseCalcCorrSingle => 'Можно безопасно внести одной дозой.';

  @override
  String doseCalcCorrSplit(Object limit, int days) {
    return 'Поднимать быстрее чем на $limit в день рискованно — внеси коррекцию за $days дневных доз.';
  }

  @override
  String get doseCalcLogDose => 'Записать дозу';

  @override
  String get doseCalcSalinityAdjust =>
      'Подстроить цель под солёность аквариума';

  @override
  String get doseCalcSalinityAdjustHelp =>
      'Целевые значения рассчитаны на морскую воду 35 ppt (1,026). Включи, чтобы пересчитать цель под измеренную солёность твоего аквариума.';

  @override
  String doseCalcSalinityAdjustActive(
    Object salinity,
    Object adjusted,
    Object original,
  ) {
    return 'При $salinity: цель $adjusted вместо $original.';
  }

  @override
  String get doseCalcSalinityNone =>
      'Для этого аквариума солёность ещё не измерена.';

  @override
  String doseCalcSalinityStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Солёность измерена $days дня назад.',
      many: 'Солёность измерена $days дней назад.',
      few: 'Солёность измерена $days дня назад.',
      one: 'Солёность измерена $days день назад.',
    );
    return '$_temp0';
  }

  @override
  String get doseCalcAdjustedTarget => 'Пересчитанная цель';

  @override
  String get correctionCta => 'Ниже диапазона — рассчитать корректирующую дозу';

  @override
  String get targetValueLabel => 'Целевое значение коррекции';

  @override
  String get targetValueHelp =>
      'Подставляется в режим коррекции калькулятора дозирования. Пусто = середина безопасного диапазона.';

  @override
  String get trendSection => 'Тренды';

  @override
  String get trendShowTitle => 'Показывать тренды';

  @override
  String get trendShowSubtitle =>
      'Прогнозирует, куда движется каждый параметр и когда выйдет за пределы диапазона';

  @override
  String get trendWindow => 'Используемые измерения';

  @override
  String trendWindowSubtitle(int days) {
    return 'Сколько последних измерений определяют тренд; при частых измерениях окно расширяется минимум до $days дней';
  }

  @override
  String get trendTitle => 'Текущий тренд';

  @override
  String trendRatePerDay(Object rate) {
    return '$rate/день';
  }

  @override
  String get trendFlat => 'Держится стабильно';

  @override
  String get trendWithinRange => 'При таком темпе остаётся в диапазоне';

  @override
  String trendAmberInDays(int days) {
    return 'Достигнет зоны внимания через ~$days дн.';
  }

  @override
  String trendRedInDays(int days) {
    return 'Достигнет критической зоны через ~$days дн.';
  }

  @override
  String trendChipAmber(int days) {
    return 'Внимание ~$days дн.';
  }

  @override
  String trendChipRed(int days) {
    return 'Срочно: ~$days д.';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Восстанавливается — вернётся в диапазон через ~$days дн.';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Восстановление ~$days дн.';
  }

  @override
  String get trendOscillating => 'Колеблется — направление не определено';

  @override
  String get trendChipOscillating => 'Колеблется';

  @override
  String get trendHorizon => 'Горизонт оповещения';

  @override
  String get trendHorizonSubtitle =>
      'Отмечать параметр, только если он выйдет за пределы в течение этого срока';

  @override
  String trendHorizonDays(int days) {
    return '$days дн.';
  }

  @override
  String get zoneOk => 'OK';

  @override
  String get zoneAttention => 'Внимание';

  @override
  String get zoneActNow => 'Действовать сейчас';

  @override
  String get zoneUnknown => '—';

  @override
  String get setupFishOnly => 'Только рыбы';

  @override
  String get setupSoft => 'Мягкие кораллы';

  @override
  String get setupLps => 'LPS';

  @override
  String get setupSps => 'SPS';

  @override
  String get setupMixed => 'Смешанный риф';

  @override
  String get paramTemperature => 'Температура';

  @override
  String get paramPh => 'pH';

  @override
  String get paramSalinity => 'Солёность';

  @override
  String get paramAlkalinity => 'Щёлочность (KH)';

  @override
  String get paramAlkalinityShort => 'KH';

  @override
  String get paramCalcium => 'Кальций (Ca)';

  @override
  String get paramMagnesium => 'Магний (Mg)';

  @override
  String get paramNitrate => 'Нитрат (NO₃)';

  @override
  String get paramPhosphate => 'Фосфат (PO₄)';

  @override
  String get paramAmmonia => 'Аммиак (NH₃/₄)';

  @override
  String get paramNitrite => 'Нитрит (NO₂)';

  @override
  String get paramOrp => 'ОВП (ORP)';

  @override
  String get paramPotassium => 'Калий (K)';

  @override
  String get paramStrontium => 'Стронций (Sr)';

  @override
  String get paramIodine => 'Йод (I)';

  @override
  String get paramIron => 'Железо (Fe)';

  @override
  String get paramSodium => 'Натрий (Na)';

  @override
  String get paramSulfur => 'Сера (S)';

  @override
  String get paramBoron => 'Бор (B)';

  @override
  String get paramBromine => 'Бром (Br)';

  @override
  String get paramSilicon => 'Кремний (Si)';

  @override
  String get paramZinc => 'Цинк (Zn)';

  @override
  String get paramVanadium => 'Ванадий (V)';

  @override
  String get paramCopper => 'Медь (Cu)';

  @override
  String get paramNickel => 'Никель (Ni)';

  @override
  String get paramManganese => 'Марганец (Mn)';

  @override
  String get paramMolybdenum => 'Молибден (Mo)';

  @override
  String get paramChromium => 'Хром (Cr)';

  @override
  String get paramCobalt => 'Кобальт (Co)';

  @override
  String get paramLithium => 'Литий (Li)';

  @override
  String get paramBarium => 'Барий (Ba)';

  @override
  String get paramSelenium => 'Селен (Se)';

  @override
  String get paramAluminium => 'Алюминий (Al)';

  @override
  String get paramAntimony => 'Сурьма (Sb)';

  @override
  String get paramTin => 'Олово (Sn)';

  @override
  String get paramBeryllium => 'Бериллий (Be)';

  @override
  String get paramSilver => 'Серебро (Ag)';

  @override
  String get paramTungsten => 'Вольфрам (W)';

  @override
  String get paramLanthanum => 'Лантан (La)';

  @override
  String get paramTitanium => 'Титан (Ti)';

  @override
  String get paramZirconium => 'Цирконий (Zr)';

  @override
  String get paramArsenic => 'Мышьяк (As)';

  @override
  String get paramCadmium => 'Кадмий (Cd)';

  @override
  String get paramMercury => 'Ртуть (Hg)';

  @override
  String get paramLead => 'Свинец (Pb)';

  @override
  String get microTitle => 'Микроэлементы';

  @override
  String get microSectionMajor => 'Макроэлементы';

  @override
  String get microSectionTrace => 'Микроэлементы';

  @override
  String get microSectionContaminants => 'Загрязнители';

  @override
  String get microNotMeasured => 'Не измерялось';

  @override
  String get microEmptyHint =>
      'Отслеживай микроэлементы по капельным тестам или ICP-анализам.';

  @override
  String get microAllOk => 'Всё в пределах диапазона';

  @override
  String microOutOfRangeN(int count) {
    return '$count вне диапазона';
  }

  @override
  String microLastMeasured(String date) {
    return 'Последнее измерение $date';
  }

  @override
  String get microAddMeasurements => 'Добавить измерения';

  @override
  String get microAddTitle => 'Измерения микроэлементов';

  @override
  String get microChipHobby => 'Капельные тесты';

  @override
  String get microChipFullIcp => 'Полный ICP';

  @override
  String get microReminderTooltip => 'Напоминание о тесте';

  @override
  String get microReminderTitle => 'Напоминание о тесте микроэлементов';

  @override
  String get microReminderHint =>
      'Добавляет в план обслуживания задачу с напоминанием регулярно проверять микроэлементы.';

  @override
  String get microReminderCreated =>
      'Напоминание добавлено в план обслуживания';

  @override
  String get microIcpTaskTitle => 'Тест микроэлементов (ICP)';

  @override
  String get microToggleSubtitle =>
      'Показывать на вкладке «Измерения», с напоминаниями о тестах. При скрытии измерения сохраняются.';

  @override
  String get microViewFull => 'Полный список';

  @override
  String get microViewNew => 'Новый набор';

  @override
  String get microViewEdit => 'Изменить набор';

  @override
  String get microViewManage => 'Управление наборами';

  @override
  String get microConfigureTitle => 'Настройки элементов';

  @override
  String get microViewNone =>
      'Пока нет своих наборов. Набор показывает только те элементы, которые измеряет твоя лаборатория.';

  @override
  String get microViewNameHint => 'напр. Панель моей лаборатории';

  @override
  String get microViewNeedElement => 'Выбери хотя бы один элемент.';

  @override
  String microViewElementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String microViewDeleteTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get microViewDeleteBody =>
      'Удаляется только набор. Измерения сохранятся.';

  @override
  String get microHideUndetectable => 'Скрыть неопределяемые (ноль)';

  @override
  String get microAttentionOnly => 'Только элементы, требующие внимания';

  @override
  String get microFilterAllHidden =>
      'Нет элементов, соответствующих текущим фильтрам.';

  @override
  String get icpImportTitle => 'Импорт ICP-отчёта';

  @override
  String get icpImportFormatHint => 'Выбери формат экспортированного файла.';

  @override
  String get icpImportFormatFaunaMarinHint =>
      'CSV-экспорт из лабораторного портала Fauna Marin';

  @override
  String get icpImportFormatZimsHint =>
      'Универсальный CSV с измерениями (дата, измерение, значение, единица)';

  @override
  String get icpImportUnreadable => 'Не удалось прочитать файл.';

  @override
  String icpImportWrongFormat(String format) {
    return 'Файл не похож на экспорт $format.';
  }

  @override
  String get icpImportNoValues => 'В файле не найдено значений для импорта.';

  @override
  String get icpImportSampleDateHint =>
      'Заполнено датой анализа из отчёта. Измени на день отбора пробы воды.';

  @override
  String get icpImportSectionCore => 'Основные параметры';

  @override
  String icpImportSkipped(String list) {
    return 'Не импортировано (нет подходящего параметра): $list';
  }

  @override
  String icpImportValueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировать $count значения',
      many: 'Импортировать $count значений',
      few: 'Импортировать $count значения',
      one: 'Импортировать $count значение',
    );
    return '$_temp0';
  }

  @override
  String get icpImportDuplicateTitle => 'Проба уже импортирована?';

  @override
  String icpImportDuplicateBody(String id) {
    return 'Существующие измерения уже упоминают пробу $id. Всё равно импортировать ещё раз?';
  }

  @override
  String get icpImportAnyway => 'Всё равно импортировать';

  @override
  String icpImportNotePrefill(String id) {
    return 'ICP-проба $id';
  }

  @override
  String get unitFixedNote => 'Этот параметр всегда использует эту единицу.';

  @override
  String get measurementImportTitle => 'Импорт измерений';

  @override
  String get measurementImportSourceHint =>
      'Выбери приложение или прибор, из которого получен файл.';

  @override
  String get measurementImportHannaHint =>
      'История CSV из приложения Hanna Lab';

  @override
  String get hannaImportTitle => 'Импорт из Hanna Lab';

  @override
  String get hannaImportIntoTank => 'Импортировать в аквариум';

  @override
  String get hannaImportFirstFrom => 'Импортировать историю с';

  @override
  String get hannaImportEverything => 'Всё';

  @override
  String get hannaImportFirstFromHint =>
      'Первый импорт в этот аквариум: выбери, с какой даты импортировать. Более старые измерения будут навсегда пропущены — удобно, если они уже введены вручную.';

  @override
  String hannaImportNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых измерений',
      many: '$count новых измерений',
      few: '$count новых измерения',
      one: '1 новое измерение',
    );
    return '$_temp0';
  }

  @override
  String hannaImportAlreadyCount(int count) {
    return 'Уже импортировано: $count';
  }

  @override
  String hannaImportBeforeCutoffCount(int count) {
    return 'До начальной даты: $count';
  }

  @override
  String get hannaImportSkippedTitle => 'Не импортировано';

  @override
  String get hannaImportSkipRange => 'вне диапазона теста';

  @override
  String get hannaImportSkipUnknown => 'тест не отслеживается приложением';

  @override
  String get hannaImportSkipValue => 'нечитаемое значение';

  @override
  String get hannaImportUpToDate => 'Всё из этого файла уже импортировано.';

  @override
  String hannaImportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировать $count измерений',
      many: 'Импортировать $count измерений',
      few: 'Импортировать $count измерения',
      one: 'Импортировать 1 измерение',
    );
    return '$_temp0';
  }

  @override
  String hannaImportDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count измерений',
      many: 'Импортировано $count измерений',
      few: 'Импортировано $count измерения',
      one: 'Импортировано 1 измерение',
    );
    return '$_temp0';
  }

  @override
  String get hannaImportUndone => 'Импорт отменён.';

  @override
  String get hannaImportWrongTankTitle => 'Другой аквариум?';

  @override
  String hannaImportWrongTankBody(String location, String tank, String other) {
    return '«$location» в прошлый раз импортировалось в $tank. Импортировать вместо этого в $other?';
  }

  @override
  String get measurementImportSettingsTitle => 'Импорт измерений';

  @override
  String hannaImportImportedUpTo(String date) {
    return 'Импортировано по $date';
  }

  @override
  String get hannaImportNeverImported => 'Ещё не импортировано';

  @override
  String get hannaImportChangeDate => 'Изменить дату…';

  @override
  String get hannaImportReset => 'Сбросить';

  @override
  String get hannaImportResetTitle => 'Сбросить импорт Hanna Lab?';

  @override
  String get hannaImportResetBody =>
      'При следующем импорте приложение снова спросит, с какой даты начать. Уже импортированные измерения сохраняются; привязка к аквариуму запоминается.';

  @override
  String get hannaConnectTitle => 'Фотометр Hanna';

  @override
  String get hannaMeasureAction => 'Измерить фотометром Hanna';

  @override
  String get hannaScanTitle => 'Сканировать дисплей чекера';

  @override
  String get hannaScanPickHint =>
      'Считывает значение прямо с дисплея чекера. Сначала выбери модель — номер HI напечатан на передней стороне чекера.';

  @override
  String get hannaScanPickTitle => 'Модель чекера';

  @override
  String get hannaScanGuide => 'Помести дисплей в рамку';

  @override
  String get hannaScanGlareHint => 'слегка наклони, чтобы избежать бликов';

  @override
  String get hannaScanZoomHint =>
      'масштаб — сведением/разведением двух пальцев';

  @override
  String get hannaScanRescan => 'Сканировать снова';

  @override
  String get hannaScanNoCamera => 'На этом устройстве нет камеры.';

  @override
  String get hannaScanCameraDenied =>
      'Доступ к камере запрещён. Разреши доступ к камере в настройках системы, чтобы сканировать дисплей.';

  @override
  String get hannaScanCameraFailed => 'Не удалось запустить камеру.';

  @override
  String get hannaScanImpossibleNote =>
      'Это значение невозможно для данного параметра, его нельзя сохранить. Отсканируй снова или проверь, выбрана ли правильная модель.';

  @override
  String get hannaScanImplausibleNote =>
      'Это значение вне правдоподобного диапазона — проверь его перед сохранением.';

  @override
  String get experimentalBadge => 'Экспериментально';

  @override
  String get experimentalSection => 'Экспериментально';

  @override
  String get experimentalToggleTitle => 'Экспериментальные функции';

  @override
  String get experimentalToggleSubtitle =>
      'Попробуй функции на стадии тестирования: подключение Hanna checker по Bluetooth и сканирование дисплея';

  @override
  String get hannaScanFabTitle => 'Кнопка сканирования камерой';

  @override
  String get hannaScanFabSubtitle =>
      'Показывать кнопку быстрого сканирования над «Добавить измерение»';

  @override
  String get hannaExperimentalNote =>
      'Экспериментальная функция: используется неофициальный Bluetooth-протокол, после обновления прошивки прибора она может перестать работать.';

  @override
  String get hannaMeasureOnlyNote =>
      'Поддерживаются только измерения. Для изменения настроек прибора или обновления его прошивки используй фирменное приложение Hanna Lab.';

  @override
  String get hannaScanning => 'Поиск прибора…';

  @override
  String get hannaScanHint => 'Включи прибор и держи его рядом с телефоном.';

  @override
  String get hannaReadingSetup => 'Подключено — чтение настроек прибора…';

  @override
  String get hannaErrUnsupported =>
      'Bluetooth LE недоступен на этом устройстве.';

  @override
  String get hannaErrBluetoothOff =>
      'Bluetooth выключен. Включи его и попробуй снова.';

  @override
  String get hannaErrNotFound =>
      'Прибор не найден. Убедись, что он включён и находится рядом.';

  @override
  String get hannaErrConnectionFailed => 'Не удалось подключиться к прибору.';

  @override
  String get hannaErrConnectionLost => 'Соединение с прибором потеряно.';

  @override
  String get hannaTryAgain => 'Повторить';

  @override
  String hannaMeterStatus(int percent, String firmware) {
    return 'Батарея $percent % · прошивка $firmware';
  }

  @override
  String get hannaAquarium => 'Аквариум';

  @override
  String get hannaSetsTitle => 'Наборы тестов';

  @override
  String hannaSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count метода',
      many: '$count методов',
      few: '$count метода',
      one: '$count метод',
    );
    return '$_temp0';
  }

  @override
  String get hannaSaveSet => 'Сохранить выбор как набор';

  @override
  String get hannaSetName => 'Название набора';

  @override
  String get hannaSetUpdate => 'Обновить из текущего выбора';

  @override
  String get hannaAllMethods => 'Все методы';

  @override
  String hannaMethodLowRange(String name) {
    return '$name (низкий диапазон)';
  }

  @override
  String get hannaStartMeasurements => 'Начать измерения';

  @override
  String get hannaFollowMeter => 'Следуй инструкциям на приборе';

  @override
  String hannaStepN(int step) {
    return 'шаг $step';
  }

  @override
  String get hannaStatusSkipped => 'Пропущено';

  @override
  String get hannaSkip => 'Пропустить';

  @override
  String get hannaFinishNow => 'Завершить';

  @override
  String get hannaTimerHint => 'Таймер реакции реагента';

  @override
  String get hannaTimerStop => 'Остановить таймер';

  @override
  String hannaTimerSec(int n) {
    return '$n с';
  }

  @override
  String hannaTimerMin(int n) {
    return '$n мин';
  }

  @override
  String get hannaTimerDoneTitle => 'Таймер реагента завершён';

  @override
  String get hannaTimerDoneBody =>
      'Время вышло — продолжи измерение на приборе.';

  @override
  String get hannaResultsTitle => 'Результаты измерений';

  @override
  String get hannaResultsDisconnected =>
      'Соединение потеряно — полученные к этому моменту результаты остаются.';

  @override
  String get hannaNoResults => 'Измерения не были получены.';

  @override
  String get hannaSaveTo => 'Сохранить в аквариум';

  @override
  String hannaSaveButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранить $count значения',
      many: 'Сохранить $count значений',
      few: 'Сохранить $count значения',
      one: 'Сохранить $count значение',
    );
    return '$_temp0';
  }

  @override
  String hannaSavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count значения сохранено',
      many: '$count значений сохранено',
      few: '$count значения сохранены',
      one: '$count значение сохранено',
    );
    return '$_temp0';
  }

  @override
  String hannaSaveButtonEnv(int count, int envCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранить $count значения',
      many: 'Сохранить $count значений',
      few: 'Сохранить $count значения',
      one: 'Сохранить $count значение',
    );
    return '$_temp0 + $envCount (среда)';
  }

  @override
  String get hannaIncludeInSave => 'Сохранить это значение';

  @override
  String get hannaValueImpossible =>
      'Вне возможного диапазона — не будет сохранено';

  @override
  String get hannaNothingSelected => 'Ничего не выбрано для сохранения';

  @override
  String get hannaRemeasure => 'Измерить заново';

  @override
  String hannaRemeasureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Измерить заново $count значения',
      many: 'Измерить заново $count значений',
      few: 'Измерить заново $count значения',
      one: 'Измерить заново $count значение',
    );
    return '$_temp0';
  }

  @override
  String get hannaRemeasureQueued => 'Будет измерено заново';

  @override
  String get hannaRemeasureKept =>
      'Заново не измерено — сохранено прежнее значение';

  @override
  String hannaPreviousValue(String value) {
    return 'было $value';
  }

  @override
  String get hannaMeasuringAgain => 'Выбранные параметры измеряются заново.';

  @override
  String get hannaRemeasureFailed =>
      'Прибор не ответил — повторное измерение не начато, результаты не изменились.';

  @override
  String get environmentTitle => 'Параметры среды';

  @override
  String get environmentInclude =>
      'Сохранять также показания среды с подключённых устройств';

  @override
  String get environmentJustNow => 'считано только что';

  @override
  String environmentMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'считано $minutes минуты назад',
      many: 'считано $minutes минут назад',
      few: 'считано $minutes минуты назад',
      one: 'считано $minutes минуту назад',
    );
    return '$_temp0';
  }

  @override
  String get environmentUnreachable =>
      'Устройства недоступны — измерения будут сохранены без показаний среды.';

  @override
  String get environmentAllMeasured =>
      'Все показания среды уже измерены в этой сессии.';

  @override
  String get hannaDiscardTitle => 'Не сохранять результаты?';

  @override
  String get hannaDiscardBody =>
      'Полученные значения не сохранены и будут потеряны.';

  @override
  String get hannaDiscard => 'Не сохранять';

  @override
  String get helpTemperature =>
      'Температура воды. Стабильность важнее точного значения.';

  @override
  String get helpSalinity => 'Плотность. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Карбонатная жёсткость. Поддерживай стабильной — избегай скачков.';

  @override
  String get helpNitrate =>
      'Питательное вещество. Кораллам нужно немного; избыток питает водоросли.';

  @override
  String get helpAmmonia =>
      'Токсичен. В созревшем аквариуме должен быть практически нулевым.';

  @override
  String get healthTitle => 'Состояние аквариума';

  @override
  String get healthGradeExcellent => 'Отлично';

  @override
  String get healthGradeGood => 'Хорошо';

  @override
  String get healthGradeCaution => 'Внимание';

  @override
  String get healthGradeCritical => 'Критично';

  @override
  String get healthGradeUnknown => 'Нет данных';

  @override
  String get healthAllOnTarget => 'Все параметры в норме';

  @override
  String healthParamsToWatch(int count) {
    return '$count под наблюдением';
  }

  @override
  String get healthSectionAttention => 'Требует внимания';

  @override
  String get healthSectionGood => 'В норме';

  @override
  String get healthSectionStale => 'Давно не измерялось';

  @override
  String healthNotTestedDays(int count) {
    return 'Не измерялось $count дн.';
  }

  @override
  String get healthNeverTested => 'Ещё не измерялось';

  @override
  String get healthNoReadingsYet => 'Пока нет измерений';

  @override
  String lastTestedAgo(String ago) {
    return 'Последний тест $ago';
  }

  @override
  String healthScoreOf(int score) {
    return '$score из 100';
  }

  @override
  String get stabilityTitle => 'Стабильность';

  @override
  String get stabilityScoreProName => 'Оценка стабильности';

  @override
  String get stabilityGradeRockSolid => 'Очень стабильно';

  @override
  String get stabilityGradeSteady => 'Стабильно';

  @override
  String get stabilityGradeVariable => 'Колеблется';

  @override
  String get stabilityGradeUnstable => 'Нестабильно';

  @override
  String get stabilityGradeUnknown => 'Нет данных';

  @override
  String stabilityIntro(int days) {
    return 'Насколько ровно держались параметры за последние $days дней.';
  }

  @override
  String get stabilitySectionVariable => 'Колеблются сильнее всего';

  @override
  String get stabilitySectionSteady => 'Держатся стабильно';

  @override
  String get stabilitySectionInsufficient => 'Мало данных';

  @override
  String stabilityTestCount(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count измерения за последние $days дн.',
      many: '$count измерений за последние $days дн.',
      few: '$count измерения за последние $days дн.',
      one: '$count измерение за последние $days дн.',
      zero: 'Нет измерений за последние $days дн.',
    );
    return '$_temp0';
  }

  @override
  String get stabilityWindowTitle => 'Окно стабильности';

  @override
  String get stabilityWindowSubtitle =>
      'Период, который учитывает оценка стабильности';

  @override
  String get insightsTitle => 'Подсказки';

  @override
  String get insightsProName => 'Умные подсказки';

  @override
  String get insightsIntro =>
      'На что стоит обратить внимание по последним измерениям.';

  @override
  String insightsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ещё $count',
      many: '+ещё $count',
      few: '+ещё $count',
      one: '+ещё $count',
    );
    return '$_temp0';
  }

  @override
  String insightLow(Object param) {
    return '$param ниже целевого диапазона';
  }

  @override
  String insightLowWorsening(Object param) {
    return '$param ниже диапазона и продолжает падать';
  }

  @override
  String insightHigh(Object param) {
    return '$param выше целевого диапазона';
  }

  @override
  String insightHighWorsening(Object param) {
    return '$param выше диапазона и продолжает расти';
  }

  @override
  String insightOutOfRange(Object param) {
    return '$param вне целевого диапазона';
  }

  @override
  String insightForecastLow(Object param, int days) {
    return '$param снижается — может выйти из диапазона через ~$days дн.';
  }

  @override
  String insightForecastHigh(Object param, int days) {
    return '$param растёт — может выйти из диапазона через ~$days дн.';
  }

  @override
  String insightOscillating(Object param) {
    return '$param колеблется, а не смещается — надёжного тренда нет';
  }

  @override
  String insightRecovering(Object param) {
    return '$param возвращается в диапазон';
  }

  @override
  String insightRecoveringDays(Object param, int days) {
    return '$param восстанавливается — в диапазоне через ~$days дн.';
  }

  @override
  String insightStale(Object param, int days) {
    return '$param: не измерялось $days дн.';
  }

  @override
  String get aiSummaryAction => 'Спроси свой ИИ';

  @override
  String get aiSummaryPrivacyNote =>
      'Это готовый промпт с данными твоего аквариума. Вставь его в ChatGPT, Claude, Gemini или другой ИИ-инструмент — всё готовится на твоём устройстве, никуда ничего не отправляется.';

  @override
  String get aiSummaryPromptPreview => 'Предпросмотр промпта';

  @override
  String get aiSummaryCopyPrompt => 'Копировать промпт';

  @override
  String aiSummaryWeeksChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недели',
      many: '$count недель',
      few: '$count недели',
      one: '$count неделя',
    );
    return '$_temp0';
  }

  @override
  String get aiSummaryCopied => 'Скопировано — вставь в чат со своим ИИ.';

  @override
  String get aiSummaryEmpty => 'Пока нет измерений — нечего обобщать.';

  @override
  String get aiSummaryInsightsFooter =>
      'Нужен более глубокий разбор? Спроси свой ИИ';

  @override
  String aiSummaryPreamble(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other:
          'У меня морской рифовый аквариум, я веду учёт в приложении. Ниже данные моего аквариума за последние $weeks недели. Проанализируй их, укажи на риски и тенденции, требующие внимания, и подскажи, что проверить или изменить.',
      many:
          'У меня морской рифовый аквариум, я веду учёт в приложении. Ниже данные моего аквариума за последние $weeks недель. Проанализируй их, укажи на риски и тенденции, требующие внимания, и подскажи, что проверить или изменить.',
      few:
          'У меня морской рифовый аквариум, я веду учёт в приложении. Ниже данные моего аквариума за последние $weeks недели. Проанализируй их, укажи на риски и тенденции, требующие внимания, и подскажи, что проверить или изменить.',
      one:
          'У меня морской рифовый аквариум, я веду учёт в приложении. Ниже данные моего аквариума за последнюю неделю. Проанализируй их, укажи на риски и тенденции, требующие внимания, и подскажи, что проверить или изменить.',
    );
    return '$_temp0';
  }

  @override
  String aiSummaryDocTitle(Object tank) {
    return '$tank — сводка морского аквариума';
  }

  @override
  String aiSummaryRunningSince(Object date) {
    return 'запущен $date';
  }

  @override
  String aiSummaryExportedLine(Object date) {
    return 'Экспортировано $date.';
  }

  @override
  String get aiSummaryStatusHeading => 'Состояние';

  @override
  String aiSummaryHealthLine(int score, Object grade) {
    return 'Оценка состояния: $score из 100 ($grade)';
  }

  @override
  String aiSummaryStabilityLine(int score, Object grade, int days) {
    return 'Оценка стабильности: $score из 100 ($grade) за последние $days дн.';
  }

  @override
  String get aiSummaryObservationsLead =>
      'Наблюдения приложения (по правилам):';

  @override
  String get aiSummaryParamsHeading => 'Параметры';

  @override
  String aiSummaryTestedOn(Object date) {
    return 'последний тест $date';
  }

  @override
  String aiSummaryTargetRange(Object range) {
    return 'Цель $range';
  }

  @override
  String aiSummaryAcceptableRange(Object range) {
    return 'допустимо $range';
  }

  @override
  String get aiSummaryColDate => 'Дата';

  @override
  String get aiSummaryColValue => 'Значение';

  @override
  String get aiSummaryColNote => 'Заметка';

  @override
  String get aiSummaryColElement => 'Элемент';

  @override
  String get aiSummaryColStatus => 'Статус';

  @override
  String aiSummaryShowingTests(int shown, int total) {
    return 'Показаны $shown последних из $total измерений.';
  }

  @override
  String get aiSummaryDosingHeading => 'План дозирования';

  @override
  String aiSummaryDailyEquivalent(Object amount) {
    return '≈$amount в день';
  }

  @override
  String aiSummarySinceDate(Object date) {
    return 'с $date';
  }

  @override
  String get aiSummaryOneOff => 'разовая доза';

  @override
  String get aiSummaryActionsHeading => 'Обслуживание за этот период';

  @override
  String get aiSummaryMicroHeading =>
      'Микроэлементы (последние измеренные значения)';

  @override
  String get dashboardSection => 'Панель';

  @override
  String get dashboardLayoutTitle => 'Вид панели';

  @override
  String get dashboardLayoutSubtitle =>
      'Как расположены карточки на вкладке «Измерения»';

  @override
  String get dashboardLayoutGrouped => 'По группам';

  @override
  String get dashboardLayoutFlat => 'Плоский';

  @override
  String get dashboardLayoutFlatGraph => 'Плоский с графиками';

  @override
  String get healthDisplayTitle => 'Состояние аквариума';

  @override
  String get healthDisplaySubtitle => 'Где показывать сводку состояния';

  @override
  String get healthDisplayBoth => 'Значок и карточка';

  @override
  String get healthDisplayBadge => 'Только значок';

  @override
  String get healthDisplayOff => 'Скрыто';

  @override
  String get routeNotFoundTitle => 'Страница не найдена';

  @override
  String get routeNotFoundBody => 'Эта ссылка никуда не ведёт в приложении.';

  @override
  String get routeNotFoundGoHome => 'На главный экран';

  @override
  String get notifChannelTesting => 'Напоминания об измерениях';

  @override
  String get notifChannelDosing => 'Напоминания о дозировании';

  @override
  String get notifChannelMaintenance => 'Напоминания об обслуживании';

  @override
  String get notifTestingTitle => 'Пора сделать тесты';

  @override
  String get notifDosingTitle => 'Пора дозировать';

  @override
  String get notifMaintenanceTitle => 'Пора провести обслуживание';

  @override
  String notifTitleWithTank(String title, String tank) {
    return '$title — $tank';
  }

  @override
  String get remindersTitle => 'Напоминания';

  @override
  String get remindersSubtitle =>
      'Уведомления об измерениях, дозировании и обслуживании';

  @override
  String get remindersTestingSubtitle => 'Когда пора сделать тест параметра';

  @override
  String get remindersDosingSubtitle =>
      'В заданное время дозирования каждой добавки';

  @override
  String get remindersMaintenanceSubtitle => 'Когда подходит срок обслуживания';

  @override
  String get reminderTimeTitle => 'Время напоминаний';

  @override
  String get reminderTimeSubtitle =>
      'Когда приходят напоминания об измерениях и обслуживании';

  @override
  String get remindersPermissionDenied =>
      'Уведомления заблокированы в настройках системы — напоминания не будут показаны.';

  @override
  String get remindToTest => 'Напоминать об измерении';

  @override
  String get cadenceOff => 'Выкл.';

  @override
  String daysShortN(int count) {
    return '$count дн.';
  }

  @override
  String get cadenceCustom => 'Свой';

  @override
  String get customDaysLabel => 'Дней';

  @override
  String get remindMe => 'Напоминать';

  @override
  String get remindMeNeedsTime =>
      'Укажи время дозирования, чтобы включить напоминания';

  @override
  String get maintenanceSchedule => 'План обслуживания';

  @override
  String get addMaintenanceTask => 'Добавить задачу';

  @override
  String get editMaintenanceTask => 'Изменить задачу';

  @override
  String get taskTypeLabel => 'Тип';

  @override
  String get customTask => 'Своя задача';

  @override
  String get taskTitleLabel => 'Название';

  @override
  String get taskTitleRequired => 'Введи название';

  @override
  String get repeatLabel => 'Повтор';

  @override
  String get oneOff => 'Однократно';

  @override
  String get dueDateLabel => 'Срок';

  @override
  String get dueDateRequired => 'Выбери срок';

  @override
  String get dueToday => 'Сегодня';

  @override
  String dueInDaysN(int count) {
    return 'Через $count дн.';
  }

  @override
  String overdueDaysN(int count) {
    return 'Просрочено на $count дн.';
  }

  @override
  String get markDone => 'Готово';

  @override
  String get taskMarkedDone => 'Отмечено выполненным';

  @override
  String get taskDeleted => 'Задача удалена';

  @override
  String get scheduleEmptyBody =>
      'Пока нет задач обслуживания. Запланируй подмены воды или свои задачи, чтобы видеть сроки и получать напоминания.';

  @override
  String get repeatModeLabel => 'Повтор';

  @override
  String get repeatEveryDays => 'Каждые X дней';

  @override
  String get repeatEveryWeeks => 'Каждые X недель';

  @override
  String get repeatEveryMonths => 'Каждые X месяцев';

  @override
  String get repeatOnWeekdays => 'Дни недели';

  @override
  String get repeatOnMonthDay => 'День месяца';

  @override
  String get weeksLabel => 'Недели';

  @override
  String get monthsLabel => 'Месяцы';

  @override
  String get monthDayLabel => 'День месяца (1–31)';

  @override
  String get invalidInterval => 'Введи целое число (не менее 1).';

  @override
  String get invalidMonthDay => 'Введи день от 1 до 31.';

  @override
  String get weekdaysRequired => 'Выбери хотя бы один день.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Каждые $n недели',
      many: 'Каждые $n недель',
      few: 'Каждые $n недели',
      one: 'Раз в $n неделю',
    );
    return '$_temp0';
  }

  @override
  String everyMonthsN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Каждые $n месяца',
      many: 'Каждые $n месяцев',
      few: 'Каждые $n месяца',
      one: 'Раз в $n месяц',
    );
    return '$_temp0';
  }

  @override
  String everyWeekdays(String days) {
    return 'По $days';
  }

  @override
  String monthlyOnDayN(int n) {
    return 'Ежемесячно $n-го числа';
  }

  @override
  String get roUnitTitle => 'Установка обратного осмоса';

  @override
  String get roStageSediment => 'Механический фильтр';

  @override
  String get roStageCarbonBlock => 'Угольный блок';

  @override
  String get roStageMembrane => 'Мембрана обратного осмоса';

  @override
  String get roStageDiResin => 'DI-смола';

  @override
  String get roCustomStage => 'Своя ступень';

  @override
  String get roAddStage => 'Добавить ступень';

  @override
  String get roEditStage => 'Изменить ступень';

  @override
  String get roLifespanLabel => 'Менять каждые';

  @override
  String get roUnitDays => 'дней';

  @override
  String get roUnitWeeks => 'недель';

  @override
  String get roUnitMonths => 'месяцев';

  @override
  String get roPartOfUnit => 'Есть в моей установке';

  @override
  String get roPartOfUnitHint =>
      'Выключи, если в твоей установке нет этой ступени';

  @override
  String get roHiddenStages => 'Нет в моей установке';

  @override
  String get roMarkReplaced => 'Заменено';

  @override
  String get roReplacedRecorded => 'Замена записана';

  @override
  String roLastReplaced(String date) {
    return 'Заменено $date';
  }

  @override
  String get roNoReplacementYet => 'Замены ещё не записаны';

  @override
  String get roDeleteStageTitle => 'Удалить ступень?';

  @override
  String get roDeleteStageBody =>
      'Ступень и история её замен будут удалены. Это нельзя отменить.';

  @override
  String get roEmptyBody =>
      'Нет ступеней. Добавь фильтры своей установки кнопкой +.';

  @override
  String get roSetupPrompt => 'Следи за заменой фильтров и мембраны';

  @override
  String get roUnitToggleSubtitle =>
      'Показывать на вкладке «Действия», с напоминаниями о замене фильтров';

  @override
  String get roAllOk => 'Все ступени в порядке';

  @override
  String get roUsageTitle => 'Интенсивность использования';

  @override
  String get roUsageDialogBody =>
      'Сколько воды производит твоя установка. Выбор интенсивности задаст всем стандартным ступеням типичные для этого уровня интервалы замены, перезаписав в том числе настроенные самостоятельно; собственные ступени останутся без изменений, а каждую ступень затем можно будет изменить вручную.';

  @override
  String get roUsageLight => 'Низкая';

  @override
  String get roUsageModerate => 'Средняя';

  @override
  String get roUsageHeavy => 'Высокая';

  @override
  String get roUsageLightHint =>
      'До ~300 л (80 гал) в месяц — долив и небольшие подмены воды';

  @override
  String get roUsageModerateHint =>
      'Примерно 300–1000 л (80–260 гал) в месяц — один обычный аквариум';

  @override
  String get roUsageHeavyHint =>
      'Более ~1000 л (260 гал) в месяц — большой аквариум или несколько';

  @override
  String get roUsageApplied =>
      'Интервалы замены стандартных ступеней заданы заново';

  @override
  String get notifRoTitle => 'Замени фильтры обратного осмоса';

  @override
  String get reefFactoryTitle => 'Устройства ReefFactory';

  @override
  String get reefFactoryMenu => 'Устройства ReefFactory';

  @override
  String get reefFactoryDisclaimer =>
      'Это приложение только считывает текущие значения с твоих устройств ReefFactory. Оно не может менять настройки, калибровать или обновлять прошивку — для этого используй приложение ReefFactory. Чтение работает, только пока телефон находится в той же сети Wi-Fi, что и устройства.';

  @override
  String get reefFactoryAddDevice => 'Добавить устройство';

  @override
  String get reefFactoryEmptyTitle => 'Пока нет устройств';

  @override
  String get reefFactoryEmptyBody =>
      'Добавь измеритель ReefFactory по IP-адресу или имени хоста, чтобы считывать его текущие значения.';

  @override
  String get reefFactoryRefresh => 'Обновить';

  @override
  String get reefFactorySave => 'Сохранить';

  @override
  String get reefFactoryRefreshAll => 'Обновить все';

  @override
  String get reefFactorySaveAll => 'Сохранить все';

  @override
  String get reefFactoryNothingToSave =>
      'Пока нечего сохранять — сначала нажми «Обновить все».';

  @override
  String reefFactorySavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранено $count показания',
      many: 'Сохранено $count показаний',
      few: 'Сохранено $count показания',
      one: 'Сохранено 1 показание',
    );
    return '$_temp0';
  }

  @override
  String get reefFactoryNotReadYet =>
      'Нажми «Обновить все», чтобы считать текущее значение.';

  @override
  String get reefFactoryHeating => 'Нагрев';

  @override
  String get reefFactoryCooling => 'Охлаждение';

  @override
  String get reefFactoryNoTank =>
      'Сначала назначь аквариум, чтобы сохранять показания.';

  @override
  String get reefFactoryTankLabel => 'Аквариум';

  @override
  String get reefFactorySelectTank => 'Выбери аквариум';

  @override
  String get reefFactoryMoveToTank => 'Переместить в другой аквариум';

  @override
  String get reefFactoryRenameDevice => 'Переименовать устройство';

  @override
  String get reefFactoryDeviceNameLabel => 'Название';

  @override
  String get reefFactoryRemove => 'Удалить устройство';

  @override
  String reefFactoryRemoveConfirm(Object name) {
    return 'Удалить $name из списка? Сохранённые показания останутся.';
  }

  @override
  String get reefFactoryHostLabel => 'IP-адрес или имя хоста';

  @override
  String get reefFactoryHostHint => 'напр. 192.168.1.50';

  @override
  String get reefFactoryHostHelp =>
      'Найди его в приложении ReefFactory или в роутере. Резервирование DHCP не даст ему меняться. Телефон должен быть в той же сети Wi-Fi, что и устройство.';

  @override
  String get reefFactoryCheck => 'Проверить';

  @override
  String reefFactoryFound(Object model) {
    return 'Найдено: $model';
  }

  @override
  String get reefFactoryErrUnreachable =>
      'Не удалось подключиться по этому адресу. Убедись, что устройство включено и в той же сети.';

  @override
  String get reefFactoryErrTimeout => 'Подключено, но значение не пришло.';

  @override
  String get reefFactoryErrUnsupported =>
      'Эта модель устройства пока не поддерживается.';

  @override
  String get reefFactoryErrProtocol => 'Не удалось считать устройство.';

  @override
  String get reefBeatTitle => 'Устройства ReefBeat';

  @override
  String get reefBeatMenu => 'Устройства ReefBeat';

  @override
  String get reefBeatSettingsSubtitle =>
      'Данные устройств Red Sea ReefBeat в реальном времени';

  @override
  String get reefBeatDisclaimer =>
      'Это приложение только считывает данные твоих устройств Red Sea ReefBeat в реальном времени. Оно не может дозировать, менять расписания или калибровать — для этого используй приложение ReefBeat. Чтение работает, только пока телефон находится в той же сети Wi-Fi, что и устройства.';

  @override
  String get reefBeatAddDevice => 'Добавить устройство';

  @override
  String get reefBeatEmptyTitle => 'Пока нет устройств';

  @override
  String get reefBeatEmptyBody =>
      'Просканируй свою сеть Wi-Fi, чтобы найти устройства Red Sea ReefBeat — ReefDose, ReefATO, ReefMat, ReefRun, ReefLED, ReefWave и ReefControl, — или добавь устройство по IP-адресу.';

  @override
  String get reefBeatRefreshAll => 'Обновить все';

  @override
  String get reefBeatNotReadYet =>
      'Нажми «Обновить все», чтобы считать текущий статус.';

  @override
  String get reefBeatTankLabel => 'Аквариум';

  @override
  String get reefBeatSelectTank => 'Выбери аквариум';

  @override
  String get reefBeatMoveToTank => 'Переместить в другой аквариум';

  @override
  String get reefBeatRenameDevice => 'Переименовать устройство';

  @override
  String get reefBeatDeviceNameLabel => 'Название';

  @override
  String get reefBeatRemove => 'Удалить устройство';

  @override
  String reefBeatRemoveConfirm(Object name) {
    return 'Удалить $name из списка?';
  }

  @override
  String get reefBeatHostLabel => 'IP-адрес или имя хоста';

  @override
  String get reefBeatHostHint => 'напр. 192.168.1.3';

  @override
  String get reefBeatHostHelp =>
      'Найди его в списке клиентов роутера. Резервирование DHCP не даст ему меняться. Телефон должен быть в той же сети Wi-Fi, что и устройство.';

  @override
  String get reefBeatCheck => 'Проверить';

  @override
  String reefBeatFound(Object model) {
    return 'Найдено: $model';
  }

  @override
  String get reefBeatErrUnreachable =>
      'Не удалось подключиться по этому адресу. Убедись, что устройство включено и в той же сети.';

  @override
  String get reefBeatErrTimeout => 'Подключено, но ответ не пришёл.';

  @override
  String get reefBeatErrUnsupported =>
      'Этот тип устройства ReefBeat пока не поддерживается.';

  @override
  String get reefBeatErrProtocol => 'Не удалось считать устройство.';

  @override
  String reefBeatHead(int number) {
    return 'Головка $number';
  }

  @override
  String get reefBeatHeadOff => 'Выкл.';

  @override
  String reefBeatDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'осталось $count дня',
      many: 'осталось $count дней',
      few: 'осталось $count дня',
      one: 'остался $count день',
    );
    return '$_temp0';
  }

  @override
  String reefBeatDosedOfDaily(Object dosed, Object daily) {
    return '$dosed / $daily мл';
  }

  @override
  String reefBeatDosedNoDaily(Object dosed) {
    return '$dosed мл';
  }

  @override
  String reefBeatDosedManual(Object volume) {
    return '$volume мл вручную';
  }

  @override
  String reefBeatDosedManualExtra(Object volume) {
    return '+$volume мл вручную';
  }

  @override
  String reefBeatDoseDue(Object volume) {
    return 'осталось $volume мл';
  }

  @override
  String get reefBeatPlanComplete => 'Выполнено';

  @override
  String reefBeatDoseCount(int done, int total) {
    return 'Дозы $done/$total';
  }

  @override
  String reefBeatDosedSemantics(Object dosed, Object daily) {
    return 'внесено $dosed из $daily мл сегодняшнего плана';
  }

  @override
  String reefBeatDosedManualSemantics(Object volume) {
    return 'плюс $volume мл внесено вручную';
  }

  @override
  String get reefBeatDosingQueue => 'Очередь дозирования на сегодня';

  @override
  String get reefBeatDosingQueueEmpty => 'На сегодня доз больше нет';

  @override
  String reefBeatDosingQueueTotal(int count, Object volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дозы',
      many: '$count доз',
      few: '$count дозы',
      one: '$count доза',
    );
    return '$_temp0 · $volume мл';
  }

  @override
  String reefBeatDosingQueueVolume(Object volume) {
    return '$volume мл';
  }

  @override
  String get reefBeatRecalibration => 'Требуется повторная калибровка';

  @override
  String reefBeatMissedDose(Object volume) {
    return 'Пропущенная доза: $volume мл';
  }

  @override
  String get reefBeatTimeError => 'Ошибка часов устройства';

  @override
  String get reefBeatBatteryLow => 'Резервная батарея разряжена';

  @override
  String get reefBeatAtoLeak => 'Обнаружена протечка!';

  @override
  String get reefBeatAtoSensorError => 'Проблема с датчиком уровня';

  @override
  String get reefBeatAtoFilling => 'Идёт долив';

  @override
  String get reefBeatAtoWaterLevel => 'Уровень воды';

  @override
  String get reefBeatAtoLevelOk => 'В норме';

  @override
  String get reefBeatAtoLevelLow => 'Низкий';

  @override
  String get reefBeatAtoLevelAbove => 'Повышенный';

  @override
  String get reefBeatAtoTemperature => 'Температура';

  @override
  String get reefBeatAtoToday => 'Сегодня';

  @override
  String reefBeatAtoFills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count долива',
      many: '$count доливов',
      few: '$count долива',
      one: '$count долив',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatAtoEvaporation => 'Испарение';

  @override
  String reefBeatAtoPerDay(Object volume) {
    return '≈$volume/день';
  }

  @override
  String get reefBeatAtoReservoir => 'Резервуар';

  @override
  String get reefBeatAtoLeakSensor => 'Датчик протечки';

  @override
  String get reefBeatAtoLeakNotConnected => 'Не подключён';

  @override
  String get reefBeatAtoLeakNotEnabled => 'Не включён';

  @override
  String get reefBeatAtoLeakDry => 'Сухо';

  @override
  String get reefBeatAtoLeakRodi => 'Протечка воды RO/DI';

  @override
  String get reefBeatAtoLeakAquarium => 'Протечка аквариумной воды';

  @override
  String get reefBeatMatRoll => 'Рулон';

  @override
  String get reefBeatMatRollEmpty => 'Конец рулона';

  @override
  String get reefBeatMatRollLow => 'Рулон заканчивается';

  @override
  String get reefBeatMatCleanSensor => 'Очисти датчик';

  @override
  String get reefBeatMatAutoAdvanceOff => 'Автоподача выключена';

  @override
  String get reefBeatMatAdvancing => 'Идёт подача';

  @override
  String get reefBeatMatUsedToday => 'Израсходовано сегодня';

  @override
  String get reefBeatMatAverage => 'В среднем';

  @override
  String reefBeatMatPerDay(Object length) {
    return '≈$length/день';
  }

  @override
  String get reefBeatMatInstalled => 'Рулон установлен';

  @override
  String reefBeatMatRollAge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatMode => 'Режим';

  @override
  String reefBeatPercent(int value) {
    return '$value %';
  }

  @override
  String reefBeatRunPump(int number) {
    return 'Помпа $number';
  }

  @override
  String get reefBeatRunScheduleOff => 'Расписание выкл.';

  @override
  String get reefBeatRunTemperature => 'Температура мотора';

  @override
  String get reefBeatRunMissingPump => 'Помпа не обнаружена';

  @override
  String get reefBeatRunMissingSensor => 'Датчик не обнаружен';

  @override
  String reefBeatRunState(Object state) {
    return 'Состояние помпы: $state';
  }

  @override
  String get reefBeatRunFullCup => 'Стакан полон';

  @override
  String get reefBeatRunOverSkimming => 'Чрезмерное вспенивание';

  @override
  String get reefBeatRunSensorOffline => 'Датчик уровня недоступен';

  @override
  String get reefBeatRunSensorBadge => 'Датчик';

  @override
  String get reefBeatLightWhite => 'Белый';

  @override
  String get reefBeatLightBlue => 'Синий';

  @override
  String get reefBeatLightMoon => 'Луна';

  @override
  String get reefBeatLightFan => 'Вентилятор';

  @override
  String get reefBeatLightTemperature => 'Радиатор';

  @override
  String get reefBeatLightTilt => 'Светильник наклонён';

  @override
  String reefBeatLightAcclimation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Акклиматизация: осталось $count дня',
      many: 'Акклиматизация: осталось $count дней',
      few: 'Акклиматизация: осталось $count дня',
      one: 'Акклиматизация: остался $count день',
    );
    return '$_temp0';
  }

  @override
  String get reefBeatLightAcclimationOn => 'Идёт акклиматизация';

  @override
  String get reefBeatLightMoonPhase => 'Фаза луны';

  @override
  String reefBeatLightMoonDay(Object name, int day) {
    return '$name, день $day';
  }

  @override
  String get reefBeatWaveGroup => 'Помпы ReefWave';

  @override
  String get apexTitle => 'Neptune Apex';

  @override
  String get apexMenu => 'Neptune Apex';

  @override
  String get apexSettingsSubtitle =>
      'Текущие показания датчиков и состояние розеток Apex';

  @override
  String get apexDisclaimer =>
      'Это приложение только считывает твой Apex. Оно не может переключать розетки, запускать режим кормления или менять программы — для этого используй Fusion или веб-страницу Apex. Чтение работает, только пока телефон находится в той же сети Wi-Fi, что и контроллер.';

  @override
  String get apexAddDevice => 'Добавить контроллер';

  @override
  String get apexEmptyTitle => 'Контроллеров пока нет';

  @override
  String get apexEmptyBody =>
      'Добавь Apex по его IP-адресу и учётным данным, которые ты используешь на его веб-странице.';

  @override
  String get apexRefreshAll => 'Обновить все';

  @override
  String get apexSaveAll => 'Сохранить все';

  @override
  String get apexSave => 'Сохранить';

  @override
  String apexSavedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохранено $count показания',
      many: 'Сохранено $count показаний',
      few: 'Сохранено $count показания',
      one: 'Сохранено 1 показание',
    );
    return '$_temp0';
  }

  @override
  String get apexNothingToSave => 'Пока нечего сохранять.';

  @override
  String get apexNoTank =>
      'Назначь контроллер аквариуму, чтобы сохранять его показания.';

  @override
  String get apexNotReadYet =>
      'Нажми «Обновить все», чтобы считать текущие значения.';

  @override
  String get apexNoProbes =>
      'У этого контроллера нет датчиков, показания которых приложение может сохранить.';

  @override
  String get apexOutlets => 'Розетки';

  @override
  String apexShowAll(int count) {
    return 'Показать ещё $count';
  }

  @override
  String get apexShowFewer => 'Показать меньше';

  @override
  String apexOverridden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count розетки переключены вручную',
      many: '$count розеток переключены вручную',
      few: '$count розетки переключены вручную',
      one: '1 розетка переключена вручную',
    );
    return '$_temp0';
  }

  @override
  String get apexOutletOnSemantics => 'включено';

  @override
  String get apexOutletOffSemantics => 'выключено';

  @override
  String get apexOutletProfileSemantics => 'управляется профилем';

  @override
  String get apexOutletOverriddenSemantics => 'переключено вручную';

  @override
  String apexFeedRunning(Object letter) {
    return 'Идёт режим кормления $letter';
  }

  @override
  String get apexRenameDevice => 'Переименовать контроллер';

  @override
  String get apexDeviceNameLabel => 'Название контроллера';

  @override
  String get apexCredentialsMenu => 'Войти заново';

  @override
  String get apexMoveToTank => 'Переместить в другой аквариум';

  @override
  String get apexRemove => 'Удалить';

  @override
  String apexRemoveConfirm(Object name) {
    return 'Удалить «$name»? Сохранённые показания останутся.';
  }

  @override
  String get apexSelectTank => 'Выбери аквариум';

  @override
  String get apexHostLabel => 'IP-адрес или имя хоста';

  @override
  String get apexHostHint => '192.168.1.50';

  @override
  String get apexHostHelp =>
      'Адрес, по которому ты открываешь веб-страницу Apex. Найди его в Fusion в разделе «Misc Setup» или в роутере.';

  @override
  String get apexUsernameLabel => 'Имя пользователя';

  @override
  String get apexPasswordLabel => 'Пароль';

  @override
  String get apexCheck => 'Проверить';

  @override
  String apexFound(Object model, Object serial) {
    return 'Найдено: $model · $serial';
  }

  @override
  String get apexTankLabel => 'Аквариум';

  @override
  String get apexErrUnreachable =>
      'Не удалось связаться с этим адресом. Проверь, что контроллер включён и находится в этой сети.';

  @override
  String get apexErrTimeout =>
      'Подключение есть, но контроллер не ответил вовремя.';

  @override
  String get apexErrAuth =>
      'Контроллер отклонил это имя пользователя или пароль.';

  @override
  String get apexErrProtocol =>
      'По этому адресу что-то ответило, но это не Apex.';

  @override
  String get discoveryTitle => 'Поиск в сети';

  @override
  String get discoverySweeping => 'Ищем устройства в твоей сети Wi-Fi…';

  @override
  String get discoveryIdentifying => 'Проверяем найденные устройства…';

  @override
  String get discoveryDone => 'Поиск завершён.';

  @override
  String get discoveryNoNetwork =>
      'Телефон не подключён к сети Wi-Fi. Подключись к той же сети, что и твои устройства, и повтори поиск.';

  @override
  String get discoveryNothingFoundHelp =>
      'Устройства не найдены. Убедись, что они включены и подключены к этой сети Wi-Fi. Некоторые гостевые сети запрещают устройствам видеть друг друга. Устройство всё ещё можно добавить по IP-адресу.';

  @override
  String get discoveryAdd => 'Добавить';

  @override
  String get discoveryUpdate => 'Обновить';

  @override
  String get discoveryAlreadyAdded => 'Добавлено';

  @override
  String discoveryAddressChanged(Object address) {
    return 'Теперь на $address';
  }

  @override
  String get discoveryUnsupported => 'Не поддерживается';

  @override
  String get discoveryUnsupportedHelp =>
      'Приложение пока не умеет читать этот тип устройств.';

  @override
  String get discoveryRescan => 'Искать снова';

  @override
  String get discoveryManualEntry => 'Ввести IP-адрес';

  @override
  String get discoveryFailed =>
      'Поиск прервался из-за непредвиденной ошибки. Попробуй выполнить поиск ещё раз.';

  @override
  String get discoveryPermissionDenied =>
      'У ReefTracker нет доступа к локальной сети, поэтому ни поиск, ни ввод адреса вручную не сработают. Разреши доступ в Настройки → Конфиденциальность и безопасность → Локальная сеть и повтори поиск.';

  @override
  String deviceAlreadyAdded(Object name) {
    return 'Устройство $name уже добавлено. Чтобы указать новый адрес, используй Поиск в сети.';
  }

  @override
  String get devicesTitle => 'Подключённые устройства';

  @override
  String get devicesTab => 'Устройства';

  @override
  String get devicesAll => 'Все';

  @override
  String devicesScopeAll(int count) {
    return 'Все устройства · $count';
  }

  @override
  String devicesScopeVendor(String vendor, int count) {
    return '$vendor · $count';
  }

  @override
  String devicesRefreshAll(int count) {
    return 'Обновить все ($count)';
  }

  @override
  String devicesSaveAll(int count) {
    return 'Сохранить все ($count)';
  }

  @override
  String get devicesDisclaimer =>
      'Приложение только считывает данные с устройств. Оно не может менять настройки, дозировать, переключать розетки или калибровать — для этого используй приложение производителя. Чтение работает, только пока телефон находится в той же сети Wi-Fi, что и устройства.';

  @override
  String get devicesEmptyTitle => 'Устройств пока нет';

  @override
  String get devicesEmptyBody =>
      'Подключи измеритель ReefFactory, устройство Red Sea ReefBeat или контроллер Neptune Apex в своей сети — или выполни измерение фотометром Hanna по Bluetooth — и они появятся здесь.';

  @override
  String get devicesAddDevice => 'Добавить устройство';

  @override
  String get devicesHannaDisclaimer =>
      'Фотометр подключается по Bluetooth только на время измерения — запусти его с карточки устройства. Завершённые измерения сохраняются в твой журнал.';

  @override
  String get devicesAddPickBrand => 'Какой бренд?';

  @override
  String get devicesReorderBrands => 'Изменить порядок брендов';

  @override
  String get devicesReorderBrandsHint =>
      'Если два устройства сообщают одно и то же значение, побеждает бренд, стоящий выше в этом списке.';

  @override
  String devicesSourceNote(String param, String device) {
    return '$param с устройства $device';
  }

  @override
  String get devicesProLocked =>
      'Чтение устройств в реальном времени входит в ReefTracker Pro.';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count устройства',
      many: '$count устройств',
      few: '$count устройства',
      one: '1 устройство',
    );
    return '$_temp0';
  }

  @override
  String get devicesDetails => 'Подробности';

  @override
  String get reefDevicesTitle => 'Подключённые устройства';

  @override
  String get reefDevicesSubtitle =>
      'Измерители ReefFactory, устройства ReefBeat, контроллеры Apex и Hanna checker';

  @override
  String get reefDevicesEmpty => 'Пока нет подключённых устройств.';

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
    return 'Последний раз на связи $date';
  }

  @override
  String get hannaSerialNumber => 'Серийный номер';

  @override
  String get hannaLastMeasurement => 'Последнее измерение';

  @override
  String get hannaNewMeasurement => 'Новое измерение';

  @override
  String get hannaRenameDevice => 'Переименовать фотометр';

  @override
  String get hannaDeviceNameLabel => 'Название фотометра';

  @override
  String get hannaRemove => 'Удалить';

  @override
  String hannaRemoveConfirm(Object name) {
    return 'Удалить «$name»? Сохранённые значения останутся, а после следующего измерения фотометр появится снова.';
  }

  @override
  String get resetParamDefaults => 'Сбросить до значений по умолчанию';

  @override
  String get resetParamDefaultsTitle =>
      'Сбросить все параметры до значений по умолчанию?';

  @override
  String get resetParamDefaultsBody =>
      'Каждый параметр вернётся к рекомендованным границам для этого типа аквариума, а микроэлементы — к встроенным значениям. Границы, заданные вручную, будут удалены. Измерения сохранятся.';

  @override
  String get paramDefaultsRestored =>
      'Параметры сброшены до значений по умолчанию.';

  @override
  String get resetThisParamDefaults =>
      'Сбросить этот параметр до значений по умолчанию';

  @override
  String get reset => 'Сбросить';

  @override
  String get followingDefaults => 'Используются значения по умолчанию';

  @override
  String get wallDisplayTitle => 'Настенный дисплей';

  @override
  String get wallDisplaySubtitle =>
      'Постоянно включённая панель с показателями твоего аквариума';

  @override
  String get wallSmallScreenNote =>
      'Настенный дисплей рассчитан на планшет, закреплённый на стене. На этом небольшом экране он тоже работает – просто на странице поместится меньше карточек.';

  @override
  String get wallStartNow => 'Запустить сейчас';

  @override
  String get wallStartNowSubtitle => 'Показать настенную панель на этом экране';

  @override
  String get wallAutoStartTitle => 'Запускать при старте';

  @override
  String get wallAutoStartSubtitle =>
      'Открывать настенный дисплей при каждом запуске приложения на этом устройстве';

  @override
  String get wallBehaviourSection => 'Поведение';

  @override
  String get wallRefreshIntervalTitle => 'Обновлять каждые';

  @override
  String get wallRefreshIntervalSubtitle =>
      'Как часто опрашиваются подключённые устройства';

  @override
  String get wallPageSecondsTitle => 'Смена страниц';

  @override
  String get wallPageSecondsSubtitle =>
      'Сколько времени показывается каждая страница';

  @override
  String get wallNightTitle => 'Ночное затемнение';

  @override
  String get wallNightSubtitle =>
      'Затемнять экран ночью; касание снимает затемнение на минуту';

  @override
  String get wallNightFromTitle => 'Затемнять с';

  @override
  String get wallNightToTitle => 'Затемнять до';

  @override
  String get wallDataSection => 'Собранные данные';

  @override
  String get wallClearSamplesTitle => 'Очистить собранные измерения';

  @override
  String get wallClearSamplesSubtitle =>
      'Удалить онлайн-измерения, используемые в графиках настенного экрана';

  @override
  String get wallClearSamplesDialogTitle => 'Очистить собранные измерения?';

  @override
  String get wallClearSamplesDialogBody =>
      'Выбери, какую часть недавней онлайн-истории сохранить. Введённые вручную измерения не удаляются.';

  @override
  String get wallClearSamplesAll => 'Удалить всё';

  @override
  String get wallKeepSamples1h => 'Сохранить данные за последний час';

  @override
  String get wallKeepSamples4h => 'Сохранить данные за последние 4 часа';

  @override
  String get wallKeepSamples12h => 'Сохранить данные за последние 12 часов';

  @override
  String get wallSamplesHistoryUpdated =>
      'История собранных измерений обновлена';

  @override
  String get wallCardsSection => 'Карточки';

  @override
  String get wallCardsHint =>
      'Каждое значение, которое сообщает устройство, получает свою карточку. Скрой ненужные дубликаты и расставь остальные; если скрыть все карточки устройства, панель перестанет к нему обращаться.';

  @override
  String get wallStoredCard => 'Ручные измерения';

  @override
  String wallSecondsLabel(int n) {
    return '$n с';
  }

  @override
  String wallMinutesLabel(int n) {
    return '$n мин';
  }

  @override
  String get wallNoTank =>
      'Пока нет аквариума. Добавь его, затем запусти настенный дисплей.';

  @override
  String get wallProLocked => 'Настенный дисплей — функция PRO.';

  @override
  String get wallExitHint => 'Удерживай в любом месте, чтобы выйти';

  @override
  String wallUpdatedAt(Object time) {
    return 'обновлено $time';
  }

  @override
  String wallDueToday(Object items) {
    return 'Сегодня: $items';
  }

  @override
  String wallTestDue(Object param) {
    return 'тест: $param';
  }

  @override
  String get wallNoDevices => 'Нет устройств';

  @override
  String get wallAllReachable => 'Все устройства доступны';

  @override
  String get wallSomeUnreachable => 'Устройство недоступно';

  @override
  String get wallNetworkDown => 'Устройства недоступны — проверь сеть';

  @override
  String wallMeasuredAgo(Object ago) {
    return 'измерено $ago';
  }

  @override
  String get wallWindow24h => '24 ч';

  @override
  String get wallWindow14d => '14 д';

  @override
  String wallHeadDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String wallHeadMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }
}
