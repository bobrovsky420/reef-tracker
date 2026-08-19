/// Flutter-facing descriptors for the registered device integrations.
///
/// The data registry owns reads, saves and cleanup. This parallel feature-layer
/// registry owns the things that cannot live in data code: localized labels,
/// icons, navigation, add flows and family-owned card sections. The Devices
/// screen only selects a descriptor; it does not dispatch on device families.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/device_live.dart';
import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/device_integrations.dart';
import '../../domain/device_vendors.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../apex/apex_screen.dart';
import '../reefbeat/reefbeat_screen.dart';
import '../reeffactory/reeffactory_screen.dart';
import 'hanna_device_section.dart';

typedef DeviceSeedCallback =
    void Function(String identifier, DeviceReadPayload payload);
typedef DeviceRemovedCallback = Future<void> Function(DeviceRecord device);
typedef DeviceSaveCallback = void Function(DeviceRecord device);
typedef DeviceRefreshCallback = void Function(DeviceRecord device);

abstract interface class DevicePresentationDescriptor {
  DeviceKind get kind;
  IconData get icon;

  String label(AppLocalizations l);
  String disclaimer(AppLocalizations l);
  bool addAvailable(WidgetRef ref);

  Future<void> add(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  });

  Widget buildSection({
    required List<DeviceRecord> devices,
    required Map<String, DeviceLiveState> live,
    required bool saving,
    required DeviceSaveCallback onSave,
    required DeviceRemovedCallback onRemoved,
    required DeviceRefreshCallback onRefresh,
  });
}

abstract class _LanPresentation implements DevicePresentationDescriptor {
  const _LanPresentation();

  Future<void> addEntitled(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  });

  @override
  bool addAvailable(WidgetRef ref) => true;

  @override
  Future<void> add(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  }) async {
    if (!await requestProCapability(
          context,
          ref,
          ProCapabilityBoundary.connectedDeviceLiveIo,
        ) ||
        !context.mounted) {
      return;
    }
    await addEntitled(context, ref, onSeed: onSeed);
  }
}

class RfDevicePresentation extends _LanPresentation {
  const RfDevicePresentation();

  @override
  DeviceKind get kind => DeviceKind.reefFactory;

  @override
  IconData get icon => Icons.sensors;

  @override
  String label(AppLocalizations l) => l.deviceVendorName(kind.id);

  @override
  String disclaimer(AppLocalizations l) => l.reefFactoryDisclaimer;

  @override
  Future<void> addEntitled(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  }) => showRfAddFlow(
    context,
    ref,
    onSeed: (identifier, snapshot) =>
        onSeed(identifier, RfReadPayload(snapshot)),
  );

  @override
  Widget buildSection({
    required List<DeviceRecord> devices,
    required Map<String, DeviceLiveState> live,
    required bool saving,
    required DeviceSaveCallback onSave,
    required DeviceRemovedCallback onRemoved,
    required DeviceRefreshCallback onRefresh,
  }) => RfDeviceSection(
    devices: devices,
    live: {
      for (final d in devices)
        d.identifier: live[d.identifier]?.rf ?? const RfLive(),
    },
    onSave: saving ? null : (device, _) => onSave(device),
    onRemoved: onRemoved,
  );
}

class RbDevicePresentation extends _LanPresentation {
  const RbDevicePresentation();

  @override
  DeviceKind get kind => DeviceKind.reefBeat;

  @override
  IconData get icon => Icons.water_drop_outlined;

  @override
  String label(AppLocalizations l) => l.deviceVendorName(kind.id);

  @override
  String disclaimer(AppLocalizations l) => l.reefBeatDisclaimer;

  @override
  Future<void> addEntitled(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  }) => showRbAddFlow(
    context,
    ref,
    onSeed: (identifier, snapshot) =>
        onSeed(identifier, RbReadPayload(snapshot)),
    onAdded: () {},
  );

  @override
  Widget buildSection({
    required List<DeviceRecord> devices,
    required Map<String, DeviceLiveState> live,
    required bool saving,
    required DeviceSaveCallback onSave,
    required DeviceRemovedCallback onRemoved,
    required DeviceRefreshCallback onRefresh,
  }) => RbDeviceSection(
    devices: devices,
    live: {
      for (final d in devices)
        d.identifier: live[d.identifier]?.rb ?? const RbLive(),
    },
    onSave: saving ? null : (device, _) => onSave(device),
    onRemoved: onRemoved,
  );
}

