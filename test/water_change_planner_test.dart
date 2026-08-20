import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/water_change_planner.dart';

void main() {
  group('batch water changes', () {
    test('projects one and repeated changes with cumulative replacement', () {
      final result = projectWaterChanges(
        method: WaterChangeMethod.batch,
        tankVolumeLiters: 200,
        changeVolumeLiters: 20,
        initialConcentration: 20,
        replacementConcentration: 0,
        plannedChanges: 3,
        targetConcentration: 15,
      );

      expect(result.afterOne.concentration, closeTo(18, 1e-12));
      expect(result.afterPlanned.concentration, closeTo(14.58, 1e-12));
      expect(
        result.afterPlanned.effectiveChangeFraction,
        closeTo(0.271, 1e-12),
      );
      expect(result.changesToTarget, 3);
    });

    test('a whole-volume batch replaces everything in one change', () {
      expect(
        projectedWaterChangeConcentration(
          method: WaterChangeMethod.batch,
          tankVolumeLiters: 100,
          changeVolumeLiters: 100,
          initialConcentration: 10,
          replacementConcentration: 2,
          changes: 1,
        ),
        2,
      );
      expect(
        waterChangesToReachTarget(
          method: WaterChangeMethod.batch,
          tankVolumeLiters: 100,
          changeVolumeLiters: 100,
          initialConcentration: 10,
          replacementConcentration: 2,
          targetConcentration: 5,
        ),
        1,
      );
    });
  });

  group('continuous automatic exchange', () {
    test('uses exponential dilution rather than batch math', () {
      final result = projectWaterChanges(
        method: WaterChangeMethod.continuous,
        tankVolumeLiters: 200,
        changeVolumeLiters: 20,
        initialConcentration: 20,
        replacementConcentration: 0,
        plannedChanges: 3,
        targetConcentration: 15,
      );

      expect(result.afterOne.concentration, closeTo(20 * 0.904837418, 1e-8));
      expect(
        result.afterPlanned.effectiveChangeFraction,
        closeTo(1 - 0.740818221, 1e-8),
      );
      expect(result.changesToTarget, 3);
    });
  });

  test('reports exact target as zero work', () {
    expect(
      waterChangesToReachTarget(
        method: WaterChangeMethod.batch,
        tankVolumeLiters: 100,
        changeVolumeLiters: 10,
        initialConcentration: 5,
        replacementConcentration: 0,
        targetConcentration: 5,
      ),
      0,
    );
  });

  test('does not promise a target replacement reaches in finite changes', () {
    for (final replacement in [5.0, 7.0]) {
      expect(
        waterChangesToReachTarget(
          method: WaterChangeMethod.batch,
          tankVolumeLiters: 100,
          changeVolumeLiters: 10,
          initialConcentration: 10,
          replacementConcentration: replacement,
          targetConcentration: 5,
        ),
        isNull,
      );
    }
  });

  test('supports rising targets when replacement is higher', () {
    expect(
      waterChangesToReachTarget(
        method: WaterChangeMethod.batch,
        tankVolumeLiters: 100,
        changeVolumeLiters: 20,
        initialConcentration: 2,
        replacementConcentration: 10,
        targetConcentration: 5,
      ),
      3,
    );
  });

  test('rejects invalid and non-finite inputs', () {
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => effectiveWaterChangeFraction(
          method: WaterChangeMethod.batch,
          tankVolumeLiters: invalid,
          changeVolumeLiters: 10,
          changes: 1,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => projectWaterChanges(
        method: WaterChangeMethod.batch,
        tankVolumeLiters: 100,
        changeVolumeLiters: 101,
        initialConcentration: 10,
        replacementConcentration: 0,
        plannedChanges: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => projectWaterChanges(
        method: WaterChangeMethod.batch,
        tankVolumeLiters: 100,
        changeVolumeLiters: 10,
        initialConcentration: -0.1,
        replacementConcentration: 0,
        plannedChanges: 1,
      ),
      throwsArgumentError,
    );
  });
}
