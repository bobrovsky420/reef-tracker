import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/seven_segment.dart';
import 'package:reeftracker/features/scan/checker_scan_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_camera_platform.dart';

/// The camera-scan screen's controller lifecycle (#77). The screen opens the
/// camera from five places — first frame, Rescan, retry-after-error, the
/// `resumed` lifecycle callback, and back-from-confirm (the PopScope handler,
/// #116a) — so "start while a start is already running" is reachable by
/// ordinary taps on a slow phone, and used to leave a second controller alive
/// with its image stream still feeding the decoder.
void main() {
  late FakeCameraPlatform camera;
  late AppDatabase db;

  setUp(() {
    camera = FakeCameraPlatform();
    CameraPlatform.instance = camera;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await camera.close();
    await db.close();
  });

  Future<void> pumpScan(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CheckerScanScreen(),
        ),
      ),
    );
    // The screen starts the camera from a post-frame callback.
    await tester.pump();
  }

  /// Unmounts inside the test body so the screen's dispose runs (and its
  /// camera is released) before the assertions on teardown state.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('one start opens exactly one camera and one frame stream', (
    tester,
  ) async {
    await pumpScan(tester);
    await tester.pump();

    expect(camera.createdCameras, hasLength(1));
    expect(camera.liveCameras, hasLength(1));
    expect(camera.activeStreams, hasLength(1));

    await unmount(tester);
  });

  testWidgets(
    'a resume while the first start is still initializing does not open a '
    'second camera',
    (tester) async {
      // Park the first start where the real plugin takes visible time.
      camera.initializeGate = Completer<void>();
      await pumpScan(tester);
      await tester.pump();
      expect(camera.createdCameras, hasLength(1), reason: 'start #1 is parked');

      // The lifecycle round-trip #77 names: `inactive` stops (nothing is open
      // yet — the first start has not assigned its controller), then `resumed`
      // sees a null controller and starts again, mid-flight.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      camera.initializeGate!.complete();
      await tester.pump();
      await tester.pump();

      // Before the fix: two controllers, the first unreachable and never
      // disposed, both streaming frames to the decoder.
      expect(camera.createdCameras, hasLength(1));
      expect(camera.liveCameras, hasLength(1));
      expect(camera.activeStreams, hasLength(1));

      await unmount(tester);
    },
  );

  testWidgets('retry after a failed start releases the camera it left open', (
    tester,
  ) async {
    // `startImageStream` is the last step of a start, so a failure there
    // leaves the error UI on screen *with* a live controller assigned — the
    // one reachable path where `_startCamera` runs against a camera that is
    // already open, and what the `await _stopCamera()` at its top is for.
    camera.streamThrows = true;
    await pumpScan(tester);
    await tester.pump();

    expect(camera.liveCameras, hasLength(1), reason: 'held despite the error');
    expect(camera.activeStreams, isEmpty);
    expect(find.text('Try again'), findsOneWidget);

    camera.streamThrows = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    // A second camera was opened — but the first was released, not stranded.
    expect(camera.createdCameras, hasLength(2));
    expect(camera.liveCameras, hasLength(1));
    expect(camera.liveCameras, contains(camera.createdCameras.last));
    expect(camera.activeStreams, hasLength(1));

    await unmount(tester);
  });

  testWidgets('leaving the screen releases the camera', (tester) async {
    await pumpScan(tester);
    await tester.pump();
    expect(camera.liveCameras, hasLength(1));

    await unmount(tester);

    expect(camera.liveCameras, isEmpty);
    expect(camera.activeStreams, isEmpty);
  });

  testWidgets('back from the confirm step restarts the viewfinder instead of '
      'leaving; back from the viewfinder pops (#116a)', (tester) async {
    // The screen must sit on a pushed route so there is something to pop to.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('base')),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const CheckerScanScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(camera.createdCameras, hasLength(1));

    // Enter the confirm phase the way an accepted vote does.
    final state = tester.state<State<CheckerScanScreen>>(
      find.byType(CheckerScanScreen),
    );
    (state as dynamic).debugEnterConfirmPhase(
      const SevenSegmentReading('0.30'),
    );
    // The camera stop is deferred (`Future(_stopCamera)`) and disposes
    // asynchronously — give the event loop a few turns.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(camera.liveCameras, isEmpty, reason: 'confirm releases the camera');

    // System back from confirm: the route must NOT pop — the PopScope
    // handler (the fifth _startCamera caller) returns to the viewfinder.
    expect(await navigator.maybePop(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CheckerScanScreen), findsOneWidget);
    expect(camera.createdCameras, hasLength(2), reason: 'camera restarted');
    expect(camera.liveCameras, hasLength(1));
    expect(camera.activeStreams, hasLength(1));

    // System back from the viewfinder leaves the flow. Bounded pumps, not
    // pumpAndSettle: the outgoing viewfinder can host a live animation
    // during the route transition, which would keep pumpAndSettle spinning.
    expect(await navigator.maybePop(), isTrue);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(CheckerScanScreen), findsNothing);
    expect(find.text('base'), findsOneWidget);
    expect(camera.liveCameras, isEmpty);

    // In-body unmount: the confirm view watched drift streams, whose
    // zero-duration close timers must flush before the binding's
    // pending-timer invariant runs (teardown-time is too late).
    await unmount(tester);
    await tester.pump(const Duration(seconds: 1));
  });
}
