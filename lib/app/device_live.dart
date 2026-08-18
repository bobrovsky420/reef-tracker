/// Feature-layer live state shared by Devices and Wall.
///
/// Lifecycle flags belong here, outside protocol DTOs and the pure integration
/// registry. Screens keep one [DeviceLiveState] map keyed by device identity;
/// the small vendor views at the bottom are adapters for family-owned cards.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ap_device_link.dart';
import '../data/ap_protocol.dart';
import '../data/database.dart';
import '../data/device_integrations.dart';
import '../data/rb_device_link.dart';
import '../data/rf_device_link.dart';
import '../data/rf_protocol.dart';
import 'providers.dart';

class DeviceLiveState {
  const DeviceLiveState({this.loading = false, this.result});

  /// Starts a read without discarding the last successful payload. Family
  /// cards still render their established loading treatment, while a failed
  /// result can retain the payload for Wall and subsequent saves.
  factory DeviceLiveState.loadingFrom(DeviceLiveState? previous) =>
      DeviceLiveState(loading: true, result: previous?.result);

  factory DeviceLiveState.completed(
    DeviceReadResult result, {
    DeviceLiveState? previous,
  }) => DeviceLiveState(result: result.retainPayloadFrom(previous?.result));

  final bool loading;
  final DeviceReadResult? result;

  DeviceReadPayload? get payload => result?.payload;
  DeviceReadFailure? get failure => result?.failure;

  RfLive get rf => RfLive.fromState(this);
  RbLive get rb => RbLive.fromState(this);
  ApLive get apex => ApLive.fromState(this);
}

class RfLive {
  const RfLive({this.loading = false, this.snapshot, this.error});

  factory RfLive.fromResult(DeviceReadResult result) => RfLive(
    snapshot: result.payloadAs<RfReadPayload>()?.snapshot,
    error: switch (result.failure?.cause) {
      final RfLinkError error => error,
      _ => null,
    },
  );

  factory RfLive.fromState(DeviceLiveState state) => RfLive(
    loading: state.loading,
    snapshot: state.result?.payloadAs<RfReadPayload>()?.snapshot,
    error: switch (state.failure?.cause) {
      final RfLinkError error => error,
      _ => null,
    },
  );

  final bool loading;
  final RfSnapshot? snapshot;
  final RfLinkError? error;
}

class RbLive {
  const RbLive({this.loading = false, this.snapshot, this.error});

  factory RbLive.fromResult(DeviceReadResult result) => RbLive(
    snapshot: result.payloadAs<RbReadPayload>()?.snapshot,
    error: switch (result.failure?.cause) {
      final RbLinkError error => error,
      _ => null,
    },
  );

  factory RbLive.fromState(DeviceLiveState state) => RbLive(
    loading: state.loading,
    snapshot: state.result?.payloadAs<RbReadPayload>()?.snapshot,
    error: switch (state.failure?.cause) {
      final RbLinkError error => error,
      _ => null,
    },
  );

  final bool loading;
  final RbSnapshot? snapshot;
  final RbLinkError? error;
}

class ApLive {
  const ApLive({this.loading = false, this.status, this.error});

  factory ApLive.fromResult(DeviceReadResult result) => ApLive(
    status: result.payloadAs<ApReadPayload>()?.status,
    error: switch (result.failure?.cause) {
      final ApLinkError error => error,
      _ => null,
    },
  );

  factory ApLive.fromState(DeviceLiveState state) => ApLive(
    loading: state.loading,
    status: state.result?.payloadAs<ApReadPayload>()?.status,
    error: switch (state.failure?.cause) {
      final ApLinkError error => error,
      _ => null,
    },
  );

  final bool loading;
  final ApStatus? status;
  final ApLinkError? error;
}

/// The only provider-aware read entry point used by feature screens.
Future<DeviceReadResult> readRegisteredDevice(
  WidgetRef ref,
  DeviceRecord device,
) => ref.read(deviceIntegrationRegistryProvider).read(device);
