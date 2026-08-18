/// Exhaustive ReefBeat family registry.
///
/// Each handler owns the protocol endpoints and decoding for one hardware
/// family together with its model aliases, capabilities, save/environment
/// candidates and normalized Wall contribution.
library;

import '../domain/wall_display.dart';
import 'device_measurements.dart';
import 'rb_measurements.dart';
import 'rb_protocol.dart';
import 'rb_snapshot.dart';
import 'wall_sources.dart';

typedef RbJsonReader = Future<Map<String, Object?>> Function(String path);
typedef RbOptionalJsonReader =
    Future<Map<String, Object?>?> Function(String path);

class RbFamilyReadContext {
  const RbFamilyReadContext({
    required this.info,
    required this.getJson,
    required this.tryGetJson,
  });

  final RbDeviceInfo info;
  final RbJsonReader getJson;
  final RbOptionalJsonReader tryGetJson;
}

class RbFamilyCapabilities {
  const RbFamilyCapabilities({
    this.savesMeasurements = false,
    this.contributesWallReadings = false,
    this.contributesWallStatus = false,
    this.contributesEnvironment = false,
  });

  final bool savesMeasurements;
  final bool contributesWallReadings;
  final bool contributesWallStatus;
  final bool contributesEnvironment;
}

abstract interface class RbFamilyHandler {
  RbFamily get family;
  String get hardwareType;
  RbFamilyCapabilities get capabilities;

  bool matchesModel(String? model);
  Future<RbSnapshot> read(RbFamilyReadContext context);
  List<DeviceMeasurement> saveCandidates(RbSnapshot snapshot);
  List<DeviceMeasurement> environmentCandidates(RbSnapshot snapshot);
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot);
}

abstract class _RbFamilyHandler implements RbFamilyHandler {
  const _RbFamilyHandler();

  String get modelPrefix;

  @override
  bool matchesModel(String? model) =>
      model != null && model.toUpperCase().startsWith(modelPrefix);

  @override
  List<DeviceMeasurement> saveCandidates(RbSnapshot snapshot) => const [];

  @override
  List<DeviceMeasurement> environmentCandidates(RbSnapshot snapshot) =>
      const [];
}

class RbDoseFamilyHandler extends _RbFamilyHandler {
  const RbDoseFamilyHandler();

  @override
  RbFamily get family => RbFamily.dose;

  @override
  String get hardwareType => kRbDosingHwType;

  @override
  String get modelPrefix => 'RSDOSE';

  @override
  RbFamilyCapabilities get capabilities =>
      const RbFamilyCapabilities(contributesWallStatus: true);

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async {
    final dashboard = await context.getJson('/dashboard');
    final initial = RbDoseStatus.fromJson(dashboard);
    final headSettings = <int, Map<String, Object?>>{};
    for (final head in initial.heads.take(kRbMaxDoseHeads)) {
      final settings = await context.tryGetJson(
        '/head/${head.number}/settings',
      );
      if (settings != null) headSettings[head.number] = settings;
    }
    return RbDoseSnapshot(
      info: context.info,
      status: RbDoseStatus.fromJson(dashboard, headSettings: headSettings),
    );
  }

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) {
    final status = (snapshot as RbDoseSnapshot).status;
    final heads = [
      for (final head in status.heads)
        if (head.supplement ?? head.shortName case final String label)
          WallDoseHeadFact(
            label: label,
            switchedOff: head.switchedOff,
            remainingDays: head.remainingDays,
            stockLevel: _stockLevel(
              head.switchedOff ? null : head.remainingDays,
            ),
          ),
    ];
    return WallDeviceSnapshot(
      statusFacts: [if (heads.isNotEmpty) WallDoseFact(heads)],
      signature: _wallSignature(const [], [
        for (final head in status.heads) head.dosedToday,
      ]),
    );
  }
}

class RbAtoFamilyHandler extends _RbFamilyHandler {
  const RbAtoFamilyHandler();

  @override
  RbFamily get family => RbFamily.ato;

  @override
  String get hardwareType => kRbAtoHwType;

  @override
  String get modelPrefix => 'RSATO';

