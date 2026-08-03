import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device error log (#107).
///
/// The app is offline-first, so there is no crash-reporting backend: instead
/// every funneled error ([FlutterError.reportError] — which the
/// `ProviderErrorObserver`, the fire-and-forget launch tasks and the framework
/// itself all go through — plus unhandled async errors via
/// [PlatformDispatcher.onError]) is appended to a small ring-buffer file under
/// the app documents directory. The user can hand the log to support via
/// Settings → About → "Share diagnostics"; without it a field report of "my
/// data is gone" is undiagnosable in release, where logcat lines are lost.
///
/// Best-effort by design: logging must never throw, block startup, or grow
/// unbounded. Writes are serialized on one future chain; the file is rotated
/// once it exceeds [kDiagnosticsLogMaxBytes] (one previous generation is
/// kept, so the log holds at most ~2× that), and a per-process record cap
/// stops an error storm from looping the ring.
class DiagnosticsLog {
  /// [directory] is injectable so tests can point at a temp dir instead of
  /// the platform's documents directory (the `DeviceSecrets` pattern);
  /// [maxBytes] so rotation is testable without megabytes of noise.
  DiagnosticsLog({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
    this.maxBytes = kDiagnosticsLogMaxBytes,
  }) : _directory = directory ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;

  /// Rotation threshold for the current log file.
  final int maxBytes;

  Future<Directory>? _dirFuture;
  Future<void> _pending = Future.value();
  int _recorded = 0;

  /// Appends one entry. Fire-and-forget: hooks call this synchronously and
  /// the write is chained (and error-swallowed) behind [_pending].
  void record({
    required String library,
    required String summary,
    Object? error,
    StackTrace? stack,
  }) {
    if (_recorded > kDiagnosticsMaxRecordsPerRun) return;
    _recorded++;
    final entry = _recorded > kDiagnosticsMaxRecordsPerRun
        ? '${_now().toUtc().toIso8601String()} [diagnostics] '
              'record cap reached — further errors this run are dropped\n'
        : _format(_now().toUtc(), library, summary, error, stack);
    _pending = _pending.then((_) => _append(entry)).catchError((Object _) {
      /* never propagate a logging failure */
    });
  }

  /// [record] for an already-packaged [FlutterErrorDetails] (the
  /// [FlutterError.onError] hook).
  void recordFlutterError(FlutterErrorDetails details) => record(
    library: details.library ?? 'framework',
    summary: details.context?.toDescription() ?? 'unhandled error',
    error: details.exception,
    stack: details.stack,
  );

  /// The whole log (previous generation first), or null when nothing has
  /// been recorded or the log cannot be read.
  Future<String?> read() async {
    try {
      await _pending;
      final dir = await _dir();
      final buf = StringBuffer();
      for (final name in [
        kDiagnosticsLogPreviousFileName,
        kDiagnosticsLogFileName,
      ]) {
        final file = File(p.join(dir.path, name));
        if (await file.exists()) buf.write(await file.readAsString());
      }
      final text = buf.toString();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Test seam: resolves when every [record] issued so far has been written
  /// (or given up).
  @visibleForTesting
  Future<void> get settled => _pending;

  String _format(
    DateTime at,
    String library,
    String summary,
    Object? error,
    StackTrace? stack,
  ) {
    final buf = StringBuffer('${at.toIso8601String()} [$library] $summary\n');
    if (error != null) {
      var text = error.toString();
      if (text.length > kDiagnosticsMaxErrorChars) {
        text = '${text.substring(0, kDiagnosticsMaxErrorChars)}…';
      }
      for (final line in text.split('\n')) {
        buf.writeln('  $line');
      }
    }
    if (stack != null) {
      final lines = stack.toString().split('\n');
      for (final line in lines.take(kDiagnosticsMaxStackLines)) {
        if (line.isEmpty) continue;
        buf.writeln('  $line');
      }
      if (lines.length > kDiagnosticsMaxStackLines) buf.writeln('  …');
    }
    return buf.toString();
  }

  Future<void> _append(String entry) async {
    final dir = await _dir();
    final file = File(p.join(dir.path, kDiagnosticsLogFileName));
    if (await file.exists() && await file.length() > maxBytes) {
      final prev = File(p.join(dir.path, kDiagnosticsLogPreviousFileName));
      if (await prev.exists()) await prev.delete();
      await file.rename(prev.path);
    }
    await file.writeAsString(entry, mode: FileMode.append, flush: true);
  }

  /// Documents-dir lookup, memoized on success only — a failure (or the
  /// pre-first-frame platform-channel hang, flutter/flutter#72872, bounded
  /// here like `_documentsDir` in database.dart) must not poison the log for
  /// the rest of the process.
  Future<Directory> _dir() async {
    try {
      return await (_dirFuture ??= _resolveDir());
    } catch (_) {
      _dirFuture = null;
      rethrow;
    }
  }

  Future<Directory> _resolveDir() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _directory().timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Retry — by now startup has likely progressed past the first frame.
      }
    }
    return _directory();
  }
}

/// Current log file, under the app documents directory.
const String kDiagnosticsLogFileName = 'diagnostics.log';

/// The rotated-out previous generation.
const String kDiagnosticsLogPreviousFileName = 'diagnostics.1.log';

/// Rotation threshold — the log holds at most ~2× this across both files.
const int kDiagnosticsLogMaxBytes = 64 * 1024;

/// Stack frames kept per entry; deep async chains add nothing diagnostic.
const int kDiagnosticsMaxStackLines = 12;

/// Cap on one exception's `toString` (a drift error can embed whole rows).
const int kDiagnosticsMaxErrorChars = 2000;

/// Per-process cap so an error storm (e.g. a throw on every frame) cannot
/// loop the ring buffer and evict the entries that explain the storm.
const int kDiagnosticsMaxRecordsPerRun = 500;

/// Installs the global error hooks (#107): every [FlutterError.reportError]
/// lands in [log] (and still reaches the previous handler — console dump in
/// debug, logcat in release), and unhandled async errors are routed into the
/// same funnel instead of being lost. Call once, before `runApp`.
void installDiagnosticsHooks(DiagnosticsLog log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    log.recordFlutterError(details);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'async',
        context: ErrorSummary('unhandled asynchronous error'),
      ),
    );
    return true;
  };
}
