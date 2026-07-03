// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_database.dart';

// ignore_for_file: type=lint
class $TranslationSentencesTable extends TranslationSentences
    with TableInfo<$TranslationSentencesTable, TranslationSentence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationSentencesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _paliSentenceMeta = const VerificationMeta(
    'paliSentence',
  );
  @override
  late final GeneratedColumn<String> paliSentence = GeneratedColumn<String>(
    'pali_sentence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationConfidenceMeta =
      const VerificationMeta('translationConfidence');
  @override
  late final GeneratedColumn<String> translationConfidence =
      GeneratedColumn<String>(
        'translation_confidence',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confidenceNoteMeta = const VerificationMeta(
    'confidenceNote',
  );
  @override
  late final GeneratedColumn<String> confidenceNote = GeneratedColumn<String>(
    'confidence_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    paraId,
    lineId,
    paliSentence,
    translation,
    translationConfidence,
    confidenceNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranslationSentence> instance, {
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
    if (data.containsKey('pali_sentence')) {
      context.handle(
        _paliSentenceMeta,
        paliSentence.isAcceptableOrUnknown(
          data['pali_sentence']!,
          _paliSentenceMeta,
        ),
      );
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    if (data.containsKey('translation_confidence')) {
      context.handle(
        _translationConfidenceMeta,
        translationConfidence.isAcceptableOrUnknown(
          data['translation_confidence']!,
          _translationConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('confidence_note')) {
      context.handle(
        _confidenceNoteMeta,
        confidenceNote.isAcceptableOrUnknown(
          data['confidence_note']!,
          _confidenceNoteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, paraId, lineId};
  @override
  TranslationSentence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationSentence(
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
      paliSentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pali_sentence'],
      ),
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
      translationConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_confidence'],
      ),
      confidenceNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence_note'],
      ),
    );
  }

  @override
  $TranslationSentencesTable createAlias(String alias) {
    return $TranslationSentencesTable(attachedDatabase, alias);
  }
}

class TranslationSentence extends DataClass
    implements Insertable<TranslationSentence> {
  final String bookId;
  final int paraId;
  final int lineId;
  final String? paliSentence;
  final String? translation;
  final String? translationConfidence;
  final String? confidenceNote;
  const TranslationSentence({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.paliSentence,
    this.translation,
    this.translationConfidence,
    this.confidenceNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['para_id'] = Variable<int>(paraId);
    map['line_id'] = Variable<int>(lineId);
    if (!nullToAbsent || paliSentence != null) {
      map['pali_sentence'] = Variable<String>(paliSentence);
    }
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    if (!nullToAbsent || translationConfidence != null) {
      map['translation_confidence'] = Variable<String>(translationConfidence);
    }
    if (!nullToAbsent || confidenceNote != null) {
      map['confidence_note'] = Variable<String>(confidenceNote);
    }
    return map;
  }

  TranslationSentencesCompanion toCompanion(bool nullToAbsent) {
    return TranslationSentencesCompanion(
      bookId: Value(bookId),
      paraId: Value(paraId),
      lineId: Value(lineId),
      paliSentence: paliSentence == null && nullToAbsent
          ? const Value.absent()
          : Value(paliSentence),
      translation: translation == null && nullToAbsent
          ? const Value.absent()
          : Value(translation),
      translationConfidence: translationConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(translationConfidence),
      confidenceNote: confidenceNote == null && nullToAbsent
          ? const Value.absent()
          : Value(confidenceNote),
    );
  }

  factory TranslationSentence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationSentence(
      bookId: serializer.fromJson<String>(json['bookId']),
      paraId: serializer.fromJson<int>(json['paraId']),
      lineId: serializer.fromJson<int>(json['lineId']),
      paliSentence: serializer.fromJson<String?>(json['paliSentence']),
      translation: serializer.fromJson<String?>(json['translation']),
      translationConfidence: serializer.fromJson<String?>(
        json['translationConfidence'],
      ),
      confidenceNote: serializer.fromJson<String?>(json['confidenceNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'paraId': serializer.toJson<int>(paraId),
      'lineId': serializer.toJson<int>(lineId),
      'paliSentence': serializer.toJson<String?>(paliSentence),
      'translation': serializer.toJson<String?>(translation),
      'translationConfidence': serializer.toJson<String?>(
        translationConfidence,
      ),
      'confidenceNote': serializer.toJson<String?>(confidenceNote),
    };
  }

  TranslationSentence copyWith({
    String? bookId,
    int? paraId,
    int? lineId,
    Value<String?> paliSentence = const Value.absent(),
    Value<String?> translation = const Value.absent(),
    Value<String?> translationConfidence = const Value.absent(),
    Value<String?> confidenceNote = const Value.absent(),
  }) => TranslationSentence(
    bookId: bookId ?? this.bookId,
    paraId: paraId ?? this.paraId,
    lineId: lineId ?? this.lineId,
    paliSentence: paliSentence.present ? paliSentence.value : this.paliSentence,
    translation: translation.present ? translation.value : this.translation,
    translationConfidence: translationConfidence.present
        ? translationConfidence.value
        : this.translationConfidence,
    confidenceNote: confidenceNote.present
        ? confidenceNote.value
        : this.confidenceNote,
  );
  TranslationSentence copyWithCompanion(TranslationSentencesCompanion data) {
    return TranslationSentence(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      paliSentence: data.paliSentence.present
          ? data.paliSentence.value
          : this.paliSentence,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      translationConfidence: data.translationConfidence.present
          ? data.translationConfidence.value
          : this.translationConfidence,
      confidenceNote: data.confidenceNote.present
          ? data.confidenceNote.value
          : this.confidenceNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationSentence(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('paliSentence: $paliSentence, ')
          ..write('translation: $translation, ')
          ..write('translationConfidence: $translationConfidence, ')
          ..write('confidenceNote: $confidenceNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    paraId,
    lineId,
    paliSentence,
    translation,
    translationConfidence,
    confidenceNote,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationSentence &&
          other.bookId == this.bookId &&
          other.paraId == this.paraId &&
          other.lineId == this.lineId &&
          other.paliSentence == this.paliSentence &&
          other.translation == this.translation &&
          other.translationConfidence == this.translationConfidence &&
          other.confidenceNote == this.confidenceNote);
}

class TranslationSentencesCompanion
    extends UpdateCompanion<TranslationSentence> {
  final Value<String> bookId;
  final Value<int> paraId;
  final Value<int> lineId;
  final Value<String?> paliSentence;
  final Value<String?> translation;
  final Value<String?> translationConfidence;
  final Value<String?> confidenceNote;
  final Value<int> rowid;
  const TranslationSentencesCompanion({
    this.bookId = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.paliSentence = const Value.absent(),
    this.translation = const Value.absent(),
    this.translationConfidence = const Value.absent(),
    this.confidenceNote = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranslationSentencesCompanion.insert({
    required String bookId,
    required int paraId,
    required int lineId,
    this.paliSentence = const Value.absent(),
    this.translation = const Value.absent(),
    this.translationConfidence = const Value.absent(),
    this.confidenceNote = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       paraId = Value(paraId),
       lineId = Value(lineId);
  static Insertable<TranslationSentence> custom({
    Expression<String>? bookId,
    Expression<int>? paraId,
    Expression<int>? lineId,
    Expression<String>? paliSentence,
    Expression<String>? translation,
    Expression<String>? translationConfidence,
    Expression<String>? confidenceNote,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (paraId != null) 'para_id': paraId,
      if (lineId != null) 'line_id': lineId,
      if (paliSentence != null) 'pali_sentence': paliSentence,
      if (translation != null) 'translation': translation,
      if (translationConfidence != null)
        'translation_confidence': translationConfidence,
      if (confidenceNote != null) 'confidence_note': confidenceNote,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranslationSentencesCompanion copyWith({
    Value<String>? bookId,
    Value<int>? paraId,
    Value<int>? lineId,
    Value<String?>? paliSentence,
    Value<String?>? translation,
    Value<String?>? translationConfidence,
    Value<String?>? confidenceNote,
    Value<int>? rowid,
  }) {
    return TranslationSentencesCompanion(
      bookId: bookId ?? this.bookId,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      paliSentence: paliSentence ?? this.paliSentence,
      translation: translation ?? this.translation,
      translationConfidence:
          translationConfidence ?? this.translationConfidence,
      confidenceNote: confidenceNote ?? this.confidenceNote,
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
    if (paliSentence.present) {
      map['pali_sentence'] = Variable<String>(paliSentence.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (translationConfidence.present) {
      map['translation_confidence'] = Variable<String>(
        translationConfidence.value,
      );
    }
    if (confidenceNote.present) {
      map['confidence_note'] = Variable<String>(confidenceNote.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationSentencesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('paliSentence: $paliSentence, ')
          ..write('translation: $translation, ')
          ..write('translationConfidence: $translationConfidence, ')
          ..write('confidenceNote: $confidenceNote, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TranslationDatabase extends GeneratedDatabase {
  _$TranslationDatabase(QueryExecutor e) : super(e);
  $TranslationDatabaseManager get managers => $TranslationDatabaseManager(this);
  late final $TranslationSentencesTable translationSentences =
      $TranslationSentencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [translationSentences];
}

typedef $$TranslationSentencesTableCreateCompanionBuilder =
    TranslationSentencesCompanion Function({
      required String bookId,
      required int paraId,
      required int lineId,
      Value<String?> paliSentence,
      Value<String?> translation,
      Value<String?> translationConfidence,
      Value<String?> confidenceNote,
      Value<int> rowid,
    });
typedef $$TranslationSentencesTableUpdateCompanionBuilder =
    TranslationSentencesCompanion Function({
      Value<String> bookId,
      Value<int> paraId,
      Value<int> lineId,
      Value<String?> paliSentence,
      Value<String?> translation,
      Value<String?> translationConfidence,
      Value<String?> confidenceNote,
      Value<int> rowid,
    });

class $$TranslationSentencesTableFilterComposer
    extends Composer<_$TranslationDatabase, $TranslationSentencesTable> {
  $$TranslationSentencesTableFilterComposer({
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

  ColumnFilters<String> get paliSentence => $composableBuilder(
    column: $table.paliSentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationConfidence => $composableBuilder(
    column: $table.translationConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidenceNote => $composableBuilder(
    column: $table.confidenceNote,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranslationSentencesTableOrderingComposer
    extends Composer<_$TranslationDatabase, $TranslationSentencesTable> {
  $$TranslationSentencesTableOrderingComposer({
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

  ColumnOrderings<String> get paliSentence => $composableBuilder(
    column: $table.paliSentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationConfidence => $composableBuilder(
    column: $table.translationConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidenceNote => $composableBuilder(
    column: $table.confidenceNote,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranslationSentencesTableAnnotationComposer
    extends Composer<_$TranslationDatabase, $TranslationSentencesTable> {
  $$TranslationSentencesTableAnnotationComposer({
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

  GeneratedColumn<String> get paliSentence => $composableBuilder(
    column: $table.paliSentence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translationConfidence => $composableBuilder(
    column: $table.translationConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidenceNote => $composableBuilder(
    column: $table.confidenceNote,
    builder: (column) => column,
  );
}

class $$TranslationSentencesTableTableManager
    extends
        RootTableManager<
          _$TranslationDatabase,
          $TranslationSentencesTable,
          TranslationSentence,
          $$TranslationSentencesTableFilterComposer,
          $$TranslationSentencesTableOrderingComposer,
          $$TranslationSentencesTableAnnotationComposer,
          $$TranslationSentencesTableCreateCompanionBuilder,
          $$TranslationSentencesTableUpdateCompanionBuilder,
          (
            TranslationSentence,
            BaseReferences<
              _$TranslationDatabase,
              $TranslationSentencesTable,
              TranslationSentence
            >,
          ),
          TranslationSentence,
          PrefetchHooks Function()
        > {
  $$TranslationSentencesTableTableManager(
    _$TranslationDatabase db,
    $TranslationSentencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationSentencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationSentencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TranslationSentencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> paraId = const Value.absent(),
                Value<int> lineId = const Value.absent(),
                Value<String?> paliSentence = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> translationConfidence = const Value.absent(),
                Value<String?> confidenceNote = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationSentencesCompanion(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                paliSentence: paliSentence,
                translation: translation,
                translationConfidence: translationConfidence,
                confidenceNote: confidenceNote,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int paraId,
                required int lineId,
                Value<String?> paliSentence = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> translationConfidence = const Value.absent(),
                Value<String?> confidenceNote = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationSentencesCompanion.insert(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                paliSentence: paliSentence,
                translation: translation,
                translationConfidence: translationConfidence,
                confidenceNote: confidenceNote,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranslationSentencesTableProcessedTableManager =
    ProcessedTableManager<
      _$TranslationDatabase,
      $TranslationSentencesTable,
      TranslationSentence,
      $$TranslationSentencesTableFilterComposer,
      $$TranslationSentencesTableOrderingComposer,
      $$TranslationSentencesTableAnnotationComposer,
      $$TranslationSentencesTableCreateCompanionBuilder,
      $$TranslationSentencesTableUpdateCompanionBuilder,
      (
        TranslationSentence,
        BaseReferences<
          _$TranslationDatabase,
          $TranslationSentencesTable,
          TranslationSentence
        >,
      ),
      TranslationSentence,
      PrefetchHooks Function()
    >;

class $TranslationDatabaseManager {
  final _$TranslationDatabase _db;
  $TranslationDatabaseManager(this._db);
  $$TranslationSentencesTableTableManager get translationSentences =>
      $$TranslationSentencesTableTableManager(_db, _db.translationSentences);
}
