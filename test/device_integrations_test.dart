import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/device_live.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/ap_device_link.dart';
import 'package:reeftracker/data/ap_protocol.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/device_integrations.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/device_vendors.dart';
import 'package:reeftracker/domain/hanna_meter.dart';

import 'fakes/fake_device_secrets.dart';

DeviceRecord _device({
  int id = 1,
  String kind = kDeviceKindReefFactory,
  String identifier = 'RF-1',
  String? model,
  String? address = '10.0.0.1',
  int? tankId = 1,
  int displayOrder = 0,
  String? username,
}) => DeviceRecord(
  id: id,
  kind: kind,
  identifier: identifier,
  model: model,
  address: address,
  tankId: tankId,
  firstSeenAt: DateTime(2026),
  displayOrder: displayOrder,
  username: username,
);

RfSnapshot _rfSnapshot({double temperature = 25}) => RfSnapshot(
  serial: 'RFTC012110010070',
  modelPrefix: kRfTempControllerModel,
  modelName: 'temperature',
  modelDisplayName: 'Temperature Controller',
  readings: [RfReading('temperature', temperature, '°C')],
);

RbSnapshot _rbSnapshot({String model = 'RSCONTROLPRO'}) => RbControlSnapshot(
  info: RbDeviceInfo(hwType: kRbControlHwType, hwModel: model, hwid: 'RB-1'),
  status: const RbControlStatus(
    probes: [RbControlProbe(type: 'ph', value: 8.2)],
  ),
);

ApStatus _apStatus() => const ApStatus(
  info: ApDeviceInfo(
    serial: 'AC5:1',
    hostname: 'apex',
    software: '5.04_7A18',
    hardware: '1.0',
    firmware: ApFirmware.aos5,
  ),
  probes: [ApProbe(did: 'base_pH', name: 'pH', type: 'pH', value: 8.1)],
  outlets: [],
);

class _RfLink implements RfDeviceLink {
  _RfLink(this.snapshot);

  final RfSnapshot snapshot;
  int reads = 0;

  @override
  Future<RfSnapshot> readOnce(String host) async {
    reads++;
    return snapshot;
  }
}

class _RbLink implements RbDeviceLink {
  _RbLink(this.snapshot);

  final RbSnapshot snapshot;
  int reads = 0;

  @override
  Future<RbSnapshot> readOnce(String host) async {
    reads++;
    return snapshot;
  }

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async => const [];
}

class _ApLink implements ApDeviceLink {
  _ApLink(this.status);

  final ApStatus status;
  int reads = 0;

  @override
  Future<ApStatus> readOnce(String host, ApCredentials credentials) async {
    reads++;
    return status;
  }
}

