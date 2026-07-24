import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('upsertReefFactoryDevice inserts then updates by serial (no dupe)', () async {
    await db.upsertReefFactoryDevice(
      identifier: 'RFPM012204210108',
      model: 'RFPM01',
      address: '192.168.1.15',
      name: 'pH',
    );
    // Re-adding the same serial at a new address updates the row in place
    // (the "device moved" path), not a second device.
    await db.upsertReefFactoryDevice(
      identifier: 'RFPM012204210108',
      model: 'RFPM01',
      address: '192.168.1.42',
      name: 'Sump pH',
    );

    final all = await db.watchDevices().first;
    expect(all, hasLength(1));
    expect(all.single.address, '192.168.1.42');
    expect(all.single.name, 'Sump pH');
    expect(all.single.kind, 'reeffactory');
  });

  test('ensureHannaDevice creates once, never clobbers a user tank/name', () async {
    await db.ensureHannaDevice(
      identifier: 'HANNA-AB12',
      model: 'HI981',
      name: 'Checker',
    );
    await db.updateDeviceNameTank(
      (await db.deviceByIdentifier('HANNA-AB12'))!.id,
      name: 'My checker',
      tankId: null,
    );
    // A later measurement must not reset the user's rename.
    await db.ensureHannaDevice(identifier: 'HANNA-AB12', name: 'Checker');

    final hanna = await db.watchDevicesOfKind('hanna').first;
    expect(hanna, hasLength(1));
    expect(hanna.single.name, 'My checker');
  });

  test('watchDevicesOfKind filters, deleteDevice removes', () async {
    await db.upsertReefFactoryDevice(
      identifier: 'RFSG012110010070',
      model: 'RFSG01',
      address: '192.168.1.7',
    );
    await db.ensureHannaDevice(identifier: 'HANNA-AB12');

    expect(await db.watchDevicesOfKind('reeffactory').first, hasLength(1));
    expect(await db.watchDevices().first, hasLength(2));

    final rf = (await db.watchDevicesOfKind('reeffactory').first).single;
    await db.deleteDevice(rf.id);
    expect(await db.watchDevicesOfKind('reeffactory').first, isEmpty);
    expect(await db.watchDevices().first, hasLength(1));
  });
}
