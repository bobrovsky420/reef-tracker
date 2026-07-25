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

  test('upsertReefBeatDevice inserts then updates by hwid (no dupe)', () async {
    await db.upsertReefBeatDevice(
      identifier: 'cc7b5c267a68',
      model: 'RSDOSE4',
      address: '192.168.1.3',
      name: 'ReefDose 4',
    );
    await db.upsertReefBeatDevice(
      identifier: 'cc7b5c267a68',
      model: 'RSDOSE4',
      address: '192.168.1.9',
      name: 'Dosing pump',
    );

    final all = await db.watchDevicesOfKind('reefbeat').first;
    expect(all, hasLength(1));
    expect(all.single.address, '192.168.1.9');
    expect(all.single.name, 'Dosing pump');
    expect(all.single.model, 'RSDOSE4');
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

  test('new devices land last and reorderDevices persists a manual order',
      () async {
    for (final n in ['A', 'B', 'C']) {
      await db.upsertReefFactoryDevice(
        identifier: 'RFPM$n',
        model: 'RFPM01',
        address: '192.168.1.1',
        name: n,
      );
    }
    final added = await db.watchDevicesOfKind('reeffactory').first;
    expect(added.map(deviceDisplayName), ['A', 'B', 'C']);
    expect(
      added.map((d) => d.displayOrder),
      [0, 1, 2],
      reason: 'each added device takes the next free position',
    );

    // Drag C to the front.
    final ids = added.map((d) => d.id).toList();
    ids.insert(0, ids.removeAt(2));
    await db.reorderDevices(ids);
    expect(
      (await db.watchDevicesOfKind('reeffactory').first).map(deviceDisplayName),
      ['C', 'A', 'B'],
    );

    // Re-adding an existing device (the moved-address path) must not send its
    // card back to the end.
    await db.upsertReefFactoryDevice(
      identifier: 'RFPMC',
      model: 'RFPM01',
      address: '192.168.1.99',
      name: 'C',
    );
    final after = await db.watchDevicesOfKind('reeffactory').first;
    expect(after.map(deviceDisplayName), ['C', 'A', 'B']);
    expect(after.first.address, '192.168.1.99');

    // A genuinely new device still goes last, after the reordered ones.
    await db.upsertReefFactoryDevice(
      identifier: 'RFPMD',
      model: 'RFPM01',
      address: '192.168.1.4',
      name: 'D',
    );
    expect(
      (await db.watchDevicesOfKind('reeffactory').first).map(deviceDisplayName),
      ['C', 'A', 'B', 'D'],
    );
  });

  test('device order is per kind — a ReefBeat add ignores ReefFactory '
      'positions', () async {
    await db.upsertReefFactoryDevice(
      identifier: 'RFPM01A',
      model: 'RFPM01',
      address: '192.168.1.15',
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFSG01A',
      model: 'RFSG01',
      address: '192.168.1.7',
    );
    await db.upsertReefBeatDevice(
      identifier: 'cc7b5c267a68',
      model: 'RSDOSE4',
      address: '192.168.1.3',
    );

    expect(
      (await db.watchDevicesOfKind('reefbeat').first).single.displayOrder,
      0,
      reason: 'each dashboard has its own sequence starting at 0',
    );
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
