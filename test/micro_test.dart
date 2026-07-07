import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:reeftracker/domain/micro.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  setUpAll(() => Intl.defaultLocale = 'en');

  group('micro catalog (U17)', () {
    test('the panel covers the Fauna Marin Reef ICP elements', () {
      // 37 lab parameters − nitrogen/pH-style core overlaps (Ca, Mg, K,
      // PO₄ stay core) − elemental P (redundant with total phosphate)
      // = 32 micro keys, 3 of which predate the panel (Sr, I, Fe).
      const expected = {
        // Majors.
        'sodium', 'sulfur', 'boron', 'bromine', 'silicon',
        // Traces.
        'strontium', 'iodine', 'iron', 'zinc', 'vanadium', 'copper',
        'nickel', 'manganese', 'molybdenum', 'chromium', 'cobalt',
        'lithium', 'barium', 'selenium',
        // Contaminants.
        'aluminium', 'antimony', 'tin', 'beryllium', 'silver', 'tungsten',
        'lanthanum', 'titanium', 'zirconium', 'arsenic', 'cadmium',
        'mercury', 'lead',
      };
      expect(kMicroParameters.map((p) => p.key).toSet(), expected);
    });

    test('isCoreParam: core keys stay core, micro keys do not, unknown keys '
        'fall back to core (legacy rows keep their surfaces)', () {
      expect(isCoreParam('calcium'), isTrue);
      expect(isCoreParam('potassium'), isTrue);
      expect(isCoreParam('iodine'), isFalse);
      expect(isCoreParam('lead'), isFalse);
      expect(isCoreParam('not-a-param'), isTrue);
    });

    test('every micro definition carries a symbol and a category section', () {
      for (final p in kMicroParameters) {
        expect(p.symbol, isNotNull, reason: p.key);
        expect(p.category, isNot(ParamCategory.core), reason: p.key);
      }
    });

    test('µg/L elements declare the fixed unit with factor 1000; ppm ones '
        'stay factor 1', () {
      for (final p in kMicroParameters) {
        if (p.displayFactor != 1) {
          expect(p.displayFactor, 1000, reason: p.key);
          expect(p.unit, 'µg/L', reason: p.key);
        } else {
          expect(p.unit, 'ppm', reason: p.key);
        }
      }
    });
  });

  group('micro view presets (U17)', () {
    test('the Fauna Marin preset names only real catalog elements', () {
      final catalog = kMicroParameters.map((p) => p.key).toSet();
      for (final k in kMicroViewFaunaMarinKeys) {
        expect(catalog, contains(k));
      }
    });

    test('the Fauna Marin preset has no duplicates', () {
      expect(
        kMicroViewFaunaMarinKeys.toSet().length,
        kMicroViewFaunaMarinKeys.length,
      );
    });

    test('today the Fauna Marin panel equals the whole catalog — this pin '
        'must be UPDATED (not the preset) when other labs\' elements join '
        'the catalog', () {
      expect(
        kMicroViewFaunaMarinKeys.toSet(),
        kMicroParameters.map((p) => p.key).toSet(),
      );
    });

    test('microPresetKeys resolves known presets and nothing else', () {
      expect(
        microPresetKeys(kMicroViewFaunaMarinToken),
        kMicroViewFaunaMarinKeys.toSet(),
      );
      // Full = no filtering; custom/dangling tokens resolve via the DB.
      expect(microPresetKeys(kMicroViewFullToken), isNull);
      expect(microPresetKeys('view:12'), isNull);
      expect(microPresetKeys('preset:nope'), isNull);
    });
  });

  group('kMicroDefaultBounds', () {
    test('every micro element has default bounds and nothing else does', () {
      expect(
        kMicroDefaultBounds.keys.toSet(),
        kMicroParameters.map((p) => p.key).toSet(),
      );
    });

    test('bounds are valid, paired, and inside the plausible range', () {
      for (final p in kMicroParameters) {
        final b = kMicroDefaultBounds[p.key]!;
        expect(b.isEmpty, isFalse, reason: p.key);
        expect(b.isValid, isTrue, reason: p.key);
        // An amber bound requires its matching green bound (the editors'
        // pairing rule — see zones.dart).
        if (b.amberLow != null) {
          expect(b.greenLow, isNotNull, reason: p.key);
        }
        if (b.amberHigh != null) {
          expect(b.greenHigh, isNotNull, reason: p.key);
        }
        // Defaults must not themselves trip the sanity check.
        for (final v in [b.amberLow, b.greenLow, b.greenHigh, b.amberHigh]) {
          if (v == null) continue;
          expect(
            checkParamValue(p.key, v),
            isNot(ParamValueCheck.impossible),
            reason: '${p.key} bound $v',
          );
          expect(
            v,
            lessThanOrEqualTo(p.plausibleMax!),
            reason: '${p.key} bound $v above plausible range',
          );
        }
      }
    });

    test('contaminants are one-sided: green from zero up to a ceiling', () {
      for (final p in kMicroParameters) {
        if (p.category != ParamCategory.contaminant) continue;
        final b = kMicroDefaultBounds[p.key]!;
        expect(b.greenLow, isNull, reason: p.key);
        expect(b.amberLow, isNull, reason: p.key);
        expect(b.greenHigh, isNotNull, reason: p.key);
        expect(b.amberHigh, isNotNull, reason: p.key);
        // Zero (a clean tank) must classify green, an overshoot red.
        expect(b.classify(0), Zone.green, reason: p.key);
        expect(b.classify(b.amberHigh! * 10), Zone.red, reason: p.key);
      }
    });

    test('microDefaultBounds falls back to empty for unknown keys', () {
      expect(microDefaultBounds('calcium').isEmpty, isTrue);
      expect(microDefaultBounds('nope').isEmpty, isTrue);
    });

    test('natural seawater values classify green', () {
      expect(kMicroDefaultBounds['iodine']!.classify(0.06), Zone.green);
      expect(kMicroDefaultBounds['strontium']!.classify(8.1), Zone.green);
      expect(kMicroDefaultBounds['sodium']!.classify(10760), Zone.green);
      expect(kMicroDefaultBounds['lithium']!.classify(0.18), Zone.green);
      expect(kMicroDefaultBounds['molybdenum']!.classify(0.01), Zone.green);
    });
  });

  group('µg/L presentation', () {
    test('converts canonical ppm to display µg/L and back', () {
      final pres = presentationForKey('iodine', 'ppm', const UnitPrefs());
      expect(pres.unitLabel, 'µg/L');
      expect(pres.unitFixed, isTrue);
      expect(pres.toDisplay(0.06), closeTo(60, 1e-9));
      expect(pres.toCanonical(60), closeTo(0.06, 1e-9));
      expect(pres.format(0.06), '60');
    });

    test('ignores the stored unit label — pre-panel iodine rows carry "ppm" '
        'but must not display a ×1000 value as ppm', () {
      final pres = presentationForKey('iodine', 'ppm', const UnitPrefs());
      expect(pres.unitLabel, 'µg/L');
    });

    test('ppm micro elements keep the identity presentation', () {
      final pres = presentationForKey('strontium', 'ppm', const UnitPrefs());
      expect(pres.unitLabel, 'ppm');
      expect(pres.unitFixed, isFalse);
      expect(pres.toDisplay(8.1), 8.1);
    });
  });

  group('computeMicroStatus', () {
    ZoneBounds b(String key) => kMicroDefaultBounds[key]!;

    test('empty panel: nothing measured, worst zone unknown', () {
      final s = computeMicroStatus(const []);
      expect(s.measured, 0);
      expect(s.outOfRange, 0);
      expect(s.worstZone, Zone.unknown);
      expect(s.lastMeasuredAt, isNull);
    });

    test('unmeasured elements are skipped, never counted as a problem', () {
      final s = computeMicroStatus([
        (paramKey: 'lead', bounds: b('lead'), latest: null, takenAt: null),
      ]);
      expect(s.measured, 0);
      expect(s.outOfRange, 0);
    });

    test('counts out-of-range elements and keeps the worst zone + newest '
        'sample date', () {
      final old = DateTime(2026, 5, 1);
      final recent = DateTime(2026, 7, 1);
      final s = computeMicroStatus([
        // Green.
        (paramKey: 'iodine', bounds: b('iodine'), latest: 0.06, takenAt: old),
        // Amber (between green ceiling 0.002 and amber ceiling 0.008).
        (paramKey: 'lead', bounds: b('lead'), latest: 0.005, takenAt: recent),
        // Red (beyond the amber ceiling 0.001).
        (paramKey: 'mercury', bounds: b('mercury'), latest: 0.01, takenAt: old),
      ]);
      expect(s.measured, 3);
      expect(s.outOfRange, 2);
      expect(s.worstZone, Zone.red);
      expect(s.lastMeasuredAt, recent);
    });

    test('a value without classifiable bounds counts as measured but not '
        'out of range', () {
      final s = computeMicroStatus([
        (
          paramKey: 'zinc',
          bounds: const ZoneBounds(),
          latest: 0.5,
          takenAt: DateTime(2026, 6, 1),
        ),
      ]);
      expect(s.measured, 1);
      expect(s.outOfRange, 0);
      expect(s.worstZone, Zone.unknown);
    });

    test('a green result does not mask an earlier red (worst zone is '
        'order-independent)', () {
      final t = DateTime(2026, 6, 1);
      final s = computeMicroStatus([
        (paramKey: 'mercury', bounds: b('mercury'), latest: 0.01, takenAt: t),
        (paramKey: 'iodine', bounds: b('iodine'), latest: 0.06, takenAt: t),
      ]);
      expect(s.worstZone, Zone.red);
    });
  });
}
