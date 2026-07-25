// Environment capture (U37): the device-agnostic source abstraction and the
// one-value-per-parameter selection algorithm behind the Hanna results step's
// Environment card.

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/environment_sources.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';

DeviceRecord _device({
  int id = 1,
  String identifier = 'RFSG01AAAA',
  String? name,
  String? model = 'RFSG01',
  String? address = '10.0.0.10',
  int? tankId = 1,
}) => DeviceRecord(
  id: id,
  kind: 'reeffactory',
  identifier: identifier,
  name: name,
  model: model,
  address: address,
  tankId: tankId,
  firstSeenAt: DateTime(2026),
  displayOrder: 0,
);

EnvSourceReadings _result({
  required String identifier,
  String? displayName,
  Set<String> primaryParams = const {},
  DateTime? takenAt,
  required List<({String paramKey, double value})> readings,
}) => (
  identifier: identifier,
  displayName: displayName ?? identifier,
  primaryParams: primaryParams,
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

    test('a dedicated device beats an incidental reading regardless of order',
        () {
      // The U36 temperature-source rule, generalized: the Temperature
      // Controller's temperature wins over the Salinity Guardian's — in both
      // arrival orders, and even though the Guardian's read is fresher.
      final guardian = _result(
        identifier: 'RFSG01AAAA',
        displayName: 'Guardian',
        primaryParams: {'salinity'},
        takenAt: DateTime(2026, 7, 24, 10, 5),
        readings: [
          (paramKey: 'salinity', value: 1.0255),
          (paramKey: 'temperature', value: 25.9),
        ],
      );
      final controller = _result(
        identifier: 'RFTC01BBBB',
        displayName: 'Controller',
        primaryParams: {'temperature'},
        takenAt: DateTime(2026, 7, 24, 10),
        readings: [(paramKey: 'temperature', value: 25.2)],
      );
      for (final order in [
        [guardian, controller],
        [controller, guardian],
      ]) {
        final picked = selectEnvironmentValues(order);
        expect(picked['temperature']?.value, 25.2);
        expect(picked['temperature']?.deviceName, 'Controller');
        expect(picked['salinity']?.value, 1.0255);
      }
    });

    test('among equals the fresher read wins', () {
      final picked = selectEnvironmentValues([
        _result(
          identifier: 'A',
          primaryParams: {'temperature'},
          takenAt: DateTime(2026, 7, 24, 10),
          readings: [(paramKey: 'temperature', value: 25.0)],
        ),
        _result(
          identifier: 'B',
          primaryParams: {'temperature'},
          takenAt: DateTime(2026, 7, 24, 10, 1),
          readings: [(paramKey: 'temperature', value: 25.5)],
        ),
      ]);
      expect(picked['temperature']?.value, 25.5);
    });

    test('a full tie breaks on identifier, so the choice is stable', () {
      final at = DateTime(2026, 7, 24, 10);
      final a = _result(
        identifier: 'AAA',
        takenAt: at,
        readings: [(paramKey: 'ph', value: 8.1)],
      );
      final b = _result(
        identifier: 'BBB',
        takenAt: at,
        readings: [(paramKey: 'ph', value: 8.3)],
      );
      expect(selectEnvironmentValues([a, b])['ph']?.value, 8.1);
      expect(selectEnvironmentValues([b, a])['ph']?.value, 8.1);
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
      final sources = environmentSourcesForTank(
        tankId: 1,
        rfDevices: [
          _device(id: 1, identifier: 'RFSG01AAAA', tankId: 1),
          _device(id: 2, identifier: 'RFPM01BBBB', tankId: 2),
          _device(id: 3, identifier: 'RFTC01CCCC', tankId: 1, address: null),
          _device(id: 4, identifier: 'RFTC01DDDD', tankId: null),
        ],
        rfLink: link,
      );
      expect([for (final s in sources) s.identifier], ['RFSG01AAAA']);
    });
  });

  group('RfEnvironmentSource', () {
    test('declares the model-specific primary parameter', () {
      final link = _FakeRfLink(const {});
      expect(
        RfEnvironmentSource(_device(model: 'RFSG01'), link).primaryParams,
        {'salinity'},
      );
      expect(
        RfEnvironmentSource(_device(model: 'RFPM01'), link).primaryParams,
        {'ph'},
      );
      expect(
        RfEnvironmentSource(_device(model: 'RFTC01'), link).primaryParams,
        {'temperature'},
      );
      expect(
        RfEnvironmentSource(_device(model: 'RFXX99'), link).primaryParams,
        isEmpty,
      );
    });

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
}
