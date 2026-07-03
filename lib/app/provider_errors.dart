import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Surfaces provider failures instead of letting them masquerade as "no data"
/// (#21).
///
/// The tank-scoped stream providers fall back to empty lists in their
/// consumers (`.value ?? const []`), so a drift query failure — corrupt
/// database, failed migration — would otherwise render as an empty tank with
/// nothing logged. [providerDidFail] fires for both build-time throws and
/// error emissions from a provider's `Stream`/`Future`, so one hook covers
/// every async failure path.
///
/// Every failure is reported to [FlutterError] (console in debug, crash
/// reporting hooks in release). [showError] — the user-visible warning — is
/// rate-limited by [throttle]: a single broken query cascades through several
/// derived providers and is retried automatically by riverpod, and one
/// warning covers all of them.
final class ProviderErrorObserver extends ProviderObserver {
  ProviderErrorObserver({
    required this.showError,
    this.throttle = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Asks the UI shell to warn the user that data failed to load.
  final void Function() showError;

  /// Minimum gap between two [showError] calls.
  final Duration throttle;

  /// Injectable clock so tests can step time across the throttle window.
  final DateTime Function() _now;

  DateTime? _lastShownAt;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'providers',
        context: ErrorSummary('provider ${context.provider} failed'),
      ),
    );
    final now = _now();
    final last = _lastShownAt;
    if (last != null && now.difference(last) < throttle) return;
    _lastShownAt = now;
    showError();
  }
}
