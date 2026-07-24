import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rf_protocol.dart';
import 'package:reeftracker/features/reeffactory/reeffactory_screen.dart';

/// The Save / Save-all filter (`rfReadingsToSave`) — the temperature-source rule
/// and the impossible-value drop. Pure, so exercised without the widget.
void main() {
  final sgReadings = [
    const RfReading('salinity', 34.6, 'ppt'),
    const RfReading('temperature', 25.3, '°C'),
  ];

  group('temperature source rule', () {
    test('Salinity Guardian temperature is dropped when a controller exists', () {
      final out = rfReadingsToSave(
        deviceModel: 'RFSG01',
        readings: sgReadings,
        hasTempController: true,
      );
      expect(out.map((e) => e.paramKey), ['salinity']);
    });

    test('Salinity Guardian temperature is kept when no controller exists', () {
      final out = rfReadingsToSave(
        deviceModel: 'RFSG01',
        readings: sgReadings,
        hasTempController: false,
      );
      expect(out.map((e) => e.paramKey), ['salinity', 'temperature']);
    });

    test('the Temperature Controller always keeps its own temperature', () {
      final out = rfReadingsToSave(
        deviceModel: kRfTempControllerModel,
        readings: [const RfReading('temperature', 25.3, '°C')],
        hasTempController: true,
      );
      expect(out, hasLength(1));
      expect(out.single.paramKey, 'temperature');
      expect(out.single.value, 25.3);
    });

    test('pH is never affected by the temperature rule', () {
      final out = rfReadingsToSave(
        deviceModel: 'RFPM01',
        readings: [const RfReading('ph', 8.2, '')],
        hasTempController: true,
      );
      expect(out.single.paramKey, 'ph');
    });
  });

  test('physically impossible readings are dropped', () {
    final out = rfReadingsToSave(
      deviceModel: 'RFPM01',
      readings: [const RfReading('ph', -1, '')],
      hasTempController: false,
    );
    expect(out, isEmpty);
  });
}
