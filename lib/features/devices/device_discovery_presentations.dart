/// Flutter-facing registry for LAN discovery results.
///
/// The transport pipeline reports canonical [DeviceKind] values. This layer
/// owns icons and persistence commands, keeping both Flutter and database
/// writes out of the pure-Dart probe contributors.
library;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/lan_discovery.dart';
import '../../data/rb_protocol.dart';
import '../../domain/device_vendors.dart';

abstract interface class DeviceDiscoveryPresentation {
  DeviceKind get kind;

  IconData iconFor(DiscoveredDevice device);

  Future<void> add(
    AppDatabase db,
    DiscoveredDevice device, {
    required int? tankId,
  });
}

class ReefFactoryDiscoveryPresentation implements DeviceDiscoveryPresentation {
  const ReefFactoryDiscoveryPresentation();

  @override
  DeviceKind get kind => DeviceKind.reefFactory;

  @override
  IconData iconFor(DiscoveredDevice device) => Icons.sensors;

  @override
  Future<void> add(
    AppDatabase db,
    DiscoveredDevice device, {
    required int? tankId,
  }) => db.upsertReefFactoryDevice(
    identifier: device.identifier,
    model: device.modelCode,
    address: device.address,
    name: device.modelDisplayName,
    tankId: tankId,
  );
}

class ReefBeatDiscoveryPresentation implements DeviceDiscoveryPresentation {
  const ReefBeatDiscoveryPresentation();

  @override
  DeviceKind get kind => DeviceKind.reefBeat;

  @override
  IconData iconFor(DiscoveredDevice device) => switch (device.hwType) {
    kRbDosingHwType => Icons.science_outlined,
    kRbAtoHwType => Icons.opacity,
    kRbMatHwType => Icons.filter_alt_outlined,
    kRbRunHwType => Icons.cyclone,
    kRbLightsHwType => Icons.lightbulb_outline,
    kRbWaveHwType => Icons.waves,
    kRbControlHwType => Icons.sensors_outlined,
    _ => Icons.device_unknown,
  };

  @override
  Future<void> add(
    AppDatabase db,
    DiscoveredDevice device, {
    required int? tankId,
  }) => db.upsertReefBeatDevice(
    identifier: device.identifier,
    model: device.modelCode,
    address: device.address,
    name: device.modelDisplayName,
    tankId: tankId,
  );
}

class DeviceDiscoveryPresentationRegistry {
  DeviceDiscoveryPresentationRegistry(
    Iterable<DeviceDiscoveryPresentation> presentations,
  ) : _byKind = {} {
    for (final presentation in presentations) {
      if (_byKind.containsKey(presentation.kind)) {
        throw ArgumentError(
          'Duplicate discovery presentation: ${presentation.kind}',
        );
      }
      _byKind[presentation.kind] = presentation;
    }
  }

  final Map<DeviceKind, DeviceDiscoveryPresentation> _byKind;

  List<DeviceKind> get kinds => List.unmodifiable(_byKind.keys);

  DeviceDiscoveryPresentation of(DeviceKind kind) {
    final presentation = _byKind[kind];
    if (presentation == null) {
      throw ArgumentError('Device kind is not LAN-discoverable: $kind');
    }
    return presentation;
  }
}

final deviceDiscoveryPresentations = DeviceDiscoveryPresentationRegistry(const [
  ReefBeatDiscoveryPresentation(),
  ReefFactoryDiscoveryPresentation(),
]);
