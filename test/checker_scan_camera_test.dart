import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/scan/checker_scan_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

import 'fakes/fake_camera_platform.dart';

/// The camera-scan screen's controller lifecycle (#77). The screen opens the
/// camera from four places — first frame, Rescan, retry-after-error, and the
/// `resumed` lifecycle callback — so "start while a start is already running"
/// is reachable by ordinary taps on a slow phone, and used to leave a second
/// controller alive with its image stream still feeding the decoder.
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
}