void main() {
  group('persisted device integration contract', () {
    test('kind IDs, registration order, and exact parsing stay stable', () {
      expect(
        [
          (DeviceKind.reefFactory, 'reeffactory'),
          (DeviceKind.reefBeat, 'reefbeat'),
          (DeviceKind.apex, 'apex'),
          (DeviceKind.hanna, 'hanna'),
        ],
        [for (final kind in kDeviceKinds) (kind, kind.id)],
      );
      expect(kKnownDeviceKindIds, {'reeffactory', 'reefbeat', 'apex', 'hanna'});
      for (final kind in kDeviceKinds) {
        expect(DeviceKind.tryParse(kind.id), kind);
      }
      expect(DeviceKind.tryParse('Apex'), isNull);
      expect(DeviceKind.tryParse('future-controller'), isNull);
    });

    test(
      'capabilities preserve polling, save, auth, and environment rules',
      () {
        expect(DeviceKind.reefFactory.capabilities.refreshes, isTrue);
        expect(DeviceKind.reefBeat.capabilities.contributesEnvironment, isTrue);
        expect(DeviceKind.apex.capabilities.authenticated, isTrue);
        expect(DeviceKind.apex.capabilities.contributesEnvironment, isFalse);
        expect(DeviceKind.hanna.capabilities.refreshes, isFalse);
        expect(DeviceKind.hanna.capabilities.containsSavableModels, isFalse);
        expect(DeviceKind.reefBeat.savesModel('RSCONTROLLITE'), isTrue);
        expect(DeviceKind.reefBeat.savesModel('RSDOSE4'), isFalse);
      },
    );

    test('protocol model and family aliases are an explicit inventory', () {
      expect(kRfModels.keys, ['RFSG01', 'RFPM01', 'RFTC01']);
      expect(kRbSupportedHwTypes, {
        'reef-dosing',
        'reef-ato',
        'reef-mat',
        'reef-run',
        'reef-lights',
        'reef-wave',
        'reef-control',
      });
      expect(kRbModelDisplayNames.keys, {
        'RSDOSE2',
        'RSDOSE4',
        'RSATO+',
        'RSMAT',
        'RSMAT250',
        'RSMAT500',
        'RSMAT1200',
        'RSRUN',
        'RSLED50',
        'RSLED90',
        'RSLED115',
        'RSLED160',
        'RSWAVE25',
        'RSWAVE45',
        'RSCONTROLLITE',
        'RSCONTROLPRO',
      });
      expect(
        const ApDeviceInfo(
          serial: 'AC5:12345',
          hostname: 'apex',
          software: '5.04',
          hardware: '1.0',
          firmware: ApFirmware.aos5,
        ).modelCode,
        'AC5',
      );
      expect(
        parseHannaInfo(
          'I,HI97115,06150128,FW,v1.07,SN,906150128111,English,v5.0',
        )?.model,
        'HI97115',
      );
    });

    test('named providers are aliases of the typed inventory family', () {
      expect(
        reefFactoryDevicesProvider,
        devicesOfKindProvider(DeviceKind.reefFactory),
      );
      expect(
        reefBeatDevicesProvider,
        devicesOfKindProvider(DeviceKind.reefBeat),
      );
      expect(apexDevicesProvider, devicesOfKindProvider(DeviceKind.apex));
      expect(hannaDevicesProvider, devicesOfKindProvider(DeviceKind.hanna));
    });
  });

  group('DeviceIntegrationRegistry', () {
    late _RfLink rf;
    late _RbLink rb;
    late _ApLink ap;
    late FakeDeviceSecrets secrets;
    late List<String> seen;
    late List<(int, String)> models;
    late DeviceIntegrationRegistry registry;

    setUp(() {
      rf = _RfLink(_rfSnapshot());
      rb = _RbLink(_rbSnapshot());
      ap = _ApLink(_apStatus());
      secrets = FakeDeviceSecrets({'AP-1': 'hunter2'});
      seen = [];
      models = [];
      registry = DeviceIntegrationRegistry([
        RfDeviceIntegration(
          link: rf,
          touchSeen: (identifier) async => seen.add(identifier),
        ),
        RbDeviceIntegration(
          link: rb,
          touchSeen: (identifier) async => seen.add(identifier),
          updateModel: (id, model) async => models.add((id, model)),
        ),
        ApDeviceIntegration(
          link: ap,
          secrets: secrets,
          touchSeen: (identifier) async => seen.add(identifier),
        ),
        const HannaDeviceIntegration(),
      ]);
    });

    test('registration order is explicit and complete', () {
      expect(registry.registeredKinds, kDeviceKinds);
      expect(
        () => DeviceIntegrationRegistry(const [HannaDeviceIntegration()]),
        throwsArgumentError,
      );
      expect(
        () => DeviceIntegrationRegistry([
          RfDeviceIntegration(link: rf, touchSeen: (_) async {}),
          RfDeviceIntegration(link: rf, touchSeen: (_) async {}),
        ]),
        throwsArgumentError,
      );
    });

    test(
      'reads route by persisted kind and retain vendor diagnostics',
      () async {
        final result = await registry.read(
          _device(model: kRfTempControllerModel),
        );
        expect(result.kind, DeviceKind.reefFactory);
        expect(result.hasFreshPayload, isTrue);
        expect(
          result.payloadAs<RfReadPayload>()?.snapshot.readings.single.value,
          25,
        );
        expect(rf.reads, 1);
        expect(seen, ['RF-1']);
      },
    );

    test(
      'unknown kinds are unsupported and never fall through to Apex',
      () async {
        final result = await registry.read(
          _device(kind: 'future-controller', identifier: 'FUTURE-1'),
        );
        expect(result.kind, isNull);
        expect(result.failure?.kind, DeviceReadFailureKind.unsupportedKind);
        expect(rf.reads, 0);
        expect(rb.reads, 0);
        expect(ap.reads, 0);
        expect(seen, isEmpty);
        expect(
          registry.valuesToSave(
            _device(kind: 'future-controller'),
            result,
            const [],
          ),
          isEmpty,
        );
      },
    );

    test(
      'missing addresses and missing Apex secrets avoid network traffic',
      () async {
        final missingAddress = await registry.read(_device(address: null));
        expect(
          missingAddress.failure?.kind,
          DeviceReadFailureKind.missingAddress,
        );

        final missingSecret = await registry.read(
          _device(
            kind: kDeviceKindApex,
            identifier: 'AP-NO-SECRET',
            username: 'admin',
          ),
        );
        expect(
          missingSecret.failure?.kind,
          DeviceReadFailureKind.authenticationRequired,
        );
        expect(missingSecret.failure?.cause, ApLinkError.auth);
        expect(ap.reads, 0);
      },
    );

    test('a failed refresh can retain the matching last-good payload', () {
      final previous = DeviceReadResult.success(
        DeviceKind.reefFactory,
        RfReadPayload(_rfSnapshot(temperature: 24.8)),
      );
      final failed = DeviceReadResult.failed(
        DeviceKind.reefFactory,
        const DeviceReadFailure(
          DeviceReadFailureKind.timeout,
          cause: RfLinkError.timeout,
        ),
      ).retainPayloadFrom(previous);

      expect(failed.failure?.kind, DeviceReadFailureKind.timeout);
      expect(
        failed.payloadAs<RfReadPayload>()?.snapshot.readings.single.value,
        24.8,
      );
      expect(failed.hasFreshPayload, isFalse);
    });

    test(
      'normalized live state retains last-good payload through a failure',
      () {
        final previous = DeviceLiveState.completed(
          DeviceReadResult.success(
            DeviceKind.reefFactory,
            RfReadPayload(_rfSnapshot(temperature: 24.8)),
          ),
        );
        final loading = DeviceLiveState.loadingFrom(previous);
        final completed = DeviceLiveState.completed(
          DeviceReadResult.failed(
            DeviceKind.reefFactory,
            const DeviceReadFailure(
              DeviceReadFailureKind.timeout,
              cause: RfLinkError.timeout,
            ),
          ),
          previous: loading,
        );

        expect(loading.loading, isTrue);
        expect(completed.loading, isFalse);
        expect(completed.rf.snapshot?.readings.single.value, 24.8);
        expect(completed.rf.error, RfLinkError.timeout);
      },
    );

    test(
      'cleanup hooks remove Apex credentials and leave other kinds alone',
      () async {
        final apex = _device(
          kind: kDeviceKindApex,
          identifier: 'AP-1',
          username: 'admin',
        );
        await registry.cleanup(apex);
        expect(secrets.secrets, isEmpty);

        secrets.secrets['AP-1'] = 'new-secret';
        await registry.cleanup(_device(identifier: 'RF-1'));
        expect(secrets.secrets, {'AP-1': 'new-secret'});
      },
    );

    test('ReefBeat read refines its persisted model', () async {
      final result = await registry.read(
        _device(
          id: 7,
          kind: kDeviceKindReefBeat,
          identifier: 'RB-1',
          model: 'RSCONTROLLITE',
        ),
      );
      expect(result.payloadAs<RbReadPayload>(), isNotNull);
      expect(models, [(7, 'RSCONTROLPRO')]);
      expect(seen, ['RB-1']);
    });

    test('save extraction is owned by each registered integration', () async {
      final rfDevice = _device(model: kRfTempControllerModel);
      final rfResult = await registry.read(rfDevice);
      expect(registry.valuesToSave(rfDevice, rfResult, [rfDevice]), [
        (paramKey: 'temperature', value: 25.0),
      ]);

      final rbDevice = _device(
        id: 2,
        kind: kDeviceKindReefBeat,
        identifier: 'RB-1',
        model: 'RSCONTROLPRO',
      );
      final rbResult = await registry.read(rbDevice);
      expect(registry.valuesToSave(rbDevice, rbResult, [rbDevice]), [
        (paramKey: 'ph', value: 8.2),
      ]);

      final apDevice = _device(
        id: 3,
        kind: kDeviceKindApex,
        identifier: 'AP-1',
        model: 'AC5',
        username: 'admin',
      );
      final apResult = await registry.read(apDevice);
      expect(registry.valuesToSave(apDevice, apResult, [apDevice]), [
        (paramKey: 'ph', value: 8.1),
      ]);
    });

    test(
      'integrations contribute environment sources in vendor/card order',
      () {
        final sources = registry.environmentSourcesForTank(
          tankId: 1,
          vendorOrder: const [
            DeviceKind.reefBeat,
            DeviceKind.reefFactory,
            DeviceKind.apex,
            DeviceKind.hanna,
          ],
          devicesByKind: {
            DeviceKind.reefFactory: [
              _device(identifier: 'rf-later', displayOrder: 2),
              _device(identifier: 'rf-first', displayOrder: 1),
            ],
            DeviceKind.reefBeat: [
              _device(
                kind: kDeviceKindReefBeat,
                identifier: 'rb-control',
                model: 'RSCONTROLPRO',
              ),
              _device(
                id: 4,
                kind: kDeviceKindReefBeat,
                identifier: 'rb-dose',
                model: 'RSDOSE4',
              ),
            ],
            DeviceKind.apex: [
              _device(
                kind: kDeviceKindApex,
                identifier: 'AP-1',
                username: 'admin',
              ),
            ],
          },
        );

        expect(sources.map((source) => source.identifier), [
          'rb-control',
          'rf-first',
          'rf-later',
        ]);
      },
    );
  });
}
