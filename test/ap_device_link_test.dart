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
    bool rejectSessionLogin = false,
  }) async {
    emulator = ApexEmulator(
      firmware: firmware,
      tempUnit: unit,
      serial: serial,
      rejectSessionLogin: rejectSessionLogin,
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

    test('an over-cap /rest/config degrades to an inferred unit instead of '
        'failing the read', () async {
      await startEmulator(unit: EmuTempUnit.fahrenheit);
      // Case B of the temperature-unit resolution (Case A — the config answers
      // — is the test above). `/rest/config` carries every output's program
      // text and is the largest document an Apex serves: ~4 KB here against
      // ~2 KB of status, and pages of it on a real controller. A ceiling
      // between the two therefore reproduces the field case exactly — status
      // fits, config does not — and `_tryGetJson` swallows the refusal.
      final capped = ApHttpLink(
        timeout: const Duration(seconds: 5),
        maxResponseBytes: 3 * 1024,
      );
      final status = await capped.readOnce(host, good);

      // Deliberate and bounded: the card is complete, only the *authority* for
      // the unit is gone. Nothing said "Faren" — the ~78 °F reading did.
      expect(status.info.serial, 'AC5:12345');
      expect(status.tempUnit, ApTempUnit.fahrenheit);
      final temp = status.readings.firstWhere(
        (r) => r.paramKey == 'temperature',
      );
      expect(temp.unit, '°C');
      expect(temp.value, inInclusiveRange(24, 27));
      expect(status.outlets, isNotEmpty);
    });

    test('the cost of that degradation: a °F controller at or below 45 °F is '
        'read as Celsius', () async {
      await startEmulator(unit: EmuTempUnit.fahrenheit);
      // 5 °C ≈ 41 °F — a chiller stuck on, or a probe sitting in the air of an
      // unheated garage. Under `apInferTempUnit`'s 45 threshold, so the range
      // test cannot tell it from a Celsius number. This is the documented
      // blind spot; it is pinned here so that widening the fallback (or
      // narrowing the threshold) is a visible decision.
      await _control(emulator, '/emu/probe?name=Tmp&value=5');
      final capped = ApHttpLink(
        timeout: const Duration(seconds: 5),
        maxResponseBytes: 3 * 1024,
      );

      final degraded = await capped.readOnce(host, good);
      expect(degraded.tempUnit, ApTempUnit.celsius);
      expect(
        degraded.readings.firstWhere((r) => r.paramKey == 'temperature').value,
        41.0,
      );

      // The same controller, same probe, with the config within reach: the
      // authoritative answer is right, so the blind spot is the price of the
      // fallback and not of the parser.
      final authoritative = await link.readOnce(host, good);
      expect(authoritative.tempUnit, ApTempUnit.fahrenheit);
      expect(
        authoritative.readings
            .firstWhere((r) => r.paramKey == 'temperature')
            .value,
        5.0,
      );
    });

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
      expect(status.readings.firstWhere((r) => r.paramKey == 'ph').value, 7.62);
    });
  });

  group('Classic', () {
    test('falls back to Basic auth when /rest/login 404s', () async {
      await startEmulator(firmware: EmuFirmware.classic, serial: 'AJ:98765');
      final status = await link.readOnce(host, good);
      expect(status.info.firmware, ApFirmware.classic);
      expect(status.info.serial, 'AJ:98765');
      expect(status.info.displayName, 'Apex Classic');
      // Classic firmware pads its numbers into strings — they still parse.
      expect(status.readings.map((r) => r.paramKey), contains('temperature'));
      expect(status.feed!.running, isFalse);
    });

    test('a 401 on /rest/login falls back to Basic auth and SUCCEEDS', () async {
      // Rung 3 of the ladder in ap_device_link.dart's header: the controller
      // routes /rest and rejects the *session* login, but still honours Basic
      // auth on the legacy path. Every other test reaches this rung on its way
      // to a failure, so the branch that has to keep working — a 401 means
      // "try Basic", never "wrong credentials" — is only pinned here. Make
      // `_login` throw on 401 and every such controller reports bad
      // credentials forever, with correct credentials.
      await startEmulator(rejectSessionLogin: true, serial: 'AC5:55555');
      final status = await link.readOnce(host, good);

      expect(status.info.serial, 'AC5:55555');
      // The side effect, recorded rather than lamented: the read lands on the
      // legacy document, so the controller is labelled by the API that
      // answered, not by the firmware it is actually running…
      expect(status.info.firmware, ApFirmware.classic);
      expect(status.info.displayName, 'Apex Classic');
      expect(status.readings.map((r) => r.paramKey), contains('temperature'));
      // …and with no /rest/config in the picture the unit is inferred, exactly
      // as for a real Classic.
      expect(status.tempUnit, ApTempUnit.celsius);
      expect(status.overriddenOutlets.map((o) => o.name), ['Wavemaker']);
    });

    test('a 401 login with credentials Basic also rejects is still an auth '
        'error', () async {
      // The negative control for the rung above: falling through a 401 must
      // not turn a genuinely wrong password into anything but [auth].
      await startEmulator(rejectSessionLogin: true);
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

    test(
      'a host that answers but is not an Apex is a protocol error',
      () async {
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
      },
    );

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

    test(
      'a scheme and trailing slashes in the address are tolerated',
      () async {
        await startEmulator();
        final status = await link.readOnce('http://$host/', good);
        expect(status.info.serial, 'AC5:12345');
      },
    );

    test(
      'a typed address with a garbage port is a protocol error (#83)',
      () async {
        await startEmulator();
        // `Uri.parse('http://1.2.3.4:bad/…')` throws FormatException — before
        // #83 that escaped the ApLinkException contract and the add-sheet Check
        // silently did nothing.
        await expectLater(
          link.readOnce('1.2.3.4:bad', good),
          throwsA(
            isA<ApLinkException>().having(
              (e) => e.error,
              'error',
              ApLinkError.protocol,
            ),
          ),
        );
      },
    );

    test('a hostile login reply with a newline session id is a protocol '
        'error, not a wedge (#83)', () async {
      // Not the emulator: a *hostile* host at the stored address, answering
      // the login with a session id that would corrupt the Cookie header.
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"connect.sid": "abc\\ndef"}');
        await request.response.close();
      });
      try {
        await expectLater(
          link.readOnce('127.0.0.1:${server.port}', good),
          throwsA(
            isA<ApLinkException>().having(
              (e) => e.error,
              'error',
              ApLinkError.protocol,
            ),
          ),
        );
      } finally {
        await server.close(force: true);
      }
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
