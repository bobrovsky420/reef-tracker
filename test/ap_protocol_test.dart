// Golden vectors for the Neptune Apex protocol (U40).
//
// The documents below are the shapes the community integrations have parsed
// for years — Home Assistant's `apex-ha` (`/rest/login` → `/rest/status`, and
// the `istat`-wrapped `/cgi-bin/status.json`) and Telegraf's `neptune_apex`
// input (the padded-string values, the `AON`/`AOF`/`TBL`/`PF1` outlet states,
// the `AC5:` serial). Neptune publishes no schema, so these are the
// specification as far as this app is concerned: change them only against
// evidence from a real controller.

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/ap_protocol.dart';

/// An AOS 5.x `GET /rest/status` body, trimmed to the sections the app reads.
const _restStatus = {
  'system': {
    'hostname': 'apex',
    'serial': 'AC5:12345',
    'timezone': -8.0,
    'date': 1766438137,
    'software': '5.12_8C24',
    'hardware': '1.0',
    'type': 'controller',
  },
  'inputs': [
    {'did': 'base_Temp', 'type': 'Temp', 'name': 'Tmp', 'value': 78.4},
    {'did': 'base_pH', 'type': 'pH', 'name': 'pH', 'value': 8.14},
    {'did': 'base_ORP', 'type': 'ORP', 'name': 'ORP', 'value': 345},
    {'did': 'base_Cond', 'type': 'Cond', 'name': 'Salt', 'value': 35.1},
    {'did': 'base_Amps', 'type': 'Amps', 'name': 'RETURN_A', 'value': 0.42},
    {'did': 'Trident_alk', 'type': 'alk', 'name': 'Alk', 'value': 8.4},
    {'did': 'Trident_ca', 'type': 'ca', 'name': 'Ca', 'value': 428},
    {'did': 'Trident_mg', 'type': 'mg', 'name': 'Mg', 'value': 1385},
  ],
  'outputs': [
    {
      'did': '2_1',
      'type': 'outlet',
      'name': 'Return',
      'status': ['AON', '', 'OK', ''],
      'ID': 8,
    },
    {
      'did': '2_3',
      'type': 'outlet',
      'name': 'Heater',
      'status': ['AOF', '', 'OK', ''],
      'ID': 10,
    },
    {
      'did': '2_5',
      'type': 'outlet',
      'name': 'Wavemaker',
      'status': ['OFF', '', 'OK', ''],
      'ID': 12,
    },
    {
      'did': '3_1',
      'type': 'vortech',
      'name': 'Vortech_L',
      'status': ['TBL', '', 'OK', ''],
      'ID': 18,
    },
    {
      'did': 'base_Alarm',
      'type': 'alert',
      'name': 'EmailAlm_I5',
      'status': ['AOF', '', 'OK', ''],
      'ID': 6,
    },
    {
      'did': 'Cntl_A2',
      'type': 'virtual',
      'name': 'LEAK',
      'status': ['AOF', '', 'OK', ''],
      'ID': 32,
    },
  ],
  'feed': {'name': 0, 'active': 65535, 'errorCode': 0, 'errorMessage': ''},
};

/// A Classic `GET /cgi-bin/status.json` body: the same information under
/// `istat`, identity fields at that level, and numbers padded into strings.
const _legacyStatus = {
  'istat': {
    'hostname': 'apex',
    'serial': 'AJ:98765',
    'software': '5.04_7A18',
    'hardware': '1.0',
    'timezone': -8.0,
    'inputs': [
      {'did': 'base_Temp', 'type': 'Temp', 'name': 'Tmp', 'value': '24.9 '},
      {'did': 'base_Cond', 'type': 'Cond', 'name': 'Salt', 'value': '30.1 '},
      {'did': 'base_pwr', 'type': 'pwr', 'name': 'RETURN_W', 'value': '  35 '},
    ],
    'outputs': [
      {
        'did': '2_1',
        'type': 'outlet',
        'name': 'Return',
        'status': ['AON', '', 'OK', ''],
        'ID': 8,
      },
      {
        'did': '4_1',
        'type': 'variable',
        'name': 'LED_Dim',
        'status': ['PF1', '', 'OK', ''],
        'ID': 28,
      },
    ],
    'feed': {'name': 6, 'active': 0},
  },
};

