// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nissaya_database.dart';

// ignore_for_file: type=lint
class $NissayaSentencesTable extends NissayaSentences
    with TableInfo<$NissayaSentencesTable, NissayaSentence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NissayaSentencesTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nissayaIdMeta = const VerificationMeta(
    'nissayaId',
  );
  @override
  late final GeneratedColumn<int> nissayaId = GeneratedColumn<int>(
    'nissaya_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    paraId,
    lineId,
    content,
    nissayaId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nissaya_sentences';
  @override
  VerificationContext validateIntegrity(
    Insertable<NissayaSentence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    } else if (isInserting) {
      context.missing(_paraIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('nissaya_id')) {
      context.handle(
        _nissayaIdMeta,
        nissayaId.isAcceptableOrUnknown(data['nissaya_id']!, _nissayaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nissayaIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nissayaId, bookId, paraId, lineId};
  @override
  NissayaSentence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NissayaSentence(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      nissayaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nissaya_id'],
      )!,
    );
  }

  @override
  $NissayaSentencesTable createAlias(String alias) {
    return $NissayaSentencesTable(attachedDatabase, alias);
  }
}

class NissayaSentence extends DataClass implements Insertable<NissayaSentence> {
  final String bookId;
  final int paraId;
  final int lineId;
  final String? content;
  final int nissayaId;
  const NissayaSentence({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.content,
    required this.nissayaId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['para_id'] = Variable<int>(paraId);
    map['line_id'] = Variable<int>(lineId);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['nissaya_id'] = Variable<int>(nissayaId);
    return map;
  }

  NissayaSentencesCompanion toCompanion(bool nullToAbsent) {
    return NissayaSentencesCompanion(
      bookId: Value(bookId),
      paraId: Value(paraId),
      lineId: Value(lineId),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      nissayaId: Value(nissayaId),
    );
  }

  factory NissayaSentence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NissayaSentence(
      bookId: serializer.fromJson<String>(json['bookId']),
      paraId: serializer.fromJson<int>(json['paraId']),
      lineId: serializer.fromJson<int>(json['lineId']),
      content: serializer.fromJson<String?>(json['content']),
      nissayaId: serializer.fromJson<int>(json['nissayaId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'paraId': serializer.toJson<int>(paraId),
      'lineId': serializer.toJson<int>(lineId),
      'content': serializer.toJson<String?>(content),
      'nissayaId': serializer.toJson<int>(nissayaId),
    };
  }

  NissayaSentence copyWith({
    String? bookId,
    int? paraId,
    int? lineId,
    Value<String?> content = const Value.absent(),
    int? nissayaId,
  }) => NissayaSentence(
    bookId: bookId ?? this.bookId,
    paraId: paraId ?? this.paraId,
    lineId: lineId ?? this.lineId,
    content: content.present ? content.value : this.content,
    nissayaId: nissayaId ?? this.nissayaId,
  );
  NissayaSentence copyWithCompanion(NissayaSentencesCompanion data) {
    return NissayaSentence(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      content: data.content.present ? data.content.value : this.content,
      nissayaId: data.nissayaId.present ? data.nissayaId.value : this.nissayaId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NissayaSentence(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('content: $content, ')
          ..write('nissayaId: $nissayaId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, paraId, lineId, content, nissayaId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NissayaSentence &&
          other.bookId == this.bookId &&
          other.paraId == this.paraId &&
          other.lineId == this.lineId &&
          other.content == this.content &&
          other.nissayaId == this.nissayaId);
}

class NissayaSentencesCompanion extends UpdateCompanion<NissayaSentence> {
  final Value<String> bookId;
  final Value<int> paraId;
  final Value<int> lineId;
  final Value<String?> content;
  final Value<int> nissayaId;
  final Value<int> rowid;
  const NissayaSentencesCompanion({
    this.bookId = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.content = const Value.absent(),
    this.nissayaId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NissayaSentencesCompanion.insert({
    required String bookId,
    required int paraId,
    required int lineId,
    this.content = const Value.absent(),
    required int nissayaId,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       paraId = Value(paraId),
       lineId = Value(lineId),
       nissayaId = Value(nissayaId);
  static Insertable<NissayaSentence> custom({
    Expression<String>? bookId,
    Expression<int>? paraId,
    Expression<int>? lineId,
    Expression<String>? content,
    Expression<int>? nissayaId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (paraId != null) 'para_id': paraId,
      if (lineId != null) 'line_id': lineId,
      if (content != null) 'content': content,
      if (nissayaId != null) 'nissaya_id': nissayaId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NissayaSentencesCompanion copyWith({
    Value<String>? bookId,
    Value<int>? paraId,
    Value<int>? lineId,
    Value<String?>? content,
    Value<int>? nissayaId,
    Value<int>? rowid,
  }) {
    return NissayaSentencesCompanion(
      bookId: bookId ?? this.bookId,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      content: content ?? this.content,
      nissayaId: nissayaId ?? this.nissayaId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (paraId.present) {
      map['para_id'] = Variable<int>(paraId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (nissayaId.present) {
      map['nissaya_id'] = Variable<int>(nissayaId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NissayaSentencesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('content: $content, ')
          ..write('nissayaId: $nissayaId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NissayaBooksTable extends NissayaBooks
    with TableInfo<$NissayaBooksTable, NissayaBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NissayaBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
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
  static const VerificationMeta _infoMeta = const VerificationMeta('info');
  @override
  late final GeneratedColumn<String> info = GeneratedColumn<String>(
    'info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, bookName, info];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nissaya_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<NissayaBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    }
    if (data.containsKey('info')) {
      context.handle(
        _infoMeta,
        info.isAcceptableOrUnknown(data['info']!, _infoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  NissayaBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NissayaBook(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      ),
      info: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info'],
      ),
    );
  }

  @override
  $NissayaBooksTable createAlias(String alias) {
    return $NissayaBooksTable(attachedDatabase, alias);
  }
}

class NissayaBook extends DataClass implements Insertable<NissayaBook> {
  final int bookId;
  final String? bookName;
  final String? info;
  const NissayaBook({required this.bookId, this.bookName, this.info});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || bookName != null) {
      map['book_name'] = Variable<String>(bookName);
    }
    if (!nullToAbsent || info != null) {
      map['info'] = Variable<String>(info);
    }
    return map;
  }

  NissayaBooksCompanion toCompanion(bool nullToAbsent) {
    return NissayaBooksCompanion(
      bookId: Value(bookId),
      bookName: bookName == null && nullToAbsent
          ? const Value.absent()
          : Value(bookName),
      info: info == null && nullToAbsent ? const Value.absent() : Value(info),
    );
  }

  factory NissayaBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NissayaBook(
      bookId: serializer.fromJson<int>(json['bookId']),
      bookName: serializer.fromJson<String?>(json['bookName']),
      info: serializer.fromJson<String?>(json['info']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'bookName': serializer.toJson<String?>(bookName),
      'info': serializer.toJson<String?>(info),
    };
  }

  NissayaBook copyWith({
    int? bookId,
    Value<String?> bookName = const Value.absent(),
    Value<String?> info = const Value.absent(),
  }) => NissayaBook(
    bookId: bookId ?? this.bookId,
    bookName: bookName.present ? bookName.value : this.bookName,
    info: info.present ? info.value : this.info,
  );
  NissayaBook copyWithCompanion(NissayaBooksCompanion data) {
    return NissayaBook(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      info: data.info.present ? data.info.value : this.info,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NissayaBook(')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('info: $info')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, bookName, info);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NissayaBook &&
          other.bookId == this.bookId &&
          other.bookName == this.bookName &&
          other.info == this.info);
}

class NissayaBooksCompanion extends UpdateCompanion<NissayaBook> {
  final Value<int> bookId;
  final Value<String?> bookName;
  final Value<String?> info;
  const NissayaBooksCompanion({
    this.bookId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.info = const Value.absent(),
  });
  NissayaBooksCompanion.insert({
    this.bookId = const Value.absent(),
    this.bookName = const Value.absent(),
    this.info = const Value.absent(),
  });
  static Insertable<NissayaBook> custom({
    Expression<int>? bookId,
    Expression<String>? bookName,
    Expression<String>? info,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (bookName != null) 'book_name': bookName,
      if (info != null) 'info': info,
    });
  }

  NissayaBooksCompanion copyWith({
    Value<int>? bookId,
    Value<String?>? bookName,
    Value<String?>? info,
  }) {
    return NissayaBooksCompanion(
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      info: info ?? this.info,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (info.present) {
      map['info'] = Variable<String>(info.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NissayaBooksCompanion(')
          ..write('bookId: $bookId, ')
          ..write('bookName: $bookName, ')
          ..write('info: $info')
          ..write(')'))
        .toString();
  }
}

abstract class _$NissayaDatabase extends GeneratedDatabase {
  _$NissayaDatabase(QueryExecutor e) : super(e);
  $NissayaDatabaseManager get managers => $NissayaDatabaseManager(this);
  late final $NissayaSentencesTable nissayaSentences = $NissayaSentencesTable(
    this,
  );
  late final $NissayaBooksTable nissayaBooks = $NissayaBooksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    nissayaSentences,
    nissayaBooks,
  ];
}

typedef $$NissayaSentencesTableCreateCompanionBuilder =
    NissayaSentencesCompanion Function({
      required String bookId,
      required int paraId,
      required int lineId,
      Value<String?> content,
      required int nissayaId,
      Value<int> rowid,
    });
typedef $$NissayaSentencesTableUpdateCompanionBuilder =
    NissayaSentencesCompanion Function({
      Value<String> bookId,
      Value<int> paraId,
      Value<int> lineId,
      Value<String?> content,
      Value<int> nissayaId,
      Value<int> rowid,
    });

class $$NissayaSentencesTableFilterComposer
    extends Composer<_$NissayaDatabase, $NissayaSentencesTable> {
  $$NissayaSentencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nissayaId => $composableBuilder(
    column: $table.nissayaId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NissayaSentencesTableOrderingComposer
    extends Composer<_$NissayaDatabase, $NissayaSentencesTable> {
  $$NissayaSentencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nissayaId => $composableBuilder(
    column: $table.nissayaId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NissayaSentencesTableAnnotationComposer
    extends Composer<_$NissayaDatabase, $NissayaSentencesTable> {
  $$NissayaSentencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get paraId =>
      $composableBuilder(column: $table.paraId, builder: (column) => column);

  GeneratedColumn<int> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get nissayaId =>
      $composableBuilder(column: $table.nissayaId, builder: (column) => column);
}

class $$NissayaSentencesTableTableManager
    extends
        RootTableManager<
          _$NissayaDatabase,
          $NissayaSentencesTable,
          NissayaSentence,
          $$NissayaSentencesTableFilterComposer,
          $$NissayaSentencesTableOrderingComposer,
          $$NissayaSentencesTableAnnotationComposer,
          $$NissayaSentencesTableCreateCompanionBuilder,
          $$NissayaSentencesTableUpdateCompanionBuilder,
          (
            NissayaSentence,
            BaseReferences<
              _$NissayaDatabase,
              $NissayaSentencesTable,
              NissayaSentence
            >,
          ),
          NissayaSentence,
          PrefetchHooks Function()
        > {
  $$NissayaSentencesTableTableManager(
    _$NissayaDatabase db,
    $NissayaSentencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NissayaSentencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NissayaSentencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NissayaSentencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> paraId = const Value.absent(),
                Value<int> lineId = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int> nissayaId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NissayaSentencesCompanion(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                content: content,
                nissayaId: nissayaId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int paraId,
                required int lineId,
                Value<String?> content = const Value.absent(),
                required int nissayaId,
                Value<int> rowid = const Value.absent(),
              }) => NissayaSentencesCompanion.insert(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                content: content,
                nissayaId: nissayaId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NissayaSentencesTableProcessedTableManager =
    ProcessedTableManager<
      _$NissayaDatabase,
      $NissayaSentencesTable,
      NissayaSentence,
      $$NissayaSentencesTableFilterComposer,
      $$NissayaSentencesTableOrderingComposer,
      $$NissayaSentencesTableAnnotationComposer,
      $$NissayaSentencesTableCreateCompanionBuilder,
      $$NissayaSentencesTableUpdateCompanionBuilder,
      (
        NissayaSentence,
        BaseReferences<
          _$NissayaDatabase,
          $NissayaSentencesTable,
          NissayaSentence
        >,
      ),
      NissayaSentence,
      PrefetchHooks Function()
    >;
typedef $$NissayaBooksTableCreateCompanionBuilder =
    NissayaBooksCompanion Function({
      Value<int> bookId,
      Value<String?> bookName,
      Value<String?> info,
    });
typedef $$NissayaBooksTableUpdateCompanionBuilder =
    NissayaBooksCompanion Function({
      Value<int> bookId,
      Value<String?> bookName,
      Value<String?> info,
    });

class $$NissayaBooksTableFilterComposer
    extends Composer<_$NissayaDatabase, $NissayaBooksTable> {
  $$NissayaBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NissayaBooksTableOrderingComposer
    extends Composer<_$NissayaDatabase, $NissayaBooksTable> {
  $$NissayaBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NissayaBooksTableAnnotationComposer
    extends Composer<_$NissayaDatabase, $NissayaBooksTable> {
  $$NissayaBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get info =>
      $composableBuilder(column: $table.info, builder: (column) => column);
}

class $$NissayaBooksTableTableManager
    extends
        RootTableManager<
          _$NissayaDatabase,
          $NissayaBooksTable,
          NissayaBook,
          $$NissayaBooksTableFilterComposer,
          $$NissayaBooksTableOrderingComposer,
          $$NissayaBooksTableAnnotationComposer,
          $$NissayaBooksTableCreateCompanionBuilder,
          $$NissayaBooksTableUpdateCompanionBuilder,
          (
            NissayaBook,
            BaseReferences<_$NissayaDatabase, $NissayaBooksTable, NissayaBook>,
          ),
          NissayaBook,
          PrefetchHooks Function()
        > {
  $$NissayaBooksTableTableManager(
    _$NissayaDatabase db,
    $NissayaBooksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NissayaBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NissayaBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NissayaBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> info = const Value.absent(),
              }) => NissayaBooksCompanion(
                bookId: bookId,
                bookName: bookName,
                info: info,
              ),
          createCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> info = const Value.absent(),
              }) => NissayaBooksCompanion.insert(
                bookId: bookId,
                bookName: bookName,
                info: info,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NissayaBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$NissayaDatabase,
      $NissayaBooksTable,
      NissayaBook,
      $$NissayaBooksTableFilterComposer,
      $$NissayaBooksTableOrderingComposer,
      $$NissayaBooksTableAnnotationComposer,
      $$NissayaBooksTableCreateCompanionBuilder,
      $$NissayaBooksTableUpdateCompanionBuilder,
      (
        NissayaBook,
        BaseReferences<_$NissayaDatabase, $NissayaBooksTable, NissayaBook>,
      ),
      NissayaBook,
      PrefetchHooks Function()
    >;

class $NissayaDatabaseManager {
  final _$NissayaDatabase _db;
  $NissayaDatabaseManager(this._db);
  $$NissayaSentencesTableTableManager get nissayaSentences =>
      $$NissayaSentencesTableTableManager(_db, _db.nissayaSentences);
  $$NissayaBooksTableTableManager get nissayaBooks =>
      $$NissayaBooksTableTableManager(_db, _db.nissayaBooks);
}
