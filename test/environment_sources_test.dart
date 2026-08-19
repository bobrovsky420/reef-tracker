// Environment capture (U37): the device-agnostic source abstraction and the
// one-value-per-parameter selection algorithm behind the Hanna results step's
// Environment card.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/environment_sources.dart';
import 'package:reeftracker/data/rb_device_link.dart';
import 'package:reeftracker/data/rb_protocol.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/domain/device_vendors.dart';
import 'package:reeftracker/domain/pro_features.dart';
import 'package:reeftracker/domain/setup_type.dart';

DeviceRecord _device({
  int id = 1,
  String kind = 'reeffactory',
  String identifier = 'RFSG01AAAA',
  String? name,
  String? model = 'RFSG01',
  String? address = '10.0.0.10',
  int? tankId = 1,
  int displayOrder = 0,
}) => DeviceRecord(
  id: id,
  kind: kind,
  identifier: identifier,
  name: name,
  model: model,
  address: address,
  tankId: tankId,
  firstSeenAt: DateTime(2026),
  displayOrder: displayOrder,
);

EnvSourceReadings _result({
  required String identifier,
  String? displayName,
  DateTime? takenAt,
  required List<({String paramKey, double value})> readings,
}) => (
  identifier: identifier,
  displayName: displayName ?? identifier,
  takenAt: takenAt ?? DateTime(2026, 7, 24, 10),
  readings: readings,
);

/// Scripted [RfDeviceLink]: one snapshot (or error) per address.
class _FakeRfLink implements RfDeviceLink {
  _FakeRfLink(this.snapshots);
  final Map<String, RfSnapshot> snapshots;

  @override
  Future<RfSnapshot> readOnce(String host) async {
    final snap = snapshots[host];
    if (snap == null) {
      throw const RfLinkException(RfLinkError.unreachable);
    }
    return snap;
  }
}

/// Scripted [RbDeviceLink]: one ReefControl snapshot (or error) per address.
class _FakeRbLink implements RbDeviceLink {
  _FakeRbLink(this.snapshots);
  final Map<String, RbSnapshot> snapshots;

  @override
  Future<RbSnapshot> readOnce(String host) async {
    final snap = snapshots[host];
    if (snap == null) {
      throw const RbLinkException(RbLinkError.unreachable);
    }
    return snap;
  }

  @override
  Future<List<RbDoseQueueEntry>> readDosingQueue(String host) async => const [];
}

RbSnapshot _rbSnapshot(List<RbControlProbe> probes) => RbControlSnapshot(
  info: const RbDeviceInfo(
    hwType: kRbControlHwType,
    hwModel: 'RSCONTROLPRO',
    hwid: 'RB-CONTROL-1',
  ),
  status: RbControlStatus(probes: probes),
);

RfSnapshot _snapshot(List<RfReading> readings) => RfSnapshot(
  serial: 'RFSG01AAAA',
  modelPrefix: 'RFSG01',
  modelName: 'salinity',
  modelDisplayName: 'Salinity Guardian',
  readings: readings,
);

