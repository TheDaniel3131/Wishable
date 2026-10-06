// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _isPresetMeta =
      const VerificationMeta('isPreset');
  @override
  late final GeneratedColumn<bool> isPreset = GeneratedColumn<bool>(
      'is_preset', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_preset" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [id, name, isPreset];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_preset')) {
      context.handle(_isPresetMeta,
          isPreset.isAcceptableOrUnknown(data['is_preset']!, _isPresetMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isPreset: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_preset'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String name;
  final bool isPreset;
  const CategoryRow(
      {required this.id, required this.name, required this.isPreset});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['is_preset'] = Variable<bool>(isPreset);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      isPreset: Value(isPreset),
    );
  }

  factory CategoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isPreset: serializer.fromJson<bool>(json['isPreset']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'isPreset': serializer.toJson<bool>(isPreset),
    };
  }

  CategoryRow copyWith({String? id, String? name, bool? isPreset}) =>
      CategoryRow(
        id: id ?? this.id,
        name: name ?? this.name,
        isPreset: isPreset ?? this.isPreset,
      );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isPreset: data.isPreset.present ? data.isPreset.value : this.isPreset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isPreset: $isPreset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isPreset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isPreset == this.isPreset);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> isPreset;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isPreset = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    this.isPreset = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? isPreset,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isPreset != null) 'is_preset': isPreset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<bool>? isPreset,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isPreset: isPreset ?? this.isPreset,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isPreset.present) {
      map['is_preset'] = Variable<bool>(isPreset.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isPreset: $isPreset, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishesTable extends Wishes with TableInfo<$WishesTable, WishRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES categories(id)');
  @override
  late final GeneratedColumnWithTypeConverter<Priority, int> priority =
      GeneratedColumn<int>('priority', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<Priority>($WishesTable.$converterpriority);
  @override
  late final GeneratedColumnWithTypeConverter<LifecycleStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<LifecycleStatus>($WishesTable.$converterstatus);
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
      'progress', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL CHECK (progress BETWEEN 0 AND 100)');
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtUtcMeta =
      const VerificationMeta('updatedAtUtc');
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
      'updated_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtUtcMeta =
      const VerificationMeta('deletedAtUtc');
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
      'deleted_at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        categoryId,
        priority,
        status,
        progress,
        createdAtUtc,
        updatedAtUtc,
        deletedAtUtc,
        seq
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishes';
  @override
  VerificationContext validateIntegrity(Insertable<WishRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
          _updatedAtUtcMeta,
          updatedAtUtc.isAcceptableOrUnknown(
              data['updated_at_utc']!, _updatedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
          _deletedAtUtcMeta,
          deletedAtUtc.isAcceptableOrUnknown(
              data['deleted_at_utc']!, _deletedAtUtcMeta));
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WishRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      priority: $WishesTable.$converterpriority.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!),
      status: $WishesTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}progress'])!,
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}updated_at_utc'])!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}deleted_at_utc']),
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq']),
    );
  }

  @override
  $WishesTable createAlias(String alias) {
    return $WishesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Priority, int, int> $converterpriority =
      const EnumIndexConverter<Priority>(Priority.values);
  static JsonTypeConverter2<LifecycleStatus, int, int> $converterstatus =
      const EnumIndexConverter<LifecycleStatus>(LifecycleStatus.values);
}

class WishRow extends DataClass implements Insertable<WishRow> {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final Priority priority;
  final LifecycleStatus status;
  final int progress;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Soft-delete tombstone marker (auth spec Option B, R12.2). Null for a live
  /// Wish; set to the UTC delete time when the Wish is deleted, so sync can
  /// resolve a delete-vs-edit conflict by last-write-wins against
  /// [updatedAtUtc]. Added in schema v2; local reads filter these out.
  final DateTime? deletedAtUtc;

  /// Stable, monotonically increasing display number ("Wish #N"). Assigned once
  /// at creation as `max(seq) + 1` and never changed, so it survives reordering
  /// and filtering (unlike a list position). Nullable only to support the v2->v3
  /// migration backfill; every row created by the app carries a value. Added in
  /// schema v3.
  final int? seq;
  const WishRow(
      {required this.id,
      required this.title,
      this.description,
      required this.categoryId,
      required this.priority,
      required this.status,
      required this.progress,
      required this.createdAtUtc,
      required this.updatedAtUtc,
      this.deletedAtUtc,
      this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['category_id'] = Variable<String>(categoryId);
    {
      map['priority'] =
          Variable<int>($WishesTable.$converterpriority.toSql(priority));
    }
    {
      map['status'] =
          Variable<int>($WishesTable.$converterstatus.toSql(status));
    }
    map['progress'] = Variable<int>(progress);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    if (!nullToAbsent || seq != null) {
      map['seq'] = Variable<int>(seq);
    }
    return map;
  }

  WishesCompanion toCompanion(bool nullToAbsent) {
    return WishesCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      categoryId: Value(categoryId),
      priority: Value(priority),
      status: Value(status),
      progress: Value(progress),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      seq: seq == null && nullToAbsent ? const Value.absent() : Value(seq),
    );
  }