void main() {
  group('AOS 5.x /rest/status', () {
    final status = ApStatus.fromRestJson(Map.of(_restStatus));

    test('identity', () {
      expect(status.info.serial, 'AC5:12345');
      expect(status.info.hostname, 'apex');
      expect(status.info.software, '5.12_8C24');
      expect(status.info.firmware, ApFirmware.aos5);
      // The serial prefix is as close to a model code as an Apex reports.
      expect(status.info.modelCode, 'AC5');
      expect(status.info.displayName, 'Apex');
    });

    test('maps probe types to catalog parameters, ignoring the rest', () {
      final byKey = {for (final r in status.readings) r.paramKey: r.value};
      // 78.4 °F is over the 45 threshold, so it is read as Fahrenheit and
      // converted to the catalog's canonical °C.
      expect(byKey['temperature'], closeTo(25.8, 0.01));
      expect(byKey['ph'], 8.14);
      expect(byKey['orp'], 345);
      // Conductivity stays in ppt here; the save path converts it to SG.
      expect(byKey['salinity'], 35.1);
      expect(byKey['alkalinity'], 8.4);
      expect(byKey['calcium'], 428);
      expect(byKey['magnesium'], 1385);
      // Amps has no catalog home and must not invent one.
      expect(byKey.keys, hasLength(7));
      // Every input is still parsed, mapped or not.
      expect(status.probes, hasLength(8));
    });

    test('outlet states', () {
      final byName = {for (final o in status.outlets) o.name: o};
      expect(byName['Return']!.on, isTrue);
      expect(byName['Return']!.overridden, isFalse);
      expect(byName['Heater']!.on, isFalse);
      // A bare OFF (no leading A) is a human override, not the program.
      expect(byName['Wavemaker']!.on, isFalse);
      expect(byName['Wavemaker']!.overridden, isTrue);
      // A profile drives a variable output: neither on nor off.
      expect(byName['Vortech_L']!.on, isNull);
      expect(status.overriddenOutlets.map((o) => o.name), ['Wavemaker']);
    });

    test('alarm and virtual outputs are kept out of the outlet list', () {
      expect(status.switchedOutlets.map((o) => o.name), [
        'Return',
        'Heater',
        'Wavemaker',
        'Vortech_L',
      ]);
    });

    test('an idle feed timer is not a running cycle', () {
      // AOS 5 parks the idle timer at a large sentinel rather than zero.
      expect(status.feed!.running, isFalse);
      expect(status.feed!.letter, isNull);
    });
  });

  group('Classic /cgi-bin/status.json', () {
    final status = ApStatus.fromLegacyJson(Map.of(_legacyStatus));

    test('unwraps istat and reads identity from that level', () {
      expect(status.info.serial, 'AJ:98765');
      expect(status.info.firmware, ApFirmware.classic);
      expect(status.info.modelCode, 'AJ');
      expect(status.info.displayName, 'Apex Classic');
    });

    test('parses padded string values', () {
      final byKey = {for (final r in status.readings) r.paramKey: r.value};
      // 24.9 is below the 45 threshold — already Celsius, left alone.
      expect(byKey['temperature'], 24.9);
      expect(byKey['salinity'], 30.1);
      expect(byKey.containsKey('orp'), isFalse);
    });

    test('name 6 is the Classic idle-feed sentinel', () {
      expect(status.feed!.running, isFalse);
    });

    test('accepts an already-unwrapped body', () {
      final inner = (_legacyStatus['istat']! as Map).cast<String, Object?>();
      expect(ApStatus.fromLegacyJson(inner).info.serial, 'AJ:98765');
    });
  });

  group('temperature unit', () {
    test('/rest/config is authoritative when it answers', () {
      const config = {
        'iconf': [
          {
            'did': 'base_Temp',
            'extra': {'range': 'Celcius'},
          },
        ],
      };
      expect(apTempUnitFromConfig(config), ApTempUnit.celsius);
      expect(
        apTempUnitFromConfig({
          'iconf': [
            {
              'did': 'base_Temp',
              'extra': {'range': 'Faren'},
            },
          ],
        }),
        ApTempUnit.fahrenheit,
      );
      // Nothing to go on → null, so the caller falls back to inference.
      expect(apTempUnitFromConfig(null), isNull);
      expect(apTempUnitFromConfig({'iconf': []}), isNull);
    });

    test('a stated unit overrides the inferred one', () {
      // 24.9 would infer Celsius, but a controller that says Fahrenheit is
      // believed — and 24.9 °F then converts to a (nonsensical but faithful)
      // negative Celsius rather than being silently "corrected".
      final status = ApStatus.fromLegacyJson(
        Map.of(_legacyStatus),
        tempUnit: ApTempUnit.fahrenheit,
      );
      expect(
        status.readings.firstWhere((r) => r.paramKey == 'temperature').value,
        closeTo(-3.9, 0.05),
      );
    });

    test('inference separates the two plausible ranges', () {
      expect(
        apInferTempUnit([
          const ApProbe(did: 'a', name: 'T', type: 'Temp', value: 26.0),
        ]),
        ApTempUnit.celsius,
      );
      expect(
        apInferTempUnit([
          const ApProbe(did: 'a', name: 'T', type: 'Temp', value: 78.4),
        ]),
        ApTempUnit.fahrenheit,
      );
      // No temperature probe at all: the answer can't matter, and Celsius is
      // the identity choice.
      expect(apInferTempUnit(const []), ApTempUnit.celsius);
    });
  });

  group('conductivity unit (#73)', () {
    ApStatus condStatus(num value) => ApStatus.fromRestJson({
      'inputs': [
        {
          'did': 'base_Cond',
          'type': 'Cond',
          'name': 'Salinity',
          'value': value,
        },
      ],
    });

    test('a ppt reading is kept and stays in ppt on the wire', () {
      final reading = condStatus(35).readings.single;
      expect(reading.paramKey, 'salinity');
      expect(reading.value, 35);
      expect(reading.unit, 'ppt');
    });

    test('a mS/cm reading is dropped rather than converted', () {
      // An Apex conductivity input can be configured to display mS/cm, and
      // nothing on the wire says which. Reef seawater is ≈35 ppt but ≈53
      // mS/cm, and `pptToSg(53) ≈ 1.040` would sit inside the plausible
      // salinity band — a believable, wrong number no later gate can catch.
      expect(condStatus(53).readings, isEmpty);
      expect(condStatus(kApCondMaxPpt + 0.1).readings, isEmpty);
      // The boundary itself is still ppt: high, but a reading, not a unit.
      expect(condStatus(kApCondMaxPpt).readings, hasLength(1));
    });

    test('a dropped Cond probe does not shadow a second one', () {
      final status = ApStatus.fromRestJson({
        'inputs': [
          {'did': 'a', 'type': 'Cond', 'name': 'mS probe', 'value': 53},
          {'did': 'b', 'type': 'Cond', 'name': 'ppt probe', 'value': 34.6},
        ],
      });
      expect(status.readings.single.value, 34.6);
    });

    test('a zero reading is left for the save path to question', () {
      // An unplugged probe reading 0 ppt is a real ppt value — the rail rule
      // puts it to the keeper instead of the protocol guessing on its behalf.
      expect(condStatus(0).readings.single.value, 0);
    });
  });

  group('tolerance', () {
    test('an empty document yields an empty, non-throwing status', () {
      final status = ApStatus.fromRestJson(const {});
      expect(status.probes, isEmpty);
      expect(status.outlets, isEmpty);
      expect(status.readings, isEmpty);
      expect(status.feed, isNull);
      expect(status.info.serial, '');
    });

    test('malformed members are skipped, not fatal', () {
      final status = ApStatus.fromRestJson({
        'system': 'not a map',
        'inputs': [
          'nonsense',
          {'did': 'base_Temp', 'type': 'Temp', 'name': 'Tmp', 'value': null},
          {'did': 'base_pH', 'type': 'pH', 'name': 'pH', 'value': 8.2},
        ],
        'outputs': {'not': 'a list'},
        'feed': 42,
      });
      // A probe with no value contributes no reading but is still listed.
      expect(status.probes, hasLength(2));
      expect(status.readings.map((r) => r.paramKey), ['ph']);
      expect(status.outlets, isEmpty);
      expect(status.feed, isNull);
    });

    test('a bare-string outlet status is accepted', () {
      final status = ApStatus.fromRestJson({
        'outputs': [
          {'did': '2_1', 'type': 'outlet', 'name': 'Return', 'status': 'AON'},
        ],
      });
      expect(status.outlets.single.on, isTrue);
    });

    test('the first probe of a type wins', () {
      // A display + sump pair is the common case; saving both would write one
      // parameter twice in the same group.
      final status = ApStatus.fromRestJson({
        'inputs': [
          {
            'did': 'base_Temp',
            'type': 'Temp',
            'name': 'Display',
            'value': 25.4,
          },
          {'did': 'sump_Temp', 'type': 'Temp', 'name': 'Sump', 'value': 25.9},
        ],
      });
      expect(status.readings, hasLength(1));
      expect(status.readings.single.value, 25.4);
    });

    test('a valueless first probe does not shadow a later usable one', () {
      final status = ApStatus.fromRestJson({
        'inputs': [
          {'did': 'a', 'type': 'Temp', 'name': 'Unplugged', 'value': null},
          {'did': 'b', 'type': 'Temp', 'name': 'Sump', 'value': 25.9},
        ],
      });
      expect(status.readings.single.value, 25.9);
    });
  });

  group('feed cycle', () {
    test('a running cycle reports its letter', () {
      const feed = ApFeed(name: 3, secondsLeft: 180);
      expect(feed.running, isTrue);
      expect(feed.letter, 'C');
    });

    test('sentinels and out-of-range cycles are idle', () {
      expect(const ApFeed(name: 0, secondsLeft: 65535).running, isFalse);
      expect(const ApFeed(name: 6, secondsLeft: 0).running, isFalse);
      expect(const ApFeed(name: 2, secondsLeft: 0).running, isFalse);
      expect(const ApFeed(name: 2, secondsLeft: 60000).running, isFalse);
    });
  });
}
