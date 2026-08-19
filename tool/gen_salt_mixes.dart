// Generates `lib/domain/salt_mix_catalog.g.dart` (the `kSaltMixProducts`
// list) from the editable `lib/domain/salt_mixes.yaml` source.
//
// Run from the project root:
//     dart run tool/gen_salt_mixes.dart
//
// Validates every persisted key, manufacturer name, positive strength,
// reference-salinity unit/value, evidence basis, HTTPS source and verification
// date before writing. On any error it prints all problems and writes nothing.
//
// Deliberately does NOT import package:reeftracker — this generator's output is
// a part of `salt_mix_catalog.dart`, so the package does not compile while the
// output is missing (build_runner deletes unclaimed `.g.dart` files).

import 'dart:io';

import 'package:yaml/yaml.dart';

const _srcPath = 'lib/domain/salt_mixes.yaml';
const _outPath = 'lib/domain/salt_mix_catalog.g.dart';
const _basisNames = {
  'finalPreparedWater',
  'manufacturerRatio',
  'sourceWaterEstimate',
  'batchBackedEstimate',
};
const _fields = {
  'key',
  'brand',
  'name',
  'gramsPerLiter',
  'referenceSalinity',
  'basis',
  'sourceUrl',
  'verifiedOn',
};
final _keyPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

void main() {
  final source = File(_srcPath);
  if (!source.existsSync()) {
    stderr.writeln('Source not found: $_srcPath (run from the project root).');
    exit(1);
  }

  final errors = <String>[];
  dynamic document;
  try {
    document = loadYaml(source.readAsStringSync());
  } on YamlException catch (error) {
    stderr.writeln('salt_mixes.yaml is not valid YAML: $error');
    exit(1);
  }
  if (document is! YamlMap) {
    stderr.writeln('salt_mixes.yaml must contain a top-level map.');
    exit(1);
  }
  for (final field in document.keys) {
    if (field != 'products') errors.add('unknown top-level field "$field"');
  }
  final rawProducts = document['products'];
  if (rawProducts is! YamlList || rawProducts.isEmpty) {
    errors.add('`products` must be a non-empty list');
  }

  final products = rawProducts is YamlList ? rawProducts : const <dynamic>[];
  final seenKeys = <String>{};
  final emitted = <String>[];
  for (var index = 0; index < products.length; index++) {
    final raw = products[index];
    final where = 'products[$index]';
    if (raw is! YamlMap) {
      errors.add('$where must be a map');
      continue;
    }
    for (final field in raw.keys) {
      if (!_fields.contains(field)) {
        errors.add('$where: unknown field "$field"');
      }
    }

    final key = _nonBlank(raw['key'], '$where.key', errors);
    final brand = _nonBlank(raw['brand'], '$where.brand', errors);
    final name = _nonBlank(raw['name'], '$where.name', errors);
    if (key != null) {
      if (!_keyPattern.hasMatch(key)) {
        errors.add('$where.key "$key" must be lowercase kebab-case');
      }
      if (key == 'custom') errors.add('$where.key "custom" is reserved');
      if (!seenKeys.add(key)) errors.add('duplicate product key "$key"');
    }

    final grams = _positiveNumber(
      raw['gramsPerLiter'],
      '$where.gramsPerLiter',
      errors,
    );
    final basis = raw['basis'];
    if (basis is! String || !_basisNames.contains(basis)) {
      errors.add('$where.basis must be one of ${_basisNames.join('/')}');
    }

    final reference = raw['referenceSalinity'];
    double? referenceValue;
    String? referenceUnit;
    if (reference is! YamlMap) {
      errors.add('$where.referenceSalinity must be a value/unit map');
    } else {
      for (final field in reference.keys) {
        if (field != 'value' && field != 'unit') {
          errors.add('$where.referenceSalinity: unknown field "$field"');
        }
      }
      referenceValue = _positiveNumber(
        reference['value'],
        '$where.referenceSalinity.value',
        errors,
      );
      final unit = reference['unit'];
      if (unit != 'ppt' && unit != 'sg') {
        errors.add('$where.referenceSalinity.unit must be ppt or sg');
      } else {
        referenceUnit = unit as String;
        if (referenceValue != null &&
            ((unit == 'ppt' && referenceValue > 100) ||
                (unit == 'sg' &&
                    (referenceValue <= 1 || referenceValue > 1.2)))) {
          errors.add('$where.referenceSalinity value is outside its unit');
        }
      }
    }

    final sourceUrl = _nonBlank(raw['sourceUrl'], '$where.sourceUrl', errors);
    if (sourceUrl != null) {
      final uri = Uri.tryParse(sourceUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        errors.add('$where.sourceUrl must be an absolute HTTPS URL');
      }
    }
    final verifiedOn = _nonBlank(
      raw['verifiedOn'],
      '$where.verifiedOn',
      errors,
    );
    DateTime? verifiedDate;
    if (verifiedOn != null) {
      verifiedDate = DateTime.tryParse(verifiedOn);
      if (!_datePattern.hasMatch(verifiedOn) ||
          verifiedDate == null ||
          _isoDate(verifiedDate) != verifiedOn) {
        errors.add('$where.verifiedOn must be a real YYYY-MM-DD date');
      }
    }

    if ([
      key,
      brand,
      name,
      grams,
      basis is String && _basisNames.contains(basis) ? basis : null,
      referenceValue,
      referenceUnit,
      sourceUrl,
      verifiedDate,
    ].contains(null)) {
      continue;
    }
    final referenceExpression = referenceUnit == 'sg'
        ? 'sgToPpt(${_number(referenceValue!)})'
        : _number(referenceValue!);
    emitted.add('''
  SaltMixProduct(
    key: '${_escape(key!)}',
    brand: '${_escape(brand!)}',
    name: '${_escape(name!)}',
    gramsPerLiter: ${_number(grams!)},
    referencePpt: $referenceExpression,
    basis: SaltMixSeedBasis.$basis,
    sourceUrl: '${_escape(sourceUrl!)}',
    verifiedOn: DateTime(${verifiedDate!.year}, ${verifiedDate.month}, ${verifiedDate.day}),
  ),''');
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Salt-mix catalogue validation failed — nothing written:');
    for (final error in errors) {
      stderr.writeln('  - $error');
    }
    exit(1);
  }

  final output = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: salt_mixes.yaml')
    ..writeln('// Regenerate: dart run tool/gen_salt_mixes.dart')
    ..writeln('')
    ..writeln("part of 'salt_mix_catalog.dart';")
    ..writeln('')
    ..writeln('/// The built-in salt-mix catalogue, generated from')
    ..writeln('/// `salt_mixes.yaml`; listing order is picker order.')
    ..writeln('final List<SaltMixProduct> kSaltMixProducts = [')
    ..writeAll(emitted)
    ..writeln('];');
  File(_outPath).writeAsStringSync(output.toString());
  final format = Process.runSync('dart', [
    'format',
    _outPath,
  ], runInShell: true);
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed:\n${format.stderr}');
    exit(1);
  }
  stdout.writeln('Wrote $_outPath (${products.length} products).');
}

String? _nonBlank(dynamic value, String where, List<String> errors) {
  if (value is! String || value.trim().isEmpty) {
    errors.add('$where must be a non-blank string');
    return null;
  }
  return value;
}

double? _positiveNumber(dynamic value, String where, List<String> errors) {
  if (value is! num) {
    errors.add('$where must be a number');
    return null;
  }
  final number = value.toDouble();
  if (!number.isFinite || number <= 0) {
    errors.add('$where must be positive and finite');
    return null;
  }
  return number;
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