  factory WishRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      priority: $WishesTable.$converterpriority
          .fromJson(serializer.fromJson<int>(json['priority'])),
      status: $WishesTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      progress: serializer.fromJson<int>(json['progress']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
      seq: serializer.fromJson<int?>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'categoryId': serializer.toJson<String>(categoryId),
      'priority': serializer
          .toJson<int>($WishesTable.$converterpriority.toJson(priority)),
      'status':
          serializer.toJson<int>($WishesTable.$converterstatus.toJson(status)),
      'progress': serializer.toJson<int>(progress),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
      'seq': serializer.toJson<int?>(seq),
    };
  }

  WishRow copyWith(
          {String? id,
          String? title,
          Value<String?> description = const Value.absent(),
          String? categoryId,
          Priority? priority,
          LifecycleStatus? status,
          int? progress,
          DateTime? createdAtUtc,
          DateTime? updatedAtUtc,
          Value<DateTime?> deletedAtUtc = const Value.absent(),
          Value<int?> seq = const Value.absent()}) =>
      WishRow(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        categoryId: categoryId ?? this.categoryId,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
        deletedAtUtc:
            deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
        seq: seq.present ? seq.value : this.seq,
      );
  WishRow copyWithCompanion(WishesCompanion data) {
    return WishRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, description, categoryId, priority,
      status, progress, createdAtUtc, updatedAtUtc, deletedAtUtc, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.categoryId == this.categoryId &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.seq == this.seq);
}

class WishesCompanion extends UpdateCompanion<WishRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> categoryId;
  final Value<Priority> priority;
  final Value<LifecycleStatus> status;
  final Value<int> progress;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<DateTime?> deletedAtUtc;
  final Value<int?> seq;
  final Value<int> rowid;
  const WishesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishesCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required String categoryId,
    required Priority priority,
    required LifecycleStatus status,
    required int progress,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.deletedAtUtc = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        categoryId = Value(categoryId),
        priority = Value(priority),
        status = Value(status),
        progress = Value(progress),
        createdAtUtc = Value(createdAtUtc),
        updatedAtUtc = Value(updatedAtUtc);
  static Insertable<WishRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? categoryId,
    Expression<int>? priority,
    Expression<int>? status,
    Expression<int>? progress,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<DateTime>? deletedAtUtc,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishesCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? description,
      Value<String>? categoryId,
      Value<Priority>? priority,
      Value<LifecycleStatus>? status,
      Value<int>? progress,
      Value<DateTime>? createdAtUtc,
      Value<DateTime>? updatedAtUtc,
      Value<DateTime?>? deletedAtUtc,
      Value<int?>? seq,
      Value<int>? rowid}) {
    return WishesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (priority.present) {
      map['priority'] =
          Variable<int>($WishesTable.$converterpriority.toSql(priority.value));
    }
    if (status.present) {
      map['status'] =
          Variable<int>($WishesTable.$converterstatus.toSql(status.value));
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) => SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
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
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingRow> custom({
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

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
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

class $WishImagesTable extends WishImages
    with TableInfo<$WishImagesTable, WishImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wishIdMeta = const VerificationMeta('wishId');
  @override
  late final GeneratedColumn<String> wishId = GeneratedColumn<String>(
      'wish_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES wishes(id) ON DELETE CASCADE');
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
      'bytes', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtUtcMeta =
      const VerificationMeta('createdAtUtc');
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
      'created_at_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _remoteNameMeta =
      const VerificationMeta('remoteName');
  @override
  late final GeneratedColumn<String> remoteName = GeneratedColumn<String>(
      'remote_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtUtcMeta =
      const VerificationMeta('deletedAtUtc');
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
      'deleted_at_utc', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        wishId,
        bytes,
        mimeType,
        position,
        createdAtUtc,
        remoteName,
        deletedAtUtc
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wish_images';
  @override
  VerificationContext validateIntegrity(Insertable<WishImageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wish_id')) {
      context.handle(_wishIdMeta,
          wishId.isAcceptableOrUnknown(data['wish_id']!, _wishIdMeta));
    } else if (isInserting) {
      context.missing(_wishIdMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
          _createdAtUtcMeta,
          createdAtUtc.isAcceptableOrUnknown(
              data['created_at_utc']!, _createdAtUtcMeta));
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('remote_name')) {
      context.handle(
          _remoteNameMeta,
          remoteName.isAcceptableOrUnknown(
              data['remote_name']!, _remoteNameMeta));
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
          _deletedAtUtcMeta,
          deletedAtUtc.isAcceptableOrUnknown(
              data['deleted_at_utc']!, _deletedAtUtcMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WishImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishImageRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      wishId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wish_id'])!,
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}bytes'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      createdAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}created_at_utc'])!,
      remoteName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_name']),
      deletedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}deleted_at_utc']),
    );
  }

  @override
  $WishImagesTable createAlias(String alias) {
    return $WishImagesTable(attachedDatabase, alias);
  }
}

