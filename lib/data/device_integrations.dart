/// Typed application boundary for connected hardware.
///
/// Screens ask this registry to read a persisted device and receive one
/// normalized outcome. Vendor transports, error enums, snapshot shapes, save
/// conversion, and optional environment sources remain behind their adapters.
/// The file is pure Dart and deliberately owns no widgets, localization, or
/// navigation.
library;

import '../domain/device_vendors.dart';
import 'ap_device_link.dart';
import 'ap_measurements.dart';
import 'ap_protocol.dart';
import 'database.dart';
import 'device_measurements.dart';
import 'device_secrets.dart';
import 'environment_sources.dart';
import 'rb_device_link.dart';
import 'rb_family_handlers.dart';
import 'rf_device_link.dart';
import 'rf_measurements.dart';
import 'rf_protocol.dart';
import 'wall_sources.dart';

typedef DeviceSeenRecorder = Future<void> Function(String identifier);
typedef DeviceModelRecorder = Future<void> Function(int id, String model);

/// Error categories every integration can express without erasing its native
/// diagnostic. [DeviceReadFailure.cause] retains the vendor enum for existing
/// localized UI and detailed tests.
enum DeviceReadFailureKind {
  missingAddress,
  authenticationRequired,
  unreachable,
  timeout,
  unsupportedModel,
  protocol,
  notRefreshable,
  unsupportedKind,
}

class DeviceReadFailure {
  const DeviceReadFailure(this.kind, {this.cause});

  final DeviceReadFailureKind kind;
  final Object? cause;
}

/// A successful vendor payload. The sealed wrappers make downcasts exhaustive
/// at the compatibility/UI boundary without making protocol DTOs inherit from
/// an application type.
sealed class DeviceReadPayload {
  const DeviceReadPayload();

  DeviceKind get kind;
}

class RfReadPayload extends DeviceReadPayload {
  const RfReadPayload(this.snapshot);

  final RfSnapshot snapshot;

  @override
  DeviceKind get kind => DeviceKind.reefFactory;
}

class RbReadPayload extends DeviceReadPayload {
  const RbReadPayload(this.snapshot);

  final RbSnapshot snapshot;

  @override
  DeviceKind get kind => DeviceKind.reefBeat;
}

class ApReadPayload extends DeviceReadPayload {
  const ApReadPayload(this.status);

  final ApStatus status;

  @override
  DeviceKind get kind => DeviceKind.apex;
}

/// One normalized read outcome. A failed refresh may carry a retained
/// [payload] from an earlier success; [retainPayloadFrom] creates that state
/// explicitly so callers never have to discard useful last-known values.
class DeviceReadResult {
  const DeviceReadResult({
    required this.kindId,
    required this.kind,
    this.payload,
    this.failure,
  });

  factory DeviceReadResult.success(DeviceKind kind, DeviceReadPayload payload) {
    assert(payload.kind == kind);
    return DeviceReadResult(kindId: kind.id, kind: kind, payload: payload);
  }

  factory DeviceReadResult.failed(DeviceKind kind, DeviceReadFailure failure) =>
      DeviceReadResult(kindId: kind.id, kind: kind, failure: failure);

  factory DeviceReadResult.unsupported(String kindId) => DeviceReadResult(
    kindId: kindId,
    kind: null,
    failure: const DeviceReadFailure(DeviceReadFailureKind.unsupportedKind),
  );

  final String kindId;
  final DeviceKind? kind;
  final DeviceReadPayload? payload;
  final DeviceReadFailure? failure;

  bool get hasFreshPayload => payload != null && failure == null;

  T? payloadAs<T extends DeviceReadPayload>() {
    final value = payload;
    return value is T ? value : null;
  }

  DeviceReadResult retainPayloadFrom(DeviceReadResult? previous) {
    if (payload != null ||
        failure == null ||
        previous?.payload == null ||
        previous!.kind != kind) {
      return this;
    }
    return DeviceReadResult(
      kindId: kindId,
      kind: kind,
      payload: previous.payload,
      failure: failure,
    );
  }
}

/// One integration registered at the composition root. Implementations own
/// transport reads and conversion into application values, not widgets.
abstract interface class DeviceIntegration {
  DeviceKind get kind;

