import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/backup.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Routes path_provider (used by [importBackup]'s rehearsal restore) to a temp
/// folder so it works under `flutter test`.
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
  group('backup encode/decode', () {
    final tanks = [
      Tank(
        id: 1,
        name: 'Reef',
        setupType: 'mixed',
        volumeLiters: 200.5,
        startDate: DateTime.fromMillisecondsSinceEpoch(1000000000000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ),
      Tank(
        id: 2,
        name: 'Nano',
        setupType: 'soft',
        volumeLiters: null,
        startDate: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000111000),
      ),
    ];
    final params = [
      TrackedParameter(
        id: 5,
        tankId: 1,
        paramKey: 'alk',
        unit: 'dKH',
        enabled: true,
        displayOrder: 0,
        amberLow: 7.0,
        greenLow: 7.5,
        greenHigh: 9.0,
        amberHigh: 9.5,
        testCadenceDays: 7,
      ),
      TrackedParameter(
        id: 6,
        tankId: 1,
        paramKey: 'ph',
        unit: '',
        enabled: false,
        displayOrder: 1,
        amberLow: null,
        greenLow: null,
        greenHigh: null,
        amberHigh: null,
      ),
    ];
    final readings = [
      Reading(
        id: 10,
        tankId: 1,
        paramKey: 'alk',
        value: 8.2,
        takenAt: DateTime.fromMillisecondsSinceEpoch(1700001000000),
        note: 'after dosing',
      ),
      Reading(
        id: 11,
        tankId: 2,
        paramKey: 'ph',
        value: 8.1,
        takenAt: DateTime.fromMillisecondsSinceEpoch(1700002000000),
        note: null,
      ),
    ];
    final waterChanges = [
      WaterChange(
        id: 20,
        tankId: 1,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700003000000),
        amountLiters: 25.0,
        note: 'Tropic Marin salt',
      ),
      WaterChange(
        id: 21,
        tankId: 2,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700004000000),
        amountLiters: null,
        note: null,
      ),
    ];
    final carbonChanges = [
      CarbonChange(
        id: 30,
        tankId: 1,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700005000000),
        grams: 200.0,
        note: 'ROWAphos',
      ),
      CarbonChange(
        id: 31,
        tankId: 2,
        changedAt: DateTime.fromMillisecondsSinceEpoch(1700006000000),
        grams: null,
        note: null,
      ),
    ];
    final equipmentCleanings = [
      EquipmentCleaning(
        id: 40,
        tankId: 1,
        cleanedAt: DateTime.fromMillisecondsSinceEpoch(1700007000000),
        note: 'Cleaned skimmer',
      ),
      EquipmentCleaning(
        id: 41,
        tankId: 2,
        cleanedAt: DateTime.fromMillisecondsSinceEpoch(1700008000000),
        note: null,
      ),
    ];
    final ratioVisibilities = [
      const RatioVisibility(
        tankId: 1,
        ratioKey: 'mgca',
        visible: false,
        displayOrder: 3,
        amberLow: 2.6,
        greenLow: 2.9,
        greenHigh: 3.3,
        amberHigh: 3.6,
      ),
      const RatioVisibility(
        tankId: 2,
        ratioKey: 'po4no3',
        visible: true,
        displayOrder: 1000,
      ),
    ];
    final dosingEntries = [
      DosingEntry(
        id: 50,
        tankId: 1,
        productKey: 'redsea.foundation_b',
        vendor: 'Red Sea',
        program: 'Reef Care Program',
        product: 'Reef Foundation B (KH/Alk)',
        elementKey: 'alkalinity',
        amount: 5.0,
        amountUnit: 'ml',
        basis: 'perDay',
        frequency: 'daily',
        doseTime: '21:00',
        remindEnabled: true,
        note: 'Auto-doser line 2',
        displayOrder: 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700004000000),
        startedAt: DateTime.fromMillisecondsSinceEpoch(1700004000000),
        state: DosingState.active.name,
      ),
      DosingEntry(
        id: 51,
        tankId: 1,
        product: 'Custom kalk mix',
        remindEnabled: false,
        displayOrder: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700005000000),
        startedAt: DateTime.fromMillisecondsSinceEpoch(1700005000000),
        endedAt: DateTime.fromMillisecondsSinceEpoch(1700006000000),
        state: DosingState.ended.name,
      ),
    ];
    final readingTemplates = [
      ReadingTemplate(
        id: 60,
        tankId: 1,
        name: 'Weekly big test',
        paramKeys: encodeTemplateParamKeys(['alkalinity', 'calcium']),
        displayOrder: 0,
      ),
      ReadingTemplate(
        id: 61,
        tankId: 2,
        name: 'Daily Alk',
        paramKeys: encodeTemplateParamKeys(['alkalinity']),
        displayOrder: 1,
      ),
    ];
    final maintenanceSchedules = [
      MaintenanceSchedule(
        id: 70,
        tankId: 1,
        actionType: 'waterChange',
        title: null,
        cadenceDays: 2,
        cadenceUnit: 'weeks',
        scheduledAt: null,
        lastDoneAt: null,
        remindEnabled: true,
        note: null,
        displayOrder: 0,
      ),
      MaintenanceSchedule(
        id: 71,
        tankId: 2,
        actionType: null,
        title: 'Replace RO membrane',
        cadenceDays: null,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(1700009000000),
        lastDoneAt: DateTime.fromMillisecondsSinceEpoch(1700009500000),
        remindEnabled: false,
        note: 'under the sink',
        displayOrder: 1,
      ),
      MaintenanceSchedule(
        id: 72,
        tankId: 1,
        actionType: null,
        title: 'Clean glass',
        weekdays: '1,4',
        monthDay: 15,
        remindEnabled: true,
        displayOrder: 2,
      ),
    ];
    final settings = [
      const Setting(key: 'temp_unit', value: 'fahrenheit'),
      const Setting(key: 'active_tank_id', value: '1'),
      const Setting(key: 'locale', value: null),
    ];
    final roStages = [
      const RoStage(
        id: 80,
        stageType: 'membrane',
        title: null,
        lifespanDays: 720,
        enabled: true,
        remindEnabled: true,
        note: '75 GPD',
        displayOrder: 2,
      ),
      const RoStage(
        id: 81,
        stageType: 'custom',
        title: 'Second DI cartridge',
        lifespanDays: 120,
        enabled: false,
        remindEnabled: false,
        note: null,
        displayOrder: 4,
      ),
    ];
    final roStageReplacements = [
      RoStageReplacement(
        id: 90,
        stageId: 80,
        replacedAt: DateTime.fromMillisecondsSinceEpoch(1700010000000),
        note: 'new Filmtec',
      ),
      RoStageReplacement(
        id: 91,
        stageId: 81,
        replacedAt: DateTime.fromMillisecondsSinceEpoch(1700011000000),
        note: null,
      ),
    ];

    test('round-trips every table preserving ids and values', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        equipmentCleanings: equipmentCleanings,
        ratioVisibilities: ratioVisibilities,
        dosingEntries: dosingEntries,
        readingTemplates: readingTemplates,
        maintenanceSchedules: maintenanceSchedules,
        roStages: roStages,
        roStageReplacements: roStageReplacements,
        settings: settings,
      );
      final data = decodeBackup(json);

      expect(data.tanks.length, 2);
      final t0 = data.tanks[0];
      expect(t0.id.value, 1);
      expect(t0.name.value, 'Reef');
      expect(t0.setupType.value, 'mixed');
      expect(t0.volumeLiters.value, 200.5);
      expect(t0.startDate.value, tanks[0].startDate);
      expect(t0.createdAt.value, tanks[0].createdAt);
      expect(data.tanks[1].volumeLiters.value, isNull);
      expect(data.tanks[1].startDate.value, isNull);

      final p0 = data.params[0];
      expect(p0.id.value, 5);
      expect(p0.tankId.value, 1);
      expect(p0.enabled.value, true);
      expect(p0.amberHigh.value, 9.5);
      expect(data.params[1].enabled.value, false);
      expect(data.params[1].greenLow.value, isNull);

      final r0 = data.readings[0];
      expect(r0.id.value, 10);
      expect(r0.value.value, 8.2);
      expect(r0.takenAt.value, readings[0].takenAt);
      expect(r0.note.value, 'after dosing');
      expect(data.readings[1].note.value, isNull);

      final w0 = data.waterChanges[0];
      expect(w0.id.value, 20);
      expect(w0.tankId.value, 1);
      expect(w0.changedAt.value, waterChanges[0].changedAt);
      expect(w0.amountLiters.value, 25.0);
      expect(w0.note.value, 'Tropic Marin salt');
      expect(data.waterChanges[1].amountLiters.value, isNull);
      expect(data.waterChanges[1].note.value, isNull);

      final c0 = data.carbonChanges[0];
      expect(c0.id.value, 30);
      expect(c0.tankId.value, 1);
      expect(c0.changedAt.value, carbonChanges[0].changedAt);
      expect(c0.grams.value, 200.0);
      expect(c0.note.value, 'ROWAphos');
      expect(data.carbonChanges[1].grams.value, isNull);
      expect(data.carbonChanges[1].note.value, isNull);

      final e0 = data.equipmentCleanings[0];
      expect(e0.id.value, 40);
      expect(e0.tankId.value, 1);
      expect(e0.cleanedAt.value, equipmentCleanings[0].cleanedAt);
      expect(e0.note.value, 'Cleaned skimmer');
      expect(data.equipmentCleanings[1].note.value, isNull);

      final rv0 = data.ratioVisibilities[0];
      expect(rv0.tankId.value, 1);
      expect(rv0.ratioKey.value, 'mgca');
      expect(rv0.visible.value, false);
      expect(rv0.displayOrder.value, 3);
      expect(rv0.greenLow.value, 2.9);
      expect(rv0.amberHigh.value, 3.6);
      expect(data.ratioVisibilities[1].ratioKey.value, 'po4no3');
      expect(data.ratioVisibilities[1].visible.value, true);
      expect(data.ratioVisibilities[1].displayOrder.value, 1000);
      expect(data.ratioVisibilities[1].greenLow.value, isNull);

      final d0 = data.dosingEntries[0];
      expect(d0.id.value, 50);
      expect(d0.tankId.value, 1);
      expect(d0.productKey.value, 'redsea.foundation_b');
      expect(d0.product.value, 'Reef Foundation B (KH/Alk)');
      expect(d0.elementKey.value, 'alkalinity');
      expect(d0.amount.value, 5.0);
      expect(d0.amountUnit.value, 'ml');
      expect(d0.basis.value, 'perDay');
      expect(d0.frequency.value, 'daily');
      expect(d0.doseTime.value, '21:00');
      expect(d0.createdAt.value, dosingEntries[0].createdAt);
      expect(d0.startedAt.value, dosingEntries[0].startedAt);
      expect(d0.endedAt.value, isNull);
      expect(d0.state.value, DosingState.active.name);
      final d1 = data.dosingEntries[1];
      expect(d1.productKey.value, isNull);
      expect(d1.elementKey.value, isNull);
      expect(d1.amount.value, isNull);
      expect(d1.startedAt.value, dosingEntries[1].startedAt);
      expect(d1.endedAt.value, dosingEntries[1].endedAt);
      expect(d1.state.value, DosingState.ended.name);

      final rt0 = data.readingTemplates[0];
      expect(rt0.id.value, 60);
      expect(rt0.tankId.value, 1);
      expect(rt0.name.value, 'Weekly big test');
      expect(decodeTemplateParamKeys(rt0.paramKeys.value), [
        'alkalinity',
        'calcium',
      ]);
      expect(rt0.displayOrder.value, 0);
      expect(data.readingTemplates[1].name.value, 'Daily Alk');

      final ms0 = data.maintenanceSchedules[0];
      expect(ms0.id.value, 70);
      expect(ms0.tankId.value, 1);
      expect(ms0.actionType.value, 'waterChange');
      expect(ms0.title.value, isNull);
      expect(ms0.cadenceDays.value, 2);
      expect(ms0.cadenceUnit.value, 'weeks');
      expect(ms0.weekdays.value, isNull);
      expect(ms0.monthDay.value, isNull);
      expect(ms0.scheduledAt.value, isNull);
      expect(ms0.lastDoneAt.value, isNull);
      expect(ms0.remindEnabled.value, isTrue);
      final ms1 = data.maintenanceSchedules[1];
      expect(ms1.actionType.value, isNull);
      expect(ms1.title.value, 'Replace RO membrane');
      expect(ms1.cadenceDays.value, isNull);
      expect(ms1.cadenceUnit.value, isNull);
      expect(ms1.scheduledAt.value, maintenanceSchedules[1].scheduledAt);
      expect(ms1.lastDoneAt.value, maintenanceSchedules[1].lastDoneAt);
      expect(ms1.remindEnabled.value, isFalse);
      expect(ms1.note.value, 'under the sink');
      final ms2 = data.maintenanceSchedules[2];
      expect(ms2.weekdays.value, '1,4');
      expect(ms2.monthDay.value, 15);

      // The v16 columns on existing sections round-trip too.
      expect(data.params[0].testCadenceDays.value, params[0].testCadenceDays);
      expect(data.dosingEntries[0].remindEnabled.value, isTrue);
      expect(data.dosingEntries[1].remindEnabled.value, isFalse);

      // RO unit sections (U16) — no tankId by design.
      final rs0 = data.roStages[0];
      expect(rs0.id.value, 80);
      expect(rs0.stageType.value, 'membrane');
      expect(rs0.title.value, isNull);
      expect(rs0.lifespanDays.value, 720);
      expect(rs0.enabled.value, isTrue);
      expect(rs0.remindEnabled.value, isTrue);
      expect(rs0.note.value, '75 GPD');
      expect(rs0.displayOrder.value, 2);
      final rs1 = data.roStages[1];
      expect(rs1.stageType.value, 'custom');
      expect(rs1.title.value, 'Second DI cartridge');
      expect(rs1.enabled.value, isFalse);
      final rr0 = data.roStageReplacements[0];
      expect(rr0.id.value, 90);
      expect(rr0.stageId.value, 80);
      expect(rr0.replacedAt.value, roStageReplacements[0].replacedAt);
      expect(rr0.note.value, 'new Filmtec');
      expect(data.roStageReplacements[1].note.value, isNull);

      expect(data.settings.length, 3);
      expect(data.settings[0].key.value, 'temp_unit');
      expect(data.settings[0].value.value, 'fahrenheit');
      expect(data.settings[2].value.value, isNull);
    });

    test(
      'rejects a readingTemplates row with non-string keys as corrupted',
      () {
        final json = encodeBackup(
          schemaVersion: 2,
          tanks: tanks,
          params: params,
          readings: readings,
          waterChanges: waterChanges,
          carbonChanges: carbonChanges,
          equipmentCleanings: equipmentCleanings,
          ratioVisibilities: ratioVisibilities,
          dosingEntries: dosingEntries,
          readingTemplates: readingTemplates,
          settings: settings,
        );
        // Tamper with a template's keys (re-encoding drops the now-stale
        // checksum, which older backups legitimately lack).
        final doc = jsonDecode(json) as Map<String, dynamic>;
        doc.remove('checksum');
        final templatesJson = doc['readingTemplates'] as List;
        (templatesJson[0] as Map<String, dynamic>)['paramKeys'] = [1, 2];
        expect(
          () => decodeBackup(jsonEncode(doc)),
          throwsA(
            isA<InvalidBackupException>().having(
              (e) => e.reason,
              'reason',
              BackupRejection.corrupted,
            ),
          ),
        );
      },
    );

    test('tolerates older backups without later action sections', () {
      final json =
          encodeBackup(
                schemaVersion: 2,
                tanks: tanks,
                params: params,
                readings: readings,
                waterChanges: waterChanges,
                carbonChanges: carbonChanges,
                equipmentCleanings: equipmentCleanings,
                ratioVisibilities: ratioVisibilities,
                dosingEntries: dosingEntries,
                settings: settings,
              )
              .replaceFirst(
                RegExp(r',\s*"waterChanges":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"carbonChanges":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"equipmentCleanings":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"ratioVisibilities":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"dosingEntries":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"readingTemplates":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"maintenanceSchedules":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"roStages":\s*\[.*?\]', dotAll: true),
                '',
              )
              .replaceFirst(
                RegExp(r',\s*"roStageReplacements":\s*\[.*?\]', dotAll: true),
                '',
              )
              // Older backups predate the checksum too (T7); with it left in,
              // the stripped document would (correctly) fail verification.
              .replaceFirst(RegExp(r',\s*"checksum":\s*"[^"]*"'), '');
      final data = decodeBackup(json);
      expect(data.waterChanges, isEmpty);
      expect(data.carbonChanges, isEmpty);
      expect(data.equipmentCleanings, isEmpty);
      expect(data.ratioVisibilities, isEmpty);
      expect(data.dosingEntries, isEmpty);
      expect(data.readingTemplates, isEmpty);
      expect(data.maintenanceSchedules, isEmpty);
      expect(data.roStages, isEmpty);
      expect(data.roStageReplacements, isEmpty);
      expect(data.readings.length, 2);
    });

    test('tolerates pre-v16 rows without the reminder fields', () {
      final json = encodeBackup(
        schemaVersion: 15,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        equipmentCleanings: equipmentCleanings,
        ratioVisibilities: ratioVisibilities,
        dosingEntries: dosingEntries,
        settings: settings,
      );
      final doc = jsonDecode(json) as Map<String, dynamic>;
      doc.remove('checksum');
      for (final p in doc['trackedParameters'] as List) {
        (p as Map<String, dynamic>).remove('testCadenceDays');
      }
      for (final d in doc['dosingEntries'] as List) {
        (d as Map<String, dynamic>).remove('remindEnabled');
      }
      final data = decodeBackup(jsonEncode(doc));
      expect(data.params[0].testCadenceDays.value, isNull);
      // Reminders stay opt-in for restored pre-v16 entries.
      expect(data.dosingEntries[0].remindEnabled.value, isFalse);
    });

    test('tolerates dosing entries without segment fields (pre-v11)', () {
      final json =
          encodeBackup(
                schemaVersion: 10,
                tanks: tanks,
                params: params,
                readings: readings,
                waterChanges: waterChanges,
                carbonChanges: carbonChanges,
                equipmentCleanings: equipmentCleanings,
                ratioVisibilities: ratioVisibilities,
                dosingEntries: dosingEntries,
                settings: settings,
              )
              .replaceAll(RegExp(r',\s*"startedAt":\s*(?:null|\d+)'), '')
              .replaceAll(RegExp(r',\s*"endedAt":\s*(?:null|\d+)'), '')
              .replaceAll(RegExp(r',\s*"state":\s*"[^"]*"'), '')
              // Pre-v11 backups predate the checksum as well (T7).
              .replaceFirst(RegExp(r',\s*"checksum":\s*"[^"]*"'), '');
      final data = decodeBackup(json);
      // Missing segment fields fall back to: started = created, not ended, active.
      final d0 = data.dosingEntries[0];
      expect(d0.startedAt.value, dosingEntries[0].createdAt);
      expect(d0.endedAt.value, isNull);
      expect(d0.state.value, DosingState.active.name);
      final d1 = data.dosingEntries[1];
      expect(d1.startedAt.value, dosingEntries[1].createdAt);
      expect(d1.endedAt.value, isNull);
      expect(d1.state.value, DosingState.active.name);
    });

    test(
      'checksum catches in-field corruption the JSON parser cannot (T7)',
      () {
        final json = encodeBackup(
          schemaVersion: 2,
          tanks: tanks,
          params: params,
          readings: readings,
          waterChanges: waterChanges,
          carbonChanges: carbonChanges,
          equipmentCleanings: equipmentCleanings,
          ratioVisibilities: ratioVisibilities,
          dosingEntries: dosingEntries,
          settings: settings,
        );
        // Same-length in-field flip: the JSON stays parseable and every row
        // still decodes — only the checksum can tell the value was damaged.
        final tampered = json.replaceFirst('"value":8.2', '"value":9.2');
        expect(tampered, isNot(json));
        expect(
          () => decodeBackup(tampered),
          throwsA(
            isA<InvalidBackupException>()
                .having((e) => e.reason, 'reason', BackupRejection.corrupted)
                .having((e) => e.detail, 'detail', contains('checksum')),
          ),
        );
        // The untampered document still decodes (the round-trip test also
        // covers this, but pin it next to the negative case).
        expect(decodeBackup(json).readings.length, 2);
      },
    );

    test('backups without a checksum are accepted unverified (T7)', () {
      // Every backup written before the checksum existed lacks the key; it
      // must keep importing.
      final legacy = encodeBackup(
        schemaVersion: 2,
        tanks: tanks,
        params: params,
        readings: readings,
        waterChanges: waterChanges,
        carbonChanges: carbonChanges,
        equipmentCleanings: equipmentCleanings,
        ratioVisibilities: ratioVisibilities,
        dosingEntries: dosingEntries,
        settings: settings,
      ).replaceFirst(RegExp(r',\s*"checksum":\s*"[^"]*"'), '');
      expect(decodeBackup(legacy).tanks.length, 2);
    });

    test('rejects a non-string checksum as corrupted (T7)', () {
      const json =
          '{"format":"reeftracker-backup","version":1,'
          '"schemaVersion":1,"tanks":[],"trackedParameters":[],'
          '"readings":[],"settings":[],"checksum":5}';
      expect(
        () => decodeBackup(json),
        throwsA(
          isA<InvalidBackupException>()
              .having((e) => e.reason, 'reason', BackupRejection.corrupted)
              .having((e) => e.detail, 'detail', contains('checksum')),
        ),
      );
    });

    test('rejects a broken row inside a section as corrupted, naming it', () {
      // A recognizable backup whose readings section holds an incomplete row.
      const json =
          '{"format":"reeftracker-backup","version":1,'
          '"schemaVersion":1,"tanks":[],"trackedParameters":[],'
          '"readings":[{"id":1}],"settings":[]}';
      expect(
        () => decodeBackup(json),
        throwsA(
          isA<InvalidBackupException>()
              .having((e) => e.reason, 'reason', BackupRejection.corrupted)
              .having((e) => e.detail, 'detail', contains('readings')),
        ),
      );
    });

    test('rejects a section that is not a list as corrupted', () {
      const json =
          '{"format":"reeftracker-backup","version":1,'
          '"schemaVersion":1,"tanks":{},"trackedParameters":[],'
          '"readings":[],"settings":[]}';
      expect(
        () => decodeBackup(json),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.corrupted,
          ),
        ),
      );
    });

    test('rejects a missing required section as corrupted', () {
      // No "tanks" key at all — unlike the optional later-version sections,
      // the core sections must be present.
      const json =
          '{"format":"reeftracker-backup","version":1,'
          '"schemaVersion":1,"trackedParameters":[],'
          '"readings":[],"settings":[]}';
      expect(
        () => decodeBackup(json),
        throwsA(
          isA<InvalidBackupException>()
              .having((e) => e.reason, 'reason', BackupRejection.corrupted)
              .having((e) => e.detail, 'detail', contains('tanks')),
        ),
      );
    });

    test('rejects files that are not ReefTracker backups', () {
      expect(
        () => decodeBackup('not json'),
        throwsA(isA<InvalidBackupException>()),
      );
      expect(
        () => decodeBackup('{"format":"something-else"}'),
        throwsA(isA<InvalidBackupException>()),
      );
      expect(() => decodeBackup('[]'), throwsA(isA<InvalidBackupException>()));
    });

    test('rejects backups from a newer document version', () {
      final json = encodeBackup(
        schemaVersion: 2,
        tanks: const [],
        params: const [],
        readings: const [],
        waterChanges: const [],
        carbonChanges: const [],
        equipmentCleanings: const [],
        ratioVisibilities: const [],
        dosingEntries: const [],
        settings: const [],
      ).replaceFirst(RegExp(r'"version":\s*1'), '"version":999');
      expect(
        () => decodeBackup(json),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.newerVersion,
          ),
        ),
      );
    });

    test('missing or non-int version is not reported as "newer app" (#38)', () {
      // A truncated/hand-edited file must not get the misleading "backup from
      // a newer app" message: absent version -> not a backup file at all;
      // non-int version -> recognized but damaged.
      const missing =
          '{"format":"reeftracker-backup",'
          '"schemaVersion":1,"tanks":[],"trackedParameters":[],'
          '"readings":[],"settings":[]}';
      expect(
        () => decodeBackup(missing),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.notBackupFile,
          ),
        ),
      );

      const nonInt =
          '{"format":"reeftracker-backup","version":"1",'
          '"schemaVersion":1,"tanks":[],"trackedParameters":[],'
          '"readings":[],"settings":[]}';
      expect(
        () => decodeBackup(nonInt),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.corrupted,
          ),
        ),
      );
    });

    test('non-UTF-8 bytes are rejected as not-a-backup, not a crash (#37)', () {
      // 0xC3 announces a two-byte sequence; 0x28 is not a continuation byte —
      // a binary file renamed .json must surface the specific rejection
      // message, not escape the InvalidBackupException contract.
      expect(
        () => decodeBackupBytes(const [0xC3, 0x28, 0x00]),
        throwsA(
          isA<InvalidBackupException>().having(
            (e) => e.reason,
            'reason',
            BackupRejection.notBackupFile,
          ),
        ),
      );

      // Valid UTF-8 bytes take the normal decode path.
      const json =
          '{"format":"reeftracker-backup","version":1,'
          '"schemaVersion":1,"tanks":[],"trackedParameters":[],'
          '"readings":[],"settings":[]}';
      expect(decodeBackupBytes(json.codeUnits).tanks, isEmpty);
    });

    test(
      'InvalidBackupException crosses the decode worker isolate typed (T5)',
      () async {
        // Import decodes in Isolate.run; the exception must arrive here as an
        // InvalidBackupException (not a RemoteError) so the user still gets the
        // specific localized rejection message (#37).
        await expectLater(
          Isolate.run(() => decodeBackupBytes(const [0xC3, 0x28, 0x00])),
          throwsA(
            isA<InvalidBackupException>().having(
              (e) => e.reason,
              'reason',
              BackupRejection.notBackupFile,
            ),
          ),
        );
      },
    );
  });

  group('validateBackup', () {
    BackupData dataWith({
      List<TanksCompanion> tanks = const [],
      List<ReadingsCompanion> readings = const [],
      List<ReadingTemplatesCompanion> readingTemplates = const [],
      List<MaintenanceSchedulesCompanion> maintenanceSchedules = const [],
      List<RoStagesCompanion> roStages = const [],
      List<RoStageReplacementsCompanion> roStageReplacements = const [],
      int schemaVersion = 1,
    }) => BackupData(
      schemaVersion: schemaVersion,
      tanks: tanks,
      params: const [],
      readings: readings,
      waterChanges: const [],
      carbonChanges: const [],
      equipmentCleanings: const [],
      ratioVisibilities: const [],
      dosingEntries: const [],
      readingTemplates: readingTemplates,
      maintenanceSchedules: maintenanceSchedules,
      roStages: roStages,
      roStageReplacements: roStageReplacements,
      settings: const [],
    );

    TanksCompanion tank(int id) => TanksCompanion(
      id: Value(id),
      name: Value('Tank $id'),
      setupType: const Value('mixed'),
      createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
    );

    ReadingsCompanion reading(int id, int tankId) => ReadingsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      paramKey: const Value('alk'),
      value: const Value(8.2),
      takenAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
    );

    Matcher rejectedWith(BackupRejection reason) => throwsA(
      isA<InvalidBackupException>().having((e) => e.reason, 'reason', reason),
    );

    test('accepts a consistent data set', () {
      final d = dataWith(tanks: [tank(1)], readings: [reading(10, 1)]);
      expect(() => validateBackup(d, appSchemaVersion: 10), returnsNormally);
    });

    test('accepts an older schema version', () {
      final d = dataWith(tanks: [tank(1)], schemaVersion: 1);
      expect(() => validateBackup(d, appSchemaVersion: 10), returnsNormally);
    });

    test('rejects a newer schema version', () {
      final d = dataWith(tanks: [tank(1)], schemaVersion: 11);
      expect(
        () => validateBackup(d, appSchemaVersion: 10),
        rejectedWith(BackupRejection.newerVersion),
      );
    });

    test('rejects a reading referencing a missing aquarium', () {
      final d = dataWith(tanks: [tank(1)], readings: [reading(10, 99)]);
      expect(
        () => validateBackup(d, appSchemaVersion: 10),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects duplicate aquarium ids', () {
      final d = dataWith(tanks: [tank(1), tank(1)]);
      expect(
        () => validateBackup(d, appSchemaVersion: 10),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    ReadingTemplatesCompanion template(
      int id,
      int tankId, {
      String name = 'Weekly',
    }) => ReadingTemplatesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      name: Value(name),
      paramKeys: Value(encodeTemplateParamKeys(['alkalinity'])),
      displayOrder: const Value(0),
    );

    test('accepts a consistent test set (U9)', () {
      final d = dataWith(tanks: [tank(1)], readingTemplates: [template(60, 1)]);
      expect(() => validateBackup(d, appSchemaVersion: 14), returnsNormally);
    });

    test('rejects a test set referencing a missing aquarium (U9)', () {
      final d = dataWith(
        tanks: [tank(1)],
        readingTemplates: [template(60, 99)],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 14),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a test set with an out-of-range id (U9, #33)', () {
      final d = dataWith(tanks: [tank(1)], readingTemplates: [template(-1, 1)]);
      expect(
        () => validateBackup(d, appSchemaVersion: 14),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a test set with a blank name (U9)', () {
      final d = dataWith(
        tanks: [tank(1)],
        readingTemplates: [template(60, 1, name: '   ')],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 14),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    MaintenanceSchedulesCompanion schedule(
      int id,
      int tankId, {
      String? actionType = 'waterChange',
      String? title,
      int? cadenceDays = 14,
      String? cadenceUnit,
      String? weekdays,
      int? monthDay,
    }) => MaintenanceSchedulesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      actionType: Value(actionType),
      title: Value(title),
      cadenceDays: Value(cadenceDays),
      cadenceUnit: Value(cadenceUnit),
      weekdays: Value(weekdays),
      monthDay: Value(monthDay),
      displayOrder: const Value(0),
    );

    test('accepts typed and custom maintenance plans (U12)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [
          schedule(70, 1),
          schedule(71, 1, actionType: null, title: 'Replace RO membrane'),
          schedule(72, 1, cadenceDays: null), // one-off typed
        ],
      );
      expect(() => validateBackup(d, appSchemaVersion: 16), returnsNormally);
    });

    test('rejects a plan referencing a missing aquarium (U12)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 99)],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a plan with an unknown actionType (U12, #34)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 1, actionType: 'bogus')],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a custom plan with a blank title (U12)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 1, actionType: null, title: '   ')],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
      final noTitle = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 1, actionType: null)],
      );
      expect(
        () => validateBackup(noTitle, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a plan with a sub-1-day cadence (U12, #8 rule)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 1, cadenceDays: 0)],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('accepts the v17 repeat modes (unit / weekdays / month day)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [
          schedule(70, 1, cadenceDays: 2, cadenceUnit: 'months'),
          schedule(71, 1, cadenceDays: null, weekdays: '1,4'),
          schedule(72, 1, cadenceDays: null, monthDay: 31),
        ],
      );
      expect(() => validateBackup(d, appSchemaVersion: 17), returnsNormally);
    });

    test('rejects an unknown cadence unit (#8 at the door)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(70, 1, cadenceUnit: 'fortnights')],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 17),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a weekday list with no valid day', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [
          schedule(70, 1, cadenceDays: null, weekdays: '0,9'),
        ],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 17),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects an out-of-range month day', () {
      for (final day in const [0, 32]) {
        final d = dataWith(
          tanks: [tank(1)],
          maintenanceSchedules: [
            schedule(70, 1, cadenceDays: null, monthDay: day),
          ],
        );
        expect(
          () => validateBackup(d, appSchemaVersion: 17),
          rejectedWith(BackupRejection.inconsistent),
          reason: 'monthDay=$day',
        );
      }
    });

    test('rejects a plan with an out-of-range id (U12, #33)', () {
      final d = dataWith(
        tanks: [tank(1)],
        maintenanceSchedules: [schedule(-1, 1)],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 16),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    RoStagesCompanion roStage(
      int id, {
      String stageType = 'sediment',
      String? title,
      int lifespanDays = 90,
    }) => RoStagesCompanion(
      id: Value(id),
      stageType: Value(stageType),
      title: Value(title),
      lifespanDays: Value(lifespanDays),
      enabled: const Value(true),
      remindEnabled: const Value(true),
      displayOrder: const Value(0),
    );

    RoStageReplacementsCompanion roReplacement(int id, int stageId) =>
        RoStageReplacementsCompanion(
          id: Value(id),
          stageId: Value(stageId),
          replacedAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
        );

    test('accepts consistent RO stages and replacements (U16)', () {
      final d = dataWith(
        roStages: [
          roStage(80),
          roStage(81, stageType: 'custom', title: 'Second DI'),
        ],
        roStageReplacements: [roReplacement(90, 80)],
      );
      expect(() => validateBackup(d, appSchemaVersion: 18), returnsNormally);
    });

    test('rejects duplicate RO stage ids (U16)', () {
      final d = dataWith(roStages: [roStage(80), roStage(80)]);
      expect(
        () => validateBackup(d, appSchemaVersion: 18),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a replacement referencing a missing stage (U16)', () {
      final d = dataWith(
        roStages: [roStage(80)],
        roStageReplacements: [roReplacement(90, 99)],
      );
      expect(
        () => validateBackup(d, appSchemaVersion: 18),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects an unknown RO stage type (U16, #34)', () {
      final d = dataWith(roStages: [roStage(80, stageType: 'uvLamp')]);
      expect(
        () => validateBackup(d, appSchemaVersion: 18),
        rejectedWith(BackupRejection.inconsistent),
      );
    });

    test('rejects a custom RO stage with a blank title (U16)', () {
      for (final title in const [null, '   ']) {
        final d = dataWith(
          roStages: [roStage(80, stageType: 'custom', title: title)],
        );
        expect(
          () => validateBackup(d, appSchemaVersion: 18),
          rejectedWith(BackupRejection.inconsistent),
          reason: 'title=$title',
        );
      }
    });

    test('rejects a sub-1-day RO lifespan (U16, #8 rule)', () {
      final d = dataWith(roStages: [roStage(80, lifespanDays: 0)]);
      expect(
        () => validateBackup(d, appSchemaVersion: 18),
        rejectedWith(BackupRejection.inconsistent),
      );
    });
  });

  group('full database round-trip', () {
    late Directory tempDir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('reeftracker-bk-');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

    /// Seeds a database with a representative spread of data across tables.
    Future<int> seed(AppDatabase db) async {
      final id = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db.insertReadingGroup(
        tankId: id,
        takenAt: DateTime(2026, 1, 1, 8),
        note: 'morning',
        values: const [
          (paramKey: 'ph', value: 8.1),
          (paramKey: 'alkalinity', value: 8.5),
        ],
      );
      await db.insertWaterChange(
        tankId: id,
        changedAt: DateTime(2026, 1, 2),
        amountLiters: 25,
      );
      await db.insertCarbonChange(
        tankId: id,
        changedAt: DateTime(2026, 1, 3),
        grams: 200,
      );
      await db.insertEquipmentCleaning(
        tankId: id,
        cleanedAt: DateTime(2026, 1, 4),
        note: 'skimmer',
      );
      await db.setRatioBounds(
        id,
        'mgca',
        amberLow: 2.6,
        greenLow: 2.9,
        greenHigh: 3.3,
        amberHigh: 3.6,
      );
      await db.insertReadingTemplate(
        tankId: id,
        name: 'Weekly big test',
        paramKeys: ['alkalinity', 'calcium'],
      );
      await db.insertMaintenanceSchedule(
        tankId: id,
        actionType: 'waterChange',
        cadenceDays: 14,
      );
      await db.setTestCadence((await db.getTrackedParameters(id)).first.id, 7);
      await db.setSetting('temp_unit', 'fahrenheit');
      // The device-scoped RO unit (U16).
      final stageId = await db.insertRoStage(
        stageType: 'diResin',
        lifespanDays: 120,
      );
      await db.insertRoReplacement(
        stageId: stageId,
        replacedAt: DateTime(2026, 1, 5),
        note: 'fresh resin',
      );
      return id;
    }

    test('encode from DB -> decode -> import reproduces every table', () async {
      final src = newDb();
      addTearDown(src.close);
      final id = await seed(src);

      final json = await encodeBackupFromDb(src);
      final data = decodeBackup(json);

      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);

      // Tank identity and ids preserved.
      final tanks = await dst.getAllTanks();
      expect(tanks.length, 1);
      expect(tanks.single.id, id);
      expect(tanks.single.name, 'Reef');

      // Counts match the source across the data tables.
      expect(
        (await dst.getAllReadings()).length,
        (await src.getAllReadings()).length,
      );
      expect((await dst.getAllWaterChanges()).length, 1);
      expect((await dst.getAllCarbonChanges()).length, 1);
      expect((await dst.getAllEquipmentCleanings()).length, 1);
      expect((await dst.getAllRatioVisibilities()).length, 1);
      final restoredTemplate = (await dst.getAllReadingTemplates()).single;
      expect(restoredTemplate.name, 'Weekly big test');
      expect(restoredTemplate.keys, ['alkalinity', 'calcium']);
      final restoredSchedule = (await dst.getAllMaintenanceSchedules()).single;
      expect(restoredSchedule.actionType, 'waterChange');
      expect(restoredSchedule.cadenceDays, 14);
      expect(
        (await dst.getAllTrackedParameters())
            .firstWhere((p) => p.testCadenceDays != null)
            .testCadenceDays,
        7,
      );
      expect(
        (await dst.getAllTrackedParameters()).length,
        (await src.getAllTrackedParameters()).length,
      );
      // The RO unit (U16) rides the backup, ids and FK link intact.
      final restoredStage = (await dst.getAllRoStages()).single;
      expect(restoredStage.stageType, 'diResin');
      expect(restoredStage.lifespanDays, 120);
      final restoredReplacement =
          (await dst.getAllRoStageReplacements()).single;
      expect(restoredReplacement.stageId, restoredStage.id);
      expect(restoredReplacement.note, 'fresh resin');
      // temp_unit is a device-local preference: the backup's value must NOT be
      // imported (#18). dst had none, so it stays unset after restore.
      expect(await dst.getSetting('temp_unit'), isNull);
    });

    test('restore backfills group ids for readings without one (#15)', () async {
      final src = newDb();
      addTearDown(src.close);
      final id = await src.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      // Rows the way a pre-v13 backup delivers them: no group id, a batch
      // recognizable only by its shared timestamp.
      final t = DateTime(2026, 2, 1, 9);
      await src.insertReading(
        tankId: id,
        paramKey: 'ph',
        value: 8.1,
        takenAt: t,
      );
      await src.insertReading(
        tankId: id,
        paramKey: 'alkalinity',
        value: 8.5,
        takenAt: t,
      );
      await src.insertReading(
        tankId: id,
        paramKey: 'calcium',
        value: 420,
        takenAt: DateTime(2026, 2, 2, 9),
      );

      final data = decodeBackup(await encodeBackupFromDb(src));
      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);

      final all = await dst.getAllReadings();
      expect(
        all.every((r) => r.groupId != null),
        isTrue,
        reason: 'restore must leave no ungrouped rows behind',
      );
      final ph = all.firstWhere((r) => r.paramKey == 'ph');
      final group = await dst.readingGroup(ph);
      expect(
        group.map((r) => r.paramKey),
        unorderedEquals(['ph', 'alkalinity']),
        reason: 'the legacy same-timestamp batch stays one group',
      );
      expect(
        all.firstWhere((r) => r.paramKey == 'calcium').groupId,
        isNot(ph.groupId),
      );
    });

    test(
      'encode excludes soft-deleted tanks and their child rows (U10)',
      () async {
        final src = newDb();
        addTearDown(src.close);
        await seed(src);
        // A second tank inside its delete-undo window: it must not enter a
        // backup written during the window.
        final doomed = await src.createTankWithPreset(
          name: 'Doomed',
          type: SetupType.fishOnly,
        );
        await src.insertReading(
          tankId: doomed,
          paramKey: 'ph',
          value: 8.0,
          takenAt: DateTime(2026, 3, 1),
        );
        await src.insertMaintenanceSchedule(
          tankId: doomed,
          actionType: 'waterChange',
          cadenceDays: 7,
        );
        await src.softDeleteTank(doomed);

        final data = decodeBackup(await encodeBackupFromDb(src));
        expect(data.tanks.map((t) => t.name.value), ['Reef']);
        expect(data.params.map((p) => p.tankId.value), isNot(contains(doomed)));
        expect(
          data.readings.map((r) => r.tankId.value),
          isNot(contains(doomed)),
        );
        expect(
          data.maintenanceSchedules.map((s) => s.tankId.value),
          isNot(contains(doomed)),
        );
      },
    );

    test('restore preserves this device\'s local preferences (#18)', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src); // src stores temp_unit = fahrenheit
      final data = decodeBackup(await encodeBackupFromDb(src));

      final dst = newDb();
      addTearDown(dst.close);
      // This device's own preferences, set before the restore.
      await dst.setSetting('temp_unit', 'celsius');
      await dst.setSetting('locale', 'de');

      await importBackup(dst, data);

      // Device-local preferences are untouched — not overwritten by the backup.
      expect(await dst.getSetting('temp_unit'), 'celsius');
      expect(await dst.getSetting('locale'), 'de');
      // …while the aquarium data was restored.
      expect((await dst.getAllTanks()).length, 1);
    });

    test('import replaces existing data rather than appending', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src);
      final data = decodeBackup(await encodeBackupFromDb(src));

      final dst = newDb();
      addTearDown(dst.close);
      // Pre-existing tank that must be wiped by the restore.
      await dst.createTankWithPreset(name: 'Old', type: SetupType.sps);

      await importBackup(dst, data);

      final tanks = await dst.getAllTanks();
      expect(tanks.length, 1);
      expect(tanks.single.name, 'Reef');
    });

    test('imports an older backup missing later sections', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src);
      // Drop a table that older app versions did not export — such backups
      // predate the checksum too (T7), so drop that as well.
      final json = (await encodeBackupFromDb(src))
          .replaceFirst(
            RegExp(r',\s*"dosingEntries":\s*\[.*?\]', dotAll: true),
            '',
          )
          .replaceFirst(RegExp(r',\s*"checksum":\s*"[^"]*"'), '');
      final data = decodeBackup(json);

      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);

      expect(await dst.getAllDosingEntries(), isEmpty);
      expect((await dst.getAllTanks()).length, 1);
    });

    List<String> exportFilesIn(Directory dir) => dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where(
          (n) => n.startsWith('reeftracker-backup-') && n.endsWith('.json'),
        )
        .toList();

    test(
      'exportBackup leaves no plaintext temp file and sweeps stale ones',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await seed(db);

        // A leftover plaintext export from an earlier run that must be swept.
        await File(
          p.join(tempDir.path, 'reeftracker-backup-stale.json'),
        ).writeAsString('{}');

        // The share sheet is unavailable under `flutter test`; the cleanup in the
        // finally must still delete the freshly written file regardless.
        try {
          await exportBackup(db);
        } catch (_) {}

        expect(exportFilesIn(tempDir), isEmpty);
      },
    );

    test(
      'exportBackup sweeps lingering share_plus cache copies (#35)',
      () async {
        final db = newDb();
        addTearDown(db.close);
        await seed(db);

        // share_plus copies every shared XFile into <temp>/share_plus/ and only
        // clears it on the *next* share — simulate the copy a previous export
        // left behind, plus a foreign file that must not be touched.
        final shareDir = Directory(p.join(tempDir.path, 'share_plus'));
        await shareDir.create();
        final lingering = File(
          p.join(shareDir.path, 'reeftracker-backup-20260101-000000.json'),
        );
        await lingering.writeAsString('{}');
        final foreign = File(p.join(shareDir.path, 'photo.jpg'));
        await foreign.writeAsString('x');

        try {
          await exportBackup(db);
        } catch (_) {}

        expect(await lingering.exists(), isFalse);
        expect(await foreign.exists(), isTrue);
      },
    );

    /// Minimal companion builders for hand-assembled [BackupData] sets.
    TanksCompanion tankRow(int id) => TanksCompanion(
      id: Value(id),
      name: Value('Tank $id'),
      setupType: const Value('mixed'),
      createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
    );

    ReadingsCompanion readingRow(int id, int tankId) => ReadingsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      paramKey: const Value('alkalinity'),
      value: const Value(8.2),
      takenAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
    );

    BackupData bareData({
      List<TanksCompanion> tanks = const [],
      List<ReadingsCompanion> readings = const [],
      List<DosingEntriesCompanion> dosingEntries = const [],
    }) => BackupData(
      schemaVersion: 1,
      tanks: tanks,
      params: const [],
      readings: readings,
      waterChanges: const [],
      carbonChanges: const [],
      equipmentCleanings: const [],
      ratioVisibilities: const [],
      dosingEntries: dosingEntries,
      settings: const [],
    );

    test(
      'duplicate non-tank primary keys are rejected by the rehearsal',
      () async {
        // validateBackup only checks tank-id uniqueness; duplicate child PKs are
        // caught by the real SQLite engine during the rehearsal restore and
        // surfaced as `inconsistent`.
        final data = bareData(
          tanks: [tankRow(1)],
          readings: [readingRow(10, 1), readingRow(10, 1)],
        );
        final dst = newDb();
        addTearDown(dst.close);
        await expectLater(
          importBackup(dst, data),
          throwsA(
            isA<InvalidBackupException>().having(
              (e) => e.reason,
              'reason',
              BackupRejection.inconsistent,
            ),
          ),
        );
      },
    );

    test('a failed import leaves the live database untouched', () async {
      final dst = newDb();
      addTearDown(dst.close);
      await seed(dst);
      final tankBefore = (await dst.getAllTanks()).single;
      final readingsBefore = (await dst.getAllReadings()).length;

      // Passes the in-memory validation (unique tank ids, FKs resolve) but
      // fails in the rehearsal: duplicate reading primary keys.
      final bad = bareData(
        tanks: [tankRow(1)],
        readings: [readingRow(10, 1), readingRow(10, 1)],
      );
      await expectLater(
        importBackup(dst, bad),
        throwsA(isA<InvalidBackupException>()),
      );

      // The rehearsal caught it before any live table was touched.
      final tankAfter = (await dst.getAllTanks()).single;
      expect(tankAfter.id, tankBefore.id);
      expect(tankAfter.name, tankBefore.name);
      expect((await dst.getAllReadings()).length, readingsBefore);
      expect((await dst.getAllWaterChanges()).length, 1);
      expect((await dst.getAllRatioVisibilities()).length, 1);
    });

    test('rejects extreme, negative and zero row ids (#33)', () async {
      // Regression test for #33: an id of 2^63−1 exhausts SQLite AUTOINCREMENT
      // (no reading could ever be inserted again after restore); negative and
      // zero ids are bogus for AUTOINCREMENT columns. validateBackup rejects
      // anything outside 1..2^31 as `inconsistent`.
      const maxId = 0x7FFFFFFFFFFFFFFF; // 2^63 − 1
      for (final badId in [-5, 0, (1 << 31) + 1, maxId]) {
        final data = bareData(
          tanks: [tankRow(1)],
          readings: [readingRow(badId, 1)],
        );
        final dst = newDb();
        addTearDown(dst.close);
        await expectLater(
          importBackup(dst, data),
          throwsA(
            isA<InvalidBackupException>().having(
              (e) => e.reason,
              'reason',
              BackupRejection.inconsistent,
            ),
          ),
          reason: 'id $badId must be rejected',
        );
        expect(await dst.getAllReadings(), isEmpty);
      }

      // The 2^31 boundary itself still imports.
      final ok = bareData(
        tanks: [tankRow(1)],
        readings: [readingRow(1 << 31, 1)],
      );
      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, ok);
      expect((await dst.getAllReadings()).single.id, 1 << 31);
    });

    DosingEntriesCompanion dosingRow(
      int id, {
      String state = 'active',
      String? frequency,
      String? amountUnit,
      String? basis,
    }) => DosingEntriesCompanion(
      id: Value(id),
      tankId: const Value(1),
      product: const Value('Mystery'),
      state: Value(state),
      frequency: Value(frequency),
      amountUnit: Value(amountUnit),
      basis: Value(basis),
      createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
      startedAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
    );

    test('rejects unrecognized enum-ish strings (#34)', () async {
      // Regression test for #34: a garbage dosing `state` would restore into a
      // row that matches neither the active-plan filter nor history — an
      // unmanageable zombie; unknown setupType/frequency/amountUnit/basis
      // silently degrade behavior. validateBackup whitelists all of them.
      final badSets = <String, BackupData>{
        'setupType': bareData(
          tanks: [
            TanksCompanion(
              id: const Value(1),
              name: const Value('T'),
              setupType: const Value('not-a-setup-type'),
              createdAt: Value(DateTime.fromMillisecondsSinceEpoch(0)),
            ),
          ],
        ),
        'state': bareData(
          tanks: [tankRow(1)],
          dosingEntries: [dosingRow(50, state: 'bogus')],
        ),
        'frequency': bareData(
          tanks: [tankRow(1)],
          dosingEntries: [dosingRow(50, frequency: 'sometimes')],
        ),
        'amountUnit': bareData(
          tanks: [tankRow(1)],
          dosingEntries: [dosingRow(50, amountUnit: 'cups')],
        ),
        'basis': bareData(
          tanks: [tankRow(1)],
          dosingEntries: [dosingRow(50, basis: 'perMoon')],
        ),
      };
      for (final bad in badSets.entries) {
        final dst = newDb();
        addTearDown(dst.close);
        await expectLater(
          importBackup(dst, bad.value),
          throwsA(
            isA<InvalidBackupException>()
                .having((e) => e.reason, 'reason', BackupRejection.inconsistent)
                .having((e) => e.detail, 'detail', contains(bad.key)),
          ),
          reason: 'garbage ${bad.key} must be rejected',
        );
        expect(await dst.getAllDosingEntries(), isEmpty);
      }
    });

    test('accepts every known enum value, including nulls (#34)', () async {
      final data = bareData(
        tanks: [tankRow(1)],
        dosingEntries: [
          // `paused` is reserved for a later phase but is a legal stored value.
          dosingRow(
            50,
            state: 'paused',
            frequency: 'everyNDays',
            amountUnit: 'g',
            basis: 'perDose',
          ),
          // The nullable enum-ish columns may all be null.
          dosingRow(51),
        ],
      );
      final dst = newDb();
      addTearDown(dst.close);
      await importBackup(dst, data);
      expect((await dst.getAllDosingEntries()).length, 2);
    });

    test(
      'rejects a backup whose child rows reference a missing tank',
      () async {
        final data = BackupData(
          schemaVersion: 1,
          tanks: const [],
          params: [
            TrackedParametersCompanion.insert(
              tankId: 99,
              paramKey: 'ph',
              unit: 'pH',
            ),
          ],
          readings: const [],
          waterChanges: const [],
          carbonChanges: const [],
          equipmentCleanings: const [],
          ratioVisibilities: const [],
          dosingEntries: const [],
          settings: const [],
        );
        final dst = newDb();
        addTearDown(dst.close);
        await expectLater(
          importBackup(dst, data),
          throwsA(isA<InvalidBackupException>()),
        );
      },
    );
  });
}
