import 'dart:async';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory stand-in for the camera plugin, enough of it to drive
/// `CameraController.initialize()` + `startImageStream()` under `flutter test`.
///
/// Its point is bookkeeping, not fidelity: [liveCameras] and [activeStreams]
/// are what a leak looks like from the outside. The real plugin holds the
/// hardware open behind an undisposed controller, and nothing on screen reveals
/// it — see #77, where two overlapping `_startCamera()` calls each built a
/// controller and only the second stayed reachable to dispose.
///
/// [initializeGate] is the seam that makes the race reproducible: hold it, and
/// a start parks exactly where the real `initialize()` takes visible time on a
/// slow device.
class FakeCameraPlatform extends CameraPlatform
    with MockPlatformInterfaceMixin {
  int _nextId = 1;

  /// Camera ids created and not yet disposed — the scan screen must never hold
  /// more than one.
  final Set<int> liveCameras = <int>{};

  /// Every id ever handed out, in order, so a test can tell "started twice"
  /// from "started once".
  final List<int> createdCameras = <int>[];

  /// Ids with a frame-stream listener attached and not yet cancelled. This is
  /// the expensive half of the leak: a stream still delivering frames to the
  /// decoder, not merely an object still allocated.
  final Set<int> activeStreams = <int>{};

  /// When non-null, [initializeCamera] parks on this until the test completes
  /// it — the window in which a second `_startCamera()` can slip in.
  Completer<void>? initializeGate;

  /// When true, [onStreamedFrameAvailable] refuses the way a plugin that
  /// cannot deliver frames does. This is the one failure that leaves the scan
  /// screen showing an error *while* holding a live, initialized camera —
  /// `startImageStream` is the last step, after the controller is assigned —
  /// so the retry it offers has to release that camera first (#77).
  bool streamThrows = false;

  final _initialized = StreamController<CameraInitializedEvent>.broadcast();
  final _frames = <int, StreamController<CameraImageData>>{};
  // `CameraController.initialize()` awaits `onCameraError(id).first`, so this
  // must be a stream that stays open and never emits — `Stream.empty()` closes
  // immediately and that `first` throws "Bad state: No element".
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'fake-back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    final id = _nextId++;
    createdCameras.add(id);
    liveCameras.add(id);
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (initializeGate != null) await initializeGate!.future;
    _initialized.add(
      CameraInitializedEvent(
        cameraId,
        1280,
        720,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream.where((e) => e.cameraId == cameraId);

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      _errors.stream.where((e) => e.cameraId == cameraId);

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    if (streamThrows) {
      throw PlatformException(
        code: 'streamFailed',
        message: 'fake: image stream refused',
      );
    }
    return _frames
        .putIfAbsent(
          cameraId,
          () => StreamController<CameraImageData>(
            onListen: () => activeStreams.add(cameraId),
            onCancel: () => activeStreams.remove(cameraId),
          ),
        )
        .stream;
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;
  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}
  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {}
  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async {
    liveCameras.remove(cameraId);
    activeStreams.remove(cameraId);
    await _frames.remove(cameraId)?.close();
  }

  /// Releases anything the test left open (the screen disposes its own camera;
  /// this covers a gate never completed).
  ///
  /// [_initialized] and [_errors] are deliberately *not* closed: a controller
  /// abandoned mid-initialize still holds a pending `.first` on both, and
  /// closing an empty stream completes that future with "Bad state: No
  /// element" — after the test body, where it reads as a failure with no
  /// stack of its own. Nothing schedules on them, so leaving them open costs
  /// the test nothing.
  Future<void> close() async {
    for (final c in _frames.values) {
      await c.close();
    }
  }
}
