// The Apex dashboard's save filter (U40): unit conversion to the catalog's
// canonical units, and dropping values no probe could truthfully report.

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/ap_protocol.dart';
import 'package:reeftracker/features/apex/apex_screen.dart';

void main() {
  test('conductivity in ppt is stored as specific gravity', () {
    final values = apReadingsToSave(const [ApReading('salinity', 35.0, 'ppt')]);
    expect(values.single.paramKey, 'salinity');
    // 35 ppt ≈ 1.026 SG — the same conversion the ReefFactory Salinity
    // Guardian's reading goes through.
    expect(values.single.value, closeTo(1.026, 0.002));
  });

  test('everything else is already in the catalog unit', () {
    final values = apReadingsToSave(const [
      ApReading('temperature', 25.4, '°C'),
      ApReading('ph', 8.14, 'pH'),
      ApReading('orp', 345, 'mV'),
      ApReading('alkalinity', 8.4, 'dKH'),
      ApReading('calcium', 428, 'ppm'),
      ApReading('magnesium', 1385, 'ppm'),
    ]);
    expect(
      {for (final v in values) v.paramKey: v.value},
      const {
        'temperature': 25.4,
        'ph': 8.14,
        'orp': 345.0,
        'alkalinity': 8.4,
        'calcium': 428.0,
        'magnesium': 1385.0,
      },
    );
  });

  test('physically impossible values are dropped, not stored as noise', () {
    // Below the catalog's hard floor — a negative pH or temperature is not a
    // measurement, so a save must not write it into the tank's history.
    final values = apReadingsToSave(const [
      ApReading('ph', -1, 'pH'),
      ApReading('temperature', -8, '°C'),
      ApReading('orp', 345, 'mV'),
    ]);
    expect(values.map((v) => v.paramKey), ['orp']);
  });

  test('merely implausible values are kept — same rule as ReefFactory', () {
    // The filter drops the impossible, not the alarming: 41 °C is a heater
    // failure a keeper needs recorded, not noise to be swallowed. The known
    // cost is that a disconnected Apex probe reporting exactly 0.00 is stored
    // as a real 0 (see DESIGN.md).
    final values = apReadingsToSave(const [
      ApReading('temperature', 41, '°C'),
      ApReading('ph', 0, 'pH'),
    ]);
    expect(values.map((v) => v.paramKey), ['temperature', 'ph']);
  });

  test('an empty read saves nothing', () {
    expect(apReadingsToSave(const []), isEmpty);
  });
}
