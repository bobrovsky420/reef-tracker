import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/hanna_import.dart';

/// Trimmed from a real Hanna Lab export (HI97115, 2026-07): preamble, BOM,
/// newest-first rows, a full test session, exact-duplicate rows (the app
/// repeats some log entries 3×), an under-range row, and an unmapped method.
const _hannaCsv =
    '\u{FEFF}Meter,HI97115\n'
    'Meter ID,06150128\n'
    'Meter Serial Number,906150128111\n'
    'Meter Firmware,v1.07\n'
    'Sample Location,200G2\n'
    '\n'
    'Reading,Unit,Method,Date,Status,Note\n'
    '0.18,ppm PO₄³⁻,Phosphate Marine ULR,19/07/2026 13:38:13,,\n'
    '11.9,ppm NO₃⁻,Nitrate Marine HR,19/07/2026 13:32:45,,\n'
    '1355,ppm Mg²⁺,Magnesium Marine,19/07/2026 13:22:20,,\n'
    '417,ppm Ca²⁺,Calcium Marine,19/07/2026 13:15:36,,\n'
    '7.6,dKH,Alkalinity Marine,19/07/2026 13:08:57,,\n'
    '8.3,pH,pH Marine,19/07/2026 13:07:38,,\n'
    '0.30,ppm NH₃,Ammonia Marine,10/12/2025 13:37:11,,\n'
    '0.30,ppm NH₃,Ammonia Marine,10/12/2025 13:37:11,,\n'
    '0.30,ppm NH₃,Ammonia Marine,10/12/2025 13:37:11,,\n'
    '<200,ppm Ca²⁺,Calcium Marine,24/01/2026 10:55:07,Under Range. Check Sample/Prep.,\n'
    '450,ppm,Chloride,05/01/2026 09:00:00,,\n';

