// Generates `lib/domain/ro.g.dart` (the `kRoLifespanDaysByUsage` /
// `kRoDefaultStageOrder` consts) from the editable
// `lib/domain/ro_defaults.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_ro_defaults.dart
//
// Validates the YAML before writing: every non-custom `RoStageType` name
// must appear exactly once (custom stages are user-created and have no
// default), every stage must carry a lifespan for every `RoUsageLevel`
// (whole days >= 1), and heavier usage must never get a longer lifespan
// than a lighter one. On any error it prints the problems and writes
// nothing.
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

/// Mirrors `RoUsageLevel` in ro.dart, lightest first.
const _usageLevels = ['light', 'moderate', 'heavy'];

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
  // Per-level lifespan maps, filled stage by stage, emitted level by level.
  final lifespans = {
    for (final level in _usageLevels) level: <String, int>{},
  };

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
    final byLevel = s['lifespanDays'];
    if (byLevel is! YamlMap) {
      errors.add(
        '$where: lifespanDays must be a map with one entry per usage '
        'level (${_usageLevels.join('/')})',
      );
      continue;
    }
    for (final level in byLevel.keys) {
      if (!_usageLevels.contains(level)) {
        errors.add('$where: unknown usage level "$level"');
      }
    }
    var ok = true;
    for (final level in _usageLevels) {
      final lifespan = byLevel[level];
      if (lifespan is! int || lifespan < 1) {
        errors.add(
          '$where: lifespanDays.$level must be a whole number of days >= 1',
        );
        ok = false;
        continue;
      }
      lifespans[level]![type] = lifespan;
    }
    if (!ok) continue;
    // Heavier usage wears a part faster, never slower.
    for (var i = 1; i < _usageLevels.length; i++) {
      final lighter = lifespans[_usageLevels[i - 1]]![type]!;
      final heavier = lifespans[_usageLevels[i]]![type]!;
      if (heavier > lighter) {
        errors.add(
          '$where: ${_usageLevels[i]} lifespan ($heavier) exceeds '
          '${_usageLevels[i - 1]} ($lighter)',
        );
      }
    }

    orderBuf.writeln('  RoStageType.$type,');
  }
  orderBuf.writeln('];');

  final lifespanBuf = StringBuffer()
    ..writeln('/// Typical replacement lifespans (days) per usage level,')
    ..writeln('/// generated from `ro_defaults.yaml`. Seeds the default')
    ..writeln('/// stage set on first RO-screen open and re-applies when the')
    ..writeln('/// user picks a usage level; `moderate` is the default.')
    ..writeln('/// Deliberately conservative, mainstream values — the user')
    ..writeln('/// edits them to match their water and unit.')
    ..writeln('/// [RoStageType.custom] has no default: custom stages are')
    ..writeln('/// user-created.')
    ..writeln(
      'const Map<RoUsageLevel, Map<RoStageType, int>> '
      'kRoLifespanDaysByUsage = {',
    );
  for (final level in _usageLevels) {
    lifespanBuf.writeln('  RoUsageLevel.$level: {');
    // Emit in listing (water-path) order, like the order const.
    for (final s in stages) {
      final type = s['type'];
      final days = lifespans[level]![type];
      if (days != null) lifespanBuf.writeln('    RoStageType.$type: $days,');
    }
    lifespanBuf.writeln('  },');
  }
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
