import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';

import 'showcase_data.dart';

/// Not a test — writes a fully migrated `seed.sqlite` holding the showcase
/// dataset (see `showcase_data.dart`), for `run-as`-pushing into the
/// emulator's app_flutter/ dir. Run explicitly:
///
///   flutter test test/tool/seed_showcase.dart
///
/// Output path can be overridden with `--dart-define=SEED_OUT=<path>`.
const _out = String.fromEnvironment(
  'SEED_OUT',
  defaultValue: r'C:\Android\reefbuild\seed.sqlite',
);

void main() {
  test('generate showcase database', () async {
    final file = File(_out);
    if (await file.exists()) await file.delete();
    await file.parent.create(recursive: true);

    final db = AppDatabase(NativeDatabase(file));
    await seedShowcaseData(db);
    await db.close();

    expect(await file.exists(), isTrue);
    // ignore: avoid_print
    print('SEED_WRITTEN=${file.path}');
  });
}
