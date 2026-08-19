// Generates `lib/domain/pro_features.g.dart` (the `ProFeature` enum and the
// `kGrandfatheredFeatures` set) from the editable
// `lib/domain/pro_features.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_pro_features.dart
//
// Validates the YAML before writing: keys must be unique camelCase Dart
// identifiers, `grandfathered` must be a bool, and every feature must declare
// at least one globally unique typed authorization boundary. On any error it
// prints the problems and writes nothing.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/pro_features.yaml';
const _outPath = 'lib/domain/pro_features.g.dart';

final _identifier = RegExp(r'^[a-z][a-zA-Z0-9]*$');
const _boundaryKinds = {
  'routeResource',
  'command',
  'presentation',
  'configuration',
};

class _Boundary {
  const _Boundary(this.id, this.kind, this.feature);

  final String id;
  final String kind;
  final String feature;
}

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
  final boundaries = <_Boundary>[];

  final features = doc['features'];
  if (features is! YamlList || features.isEmpty) {
    stderr.writeln(
      'pro_features.yaml must contain a non-empty `features` list.',
    );
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

    final rawBoundaries = f['boundaries'];
    if (rawBoundaries is! YamlList || rawBoundaries.isEmpty) {
      errors.add('"$key": boundaries must be a non-empty list');
      continue;
    }
    for (final raw in rawBoundaries) {
      if (raw is! YamlMap) {
        errors.add('"$key": every boundary must be a map');
        continue;
      }
      final id = raw['id'];
      final kind = raw['kind'];
      if (id is! String || !_identifier.hasMatch(id)) {
        errors.add('"$key": boundary id "$id" is not camelCase');
        continue;
      }
      if (boundaries.any((b) => b.id == id)) {
        errors.add('duplicate boundary id "$id"');
        continue;
      }
      if (kind is! String || !_boundaryKinds.contains(kind)) {
        errors.add(
          '"$key.$id": kind must be one of ${_boundaryKinds.join(', ')}, '
          'got "$kind"',
        );
        continue;
      }
      boundaries.add(_Boundary(id, kind, key));
    }
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
    ..writeln('/// Every authoritative Pro authorization boundary, generated')
    ..writeln('/// from `pro_features.yaml`.')
    ..writeln('enum ProCapabilityBoundary {');
  for (final b in boundaries) {
    buf.writeln('  ${b.id},');
  }
  buf
    ..writeln('}')
    ..writeln('')
    ..writeln('/// Feature and enforcement kind for each capability boundary.')
    ..writeln(
      'const Map<ProCapabilityBoundary, ProCapabilityContract> '
      'kProCapabilityContracts = {',
    );
  for (final b in boundaries) {
    buf
      ..writeln('  ProCapabilityBoundary.${b.id}: ProCapabilityContract(')
      ..writeln('    feature: ProFeature.${b.feature},')
      ..writeln('    kind: ProBoundaryKind.${b.kind},')
      ..writeln('  ),');
  }
  buf
    ..writeln('};')
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
    '${grandfathered.length} grandfathered, '
    '${boundaries.length} authorization boundaries.',
  );
}
