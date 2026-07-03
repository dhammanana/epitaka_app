// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epitaka_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<int> refId = GeneratedColumn<int>(
    'ref_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vriIdMeta = const VerificationMeta('vriId');
  @override
  late final GeneratedColumn<String> vriId = GeneratedColumn<String>(
    'vri_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nikayaMeta = const VerificationMeta('nikaya');
  @override
  late final GeneratedColumn<String> nikaya = GeneratedColumn<String>(
    'nikaya',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subNikayaMeta = const VerificationMeta(
    'subNikaya',
  );
  @override
  late final GeneratedColumn<String> subNikaya = GeneratedColumn<String>(
    'sub_nikaya',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mulaRefMeta = const VerificationMeta(
    'mulaRef',
  );
  @override
  late final GeneratedColumn<String> mulaRef = GeneratedColumn<String>(
    'mula_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atthaRefMeta = const VerificationMeta(
    'atthaRef',
  );
  @override
  late final GeneratedColumn<String> atthaRef = GeneratedColumn<String>(
    'attha_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tikaRefMeta = const VerificationMeta(
    'tikaRef',
  );
  @override
  late final GeneratedColumn<String> tikaRef = GeneratedColumn<String>(
    'tika_ref',
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
  static const VerificationMeta _chapterLenMeta = const VerificationMeta(
    'chapterLen',
  );
  @override
  late final GeneratedColumn<int> chapterLen = GeneratedColumn<int>(
    'chapter_len',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    refId,
    vriId,
    bookId,
    category,
    nikaya,
    subNikaya,
    bookName,
    description,
    mulaRef,
    atthaRef,
    tikaRef,
    paraId,
    chapterLen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    }
    if (data.containsKey('vri_id')) {
      context.handle(
        _vriIdMeta,
        vriId.isAcceptableOrUnknown(data['vri_id']!, _vriIdMeta),
      );
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('nikaya')) {
      context.handle(
        _nikayaMeta,
        nikaya.isAcceptableOrUnknown(data['nikaya']!, _nikayaMeta),
      );
    }
    if (data.containsKey('sub_nikaya')) {
      context.handle(
        _subNikayaMeta,
        subNikaya.isAcceptableOrUnknown(data['sub_nikaya']!, _subNikayaMeta),
      );
    }
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('mula_ref')) {
      context.handle(
        _mulaRefMeta,
        mulaRef.isAcceptableOrUnknown(data['mula_ref']!, _mulaRefMeta),
      );
    }
    if (data.containsKey('attha_ref')) {
      context.handle(
        _atthaRefMeta,
        atthaRef.isAcceptableOrUnknown(data['attha_ref']!, _atthaRefMeta),
      );
    }
    if (data.containsKey('tika_ref')) {
      context.handle(
        _tikaRefMeta,
        tikaRef.isAcceptableOrUnknown(data['tika_ref']!, _tikaRefMeta),
      );
    }
    if (data.containsKey('para_id')) {
      context.handle(
        _paraIdMeta,
        paraId.isAcceptableOrUnknown(data['para_id']!, _paraIdMeta),
      );
    }
    if (data.containsKey('chapter_len')) {
      context.handle(
        _chapterLenMeta,
        chapterLen.isAcceptableOrUnknown(data['chapter_len']!, _chapterLenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ref_id'],
      ),
      vriId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vri_id'],
      ),
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      nikaya: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nikaya'],
      ),
      subNikaya: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_nikaya'],
      ),
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      mulaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mula_ref'],
      ),
      atthaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attha_ref'],
      ),
      tikaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tika_ref'],
      ),
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      ),
      chapterLen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_len'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final int? refId;
  final String? vriId;
  final String bookId;
  final String? category;
  final String? nikaya;
  final String? subNikaya;
  final String? bookName;
  final String? description;
  final String? mulaRef;
  final String? atthaRef;
  final String? tikaRef;
  final int? paraId;
  final int? chapterLen;
  const Book({
    required this.id,
    this.refId,
    this.vriId,
    required this.bookId,
    this.category,
    this.nikaya,
    this.subNikaya,
    this.bookName,
    this.description,
    this.mulaRef,
    this.atthaRef,
    this.tikaRef,
    this.paraId,
    this.chapterLen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || refId != null) {
      map['ref_id'] = Variable<int>(refId);
    }
    if (!nullToAbsent || vriId != null) {
      map['vri_id'] = Variable<String>(vriId);
    }
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || nikaya != null) {
      map['nikaya'] = Variable<String>(nikaya);
    }
    if (!nullToAbsent || subNikaya != null) {
      map['sub_nikaya'] = Variable<String>(subNikaya);
    }
    if (!nullToAbsent || bookName != null) {
      map['book_name'] = Variable<String>(bookName);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || mulaRef != null) {
      map['mula_ref'] = Variable<String>(mulaRef);
    }
    if (!nullToAbsent || atthaRef != null) {
      map['attha_ref'] = Variable<String>(atthaRef);
    }
    if (!nullToAbsent || tikaRef != null) {
      map['tika_ref'] = Variable<String>(tikaRef);
    }
    if (!nullToAbsent || paraId != null) {
      map['para_id'] = Variable<int>(paraId);
    }
    if (!nullToAbsent || chapterLen != null) {
      map['chapter_len'] = Variable<int>(chapterLen);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      refId: refId == null && nullToAbsent
          ? const Value.absent()
          : Value(refId),
      vriId: vriId == null && nullToAbsent
          ? const Value.absent()
          : Value(vriId),
      bookId: Value(bookId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      nikaya: nikaya == null && nullToAbsent
          ? const Value.absent()
          : Value(nikaya),
      subNikaya: subNikaya == null && nullToAbsent
          ? const Value.absent()
          : Value(subNikaya),
      bookName: bookName == null && nullToAbsent
          ? const Value.absent()
          : Value(bookName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      mulaRef: mulaRef == null && nullToAbsent
          ? const Value.absent()
          : Value(mulaRef),
      atthaRef: atthaRef == null && nullToAbsent
          ? const Value.absent()
          : Value(atthaRef),
      tikaRef: tikaRef == null && nullToAbsent
          ? const Value.absent()
          : Value(tikaRef),
      paraId: paraId == null && nullToAbsent
          ? const Value.absent()
          : Value(paraId),
      chapterLen: chapterLen == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterLen),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      refId: serializer.fromJson<int?>(json['refId']),
      vriId: serializer.fromJson<String?>(json['vriId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      category: serializer.fromJson<String?>(json['category']),
      nikaya: serializer.fromJson<String?>(json['nikaya']),
      subNikaya: serializer.fromJson<String?>(json['subNikaya']),
      bookName: serializer.fromJson<String?>(json['bookName']),
      description: serializer.fromJson<String?>(json['description']),
      mulaRef: serializer.fromJson<String?>(json['mulaRef']),
      atthaRef: serializer.fromJson<String?>(json['atthaRef']),
      tikaRef: serializer.fromJson<String?>(json['tikaRef']),
      paraId: serializer.fromJson<int?>(json['paraId']),
      chapterLen: serializer.fromJson<int?>(json['chapterLen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'refId': serializer.toJson<int?>(refId),
      'vriId': serializer.toJson<String?>(vriId),
      'bookId': serializer.toJson<String>(bookId),
      'category': serializer.toJson<String?>(category),
      'nikaya': serializer.toJson<String?>(nikaya),
      'subNikaya': serializer.toJson<String?>(subNikaya),
      'bookName': serializer.toJson<String?>(bookName),
      'description': serializer.toJson<String?>(description),
      'mulaRef': serializer.toJson<String?>(mulaRef),
      'atthaRef': serializer.toJson<String?>(atthaRef),
      'tikaRef': serializer.toJson<String?>(tikaRef),
      'paraId': serializer.toJson<int?>(paraId),
      'chapterLen': serializer.toJson<int?>(chapterLen),
    };
  }

  Book copyWith({
    int? id,
    Value<int?> refId = const Value.absent(),
    Value<String?> vriId = const Value.absent(),
    String? bookId,
    Value<String?> category = const Value.absent(),
    Value<String?> nikaya = const Value.absent(),
    Value<String?> subNikaya = const Value.absent(),
    Value<String?> bookName = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> mulaRef = const Value.absent(),
    Value<String?> atthaRef = const Value.absent(),
    Value<String?> tikaRef = const Value.absent(),
    Value<int?> paraId = const Value.absent(),
    Value<int?> chapterLen = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    refId: refId.present ? refId.value : this.refId,
    vriId: vriId.present ? vriId.value : this.vriId,
    bookId: bookId ?? this.bookId,
    category: category.present ? category.value : this.category,
    nikaya: nikaya.present ? nikaya.value : this.nikaya,
    subNikaya: subNikaya.present ? subNikaya.value : this.subNikaya,
    bookName: bookName.present ? bookName.value : this.bookName,
    description: description.present ? description.value : this.description,
    mulaRef: mulaRef.present ? mulaRef.value : this.mulaRef,
    atthaRef: atthaRef.present ? atthaRef.value : this.atthaRef,
    tikaRef: tikaRef.present ? tikaRef.value : this.tikaRef,
    paraId: paraId.present ? paraId.value : this.paraId,
    chapterLen: chapterLen.present ? chapterLen.value : this.chapterLen,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      refId: data.refId.present ? data.refId.value : this.refId,
      vriId: data.vriId.present ? data.vriId.value : this.vriId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      category: data.category.present ? data.category.value : this.category,
      nikaya: data.nikaya.present ? data.nikaya.value : this.nikaya,
      subNikaya: data.subNikaya.present ? data.subNikaya.value : this.subNikaya,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      description: data.description.present
          ? data.description.value
          : this.description,
      mulaRef: data.mulaRef.present ? data.mulaRef.value : this.mulaRef,
      atthaRef: data.atthaRef.present ? data.atthaRef.value : this.atthaRef,
      tikaRef: data.tikaRef.present ? data.tikaRef.value : this.tikaRef,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      chapterLen: data.chapterLen.present
          ? data.chapterLen.value
          : this.chapterLen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('refId: $refId, ')
          ..write('vriId: $vriId, ')
          ..write('bookId: $bookId, ')
          ..write('category: $category, ')
          ..write('nikaya: $nikaya, ')
          ..write('subNikaya: $subNikaya, ')
          ..write('bookName: $bookName, ')
          ..write('description: $description, ')
          ..write('mulaRef: $mulaRef, ')
          ..write('atthaRef: $atthaRef, ')
          ..write('tikaRef: $tikaRef, ')
          ..write('paraId: $paraId, ')
          ..write('chapterLen: $chapterLen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    refId,
    vriId,
    bookId,
    category,
    nikaya,
    subNikaya,
    bookName,
    description,
    mulaRef,
    atthaRef,
    tikaRef,
    paraId,
    chapterLen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.refId == this.refId &&
          other.vriId == this.vriId &&
          other.bookId == this.bookId &&
          other.category == this.category &&
          other.nikaya == this.nikaya &&
          other.subNikaya == this.subNikaya &&
          other.bookName == this.bookName &&
          other.description == this.description &&
          other.mulaRef == this.mulaRef &&
          other.atthaRef == this.atthaRef &&
          other.tikaRef == this.tikaRef &&
          other.paraId == this.paraId &&
          other.chapterLen == this.chapterLen);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<int?> refId;
  final Value<String?> vriId;
  final Value<String> bookId;
  final Value<String?> category;
  final Value<String?> nikaya;
  final Value<String?> subNikaya;
  final Value<String?> bookName;
  final Value<String?> description;
  final Value<String?> mulaRef;
  final Value<String?> atthaRef;
  final Value<String?> tikaRef;
  final Value<int?> paraId;
  final Value<int?> chapterLen;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.refId = const Value.absent(),
    this.vriId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.category = const Value.absent(),
    this.nikaya = const Value.absent(),
    this.subNikaya = const Value.absent(),
    this.bookName = const Value.absent(),
    this.description = const Value.absent(),
    this.mulaRef = const Value.absent(),
    this.atthaRef = const Value.absent(),
    this.tikaRef = const Value.absent(),
    this.paraId = const Value.absent(),
    this.chapterLen = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    this.refId = const Value.absent(),
    this.vriId = const Value.absent(),
    required String bookId,
    this.category = const Value.absent(),
    this.nikaya = const Value.absent(),
    this.subNikaya = const Value.absent(),
    this.bookName = const Value.absent(),
    this.description = const Value.absent(),
    this.mulaRef = const Value.absent(),
    this.atthaRef = const Value.absent(),
    this.tikaRef = const Value.absent(),
    this.paraId = const Value.absent(),
    this.chapterLen = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<int>? refId,
    Expression<String>? vriId,
    Expression<String>? bookId,
    Expression<String>? category,
    Expression<String>? nikaya,
    Expression<String>? subNikaya,
    Expression<String>? bookName,
    Expression<String>? description,
    Expression<String>? mulaRef,
    Expression<String>? atthaRef,
    Expression<String>? tikaRef,
    Expression<int>? paraId,
    Expression<int>? chapterLen,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (refId != null) 'ref_id': refId,
      if (vriId != null) 'vri_id': vriId,
      if (bookId != null) 'book_id': bookId,
      if (category != null) 'category': category,
      if (nikaya != null) 'nikaya': nikaya,
      if (subNikaya != null) 'sub_nikaya': subNikaya,
      if (bookName != null) 'book_name': bookName,
      if (description != null) 'description': description,
      if (mulaRef != null) 'mula_ref': mulaRef,
      if (atthaRef != null) 'attha_ref': atthaRef,
      if (tikaRef != null) 'tika_ref': tikaRef,
      if (paraId != null) 'para_id': paraId,
      if (chapterLen != null) 'chapter_len': chapterLen,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<int?>? refId,
    Value<String?>? vriId,
    Value<String>? bookId,
    Value<String?>? category,
    Value<String?>? nikaya,
    Value<String?>? subNikaya,
    Value<String?>? bookName,
    Value<String?>? description,
    Value<String?>? mulaRef,
    Value<String?>? atthaRef,
    Value<String?>? tikaRef,
    Value<int?>? paraId,
    Value<int?>? chapterLen,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      refId: refId ?? this.refId,
      vriId: vriId ?? this.vriId,
      bookId: bookId ?? this.bookId,
      category: category ?? this.category,
      nikaya: nikaya ?? this.nikaya,
      subNikaya: subNikaya ?? this.subNikaya,
      bookName: bookName ?? this.bookName,
      description: description ?? this.description,
      mulaRef: mulaRef ?? this.mulaRef,
      atthaRef: atthaRef ?? this.atthaRef,
      tikaRef: tikaRef ?? this.tikaRef,
      paraId: paraId ?? this.paraId,
      chapterLen: chapterLen ?? this.chapterLen,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<int>(refId.value);
    }
    if (vriId.present) {
      map['vri_id'] = Variable<String>(vriId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (nikaya.present) {
      map['nikaya'] = Variable<String>(nikaya.value);
    }
    if (subNikaya.present) {
      map['sub_nikaya'] = Variable<String>(subNikaya.value);
    }
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (mulaRef.present) {
      map['mula_ref'] = Variable<String>(mulaRef.value);
    }
    if (atthaRef.present) {
      map['attha_ref'] = Variable<String>(atthaRef.value);
    }
    if (tikaRef.present) {
      map['tika_ref'] = Variable<String>(tikaRef.value);
    }
    if (paraId.present) {
      map['para_id'] = Variable<int>(paraId.value);
    }
    if (chapterLen.present) {
      map['chapter_len'] = Variable<int>(chapterLen.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('refId: $refId, ')
          ..write('vriId: $vriId, ')
          ..write('bookId: $bookId, ')
          ..write('category: $category, ')
          ..write('nikaya: $nikaya, ')
          ..write('subNikaya: $subNikaya, ')
          ..write('bookName: $bookName, ')
          ..write('description: $description, ')
          ..write('mulaRef: $mulaRef, ')
          ..write('atthaRef: $atthaRef, ')
          ..write('tikaRef: $tikaRef, ')
          ..write('paraId: $paraId, ')
          ..write('chapterLen: $chapterLen')
          ..write(')'))
        .toString();
  }
}

class $HeadingsTable extends Headings with TableInfo<$HeadingsTable, Heading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeadingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _chapterLenMeta = const VerificationMeta(
    'chapterLen',
  );
  @override
  late final GeneratedColumn<int> chapterLen = GeneratedColumn<int>(
    'chapter_len',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentMeta = const VerificationMeta('parent');
  @override
  late final GeneratedColumn<int> parent = GeneratedColumn<int>(
    'parent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scIdMeta = const VerificationMeta('scId');
  @override
  late final GeneratedColumn<String> scId = GeneratedColumn<String>(
    'sc_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    paraId,
    level,
    title,
    chapterLen,
    parent,
    scId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'headings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Heading> instance, {
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
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('chapter_len')) {
      context.handle(
        _chapterLenMeta,
        chapterLen.isAcceptableOrUnknown(data['chapter_len']!, _chapterLenMeta),
      );
    }
    if (data.containsKey('parent')) {
      context.handle(
        _parentMeta,
        parent.isAcceptableOrUnknown(data['parent']!, _parentMeta),
      );
    }
    if (data.containsKey('sc_id')) {
      context.handle(
        _scIdMeta,
        scId.isAcceptableOrUnknown(data['sc_id']!, _scIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, paraId};
  @override
  Heading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Heading(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      chapterLen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_len'],
      ),
      parent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent'],
      ),
      scId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_id'],
      ),
    );
  }

  @override
  $HeadingsTable createAlias(String alias) {
    return $HeadingsTable(attachedDatabase, alias);
  }
}

class Heading extends DataClass implements Insertable<Heading> {
  final String bookId;
  final int paraId;
  final int? level;
  final String? title;
  final int? chapterLen;
  final int? parent;
  final String? scId;
  const Heading({
    required this.bookId,
    required this.paraId,
    this.level,
    this.title,
    this.chapterLen,
    this.parent,
    this.scId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['para_id'] = Variable<int>(paraId);
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<int>(level);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || chapterLen != null) {
      map['chapter_len'] = Variable<int>(chapterLen);
    }
    if (!nullToAbsent || parent != null) {
      map['parent'] = Variable<int>(parent);
    }
    if (!nullToAbsent || scId != null) {
      map['sc_id'] = Variable<String>(scId);
    }
    return map;
  }

  HeadingsCompanion toCompanion(bool nullToAbsent) {
    return HeadingsCompanion(
      bookId: Value(bookId),
      paraId: Value(paraId),
      level: level == null && nullToAbsent
          ? const Value.absent()
          : Value(level),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      chapterLen: chapterLen == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterLen),
      parent: parent == null && nullToAbsent
          ? const Value.absent()
          : Value(parent),
      scId: scId == null && nullToAbsent ? const Value.absent() : Value(scId),
    );
  }

  factory Heading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Heading(
      bookId: serializer.fromJson<String>(json['bookId']),
      paraId: serializer.fromJson<int>(json['paraId']),
      level: serializer.fromJson<int?>(json['level']),
      title: serializer.fromJson<String?>(json['title']),
      chapterLen: serializer.fromJson<int?>(json['chapterLen']),
      parent: serializer.fromJson<int?>(json['parent']),
      scId: serializer.fromJson<String?>(json['scId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'paraId': serializer.toJson<int>(paraId),
      'level': serializer.toJson<int?>(level),
      'title': serializer.toJson<String?>(title),
      'chapterLen': serializer.toJson<int?>(chapterLen),
      'parent': serializer.toJson<int?>(parent),
      'scId': serializer.toJson<String?>(scId),
    };
  }

  Heading copyWith({
    String? bookId,
    int? paraId,
    Value<int?> level = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<int?> chapterLen = const Value.absent(),
    Value<int?> parent = const Value.absent(),
    Value<String?> scId = const Value.absent(),
  }) => Heading(
    bookId: bookId ?? this.bookId,
    paraId: paraId ?? this.paraId,
    level: level.present ? level.value : this.level,
    title: title.present ? title.value : this.title,
    chapterLen: chapterLen.present ? chapterLen.value : this.chapterLen,
    parent: parent.present ? parent.value : this.parent,
    scId: scId.present ? scId.value : this.scId,
  );
  Heading copyWithCompanion(HeadingsCompanion data) {
    return Heading(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      level: data.level.present ? data.level.value : this.level,
      title: data.title.present ? data.title.value : this.title,
      chapterLen: data.chapterLen.present
          ? data.chapterLen.value
          : this.chapterLen,
      parent: data.parent.present ? data.parent.value : this.parent,
      scId: data.scId.present ? data.scId.value : this.scId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Heading(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('chapterLen: $chapterLen, ')
          ..write('parent: $parent, ')
          ..write('scId: $scId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, paraId, level, title, chapterLen, parent, scId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Heading &&
          other.bookId == this.bookId &&
          other.paraId == this.paraId &&
          other.level == this.level &&
          other.title == this.title &&
          other.chapterLen == this.chapterLen &&
          other.parent == this.parent &&
          other.scId == this.scId);
}

class HeadingsCompanion extends UpdateCompanion<Heading> {
  final Value<String> bookId;
  final Value<int> paraId;
  final Value<int?> level;
  final Value<String?> title;
  final Value<int?> chapterLen;
  final Value<int?> parent;
  final Value<String?> scId;
  final Value<int> rowid;
  const HeadingsCompanion({
    this.bookId = const Value.absent(),
    this.paraId = const Value.absent(),
    this.level = const Value.absent(),
    this.title = const Value.absent(),
    this.chapterLen = const Value.absent(),
    this.parent = const Value.absent(),
    this.scId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeadingsCompanion.insert({
    required String bookId,
    required int paraId,
    this.level = const Value.absent(),
    this.title = const Value.absent(),
    this.chapterLen = const Value.absent(),
    this.parent = const Value.absent(),
    this.scId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       paraId = Value(paraId);
  static Insertable<Heading> custom({
    Expression<String>? bookId,
    Expression<int>? paraId,
    Expression<int>? level,
    Expression<String>? title,
    Expression<int>? chapterLen,
    Expression<int>? parent,
    Expression<String>? scId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (paraId != null) 'para_id': paraId,
      if (level != null) 'level': level,
      if (title != null) 'title': title,
      if (chapterLen != null) 'chapter_len': chapterLen,
      if (parent != null) 'parent': parent,
      if (scId != null) 'sc_id': scId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeadingsCompanion copyWith({
    Value<String>? bookId,
    Value<int>? paraId,
    Value<int?>? level,
    Value<String?>? title,
    Value<int?>? chapterLen,
    Value<int?>? parent,
    Value<String?>? scId,
    Value<int>? rowid,
  }) {
    return HeadingsCompanion(
      bookId: bookId ?? this.bookId,
      paraId: paraId ?? this.paraId,
      level: level ?? this.level,
      title: title ?? this.title,
      chapterLen: chapterLen ?? this.chapterLen,
      parent: parent ?? this.parent,
      scId: scId ?? this.scId,
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
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (chapterLen.present) {
      map['chapter_len'] = Variable<int>(chapterLen.value);
    }
    if (parent.present) {
      map['parent'] = Variable<int>(parent.value);
    }
    if (scId.present) {
      map['sc_id'] = Variable<String>(scId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeadingsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('chapterLen: $chapterLen, ')
          ..write('parent: $parent, ')
          ..write('scId: $scId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SentencesTable extends Sentences
    with TableInfo<$SentencesTable, Sentence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentencesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _vriparaMeta = const VerificationMeta(
    'vripara',
  );
  @override
  late final GeneratedColumn<String> vripara = GeneratedColumn<String>(
    'vripara',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thaipageMeta = const VerificationMeta(
    'thaipage',
  );
  @override
  late final GeneratedColumn<String> thaipage = GeneratedColumn<String>(
    'thaipage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vripageMeta = const VerificationMeta(
    'vripage',
  );
  @override
  late final GeneratedColumn<String> vripage = GeneratedColumn<String>(
    'vripage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ptspageMeta = const VerificationMeta(
    'ptspage',
  );
  @override
  late final GeneratedColumn<String> ptspage = GeneratedColumn<String>(
    'ptspage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mypageMeta = const VerificationMeta('mypage');
  @override
  late final GeneratedColumn<String> mypage = GeneratedColumn<String>(
    'mypage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paliMeta = const VerificationMeta('pali');
  @override
  late final GeneratedColumn<String> pali = GeneratedColumn<String>(
    'pali',
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
    vripara,
    thaipage,
    vripage,
    ptspage,
    mypage,
    pali,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sentence> instance, {
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
    if (data.containsKey('vripara')) {
      context.handle(
        _vriparaMeta,
        vripara.isAcceptableOrUnknown(data['vripara']!, _vriparaMeta),
      );
    }
    if (data.containsKey('thaipage')) {
      context.handle(
        _thaipageMeta,
        thaipage.isAcceptableOrUnknown(data['thaipage']!, _thaipageMeta),
      );
    }
    if (data.containsKey('vripage')) {
      context.handle(
        _vripageMeta,
        vripage.isAcceptableOrUnknown(data['vripage']!, _vripageMeta),
      );
    }
    if (data.containsKey('ptspage')) {
      context.handle(
        _ptspageMeta,
        ptspage.isAcceptableOrUnknown(data['ptspage']!, _ptspageMeta),
      );
    }
    if (data.containsKey('mypage')) {
      context.handle(
        _mypageMeta,
        mypage.isAcceptableOrUnknown(data['mypage']!, _mypageMeta),
      );
    }
    if (data.containsKey('pali')) {
      context.handle(
        _paliMeta,
        pali.isAcceptableOrUnknown(data['pali']!, _paliMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, paraId, lineId};
  @override
  Sentence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sentence(
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
      vripara: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vripara'],
      ),
      thaipage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thaipage'],
      ),
      vripage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vripage'],
      ),
      ptspage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ptspage'],
      ),
      mypage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mypage'],
      ),
      pali: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pali'],
      ),
    );
  }

  @override
  $SentencesTable createAlias(String alias) {
    return $SentencesTable(attachedDatabase, alias);
  }
}

class Sentence extends DataClass implements Insertable<Sentence> {
  final String bookId;
  final int paraId;
  final int lineId;
  final String? vripara;
  final String? thaipage;
  final String? vripage;
  final String? ptspage;
  final String? mypage;
  final String? pali;
  const Sentence({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.vripara,
    this.thaipage,
    this.vripage,
    this.ptspage,
    this.mypage,
    this.pali,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['para_id'] = Variable<int>(paraId);
    map['line_id'] = Variable<int>(lineId);
    if (!nullToAbsent || vripara != null) {
      map['vripara'] = Variable<String>(vripara);
    }
    if (!nullToAbsent || thaipage != null) {
      map['thaipage'] = Variable<String>(thaipage);
    }
    if (!nullToAbsent || vripage != null) {
      map['vripage'] = Variable<String>(vripage);
    }
    if (!nullToAbsent || ptspage != null) {
      map['ptspage'] = Variable<String>(ptspage);
    }
    if (!nullToAbsent || mypage != null) {
      map['mypage'] = Variable<String>(mypage);
    }
    if (!nullToAbsent || pali != null) {
      map['pali'] = Variable<String>(pali);
    }
    return map;
  }

  SentencesCompanion toCompanion(bool nullToAbsent) {
    return SentencesCompanion(
      bookId: Value(bookId),
      paraId: Value(paraId),
      lineId: Value(lineId),
      vripara: vripara == null && nullToAbsent
          ? const Value.absent()
          : Value(vripara),
      thaipage: thaipage == null && nullToAbsent
          ? const Value.absent()
          : Value(thaipage),
      vripage: vripage == null && nullToAbsent
          ? const Value.absent()
          : Value(vripage),
      ptspage: ptspage == null && nullToAbsent
          ? const Value.absent()
          : Value(ptspage),
      mypage: mypage == null && nullToAbsent
          ? const Value.absent()
          : Value(mypage),
      pali: pali == null && nullToAbsent ? const Value.absent() : Value(pali),
    );
  }

  factory Sentence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sentence(
      bookId: serializer.fromJson<String>(json['bookId']),
      paraId: serializer.fromJson<int>(json['paraId']),
      lineId: serializer.fromJson<int>(json['lineId']),
      vripara: serializer.fromJson<String?>(json['vripara']),
      thaipage: serializer.fromJson<String?>(json['thaipage']),
      vripage: serializer.fromJson<String?>(json['vripage']),
      ptspage: serializer.fromJson<String?>(json['ptspage']),
      mypage: serializer.fromJson<String?>(json['mypage']),
      pali: serializer.fromJson<String?>(json['pali']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'paraId': serializer.toJson<int>(paraId),
      'lineId': serializer.toJson<int>(lineId),
      'vripara': serializer.toJson<String?>(vripara),
      'thaipage': serializer.toJson<String?>(thaipage),
      'vripage': serializer.toJson<String?>(vripage),
      'ptspage': serializer.toJson<String?>(ptspage),
      'mypage': serializer.toJson<String?>(mypage),
      'pali': serializer.toJson<String?>(pali),
    };
  }

  Sentence copyWith({
    String? bookId,
    int? paraId,
    int? lineId,
    Value<String?> vripara = const Value.absent(),
    Value<String?> thaipage = const Value.absent(),
    Value<String?> vripage = const Value.absent(),
    Value<String?> ptspage = const Value.absent(),
    Value<String?> mypage = const Value.absent(),
    Value<String?> pali = const Value.absent(),
  }) => Sentence(
    bookId: bookId ?? this.bookId,
    paraId: paraId ?? this.paraId,
    lineId: lineId ?? this.lineId,
    vripara: vripara.present ? vripara.value : this.vripara,
    thaipage: thaipage.present ? thaipage.value : this.thaipage,
    vripage: vripage.present ? vripage.value : this.vripage,
    ptspage: ptspage.present ? ptspage.value : this.ptspage,
    mypage: mypage.present ? mypage.value : this.mypage,
    pali: pali.present ? pali.value : this.pali,
  );
  Sentence copyWithCompanion(SentencesCompanion data) {
    return Sentence(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      vripara: data.vripara.present ? data.vripara.value : this.vripara,
      thaipage: data.thaipage.present ? data.thaipage.value : this.thaipage,
      vripage: data.vripage.present ? data.vripage.value : this.vripage,
      ptspage: data.ptspage.present ? data.ptspage.value : this.ptspage,
      mypage: data.mypage.present ? data.mypage.value : this.mypage,
      pali: data.pali.present ? data.pali.value : this.pali,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sentence(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('vripara: $vripara, ')
          ..write('thaipage: $thaipage, ')
          ..write('vripage: $vripage, ')
          ..write('ptspage: $ptspage, ')
          ..write('mypage: $mypage, ')
          ..write('pali: $pali')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    paraId,
    lineId,
    vripara,
    thaipage,
    vripage,
    ptspage,
    mypage,
    pali,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sentence &&
          other.bookId == this.bookId &&
          other.paraId == this.paraId &&
          other.lineId == this.lineId &&
          other.vripara == this.vripara &&
          other.thaipage == this.thaipage &&
          other.vripage == this.vripage &&
          other.ptspage == this.ptspage &&
          other.mypage == this.mypage &&
          other.pali == this.pali);
}

class SentencesCompanion extends UpdateCompanion<Sentence> {
  final Value<String> bookId;
  final Value<int> paraId;
  final Value<int> lineId;
  final Value<String?> vripara;
  final Value<String?> thaipage;
  final Value<String?> vripage;
  final Value<String?> ptspage;
  final Value<String?> mypage;
  final Value<String?> pali;
  final Value<int> rowid;
  const SentencesCompanion({
    this.bookId = const Value.absent(),
    this.paraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.vripara = const Value.absent(),
    this.thaipage = const Value.absent(),
    this.vripage = const Value.absent(),
    this.ptspage = const Value.absent(),
    this.mypage = const Value.absent(),
    this.pali = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SentencesCompanion.insert({
    required String bookId,
    required int paraId,
    required int lineId,
    this.vripara = const Value.absent(),
    this.thaipage = const Value.absent(),
    this.vripage = const Value.absent(),
    this.ptspage = const Value.absent(),
    this.mypage = const Value.absent(),
    this.pali = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       paraId = Value(paraId),
       lineId = Value(lineId);
  static Insertable<Sentence> custom({
    Expression<String>? bookId,
    Expression<int>? paraId,
    Expression<int>? lineId,
    Expression<String>? vripara,
    Expression<String>? thaipage,
    Expression<String>? vripage,
    Expression<String>? ptspage,
    Expression<String>? mypage,
    Expression<String>? pali,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (paraId != null) 'para_id': paraId,
      if (lineId != null) 'line_id': lineId,
      if (vripara != null) 'vripara': vripara,
      if (thaipage != null) 'thaipage': thaipage,
      if (vripage != null) 'vripage': vripage,
      if (ptspage != null) 'ptspage': ptspage,
      if (mypage != null) 'mypage': mypage,
      if (pali != null) 'pali': pali,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SentencesCompanion copyWith({
    Value<String>? bookId,
    Value<int>? paraId,
    Value<int>? lineId,
    Value<String?>? vripara,
    Value<String?>? thaipage,
    Value<String?>? vripage,
    Value<String?>? ptspage,
    Value<String?>? mypage,
    Value<String?>? pali,
    Value<int>? rowid,
  }) {
    return SentencesCompanion(
      bookId: bookId ?? this.bookId,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      vripara: vripara ?? this.vripara,
      thaipage: thaipage ?? this.thaipage,
      vripage: vripage ?? this.vripage,
      ptspage: ptspage ?? this.ptspage,
      mypage: mypage ?? this.mypage,
      pali: pali ?? this.pali,
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
    if (vripara.present) {
      map['vripara'] = Variable<String>(vripara.value);
    }
    if (thaipage.present) {
      map['thaipage'] = Variable<String>(thaipage.value);
    }
    if (vripage.present) {
      map['vripage'] = Variable<String>(vripage.value);
    }
    if (ptspage.present) {
      map['ptspage'] = Variable<String>(ptspage.value);
    }
    if (mypage.present) {
      map['mypage'] = Variable<String>(mypage.value);
    }
    if (pali.present) {
      map['pali'] = Variable<String>(pali.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentencesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('paraId: $paraId, ')
          ..write('lineId: $lineId, ')
          ..write('vripara: $vripara, ')
          ..write('thaipage: $thaipage, ')
          ..write('vripage: $vripage, ')
          ..write('ptspage: $ptspage, ')
          ..write('mypage: $mypage, ')
          ..write('pali: $pali, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EpitakaDatabase extends GeneratedDatabase {
  _$EpitakaDatabase(QueryExecutor e) : super(e);
  $EpitakaDatabaseManager get managers => $EpitakaDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $HeadingsTable headings = $HeadingsTable(this);
  late final $SentencesTable sentences = $SentencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    headings,
    sentences,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<int?> refId,
      Value<String?> vriId,
      required String bookId,
      Value<String?> category,
      Value<String?> nikaya,
      Value<String?> subNikaya,
      Value<String?> bookName,
      Value<String?> description,
      Value<String?> mulaRef,
      Value<String?> atthaRef,
      Value<String?> tikaRef,
      Value<int?> paraId,
      Value<int?> chapterLen,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<int?> refId,
      Value<String?> vriId,
      Value<String> bookId,
      Value<String?> category,
      Value<String?> nikaya,
      Value<String?> subNikaya,
      Value<String?> bookName,
      Value<String?> description,
      Value<String?> mulaRef,
      Value<String?> atthaRef,
      Value<String?> tikaRef,
      Value<int?> paraId,
      Value<int?> chapterLen,
    });

class $$BooksTableFilterComposer
    extends Composer<_$EpitakaDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
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

  ColumnFilters<int> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vriId => $composableBuilder(
    column: $table.vriId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nikaya => $composableBuilder(
    column: $table.nikaya,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subNikaya => $composableBuilder(
    column: $table.subNikaya,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mulaRef => $composableBuilder(
    column: $table.mulaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get atthaRef => $composableBuilder(
    column: $table.atthaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tikaRef => $composableBuilder(
    column: $table.tikaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$EpitakaDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
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

  ColumnOrderings<int> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vriId => $composableBuilder(
    column: $table.vriId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nikaya => $composableBuilder(
    column: $table.nikaya,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subNikaya => $composableBuilder(
    column: $table.subNikaya,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mulaRef => $composableBuilder(
    column: $table.mulaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get atthaRef => $composableBuilder(
    column: $table.atthaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tikaRef => $composableBuilder(
    column: $table.tikaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paraId => $composableBuilder(
    column: $table.paraId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$EpitakaDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get vriId =>
      $composableBuilder(column: $table.vriId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get nikaya =>
      $composableBuilder(column: $table.nikaya, builder: (column) => column);

  GeneratedColumn<String> get subNikaya =>
      $composableBuilder(column: $table.subNikaya, builder: (column) => column);

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mulaRef =>
      $composableBuilder(column: $table.mulaRef, builder: (column) => column);

  GeneratedColumn<String> get atthaRef =>
      $composableBuilder(column: $table.atthaRef, builder: (column) => column);

  GeneratedColumn<String> get tikaRef =>
      $composableBuilder(column: $table.tikaRef, builder: (column) => column);

  GeneratedColumn<int> get paraId =>
      $composableBuilder(column: $table.paraId, builder: (column) => column);

  GeneratedColumn<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$EpitakaDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$EpitakaDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$EpitakaDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> refId = const Value.absent(),
                Value<String?> vriId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> nikaya = const Value.absent(),
                Value<String?> subNikaya = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> mulaRef = const Value.absent(),
                Value<String?> atthaRef = const Value.absent(),
                Value<String?> tikaRef = const Value.absent(),
                Value<int?> paraId = const Value.absent(),
                Value<int?> chapterLen = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                refId: refId,
                vriId: vriId,
                bookId: bookId,
                category: category,
                nikaya: nikaya,
                subNikaya: subNikaya,
                bookName: bookName,
                description: description,
                mulaRef: mulaRef,
                atthaRef: atthaRef,
                tikaRef: tikaRef,
                paraId: paraId,
                chapterLen: chapterLen,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> refId = const Value.absent(),
                Value<String?> vriId = const Value.absent(),
                required String bookId,
                Value<String?> category = const Value.absent(),
                Value<String?> nikaya = const Value.absent(),
                Value<String?> subNikaya = const Value.absent(),
                Value<String?> bookName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> mulaRef = const Value.absent(),
                Value<String?> atthaRef = const Value.absent(),
                Value<String?> tikaRef = const Value.absent(),
                Value<int?> paraId = const Value.absent(),
                Value<int?> chapterLen = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                refId: refId,
                vriId: vriId,
                bookId: bookId,
                category: category,
                nikaya: nikaya,
                subNikaya: subNikaya,
                bookName: bookName,
                description: description,
                mulaRef: mulaRef,
                atthaRef: atthaRef,
                tikaRef: tikaRef,
                paraId: paraId,
                chapterLen: chapterLen,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$EpitakaDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$EpitakaDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$HeadingsTableCreateCompanionBuilder =
    HeadingsCompanion Function({
      required String bookId,
      required int paraId,
      Value<int?> level,
      Value<String?> title,
      Value<int?> chapterLen,
      Value<int?> parent,
      Value<String?> scId,
      Value<int> rowid,
    });
typedef $$HeadingsTableUpdateCompanionBuilder =
    HeadingsCompanion Function({
      Value<String> bookId,
      Value<int> paraId,
      Value<int?> level,
      Value<String?> title,
      Value<int?> chapterLen,
      Value<int?> parent,
      Value<String?> scId,
      Value<int> rowid,
    });

class $$HeadingsTableFilterComposer
    extends Composer<_$EpitakaDatabase, $HeadingsTable> {
  $$HeadingsTableFilterComposer({
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

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scId => $composableBuilder(
    column: $table.scId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HeadingsTableOrderingComposer
    extends Composer<_$EpitakaDatabase, $HeadingsTable> {
  $$HeadingsTableOrderingComposer({
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

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scId => $composableBuilder(
    column: $table.scId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HeadingsTableAnnotationComposer
    extends Composer<_$EpitakaDatabase, $HeadingsTable> {
  $$HeadingsTableAnnotationComposer({
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

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get chapterLen => $composableBuilder(
    column: $table.chapterLen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parent =>
      $composableBuilder(column: $table.parent, builder: (column) => column);

  GeneratedColumn<String> get scId =>
      $composableBuilder(column: $table.scId, builder: (column) => column);
}

class $$HeadingsTableTableManager
    extends
        RootTableManager<
          _$EpitakaDatabase,
          $HeadingsTable,
          Heading,
          $$HeadingsTableFilterComposer,
          $$HeadingsTableOrderingComposer,
          $$HeadingsTableAnnotationComposer,
          $$HeadingsTableCreateCompanionBuilder,
          $$HeadingsTableUpdateCompanionBuilder,
          (Heading, BaseReferences<_$EpitakaDatabase, $HeadingsTable, Heading>),
          Heading,
          PrefetchHooks Function()
        > {
  $$HeadingsTableTableManager(_$EpitakaDatabase db, $HeadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> paraId = const Value.absent(),
                Value<int?> level = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> chapterLen = const Value.absent(),
                Value<int?> parent = const Value.absent(),
                Value<String?> scId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeadingsCompanion(
                bookId: bookId,
                paraId: paraId,
                level: level,
                title: title,
                chapterLen: chapterLen,
                parent: parent,
                scId: scId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int paraId,
                Value<int?> level = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> chapterLen = const Value.absent(),
                Value<int?> parent = const Value.absent(),
                Value<String?> scId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeadingsCompanion.insert(
                bookId: bookId,
                paraId: paraId,
                level: level,
                title: title,
                chapterLen: chapterLen,
                parent: parent,
                scId: scId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HeadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$EpitakaDatabase,
      $HeadingsTable,
      Heading,
      $$HeadingsTableFilterComposer,
      $$HeadingsTableOrderingComposer,
      $$HeadingsTableAnnotationComposer,
      $$HeadingsTableCreateCompanionBuilder,
      $$HeadingsTableUpdateCompanionBuilder,
      (Heading, BaseReferences<_$EpitakaDatabase, $HeadingsTable, Heading>),
      Heading,
      PrefetchHooks Function()
    >;
typedef $$SentencesTableCreateCompanionBuilder =
    SentencesCompanion Function({
      required String bookId,
      required int paraId,
      required int lineId,
      Value<String?> vripara,
      Value<String?> thaipage,
      Value<String?> vripage,
      Value<String?> ptspage,
      Value<String?> mypage,
      Value<String?> pali,
      Value<int> rowid,
    });
typedef $$SentencesTableUpdateCompanionBuilder =
    SentencesCompanion Function({
      Value<String> bookId,
      Value<int> paraId,
      Value<int> lineId,
      Value<String?> vripara,
      Value<String?> thaipage,
      Value<String?> vripage,
      Value<String?> ptspage,
      Value<String?> mypage,
      Value<String?> pali,
      Value<int> rowid,
    });

class $$SentencesTableFilterComposer
    extends Composer<_$EpitakaDatabase, $SentencesTable> {
  $$SentencesTableFilterComposer({
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

  ColumnFilters<String> get vripara => $composableBuilder(
    column: $table.vripara,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thaipage => $composableBuilder(
    column: $table.thaipage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vripage => $composableBuilder(
    column: $table.vripage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ptspage => $composableBuilder(
    column: $table.ptspage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mypage => $composableBuilder(
    column: $table.mypage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pali => $composableBuilder(
    column: $table.pali,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SentencesTableOrderingComposer
    extends Composer<_$EpitakaDatabase, $SentencesTable> {
  $$SentencesTableOrderingComposer({
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

  ColumnOrderings<String> get vripara => $composableBuilder(
    column: $table.vripara,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thaipage => $composableBuilder(
    column: $table.thaipage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vripage => $composableBuilder(
    column: $table.vripage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ptspage => $composableBuilder(
    column: $table.ptspage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mypage => $composableBuilder(
    column: $table.mypage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pali => $composableBuilder(
    column: $table.pali,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentencesTableAnnotationComposer
    extends Composer<_$EpitakaDatabase, $SentencesTable> {
  $$SentencesTableAnnotationComposer({
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

  GeneratedColumn<String> get vripara =>
      $composableBuilder(column: $table.vripara, builder: (column) => column);

  GeneratedColumn<String> get thaipage =>
      $composableBuilder(column: $table.thaipage, builder: (column) => column);

  GeneratedColumn<String> get vripage =>
      $composableBuilder(column: $table.vripage, builder: (column) => column);

  GeneratedColumn<String> get ptspage =>
      $composableBuilder(column: $table.ptspage, builder: (column) => column);

  GeneratedColumn<String> get mypage =>
      $composableBuilder(column: $table.mypage, builder: (column) => column);

  GeneratedColumn<String> get pali =>
      $composableBuilder(column: $table.pali, builder: (column) => column);
}

class $$SentencesTableTableManager
    extends
        RootTableManager<
          _$EpitakaDatabase,
          $SentencesTable,
          Sentence,
          $$SentencesTableFilterComposer,
          $$SentencesTableOrderingComposer,
          $$SentencesTableAnnotationComposer,
          $$SentencesTableCreateCompanionBuilder,
          $$SentencesTableUpdateCompanionBuilder,
          (
            Sentence,
            BaseReferences<_$EpitakaDatabase, $SentencesTable, Sentence>,
          ),
          Sentence,
          PrefetchHooks Function()
        > {
  $$SentencesTableTableManager(_$EpitakaDatabase db, $SentencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> paraId = const Value.absent(),
                Value<int> lineId = const Value.absent(),
                Value<String?> vripara = const Value.absent(),
                Value<String?> thaipage = const Value.absent(),
                Value<String?> vripage = const Value.absent(),
                Value<String?> ptspage = const Value.absent(),
                Value<String?> mypage = const Value.absent(),
                Value<String?> pali = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SentencesCompanion(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                vripara: vripara,
                thaipage: thaipage,
                vripage: vripage,
                ptspage: ptspage,
                mypage: mypage,
                pali: pali,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int paraId,
                required int lineId,
                Value<String?> vripara = const Value.absent(),
                Value<String?> thaipage = const Value.absent(),
                Value<String?> vripage = const Value.absent(),
                Value<String?> ptspage = const Value.absent(),
                Value<String?> mypage = const Value.absent(),
                Value<String?> pali = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SentencesCompanion.insert(
                bookId: bookId,
                paraId: paraId,
                lineId: lineId,
                vripara: vripara,
                thaipage: thaipage,
                vripage: vripage,
                ptspage: ptspage,
                mypage: mypage,
                pali: pali,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SentencesTableProcessedTableManager =
    ProcessedTableManager<
      _$EpitakaDatabase,
      $SentencesTable,
      Sentence,
      $$SentencesTableFilterComposer,
      $$SentencesTableOrderingComposer,
      $$SentencesTableAnnotationComposer,
      $$SentencesTableCreateCompanionBuilder,
      $$SentencesTableUpdateCompanionBuilder,
      (Sentence, BaseReferences<_$EpitakaDatabase, $SentencesTable, Sentence>),
      Sentence,
      PrefetchHooks Function()
    >;

class $EpitakaDatabaseManager {
  final _$EpitakaDatabase _db;
  $EpitakaDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$HeadingsTableTableManager get headings =>
      $$HeadingsTableTableManager(_db, _db.headings);
  $$SentencesTableTableManager get sentences =>
      $$SentencesTableTableManager(_db, _db.sentences);
}
