import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Not a test — a seeding helper run via `flutter test` to produce a fully
/// migrated (current-schema) `reeftracker.sqlite` populated with demo data,
/// which is then `run-as`-pushed into the emulator's app_flutter/ dir.
///
/// Output path can be overridden with `--dart-define=SEED_OUT=<path>`;
/// defaults to C:/Android/reefbuild/seed.sqlite (a non-OneDrive dir).
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed.sqlite',
);

void main() {
  test('generate sample database', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));

    // A display tank with a realistic volume so the calculator has inputs.
    final tank = await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
      volumeLiters: 300,
      startDate: daysAgo(400),
      vendor: 'Red Sea',
      model: 'Reefer 350',
    );

    // Alkalinity gently declining over ~4 weeks (dosing can't quite keep up).
    // Two readings carry notes so the chart note markers (U5b/U13) have data.
    const alkSeries = [8.6, 8.5, 8.3, 8.2, 8.0, 7.9, 7.7, 7.6];
    const alkNotes = <int, String>{
      2: 'Salifert test kit, fresh reagents',
      6:
          'Retested twice — corals look pale, raising the dose tomorrow. '
          'Long note to exercise the tooltip truncation behavior on device.',
    };
    for (var i = 0; i < alkSeries.length; i++) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: alkSeries[i],
        takenAt: daysAgo((alkSeries.length - 1 - i) * 4),
        note: alkNotes[i],
      );
    }
    // One of each action mid-series so all three marker styles + the legend
    // (U6) render on the alkalinity graph.
    await db.insertWaterChange(
      tankId: tank,
      changedAt: daysAgo(10),
      amountLiters: 30,
    );
    await db.insertCarbonChange(
      tankId: tank,
      changedAt: daysAgo(18),
      grams: 60,
    );
    await db.insertEquipmentCleaning(
      tankId: tank,
      cleanedAt: daysAgo(5),
      note: 'Skimmer cup',
    );
    // A couple of calcium points too.
    for (final (i, v) in [430.0, 425.0, 420.0].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'calcium',
        value: v,
        takenAt: daysAgo((2 - i) * 7),
      );
    }
    // Nitrate coming down after a spike: above greenHigh (10 in the mixed
    // preset) but falling ~1.5/day → back in range in ~3 d. Exercises the
    // positive "Recovering" trend chip/card (U15).
    for (final (i, v) in [22.0, 20.5, 19.0, 17.5, 16.0, 14.5].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'nitrate',
        value: v,
        takenAt: daysAgo(5 - i),
      );
    }
    // Environment series (temperature/pH/salinity) so the Environment section
    // and the derived free-ammonia calc have inputs.
    for (final (i, v) in [25.8, 26.0, 26.1].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'temperature',
        value: v,
        takenAt: daysAgo((2 - i) * 2),
      );
    }
    for (final (i, v) in [8.15, 8.20, 8.25].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'ph',
        value: v,
        takenAt: daysAgo((2 - i) * 2),
      );
    }
    await db.insertReading(
      tankId: tank,
      paramKey: 'salinity',
      value: 1.0264, // 35 ppt at 25 °C
      takenAt: daysAgo(2),
    );
    // A minor ammonia event after adding livestock: 0.30 ppm total. At pH 8.25
    // / 26 °C / 35 ppt ≈ 9 % is the toxic un-ionized NH₃ form (~0.027 ppm) —
    // amber on the free-ammonia gauge, exercising the derived-value card.
    await db.insertReading(
      tankId: tank,
      paramKey: 'ammonia',
      value: 0.30,
      takenAt: daysAgo(1),
      note: 'Added two new fish yesterday',
    );

    // --- Microelements (U17) -------------------------------------------------
    // One full ICP batch a month ago: mostly natural-seawater values, copper
    // slightly elevated (amber) and lead contaminated (red) so the summary
    // tile shows "2 out of range" in red. Iodine was low (amber) on the ICP
    // and a fresh hobby-kit retest brings it back green — the panel then
    // shows a recent "last measured" date.
    const icp = <String, double>{
      'sodium': 10600,
      'potassium': 412,
      'sulfur': 910,
      'boron': 4.3,
      'bromine': 63,
      'silicon': 0.09,
      'strontium': 7.8,
      'iodine': 0.045,
      'iron': 0.003,
      'zinc': 0.006,
      'copper': 0.004,
      'lithium': 0.19,
      'barium': 0.012,
      'molybdenum': 0.011,
      'aluminium': 0.006,
      'lead': 0.012,
    };
    for (final key in icp.keys) {
      await db.addTrackedParameter(tank, key, SetupType.mixed);
    }
    await db.insertReadingGroup(
      tankId: tank,
      takenAt: daysAgo(32),
      note: 'Fauna Marin Reef ICP #4711',
      values: [for (final e in icp.entries) (paramKey: e.key, value: e.value)],
    );
    await db.insertReadingGroup(
      tankId: tank,
      takenAt: daysAgo(3),
      values: const [(paramKey: 'iodine', value: 0.06)],
    );
    // A potassium series drifting up out of the green zone (380–420) so its
    // graph shows the line crossing green → amber with all three bands.
    for (final (i, v) in [396.0, 412.0, 431.0].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'potassium',
        value: v,
        takenAt: daysAgo((2 - i) * 12),
      );
    }

    // --- Dosing plan with real history --------------------------------------
    // Alk: an OLD segment (5 ml/day, 40d ago → superseded 12d ago) plus the
    // CURRENT active segment (7 ml/day since 12d ago). This makes the dose
    // calculator's "dose changed within window" warning fire.
    final oldAlkId = await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tank),
        productKey: const Value('redsea.foundation_b'),
        vendor: const Value('Red Sea'),
        program: const Value('Reef Care Program'),
        product: const Value('Reef Foundation B (KH/Alk)'),
        elementKey: const Value('alkalinity'),
        amount: const Value(5),
        amountUnit: Value(DoseUnit.ml.name),
        basis: Value(DoseBasis.perDay.name),
        frequency: Value(DoseFrequency.daily.name),
        startedAt: Value(daysAgo(40)),
      ),
    );
    // Backdate the ended segment's boundary explicitly.
    await (db.update(
      db.dosingEntries,
    )..where((d) => d.id.equals(oldAlkId))).write(
      DosingEntriesCompanion(
        state: Value(DosingState.ended.name),
        endedAt: Value(daysAgo(12)),
      ),
    );
    final newAlkId = await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tank),
        productKey: const Value('redsea.foundation_b'),
        vendor: const Value('Red Sea'),
        program: const Value('Reef Care Program'),
        product: const Value('Reef Foundation B (KH/Alk)'),
        elementKey: const Value('alkalinity'),
        amount: const Value(7),
        amountUnit: Value(DoseUnit.ml.name),
        basis: Value(DoseBasis.perDay.name),
        frequency: Value(DoseFrequency.daily.name),
      ),
    );
    await (db.update(db.dosingEntries)..where((d) => d.id.equals(newAlkId)))
        .write(DosingEntriesCompanion(startedAt: Value(daysAgo(12))));

    // Calcium: a single active supplement, no history yet.
    await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tank),
        productKey: const Value('redsea.foundation_a'),
        vendor: const Value('Red Sea'),
        program: const Value('Reef Care Program'),
        product: const Value('Reef Foundation A (Ca)'),
        elementKey: const Value('calcium'),
        amount: const Value(6),
        amountUnit: Value(DoseUnit.ml.name),
        basis: Value(DoseBasis.perDay.name),
        frequency: Value(DoseFrequency.daily.name),
      ),
    );

    // A stopped trace supplement (soft-ended) — history only, hidden from list.
    final traceId = await db.insertDosingEntry(
      DosingEntriesCompanion(
        tankId: Value(tank),
        vendor: const Value('Custom'),
        product: const Value('Vitamin C (occasional)'),
        note: const Value('Stopped during algae outbreak'),
        startedAt: Value(daysAgo(60)),
      ),
    );
    await db.stopDosingEntry(traceId);
    await (db.update(db.dosingEntries)..where((d) => d.id.equals(traceId)))
        .write(DosingEntriesCompanion(endedAt: Value(daysAgo(20))));

    // --- Reminders & maintenance schedule (U1/U2/U12) ------------------------
    // All three categories pre-enabled so a device smoke can check that the
    // scheduler registers OS alarms right after first launch.
    final settings = AppSettings(db);
    // Skip the first-run tour so a device smoke can navigate immediately.
    await settings.setTourSeen(true);
    await settings.setRemindersTesting(true);
    await settings.setRemindersDosing(true);
    await settings.setRemindersMaintenance(true);
    // Alkalinity tested every 4 days (latest reading is "today" per the series
    // above → next testing reminder in 4 days).
    final alkParam = (await db.getTrackedParameters(
      tank,
    )).firstWhere((p) => p.paramKey == 'alkalinity');
    await db.setTestCadence(alkParam.id, 4);
    // The active Alk supplement reminds at its dose time.
    await (db.update(
      db.dosingEntries,
    )..where((d) => d.id.equals(newAlkId))).write(
      const DosingEntriesCompanion(
        doseTime: Value('21:00'),
        remindEnabled: Value(true),
      ),
    );
    // Maintenance plans: a recurring typed one (water change every 14 d, last
    // done 10 d ago → due in 4 d), a recurring custom task, and an overdue
    // one-off so the due chips show all states.
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
    await db.markMaintenanceDone(skimmer, daysAgo(6));
    await db.insertMaintenanceSchedule(
      tankId: tank,
      title: 'Replace RO membrane',
      scheduledAt: daysAgo(2),
      note: 'Cartridge is in the cabinet',
    );

    // --- RO unit (U16) -------------------------------------------------------
    // The default 4-stage set with realistic anchors: sediment green, carbon
    // block inside the amber warning window, membrane long overdue (drives
    // the red equipment-alert card on the Actions tab, REDESIGN #11), DI
    // resin with no replacement recorded yet.
    await db.seedDefaultRoStages();
    final roStages = await db.watchRoStages().first;
    final lastByType = <String, DateTime>{
      'sediment': daysAgo(30), // 90 d lifespan → due in 60 d
      'carbonBlock': daysAgo(170), // 180 d lifespan → due in 10 d (amber)
      'membrane': daysAgo(800), // 730 d lifespan → 70 d overdue (red)
    };
    for (final stage in roStages) {
      final replacedAt = lastByType[stage.stageType];
      if (replacedAt == null) continue;
      await db.insertRoReplacement(stageId: stage.id, replacedAt: replacedAt);
    }

    await db.close();

    // Sanity: the file exists and holds the active plan we expect.
    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path}');
  });
}
