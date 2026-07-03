import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';

/// Guards the invariants the dosing feature (and the future consumption
/// calculator) rely on. These hold for the generated `kSupplementVendors`, so
/// the test catches a bad `supplements.yaml` edit OR a stale/hand-edited
/// `supplement_catalog.g.dart`.
void main() {
  final validParams = kParameterByKey.keys.toSet();

  Iterable<SupplementProduct> allProducts() => [
    for (final v in kSupplementVendors) ...v.allProducts,
  ];

  test('product keys are unique across the whole catalog', () {
    final seen = <String>{};
    final dupes = <String>[];
    for (final p in allProducts()) {
      if (!seen.add(p.key)) dupes.add(p.key);
    }
    expect(dupes, isEmpty, reason: 'duplicate product keys: $dupes');
    // The lookup map must cover every product (would silently drop dupes).
    expect(kSupplementProductByKey.length, seen.length);
  });

  test('every elementKey is a real reef-parameter key', () {
    for (final p in allProducts()) {
      if (p.elementKey != null) {
        expect(
          validParams,
          contains(p.elementKey),
          reason:
              'product "${p.key}" has unknown elementKey '
              '"${p.elementKey}"',
        );
      }
    }
  });

  test('every strength key is a real reef-parameter key', () {
    for (final p in allProducts()) {
      for (final key in p.strength?.keys ?? const <String>[]) {
        expect(
          validParams,
          contains(key),
          reason: 'product "${p.key}" has unknown strength key "$key"',
        );
      }
    }
  });

  test('vendor and product keys resolve through the lookup maps', () {
    for (final v in kSupplementVendors) {
      expect(kSupplementVendorByKey[v.key], same(v));
      for (final p in v.allProducts) {
        expect(kVendorKeyByProductKey[p.key], v.key);
      }
    }
  });

  test('dosing element keys are all real parameters', () {
    for (final key in kDosingElementKeys) {
      expect(validParams, contains(key));
    }
  });

  group('resolveSupplementNames', () {
    test('uses live catalog names, ignoring a stale stored snapshot', () {
      final r = resolveSupplementNames(
        productKey: 'redsea.foundation_b',
        storedVendor: 'OLD VENDOR',
        storedProgram: 'OLD PROGRAM',
        storedProduct: 'OLD NAME',
      );
      expect(r.product, 'Foundation B — KH/Alkalinity');
      expect(r.vendor, 'Red Sea');
      expect(r.program, 'Foundation ABC');
    });

    test('an ungrouped catalog product resolves with a null program', () {
      final r = resolveSupplementNames(
        productKey: 'tropicmarin.all_for_reef',
        storedVendor: null,
        storedProgram: 'stale',
        storedProduct: 'stale',
      );
      expect(r.product, 'All-For-Reef');
      expect(r.vendor, 'Tropic Marin');
      expect(r.program, isNull);
    });

    test('a custom entry (no key) falls back to the stored snapshot', () {
      final r = resolveSupplementNames(
        productKey: null,
        storedVendor: 'My brand',
        storedProgram: null,
        storedProduct: 'My mix',
      );
      expect(r.product, 'My mix');
      expect(r.vendor, 'My brand');
      expect(r.program, isNull);
    });

    test('an orphaned key (no longer in catalog) falls back to stored', () {
      final r = resolveSupplementNames(
        productKey: 'redsea.removed_product',
        storedVendor: 'Red Sea',
        storedProgram: 'Reef Care Program',
        storedProduct: 'Some discontinued product',
      );
      expect(r.product, 'Some discontinued product');
      expect(r.vendor, 'Red Sea');
      expect(r.program, 'Reef Care Program');
    });
  });
}