class ApDevicePresentation extends _LanPresentation {
  const ApDevicePresentation();

  @override
  DeviceKind get kind => DeviceKind.apex;

  @override
  IconData get icon => Icons.hub_outlined;

  @override
  String label(AppLocalizations l) => l.deviceVendorName(kind.id);

  @override
  String disclaimer(AppLocalizations l) => l.apexDisclaimer;

  @override
  Future<void> addEntitled(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  }) => showApAddFlow(
    context,
    ref,
    onSeed: (identifier, status) => onSeed(identifier, ApReadPayload(status)),
  );

  @override
  Widget buildSection({
    required List<DeviceRecord> devices,
    required Map<String, DeviceLiveState> live,
    required bool saving,
    required DeviceSaveCallback onSave,
    required DeviceRemovedCallback onRemoved,
    required DeviceRefreshCallback onRefresh,
  }) => ApDeviceSection(
    devices: devices,
    live: {
      for (final d in devices)
        d.identifier: live[d.identifier]?.apex ?? const ApLive(),
    },
    onSave: saving ? null : (device, _) => onSave(device),
    onRemoved: onRemoved,
    onRefreshRequested: onRefresh,
  );
}

class HannaDevicePresentation implements DevicePresentationDescriptor {
  const HannaDevicePresentation();

  @override
  DeviceKind get kind => DeviceKind.hanna;

  @override
  IconData get icon => Icons.bluetooth;

  @override
  String label(AppLocalizations l) => l.deviceVendorName(kind.id);

  @override
  String disclaimer(AppLocalizations l) => l.devicesHannaDisclaimer;

  @override
  bool addAvailable(WidgetRef ref) =>
      (ref.read(experimentalEnabledProvider).value ?? false) &&
      (ref.read(hannaBleSupportedProvider).value ?? true);

  @override
  Future<void> add(
    BuildContext context,
    WidgetRef ref, {
    required DeviceSeedCallback onSeed,
  }) => runProCapabilityGated(
    context,
    ref,
    ProCapabilityBoundary.hannaConnectRoute,
    () => context.push('/hanna/measure'),
  );

  @override
  Widget buildSection({
    required List<DeviceRecord> devices,
    required Map<String, DeviceLiveState> live,
    required bool saving,
    required DeviceSaveCallback onSave,
    required DeviceRemovedCallback onRemoved,
    required DeviceRefreshCallback onRefresh,
  }) => HannaDeviceSection(devices: devices, onRemoved: onRemoved);
}

class DevicePresentationRegistry {
  DevicePresentationRegistry(Iterable<DevicePresentationDescriptor> values)
    : _byKind = {} {
    for (final value in values) {
      if (_byKind.containsKey(value.kind)) {
        throw ArgumentError('Duplicate device presentation: ${value.kind}');
      }
      _byKind[value.kind] = value;
    }
    final missing = [
      for (final kind in kDeviceKinds)
        if (!_byKind.containsKey(kind)) kind,
    ];
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing device presentations: $missing');
    }
  }

  final Map<DeviceKind, DevicePresentationDescriptor> _byKind;

  List<DevicePresentationDescriptor> get values => [
    for (final kind in kDeviceKinds) _byKind[kind]!,
  ];

  DevicePresentationDescriptor of(DeviceKind kind) => _byKind[kind]!;

  DevicePresentationDescriptor? forId(String kindId) {
    final kind = DeviceKind.tryParse(kindId);
    return kind == null ? null : _byKind[kind];
  }
}

final devicePresentationRegistry = DevicePresentationRegistry(const [
  RfDevicePresentation(),
  RbDevicePresentation(),
  ApDevicePresentation(),
  HannaDevicePresentation(),
]);
