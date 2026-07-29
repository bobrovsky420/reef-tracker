import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/setup_type.dart';

/// Not a test — a seeding helper run via `flutter test` to produce a **pre-v28**
/// `reeftracker.sqlite`, i.e. a database as it existed before the parameter
/// bounds moved out of `tracked_parameters` into `parameter_overrides`.
///
/// Pushed into the emulator's app_flutter/ dir, it lets the real app perform the
/// v27 → v28 upgrade on launch, so the destructive step (hand-tuned bounds are
/// dropped, every parameter falls back to the live defaults) can be watched in
/// the UI rather than only asserted in migration_test.dart.
///
/// Output path can be overridden with `--dart-define=SEED_OUT=<path>`;
/// defaults to C:/Android/reefbuild/seed_v27.sqlite (a non-OneDrive dir).
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed_v27.sqlite',
);

void main() {
  test('generate pre-v28 database with hand-tuned bounds', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));

    final tank = await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
      volumeLiters: 300,
      startDate: daysAgo(400),
      vendor: 'Red Sea',
      model: 'Reefer 350',
    );

    // Enough history that the dashboard tiles and trend cards have something to
    // draw against the (post-upgrade) default bands.
    const alkSeries = [8.6, 8.5, 8.3, 8.2, 8.0, 7.9, 7.7, 7.6];
    for (var i = 0; i < alkSeries.length; i++) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: alkSeries[i],
        takenAt: daysAgo((alkSeries.length - 1 - i) * 4),
      );
    }
    for (final (i, v) in [430.0, 425.0, 420.0].indexed) {
      await db.insertReading(
        tankId: tank,
        paramKey: 'calcium',
        value: v,
        takenAt: daysAgo((2 - i) * 7),
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

    final settings = AppSettings(db);
    await settings.setTourSeen(true);

    // --- Rewind the schema to v27 -------------------------------------------
    // Same reconstruction migration_test.dart uses: put the five dropped
    // columns back, give alkalinity and calcium hand-tuned values a real user
    // would have had, and remove the table v28 introduces.
    for (final col in const [
      'amber_low',
      'green_low',
      'green_high',
      'amber_high',
      'target_value',
    ]) {
      await db.customStatement(
        'ALTER TABLE tracked_parameters ADD COLUMN $col REAL',
      );
    }
    // Deliberately eccentric bounds: nothing like the mixed preset, so after the
    // upgrade it is obvious on screen whether they survived or were reset.
    await db.customStatement(
      'UPDATE tracked_parameters SET amber_low = 6.0, green_low = 6.5, '
      "green_high = 7.0, amber_high = 7.5, target_value = 6.8 "
      "WHERE param_key = 'alkalinity'",
    );
    await db.customStatement(
      'UPDATE tracked_parameters SET amber_low = 500, green_low = 520, '
      "green_high = 560, amber_high = 580, target_value = 540 "
      "WHERE param_key = 'calcium'",
    );
    await db.customStatement('DROP TABLE IF EXISTS parameter_overrides');
    await db.customStatement('PRAGMA user_version = 27');

    await db.close();

    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path}');
  });
}
