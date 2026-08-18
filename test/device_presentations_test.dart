import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/device_vendors.dart';
import 'package:reeftracker/features/devices/device_presentations.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';

void main() {
  test('presentation registry is complete and follows integration order', () {
    expect(
      devicePresentationRegistry.values.map((value) => value.kind),
      kDeviceKinds,
    );
    expect(
      devicePresentationRegistry.of(DeviceKind.reefFactory).icon,
      Icons.sensors,
    );
    expect(
      devicePresentationRegistry.of(DeviceKind.reefBeat).icon,
      Icons.water_drop_outlined,
    );
    expect(
      devicePresentationRegistry.of(DeviceKind.apex).icon,
      Icons.hub_outlined,
    );
    expect(
      devicePresentationRegistry.of(DeviceKind.hanna).icon,
      Icons.bluetooth,
    );
    expect(
      deviceVendorIcon('future-controller'),
      Icons.device_unknown_outlined,
    );
  });

  test('missing and duplicate presentation registrations are rejected', () {
    expect(
      () => DevicePresentationRegistry(const [HannaDevicePresentation()]),
      throwsArgumentError,
    );
    expect(
      () => DevicePresentationRegistry(const [
        RfDevicePresentation(),
        RfDevicePresentation(),
      ]),
      throwsArgumentError,
    );
  });
}
