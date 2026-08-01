import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/device_vendors.dart';

void main() {
  group('orderDeviceVendors (U41)', () {
    test('no stored order means registration order', () {
      expect(orderDeviceVendors(null), kDeviceVendors);
      expect(orderDeviceVendors(''), kDeviceVendors);
      expect(orderDeviceVendors('   '), kDeviceVendors);
    });

    test('a stored order is honoured', () {
      expect(orderDeviceVendors('hanna,apex,reefbeat,reeffactory'), [
        kDeviceKindHanna,
        kDeviceKindApex,
        kDeviceKindReefBeat,
        kDeviceKindReefFactory,
      ]);
    });

    test('surrounding whitespace is tolerated', () {
      expect(orderDeviceVendors(' apex , reeffactory '), [
        kDeviceKindApex,
        kDeviceKindReefFactory,
        // Not mentioned → appended in registration order.
        kDeviceKindReefBeat,
        kDeviceKindHanna,
      ]);
    });

    test('a vendor the app gained later is appended, never promoted', () {
      // The stored value predates the Apex integration and the Hanna vendor
      // (U43) alike — both land at the end, in registration order.
      expect(orderDeviceVendors('reefbeat,reeffactory'), [
        kDeviceKindReefBeat,
        kDeviceKindReefFactory,
        kDeviceKindApex,
        kDeviceKindHanna,
      ]);
    });

    test('unknown kinds are dropped, not rendered as ghost chips', () {
      // A vendor removed from the app.
      expect(orderDeviceVendors('seneye,apex'), [
        kDeviceKindApex,
        kDeviceKindReefFactory,
        kDeviceKindReefBeat,
        kDeviceKindHanna,
      ]);
    });

    test('duplicates collapse to the first occurrence', () {
      expect(orderDeviceVendors('apex,apex,reeffactory,apex'), [
        kDeviceKindApex,
        kDeviceKindReefFactory,
        kDeviceKindReefBeat,
        kDeviceKindHanna,
      ]);
    });

    test('the result always holds every known vendor exactly once', () {
      for (final stored in [
        null,
        '',
        'garbage',
        'apex',
        'reefbeat,reefbeat',
        'apex,reeffactory,reefbeat',
        'hanna,apex,reeffactory,reefbeat',
      ]) {
        final order = orderDeviceVendors(stored);
        expect(order.toSet(), kDeviceVendors.toSet(), reason: 'stored=$stored');
        expect(order.length, kDeviceVendors.length, reason: 'stored=$stored');
      }
    });

    test('encode round-trips through the parser', () {
      const order = [
        kDeviceKindApex,
        kDeviceKindHanna,
        kDeviceKindReefFactory,
        kDeviceKindReefBeat,
      ];
      expect(orderDeviceVendors(encodeDeviceVendorOrder(order)), order);
    });
  });

  group('deviceKindSaves (U41)', () {
    test('meters and controllers with probes can save', () {
      expect(deviceKindSaves(kDeviceKindReefFactory), isTrue);
      expect(deviceKindSaves(kDeviceKindApex), isTrue);
    });

    test('ReefBeat devices report status, never a measurement', () {
      expect(deviceKindSaves(kDeviceKindReefBeat), isFalse);
    });

    test('the Hanna checker saves through its own flow, not the page', () {
      expect(deviceKindSaves(kDeviceKindHanna), isFalse);
    });

    test('an unknown kind is not assumed savable', () {
      expect(deviceKindSaves('seneye'), isFalse);
    });
  });

  group('deviceKindRefreshes (U43)', () {
    test('every LAN vendor is polled by the refresh actions', () {
      expect(deviceKindRefreshes(kDeviceKindReefFactory), isTrue);
      expect(deviceKindRefreshes(kDeviceKindReefBeat), isTrue);
      expect(deviceKindRefreshes(kDeviceKindApex), isTrue);
    });

    test('the Hanna checker is Bluetooth-only and never polled', () {
      expect(deviceKindRefreshes(kDeviceKindHanna), isFalse);
    });
  });
}
