import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rb_family_handlers.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rb_snapshot.dart';
import 'package:reeftracker/data/wall_sources.dart';

RbDeviceInfo _info(String type, String model) =>
    RbDeviceInfo(hwType: type, hwModel: model, hwid: '$type-1');

void main() {
  group('ReefBeat family registry', () {
    test(
      'has exactly one handler for every sealed family and hardware type',
      () {
        expect(
          rbFamilyHandlers.values.map((handler) => handler.family),
          RbFamily.values,
        );
        expect(rbFamilyHandlers.supportedHardwareTypes, kRbSupportedHwTypes);
        expect(
          () => RbFamilyHandlerRegistry(const [RbDoseFamilyHandler()]),
          throwsArgumentError,
        );
        expect(
          () => RbFamilyHandlerRegistry(const [
            RbDoseFamilyHandler(),
            RbDoseFamilyHandler(),
          ]),
          throwsArgumentError,
        );
      },
    );

    test('model aliases and capabilities are family-owned', () {
      expect(rbFamilyHandlers.forModel('rsdose4')?.family, RbFamily.dose);
      expect(rbFamilyHandlers.forModel('RSATO+')?.family, RbFamily.ato);
      expect(rbFamilyHandlers.forModel('RSMAT1200')?.family, RbFamily.mat);
      expect(rbFamilyHandlers.forModel('RSRUN')?.family, RbFamily.run);
      expect(rbFamilyHandlers.forModel('RSLED160')?.family, RbFamily.light);
      expect(rbFamilyHandlers.forModel('RSWAVE99')?.family, RbFamily.wave);
      expect(
        rbFamilyHandlers.forModel('RSCONTROLLITE')?.family,
        RbFamily.control,
      );
      expect(rbFamilyHandlers.forModel('future-device'), isNull);
      expect(rbFamilyHandlers.savesModel('RSCONTROLPRO'), isTrue);
      expect(rbFamilyHandlers.savesModel('RSDOSE4'), isFalse);
      expect(
        rbFamilyHandlers
            .forModel('RSCONTROLPRO')
            ?.capabilities
            .contributesEnvironment,
        isTrue,
      );
    });
  });

  group('family-owned values and Wall facts', () {
    test('ReefControl alone supplies save and environment measurements', () {
      final snapshot = RbControlSnapshot(
        info: _info(kRbControlHwType, 'RSCONTROLPRO'),
        status: const RbControlStatus(
          probes: [RbControlProbe(type: 'ph', value: 8.15, temperatureC: 25.2)],
        ),
      );

      expect(rbFamilyHandlers.saveCandidates(snapshot), [
        (paramKey: 'ph', value: 8.15),
        (paramKey: 'temperature', value: 25.2),
      ]);
      expect(
        rbFamilyHandlers.environmentCandidates(snapshot),
        rbFamilyHandlers.saveCandidates(snapshot),
      );
      expect(rbFamilyHandlers.wallSnapshot(snapshot).readings, [
        (paramKey: 'ph', value: 8.15),
        (paramKey: 'temperature', value: 25.2),
      ]);
    });

    test('ATO normalizes readings, alarm state, stock, and signature', () {
      final snapshot = RbAtoSnapshot(
        info: _info(kRbAtoHwType, 'RSATO+'),
        status: const RbAtoStatus(
          waterLevelRaw: 'below',
          leakSensorConnected: true,
          leakSensorEnabled: true,
          leakAlarm: true,
          daysTillEmpty: 5,
          temperatureC: 25.4,
        ),
      );
      final wall = rbFamilyHandlers.wallSnapshot(snapshot);
      expect(wall.readings, [(paramKey: 'temperature', value: 25.4)]);
      final fact = wall.statusFacts.single as WallAtoFact;
      expect(fact.level, WallLevelState.below);
      expect(fact.leakAlarm, isTrue);
      expect(fact.stockLevel, WallStockLevel.critical);
      expect(wall.signature, contains('below'));
    });

    test('Dose, Mat, and Run expose only normalized status facts', () {
      final dose = RbDoseSnapshot(
        info: _info(kRbDosingHwType, 'RSDOSE4'),
        status: const RbDoseStatus(
          heads: [
            RbDoseHead(number: 1, supplement: 'Alkalinity', remainingDays: 10),
          ],
        ),
      );
      final mat = RbMatSnapshot(
        info: _info(kRbMatHwType, 'RSMAT'),
        status: const RbMatStatus(
          modeRaw: kRbMatEndOfRollMode,
          modelCode: 'RSMAT250',
        ),
      );
      final run = RbRunSnapshot(
        info: _info(kRbRunHwType, 'RSRUN'),
        status: const RbRunStatus(
          pumps: [
            RbRunPump(
              number: 1,
              type: 'skimmer',
              name: 'Skimmer',
              state: 'full_cup',
            ),
          ],
        ),
      );

      final doseFact =
          rbFamilyHandlers.wallSnapshot(dose).statusFacts.single
              as WallDoseFact;
      expect(doseFact.heads.single.label, 'Alkalinity');
      expect(doseFact.heads.single.stockLevel, WallStockLevel.caution);
      expect(
        rbFamilyHandlers.wallSnapshot(mat).statusFacts.single,
        isA<WallFilterRollFact>().having((fact) => fact.empty, 'empty', isTrue),
      );
      expect(mat.modelCode, 'RSMAT250');
      expect(
        rbFamilyHandlers.wallSnapshot(run).statusFacts.single,
        isA<WallSkimmerFact>().having(
          (fact) => fact.fullCup,
          'full cup',
          isTrue,
        ),
      );
    });

    test('Light and Wave are valid exhaustive status-only snapshots', () {
      final snapshots = <RbSnapshot>[
        RbLightSnapshot(
          info: _info(kRbLightsHwType, 'RSLED90'),
          status: const RbLightStatus(mode: 'auto'),
        ),
        RbWaveSnapshot(
          info: _info(kRbWaveHwType, 'RSWAVE25'),
          status: const RbWaveStatus(mode: 'auto'),
        ),
      ];
      for (final snapshot in snapshots) {
        expect(rbFamilyHandlers.saveCandidates(snapshot), isEmpty);
        expect(rbFamilyHandlers.wallSnapshot(snapshot).statusFacts, isEmpty);
      }
    });
  });
}
