import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
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
    const alkSeries = [8.6, 8.5, 8.3, 8.2, 8.0, 7.9, 7.7, 7.6];
    for (var i = 0; i < alkSeries.length; i++) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: alkSeries[i],
        takenAt: daysAgo((alkSeries.length - 1 - i) * 4),
      );
    }
    // A couple of calcium points too.
    for (final (i, v) in [430.0, 425.0, 420.0].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'calcium',
        value: v,
        takenAt: daysAgo((2 - i) * 7),
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

    await db.close();

    // Sanity: the file exists and holds the active plan we expect.
    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path}');
  });
}
