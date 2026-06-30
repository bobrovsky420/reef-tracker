/// Static catalog of reef supplement vendors, dosing programs and products.
/// Like `parameter_catalog.dart` this is app data (not stored in the DB) so it
/// can evolve without a migration. Brand/program/product names are proper nouns
/// and are intentionally **not** localized.
///
/// **The data ([kSupplementVendors]) is GENERATED from `supplements.yaml`** — do
/// not edit it by hand. Edit the YAML, then run `dart run tool/gen_supplements.dart`
/// to regenerate `supplement_catalog.g.dart`. This file owns the model + lookups.
///
/// Phase-1 dosing is information-only (a standing per-tank plan). The model is
/// shaped so later phases — manual dose logging and consumption calculation —
/// can join a stored entry back to its catalog [SupplementProduct] (via the
/// stable [SupplementProduct.key]) and read its [SupplementProduct.strength].
library;

part 'supplement_catalog.g.dart';

/// The unit a supplement is measured in. Restricted to **ml** (liquids) and
/// **g** (solids): both are already canonical, so — unlike volume/temperature —
/// no unit-preference conversion is ever needed, and the stored amount is ready
/// for the future consumption math.
enum DoseUnit {
  ml('ml'),
  g('g');

  const DoseUnit(this.symbol);

  /// Suffix shown next to the amount field and in the dosing list.
  final String symbol;

  static DoseUnit fromName(String? name) =>
      values.firstWhere((u) => u.name == name, orElse: () => DoseUnit.ml);
}

/// Whether a dosage amount is "per day" (a daily total) or "per single dose".
enum DoseBasis {
  perDay,
  perDose;

  static DoseBasis? fromName(String? name) {
    for (final b in values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// How often a supplement is dosed. Purely descriptive in phase 1 — the future
/// consumption calculator works off **actual logged doses**, never this plan.
enum DoseFrequency {
  daily,
  everyNDays,
  weekly;

  static DoseFrequency? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// A single supplement product in the built-in catalog.
class SupplementProduct {
  const SupplementProduct({
    required this.key,
    required this.name,
    this.elementKey,
    this.defaultUnit = DoseUnit.ml,
    this.strength,
  });

  /// Stable identifier persisted on dosing entries (e.g. `redsea.foundation_b`).
  /// Never reuse or repurpose a key — stored entries and the future dose log
  /// resolve display + potency through it.
  final String key;

  /// Display name (proper noun, not localized).
  final String name;

  /// The reef parameter this product primarily targets, as a real
  /// `Readings.paramKey` (e.g. `alkalinity`, `calcium`, `magnesium`). Null for
  /// trace blends / multi-element products with no single primary element.
  final String? elementKey;

  /// Default amount unit (liquids → ml, dry salts/powders → g).
  final DoseUnit defaultUnit;

  /// Potency map for the future consumption calculator:
  /// `{paramKey: amount of that element delivered per ONE [defaultUnit] of
  /// product per ONE litre of tank water, in the parameter's canonical unit}`.
  ///
  /// So for a tank of `V` litres a dose of `D` units raises the element by
  /// `strength[paramKey]! * D / V`. Example convention (NOT a real value):
  /// an alkalinity liquid where 30 ml raises 100 L by 1.0 dKH has
  /// `strength = {'alkalinity': 1.0 * 100 / 30}` ≈ `3.33` dKH·L/ml.
  ///
  /// Left null until a value is verified against the vendor's own dosing chart
  /// — a sparse-but-correct map beats a full-but-wrong one, because wrong
  /// potency would silently corrupt later consumption estimates.
  final Map<String, double>? strength;
}

/// A named dosing program / product line grouping several products
/// (e.g. Red Sea "Reef Care Program", Tropic Marin "Balling").
class SupplementProgram {
  const SupplementProgram({
    required this.key,
    required this.name,
    required this.products,
  });

  final String key;
  final String name;
  final List<SupplementProduct> products;
}

/// A supplement manufacturer, with optional program groupings and/or products
/// offered directly (ungrouped).
class SupplementVendor {
  const SupplementVendor({
    required this.key,
    required this.name,
    this.programs = const [],
    this.products = const [],
  });

  final String key;
  final String name;
  final List<SupplementProgram> programs;
  final List<SupplementProduct> products;

  /// Every product under this vendor, flattened across programs + ungrouped.
  Iterable<SupplementProduct> get allProducts =>
      [...products, for (final p in programs) ...p.products];
}

/// Vendor lookup by [SupplementVendor.key].
final Map<String, SupplementVendor> kSupplementVendorByKey = {
  for (final v in kSupplementVendors) v.key: v,
};

/// Product lookup by [SupplementProduct.key], across every vendor/program.
final Map<String, SupplementProduct> kSupplementProductByKey = {
  for (final v in kSupplementVendors)
    for (final p in v.allProducts) p.key: p,
};

/// The owning vendor key for each product key.
final Map<String, String> kVendorKeyByProductKey = {
  for (final v in kSupplementVendors)
    for (final p in v.allProducts) p.key: v.key,
};

/// The owning program name for each product key that belongs to a program
/// (ungrouped products are absent).
final Map<String, String> kProgramNameByProductKey = {
  for (final v in kSupplementVendors)
    for (final prog in v.programs)
      for (final p in prog.products) p.key: prog.name,
};

/// Resolves the display names for a stored dosing selection.
///
/// When [productKey] still matches a catalog product, the **live** catalog
/// values are returned (so a renamed/moved product shows its current name,
/// vendor and program everywhere). For a custom or orphaned entry (no key, or a
/// key no longer in the catalog) it falls back to the denormalized
/// [storedVendor]/[storedProgram]/[storedProduct] snapshot saved on the row.
///
/// The target element is intentionally **not** resolved here: it is
/// user-editable and stored independently of the product.
({String product, String? vendor, String? program}) resolveSupplementNames({
  required String? productKey,
  required String? storedVendor,
  required String? storedProgram,
  required String storedProduct,
}) {
  final product =
      productKey == null ? null : kSupplementProductByKey[productKey];
  if (product == null) {
    return (
      product: storedProduct,
      vendor: storedVendor,
      program: storedProgram,
    );
  }
  final vendorKey = kVendorKeyByProductKey[productKey];
  return (
    product: product.name,
    vendor: vendorKey == null
        ? storedVendor
        : kSupplementVendorByKey[vendorKey]?.name,
    // Null when the product is (now) ungrouped — that is the current truth, so
    // we do not fall back to a possibly-stale stored program here.
    program: kProgramNameByProductKey[productKey],
  );
}

/// The reef parameters offered in the dosing element picker (a subset of
/// `kReefParameters` that supplements actually target), in a sensible order.
/// Localized via `AppLocalizations.paramName`.
const List<String> kDosingElementKeys = [
  'alkalinity',
  'calcium',
  'magnesium',
  'potassium',
  'strontium',
  'iodine',
  'iron',
  'nitrate',
  'phosphate',
];
