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
    programs: [
      SupplementProgram(
        key: 'reef_care',
        name: 'Reef Care Program',
        products: [
          SupplementProduct(
            key: 'redsea.foundation_a',
            name: 'Reef Foundation A (Ca/Sr/Ba)',
            elementKey: 'calcium',
          ),
          SupplementProduct(
            key: 'redsea.foundation_b',
            name: 'Reef Foundation B (KH/Alk)',
            elementKey: 'alkalinity',
          ),
          SupplementProduct(
            key: 'redsea.foundation_c',
            name: 'Reef Foundation C (Mg)',
            elementKey: 'magnesium',
          ),
          SupplementProduct(
            key: 'redsea.colors_a',
            name: 'Reef Colors A (Iodine/Halogens)',
            elementKey: 'iodine',
          ),
          SupplementProduct(
            key: 'redsea.colors_b',
            name: 'Reef Colors B (Potassium)',
            elementKey: 'potassium',
          ),
          SupplementProduct(
            key: 'redsea.colors_c',
            name: 'Reef Colors C (Iron/trace)',
          ),
          SupplementProduct(
            key: 'redsea.colors_d',
            name: 'Reef Colors D (trace)',
          ),
          SupplementProduct(
            key: 'redsea.no3po4x',
            name: 'NO₃:PO₄-X (nutrient reducer)',
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
          ),
          SupplementProduct(
            key: 'tropicmarin.balling_b',
            name: 'Part B — Carbonate (Alk)',
            elementKey: 'alkalinity',
          ),
          SupplementProduct(
            key: 'tropicmarin.balling_c',
            name: 'Part C — Trace/Mg',
            elementKey: 'magnesium',
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
          ),
          SupplementProduct(
            key: 'faunamarin.bl_carbonate',
            name: 'Carbonate Mix',
            elementKey: 'alkalinity',
          ),
          SupplementProduct(
            key: 'faunamarin.bl_magnesium',
            name: 'Magnesium Mix',
            elementKey: 'magnesium',
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
        key: 'component',
        name: 'Component 1·2·3+',
        products: [
          SupplementProduct(
            key: 'aquaforest.component_1',
            name: 'Component 1+ (Ca)',
            elementKey: 'calcium',
          ),
          SupplementProduct(
            key: 'aquaforest.component_2',
            name: 'Component 2+ (KH)',
            elementKey: 'alkalinity',
          ),
          SupplementProduct(
            key: 'aquaforest.component_3',
            name: 'Component 3+ (Mg)',
            elementKey: 'magnesium',
          ),
        ],
      ),
    ],
  ),
  SupplementVendor(
    key: 'zeovit',
    name: 'ZEOvit (Korallen-Zucht)',
    products: [
      SupplementProduct(
        key: 'zeovit.zeobak',
        name: 'ZEObak',
      ),
      SupplementProduct(
        key: 'zeovit.zeofood',
        name: 'ZEOfood7',
      ),
      SupplementProduct(
        key: 'zeovit.coral_vitalizer',
        name: 'Coral Vitalizer',
      ),
      SupplementProduct(
        key: 'zeovit.pohls_xtra',
        name: 'Pohl\'s Xtra',
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