void main() {
  group('selectEnvironmentValues', () {
    test('empty input selects nothing', () {
      expect(selectEnvironmentValues(const []), isEmpty);
    });

    test('the first source wins even when a later reading is fresher', () {
      final picked = selectEnvironmentValues([
        _result(
          identifier: 'A',
          takenAt: DateTime(2026, 7, 24, 10),
          readings: [(paramKey: 'temperature', value: 25.0)],
        ),
        _result(
          identifier: 'B',
          takenAt: DateTime(2026, 7, 24, 10, 1),
          readings: [(paramKey: 'temperature', value: 25.5)],
        ),
      ]);
      expect(picked['temperature']?.value, 25.0);
      expect(picked['temperature']?.deviceName, 'A');
    });

    test('the first reading within one device wins', () {
      final picked = selectEnvironmentValues([
        _result(
          identifier: 'control',
          readings: [
            (paramKey: 'temperature', value: 25.1),
            (paramKey: 'temperature', value: 26.4),
          ],
        ),
      ]);
      expect(picked['temperature']?.value, 25.1);
    });

    test('non-environment parameters are ignored', () {
      final picked = selectEnvironmentValues([
        _result(
          identifier: 'A',
          readings: [
            (paramKey: 'alkalinity', value: 8.0),
            (paramKey: 'ph', value: 8.2),
          ],
        ),
      ]);
      expect(picked.keys, ['ph']);
    });
  });

  group('environmentSourcesForTank', () {
    test('filters by tank assignment and usable address', () {
      final link = _FakeRfLink(const {});
      final rbLink = _FakeRbLink(const {});
      final sources = environmentSourcesForTank(
        tankId: 1,
        vendorOrder: kDeviceVendors,
        rfDevices: [
          _device(id: 1, identifier: 'RFSG01AAAA', tankId: 1),
          _device(id: 2, identifier: 'RFPM01BBBB', tankId: 2),
          _device(id: 3, identifier: 'RFTC01CCCC', tankId: 1, address: null),
          _device(id: 4, identifier: 'RFTC01DDDD', tankId: null),
        ],
        rfLink: link,
        rbDevices: [
          _device(
            id: 5,
            kind: 'reefbeat',
            identifier: 'RB-CONTROL-1',
            model: 'RSCONTROLPRO',
            address: '10.0.0.20',
          ),
          _device(
            id: 6,
            kind: 'reefbeat',
            identifier: 'RB-DOSE-1',
            model: 'RSDOSE4',
            address: '10.0.0.21',
          ),
        ],
        rbLink: rbLink,
      );
      expect(
        [for (final s in sources) s.identifier],
        ['RFSG01AAAA', 'RB-CONTROL-1'],
      );
    });

    test('uses vendor order, then card order within each vendor', () {
      final sources = environmentSourcesForTank(
        tankId: 1,
        vendorOrder: const [
          kDeviceKindReefBeat,
          kDeviceKindReefFactory,
          kDeviceKindApex,
          kDeviceKindHanna,
        ],
        rfDevices: [
          _device(identifier: 'rf-later', displayOrder: 2),
          _device(identifier: 'rf-first', displayOrder: 1),
        ],
        rfLink: _FakeRfLink(const {}),
        rbDevices: [
          _device(
            kind: kDeviceKindReefBeat,
            identifier: 'rb-later',
            model: 'RSCONTROLPRO',
            displayOrder: 3,
          ),
          _device(
            kind: kDeviceKindReefBeat,
            identifier: 'rb-first',
            model: 'RSCONTROLLITE',
            displayOrder: 0,
          ),
        ],
        rbLink: _FakeRbLink(const {}),
      );

      expect(
        [for (final source in sources) source.identifier],
        ['rb-first', 'rb-later', 'rf-first', 'rf-later'],
      );
    });
  });

  group('RfEnvironmentSource', () {
    test('display name falls back name → model → identifier', () {
      final link = _FakeRfLink(const {});
      expect(
        RfEnvironmentSource(_device(name: 'Sump meter'), link).displayName,
        'Sump meter',
      );
      expect(RfEnvironmentSource(_device(), link).displayName, 'RFSG01');
      expect(
        RfEnvironmentSource(_device(model: null), link).displayName,
        'RFSG01AAAA',
      );
    });

    test('read converts salinity to specific gravity and drops impossible '
        'values', () async {
      final link = _FakeRfLink({
        '10.0.0.10': _snapshot(const [
          RfReading('salinity', 34.6, 'ppt'),
          RfReading('temperature', -40.0, '°C'), // impossible → dropped
        ]),
      });
      final result = await RfEnvironmentSource(_device(), link).read();
      expect(result.readings, hasLength(1));
      expect(result.readings.single.paramKey, 'salinity');
      // 34.6 ppt lands in the plausible specific-gravity band, not raw ppt.
      expect(result.readings.single.value, closeTo(1.026, 0.002));
    });

    test('read surfaces transport failure', () {
      final link = _FakeRfLink(const {});
      expect(
        RfEnvironmentSource(_device(), link).read(),
        throwsA(isA<RfLinkException>()),
      );
    });

    test('read throws unreachable when the device has no address', () {
      final link = _FakeRfLink(const {});
      expect(
        RfEnvironmentSource(_device(address: null), link).read(),
        throwsA(isA<RfLinkException>()),
      );
    });
  });

  group('RbEnvironmentSource', () {
    DeviceRecord device({String? address = '10.0.0.20'}) => _device(
      kind: 'reefbeat',
      identifier: 'RB-CONTROL-1',
      name: 'ReefControl',
      model: 'RSCONTROLPRO',
      address: address,
    );

    test(
      'offers all probe values and the first probe temperature to Hanna',
      () async {
        final source = RbEnvironmentSource(
          device(),
          _FakeRbLink({
            '10.0.0.20': _rbSnapshot(const [
              RbControlProbe(type: 'ec', ppt: 35, temperatureC: 25.1),
              RbControlProbe(type: 'orp', value: 410),
              RbControlProbe(type: 'ph', value: 8.2, temperatureC: 26.4),
            ]),
          }),
        );

        final result = await source.read();
        expect(result.readings.map((r) => r.paramKey), [
          'salinity',
          'temperature',
          'orp',
          'ph',
        ]);
        expect(
          result.readings.firstWhere((r) => r.paramKey == 'temperature').value,
          25.1,
        );
      },
    );

    test('read throws unreachable when the device has no address', () {
      expect(
        RbEnvironmentSource(
          device(address: null),
          _FakeRbLink(const {}),
        ).read(),
        throwsA(isA<RbLinkException>()),
      );
    });
  });

  test(
    'Hanna environment provider includes assigned ReefControl values',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tankId = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db.upsertReefBeatDevice(
        identifier: 'RB-CONTROL-1',
        model: 'RSCONTROLPRO',
        address: '10.0.0.20',
        name: 'ReefControl',
        tankId: tankId,
      );
      final rbLink = _FakeRbLink({
        '10.0.0.20': _rbSnapshot(const [
          RbControlProbe(type: 'ec', ppt: 35, temperatureC: 25.1),
          RbControlProbe(type: 'orp', value: 410),
          RbControlProbe(type: 'ph', value: 8.2, temperatureC: 26.4),
        ]),
      });
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          rbDeviceLinkProvider.overrideWithValue(rbLink),
          rfDeviceLinkProvider.overrideWithValue(_FakeRfLink(const {})),
          proCapabilityProvider(
            ProCapabilityBoundary.connectedDeviceLiveIo,
          ).overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        environmentSourcesProvider(tankId),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      for (
        var i = 0;
        i < 200 && container.read(environmentSourcesProvider(tankId)).isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final sources = container.read(environmentSourcesProvider(tankId));
      expect(sources.map((s) => s.identifier), ['RB-CONTROL-1']);

      final selected = selectEnvironmentValues([await sources.single.read()]);
      expect(selected.keys, {'salinity', 'temperature', 'orp', 'ph'});
      expect(selected['temperature']?.value, 25.1);
    },
  );
}
