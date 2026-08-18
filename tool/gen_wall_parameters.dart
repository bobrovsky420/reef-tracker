// Generates `lib/domain/wall_parameters.g.dart` (the `kWallParameterKeys`
// set) from the editable `lib/domain/wall_parameters.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_wall_parameters.dart
//
// Validates the YAML before writing: every key must be unique, exist in
// `parameters.yaml`, and be a CORE parameter — microelements (any entry with
// a `category` other than core) are rejected, which is the whole point of
// the catalogue (U49: the wall never shows the ICP panel). On any error it
// prints the problems and writes nothing.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/wall_parameters.yaml';
const _catalogPath = 'lib/domain/parameters.yaml';
const _outPath = 'lib/domain/wall_parameters.g.dart';

void main() {
  final src = File(_srcPath);
  final catalog = File(_catalogPath);
  if (!src.existsSync() || !catalog.existsSync()) {
    stderr.writeln(
      'Source not found: $_srcPath / $_catalogPath '
      '(run from the project root).',
    );
    exit(1);
  }

  // key → category (null = core, the parameters.yaml default).
  final categories = <String, String?>{};
  final catalogDoc = loadYaml(catalog.readAsStringSync());
  for (final p in catalogDoc['parameters'] as YamlList) {
    categories[p['key'] as String] = p['category'] as String?;
  }

  final doc = loadYaml(src.readAsStringSync());
  final entries = doc['parameters'];
  if (entries is! YamlList || entries.isEmpty) {
    stderr.writeln(
      'wall_parameters.yaml must contain a non-empty `parameters` list.',
    );
    exit(1);
  }

  final errors = <String>[];
  final keys = <String>[];
  for (final entry in entries) {
    if (entry is! String) {
      errors.add('"$entry" is not a plain string key');
      continue;
    }
    if (keys.contains(entry)) {
      errors.add('duplicate key "$entry"');
      continue;
    }
    if (!categories.containsKey(entry)) {
      errors.add('key "$entry" does not exist in parameters.yaml');
      continue;
    }
    final category = categories[entry];
    if (category != null && category != 'core') {
      errors.add(
        'key "$entry" is a microelement (category: $category) — '
        'microelements are excluded from the wall by design',
      );
      continue;
    }
    keys.add(entry);
  }

  if (errors.isNotEmpty) {
    stderr.writeln('wall_parameters.yaml is invalid:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: wall_parameters.yaml')
    ..writeln('// Regenerate: dart run tool/gen_wall_parameters.dart')
    ..writeln('')
    ..writeln("part of 'wall_display.dart';")
    ..writeln('')
    ..writeln('/// The parameters that may appear on the wall board — the')
    ..writeln('/// selectable card set, generated from `wall_parameters.yaml`.')
    ..writeln('/// Microelements are excluded by design (the generator')
    ..writeln('/// rejects them); `buildWallCards` drops any key outside this')
    ..writeln('/// set, whatever a tank tracks or a device reports.')
    ..writeln('const Set<String> kWallParameterKeys = {');
  for (final k in keys) {
    buf.writeln("  '$k',");
  }
  buf.writeln('};');

  File(_outPath).writeAsStringSync(buf.toString());
  // The emitted style must satisfy the CI format gate (T10 lesson).
  final fmt = Process.runSync('dart', ['format', _outPath], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed: ${fmt.stderr}');
    exit(1);
  }
  stdout.writeln('Wrote $_outPath: ${keys.length} wall parameter(s).');
}