class WishImageRow extends DataClass implements Insertable<WishImageRow> {
  final String id;
  final String wishId;
  final Uint8List bytes;
  final String mimeType;
  final int position;
  final DateTime createdAtUtc;
  final String? remoteName;
  final DateTime? deletedAtUtc;
  const WishImageRow(
      {required this.id,
      required this.wishId,
      required this.bytes,
      required this.mimeType,
      required this.position,
      required this.createdAtUtc,
      this.remoteName,
      this.deletedAtUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wish_id'] = Variable<String>(wishId);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['mime_type'] = Variable<String>(mimeType);
    map['position'] = Variable<int>(position);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || remoteName != null) {
      map['remote_name'] = Variable<String>(remoteName);
    }
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    return map;
  }

  WishImagesCompanion toCompanion(bool nullToAbsent) {
    return WishImagesCompanion(
      id: Value(id),
      wishId: Value(wishId),
      bytes: Value(bytes),
      mimeType: Value(mimeType),
      position: Value(position),
      createdAtUtc: Value(createdAtUtc),
      remoteName: remoteName == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteName),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory WishImageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishImageRow(
      id: serializer.fromJson<String>(json['id']),
      wishId: serializer.fromJson<String>(json['wishId']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      position: serializer.fromJson<int>(json['position']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      remoteName: serializer.fromJson<String?>(json['remoteName']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'wishId': serializer.toJson<String>(wishId),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'mimeType': serializer.toJson<String>(mimeType),
      'position': serializer.toJson<int>(position),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'remoteName': serializer.toJson<String?>(remoteName),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
    };
  }

  WishImageRow copyWith(
          {String? id,
          String? wishId,
          Uint8List? bytes,
          String? mimeType,
          int? position,
          DateTime? createdAtUtc,
          Value<String?> remoteName = const Value.absent(),
          Value<DateTime?> deletedAtUtc = const Value.absent()}) =>
      WishImageRow(
        id: id ?? this.id,
        wishId: wishId ?? this.wishId,
        bytes: bytes ?? this.bytes,
        mimeType: mimeType ?? this.mimeType,
        position: position ?? this.position,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        remoteName: remoteName.present ? remoteName.value : this.remoteName,
        deletedAtUtc:
            deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
      );
  WishImageRow copyWithCompanion(WishImagesCompanion data) {
    return WishImageRow(
      id: data.id.present ? data.id.value : this.id,
      wishId: data.wishId.present ? data.wishId.value : this.wishId,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      position: data.position.present ? data.position.value : this.position,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      remoteName:
          data.remoteName.present ? data.remoteName.value : this.remoteName,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishImageRow(')
          ..write('id: $id, ')
          ..write('wishId: $wishId, ')
          ..write('bytes: $bytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('position: $position, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('remoteName: $remoteName, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, wishId, $driftBlobEquality.hash(bytes),
      mimeType, position, createdAtUtc, remoteName, deletedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishImageRow &&
          other.id == this.id &&
          other.wishId == this.wishId &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.mimeType == this.mimeType &&
          other.position == this.position &&
          other.createdAtUtc == this.createdAtUtc &&
          other.remoteName == this.remoteName &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class WishImagesCompanion extends UpdateCompanion<WishImageRow> {
  final Value<String> id;
  final Value<String> wishId;
  final Value<Uint8List> bytes;
  final Value<String> mimeType;
  final Value<int> position;
  final Value<DateTime> createdAtUtc;
  final Value<String?> remoteName;
  final Value<DateTime?> deletedAtUtc;
  final Value<int> rowid;
  const WishImagesCompanion({
    this.id = const Value.absent(),
    this.wishId = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.remoteName = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishImagesCompanion.insert({
    required String id,
    required String wishId,
    required Uint8List bytes,
    required String mimeType,
    this.position = const Value.absent(),
    required DateTime createdAtUtc,
    this.remoteName = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        wishId = Value(wishId),
        bytes = Value(bytes),
        mimeType = Value(mimeType),
        createdAtUtc = Value(createdAtUtc);
  static Insertable<WishImageRow> custom({
    Expression<String>? id,
    Expression<String>? wishId,
    Expression<Uint8List>? bytes,
    Expression<String>? mimeType,
    Expression<int>? position,
    Expression<DateTime>? createdAtUtc,
    Expression<String>? remoteName,
    Expression<DateTime>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wishId != null) 'wish_id': wishId,
      if (bytes != null) 'bytes': bytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (position != null) 'position': position,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (remoteName != null) 'remote_name': remoteName,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishImagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? wishId,
      Value<Uint8List>? bytes,
      Value<String>? mimeType,
      Value<int>? position,
      Value<DateTime>? createdAtUtc,
      Value<String?>? remoteName,
      Value<DateTime?>? deletedAtUtc,
      Value<int>? rowid}) {
    return WishImagesCompanion(
      id: id ?? this.id,
      wishId: wishId ?? this.wishId,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      position: position ?? this.position,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      remoteName: remoteName ?? this.remoteName,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (wishId.present) {
      map['wish_id'] = Variable<String>(wishId.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (remoteName.present) {
      map['remote_name'] = Variable<String>(remoteName.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishImagesCompanion(')
          ..write('id: $id, ')
          ..write('wishId: $wishId, ')
          ..write('bytes: $bytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('position: $position, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('remoteName: $remoteName, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $WishesTable wishes = $WishesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $WishImagesTable wishImages = $WishImagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [categories, wishes, settings, wishImages];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('wishes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('wish_images', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  Value<bool> isPreset,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<bool> isPreset,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WishesTable, List<WishRow>> _wishesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.wishes,
          aliasName:
              $_aliasNameGenerator(db.categories.id, db.wishes.categoryId));

  $$WishesTableProcessedTableManager get wishesRefs {
    final manager = $$WishesTableTableManager($_db, $_db.wishes)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wishesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPreset => $composableBuilder(
      column: $table.isPreset, builder: (column) => ColumnFilters(column));

  Expression<bool> wishesRefs(
      Expression<bool> Function($$WishesTableFilterComposer f) f) {
    final $$WishesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishes,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishesTableFilterComposer(
              $db: $db,
              $table: $db.wishes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPreset => $composableBuilder(
      column: $table.isPreset, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isPreset =>
      $composableBuilder(column: $table.isPreset, builder: (column) => column);

  Expression<T> wishesRefs<T extends Object>(
      Expression<T> Function($$WishesTableAnnotationComposer a) f) {
    final $$WishesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishes,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishesTableAnnotationComposer(
              $db: $db,
              $table: $db.wishes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    CategoryRow,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (CategoryRow, $$CategoriesTableReferences),
    CategoryRow,
    PrefetchHooks Function({bool wishesRefs})> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> isPreset = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            isPreset: isPreset,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<bool> isPreset = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            isPreset: isPreset,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({wishesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (wishesRefs) db.wishes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wishesRefs)
                    await $_getPrefetchedData<CategoryRow, $CategoriesTable,
                            WishRow>(
                        currentTable: table,
                        referencedTable:
                            $$CategoriesTableReferences._wishesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .wishesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    CategoryRow,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (CategoryRow, $$CategoriesTableReferences),
    CategoryRow,
    PrefetchHooks Function({bool wishesRefs})>;
typedef $$WishesTableCreateCompanionBuilder = WishesCompanion Function({
  required String id,
  required String title,
  Value<String?> description,
  required String categoryId,
  required Priority priority,
  required LifecycleStatus status,
  required int progress,
  required DateTime createdAtUtc,
  required DateTime updatedAtUtc,
  Value<DateTime?> deletedAtUtc,
  Value<int?> seq,
  Value<int> rowid,
});
typedef $$WishesTableUpdateCompanionBuilder = WishesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> description,
  Value<String> categoryId,
  Value<Priority> priority,
  Value<LifecycleStatus> status,
  Value<int> progress,
  Value<DateTime> createdAtUtc,
  Value<DateTime> updatedAtUtc,
  Value<DateTime?> deletedAtUtc,
  Value<int?> seq,
  Value<int> rowid,
});

final class $$WishesTableReferences
    extends BaseReferences<_$AppDatabase, $WishesTable, WishRow> {
  $$WishesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
          $_aliasNameGenerator(db.wishes.categoryId, db.categories.id));

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$WishImagesTable, List<WishImageRow>>
      _wishImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.wishImages,
          aliasName: $_aliasNameGenerator(db.wishes.id, db.wishImages.wishId));

  $$WishImagesTableProcessedTableManager get wishImagesRefs {
    final manager = $$WishImagesTableTableManager($_db, $_db.wishImages)
        .filter((f) => f.wishId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wishImagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$WishesTableFilterComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Priority, Priority, int> get priority =>
      $composableBuilder(
          column: $table.priority,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<LifecycleStatus, LifecycleStatus, int>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
      column: $table.updatedAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> wishImagesRefs(
      Expression<bool> Function($$WishImagesTableFilterComposer f) f) {
    final $$WishImagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishImages,
        getReferencedColumn: (t) => t.wishId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishImagesTableFilterComposer(
              $db: $db,
              $table: $db.wishImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WishesTableOrderingComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
      column: $table.updatedAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishesTable> {
  $$WishesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Priority, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LifecycleStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
      column: $table.updatedAtUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> wishImagesRefs<T extends Object>(
      Expression<T> Function($$WishImagesTableAnnotationComposer a) f) {
    final $$WishImagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.wishImages,
        getReferencedColumn: (t) => t.wishId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishImagesTableAnnotationComposer(
              $db: $db,
              $table: $db.wishImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WishesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WishesTable,
    WishRow,
    $$WishesTableFilterComposer,
    $$WishesTableOrderingComposer,
    $$WishesTableAnnotationComposer,
    $$WishesTableCreateCompanionBuilder,
    $$WishesTableUpdateCompanionBuilder,
    (WishRow, $$WishesTableReferences),
    WishRow,
    PrefetchHooks Function({bool categoryId, bool wishImagesRefs})> {
  $$WishesTableTableManager(_$AppDatabase db, $WishesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<Priority> priority = const Value.absent(),
            Value<LifecycleStatus> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<DateTime> updatedAtUtc = const Value.absent(),
            Value<DateTime?> deletedAtUtc = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishesCompanion(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            priority: priority,
            status: status,
            progress: progress,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            deletedAtUtc: deletedAtUtc,
            seq: seq,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> description = const Value.absent(),
            required String categoryId,
            required Priority priority,
            required LifecycleStatus status,
            required int progress,
            required DateTime createdAtUtc,
            required DateTime updatedAtUtc,
            Value<DateTime?> deletedAtUtc = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishesCompanion.insert(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            priority: priority,
            status: status,
            progress: progress,
            createdAtUtc: createdAtUtc,
            updatedAtUtc: updatedAtUtc,
            deletedAtUtc: deletedAtUtc,
            seq: seq,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$WishesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {categoryId = false, wishImagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (wishImagesRefs) db.wishImages],
              addJoins: <
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
                      dynamic>>(state) {
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$WishesTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$WishesTableReferences._categoryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wishImagesRefs)
                    await $_getPrefetchedData<WishRow, $WishesTable,
                            WishImageRow>(
                        currentTable: table,
                        referencedTable:
                            $$WishesTableReferences._wishImagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$WishesTableReferences(db, table, p0)
                                .wishImagesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.wishId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$WishesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WishesTable,
    WishRow,
    $$WishesTableFilterComposer,
    $$WishesTableOrderingComposer,
    $$WishesTableAnnotationComposer,
    $$WishesTableCreateCompanionBuilder,
    $$WishesTableUpdateCompanionBuilder,
    (WishRow, $$WishesTableReferences),
    WishRow,
    PrefetchHooks Function({bool categoryId, bool wishImagesRefs})>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
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
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
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
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
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

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()>;
typedef $$WishImagesTableCreateCompanionBuilder = WishImagesCompanion Function({
  required String id,
  required String wishId,
  required Uint8List bytes,
  required String mimeType,
  Value<int> position,
  required DateTime createdAtUtc,
  Value<String?> remoteName,
  Value<DateTime?> deletedAtUtc,
  Value<int> rowid,
});
typedef $$WishImagesTableUpdateCompanionBuilder = WishImagesCompanion Function({
  Value<String> id,
  Value<String> wishId,
  Value<Uint8List> bytes,
  Value<String> mimeType,
  Value<int> position,
  Value<DateTime> createdAtUtc,
  Value<String?> remoteName,
  Value<DateTime?> deletedAtUtc,
  Value<int> rowid,
});

final class $$WishImagesTableReferences
    extends BaseReferences<_$AppDatabase, $WishImagesTable, WishImageRow> {
  $$WishImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WishesTable _wishIdTable(_$AppDatabase db) => db.wishes
      .createAlias($_aliasNameGenerator(db.wishImages.wishId, db.wishes.id));

  $$WishesTableProcessedTableManager get wishId {
    final $_column = $_itemColumn<String>('wish_id')!;

    final manager = $$WishesTableTableManager($_db, $_db.wishes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wishIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WishImagesTableFilterComposer
    extends Composer<_$AppDatabase, $WishImagesTable> {
  $$WishImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteName => $composableBuilder(
      column: $table.remoteName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc, builder: (column) => ColumnFilters(column));

  $$WishesTableFilterComposer get wishId {
    final $$WishesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.wishId,
        referencedTable: $db.wishes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishesTableFilterComposer(
              $db: $db,
              $table: $db.wishes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $WishImagesTable> {
  $$WishImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteName => $composableBuilder(
      column: $table.remoteName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc,
      builder: (column) => ColumnOrderings(column));

  $$WishesTableOrderingComposer get wishId {
    final $$WishesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.wishId,
        referencedTable: $db.wishes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishesTableOrderingComposer(
              $db: $db,
              $table: $db.wishes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishImagesTable> {
  $$WishImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
      column: $table.createdAtUtc, builder: (column) => column);

  GeneratedColumn<String> get remoteName => $composableBuilder(
      column: $table.remoteName, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
      column: $table.deletedAtUtc, builder: (column) => column);

  $$WishesTableAnnotationComposer get wishId {
    final $$WishesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.wishId,
        referencedTable: $db.wishes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WishesTableAnnotationComposer(
              $db: $db,
              $table: $db.wishes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WishImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WishImagesTable,
    WishImageRow,
    $$WishImagesTableFilterComposer,
    $$WishImagesTableOrderingComposer,
    $$WishImagesTableAnnotationComposer,
    $$WishImagesTableCreateCompanionBuilder,
    $$WishImagesTableUpdateCompanionBuilder,
    (WishImageRow, $$WishImagesTableReferences),
    WishImageRow,
    PrefetchHooks Function({bool wishId})> {
  $$WishImagesTableTableManager(_$AppDatabase db, $WishImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> wishId = const Value.absent(),
            Value<Uint8List> bytes = const Value.absent(),
            Value<String> mimeType = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> createdAtUtc = const Value.absent(),
            Value<String?> remoteName = const Value.absent(),
            Value<DateTime?> deletedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishImagesCompanion(
            id: id,
            wishId: wishId,
            bytes: bytes,
            mimeType: mimeType,
            position: position,
            createdAtUtc: createdAtUtc,
            remoteName: remoteName,
            deletedAtUtc: deletedAtUtc,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String wishId,
            required Uint8List bytes,
            required String mimeType,
            Value<int> position = const Value.absent(),
            required DateTime createdAtUtc,
            Value<String?> remoteName = const Value.absent(),
            Value<DateTime?> deletedAtUtc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WishImagesCompanion.insert(
            id: id,
            wishId: wishId,
            bytes: bytes,
            mimeType: mimeType,
            position: position,
            createdAtUtc: createdAtUtc,
            remoteName: remoteName,
            deletedAtUtc: deletedAtUtc,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WishImagesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({wishId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (wishId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.wishId,
                    referencedTable:
                        $$WishImagesTableReferences._wishIdTable(db),
                    referencedColumn:
                        $$WishImagesTableReferences._wishIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WishImagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WishImagesTable,
    WishImageRow,
    $$WishImagesTableFilterComposer,
    $$WishImagesTableOrderingComposer,
    $$WishImagesTableAnnotationComposer,
    $$WishImagesTableCreateCompanionBuilder,
    $$WishImagesTableUpdateCompanionBuilder,
    (WishImageRow, $$WishImagesTableReferences),
    WishImageRow,
    PrefetchHooks Function({bool wishId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$WishesTableTableManager get wishes =>
      $$WishesTableTableManager(_db, _db.wishes);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$WishImagesTableTableManager get wishImages =>
      $$WishImagesTableTableManager(_db, _db.wishImages);
}
