import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/wall_display.dart';

/// DB-layer tests for the wall display's tables (U49): the bucket-collapse
/// rule on `device_samples`, the prune boundary, and the sparse
/// `wall_tile_settings` upserts. Migration idempotency for schema v29 rides
/// the existing sweep in migration_test.dart (it re-runs every step up to
/// `schemaVersion`).
void main() {
  late AppDatabase db;
  late int tankId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tankId = await db.createTankWithPreset(name: 'T', type: SetupType.mixed);
  });
  tearDown(() => db.close());

  group('device samples', () {
    final bucket = bucketStartFor(DateTime(2026, 8, 11, 12, 3));

    test('several polls inside one bucket collapse to one row', () async {
      for (final v in [8.2, 8.4, 8.1]) {
        await db.upsertDeviceSample(
          tankId: tankId,
          deviceIdentifier: 'apex1',
          paramKey: 'ph',
          bucketStart: bucket,
          value: v,
        );
      }
      final rows = await db.getDeviceSamplesSince(
        tankId,
        bucket.subtract(const Duration(hours: 1)),
      );
      expect(rows, hasLength(1));
      expect(rows.single.value, 8.1); // last in bucket
      expect(rows.single.minValue, 8.1);
      expect(rows.single.maxValue, 8.4);
    });

    test('different devices and buckets keep their own rows', () async {
      await db.upsertDeviceSample(
        tankId: tankId,
        deviceIdentifier: 'apex1',
        paramKey: 'temperature',
        bucketStart: bucket,
        value: 25,
      );
      await db.upsertDeviceSample(
        tankId: tankId,
        deviceIdentifier: 'rfsg1',
        paramKey: 'temperature',
        bucketStart: bucket,
        value: 25.4,
      );
      await db.upsertDeviceSample(
        tankId: tankId,
        deviceIdentifier: 'apex1',
        paramKey: 'temperature',
        bucketStart: bucket.add(kWallSampleBucket),
        value: 25.1,
      );
      final rows = await db.getDeviceSamplesSince(
        tankId,
        bucket.subtract(const Duration(hours: 1)),
      );
      expect(rows, hasLength(3));
      // Oldest first, so the caller can hand the list straight to a line.
      expect(rows.last.bucketStart, bucket.add(kWallSampleBucket));
    });

    test(
      'prune removes strictly older buckets and spares the cutoff',
      () async {
        final cutoff = bucket;
        for (final (id, start) in [
          ('apex1', cutoff.subtract(kWallSampleBucket)), // older — pruned
          ('apex1', cutoff), // exactly at cutoff — kept
          ('apex1', cutoff.add(kWallSampleBucket)), // newer — kept
        ]) {
          await db.upsertDeviceSample(
            tankId: tankId,
            deviceIdentifier: id,
            paramKey: 'ph',
            bucketStart: start,
            value: 8,
          );
        }
        final pruned = await db.pruneDeviceSamples(cutoff);
        expect(pruned, 1);
        final rows = await db.getDeviceSamplesSince(
          tankId,
          cutoff.subtract(const Duration(days: 1)),
        );
        expect(rows, hasLength(2));
        expect(rows.first.bucketStart, cutoff);
      },
    );
  });

  group('wall tile settings', () {
    test('insertMissingWallTiles never touches existing rows', () async {
      await db.setWallTileVisible(
        tankId: tankId,
        deviceIdentifier: 'rfpm1',
        paramKey: 'ph',
        visible: false,
      );
      await db.insertMissingWallTiles(tankId, [
        (deviceIdentifier: 'rfpm1', paramKey: 'ph', visible: true),
        (deviceIdentifier: 'rfpm1', paramKey: 'temperature', visible: false),
      ]);
      final rows = await db.getWallTileSettings(tankId);
      final byKey = {for (final r in rows) r.paramKey: r};
      // The pre-existing hidden row survived the "discovered" insert…
      expect(byKey['ph']!.visible, isFalse);
      // …and the new card arrived with the caller's visibility (muted rule).
      expect(byKey['temperature']!.visible, isFalse);
    });

    test('setWallTileVisible upserts; setWallTileOrder renumbers', () async {
      await db.setWallTileVisible(
        tankId: tankId,
        deviceIdentifier: kWallNoDevice,
        paramKey: 'alkalinity',
        visible: false,
      );
      await db.setWallTileOrder(tankId, [
        (deviceIdentifier: 'apex1', paramKey: 'ph'),
        (deviceIdentifier: kWallNoDevice, paramKey: 'alkalinity'),
      ]);
      final rows = await db.getWallTileSettings(tankId);
      final byKey = {
        for (final r in rows) '${r.deviceIdentifier}:${r.paramKey}': r,
      };
      expect(byKey['apex1:ph']!.displayOrder, 0);
      expect(byKey['$kWallNoDevice:alkalinity']!.displayOrder, 1);
      // Ordering preserved the earlier visibility choice.
      expect(byKey['$kWallNoDevice:alkalinity']!.visible, isFalse);
    });
  });
}
