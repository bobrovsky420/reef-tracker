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
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    setupType,
    volumeLiters,
    startDate,
    notes,
    vendor,
    model,
    createdAt,
    deletedAt,
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
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('vendor')) {
      context.handle(
        _vendorMeta,
        vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      vendor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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

  /// When the aquarium was set up/started (optional, user-editable).
  final DateTime? startDate;

  /// Free-text, multi-line notes about the aquarium (optional).
  final String? notes;

  /// Hardware vendor/manufacturer of the tank (optional, single line).
  final String? vendor;

  /// Tank model/name (optional, single line).
  final String? model;
  final DateTime createdAt;

  /// Soft-delete stamp (U10). Set by [AppDatabase.softDeleteTank] — the tank
  /// vanishes from every read path but its rows survive the undo window —
  /// and cleared by [AppDatabase.restoreTank]. Non-null rows are finalized by
  /// [AppDatabase.hardDeleteTank] / [AppDatabase.purgeDeletedTanks].
  final DateTime? deletedAt;
  const Tank({
    required this.id,
    required this.name,
    required this.setupType,
    this.volumeLiters,
    this.startDate,
    this.notes,
    this.vendor,
    this.model,
    required this.createdAt,
    this.deletedAt,
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
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      vendor: vendor == null && nullToAbsent
          ? const Value.absent()
          : Value(vendor),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
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
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      notes: serializer.fromJson<String?>(json['notes']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      model: serializer.fromJson<String?>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
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
      'startDate': serializer.toJson<DateTime?>(startDate),
      'notes': serializer.toJson<String?>(notes),
      'vendor': serializer.toJson<String?>(vendor),
      'model': serializer.toJson<String?>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Tank copyWith({
    int? id,
    String? name,
    String? setupType,
    Value<double?> volumeLiters = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> vendor = const Value.absent(),
    Value<String?> model = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Tank(
    id: id ?? this.id,
    name: name ?? this.name,
    setupType: setupType ?? this.setupType,
    volumeLiters: volumeLiters.present ? volumeLiters.value : this.volumeLiters,
    startDate: startDate.present ? startDate.value : this.startDate,
    notes: notes.present ? notes.value : this.notes,
    vendor: vendor.present ? vendor.value : this.vendor,
    model: model.present ? model.value : this.model,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Tank copyWithCompanion(TanksCompanion data) {
    return Tank(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      setupType: data.setupType.present ? data.setupType.value : this.setupType,
      volumeLiters: data.volumeLiters.present
          ? data.volumeLiters.value
          : this.volumeLiters,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      notes: data.notes.present ? data.notes.value : this.notes,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tank(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('setupType: $setupType, ')
          ..write('volumeLiters: $volumeLiters, ')
          ..write('startDate: $startDate, ')
          ..write('notes: $notes, ')
          ..write('vendor: $vendor, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    setupType,
    volumeLiters,
    startDate,
    notes,
    vendor,
    model,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tank &&
          other.id == this.id &&
          other.name == this.name &&
          other.setupType == this.setupType &&
          other.volumeLiters == this.volumeLiters &&
          other.startDate == this.startDate &&
          other.notes == this.notes &&
          other.vendor == this.vendor &&
          other.model == this.model &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class TanksCompanion extends UpdateCompanion<Tank> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> setupType;
  final Value<double?> volumeLiters;
  final Value<DateTime?> startDate;
  final Value<String?> notes;
  final Value<String?> vendor;
  final Value<String?> model;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const TanksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.setupType = const Value.absent(),
    this.volumeLiters = const Value.absent(),
    this.startDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.vendor = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TanksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String setupType,
    this.volumeLiters = const Value.absent(),
    this.startDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.vendor = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       setupType = Value(setupType);
  static Insertable<Tank> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? setupType,
    Expression<double>? volumeLiters,
    Expression<DateTime>? startDate,
    Expression<String>? notes,
    Expression<String>? vendor,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (setupType != null) 'setup_type': setupType,
      if (volumeLiters != null) 'volume_liters': volumeLiters,
      if (startDate != null) 'start_date': startDate,
      if (notes != null) 'notes': notes,
      if (vendor != null) 'vendor': vendor,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TanksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? setupType,
    Value<double?>? volumeLiters,
    Value<DateTime?>? startDate,
    Value<String?>? notes,
    Value<String?>? vendor,
    Value<String?>? model,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
  }) {
    return TanksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      setupType: setupType ?? this.setupType,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      startDate: startDate ?? this.startDate,
      notes: notes ?? this.notes,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('startDate: $startDate, ')
          ..write('notes: $notes, ')
          ..write('vendor: $vendor, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
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
  static const VerificationMeta _testCadenceDaysMeta = const VerificationMeta(
    'testCadenceDays',
  );
  @override
  late final GeneratedColumn<int> testCadenceDays = GeneratedColumn<int>(
    'test_cadence_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    testCadenceDays,
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
    if (data.containsKey('test_cadence_days')) {
      context.handle(
        _testCadenceDaysMeta,
        testCadenceDays.isAcceptableOrUnknown(
          data['test_cadence_days']!,
          _testCadenceDaysMeta,
        ),
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
      testCadenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_cadence_days'],
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

  /// "Remind to test every N days" (U1); null = no reminder for this
  /// parameter. The reminder anchors elastically on the parameter's latest
  /// reading (see `domain/reminders.dart`).
  final int? testCadenceDays;
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
    this.testCadenceDays,
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
    if (!nullToAbsent || testCadenceDays != null) {
      map['test_cadence_days'] = Variable<int>(testCadenceDays);
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
      testCadenceDays: testCadenceDays == null && nullToAbsent
          ? const Value.absent()
          : Value(testCadenceDays),
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
      testCadenceDays: serializer.fromJson<int?>(json['testCadenceDays']),
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
      'testCadenceDays': serializer.toJson<int?>(testCadenceDays),
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
    Value<int?> testCadenceDays = const Value.absent(),
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
    testCadenceDays: testCadenceDays.present
        ? testCadenceDays.value
        : this.testCadenceDays,
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
      testCadenceDays: data.testCadenceDays.present
          ? data.testCadenceDays.value
          : this.testCadenceDays,
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
          ..write('amberHigh: $amberHigh, ')
          ..write('testCadenceDays: $testCadenceDays')
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
    testCadenceDays,
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
          other.amberHigh == this.amberHigh &&
          other.testCadenceDays == this.testCadenceDays);
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
  final Value<int?> testCadenceDays;
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
    this.testCadenceDays = const Value.absent(),
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
    this.testCadenceDays = const Value.absent(),
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
    Expression<int>? testCadenceDays,
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
      if (testCadenceDays != null) 'test_cadence_days': testCadenceDays,
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
    Value<int?>? testCadenceDays,
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
      testCadenceDays: testCadenceDays ?? this.testCadenceDays,
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
    if (testCadenceDays.present) {
      map['test_cadence_days'] = Variable<int>(testCadenceDays.value);
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
          ..write('amberHigh: $amberHigh, ')
          ..write('testCadenceDays: $testCadenceDays')
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
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
    groupId,
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
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

  /// Identifies readings entered together as one batch on the add-reading
  /// screen (#15). Group edit/delete keys on this instead of the second-level
  /// `takenAt` timestamp, which silently merged distinct groups saved (or
  /// re-timed onto) the same second. Null for rows from before schema v13,
  /// which fall back to timestamp grouping.
  final String? groupId;
  const Reading({
    required this.id,
    required this.tankId,
    required this.paramKey,
    required this.value,
    required this.takenAt,
    this.note,
    this.groupId,
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
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
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
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
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
      groupId: serializer.fromJson<String?>(json['groupId']),
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
      'groupId': serializer.toJson<String?>(groupId),
    };
  }

  Reading copyWith({
    int? id,
    int? tankId,
    String? paramKey,
    double? value,
    DateTime? takenAt,
    Value<String?> note = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
  }) => Reading(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    paramKey: paramKey ?? this.paramKey,
    value: value ?? this.value,
    takenAt: takenAt ?? this.takenAt,
    note: note.present ? note.value : this.note,
    groupId: groupId.present ? groupId.value : this.groupId,
  );
  Reading copyWithCompanion(ReadingsCompanion data) {
    return Reading(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      paramKey: data.paramKey.present ? data.paramKey.value : this.paramKey,
      value: data.value.present ? data.value.value : this.value,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      note: data.note.present ? data.note.value : this.note,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
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
          ..write('note: $note, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tankId, paramKey, value, takenAt, note, groupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reading &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.paramKey == this.paramKey &&
          other.value == this.value &&
          other.takenAt == this.takenAt &&
          other.note == this.note &&
          other.groupId == this.groupId);
}

class ReadingsCompanion extends UpdateCompanion<Reading> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String> paramKey;
  final Value<double> value;
  final Value<DateTime> takenAt;
  final Value<String?> note;
  final Value<String?> groupId;
  const ReadingsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.paramKey = const Value.absent(),
    this.value = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
  });
  ReadingsCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required String paramKey,
    required double value,
    required DateTime takenAt,
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
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
    Expression<String>? groupId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (paramKey != null) 'param_key': paramKey,
      if (value != null) 'value': value,
      if (takenAt != null) 'taken_at': takenAt,
      if (note != null) 'note': note,
      if (groupId != null) 'group_id': groupId,
    });
  }

  ReadingsCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String>? paramKey,
    Value<double>? value,
    Value<DateTime>? takenAt,
    Value<String?>? note,
    Value<String?>? groupId,
  }) {
    return ReadingsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      paramKey: paramKey ?? this.paramKey,
      value: value ?? this.value,
      takenAt: takenAt ?? this.takenAt,
      note: note ?? this.note,
      groupId: groupId ?? this.groupId,
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
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
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
          ..write('note: $note, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }
}

class $WaterChangesTable extends WaterChanges
    with TableInfo<$WaterChangesTable, WaterChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterChangesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountLitersMeta = const VerificationMeta(
    'amountLiters',
  );
  @override
  late final GeneratedColumn<double> amountLiters = GeneratedColumn<double>(
    'amount_liters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
    changedAt,
    amountLiters,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterChange> instance, {
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
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('amount_liters')) {
      context.handle(
        _amountLitersMeta,
        amountLiters.isAcceptableOrUnknown(
          data['amount_liters']!,
          _amountLitersMeta,
        ),
      );
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
  WaterChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      amountLiters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_liters'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $WaterChangesTable createAlias(String alias) {
    return $WaterChangesTable(attachedDatabase, alias);
  }
}

class WaterChange extends DataClass implements Insertable<WaterChange> {
  final int id;
  final int tankId;
  final DateTime changedAt;

  /// Volume of water exchanged, in litres. Optional.
  final double? amountLiters;

  /// Free-text note (e.g. salt brand). Optional.
  final String? note;
  const WaterChange({
    required this.id,
    required this.tankId,
    required this.changedAt,
    this.amountLiters,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['changed_at'] = Variable<DateTime>(changedAt);
    if (!nullToAbsent || amountLiters != null) {
      map['amount_liters'] = Variable<double>(amountLiters);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  WaterChangesCompanion toCompanion(bool nullToAbsent) {
    return WaterChangesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      changedAt: Value(changedAt),
      amountLiters: amountLiters == null && nullToAbsent
          ? const Value.absent()
          : Value(amountLiters),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory WaterChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterChange(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      amountLiters: serializer.fromJson<double?>(json['amountLiters']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'amountLiters': serializer.toJson<double?>(amountLiters),
      'note': serializer.toJson<String?>(note),
    };
  }

  WaterChange copyWith({
    int? id,
    int? tankId,
    DateTime? changedAt,
    Value<double?> amountLiters = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => WaterChange(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    changedAt: changedAt ?? this.changedAt,
    amountLiters: amountLiters.present ? amountLiters.value : this.amountLiters,
    note: note.present ? note.value : this.note,
  );
  WaterChange copyWithCompanion(WaterChangesCompanion data) {
    return WaterChange(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      amountLiters: data.amountLiters.present
          ? data.amountLiters.value
          : this.amountLiters,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterChange(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('changedAt: $changedAt, ')
          ..write('amountLiters: $amountLiters, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tankId, changedAt, amountLiters, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterChange &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.changedAt == this.changedAt &&
          other.amountLiters == this.amountLiters &&
          other.note == this.note);
}

class WaterChangesCompanion extends UpdateCompanion<WaterChange> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<DateTime> changedAt;
  final Value<double?> amountLiters;
  final Value<String?> note;
  const WaterChangesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.amountLiters = const Value.absent(),
    this.note = const Value.absent(),
  });
  WaterChangesCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required DateTime changedAt,
    this.amountLiters = const Value.absent(),
    this.note = const Value.absent(),
  }) : tankId = Value(tankId),
       changedAt = Value(changedAt);
  static Insertable<WaterChange> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<DateTime>? changedAt,
    Expression<double>? amountLiters,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (changedAt != null) 'changed_at': changedAt,
      if (amountLiters != null) 'amount_liters': amountLiters,
      if (note != null) 'note': note,
    });
  }

  WaterChangesCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<DateTime>? changedAt,
    Value<double?>? amountLiters,
    Value<String?>? note,
  }) {
    return WaterChangesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      changedAt: changedAt ?? this.changedAt,
      amountLiters: amountLiters ?? this.amountLiters,
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
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (amountLiters.present) {
      map['amount_liters'] = Variable<double>(amountLiters.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterChangesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('changedAt: $changedAt, ')
          ..write('amountLiters: $amountLiters, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $CarbonChangesTable extends CarbonChanges
    with TableInfo<$CarbonChangesTable, CarbonChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbonChangesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [id, tankId, changedAt, grams, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carbon_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarbonChange> instance, {
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
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
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
  CarbonChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbonChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $CarbonChangesTable createAlias(String alias) {
    return $CarbonChangesTable(attachedDatabase, alias);
  }
}

class CarbonChange extends DataClass implements Insertable<CarbonChange> {
  final int id;
  final int tankId;
  final DateTime changedAt;

  /// Weight of carbon used, in grams. Optional.
  final double? grams;

  /// Free-text note (e.g. brand). Optional.
  final String? note;
  const CarbonChange({
    required this.id,
    required this.tankId,
    required this.changedAt,
    this.grams,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['changed_at'] = Variable<DateTime>(changedAt);
    if (!nullToAbsent || grams != null) {
      map['grams'] = Variable<double>(grams);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  CarbonChangesCompanion toCompanion(bool nullToAbsent) {
    return CarbonChangesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      changedAt: Value(changedAt),
      grams: grams == null && nullToAbsent
          ? const Value.absent()
          : Value(grams),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory CarbonChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbonChange(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      grams: serializer.fromJson<double?>(json['grams']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'grams': serializer.toJson<double?>(grams),
      'note': serializer.toJson<String?>(note),
    };
  }

  CarbonChange copyWith({
    int? id,
    int? tankId,
    DateTime? changedAt,
    Value<double?> grams = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => CarbonChange(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    changedAt: changedAt ?? this.changedAt,
    grams: grams.present ? grams.value : this.grams,
    note: note.present ? note.value : this.note,
  );
  CarbonChange copyWithCompanion(CarbonChangesCompanion data) {
    return CarbonChange(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      grams: data.grams.present ? data.grams.value : this.grams,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbonChange(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('changedAt: $changedAt, ')
          ..write('grams: $grams, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tankId, changedAt, grams, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbonChange &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.changedAt == this.changedAt &&
          other.grams == this.grams &&
          other.note == this.note);
}

class CarbonChangesCompanion extends UpdateCompanion<CarbonChange> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<DateTime> changedAt;
  final Value<double?> grams;
  final Value<String?> note;
  const CarbonChangesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.grams = const Value.absent(),
    this.note = const Value.absent(),
  });
  CarbonChangesCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required DateTime changedAt,
    this.grams = const Value.absent(),
    this.note = const Value.absent(),
  }) : tankId = Value(tankId),
       changedAt = Value(changedAt);
  static Insertable<CarbonChange> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<DateTime>? changedAt,
    Expression<double>? grams,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (changedAt != null) 'changed_at': changedAt,
      if (grams != null) 'grams': grams,
      if (note != null) 'note': note,
    });
  }

  CarbonChangesCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<DateTime>? changedAt,
    Value<double?>? grams,
    Value<String?>? note,
  }) {
    return CarbonChangesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      changedAt: changedAt ?? this.changedAt,
      grams: grams ?? this.grams,
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
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbonChangesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('changedAt: $changedAt, ')
          ..write('grams: $grams, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $EquipmentCleaningsTable extends EquipmentCleanings
    with TableInfo<$EquipmentCleaningsTable, EquipmentCleaning> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentCleaningsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cleanedAtMeta = const VerificationMeta(
    'cleanedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cleanedAt = GeneratedColumn<DateTime>(
    'cleaned_at',
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
  List<GeneratedColumn> get $columns => [id, tankId, cleanedAt, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_cleanings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentCleaning> instance, {
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
    if (data.containsKey('cleaned_at')) {
      context.handle(
        _cleanedAtMeta,
        cleanedAt.isAcceptableOrUnknown(data['cleaned_at']!, _cleanedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cleanedAtMeta);
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
  EquipmentCleaning map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentCleaning(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      cleanedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cleaned_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $EquipmentCleaningsTable createAlias(String alias) {
    return $EquipmentCleaningsTable(attachedDatabase, alias);
  }
}

class EquipmentCleaning extends DataClass
    implements Insertable<EquipmentCleaning> {
  final int id;
  final int tankId;
  final DateTime cleanedAt;

  /// Free-text note (e.g. the equipment cleaned). Optional.
  final String? note;
  const EquipmentCleaning({
    required this.id,
    required this.tankId,
    required this.cleanedAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['cleaned_at'] = Variable<DateTime>(cleanedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  EquipmentCleaningsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentCleaningsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      cleanedAt: Value(cleanedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory EquipmentCleaning.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentCleaning(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      cleanedAt: serializer.fromJson<DateTime>(json['cleanedAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'cleanedAt': serializer.toJson<DateTime>(cleanedAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  EquipmentCleaning copyWith({
    int? id,
    int? tankId,
    DateTime? cleanedAt,
    Value<String?> note = const Value.absent(),
  }) => EquipmentCleaning(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    cleanedAt: cleanedAt ?? this.cleanedAt,
    note: note.present ? note.value : this.note,
  );
  EquipmentCleaning copyWithCompanion(EquipmentCleaningsCompanion data) {
    return EquipmentCleaning(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      cleanedAt: data.cleanedAt.present ? data.cleanedAt.value : this.cleanedAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentCleaning(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('cleanedAt: $cleanedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tankId, cleanedAt, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentCleaning &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.cleanedAt == this.cleanedAt &&
          other.note == this.note);
}

class EquipmentCleaningsCompanion extends UpdateCompanion<EquipmentCleaning> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<DateTime> cleanedAt;
  final Value<String?> note;
  const EquipmentCleaningsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.cleanedAt = const Value.absent(),
    this.note = const Value.absent(),
  });
  EquipmentCleaningsCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required DateTime cleanedAt,
    this.note = const Value.absent(),
  }) : tankId = Value(tankId),
       cleanedAt = Value(cleanedAt);
  static Insertable<EquipmentCleaning> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<DateTime>? cleanedAt,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (cleanedAt != null) 'cleaned_at': cleanedAt,
      if (note != null) 'note': note,
    });
  }

  EquipmentCleaningsCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<DateTime>? cleanedAt,
    Value<String?>? note,
  }) {
    return EquipmentCleaningsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      cleanedAt: cleanedAt ?? this.cleanedAt,
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
    if (cleanedAt.present) {
      map['cleaned_at'] = Variable<DateTime>(cleanedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentCleaningsCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('cleanedAt: $cleanedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $RatioVisibilitiesTable extends RatioVisibilities
    with TableInfo<$RatioVisibilitiesTable, RatioVisibility> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatioVisibilitiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _ratioKeyMeta = const VerificationMeta(
    'ratioKey',
  );
  @override
  late final GeneratedColumn<String> ratioKey = GeneratedColumn<String>(
    'ratio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibleMeta = const VerificationMeta(
    'visible',
  );
  @override
  late final GeneratedColumn<bool> visible = GeneratedColumn<bool>(
    'visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visible" IN (0, 1))',
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
    defaultValue: const Constant(1000),
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
    tankId,
    ratioKey,
    visible,
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
  static const String $name = 'ratio_visibilities';
  @override
  VerificationContext validateIntegrity(
    Insertable<RatioVisibility> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('ratio_key')) {
      context.handle(
        _ratioKeyMeta,
        ratioKey.isAcceptableOrUnknown(data['ratio_key']!, _ratioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_ratioKeyMeta);
    }
    if (data.containsKey('visible')) {
      context.handle(
        _visibleMeta,
        visible.isAcceptableOrUnknown(data['visible']!, _visibleMeta),
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
  Set<GeneratedColumn> get $primaryKey => {tankId, ratioKey};
  @override
  RatioVisibility map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatioVisibility(
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      ratioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ratio_key'],
      )!,
      visible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visible'],
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
  $RatioVisibilitiesTable createAlias(String alias) {
    return $RatioVisibilitiesTable(attachedDatabase, alias);
  }
}

class RatioVisibility extends DataClass implements Insertable<RatioVisibility> {
  final int tankId;
  final String ratioKey;
  final bool visible;

  /// Dashboard position, shared with `TrackedParameters.displayOrder`. Defaults
  /// high so ratio cards sit after measurements until the user reorders them.
  final int displayOrder;

  /// Per-tank zone bounds (in the displayed-metric space). Null on all four =
  /// fall back to the kind's recommended defaults.
  final double? amberLow;
  final double? greenLow;
  final double? greenHigh;
  final double? amberHigh;
  const RatioVisibility({
    required this.tankId,
    required this.ratioKey,
    required this.visible,
    required this.displayOrder,
    this.amberLow,
    this.greenLow,
    this.greenHigh,
    this.amberHigh,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tank_id'] = Variable<int>(tankId);
    map['ratio_key'] = Variable<String>(ratioKey);
    map['visible'] = Variable<bool>(visible);
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

  RatioVisibilitiesCompanion toCompanion(bool nullToAbsent) {
    return RatioVisibilitiesCompanion(
      tankId: Value(tankId),
      ratioKey: Value(ratioKey),
      visible: Value(visible),
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

  factory RatioVisibility.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatioVisibility(
      tankId: serializer.fromJson<int>(json['tankId']),
      ratioKey: serializer.fromJson<String>(json['ratioKey']),
      visible: serializer.fromJson<bool>(json['visible']),
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
      'tankId': serializer.toJson<int>(tankId),
      'ratioKey': serializer.toJson<String>(ratioKey),
      'visible': serializer.toJson<bool>(visible),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'amberLow': serializer.toJson<double?>(amberLow),
      'greenLow': serializer.toJson<double?>(greenLow),
      'greenHigh': serializer.toJson<double?>(greenHigh),
      'amberHigh': serializer.toJson<double?>(amberHigh),
    };
  }

  RatioVisibility copyWith({
    int? tankId,
    String? ratioKey,
    bool? visible,
    int? displayOrder,
    Value<double?> amberLow = const Value.absent(),
    Value<double?> greenLow = const Value.absent(),
    Value<double?> greenHigh = const Value.absent(),
    Value<double?> amberHigh = const Value.absent(),
  }) => RatioVisibility(
    tankId: tankId ?? this.tankId,
    ratioKey: ratioKey ?? this.ratioKey,
    visible: visible ?? this.visible,
    displayOrder: displayOrder ?? this.displayOrder,
    amberLow: amberLow.present ? amberLow.value : this.amberLow,
    greenLow: greenLow.present ? greenLow.value : this.greenLow,
    greenHigh: greenHigh.present ? greenHigh.value : this.greenHigh,
    amberHigh: amberHigh.present ? amberHigh.value : this.amberHigh,
  );
  RatioVisibility copyWithCompanion(RatioVisibilitiesCompanion data) {
    return RatioVisibility(
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      ratioKey: data.ratioKey.present ? data.ratioKey.value : this.ratioKey,
      visible: data.visible.present ? data.visible.value : this.visible,
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
    return (StringBuffer('RatioVisibility(')
          ..write('tankId: $tankId, ')
          ..write('ratioKey: $ratioKey, ')
          ..write('visible: $visible, ')
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
    tankId,
    ratioKey,
    visible,
    displayOrder,
    amberLow,
    greenLow,
    greenHigh,
    amberHigh,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatioVisibility &&
          other.tankId == this.tankId &&
          other.ratioKey == this.ratioKey &&
          other.visible == this.visible &&
          other.displayOrder == this.displayOrder &&
          other.amberLow == this.amberLow &&
          other.greenLow == this.greenLow &&
          other.greenHigh == this.greenHigh &&
          other.amberHigh == this.amberHigh);
}

class RatioVisibilitiesCompanion extends UpdateCompanion<RatioVisibility> {
  final Value<int> tankId;
  final Value<String> ratioKey;
  final Value<bool> visible;
  final Value<int> displayOrder;
  final Value<double?> amberLow;
  final Value<double?> greenLow;
  final Value<double?> greenHigh;
  final Value<double?> amberHigh;
  final Value<int> rowid;
  const RatioVisibilitiesCompanion({
    this.tankId = const Value.absent(),
    this.ratioKey = const Value.absent(),
    this.visible = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.amberLow = const Value.absent(),
    this.greenLow = const Value.absent(),
    this.greenHigh = const Value.absent(),
    this.amberHigh = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatioVisibilitiesCompanion.insert({
    required int tankId,
    required String ratioKey,
    this.visible = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.amberLow = const Value.absent(),
    this.greenLow = const Value.absent(),
    this.greenHigh = const Value.absent(),
    this.amberHigh = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tankId = Value(tankId),
       ratioKey = Value(ratioKey);
  static Insertable<RatioVisibility> custom({
    Expression<int>? tankId,
    Expression<String>? ratioKey,
    Expression<bool>? visible,
    Expression<int>? displayOrder,
    Expression<double>? amberLow,
    Expression<double>? greenLow,
    Expression<double>? greenHigh,
    Expression<double>? amberHigh,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tankId != null) 'tank_id': tankId,
      if (ratioKey != null) 'ratio_key': ratioKey,
      if (visible != null) 'visible': visible,
      if (displayOrder != null) 'display_order': displayOrder,
      if (amberLow != null) 'amber_low': amberLow,
      if (greenLow != null) 'green_low': greenLow,
      if (greenHigh != null) 'green_high': greenHigh,
      if (amberHigh != null) 'amber_high': amberHigh,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatioVisibilitiesCompanion copyWith({
    Value<int>? tankId,
    Value<String>? ratioKey,
    Value<bool>? visible,
    Value<int>? displayOrder,
    Value<double?>? amberLow,
    Value<double?>? greenLow,
    Value<double?>? greenHigh,
    Value<double?>? amberHigh,
    Value<int>? rowid,
  }) {
    return RatioVisibilitiesCompanion(
      tankId: tankId ?? this.tankId,
      ratioKey: ratioKey ?? this.ratioKey,
      visible: visible ?? this.visible,
      displayOrder: displayOrder ?? this.displayOrder,
      amberLow: amberLow ?? this.amberLow,
      greenLow: greenLow ?? this.greenLow,
      greenHigh: greenHigh ?? this.greenHigh,
      amberHigh: amberHigh ?? this.amberHigh,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tankId.present) {
      map['tank_id'] = Variable<int>(tankId.value);
    }
    if (ratioKey.present) {
      map['ratio_key'] = Variable<String>(ratioKey.value);
    }
    if (visible.present) {
      map['visible'] = Variable<bool>(visible.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatioVisibilitiesCompanion(')
          ..write('tankId: $tankId, ')
          ..write('ratioKey: $ratioKey, ')
          ..write('visible: $visible, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('amberLow: $amberLow, ')
          ..write('greenLow: $greenLow, ')
          ..write('greenHigh: $greenHigh, ')
          ..write('amberHigh: $amberHigh, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DosingEntriesTable extends DosingEntries
    with TableInfo<$DosingEntriesTable, DosingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DosingEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _productKeyMeta = const VerificationMeta(
    'productKey',
  );
  @override
  late final GeneratedColumn<String> productKey = GeneratedColumn<String>(
    'product_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _programMeta = const VerificationMeta(
    'program',
  );
  @override
  late final GeneratedColumn<String> program = GeneratedColumn<String>(
    'program',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productMeta = const VerificationMeta(
    'product',
  );
  @override
  late final GeneratedColumn<String> product = GeneratedColumn<String>(
    'product',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elementKeyMeta = const VerificationMeta(
    'elementKey',
  );
  @override
  late final GeneratedColumn<String> elementKey = GeneratedColumn<String>(
    'element_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountUnitMeta = const VerificationMeta(
    'amountUnit',
  );
  @override
  late final GeneratedColumn<String> amountUnit = GeneratedColumn<String>(
    'amount_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doseTimeMeta = const VerificationMeta(
    'doseTime',
  );
  @override
  late final GeneratedColumn<String> doseTime = GeneratedColumn<String>(
    'dose_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindEnabledMeta = const VerificationMeta(
    'remindEnabled',
  );
  @override
  late final GeneratedColumn<bool> remindEnabled = GeneratedColumn<bool>(
    'remind_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("remind_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(DosingState.active.name),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    productKey,
    vendor,
    program,
    product,
    elementKey,
    amount,
    amountUnit,
    basis,
    frequency,
    intervalDays,
    weekdays,
    doseTime,
    remindEnabled,
    note,
    displayOrder,
    createdAt,
    startedAt,
    endedAt,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dosing_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DosingEntry> instance, {
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
    if (data.containsKey('product_key')) {
      context.handle(
        _productKeyMeta,
        productKey.isAcceptableOrUnknown(data['product_key']!, _productKeyMeta),
      );
    }
    if (data.containsKey('vendor')) {
      context.handle(
        _vendorMeta,
        vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta),
      );
    }
    if (data.containsKey('program')) {
      context.handle(
        _programMeta,
        program.isAcceptableOrUnknown(data['program']!, _programMeta),
      );
    }
    if (data.containsKey('product')) {
      context.handle(
        _productMeta,
        product.isAcceptableOrUnknown(data['product']!, _productMeta),
      );
    } else if (isInserting) {
      context.missing(_productMeta);
    }
    if (data.containsKey('element_key')) {
      context.handle(
        _elementKeyMeta,
        elementKey.isAcceptableOrUnknown(data['element_key']!, _elementKeyMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('amount_unit')) {
      context.handle(
        _amountUnitMeta,
        amountUnit.isAcceptableOrUnknown(data['amount_unit']!, _amountUnitMeta),
      );
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('dose_time')) {
      context.handle(
        _doseTimeMeta,
        doseTime.isAcceptableOrUnknown(data['dose_time']!, _doseTimeMeta),
      );
    }
    if (data.containsKey('remind_enabled')) {
      context.handle(
        _remindEnabledMeta,
        remindEnabled.isAcceptableOrUnknown(
          data['remind_enabled']!,
          _remindEnabledMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DosingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DosingEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      productKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_key'],
      ),
      vendor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor'],
      ),
      program: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program'],
      ),
      product: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product'],
      )!,
      elementKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_key'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      amountUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_unit'],
      ),
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      ),
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      ),
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      doseTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_time'],
      ),
      remindEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}remind_enabled'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $DosingEntriesTable createAlias(String alias) {
    return $DosingEntriesTable(attachedDatabase, alias);
  }
}

class DosingEntry extends DataClass implements Insertable<DosingEntry> {
  final int id;
  final int tankId;

  /// Stable `SupplementProduct.key` from the catalog, or null for a custom
  /// (free-text) entry.
  final String? productKey;

  /// Denormalized display names (the catalog values at entry time, or the
  /// user's free text for a custom entry).
  final String? vendor;
  final String? program;
  final String product;

  /// Target element as a real `Readings.paramKey` (e.g. `alkalinity`), or null
  /// for trace/multi-element products.
  final String? elementKey;

  /// Dosage amount in its canonical unit (ml or g), optional.
  final double? amount;

  /// Amount unit, stored as [DoseUnit.name] (`ml`/`g`). Optional.
  final String? amountUnit;

  /// Whether [amount] is per day or per dose, stored as [DoseBasis.name].
  final String? basis;

  /// Schedule frequency, stored as [DoseFrequency.name]. Optional/descriptive.
  final String? frequency;

  /// Interval in days when [frequency] is `everyNDays`.
  final int? intervalDays;

  /// Comma-separated weekday numbers (1=Mon … 7=Sun) when [frequency] is
  /// `weekly`.
  final String? weekdays;

  /// Time of day as `HH:mm`, optional.
  final String? doseTime;

  /// Whether this entry fires dosing reminders (U2). Opt-in (default off);
  /// only effective while the entry is active, has a parsable [doseTime], and
  /// the Settings master switch for dosing reminders is on.
  final bool remindEnabled;
  final String? note;
  final int displayOrder;
  final DateTime createdAt;

  /// When this dose segment became active. A dosing plan is a chain of dated
  /// segments: editing a dose-affecting field ends the current segment and
  /// starts a new one. Nullable only so the migration can backfill it from
  /// [createdAt] for pre-history rows; new inserts always set it.
  final DateTime? startedAt;

  /// When this segment stopped being active — set when it is superseded by an
  /// edit or the supplement is stopped. Null = current/active.
  final DateTime? endedAt;

  /// Lifecycle state, stored as [DosingState.name] (`active`/`ended`/`paused`).
  /// Only `active` rows show in the Dosing tab and feed the calculator.
  final String state;
  const DosingEntry({
    required this.id,
    required this.tankId,
    this.productKey,
    this.vendor,
    this.program,
    required this.product,
    this.elementKey,
    this.amount,
    this.amountUnit,
    this.basis,
    this.frequency,
    this.intervalDays,
    this.weekdays,
    this.doseTime,
    required this.remindEnabled,
    this.note,
    required this.displayOrder,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    if (!nullToAbsent || productKey != null) {
      map['product_key'] = Variable<String>(productKey);
    }
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    if (!nullToAbsent || program != null) {
      map['program'] = Variable<String>(program);
    }
    map['product'] = Variable<String>(product);
    if (!nullToAbsent || elementKey != null) {
      map['element_key'] = Variable<String>(elementKey);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || amountUnit != null) {
      map['amount_unit'] = Variable<String>(amountUnit);
    }
    if (!nullToAbsent || basis != null) {
      map['basis'] = Variable<String>(basis);
    }
    if (!nullToAbsent || frequency != null) {
      map['frequency'] = Variable<String>(frequency);
    }
    if (!nullToAbsent || intervalDays != null) {
      map['interval_days'] = Variable<int>(intervalDays);
    }
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || doseTime != null) {
      map['dose_time'] = Variable<String>(doseTime);
    }
    map['remind_enabled'] = Variable<bool>(remindEnabled);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['display_order'] = Variable<int>(displayOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['state'] = Variable<String>(state);
    return map;
  }

  DosingEntriesCompanion toCompanion(bool nullToAbsent) {
    return DosingEntriesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      productKey: productKey == null && nullToAbsent
          ? const Value.absent()
          : Value(productKey),
      vendor: vendor == null && nullToAbsent
          ? const Value.absent()
          : Value(vendor),
      program: program == null && nullToAbsent
          ? const Value.absent()
          : Value(program),
      product: Value(product),
      elementKey: elementKey == null && nullToAbsent
          ? const Value.absent()
          : Value(elementKey),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      amountUnit: amountUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(amountUnit),
      basis: basis == null && nullToAbsent
          ? const Value.absent()
          : Value(basis),
      frequency: frequency == null && nullToAbsent
          ? const Value.absent()
          : Value(frequency),
      intervalDays: intervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalDays),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      doseTime: doseTime == null && nullToAbsent
          ? const Value.absent()
          : Value(doseTime),
      remindEnabled: Value(remindEnabled),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      displayOrder: Value(displayOrder),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      state: Value(state),
    );
  }

  factory DosingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DosingEntry(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      productKey: serializer.fromJson<String?>(json['productKey']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      program: serializer.fromJson<String?>(json['program']),
      product: serializer.fromJson<String>(json['product']),
      elementKey: serializer.fromJson<String?>(json['elementKey']),
      amount: serializer.fromJson<double?>(json['amount']),
      amountUnit: serializer.fromJson<String?>(json['amountUnit']),
      basis: serializer.fromJson<String?>(json['basis']),
      frequency: serializer.fromJson<String?>(json['frequency']),
      intervalDays: serializer.fromJson<int?>(json['intervalDays']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      doseTime: serializer.fromJson<String?>(json['doseTime']),
      remindEnabled: serializer.fromJson<bool>(json['remindEnabled']),
      note: serializer.fromJson<String?>(json['note']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'productKey': serializer.toJson<String?>(productKey),
      'vendor': serializer.toJson<String?>(vendor),
      'program': serializer.toJson<String?>(program),
      'product': serializer.toJson<String>(product),
      'elementKey': serializer.toJson<String?>(elementKey),
      'amount': serializer.toJson<double?>(amount),
      'amountUnit': serializer.toJson<String?>(amountUnit),
      'basis': serializer.toJson<String?>(basis),
      'frequency': serializer.toJson<String?>(frequency),
      'intervalDays': serializer.toJson<int?>(intervalDays),
      'weekdays': serializer.toJson<String?>(weekdays),
      'doseTime': serializer.toJson<String?>(doseTime),
      'remindEnabled': serializer.toJson<bool>(remindEnabled),
      'note': serializer.toJson<String?>(note),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'state': serializer.toJson<String>(state),
    };
  }

  DosingEntry copyWith({
    int? id,
    int? tankId,
    Value<String?> productKey = const Value.absent(),
    Value<String?> vendor = const Value.absent(),
    Value<String?> program = const Value.absent(),
    String? product,
    Value<String?> elementKey = const Value.absent(),
    Value<double?> amount = const Value.absent(),
    Value<String?> amountUnit = const Value.absent(),
    Value<String?> basis = const Value.absent(),
    Value<String?> frequency = const Value.absent(),
    Value<int?> intervalDays = const Value.absent(),
    Value<String?> weekdays = const Value.absent(),
    Value<String?> doseTime = const Value.absent(),
    bool? remindEnabled,
    Value<String?> note = const Value.absent(),
    int? displayOrder,
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
    String? state,
  }) => DosingEntry(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    productKey: productKey.present ? productKey.value : this.productKey,
    vendor: vendor.present ? vendor.value : this.vendor,
    program: program.present ? program.value : this.program,
    product: product ?? this.product,
    elementKey: elementKey.present ? elementKey.value : this.elementKey,
    amount: amount.present ? amount.value : this.amount,
    amountUnit: amountUnit.present ? amountUnit.value : this.amountUnit,
    basis: basis.present ? basis.value : this.basis,
    frequency: frequency.present ? frequency.value : this.frequency,
    intervalDays: intervalDays.present ? intervalDays.value : this.intervalDays,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    doseTime: doseTime.present ? doseTime.value : this.doseTime,
    remindEnabled: remindEnabled ?? this.remindEnabled,
    note: note.present ? note.value : this.note,
    displayOrder: displayOrder ?? this.displayOrder,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    state: state ?? this.state,
  );
  DosingEntry copyWithCompanion(DosingEntriesCompanion data) {
    return DosingEntry(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      productKey: data.productKey.present
          ? data.productKey.value
          : this.productKey,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      program: data.program.present ? data.program.value : this.program,
      product: data.product.present ? data.product.value : this.product,
      elementKey: data.elementKey.present
          ? data.elementKey.value
          : this.elementKey,
      amount: data.amount.present ? data.amount.value : this.amount,
      amountUnit: data.amountUnit.present
          ? data.amountUnit.value
          : this.amountUnit,
      basis: data.basis.present ? data.basis.value : this.basis,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      doseTime: data.doseTime.present ? data.doseTime.value : this.doseTime,
      remindEnabled: data.remindEnabled.present
          ? data.remindEnabled.value
          : this.remindEnabled,
      note: data.note.present ? data.note.value : this.note,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DosingEntry(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('productKey: $productKey, ')
          ..write('vendor: $vendor, ')
          ..write('program: $program, ')
          ..write('product: $product, ')
          ..write('elementKey: $elementKey, ')
          ..write('amount: $amount, ')
          ..write('amountUnit: $amountUnit, ')
          ..write('basis: $basis, ')
          ..write('frequency: $frequency, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('weekdays: $weekdays, ')
          ..write('doseTime: $doseTime, ')
          ..write('remindEnabled: $remindEnabled, ')
          ..write('note: $note, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tankId,
    productKey,
    vendor,
    program,
    product,
    elementKey,
    amount,
    amountUnit,
    basis,
    frequency,
    intervalDays,
    weekdays,
    doseTime,
    remindEnabled,
    note,
    displayOrder,
    createdAt,
    startedAt,
    endedAt,
    state,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DosingEntry &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.productKey == this.productKey &&
          other.vendor == this.vendor &&
          other.program == this.program &&
          other.product == this.product &&
          other.elementKey == this.elementKey &&
          other.amount == this.amount &&
          other.amountUnit == this.amountUnit &&
          other.basis == this.basis &&
          other.frequency == this.frequency &&
          other.intervalDays == this.intervalDays &&
          other.weekdays == this.weekdays &&
          other.doseTime == this.doseTime &&
          other.remindEnabled == this.remindEnabled &&
          other.note == this.note &&
          other.displayOrder == this.displayOrder &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.state == this.state);
}

class DosingEntriesCompanion extends UpdateCompanion<DosingEntry> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String?> productKey;
  final Value<String?> vendor;
  final Value<String?> program;
  final Value<String> product;
  final Value<String?> elementKey;
  final Value<double?> amount;
  final Value<String?> amountUnit;
  final Value<String?> basis;
  final Value<String?> frequency;
  final Value<int?> intervalDays;
  final Value<String?> weekdays;
  final Value<String?> doseTime;
  final Value<bool> remindEnabled;
  final Value<String?> note;
  final Value<int> displayOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> state;
  const DosingEntriesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.productKey = const Value.absent(),
    this.vendor = const Value.absent(),
    this.program = const Value.absent(),
    this.product = const Value.absent(),
    this.elementKey = const Value.absent(),
    this.amount = const Value.absent(),
    this.amountUnit = const Value.absent(),
    this.basis = const Value.absent(),
    this.frequency = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.doseTime = const Value.absent(),
    this.remindEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.state = const Value.absent(),
  });
  DosingEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    this.productKey = const Value.absent(),
    this.vendor = const Value.absent(),
    this.program = const Value.absent(),
    required String product,
    this.elementKey = const Value.absent(),
    this.amount = const Value.absent(),
    this.amountUnit = const Value.absent(),
    this.basis = const Value.absent(),
    this.frequency = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.doseTime = const Value.absent(),
    this.remindEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.state = const Value.absent(),
  }) : tankId = Value(tankId),
       product = Value(product);
  static Insertable<DosingEntry> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<String>? productKey,
    Expression<String>? vendor,
    Expression<String>? program,
    Expression<String>? product,
    Expression<String>? elementKey,
    Expression<double>? amount,
    Expression<String>? amountUnit,
    Expression<String>? basis,
    Expression<String>? frequency,
    Expression<int>? intervalDays,
    Expression<String>? weekdays,
    Expression<String>? doseTime,
    Expression<bool>? remindEnabled,
    Expression<String>? note,
    Expression<int>? displayOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? state,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (productKey != null) 'product_key': productKey,
      if (vendor != null) 'vendor': vendor,
      if (program != null) 'program': program,
      if (product != null) 'product': product,
      if (elementKey != null) 'element_key': elementKey,
      if (amount != null) 'amount': amount,
      if (amountUnit != null) 'amount_unit': amountUnit,
      if (basis != null) 'basis': basis,
      if (frequency != null) 'frequency': frequency,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (weekdays != null) 'weekdays': weekdays,
      if (doseTime != null) 'dose_time': doseTime,
      if (remindEnabled != null) 'remind_enabled': remindEnabled,
      if (note != null) 'note': note,
      if (displayOrder != null) 'display_order': displayOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (state != null) 'state': state,
    });
  }

  DosingEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String?>? productKey,
    Value<String?>? vendor,
    Value<String?>? program,
    Value<String>? product,
    Value<String?>? elementKey,
    Value<double?>? amount,
    Value<String?>? amountUnit,
    Value<String?>? basis,
    Value<String?>? frequency,
    Value<int?>? intervalDays,
    Value<String?>? weekdays,
    Value<String?>? doseTime,
    Value<bool>? remindEnabled,
    Value<String?>? note,
    Value<int>? displayOrder,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? state,
  }) {
    return DosingEntriesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      productKey: productKey ?? this.productKey,
      vendor: vendor ?? this.vendor,
      program: program ?? this.program,
      product: product ?? this.product,
      elementKey: elementKey ?? this.elementKey,
      amount: amount ?? this.amount,
      amountUnit: amountUnit ?? this.amountUnit,
      basis: basis ?? this.basis,
      frequency: frequency ?? this.frequency,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      doseTime: doseTime ?? this.doseTime,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      note: note ?? this.note,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      state: state ?? this.state,
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
    if (productKey.present) {
      map['product_key'] = Variable<String>(productKey.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (program.present) {
      map['program'] = Variable<String>(program.value);
    }
    if (product.present) {
      map['product'] = Variable<String>(product.value);
    }
    if (elementKey.present) {
      map['element_key'] = Variable<String>(elementKey.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (amountUnit.present) {
      map['amount_unit'] = Variable<String>(amountUnit.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (doseTime.present) {
      map['dose_time'] = Variable<String>(doseTime.value);
    }
    if (remindEnabled.present) {
      map['remind_enabled'] = Variable<bool>(remindEnabled.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DosingEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('productKey: $productKey, ')
          ..write('vendor: $vendor, ')
          ..write('program: $program, ')
          ..write('product: $product, ')
          ..write('elementKey: $elementKey, ')
          ..write('amount: $amount, ')
          ..write('amountUnit: $amountUnit, ')
          ..write('basis: $basis, ')
          ..write('frequency: $frequency, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('weekdays: $weekdays, ')
          ..write('doseTime: $doseTime, ')
          ..write('remindEnabled: $remindEnabled, ')
          ..write('note: $note, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }
}

class $ReadingTemplatesTable extends ReadingTemplates
    with TableInfo<$ReadingTemplatesTable, ReadingTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingTemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _paramKeysMeta = const VerificationMeta(
    'paramKeys',
  );
  @override
  late final GeneratedColumn<String> paramKeys = GeneratedColumn<String>(
    'param_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    name,
    paramKeys,
    displayOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingTemplate> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('param_keys')) {
      context.handle(
        _paramKeysMeta,
        paramKeys.isAcceptableOrUnknown(data['param_keys']!, _paramKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_paramKeysMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      paramKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}param_keys'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $ReadingTemplatesTable createAlias(String alias) {
    return $ReadingTemplatesTable(attachedDatabase, alias);
  }
}

class ReadingTemplate extends DataClass implements Insertable<ReadingTemplate> {
  final int id;
  final int tankId;
  final String name;

  /// JSON array of catalog `paramKey` strings, e.g. `["alkalinity","calcium"]`.
  final String paramKeys;

  /// Position of the set's chip on the Add Reading screen.
  final int displayOrder;
  const ReadingTemplate({
    required this.id,
    required this.tankId,
    required this.name,
    required this.paramKeys,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    map['name'] = Variable<String>(name);
    map['param_keys'] = Variable<String>(paramKeys);
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  ReadingTemplatesCompanion toCompanion(bool nullToAbsent) {
    return ReadingTemplatesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      name: Value(name),
      paramKeys: Value(paramKeys),
      displayOrder: Value(displayOrder),
    );
  }

  factory ReadingTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingTemplate(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      name: serializer.fromJson<String>(json['name']),
      paramKeys: serializer.fromJson<String>(json['paramKeys']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'name': serializer.toJson<String>(name),
      'paramKeys': serializer.toJson<String>(paramKeys),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  ReadingTemplate copyWith({
    int? id,
    int? tankId,
    String? name,
    String? paramKeys,
    int? displayOrder,
  }) => ReadingTemplate(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    name: name ?? this.name,
    paramKeys: paramKeys ?? this.paramKeys,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  ReadingTemplate copyWithCompanion(ReadingTemplatesCompanion data) {
    return ReadingTemplate(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      name: data.name.present ? data.name.value : this.name,
      paramKeys: data.paramKeys.present ? data.paramKeys.value : this.paramKeys,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingTemplate(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('name: $name, ')
          ..write('paramKeys: $paramKeys, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tankId, name, paramKeys, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingTemplate &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.name == this.name &&
          other.paramKeys == this.paramKeys &&
          other.displayOrder == this.displayOrder);
}

class ReadingTemplatesCompanion extends UpdateCompanion<ReadingTemplate> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String> name;
  final Value<String> paramKeys;
  final Value<int> displayOrder;
  const ReadingTemplatesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.name = const Value.absent(),
    this.paramKeys = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  ReadingTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    required String name,
    required String paramKeys,
    this.displayOrder = const Value.absent(),
  }) : tankId = Value(tankId),
       name = Value(name),
       paramKeys = Value(paramKeys);
  static Insertable<ReadingTemplate> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<String>? name,
    Expression<String>? paramKeys,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (name != null) 'name': name,
      if (paramKeys != null) 'param_keys': paramKeys,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  ReadingTemplatesCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String>? name,
    Value<String>? paramKeys,
    Value<int>? displayOrder,
  }) {
    return ReadingTemplatesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      name: name ?? this.name,
      paramKeys: paramKeys ?? this.paramKeys,
      displayOrder: displayOrder ?? this.displayOrder,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (paramKeys.present) {
      map['param_keys'] = Variable<String>(paramKeys.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('name: $name, ')
          ..write('paramKeys: $paramKeys, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceSchedulesTable extends MaintenanceSchedules
    with TableInfo<$MaintenanceSchedulesTable, MaintenanceSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceSchedulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cadenceDaysMeta = const VerificationMeta(
    'cadenceDays',
  );
  @override
  late final GeneratedColumn<int> cadenceDays = GeneratedColumn<int>(
    'cadence_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
    'scheduled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDoneAtMeta = const VerificationMeta(
    'lastDoneAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastDoneAt = GeneratedColumn<DateTime>(
    'last_done_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindEnabledMeta = const VerificationMeta(
    'remindEnabled',
  );
  @override
  late final GeneratedColumn<bool> remindEnabled = GeneratedColumn<bool>(
    'remind_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("remind_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    actionType,
    title,
    cadenceDays,
    scheduledAt,
    lastDoneAt,
    remindEnabled,
    note,
    displayOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceSchedule> instance, {
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
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('cadence_days')) {
      context.handle(
        _cadenceDaysMeta,
        cadenceDays.isAcceptableOrUnknown(
          data['cadence_days']!,
          _cadenceDaysMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    }
    if (data.containsKey('last_done_at')) {
      context.handle(
        _lastDoneAtMeta,
        lastDoneAt.isAcceptableOrUnknown(
          data['last_done_at']!,
          _lastDoneAtMeta,
        ),
      );
    }
    if (data.containsKey('remind_enabled')) {
      context.handle(
        _remindEnabledMeta,
        remindEnabled.isAcceptableOrUnknown(
          data['remind_enabled']!,
          _remindEnabledMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      cadenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadence_days'],
      ),
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_at'],
      ),
      lastDoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_done_at'],
      ),
      remindEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}remind_enabled'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $MaintenanceSchedulesTable createAlias(String alias) {
    return $MaintenanceSchedulesTable(attachedDatabase, alias);
  }
}

class MaintenanceSchedule extends DataClass
    implements Insertable<MaintenanceSchedule> {
  final int id;
  final int tankId;

  /// [MaintenanceActionType.name] (`waterChange`/`carbonChange`/
  /// `equipmentCleaning`), or null = custom task ([title] required then).
  final String? actionType;

  /// Display name for a custom task; null for typed rows, which render the
  /// localized action name instead.
  final String? title;

  /// Repeat every N days after the last completion; null = one-off (due at
  /// [scheduledAt], retired once done).
  final int? cadenceDays;

  /// Planned first (or one-off) due date; ignored once the task has ever been
  /// completed.
  final DateTime? scheduledAt;

  /// Completion stamp for **custom** rows only (typed rows read their action
  /// log). For a one-off custom task, non-null means finished.
  final DateTime? lastDoneAt;

  /// Per-plan reminder opt-out; the Settings maintenance master switch still
  /// gates all of them.
  final bool remindEnabled;
  final String? note;

  /// Position in the schedule list / due-chip row.
  final int displayOrder;
  const MaintenanceSchedule({
    required this.id,
    required this.tankId,
    this.actionType,
    this.title,
    this.cadenceDays,
    this.scheduledAt,
    this.lastDoneAt,
    required this.remindEnabled,
    this.note,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tank_id'] = Variable<int>(tankId);
    if (!nullToAbsent || actionType != null) {
      map['action_type'] = Variable<String>(actionType);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || cadenceDays != null) {
      map['cadence_days'] = Variable<int>(cadenceDays);
    }
    if (!nullToAbsent || scheduledAt != null) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    }
    if (!nullToAbsent || lastDoneAt != null) {
      map['last_done_at'] = Variable<DateTime>(lastDoneAt);
    }
    map['remind_enabled'] = Variable<bool>(remindEnabled);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  MaintenanceSchedulesCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceSchedulesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      actionType: actionType == null && nullToAbsent
          ? const Value.absent()
          : Value(actionType),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      cadenceDays: cadenceDays == null && nullToAbsent
          ? const Value.absent()
          : Value(cadenceDays),
      scheduledAt: scheduledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAt),
      lastDoneAt: lastDoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDoneAt),
      remindEnabled: Value(remindEnabled),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      displayOrder: Value(displayOrder),
    );
  }

  factory MaintenanceSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceSchedule(
      id: serializer.fromJson<int>(json['id']),
      tankId: serializer.fromJson<int>(json['tankId']),
      actionType: serializer.fromJson<String?>(json['actionType']),
      title: serializer.fromJson<String?>(json['title']),
      cadenceDays: serializer.fromJson<int?>(json['cadenceDays']),
      scheduledAt: serializer.fromJson<DateTime?>(json['scheduledAt']),
      lastDoneAt: serializer.fromJson<DateTime?>(json['lastDoneAt']),
      remindEnabled: serializer.fromJson<bool>(json['remindEnabled']),
      note: serializer.fromJson<String?>(json['note']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tankId': serializer.toJson<int>(tankId),
      'actionType': serializer.toJson<String?>(actionType),
      'title': serializer.toJson<String?>(title),
      'cadenceDays': serializer.toJson<int?>(cadenceDays),
      'scheduledAt': serializer.toJson<DateTime?>(scheduledAt),
      'lastDoneAt': serializer.toJson<DateTime?>(lastDoneAt),
      'remindEnabled': serializer.toJson<bool>(remindEnabled),
      'note': serializer.toJson<String?>(note),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  MaintenanceSchedule copyWith({
    int? id,
    int? tankId,
    Value<String?> actionType = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<int?> cadenceDays = const Value.absent(),
    Value<DateTime?> scheduledAt = const Value.absent(),
    Value<DateTime?> lastDoneAt = const Value.absent(),
    bool? remindEnabled,
    Value<String?> note = const Value.absent(),
    int? displayOrder,
  }) => MaintenanceSchedule(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    actionType: actionType.present ? actionType.value : this.actionType,
    title: title.present ? title.value : this.title,
    cadenceDays: cadenceDays.present ? cadenceDays.value : this.cadenceDays,
    scheduledAt: scheduledAt.present ? scheduledAt.value : this.scheduledAt,
    lastDoneAt: lastDoneAt.present ? lastDoneAt.value : this.lastDoneAt,
    remindEnabled: remindEnabled ?? this.remindEnabled,
    note: note.present ? note.value : this.note,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  MaintenanceSchedule copyWithCompanion(MaintenanceSchedulesCompanion data) {
    return MaintenanceSchedule(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      title: data.title.present ? data.title.value : this.title,
      cadenceDays: data.cadenceDays.present
          ? data.cadenceDays.value
          : this.cadenceDays,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      lastDoneAt: data.lastDoneAt.present
          ? data.lastDoneAt.value
          : this.lastDoneAt,
      remindEnabled: data.remindEnabled.present
          ? data.remindEnabled.value
          : this.remindEnabled,
      note: data.note.present ? data.note.value : this.note,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceSchedule(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('remindEnabled: $remindEnabled, ')
          ..write('note: $note, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tankId,
    actionType,
    title,
    cadenceDays,
    scheduledAt,
    lastDoneAt,
    remindEnabled,
    note,
    displayOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceSchedule &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.actionType == this.actionType &&
          other.title == this.title &&
          other.cadenceDays == this.cadenceDays &&
          other.scheduledAt == this.scheduledAt &&
          other.lastDoneAt == this.lastDoneAt &&
          other.remindEnabled == this.remindEnabled &&
          other.note == this.note &&
          other.displayOrder == this.displayOrder);
}

class MaintenanceSchedulesCompanion
    extends UpdateCompanion<MaintenanceSchedule> {
  final Value<int> id;
  final Value<int> tankId;
  final Value<String?> actionType;
  final Value<String?> title;
  final Value<int?> cadenceDays;
  final Value<DateTime?> scheduledAt;
  final Value<DateTime?> lastDoneAt;
  final Value<bool> remindEnabled;
  final Value<String?> note;
  final Value<int> displayOrder;
  const MaintenanceSchedulesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.title = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.lastDoneAt = const Value.absent(),
    this.remindEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  MaintenanceSchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int tankId,
    this.actionType = const Value.absent(),
    this.title = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.lastDoneAt = const Value.absent(),
    this.remindEnabled = const Value.absent(),
    this.note = const Value.absent(),
    this.displayOrder = const Value.absent(),
  }) : tankId = Value(tankId);
  static Insertable<MaintenanceSchedule> custom({
    Expression<int>? id,
    Expression<int>? tankId,
    Expression<String>? actionType,
    Expression<String>? title,
    Expression<int>? cadenceDays,
    Expression<DateTime>? scheduledAt,
    Expression<DateTime>? lastDoneAt,
    Expression<bool>? remindEnabled,
    Expression<String>? note,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (actionType != null) 'action_type': actionType,
      if (title != null) 'title': title,
      if (cadenceDays != null) 'cadence_days': cadenceDays,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (lastDoneAt != null) 'last_done_at': lastDoneAt,
      if (remindEnabled != null) 'remind_enabled': remindEnabled,
      if (note != null) 'note': note,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  MaintenanceSchedulesCompanion copyWith({
    Value<int>? id,
    Value<int>? tankId,
    Value<String?>? actionType,
    Value<String?>? title,
    Value<int?>? cadenceDays,
    Value<DateTime?>? scheduledAt,
    Value<DateTime?>? lastDoneAt,
    Value<bool>? remindEnabled,
    Value<String?>? note,
    Value<int>? displayOrder,
  }) {
    return MaintenanceSchedulesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      cadenceDays: cadenceDays ?? this.cadenceDays,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      note: note ?? this.note,
      displayOrder: displayOrder ?? this.displayOrder,
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
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (cadenceDays.present) {
      map['cadence_days'] = Variable<int>(cadenceDays.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (lastDoneAt.present) {
      map['last_done_at'] = Variable<DateTime>(lastDoneAt.value);
    }
    if (remindEnabled.present) {
      map['remind_enabled'] = Variable<bool>(remindEnabled.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('remindEnabled: $remindEnabled, ')
          ..write('note: $note, ')
          ..write('displayOrder: $displayOrder')
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
  late final $WaterChangesTable waterChanges = $WaterChangesTable(this);
  late final $CarbonChangesTable carbonChanges = $CarbonChangesTable(this);
  late final $EquipmentCleaningsTable equipmentCleanings =
      $EquipmentCleaningsTable(this);
  late final $RatioVisibilitiesTable ratioVisibilities =
      $RatioVisibilitiesTable(this);
  late final $DosingEntriesTable dosingEntries = $DosingEntriesTable(this);
  late final $ReadingTemplatesTable readingTemplates = $ReadingTemplatesTable(
    this,
  );
  late final $MaintenanceSchedulesTable maintenanceSchedules =
      $MaintenanceSchedulesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxReadingsTankParamTaken = Index(
    'idx_readings_tank_param_taken',
    'CREATE INDEX idx_readings_tank_param_taken ON readings (tank_id, param_key, taken_at)',
  );
  late final Index idxReadingsTankTaken = Index(
    'idx_readings_tank_taken',
    'CREATE INDEX idx_readings_tank_taken ON readings (tank_id, taken_at)',
  );
  late final Index idxWaterChangesTankChanged = Index(
    'idx_water_changes_tank_changed',
    'CREATE INDEX idx_water_changes_tank_changed ON water_changes (tank_id, changed_at)',
  );
  late final Index idxCarbonChangesTankChanged = Index(
    'idx_carbon_changes_tank_changed',
    'CREATE INDEX idx_carbon_changes_tank_changed ON carbon_changes (tank_id, changed_at)',
  );
  late final Index idxEquipmentCleaningsTankCleaned = Index(
    'idx_equipment_cleanings_tank_cleaned',
    'CREATE INDEX idx_equipment_cleanings_tank_cleaned ON equipment_cleanings (tank_id, cleaned_at)',
  );
  late final Index idxDosingEntriesTank = Index(
    'idx_dosing_entries_tank',
    'CREATE INDEX idx_dosing_entries_tank ON dosing_entries (tank_id)',
  );
  late final Index idxReadingTemplatesTank = Index(
    'idx_reading_templates_tank',
    'CREATE INDEX idx_reading_templates_tank ON reading_templates (tank_id)',
  );
  late final Index idxMaintenanceSchedulesTank = Index(
    'idx_maintenance_schedules_tank',
    'CREATE INDEX idx_maintenance_schedules_tank ON maintenance_schedules (tank_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tanks,
    trackedParameters,
    readings,
    waterChanges,
    carbonChanges,
    equipmentCleanings,
    ratioVisibilities,
    dosingEntries,
    readingTemplates,
    maintenanceSchedules,
    settings,
    idxReadingsTankParamTaken,
    idxReadingsTankTaken,
    idxWaterChangesTankChanged,
    idxCarbonChangesTankChanged,
    idxEquipmentCleaningsTankCleaned,
    idxDosingEntriesTank,
    idxReadingTemplatesTank,
    idxMaintenanceSchedulesTank,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('water_changes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('carbon_changes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_cleanings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ratio_visibilities', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dosing_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_templates', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tanks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('maintenance_schedules', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TanksTableCreateCompanionBuilder =
    TanksCompanion Function({
      Value<int> id,
      required String name,
      required String setupType,
      Value<double?> volumeLiters,
      Value<DateTime?> startDate,
      Value<String?> notes,
      Value<String?> vendor,
      Value<String?> model,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
    });
typedef $$TanksTableUpdateCompanionBuilder =
    TanksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> setupType,
      Value<double?> volumeLiters,
      Value<DateTime?> startDate,
      Value<String?> notes,
      Value<String?> vendor,
      Value<String?> model,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
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

  static MultiTypedResultKey<$WaterChangesTable, List<WaterChange>>
  _waterChangesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.waterChanges,
    aliasName: 'tanks__id__water_changes__tank_id',
  );

  $$WaterChangesTableProcessedTableManager get waterChangesRefs {
    final manager = $$WaterChangesTableTableManager(
      $_db,
      $_db.waterChanges,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_waterChangesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CarbonChangesTable, List<CarbonChange>>
  _carbonChangesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.carbonChanges,
    aliasName: 'tanks__id__carbon_changes__tank_id',
  );

  $$CarbonChangesTableProcessedTableManager get carbonChangesRefs {
    final manager = $$CarbonChangesTableTableManager(
      $_db,
      $_db.carbonChanges,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_carbonChangesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EquipmentCleaningsTable, List<EquipmentCleaning>>
  _equipmentCleaningsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentCleanings,
        aliasName: 'tanks__id__equipment_cleanings__tank_id',
      );

  $$EquipmentCleaningsTableProcessedTableManager get equipmentCleaningsRefs {
    final manager = $$EquipmentCleaningsTableTableManager(
      $_db,
      $_db.equipmentCleanings,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentCleaningsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RatioVisibilitiesTable, List<RatioVisibility>>
  _ratioVisibilitiesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.ratioVisibilities,
        aliasName: 'tanks__id__ratio_visibilities__tank_id',
      );

  $$RatioVisibilitiesTableProcessedTableManager get ratioVisibilitiesRefs {
    final manager = $$RatioVisibilitiesTableTableManager(
      $_db,
      $_db.ratioVisibilities,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _ratioVisibilitiesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DosingEntriesTable, List<DosingEntry>>
  _dosingEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dosingEntries,
    aliasName: 'tanks__id__dosing_entries__tank_id',
  );

  $$DosingEntriesTableProcessedTableManager get dosingEntriesRefs {
    final manager = $$DosingEntriesTableTableManager(
      $_db,
      $_db.dosingEntries,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_dosingEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingTemplatesTable, List<ReadingTemplate>>
  _readingTemplatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingTemplates,
    aliasName: 'tanks__id__reading_templates__tank_id',
  );

  $$ReadingTemplatesTableProcessedTableManager get readingTemplatesRefs {
    final manager = $$ReadingTemplatesTableTableManager(
      $_db,
      $_db.readingTemplates,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingTemplatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MaintenanceSchedulesTable,
    List<MaintenanceSchedule>
  >
  _maintenanceSchedulesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.maintenanceSchedules,
        aliasName: 'tanks__id__maintenance_schedules__tank_id',
      );

  $$MaintenanceSchedulesTableProcessedTableManager
  get maintenanceSchedulesRefs {
    final manager = $$MaintenanceSchedulesTableTableManager(
      $_db,
      $_db.maintenanceSchedules,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceSchedulesRefsTable($_db),
    );
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

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  Expression<bool> waterChangesRefs(
    Expression<bool> Function($$WaterChangesTableFilterComposer f) f,
  ) {
    final $$WaterChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.waterChanges,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterChangesTableFilterComposer(
            $db: $db,
            $table: $db.waterChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> carbonChangesRefs(
    Expression<bool> Function($$CarbonChangesTableFilterComposer f) f,
  ) {
    final $$CarbonChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.carbonChanges,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CarbonChangesTableFilterComposer(
            $db: $db,
            $table: $db.carbonChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equipmentCleaningsRefs(
    Expression<bool> Function($$EquipmentCleaningsTableFilterComposer f) f,
  ) {
    final $$EquipmentCleaningsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentCleanings,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentCleaningsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentCleanings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ratioVisibilitiesRefs(
    Expression<bool> Function($$RatioVisibilitiesTableFilterComposer f) f,
  ) {
    final $$RatioVisibilitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ratioVisibilities,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RatioVisibilitiesTableFilterComposer(
            $db: $db,
            $table: $db.ratioVisibilities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dosingEntriesRefs(
    Expression<bool> Function($$DosingEntriesTableFilterComposer f) f,
  ) {
    final $$DosingEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dosingEntries,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosingEntriesTableFilterComposer(
            $db: $db,
            $table: $db.dosingEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingTemplatesRefs(
    Expression<bool> Function($$ReadingTemplatesTableFilterComposer f) f,
  ) {
    final $$ReadingTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingTemplates,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.readingTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceSchedulesRefs(
    Expression<bool> Function($$MaintenanceSchedulesTableFilterComposer f) f,
  ) {
    final $$MaintenanceSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceSchedules,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceSchedules,
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

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

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

  Expression<T> waterChangesRefs<T extends Object>(
    Expression<T> Function($$WaterChangesTableAnnotationComposer a) f,
  ) {
    final $$WaterChangesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.waterChanges,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterChangesTableAnnotationComposer(
            $db: $db,
            $table: $db.waterChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> carbonChangesRefs<T extends Object>(
    Expression<T> Function($$CarbonChangesTableAnnotationComposer a) f,
  ) {
    final $$CarbonChangesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.carbonChanges,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CarbonChangesTableAnnotationComposer(
            $db: $db,
            $table: $db.carbonChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> equipmentCleaningsRefs<T extends Object>(
    Expression<T> Function($$EquipmentCleaningsTableAnnotationComposer a) f,
  ) {
    final $$EquipmentCleaningsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentCleanings,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentCleaningsTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentCleanings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> ratioVisibilitiesRefs<T extends Object>(
    Expression<T> Function($$RatioVisibilitiesTableAnnotationComposer a) f,
  ) {
    final $$RatioVisibilitiesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.ratioVisibilities,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RatioVisibilitiesTableAnnotationComposer(
                $db: $db,
                $table: $db.ratioVisibilities,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> dosingEntriesRefs<T extends Object>(
    Expression<T> Function($$DosingEntriesTableAnnotationComposer a) f,
  ) {
    final $$DosingEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dosingEntries,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosingEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.dosingEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingTemplatesRefs<T extends Object>(
    Expression<T> Function($$ReadingTemplatesTableAnnotationComposer a) f,
  ) {
    final $$ReadingTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingTemplates,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.readingTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> maintenanceSchedulesRefs<T extends Object>(
    Expression<T> Function($$MaintenanceSchedulesTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.maintenanceSchedules,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MaintenanceSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.maintenanceSchedules,
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
            bool waterChangesRefs,
            bool carbonChangesRefs,
            bool equipmentCleaningsRefs,
            bool ratioVisibilitiesRefs,
            bool dosingEntriesRefs,
            bool readingTemplatesRefs,
            bool maintenanceSchedulesRefs,
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
                Value<DateTime?> startDate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TanksCompanion(
                id: id,
                name: name,
                setupType: setupType,
                volumeLiters: volumeLiters,
                startDate: startDate,
                notes: notes,
                vendor: vendor,
                model: model,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String setupType,
                Value<double?> volumeLiters = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TanksCompanion.insert(
                id: id,
                name: name,
                setupType: setupType,
                volumeLiters: volumeLiters,
                startDate: startDate,
                notes: notes,
                vendor: vendor,
                model: model,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TanksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                trackedParametersRefs = false,
                readingsRefs = false,
                waterChangesRefs = false,
                carbonChangesRefs = false,
                equipmentCleaningsRefs = false,
                ratioVisibilitiesRefs = false,
                dosingEntriesRefs = false,
                readingTemplatesRefs = false,
                maintenanceSchedulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trackedParametersRefs) db.trackedParameters,
                    if (readingsRefs) db.readings,
                    if (waterChangesRefs) db.waterChanges,
                    if (carbonChangesRefs) db.carbonChanges,
                    if (equipmentCleaningsRefs) db.equipmentCleanings,
                    if (ratioVisibilitiesRefs) db.ratioVisibilities,
                    if (dosingEntriesRefs) db.dosingEntries,
                    if (readingTemplatesRefs) db.readingTemplates,
                    if (maintenanceSchedulesRefs) db.maintenanceSchedules,
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
                      if (waterChangesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          WaterChange
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._waterChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).waterChangesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (carbonChangesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          CarbonChange
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._carbonChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).carbonChangesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (equipmentCleaningsRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          EquipmentCleaning
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._equipmentCleaningsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentCleaningsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ratioVisibilitiesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          RatioVisibility
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._ratioVisibilitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).ratioVisibilitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dosingEntriesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          DosingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._dosingEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).dosingEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingTemplatesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          ReadingTemplate
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._readingTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingTemplatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceSchedulesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          MaintenanceSchedule
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._maintenanceSchedulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceSchedulesRefs,
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
      PrefetchHooks Function({
        bool trackedParametersRefs,
        bool readingsRefs,
        bool waterChangesRefs,
        bool carbonChangesRefs,
        bool equipmentCleaningsRefs,
        bool ratioVisibilitiesRefs,
        bool dosingEntriesRefs,
        bool readingTemplatesRefs,
        bool maintenanceSchedulesRefs,
      })
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
      Value<int?> testCadenceDays,
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
      Value<int?> testCadenceDays,
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

  ColumnFilters<int> get testCadenceDays => $composableBuilder(
    column: $table.testCadenceDays,
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

  ColumnOrderings<int> get testCadenceDays => $composableBuilder(
    column: $table.testCadenceDays,
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

  GeneratedColumn<int> get testCadenceDays => $composableBuilder(
    column: $table.testCadenceDays,
    builder: (column) => column,
  );

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
                Value<int?> testCadenceDays = const Value.absent(),
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
                testCadenceDays: testCadenceDays,
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
                Value<int?> testCadenceDays = const Value.absent(),
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
                testCadenceDays: testCadenceDays,
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
      Value<String?> groupId,
    });
typedef $$ReadingsTableUpdateCompanionBuilder =
    ReadingsCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String> paramKey,
      Value<double> value,
      Value<DateTime> takenAt,
      Value<String?> note,
      Value<String?> groupId,
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
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

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

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
                Value<String?> groupId = const Value.absent(),
              }) => ReadingsCompanion(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                value: value,
                takenAt: takenAt,
                note: note,
                groupId: groupId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required String paramKey,
                required double value,
                required DateTime takenAt,
                Value<String?> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
              }) => ReadingsCompanion.insert(
                id: id,
                tankId: tankId,
                paramKey: paramKey,
                value: value,
                takenAt: takenAt,
                note: note,
                groupId: groupId,
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
typedef $$WaterChangesTableCreateCompanionBuilder =
    WaterChangesCompanion Function({
      Value<int> id,
      required int tankId,
      required DateTime changedAt,
      Value<double?> amountLiters,
      Value<String?> note,
    });
typedef $$WaterChangesTableUpdateCompanionBuilder =
    WaterChangesCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<DateTime> changedAt,
      Value<double?> amountLiters,
      Value<String?> note,
    });

final class $$WaterChangesTableReferences
    extends BaseReferences<_$AppDatabase, $WaterChangesTable, WaterChange> {
  $$WaterChangesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('water_changes__tank_id__tanks__id');

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

class $$WaterChangesTableFilterComposer
    extends Composer<_$AppDatabase, $WaterChangesTable> {
  $$WaterChangesTableFilterComposer({
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

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amountLiters => $composableBuilder(
    column: $table.amountLiters,
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

class $$WaterChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterChangesTable> {
  $$WaterChangesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amountLiters => $composableBuilder(
    column: $table.amountLiters,
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

class $$WaterChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterChangesTable> {
  $$WaterChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<double> get amountLiters => $composableBuilder(
    column: $table.amountLiters,
    builder: (column) => column,
  );

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

class $$WaterChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterChangesTable,
          WaterChange,
          $$WaterChangesTableFilterComposer,
          $$WaterChangesTableOrderingComposer,
          $$WaterChangesTableAnnotationComposer,
          $$WaterChangesTableCreateCompanionBuilder,
          $$WaterChangesTableUpdateCompanionBuilder,
          (WaterChange, $$WaterChangesTableReferences),
          WaterChange,
          PrefetchHooks Function({bool tankId})
        > {
  $$WaterChangesTableTableManager(_$AppDatabase db, $WaterChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<double?> amountLiters = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => WaterChangesCompanion(
                id: id,
                tankId: tankId,
                changedAt: changedAt,
                amountLiters: amountLiters,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required DateTime changedAt,
                Value<double?> amountLiters = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => WaterChangesCompanion.insert(
                id: id,
                tankId: tankId,
                changedAt: changedAt,
                amountLiters: amountLiters,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WaterChangesTableReferences(db, table, e),
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
                                referencedTable: $$WaterChangesTableReferences
                                    ._tankIdTable(db),
                                referencedColumn: $$WaterChangesTableReferences
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

typedef $$WaterChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterChangesTable,
      WaterChange,
      $$WaterChangesTableFilterComposer,
      $$WaterChangesTableOrderingComposer,
      $$WaterChangesTableAnnotationComposer,
      $$WaterChangesTableCreateCompanionBuilder,
      $$WaterChangesTableUpdateCompanionBuilder,
      (WaterChange, $$WaterChangesTableReferences),
      WaterChange,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$CarbonChangesTableCreateCompanionBuilder =
    CarbonChangesCompanion Function({
      Value<int> id,
      required int tankId,
      required DateTime changedAt,
      Value<double?> grams,
      Value<String?> note,
    });
typedef $$CarbonChangesTableUpdateCompanionBuilder =
    CarbonChangesCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<DateTime> changedAt,
      Value<double?> grams,
      Value<String?> note,
    });

final class $$CarbonChangesTableReferences
    extends BaseReferences<_$AppDatabase, $CarbonChangesTable, CarbonChange> {
  $$CarbonChangesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('carbon_changes__tank_id__tanks__id');

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

class $$CarbonChangesTableFilterComposer
    extends Composer<_$AppDatabase, $CarbonChangesTable> {
  $$CarbonChangesTableFilterComposer({
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

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
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

class $$CarbonChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbonChangesTable> {
  $$CarbonChangesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
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

class $$CarbonChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbonChangesTable> {
  $$CarbonChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

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

class $$CarbonChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarbonChangesTable,
          CarbonChange,
          $$CarbonChangesTableFilterComposer,
          $$CarbonChangesTableOrderingComposer,
          $$CarbonChangesTableAnnotationComposer,
          $$CarbonChangesTableCreateCompanionBuilder,
          $$CarbonChangesTableUpdateCompanionBuilder,
          (CarbonChange, $$CarbonChangesTableReferences),
          CarbonChange,
          PrefetchHooks Function({bool tankId})
        > {
  $$CarbonChangesTableTableManager(_$AppDatabase db, $CarbonChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbonChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarbonChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarbonChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<double?> grams = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CarbonChangesCompanion(
                id: id,
                tankId: tankId,
                changedAt: changedAt,
                grams: grams,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required DateTime changedAt,
                Value<double?> grams = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CarbonChangesCompanion.insert(
                id: id,
                tankId: tankId,
                changedAt: changedAt,
                grams: grams,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CarbonChangesTableReferences(db, table, e),
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
                                referencedTable: $$CarbonChangesTableReferences
                                    ._tankIdTable(db),
                                referencedColumn: $$CarbonChangesTableReferences
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

typedef $$CarbonChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarbonChangesTable,
      CarbonChange,
      $$CarbonChangesTableFilterComposer,
      $$CarbonChangesTableOrderingComposer,
      $$CarbonChangesTableAnnotationComposer,
      $$CarbonChangesTableCreateCompanionBuilder,
      $$CarbonChangesTableUpdateCompanionBuilder,
      (CarbonChange, $$CarbonChangesTableReferences),
      CarbonChange,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$EquipmentCleaningsTableCreateCompanionBuilder =
    EquipmentCleaningsCompanion Function({
      Value<int> id,
      required int tankId,
      required DateTime cleanedAt,
      Value<String?> note,
    });
typedef $$EquipmentCleaningsTableUpdateCompanionBuilder =
    EquipmentCleaningsCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<DateTime> cleanedAt,
      Value<String?> note,
    });

final class $$EquipmentCleaningsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EquipmentCleaningsTable,
          EquipmentCleaning
        > {
  $$EquipmentCleaningsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('equipment_cleanings__tank_id__tanks__id');

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

class $$EquipmentCleaningsTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentCleaningsTable> {
  $$EquipmentCleaningsTableFilterComposer({
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

  ColumnFilters<DateTime> get cleanedAt => $composableBuilder(
    column: $table.cleanedAt,
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

class $$EquipmentCleaningsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentCleaningsTable> {
  $$EquipmentCleaningsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get cleanedAt => $composableBuilder(
    column: $table.cleanedAt,
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

class $$EquipmentCleaningsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentCleaningsTable> {
  $$EquipmentCleaningsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get cleanedAt =>
      $composableBuilder(column: $table.cleanedAt, builder: (column) => column);

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

class $$EquipmentCleaningsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentCleaningsTable,
          EquipmentCleaning,
          $$EquipmentCleaningsTableFilterComposer,
          $$EquipmentCleaningsTableOrderingComposer,
          $$EquipmentCleaningsTableAnnotationComposer,
          $$EquipmentCleaningsTableCreateCompanionBuilder,
          $$EquipmentCleaningsTableUpdateCompanionBuilder,
          (EquipmentCleaning, $$EquipmentCleaningsTableReferences),
          EquipmentCleaning,
          PrefetchHooks Function({bool tankId})
        > {
  $$EquipmentCleaningsTableTableManager(
    _$AppDatabase db,
    $EquipmentCleaningsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentCleaningsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentCleaningsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentCleaningsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<DateTime> cleanedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => EquipmentCleaningsCompanion(
                id: id,
                tankId: tankId,
                cleanedAt: cleanedAt,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required DateTime cleanedAt,
                Value<String?> note = const Value.absent(),
              }) => EquipmentCleaningsCompanion.insert(
                id: id,
                tankId: tankId,
                cleanedAt: cleanedAt,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EquipmentCleaningsTableReferences(db, table, e),
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
                                    $$EquipmentCleaningsTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$EquipmentCleaningsTableReferences
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

typedef $$EquipmentCleaningsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentCleaningsTable,
      EquipmentCleaning,
      $$EquipmentCleaningsTableFilterComposer,
      $$EquipmentCleaningsTableOrderingComposer,
      $$EquipmentCleaningsTableAnnotationComposer,
      $$EquipmentCleaningsTableCreateCompanionBuilder,
      $$EquipmentCleaningsTableUpdateCompanionBuilder,
      (EquipmentCleaning, $$EquipmentCleaningsTableReferences),
      EquipmentCleaning,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$RatioVisibilitiesTableCreateCompanionBuilder =
    RatioVisibilitiesCompanion Function({
      required int tankId,
      required String ratioKey,
      Value<bool> visible,
      Value<int> displayOrder,
      Value<double?> amberLow,
      Value<double?> greenLow,
      Value<double?> greenHigh,
      Value<double?> amberHigh,
      Value<int> rowid,
    });
typedef $$RatioVisibilitiesTableUpdateCompanionBuilder =
    RatioVisibilitiesCompanion Function({
      Value<int> tankId,
      Value<String> ratioKey,
      Value<bool> visible,
      Value<int> displayOrder,
      Value<double?> amberLow,
      Value<double?> greenLow,
      Value<double?> greenHigh,
      Value<double?> amberHigh,
      Value<int> rowid,
    });

final class $$RatioVisibilitiesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RatioVisibilitiesTable,
          RatioVisibility
        > {
  $$RatioVisibilitiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('ratio_visibilities__tank_id__tanks__id');

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

class $$RatioVisibilitiesTableFilterComposer
    extends Composer<_$AppDatabase, $RatioVisibilitiesTable> {
  $$RatioVisibilitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ratioKey => $composableBuilder(
    column: $table.ratioKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visible => $composableBuilder(
    column: $table.visible,
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

class $$RatioVisibilitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $RatioVisibilitiesTable> {
  $$RatioVisibilitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ratioKey => $composableBuilder(
    column: $table.ratioKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visible => $composableBuilder(
    column: $table.visible,
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

class $$RatioVisibilitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatioVisibilitiesTable> {
  $$RatioVisibilitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ratioKey =>
      $composableBuilder(column: $table.ratioKey, builder: (column) => column);

  GeneratedColumn<bool> get visible =>
      $composableBuilder(column: $table.visible, builder: (column) => column);

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

class $$RatioVisibilitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatioVisibilitiesTable,
          RatioVisibility,
          $$RatioVisibilitiesTableFilterComposer,
          $$RatioVisibilitiesTableOrderingComposer,
          $$RatioVisibilitiesTableAnnotationComposer,
          $$RatioVisibilitiesTableCreateCompanionBuilder,
          $$RatioVisibilitiesTableUpdateCompanionBuilder,
          (RatioVisibility, $$RatioVisibilitiesTableReferences),
          RatioVisibility,
          PrefetchHooks Function({bool tankId})
        > {
  $$RatioVisibilitiesTableTableManager(
    _$AppDatabase db,
    $RatioVisibilitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatioVisibilitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatioVisibilitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatioVisibilitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> tankId = const Value.absent(),
                Value<String> ratioKey = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<double?> amberLow = const Value.absent(),
                Value<double?> greenLow = const Value.absent(),
                Value<double?> greenHigh = const Value.absent(),
                Value<double?> amberHigh = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatioVisibilitiesCompanion(
                tankId: tankId,
                ratioKey: ratioKey,
                visible: visible,
                displayOrder: displayOrder,
                amberLow: amberLow,
                greenLow: greenLow,
                greenHigh: greenHigh,
                amberHigh: amberHigh,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tankId,
                required String ratioKey,
                Value<bool> visible = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<double?> amberLow = const Value.absent(),
                Value<double?> greenLow = const Value.absent(),
                Value<double?> greenHigh = const Value.absent(),
                Value<double?> amberHigh = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatioVisibilitiesCompanion.insert(
                tankId: tankId,
                ratioKey: ratioKey,
                visible: visible,
                displayOrder: displayOrder,
                amberLow: amberLow,
                greenLow: greenLow,
                greenHigh: greenHigh,
                amberHigh: amberHigh,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RatioVisibilitiesTableReferences(db, table, e),
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
                                    $$RatioVisibilitiesTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$RatioVisibilitiesTableReferences
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

typedef $$RatioVisibilitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatioVisibilitiesTable,
      RatioVisibility,
      $$RatioVisibilitiesTableFilterComposer,
      $$RatioVisibilitiesTableOrderingComposer,
      $$RatioVisibilitiesTableAnnotationComposer,
      $$RatioVisibilitiesTableCreateCompanionBuilder,
      $$RatioVisibilitiesTableUpdateCompanionBuilder,
      (RatioVisibility, $$RatioVisibilitiesTableReferences),
      RatioVisibility,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$DosingEntriesTableCreateCompanionBuilder =
    DosingEntriesCompanion Function({
      Value<int> id,
      required int tankId,
      Value<String?> productKey,
      Value<String?> vendor,
      Value<String?> program,
      required String product,
      Value<String?> elementKey,
      Value<double?> amount,
      Value<String?> amountUnit,
      Value<String?> basis,
      Value<String?> frequency,
      Value<int?> intervalDays,
      Value<String?> weekdays,
      Value<String?> doseTime,
      Value<bool> remindEnabled,
      Value<String?> note,
      Value<int> displayOrder,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<String> state,
    });
typedef $$DosingEntriesTableUpdateCompanionBuilder =
    DosingEntriesCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String?> productKey,
      Value<String?> vendor,
      Value<String?> program,
      Value<String> product,
      Value<String?> elementKey,
      Value<double?> amount,
      Value<String?> amountUnit,
      Value<String?> basis,
      Value<String?> frequency,
      Value<int?> intervalDays,
      Value<String?> weekdays,
      Value<String?> doseTime,
      Value<bool> remindEnabled,
      Value<String?> note,
      Value<int> displayOrder,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> endedAt,
      Value<String> state,
    });

final class $$DosingEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $DosingEntriesTable, DosingEntry> {
  $$DosingEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('dosing_entries__tank_id__tanks__id');

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

class $$DosingEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DosingEntriesTable> {
  $$DosingEntriesTableFilterComposer({
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

  ColumnFilters<String> get productKey => $composableBuilder(
    column: $table.productKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get program => $composableBuilder(
    column: $table.program,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elementKey => $composableBuilder(
    column: $table.elementKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountUnit => $composableBuilder(
    column: $table.amountUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseTime => $composableBuilder(
    column: $table.doseTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
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

class $$DosingEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DosingEntriesTable> {
  $$DosingEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get productKey => $composableBuilder(
    column: $table.productKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get program => $composableBuilder(
    column: $table.program,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elementKey => $composableBuilder(
    column: $table.elementKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountUnit => $composableBuilder(
    column: $table.amountUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseTime => $composableBuilder(
    column: $table.doseTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
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

class $$DosingEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DosingEntriesTable> {
  $$DosingEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productKey => $composableBuilder(
    column: $table.productKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get program =>
      $composableBuilder(column: $table.program, builder: (column) => column);

  GeneratedColumn<String> get product =>
      $composableBuilder(column: $table.product, builder: (column) => column);

  GeneratedColumn<String> get elementKey => $composableBuilder(
    column: $table.elementKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get amountUnit => $composableBuilder(
    column: $table.amountUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<String> get doseTime =>
      $composableBuilder(column: $table.doseTime, builder: (column) => column);

  GeneratedColumn<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

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

class $$DosingEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DosingEntriesTable,
          DosingEntry,
          $$DosingEntriesTableFilterComposer,
          $$DosingEntriesTableOrderingComposer,
          $$DosingEntriesTableAnnotationComposer,
          $$DosingEntriesTableCreateCompanionBuilder,
          $$DosingEntriesTableUpdateCompanionBuilder,
          (DosingEntry, $$DosingEntriesTableReferences),
          DosingEntry,
          PrefetchHooks Function({bool tankId})
        > {
  $$DosingEntriesTableTableManager(_$AppDatabase db, $DosingEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DosingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DosingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DosingEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<String?> productKey = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> program = const Value.absent(),
                Value<String> product = const Value.absent(),
                Value<String?> elementKey = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> amountUnit = const Value.absent(),
                Value<String?> basis = const Value.absent(),
                Value<String?> frequency = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> doseTime = const Value.absent(),
                Value<bool> remindEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> state = const Value.absent(),
              }) => DosingEntriesCompanion(
                id: id,
                tankId: tankId,
                productKey: productKey,
                vendor: vendor,
                program: program,
                product: product,
                elementKey: elementKey,
                amount: amount,
                amountUnit: amountUnit,
                basis: basis,
                frequency: frequency,
                intervalDays: intervalDays,
                weekdays: weekdays,
                doseTime: doseTime,
                remindEnabled: remindEnabled,
                note: note,
                displayOrder: displayOrder,
                createdAt: createdAt,
                startedAt: startedAt,
                endedAt: endedAt,
                state: state,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                Value<String?> productKey = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> program = const Value.absent(),
                required String product,
                Value<String?> elementKey = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> amountUnit = const Value.absent(),
                Value<String?> basis = const Value.absent(),
                Value<String?> frequency = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> doseTime = const Value.absent(),
                Value<bool> remindEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> state = const Value.absent(),
              }) => DosingEntriesCompanion.insert(
                id: id,
                tankId: tankId,
                productKey: productKey,
                vendor: vendor,
                program: program,
                product: product,
                elementKey: elementKey,
                amount: amount,
                amountUnit: amountUnit,
                basis: basis,
                frequency: frequency,
                intervalDays: intervalDays,
                weekdays: weekdays,
                doseTime: doseTime,
                remindEnabled: remindEnabled,
                note: note,
                displayOrder: displayOrder,
                createdAt: createdAt,
                startedAt: startedAt,
                endedAt: endedAt,
                state: state,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DosingEntriesTableReferences(db, table, e),
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
                                referencedTable: $$DosingEntriesTableReferences
                                    ._tankIdTable(db),
                                referencedColumn: $$DosingEntriesTableReferences
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

typedef $$DosingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DosingEntriesTable,
      DosingEntry,
      $$DosingEntriesTableFilterComposer,
      $$DosingEntriesTableOrderingComposer,
      $$DosingEntriesTableAnnotationComposer,
      $$DosingEntriesTableCreateCompanionBuilder,
      $$DosingEntriesTableUpdateCompanionBuilder,
      (DosingEntry, $$DosingEntriesTableReferences),
      DosingEntry,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$ReadingTemplatesTableCreateCompanionBuilder =
    ReadingTemplatesCompanion Function({
      Value<int> id,
      required int tankId,
      required String name,
      required String paramKeys,
      Value<int> displayOrder,
    });
typedef $$ReadingTemplatesTableUpdateCompanionBuilder =
    ReadingTemplatesCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String> name,
      Value<String> paramKeys,
      Value<int> displayOrder,
    });

final class $$ReadingTemplatesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReadingTemplatesTable, ReadingTemplate> {
  $$ReadingTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('reading_templates__tank_id__tanks__id');

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

class $$ReadingTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingTemplatesTable> {
  $$ReadingTemplatesTableFilterComposer({
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

  ColumnFilters<String> get paramKeys => $composableBuilder(
    column: $table.paramKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

class $$ReadingTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingTemplatesTable> {
  $$ReadingTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get paramKeys => $composableBuilder(
    column: $table.paramKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

class $$ReadingTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingTemplatesTable> {
  $$ReadingTemplatesTableAnnotationComposer({
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

  GeneratedColumn<String> get paramKeys =>
      $composableBuilder(column: $table.paramKeys, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

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

class $$ReadingTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingTemplatesTable,
          ReadingTemplate,
          $$ReadingTemplatesTableFilterComposer,
          $$ReadingTemplatesTableOrderingComposer,
          $$ReadingTemplatesTableAnnotationComposer,
          $$ReadingTemplatesTableCreateCompanionBuilder,
          $$ReadingTemplatesTableUpdateCompanionBuilder,
          (ReadingTemplate, $$ReadingTemplatesTableReferences),
          ReadingTemplate,
          PrefetchHooks Function({bool tankId})
        > {
  $$ReadingTemplatesTableTableManager(
    _$AppDatabase db,
    $ReadingTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> paramKeys = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => ReadingTemplatesCompanion(
                id: id,
                tankId: tankId,
                name: name,
                paramKeys: paramKeys,
                displayOrder: displayOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                required String name,
                required String paramKeys,
                Value<int> displayOrder = const Value.absent(),
              }) => ReadingTemplatesCompanion.insert(
                id: id,
                tankId: tankId,
                name: name,
                paramKeys: paramKeys,
                displayOrder: displayOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingTemplatesTableReferences(db, table, e),
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
                                    $$ReadingTemplatesTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$ReadingTemplatesTableReferences
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

typedef $$ReadingTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingTemplatesTable,
      ReadingTemplate,
      $$ReadingTemplatesTableFilterComposer,
      $$ReadingTemplatesTableOrderingComposer,
      $$ReadingTemplatesTableAnnotationComposer,
      $$ReadingTemplatesTableCreateCompanionBuilder,
      $$ReadingTemplatesTableUpdateCompanionBuilder,
      (ReadingTemplate, $$ReadingTemplatesTableReferences),
      ReadingTemplate,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$MaintenanceSchedulesTableCreateCompanionBuilder =
    MaintenanceSchedulesCompanion Function({
      Value<int> id,
      required int tankId,
      Value<String?> actionType,
      Value<String?> title,
      Value<int?> cadenceDays,
      Value<DateTime?> scheduledAt,
      Value<DateTime?> lastDoneAt,
      Value<bool> remindEnabled,
      Value<String?> note,
      Value<int> displayOrder,
    });
typedef $$MaintenanceSchedulesTableUpdateCompanionBuilder =
    MaintenanceSchedulesCompanion Function({
      Value<int> id,
      Value<int> tankId,
      Value<String?> actionType,
      Value<String?> title,
      Value<int?> cadenceDays,
      Value<DateTime?> scheduledAt,
      Value<DateTime?> lastDoneAt,
      Value<bool> remindEnabled,
      Value<String?> note,
      Value<int> displayOrder,
    });

final class $$MaintenanceSchedulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MaintenanceSchedulesTable,
          MaintenanceSchedule
        > {
  $$MaintenanceSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('maintenance_schedules__tank_id__tanks__id');

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

class $$MaintenanceSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceSchedulesTable> {
  $$MaintenanceSchedulesTableFilterComposer({
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

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

class $$MaintenanceSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceSchedulesTable> {
  $$MaintenanceSchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
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

class $$MaintenanceSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceSchedulesTable> {
  $$MaintenanceSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get remindEnabled => $composableBuilder(
    column: $table.remindEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

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

class $$MaintenanceSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceSchedulesTable,
          MaintenanceSchedule,
          $$MaintenanceSchedulesTableFilterComposer,
          $$MaintenanceSchedulesTableOrderingComposer,
          $$MaintenanceSchedulesTableAnnotationComposer,
          $$MaintenanceSchedulesTableCreateCompanionBuilder,
          $$MaintenanceSchedulesTableUpdateCompanionBuilder,
          (MaintenanceSchedule, $$MaintenanceSchedulesTableReferences),
          MaintenanceSchedule,
          PrefetchHooks Function({bool tankId})
        > {
  $$MaintenanceSchedulesTableTableManager(
    _$AppDatabase db,
    $MaintenanceSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceSchedulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MaintenanceSchedulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tankId = const Value.absent(),
                Value<String?> actionType = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> cadenceDays = const Value.absent(),
                Value<DateTime?> scheduledAt = const Value.absent(),
                Value<DateTime?> lastDoneAt = const Value.absent(),
                Value<bool> remindEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => MaintenanceSchedulesCompanion(
                id: id,
                tankId: tankId,
                actionType: actionType,
                title: title,
                cadenceDays: cadenceDays,
                scheduledAt: scheduledAt,
                lastDoneAt: lastDoneAt,
                remindEnabled: remindEnabled,
                note: note,
                displayOrder: displayOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tankId,
                Value<String?> actionType = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> cadenceDays = const Value.absent(),
                Value<DateTime?> scheduledAt = const Value.absent(),
                Value<DateTime?> lastDoneAt = const Value.absent(),
                Value<bool> remindEnabled = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => MaintenanceSchedulesCompanion.insert(
                id: id,
                tankId: tankId,
                actionType: actionType,
                title: title,
                cadenceDays: cadenceDays,
                scheduledAt: scheduledAt,
                lastDoneAt: lastDoneAt,
                remindEnabled: remindEnabled,
                note: note,
                displayOrder: displayOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceSchedulesTableReferences(db, table, e),
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
                                    $$MaintenanceSchedulesTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$MaintenanceSchedulesTableReferences
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

typedef $$MaintenanceSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceSchedulesTable,
      MaintenanceSchedule,
      $$MaintenanceSchedulesTableFilterComposer,
      $$MaintenanceSchedulesTableOrderingComposer,
      $$MaintenanceSchedulesTableAnnotationComposer,
      $$MaintenanceSchedulesTableCreateCompanionBuilder,
      $$MaintenanceSchedulesTableUpdateCompanionBuilder,
      (MaintenanceSchedule, $$MaintenanceSchedulesTableReferences),
      MaintenanceSchedule,
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
  $$WaterChangesTableTableManager get waterChanges =>
      $$WaterChangesTableTableManager(_db, _db.waterChanges);
  $$CarbonChangesTableTableManager get carbonChanges =>
      $$CarbonChangesTableTableManager(_db, _db.carbonChanges);
  $$EquipmentCleaningsTableTableManager get equipmentCleanings =>
      $$EquipmentCleaningsTableTableManager(_db, _db.equipmentCleanings);
  $$RatioVisibilitiesTableTableManager get ratioVisibilities =>
      $$RatioVisibilitiesTableTableManager(_db, _db.ratioVisibilities);
  $$DosingEntriesTableTableManager get dosingEntries =>
      $$DosingEntriesTableTableManager(_db, _db.dosingEntries);
  $$ReadingTemplatesTableTableManager get readingTemplates =>
      $$ReadingTemplatesTableTableManager(_db, _db.readingTemplates);
  $$MaintenanceSchedulesTableTableManager get maintenanceSchedules =>
      $$MaintenanceSchedulesTableTableManager(_db, _db.maintenanceSchedules);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
