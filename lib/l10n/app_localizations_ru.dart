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
  String get tourTankTitle => 'Ваши аквариумы';

  @override
  String get tourTankDesc =>
      'Нажмите здесь, чтобы переключаться между аквариумами или добавить новый.';

  @override
  String get tourCompareTitle => 'Сравнение';

  @override
  String get tourCompareDesc =>
      'Переключайтесь между карточками параметров и совмещёнными графиками.';

  @override
  String get tourParamsTitle => 'Управление параметрами';

  @override
  String get tourParamsDesc =>
      'Выберите, какие параметры воды отслеживать, и задайте их целевые диапазоны.';

  @override
  String get tourDosingHistoryTitle => 'История дозирования';

  @override
  String get tourDosingHistoryDesc =>
      'Просматривайте все прошлые и текущие периоды дозирования и удаляйте запись, добавленную по ошибке.';

  @override
  String get tourDoseCalcTitle => 'Калькулятор дозировки';

  @override
  String get tourDoseCalcDesc =>
      'На вкладке «Дозирование» откройте калькулятор, чтобы оценить суточную дозу, удерживающую элемент стабильным.';

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
      'Создайте свой первый аквариум, чтобы начать отслеживать параметры воды.';

  @override
  String get noParamsTracked =>
      'Для этого аквариума не отслеживаются параметры.';

  @override
  String get noReadings => 'Нет измерений';

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
    return '$count дн назад';
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
  String get enterAName => 'Введите название';

  @override
  String get setupType => 'Тип аквариума';

  @override
  String get presetSeedNote =>
      'Для этого типа аквариума будут заданы параметры по умолчанию и границы зон. Их можно настроить в любой момент.';

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
  String sinceDate(Object date) {
    return 'с $date';
  }

  @override
  String get parameters => 'Параметры';

  @override
  String get noActiveAquarium => 'Нет активного аквариума.';

  @override
  String reapplyPreset(Object type) {
    return 'Повторно применить пресет $type';
  }

  @override
  String reapplyPresetTitle(Object type) {
    return 'Повторно применить пресет $type?';
  }

  @override
  String get reapplyPresetBody =>
      'Это перезапишет границы зелёная/жёлтая/красная всех отслеживаемых параметров значениями пресета по умолчанию. Ваши измерения сохранятся.';

  @override
  String get presetApplied => 'Пресет применён.';

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
  String get enterANumber => 'Введите число';

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
  String get invalidVolume => 'Введите корректный положительный объём.';

  @override
  String get invalidPositiveNumber => 'Введите положительное число.';

  @override
  String get invalidIntervalDays => 'Введите целое число дней (не менее 1).';

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
      'Следующее значение выходит за пределы обычного диапазона. Проверьте, нет ли опечатки, прежде чем сохранять.';

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
  String get saveAnyway => 'Всё равно сохранить';

  @override
  String get enterAtLeastOneValue => 'Введите хотя бы одно значение.';

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
  String get testSetNeedParam => 'Выберите хотя бы один параметр.';

  @override
  String deleteTestSetTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteTestSetBody =>
      'Набор тестов будет удалён. Ваши измерения сохранятся.';

  @override
  String get testSetEmptyHint =>
      'В этом наборе нет активных параметров. Измените его или переключитесь на «Все».';

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
      'Наборов тестов пока нет. Набор позволяет записывать только те параметры, которые вы тестируете вместе.';

  @override
  String get rangeWeek => '7 дн';

  @override
  String get rangeMonth => '30 дн';

  @override
  String get rangeQuarter => '90 дн';

  @override
  String get rangeAll => 'Все';

  @override
  String get noReadingsInRange => 'Нет измерений в этом диапазоне.';

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
  String get ratioPo4No3Label => 'PO₄ : NO₃';

  @override
  String get ratioPo4No3Title => 'Соотношение PO₄ : NO₃';

  @override
  String get ratioMgCaLabel => 'Mg : Ca';

  @override
  String get ratioMgCaTitle => 'Соотношение Mg : Ca';

  @override
  String get ratioCaAlkLabel => 'Ca : Alk';

  @override
  String get ratioCaAlkTitle => 'Соотношение Ca : Alk';

  @override
  String get ratioMgAlkLabel => 'Mg : Alk';

  @override
  String get ratioMgAlkTitle => 'Соотношение Mg : Alk';

  @override
  String get ratioNoData =>
      'Запишите оба параметра, чтобы увидеть их соотношение.';

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
      'Добавьте добавки, которые вы дозируете в этот аквариум — производитель, продукт и при желании доза и расписание.';

  @override
  String get dosingNoDosage => 'Доза не указана';

  @override
  String get supplementStopped => 'Добавка остановлена';

  @override
  String get dosingHistoryTitle => 'История дозирования';

  @override
  String get dosingHistoryEmpty => 'Истории дозирования пока нет.';

  @override
  String get dosingHistoryCurrent => 'Текущая';

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
  String get dosingBasis => 'Основа';

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
      one: 'Каждый $n-й день',
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
  String get languageSection => 'Язык';

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
  String get salinityCalculatorSubtitle => 'Перевод ppt ↔ удельный вес (SG)';

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
      'ВСЕ данные ваших аквариумов — все аквариумы, параметры и измерения — будут заменены содержимым файла резервной копии. Настройки на этом устройстве (язык, единицы измерения и предпочтения) сохранятся. Это действие нельзя отменить.';

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
      'Не удалось загрузить часть данных. Если это повторяется, перезапустите приложение или восстановите резервную копию.';

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
  String get aboutAppName => 'О приложении ReefTracker';

  @override
  String get aboutDescription =>
      'Офлайн-трекер параметров морского аквариума с историей, графиками по времени и зонами здоровья зелёная/жёлтая/красная.';

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
  String get calculatorIntro =>
      'Перевод между практической солёностью (ppt) и удельным весом (SG). Вводите в любое поле.';

  @override
  String get specificGravity => 'Удельный вес';

  @override
  String get referencePoints => 'Опорные значения';

  @override
  String get refSeawater => '• Природная морская вода ≈ 35 ppt ≈ 1,0264 SG';

  @override
  String get refReefTarget =>
      '• Типичная цель для рифа ≈ 35 ppt (1,025–1,027 SG)';

  @override
  String get refFormulaNote =>
      'SG приведён к 25 °C. Перевод — линейная аппроксимация: SG = 1 + ppt × 0,0264/35.';

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
      'Текущая доза удерживает элемент стабильным — оставьте как есть.';

  @override
  String get doseCalcIncrease =>
      'Увеличьте дозу, чтобы удержать элемент стабильным.';

  @override
  String get doseCalcDecrease =>
      'Дозу можно снизить и всё равно удержать элемент стабильным.';

  @override
  String get doseCalcOverdosing =>
      'Элемент растёт — снизьте или приостановите дозирование.';

  @override
  String get doseCalcNoDoseNeeded =>
      'Ничего не дозируется, и этот элемент не падает — дозирование не требуется.';

  @override
  String get doseCalcNeedsPotency =>
      'Укажите концентрацию добавки, чтобы получить рекомендацию по дозе.';

  @override
  String get doseCalcInsufficient =>
      'Для расчёта добавьте не менее двух измерений в разные дни и объём аквариума.';

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
    return 'Достигнет зоны внимания через ~$days дн';
  }

  @override
  String trendRedInDays(int days) {
    return 'Достигнет критической зоны через ~$days дн';
  }

  @override
  String trendChipAmber(int days) {
    return 'Внимание ~$days дн';
  }

  @override
  String trendChipRed(int days) {
    return 'Действие ~$days дн';
  }

  @override
  String trendBackInRangeDays(int days) {
    return 'Восстанавливается — вернётся в диапазон через ~$days дн';
  }

  @override
  String trendChipRecovering(int days) {
    return 'Восстановление ~$days дн';
  }

  @override
  String get trendHorizon => 'Горизонт оповещения';

  @override
  String get trendHorizonSubtitle =>
      'Отмечать параметр, только если он выйдет за пределы в течение этого срока';

  @override
  String trendHorizonDays(int days) {
    return '$days дн';
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
  String get setupFishOnly => 'Только рыбы / FOWLR';

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
  String get paramOrp => 'ORP';

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
  String get microSectionMajor => 'Основные элементы';

  @override
  String get microSectionTrace => 'Следовые элементы';

  @override
  String get microSectionContaminants => 'Загрязнители';

  @override
  String get microNotMeasured => 'Не измерялось';

  @override
  String get microEmptyHint =>
      'Отслеживайте микроэлементы по домашним тестам или ICP-анализам.';

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
  String get microChipHobby => 'Домашние тесты';

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
  String get microViewNone =>
      'Пока нет своих наборов. Набор показывает только те элементы, которые измеряет ваша лаборатория.';

  @override
  String get microViewNameHint => 'напр. Панель моей лаборатории';

  @override
  String get microViewNeedElement => 'Выберите хотя бы один элемент.';

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
  String get icpImportTitle => 'Импорт ICP-отчёта';

  @override
  String get icpImportFormatHint => 'Выберите формат экспортированного файла.';

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
      'Заполнено датой анализа из отчёта. Измените на день, когда вы взяли пробу воды.';

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
  String get helpTemperature =>
      'Температура воды. Стабильность важнее точного значения.';

  @override
  String get helpSalinity => 'Удельный вес. ~1,026 SG ≈ 35 ppt.';

  @override
  String get helpAlkalinity =>
      'Карбонатная жёсткость. Поддерживайте стабильной — избегайте скачков.';

  @override
  String get helpNitrate =>
      'Питательное вещество. Кораллам нужно немного; избыток питает водоросли.';

  @override
  String get helpAmmonia =>
      'Токсичен. В запущенном аквариуме должен быть практически нулевым.';

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
  String healthScoreOf(int score) {
    return '$score из 100';
  }

  @override
  String get dashboardSection => 'Панель';

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
      'Во время дозирования каждого препарата';

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
    return '$count дн';
  }

  @override
  String get cadenceCustom => 'Свой';

  @override
  String get customDaysLabel => 'Дней';

  @override
  String get remindMe => 'Напоминать';

  @override
  String get remindMeNeedsTime =>
      'Укажите время дозирования, чтобы включить напоминания';

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
  String get taskTitleRequired => 'Введите название';

  @override
  String get repeatLabel => 'Повтор';

  @override
  String get oneOff => 'Однократно';

  @override
  String get dueDateLabel => 'Срок';

  @override
  String get dueDateRequired => 'Выберите срок';

  @override
  String get dueToday => 'Сегодня';

  @override
  String dueInDaysN(int count) {
    return 'Через $count дн';
  }

  @override
  String overdueDaysN(int count) {
    return 'Просрочено на $count дн';
  }

  @override
  String get markDone => 'Готово';

  @override
  String get taskMarkedDone => 'Отмечено выполненным';

  @override
  String get taskDeleted => 'Задача удалена';

  @override
  String get scheduleEmptyBody =>
      'Пока нет задач обслуживания. Запланируйте подмены воды или свои задачи, чтобы видеть сроки и получать напоминания.';

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
  String get invalidInterval => 'Введите целое число (не менее 1).';

  @override
  String get invalidMonthDay => 'Введите день от 1 до 31.';

  @override
  String get weekdaysRequired => 'Выберите хотя бы один день.';

  @override
  String everyWeeksN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Каждые $n недели',
      many: 'Каждые $n недель',
      few: 'Каждые $n недели',
      one: 'Каждую $n-ю неделю',
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
      one: 'Каждый $n-й месяц',
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
  String get roCustomStage => 'Свой элемент';

  @override
  String get roAddStage => 'Добавить элемент';

  @override
  String get roEditStage => 'Изменить элемент';

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
      'Выключите, если в вашей установке нет этой ступени';

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
  String get roDeleteStageTitle => 'Удалить элемент?';

  @override
  String get roDeleteStageBody =>
      'Элемент и история его замен будут удалены. Это нельзя отменить.';

  @override
  String get roEmptyBody =>
      'Нет элементов. Добавьте фильтры вашей установки кнопкой +.';

  @override
  String get roSetupPrompt => 'Следите за заменой фильтров и мембраны';

  @override
  String get roUnitToggleSubtitle =>
      'Показывать на вкладке «Действия», с напоминаниями о замене фильтров';

  @override
  String get roAllOk => 'Все элементы в порядке';

  @override
  String get notifRoTitle => 'Замените фильтры обратного осмоса';
}
