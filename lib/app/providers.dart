import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/database.dart';
import '../domain/units.dart';

const kTempUnitKey = 'temp_unit';
const kSalinityUnitKey = 'salinity_unit';
const kVolumeUnitKey = 'volume_unit';
const kLocaleKey = 'locale';
const kChartRangeKey = 'chart_range';
const kShowRatioPo4No3Key = 'show_ratio_po4_no3';
const kShowRatioMgCaKey = 'show_ratio_mg_ca';

/// The app's version + build number from the running package (e.g. "0.3.1+4"),
/// so the About box always reflects the actual installed build.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// The singleton app database.
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// All tanks, reactive.
final tanksProvider = StreamProvider<List<Tank>>(
  (ref) => ref.watch(dbProvider).watchTanks(),
);

/// The id of the currently selected tank (persisted in settings).
final activeTankIdProvider = StreamProvider<int?>(
  (ref) => ref.watch(dbProvider).watchActiveTankId(),
);

/// The currently selected tank, resolving the active id against the tank list.
/// Falls back to the first tank when none is explicitly selected.
final activeTankProvider = Provider<Tank?>((ref) {
  final tanks = ref.watch(tanksProvider).value ?? const [];
  if (tanks.isEmpty) return null;
  final activeId = ref.watch(activeTankIdProvider).value;
  for (final t in tanks) {
    if (t.id == activeId) return t;
  }
  return tanks.first;
});

/// Tracked parameters for the active tank.
final trackedParametersProvider =
    StreamProvider<List<TrackedParameter>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchTrackedParameters(tank.id);
});

/// All readings for the active tank (newest first).
final tankReadingsProvider = StreamProvider<List<Reading>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchReadingsForTank(tank.id);
});

/// Water changes for the active tank (newest first).
final waterChangesProvider = StreamProvider<List<WaterChange>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchWaterChanges(tank.id);
});

/// Activated-carbon changes for the active tank (newest first).
final carbonChangesProvider = StreamProvider<List<CarbonChange>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchCarbonChanges(tank.id);
});

/// Equipment cleanings for the active tank (newest first).
final equipmentCleaningsProvider =
    StreamProvider<List<EquipmentCleaning>>((ref) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchEquipmentCleanings(tank.id);
});

/// Readings for a single parameter of the active tank (oldest first).
final paramReadingsProvider =
    StreamProvider.family<List<Reading>, String>((ref, paramKey) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchParamReadings(tank.id, paramKey);
});

/// Preferred temperature display unit (default Celsius).
final tempUnitProvider = StreamProvider<TempUnit>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kTempUnitKey)
    .map((v) => TempUnit.fromName(v)));

/// Preferred salinity display unit (default ppt).
final salinityUnitProvider = StreamProvider<SalinityUnit>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kSalinityUnitKey)
    .map((v) => SalinityUnit.fromName(v)));

/// Preferred volume display unit (default litres).
final volumeUnitProvider = StreamProvider<VolumeUnit>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kVolumeUnitKey)
    .map((v) => VolumeUnit.fromName(v)));

/// Combined unit preferences, reactive to settings changes.
final unitPrefsProvider = Provider<UnitPrefs>((ref) {
  final temp = ref.watch(tempUnitProvider).value ?? TempUnit.celsius;
  final salinity = ref.watch(salinityUnitProvider).value ?? SalinityUnit.ppt;
  final volume = ref.watch(volumeUnitProvider).value ?? VolumeUnit.liters;
  return UnitPrefs(temp: temp, salinity: salinity, volume: volume);
});

/// Stored language code ('system' / 'en' / 'cs'), defaulting to 'system'.
final localeCodeProvider = StreamProvider<String>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kLocaleKey)
    .map((v) => v ?? 'system'));

/// The locale override for MaterialApp, or null to follow the system locale.
final localeProvider = Provider<Locale?>((ref) {
  final code = ref.watch(localeCodeProvider).value ?? 'system';
  return code == 'system' ? null : Locale(code);
});

/// The history-chart time range, stored as the range's label ('7d', '30d',
/// '90d', 'All'). Shared across every parameter graph. Defaults to '30d'.
final chartRangeProvider = StreamProvider<String>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kChartRangeKey)
    .map((v) => v ?? '30d'));

/// Whether the PO₄ : NO₃ ratio card is shown on the dashboard (default true).
final showRatioPo4No3Provider = StreamProvider<bool>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kShowRatioPo4No3Key)
    .map((v) => v != 'false'));

/// Whether the Mg : Ca ratio card is shown on the dashboard (default true).
final showRatioMgCaProvider = StreamProvider<bool>((ref) => ref
    .watch(dbProvider)
    .watchSetting(kShowRatioMgCaKey)
    .map((v) => v != 'false'));
