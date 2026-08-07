import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/l10n/l10n_helpers.dart';

import 'support/pump.dart';

void main() {
  final initial = DateTime(2026, 6, 1, 10, 30);

  group('paramName ↔ parameter catalog', () {
    test('every catalog key resolves to a real name in every locale', () {
      // paramName is a hand-written switch over the generated catalog with
      // `default: return key` — a parameter added to parameters.yaml without
      // a switch case (or without its ARB keys) ships its raw key as the
      // display name, in every language, silently.
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (final def in kReefParameters) {
          final name = l.paramName(def.key);
          expect(
            name,
            isNot(def.key),
            reason:
                'paramName("${def.key}") fell through to the raw key '
                '($locale) — switch case or ARB key missing',
          );
          expect(name.trim(), isNotEmpty);
        }
      }
    });

    test('symbol-carrying parameters keep the "(Symbol)" convention '
        'in every locale', () {
      // Micro rows match an ICP report by their element symbol, and
      // paramShortName extracts the dial label from the parenthetical — a
      // translation that drops or localizes the symbol breaks both.
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (final def in kReefParameters) {
          final symbol = def.symbol;
          if (symbol == null) continue;
          expect(
            l.paramName(def.key),
            contains('($symbol)'),
            reason: '"${def.key}" must carry "($symbol)" ($locale)',
          );
          expect(l.paramShortName(def.key), symbol);
        }
      }
    });
  });

  group('paramShortName (REDESIGN #7 dial labels)', () {
    test('a dedicated short name wins in every locale (alkalinity → KH)', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        expect(
          l.paramShortName('alkalinity'),
          'KH',
          reason: 'alkalinity dial label must be the dedicated KH ($locale)',
        );
      }
    });

    test('otherwise the "(Symbol)" parenthetical is extracted in every '
        'locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        expect(
          l.paramShortName('calcium'),
          'Ca',
          reason: 'calcium dial label is the extracted symbol ($locale)',
        );
        // Ammonia's parenthetical carries subscripts/slashes — extracted
        // whole, braces dropped.
        expect(l.paramShortName('ammonia'), isNotEmpty);
        expect(l.paramShortName('ammonia'), isNot(contains('(')));
      }
    });

    test('names with neither pass through unchanged', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(l.paramShortName('temperature'), 'Temperature');
      expect(l.paramShortName('ph'), 'pH');
      // Unknown keys fall back to the key itself, like paramName.
      expect(l.paramShortName('custom_key'), 'custom_key');
    });
  });

  /// Pumps a button that runs [pickPastDateTime] and records its result.
  Future<void Function()> pumpPicker(
    WidgetTester tester,
    void Function(DateTime? result) onResult,
  ) async {
    late void Function() open;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          open = () async => onResult(await pickPastDateTime(context, initial));
          return TextButton(onPressed: open, child: const Text('pick'));
        },
      ),
    );
    return open;
  }

  testWidgets('confirming both steps returns the composed date and time', (
    tester,
  ) async {
    DateTime? result;
    var completed = false;
    await pumpPicker(tester, (r) {
      result = r;
      completed = true;
    });

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date step
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time step
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, initial);
  });

  testWidgets('cancelling the time step aborts instead of recording midnight', (
    tester,
  ) async {
    DateTime? result;
    var completed = false;
    await pumpPicker(tester, (r) {
      result = r;
      completed = true;
    });

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirm the date step
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // cancel the time step (#16)
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });
}
