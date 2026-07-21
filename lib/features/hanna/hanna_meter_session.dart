import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/hanna_meter_link.dart';
import '../../domain/hanna_meter.dart';

/// Where the live-measurement flow currently stands. One-way street per
/// session: `connecting → ready → measuring → finished`, with [failed] as
/// the off-ramp; a retry starts over with a fresh link.
enum HannaSessionPhase { connecting, ready, measuring, finished, failed }

/// Why the session failed — the link's errors plus a drop after establishment.
enum HannaSessionErrorKind {
  unsupported,
  bluetoothOff,
  notFound,
  connectionFailed,
  connectionLost,
}

/// State of one queued method inside a measurement run.
enum HannaRunStatus { pending, running, done, skipped }

/// One method the user queued, and what became of it.
class HannaMethodRun {
  HannaMethodRun(this.method);

  final HannaMeterMethod method;
  HannaRunStatus status = HannaRunStatus.pending;
  double? value;
  DateTime? takenAt;

  /// The meter's `STATUS` step from the latest progress tick — proof of life
  /// while the user works through reagents on the device.
  int? progressStep;
}

/// Drives one connect-and-measure session against a [HannaMeterLink]:
/// scan/connect, the handshake (`info` → RTC sync → battery → setup → tank
/// list), then the measurement loop — `set meas on` + `set setup start` once,
/// then per queued method `set setup method,<code>` and an unbounded wait for
/// the `…,R` result frame (the user is doing wet chemistry on the meter;
/// minutes are normal). A [ChangeNotifier] so the single screen that owns it
/// can rebuild from one listenable.
class HannaMeterSession extends ChangeNotifier {
  HannaMeterSession(this._linkFactory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final HannaMeterLink Function() _linkFactory;
  final DateTime Function() _clock;

  HannaMeterLink? _link;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<void>? _discSub;
  bool _disposed = false;

  HannaSessionPhase phase = HannaSessionPhase.connecting;
  HannaSessionErrorKind? error;

  /// True on [HannaSessionPhase.finished] when the run ended because the
  /// connection dropped, not because the queue completed.
  bool endedByDisconnect = false;

  String? deviceName;
  HannaMeterInfo? info;
  int? battery;

  /// The meter-side tank/location names from `get setup tank,all`, in meter
  /// order (the first is the meter's location 0).
  List<String> meterTanks = const [];

  /// The location name the result frames carried — the name the meter logs
  /// the readings under on-device, which is what a later CSV export will say.
  String? resultTankName;

  List<HannaMethodRun> runs = const [];
  int _current = 0;

  HannaMethodRun? get currentRun =>
      phase == HannaSessionPhase.measuring && _current < runs.length
      ? runs[_current]
      : null;

  List<HannaMethodRun> get completedRuns => [
    for (final r in runs)
      if (r.status == HannaRunStatus.done) r,
  ];

  static const _replyTimeout = Duration(seconds: 8);

  /// (Re)starts the whole session with a fresh link. Safe to call from the
  /// failed phase as the retry action.
  Future<void> connect() async {
    await _teardownLink();
    final link = _linkFactory();
    _link = link;
    phase = HannaSessionPhase.connecting;
    error = null;
    endedByDisconnect = false;
    _notify();
    try {
      deviceName = await link.connect();
      if (_disposed) return;
      _notify();
      _lineSub = link.lines.listen(_onLine);
      _discSub = link.onDisconnected.listen((_) => _onDisconnected());

      info = parseHannaInfo(
        await _request(hannaCmdInfo, (l) => parseHannaInfo(l) != null),
      );
      await _request(hannaCmdSetTime(_clock()), (l) => isHannaAck(l, 'ST'));
      battery = parseHannaBattery(
        await _request(hannaCmdGetBattery, (l) => parseHannaBattery(l) != null),
      );
      await _request(hannaCmdGetSetup, (l) => l.startsWith('GS'));
      meterTanks = await _collectTanks();
      if (_disposed) return;
      phase = HannaSessionPhase.ready;
      _notify();
    } on HannaLinkException catch (e) {
      _fail(switch (e.error) {
        HannaLinkError.unsupported => HannaSessionErrorKind.unsupported,
        HannaLinkError.bluetoothOff => HannaSessionErrorKind.bluetoothOff,
        HannaLinkError.notFound => HannaSessionErrorKind.notFound,
        HannaLinkError.connectionFailed =>
          HannaSessionErrorKind.connectionFailed,
      });
    } catch (_) {
      _fail(HannaSessionErrorKind.connectionFailed);
    }
  }

  /// Queues [methods] and enters measurement mode. The per-method result wait
  /// is unbounded — progress ticks and the final result frame arrive via
  /// [_onLine].
  Future<void> startMeasurements(List<HannaMeterMethod> methods) async {
    if (phase != HannaSessionPhase.ready || methods.isEmpty) return;
    runs = [for (final m in methods) HannaMethodRun(m)];
    _current = 0;
    phase = HannaSessionPhase.measuring;
    _notify();
    try {
      await _request(hannaCmdMeasOn, (l) => isHannaAck(l, 'SM'));
      await _request(hannaCmdStart, (l) => isHannaAck(l, 'SS'));
      await _selectCurrent();
    } catch (_) {
      _onDisconnected();
    }
  }

  /// Abandons the currently running method and moves on (the meter is simply
  /// told to select the next method; per-method state on the device resets).
  Future<void> skipCurrent() async {
    final run = currentRun;
    if (run == null) return;
    run.status = HannaRunStatus.skipped;
    await _advance();
  }

  /// Ends the run now: everything not yet measured is skipped and whatever
  /// was captured goes to the results.
  Future<void> stopEarly() async {
    if (phase != HannaSessionPhase.measuring) return;
    for (final r in runs) {
      if (r.status == HannaRunStatus.pending ||
          r.status == HannaRunStatus.running) {
        r.status = HannaRunStatus.skipped;
      }
    }
    await _finish();
  }

  Future<void> _selectCurrent() async {
    final run = runs[_current];
    run.status = HannaRunStatus.running;
    _notify();
    await _request(
      hannaCmdSelectMethod(run.method.code),
      (l) => isHannaAck(l, 'SD'),
    );
  }

  Future<void> _advance() async {
    _current++;
    if (_current < runs.length) {
      _notify();
      try {
        await _selectCurrent();
      } catch (_) {
        _onDisconnected();
      }
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    phase = HannaSessionPhase.finished;
    _notify();
    // Best-effort: put the meter back on its home screen.
    try {
      await _link?.send(hannaCmdExit);
    } catch (_) {}
  }

  void _onLine(String line) {
    if (phase != HannaSessionPhase.measuring) return;
    final run = currentRun;
    if (run == null) return;
    final parsed = parseHannaMeasurementFrame(line);
    if (parsed is HannaProgress) {
      if (parsed.methodCode == run.method.code &&
          run.status == HannaRunStatus.running) {
        run.progressStep = parsed.step;
        _notify();
      }
    } else if (parsed is HannaMeasurement) {
      // Trust the frame's method code over our cursor — a stray frame from a
      // method the user switched to on the device must not land on the wrong
      // parameter.
      if (parsed.methodCode != run.method.code) return;
      if (parsed.tankName.isNotEmpty) resultTankName = parsed.tankName;
      // The frame's value is in the meter's unit for this chemistry; scale
      // to the catalog's canonical unit (nitrite LR: ppb → ppm).
      run.value = parsed.value * run.method.factor;
      run.takenAt = parsed.takenAt ?? _clock();
      run.status = HannaRunStatus.done;
      unawaited(_advance());
    }
  }

  void _onDisconnected() {
    if (_disposed ||
        phase == HannaSessionPhase.finished ||
        phase == HannaSessionPhase.failed) {
      return;
    }
    if (phase == HannaSessionPhase.measuring && completedRuns.isNotEmpty) {
      // Keep what was captured — the user confirmed each value on the meter;
      // losing the link afterwards shouldn't throw the results away.
      for (final r in runs) {
        if (r.status != HannaRunStatus.done) r.status = HannaRunStatus.skipped;
      }
      endedByDisconnect = true;
      phase = HannaSessionPhase.finished;
      _notify();
    } else {
      _fail(HannaSessionErrorKind.connectionLost);
    }
  }

  void _fail(HannaSessionErrorKind kind) {
    if (_disposed) return;
    phase = HannaSessionPhase.failed;
    error = kind;
    _notify();
  }

  /// Sends [cmd] and resolves with the first line matching [test]. The
  /// listener is attached before the write so a fast reply can't be missed.
  Future<String> _request(String cmd, bool Function(String) test) async {
    final link = _link!;
    final reply = link.lines.firstWhere(test).timeout(_replyTimeout);
    await link.send(cmd);
    return reply;
  }

  /// Collects the paginated `GL` tank list: a short page ends it, a
  /// multiple-of-page-size list ends on a quiet window instead.
  Future<List<String>> _collectTanks() async {
    final link = _link!;
    final names = <String>[];
    final done = Completer<void>();
    Timer? quiet;
    void arm() {
      quiet?.cancel();
      quiet = Timer(const Duration(milliseconds: 1200), () {
        if (!done.isCompleted) done.complete();
      });
    }

    final sub = link.lines.listen((l) {
      final page = parseHannaTankPage(l);
      if (page == null) return;
      names.addAll(page);
      if (page.length < kHannaTankPageSize) {
        if (!done.isCompleted) done.complete();
      } else {
        arm();
      }
    });
    arm();
    try {
      await link.send(hannaCmdGetTanks);
      await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } finally {
      quiet?.cancel();
      await sub.cancel();
    }
    return names;
  }

  Future<void> _teardownLink() async {
    await _lineSub?.cancel();
    await _discSub?.cancel();
    _lineSub = null;
    _discSub = null;
    final link = _link;
    _link = null;
    if (link != null) await link.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final link = _link;
    if (link != null && phase == HannaSessionPhase.measuring) {
      // Leaving mid-run: best-effort take the meter out of measurement mode
      // before dropping the connection.
      unawaited(() async {
        try {
          await link.send(hannaCmdExit);
        } catch (_) {}
        await _teardownLink();
      }());
    } else {
      unawaited(_teardownLink());
    }
    super.dispose();
  }
}
