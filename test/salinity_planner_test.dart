import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/salinity_planner.dart';
import 'package:reeftracker/domain/units.dart';

void main() {
  const mix = SaltMixCalibration(
    name: 'Measured mix',
    gramsPerLiter: 38.2,
    referencePpt: 35,
  );

  group('salt calibration and new batches', () {
    test('derives a normalized measured factor', () {
      expect(
        calibrateSaltMixGramsPerLiter(
          dryMassG: 720,
          finalVolumeLiters: 20,
          measuredPpt: 33,
          referencePpt: 35,
        ),
        closeTo(38.181818, 1e-6),
      );
    });

    test('20 L at the calibration salinity needs 764 g', () {
      expect(
        saltMixMassGrams(
          finalVolumeLiters: 20,
          targetPpt: 35,
          calibration: mix,
        ),
        closeTo(764, 1e-9),
      );
    });

    test('target salinity scales the estimate linearly', () {
      expect(
        saltMixMassGrams(
          finalVolumeLiters: 20,
          targetPpt: 33,
          calibration: mix,
        ),
        closeTo(720.342857, 1e-6),
      );
    });
  });

  group('constant-volume salinity correction', () {
    test('high tank uses an RO/DI exchange', () {
      expect(
        salinityCorrectionExchangeLiters(
          tankVolumeLiters: 200,
          currentPpt: 37,
          targetPpt: 35,
          replacementPpt: 0,
        ),
        closeTo(10.810810, 1e-6),
      );
    });

    test('low tank uses concentrated replacement water', () {
      final exchange = salinityCorrectionExchangeLiters(
        tankVolumeLiters: 200,
        currentPpt: 32,
        targetPpt: 35,
        replacementPpt: 40,
      );
      expect(exchange, closeTo(75, 1e-9));
      expect(
        saltMixMassGrams(
          finalVolumeLiters: exchange,
          targetPpt: 40,
          calibration: mix,
        ),
        closeTo(3274.285714, 1e-6),
      );
      expect(
        additionalSaltEquivalentGrams(
          tankVolumeLiters: 200,
          currentPpt: 32,
          targetPpt: 35,
          calibration: mix,
        ),
        closeTo(654.857142, 1e-6),
      );
    });

    test('already at target is a zero-work result', () {
      expect(
        salinityCorrectionExchangeLiters(
          tankVolumeLiters: 200,
          currentPpt: 35,
          targetPpt: 35,
          replacementPpt: 0,
        ),
        0,
      );
      expect(
        additionalSaltEquivalentGrams(
          tankVolumeLiters: 200,
          currentPpt: 35,
          targetPpt: 35,
          calibration: mix,
        ),
        0,
      );
    });

    test('replacement must lie beyond target', () {
      expect(
        () => salinityCorrectionExchangeLiters(
          tankVolumeLiters: 200,
          currentPpt: 32,
          targetPpt: 35,
          replacementPpt: 34,
        ),
        throwsArgumentError,
      );
      expect(
        () => salinityCorrectionExchangeLiters(
          tankVolumeLiters: 200,
          currentPpt: 37,
          targetPpt: 35,
          replacementPpt: 36,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite and non-positive physical inputs', () {
      expect(
        () => saltMixMassGrams(
          finalVolumeLiters: double.nan,
          targetPpt: 35,
          calibration: mix,
        ),
        throwsArgumentError,
      );
      expect(
        () => salinityCorrectionExchangeLiters(
          tankVolumeLiters: 0,
          currentPpt: 37,
          targetPpt: 35,
          replacementPpt: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => additionalSaltEquivalentGrams(
          tankVolumeLiters: 200,
          currentPpt: 37,
          targetPpt: 35,
          calibration: mix,
        ),
        throwsArgumentError,
      );
    });

    test('SG and US-gallon presentation conversions preserve the result', () {
      final liters = salinityCorrectionExchangeLiters(
        tankVolumeLiters: gallonsToLiters(52.834410),
        currentPpt: sgToPpt(pptToSg(37)),
        targetPpt: sgToPpt(pptToSg(35)),
        replacementPpt: 0,
      );
      expect(litersToGallons(liters), closeTo(2.855914, 1e-6));
    });
  });
}
