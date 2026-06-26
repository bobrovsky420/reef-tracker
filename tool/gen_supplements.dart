// Generates `lib/domain/supplement_catalog.g.dart` (the `kSupplementVendors`
// const list) from the editable `lib/domain/supplements.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_supplements.dart
//
// Validates the YAML before writing: product keys must be unique, every
// `element` / `strength` key must be a real reef-parameter key, and `unit` must
// be ml or g. On any error it prints the problems and writes nothing.

import 'dart:io';

import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/supplements.yaml';
const _outPath = 'lib/domain/supplement_catalog.g.dart';

void main() {
  final src = File(_srcPath);
  if (!src.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }

  final doc = loadYaml(src.readAsStringSync());
  final validParams = kParameterByKey.keys.toSet();
  final errors = <String>[];
  final seenKeys = <String>{};

  final buf = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: supplements.yaml')
    ..writeln('// Regenerate: dart run tool/gen_supplements.dart')
    ..writeln('')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln('')
    ..writeln("part of 'supplement_catalog.dart';")
    ..writeln('')
    ..writeln('/// The built-in supplement catalog, generated from')
    ..writeln('/// `supplements.yaml`. Curated, with a UI "Other…" escape hatch.')
    ..writeln('const List<SupplementVendor> kSupplementVendors = [');

  final vendors = doc['vendors'] as YamlList;
  for (final v in vendors) {
    buf
      ..writeln('  SupplementVendor(')
      ..writeln("    key: '${_esc(v['key'])}',")
      ..writeln("    name: '${_esc(v['name'])}',");

    final products = v['products'] as YamlList?;
    if (products != null) {
      buf.writeln('    products: [');
      for (final p in products) {
        buf.write(_emitProduct(p, '      ', validParams, seenKeys, errors));
      }
      buf.writeln('    ],');
    }

    final programs = v['programs'] as YamlList?;
    if (programs != null) {
      buf.writeln('    programs: [');
      for (final prog in programs) {
        buf
          ..writeln('      SupplementProgram(')
          ..writeln("        key: '${_esc(prog['key'])}',")
          ..writeln("        name: '${_esc(prog['name'])}',")
          ..writeln('        products: [');
        for (final p in prog['products'] as YamlList) {
          buf.write(_emitProduct(p, '          ', validParams, seenKeys, errors));
        }
        buf
          ..writeln('        ],')
          ..writeln('      ),');
      }
      buf.writeln('    ],');
    }

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
  stdout.writeln('Wrote $_outPath '
      '(${vendors.length} vendors, ${seenKeys.length} products).');
}

String _emitProduct(
  dynamic p,
  String indent,
  Set<String> validParams,
  Set<String> seen,
  List<String> errors,
) {
  final key = p['key'] as String;
  if (!seen.add(key)) errors.add('duplicate product key: "$key"');

  final element = p['element'] as String?;
  if (element != null && !validParams.contains(element)) {
    errors.add('product "$key": unknown element "$element"');
  }

  final unit = p['unit'] as String?;
  if (unit != null && unit != 'ml' && unit != 'g') {
    errors.add('product "$key": unit must be ml or g (got "$unit")');
  }

  final strength = p['strength'] as YamlMap?;
  String? strengthLiteral;
  if (strength != null) {
    final entries = <String>[];
    strength.forEach((k, val) {
      final ks = k as String;
      if (!validParams.contains(ks)) {
        errors.add('product "$key": unknown strength key "$ks"');
      }
      entries.add("'${_esc(ks)}': ${(val as num).toDouble()}");
    });
    strengthLiteral = '{${entries.join(', ')}}';
  }

  final sb = StringBuffer()
    ..writeln('${indent}SupplementProduct(')
    ..writeln("$indent  key: '${_esc(key)}',")
    ..writeln("$indent  name: '${_esc(p['name'])}',");
  if (element != null) sb.writeln("$indent  elementKey: '${_esc(element)}',");
  if (unit == 'g') sb.writeln('$indent  defaultUnit: DoseUnit.g,');
  if (strengthLiteral != null) {
    sb.writeln('$indent  strength: $strengthLiteral,');
  }
  sb.writeln('$indent),');
  return sb.toString();
}

/// Escapes a string for a single-quoted Dart literal.
String _esc(dynamic v) => (v as String)
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
