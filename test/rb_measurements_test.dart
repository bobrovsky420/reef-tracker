import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rb_measurements.dart';
import 'package:reeftracker/data/rb_protocol.dart';

void main() {
  group('rbControlMeasurements', () {
    test('extracts every probe parameter in canonical units', () {
      final values = rbControlMeasurements(
        const RbControlStatus(
          probes: [
            RbControlProbe(
              type: 'ec',
              ppt: 35.0,
              temperatureC: 25.1,
              level: 'danger',
              temperatureLevel: 'danger',
            ),
            RbControlProbe(type: 'orp', value: 412),
            RbControlProbe(type: 'ph', value: 8.18, temperatureC: 26.4),
          ],
        ),
      );

      expect(values.map((v) => v.paramKey), [
        'salinity',
        'temperature',
        'orp',
        'ph',
      ]);
      expect(values[0].value, closeTo(1.0264, 0.001));
      expect(values[1].value, 25.1);
      expect(values[2].value, 412);
      expect(values[3].value, 8.18);
    });

    test('uses only the first probe carrying temperature', () {
      final values = rbControlMeasurements(
        const RbControlStatus(
          probes: [
            RbControlProbe(type: 'ec', ppt: 35),
            RbControlProbe(type: 'orp', value: 400, temperatureC: 24.8),
            RbControlProbe(type: 'ph', value: 8.1, temperatureC: 26.2),
          ],
        ),
      );

      expect(
        values.singleWhere((v) => v.paramKey == 'temperature').value,
        24.8,
      );
    });

    test('drops impossible values and ignores unsupported probes', () {
      final values = rbControlMeasurements(
        const RbControlStatus(
          probes: [
            RbControlProbe(type: 'leak', detected: true),
            RbControlProbe(type: 'ph', value: -100, temperatureC: -100),
            RbControlProbe(type: 'orp', value: 401),
          ],
        ),
      );

      expect(values, [(paramKey: 'orp', value: 401.0)]);
    });
  });
}
