// Generates `lib/domain/presets.g.dart` (the `kPresets` / `kPresetTargets`
// const maps) and `lib/domain/ratio.g.dart` (the `kRatioDefaultBounds` const
// map) from the editable `lib/domain/tank_presets.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_tank_presets.dart
//
// Validates the YAML before writing: every `SetupType` name must have a
// section (and nothing else may), every parameter key must be a CORE
// parameter from parameters.yaml, greenLow/greenHigh are required, present
// bounds must be strictly ascending and inside the parameter's plausible
// range, and a `target` must lie inside its green range. The `ratios`
// section must cover every `RatioKind` name (and nothing else) with a full,
// strictly ascending bounds quadruple. On any error it prints the problems
// and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's output
// is a part of `presets.dart`, so the package doesn't compile while the
// output is missing (build_runner deletes unclaimed `.g.dart` files as
// conflicting outputs; this tool must be runnable right after that).
// Parameter keys are validated against `parameters.yaml` directly instead.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/tank_presets.yaml';
const _paramsPath = 'lib/domain/parameters.yaml';
const _outPath = 'lib/domain/presets.g.dart';
const _ratioOutPath = 'lib/domain/ratio.g.dart';

/// Mirrors `SetupType` in setup_type.dart, in enum order.
const _setupTypes = ['fishOnly', 'soft', 'lps', 'sps', 'mixed'];

/// Mirrors `RatioKind` in ratio.dart, in enum order.
const _ratioKinds = ['po4no3', 'mgca', 'caalk', 'mgalk'];

