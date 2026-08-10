import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rf_protocol.dart';

/// Parses a space-separated hex string into bytes, e.g. "00 07 fe e0".
Uint8List _hex(String s) => Uint8List.fromList(
  s
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => int.parse(t, radix: 16))
      .toList(),
);

void main() {
  group('frame codec', () {
    test('encode → decode round-trips all fields', () {
      final bytes = RfFrame.encode(
        command: 'sgConnect',
        subcommand: 'join',
        serial: 'RFSG012110010070',
        msgId: 'join',
        payload: const [1, 2, 3],
      );
      final f = RfFrame.decode(bytes);
      expect(f.serial, 'RFSG012110010070');
      expect(f.command, 'sgConnect');
      expect(f.subcommand, 'join');
      expect(f.msgId, 'join');
      // Payload is everything after the fourth NUL, minus nothing added by us
      // except the trailing NUL the firmware also expects.
      expect(f.payload.sublist(0, 3), [1, 2, 3]);
    });

    test('readCString reads the leading serial of a config payload', () {
      final p = Uint8List.fromList('RFSG012110010070'.codeUnits + [0, 9, 9]);
      expect(readCString(p), 'RFSG012110010070');
    });
  });

  group('model registry', () {
    test('maps serial prefixes to models', () {
      expect(rfModelForSerial('RFSG012110010070')?.name, 'salinity');
      expect(rfModelForSerial('RFPM012204210108')?.name, 'pH');
      expect(rfModelForSerial('RFTC012202100087')?.name, 'temperature');
      expect(rfModelForSerial('RFZZ01xxxxxxxxxx'), isNull);
      expect(rfModelForSerial('short'), isNull);
    });

    test('exposes vendor product names as displayName', () {
      expect(
        rfModelForSerial('RFSG012110010070')?.displayName,
        'Salinity Guardian',
      );
      expect(rfModelForSerial('RFPM012204210108')?.displayName, 'pH Monitor');
      expect(
        rfModelForSerial('RFTC012202100087')?.displayName,
        'Temperature Controller',
      );
    });
  });

  group('salinity formula (RFSG01)', () {
    test('reproduces the meter display: 52.4 mS/cm @ 24.9 °C → 34.6 ppt', () {
      expect(calculateSalinity(52.4, 24.9), 34.6);
    });
  });

  group('payload parsers — golden vectors from live hardware', () {
    test('RFSG01 salinity frame → 34.6 ppt + 24.9 °C', () {
      // Captured live from the Salinity Guardian at 192.168.1.7.
      final payload = _hex(
        '00 07 fe e0 00 00 07 c8 30 00 08 64 70 00 05 30 '
        '20 00 05 7e 40 00 00 27 ef 00 00 28 03 00 00 28 '
        '0e 00 00 28 22 00 00 00 03 cc a8 00 ff ff dd be '
        '00 00 07',
      );
      final readings = kRfModels['RFSG01']!.parse(payload);
      final byKey = {for (final r in readings) r.paramKey: r};
      expect(byKey['salinity']!.value, 34.6);
      expect(byKey['salinity']!.unit, 'ppt');
      expect(byKey['temperature']!.value, closeTo(24.9, 0.001));
    });

    test('RFPM01 pH frame → pH 8.39', () {
      // Captured live from the pH Monitor at 192.168.1.15.
      final payload = _hex(
        '00 01 47 bc 00 00 01 24 f8 00 01 4c 08 00 00 00 00 00 00',
      );
      final readings = kRfModels['RFPM01']!.parse(payload);
      expect(readings, hasLength(1));
      expect(readings.single.paramKey, 'ph');
      expect(readings.single.value, closeTo(8.39, 0.001));
    });

    test('RFTC01 temperature frame → 25.2 °C (÷1000, unit byte °C)', () {
      // 25200 = 0x00006270 at bytes 0–3, unit byte 0 = Celsius.
      final readings = kRfModels['RFTC01']!.parse(
        _hex('00 00 62 70 00 00 00 00 00 00'),
      );
      expect(readings, hasLength(1));
      expect(readings.single.paramKey, 'temperature');
      expect(readings.single.value, closeTo(25.2, 0.001));
      expect(readings.single.unit, '°C');
    });

    test('RFTC01 Fahrenheit frame is normalised to °C', () {
      // 77000 = 0x00012CC8 (77.0), unit byte 1 = Fahrenheit → 25.0 °C.
      final readings = kRfModels['RFTC01']!.parse(
        _hex('00 01 2c c8 01 00 00 00 00 00'),
      );
      expect(readings.single.value, closeTo(25.0, 0.001));
      expect(readings.single.unit, '°C');
    });

    test('RFTC01 all-0xFF temperature (probe unavailable) → empty', () {
      expect(kRfModels['RFTC01']!.parse(_hex('ff ff ff ff 00 00')), isEmpty);
    });

    test('short payloads degrade to empty, never throw', () {
      expect(kRfModels['RFSG01']!.parse(Uint8List(4)), isEmpty);
      expect(kRfModels['RFPM01']!.parse(Uint8List(2)), isEmpty);
      expect(kRfModels['RFTC01']!.parse(Uint8List(4)), isEmpty);
    });
  });

  group('RFTC01 heating/cooling state', () {
    /// A full 25-byte settings payload: 25.2 °C, °C units, alarms/setpoints,
    /// with the two output bytes (13 heating, 22 cooling) parameterised.
    Uint8List tc({required int heat, required int cool}) => Uint8List.fromList([
      0x00, 0x00, 0x62, 0x70, // 0–3   current temperature 25.200
      0x00, //                   4     unit byte: °C
      0x00, 0x00, 0x5d, 0xc0, // 5–8   alarm low 24.000
      0x00, 0x00, 0x61, 0xa8, // 9–12  heating setpoint 25.000
      heat, //                   13    heating output
      0x00, 0x00, 0x6a, 0xc8, // 14–17 alarm high 27.400
      0x00, 0x00, 0x66, 0xa8, // 18–21 cooling setpoint 26.280
      cool, //                   22    cooling output
      0x00, //                   23    reserved
      0x00, //                   24    sound / light flags
    ]);

    RfThermalState? state(Uint8List p) => kRfModels['RFTC01']!.parseThermal!(p);

    test('heating output on → heating', () {
      expect(state(tc(heat: 1, cool: 0)), RfThermalState.heating);
    });

    test('cooling output on → cooling', () {
      expect(state(tc(heat: 0, cool: 1)), RfThermalState.cooling);
    });

    test('neither output on → idle', () {
      expect(state(tc(heat: 0, cool: 0)), RfThermalState.idle);
    });

    test('both outputs on → heating, as the device UI itself resolves it', () {
      expect(state(tc(heat: 1, cool: 1)), RfThermalState.heating);
    });

    test('the payload still parses its temperature reading', () {
      final readings = kRfModels['RFTC01']!.parse(tc(heat: 1, cool: 0));
      expect(readings.single.value, closeTo(25.2, 0.001));
    });

    test(
      'a payload too short for the output bytes yields null, not a guess',
      () {
        expect(state(_hex('00 00 62 70 00 00 00 00 00 00')), isNull);
        expect(state(Uint8List(22)), isNull);
      },
    );

    test('live-hardware frame: idle at 25.2 °C between its setpoints', () {
      // Captured from the Temperature Controller at 192.168.1.6. 29 bytes —
      // longer than the 25 its own UI reads, which is why the parsers bound-
      // check rather than assume a length. Decoded: 25.2 °C · °C · alarms
      // 23.0/27.0 · setpoints heat 24.5 / cool 25.5 · both outputs off ·
      // byte 24 = 0x90, the firmware's "light off, sound off" flag pair.
      final payload = _hex(
        '00 00 62 70 00 00 00 59 d8 00 00 5f b4 00 00 00 '
        '69 78 00 00 63 9c 00 00 90 00 00 00 00',
      );
      expect(state(payload), RfThermalState.idle);
      expect(
        kRfModels['RFTC01']!.parse(payload).single.value,
        closeTo(25.2, 0.001),
      );
    });

    test('models with no outputs expose no thermal parser', () {
      expect(kRfModels['RFSG01']!.parseThermal, isNull);
      expect(kRfModels['RFPM01']!.parseThermal, isNull);
    });
  });
}
