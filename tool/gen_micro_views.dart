// Generates `lib/domain/micro_views.g.dart` (the `kMicroViewPresets` const
// list) from the editable `lib/domain/micro_views.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_micro_views.dart
//
// Validates the YAML before writing: preset ids/names must be unique (ids are
// persisted as `preset:<id>` tokens in the device-local `micro_view` setting),
// and every key must be a microelement key from parameters.yaml (category
// major / trace / contaminant), listed at most once per preset. On any error
// it prints the problems and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's output
// is a part of `micro.dart`, so the package doesn't compile while the output
// is missing (build_runner deletes unclaimed `.g.dart` files as conflicting
// outputs; this tool must be runnable right after that). Microelement keys
// are validated against `parameters.yaml` directly instead.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/micro_views.yaml';
const _paramsPath = 'lib/domain/parameters.yaml';
const _outPath = 'lib/domain/micro_views.g.dart';

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

  // Microelement keys = catalog entries whose category is not core (the
  // same core-vs-micro split as `isCoreParam` / `kMicroParameters`).
  final paramsDoc = loadYaml(paramsSrc.readAsStringSync());
  final microKeys = <String>{
    for (final p in paramsDoc['parameters'] as YamlList)
      if ((p['category'] as String? ?? 'core') != 'core') p['key'] as String,
  };

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];
  final seenIds = <String>{};
  final seenNames = <String>{};

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: micro_views.yaml')
    ..writeln('// Regenerate: dart run tool/gen_micro_views.dart')
    ..writeln('')
    ..writeln("part of 'micro.dart';")
    ..writeln('')
    ..writeln('/// The built-in lab view presets of the Microelements screen,')
    ..writeln('/// generated from `micro_views.yaml`, in chip order.')
    ..writeln('const List<MicroViewPreset> kMicroViewPresets = [');

  final presets = doc['presets'] as YamlList;
  for (final p in presets) {
    final id = p['id'] as String? ?? '';
    if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(id)) {
      errors.add('bad or missing preset id: "$id"');
    }
    if (!seenIds.add(id)) errors.add('duplicate preset id: "$id"');

    final name = p['name'] as String? ?? '';
    if (name.isEmpty) errors.add('"$id": missing name');
    if (!seenNames.add(name)) errors.add('"$id": duplicate name "$name"');

    final keys = p['keys'] as YamlList?;
    if (keys == null || keys.isEmpty) {
      errors.add('"$id": a preset needs at least one element key');
    }
    final seenKeys = <String>{};
    for (final k in keys ?? const []) {
      final key = k as String;
      if (!microKeys.contains(key)) {
        errors.add(
          '"$id": "$key" is not a microelement key in parameters.yaml',
        );
      }
      if (!seenKeys.add(key)) errors.add('"$id": duplicate key "$key"');
    }

    buf
      ..writeln('  MicroViewPreset(')
      ..writeln("    token: 'preset:${_esc(id)}',")
      ..writeln("    name: '${_esc(name)}',")
      ..writeln('    keys: [');
    for (final k in keys ?? const []) {
      buf.writeln("      '${_esc(k as String)}',");
    }
    buf
      ..writeln('    ],')
      ..writeln('  ),');
  }
  buf.writeln('];');

  if (errors.isNotEmpty) {
    stderr.writeln('Preset validation failed — nothing written:');
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
  stdout.writeln('Wrote $_outPath (${presets.length} presets).');
}

/// Escapes a string for a single-quoted Dart literal.
String _esc(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
