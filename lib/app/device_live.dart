/// Feature-layer compatibility state for device cards and Wall.
///
/// Lifecycle flags belong here, outside protocol DTOs and the pure integration
/// registry. Phase 2 can replace the three maps with one normalized map without
/// making vendor widgets depend directly on [DeviceReadResult].
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

class RfLive {
  const RfLive({this.loading = false, this.snapshot, this.error});

  factory RfLive.fromResult(DeviceReadResult result) => RfLive(
    snapshot: result.payloadAs<RfReadPayload>()?.snapshot,
    error: switch (result.failure?.cause) {
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

  final bool loading;
  final ApStatus? status;
  final ApLinkError? error;
}

/// The only provider-aware read entry point used by feature screens.
Future<DeviceReadResult> readRegisteredDevice(
  WidgetRef ref,
  DeviceRecord device,
) => ref.read(deviceIntegrationRegistryProvider).read(device);
