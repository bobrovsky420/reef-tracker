// Generates `lib/domain/ro.g.dart` (the `kRoDefaultLifespanDays` /
// `kRoDefaultStageOrder` consts) from the editable
// `lib/domain/ro_defaults.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_ro_defaults.dart
//
// Validates the YAML before writing: every non-custom `RoStageType` name
// must appear exactly once (custom stages are user-created and have no
// default), and every lifespan must be a whole number of days >= 1. On any
// error it prints the problems and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's output
// is a part of `ro.dart`, so the package doesn't compile while the output is
// missing (build_runner deletes unclaimed `.g.dart` files as conflicting
// outputs; this tool must be runnable right after that).

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/ro_defaults.yaml';
const _outPath = 'lib/domain/ro.g.dart';

/// Mirrors the non-custom values of `RoStageType` in ro.dart, in enum order.
const _stageTypes = ['sediment', 'carbonBlock', 'membrane', 'diResin'];

void main() {
  final src = File(_srcPath);
  if (!src.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];
  final seenTypes = <String>{};

  final orderBuf = StringBuffer()
    ..writeln('/// Seed order of the default stages — the water path through')
    ..writeln('/// the unit. Generated from `ro_defaults.yaml` (listing')
    ..writeln('/// order).')
    ..writeln('const List<RoStageType> kRoDefaultStageOrder = [');
  final lifespanBuf = StringBuffer()
    ..writeln('/// Typical replacement lifespans (days) used to seed the')
    ..writeln('/// default stage set the first time the RO screen is opened,')
    ..writeln('/// generated from `ro_defaults.yaml`. Deliberately')
    ..writeln('/// conservative, mainstream values — the user edits them to')
    ..writeln('/// match their water and unit. [RoStageType.custom] has no')
    ..writeln('/// default: custom stages are user-created.')
    ..writeln('const Map<RoStageType, int> kRoDefaultLifespanDays = {');

  final stages = doc['stages'] as YamlList;
  for (final s in stages) {
    final type = s['type'] as String? ?? '';
    final where = 'stage "$type"';
    if (!_stageTypes.contains(type)) {
      errors.add('$where: not a non-custom RoStageType name');
      continue;
    }
    if (!seenTypes.add(type)) errors.add('$where: listed more than once');

    const stageFields = {'type', 'lifespanDays'};
    for (final f in (s as YamlMap).keys) {
      if (!stageFields.contains(f)) {
        errors.add('$where: unknown field "$f"');
      }
    }
    final lifespan = s['lifespanDays'];
    if (lifespan is! int || lifespan < 1) {
      errors.add('$where: lifespanDays must be a whole number of days >= 1');
      continue;
    }

    orderBuf.writeln('  RoStageType.$type,');
    lifespanBuf.writeln('  RoStageType.$type: $lifespan,');
  }
  orderBuf.writeln('];');
  lifespanBuf.writeln('};');

  for (final type in _stageTypes) {
    if (!seenTypes.contains(type)) {
      errors.add(
        'missing stage "$type" (every non-custom RoStageType needs a '
        'default lifespan)',
      );
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('RO defaults validation failed — nothing written:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final out = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: ro_defaults.yaml')
    ..writeln('// Regenerate: dart run tool/gen_ro_defaults.dart')
    ..writeln('')
    ..writeln("part of 'ro.dart';")
    ..writeln('')
    ..write(lifespanBuf)
    ..writeln('')
    ..write(orderBuf);

  File(_outPath).writeAsStringSync(out.toString());
  // Normalize to the current formatter style so the file stays byte-identical
  // to what CI's format + generated-code checks expect.
  final fmt = Process.runSync('dart', ['format', _outPath], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed:\n${fmt.stderr}');
    exit(1);
  }
  stdout.writeln('Wrote $_outPath (${stages.length} stages).');
}