  DeviceCapabilities get capabilities => kind.capabilities;

  bool savesModel(String? model);

  Future<DeviceReadResult> read(DeviceRecord device);

  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  );

  EnvironmentSource? environmentSource(DeviceRecord device);

  List<String> knownWallParameters(DeviceRecord device);

  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  );

  /// Removes integration-owned sidecars after an inventory row is deleted.
  /// Most integrations own none; Apex uses this hook for its password.
  Future<void> cleanup(DeviceRecord device);
}

class RfDeviceIntegration implements DeviceIntegration {
  const RfDeviceIntegration({required this.link, required this.touchSeen});

  final RfDeviceLink link;
  final DeviceSeenRecorder touchSeen;

  @override
  DeviceKind get kind => DeviceKind.reefFactory;

  @override
  DeviceCapabilities get capabilities => kind.capabilities;

  @override
  bool savesModel(String? model) => true;

  @override
  Future<DeviceReadResult> read(DeviceRecord device) async {
    final address = device.address;
    if (address == null || address.isEmpty) {
      return DeviceReadResult.failed(
        kind,
        const DeviceReadFailure(DeviceReadFailureKind.missingAddress),
      );
    }
    try {
      final snapshot = await link.readOnce(address);
      await touchSeen(device.identifier);
      return DeviceReadResult.success(kind, RfReadPayload(snapshot));
    } on RfLinkException catch (error) {
      return DeviceReadResult.failed(
        kind,
        DeviceReadFailure(_rfFailure(error.error), cause: error.error),
      );
    }
  }

  @override
  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  ) {
    final snapshot = result.payloadAs<RfReadPayload>()?.snapshot;
    if (snapshot == null) return const [];
    return rfValuesToSave(device, snapshot, peerDevices);
  }

  @override
  EnvironmentSource? environmentSource(DeviceRecord device) {
    final address = device.address;
    return address == null || address.isEmpty
        ? null
        : RfEnvironmentSource(device, link);
  }

  @override
  List<String> knownWallParameters(DeviceRecord device) =>
      wallKnownRfParams(model: device.model, identifier: device.identifier);

  @override
  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  ) {
    final snapshot = result.payloadAs<RfReadPayload>()?.snapshot;
    return snapshot == null ? null : wallRfSnapshot(snapshot);
  }

  @override
  Future<void> cleanup(DeviceRecord device) async {}
}

class RbDeviceIntegration implements DeviceIntegration {
  RbDeviceIntegration({
    required this.link,
    required this.touchSeen,
    required this.updateModel,
    RbFamilyHandlerRegistry? families,
  }) : families = families ?? rbFamilyHandlers;

  final RbDeviceLink link;
  final DeviceSeenRecorder touchSeen;
  final DeviceModelRecorder updateModel;
  final RbFamilyHandlerRegistry families;

  @override
  DeviceKind get kind => DeviceKind.reefBeat;

  @override
  DeviceCapabilities get capabilities => kind.capabilities;

  @override
  bool savesModel(String? model) => families.savesModel(model);

  @override
  Future<DeviceReadResult> read(DeviceRecord device) async {
    final address = device.address;
    if (address == null || address.isEmpty) {
      return DeviceReadResult.failed(
        kind,
        const DeviceReadFailure(DeviceReadFailureKind.missingAddress),
      );
    }
    try {
      final snapshot = await link.readOnce(address);
      await touchSeen(device.identifier);
      if (snapshot.modelCode != device.model) {
        await updateModel(device.id, snapshot.modelCode);
      }
      return DeviceReadResult.success(kind, RbReadPayload(snapshot));
    } on RbLinkException catch (error) {
      return DeviceReadResult.failed(
        kind,
        DeviceReadFailure(_rbFailure(error.error), cause: error.error),
      );
    }
  }

