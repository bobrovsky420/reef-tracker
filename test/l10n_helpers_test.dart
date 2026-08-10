import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:reeftracker/domain/clock.dart';
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

  group('relativeTimeLabel buckets', () {
    final now = DateTime(2026, 7, 22, 14, 5);
    final en = lookupAppLocalizations(const Locale('en'));

    String labelAt(Duration age, {AppLocalizations? l}) =>
        relativeTimeLabel(l ?? en, now.subtract(age), now: now);

    test('each bucket switches at its exact boundary', () {
      // The buckets truncate (`inMinutes`/`inHours`/`inDays`), so every
      // boundary is "last second of the old label, first second of the new".
      expect(labelAt(Duration.zero), 'just now');
      expect(labelAt(const Duration(seconds: 59)), 'just now');
      expect(labelAt(const Duration(minutes: 1)), '1 min ago');

      expect(labelAt(const Duration(minutes: 59, seconds: 59)), '59 min ago');
      expect(labelAt(const Duration(minutes: 60)), '1 h ago');

      expect(labelAt(const Duration(hours: 23, minutes: 59)), '23 h ago');
      expect(labelAt(const Duration(hours: 24)), '1 d ago');

      expect(
        labelAt(const Duration(days: 6, hours: 23, minutes: 59)),
        '6 d ago',
      );
      // At exactly a week the relative label gives up and prints a date.
      expect(
        labelAt(const Duration(days: 7)),
        DateFormat.yMMMd().format(now.subtract(const Duration(days: 7))),
      );
    });

    test('a future timestamp clamps to "just now", never a negative span', () {
      // ageSince clamps; a device whose clock moved backwards after a reading
      // was saved must not render "-3 min ago".
      expect(
        relativeTimeLabel(en, now.add(const Duration(hours: 3)), now: now),
        'just now',
      );
      expect(
        relativeTimeLabel(en, now.add(const Duration(days: 30)), now: now),
        'just now',
      );
    });

    test('daysSince < 7 always renders a relative label, in every locale', () {
      // tanks_screen.dart's _LastTestedLine wraps this in "Last tested {ago}"
      // whenever `daysSince(at) < 7`. daysSince ROUNDS while the buckets
      // TRUNCATE, so the two only line up by argument: if a rounded 6 could
      // ever meet a truncated 7, the tile would read "Last tested Jul 15,
      // 2026 ago" — in all seven languages.
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (var hours = 0; hours <= 24 * 10; hours++) {
          final at = now.subtract(Duration(hours: hours));
          final label = relativeTimeLabel(l, at, now: now);
          final isDate = label == DateFormat.yMMMd().format(at);
          if (daysSince(at, now: now) < 7) {
            expect(
              isDate,
              isFalse,
              reason:
                  'daysSince=${daysSince(at, now: now)} at ${hours}h still '
                  'takes the "Last tested {ago}" path ($locale) but got the '
                  'absolute date "$label"',
            );
          } else {
            // The converse keeps the switch from firing early: the plain date
            // may only appear once the tile has stopped asking for it.
            expect(
              daysSince(at, now: now),
              greaterThanOrEqualTo(7),
              reason: 'absolute date at ${hours}h ($locale)',
            );
          }
        }
      }
    });

    test('omitting `now` falls back to the wall clock', () {
      // The seam is opt-in: the eight production call sites pass no `now`.
      expect(relativeTimeLabel(en, DateTime.now()), 'just now');
      expect(
        relativeTimeLabel(
          en,
          DateTime.now().subtract(const Duration(hours: 5)),
        ),
        '5 h ago',
      );
    });
  });

  group('formatWeekdays (ISO 1..7 → Sunday-first narrowWeekdays)', () {
    /// Renders through the real widget tree: `formatWeekdays` reads
    /// `MaterialLocalizations`, so the only honest way to ask it anything is
    /// from a context under a `MaterialApp` at the locale under test.
    Future<String Function(Iterable<int>)> weekdaysAt(
      WidgetTester tester,
      String languageCode,
    ) async {
      late BuildContext captured;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
        locale: Locale(languageCode),
      );
      return (Iterable<int> days) => formatWeekdays(captured, days);
    }

    // The whole ISO week, written out by hand per language from the day names
    // themselves — Monday first, Sunday last. Hardcoded on purpose: deriving
    // the expectation from `narrowWeekdays[...]` would restate the very index
    // arithmetic under test (a 1-based ISO weekday indexing a 0-based
    // Sunday-first array), so an off-by-one would survive it.
    const fullWeek = <String, String>{
      // Mon Tue Wed Thu Fri Sat Sun
      'en': 'M, T, W, T, F, S, S',
      'cs': 'P, Ú, S, Č, P, S, N',
      'de': 'M, D, M, D, F, S, S',
      'fr': 'L, M, M, J, V, S, D',
      'it': 'L, M, M, G, V, S, D',
      // Polish narrow weekdays are lowercase in CLDR, unlike every other
      // language here — copied as the data gives them, not title-cased.
      'pl': 'p, w, ś, c, p, s, n',
      // Russian narrow weekdays are single Cyrillic letters, not the two-letter
      // "пн/вт" abbreviations — понедельник, вторник, среда, четверг, пятница,
      // суббота, воскресенье.
      'ru': 'П, В, С, Ч, П, С, В',
    };

    testWidgets('the full week reads Monday → Sunday in every locale', (
      tester,
    ) async {
      for (final entry in fullWeek.entries) {
        final formatWeek = await weekdaysAt(tester, entry.key);
        expect(
          formatWeek(const [1, 2, 3, 4, 5, 6, 7]),
          entry.value,
          reason: 'ISO 1..7 must render Mon..Sun (${entry.key})',
        );
      }
    });

    testWidgets('Sunday (ISO 7) folds onto the Sunday name, not off the end', (
      tester,
    ) async {
      // The `% 7` in the implementation is the whole trick: ISO 7 has to reach
      // index 0. Asserted in the two languages whose Sunday letter is unique —
      // in en/de/fr/it/ru Sunday shares its narrow letter with Saturday or
      // Tuesday, so those would pass under a wrong fold too.
      for (final (locale, sunday, monday) in const [
        ('cs', 'N', 'P'),
        ('pl', 'n', 'p'),
      ]) {
        final formatWeek = await weekdaysAt(tester, locale);
        expect(formatWeek(const [7]), sunday, reason: 'Sunday ($locale)');
        expect(formatWeek(const [1]), monday, reason: 'Monday ($locale)');
      }
    });

    testWidgets('days render in ascending ISO order whatever order they '
        'arrive in', (tester) async {
      // The dosing rows hand over whatever set the user checked, in tap order;
      // the schedule subtitles hand over a stored set. Both must read as a
      // week.
      final formatWeek = await weekdaysAt(tester, 'cs');
      // Sunday, Thursday, Monday → Mon, Thu, Sun.
      expect(formatWeek(const [7, 4, 1]), 'P, Č, N');
      expect(formatWeek(const [1, 4, 7]), 'P, Č, N');
      // Weekend, given backwards.
      expect(formatWeek(const [7, 6]), 'S, N');
    });

    testWidgets('no days renders as nothing at all', (tester) async {
      final formatWeek = await weekdaysAt(tester, 'en');
      expect(formatWeek(const <int>[]), isEmpty);
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