  @override
  RbFamilyCapabilities get capabilities => const RbFamilyCapabilities(
    contributesWallReadings: true,
    contributesWallStatus: true,
  );

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async => RbAtoSnapshot(
    info: context.info,
    status: RbAtoStatus.fromJson(await context.getJson('/dashboard')),
  );

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) {
    final status = (snapshot as RbAtoSnapshot).status;
    final readings = wallRbReadings(snapshot);
    return WallDeviceSnapshot(
      readings: readings,
      statusFacts: [
        WallAtoFact(
          level: switch (status.waterLevel) {
            RbAtoWaterLevel.ok => WallLevelState.ok,
            RbAtoWaterLevel.below => WallLevelState.below,
            RbAtoWaterLevel.above => WallLevelState.above,
            RbAtoWaterLevel.unknown => WallLevelState.unknown,
          },
          rawLevel: status.waterLevelRaw,
          leakSensorActive: status.leakSensorActive,
          leakAlarm: status.leakAlarm,
          daysTillEmpty: status.daysTillEmpty,
          stockLevel: _stockLevel(status.daysTillEmpty),
        ),
      ],
      signature: _wallSignature(readings, [
        status.waterLevelRaw,
        status.leakAlarm,
        status.todayVolumeMl,
        status.daysTillEmpty,
      ]),
    );
  }
}

class RbMatFamilyHandler extends _RbFamilyHandler {
  const RbMatFamilyHandler();

  @override
  RbFamily get family => RbFamily.mat;

  @override
  String get hardwareType => kRbMatHwType;

  @override
  String get modelPrefix => 'RSMAT';

  @override
  RbFamilyCapabilities get capabilities =>
      const RbFamilyCapabilities(contributesWallStatus: true);

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async {
    final dashboard = await context.getJson('/dashboard');
    final configuration = await context.tryGetJson('/configuration');
    return RbMatSnapshot(
      info: context.info,
      status: RbMatStatus.fromJson(dashboard, configuration: configuration),
    );
  }

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) {
    final status = (snapshot as RbMatSnapshot).status;
    return WallDeviceSnapshot(
      statusFacts: [
        WallFilterRollFact(
          empty: status.modeRaw == kRbMatEndOfRollMode,
          daysTillEndOfRoll: status.daysTillEndOfRoll,
        ),
      ],
      signature: _wallSignature(const [], [
        status.daysTillEndOfRoll,
        status.modeRaw,
      ]),
    );
  }
}

class RbRunFamilyHandler extends _RbFamilyHandler {
  const RbRunFamilyHandler();

  @override
  RbFamily get family => RbFamily.run;

  @override
  String get hardwareType => kRbRunHwType;

  @override
  String get modelPrefix => 'RSRUN';

  @override
  RbFamilyCapabilities get capabilities =>
      const RbFamilyCapabilities(contributesWallStatus: true);

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async => RbRunSnapshot(
    info: context.info,
    status: RbRunStatus.fromJson(await context.getJson('/dashboard')),
  );

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) {
    final status = (snapshot as RbRunSnapshot).status;
    return WallDeviceSnapshot(
      statusFacts: [
        for (final pump in status.pumps)
          if (!pump.isEmptySocket && pump.type == 'skimmer')
            WallSkimmerFact(
              name: pump.name,
              fullCup: pump.fullCup,
              overSkimming: pump.overSkimming,
              faulted: pump.faulted,
            ),
      ],
      signature: _wallSignature(const [], [
        for (final pump in status.pumps) pump.state,
      ]),
    );
  }
}

class RbLightFamilyHandler extends _RbFamilyHandler {
  const RbLightFamilyHandler();

  @override
  RbFamily get family => RbFamily.light;

  @override
  String get hardwareType => kRbLightsHwType;

  @override
  String get modelPrefix => 'RSLED';

  @override
  RbFamilyCapabilities get capabilities => const RbFamilyCapabilities();

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async => RbLightSnapshot(
    info: context.info,
    status: RbLightStatus.fromJson(await context.getJson('/dashboard')),
  );

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) =>
      WallDeviceSnapshot(signature: _wallSignature(const [], const []));
}

class RbWaveFamilyHandler extends _RbFamilyHandler {
  const RbWaveFamilyHandler();

  @override
  RbFamily get family => RbFamily.wave;

  @override
  String get hardwareType => kRbWaveHwType;

  @override
  String get modelPrefix => 'RSWAVE';

  @override
  RbFamilyCapabilities get capabilities => const RbFamilyCapabilities();

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async => RbWaveSnapshot(
    info: context.info,
    status: RbWaveStatus.fromJson(
      await context.getJson('/mode'),
      auto: await context.tryGetJson('/auto'),
    ),
  );

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) =>
      WallDeviceSnapshot(signature: _wallSignature(const [], const []));
}