  @override
  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  ) {
    final snapshot = result.payloadAs<RbReadPayload>()?.snapshot;
    return snapshot == null ? const [] : families.saveCandidates(snapshot);
  }

  @override
  EnvironmentSource? environmentSource(DeviceRecord device) {
    final address = device.address;
    if (!(families
                .forModel(device.model)
                ?.capabilities
                .contributesEnvironment ??
            false) ||
        address == null ||
        address.isEmpty) {
      return null;
    }
    return RbEnvironmentSource(device, link, families: families);
  }

  @override
  List<String> knownWallParameters(DeviceRecord device) => const [];

  @override
  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  ) {
    final snapshot = result.payloadAs<RbReadPayload>()?.snapshot;
    return snapshot == null ? null : families.wallSnapshot(snapshot);
  }

  @override
  Future<void> cleanup(DeviceRecord device) async {}
}

class ApDeviceIntegration implements DeviceIntegration {
  const ApDeviceIntegration({
    required this.link,
    required this.secrets,
    required this.touchSeen,
  });

  final ApDeviceLink link;
  final DeviceSecrets secrets;
  final DeviceSeenRecorder touchSeen;

  @override
  DeviceKind get kind => DeviceKind.apex;

  @override
  DeviceCapabilities get capabilities => kind.capabilities;

  @override
  bool savesModel(String? model) => true;

  @override
  Future<DeviceReadResult> read(DeviceRecord device) async {
    final address = device.address;
    if (address == null || address.isEmpty) {
      return DeviceReadResult.failed(
        kind,
        const DeviceReadFailure(DeviceReadFailureKind.missingAddress),
      );
    }
    final credentials = await apCredentialsOf(secrets, device);
    if (credentials == null) {
      return DeviceReadResult.failed(
        kind,
        const DeviceReadFailure(
          DeviceReadFailureKind.authenticationRequired,
          cause: ApLinkError.auth,
        ),
      );
    }
    try {
      final status = await link.readOnce(address, credentials);
      await touchSeen(device.identifier);
      return DeviceReadResult.success(kind, ApReadPayload(status));
    } on ApLinkException catch (error) {
      return DeviceReadResult.failed(
        kind,
        DeviceReadFailure(_apFailure(error.error), cause: error.error),
      );
    }
  }

  @override
  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  ) {
    final status = result.payloadAs<ApReadPayload>()?.status;
    return status == null ? const [] : apReadingsToSave(status.readings);
  }

  @override
  EnvironmentSource? environmentSource(DeviceRecord device) => null;

  @override
  List<String> knownWallParameters(DeviceRecord device) => const [];

  @override
  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  ) {
    final status = result.payloadAs<ApReadPayload>()?.status;
    return status == null ? null : wallApSnapshot(status);
  }

  @override
  Future<void> cleanup(DeviceRecord device) =>
      secrets.remove(device.identifier);
}

class HannaDeviceIntegration implements DeviceIntegration {
  const HannaDeviceIntegration();

  @override
  DeviceKind get kind => DeviceKind.hanna;

  @override
  DeviceCapabilities get capabilities => kind.capabilities;

  @override
  bool savesModel(String? model) => false;

  @override
  Future<DeviceReadResult> read(DeviceRecord device) async =>
      DeviceReadResult.failed(
        kind,
        const DeviceReadFailure(DeviceReadFailureKind.notRefreshable),
      );

  @override
  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  ) => const [];

  @override
  EnvironmentSource? environmentSource(DeviceRecord device) => null;

  @override
  List<String> knownWallParameters(DeviceRecord device) => const [];

  @override
  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  ) => null;

  @override
  Future<void> cleanup(DeviceRecord device) async {}
}

/// The credentials for a persisted Apex row. The username rides with the row;
/// the password lives in the backup-excluded sidecar. Null means the restored
/// or transferred controller must be signed in again.
Future<ApCredentials?> apCredentialsOf(
  DeviceSecrets secrets,
  DeviceRecord device,
) async {
  final username = device.username;
  if (username == null) return null;
  final password = await secrets.read(device.identifier);
  if (password == null) return null;
  return ApCredentials(username: username, password: password);
}

