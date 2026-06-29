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
  String get apply => 'Применить';

  @override
  String get change => 'Изменить';

  @override
  String errorWith(Object message) {
    return 'Ошибка: $message';
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
  String get edit => 'Изменить';

  @override
  String deleteTankTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteTankBody =>
      'Это навсегда удалит аквариум и все его измерения.';

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
  String get noteOptional => 'Заметка (необязательно)';

  @override
  String get saveReadings => 'Сохранить измерения';

  @override
  String invalidNumberFor(Object name) {
    return 'Неверное число для $name';
  }

  @override
  String get enterAtLeastOneValue => 'Введите хотя бы одно значение.';

  @override
  String savedReadings(int count) {
    return 'Сохранено измерений: $count.';
  }

  @override
  String get noTrackedToRecord => 'Нет отслеживаемых параметров для записи.';

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
  String get deleteMeasurementTitle => 'Удалить измерение?';

  @override
  String get deleteMeasurementBody =>
      'Это безвозвратно удалит данное значение.';

  @override
  String get deleteTogetherTitle => 'Удалить измерение';

  @override
  String deleteTogetherBody(int count) {
    return 'Это значение было введено вместе с ещё $count измерениями. Удалить только это значение или все значения, введённые вместе?';
  }

  @override
  String get deleteOnlyThis => 'Только это значение';

  @override
  String get deleteAllTogether => 'Все вместе';

  @override
  String get editTogetherTitle => 'Изменить время измерения';

  @override
  String editTogetherBody(int count) {
    return 'Это значение было введено вместе с ещё $count измерениями. Изменить время только для этого значения или для всех значений, введённых вместе?';
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
  String get deleteWaterChangeTitle => 'Удалить подмену воды?';

  @override
  String get deleteWaterChangeBody =>
      'Это безвозвратно удалит эту подмену воды.';

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
  String get deleteCarbonChangeTitle => 'Удалить замену угля?';

  @override
  String get deleteCarbonChangeBody =>
      'Это безвозвратно удалит эту замену угля.';

  @override
  String get equipmentCleaning => 'Чистка оборудования';

  @override
  String get recordEquipmentCleaning => 'Записать чистку оборудования';

  @override
  String get deleteEquipmentCleaningTitle => 'Удалить чистку оборудования?';

  @override
  String get deleteEquipmentCleaningBody =>
      'Это безвозвратно удалит эту чистку оборудования.';

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
  String get deleteDosingTitle => 'Удалить добавку?';

  @override
  String get deleteDosingBody => 'Это удалит эту добавку из плана дозирования.';

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
  String dosingEveryDaysN(Object n) {
    return 'Каждые $n дн.';
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
  String get backupExport => 'Экспортировать копию';

  @override
  String get backupExportSubtitle =>
      'Сохранить все аквариумы и измерения в файл';

  @override
  String get backupImport => 'Восстановить из копии';

  @override
  String get backupImportSubtitle =>
      'Заменить все данные файлом резервной копии';

  @override
  String get backupRestoreConfirmTitle => 'Восстановить копию?';

  @override
  String get backupRestoreConfirmBody =>
      'Все текущие аквариумы, параметры и измерения будут заменены содержимым файла резервной копии. Это действие нельзя отменить.';

  @override
  String get restore => 'Восстановить';

  @override
  String get backupRestored => 'Резервная копия восстановлена';

  @override
  String get backupExportFailed => 'Не удалось экспортировать копию';

  @override
  String get backupImportFailed => 'Не удалось восстановить копию';

  @override
  String get backupInvalidFile =>
      'Этот файл не является корректной резервной копией ReefTracker';

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
  String doseCalcReadings(Object count) {
    return 'Измерений в периоде: $count';
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
  String get trendWindowSubtitle =>
      'Сколько последних измерений определяют тренд';

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
  String get paramPotassium => 'Калий';

  @override
  String get paramStrontium => 'Стронций';

  @override
  String get paramIodine => 'Йод';

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
}
