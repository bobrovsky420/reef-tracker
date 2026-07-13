// Generates `lib/domain/pro_features.g.dart` (the `ProFeature` enum and the
// `kGrandfatheredFeatures` set) from the editable
// `lib/domain/pro_features.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_pro_features.dart
//
// Validates the YAML before writing: keys must be unique camelCase Dart
// identifiers and `grandfathered` must be a bool. On any error it prints the
// problems and writes nothing.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/pro_features.yaml';
const _outPath = 'lib/domain/pro_features.g.dart';

final _identifier = RegExp(r'^[a-z][a-zA-Z0-9]*$');

void main() {
  final src = File(_srcPath);
  if (!src.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }

  final doc = loadYaml(src.readAsStringSync());
  final errors = <String>[];
  final keys = <String>[];
  final grandfathered = <String>[];

  final features = doc['features'];
  if (features is! YamlList || features.isEmpty) {
    stderr.writeln('pro_features.yaml must contain a non-empty `features` list.');
    exit(1);
  }
  for (final f in features) {
    final key = f['key'];
    if (key is! String || !_identifier.hasMatch(key)) {
      errors.add('key "$key" is not a camelCase Dart identifier');
      continue;
    }
    if (keys.contains(key)) {
      errors.add('duplicate key "$key"');
      continue;
    }
    final flag = f['grandfathered'];
    if (flag is! bool) {
      errors.add('"$key": grandfathered must be true or false, got "$flag"');
      continue;
    }
    keys.add(key);
    if (flag) grandfathered.add(key);
  }

  if (errors.isNotEmpty) {
    stderr.writeln('pro_features.yaml is invalid:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: pro_features.yaml')
    ..writeln('// Regenerate: dart run tool/gen_pro_features.dart')
    ..writeln('')
    ..writeln("part of 'pro_features.dart';")
    ..writeln('')
    ..writeln('/// Every feature behind the Pro gate, generated from')
    ..writeln('/// `pro_features.yaml`.')
    ..writeln('enum ProFeature {');
  for (final k in keys) {
    buf.writeln('  $k,');
  }
  buf
    ..writeln('}')
    ..writeln('')
    ..writeln('/// Features that existed at the monetization cutoff: free')
    ..writeln('/// FOREVER for Founder\'s Edition installs. Entries are never')
    ..writeln('/// removed (see pro_features.yaml).')
    ..writeln('const Set<ProFeature> kGrandfatheredFeatures = {');
  for (final k in grandfathered) {
    buf.writeln('  ProFeature.$k,');
  }
  buf.writeln('};');

  File(_outPath).writeAsStringSync(buf.toString());
  // The emitted style must satisfy the CI format gate (T10 lesson).
  final fmt = Process.runSync('dart', ['format', _outPath], runInShell: true);
  if (fmt.exitCode != 0) {
    stderr.writeln('dart format failed: ${fmt.stderr}');
    exit(1);
  }
  stdout.writeln(
    'Wrote $_outPath: ${keys.length} feature(s), '
    '${grandfathered.length} grandfathered.',
  );
}