/// All registered integrations, with safe lookup at the persisted-string
/// boundary. Production composition requires every canonical kind exactly
/// once; this prevents a new enum member from quietly becoming unreadable.
class DeviceIntegrationRegistry {
  DeviceIntegrationRegistry(Iterable<DeviceIntegration> integrations)
    : _byKind = {} {
    for (final integration in integrations) {
      if (_byKind.containsKey(integration.kind)) {
        throw ArgumentError(
          'Duplicate device integration: ${integration.kind}',
        );
      }
      _byKind[integration.kind] = integration;
    }
    final missing = [
      for (final kind in kDeviceKinds)
        if (!_byKind.containsKey(kind)) kind,
    ];
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing device integrations: $missing');
    }
  }

  final Map<DeviceKind, DeviceIntegration> _byKind;

  List<DeviceKind> get registeredKinds => List.unmodifiable(_byKind.keys);

  DeviceIntegration integrationOf(DeviceKind kind) => _byKind[kind]!;

  DeviceIntegration? integrationForId(String kindId) {
    final kind = DeviceKind.tryParse(kindId);
    return kind == null ? null : _byKind[kind];
  }

  bool savesModel(DeviceRecord device) =>
      integrationForId(device.kind)?.savesModel(device.model) ?? false;

  Future<void> cleanup(DeviceRecord device) async {
    await integrationForId(device.kind)?.cleanup(device);
  }

  Future<DeviceReadResult> read(DeviceRecord device) {
    final integration = integrationForId(device.kind);
    return integration == null
        ? Future.value(DeviceReadResult.unsupported(device.kind))
        : integration.read(device);
  }

  List<DeviceMeasurement> valuesToSave(
    DeviceRecord device,
    DeviceReadResult result,
    Iterable<DeviceRecord> peerDevices,
  ) =>
      integrationForId(
        device.kind,
      )?.valuesToSave(device, result, peerDevices) ??
      const [];

  List<String> knownWallParameters(DeviceRecord device) =>
      integrationForId(device.kind)?.knownWallParameters(device) ?? const [];

  WallDeviceSnapshot? wallSnapshot(
    DeviceRecord device,
    DeviceReadResult result,
  ) => integrationForId(device.kind)?.wallSnapshot(device, result);

  /// Environment contributors in the same vendor/card order as Devices.
  List<EnvironmentSource> environmentSourcesForTank({
    required int tankId,
    required List<DeviceKind> vendorOrder,
    required Map<DeviceKind, List<DeviceRecord>> devicesByKind,
  }) {
    final sources = <EnvironmentSource>[];
    for (final kind in vendorOrder) {
      final integration = integrationOf(kind);
      if (!integration.capabilities.contributesEnvironment) continue;
      final devices = [
        for (final device in devicesByKind[kind] ?? const <DeviceRecord>[])
          if (device.tankId == tankId) device,
      ]..sort(_compareDevices);
      for (final device in devices) {
        final source = integration.environmentSource(device);
        if (source != null) sources.add(source);
      }
    }
    return sources;
  }
}

int _compareDevices(DeviceRecord a, DeviceRecord b) {
  final byOrder = a.displayOrder.compareTo(b.displayOrder);
  if (byOrder != 0) return byOrder;
  return deviceDisplayName(
    a,
  ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
}

DeviceReadFailureKind _rfFailure(RfLinkError error) => switch (error) {
  RfLinkError.unreachable => DeviceReadFailureKind.unreachable,
  RfLinkError.timeout => DeviceReadFailureKind.timeout,
  RfLinkError.unsupportedModel => DeviceReadFailureKind.unsupportedModel,
  RfLinkError.protocol => DeviceReadFailureKind.protocol,
};

DeviceReadFailureKind _rbFailure(RbLinkError error) => switch (error) {
  RbLinkError.unreachable => DeviceReadFailureKind.unreachable,
  RbLinkError.timeout => DeviceReadFailureKind.timeout,
  RbLinkError.unsupportedModel => DeviceReadFailureKind.unsupportedModel,
  RbLinkError.protocol => DeviceReadFailureKind.protocol,
};

DeviceReadFailureKind _apFailure(ApLinkError error) => switch (error) {
  ApLinkError.unreachable => DeviceReadFailureKind.unreachable,
  ApLinkError.timeout => DeviceReadFailureKind.timeout,
  ApLinkError.auth => DeviceReadFailureKind.authenticationRequired,
  ApLinkError.protocol => DeviceReadFailureKind.protocol,
};
