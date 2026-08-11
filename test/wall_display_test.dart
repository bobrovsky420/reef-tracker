import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/wall_display.dart';

void main() {
  group('inNightWindow', () {
    test('window crossing midnight covers both sides', () {
      const from = 22 * 60, to = 7 * 60; // 22:00–07:00
      expect(inNightWindow(21 * 60 + 59, from: from, to: to), isFalse);
      expect(inNightWindow(22 * 60, from: from, to: to), isTrue);
      expect(inNightWindow(23 * 60 + 59, from: from, to: to), isTrue);
      expect(inNightWindow(0, from: from, to: to), isTrue);
      expect(inNightWindow(6 * 60 + 59, from: from, to: to), isTrue);
      expect(inNightWindow(7 * 60, from: from, to: to), isFalse);
      expect(inNightWindow(12 * 60, from: from, to: to), isFalse);
    });

    test('same-day window is a plain range', () {
      const from = 13 * 60, to = 15 * 60;
      expect(inNightWindow(12 * 60 + 59, from: from, to: to), isFalse);
      expect(inNightWindow(13 * 60, from: from, to: to), isTrue);
      expect(inNightWindow(14 * 60 + 59, from: from, to: to), isTrue);
      expect(inNightWindow(15 * 60, from: from, to: to), isFalse);
    });

    test('degenerate window (from == to) never dims', () {
      expect(inNightWindow(9 * 60, from: 540, to: 540), isFalse);
      expect(inNightWindow(0, from: 540, to: 540), isFalse);
    });
  });

  group('bucketStartFor', () {
    test('floors onto the 5-minute epoch grid', () {
      final t = DateTime.fromMillisecondsSinceEpoch(1000 * (300 * 7 + 299));
      expect(
        bucketStartFor(t),
        DateTime.fromMillisecondsSinceEpoch(1000 * 300 * 7),
      );
      // A poll 30 s later lands in the same bucket.
      expect(
        bucketStartFor(t.add(const Duration(seconds: 1))),
        isNot(bucketStartFor(t)),
      );
      expect(
        bucketStartFor(t.subtract(const Duration(seconds: 30))),
        bucketStartFor(t),
      );
    });
  });

  group('wallPollInterval', () {
    const base = Duration(minutes: 5);

    test('no backoff: the display interval, floored per kind', () {
      expect(wallPollInterval(base: base), base);
      expect(
        wallPollInterval(base: base, floor: const Duration(minutes: 15)),
        const Duration(minutes: 15),
      );
      // A floor below the base changes nothing.
      expect(
        wallPollInterval(base: base, floor: const Duration(minutes: 1)),
        base,
      );
    });

    test('failures double up to the 30 min ceiling', () {
      expect(
        wallPollInterval(base: base, failures: 1),
        const Duration(minutes: 10),
      );
      expect(
        wallPollInterval(base: base, failures: 2),
        const Duration(minutes: 20),
      );
      expect(wallPollInterval(base: base, failures: 3), kWallBackoffCeiling);
      expect(wallPollInterval(base: base, failures: 30), kWallBackoffCeiling);
    });

    test('unchanged payloads back off only beyond the threshold', () {
      expect(
        wallPollInterval(
          base: base,
          unchangedPolls: kWallUnchangedPollsBeforeBackoff,
        ),
        base,
      );
      expect(
        wallPollInterval(
          base: base,
          unchangedPolls: kWallUnchangedPollsBeforeBackoff + 1,
        ),
        base * 2,
      );
      expect(
        wallPollInterval(base: base, unchangedPolls: 100),
        kWallBackoffCeiling,
      );
    });
  });

  group('WallPollSchedule', () {
    const base = Duration(minutes: 5);

    test('starts due, success schedules at base, failure doubles', () {
      final s = WallPollSchedule();
      final t0 = DateTime(2026, 8, 11, 12);
      expect(s.isDue(t0), isTrue);
      s.onSuccess(t0, base, 'a=1');
      expect(s.nextDue, t0.add(base));
      expect(s.isDue(t0.add(base)), isTrue);
      s.onFailure(t0.add(base), base);
      expect(s.nextDue, t0.add(base).add(base * 2));
      // First success resets the failure backoff.
      final t1 = s.nextDue;
      s.onSuccess(t1, base, 'a=2');
      expect(s.nextDue, t1.add(base));
      expect(s.failures, 0);
    });

    test('unchanged payloads accumulate; a change resets', () {
      final s = WallPollSchedule();
      var t = DateTime(2026, 8, 11);
      for (var i = 0; i <= kWallUnchangedPollsBeforeBackoff; i++) {
        s.onSuccess(t, base, 'same');
        t = s.nextDue;
      }
      expect(s.unchangedPolls, kWallUnchangedPollsBeforeBackoff);
      // One more unchanged poll crosses the threshold and doubles.
      s.onSuccess(t, base, 'same');
      expect(s.nextDue, t.add(base * 2));
      s.onSuccess(s.nextDue, base, 'different');
      expect(s.unchangedPolls, 0);
    });
  });

  test('wallPayloadSignature is order-independent', () {
    expect(
      wallPayloadSignature([
        (paramKey: 'ph', value: 8.1),
        (paramKey: 'temperature', value: 25.0),
      ]),
      wallPayloadSignature([
        (paramKey: 'temperature', value: 25.0),
        (paramKey: 'ph', value: 8.1),
      ]),
    );
    expect(
      wallPayloadSignature([(paramKey: 'ph', value: 8.1)]),
      isNot(wallPayloadSignature([(paramKey: 'ph', value: 8.2)])),
    );
  });

  group('buildWallCards', () {
    test('default order groups duplicates adjacently in tracked order, '
        'no-device card only where nothing reports', () {
      final cards = buildWallCards(
        trackedKeys: ['alkalinity', 'temperature', 'salinity'],
        reportedByDevice: {
          'apex1': ['temperature', 'salinity', 'ph'],
          'rfsg1': ['salinity', 'temperature'],
        },
        rows: const [],
      );
      expect(cards.every((c) => c.visible), isTrue);
      expect(
        [for (final c in cards) '${c.id.deviceIdentifier}:${c.id.paramKey}'],
        [
          // Alkalinity: tracked, nothing reports it — stored-readings card.
          ':alkalinity',
          // Temperature: both devices, adjacent, in device page order.
          'apex1:temperature',
          'rfsg1:temperature',
          'apex1:salinity',
          'rfsg1:salinity',
          // pH is reported but untracked — after the tracked ones.
          'apex1:ph',
        ],
      );
    });

    test('explicit displayOrder wins; new cards append after it', () {
      final cards = buildWallCards(
        trackedKeys: ['temperature', 'ph'],
        reportedByDevice: {
          'apex1': ['temperature', 'ph'],
          'newdev': ['temperature'],
        },
        rows: const [
          WallTileConfig(
            deviceIdentifier: 'apex1',
            paramKey: 'ph',
            displayOrder: 0,
          ),
          WallTileConfig(
            deviceIdentifier: 'apex1',
            paramKey: 'temperature',
            displayOrder: 1,
          ),
        ],
      );
      expect(
        [for (final c in cards) '${c.id.deviceIdentifier}:${c.id.paramKey}'],
        [
          'apex1:ph',
          'apex1:temperature',
          // The later-arriving device never interleaves into the arrangement.
          'newdev:temperature',
        ],
      );
    });

    test('a hidden row hides its card; others stay visible', () {
      // The common edit on a Salinity Guardian: hide the incidental
      // temperature, keep salinity. Both rows exist — the wall materializes
      // rows for every discovered card in the same poll (`_recordSamples`),
      // so a lone hidden row with a row-less sibling cannot arise.
      final cards = buildWallCards(
        trackedKeys: ['temperature'],
        reportedByDevice: {
          'rfsg1': ['salinity', 'temperature'],
        },
        rows: const [
          WallTileConfig(deviceIdentifier: 'rfsg1', paramKey: 'salinity'),
          WallTileConfig(
            deviceIdentifier: 'rfsg1',
            paramKey: 'temperature',
            visible: false,
          ),
        ],
      );
      final byId = {
        for (final c in cards) '${c.id.deviceIdentifier}:${c.id.paramKey}': c,
      };
      expect(byId['rfsg1:temperature']!.visible, isFalse);
      expect(byId['rfsg1:salinity']!.visible, isTrue);
      // The hidden device card does NOT resurrect a stored-readings card:
      // hiding means "not measured at all" (§12q).
      expect(byId.containsKey(':temperature'), isFalse);
    });

    test('new cards from a muted device default to hidden', () {
      const rows = [
        WallTileConfig(
          deviceIdentifier: 'rfpm1',
          paramKey: 'ph',
          visible: false,
        ),
      ];
      expect(isWallDeviceMuted('rfpm1', rows), isTrue);
      final cards = buildWallCards(
        trackedKeys: ['ph'],
        reportedByDevice: {
          // Firmware update grew a second reading — it must arrive hidden.
          'rfpm1': ['ph', 'temperature'],
        },
        rows: rows,
      );
      expect(cards.where((c) => c.visible), isEmpty);
      // Un-hiding any card clears the mute.
      expect(
        isWallDeviceMuted('rfpm1', const [
          WallTileConfig(
            deviceIdentifier: 'rfpm1',
            paramKey: 'ph',
            visible: false,
          ),
          WallTileConfig(deviceIdentifier: 'rfpm1', paramKey: 'temperature'),
        ]),
        isFalse,
      );
    });
  });

  group('wallPolledDevices', () {
    test('unknown devices poll; fully hidden devices leave the rotation', () {
      final cards = buildWallCards(
        trackedKeys: ['ph', 'temperature'],
        reportedByDevice: {
          'muted': ['ph'],
          'partial': ['ph', 'temperature'],
        },
        rows: const [
          WallTileConfig(
            deviceIdentifier: 'muted',
            paramKey: 'ph',
            visible: false,
          ),
          WallTileConfig(deviceIdentifier: 'partial', paramKey: 'ph'),
          WallTileConfig(
            deviceIdentifier: 'partial',
            paramKey: 'temperature',
            visible: false,
          ),
        ],
      );
      expect(wallPolledDevices(['muted', 'partial', 'unseen'], cards), {
        'partial',
        'unseen',
      });
    });
  });

  group('resolveWallTileValue', () {
    final now = DateTime(2026, 8, 11, 12);

    test('device card: live wins, then persisted sample, then none', () {
      final live = resolveWallTileValue(
        deviceCard: true,
        liveValue: 8.2,
        liveAt: now,
        sampleValue: 8.0,
        sampleAt: now.subtract(const Duration(minutes: 10)),
        readingValue: 7.5,
        readingAt: now.subtract(const Duration(days: 2)),
      );
      expect(live.source, WallValueSource.live);
      expect(live.value, 8.2);

      final sample = resolveWallTileValue(
        deviceCard: true,
        sampleValue: 8.0,
        sampleAt: now.subtract(const Duration(minutes: 10)),
        readingValue: 7.5,
      );
      expect(sample.source, WallValueSource.sample);
      expect(sample.value, 8.0);

      // A stored reading never feeds a device card — no cross-source
      // switching under the keeper's feet.
      final none = resolveWallTileValue(deviceCard: true, readingValue: 7.5);
      expect(none.source, WallValueSource.none);
      expect(none.value, isNull);
    });

    test('stored card: last reading, else none', () {
      final reading = resolveWallTileValue(
        deviceCard: false,
        readingValue: 7.5,
        readingAt: now.subtract(const Duration(days: 2)),
      );
      expect(reading.source, WallValueSource.reading);
      expect(reading.value, 7.5);
      expect(
        resolveWallTileValue(deviceCard: false).source,
        WallValueSource.none,
      );
    });
  });

  group('wall parameter catalogue', () {
    test('contains only known core parameters', () {
      expect(kWallParameterKeys, isNotEmpty);
      for (final key in kWallParameterKeys) {
        expect(kParameterByKey, contains(key));
        expect(
          isCoreParam(key),
          isTrue,
          reason: '$key must not be a microelement',
        );
      }
    });

    test('excludes every microelement', () {
      for (final p in kMicroParameters) {
        expect(kWallParameterKeys, isNot(contains(p.key)));
      }
    });

    test('tracked microelements never become cards', () {
      final cards = buildWallCards(
        trackedKeys: ['alkalinity', 'iodine'],
        reportedByDevice: const {},
        rows: const [],
      );
      expect(cards.map((c) => c.id.paramKey), ['alkalinity']);
    });

    test('device-reported keys outside the catalogue never become cards', () {
      final cards = buildWallCards(
        trackedKeys: const [],
        reportedByDevice: {
          'apex1': ['temperature', 'iodine'],
        },
        rows: const [],
      );
      expect(cards.map((c) => (c.id.deviceIdentifier, c.id.paramKey)), [
        ('apex1', 'temperature'),
      ]);
    });
  });
}
