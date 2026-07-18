import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/stability_score.dart';
import 'package:reeftracker/domain/trend.dart';
import 'package:reeftracker/domain/units.dart';

void main() {
  late AppDatabase db;
  late AppSettings settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettings(db);
  });
  tearDown(() => db.close());

  group('AppSettings typed accessors', () {
    test('typed setters/getters round-trip through the store', () async {
      await settings.setTempUnit(TempUnit.fahrenheit);
      await settings.setTrendWindow(9);
      await settings.setAutoBackupInterval(AutoBackupInterval.weekly);
      await settings.setHealthDisplay(HealthDisplay.badge);
      await settings.setTourSeen(true);

      expect(await settings.watchTempUnit().first, TempUnit.fahrenheit);
      expect(await settings.watchTrendWindow().first, 9);
      expect(
        await settings.readAutoBackupInterval(),
        AutoBackupInterval.weekly,
      );
      expect(await settings.watchHealthDisplay().first, HealthDisplay.badge);
      expect(await settings.watchTourSeen().first, isTrue);
      // The typed setter writes under the canonical storage key.
      expect(await db.getSetting(kTempUnitKey), 'fahrenheit');
    });

    test('unset keys decode to their single-sourced defaults', () async {
      expect(await settings.watchTempUnit().first, TempUnit.celsius);
      expect(await settings.watchLocaleCode().first, kDefaultLocaleCode);
      expect(await settings.watchChartRange().first, kDefaultChartRange);
      expect(await settings.watchTrendEnabled().first, kTrendDefaultEnabled);
      expect(await settings.watchTrendWindow().first, kTrendDefaultWindow);
      expect(await settings.watchTrendHorizon().first, kTrendDefaultHorizon);
      expect(await settings.readAutoBackupEnabled(), kAutoBackupDefaultEnabled);
      expect(await settings.readAutoBackupKeep(), kAutoBackupDefaultKeep);
      expect(await settings.watchLastBackupAt().first, isNull);
    });

    test('last-backup timestamp round-trips to the minute', () async {
      final when = DateTime.fromMillisecondsSinceEpoch(1751000000000);
      await settings.setLastBackupAt(when);
      expect(await settings.readLastBackupAt(), when);
    });

    test('a garbage last-backup value reads as null (never throws)', () async {
      await db.setSetting(kLastAutoBackupAtKey, 'not-a-number');
      expect(await settings.readLastBackupAt(), isNull);
      expect(await settings.watchLastBackupAt().first, isNull);

      await db.setSetting(kLastAutoBackupAtKey, '');
      expect(await settings.readLastBackupAt(), isNull);
    });

    test('last-used test set round-trips per tank; null clears (U9)', () async {
      await settings.setLastReadingTemplate(1, 5);
      await settings.setLastReadingTemplate(2, 9);
      expect(await settings.watchLastReadingTemplates().first, {1: 5, 2: 9});

      // Selecting "All" removes the tank's entry, leaving others intact.
      await settings.setLastReadingTemplate(1, null);
      expect(await settings.watchLastReadingTemplates().first, {2: 9});
    });

    test('active micro view round-trips per tank; null clears (U17)', () async {
      await settings.setMicroView(1, 'preset:faunaMarin');
      await settings.setMicroView(2, 'view:7');
      expect(await settings.watchMicroViewSelections().first, {
        1: 'preset:faunaMarin',
        2: 'view:7',
      });

      // Selecting the full list removes the tank's entry, leaving others.
      await settings.setMicroView(1, null);
      expect(await settings.watchMicroViewSelections().first, {2: 'view:7'});
    });

    test('garbage micro-view selections decode as empty (U17)', () {
      expect(AppSettings.decodeMicroViewSelections(null), isEmpty);
      expect(AppSettings.decodeMicroViewSelections('not json'), isEmpty);
      expect(AppSettings.decodeMicroViewSelections('[1]'), isEmpty);
      // Non-numeric keys / non-string values are skipped, not crashed on.
      expect(
        AppSettings.decodeMicroViewSelections('{"x":"a","2":3,"4":"view:9"}'),
        {4: 'view:9'},
      );
    });

    test('garbage last-used test set values decode as empty (U9)', () {
      expect(AppSettings.decodeLastReadingTemplates(null), isEmpty);
      expect(AppSettings.decodeLastReadingTemplates('not json'), isEmpty);
      expect(AppSettings.decodeLastReadingTemplates('[1,2]'), isEmpty);
      // Non-numeric keys / non-int values are skipped, not crashed on.
      expect(AppSettings.decodeLastReadingTemplates('{"x":1,"2":"y","3":7}'), {
        3: 7,
      });
    });

    test(
      'reminder category switches default off and round-trip (U1/U2/U12)',
      () async {
        expect(await settings.readRemindersTesting(), isFalse);
        expect(await settings.readRemindersDosing(), isFalse);
        expect(await settings.readRemindersMaintenance(), isFalse);

        await settings.setRemindersTesting(true);
        await settings.setRemindersMaintenance(true);
        expect(await settings.watchRemindersTesting().first, isTrue);
        expect(await settings.watchRemindersDosing().first, isFalse);
        expect(await settings.readRemindersMaintenance(), isTrue);
      },
    );

    test(
      'early-adopter marker seeds once and never overwrites (U19)',
      () async {
        // Fresh install before seeding: standard edition.
        expect(await settings.watchEdition().first, AppEdition.standard);

        await settings.seedLegacyFreeSince('0.26.0');
        expect(await db.getSetting(kLegacyFreeSinceKey), '0.26.0');
        expect(await settings.watchEdition().first, AppEdition.founder);

        // A later launch (newer version) must not overwrite the original stamp.
        await settings.seedLegacyFreeSince('0.27.0');
        expect(await db.getSetting(kLegacyFreeSinceKey), '0.26.0');
      },
    );

    test('edition decodes from the raw marker value (U19)', () {
      expect(AppSettings.decodeLegacyFreeSince(null), isNull);
      expect(AppSettings.decodeLegacyFreeSince(''), isNull);
      expect(AppSettings.decodeLegacyFreeSince('0.26.0'), '0.26.0');
      expect(AppSettings.decodeEdition(null), AppEdition.standard);
      expect(AppSettings.decodeEdition(''), AppEdition.standard);
      expect(AppSettings.decodeEdition('0.26.0'), AppEdition.founder);
    });

    test('reminder time defaults to 09:00, round-trips zero-padded, and '
        'garbage decodes to the default', () async {
      expect(await settings.readReminderTime(), kDefaultReminderTime);

      await settings.setReminderTime(7, 5);
      expect(await db.getSetting(kReminderTimeKey), '07:05');
      expect(await settings.watchReminderTime().first, (hour: 7, minute: 5));

      expect(AppSettings.decodeReminderTime('25:99'), kDefaultReminderTime);
      expect(AppSettings.decodeReminderTime('soon'), kDefaultReminderTime);
      expect(AppSettings.decodeReminderTime(null), kDefaultReminderTime);
    });

    test('stability window decodes whitelisted values only (U26)', () async {
      expect(AppSettings.decodeStabilityWindow(null), kStabilityWindowDays);
      for (final choice in kStabilityWindowChoices) {
        expect(AppSettings.decodeStabilityWindow('$choice'), choice);
      }
      // A value the dropdown doesn't offer would crash Settings (the
      // trend-window clamp rationale) — hand-edited/garbage input falls back
      // to the default instead.
      expect(AppSettings.decodeStabilityWindow('45'), kStabilityWindowDays);
      expect(AppSettings.decodeStabilityWindow('soon'), kStabilityWindowDays);

      await settings.setStabilityWindow(90);
      expect(await settings.watchStabilityWindow().first, 90);
    });

    test('dashboard layout defaults to grouped and round-trips (#6)', () async {
      // Unset / unknown → grouped (the new categorized layout is the default
      // and the target of future work).
      expect(AppSettings.decodeDashboardLayout(null), DashboardLayout.grouped);
      expect(
        AppSettings.decodeDashboardLayout('nonsense'),
        DashboardLayout.grouped,
      );
      expect(
        AppSettings.decodeDashboardLayout('classic'),
        DashboardLayout.classic,
      );

      expect(
        await settings.watchDashboardLayout().first,
        DashboardLayout.grouped,
      );
      await settings.setDashboardLayout(DashboardLayout.classic);
      expect(
        await settings.watchDashboardLayout().first,
        DashboardLayout.classic,
      );
      expect(await db.getSetting(kDashboardLayoutKey), 'classic');
    });
  });

  group('SettingKey registry', () {
    test('deviceLocalKeys covers every preference key', () {
      // Every registered key is device-local (#18) except the RO seed flag
      // (U16), which describes domain data and must travel with the RO rows
      // it guards on a backup restore, and the early-adopter marker (U19),
      // which must ride backups to carry the status to a new device. This
      // pins the split so a new setting can't be added without deciding its
      // restore behaviour.
      expect(SettingKey.deviceLocalKeys, {
        for (final k in SettingKey.values)
          if (k != SettingKey.roSeeded && k != SettingKey.legacyFreeSince)
            k.storageKey,
      });
      expect(SettingKey.roSeeded.deviceLocal, isFalse);
      expect(SettingKey.legacyFreeSince.deviceLocal, isFalse);
    });

    test('storage keys are unique', () {
      final keys = SettingKey.values.map((k) => k.storageKey).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
