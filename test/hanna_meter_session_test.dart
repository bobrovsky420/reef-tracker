import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/hanna_meter_link.dart';
import 'package:reeftracker/domain/hanna_meter.dart';
import 'package:reeftracker/features/hanna/hanna_meter_session.dart';

const _info =
    'I,HI97115,06150128,FW,v1.07,nRF FW,v1.01,SN,906150128111,RCL,130,English,v5.0';
const _setup =
    'GS,2069,0,0,backlight,50,contrast,50,tformat,24h,dformat,YYYY_MM_DD,'
    'decsep,dot,language,EN.LNG,beep,on,tutorial,on,BLE PAIR,locmax,10,';

/// Scripted stand-in for the BLE transport: answers every command the way the
/// real meter did in the capture. Delivery is asynchronous (plain broadcast
/// controllers), matching real BLE — the session reacts to a line by sending
/// the next command, which must not re-enter a dispatch in progress.
class FakeHannaMeterLink implements HannaMeterLink {
  final _lines = StreamController<String>.broadcast();
  final _disc = StreamController<void>.broadcast();
  final List<String> sent = [];

  /// Overrides keyed by exact command; anything absent uses [_autoReply].
  final Map<String, List<String>> replies = {};

  HannaLinkException? connectError;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<void> get onDisconnected => _disc.stream;

  @override
  Future<String> connect() async {
    final err = connectError;
    if (err != null) throw err;
    return 'HI97115 06150128';
  }

  @override
  Future<void> send(String command) async {
    sent.add(command);
    for (final line in replies[command] ?? _autoReply(command)) {
      _lines.add(line);
    }
  }

  List<String> _autoReply(String cmd) {
    if (cmd == hannaCmdInfo) return const [_info];
    if (cmd.startsWith('set time')) return const ['ST,Ack'];
    if (cmd == hannaCmdGetBattery) return const ['GB,75,%'];
    if (cmd == hannaCmdGetSetup) return const [_setup];
    if (cmd == hannaCmdGetTanks) return const ['GL,200G2,TANK2,TANK3,'];
    if (cmd == hannaCmdMeasOn) return const ['SM,Ack'];
    if (cmd == hannaCmdStart) return const ['SS,Ack'];
    if (cmd.startsWith('set setup method')) return const ['SD,Ack'];
    if (cmd == hannaCmdExit) return const ['SE,Ack'];
    return const [];
  }

  void emit(String line) => _lines.add(line);

  void dropConnection() => _disc.add(null);

  @override
  Future<void> dispose() async {}
}

String _result(int code, String value, String ts) =>
    'M,$code, ,$value,0,200G2,0,06150128,$ts,STATUS,11,Z,R';

/// Lets queued microtasks/zero timers run so async stream deliveries land.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeHannaMeterLink link;
  late HannaMeterSession session;

  setUp(() {
    link = FakeHannaMeterLink();
    session = HannaMeterSession(
      () => link,
      clock: () => DateTime(2026, 7, 21, 12),
    );
  });

  tearDown(() {
    session.dispose();
  });

  test('connect runs the full handshake and lands ready', () async {
    await session.connect();
    expect(session.phase, HannaSessionPhase.ready);
    expect(session.deviceName, 'HI97115 06150128');
    expect(session.info?.firmware, 'v1.07');
    expect(session.battery, 75);
    expect(session.meterTanks, ['200G2', 'TANK2', 'TANK3']);
    // RTC synced from the injected clock.
    expect(link.sent, contains('set time 20260721120000'));
  });

  test('link errors map to session error kinds', () async {
    link.connectError = const HannaLinkException(HannaLinkError.notFound);
    await session.connect();
    expect(session.phase, HannaSessionPhase.failed);
    expect(session.error, HannaSessionErrorKind.notFound);
  });

  test('measures queued methods one by one and finishes', () async {
    await session.connect();
    await session.startMeasurements([
      hannaMethodByCode(2002)!,
      hannaMethodByCode(2095)!,
    ]);
    expect(session.phase, HannaSessionPhase.measuring);
    expect(session.runs[0].status, HannaRunStatus.running);
    expect(session.runs[1].status, HannaRunStatus.pending);
    expect(link.sent, contains(hannaCmdMeasOn));
    expect(link.sent, contains('set setup method,2002'));

    // Progress ticks surface the meter's STATUS step on the current run.
    link.emit('T,2002,-,-,0,200G2,0,06150128,-,STATUS,3,-,-');
    await _pump();
    expect(session.runs[0].progressStep, 3);

    link.emit(_result(2002, '8.104962', '20260721102041'));
    await _pump();
    expect(session.runs[0].status, HannaRunStatus.done);
    expect(session.runs[0].value, closeTo(8.104962, 1e-9));
    expect(session.runs[0].takenAt, DateTime(2026, 7, 21, 10, 20, 41));
    expect(session.runs[1].status, HannaRunStatus.running);
    expect(link.sent, contains('set setup method,2095'));

    link.emit(_result(2095, '11.525447', '20260721103106'));
    await _pump();
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.completedRuns.length, 2);
    expect(session.resultTankName, '200G2');
    expect(link.sent.last, hannaCmdExit);
  });

  test('a result frame for the wrong method is ignored', () async {
    await session.connect();
    await session.startMeasurements([hannaMethodByCode(2002)!]);
    link.emit(_result(2095, '11.5', '20260721103106'));
    await _pump();
    expect(session.runs[0].status, HannaRunStatus.running);
    expect(session.phase, HannaSessionPhase.measuring);
  });

  test('skip moves on; stopEarly keeps captured results', () async {
    await session.connect();
    await session.startMeasurements([
      hannaMethodByCode(2002)!,
      hannaMethodByCode(2069)!,
      hannaMethodByCode(2097)!,
    ]);
    link.emit(_result(2002, '8.1', '20260721102041'));
    await _pump();
    await session.skipCurrent(); // 2069
    expect(session.runs[1].status, HannaRunStatus.skipped);
    expect(session.runs[2].status, HannaRunStatus.running);
    await session.stopEarly();
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.runs[2].status, HannaRunStatus.skipped);
    expect(session.completedRuns.length, 1);
  });

  test('mid-run disconnect keeps captured results, flags the ending', () async {
    await session.connect();
    await session.startMeasurements([
      hannaMethodByCode(2002)!,
      hannaMethodByCode(2095)!,
    ]);
    link.emit(_result(2002, '8.1', '20260721102041'));
    await _pump();
    link.dropConnection();
    await _pump();
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.endedByDisconnect, isTrue);
    expect(session.completedRuns.length, 1);
    expect(session.runs[1].status, HannaRunStatus.skipped);
  });

  test('disconnect with nothing captured fails the session', () async {
    await session.connect();
    await session.startMeasurements([hannaMethodByCode(2002)!]);
    link.dropConnection();
    await _pump();
    expect(session.phase, HannaSessionPhase.failed);
    expect(session.error, HannaSessionErrorKind.connectionLost);
  });
}
