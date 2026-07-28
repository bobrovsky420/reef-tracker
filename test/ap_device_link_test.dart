// End-to-end coverage of the Apex transport (U40) against `tool/apex_emulator.dart`.
//
// The emulator speaks the same HTTP surface a real controller does — the
// session handshake, the Classic Basic-auth path, the `istat` wrapper, the
// padded string values and the two different idle-feed sentinels — so driving
// a real [ApHttpLink] at it exercises the login flow, the firmware detection
// and both parsers together. That is the part hand-written JSON fixtures
// (ap_protocol_test.dart) cannot cover.
//
// Every server binds port 0, so the suite never collides with a real emulator
// process the developer left running.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/ap_device_link.dart';
import 'package:reeftracker/data/ap_protocol.dart';

import '../tool/apex_emulator.dart';

void main() {
  late ApexEmulator emulator;
  late String host;
  final link = ApHttpLink(timeout: const Duration(seconds: 5));
  const good = ApCredentials(username: 'admin', password: '1234');

  Future<void> startEmulator({
    EmuFirmware firmware = EmuFirmware.aos5,
    EmuTempUnit unit = EmuTempUnit.celsius,
    String serial = 'AC5:12345',
  }) async {
    emulator = ApexEmulator(
      firmware: firmware,
      tempUnit: unit,
      serial: serial,
      verbose: false,
    );
    await emulator.start(host: '127.0.0.1', port: 0);
    host = '127.0.0.1:${emulator.port}';
  }

  tearDown(() => emulator.stop());

  group('AOS 5.x', () {
    test('logs in and reads a full status', () async {
      await startEmulator();
      final status = await link.readOnce(host, good);

      expect(status.info.serial, 'AC5:12345');
      expect(status.info.firmware, ApFirmware.aos5);
      expect(status.info.displayName, 'Apex');

      final keys = status.readings.map((r) => r.paramKey).toSet();
      expect(
        keys,
        containsAll([
          'temperature',
          'ph',
          'orp',
          'salinity',
          'alkalinity',
          'calcium',
          'magnesium',
        ]),
      );
      // The emulator's simulated tank sits in a plausible reef range.
      final temp = status.readings.firstWhere(
        (r) => r.paramKey == 'temperature',
      );
      expect(temp.value, inInclusiveRange(24, 27));

      // The wavemaker is left overridden on purpose — the case the dashboard's
      // caution chip exists for.
      expect(status.overriddenOutlets.map((o) => o.name), ['Wavemaker']);
      expect(status.feed!.running, isFalse);
    });

    test(
      'a Fahrenheit controller is normalised via /rest/config, not guesswork',
      () async {
        await startEmulator(unit: EmuTempUnit.fahrenheit);
        final status = await link.readOnce(host, good);
        // The controller reports ~78 °F; the config says "Faren", and the
        // reading lands back in °C.
        expect(status.tempUnit, ApTempUnit.fahrenheit);
        final temp = status.readings.firstWhere(
          (r) => r.paramKey == 'temperature',
        );
        expect(temp.unit, '°C');
        expect(temp.value, inInclusiveRange(24, 27));
      },
    );

    test('a wrong password is an auth error, not a protocol one', () async {
      await startEmulator();
      await expectLater(
        link.readOnce(
          host,
          const ApCredentials(username: 'admin', password: 'nope'),
        ),
        throwsA(
          isA<ApLinkException>().having(
            (e) => e.error,
            'error',
            ApLinkError.auth,
          ),
        ),
      );
    });

    test('a running feed cycle surfaces with its letter', () async {
      await startEmulator();
      await _control(emulator, '/emu/feed?cycle=B&seconds=300');
      final status = await link.readOnce(host, good);
      expect(status.feed!.running, isTrue);
      expect(status.feed!.letter, 'B');
    });

    test('a forced outlet state shows up on the next read', () async {
      await startEmulator();
      await _control(emulator, '/emu/outlet?name=Heater&state=ON');
      final status = await link.readOnce(host, good);
      final heater = status.outlets.firstWhere((o) => o.name == 'Heater');
      expect(heater.on, isTrue);
      expect(heater.overridden, isTrue);
    });

    test('a pinned probe value is read back exactly', () async {
      await startEmulator();
      await _control(emulator, '/emu/probe?name=pH&value=7.62');
      final status = await link.readOnce(host, good);
      expect(
        status.readings.firstWhere((r) => r.paramKey == 'ph').value,
        7.62,
      );
    });
  });

  group('Classic', () {
    test('falls back to Basic auth when /rest/login 404s', () async {
      await startEmulator(
        firmware: EmuFirmware.classic,
        serial: 'AJ:98765',
      );
      final status = await link.readOnce(host, good);
      expect(status.info.firmware, ApFirmware.classic);
      expect(status.info.serial, 'AJ:98765');
      expect(status.info.displayName, 'Apex Classic');
      // Classic firmware pads its numbers into strings — they still parse.
      expect(status.readings.map((r) => r.paramKey), contains('temperature'));
      expect(status.feed!.running, isFalse);
    });

    test('bad Basic credentials are an auth error', () async {
      await startEmulator(firmware: EmuFirmware.classic);
      await expectLater(
        link.readOnce(
          host,
          const ApCredentials(username: 'admin', password: 'nope'),
        ),
        throwsA(
          isA<ApLinkException>().having(
            (e) => e.error,
            'error',
            ApLinkError.auth,
          ),
        ),
      );
    });
  });

  group('failure modes', () {
    test('an address nothing listens on is unreachable', () async {
      await startEmulator();
      // Port 1 on loopback: reliably refused, and never a real service.
      await expectLater(
        link.readOnce('127.0.0.1:1', good),
        throwsA(
          isA<ApLinkException>().having(
            (e) => e.error,
            'error',
            ApLinkError.unreachable,
          ),
        ),
      );
    });

    test('a host that answers but is not an Apex is a protocol error', () async {
      await startEmulator();
      // Address it under a path prefix, so neither /rest/login nor
      // /cgi-bin/status.json exists there: the server answers, but with
      // nothing an Apex serves — the router admin page a mistyped address
      // usually lands on, in miniature.
      await expectLater(
        link.readOnce('$host/not-an-apex', good),
        throwsA(
          isA<ApLinkException>().having(
            (e) => e.error,
            'error',
            ApLinkError.protocol,
          ),
        ),
      );
    });

    test('a response past the #72 ceiling is a protocol error', () async {
      await startEmulator();
      // The emulator's /rest/status is ~2 KB, so a 512-byte ceiling stands in
      // for the real case: a controller (or something at its address) serving
      // more than the app is willing to hold. The production constant is 1 MB
      // — this asserts the mechanism, not the number.
      final capped = ApHttpLink(
        timeout: const Duration(seconds: 5),
        maxResponseBytes: 512,
      );
      await expectLater(
        capped.readOnce(host, good),
        throwsA(
          isA<ApLinkException>()
              .having((e) => e.error, 'error', ApLinkError.protocol)
              .having((e) => e.detail, 'detail', contains('cap')),
        ),
      );
      // The login reply is 27 bytes and must still fit: the ceiling has to bite
      // on the big document, not on the handshake that precedes it.
      expect(
        await ApHttpLink(
          timeout: const Duration(seconds: 5),
          maxResponseBytes: 2 * 1024,
        ).readOnce(host, good).then((s) => s.info.serial),
        'AC5:12345',
      );
    });

    test('a scheme and trailing slashes in the address are tolerated', () async {
      await startEmulator();
      final status = await link.readOnce('http://$host/', good);
      expect(status.info.serial, 'AC5:12345');
    });
  });
}

/// Hits one of the emulator's own control endpoints.
Future<void> _control(ApexEmulator emulator, String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${emulator.port}$path'),
    );
    await (await request.close()).drain<void>();
  } finally {
    client.close();
  }
}
