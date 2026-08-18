/// Exhaustive ReefBeat read results.
///
/// A snapshot is always exactly one supported family. This removes the former
/// seven-nullable-fields state where callers had to guess which payload was
/// present and where invalid zero/multiple-family snapshots were constructible.
library;

import 'rb_protocol.dart';

enum RbFamily { dose, ato, mat, run, light, wave, control }

sealed class RbSnapshot {
  const RbSnapshot(this.info);

  final RbDeviceInfo info;

  RbFamily get family;

  /// The most precise model code known. ReefMat refines the generic identity
  /// model from its configuration payload; every other family uses hw_model.
  String get modelCode => info.hwModel;

  String get modelDisplayName => rbModelDisplayName(modelCode);
}

final class RbDoseSnapshot extends RbSnapshot {
  const RbDoseSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbDoseStatus status;

  @override
  RbFamily get family => RbFamily.dose;
}

final class RbAtoSnapshot extends RbSnapshot {
  const RbAtoSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbAtoStatus status;

  @override
  RbFamily get family => RbFamily.ato;
}

final class RbMatSnapshot extends RbSnapshot {
  const RbMatSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbMatStatus status;

  @override
  RbFamily get family => RbFamily.mat;

  @override
  String get modelCode => status.modelCode ?? info.hwModel;
}

final class RbRunSnapshot extends RbSnapshot {
  const RbRunSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbRunStatus status;

  @override
  RbFamily get family => RbFamily.run;
}

final class RbLightSnapshot extends RbSnapshot {
  const RbLightSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbLightStatus status;

  @override
  RbFamily get family => RbFamily.light;
}

final class RbWaveSnapshot extends RbSnapshot {
  const RbWaveSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbWaveStatus status;

  @override
  RbFamily get family => RbFamily.wave;
}

final class RbControlSnapshot extends RbSnapshot {
  const RbControlSnapshot({required RbDeviceInfo info, required this.status})
    : super(info);

  final RbControlStatus status;

  @override
  RbFamily get family => RbFamily.control;
}
