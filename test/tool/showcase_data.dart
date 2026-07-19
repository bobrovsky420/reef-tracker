// Showcase dataset shared by the emulator seeder (`seed_showcase.dart`) and
// the store-screenshot harness (`integration_test/screenshots_test.dart`).
//
// Unlike `seed_sample_data.dart` (a QA dataset that deliberately provokes
// amber/red states), this one paints a realistic, well-kept mixed reef:
// ~12 weeks of measurement history, a dosing plan with one adjustment in its
// history, a full ICP batch, a healthy RO unit and an active maintenance
// schedule. Values are hardcoded so the output is deterministic.
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Wipes all rows and seeds the showcase dataset. Idempotent, so the
/// screenshot harness can run repeatedly against the same device DB.
Future<void> seedShowcaseData(AppDatabase db, {DateTime? now}) async {
  final today = now ?? DateTime.now();
  DateTime at(int daysAgo, [int hour = 19, int minute = 15]) {
    final d = today.subtract(Duration(days: daysAgo));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  // --- Wipe (children before parents, mirrors restoreFromBackup) ----------
  await db.transaction(() async {
    await db.delete(db.readings).go();
    await db.delete(db.waterChanges).go();
    await db.delete(db.carbonChanges).go();
    await db.delete(db.equipmentCleanings).go();
    await db.delete(db.ratioVisibilities).go();
    await db.delete(db.dosingEntries).go();
    await db.delete(db.manualDoses).go();
    await db.delete(db.readingTemplates).go();
    await db.delete(db.microViews).go();
    await db.delete(db.maintenanceSchedules).go();
    await db.delete(db.roStageReplacements).go();
    await db.delete(db.roStages).go();
    await db.delete(db.trackedParameters).go();
    await db.delete(db.settings).go();
    await db.delete(db.tanks).go();
  });

  // --- Tank ---------------------------------------------------------------
  final tank = await db.createTankWithPreset(
    name: 'Reef Display',
    type: SetupType.mixed,
    volumeLiters: 400,
    startDate: at(700),
    vendor: 'Red Sea',
    model: 'Reefer 425 G2',
  );

  // --- Core chemistry, ~12 weeks ------------------------------------------
  // Alkalinity every 3 days: stable around 8.4 dKH with a gentle dip that a
  // dose adjustment (21 d ago) corrects — a nice, believable line.
  const alk = [
    8.3, 8.4, 8.5, 8.4, 8.3, 8.2, 8.3, 8.4, 8.6, 8.5, //
    8.4, 8.3, 8.2, 8.2, 8.3, 8.5, 8.6, 8.5, 8.4, 8.3, //
    8.2, 8.3, 8.4, 8.5, 8.4, 8.4, 8.3, 8.4,
  ];
  const alkNotes = <int, String>{
    20: 'Drifting down — raised Foundation B to 25 ml/day',
    26: 'Great polyp extension on the acros',
  };
  for (var i = 0; i < alk.length; i++) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'alkalinity',
      value: alk[i],
      takenAt: at((alk.length - 1 - i) * 3 + 1, 20, 40),
      note: alkNotes[i],
    );
  }

  // Calcium weekly.
  const ca = <double>[420, 425, 430, 425, 420, 415, 420, 430, 435, 430, 425, 430];
  for (final (i, v) in ca.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'calcium',
      value: v,
      takenAt: at((ca.length - 1 - i) * 7 + 2),
    );
  }

  // Magnesium every two weeks.
  const mg = <double>[1350, 1340, 1330, 1320, 1340, 1350];
  for (final (i, v) in mg.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'magnesium',
      value: v,
      takenAt: at((mg.length - 1 - i) * 14 + 3),
    );
  }

  // Nutrients weekly: both trending down after a summer peak — starts a touch
  // above the green band, ends comfortably inside it.
  const no3 = [12.5, 12.0, 11.0, 10.5, 9.5, 9.0, 8.0, 7.5, 7.0, 6.5, 6.0, 5.5];
  const no3Notes = <int, String>{
    0: 'Started weekly 10% water changes',
    11: 'Nutrients finally dialed in',
  };
  for (final (i, v) in no3.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'nitrate',
      value: v,
      takenAt: at((no3.length - 1 - i) * 7 + 1),
      note: no3Notes[i],
    );
  }
  const po4 = [0.1, 0.09, 0.09, 0.08, 0.07, 0.07, 0.06, 0.06, 0.05, 0.05, 0.04, 0.05];
  for (final (i, v) in po4.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'phosphate',
      value: v,
      takenAt: at((po4.length - 1 - i) * 7 + 1),
    );
  }

  // --- Environment, last two weeks ----------------------------------------
  const temp = [25.7, 25.9, 26.1, 25.9, 25.8, 25.9, 25.8, 25.8];
  for (final (i, v) in temp.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'temperature',
      value: v,
      takenAt: at((temp.length - 1 - i) * 2, 18, 30),
    );
  }
  const ph = [8.1, 8.15, 8.2, 8.15, 8.1, 8.2, 8.25, 8.2];
  for (final (i, v) in ph.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'ph',
      value: v,
      takenAt: at((ph.length - 1 - i) * 2, 18, 30),
    );
  }
  const sal = [1.0258, 1.026, 1.0262, 1.0259, 1.0258, 1.0257];
  for (final (i, v) in sal.indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'salinity',
      value: v,
      takenAt: at((sal.length - 1 - i) * 7),
    );
  }
  // Occasional ammonia/nitrite checks (a mature tank reads ~zero) so their
  // gauges aren't empty on the wider tablet layouts.
  await db.insertReading(
    tankId: tank,
    paramKey: 'ammonia',
    value: 0.01,
    takenAt: at(2, 18, 45),
  );
  await db.insertReading(
    tankId: tank,
    paramKey: 'nitrite',
    value: 0.01,
    takenAt: at(2, 18, 45),
  );

  // --- Actions log ---------------------------------------------------------
  for (final d in [3, 17, 31, 45, 59, 73]) {
    await db.insertWaterChange(tankId: tank, changedAt: at(d, 17), amountLiters: 40);
  }
  for (final d in [12, 42, 72]) {
    await db.insertCarbonChange(tankId: tank, changedAt: at(d, 17, 45), grams: 60);
  }
  for (final d in [2, 9, 16, 23]) {
    await db.insertEquipmentCleaning(
      tankId: tank,
      cleanedAt: at(d, 17, 30),
      note: 'Skimmer cup',
    );
  }
  await db.insertEquipmentCleaning(
    tankId: tank,
    cleanedAt: at(20, 16),
    note: 'Return pump and wavemakers',
  );

  // --- Microelements: one full ICP a month ago, all healthy except iodine
  // slightly low — corrected by dosing and confirmed by a recent retest.
  const icp = <String, double>{
    'sodium': 10550,
    'potassium': 402,
    'sulfur': 900,
    'boron': 4.4,
    'bromine': 66,
    'silicon': 0.06,
    'strontium': 8.1,
    'iodine': 0.048,
    'iron': 0.002,
    'zinc': 0.004,
    'copper': 0.001,
    'lithium': 0.17,
    'barium': 0.008,
    'molybdenum': 0.01,
    'aluminium': 0.003,
    'lead': 0.001,
  };
  for (final key in icp.keys) {
    await db.addTrackedParameter(tank, key, SetupType.mixed);
  }
  await db.insertReadingGroup(
    tankId: tank,
    takenAt: at(30, 12),
    note: 'Fauna Marin Reef ICP #8231',
    values: [for (final e in icp.entries) (paramKey: e.key, value: e.value)],
  );
  await db.insertReadingGroup(
    tankId: tank,
    takenAt: at(4, 18),
    values: const [(paramKey: 'iodine', value: 0.062)],
  );
  // A short potassium series so its graph has a line, not a single dot.
  for (final (i, v) in const <double>[398, 404, 402].indexed) {
    await db.insertReading(
      tankId: tank,
      paramKey: 'potassium',
      value: v,
      takenAt: at((2 - i) * 12 + 2),
    );
  }

  // --- Dosing plan with history --------------------------------------------
  // Alkalinity: 22 ml/day for two months, raised to 25 ml/day three weeks ago
  // (matches the note on the alkalinity series).
  final oldAlk = await db.insertDosingEntry(
    DosingEntriesCompanion(
      tankId: Value(tank),
      productKey: const Value('redsea.foundation_b'),
      vendor: const Value('Red Sea'),
      program: const Value('Reef Care Program'),
      product: const Value('Reef Foundation B (KH/Alk)'),
      elementKey: const Value('alkalinity'),
      amount: const Value(22),
      amountUnit: Value(DoseUnit.ml.name),
      basis: Value(DoseBasis.perDay.name),
      frequency: Value(DoseFrequency.daily.name),
      startedAt: Value(at(90)),
    ),
  );
  await (db.update(db.dosingEntries)..where((d) => d.id.equals(oldAlk))).write(
    DosingEntriesCompanion(
      state: Value(DosingState.ended.name),
      endedAt: Value(at(21)),
    ),
  );
  final newAlk = await db.insertDosingEntry(
    DosingEntriesCompanion(
      tankId: Value(tank),
      productKey: const Value('redsea.foundation_b'),
      vendor: const Value('Red Sea'),
      program: const Value('Reef Care Program'),
      product: const Value('Reef Foundation B (KH/Alk)'),
      elementKey: const Value('alkalinity'),
      amount: const Value(25),
      amountUnit: Value(DoseUnit.ml.name),
      basis: Value(DoseBasis.perDay.name),
      frequency: Value(DoseFrequency.daily.name),
      doseTime: const Value('21:00'),
      remindEnabled: const Value(true),
    ),
  );
  await (db.update(db.dosingEntries)..where((d) => d.id.equals(newAlk)))
      .write(DosingEntriesCompanion(startedAt: Value(at(21))));

  // Calcium and magnesium: steady single segments.
  final caDose = await db.insertDosingEntry(
    DosingEntriesCompanion(
      tankId: Value(tank),
      productKey: const Value('redsea.foundation_a'),
      vendor: const Value('Red Sea'),
      program: const Value('Reef Care Program'),
      product: const Value('Reef Foundation A (Ca)'),
      elementKey: const Value('calcium'),
      amount: const Value(15),
      amountUnit: Value(DoseUnit.ml.name),
      basis: Value(DoseBasis.perDay.name),
      frequency: Value(DoseFrequency.daily.name),
    ),
  );
  await (db.update(db.dosingEntries)..where((d) => d.id.equals(caDose)))
      .write(DosingEntriesCompanion(startedAt: Value(at(90))));
  final mgDose = await db.insertDosingEntry(
    DosingEntriesCompanion(
      tankId: Value(tank),
      productKey: const Value('redsea.foundation_c'),
      vendor: const Value('Red Sea'),
      program: const Value('Reef Care Program'),
      product: const Value('Reef Foundation C (Mg)'),
      elementKey: const Value('magnesium'),
      amount: const Value(20),
      amountUnit: Value(DoseUnit.ml.name),
      basis: Value(DoseBasis.perDose.name),
      frequency: Value(DoseFrequency.weekly.name),
    ),
  );
  await (db.update(db.dosingEntries)..where((d) => d.id.equals(mgDose)))
      .write(DosingEntriesCompanion(startedAt: Value(at(60))));

  // One ended supplement so the dosing history has a closed chapter.
  final aminos = await db.insertDosingEntry(
    DosingEntriesCompanion(
      tankId: Value(tank),
      vendor: const Value('Custom'),
      product: const Value('Amino acids (coral food)'),
      note: const Value('Paused while nutrients were high'),
      startedAt: Value(at(120)),
    ),
  );
  await db.stopDosingEntry(aminos);
  await (db.update(db.dosingEntries)..where((d) => d.id.equals(aminos)))
      .write(DosingEntriesCompanion(endedAt: Value(at(30))));

  // --- RO unit: default 4-stage set, all comfortably within lifespan -------
  await db.seedDefaultRoStages();
  final roStages = await db.watchRoStages().first;
  const roReplacedDaysAgo = <String, int>{
    'sediment': 25,
    'carbonBlock': 55,
    'membrane': 300,
    'diResin': 40,
  };
  for (final stage in roStages) {
    final daysAgo = roReplacedDaysAgo[stage.stageType];
    if (daysAgo == null) continue;
    await db.insertRoReplacement(stageId: stage.id, replacedAt: at(daysAgo));
  }

  // --- Maintenance schedule & reminders ------------------------------------
  final settings = AppSettings(db);
  await settings.setTourSeen(true);
  await settings.setRemindersTesting(true);
  await settings.setRemindersDosing(true);
  await settings.setRemindersMaintenance(true);

  final tracked = await db.getTrackedParameters(tank);
  Future<void> cadence(String key, int days) async {
    final p = tracked.firstWhere((p) => p.paramKey == key);
    await db.setTestCadence(p.id, days);
  }

  await cadence('alkalinity', 3);
  await cadence('calcium', 7);
  await cadence('nitrate', 7);

  // Recurring water change anchored to the log (last one 3 d ago).
  await db.insertMaintenanceSchedule(
    tankId: tank,
    actionType: 'waterChange',
    cadenceDays: 14,
  );
  final skimmer = await db.insertMaintenanceSchedule(
    tankId: tank,
    title: 'Clean skimmer cup',
    cadenceDays: 7,
  );
  await db.markMaintenanceDone(skimmer, at(2));
  await db.insertMaintenanceSchedule(
    tankId: tank,
    title: 'Replace filter socks',
    scheduledAt: at(-4, 10),
    note: 'New socks are in the cabinet',
  );
}
