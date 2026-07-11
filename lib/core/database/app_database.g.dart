// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paraIdMeta = const VerificationMeta('paraId');
  @override
  late final GeneratedColumn<int> paraId = GeneratedColumn<int>(
    'para_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
    'line_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<String> pageNumber = GeneratedColumn<String>(
    'page_number',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    bookId,
    paraId,
    lineId,
    bookName,
    pageNumber,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
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
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('para_id')) {
      context.handle(
        _paraIdMeta,
        paraId.isAcceptableOrUnknown(data['para_id']!, _paraIdMeta),
      );
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      ),
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_id'],
      ),
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_number'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;
  final String name;
  final String bookId;
  final int? paraId;
  final int? lineId;
  final String? bookName;
  final String? pageNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.name,
    required this.bookId,
    this.paraId,
    this.lineId,
    this.bookName,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || paraId != null) {
      map['para_id'] = Variable<int>(paraId);
    }
    if (!nullToAbsent || lineId != null) {
      map['line_id'] = Variable<int>(lineId);
    }
    if (!nullToAbsent || bookName != null) {
      map['book_name'] = Variable<String>(bookName);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<String>(pageNumber);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      name: Value(name),
      bookId: Value(bookId),
      paraId: paraId == null && nullToAbsent
          ? const Value.absent()
          : Value(paraId),
      lineId: lineId == null && nullToAbsent
          ? const Value.absent()
          : Value(lineId),
      bookName: bookName == null && nullToAbsent
          ? const Value.absent()
          : Value(bookName),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bookId: serializer.fromJson<String>(json['bookId']),
      paraId: serializer.fromJson<int?>(json['paraId']),
      lineId: serializer.fromJson<int?>(json['lineId']),
      bookName: serializer.fromJson<String?>(json['bookName']),
      pageNumber: serializer.fromJson<String?>(json['pageNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'bookId': serializer.toJson<String>(bookId),
      'paraId': serializer.toJson<int?>(paraId),
      'lineId': serializer.toJson<int?>(lineId),
      'bookName': serializer.toJson<String?>(bookName),
      'pageNumber': serializer.toJson<String?>(pageNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    int? id,
    String? name,
    String? bookId,
    Value<int?> paraId = const Value.absent(),
    Value<int?> lineId = const Value.absent(),
    Value<String?> bookName = const Value.absent(),
    Value<String?> pageNumber = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    name: name ?? this.name,
    bookId: bookId ?? this.bookId,
    paraId: paraId.present ? paraId.value : this.paraId,
    lineId: lineId.present ? lineId.value : this.lineId,
    bookName: bookName.present ? bookName.value : this.bookName,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('bookName: $bookName, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bookId,
    paraId,
    lineId,
    bookName,
    pageNumber,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.name == this.name &&
          other.bookId == this.bookId &&
          other.paraId == this.paraId &&
          other.lineId == this.lineId &&
          other.bookName == this.bookName &&
          other.pageNumber == this.pageNumber &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> bookId;
  final Value<int?> paraId;
  final Value<int?> lineId;
  final Value<String?> bookName;
  final Value<String?> pageNumber;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bookId = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String bookId,
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.pageNumber = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       bookId = Value(bookId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? bookId,
    Expression<int>? paraId,
    Expression<int>? lineId,
    Expression<String>? bookName,
    Expression<String>? pageNumber,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bookId != null) 'book_id': bookId,
      if (paraId != null) 'para_id': paraId,
      if (lineId != null) 'line_id': lineId,
      if (bookName != null) 'book_name': bookName,
      if (pageNumber != null) 'page_number': pageNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? bookId,
    Value<int?>? paraId,
    Value<int?>? lineId,
    Value<String?>? bookName,
    Value<String?>? pageNumber,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bookId: bookId ?? this.bookId,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      bookName: bookName ?? this.bookName,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (paraId.present) {
      map['para_id'] = Variable<int>(paraId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<String>(pageNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('bookName: $bookName, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingHistoryTable extends ReadingHistory
    with TableInfo<$ReadingHistoryTable, ReadingHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paraIdMeta = const VerificationMeta('paraId');
  @override
  late final GeneratedColumn<int> paraId = GeneratedColumn<int>(
    'para_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
    'line_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readCountMeta = const VerificationMeta(
    'readCount',
  );
  @override
  late final GeneratedColumn<int> readCount = GeneratedColumn<int>(
    'read_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    bookName,
    paraId,
    lineId,
    openedAt,
    updatedAt,
    readCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    }
    if (data.containsKey('para_id')) {
      context.handle(
        _paraIdMeta,
        paraId.isAcceptableOrUnknown(data['para_id']!, _paraIdMeta),
      );
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('read_count')) {
      context.handle(
        _readCountMeta,
        readCount.isAcceptableOrUnknown(data['read_count']!, _readCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      ),
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      ),
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_id'],
      ),
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      readCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_count'],
      )!,
    );
  }

  @override
  $ReadingHistoryTable createAlias(String alias) {
    return $ReadingHistoryTable(attachedDatabase, alias);
  }
}

class ReadingHistoryData extends DataClass
    implements Insertable<ReadingHistoryData> {
  final int id;
  final String bookId;
  final String? bookName;
  final int? paraId;
  final int? lineId;
  final DateTime openedAt;
  final DateTime updatedAt;
  final int readCount;
  const ReadingHistoryData({
    required this.id,
    required this.bookId,
    this.bookName,
    this.paraId,
    this.lineId,
    required this.openedAt,
    required this.updatedAt,
    required this.readCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || bookName != null) {
      map['book_name'] = Variable<String>(bookName);
    }
    if (!nullToAbsent || paraId != null) {
      map['para_id'] = Variable<int>(paraId);
    }
    if (!nullToAbsent || lineId != null) {
      map['line_id'] = Variable<int>(lineId);
    }
    map['opened_at'] = Variable<DateTime>(openedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['read_count'] = Variable<int>(readCount);
    return map;
  }

  ReadingHistoryCompanion toCompanion(bool nullToAbsent) {
    return ReadingHistoryCompanion(
      id: Value(id),
      bookId: Value(bookId),
      bookName: bookName == null && nullToAbsent
          ? const Value.absent()
          : Value(bookName),
      paraId: paraId == null && nullToAbsent
          ? const Value.absent()
          : Value(paraId),
      lineId: lineId == null && nullToAbsent
          ? const Value.absent()
          : Value(lineId),
      openedAt: Value(openedAt),
      updatedAt: Value(updatedAt),
      readCount: Value(readCount),
    );
  }

  factory ReadingHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingHistoryData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookName: serializer.fromJson<String?>(json['bookName']),
      paraId: serializer.fromJson<int?>(json['paraId']),
      lineId: serializer.fromJson<int?>(json['lineId']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      readCount: serializer.fromJson<int>(json['readCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'bookName': serializer.toJson<String?>(bookName),
      'paraId': serializer.toJson<int?>(paraId),
      'lineId': serializer.toJson<int?>(lineId),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'readCount': serializer.toJson<int>(readCount),
    };
  }

  ReadingHistoryData copyWith({
    int? id,
    String? bookId,
    Value<String?> bookName = const Value.absent(),
    Value<int?> paraId = const Value.absent(),
    Value<int?> lineId = const Value.absent(),
    DateTime? openedAt,
    DateTime? updatedAt,
    int? readCount,
  }) => ReadingHistoryData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    bookName: bookName.present ? bookName.value : this.bookName,
    paraId: paraId.present ? paraId.value : this.paraId,
    lineId: lineId.present ? lineId.value : this.lineId,
    openedAt: openedAt ?? this.openedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    readCount: readCount ?? this.readCount,
  );
  ReadingHistoryData copyWithCompanion(ReadingHistoryCompanion data) {
    return ReadingHistoryData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      readCount: data.readCount.present ? data.readCount.value : this.readCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoryData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('openedAt: $openedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('readCount: $readCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    bookName,
    paraId,
    lineId,
    openedAt,
    updatedAt,
    readCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingHistoryData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.bookName == this.bookName &&
          other.paraId == this.paraId &&
          other.lineId == this.lineId &&
          other.openedAt == this.openedAt &&
          other.updatedAt == this.updatedAt &&
          other.readCount == this.readCount);
}

class ReadingHistoryCompanion extends UpdateCompanion<ReadingHistoryData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String?> bookName;
  final Value<int?> paraId;
  final Value<int?> lineId;
  final Value<DateTime> openedAt;
  final Value<DateTime> updatedAt;
  final Value<int> readCount;
  const ReadingHistoryCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.readCount = const Value.absent(),
  });
  ReadingHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    this.bookName = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    required DateTime openedAt,
    required DateTime updatedAt,
    this.readCount = const Value.absent(),
  }) : bookId = Value(bookId),
       openedAt = Value(openedAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingHistoryData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? bookName,
    Expression<int>? paraId,
    Expression<int>? lineId,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? readCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (bookName != null) 'book_name': bookName,
      if (paraId != null) 'para_id': paraId,
      if (lineId != null) 'line_id': lineId,
      if (openedAt != null) 'opened_at': openedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (readCount != null) 'read_count': readCount,
    });
  }

  ReadingHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String?>? bookName,
    Value<int?>? paraId,
    Value<int?>? lineId,
    Value<DateTime>? openedAt,
    Value<DateTime>? updatedAt,
    Value<int>? readCount,
  }) {
    return ReadingHistoryCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      openedAt: openedAt ?? this.openedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readCount: readCount ?? this.readCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (paraId.present) {
      map['para_id'] = Variable<int>(paraId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (readCount.present) {
      map['read_count'] = Variable<int>(readCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoryCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('openedAt: $openedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('readCount: $readCount')
          ..write(')'))
        .toString();
  }
}

class $TtsReplacementsTable extends TtsReplacements
    with TableInfo<$TtsReplacementsTable, TtsReplacement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsReplacementsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replacementMeta = const VerificationMeta(
    'replacement',
  );
  @override
  late final GeneratedColumn<String> replacement = GeneratedColumn<String>(
    'replacement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRegexMeta = const VerificationMeta(
    'isRegex',
  );
  @override
  late final GeneratedColumn<bool> isRegex = GeneratedColumn<bool>(
    'is_regex',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_regex" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pattern,
    replacement,
    isRegex,
    enabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_replacements';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsReplacement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('replacement')) {
      context.handle(
        _replacementMeta,
        replacement.isAcceptableOrUnknown(
          data['replacement']!,
          _replacementMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_replacementMeta);
    }
    if (data.containsKey('is_regex')) {
      context.handle(
        _isRegexMeta,
        isRegex.isAcceptableOrUnknown(data['is_regex']!, _isRegexMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsReplacement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsReplacement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      replacement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement'],
      )!,
      isRegex: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_regex'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TtsReplacementsTable createAlias(String alias) {
    return $TtsReplacementsTable(attachedDatabase, alias);
  }
}

class TtsReplacement extends DataClass implements Insertable<TtsReplacement> {
  final int id;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool enabled;
  final DateTime createdAt;
  const TtsReplacement({
    required this.id,
    required this.pattern,
    required this.replacement,
    required this.isRegex,
    required this.enabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pattern'] = Variable<String>(pattern);
    map['replacement'] = Variable<String>(replacement);
    map['is_regex'] = Variable<bool>(isRegex);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TtsReplacementsCompanion toCompanion(bool nullToAbsent) {
    return TtsReplacementsCompanion(
      id: Value(id),
      pattern: Value(pattern),
      replacement: Value(replacement),
      isRegex: Value(isRegex),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
    );
  }

  factory TtsReplacement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsReplacement(
      id: serializer.fromJson<int>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      replacement: serializer.fromJson<String>(json['replacement']),
      isRegex: serializer.fromJson<bool>(json['isRegex']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pattern': serializer.toJson<String>(pattern),
      'replacement': serializer.toJson<String>(replacement),
      'isRegex': serializer.toJson<bool>(isRegex),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TtsReplacement copyWith({
    int? id,
    String? pattern,
    String? replacement,
    bool? isRegex,
    bool? enabled,
    DateTime? createdAt,
  }) => TtsReplacement(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    replacement: replacement ?? this.replacement,
    isRegex: isRegex ?? this.isRegex,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
  );
  TtsReplacement copyWithCompanion(TtsReplacementsCompanion data) {
    return TtsReplacement(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      replacement: data.replacement.present
          ? data.replacement.value
          : this.replacement,
      isRegex: data.isRegex.present ? data.isRegex.value : this.isRegex,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsReplacement(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('isRegex: $isRegex, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pattern, replacement, isRegex, enabled, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsReplacement &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.replacement == this.replacement &&
          other.isRegex == this.isRegex &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt);
}

class TtsReplacementsCompanion extends UpdateCompanion<TtsReplacement> {
  final Value<int> id;
  final Value<String> pattern;
  final Value<String> replacement;
  final Value<bool> isRegex;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  const TtsReplacementsCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.replacement = const Value.absent(),
    this.isRegex = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TtsReplacementsCompanion.insert({
    this.id = const Value.absent(),
    required String pattern,
    required String replacement,
    this.isRegex = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime createdAt,
  }) : pattern = Value(pattern),
       replacement = Value(replacement),
       createdAt = Value(createdAt);
  static Insertable<TtsReplacement> custom({
    Expression<int>? id,
    Expression<String>? pattern,
    Expression<String>? replacement,
    Expression<bool>? isRegex,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (replacement != null) 'replacement': replacement,
      if (isRegex != null) 'is_regex': isRegex,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TtsReplacementsCompanion copyWith({
    Value<int>? id,
    Value<String>? pattern,
    Value<String>? replacement,
    Value<bool>? isRegex,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
  }) {
    return TtsReplacementsCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      isRegex: isRegex ?? this.isRegex,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (replacement.present) {
      map['replacement'] = Variable<String>(replacement.value);
    }
    if (isRegex.present) {
      map['is_regex'] = Variable<bool>(isRegex.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsReplacementsCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('replacement: $replacement, ')
          ..write('isRegex: $isRegex, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadingHistoryTable readingHistory = $ReadingHistoryTable(this);
  late final $TtsReplacementsTable ttsReplacements = $TtsReplacementsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bookmarks,
    readingHistory,
    ttsReplacements,
  ];
}

typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      required String name,
      required String bookId,
      Value<int?> paraId,
      Value<int?> lineId,
      Value<String?> bookName,
      Value<String?> pageNumber,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> bookId,
      Value<int?> paraId,
      Value<int?> lineId,
      Value<String?> bookName,
      Value<String?> pageNumber,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
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

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get paraId =>
      $composableBuilder(column: $table.paraId, builder: (column) => column);

  GeneratedColumn<int> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int?> paraId = const Value.absent(),
                Value<int?> lineId = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> pageNumber = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                name: name,
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                bookName: bookName,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String bookId,
                Value<int?> paraId = const Value.absent(),
                Value<int?> lineId = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> pageNumber = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => BookmarksCompanion.insert(
                id: id,
                name: name,
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                bookName: bookName,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$ReadingHistoryTableCreateCompanionBuilder =
    ReadingHistoryCompanion Function({
      Value<int> id,
      required String bookId,
      Value<String?> bookName,
      Value<int?> paraId,
      Value<int?> lineId,
      required DateTime openedAt,
      required DateTime updatedAt,
      Value<int> readCount,
    });
typedef $$ReadingHistoryTableUpdateCompanionBuilder =
    ReadingHistoryCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String?> bookName,
      Value<int?> paraId,
      Value<int?> lineId,
      Value<DateTime> openedAt,
      Value<DateTime> updatedAt,
      Value<int> readCount,
    });

class $$ReadingHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readCount => $composableBuilder(
    column: $table.readCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readCount => $composableBuilder(
    column: $table.readCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingHistoryTable> {
  $$ReadingHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<int> get paraId =>
      $composableBuilder(column: $table.paraId, builder: (column) => column);

  GeneratedColumn<int> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get readCount =>
      $composableBuilder(column: $table.readCount, builder: (column) => column);
}

class $$ReadingHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingHistoryTable,
          ReadingHistoryData,
          $$ReadingHistoryTableFilterComposer,
          $$ReadingHistoryTableOrderingComposer,
          $$ReadingHistoryTableAnnotationComposer,
          $$ReadingHistoryTableCreateCompanionBuilder,
          $$ReadingHistoryTableUpdateCompanionBuilder,
          (
            ReadingHistoryData,
            BaseReferences<
              _$AppDatabase,
              $ReadingHistoryTable,
              ReadingHistoryData
            >,
          ),
          ReadingHistoryData,
          PrefetchHooks Function()
        > {
  $$ReadingHistoryTableTableManager(
    _$AppDatabase db,
    $ReadingHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<int?> paraId = const Value.absent(),
                Value<int?> lineId = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> readCount = const Value.absent(),
              }) => ReadingHistoryCompanion(
                id: id,
                bookId: bookId,
                bookName: bookName,
                paraId: paraId,
                lineId: lineId,
                openedAt: openedAt,
                updatedAt: updatedAt,
                readCount: readCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                Value<String?> bookName = const Value.absent(),
                Value<int?> paraId = const Value.absent(),
                Value<int?> lineId = const Value.absent(),
                required DateTime openedAt,
                required DateTime updatedAt,
                Value<int> readCount = const Value.absent(),
              }) => ReadingHistoryCompanion.insert(
                id: id,
                bookId: bookId,
                bookName: bookName,
                paraId: paraId,
                lineId: lineId,
                openedAt: openedAt,
                updatedAt: updatedAt,
                readCount: readCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingHistoryTable,
      ReadingHistoryData,
      $$ReadingHistoryTableFilterComposer,
      $$ReadingHistoryTableOrderingComposer,
      $$ReadingHistoryTableAnnotationComposer,
      $$ReadingHistoryTableCreateCompanionBuilder,
      $$ReadingHistoryTableUpdateCompanionBuilder,
      (
        ReadingHistoryData,
        BaseReferences<_$AppDatabase, $ReadingHistoryTable, ReadingHistoryData>,
      ),
      ReadingHistoryData,
      PrefetchHooks Function()
    >;
typedef $$TtsReplacementsTableCreateCompanionBuilder =
    TtsReplacementsCompanion Function({
      Value<int> id,
      required String pattern,
      required String replacement,
      Value<bool> isRegex,
      Value<bool> enabled,
      required DateTime createdAt,
    });
typedef $$TtsReplacementsTableUpdateCompanionBuilder =
    TtsReplacementsCompanion Function({
      Value<int> id,
      Value<String> pattern,
      Value<String> replacement,
      Value<bool> isRegex,
      Value<bool> enabled,
      Value<DateTime> createdAt,
    });

class $$TtsReplacementsTableFilterComposer
    extends Composer<_$AppDatabase, $TtsReplacementsTable> {
  $$TtsReplacementsTableFilterComposer({
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

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRegex => $composableBuilder(
    column: $table.isRegex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TtsReplacementsTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsReplacementsTable> {
  $$TtsReplacementsTableOrderingComposer({
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

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRegex => $composableBuilder(
    column: $table.isRegex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TtsReplacementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsReplacementsTable> {
  $$TtsReplacementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get replacement => $composableBuilder(
    column: $table.replacement,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRegex =>
      $composableBuilder(column: $table.isRegex, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TtsReplacementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsReplacementsTable,
          TtsReplacement,
          $$TtsReplacementsTableFilterComposer,
          $$TtsReplacementsTableOrderingComposer,
          $$TtsReplacementsTableAnnotationComposer,
          $$TtsReplacementsTableCreateCompanionBuilder,
          $$TtsReplacementsTableUpdateCompanionBuilder,
          (
            TtsReplacement,
            BaseReferences<
              _$AppDatabase,
              $TtsReplacementsTable,
              TtsReplacement
            >,
          ),
          TtsReplacement,
          PrefetchHooks Function()
        > {
  $$TtsReplacementsTableTableManager(
    _$AppDatabase db,
    $TtsReplacementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsReplacementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsReplacementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsReplacementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String> replacement = const Value.absent(),
                Value<bool> isRegex = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TtsReplacementsCompanion(
                id: id,
                pattern: pattern,
                replacement: replacement,
                isRegex: isRegex,
                enabled: enabled,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pattern,
                required String replacement,
                Value<bool> isRegex = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime createdAt,
              }) => TtsReplacementsCompanion.insert(
                id: id,
                pattern: pattern,
                replacement: replacement,
                isRegex: isRegex,
                enabled: enabled,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TtsReplacementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsReplacementsTable,
      TtsReplacement,
      $$TtsReplacementsTableFilterComposer,
      $$TtsReplacementsTableOrderingComposer,
      $$TtsReplacementsTableAnnotationComposer,
      $$TtsReplacementsTableCreateCompanionBuilder,
      $$TtsReplacementsTableUpdateCompanionBuilder,
      (
        TtsReplacement,
        BaseReferences<_$AppDatabase, $TtsReplacementsTable, TtsReplacement>,
      ),
      TtsReplacement,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadingHistoryTableTableManager get readingHistory =>
      $$ReadingHistoryTableTableManager(_db, _db.readingHistory);
  $$TtsReplacementsTableTableManager get ttsReplacements =>
      $$TtsReplacementsTableTableManager(_db, _db.ttsReplacements);
}
