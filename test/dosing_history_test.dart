import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Dosing entries are effective-dated segments: editing a dose-affecting field
/// terminates the current segment and starts a new active one, stopping
/// soft-ends, and only active segments show in the plan / feed the calculator.
void main() {
  group('dosing history (in-memory)', () {
    late AppDatabase db;
    late int tankId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tankId =
          await db.createTankWithPreset(name: 'Reef', type: SetupType.mixed);
    });
    tearDown(() => db.close());

    Future<void> addAlk({double amount = 5}) => db.insertDosingEntry(
          DosingEntriesCompanion(
            tankId: Value(tankId),
            product: const Value('Alk'),
            elementKey: const Value('alkalinity'),
            amount: Value(amount),
            amountUnit: Value(DoseUnit.ml.name),
            basis: Value(DoseBasis.perDay.name),
          ),
        );

    test('insert stamps startedAt and an active state', () async {
      await addAlk();
      final row = (await db.getAllDosingEntries()).single;
      expect(row.state, DosingState.active.name);
      expect(row.startedAt, isNotNull);
      expect(row.endedAt, isNull);
    });

    test('supersede ends the old segment and starts a new active one in place',
        () async {
      await addAlk(amount: 5);
      final old = (await db.getAllDosingEntries()).single;

      await db.supersedeDosingEntry(
        old,
        DosingEntriesCompanion(
          product: const Value('Alk'),
          elementKey: const Value('alkalinity'),
          amount: const Value(7),
        ),
      );

      final all = await db.getAllDosingEntries();
      expect(all, hasLength(2));
      final ended = all.firstWhere((e) => e.id == old.id);
      final active = all.firstWhere((e) => e.id != old.id);
      expect(ended.state, DosingState.ended.name);
      expect(ended.endedAt, isNotNull);
      expect(active.state, DosingState.active.name);
      expect(active.amount, 7);
      // The replacement keeps its place in the list.
      expect(active.displayOrder, old.displayOrder);

      // Only the active segment is visible in the plan.
      final visible = await db.watchDosingEntries(tankId).first;
      expect(visible.map((e) => e.id), [active.id]);
    });

    test('stop soft-ends the entry but keeps it as history', () async {
      await addAlk();
      final e = (await db.getAllDosingEntries()).single;

      await db.stopDosingEntry(e.id);

      final row = (await db.getAllDosingEntries()).single; // still present
      expect(row.state, DosingState.ended.name);
      expect(row.endedAt, isNotNull);
      expect(await db.watchDosingEntries(tankId).first, isEmpty);
    });
  });

  group('dosing migration backfill (v11)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reeftracker-dosemig-');
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('backfills started_at from created_at for pre-v11 rows', () async {
      final file = File('${tempDir.path}/dose.sqlite');
      final created = DateTime(2026, 1, 2, 3, 4, 5);

      // Seed a current-schema db, then simulate a pre-v11 row (started_at NULL)
      // and rewind the recorded version so the next open replays the v11 step.
      final seed = AppDatabase(NativeDatabase(file));
      final id =
          await seed.createTankWithPreset(name: 'R', type: SetupType.mixed);
      await seed.insertDosingEntry(DosingEntriesCompanion(
        tankId: Value(id),
        product: const Value('Alk'),
        createdAt: Value(created),
      ));
      await seed.customStatement('UPDATE dosing_entries SET started_at = NULL');
      await seed.customStatement('PRAGMA user_version = 10');
      await seed.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      // Forcing a query runs beforeOpen -> onUpgrade(10, 11) -> the backfill.
      await db.customSelect('SELECT 1').get();

      final row = (await db.getAllDosingEntries()).single;
      expect(row.startedAt, created);
      expect(row.state, DosingState.active.name);
    });
  });
}
