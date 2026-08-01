import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/hanna_meter_link.dart';
import '../../domain/hanna_meter.dart';

/// Where the live-measurement flow currently stands:
/// `connecting → ready → measuring → finished`, with [failed] as the
/// off-ramp; a retry starts over with a fresh link. The one way back is
/// [HannaMeterSession.remeasure], which re-enters [measuring] from
/// [finished] for a subset of the queue.
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

  /// What this run held before the current re-measure pass. Restored if the
  /// pass ends without a new value, and shown as a "was …" caption once one
  /// lands, so a redo can be compared against what it replaced.
  double? previousValue;
  DateTime? previousTakenAt;

  /// True when a re-measure pass for this run ended without a new value (the
  /// user skipped it, finished early, or the link dropped) and the earlier
  /// reading was put back — the screen leaves such a value out of the save
  /// until the user says otherwise.
  bool remeasureAbandoned = false;
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

  /// Whether the transport is still usable. Distinct from [phase]: a meter
  /// that drops *after* the queue finished leaves a perfectly savable set of
  /// results behind, but nothing can be measured again on it.
  bool _linkAlive = false;

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

  /// Indices into [runs] that the current pass measures, in order: every run
  /// on the first pass, the user's marked subset on a re-measure. [_cursor]
  /// indexes this queue, not [runs].
  List<int> _queue = const [];
  int _cursor = 0;

  /// True while the current pass is a re-measurement of already-captured
  /// methods rather than the session's first run through the queue.
  bool remeasuring = false;

  /// The runs of the current pass in queue order — what the runner step
  /// lists. Identical to [runs] on the first pass.
  List<HannaMethodRun> get passRuns => [
    for (final i in _queue)
      if (i < runs.length) runs[i],
  ];

  HannaMethodRun? get currentRun =>
      phase == HannaSessionPhase.measuring && _cursor < _queue.length
      ? runs[_queue[_cursor]]
      : null;

  List<HannaMethodRun> get completedRuns => [
    for (final r in runs)
      if (r.status == HannaRunStatus.done) r,
  ];

  static const _replyTimeout = Duration(seconds: 8);

  /// Monotonic connect generation (#88): a second [connect] — a double-tapped
  /// "Try again" — supersedes the first, whose remaining awaits must neither
  /// drive the phase nor fail the session once the winner owns the link.
  int _connectGen = 0;

  /// True when [gen]'s connect attempt has been superseded (or the session
  /// disposed) — everything it still holds must be dropped on the floor.
  bool _stale(int gen) => _disposed || gen != _connectGen;

  /// (Re)starts the whole session with a fresh link. Safe to call from the
  /// failed phase as the retry action; re-entrant — a connect already in
  /// flight is superseded, its link torn down, its late completions ignored.
  Future<void> connect() async {
    final gen = ++_connectGen;
    // Phase first, teardown second: disposing the loser's link can take
    // seconds, and the failed view's retry button must not stay live for
    // them (#77's class).
    phase = HannaSessionPhase.connecting;
    error = null;
    endedByDisconnect = false;
    _notify();
    await _teardownLink();
    if (_stale(gen)) return;
    final link = _linkFactory();
    _link = link;
    try {
      final name = await link.connect();
      if (_stale(gen)) return;
      deviceName = name;
      _linkAlive = true;
      _notify();
      _lineSub = link.lines.listen(_onLine);
      _discSub = link.onDisconnected.listen((_) => _onDisconnected());

      final infoLine = await _request(
        hannaCmdInfo,
        (l) => parseHannaInfo(l) != null,
      );
      if (_stale(gen)) return;
      info = parseHannaInfo(infoLine);
      await _request(hannaCmdSetTime(_clock()), (l) => isHannaAck(l, 'ST'));
      final batteryLine = await _request(
        hannaCmdGetBattery,
        (l) => parseHannaBattery(l) != null,
      );
      if (_stale(gen)) return;
      battery = parseHannaBattery(batteryLine);
      await _request(hannaCmdGetSetup, (l) => l.startsWith('GS'));
      final tanks = await _collectTanks();
      if (_stale(gen)) return;
      meterTanks = tanks;
      phase = HannaSessionPhase.ready;
      _notify();
    } on HannaLinkException catch (e) {
      if (_stale(gen)) return;
      _fail(switch (e.error) {
        HannaLinkError.unsupported => HannaSessionErrorKind.unsupported,
        HannaLinkError.bluetoothOff => HannaSessionErrorKind.bluetoothOff,
        HannaLinkError.notFound => HannaSessionErrorKind.notFound,
        HannaLinkError.connectionFailed =>
          HannaSessionErrorKind.connectionFailed,
      });
    } catch (_) {
      if (_stale(gen)) return;
      _fail(HannaSessionErrorKind.connectionFailed);
    }
  }

  /// Queues [methods] and enters measurement mode. The per-method result wait
  /// is unbounded — progress ticks and the final result frame arrive via
  /// [_onLine].
  Future<void> startMeasurements(List<HannaMeterMethod> methods) async {
    if (phase != HannaSessionPhase.ready || methods.isEmpty) return;
    runs = [for (final m in methods) HannaMethodRun(m)];
    _queue = [for (var i = 0; i < runs.length; i++) i];
    _cursor = 0;
    remeasuring = false;
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

  /// Whether the results step can still offer another measurement pass: the
  /// queue is done and the meter is still on the other end of the link.
  bool get canRemeasure =>
      phase == HannaSessionPhase.finished && _linkAlive && !_disposed;

  /// Re-enters measurement mode for [targets] — results the user rejected on
  /// the confirm step (wrong reagent, spoiled cuvette). The meter is still
  /// connected at this point ([_finish] only sends `exit`), so the pass is
  /// the same handshake as a first run.
  ///
  /// Each target's captured value is stashed, not dropped: an abandoned pass
  /// puts it back rather than losing a reading the user may still want.
  /// Returns false if the pass couldn't be started (the meter stopped
  /// answering) — the results are left exactly as they were.
  Future<bool> remeasure(List<HannaMethodRun> targets) async {
    if (!canRemeasure || targets.isEmpty) return false;
    final queue = [
      for (var i = 0; i < runs.length; i++)
        if (targets.contains(runs[i])) i,
    ];
    if (queue.isEmpty) return false;
    for (final i in queue) {
      final run = runs[i];
      run.previousValue = run.value;
      run.previousTakenAt = run.takenAt;
      run.remeasureAbandoned = false;
      run.status = HannaRunStatus.pending;
      run.value = null;
      run.takenAt = null;
      run.progressStep = null;
    }
    _queue = queue;
    _cursor = 0;
    remeasuring = true;
    phase = HannaSessionPhase.measuring;
    _notify();
    try {
      await _request(hannaCmdMeasOn, (l) => isHannaAck(l, 'SM'));
      await _request(hannaCmdStart, (l) => isHannaAck(l, 'SS'));
      await _selectCurrent();
      return true;
    } catch (_) {
      // The meter went to sleep or was walked back to its home screen. Undo
      // the pass and hand the intact results back to the confirm step.
      for (final i in queue) {
        _restorePrevious(runs[i]);
      }
      phase = HannaSessionPhase.finished;
      _notify();
      return false;
    }
  }

  /// Puts a run that was queued for re-measurement but produced no new value
  /// back the way it was, and flags it as abandoned. Returns false when there
  /// is nothing to restore (an ordinary first-pass run), leaving the caller
  /// to mark it skipped.
  bool _restorePrevious(HannaMethodRun run) {
    final value = run.previousValue;
    final takenAt = run.previousTakenAt;
    if (value == null || takenAt == null) return false;
    run.value = value;
    run.takenAt = takenAt;
    run.status = HannaRunStatus.done;
    run.progressStep = null;
    run.previousValue = null;
    run.previousTakenAt = null;
    run.remeasureAbandoned = true;
    return true;
  }

  /// Abandons the currently running method and moves on (the meter is simply
  /// told to select the next method; per-method state on the device resets).
  Future<void> skipCurrent() async {
    final run = currentRun;
    if (run == null) return;
    if (!_restorePrevious(run)) run.status = HannaRunStatus.skipped;
    await _advance();
  }

  /// Ends the run now: everything not yet measured is skipped and whatever
  /// was captured goes to the results.
  Future<void> stopEarly() async {
    if (phase != HannaSessionPhase.measuring) return;
    for (final r in runs) {
      if (r.status == HannaRunStatus.pending ||
          r.status == HannaRunStatus.running) {
        if (!_restorePrevious(r)) r.status = HannaRunStatus.skipped;
      }
    }
    await _finish();
  }

  Future<void> _selectCurrent() async {
    final run = runs[_queue[_cursor]];
    run.status = HannaRunStatus.running;
    _notify();
    await _request(
      hannaCmdSelectMethod(run.method.code),
      (l) => isHannaAck(l, 'SD'),
    );
  }

  Future<void> _advance() async {
    _cursor++;
    if (_cursor < _queue.length) {
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
    if (_disposed) return;
    final wasAlive = _linkAlive;
    _linkAlive = false;
    if (phase == HannaSessionPhase.finished ||
        phase == HannaSessionPhase.failed) {
      // Nothing to salvage — but a results step still offering another
      // measurement pass has to stop offering it.
      if (wasAlive) _notify();
      return;
    }
    if (phase == HannaSessionPhase.measuring) {
      // Keep what was captured — the user confirmed each value on the meter;
      // losing the link afterwards shouldn't throw the results away. A run
      // queued for re-measurement gets its earlier reading back instead of
      // dying with the pass, so restoring comes before the "anything left?"
      // test: a pass that re-measured *every* result still has results.
      for (final r in runs) {
        if (r.status != HannaRunStatus.done && !_restorePrevious(r)) {
          r.status = HannaRunStatus.skipped;
        }
      }
      if (completedRuns.isNotEmpty) {
        endedByDisconnect = true;
        phase = HannaSessionPhase.finished;
        _notify();
        return;
      }
    }
    _fail(HannaSessionErrorKind.connectionLost);
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
    // A failing send abandons `reply`, whose eventual timeout would then be
    // an unhandled async error. Marking it handled costs nothing — an await
    // below still receives the error.
    reply.ignore();
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
    _linkAlive = false;
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
