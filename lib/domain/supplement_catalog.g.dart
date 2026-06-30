// GENERATED CODE — DO NOT EDIT BY HAND.
//
// Source: supplements.yaml
// Regenerate: dart run tool/gen_supplements.dart

// ignore_for_file: lines_longer_than_80_chars

part of 'supplement_catalog.dart';

/// The built-in supplement catalog, generated from
/// `supplements.yaml`. Curated, with a UI "Other…" escape hatch.
const List<SupplementVendor> kSupplementVendors = [
  SupplementVendor(
    key: 'redsea',
    name: 'Red Sea',
    products: [
      SupplementProduct(
        key: 'redsea.no3po4x',
        name: 'NO₃:PO₄-X (nutrient reducer)',
      ),
    ],
    programs: [
      SupplementProgram(
        key: 'foundation_abc',
        name: 'Foundation ABC',
        products: [
          SupplementProduct(
            key: 'redsea.foundation_a',
            name: 'Foundation A — Calcium',
            elementKey: 'calcium',
            strength: {'calcium': 200.0},
          ),
          SupplementProduct(
            key: 'redsea.foundation_b',
            name: 'Foundation B — KH/Alkalinity',
            elementKey: 'alkalinity',
            strength: {'alkalinity': 10.0},
          ),
          SupplementProduct(
            key: 'redsea.foundation_c',
            name: 'Foundation C — Magnesium',
            elementKey: 'magnesium',
            strength: {'magnesium': 100.0},
          ),
          SupplementProduct(
            key: 'redsea.colors_a',
            name: 'Trace Colors A — Iodine',
            elementKey: 'iodine',
            strength: {'iodine': 3.0},
          ),
          SupplementProduct(
            key: 'redsea.colors_b',
            name: 'Trace Colors B — Potassium',
            elementKey: 'potassium',
            strength: {'potassium': 175.0},
          ),
          SupplementProduct(
            key: 'redsea.colors_c',
            name: 'Trace Colors C — Iron',
            elementKey: 'iron',
            strength: {'iron': 1.0},
          ),
          SupplementProduct(
            key: 'redsea.colors_d',
            name: 'Trace Colors D — Bioactive Elements',
          ),
        ],
      ),
      SupplementProgram(
        key: 'complete_reef_care',
        name: 'Complete Reef Care Program',
        products: [
          SupplementProduct(
            key: 'redsea.complete_1',
            name: 'Part 1 — Calcium & Magnesium',
            elementKey: 'calcium',
            strength: {'calcium': 140.0},
          ),
          SupplementProduct(
            key: 'redsea.complete_2',
            name: 'Part 2 — KH/Alkalinity & pH Stabilizer',
            elementKey: 'alkalinity',
            strength: {'alkalinity': 10.0},
          ),
          SupplementProduct(
            key: 'redsea.complete_3',
            name: 'Part 3 — Iodine & Potassium',
          ),
          SupplementProduct(
            key: 'redsea.complete_4',
            name: 'Part 4 — Iron & Bioactive Elements',
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'tropicmarin',
    name: 'Tropic Marin',
    products: [
      SupplementProduct(
        key: 'tropicmarin.all_for_reef',
        name: 'All-For-Reef',
      ),
    ],
    programs: [
      SupplementProgram(
        key: 'balling',
        name: 'Balling',
        products: [
          SupplementProduct(
            key: 'tropicmarin.balling_a',
            name: 'Part A — Calcium',
            elementKey: 'calcium',
            strength: {'calcium': 20.0},
          ),
          SupplementProduct(
            key: 'tropicmarin.balling_b',
            name: 'Part B — Carbonate (Alk)',
            elementKey: 'alkalinity',
            strength: {'alkalinity': 2.8},
          ),
          SupplementProduct(
            key: 'tropicmarin.balling_c',
            name: 'Part C — Trace/Mg',
            elementKey: 'magnesium',
            strength: {'magnesium': 3.35, 'potassium': 0.98},
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'triton',
    name: 'Triton',
    programs: [
      SupplementProgram(
        key: 'core7',
        name: 'Core7 Base Elementz',
        products: [
          SupplementProduct(
            key: 'triton.core7_1',
            name: 'Base Elementz #1',
          ),
          SupplementProduct(
            key: 'triton.core7_2',
            name: 'Base Elementz #2',
          ),
          SupplementProduct(
            key: 'triton.core7_3',
            name: 'Base Elementz #3',
          ),
          SupplementProduct(
            key: 'triton.core7_4',
            name: 'Base Elementz #4',
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'faunamarin',
    name: 'Fauna Marin',
    programs: [
      SupplementProgram(
        key: 'balling_light',
        name: 'Balling Light',
        products: [
          SupplementProduct(
            key: 'faunamarin.bl_calcium',
            name: 'Calcium Mix',
            elementKey: 'calcium',
            strength: {'calcium': 110.0},
          ),
          SupplementProduct(
            key: 'faunamarin.bl_carbonate',
            name: 'Carbonate Mix',
            elementKey: 'alkalinity',
            strength: {'alkalinity': 5.0},
          ),
          SupplementProduct(
            key: 'faunamarin.bl_magnesium',
            name: 'Magnesium Mix',
            elementKey: 'magnesium',
            strength: {'magnesium': 50.0},
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'aquaforest',
    name: 'Aquaforest',
    programs: [
      SupplementProgram(
        key: 'component_123',
        name: 'Component 1·2·3',
        products: [
          SupplementProduct(
            key: 'aquaforest.component_1',
            name: 'Component 1+ (Ca)',
            elementKey: 'calcium',
            strength: {'calcium': 18.0},
          ),
          SupplementProduct(
            key: 'aquaforest.component_2',
            name: 'Component 2+ (KH)',
            elementKey: 'alkalinity',
            strength: {'alkalinity': 2.6},
          ),
          SupplementProduct(
            key: 'aquaforest.component_3',
            name: 'Component 3+ (Mg)',
            elementKey: 'magnesium',
            strength: {'magnesium': 1.52},
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'generic',
    name: 'Generic / DIY',
    products: [
      SupplementProduct(
        key: 'generic.kalkwasser',
        name: 'Kalkwasser (limewater)',
        elementKey: 'calcium',
      ),
      SupplementProduct(
        key: 'generic.calcium_chloride',
        name: 'Calcium chloride (2-part Ca)',
        elementKey: 'calcium',
      ),
      SupplementProduct(
        key: 'generic.soda_ash',
        name: 'Soda ash / bicarbonate (2-part Alk)',
        elementKey: 'alkalinity',
      ),
      SupplementProduct(
        key: 'generic.magnesium_mix',
        name: 'Magnesium mix (2-part Mg)',
        elementKey: 'magnesium',
      ),
      SupplementProduct(
        key: 'generic.dry_salt',
        name: 'Dry salt / powder',
        defaultUnit: DoseUnit.g,
      ),
    ],
  ),
];
