import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rf_device_link.dart';
import 'package:reeftracker/data/rf_protocol.dart';

import '../tool/reeffactory_emulator.dart';

/// T18: drives the REAL RfWebSocketLink transport against the committed fake
/// (`tool/reeffactory_emulator.dart`) — connect, `get/config` → `join` →
/// `settings` state machine, error mapping and teardown — the ReefFactory
/// counterpart of `ap_device_link_test.dart`. The fake hand-rolls the wire
/// format independently of rf_protocol.dart, so a codec regression cannot
/// hide by breaking both sides identically.
///
/// HONESTY NOTE: the fake is written from recorded frames and firmware
/// transcriptions; nothing here has ever run against real ReefFactory
/// hardware.
void main() {
  /// Starts an emulator (torn down after the test) and returns it; connect
  /// with `host(emu)`.
  Future<ReefFactoryEmulator> emulator({
    RfEmuModel model = RfEmuModel.salinity,
    String? serial,
  }) async {
    final emu = ReefFactoryEmulator(model: model, serial: serial);
    await emu.start();
    addTearDown(emu.stop);
    return emu;
  }

  String host(ReefFactoryEmulator emu) => '127.0.0.1:${emu.boundPort}';

  const link = RfWebSocketLink();
  // Short timeout for the paths that deliberately never answer.
  const impatient = RfWebSocketLink(timeout: Duration(milliseconds: 500));

  group('identify', () {
    test('supported model: serial, prefix and display name', () async {
      final emu = await emulator();
      final id = await link.identify(host(emu));
      expect(id.serial, 'RFSG01EMU0000001');
      expect(id.modelPrefix, 'RFSG01');
      expect(id.supported, isTrue);
      expect(id.displayName, 'Salinity Guardian');
    });

    test('unknown model prefix: found-but-unsupported, NOT an error — '
        'discovery reports it instead of skipping it', () async {
      final emu = await emulator(serial: 'RFXX99EMU0000001');
      final id = await link.identify(host(emu));
      expect(id.serial, 'RFXX99EMU0000001');
      expect(id.supported, isFalse);
      expect(id.modelName, isNull);
    });

    test('nothing listening on the port maps to unreachable', () async {
      await expectLater(
        impatient.identify('127.0.0.1:1'),
        throwsA(
          isA<RfLinkException>().having(
            (e) => e.error,
            'error',
            RfLinkError.unreachable,
          ),
        ),
      );
    });
  });

  group('readOnce', () {
    test('salinity meter: full handshake, values through the device\'s own '
        'PSS-78 conversion', () async {
      final emu = await emulator()
        ..pinnedConductivity = 53.0
        ..pinnedTemperature = 25.0;
      final snap = await link.readOnce(host(emu));
      expect(snap.modelName, 'salinity');
      expect(snap.modelDisplayName, 'Salinity Guardian');
      final byName = {for (final r in snap.readings) r.paramKey: r};
      // The link must reproduce the meter's own display math exactly.
      expect(byName['salinity']!.value, calculateSalinity(53.0, 25.0));
      expect(byName['salinity']!.unit, 'ppt');
      expect(byName['temperature']!.value, closeTo(25.0, 1e-9));
    });

    test('pH monitor: the second command family joins too', () async {
      final emu = await emulator(model: RfEmuModel.ph)
        ..pinnedPh = 7.94;
      final snap = await link.readOnce(host(emu));
      expect(snap.modelName, 'pH');
      expect(snap.readings.single.paramKey, 'ph');
      expect(snap.readings.single.value, closeTo(7.94, 1e-9));
    });

    test('temperature controller: value plus thermal state', () async {
      final emu = await emulator(model: RfEmuModel.temperature)
        ..pinnedTemperature = 24.5;
      final snap = await link.readOnce(host(emu));
      expect(snap.readings.single.paramKey, 'temperature');
      expect(snap.readings.single.value, closeTo(24.5, 1e-9));
      expect(snap.thermal, isNotNull);
    });

    test(
      'unsupported model maps to unsupportedModel with the serial',
      () async {
        final emu = await emulator(serial: 'RFXX99EMU0000001');
        await expectLater(
          link.readOnce(host(emu)),
          throwsA(
            isA<RfLinkException>()
                .having((e) => e.error, 'error', RfLinkError.unsupportedModel)
                .having((e) => e.detail, 'detail', 'RFXX99EMU0000001'),
          ),
        );
      },
    );

    test(
      'socket closed right after connect maps to protocol "closed early"',
      () async {
        final emu = await emulator()
          ..closeAfterUpgrade = true;
        await expectLater(
          link.readOnce(host(emu)),
          throwsA(
            isA<RfLinkException>()
                .having((e) => e.error, 'error', RfLinkError.protocol)
                .having((e) => e.detail, 'detail', 'closed early'),
          ),
        );
      },
    );

    test('a host that accepts and stays silent maps to timeout', () async {
      final emu = await emulator()
        ..silent = true;
      await expectLater(
        impatient.readOnce(host(emu)),
        throwsA(
          isA<RfLinkException>().having(
            (e) => e.error,
            'error',
            RfLinkError.timeout,
          ),
        ),
      );
    });

    test('a device that identifies but never answers the join maps to '
        'timeout', () async {
      final emu = await emulator()
        ..ignoreJoin = true;
      await expectLater(
        impatient.readOnce(host(emu)),
        throwsA(
          isA<RfLinkException>().having(
            (e) => e.error,
            'error',
            RfLinkError.timeout,
          ),
        ),
      );
    });

    test('stray TEXT frames are ignored, not decoded', () async {
      final emu = await emulator()
        ..textFrameBeforeConfig = true;
      final snap = await link.readOnce(host(emu));
      expect(snap.modelName, 'salinity');
    });

    test('an empty settings payload maps to protocol "empty payload" — '
        'firmware drift degrades, never a crash or a fake snapshot', () async {
      final emu = await emulator()
        ..emptySettingsPayload = true;
      await expectLater(
        link.readOnce(host(emu)),
        throwsA(
          isA<RfLinkException>()
              .having((e) => e.error, 'error', RfLinkError.protocol)
              .having((e) => e.detail, 'detail', 'empty payload'),
        ),
      );
    });
  });
}
