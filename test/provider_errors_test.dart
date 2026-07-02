import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/provider_errors.dart';

void main() {
  // Captures FlutterError reports so the tests can assert on them without the
  // default handler failing the test.
  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? previousOnError;

  setUp(() {
    reported = [];
    previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
  });

  ProviderContainer containerWith(ProviderErrorObserver observer) {
    final container = ProviderContainer(
      observers: [observer],
      // Disable riverpod's automatic retry so a failing provider doesn't
      // leave pending timers behind in the test.
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a stream provider error is logged and surfaced', () async {
    var shown = 0;
    final observer = ProviderErrorObserver(showError: () => shown++);
    final container = containerWith(observer);

    final failing = StreamProvider<int>((ref) => Stream.error('boom'));
    container.listen(failing, (_, _) {});
    await container.read(failing.future).then((_) => 0, onError: (_) => 0);

    expect(shown, 1);
    expect(reported, hasLength(1));
    expect(reported.single.exception, 'boom');
  });

  test('failures within the throttle window surface only once', () async {
    var shown = 0;
    var now = DateTime(2026, 1, 1);
    final observer = ProviderErrorObserver(
      showError: () => shown++,
      throttle: const Duration(minutes: 1),
      now: () => now,
    );
    final container = containerWith(observer);

    Future<void> fail() async {
      final failing = StreamProvider<int>((ref) => Stream.error('boom'));
      container.listen(failing, (_, _) {});
      await container.read(failing.future).then((_) => 0, onError: (_) => 0);
    }

    await fail();
    await fail(); // A second provider failing right after: same root cause.
    expect(shown, 1);
    expect(reported, hasLength(2), reason: 'every failure is still logged');

    now = now.add(const Duration(minutes: 2));
    await fail();
    expect(shown, 2, reason: 'a failure past the throttle surfaces again');
  });
}
