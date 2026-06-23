// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TanksTable extends Tanks with TableInfo<$TanksTable, Tank> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TanksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setupTypeMeta = const VerificationMeta(
    'setupType',
  );
  @override
  late final GeneratedColumn<String> setupType = GeneratedColumn<String>(
    'setup_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeLitersMeta = const VerificationMeta(
    'volumeLiters',
  );
  @override
  late final GeneratedColumn<double> volumeLiters = GeneratedColumn<double>(
    'volume_liters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    setupType,
    volumeLiters,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tanks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tank> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('setup_type')) {
      context.handle(
        _setupTypeMeta,
        setupType.isAcceptableOrUnknown(data['setup_type']!, _setupTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_setupTypeMeta);
    }
    if (data.containsKey('volume_liters')) {
      context.handle(
        _volumeLitersMeta,
        volumeLiters.isAcceptableOrUnknown(
          data['volume_liters']!,
          _volumeLitersMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tank map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tank(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      setupType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setup_type'],
      )!,
      volumeLiters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume_liters'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TanksTable createAlias(String alias) {
    return $TanksTable(attachedDatabase, alias);
  }
}

class Tank extends DataClass implements Insertable<Tank> {
  final int id;
  final String name;

  /// Stored as [SetupType.name].
  final String setupType;
  final double? volumeLiters;
  final DateTime createdAt;
  const Tank({
    required this.id,
    required this.name,
    required this.setupType,
    this.volumeLiters,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['setup_type'] = Variable<String>(setupType);
    if (!nullToAbsent || volumeLiters != null) {
      map['volume_liters'] = Variable<double>(volumeLiters);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TanksCompanion toCompanion(bool nullToAbsent) {
    return TanksCompanion(
      id: Value(id),
      name: Value(name),
      setupType: Value(setupType),
      volumeLiters: volumeLiters == null && nullToAbsent
          ? const Value.absent()
          : Value(volumeLiters),
      createdAt: Value(createdAt),
    );
  }

  factory Tank.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tank(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      setupType: serializer.fromJson<String>(json['setupType']),
      volumeLiters: serializer.fromJson<double?>(json['volumeLiters']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'setupType': serializer.toJson<String>(setupType),
      'volumeLiters': serializer.toJson<double?>(volumeLiters),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tank copyWith({
    int? id,
    String? name,
    String? setupType,
    Value<double?> volumeLiters = const Value.absent(),
    DateTime? createdAt,
  }) => Tank(
    id: id ?? this.id,
    name: name ?? this.name,
    setupType: setupType ?? this.setupType,
    volumeLiters: volumeLiters.present ? volumeLiters.value : this.volumeLiters,
    createdAt: createdAt ?? this.createdAt,
  );
  Tank copyWithCompanion(TanksCompanion data) {
    return Tank(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      setupType: data.setupType.present ? data.setupType.value : this.setupType,
      volumeLiters: data.volumeLiters.present
          ? data.volumeLiters.value
          : this.volumeLiters,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tank(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('setupType: $setupType, ')
          ..write('volumeLiters: $volumeLiters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, setupType, volumeLiters, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tank &&
          other.id == this.id &&
          other.name == this.name &&
          other.setupType == this.setupType &&
          other.volumeLiters == this.volumeLiters &&
          other.createdAt == this.createdAt);
}

class TanksCompanion extends UpdateCompanion<Tank> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> setupType;
  final Value<double?> volumeLiters;
  final Value<DateTime> createdAt;
  const TanksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.setupType = const Value.absent(),
    this.volumeLiters = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TanksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String setupType,
    this.volumeLiters = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       setupType = Value(setupType);
  static Insertable<Tank> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? setupType,
    Expression<double>? volumeLiters,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (setupType != null) 'setup_type': setupType,
      if (volumeLiters != null) 'volume_liters': volumeLiters,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TanksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? setupType,
    Value<double?>? volumeLiters,
    Value<DateTime>? createdAt,
  }) {
    return TanksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      setupType: setupType ?? this.setupType,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (setupType.present) {
      map['setup_type'] = Variable<String>(setupType.value);
    }
    if (volumeLiters.present) {
      map['volume_liters'] = Variable<double>(volumeLiters.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TanksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('setupType: $setupType, ')
          ..write('volumeLiters: $volumeLiters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TrackedParametersTable extends TrackedParameters
    with TableInfo<$TrackedParametersTable, TrackedParameter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackedParametersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<int> tankId = GeneratedColumn<int>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paramKeyMeta = const VerificationMeta(
    'paramKey',
  );
  @override
  late final GeneratedColumn<String> paramKey = GeneratedColumn<String>(
    'param_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _amberLowMeta = const VerificationMeta(
    'amberLow',
  );
  @override
  late final GeneratedColumn<double> amberLow = GeneratedColumn<double>(
    'amber_low',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _greenLowMeta = const VerificationMeta(
    'greenLow',
  );
  @override
  late final GeneratedColumn<double> greenLow = GeneratedColumn<double>(
    'green_low',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _greenHighMeta = const VerificationMeta(
    'greenHigh',
  );
  @override
  late final GeneratedColumn<double> greenHigh = GeneratedColumn<double>(
    'green_high',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amberHighMeta = const VerificationMeta(
    'amberHigh',
  );
  @override
  late final GeneratedColumn<double> amberHigh = GeneratedColumn<double>(
    'amber_high',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    paramKey,
    unit,
    enabled,
    displayOrder,
    amberLow,
    greenLow,
    greenHigh,
    amberHigh,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracked_parameters';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackedParameter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('param_key')) {
      context.handle(
        _paramKeyMeta,
        paramKey.isAcceptableOrUnknown(data['param_key']!, _paramKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_paramKeyMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('amber_low')) {
      context.handle(
        _amberLowMeta,
        amberLow.isAcceptableOrUnknown(data['amber_low']!, _amberLowMeta),
      );
    }
    if (data.containsKey('green_low')) {
      context.handle(
        _greenLowMeta,
        greenLow.isAcceptableOrUnknown(data['green_low']!, _greenLowMeta),
      );
    }
    if (data.containsKey('green_high')) {
      context.handle(
        _greenHighMeta,
        greenHigh.isAcceptableOrUnknown(data['green_high']!, _greenHighMeta),
      );
    }
    if (data.containsKey('amber_high')) {
      context.handle(
        _amberHighMeta,
        amberHigh.isAcceptableOrUnknown(data['amber_high']!, _amberHighMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackedParameter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackedParameter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      paramKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}param_key'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      amberLow: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amber_low'],
      ),
      greenLow: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}green_low'],
      ),
      greenHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}green_high'],
      ),
      amberHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amber_high'],
      ),
    );
  }

  @override
  $TrackedParametersTable createAlias(String alias) {
    return $TrackedParametersTable(attachedDatabase, alias);
  }
}

class TrackedParameter extends DataClass
    implements Insertable<TrackedParameter> {
  final int id;
  final int tankId;
  final String paramKey;
  final String unit;
  final bool enabled;
  final int displayOrder;
  final double? amberLow;
  final double? greenLow;
  final double? greenHigh;
  final double? amberHigh;
  const TrackedParameter({
    required this.id,
    required this.tankId,
    required this.paramKey,
    required this.unit,
    required this.enabled,
    required this.displayOrder,
    this.amberLow,
    this.greenLow,
    this.greenHigh,
    this.amberHigh,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['param_key'] = Variable<String>(paramKey);
    map['unit'] = Variable<String>(unit);
    map['enabled'] = Variable<bool>(enabled);
    map['display_order'] = Variable<int>(displayOrder);
    if (!nullToAbsent || amberLow != null) {
      map['amber_low'] = Variable<double>(amberLow);
    }
    if (!nullToAbsent || greenLow != null) {
      map['green_low'] = Variable<double>(greenLow);
    }
    if (!nullToAbsent || greenHigh != null) {
      map['green_high'] = Variable<double>(greenHigh);
    }
    if (!nullToAbsent || amberHigh != null) {
      map['amber_high'] = Variable<double>(amberHigh);
    }
    return map;
  }

  TrackedParametersCompanion toCompanion(bool nullToAbsent) {
    return TrackedParametersCompanion(
      id: Value(id),
      tankId: Value(tankId),
      paramKey: Value(paramKey),
      unit: Value(unit),
      enabled: Value(enabled),
      displayOrder: Value(displayOrder),
      amberLow: amberLow == null && nullToAbsent
          ? const Value.absent()
          : Value(amberLow),
      greenLow: greenLow == null && nullToAbsent
          ? const Value.absent()
          : Value(greenLow),
      greenHigh: greenHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(greenHigh),
      amberHigh: amberHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(amberHigh),
    );
  }

  factory TrackedParameter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackedParameter(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      paramKey: serializer.fromJson<String>(json['paramKey']),
      unit: serializer.fromJson<String>(json['unit']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      amberLow: serializer.fromJson<double?>(json['amberLow']),
      greenLow: serializer.fromJson<double?>(json['greenLow']),
      greenHigh: serializer.fromJson<double?>(json['greenHigh']),
      amberHigh: serializer.fromJson<double?>(json['amberHigh']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'paramKey': serializer.toJson<String>(paramKey),
      'unit': serializer.toJson<String>(unit),
      'enabled': serializer.toJson<bool>(enabled),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'amberLow': serializer.toJson<double?>(amberLow),
      'greenLow': serializer.toJson<double?>(greenLow),
      'greenHigh': serializer.toJson<double?>(greenHigh),
      'amberHigh': serializer.toJson<double?>(amberHigh),
    };
  }

  TrackedParameter copyWith({
    int? id,
    int? tankId,
    String? paramKey,
    String? unit,
    bool? enabled,
    int? displayOrder,
    Value<double?> amberLow = const Value.absent(),
    Value<double?> greenLow = const Value.absent(),
    Value<double?> greenHigh = const Value.absent(),
    Value<double?> amberHigh = const Value.absent(),
  }) => TrackedParameter(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    paramKey: paramKey ?? this.paramKey,
    unit: unit ?? this.unit,
    enabled: enabled ?? this.enabled,
    displayOrder: displayOrder ?? this.displayOrder,
    amberLow: amberLow.present ? amberLow.value : this.amberLow,
    greenLow: greenLow.present ? greenLow.value : this.greenLow,
    greenHigh: greenHigh.present ? greenHigh.value : this.greenHigh,
    amberHigh: amberHigh.present ? amberHigh.value : this.amberHigh,
  );
  TrackedParameter copyWithCompanion(TrackedParametersCompanion data) {
    return TrackedParameter(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      paramKey: data.paramKey.present ? data.paramKey.value : this.paramKey,
      unit: data.unit.present ? data.unit.value : this.unit,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      amberLow: data.amberLow.present ? data.amberLow.value : this.amberLow,
      greenLow: data.greenLow.present ? data.greenLow.value : this.greenLow,
      greenHigh: data.greenHigh.present ? data.greenHigh.value : this.greenHigh,
      amberHigh: data.amberHigh.present ? data.amberHigh.value : this.amberHigh,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackedParameter(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('paramKey: $paramKey, ')
          ..write('unit: $unit, ')
          ..write('enabled: $enabled, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('amberLow: $amberLow, ')
          ..write('greenLow: $greenLow, ')
          ..write('greenHigh: $greenHigh, ')
          ..write('amberHigh: $amberHigh')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tankId,
    paramKey,
    unit,
    enabled,
    displayOrder,
    amberLow,
    greenLow,
    greenHigh,
    amberHigh,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackedParameter &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.paramKey == this.paramKey &&
          other.unit == this.unit &&
          other.enabled == this.enabled &&
          other.displayOrder == this.displayOrder &&
          other.amberLow == this.amberLow &&
          other.greenLow == this.greenLow &&
          other.greenHigh == this.greenHigh &&
          other.amberHigh == this.amberHigh);
}

class TrackedParametersCompanion extends UpdateCompanion<TrackedParameter> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String> paramKey;
  final Value<String> unit;
  final Value<bool> enabled;
  final Value<int> displayOrder;
  final Value<double?> amberLow;
  final Value<double?> greenLow;
  final Value<double?> greenHigh;
  final Value<double?> amberHigh;
  const TrackedParametersCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.paramKey = const Value.absent(),
    this.unit = const Value.absent(),
    this.enabled = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.amberLow = const Value.absent(),
    this.greenLow = const Value.absent(),
    this.greenHigh = const Value.absent(),
    this.amberHigh = const Value.absent(),
  });
  TrackedParametersCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required String paramKey,
    required String unit,
    this.enabled = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.amberLow = const Value.absent(),
    this.greenLow = const Value.absent(),
    this.greenHigh = const Value.absent(),
    this.amberHigh = const Value.absent(),
  }) : tankId = Value(tankId),
       paramKey = Value(paramKey),
       unit = Value(unit);
  static Insertable<TrackedParameter> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<String>? paramKey,
    Expression<String>? unit,
    Expression<bool>? enabled,
    Expression<int>? displayOrder,
    Expression<double>? amberLow,
    Expression<double>? greenLow,
    Expression<double>? greenHigh,
    Expression<double>? amberHigh,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (paramKey != null) 'param_key': paramKey,
      if (unit != null) 'unit': unit,
      if (enabled != null) 'enabled': enabled,
      if (displayOrder != null) 'display_order': displayOrder,
      if (amberLow != null) 'amber_low': amberLow,
      if (greenLow != null) 'green_low': greenLow,
      if (greenHigh != null) 'green_high': greenHigh,
      if (amberHigh != null) 'amber_high': amberHigh,
    });
  }

  TrackedParametersCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String>? paramKey,
    Value<String>? unit,
    Value<bool>? enabled,
    Value<int>? displayOrder,
    Value<double?>? amberLow,
    Value<double?>? greenLow,
    Value<double?>? greenHigh,
    Value<double?>? amberHigh,
  }) {
    return TrackedParametersCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      paramKey: paramKey ?? this.paramKey,
      unit: unit ?? this.unit,
      enabled: enabled ?? this.enabled,
      displayOrder: displayOrder ?? this.displayOrder,
      amberLow: amberLow ?? this.amberLow,
      greenLow: greenLow ?? this.greenLow,
      greenHigh: greenHigh ?? this.greenHigh,
      amberHigh: amberHigh ?? this.amberHigh,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<int>(tankId.value);
    }
    if (paramKey.present) {
      map['param_key'] = Variable<String>(paramKey.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (amberLow.present) {
      map['amber_low'] = Variable<double>(amberLow.value);
    }
    if (greenLow.present) {
      map['green_low'] = Variable<double>(greenLow.value);
    }
    if (greenHigh.present) {
      map['green_high'] = Variable<double>(greenHigh.value);
    }
    if (amberHigh.present) {
      map['amber_high'] = Variable<double>(amberHigh.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackedParametersCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('paramKey: $paramKey, ')
          ..write('unit: $unit, ')
          ..write('enabled: $enabled, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('amberLow: $amberLow, ')
          ..write('greenLow: $greenLow, ')
          ..write('greenHigh: $greenHigh, ')
          ..write('amberHigh: $amberHigh')
          ..write(')'))
        .toString();
  }
}

class $ReadingsTable extends Readings with TableInfo<$ReadingsTable, Reading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<int> tankId = GeneratedColumn<int>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paramKeyMeta = const VerificationMeta(
    'paramKey',
  );
  @override
  late final GeneratedColumn<String> paramKey = GeneratedColumn<String>(
    'param_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    paramKey,
    value,
    takenAt,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reading> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('param_key')) {
      context.handle(
        _paramKeyMeta,
        paramKey.isAcceptableOrUnknown(data['param_key']!, _paramKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_paramKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reading(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      paramKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}param_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ReadingsTable createAlias(String alias) {
    return $ReadingsTable(attachedDatabase, alias);
  }
}

class Reading extends DataClass implements Insertable<Reading> {
  final int id;
  final int tankId;
  final String paramKey;
  final double value;
  final DateTime takenAt;
  final String? note;
  const Reading({
    required this.id,
    required this.tankId,
    required this.paramKey,
    required this.value,
    required this.takenAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['param_key'] = Variable<String>(paramKey);
    map['value'] = Variable<double>(value);
    map['taken_at'] = Variable<DateTime>(takenAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ReadingsCompanion toCompanion(bool nullToAbsent) {
    return ReadingsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      paramKey: Value(paramKey),
      value: Value(value),
      takenAt: Value(takenAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Reading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reading(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      paramKey: serializer.fromJson<String>(json['paramKey']),
      value: serializer.fromJson<double>(json['value']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'paramKey': serializer.toJson<String>(paramKey),
      'value': serializer.toJson<double>(value),
      'takenAt': serializer.toJson<DateTime>(takenAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  Reading copyWith({
    int? id,
    int? tankId,
    String? paramKey,
    double? value,
    DateTime? takenAt,
    Value<String?> note = const Value.absent(),
  }) => Reading(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    paramKey: paramKey ?? this.paramKey,
    value: value ?? this.value,
    takenAt: takenAt ?? this.takenAt,
    note: note.present ? note.value : this.note,
  );
  Reading copyWithCompanion(ReadingsCompanion data) {
    return Reading(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      paramKey: data.paramKey.present ? data.paramKey.value : this.paramKey,
      value: data.value.present ? data.value.value : this.value,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reading(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('paramKey: $paramKey, ')
          ..write('value: $value, ')
          ..write('takenAt: $takenAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tankId, paramKey, value, takenAt, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reading &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.paramKey == this.paramKey &&
          other.value == this.value &&
          other.takenAt == this.takenAt &&
          other.note == this.note);
}

class ReadingsCompanion extends UpdateCompanion<Reading> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String> paramKey;
  final Value<double> value;
  final Value<DateTime> takenAt;
  final Value<String?> note;
  const ReadingsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.paramKey = const Value.absent(),
    this.value = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.note = const Value.absent(),
  });
  ReadingsCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required String paramKey,
    required double value,
    required DateTime takenAt,
    this.note = const Value.absent(),
  }) : tankId = Value(tankId),
       paramKey = Value(paramKey),
       value = Value(value),
       takenAt = Value(takenAt);
  static Insertable<Reading> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<String>? paramKey,
    Expression<double>? value,
    Expression<DateTime>? takenAt,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (paramKey != null) 'param_key': paramKey,
      if (value != null) 'value': value,
      if (takenAt != null) 'taken_at': takenAt,
      if (note != null) 'note': note,
    });
  }

  ReadingsCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String>? paramKey,
    Value<double>? value,
    Value<DateTime>? takenAt,
    Value<String?>? note,
  }) {
    return ReadingsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      paramKey: paramKey ?? this.paramKey,
      value: value ?? this.value,
      takenAt: takenAt ?? this.takenAt,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<int>(tankId.value);
    }
    if (paramKey.present) {
      map['param_key'] = Variable<String>(paramKey.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingsCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('paramKey: $paramKey, ')
          ..write('value: $value, ')
          ..write('takenAt: $takenAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String? value;
  const Setting({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  Setting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => Setting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TanksTable tanks = $TanksTable(this);
  late final $TrackedParametersTable trackedParameters =
      $TrackedParametersTable(this);
  late final $ReadingsTable readings = $ReadingsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tanks,
    trackedParameters,
    readings,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracked_parameters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('readings', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TanksTableCreateCompanionBuilder =
    TanksCompanion Function({
      Value<int> id,
      required String name,
      required String setupType,
      Value<double?> volumeLiters,
      Value<DateTime> createdAt,
    });
typedef $$TanksTableUpdateCompanionBuilder =
    TanksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> setupType,
      Value<double?> volumeLiters,
      Value<DateTime> createdAt,
    });

final class $$TanksTableReferences
    extends BaseReferences<_$AppDatabase, $TanksTable, Tank> {
  $$TanksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackedParametersTable, List<TrackedParameter>>
  _trackedParametersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.trackedParameters,
        aliasName: 'tanks__id__tracked_parameters__tank_id',
      );

  $$TrackedParametersTableProcessedTableManager get trackedParametersRefs {
    final manager = $$TrackedParametersTableTableManager(
      $_db,
      $_db.trackedParameters,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _trackedParametersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingsTable, List<Reading>> _readingsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.readings,
    aliasName: 'tanks__id__readings__tank_id',
  );

  $$ReadingsTableProcessedTableManager get readingsRefs {
    final manager = $$ReadingsTableTableManager(
      $_db,
      $_db.readings,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_readingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TanksTableFilterComposer extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setupType => $composableBuilder(
    column: $table.setupType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackedParametersRefs(
    Expression<bool> Function($$TrackedParametersTableFilterComposer f) f,
  ) {
    final $$TrackedParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackedParameters,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackedParametersTableFilterComposer(
            $db: $db,
            $table: $db.trackedParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingsRefs(
    Expression<bool> Function($$ReadingsTableFilterComposer f) f,
  ) {
    final $$ReadingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readings,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingsTableFilterComposer(
            $db: $db,
            $table: $db.readings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TanksTableOrderingComposer
    extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setupType => $composableBuilder(
    column: $table.setupType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TanksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get setupType =>
      $composableBuilder(column: $table.setupType, builder: (column) => column);

  GeneratedColumn<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> trackedParametersRefs<T extends Object>(
    Expression<T> Function($$TrackedParametersTableAnnotationComposer a) f,
  ) {
    final $$TrackedParametersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.trackedParameters,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TrackedParametersTableAnnotationComposer(
                $db: $db,
                $table: $db.trackedParameters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> readingsRefs<T extends Object>(
    Expression<T> Function($$ReadingsTableAnnotationComposer a) f,
  ) {
    final $$ReadingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readings,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingsTableAnnotationComposer(
            $db: $db,
            $table: $db.readings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TanksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TanksTable,
          Tank,
          $$TanksTableFilterComposer,
          $$TanksTableOrderingComposer,
          $$TanksTableAnnotationComposer,
          $$TanksTableCreateCompanionBuilder,
          $$TanksTableUpdateCompanionBuilder,
          (Tank, $$TanksTableReferences),
          Tank,
          PrefetchHooks Function({
            bool trackedParametersRefs,
            bool readingsRefs,
          })
        > {
  $$TanksTableTableManager(_$AppDatabase db, $TanksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TanksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TanksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TanksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> setupType = const Value.absent(),
                Value<double?> volumeLiters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TanksCompanion(
                id: id,
                name: name,
                setupType: setupType,
                volumeLiters: volumeLiters,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String setupType,
                Value<double?> volumeLiters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TanksCompanion.insert(
                id: id,
                name: name,
                setupType: setupType,
                volumeLiters: volumeLiters,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TanksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({trackedParametersRefs = false, readingsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trackedParametersRefs) db.trackedParameters,
                    if (readingsRefs) db.readings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trackedParametersRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          TrackedParameter
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._trackedParametersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackedParametersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingsRefs)
                        await $_getPrefetchedData<Tank, $TanksTable, Reading>(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._readingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TanksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TanksTable,
      Tank,
      $$TanksTableFilterComposer,
      $$TanksTableOrderingComposer,
      $$TanksTableAnnotationComposer,
      $$TanksTableCreateCompanionBuilder,
      $$TanksTableUpdateCompanionBuilder,
      (Tank, $$TanksTableReferences),
      Tank,
      PrefetchHooks Function({bool trackedParametersRefs, bool readingsRefs})
    >;
typedef $$TrackedParametersTableCreateCompanionBuilder =
    TrackedParametersCompanion Function({
      Value<int> id,
      required int tankId,
      required String paramKey,
      required String unit,
      Value<bool> enabled,
      Value<int> displayOrder,
      Value<double?> amberLow,
      Value<double?> greenLow,
      Value<double?> greenHigh,
      Value<double?> amberHigh,
    });
typedef $$TrackedParametersTableUpdateCompanionBuilder =
    TrackedParametersCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String> paramKey,
      Value<String> unit,
      Value<bool> enabled,
      Value<int> displayOrder,
      Value<double?> amberLow,
      Value<double?> greenLow,
      Value<double?> greenHigh,
      Value<double?> amberHigh,
    });

final class $$TrackedParametersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TrackedParametersTable,
          TrackedParameter
        > {
  $$TrackedParametersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('tracked_parameters__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<int>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackedParametersTableFilterComposer
    extends Composer<_$AppDatabase, $TrackedParametersTable> {
  $$TrackedParametersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paramKey => $composableBuilder(
    column: $table.paramKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amberLow => $composableBuilder(
    column: $table.amberLow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get greenLow => $composableBuilder(
    column: $table.greenLow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get greenHigh => $composableBuilder(
    column: $table.greenHigh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amberHigh => $composableBuilder(
    column: $table.amberHigh,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackedParametersTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackedParametersTable> {
  $$TrackedParametersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paramKey => $composableBuilder(
    column: $table.paramKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amberLow => $composableBuilder(
    column: $table.amberLow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get greenLow => $composableBuilder(
    column: $table.greenLow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get greenHigh => $composableBuilder(
    column: $table.greenHigh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amberHigh => $composableBuilder(
    column: $table.amberHigh,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackedParametersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackedParametersTable> {
  $$TrackedParametersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get paramKey =>
      $composableBuilder(column: $table.paramKey, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amberLow =>
      $composableBuilder(column: $table.amberLow, builder: (column) => column);

  GeneratedColumn<double> get greenLow =>
      $composableBuilder(column: $table.greenLow, builder: (column) => column);

  GeneratedColumn<double> get greenHigh =>
      $composableBuilder(column: $table.greenHigh, builder: (column) => column);

  GeneratedColumn<double> get amberHigh =>
      $composableBuilder(column: $table.amberHigh, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackedParametersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackedParametersTable,
          TrackedParameter,
          $$TrackedParametersTableFilterComposer,
          $$TrackedParametersTableOrderingComposer,
          $$TrackedParametersTableAnnotationComposer,
          $$TrackedParametersTableCreateCompanionBuilder,
          $$TrackedParametersTableUpdateCompanionBuilder,
          (TrackedParameter, $$TrackedParametersTableReferences),
          TrackedParameter,
          PrefetchHooks Function({bool tankId})
        > {
  $$TrackedParametersTableTableManager(
    _$AppDatabase db,
    $TrackedParametersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackedParametersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackedParametersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackedParametersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<String> paramKey = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<double?> amberLow = const Value.absent(),
                Value<double?> greenLow = const Value.absent(),
                Value<double?> greenHigh = const Value.absent(),
                Value<double?> amberHigh = const Value.absent(),
              }) => TrackedParametersCompanion(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                unit: unit,
                enabled: enabled,
                displayOrder: displayOrder,
                amberLow: amberLow,
                greenLow: greenLow,
                greenHigh: greenHigh,
                amberHigh: amberHigh,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required String paramKey,
                required String unit,
                Value<bool> enabled = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<double?> amberLow = const Value.absent(),
                Value<double?> greenLow = const Value.absent(),
                Value<double?> greenHigh = const Value.absent(),
                Value<double?> amberHigh = const Value.absent(),
              }) => TrackedParametersCompanion.insert(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                unit: unit,
                enabled: enabled,
                displayOrder: displayOrder,
                amberLow: amberLow,
                greenLow: greenLow,
                greenHigh: greenHigh,
                amberHigh: amberHigh,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrackedParametersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable:
                                    $$TrackedParametersTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$TrackedParametersTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackedParametersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackedParametersTable,
      TrackedParameter,
      $$TrackedParametersTableFilterComposer,
      $$TrackedParametersTableOrderingComposer,
      $$TrackedParametersTableAnnotationComposer,
      $$TrackedParametersTableCreateCompanionBuilder,
      $$TrackedParametersTableUpdateCompanionBuilder,
      (TrackedParameter, $$TrackedParametersTableReferences),
      TrackedParameter,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$ReadingsTableCreateCompanionBuilder =
    ReadingsCompanion Function({
      Value<int> id,
      required int tankId,
      required String paramKey,
      required double value,
      required DateTime takenAt,
      Value<String?> note,
    });
typedef $$ReadingsTableUpdateCompanionBuilder =
    ReadingsCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String> paramKey,
      Value<double> value,
      Value<DateTime> takenAt,
      Value<String?> note,
    });

final class $$ReadingsTableReferences
    extends BaseReferences<_$AppDatabase, $ReadingsTable, Reading> {
  $$ReadingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('readings__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<int>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paramKey => $composableBuilder(
    column: $table.paramKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paramKey => $composableBuilder(
    column: $table.paramKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingsTable> {
  $$ReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get paramKey =>
      $composableBuilder(column: $table.paramKey, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingsTable,
          Reading,
          $$ReadingsTableFilterComposer,
          $$ReadingsTableOrderingComposer,
          $$ReadingsTableAnnotationComposer,
          $$ReadingsTableCreateCompanionBuilder,
          $$ReadingsTableUpdateCompanionBuilder,
          (Reading, $$ReadingsTableReferences),
          Reading,
          PrefetchHooks Function({bool tankId})
        > {
  $$ReadingsTableTableManager(_$AppDatabase db, $ReadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<String> paramKey = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => ReadingsCompanion(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                value: value,
                takenAt: takenAt,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required String paramKey,
                required double value,
                required DateTime takenAt,
                Value<String?> note = const Value.absent(),
              }) => ReadingsCompanion.insert(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                value: value,
                takenAt: takenAt,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable: $$ReadingsTableReferences
                                    ._tankIdTable(db),
                                referencedColumn: $$ReadingsTableReferences
                                    ._tankIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingsTable,
      Reading,
      $$ReadingsTableFilterComposer,
      $$ReadingsTableOrderingComposer,
      $$ReadingsTableAnnotationComposer,
      $$ReadingsTableCreateCompanionBuilder,
      $$ReadingsTableUpdateCompanionBuilder,
      (Reading, $$ReadingsTableReferences),
      Reading,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TanksTableTableManager get tanks =>
      $$TanksTableTableManager(_db, _db.tanks);
  $$TrackedParametersTableTableManager get trackedParameters =>
      $$TrackedParametersTableTableManager(_db, _db.trackedParameters);
  $$ReadingsTableTableManager get readings =>
      $$ReadingsTableTableManager(_db, _db.readings);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
