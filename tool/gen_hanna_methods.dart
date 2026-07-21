// Generates `lib/domain/hanna_meter.g.dart` (the `kHannaMeterMethods` const
// list) and `lib/domain/hanna_import.g.dart` (the `kHannaCsvMethods` const
// list) from the editable `lib/domain/hanna_methods.yaml` source — ONE yaml,
// TWO part files (the tank_presets.yaml pattern).
//
// Run from the project root:
//     dart run tool/gen_hanna_methods.dart
//
// Validates the YAML before writing. `methods`: codes must be unique positive
// integers, every param must be a key in parameters.yaml, a param may
// appear at most once per range flavor (standard/lowRange — a parameter may
// carry only a low-range code, like nitrite), and factor must be a positive
// number (the value → canonical-unit multiplier, e.g. nitrite's ppb → ppm).
// `csv`: prefixes/params must be unique, params must be
// keys in parameters.yaml, an earlier prefix must not shadow a later one
// (entries match in order — `phosphate` before `ph`), and factor must be a
// positive number. On any error it prints
// the problems and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's outputs
// are parts of `hanna_meter.dart`/`hanna_import.dart`, so the package doesn't
// compile while an output is missing (build_runner deletes unclaimed `.g.dart`
// files as conflicting outputs; this tool must be runnable right after that).
// Parameter keys are validated against `parameters.yaml` directly instead.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/hanna_methods.yaml';
const _paramsPath = 'lib/domain/parameters.yaml';
const _meterOutPath = 'lib/domain/hanna_meter.g.dart';
const _importOutPath = 'lib/domain/hanna_import.g.dart';

final _keyword = RegExp(r'^[a-z][a-z0-9]*$');

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

  final paramsDoc = loadYaml(paramsSrc.readAsStringSync());
  final paramKeys = <String>{
    for (final p in paramsDoc['parameters'] as YamlList) p['key'] as String,
  };

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];

  final meterBuf = _genMeterMethods(doc, paramKeys, errors);
  final importBuf = _genCsvMethods(doc, paramKeys, errors);

  if (errors.isNotEmpty) {
    stderr.writeln('hanna_methods.yaml is invalid — nothing written:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  _write(_meterOutPath, meterBuf);
  _write(_importOutPath, importBuf);
  stdout.writeln(
    'Wrote $_meterOutPath (${(doc['methods'] as YamlList).length} methods) '
    'and $_importOutPath (${(doc['csv'] as YamlList).length} CSV mappings).',
  );
}

StringBuffer _genMeterMethods(
  dynamic doc,
  Set<String> paramKeys,
  List<String> errors,
) {
  final seenCodes = <int>{};
  final standardParams = <String>{};
  final lowRangeParams = <String>{};

  final methods = doc['methods'];
  if (methods is! YamlList || methods.isEmpty) {
    stderr.writeln(
      'hanna_methods.yaml must contain a non-empty `methods` list.',
    );
    exit(1);
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: hanna_methods.yaml')
    ..writeln('// Regenerate: dart run tool/gen_hanna_methods.dart')
    ..writeln('')
    ..writeln("part of 'hanna_meter.dart';")
    ..writeln('')
    ..writeln('/// Every method the HI97115C registers, in display order,')
    ..writeln('/// generated from `hanna_methods.yaml`.')
    ..writeln('const List<HannaMeterMethod> kHannaMeterMethods = [');

  for (final m in methods) {
    final code = m['code'];
    if (code is! int || code <= 0) {
      errors.add('methods: code must be a positive integer, got "$code"');
      continue;
    }
    if (!seenCodes.add(code)) errors.add('methods: duplicate code $code');

    final param = m['param'];
    if (param is! String || !paramKeys.contains(param)) {
      errors.add(
        'methods: $code: "$param" is not a parameter key in parameters.yaml',
      );
      continue;
    }

    final lowRange = m['lowRange'] ?? false;
    if (lowRange is! bool) {
      errors.add(
        'methods: $code: lowRange must be true or false, got "$lowRange"',
      );
      continue;
    }
    final flavor = lowRange ? lowRangeParams : standardParams;
    if (!flavor.add(param)) {
      errors.add(
        'methods: $code: "$param" already has a '
        '${lowRange ? 'low' : 'standard'}-range code',
      );
    }

    final factor = m['factor'] ?? 1;
    if (factor is! num || factor <= 0) {
      errors.add(
        'methods: $code: factor must be a positive number, '
        'got "$factor"',
      );
      continue;
    }

    final args = [
      "$code, '${_esc(param)}'",
      if (lowRange) 'lowRange: true',
      if (factor != 1) 'factor: $factor',
    ];
    buf.writeln('  HannaMeterMethod(${args.join(', ')}),');
  }
  buf.writeln('];');
  return buf;
}

StringBuffer _genCsvMethods(
  dynamic doc,
  Set<String> paramKeys,
  List<String> errors,
) {
  final seenPrefixes = <String>[];
  final seenParams = <String>{};

  final csv = doc['csv'];
  if (csv is! YamlList || csv.isEmpty) {
    stderr.writeln('hanna_methods.yaml must contain a non-empty `csv` list.');
    exit(1);
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: hanna_methods.yaml')
    ..writeln('// Regenerate: dart run tool/gen_hanna_methods.dart')
    ..writeln('')
    ..writeln("part of 'hanna_import.dart';")
    ..writeln('')
    ..writeln(
      '/// The Hanna Lab CSV method mappings, in match order, generated',
    )
    ..writeln('/// from `hanna_methods.yaml`.')
    ..writeln('const List<HannaCsvMethod> kHannaCsvMethods = [');

  for (final m in csv) {
    final prefix = m['prefix'];
    if (prefix is! String || !_keyword.hasMatch(prefix)) {
      errors.add('csv: bad or missing prefix: "$prefix"');
      continue;
    }
    // Entries match in order: an earlier prefix that starts a later one
    // would shadow it (`ph` before `phosphate` breaks phosphate).
    for (final earlier in seenPrefixes) {
      if (prefix.startsWith(earlier)) {
        errors.add('csv: prefix "$earlier" shadows the later "$prefix"');
      }
    }
    if (seenPrefixes.contains(prefix)) {
      errors.add('csv: duplicate prefix "$prefix"');
    }
    seenPrefixes.add(prefix);

    final param = m['param'];
    if (param is! String || !paramKeys.contains(param)) {
      errors.add(
        'csv: "$prefix": "$param" is not a parameter key in parameters.yaml',
      );
      continue;
    }
    if (!seenParams.add(param)) {
      errors.add('csv: duplicate param "$param"');
    }

    final unit = m['unit'];
    if (unit is! String || !_keyword.hasMatch(unit)) {
      errors.add('csv: "$prefix": bad or missing unit: "$unit"');
      continue;
    }

    final factor = m['factor'] ?? 1;
    if (factor is! num || factor <= 0) {
      errors.add(
        'csv: "$prefix": factor must be a positive number, '
        'got "$factor"',
      );
      continue;
    }

    buf.writeln(
      "  HannaCsvMethod('${_esc(prefix)}', '${_esc(param)}', "
      "'${_esc(unit)}'${factor != 1 ? ', factor: $factor' : ''}),",
    );
  }
  buf.writeln('];');
  return buf;
}

void _write(String path, StringBuffer buf) {
  File(path).writeAsStringSync(buf.toString());
  // The emitted style must satisfy the CI format gate (T10 lesson).
  final fmt = Process.runSync('dart', ['format', path], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed: ${fmt.stderr}');
    exit(1);
  }
}

/// Escapes a string for a single-quoted Dart literal.
String _esc(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