class RbControlFamilyHandler extends _RbFamilyHandler {
  const RbControlFamilyHandler();

  @override
  RbFamily get family => RbFamily.control;

  @override
  String get hardwareType => kRbControlHwType;

  @override
  String get modelPrefix => 'RSCONTROL';

  @override
  RbFamilyCapabilities get capabilities => const RbFamilyCapabilities(
    savesMeasurements: true,
    contributesWallReadings: true,
    contributesEnvironment: true,
  );

  @override
  Future<RbSnapshot> read(RbFamilyReadContext context) async =>
      RbControlSnapshot(
        info: context.info,
        status: RbControlStatus.fromJson(await context.getJson('/dashboard')),
      );

  @override
  List<DeviceMeasurement> saveCandidates(RbSnapshot snapshot) =>
      rbControlMeasurements((snapshot as RbControlSnapshot).status);

  @override
  List<DeviceMeasurement> environmentCandidates(RbSnapshot snapshot) =>
      saveCandidates(snapshot);

  @override
  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) {
    final readings = wallRbReadings(snapshot);
    return WallDeviceSnapshot(
      readings: readings,
      signature: _wallSignature(readings, const []),
    );
  }
}

class RbFamilyHandlerRegistry {
  RbFamilyHandlerRegistry(Iterable<RbFamilyHandler> handlers)
    : _byFamily = {},
      _byHardwareType = {} {
    for (final handler in handlers) {
      if (_byFamily.containsKey(handler.family)) {
        throw ArgumentError('Duplicate ReefBeat family: ${handler.family}');
      }
      if (_byHardwareType.containsKey(handler.hardwareType)) {
        throw ArgumentError(
          'Duplicate ReefBeat hardware type: ${handler.hardwareType}',
        );
      }
      _byFamily[handler.family] = handler;
      _byHardwareType[handler.hardwareType] = handler;
    }
    final missing = [
      for (final family in RbFamily.values)
        if (!_byFamily.containsKey(family)) family,
    ];
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing ReefBeat family handlers: $missing');
    }
  }

  final Map<RbFamily, RbFamilyHandler> _byFamily;
  final Map<String, RbFamilyHandler> _byHardwareType;

  List<RbFamilyHandler> get values => [
    for (final family in RbFamily.values) _byFamily[family]!,
  ];

  Set<String> get supportedHardwareTypes => _byHardwareType.keys.toSet();

  RbFamilyHandler? forHardwareType(String hardwareType) =>
      _byHardwareType[hardwareType];

  RbFamilyHandler forSnapshot(RbSnapshot snapshot) =>
      _byFamily[snapshot.family]!;

  RbFamilyHandler? forModel(String? model) {
    for (final handler in values) {
      if (handler.matchesModel(model)) return handler;
    }
    return null;
  }

  bool isModelFamily(String? model, RbFamily family) =>
      forModel(model)?.family == family;

  bool savesModel(String? model) =>
      forModel(model)?.capabilities.savesMeasurements ?? false;

  List<DeviceMeasurement> saveCandidates(RbSnapshot snapshot) =>
      forSnapshot(snapshot).saveCandidates(snapshot);

  List<DeviceMeasurement> environmentCandidates(RbSnapshot snapshot) =>
      forSnapshot(snapshot).environmentCandidates(snapshot);

  WallDeviceSnapshot wallSnapshot(RbSnapshot snapshot) =>
      forSnapshot(snapshot).wallSnapshot(snapshot);
}

final rbFamilyHandlers = RbFamilyHandlerRegistry(const [
  RbDoseFamilyHandler(),
  RbAtoFamilyHandler(),
  RbMatFamilyHandler(),
  RbRunFamilyHandler(),
  RbLightFamilyHandler(),
  RbWaveFamilyHandler(),
  RbControlFamilyHandler(),
]);

String _wallSignature(List<WallReading> readings, List<Object?> statusParts) =>
    '${wallPayloadSignature(readings)}|${statusParts.join(';')}';

WallStockLevel _stockLevel(int? remainingDays) => switch (remainingDays) {
  null => WallStockLevel.unknown,
  final days => switch (rbStockSeverity(days)) {
    RbStockSeverity.healthy => WallStockLevel.healthy,
    RbStockSeverity.caution => WallStockLevel.caution,
    RbStockSeverity.critical => WallStockLevel.critical,
  },
};
