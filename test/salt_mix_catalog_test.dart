import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/salt_mix_catalog.dart';
import 'package:reeftracker/domain/units.dart';

void main() {
  test(
    'catalogue contains the reviewed launch set with stable unique keys',
    () {
      expect(kSaltMixProducts, hasLength(16));
      expect(
        kSaltMixProducts.map((product) => product.key).toSet(),
        hasLength(16),
      );
      expect(kSaltMixProductByKey, hasLength(16));
    },
  );

  test('manufacturer values retain their reviewed reference salinities', () {
    final coralPro = kSaltMixProductByKey['red-sea-coral-pro']!;
    expect(coralPro.gramsPerLiter, 40.6);
    expect(coralPro.referencePpt, 35);

    final seaSalt = kSaltMixProductByKey['instant-ocean-sea-salt']!;
    expect(seaSalt.gramsPerLiter, 35.95);
    expect(pptToSg(seaSalt.referencePpt), closeTo(1.022, 1e-12));

    final vibrantSea = kSaltMixProductByKey['seachem-vibrant-sea']!;
    expect(vibrantSea.gramsPerLiter, 31);
    expect(pptToSg(vibrantSea.referencePpt), closeTo(1.023, 1e-12));

    final aquaforest = kSaltMixProductByKey['aquaforest-reef-salt']!;
    expect(aquaforest.gramsPerLiter, 39);
    expect(aquaforest.referencePpt, 33);
    expect(aquaforest.isSourceWaterEstimate, isTrue);
  });

  test('all entries contain maintainable source provenance', () {
    for (final product in kSaltMixProducts) {
      expect(product.initialCalibration.isValid, isTrue, reason: product.key);
      expect(Uri.parse(product.sourceUrl).isScheme('https'), isTrue);
      expect(product.verifiedOn, DateTime(2026, 8, 19));
    }
  });
}
