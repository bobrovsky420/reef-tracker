import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/hanna_meter.dart';

// Real lines from the 2026-07-21 BLE capture (HANNA.md / hanna_spike/cap3).
const kInfoLine =
    'I,HI97115,06150128,FW,v1.07,nRF FW,v1.01,SN,906150128111,RCL,130,English,v5.0';
const kResultLine =
    'M,2002, ,8.104962,0,200G2,0,06150128,20260721102041,STATUS,11,Z,R';
const kTickLine = 'T,2095,-,-,0,200G2,0,06150128,-,STATUS,7,Z,-';
const kPlaceholderM = 'M,2069,-,-,0,200G2,0,06150128,-,STATUS,4,Z,-';

void main() {
  group('HannaLineBuffer', () {
    test('reassembles MTU-chunked lines and keeps the partial tail', () {
      final buf = HannaLineBuffer();
      expect(buf.feed('GB,7'), isEmpty);
      expect(buf.feed('5,%\nI,HI97'), ['GB,75,%']);
      expect(buf.feed('115\n'), ['I,HI97115']);
    });

    test('splits several glued lines and drops blanks', () {
      final buf = HannaLineBuffer();
      expect(buf.feed('SM,Ack\n\nSS,Ack\n'), ['SM,Ack', 'SS,Ack']);
    });
  });

  group('response parsing', () {
    test('info line parses identity by label', () {
      final info = parseHannaInfo(kInfoLine)!;
      expect(info.model, 'HI97115');
      expect(info.deviceId, '06150128');
      expect(info.firmware, 'v1.07');
      expect(info.serial, '906150128111');
      expect(info.protocolVersion, 'v5.0');
    });

    test('battery and acks', () {
      expect(parseHannaBattery('GB,75,%'), 75);
      expect(parseHannaBattery('GS,whatever'), isNull);
      expect(isHannaAck('ST,Ack', 'ST'), isTrue);
      expect(isHannaAck('SD,Ack', 'SS'), isFalse);
    });

    test('tank pages: full page, short page, trailing separator', () {
      final full = parseHannaTankPage(
        'GL,200G2,TANK2,TANK3,TANK4,TANK5,TANK6,TANK7,TANK8,TANK9,TANK10,'
        'TANK11,TANK12,TANK13,TANK14,TANK15,',
      )!;
      expect(full.length, kHannaTankPageSize);
      expect(full.first, '200G2');
      final short = parseHannaTankPage('GL,TANK91,TANK92,')!;
      expect(short, ['TANK91', 'TANK92']);
      expect(parseHannaTankPage('GB,75,%'), isNull);
    });
  });

  group('measurement frames', () {
    test('final R-frame decodes value, tank and timestamp', () {
      final m = parseHannaMeasurementFrame(kResultLine);
      expect(m, isA<HannaMeasurement>());
      final r = m as HannaMeasurement;
      expect(r.methodCode, 2002);
      expect(r.value, closeTo(8.104962, 1e-9));
      expect(r.tankName, '200G2');
      expect(r.takenAt, DateTime(2026, 7, 21, 10, 20, 41));
    });

    test('comma decimal separator splits the value field — still one value', () {
      final m = parseHannaMeasurementFrame(
        'M,2002, ,8,104962,0,200G2,0,06150128,20260721102041,STATUS,11,Z,R',
      );
      expect((m as HannaMeasurement).value, closeTo(8.104962, 1e-9));
      expect(m.tankName, '200G2');
    });

    test('ticks and placeholder M-frames are progress, not results', () {
      final t = parseHannaMeasurementFrame(kTickLine);
      expect(t, isA<HannaProgress>());
      expect((t as HannaProgress).methodCode, 2095);
      expect(t.step, 7);
      final p = parseHannaMeasurementFrame(kPlaceholderM);
      expect(p, isA<HannaProgress>());
      expect((p as HannaProgress).step, 4);
    });

    test('non-measurement lines return null', () {
      expect(parseHannaMeasurementFrame(kInfoLine), isNull);
      expect(parseHannaMeasurementFrame('SD,Ack'), isNull);
      expect(parseHannaMeasurementFrame(''), isNull);
    });

    test('R-frame with dash timestamp keeps a null takenAt', () {
      final m = parseHannaMeasurementFrame(
        'M,2002, ,8.1,0,200G2,0,06150128,-,STATUS,11,Z,R',
      );
      expect((m as HannaMeasurement).takenAt, isNull);
    });
  });

  group('commands & methods', () {
    test('set time formats YYYYMMDDHHMMSS', () {
      expect(
        hannaCmdSetTime(DateTime(2026, 7, 21, 10, 6, 37)),
        'set time 20260721100637',
      );
    });

    test('all nine codes map, range variants collapse to one parameter', () {
      expect(kHannaMeterMethods.length, 9);
      expect(hannaMethodByCode(2002)!.paramKey, 'alkalinity');
      expect(hannaMethodByCode(2095)!.paramKey, 'nitrate');
      expect(hannaMethodByCode(2096)!.paramKey, 'nitrate');
      expect(hannaMethodByCode(2096)!.lowRange, isTrue);
      expect(hannaMethodByCode(2057)!.paramKey, 'nitrite');
      expect(hannaMethodByCode(1234), isNull);
    });
  });

  group('method sets codec', () {
    test('round-trips and drops unknown codes', () {
      final decoded = AppSettings.decodeHannaMethodSets(
        '[{"name":"Daily test","codes":[2097,2002,9999]},'
        '{"name":"Weekly","codes":[2069]}]',
      );
      expect(decoded.length, 2);
      expect(decoded.first.name, 'Daily test');
      expect(decoded.first.codes, [2097, 2002]);
      expect(decoded[1].codes, [2069]);
    });

    test('null and malformed input decode to no sets', () {
      expect(AppSettings.decodeHannaMethodSets(null), isEmpty);
      expect(AppSettings.decodeHannaMethodSets('not json'), isEmpty);
      expect(AppSettings.decodeHannaMethodSets('{"name":1}'), isEmpty);
    });
  });
}
