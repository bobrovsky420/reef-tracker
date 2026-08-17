import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/presets.dart';
import 'package:reeftracker/domain/ratio.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/zones.dart';

void main() {
  group('presets integrity', () {
    test('every preset key exists in the catalog', () {
      for (final entry in kPresets.entries) {
        for (final key in entry.value.keys) {
          expect(
            kParameterByKey.containsKey(key),
            isTrue,
            reason: '${entry.key} references unknown parameter "$key"',
          );
        }
      }
    });

    test('every setup type has at least one parameter', () {
      for (final type in SetupType.values) {
        expect(defaultTrackedKeys(type), isNotEmpty, reason: '$type has none');
      }
    });

    test(
      'ORP has shared defaults without becoming a default dashboard card',
      () {
        for (final type in SetupType.values) {
          expect(
            defaultTrackedKeys(type),
            isNot(contains('orp')),
            reason: '$type',
          );
          final bounds = defaultBoundsFor(type, 'orp');
          expect(bounds.amberLow, 200, reason: '$type');
          expect(bounds.greenLow, 250, reason: '$type');
          expect(bounds.greenHigh, 450, reason: '$type');
          expect(bounds.amberHigh, 500, reason: '$type');
          expect(bounds.classify(199), Zone.red, reason: '$type low red');
          expect(bounds.classify(200), Zone.amber, reason: '$type low amber');
          expect(bounds.classify(250), Zone.green, reason: '$type green floor');
          expect(
            bounds.classify(450),
            Zone.green,
            reason: '$type green ceiling',
          );
          expect(bounds.classify(500), Zone.amber, reason: '$type high amber');
          expect(bounds.classify(501), Zone.red, reason: '$type high red');
        }
      },
    );

    test('a tank at its preset centre classifies green on every ratio', () {
      // kPresets and kRatioDefaultBounds are generated from two blocks of the
      // same tank_presets.yaml and validated independently — nothing else ties
      // them together. If they drift, the app amber-flags the very chemistry
      // its own presets just recommended. Asserted through the Zone, never
      // through the literal bounds.
      double? greenCentre(ZoneBounds b) {
        final hi = b.greenHigh;
        if (hi == null) return null;
        return ((b.greenLow ?? 0) + hi) / 2;
      }

      for (final type in SetupType.values) {
        for (final kind in RatioKind.values) {
          final num = greenCentre(presetBounds(type, kind.numeratorKey));
          final den = greenCentre(presetBounds(type, kind.denominatorKey));
          // Setups that don't preset both halves (fish-only has no Ca/alk
          // bands) have no recommended centre to hold to — skip, don't fail.
          if (num == null || den == null || den == 0) continue;
          expect(
            ratioZone(kind, kind.defaultBounds, num / den),
            Zone.green,
            reason:
                '$type at its preset centre '
                '(${kind.numeratorKey} $num / ${kind.denominatorKey} $den) '
                'is off the recommended ${kind.name} band',
          );
        }
      }
    });

    test('bounds are monotonically increasing where defined', () {
      for (final entry in kPresets.entries) {
        for (final bounds in entry.value.values) {
          final seq = [
            bounds.amberLow,
            bounds.greenLow,
            bounds.greenHigh,
            bounds.amberHigh,
          ].whereType<double>().toList();
          for (var i = 1; i < seq.length; i++) {
            expect(
              seq[i] >= seq[i - 1],
              isTrue,
              reason: 'Out-of-order bound in ${entry.key}: $seq',
            );
          }
        }
      }
    });
  });
}
