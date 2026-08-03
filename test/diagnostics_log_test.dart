import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/diagnostics_log.dart';

/// #107 — the on-device error ring-buffer log and the global error hooks.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diag_test');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  DiagnosticsLog makeLog({int maxBytes = kDiagnosticsLogMaxBytes}) =>
      DiagnosticsLog(directory: () async => dir, maxBytes: maxBytes);

  test(
    'record → read round-trip carries timestamp, library, error and stack',
    () async {
      final log = makeLog();
      log.record(
        library: 'providers',
        summary: 'provider tankHealth failed',
        error: StateError('boom'),
        stack: StackTrace.fromString(
          List.generate(30, (i) => '#$i frame$i').join('\n'),
        ),
      );
      final text = await log.read();
      expect(text, isNotNull);
      expect(text, contains('[providers] provider tankHealth failed'));
      expect(text, contains('Bad state: boom'));
      // Stack is truncated to kDiagnosticsMaxStackLines frames + ellipsis.
      expect(text, contains('#${kDiagnosticsMaxStackLines - 1} '));
      expect(text, isNot(contains('#$kDiagnosticsMaxStackLines ')));
      expect(text, contains('…'));
    },
  );

  test('read() is null when nothing was ever recorded', () async {
    expect(await makeLog().read(), isNull);
  });

  test('rotation keeps one previous generation and read() concatenates '
      'old-first', () async {
    final log = makeLog(maxBytes: 200);
    for (var i = 0; i < 20; i++) {
      log.record(library: 'test', summary: 'entry number $i');
    }
    await log.settled;
    final current = File('${dir.path}/$kDiagnosticsLogFileName');
    final previous = File('${dir.path}/$kDiagnosticsLogPreviousFileName');
    expect(await current.exists(), isTrue);
    expect(await previous.exists(), isTrue);
    // Both files stay bounded: rotation happens once the current file
    // exceeds maxBytes, so neither grows past maxBytes + one entry.
    expect(await current.length(), lessThan(400));
    expect(await previous.length(), lessThan(400));
    final text = (await log.read())!;
    // Newest entry always survives; the oldest was rotated away eventually.
    expect(text, contains('entry number 19'));
    // Concatenation order is previous generation first.
    final firstKept = RegExp('entry number (\\d+)').firstMatch(text)!.group(1)!;
    final lastKept = RegExp(
      'entry number (\\d+)',
    ).allMatches(text).last.group(1)!;
    expect(int.parse(firstKept), lessThan(int.parse(lastKept)));
  });

  test('a failing directory lookup never throws — and recovers once the '
      'directory works again', () async {
    var broken = true;
    final log = DiagnosticsLog(
      directory: () async {
        if (broken) throw const FileSystemException('no docs dir');
        return dir;
      },
    );
    log.record(library: 'test', summary: 'lost entry');
    await log.settled;
    expect(await log.read(), isNull);

    broken = false;
    log.record(library: 'test', summary: 'kept entry');
    final text = await log.read();
    expect(text, contains('kept entry'));
  });

  test('installDiagnosticsHooks: FlutterError.reportError lands in the log '
      'and still reaches the previous handler', () async {
    final log = makeLog();
    final previousHook = FlutterError.onError;
    FlutterErrorDetails? seenByPrevious;
    FlutterError.onError = (details) => seenByPrevious = details;
    try {
      installDiagnosticsHooks(log);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('funneled'),
          library: 'cloud_sync',
          context: ErrorSummary('running the Drive backup sync'),
        ),
      );
      final text = await log.read();
      expect(text, contains('[cloud_sync] running the Drive backup sync'));
      expect(text, contains('Bad state: funneled'));
      expect(seenByPrevious?.exception, isA<StateError>());
    } finally {
      FlutterError.onError = previousHook;
    }
  });

  test('installDiagnosticsHooks: unhandled async errors are funneled and '
      'marked handled', () async {
    final log = makeLog();
    final previousHook = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      installDiagnosticsHooks(log);
      final handled = PlatformDispatcher.instance.onError!(
        StateError('async boom'),
        StackTrace.current,
      );
      expect(handled, isTrue);
      final text = await log.read();
      expect(text, contains('[async] unhandled asynchronous error'));
      expect(text, contains('Bad state: async boom'));
    } finally {
      FlutterError.onError = previousHook;
      PlatformDispatcher.instance.onError = null;
    }
  });

  test('record cap: entries past the per-run limit are dropped with one '
      'marker line', () async {
    final log = makeLog();
    for (var i = 0; i < kDiagnosticsMaxRecordsPerRun + 50; i++) {
      log.record(library: 'storm', summary: 'entry $i');
    }
    await log.settled;
    final text = (await log.read())!;
    expect(text, contains('record cap reached'));
    expect(text, isNot(contains('entry ${kDiagnosticsMaxRecordsPerRun + 10}')));
  });
}
