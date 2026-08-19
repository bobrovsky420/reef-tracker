/// Static catalogue of commercial marine salt mixes.
///
/// **The data ([kSaltMixProducts]) is GENERATED from `salt_mixes.yaml`** — do
/// not edit it by hand. Edit the YAML, then run
/// `dart run tool/gen_salt_mixes.dart` to regenerate
/// `salt_mix_catalog.g.dart`. This file owns the model and lookups.
library;

import 'salinity_planner.dart';
import 'units.dart';

part 'salt_mix_catalog.g.dart';

/// Stable identity used for the aquarium's one free-form salt calibration.
const kCustomSaltMixKey = 'custom';

/// How closely a manufacturer's instruction matches ReefTracker's canonical
/// grams-per-litre-of-final-water calibration.
enum SaltMixSeedBasis {
  finalPreparedWater,
  manufacturerRatio,
  sourceWaterEstimate,
  batchBackedEstimate,
}

/// A current commercial salt mix with a manufacturer-backed first-use value.
///
/// Catalogue values only seed a product the first time it is selected for an
/// aquarium. A stored aquarium/product calibration always takes precedence.
class SaltMixProduct {
  const SaltMixProduct({
    required this.key,
    required this.brand,
    required this.name,
    required this.gramsPerLiter,
    required this.referencePpt,
    required this.basis,
    required this.sourceUrl,
    required this.verifiedOn,
  });

  final String key;
  final String brand;
  final String name;
  final double gramsPerLiter;
  final double referencePpt;
  final SaltMixSeedBasis basis;
  final String sourceUrl;
  final DateTime verifiedOn;

  String get displayName => '$brand — $name';

  SaltMixCalibration get initialCalibration => SaltMixCalibration(
    name: displayName,
    gramsPerLiter: gramsPerLiter,
    referencePpt: referencePpt,
  );

  bool get isSourceWaterEstimate =>
      basis == SaltMixSeedBasis.sourceWaterEstimate ||
      basis == SaltMixSeedBasis.batchBackedEstimate;
}

final kSaltMixProductByKey = {
  for (final product in kSaltMixProducts) product.key: product,
};
