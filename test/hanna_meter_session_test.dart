import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/hanna_meter_link.dart';
import 'package:reeftracker/domain/hanna_meter.dart';
import 'package:reeftracker/features/hanna/hanna_meter_session.dart';

import 'fake_hanna_link.dart';

const _result = hannaResultFrame;

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

  test('a nitrite LR result scales from the meter\'s ppb to ppm', () async {
    await session.connect();
    await session.startMeasurements([hannaMethodByCode(2057)!]);
    link.emit(_result(2057, '15', '20260721102041'));
    await _pump();
    expect(session.runs[0].status, HannaRunStatus.done);
    expect(session.runs[0].value, closeTo(0.015, 1e-9));
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

  /// Two measured results, sitting on the confirm step.
  Future<void> measureTwo() async {
    await session.connect();
    await session.startMeasurements([
      hannaMethodByCode(2002)!,
      hannaMethodByCode(2095)!,
    ]);
    link.emit(_result(2002, '8.1', '20260721102041'));
    await _pump();
    link.emit(_result(2095, '11.5', '20260721103106'));
    await _pump();
    expect(session.phase, HannaSessionPhase.finished);
  }

  test('remeasure re-runs only the marked results and replaces them', () async {
    await measureTwo();
    expect(await session.remeasure([session.runs[0]]), isTrue);
    expect(session.phase, HannaSessionPhase.measuring);
    expect(session.remeasuring, isTrue);
    // The pass — and therefore the runner list — is the marked subset only.
    expect(session.passRuns, [session.runs[0]]);
    expect(session.currentRun, session.runs[0]);
    expect(session.runs[0].previousValue, closeTo(8.1, 1e-9));
    expect(session.runs[0].value, isNull);
    expect(session.runs[1].status, HannaRunStatus.done);

    link.emit(_result(2002, '9.4', '20260721111500'));
    await _pump();
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.runs[0].value, closeTo(9.4, 1e-9));
    expect(session.runs[0].takenAt, DateTime(2026, 7, 21, 11, 15));
    expect(session.runs[0].remeasureAbandoned, isFalse);
    // The replaced value stays for the "was …" caption.
    expect(session.runs[0].previousValue, closeTo(8.1, 1e-9));
    expect(session.completedRuns.length, 2);
  });

  test('an abandoned re-measure puts the earlier value back', () async {
    await measureTwo();
    await session.remeasure([session.runs[1]]);
    await session.skipCurrent();
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.runs[1].status, HannaRunStatus.done);
    expect(session.runs[1].value, closeTo(11.5, 1e-9));
    expect(session.runs[1].takenAt, DateTime(2026, 7, 21, 10, 31, 6));
    expect(session.runs[1].remeasureAbandoned, isTrue);
    expect(session.completedRuns.length, 2);
  });

  test('stopEarly during a re-measure keeps every earlier value', () async {
    await measureTwo();
    await session.remeasure(session.runs);
    await session.stopEarly();
    expect(session.completedRuns.length, 2);
    expect(session.runs.map((r) => r.value), [closeTo(8.1, 1e-9), closeTo(11.5, 1e-9)]);
    expect(session.runs.every((r) => r.remeasureAbandoned), isTrue);
  });

  test('a disconnect while re-measuring everything keeps the results', () async {
    await measureTwo();
    await session.remeasure(session.runs);
    link.dropConnection();
    await _pump();
    // Nothing is "done" at the moment the link drops — the restore has to
    // come first, or the whole session would be thrown away as empty.
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.endedByDisconnect, isTrue);
    expect(session.completedRuns.length, 2);
  });

  test('a meter that stops answering leaves the results untouched', () async {
    await measureTwo();
    await link.goSilent();
    expect(await session.remeasure([session.runs[0]]), isFalse);
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.completedRuns.length, 2);
    expect(session.runs[0].value, closeTo(8.1, 1e-9));
    expect(session.runs[0].remeasureAbandoned, isTrue);
  });

  test('remeasure is refused once the link has dropped', () async {
    await session.connect();
    await session.startMeasurements([hannaMethodByCode(2002)!]);
    link.emit(_result(2002, '8.1', '20260721102041'));
    await _pump();
    link.dropConnection();
    await _pump();
    expect(await session.remeasure([session.runs[0]]), isFalse);
    expect(session.phase, HannaSessionPhase.finished);
    expect(session.runs[0].value, closeTo(8.1, 1e-9));
  });
}