void main() {
  final src = File(_srcPath);
  if (!src.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }
  final paramsSrc = File(_paramsPath);
  if (!paramsSrc.existsSync()) {
    stderr.writeln('Catalog source not found: $_paramsPath.');
    exit(1);
  }

  // Core parameter keys + their sanity limits, for cross-validation.
  final paramsDoc = loadYaml(paramsSrc.readAsStringSync());
  final coreParams = <String, YamlMap>{
    for (final p in paramsDoc['parameters'] as YamlList)
      if ((p['category'] as String? ?? 'core') == 'core')
        p['key'] as String: p as YamlMap,
  };

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];

  final presets = doc['presets'] as YamlMap;
  for (final setup in presets.keys) {
    if (!_setupTypes.contains(setup)) {
      errors.add('unknown setup type "$setup"');
    }
  }
  for (final setup in _setupTypes) {
    if (!presets.containsKey(setup)) {
      errors.add('missing setup type "$setup" (every SetupType needs one)');
    }
  }

  final presetsBuf = StringBuffer()
    ..writeln('/// Default boundaries per setup type, generated from')
    ..writeln('/// `tank_presets.yaml`. The *keys present* in each map are')
    ..writeln('/// the parameters tracked by default for that setup type;')
    ..writeln('/// everything else can be added manually later. These are')
    ..writeln('/// sensible starting points — every bound is editable per')
    ..writeln('/// tank.')
    ..writeln('const Map<SetupType, Map<String, ZoneBounds>> kPresets = {');
  final targetsBuf = StringBuffer()
    ..writeln('/// Default correction *targets* per setup type, generated')
    ..writeln('/// from `tank_presets.yaml` (`target` fields) — see')
    ..writeln('/// [presetTarget] for the fallback rule.')
    ..writeln('const Map<SetupType, Map<String, double>> kPresetTargets = {');

  for (final setup in _setupTypes) {
    final params = presets[setup] as YamlMap?;
    if (params == null) continue;
    if (params.isEmpty) {
      errors.add('"$setup": a preset needs at least one parameter');
      continue;
    }
    presetsBuf.writeln('  SetupType.$setup: {');
    final targetRows = StringBuffer();

    for (final entry in params.entries) {
      final key = entry.key as String;
      final where = '"$setup.$key"';
      final def = coreParams[key];
      if (def == null) {
        errors.add('$where: not a core parameter key in parameters.yaml');
      }

      final row = entry.value as YamlMap;
      const rowFields = {
        'amberLow',
        'greenLow',
        'greenHigh',
        'amberHigh',
        'target',
      };
      for (final f in row.keys) {
        if (!rowFields.contains(f)) {
          errors.add('$where: unknown field "$f"');
        }
      }

      final amberLow = row['amberLow'] as num?;
      final greenLow = row['greenLow'] as num?;
      final greenHigh = row['greenHigh'] as num?;
      final amberHigh = row['amberHigh'] as num?;
      final target = row['target'] as num?;
      if (greenLow == null || greenHigh == null) {
        errors.add('$where: greenLow and greenHigh are required');
      }
      final present = [
        amberLow,
        greenLow,
        greenHigh,
        amberHigh,
      ].whereType<num>().toList();
      for (var i = 1; i < present.length; i++) {
        if (present[i - 1] >= present[i]) {
          errors.add('$where: bounds must be strictly ascending');
          break;
        }
      }
      final minValue = def?['minValue'] as num?;
      final plausibleMin = def?['plausibleMin'] as num?;
      final plausibleMax = def?['plausibleMax'] as num?;
      for (final v in present) {
        if (minValue != null && v < minValue) {
          errors.add('$where: bound $v below the hard floor');
        }
        if (plausibleMin != null && v < plausibleMin) {
          errors.add('$where: bound $v below the plausible range');
        }
        if (plausibleMax != null && v > plausibleMax) {
          errors.add('$where: bound $v above the plausible range');
        }
      }
      if (target != null &&
          greenLow != null &&
          greenHigh != null &&
          (target < greenLow || target > greenHigh)) {
        errors.add('$where: target $target outside the green range');
      }

      presetsBuf.write("    '${_esc(key)}': ZoneBounds(");
      if (amberLow != null) presetsBuf.write('amberLow: $amberLow, ');
      presetsBuf.write('greenLow: $greenLow, greenHigh: $greenHigh');
      if (amberHigh != null) presetsBuf.write(', amberHigh: $amberHigh');
      presetsBuf.writeln('),');
      if (target != null) {
        targetRows.writeln("    '${_esc(key)}': $target,");
      }
    }

    presetsBuf.writeln('  },');
    if (targetRows.isNotEmpty) {
      targetsBuf
        ..writeln('  SetupType.$setup: {')
        ..write(targetRows)
        ..writeln('  },');
    }
  }
  presetsBuf.writeln('};');
  targetsBuf.writeln('};');

  final ratios = doc['ratios'] as YamlMap? ?? YamlMap();
  for (final kind in ratios.keys) {
    if (!_ratioKinds.contains(kind)) {
      errors.add('ratios: unknown ratio kind "$kind"');
    }
  }
  final ratiosBuf = StringBuffer()
    ..writeln('/// Recommended zone bounds per ratio kind, generated from')
    ..writeln('/// `tank_presets.yaml` (`ratios` section) — see')
    ..writeln('/// [RatioKindZones.defaultBounds] for the metric space.')
    ..writeln('const Map<RatioKind, ZoneBounds> kRatioDefaultBounds = {');
  for (final kind in _ratioKinds) {
    final row = ratios[kind] as YamlMap?;
    if (row == null) {
      errors.add(
        'ratios: missing ratio kind "$kind" (every RatioKind '
        'needs recommended bounds)',
      );
      continue;
    }
    const boundFields = {'amberLow', 'greenLow', 'greenHigh', 'amberHigh'};
    for (final f in row.keys) {
      if (!boundFields.contains(f)) {
        errors.add('ratios.$kind: unknown field "$f"');
      }
    }
    final bounds = [
      row['amberLow'] as num?,
      row['greenLow'] as num?,
      row['greenHigh'] as num?,
      row['amberHigh'] as num?,
    ];
    if (bounds.contains(null)) {
      errors.add('ratios.$kind: all four bounds are required');
      continue;
    }
    for (var i = 1; i < bounds.length; i++) {
      if (bounds[i - 1]! >= bounds[i]!) {
        errors.add('ratios.$kind: bounds must be strictly ascending');
        break;
      }
    }
    ratiosBuf
      ..write('  RatioKind.$kind: ZoneBounds(')
      ..write('amberLow: ${bounds[0]}, greenLow: ${bounds[1]}, ')
      ..write('greenHigh: ${bounds[2]}, amberHigh: ${bounds[3]}')
      ..writeln('),');
  }
  ratiosBuf.writeln('};');

  if (errors.isNotEmpty) {
    stderr.writeln('Preset validation failed — nothing written:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final out = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: tank_presets.yaml')
    ..writeln('// Regenerate: dart run tool/gen_tank_presets.dart')
    ..writeln('')
    ..writeln("part of 'presets.dart';")
    ..writeln('')
    ..write(presetsBuf)
    ..writeln('')
    ..write(targetsBuf);

  final ratioOut = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: tank_presets.yaml (ratios section)')
    ..writeln('// Regenerate: dart run tool/gen_tank_presets.dart')
    ..writeln('')
    ..writeln("part of 'ratio.dart';")
    ..writeln('')
    ..write(ratiosBuf);

  File(_outPath).writeAsStringSync(out.toString());
  File(_ratioOutPath).writeAsStringSync(ratioOut.toString());
  // Normalize to the current formatter style so the files stay byte-identical
  // to what CI's format + generated-code checks expect.
  final fmt = Process.runSync('dart', [
    'format',
    _outPath,
    _ratioOutPath,
  ], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed:\n${fmt.stderr}');
    exit(1);
  }
  stdout.writeln(
    'Wrote $_outPath (${presets.length} setup types) and '
    '$_ratioOutPath (${ratios.length} ratio kinds).',
  );
}

/// Escapes a string for a single-quoted Dart literal.
String _esc(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
