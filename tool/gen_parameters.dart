// Generates `lib/domain/parameter_catalog.g.dart` (the `kReefParameters`
// const list) from the editable `lib/domain/parameters.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_parameters.dart
//
// Validates the YAML before writing: keys/symbols must be unique, category
// must be a real `ParamCategory` name, microelements must carry a symbol,
// bounds must be ordered, and both plausible bounds must be defined or
// neither. On any error it prints the problems and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's output
// is a part of `parameter_catalog.dart`, so the package doesn't compile while
// the output is missing (build_runner deletes unclaimed `.g.dart` files as
// conflicting outputs; this tool must be runnable right after that).

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/parameters.yaml';
const _outPath = 'lib/domain/parameter_catalog.g.dart';

/// Mirrors `ParamCategory` in parameter_catalog.dart. `core` is the default
/// and is omitted from the generated constructor calls.
const _categories = {'core', 'major', 'trace', 'contaminant'};

void main() {
  final src = File(_srcPath);
  if (!src.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];
  final seenKeys = <String>{};
  final seenSymbols = <String>{};

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: parameters.yaml')
    ..writeln('// Regenerate: dart run tool/gen_parameters.dart')
    ..writeln('')
    ..writeln("part of 'parameter_catalog.dart';")
    ..writeln('')
    ..writeln('/// The built-in catalog of typical reef aquarium parameters,')
    ..writeln('/// generated from `parameters.yaml`.')
    ..writeln('const List<ParameterDef> kReefParameters = [');

  final params = doc['parameters'] as YamlList;
  for (final p in params) {
    final key = p['key'] as String? ?? '';
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
      errors.add('bad or missing key: "$key"');
    }
    if (!seenKeys.add(key)) errors.add('duplicate parameter key: "$key"');

    final unit = p['unit'] as String? ?? '';
    if (unit.isEmpty) errors.add('"$key": missing unit');

    final decimals = p['decimals'];
    if (decimals is! int || decimals < 0 || decimals > 4) {
      errors.add('"$key": decimals must be an integer 0–4 (got "$decimals")');
    }

    final category = p['category'] as String? ?? 'core';
    if (!_categories.contains(category)) {
      errors.add('"$key": unknown category "$category"');
    }

    final symbol = p['symbol'] as String?;
    if (category != 'core' && (symbol == null || symbol.isEmpty)) {
      errors.add('"$key": microelements must carry an element symbol');
    }
    if (symbol != null && !seenSymbols.add(symbol)) {
      errors.add('"$key": duplicate symbol "$symbol"');
    }

    final displayFactor = p['displayFactor'] as num?;
    if (displayFactor != null && displayFactor <= 0) {
      errors.add('"$key": displayFactor must be positive');
    }
    if (displayFactor != null && category == 'core') {
      errors.add('"$key": displayFactor is a microelement mechanism');
    }

    final minValue = p['minValue'] as num?;
    final plausibleMin = p['plausibleMin'] as num?;
    final plausibleMax = p['plausibleMax'] as num?;
    if ((plausibleMin == null) != (plausibleMax == null)) {
      errors.add('"$key": define both plausible bounds or neither');
    }
    if (plausibleMin != null &&
        plausibleMax != null &&
        plausibleMin >= plausibleMax) {
      errors.add('"$key": plausibleMin must be below plausibleMax');
    }
    if (minValue != null && plausibleMin != null && plausibleMin < minValue) {
      errors.add('"$key": plausibleMin sits below the hard floor');
    }

    buf
      ..writeln('  ParameterDef(')
      ..writeln("    key: '${_esc(key)}',")
      ..writeln("    unit: '${_esc(unit)}',")
      ..writeln('    decimals: $decimals,');
    if (category != 'core') {
      buf.writeln('    category: ParamCategory.$category,');
    }
    if (symbol != null) buf.writeln("    symbol: '${_esc(symbol)}',");
    if (displayFactor != null) {
      buf.writeln('    displayFactor: $displayFactor,');
    }
    if (minValue != null) buf.writeln('    minValue: $minValue,');
    if (plausibleMin != null) buf.writeln('    plausibleMin: $plausibleMin,');
    if (plausibleMax != null) buf.writeln('    plausibleMax: $plausibleMax,');
    buf.writeln('  ),');
  }
  buf.writeln('];');

  if (errors.isNotEmpty) {
    stderr.writeln('Catalog validation failed — nothing written:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  File(_outPath).writeAsStringSync(buf.toString());
  // Normalize to the current formatter style so the file stays byte-identical
  // to what CI's format + generated-code checks expect.
  final fmt = Process.runSync('dart', ['format', _outPath], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed:\n${fmt.stderr}');
    exit(1);
  }
  stdout.writeln('Wrote $_outPath (${params.length} parameters).');
}

/// Escapes a string for a single-quoted Dart literal.
String _esc(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
