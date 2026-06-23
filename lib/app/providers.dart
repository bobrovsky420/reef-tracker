import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

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

/// Readings for a single parameter of the active tank (oldest first).
final paramReadingsProvider =
    StreamProvider.family<List<Reading>, String>((ref, paramKey) {
  final tank = ref.watch(activeTankProvider);
  if (tank == null) return Stream.value(const []);
  return ref.watch(dbProvider).watchParamReadings(tank.id, paramKey);
});