void main() {
  group('parseHannaCsv', () {
    test('reads preamble, maps methods, sorts oldest first', () {
      final r = parseHannaCsv(_hannaCsv);
      expect(r.meter, 'HI97115');
      expect(r.location, '200G2');
      // 6-reading session + 1 deduped ammonia row.
      expect(r.rows, hasLength(7));
      // Chronological regardless of the file's newest-first order.
      expect(r.rows.first.paramKey, 'ammonia');
      expect(r.rows.first.value, 0.30);
      expect(r.rows.first.takenAt, DateTime(2025, 12, 10, 13, 37, 11));
      expect(r.rows.last.paramKey, 'phosphate');
      expect(r.rows.last.takenAt, DateTime(2026, 7, 19, 13, 38, 13));
      final byKey = {for (final row in r.rows) row.paramKey: row.value};
      expect(byKey, {
        'ammonia': 0.30,
        'phosphate': 0.18,
        'nitrate': 11.9,
        'magnesium': 1355,
        'calcium': 417,
        'alkalinity': 7.6,
        'ph': 8.3,
      });
    });

    test('collapses exact in-file duplicates, first occurrence wins', () {
      final r = parseHannaCsv(_hannaCsv);
      expect(r.rows.where((x) => x.paramKey == 'ammonia'), hasLength(1));
    });

    test('skips flagged and unmapped rows with the right reasons', () {
      final r = parseHannaCsv(_hannaCsv);
      expect(r.skipped, hasLength(2));
      final byLabel = {for (final s in r.skipped) s.label: s.reason};
      expect(byLabel['Calcium Marine'], HannaSkipReason.outOfRange);
      expect(byLabel['Chloride'], HannaSkipReason.unknownTest);
    });

    test('maps method range variants and orders phosphate before ph', () {
      expect(hannaMethodKey('Phosphate Marine ULR'), 'phosphate');
      expect(hannaMethodKey('Phosphate Marine HR'), 'phosphate');
      expect(hannaMethodKey('pH Marine'), 'ph');
      expect(hannaMethodKey('Nitrate Marine LR'), 'nitrate');
      expect(hannaMethodKey('Nitrite Marine LR'), 'nitrite');
      expect(hannaMethodKey('Silica Marine'), isNull);
    });

    test('converts a ppb nitrite LR row to canonical ppm', () {
      const csv =
          'Meter,HI97115\n'
          'Reading,Unit,Method,Date,Status,Note\n'
          '15,ppb NO₂⁻,Nitrite Marine LR,19/07/2026 13:08:57,,\n';
      final r = parseHannaCsv(csv);
      expect(r.rows.single.paramKey, 'nitrite');
      expect(r.rows.single.value, closeTo(0.015, 1e-9));
    });

    test('rejects a ppm-unit nitrite row (the checker exports ppb)', () {
      const csv =
          'Meter,HI97115\n'
          'Reading,Unit,Method,Date,Status,Note\n'
          '0.015,ppm NO₂⁻,Nitrite Marine LR,19/07/2026 13:08:57,,\n';
      final r = parseHannaCsv(csv);
      expect(r.rows, isEmpty);
      expect(r.skipped.single.reason, HannaSkipReason.unknownTest);
    });

    test('rejects a wrong-unit row instead of guessing a conversion', () {
      // A checker configured to ppm CaCO₃ alkalinity must not import as dKH.
      const csv =
          'Meter,HI97115\n'
          'Reading,Unit,Method,Date,Status,Note\n'
          '143,ppm CaCO₃,Alkalinity Marine,19/07/2026 13:08:57,,\n';
      final r = parseHannaCsv(csv);
      expect(r.rows, isEmpty);
      expect(r.skipped.single.reason, HannaSkipReason.unknownTest);
    });

    test('self-disambiguates a month-first export via day > 12', () {
      const csv =
          'Meter,HI97115\n'
          'Reading,Unit,Method,Date,Status,Note\n'
          '8.1,dKH,Alkalinity Marine,07/19/2026 10:00:00,,\n';
      final r = parseHannaCsv(csv);
      expect(r.rows.single.takenAt, DateTime(2026, 7, 19, 10, 0, 0));
    });

    test('rejects an impossible date row as badValue', () {
      const csv =
          'Meter,HI97115\n'
          'Reading,Unit,Method,Date,Status,Note\n'
          '8.1,dKH,Alkalinity Marine,31/04/2026 10:00:00,,\n';
      final r = parseHannaCsv(csv);
      expect(r.rows, isEmpty);
      expect(r.skipped.single.reason, HannaSkipReason.badValue);
    });

    test('throws wrongFormat for a non-Hanna CSV', () {
      expect(
        () => parseHannaCsv('Date,Measurement,Value\n2026-01-01,pH,8.1\n'),
        throwsA(
          isA<HannaImportException>().having(
            (e) => e.reason,
            'reason',
            HannaImportRejection.wrongFormat,
          ),
        ),
      );
    });

    test('throws noValues for a header-only export', () {
      expect(
        () => parseHannaCsv(
          'Meter,HI97115\nReading,Unit,Method,Date,Status,Note\n',
        ),
        throwsA(
          isA<HannaImportException>().having(
            (e) => e.reason,
            'reason',
            HannaImportRejection.noValues,
          ),
        ),
      );
    });
  });

  group('hannaSessions', () {
    test('splits on gaps over the window, keeps a spread session together', () {
      final r = parseHannaCsv(_hannaCsv);
      final sessions = hannaSessions(r.rows);
      // Dec 2025 ammonia alone; the Jul 2026 six-test run (13:07–13:38) as
      // one session.
      expect(sessions, hasLength(2));
      expect(sessions.first.single.paramKey, 'ammonia');
      expect(sessions.last, hasLength(6));
    });

    test('chains readings: each gap counts from the previous reading', () {
      HannaReading at(String key, int hour, int minute) => HannaReading(
        paramKey: key,
        value: 8,
        takenAt: DateTime(2026, 1, 1, hour, minute),
      );
      // 10:00 → 11:20 → 12:40 — each hop 80 min ≤ the 90-min window, so one
      // session even though the total span (160 min) exceeds it.
      final rows = [
        at('alkalinity', 10, 0),
        at('ph', 11, 20),
        at('calcium', 12, 40),
      ];
      expect(hannaSessions(rows), hasLength(1));
      // 10:00 → 13:00 breaks the chain.
      final split = [at('alkalinity', 10, 0), at('ph', 13, 0)];
      expect(hannaSessions(split), hasLength(2));
    });
  });

  group('planHannaImport', () {
    final rows = parseHannaCsv(_hannaCsv).rows;

    test('normal import takes strictly newer than the watermark', () {
      final plan = planHannaImport(
        rows: rows,
        importedUpTo: DateTime(2026, 7, 19, 13, 8, 57),
      );
      // The 13:08:57 alkalinity row itself is already imported (strict >).
      expect(plan.newRows.map((r) => r.paramKey), [
        'calcium',
        'magnesium',
        'nitrate',
        'phosphate',
      ]);
      expect(plan.alreadyImported, 3);
      expect(plan.beforeCutoff, 0);
    });

    test('first import honors the cutoff, inclusive of the day itself', () {
      final plan = planHannaImport(rows: rows, cutoff: DateTime(2026, 7, 19));
      expect(plan.newRows, hasLength(6));
      expect(plan.beforeCutoff, 1); // the Dec 2025 ammonia row
      expect(plan.alreadyImported, 0);
    });

    test('first import with no cutoff takes everything', () {
      final plan = planHannaImport(rows: rows);
      expect(plan.newRows, hasLength(rows.length));
    });

    test('a rewound import diffs against existing readings', () {
      final plan = planHannaImport(
        rows: rows,
        importedUpTo: DateTime(2026, 7, 1),
        rewound: true,
        existingKeys: {
          hannaReadingKey('ph', DateTime(2026, 7, 19, 13, 7, 38)),
          hannaReadingKey('alkalinity', DateTime(2026, 7, 19, 13, 8, 57)),
        },
      );
      expect(plan.newRows, hasLength(4));
      expect(plan.alreadyImported, 3); // 1 pre-watermark + 2 diff-matched
    });

    test('without the rewound flag existing keys are ignored', () {
      final plan = planHannaImport(
        rows: rows,
        importedUpTo: DateTime(2026, 7, 1),
        existingKeys: {hannaReadingKey('ph', DateTime(2026, 7, 19, 13, 7, 38))},
      );
      expect(plan.newRows, hasLength(6));
    });
  });
}
