import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/csv_export.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/units.dart';

/// Routes path_provider (used by the export share flow) to a temp folder so
/// it works under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  group('encodeReadingsCsv', () {
    TrackedParameter param(String key, String unit) => TrackedParameter(
      id: 1,
      tankId: 1,
      paramKey: key,
      unit: unit,
      enabled: true,
      displayOrder: 0,
      amberLow: null,
      greenLow: null,
      greenHigh: null,
      amberHigh: null,
    );
    Reading reading(String key, double value, {DateTime? at, String? note}) =>
        Reading(
          id: 1,
          tankId: 1,
          paramKey: key,
          value: value,
          takenAt: at ?? DateTime(2026, 7, 5, 14, 30, 7),
          note: note,
        );

    test('emits RFC 4180 rows: header, CRLF, local timestamp, precision', () {
      final csv = encodeReadingsCsv(
        readings: [
          reading('alkalinity', 8.2, at: DateTime(2026, 1, 2, 8, 5)),
          reading('calcium', 420.4, note: 'after dosing'),
        ],
        params: [param('alkalinity', 'dKH'), param('calcium', 'ppm')],
        prefs: const UnitPrefs(),
      );
      expect(csv.split('\r\n'), [
        'taken_at,parameter,value,unit,note',
        '2026-01-02 08:05:00,alkalinity,8.2,dKH,',
        '2026-07-05 14:30:07,calcium,420,ppm,after dosing',
        '',
      ]);
    });

    test('quotes and escapes fields with delimiters, quotes and newlines', () {
      final csv = encodeReadingsCsv(
        readings: [reading('nitrate', 5.0, note: 'salt "AB", batch 2\nredose')],
        params: [param('nitrate', 'ppm')],
        prefs: const UnitPrefs(),
      );
      expect(csv, contains('"salt ""AB"", batch 2\nredose"'));
    });

    test('neutralizes notes starting with spreadsheet formula characters', () {
      final csv = encodeReadingsCsv(
        readings: [
          reading('nitrate', 5.0, note: '=1+2'),
          reading('nitrate', 5.0, note: '@SUM(A1:A9)'),
          reading('nitrate', 5.0, note: '+0.5 after dosing'),
          reading('nitrate', 5.0, note: '-0.3 vs last week'),
          reading('nitrate', 5.0, note: '=HYPERLINK("http://evil",A1)'),
        ],
        params: [param('nitrate', 'ppm')],
        prefs: const UnitPrefs(),
      );
      expect(csv, contains(",'=1+2\r\n"));
      expect(csv, contains(",'@SUM(A1:A9)\r\n"));
      expect(csv, contains(",'+0.5 after dosing\r\n"));
      expect(csv, contains(",'-0.3 vs last week\r\n"));
      // Neutralization composes with RFC 4180 quoting/escaping.
      expect(csv, contains(',"\'=HYPERLINK(""http://evil"",A1)"\r\n'));
      // The numeric value column stays untouched (a plain number, not text).
      expect(csv, contains(',nitrate,5.0,ppm,'));
    });

    test('converts temperature and salinity to the preferred display unit', () {
      final readings = [
        reading('temperature', 25.0),
        reading('salinity', 1.0264),
      ];
      final params = [param('temperature', '°C'), param('salinity', 'SG')];

      final metric = encodeReadingsCsv(
        readings: readings,
        params: params,
        prefs: const UnitPrefs(salinity: SalinityUnit.sg),
      );
      expect(metric, contains(',temperature,25.0,°C,'));
      expect(metric, contains(',salinity,1.026,SG,'));

      final imperial = encodeReadingsCsv(
        readings: readings,
        params: params,
        prefs: const UnitPrefs(temp: TempUnit.fahrenheit),
      );
      expect(imperial, contains(',temperature,77.0,°F,'));
      // Default salinity preference is ppt.
      expect(imperial, contains(',salinity,35.0,ppt,'));
    });

    test('falls back to the catalog unit for readings without a tracked row', () {
      final csv = encodeReadingsCsv(
        readings: [reading('magnesium', 1300), reading('mystery', 1.5)],
        params: const [],
        prefs: const UnitPrefs(),
      );
      // Removed tracked parameter -> catalog default unit; unknown key -> none.
      expect(csv, contains(',magnesium,1300,ppm,'));
      expect(csv, contains(',mystery,1.50,,'));
    });
  });

  group('exportReadingsCsv', () {
    late Directory tempDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('reeftracker-csv-');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

    List<String> csvFilesIn(Directory dir) => dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where(
          (n) => n.startsWith('reeftracker-readings-') && n.endsWith('.csv'),
        )
        .toList();

    test('getReadingsForTank returns readings oldest first', () async {
      final db = newDb();
      addTearDown(db.close);
      final id = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db.insertReadingGroup(
        tankId: id,
        takenAt: DateTime(2026, 2, 1),
        values: const [(paramKey: 'ph', value: 8.1)],
      );
      await db.insertReadingGroup(
        tankId: id,
        takenAt: DateTime(2026, 1, 1),
        values: const [(paramKey: 'ph', value: 8.0)],
      );

      final rows = await db.getReadingsForTank(id);
      expect(rows.map((r) => r.value), [8.0, 8.1]);
    });

    test(
      'returns false and stages nothing for a tank without readings',
      () async {
        final db = newDb();
        addTearDown(db.close);
        final id = await db.createTankWithPreset(
          name: 'Empty',
          type: SetupType.mixed,
        );

        final shared = await exportReadingsCsv(
          db,
          tankId: id,
          tankName: 'Empty',
          prefs: const UnitPrefs(),
        );

        expect(shared, isFalse);
        expect(csvFilesIn(tempDir), isEmpty);
      },
    );

    test(
      'leaves no plaintext temp file and sweeps stale CSV exports',
      () async {
        final db = newDb();
        addTearDown(db.close);
        final id = await db.createTankWithPreset(
          name: 'Reef',
          type: SetupType.mixed,
        );
        await db.insertReadingGroup(
          tankId: id,
          takenAt: DateTime(2026, 1, 1, 8),
          values: const [(paramKey: 'alkalinity', value: 8.5)],
        );

        // A leftover CSV export from an earlier run that must be swept.
        await File(
          p.join(tempDir.path, 'reeftracker-readings-stale.csv'),
        ).writeAsString('x');

        // The share sheet is unavailable under `flutter test`; the cleanup in
        // the finally must still delete the freshly written file regardless.
        try {
          await exportReadingsCsv(
            db,
            tankId: id,
            tankName: 'Reef',
            prefs: const UnitPrefs(),
          );
        } catch (_) {}

        expect(csvFilesIn(tempDir), isEmpty);
      },
    );
  });
}
