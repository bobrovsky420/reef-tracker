import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/data/tank_summary_export.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

/// Tests for the "Ask your AI" summary export (U27): the collector's
/// windowing/empty rules against an in-memory DB, and the encoder's document
/// structure (en locale via [lookupAppLocalizations] — no widgets needed).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l = lookupAppLocalizations(const Locale('en'));
  const prefs = UnitPrefs(
    temp: TempUnit.celsius,
    salinity: SalinityUnit.ppt,
    volume: VolumeUnit.liters,
  );
  final now = DateTime(2026, 7, 15, 12);

  Future<AppDatabase> memDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Future<int> seedTank(AppDatabase db) => db.createTankWithPreset(
    name: 'Display Reef',
    type: SetupType.mixed,
    volumeLiters: 300,
    startDate: DateTime(2025, 6, 1),
  );

  group('collectTankSummary', () {
    test('returns null for a tank with no readings', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      expect(
        await collectTankSummary(db, tankId: tank, weeks: 8, now: now),
        isNull,
      );
    });

    test('returns null for an unknown tank', () async {
      final db = await memDb();
      expect(
        await collectTankSummary(db, tankId: 999, weeks: 8, now: now),
        isNull,
      );
    });

    test('windows readings and actions; keeps older micro values', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      // Inside the 4-week window.
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: 8.0,
        takenAt: now.subtract(const Duration(days: 3)),
      );
      // Outside the window: excluded from the table but still the trend/
      // health feed's business (collector uses the recent-per-param head).
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: 8.4,
        takenAt: now.subtract(const Duration(days: 60)),
      );
      // Micro element measured 2 months ago: included regardless of window.
      await db.addTrackedParameter(tank, 'copper', SetupType.mixed);
      await db.insertReading(
        tankId: tank,
        paramKey: 'copper',
        value: 0.004,
        takenAt: now.subtract(const Duration(days: 60)),
      );
      // One action in the window, one before it.
      await db.insertWaterChange(
        tankId: tank,
        changedAt: now.subtract(const Duration(days: 5)),
        amountLiters: 30,
      );
      await db.insertWaterChange(
        tankId: tank,
        changedAt: now.subtract(const Duration(days: 90)),
        amountLiters: 45,
      );

      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 4,
        now: now,
      ))!;

      final alk = data.params.singleWhere(
        (p) => p.param.paramKey == 'alkalinity',
      );
      expect(alk.windowed, hasLength(1));
      expect(alk.windowed.single.value, 8.0);
      expect(alk.latest!.value, 8.0);

      expect(data.micro, hasLength(1));
      expect(data.micro.single.paramKey, 'copper');

      expect(data.waterChanges, hasLength(1));
      expect(data.waterChanges.single.amountLiters, 30);
    });
  });

  group('encodeTankSummary', () {
    test('renders the full document structure', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      // A declining alkalinity series (green but falling) + a note.
      const series = [8.6, 8.5, 8.3, 8.2, 8.0, 7.9];
      for (var i = 0; i < series.length; i++) {
        await db.insertReading(
          tankId: tank,
          paramKey: 'alkalinity',
          value: series[i],
          takenAt: now.subtract(Duration(days: (series.length - 1 - i) * 4)),
          note: i == 1 ? 'fresh reagents | batch 2' : null,
        );
      }
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(tank),
          product: const Value('Reef Foundation B'),
          elementKey: const Value('alkalinity'),
          amount: const Value(7),
          amountUnit: Value(DoseUnit.ml.name),
          basis: Value(DoseBasis.perDay.name),
          frequency: Value(DoseFrequency.daily.name),
          startedAt: Value(now.subtract(const Duration(days: 12))),
        ),
      );
      await db.insertWaterChange(
        tankId: tank,
        changedAt: now.subtract(const Duration(days: 5)),
        amountLiters: 30,
        note: 'salinity matched',
      );
      await db.addTrackedParameter(tank, 'copper', SetupType.mixed);
      await db.insertReading(
        tankId: tank,
        paramKey: 'copper',
        value: 0.004,
        takenAt: now.subtract(const Duration(days: 32)),
      );

      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 8,
        now: now,
      ))!;
      final doc = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: true,
        includeInsights: true,
      );

      // Preamble + title + profile.
      expect(doc, contains('I keep a saltwater reef aquarium'));
      expect(doc, contains('the last 8 weeks'));
      expect(doc, contains('# Display Reef — saltwater aquarium summary'));
      expect(doc, contains('Mixed reef'));
      expect(doc, contains('300 L'));
      expect(doc, contains('running since 2025-06-01'));
      expect(doc, contains('Exported 2026-07-15.'));

      // Status: health line + observations (the falling-alk forecast insight).
      expect(doc, contains('Health score:'));
      expect(doc, contains("The app's rule-based observations:"));

      // Parameter section: localized name + stable key, ranges, trend, table.
      expect(doc, contains('### Alkalinity (alkalinity)'));
      expect(doc, contains('Target 7.5–9.0'));
      expect(doc, contains('acceptable 7.0–11.0'));
      expect(doc, contains('| Date | Value (dKH) | Note |'));
      expect(doc, contains('| 2026-07-15 | 7.9 |'));
      // Table cells escape pipes so a note can't break the markdown table.
      expect(doc, contains(r'fresh reagents \| batch 2'));

      // Dosing: plan line with daily equivalent + start date.
      expect(doc, contains('## Dosing plan'));
      expect(doc, contains('Reef Foundation B — Alkalinity:'));
      expect(doc, contains('≈7 ml per day'));
      expect(doc, contains('since 2026-07-03'));

      // Maintenance: date, amount, percent of volume, note.
      expect(doc, contains('## Maintenance in this period'));
      expect(doc, contains('2026-07-10: Water change — 30 L (10 %)'));
      expect(doc, contains('· salinity matched'));

      // Trace elements table with per-row date.
      expect(doc, contains('## Trace elements (latest measured values)'));
      expect(doc, contains('| Copper (Cu) (copper) |'));
      expect(doc, contains('| 2026-06-13 |'));
    });

    test('escapes markdown in tank and product names', () async {
      final db = await memDb();
      final tank = await db.createTankWithPreset(
        name: 'My `Reef`\n# Tank',
        type: SetupType.mixed,
        volumeLiters: 300,
        startDate: DateTime(2025, 6, 1),
      );
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: 8.0,
        takenAt: now.subtract(const Duration(days: 1)),
      );
      await db.insertDosingEntry(
        DosingEntriesCompanion(
          tankId: Value(tank),
          product: const Value('- All-For\nReef'),
          amount: const Value(7),
          amountUnit: Value(DoseUnit.ml.name),
          basis: Value(DoseBasis.perDay.name),
          frequency: Value(DoseFrequency.daily.name),
        ),
      );
      await db.insertManualDose(
        ManualDosesCompanion(
          tankId: Value(tank),
          dosedAt: Value(now.subtract(const Duration(days: 2))),
          product: const Value('One-Shot\nBoost'),
          amount: const Value(5),
          amountUnit: Value(DoseUnit.ml.name),
        ),
      );

      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 8,
        now: now,
      ))!;
      final doc = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: true,
        includeInsights: true,
      );

      // Title: newline flattened, backticks escaped — the H1 stays one line.
      expect(
        doc,
        contains('# My \\`Reef\\` # Tank — saltwater aquarium summary\n'),
      );
      // Dosing plan: newline flattened, leading list marker escaped so the
      // product can't open its own list item.
      expect(doc, contains('- \\- All-For Reef:'));
      // Manual dose: newline flattened into the one-off line.
      expect(doc, contains('one-off dose — One-Shot Boost, 5 ml'));
    });

    test('caps the per-parameter table and announces the cap', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      for (var i = 0; i < 30; i++) {
        await db.insertReading(
          tankId: tank,
          paramKey: 'alkalinity',
          value: 8.0,
          takenAt: now.subtract(Duration(days: i)),
        );
      }
      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 8,
        now: now,
      ))!;
      final doc = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: true,
        includeInsights: true,
      );
      expect(doc, contains('Showing the 20 most recent of 30 tests.'));
      // 20 data rows: count the table pipes for the alkalinity section.
      expect(RegExp(r'^\| 2026-', multiLine: true).allMatches(doc).length, 20);
    });

    test('omits empty sections', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      await db.insertReading(
        tankId: tank,
        paramKey: 'alkalinity',
        value: 8.0,
        takenAt: now.subtract(const Duration(days: 1)),
      );
      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 8,
        now: now,
      ))!;
      final doc = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: true,
        includeInsights: true,
      );
      expect(doc, isNot(contains('## Dosing plan')));
      expect(doc, isNot(contains('## Maintenance in this period')));
      expect(doc, isNot(contains('## Trace elements')));
    });

    test('omits the Pro-gated layers for a non-entitled export', () async {
      final db = await memDb();
      final tank = await seedTank(db);
      // A red alkalinity value (below amberLow 7) -> an insight exists, and
      // enough spread readings for a stability score.
      for (var i = 0; i < 5; i++) {
        await db.insertReading(
          tankId: tank,
          paramKey: 'alkalinity',
          value: 6.5 - i * 0.1,
          takenAt: now.subtract(Duration(days: 8 - i * 2)),
        );
      }
      final data = (await collectTankSummary(
        db,
        tankId: tank,
        weeks: 8,
        now: now,
      ))!;
      expect(data.insights, isNotEmpty);
      expect(data.stability.hasData, isTrue);

      final gated = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: false,
        includeInsights: false,
      );
      // The free health line stays; the Pro layers are gone.
      expect(gated, contains('Health score:'));
      expect(gated, isNot(contains('Stability score:')));
      expect(gated, isNot(contains("The app's rule-based observations:")));

      final full = encodeTankSummary(
        data,
        l: l,
        prefs: prefs,
        includeStability: true,
        includeInsights: true,
      );
      expect(full, contains('Stability score:'));
      expect(full, contains("The app's rule-based observations:"));
    });
  });

  test('decodeAiSummaryWeeks whitelists the offered choices', () {
    expect(AppSettings.decodeAiSummaryWeeks(null), kAiSummaryDefaultWeeks);
    expect(AppSettings.decodeAiSummaryWeeks('12'), 12);
    expect(AppSettings.decodeAiSummaryWeeks('45'), kAiSummaryDefaultWeeks);
    expect(AppSettings.decodeAiSummaryWeeks('garbage'), kAiSummaryDefaultWeeks);
  });
}
