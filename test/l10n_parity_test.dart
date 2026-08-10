/// Machine enforcement of the project's localization contract (CLAUDE.md):
/// seven hand-maintained ARB files that must never drift apart. A dropped key
/// is a silent English fallback at runtime; a dropped ICU placeholder renders
/// a hole in the sentence ("Based on pH , and ."); stale template metadata
/// breaks `flutter gen-l10n`'s argument typing.
///
/// The files are read from disk, so this also catches a hand-edit that was
/// never run through gen-l10n.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Language codes of every ARB file, template first (mirrors l10n.yaml).
const List<String> kArbLanguages = ['en', 'cs', 'de', 'ru', 'pl', 'fr', 'it'];

void main() {
  final arbs = <String, Map<String, dynamic>>{
    for (final lang in kArbLanguages)
      lang:
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>,
  };
  final template = arbs['en']!;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final templateKeys = messageKeys(template);

  test('the ARB set covers exactly the supported locales', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      kArbLanguages.toSet(),
    );
    for (final lang in kArbLanguages) {
      expect(arbs[lang]!['@@locale'], lang, reason: 'app_$lang.arb @@locale');
    }
  });

  test('every language defines exactly the template keys', () {
    for (final lang in kArbLanguages.skip(1)) {
      final keys = messageKeys(arbs[lang]!);
      expect(
        templateKeys.difference(keys),
        isEmpty,
        reason: 'app_$lang.arb is missing keys (silent English fallback)',
      );
      expect(
        keys.difference(templateKeys),
        isEmpty,
        reason: 'app_$lang.arb has keys the template does not',
      );
    }
  });

  test('every message is a non-empty string in every language', () {
    for (final lang in kArbLanguages) {
      final arb = arbs[lang]!;
      for (final key in messageKeys(arb)) {
        final value = arb[key];
        expect(value, isA<String>(), reason: 'app_$lang.arb "$key"');
        expect(
          (value as String).trim(),
          isNotEmpty,
          reason: 'app_$lang.arb "$key" is blank',
        );
      }
    }
  });

  test('template metadata declares exactly the placeholders each message '
      'references', () {
    for (final key in templateKeys) {
      final referenced = referencedIcuArgs(template[key] as String);
      final meta = template['@$key'] as Map<String, dynamic>?;
      final declared =
          ((meta?['placeholders'] as Map<String, dynamic>?) ?? const {}).keys
              .toSet();
      expect(
        referenced,
        declared,
        reason:
            '"$key": message references $referenced but @$key declares '
            '$declared',
      );
    }
  });

  test('every translation uses exactly the template\'s ICU arguments', () {
    for (final key in templateKeys) {
      final expected = referencedIcuArgs(template[key] as String);
      for (final lang in kArbLanguages.skip(1)) {
        final value = arbs[lang]![key];
        if (value is! String) continue; // covered by the key-set test
        expect(
          referencedIcuArgs(value),
          expected,
          reason:
              'app_$lang.arb "$key" drops or invents a placeholder '
              '(template uses $expected)',
        );
      }
    }
  });
}

/// The set of ICU argument names a message references, via a minimal ICU
/// MessageFormat scan. A naive `{word}` regex would misread one-word plural
/// *branch contents* (cs "one{den}") as arguments; this walks the real
/// structure instead: an argument is `{name}` or `{name, type, ...}`, and only
/// plural/select branch bodies are re-entered as nested messages.
Set<String> referencedIcuArgs(String message) {
  final args = <String>{};
  _scanMessage(message, 0, args);
  return args;
}

final _idChar = RegExp(r'[A-Za-z0-9_]');

/// Scans message text from [i], collecting into [out]; returns the index of
/// the `}` closing the enclosing branch, or the end of the string.
int _scanMessage(String s, int i, Set<String> out) {
  while (i < s.length) {
    final c = s[i];
    if (c == '}') return i;
    if (c == '{') {
      i = _scanArg(s, i + 1, out);
    } else {
      i++;
    }
  }
  return i;
}

/// Scans one argument starting just past its `{`; returns the index just past
/// its closing `}`.
int _scanArg(String s, int i, Set<String> out) {
  final nameStart = i;
  while (i < s.length && _idChar.hasMatch(s[i])) {
    i++;
  }
  out.add(s.substring(nameStart, i));
  while (i < s.length && s[i].trim().isEmpty) {
    i++;
  }
  if (i >= s.length) return i;
  if (s[i] == '}') return i + 1; // simple `{name}`

  // Complex `{name, type ...}` — read the type word.
  if (s[i] != ',') {
    throw FormatException('expected "," or "}" in ICU argument', s, i);
  }
  i++;
  while (i < s.length && s[i].trim().isEmpty) {
    i++;
  }
  final typeStart = i;
  while (i < s.length && _idChar.hasMatch(s[i])) {
    i++;
  }
  final type = s.substring(typeStart, i);
  while (i < s.length && s[i].trim().isEmpty) {
    i++;
  }
  if (i >= s.length) return i;
  if (s[i] == '}') return i + 1; // e.g. `{count, number}`
  if (s[i] == ',') i++;

  if (type == 'plural' || type == 'select' || type == 'selectordinal') {
    // Branches: `selector {message}` repeated until the arg's own `}`.
    while (i < s.length) {
      while (i < s.length && s[i] != '{' && s[i] != '}') {
        i++; // selector / offset text
      }
      if (i >= s.length || s[i] == '}') return i + 1;
      i = _scanMessage(s, i + 1, out); // branch body — nested args count
      i++; // past the branch's `}`
    }
    return i;
  }
  // Other styles (date/number formats): skip to the matching `}`.
  var depth = 1;
  while (i < s.length && depth > 0) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') depth--;
    i++;
  }
  return i;
}
