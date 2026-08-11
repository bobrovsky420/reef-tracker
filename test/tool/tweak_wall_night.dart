import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';

/// Not a test — a verification helper (the `seed_wall.dart` pattern): flips a
/// pulled emulator database into "wall auto-start on + night window active
/// right now", so the cold-start redirect and the dim scrim can be looked at
/// on the emulator without fighting the time-picker dial.
///
///     flutter test test/tool/tweak_wall_night.dart --dart-define=DB=<path>
const _db = String.fromEnvironment(
  'DB',
  defaultValue: r'C:\Android\reefbuild\pull.sqlite',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arm wall auto-start + an always-active night window', () async {
    final db = AppDatabase(NativeDatabase(File(_db)));
    final settings = AppSettings(db);
    await settings.setWallAutoStart(true);
    await settings.setWallNightFrom(0); // 00:00
    await settings.setWallNightTo(23 * 60); // 23:00 — active all day
    await db.close();
    stdout.writeln('Tweaked $_db');
  });
}
