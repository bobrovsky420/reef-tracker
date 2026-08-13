// End-to-end coverage of the ReefBeat transport against
// `tool/reefbeat_emulator.dart` — the same pattern as ap_device_link_test:
// driving a real [RbHttpLink] at the fake covers the transport and the parsers
// together, which hand-written JSON fixtures (rb_protocol_test.dart) cannot.
//
// The forced states are the point: the emulator can stand its ATO in RO/DI
// water and fill its skimmer cup on demand, which real hardware only shows
// when something is actually wrong.
//
// Every server binds port 0, so the suite never collides with a real emulator
// process the developer left running.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/rb_device_link.dart';

import '../tool/reefbeat_emulator.dart';

void main() {
  late ReefBeatEmulator emulator;
  late String host;
  final link = RbHttpLink(timeout: const Duration(seconds: 5));

  Future<void> startEmulator(EmuRbType type) async {
    emulator = ReefBeatEmulator(type: type);
    await emulator.start(host: '127.0.0.1', port: 0);
    host = '127.0.0.1:${emulator.port}';
  }

  tearDown(() => emulator.stop());

  test('reads the ATO, dry: sensor row active, no alarm', () async {
    await startEmulator(EmuRbType.ato);
    final snap = await link.readOnce(host);

    expect(snap.info.hwType, 'reef-ato');
    expect(snap.modelDisplayName, 'ReefATO+');
    final ato = snap.ato!;
    expect(ato.leakSensorActive, isTrue);
    expect(ato.leakStatusRaw, 'dry');
    expect(ato.leakAlarm, isFalse);
    expect(ato.temperatureC, closeTo(25.715, 0.001));
  });

  test('a forced RO/DI leak raises the alarm and survives a re-read', () async {
    await startEmulator(EmuRbType.ato);
    await _control(emulator, '/emu/leak?status=rodi_water_leak');

    final leaking = (await link.readOnce(host)).ato!;
    expect(leaking.leakAlarm, isTrue);
    expect(leaking.leakStatusRaw, 'rodi_water_leak');

    await _control(emulator, '/emu/leak?status=dry');
    final dried = (await link.readOnce(host)).ato!;
    expect(dried.leakAlarm, isFalse);
  });

  test('reads the ReefRun, and a forced full cup pauses the skimmer', () async {
    await startEmulator(EmuRbType.run);
    final healthy = (await link.readOnce(host)).run!;
    expect(healthy.pumps, hasLength(2));
    expect(healthy.pumps[1].type, 'skimmer');
    expect(healthy.pumps[1].fullCup, isFalse);
    expect(healthy.pumps[1].intensity, 70);

    await _control(emulator, '/emu/pump?n=2&state=full_cup');
    final paused = (await link.readOnce(host)).run!;
    expect(paused.pumps[1].fullCup, isTrue);
    expect(paused.pumps[1].faulted, isTrue);
    expect(paused.pumps[1].intensity, 0);
    // The return pump is untouched by the skimmer's cup.
    expect(paused.pumps[0].fullCup, isFalse);
    expect(paused.pumps[0].intensity, 80);
  });

  test('reads the ReefDose: four heads with abbreviations resolved', () async {
    await startEmulator(EmuRbType.dose);
    final snap = await link.readOnce(host);

    expect(snap.modelDisplayName, 'ReefDose 4');
    final dose = snap.dose!;
    expect(dose.heads, hasLength(4));
    expect(dose.heads[0].supplement, 'Balling light KH');
    // The abbreviation lives only in /head/<n>/settings — its presence proves
    // the link chased all four settings reads against the fake.
    expect(dose.heads.map((h) => h.shortName), ['KH', 'Ca', 'Mg', 'NPX']);
    expect(dose.heads[0].dosedToday, 26.7);
    expect(dose.heads[0].dailyDose, 40);
    expect(dose.heads[3].planComplete, isTrue);
    expect(dose.heads.every((h) => !h.switchedOff), isTrue);

    // The queue parses; near midnight it may legitimately run empty, so only
    // shape is asserted, not length.
    final queue = await link.readDosingQueue(host);
    for (final entry in queue) {
      expect(['KH', 'Ca', 'Mg', 'NPX'], contains(entry.head));
      expect(entry.volumeMl, isPositive);
    }
  });

  test('a forced low stock survives a re-read', () async {
    await startEmulator(EmuRbType.dose);
    expect((await link.readOnce(host)).dose!.heads[3].remainingDays, 48);

    await _control(emulator, '/emu/dose?head=4&days=5');
    final low = (await link.readOnce(host)).dose!;
    expect(low.heads[3].remainingDays, 5);
    expect(low.heads[3].stockLevel, 'low');
    // The other heads keep their stock.
    expect(low.heads[0].remainingDays, 117);
  });

  test(
    'reads ReefControl probes and forced values survive a re-read',
    () async {
      await startEmulator(EmuRbType.control);
      final snap = await link.readOnce(host);

      expect(snap.info.hwType, 'reef-control');
      expect(snap.modelDisplayName, 'ReefControl Pro');
      final control = snap.control!;
      expect(control.probeOf('ec')!.salinityPpt, 35.8);
      expect(control.probeOf('ph')!.value, 8.06);
      expect(control.probeOf('orp')!.value, 81);
      expect(control.leakProbe!.detected, isFalse);

      await _control(emulator, '/emu/probes?salinity=36.1&ph=7.7&orp=320');
      await _control(emulator, '/emu/leak?status=reef_water_leak');
      final changed = (await link.readOnce(host)).control!;
      expect(changed.probeOf('ec')!.salinityPpt, 36.1);
      expect(changed.probeOf('ph')!.value, 7.7);
      expect(changed.probeOf('orp')!.value, 320);
      expect(changed.leakProbe!.detected, isTrue);
    },
  );
}

/// Hits an `/emu/*` control endpoint (not part of the ReefBeat API).
Future<void> _control(ReefBeatEmulator emulator, String path) async {
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
