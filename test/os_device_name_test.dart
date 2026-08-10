import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/os_device_name.dart';

void main() {
  group('friendlyAndroidDeviceName', () {
    test('the user-assigned device name wins over manufacturer/model', () {
      expect(
        friendlyAndroidDeviceName(
          name: "Alex's phone",
          manufacturer: 'Google',
          model: 'Pixel 7',
        ),
        "Alex's phone",
      );
    });

    test('blank name falls back to capitalized manufacturer + model', () {
      expect(
        friendlyAndroidDeviceName(
          name: '  ',
          manufacturer: 'samsung',
          model: 'SM-S918B',
        ),
        'Samsung SM-S918B',
      );
      // Mixed-case brands keep their own casing.
      expect(
        friendlyAndroidDeviceName(
          name: '',
          manufacturer: 'OnePlus',
          model: 'CPH2581',
        ),
        'OnePlus CPH2581',
      );
    });

    test('model already carrying the brand is not double-prefixed', () {
      expect(
        friendlyAndroidDeviceName(
          name: '',
          manufacturer: 'xiaomi',
          model: 'Xiaomi 14T',
        ),
        'Xiaomi 14T',
      );
    });

    test('the literal "unknown" manufacturer placeholder is dropped', () {
      expect(
        friendlyAndroidDeviceName(
          name: '',
          manufacturer: 'unknown',
          model: 'Tablet X10',
        ),
        'Tablet X10',
      );
      expect(
        friendlyAndroidDeviceName(name: '', manufacturer: 'unknown', model: ''),
        isNull,
      );
    });

    test('prefill is clipped to the dialog cap of 40 characters', () {
      final long = 'A' * 39 + ' tail that overflows';
      final result = friendlyAndroidDeviceName(
        name: long,
        manufacturer: '',
        model: '',
      )!;
      expect(result.length, lessThanOrEqualTo(40));
      // Clip must not leave a dangling space at the cut.
      expect(result, result.trimRight());
    });
  });

  group('friendlyIosDeviceName', () {
    test('a personalized name (differs from the device class) wins', () {
      expect(
        friendlyIosDeviceName(
          name: "Alex's iPhone",
          model: 'iPhone',
          modelName: 'iPhone 16 Pro',
        ),
        "Alex's iPhone",
      );
    });

    test('the iOS 16+ entitlement-less generic name yields the commercial '
        'model name instead', () {
      expect(
        friendlyIosDeviceName(
          name: 'iPhone',
          model: 'iPhone',
          modelName: 'iPhone 16 Pro',
        ),
        'iPhone 16 Pro',
      );
    });

    test('generic name without a model name still beats an empty field', () {
      expect(
        friendlyIosDeviceName(name: 'iPad', model: 'iPad', modelName: ''),
        'iPad',
      );
      expect(friendlyIosDeviceName(name: '', model: '', modelName: ''), isNull);
    });
  });
}
