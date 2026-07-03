// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dpd_database.dart';

// ignore_for_file: type=lint
class $DictMetaTable extends DictMeta
    with TableInfo<$DictMetaTable, DictMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dictIdMeta = const VerificationMeta('dictId');
  @override
  late final GeneratedColumn<String> dictId = GeneratedColumn<String>(
    'dict_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cssMeta = const VerificationMeta('css');
  @override
  late final GeneratedColumn<String> css = GeneratedColumn<String>(
    'css',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryCountMeta = const VerificationMeta(
    'entryCount',
  );
  @override
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
    'entry_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [dictId, name, author, css, entryCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dict_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dict_id')) {
      context.handle(
        _dictIdMeta,
        dictId.isAcceptableOrUnknown(data['dict_id']!, _dictIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dictIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('css')) {
      context.handle(
        _cssMeta,
        css.isAcceptableOrUnknown(data['css']!, _cssMeta),
      );
    }
    if (data.containsKey('entry_count')) {
      context.handle(
        _entryCountMeta,
        entryCount.isAcceptableOrUnknown(data['entry_count']!, _entryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dictId};
  @override
  DictMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictMetaData(
      dictId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dict_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      css: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}css'],
      ),
      entryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_count'],
      ),
    );
  }

  @override
  $DictMetaTable createAlias(String alias) {
    return $DictMetaTable(attachedDatabase, alias);
  }
}

class DictMetaData extends DataClass implements Insertable<DictMetaData> {
  final String dictId;
  final String? name;
  final String? author;
  final String? css;
  final int? entryCount;
  const DictMetaData({
    required this.dictId,
    this.name,
    this.author,
    this.css,
    this.entryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dict_id'] = Variable<String>(dictId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || css != null) {
      map['css'] = Variable<String>(css);
    }
    if (!nullToAbsent || entryCount != null) {
      map['entry_count'] = Variable<int>(entryCount);
    }
    return map;
  }

  DictMetaCompanion toCompanion(bool nullToAbsent) {
    return DictMetaCompanion(
      dictId: Value(dictId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      css: css == null && nullToAbsent ? const Value.absent() : Value(css),
      entryCount: entryCount == null && nullToAbsent
          ? const Value.absent()
          : Value(entryCount),
    );
  }

  factory DictMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictMetaData(
      dictId: serializer.fromJson<String>(json['dictId']),
      name: serializer.fromJson<String?>(json['name']),
      author: serializer.fromJson<String?>(json['author']),
      css: serializer.fromJson<String?>(json['css']),
      entryCount: serializer.fromJson<int?>(json['entryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dictId': serializer.toJson<String>(dictId),
      'name': serializer.toJson<String?>(name),
      'author': serializer.toJson<String?>(author),
      'css': serializer.toJson<String?>(css),
      'entryCount': serializer.toJson<int?>(entryCount),
    };
  }

  DictMetaData copyWith({
    String? dictId,
    Value<String?> name = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> css = const Value.absent(),
    Value<int?> entryCount = const Value.absent(),
  }) => DictMetaData(
    dictId: dictId ?? this.dictId,
    name: name.present ? name.value : this.name,
    author: author.present ? author.value : this.author,
    css: css.present ? css.value : this.css,
    entryCount: entryCount.present ? entryCount.value : this.entryCount,
  );
  DictMetaData copyWithCompanion(DictMetaCompanion data) {
    return DictMetaData(
      dictId: data.dictId.present ? data.dictId.value : this.dictId,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      css: data.css.present ? data.css.value : this.css,
      entryCount: data.entryCount.present
          ? data.entryCount.value
          : this.entryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictMetaData(')
          ..write('dictId: $dictId, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('css: $css, ')
          ..write('entryCount: $entryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dictId, name, author, css, entryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictMetaData &&
          other.dictId == this.dictId &&
          other.name == this.name &&
          other.author == this.author &&
          other.css == this.css &&
          other.entryCount == this.entryCount);
}

class DictMetaCompanion extends UpdateCompanion<DictMetaData> {
  final Value<String> dictId;
  final Value<String?> name;
  final Value<String?> author;
  final Value<String?> css;
  final Value<int?> entryCount;
  final Value<int> rowid;
  const DictMetaCompanion({
    this.dictId = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.css = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictMetaCompanion.insert({
    required String dictId,
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.css = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dictId = Value(dictId);
  static Insertable<DictMetaData> custom({
    Expression<String>? dictId,
    Expression<String>? name,
    Expression<String>? author,
    Expression<String>? css,
    Expression<int>? entryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dictId != null) 'dict_id': dictId,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (css != null) 'css': css,
      if (entryCount != null) 'entry_count': entryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictMetaCompanion copyWith({
    Value<String>? dictId,
    Value<String?>? name,
    Value<String?>? author,
    Value<String?>? css,
    Value<int?>? entryCount,
    Value<int>? rowid,
  }) {
    return DictMetaCompanion(
      dictId: dictId ?? this.dictId,
      name: name ?? this.name,
      author: author ?? this.author,
      css: css ?? this.css,
      entryCount: entryCount ?? this.entryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dictId.present) {
      map['dict_id'] = Variable<String>(dictId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (css.present) {
      map['css'] = Variable<String>(css.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictMetaCompanion(')
          ..write('dictId: $dictId, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('css: $css, ')
          ..write('entryCount: $entryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictEntriesTable extends DictEntries
    with TableInfo<$DictEntriesTable, DictEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dictIdMeta = const VerificationMeta('dictId');
  @override
  late final GeneratedColumn<String> dictId = GeneratedColumn<String>(
    'dict_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordFuzzyMeta = const VerificationMeta(
    'wordFuzzy',
  );
  @override
  late final GeneratedColumn<String> wordFuzzy = GeneratedColumn<String>(
    'word_fuzzy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionHtmlMeta = const VerificationMeta(
    'definitionHtml',
  );
  @override
  late final GeneratedColumn<String> definitionHtml = GeneratedColumn<String>(
    'definition_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionPlainMeta = const VerificationMeta(
    'definitionPlain',
  );
  @override
  late final GeneratedColumn<String> definitionPlain = GeneratedColumn<String>(
    'definition_plain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dictId,
    word,
    wordFuzzy,
    definitionHtml,
    definitionPlain,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dict_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dict_id')) {
      context.handle(
        _dictIdMeta,
        dictId.isAcceptableOrUnknown(data['dict_id']!, _dictIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dictIdMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('word_fuzzy')) {
      context.handle(
        _wordFuzzyMeta,
        wordFuzzy.isAcceptableOrUnknown(data['word_fuzzy']!, _wordFuzzyMeta),
      );
    }
    if (data.containsKey('definition_html')) {
      context.handle(
        _definitionHtmlMeta,
        definitionHtml.isAcceptableOrUnknown(
          data['definition_html']!,
          _definitionHtmlMeta,
        ),
      );
    }
    if (data.containsKey('definition_plain')) {
      context.handle(
        _definitionPlainMeta,
        definitionPlain.isAcceptableOrUnknown(
          data['definition_plain']!,
          _definitionPlainMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dictId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dict_id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      wordFuzzy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_fuzzy'],
      ),
      definitionHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_html'],
      ),
      definitionPlain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_plain'],
      ),
    );
  }

  @override
  $DictEntriesTable createAlias(String alias) {
    return $DictEntriesTable(attachedDatabase, alias);
  }
}

class DictEntry extends DataClass implements Insertable<DictEntry> {
  final int id;
  final String dictId;
  final String word;
  final String? wordFuzzy;
  final String? definitionHtml;
  final String? definitionPlain;
  const DictEntry({
    required this.id,
    required this.dictId,
    required this.word,
    this.wordFuzzy,
    this.definitionHtml,
    this.definitionPlain,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dict_id'] = Variable<String>(dictId);
    map['word'] = Variable<String>(word);
    if (!nullToAbsent || wordFuzzy != null) {
      map['word_fuzzy'] = Variable<String>(wordFuzzy);
    }
    if (!nullToAbsent || definitionHtml != null) {
      map['definition_html'] = Variable<String>(definitionHtml);
    }
    if (!nullToAbsent || definitionPlain != null) {
      map['definition_plain'] = Variable<String>(definitionPlain);
    }
    return map;
  }

  DictEntriesCompanion toCompanion(bool nullToAbsent) {
    return DictEntriesCompanion(
      id: Value(id),
      dictId: Value(dictId),
      word: Value(word),
      wordFuzzy: wordFuzzy == null && nullToAbsent
          ? const Value.absent()
          : Value(wordFuzzy),
      definitionHtml: definitionHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(definitionHtml),
      definitionPlain: definitionPlain == null && nullToAbsent
          ? const Value.absent()
          : Value(definitionPlain),
    );
  }

  factory DictEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictEntry(
      id: serializer.fromJson<int>(json['id']),
      dictId: serializer.fromJson<String>(json['dictId']),
      word: serializer.fromJson<String>(json['word']),
      wordFuzzy: serializer.fromJson<String?>(json['wordFuzzy']),
      definitionHtml: serializer.fromJson<String?>(json['definitionHtml']),
      definitionPlain: serializer.fromJson<String?>(json['definitionPlain']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dictId': serializer.toJson<String>(dictId),
      'word': serializer.toJson<String>(word),
      'wordFuzzy': serializer.toJson<String?>(wordFuzzy),
      'definitionHtml': serializer.toJson<String?>(definitionHtml),
      'definitionPlain': serializer.toJson<String?>(definitionPlain),
    };
  }

  DictEntry copyWith({
    int? id,
    String? dictId,
    String? word,
    Value<String?> wordFuzzy = const Value.absent(),
    Value<String?> definitionHtml = const Value.absent(),
    Value<String?> definitionPlain = const Value.absent(),
  }) => DictEntry(
    id: id ?? this.id,
    dictId: dictId ?? this.dictId,
    word: word ?? this.word,
    wordFuzzy: wordFuzzy.present ? wordFuzzy.value : this.wordFuzzy,
    definitionHtml: definitionHtml.present
        ? definitionHtml.value
        : this.definitionHtml,
    definitionPlain: definitionPlain.present
        ? definitionPlain.value
        : this.definitionPlain,
  );
  DictEntry copyWithCompanion(DictEntriesCompanion data) {
    return DictEntry(
      id: data.id.present ? data.id.value : this.id,
      dictId: data.dictId.present ? data.dictId.value : this.dictId,
      word: data.word.present ? data.word.value : this.word,
      wordFuzzy: data.wordFuzzy.present ? data.wordFuzzy.value : this.wordFuzzy,
      definitionHtml: data.definitionHtml.present
          ? data.definitionHtml.value
          : this.definitionHtml,
      definitionPlain: data.definitionPlain.present
          ? data.definitionPlain.value
          : this.definitionPlain,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictEntry(')
          ..write('id: $id, ')
          ..write('dictId: $dictId, ')
          ..write('word: $word, ')
          ..write('wordFuzzy: $wordFuzzy, ')
          ..write('definitionHtml: $definitionHtml, ')
          ..write('definitionPlain: $definitionPlain')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dictId, word, wordFuzzy, definitionHtml, definitionPlain);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictEntry &&
          other.id == this.id &&
          other.dictId == this.dictId &&
          other.word == this.word &&
          other.wordFuzzy == this.wordFuzzy &&
          other.definitionHtml == this.definitionHtml &&
          other.definitionPlain == this.definitionPlain);
}

class DictEntriesCompanion extends UpdateCompanion<DictEntry> {
  final Value<int> id;
  final Value<String> dictId;
  final Value<String> word;
  final Value<String?> wordFuzzy;
  final Value<String?> definitionHtml;
  final Value<String?> definitionPlain;
  const DictEntriesCompanion({
    this.id = const Value.absent(),
    this.dictId = const Value.absent(),
    this.word = const Value.absent(),
    this.wordFuzzy = const Value.absent(),
    this.definitionHtml = const Value.absent(),
    this.definitionPlain = const Value.absent(),
  });
  DictEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String dictId,
    required String word,
    this.wordFuzzy = const Value.absent(),
    this.definitionHtml = const Value.absent(),
    this.definitionPlain = const Value.absent(),
  }) : dictId = Value(dictId),
       word = Value(word);
  static Insertable<DictEntry> custom({
    Expression<int>? id,
    Expression<String>? dictId,
    Expression<String>? word,
    Expression<String>? wordFuzzy,
    Expression<String>? definitionHtml,
    Expression<String>? definitionPlain,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dictId != null) 'dict_id': dictId,
      if (word != null) 'word': word,
      if (wordFuzzy != null) 'word_fuzzy': wordFuzzy,
      if (definitionHtml != null) 'definition_html': definitionHtml,
      if (definitionPlain != null) 'definition_plain': definitionPlain,
    });
  }

  DictEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? dictId,
    Value<String>? word,
    Value<String?>? wordFuzzy,
    Value<String?>? definitionHtml,
    Value<String?>? definitionPlain,
  }) {
    return DictEntriesCompanion(
      id: id ?? this.id,
      dictId: dictId ?? this.dictId,
      word: word ?? this.word,
      wordFuzzy: wordFuzzy ?? this.wordFuzzy,
      definitionHtml: definitionHtml ?? this.definitionHtml,
      definitionPlain: definitionPlain ?? this.definitionPlain,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dictId.present) {
      map['dict_id'] = Variable<String>(dictId.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (wordFuzzy.present) {
      map['word_fuzzy'] = Variable<String>(wordFuzzy.value);
    }
    if (definitionHtml.present) {
      map['definition_html'] = Variable<String>(definitionHtml.value);
    }
    if (definitionPlain.present) {
      map['definition_plain'] = Variable<String>(definitionPlain.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dictId: $dictId, ')
          ..write('word: $word, ')
          ..write('wordFuzzy: $wordFuzzy, ')
          ..write('definitionHtml: $definitionHtml, ')
          ..write('definitionPlain: $definitionPlain')
          ..write(')'))
        .toString();
  }
}

class $DpdHeadwordsTable extends DpdHeadwords
    with TableInfo<$DpdHeadwordsTable, DpdHeadword> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DpdHeadwordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lemma1Meta = const VerificationMeta('lemma1');
  @override
  late final GeneratedColumn<String> lemma1 = GeneratedColumn<String>(
    'lemma_1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lemma2Meta = const VerificationMeta('lemma2');
  @override
  late final GeneratedColumn<String> lemma2 = GeneratedColumn<String>(
    'lemma_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grammarMeta = const VerificationMeta(
    'grammar',
  );
  @override
  late final GeneratedColumn<String> grammar = GeneratedColumn<String>(
    'grammar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _derivedFromMeta = const VerificationMeta(
    'derivedFrom',
  );
  @override
  late final GeneratedColumn<String> derivedFrom = GeneratedColumn<String>(
    'derived_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _negMeta = const VerificationMeta('neg');
  @override
  late final GeneratedColumn<String> neg = GeneratedColumn<String>(
    'neg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verbMeta = const VerificationMeta('verb');
  @override
  late final GeneratedColumn<String> verb = GeneratedColumn<String>(
    'verb',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transMeta = const VerificationMeta('trans');
  @override
  late final GeneratedColumn<String> trans = GeneratedColumn<String>(
    'trans',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plusCaseMeta = const VerificationMeta(
    'plusCase',
  );
  @override
  late final GeneratedColumn<String> plusCase = GeneratedColumn<String>(
    'plus_case',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaning1Meta = const VerificationMeta(
    'meaning1',
  );
  @override
  late final GeneratedColumn<String> meaning1 = GeneratedColumn<String>(
    'meaning_1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningLitMeta = const VerificationMeta(
    'meaningLit',
  );
  @override
  late final GeneratedColumn<String> meaningLit = GeneratedColumn<String>(
    'meaning_lit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaning2Meta = const VerificationMeta(
    'meaning2',
  );
  @override
  late final GeneratedColumn<String> meaning2 = GeneratedColumn<String>(
    'meaning_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _source1Meta = const VerificationMeta(
    'source1',
  );
  @override
  late final GeneratedColumn<String> source1 = GeneratedColumn<String>(
    'source_1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sutta1Meta = const VerificationMeta('sutta1');
  @override
  late final GeneratedColumn<String> sutta1 = GeneratedColumn<String>(
    'sutta_1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _example1Meta = const VerificationMeta(
    'example1',
  );
  @override
  late final GeneratedColumn<String> example1 = GeneratedColumn<String>(
    'example_1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _source2Meta = const VerificationMeta(
    'source2',
  );
  @override
  late final GeneratedColumn<String> source2 = GeneratedColumn<String>(
    'source_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sutta2Meta = const VerificationMeta('sutta2');
  @override
  late final GeneratedColumn<String> sutta2 = GeneratedColumn<String>(
    'sutta_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _example2Meta = const VerificationMeta(
    'example2',
  );
  @override
  late final GeneratedColumn<String> example2 = GeneratedColumn<String>(
    'example_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootKeyMeta = const VerificationMeta(
    'rootKey',
  );
  @override
  late final GeneratedColumn<String> rootKey = GeneratedColumn<String>(
    'root_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootSignMeta = const VerificationMeta(
    'rootSign',
  );
  @override
  late final GeneratedColumn<String> rootSign = GeneratedColumn<String>(
    'root_sign',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootBaseMeta = const VerificationMeta(
    'rootBase',
  );
  @override
  late final GeneratedColumn<String> rootBase = GeneratedColumn<String>(
    'root_base',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyRootMeta = const VerificationMeta(
    'familyRoot',
  );
  @override
  late final GeneratedColumn<String> familyRoot = GeneratedColumn<String>(
    'family_root',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyWordMeta = const VerificationMeta(
    'familyWord',
  );
  @override
  late final GeneratedColumn<String> familyWord = GeneratedColumn<String>(
    'family_word',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyCompoundMeta = const VerificationMeta(
    'familyCompound',
  );
  @override
  late final GeneratedColumn<String> familyCompound = GeneratedColumn<String>(
    'family_compound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyIdiomsMeta = const VerificationMeta(
    'familyIdioms',
  );
  @override
  late final GeneratedColumn<String> familyIdioms = GeneratedColumn<String>(
    'family_idioms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _constructionMeta = const VerificationMeta(
    'construction',
  );
  @override
  late final GeneratedColumn<String> construction = GeneratedColumn<String>(
    'construction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _compoundTypeMeta = const VerificationMeta(
    'compoundType',
  );
  @override
  late final GeneratedColumn<String> compoundType = GeneratedColumn<String>(
    'compound_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _antonymMeta = const VerificationMeta(
    'antonym',
  );
  @override
  late final GeneratedColumn<String> antonym = GeneratedColumn<String>(
    'antonym',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synonymMeta = const VerificationMeta(
    'synonym',
  );
  @override
  late final GeneratedColumn<String> synonym = GeneratedColumn<String>(
    'synonym',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variantMeta = const VerificationMeta(
    'variant',
  );
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stemMeta = const VerificationMeta('stem');
  @override
  late final GeneratedColumn<String> stem = GeneratedColumn<String>(
    'stem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
    'suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _freqDataMeta = const VerificationMeta(
    'freqData',
  );
  @override
  late final GeneratedColumn<String> freqData = GeneratedColumn<String>(
    'freq_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lemmaIpaMeta = const VerificationMeta(
    'lemmaIpa',
  );
  @override
  late final GeneratedColumn<String> lemmaIpa = GeneratedColumn<String>(
    'lemma_ipa',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ebtCountMeta = const VerificationMeta(
    'ebtCount',
  );
  @override
  late final GeneratedColumn<int> ebtCount = GeneratedColumn<int>(
    'ebt_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nonIaMeta = const VerificationMeta('nonIa');
  @override
  late final GeneratedColumn<String> nonIa = GeneratedColumn<String>(
    'non_ia',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sanskritMeta = const VerificationMeta(
    'sanskrit',
  );
  @override
  late final GeneratedColumn<String> sanskrit = GeneratedColumn<String>(
    'sanskrit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cognateMeta = const VerificationMeta(
    'cognate',
  );
  @override
  late final GeneratedColumn<String> cognate = GeneratedColumn<String>(
    'cognate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneticMeta = const VerificationMeta(
    'phonetic',
  );
  @override
  late final GeneratedColumn<String> phonetic = GeneratedColumn<String>(
    'phonetic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _varPhoneticMeta = const VerificationMeta(
    'varPhonetic',
  );
  @override
  late final GeneratedColumn<String> varPhonetic = GeneratedColumn<String>(
    'var_phonetic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _varTextMeta = const VerificationMeta(
    'varText',
  );
  @override
  late final GeneratedColumn<String> varText = GeneratedColumn<String>(
    'var_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _commentaryMeta = const VerificationMeta(
    'commentary',
  );
  @override
  late final GeneratedColumn<String> commentary = GeneratedColumn<String>(
    'commentary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lemma1,
    lemma2,
    pos,
    grammar,
    derivedFrom,
    neg,
    verb,
    trans,
    plusCase,
    meaning1,
    meaningLit,
    meaning2,
    source1,
    sutta1,
    example1,
    source2,
    sutta2,
    example2,
    rootKey,
    rootSign,
    rootBase,
    familyRoot,
    familyWord,
    familyCompound,
    familyIdioms,
    construction,
    compoundType,
    antonym,
    synonym,
    variant,
    stem,
    pattern,
    suffix,
    freqData,
    lemmaIpa,
    ebtCount,
    nonIa,
    sanskrit,
    cognate,
    link,
    phonetic,
    varPhonetic,
    varText,
    origin,
    notes,
    commentary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dpd_headwords';
  @override
  VerificationContext validateIntegrity(
    Insertable<DpdHeadword> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lemma_1')) {
      context.handle(
        _lemma1Meta,
        lemma1.isAcceptableOrUnknown(data['lemma_1']!, _lemma1Meta),
      );
    } else if (isInserting) {
      context.missing(_lemma1Meta);
    }
    if (data.containsKey('lemma_2')) {
      context.handle(
        _lemma2Meta,
        lemma2.isAcceptableOrUnknown(data['lemma_2']!, _lemma2Meta),
      );
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    }
    if (data.containsKey('grammar')) {
      context.handle(
        _grammarMeta,
        grammar.isAcceptableOrUnknown(data['grammar']!, _grammarMeta),
      );
    }
    if (data.containsKey('derived_from')) {
      context.handle(
        _derivedFromMeta,
        derivedFrom.isAcceptableOrUnknown(
          data['derived_from']!,
          _derivedFromMeta,
        ),
      );
    }
    if (data.containsKey('neg')) {
      context.handle(
        _negMeta,
        neg.isAcceptableOrUnknown(data['neg']!, _negMeta),
      );
    }
    if (data.containsKey('verb')) {
      context.handle(
        _verbMeta,
        verb.isAcceptableOrUnknown(data['verb']!, _verbMeta),
      );
    }
    if (data.containsKey('trans')) {
      context.handle(
        _transMeta,
        trans.isAcceptableOrUnknown(data['trans']!, _transMeta),
      );
    }
    if (data.containsKey('plus_case')) {
      context.handle(
        _plusCaseMeta,
        plusCase.isAcceptableOrUnknown(data['plus_case']!, _plusCaseMeta),
      );
    }
    if (data.containsKey('meaning_1')) {
      context.handle(
        _meaning1Meta,
        meaning1.isAcceptableOrUnknown(data['meaning_1']!, _meaning1Meta),
      );
    }
    if (data.containsKey('meaning_lit')) {
      context.handle(
        _meaningLitMeta,
        meaningLit.isAcceptableOrUnknown(data['meaning_lit']!, _meaningLitMeta),
      );
    }
    if (data.containsKey('meaning_2')) {
      context.handle(
        _meaning2Meta,
        meaning2.isAcceptableOrUnknown(data['meaning_2']!, _meaning2Meta),
      );
    }
    if (data.containsKey('source_1')) {
      context.handle(
        _source1Meta,
        source1.isAcceptableOrUnknown(data['source_1']!, _source1Meta),
      );
    }
    if (data.containsKey('sutta_1')) {
      context.handle(
        _sutta1Meta,
        sutta1.isAcceptableOrUnknown(data['sutta_1']!, _sutta1Meta),
      );
    }
    if (data.containsKey('example_1')) {
      context.handle(
        _example1Meta,
        example1.isAcceptableOrUnknown(data['example_1']!, _example1Meta),
      );
    }
    if (data.containsKey('source_2')) {
      context.handle(
        _source2Meta,
        source2.isAcceptableOrUnknown(data['source_2']!, _source2Meta),
      );
    }
    if (data.containsKey('sutta_2')) {
      context.handle(
        _sutta2Meta,
        sutta2.isAcceptableOrUnknown(data['sutta_2']!, _sutta2Meta),
      );
    }
    if (data.containsKey('example_2')) {
      context.handle(
        _example2Meta,
        example2.isAcceptableOrUnknown(data['example_2']!, _example2Meta),
      );
    }
    if (data.containsKey('root_key')) {
      context.handle(
        _rootKeyMeta,
        rootKey.isAcceptableOrUnknown(data['root_key']!, _rootKeyMeta),
      );
    }
    if (data.containsKey('root_sign')) {
      context.handle(
        _rootSignMeta,
        rootSign.isAcceptableOrUnknown(data['root_sign']!, _rootSignMeta),
      );
    }
    if (data.containsKey('root_base')) {
      context.handle(
        _rootBaseMeta,
        rootBase.isAcceptableOrUnknown(data['root_base']!, _rootBaseMeta),
      );
    }
    if (data.containsKey('family_root')) {
      context.handle(
        _familyRootMeta,
        familyRoot.isAcceptableOrUnknown(data['family_root']!, _familyRootMeta),
      );
    }
    if (data.containsKey('family_word')) {
      context.handle(
        _familyWordMeta,
        familyWord.isAcceptableOrUnknown(data['family_word']!, _familyWordMeta),
      );
    }
    if (data.containsKey('family_compound')) {
      context.handle(
        _familyCompoundMeta,
        familyCompound.isAcceptableOrUnknown(
          data['family_compound']!,
          _familyCompoundMeta,
        ),
      );
    }
    if (data.containsKey('family_idioms')) {
      context.handle(
        _familyIdiomsMeta,
        familyIdioms.isAcceptableOrUnknown(
          data['family_idioms']!,
          _familyIdiomsMeta,
        ),
      );
    }
    if (data.containsKey('construction')) {
      context.handle(
        _constructionMeta,
        construction.isAcceptableOrUnknown(
          data['construction']!,
          _constructionMeta,
        ),
      );
    }
    if (data.containsKey('compound_type')) {
      context.handle(
        _compoundTypeMeta,
        compoundType.isAcceptableOrUnknown(
          data['compound_type']!,
          _compoundTypeMeta,
        ),
      );
    }
    if (data.containsKey('antonym')) {
      context.handle(
        _antonymMeta,
        antonym.isAcceptableOrUnknown(data['antonym']!, _antonymMeta),
      );
    }
    if (data.containsKey('synonym')) {
      context.handle(
        _synonymMeta,
        synonym.isAcceptableOrUnknown(data['synonym']!, _synonymMeta),
      );
    }
    if (data.containsKey('variant')) {
      context.handle(
        _variantMeta,
        variant.isAcceptableOrUnknown(data['variant']!, _variantMeta),
      );
    }
    if (data.containsKey('stem')) {
      context.handle(
        _stemMeta,
        stem.isAcceptableOrUnknown(data['stem']!, _stemMeta),
      );
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    }
    if (data.containsKey('suffix')) {
      context.handle(
        _suffixMeta,
        suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta),
      );
    }
    if (data.containsKey('freq_data')) {
      context.handle(
        _freqDataMeta,
        freqData.isAcceptableOrUnknown(data['freq_data']!, _freqDataMeta),
      );
    }
    if (data.containsKey('lemma_ipa')) {
      context.handle(
        _lemmaIpaMeta,
        lemmaIpa.isAcceptableOrUnknown(data['lemma_ipa']!, _lemmaIpaMeta),
      );
    }
    if (data.containsKey('ebt_count')) {
      context.handle(
        _ebtCountMeta,
        ebtCount.isAcceptableOrUnknown(data['ebt_count']!, _ebtCountMeta),
      );
    }
    if (data.containsKey('non_ia')) {
      context.handle(
        _nonIaMeta,
        nonIa.isAcceptableOrUnknown(data['non_ia']!, _nonIaMeta),
      );
    }
    if (data.containsKey('sanskrit')) {
      context.handle(
        _sanskritMeta,
        sanskrit.isAcceptableOrUnknown(data['sanskrit']!, _sanskritMeta),
      );
    }
    if (data.containsKey('cognate')) {
      context.handle(
        _cognateMeta,
        cognate.isAcceptableOrUnknown(data['cognate']!, _cognateMeta),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    if (data.containsKey('phonetic')) {
      context.handle(
        _phoneticMeta,
        phonetic.isAcceptableOrUnknown(data['phonetic']!, _phoneticMeta),
      );
    }
    if (data.containsKey('var_phonetic')) {
      context.handle(
        _varPhoneticMeta,
        varPhonetic.isAcceptableOrUnknown(
          data['var_phonetic']!,
          _varPhoneticMeta,
        ),
      );
    }
    if (data.containsKey('var_text')) {
      context.handle(
        _varTextMeta,
        varText.isAcceptableOrUnknown(data['var_text']!, _varTextMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('commentary')) {
      context.handle(
        _commentaryMeta,
        commentary.isAcceptableOrUnknown(data['commentary']!, _commentaryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DpdHeadword map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DpdHeadword(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lemma1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma_1'],
      )!,
      lemma2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma_2'],
      ),
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      ),
      grammar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grammar'],
      ),
      derivedFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derived_from'],
      ),
      neg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}neg'],
      ),
      verb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verb'],
      ),
      trans: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trans'],
      ),
      plusCase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plus_case'],
      ),
      meaning1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning_1'],
      ),
      meaningLit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning_lit'],
      ),
      meaning2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning_2'],
      ),
      source1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_1'],
      ),
      sutta1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sutta_1'],
      ),
      example1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_1'],
      ),
      source2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_2'],
      ),
      sutta2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sutta_2'],
      ),
      example2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_2'],
      ),
      rootKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_key'],
      ),
      rootSign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_sign'],
      ),
      rootBase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_base'],
      ),
      familyRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_root'],
      ),
      familyWord: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_word'],
      ),
      familyCompound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_compound'],
      ),
      familyIdioms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_idioms'],
      ),
      construction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}construction'],
      ),
      compoundType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_type'],
      ),
      antonym: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}antonym'],
      ),
      synonym: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synonym'],
      ),
      variant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant'],
      ),
      stem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stem'],
      ),
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      ),
      suffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suffix'],
      ),
      freqData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}freq_data'],
      ),
      lemmaIpa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma_ipa'],
      ),
      ebtCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ebt_count'],
      ),
      nonIa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}non_ia'],
      ),
      sanskrit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit'],
      ),
      cognate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cognate'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      phonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phonetic'],
      ),
      varPhonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}var_phonetic'],
      ),
      varText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}var_text'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      commentary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commentary'],
      ),
    );
  }

  @override
  $DpdHeadwordsTable createAlias(String alias) {
    return $DpdHeadwordsTable(attachedDatabase, alias);
  }
}

class DpdHeadword extends DataClass implements Insertable<DpdHeadword> {
  final int id;
  final String lemma1;
  final String? lemma2;
  final String? pos;
  final String? grammar;
  final String? derivedFrom;
  final String? neg;
  final String? verb;
  final String? trans;
  final String? plusCase;
  final String? meaning1;
  final String? meaningLit;
  final String? meaning2;
  final String? source1;
  final String? sutta1;
  final String? example1;
  final String? source2;
  final String? sutta2;
  final String? example2;
  final String? rootKey;
  final String? rootSign;
  final String? rootBase;
  final String? familyRoot;
  final String? familyWord;
  final String? familyCompound;
  final String? familyIdioms;
  final String? construction;
  final String? compoundType;
  final String? antonym;
  final String? synonym;
  final String? variant;
  final String? stem;
  final String? pattern;
  final String? suffix;
  final String? freqData;
  final String? lemmaIpa;
  final int? ebtCount;
  final String? nonIa;
  final String? sanskrit;
  final String? cognate;
  final String? link;
  final String? phonetic;
  final String? varPhonetic;
  final String? varText;
  final String? origin;
  final String? notes;
  final String? commentary;
  const DpdHeadword({
    required this.id,
    required this.lemma1,
    this.lemma2,
    this.pos,
    this.grammar,
    this.derivedFrom,
    this.neg,
    this.verb,
    this.trans,
    this.plusCase,
    this.meaning1,
    this.meaningLit,
    this.meaning2,
    this.source1,
    this.sutta1,
    this.example1,
    this.source2,
    this.sutta2,
    this.example2,
    this.rootKey,
    this.rootSign,
    this.rootBase,
    this.familyRoot,
    this.familyWord,
    this.familyCompound,
    this.familyIdioms,
    this.construction,
    this.compoundType,
    this.antonym,
    this.synonym,
    this.variant,
    this.stem,
    this.pattern,
    this.suffix,
    this.freqData,
    this.lemmaIpa,
    this.ebtCount,
    this.nonIa,
    this.sanskrit,
    this.cognate,
    this.link,
    this.phonetic,
    this.varPhonetic,
    this.varText,
    this.origin,
    this.notes,
    this.commentary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lemma_1'] = Variable<String>(lemma1);
    if (!nullToAbsent || lemma2 != null) {
      map['lemma_2'] = Variable<String>(lemma2);
    }
    if (!nullToAbsent || pos != null) {
      map['pos'] = Variable<String>(pos);
    }
    if (!nullToAbsent || grammar != null) {
      map['grammar'] = Variable<String>(grammar);
    }
    if (!nullToAbsent || derivedFrom != null) {
      map['derived_from'] = Variable<String>(derivedFrom);
    }
    if (!nullToAbsent || neg != null) {
      map['neg'] = Variable<String>(neg);
    }
    if (!nullToAbsent || verb != null) {
      map['verb'] = Variable<String>(verb);
    }
    if (!nullToAbsent || trans != null) {
      map['trans'] = Variable<String>(trans);
    }
    if (!nullToAbsent || plusCase != null) {
      map['plus_case'] = Variable<String>(plusCase);
    }
    if (!nullToAbsent || meaning1 != null) {
      map['meaning_1'] = Variable<String>(meaning1);
    }
    if (!nullToAbsent || meaningLit != null) {
      map['meaning_lit'] = Variable<String>(meaningLit);
    }
    if (!nullToAbsent || meaning2 != null) {
      map['meaning_2'] = Variable<String>(meaning2);
    }
    if (!nullToAbsent || source1 != null) {
      map['source_1'] = Variable<String>(source1);
    }
    if (!nullToAbsent || sutta1 != null) {
      map['sutta_1'] = Variable<String>(sutta1);
    }
    if (!nullToAbsent || example1 != null) {
      map['example_1'] = Variable<String>(example1);
    }
    if (!nullToAbsent || source2 != null) {
      map['source_2'] = Variable<String>(source2);
    }
    if (!nullToAbsent || sutta2 != null) {
      map['sutta_2'] = Variable<String>(sutta2);
    }
    if (!nullToAbsent || example2 != null) {
      map['example_2'] = Variable<String>(example2);
    }
    if (!nullToAbsent || rootKey != null) {
      map['root_key'] = Variable<String>(rootKey);
    }
    if (!nullToAbsent || rootSign != null) {
      map['root_sign'] = Variable<String>(rootSign);
    }
    if (!nullToAbsent || rootBase != null) {
      map['root_base'] = Variable<String>(rootBase);
    }
    if (!nullToAbsent || familyRoot != null) {
      map['family_root'] = Variable<String>(familyRoot);
    }
    if (!nullToAbsent || familyWord != null) {
      map['family_word'] = Variable<String>(familyWord);
    }
    if (!nullToAbsent || familyCompound != null) {
      map['family_compound'] = Variable<String>(familyCompound);
    }
    if (!nullToAbsent || familyIdioms != null) {
      map['family_idioms'] = Variable<String>(familyIdioms);
    }
    if (!nullToAbsent || construction != null) {
      map['construction'] = Variable<String>(construction);
    }
    if (!nullToAbsent || compoundType != null) {
      map['compound_type'] = Variable<String>(compoundType);
    }
    if (!nullToAbsent || antonym != null) {
      map['antonym'] = Variable<String>(antonym);
    }
    if (!nullToAbsent || synonym != null) {
      map['synonym'] = Variable<String>(synonym);
    }
    if (!nullToAbsent || variant != null) {
      map['variant'] = Variable<String>(variant);
    }
    if (!nullToAbsent || stem != null) {
      map['stem'] = Variable<String>(stem);
    }
    if (!nullToAbsent || pattern != null) {
      map['pattern'] = Variable<String>(pattern);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    if (!nullToAbsent || freqData != null) {
      map['freq_data'] = Variable<String>(freqData);
    }
    if (!nullToAbsent || lemmaIpa != null) {
      map['lemma_ipa'] = Variable<String>(lemmaIpa);
    }
    if (!nullToAbsent || ebtCount != null) {
      map['ebt_count'] = Variable<int>(ebtCount);
    }
    if (!nullToAbsent || nonIa != null) {
      map['non_ia'] = Variable<String>(nonIa);
    }
    if (!nullToAbsent || sanskrit != null) {
      map['sanskrit'] = Variable<String>(sanskrit);
    }
    if (!nullToAbsent || cognate != null) {
      map['cognate'] = Variable<String>(cognate);
    }
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    if (!nullToAbsent || phonetic != null) {
      map['phonetic'] = Variable<String>(phonetic);
    }
    if (!nullToAbsent || varPhonetic != null) {
      map['var_phonetic'] = Variable<String>(varPhonetic);
    }
    if (!nullToAbsent || varText != null) {
      map['var_text'] = Variable<String>(varText);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || commentary != null) {
      map['commentary'] = Variable<String>(commentary);
    }
    return map;
  }

  DpdHeadwordsCompanion toCompanion(bool nullToAbsent) {
    return DpdHeadwordsCompanion(
      id: Value(id),
      lemma1: Value(lemma1),
      lemma2: lemma2 == null && nullToAbsent
          ? const Value.absent()
          : Value(lemma2),
      pos: pos == null && nullToAbsent ? const Value.absent() : Value(pos),
      grammar: grammar == null && nullToAbsent
          ? const Value.absent()
          : Value(grammar),
      derivedFrom: derivedFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(derivedFrom),
      neg: neg == null && nullToAbsent ? const Value.absent() : Value(neg),
      verb: verb == null && nullToAbsent ? const Value.absent() : Value(verb),
      trans: trans == null && nullToAbsent
          ? const Value.absent()
          : Value(trans),
      plusCase: plusCase == null && nullToAbsent
          ? const Value.absent()
          : Value(plusCase),
      meaning1: meaning1 == null && nullToAbsent
          ? const Value.absent()
          : Value(meaning1),
      meaningLit: meaningLit == null && nullToAbsent
          ? const Value.absent()
          : Value(meaningLit),
      meaning2: meaning2 == null && nullToAbsent
          ? const Value.absent()
          : Value(meaning2),
      source1: source1 == null && nullToAbsent
          ? const Value.absent()
          : Value(source1),
      sutta1: sutta1 == null && nullToAbsent
          ? const Value.absent()
          : Value(sutta1),
      example1: example1 == null && nullToAbsent
          ? const Value.absent()
          : Value(example1),
      source2: source2 == null && nullToAbsent
          ? const Value.absent()
          : Value(source2),
      sutta2: sutta2 == null && nullToAbsent
          ? const Value.absent()
          : Value(sutta2),
      example2: example2 == null && nullToAbsent
          ? const Value.absent()
          : Value(example2),
      rootKey: rootKey == null && nullToAbsent
          ? const Value.absent()
          : Value(rootKey),
      rootSign: rootSign == null && nullToAbsent
          ? const Value.absent()
          : Value(rootSign),
      rootBase: rootBase == null && nullToAbsent
          ? const Value.absent()
          : Value(rootBase),
      familyRoot: familyRoot == null && nullToAbsent
          ? const Value.absent()
          : Value(familyRoot),
      familyWord: familyWord == null && nullToAbsent
          ? const Value.absent()
          : Value(familyWord),
      familyCompound: familyCompound == null && nullToAbsent
          ? const Value.absent()
          : Value(familyCompound),
      familyIdioms: familyIdioms == null && nullToAbsent
          ? const Value.absent()
          : Value(familyIdioms),
      construction: construction == null && nullToAbsent
          ? const Value.absent()
          : Value(construction),
      compoundType: compoundType == null && nullToAbsent
          ? const Value.absent()
          : Value(compoundType),
      antonym: antonym == null && nullToAbsent
          ? const Value.absent()
          : Value(antonym),
      synonym: synonym == null && nullToAbsent
          ? const Value.absent()
          : Value(synonym),
      variant: variant == null && nullToAbsent
          ? const Value.absent()
          : Value(variant),
      stem: stem == null && nullToAbsent ? const Value.absent() : Value(stem),
      pattern: pattern == null && nullToAbsent
          ? const Value.absent()
          : Value(pattern),
      suffix: suffix == null && nullToAbsent
          ? const Value.absent()
          : Value(suffix),
      freqData: freqData == null && nullToAbsent
          ? const Value.absent()
          : Value(freqData),
      lemmaIpa: lemmaIpa == null && nullToAbsent
          ? const Value.absent()
          : Value(lemmaIpa),
      ebtCount: ebtCount == null && nullToAbsent
          ? const Value.absent()
          : Value(ebtCount),
      nonIa: nonIa == null && nullToAbsent
          ? const Value.absent()
          : Value(nonIa),
      sanskrit: sanskrit == null && nullToAbsent
          ? const Value.absent()
          : Value(sanskrit),
      cognate: cognate == null && nullToAbsent
          ? const Value.absent()
          : Value(cognate),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      phonetic: phonetic == null && nullToAbsent
          ? const Value.absent()
          : Value(phonetic),
      varPhonetic: varPhonetic == null && nullToAbsent
          ? const Value.absent()
          : Value(varPhonetic),
      varText: varText == null && nullToAbsent
          ? const Value.absent()
          : Value(varText),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      commentary: commentary == null && nullToAbsent
          ? const Value.absent()
          : Value(commentary),
    );
  }

  factory DpdHeadword.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DpdHeadword(
      id: serializer.fromJson<int>(json['id']),
      lemma1: serializer.fromJson<String>(json['lemma1']),
      lemma2: serializer.fromJson<String?>(json['lemma2']),
      pos: serializer.fromJson<String?>(json['pos']),
      grammar: serializer.fromJson<String?>(json['grammar']),
      derivedFrom: serializer.fromJson<String?>(json['derivedFrom']),
      neg: serializer.fromJson<String?>(json['neg']),
      verb: serializer.fromJson<String?>(json['verb']),
      trans: serializer.fromJson<String?>(json['trans']),
      plusCase: serializer.fromJson<String?>(json['plusCase']),
      meaning1: serializer.fromJson<String?>(json['meaning1']),
      meaningLit: serializer.fromJson<String?>(json['meaningLit']),
      meaning2: serializer.fromJson<String?>(json['meaning2']),
      source1: serializer.fromJson<String?>(json['source1']),
      sutta1: serializer.fromJson<String?>(json['sutta1']),
      example1: serializer.fromJson<String?>(json['example1']),
      source2: serializer.fromJson<String?>(json['source2']),
      sutta2: serializer.fromJson<String?>(json['sutta2']),
      example2: serializer.fromJson<String?>(json['example2']),
      rootKey: serializer.fromJson<String?>(json['rootKey']),
      rootSign: serializer.fromJson<String?>(json['rootSign']),
      rootBase: serializer.fromJson<String?>(json['rootBase']),
      familyRoot: serializer.fromJson<String?>(json['familyRoot']),
      familyWord: serializer.fromJson<String?>(json['familyWord']),
      familyCompound: serializer.fromJson<String?>(json['familyCompound']),
      familyIdioms: serializer.fromJson<String?>(json['familyIdioms']),
      construction: serializer.fromJson<String?>(json['construction']),
      compoundType: serializer.fromJson<String?>(json['compoundType']),
      antonym: serializer.fromJson<String?>(json['antonym']),
      synonym: serializer.fromJson<String?>(json['synonym']),
      variant: serializer.fromJson<String?>(json['variant']),
      stem: serializer.fromJson<String?>(json['stem']),
      pattern: serializer.fromJson<String?>(json['pattern']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      freqData: serializer.fromJson<String?>(json['freqData']),
      lemmaIpa: serializer.fromJson<String?>(json['lemmaIpa']),
      ebtCount: serializer.fromJson<int?>(json['ebtCount']),
      nonIa: serializer.fromJson<String?>(json['nonIa']),
      sanskrit: serializer.fromJson<String?>(json['sanskrit']),
      cognate: serializer.fromJson<String?>(json['cognate']),
      link: serializer.fromJson<String?>(json['link']),
      phonetic: serializer.fromJson<String?>(json['phonetic']),
      varPhonetic: serializer.fromJson<String?>(json['varPhonetic']),
      varText: serializer.fromJson<String?>(json['varText']),
      origin: serializer.fromJson<String?>(json['origin']),
      notes: serializer.fromJson<String?>(json['notes']),
      commentary: serializer.fromJson<String?>(json['commentary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lemma1': serializer.toJson<String>(lemma1),
      'lemma2': serializer.toJson<String?>(lemma2),
      'pos': serializer.toJson<String?>(pos),
      'grammar': serializer.toJson<String?>(grammar),
      'derivedFrom': serializer.toJson<String?>(derivedFrom),
      'neg': serializer.toJson<String?>(neg),
      'verb': serializer.toJson<String?>(verb),
      'trans': serializer.toJson<String?>(trans),
      'plusCase': serializer.toJson<String?>(plusCase),
      'meaning1': serializer.toJson<String?>(meaning1),
      'meaningLit': serializer.toJson<String?>(meaningLit),
      'meaning2': serializer.toJson<String?>(meaning2),
      'source1': serializer.toJson<String?>(source1),
      'sutta1': serializer.toJson<String?>(sutta1),
      'example1': serializer.toJson<String?>(example1),
      'source2': serializer.toJson<String?>(source2),
      'sutta2': serializer.toJson<String?>(sutta2),
      'example2': serializer.toJson<String?>(example2),
      'rootKey': serializer.toJson<String?>(rootKey),
      'rootSign': serializer.toJson<String?>(rootSign),
      'rootBase': serializer.toJson<String?>(rootBase),
      'familyRoot': serializer.toJson<String?>(familyRoot),
      'familyWord': serializer.toJson<String?>(familyWord),
      'familyCompound': serializer.toJson<String?>(familyCompound),
      'familyIdioms': serializer.toJson<String?>(familyIdioms),
      'construction': serializer.toJson<String?>(construction),
      'compoundType': serializer.toJson<String?>(compoundType),
      'antonym': serializer.toJson<String?>(antonym),
      'synonym': serializer.toJson<String?>(synonym),
      'variant': serializer.toJson<String?>(variant),
      'stem': serializer.toJson<String?>(stem),
      'pattern': serializer.toJson<String?>(pattern),
      'suffix': serializer.toJson<String?>(suffix),
      'freqData': serializer.toJson<String?>(freqData),
      'lemmaIpa': serializer.toJson<String?>(lemmaIpa),
      'ebtCount': serializer.toJson<int?>(ebtCount),
      'nonIa': serializer.toJson<String?>(nonIa),
      'sanskrit': serializer.toJson<String?>(sanskrit),
      'cognate': serializer.toJson<String?>(cognate),
      'link': serializer.toJson<String?>(link),
      'phonetic': serializer.toJson<String?>(phonetic),
      'varPhonetic': serializer.toJson<String?>(varPhonetic),
      'varText': serializer.toJson<String?>(varText),
      'origin': serializer.toJson<String?>(origin),
      'notes': serializer.toJson<String?>(notes),
      'commentary': serializer.toJson<String?>(commentary),
    };
  }

  DpdHeadword copyWith({
    int? id,
    String? lemma1,
    Value<String?> lemma2 = const Value.absent(),
    Value<String?> pos = const Value.absent(),
    Value<String?> grammar = const Value.absent(),
    Value<String?> derivedFrom = const Value.absent(),
    Value<String?> neg = const Value.absent(),
    Value<String?> verb = const Value.absent(),
    Value<String?> trans = const Value.absent(),
    Value<String?> plusCase = const Value.absent(),
    Value<String?> meaning1 = const Value.absent(),
    Value<String?> meaningLit = const Value.absent(),
    Value<String?> meaning2 = const Value.absent(),
    Value<String?> source1 = const Value.absent(),
    Value<String?> sutta1 = const Value.absent(),
    Value<String?> example1 = const Value.absent(),
    Value<String?> source2 = const Value.absent(),
    Value<String?> sutta2 = const Value.absent(),
    Value<String?> example2 = const Value.absent(),
    Value<String?> rootKey = const Value.absent(),
    Value<String?> rootSign = const Value.absent(),
    Value<String?> rootBase = const Value.absent(),
    Value<String?> familyRoot = const Value.absent(),
    Value<String?> familyWord = const Value.absent(),
    Value<String?> familyCompound = const Value.absent(),
    Value<String?> familyIdioms = const Value.absent(),
    Value<String?> construction = const Value.absent(),
    Value<String?> compoundType = const Value.absent(),
    Value<String?> antonym = const Value.absent(),
    Value<String?> synonym = const Value.absent(),
    Value<String?> variant = const Value.absent(),
    Value<String?> stem = const Value.absent(),
    Value<String?> pattern = const Value.absent(),
    Value<String?> suffix = const Value.absent(),
    Value<String?> freqData = const Value.absent(),
    Value<String?> lemmaIpa = const Value.absent(),
    Value<int?> ebtCount = const Value.absent(),
    Value<String?> nonIa = const Value.absent(),
    Value<String?> sanskrit = const Value.absent(),
    Value<String?> cognate = const Value.absent(),
    Value<String?> link = const Value.absent(),
    Value<String?> phonetic = const Value.absent(),
    Value<String?> varPhonetic = const Value.absent(),
    Value<String?> varText = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> commentary = const Value.absent(),
  }) => DpdHeadword(
    id: id ?? this.id,
    lemma1: lemma1 ?? this.lemma1,
    lemma2: lemma2.present ? lemma2.value : this.lemma2,
    pos: pos.present ? pos.value : this.pos,
    grammar: grammar.present ? grammar.value : this.grammar,
    derivedFrom: derivedFrom.present ? derivedFrom.value : this.derivedFrom,
    neg: neg.present ? neg.value : this.neg,
    verb: verb.present ? verb.value : this.verb,
    trans: trans.present ? trans.value : this.trans,
    plusCase: plusCase.present ? plusCase.value : this.plusCase,
    meaning1: meaning1.present ? meaning1.value : this.meaning1,
    meaningLit: meaningLit.present ? meaningLit.value : this.meaningLit,
    meaning2: meaning2.present ? meaning2.value : this.meaning2,
    source1: source1.present ? source1.value : this.source1,
    sutta1: sutta1.present ? sutta1.value : this.sutta1,
    example1: example1.present ? example1.value : this.example1,
    source2: source2.present ? source2.value : this.source2,
    sutta2: sutta2.present ? sutta2.value : this.sutta2,
    example2: example2.present ? example2.value : this.example2,
    rootKey: rootKey.present ? rootKey.value : this.rootKey,
    rootSign: rootSign.present ? rootSign.value : this.rootSign,
    rootBase: rootBase.present ? rootBase.value : this.rootBase,
    familyRoot: familyRoot.present ? familyRoot.value : this.familyRoot,
    familyWord: familyWord.present ? familyWord.value : this.familyWord,
    familyCompound: familyCompound.present
        ? familyCompound.value
        : this.familyCompound,
    familyIdioms: familyIdioms.present ? familyIdioms.value : this.familyIdioms,
    construction: construction.present ? construction.value : this.construction,
    compoundType: compoundType.present ? compoundType.value : this.compoundType,
    antonym: antonym.present ? antonym.value : this.antonym,
    synonym: synonym.present ? synonym.value : this.synonym,
    variant: variant.present ? variant.value : this.variant,
    stem: stem.present ? stem.value : this.stem,
    pattern: pattern.present ? pattern.value : this.pattern,
    suffix: suffix.present ? suffix.value : this.suffix,
    freqData: freqData.present ? freqData.value : this.freqData,
    lemmaIpa: lemmaIpa.present ? lemmaIpa.value : this.lemmaIpa,
    ebtCount: ebtCount.present ? ebtCount.value : this.ebtCount,
    nonIa: nonIa.present ? nonIa.value : this.nonIa,
    sanskrit: sanskrit.present ? sanskrit.value : this.sanskrit,
    cognate: cognate.present ? cognate.value : this.cognate,
    link: link.present ? link.value : this.link,
    phonetic: phonetic.present ? phonetic.value : this.phonetic,
    varPhonetic: varPhonetic.present ? varPhonetic.value : this.varPhonetic,
    varText: varText.present ? varText.value : this.varText,
    origin: origin.present ? origin.value : this.origin,
    notes: notes.present ? notes.value : this.notes,
    commentary: commentary.present ? commentary.value : this.commentary,
  );
  DpdHeadword copyWithCompanion(DpdHeadwordsCompanion data) {
    return DpdHeadword(
      id: data.id.present ? data.id.value : this.id,
      lemma1: data.lemma1.present ? data.lemma1.value : this.lemma1,
      lemma2: data.lemma2.present ? data.lemma2.value : this.lemma2,
      pos: data.pos.present ? data.pos.value : this.pos,
      grammar: data.grammar.present ? data.grammar.value : this.grammar,
      derivedFrom: data.derivedFrom.present
          ? data.derivedFrom.value
          : this.derivedFrom,
      neg: data.neg.present ? data.neg.value : this.neg,
      verb: data.verb.present ? data.verb.value : this.verb,
      trans: data.trans.present ? data.trans.value : this.trans,
      plusCase: data.plusCase.present ? data.plusCase.value : this.plusCase,
      meaning1: data.meaning1.present ? data.meaning1.value : this.meaning1,
      meaningLit: data.meaningLit.present
          ? data.meaningLit.value
          : this.meaningLit,
      meaning2: data.meaning2.present ? data.meaning2.value : this.meaning2,
      source1: data.source1.present ? data.source1.value : this.source1,
      sutta1: data.sutta1.present ? data.sutta1.value : this.sutta1,
      example1: data.example1.present ? data.example1.value : this.example1,
      source2: data.source2.present ? data.source2.value : this.source2,
      sutta2: data.sutta2.present ? data.sutta2.value : this.sutta2,
      example2: data.example2.present ? data.example2.value : this.example2,
      rootKey: data.rootKey.present ? data.rootKey.value : this.rootKey,
      rootSign: data.rootSign.present ? data.rootSign.value : this.rootSign,
      rootBase: data.rootBase.present ? data.rootBase.value : this.rootBase,
      familyRoot: data.familyRoot.present
          ? data.familyRoot.value
          : this.familyRoot,
      familyWord: data.familyWord.present
          ? data.familyWord.value
          : this.familyWord,
      familyCompound: data.familyCompound.present
          ? data.familyCompound.value
          : this.familyCompound,
      familyIdioms: data.familyIdioms.present
          ? data.familyIdioms.value
          : this.familyIdioms,
      construction: data.construction.present
          ? data.construction.value
          : this.construction,
      compoundType: data.compoundType.present
          ? data.compoundType.value
          : this.compoundType,
      antonym: data.antonym.present ? data.antonym.value : this.antonym,
      synonym: data.synonym.present ? data.synonym.value : this.synonym,
      variant: data.variant.present ? data.variant.value : this.variant,
      stem: data.stem.present ? data.stem.value : this.stem,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      freqData: data.freqData.present ? data.freqData.value : this.freqData,
      lemmaIpa: data.lemmaIpa.present ? data.lemmaIpa.value : this.lemmaIpa,
      ebtCount: data.ebtCount.present ? data.ebtCount.value : this.ebtCount,
      nonIa: data.nonIa.present ? data.nonIa.value : this.nonIa,
      sanskrit: data.sanskrit.present ? data.sanskrit.value : this.sanskrit,
      cognate: data.cognate.present ? data.cognate.value : this.cognate,
      link: data.link.present ? data.link.value : this.link,
      phonetic: data.phonetic.present ? data.phonetic.value : this.phonetic,
      varPhonetic: data.varPhonetic.present
          ? data.varPhonetic.value
          : this.varPhonetic,
      varText: data.varText.present ? data.varText.value : this.varText,
      origin: data.origin.present ? data.origin.value : this.origin,
      notes: data.notes.present ? data.notes.value : this.notes,
      commentary: data.commentary.present
          ? data.commentary.value
          : this.commentary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DpdHeadword(')
          ..write('id: $id, ')
          ..write('lemma1: $lemma1, ')
          ..write('lemma2: $lemma2, ')
          ..write('pos: $pos, ')
          ..write('grammar: $grammar, ')
          ..write('derivedFrom: $derivedFrom, ')
          ..write('neg: $neg, ')
          ..write('verb: $verb, ')
          ..write('trans: $trans, ')
          ..write('plusCase: $plusCase, ')
          ..write('meaning1: $meaning1, ')
          ..write('meaningLit: $meaningLit, ')
          ..write('meaning2: $meaning2, ')
          ..write('source1: $source1, ')
          ..write('sutta1: $sutta1, ')
          ..write('example1: $example1, ')
          ..write('source2: $source2, ')
          ..write('sutta2: $sutta2, ')
          ..write('example2: $example2, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootBase: $rootBase, ')
          ..write('familyRoot: $familyRoot, ')
          ..write('familyWord: $familyWord, ')
          ..write('familyCompound: $familyCompound, ')
          ..write('familyIdioms: $familyIdioms, ')
          ..write('construction: $construction, ')
          ..write('compoundType: $compoundType, ')
          ..write('antonym: $antonym, ')
          ..write('synonym: $synonym, ')
          ..write('variant: $variant, ')
          ..write('stem: $stem, ')
          ..write('pattern: $pattern, ')
          ..write('suffix: $suffix, ')
          ..write('freqData: $freqData, ')
          ..write('lemmaIpa: $lemmaIpa, ')
          ..write('ebtCount: $ebtCount, ')
          ..write('nonIa: $nonIa, ')
          ..write('sanskrit: $sanskrit, ')
          ..write('cognate: $cognate, ')
          ..write('link: $link, ')
          ..write('phonetic: $phonetic, ')
          ..write('varPhonetic: $varPhonetic, ')
          ..write('varText: $varText, ')
          ..write('origin: $origin, ')
          ..write('notes: $notes, ')
          ..write('commentary: $commentary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    lemma1,
    lemma2,
    pos,
    grammar,
    derivedFrom,
    neg,
    verb,
    trans,
    plusCase,
    meaning1,
    meaningLit,
    meaning2,
    source1,
    sutta1,
    example1,
    source2,
    sutta2,
    example2,
    rootKey,
    rootSign,
    rootBase,
    familyRoot,
    familyWord,
    familyCompound,
    familyIdioms,
    construction,
    compoundType,
    antonym,
    synonym,
    variant,
    stem,
    pattern,
    suffix,
    freqData,
    lemmaIpa,
    ebtCount,
    nonIa,
    sanskrit,
    cognate,
    link,
    phonetic,
    varPhonetic,
    varText,
    origin,
    notes,
    commentary,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DpdHeadword &&
          other.id == this.id &&
          other.lemma1 == this.lemma1 &&
          other.lemma2 == this.lemma2 &&
          other.pos == this.pos &&
          other.grammar == this.grammar &&
          other.derivedFrom == this.derivedFrom &&
          other.neg == this.neg &&
          other.verb == this.verb &&
          other.trans == this.trans &&
          other.plusCase == this.plusCase &&
          other.meaning1 == this.meaning1 &&
          other.meaningLit == this.meaningLit &&
          other.meaning2 == this.meaning2 &&
          other.source1 == this.source1 &&
          other.sutta1 == this.sutta1 &&
          other.example1 == this.example1 &&
          other.source2 == this.source2 &&
          other.sutta2 == this.sutta2 &&
          other.example2 == this.example2 &&
          other.rootKey == this.rootKey &&
          other.rootSign == this.rootSign &&
          other.rootBase == this.rootBase &&
          other.familyRoot == this.familyRoot &&
          other.familyWord == this.familyWord &&
          other.familyCompound == this.familyCompound &&
          other.familyIdioms == this.familyIdioms &&
          other.construction == this.construction &&
          other.compoundType == this.compoundType &&
          other.antonym == this.antonym &&
          other.synonym == this.synonym &&
          other.variant == this.variant &&
          other.stem == this.stem &&
          other.pattern == this.pattern &&
          other.suffix == this.suffix &&
          other.freqData == this.freqData &&
          other.lemmaIpa == this.lemmaIpa &&
          other.ebtCount == this.ebtCount &&
          other.nonIa == this.nonIa &&
          other.sanskrit == this.sanskrit &&
          other.cognate == this.cognate &&
          other.link == this.link &&
          other.phonetic == this.phonetic &&
          other.varPhonetic == this.varPhonetic &&
          other.varText == this.varText &&
          other.origin == this.origin &&
          other.notes == this.notes &&
          other.commentary == this.commentary);
}

class DpdHeadwordsCompanion extends UpdateCompanion<DpdHeadword> {
  final Value<int> id;
  final Value<String> lemma1;
  final Value<String?> lemma2;
  final Value<String?> pos;
  final Value<String?> grammar;
  final Value<String?> derivedFrom;
  final Value<String?> neg;
  final Value<String?> verb;
  final Value<String?> trans;
  final Value<String?> plusCase;
  final Value<String?> meaning1;
  final Value<String?> meaningLit;
  final Value<String?> meaning2;
  final Value<String?> source1;
  final Value<String?> sutta1;
  final Value<String?> example1;
  final Value<String?> source2;
  final Value<String?> sutta2;
  final Value<String?> example2;
  final Value<String?> rootKey;
  final Value<String?> rootSign;
  final Value<String?> rootBase;
  final Value<String?> familyRoot;
  final Value<String?> familyWord;
  final Value<String?> familyCompound;
  final Value<String?> familyIdioms;
  final Value<String?> construction;
  final Value<String?> compoundType;
  final Value<String?> antonym;
  final Value<String?> synonym;
  final Value<String?> variant;
  final Value<String?> stem;
  final Value<String?> pattern;
  final Value<String?> suffix;
  final Value<String?> freqData;
  final Value<String?> lemmaIpa;
  final Value<int?> ebtCount;
  final Value<String?> nonIa;
  final Value<String?> sanskrit;
  final Value<String?> cognate;
  final Value<String?> link;
  final Value<String?> phonetic;
  final Value<String?> varPhonetic;
  final Value<String?> varText;
  final Value<String?> origin;
  final Value<String?> notes;
  final Value<String?> commentary;
  const DpdHeadwordsCompanion({
    this.id = const Value.absent(),
    this.lemma1 = const Value.absent(),
    this.lemma2 = const Value.absent(),
    this.pos = const Value.absent(),
    this.grammar = const Value.absent(),
    this.derivedFrom = const Value.absent(),
    this.neg = const Value.absent(),
    this.verb = const Value.absent(),
    this.trans = const Value.absent(),
    this.plusCase = const Value.absent(),
    this.meaning1 = const Value.absent(),
    this.meaningLit = const Value.absent(),
    this.meaning2 = const Value.absent(),
    this.source1 = const Value.absent(),
    this.sutta1 = const Value.absent(),
    this.example1 = const Value.absent(),
    this.source2 = const Value.absent(),
    this.sutta2 = const Value.absent(),
    this.example2 = const Value.absent(),
    this.rootKey = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootBase = const Value.absent(),
    this.familyRoot = const Value.absent(),
    this.familyWord = const Value.absent(),
    this.familyCompound = const Value.absent(),
    this.familyIdioms = const Value.absent(),
    this.construction = const Value.absent(),
    this.compoundType = const Value.absent(),
    this.antonym = const Value.absent(),
    this.synonym = const Value.absent(),
    this.variant = const Value.absent(),
    this.stem = const Value.absent(),
    this.pattern = const Value.absent(),
    this.suffix = const Value.absent(),
    this.freqData = const Value.absent(),
    this.lemmaIpa = const Value.absent(),
    this.ebtCount = const Value.absent(),
    this.nonIa = const Value.absent(),
    this.sanskrit = const Value.absent(),
    this.cognate = const Value.absent(),
    this.link = const Value.absent(),
    this.phonetic = const Value.absent(),
    this.varPhonetic = const Value.absent(),
    this.varText = const Value.absent(),
    this.origin = const Value.absent(),
    this.notes = const Value.absent(),
    this.commentary = const Value.absent(),
  });
  DpdHeadwordsCompanion.insert({
    this.id = const Value.absent(),
    required String lemma1,
    this.lemma2 = const Value.absent(),
    this.pos = const Value.absent(),
    this.grammar = const Value.absent(),
    this.derivedFrom = const Value.absent(),
    this.neg = const Value.absent(),
    this.verb = const Value.absent(),
    this.trans = const Value.absent(),
    this.plusCase = const Value.absent(),
    this.meaning1 = const Value.absent(),
    this.meaningLit = const Value.absent(),
    this.meaning2 = const Value.absent(),
    this.source1 = const Value.absent(),
    this.sutta1 = const Value.absent(),
    this.example1 = const Value.absent(),
    this.source2 = const Value.absent(),
    this.sutta2 = const Value.absent(),
    this.example2 = const Value.absent(),
    this.rootKey = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootBase = const Value.absent(),
    this.familyRoot = const Value.absent(),
    this.familyWord = const Value.absent(),
    this.familyCompound = const Value.absent(),
    this.familyIdioms = const Value.absent(),
    this.construction = const Value.absent(),
    this.compoundType = const Value.absent(),
    this.antonym = const Value.absent(),
    this.synonym = const Value.absent(),
    this.variant = const Value.absent(),
    this.stem = const Value.absent(),
    this.pattern = const Value.absent(),
    this.suffix = const Value.absent(),
    this.freqData = const Value.absent(),
    this.lemmaIpa = const Value.absent(),
    this.ebtCount = const Value.absent(),
    this.nonIa = const Value.absent(),
    this.sanskrit = const Value.absent(),
    this.cognate = const Value.absent(),
    this.link = const Value.absent(),
    this.phonetic = const Value.absent(),
    this.varPhonetic = const Value.absent(),
    this.varText = const Value.absent(),
    this.origin = const Value.absent(),
    this.notes = const Value.absent(),
    this.commentary = const Value.absent(),
  }) : lemma1 = Value(lemma1);
  static Insertable<DpdHeadword> custom({
    Expression<int>? id,
    Expression<String>? lemma1,
    Expression<String>? lemma2,
    Expression<String>? pos,
    Expression<String>? grammar,
    Expression<String>? derivedFrom,
    Expression<String>? neg,
    Expression<String>? verb,
    Expression<String>? trans,
    Expression<String>? plusCase,
    Expression<String>? meaning1,
    Expression<String>? meaningLit,
    Expression<String>? meaning2,
    Expression<String>? source1,
    Expression<String>? sutta1,
    Expression<String>? example1,
    Expression<String>? source2,
    Expression<String>? sutta2,
    Expression<String>? example2,
    Expression<String>? rootKey,
    Expression<String>? rootSign,
    Expression<String>? rootBase,
    Expression<String>? familyRoot,
    Expression<String>? familyWord,
    Expression<String>? familyCompound,
    Expression<String>? familyIdioms,
    Expression<String>? construction,
    Expression<String>? compoundType,
    Expression<String>? antonym,
    Expression<String>? synonym,
    Expression<String>? variant,
    Expression<String>? stem,
    Expression<String>? pattern,
    Expression<String>? suffix,
    Expression<String>? freqData,
    Expression<String>? lemmaIpa,
    Expression<int>? ebtCount,
    Expression<String>? nonIa,
    Expression<String>? sanskrit,
    Expression<String>? cognate,
    Expression<String>? link,
    Expression<String>? phonetic,
    Expression<String>? varPhonetic,
    Expression<String>? varText,
    Expression<String>? origin,
    Expression<String>? notes,
    Expression<String>? commentary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lemma1 != null) 'lemma_1': lemma1,
      if (lemma2 != null) 'lemma_2': lemma2,
      if (pos != null) 'pos': pos,
      if (grammar != null) 'grammar': grammar,
      if (derivedFrom != null) 'derived_from': derivedFrom,
      if (neg != null) 'neg': neg,
      if (verb != null) 'verb': verb,
      if (trans != null) 'trans': trans,
      if (plusCase != null) 'plus_case': plusCase,
      if (meaning1 != null) 'meaning_1': meaning1,
      if (meaningLit != null) 'meaning_lit': meaningLit,
      if (meaning2 != null) 'meaning_2': meaning2,
      if (source1 != null) 'source_1': source1,
      if (sutta1 != null) 'sutta_1': sutta1,
      if (example1 != null) 'example_1': example1,
      if (source2 != null) 'source_2': source2,
      if (sutta2 != null) 'sutta_2': sutta2,
      if (example2 != null) 'example_2': example2,
      if (rootKey != null) 'root_key': rootKey,
      if (rootSign != null) 'root_sign': rootSign,
      if (rootBase != null) 'root_base': rootBase,
      if (familyRoot != null) 'family_root': familyRoot,
      if (familyWord != null) 'family_word': familyWord,
      if (familyCompound != null) 'family_compound': familyCompound,
      if (familyIdioms != null) 'family_idioms': familyIdioms,
      if (construction != null) 'construction': construction,
      if (compoundType != null) 'compound_type': compoundType,
      if (antonym != null) 'antonym': antonym,
      if (synonym != null) 'synonym': synonym,
      if (variant != null) 'variant': variant,
      if (stem != null) 'stem': stem,
      if (pattern != null) 'pattern': pattern,
      if (suffix != null) 'suffix': suffix,
      if (freqData != null) 'freq_data': freqData,
      if (lemmaIpa != null) 'lemma_ipa': lemmaIpa,
      if (ebtCount != null) 'ebt_count': ebtCount,
      if (nonIa != null) 'non_ia': nonIa,
      if (sanskrit != null) 'sanskrit': sanskrit,
      if (cognate != null) 'cognate': cognate,
      if (link != null) 'link': link,
      if (phonetic != null) 'phonetic': phonetic,
      if (varPhonetic != null) 'var_phonetic': varPhonetic,
      if (varText != null) 'var_text': varText,
      if (origin != null) 'origin': origin,
      if (notes != null) 'notes': notes,
      if (commentary != null) 'commentary': commentary,
    });
  }

  DpdHeadwordsCompanion copyWith({
    Value<int>? id,
    Value<String>? lemma1,
    Value<String?>? lemma2,
    Value<String?>? pos,
    Value<String?>? grammar,
    Value<String?>? derivedFrom,
    Value<String?>? neg,
    Value<String?>? verb,
    Value<String?>? trans,
    Value<String?>? plusCase,
    Value<String?>? meaning1,
    Value<String?>? meaningLit,
    Value<String?>? meaning2,
    Value<String?>? source1,
    Value<String?>? sutta1,
    Value<String?>? example1,
    Value<String?>? source2,
    Value<String?>? sutta2,
    Value<String?>? example2,
    Value<String?>? rootKey,
    Value<String?>? rootSign,
    Value<String?>? rootBase,
    Value<String?>? familyRoot,
    Value<String?>? familyWord,
    Value<String?>? familyCompound,
    Value<String?>? familyIdioms,
    Value<String?>? construction,
    Value<String?>? compoundType,
    Value<String?>? antonym,
    Value<String?>? synonym,
    Value<String?>? variant,
    Value<String?>? stem,
    Value<String?>? pattern,
    Value<String?>? suffix,
    Value<String?>? freqData,
    Value<String?>? lemmaIpa,
    Value<int?>? ebtCount,
    Value<String?>? nonIa,
    Value<String?>? sanskrit,
    Value<String?>? cognate,
    Value<String?>? link,
    Value<String?>? phonetic,
    Value<String?>? varPhonetic,
    Value<String?>? varText,
    Value<String?>? origin,
    Value<String?>? notes,
    Value<String?>? commentary,
  }) {
    return DpdHeadwordsCompanion(
      id: id ?? this.id,
      lemma1: lemma1 ?? this.lemma1,
      lemma2: lemma2 ?? this.lemma2,
      pos: pos ?? this.pos,
      grammar: grammar ?? this.grammar,
      derivedFrom: derivedFrom ?? this.derivedFrom,
      neg: neg ?? this.neg,
      verb: verb ?? this.verb,
      trans: trans ?? this.trans,
      plusCase: plusCase ?? this.plusCase,
      meaning1: meaning1 ?? this.meaning1,
      meaningLit: meaningLit ?? this.meaningLit,
      meaning2: meaning2 ?? this.meaning2,
      source1: source1 ?? this.source1,
      sutta1: sutta1 ?? this.sutta1,
      example1: example1 ?? this.example1,
      source2: source2 ?? this.source2,
      sutta2: sutta2 ?? this.sutta2,
      example2: example2 ?? this.example2,
      rootKey: rootKey ?? this.rootKey,
      rootSign: rootSign ?? this.rootSign,
      rootBase: rootBase ?? this.rootBase,
      familyRoot: familyRoot ?? this.familyRoot,
      familyWord: familyWord ?? this.familyWord,
      familyCompound: familyCompound ?? this.familyCompound,
      familyIdioms: familyIdioms ?? this.familyIdioms,
      construction: construction ?? this.construction,
      compoundType: compoundType ?? this.compoundType,
      antonym: antonym ?? this.antonym,
      synonym: synonym ?? this.synonym,
      variant: variant ?? this.variant,
      stem: stem ?? this.stem,
      pattern: pattern ?? this.pattern,
      suffix: suffix ?? this.suffix,
      freqData: freqData ?? this.freqData,
      lemmaIpa: lemmaIpa ?? this.lemmaIpa,
      ebtCount: ebtCount ?? this.ebtCount,
      nonIa: nonIa ?? this.nonIa,
      sanskrit: sanskrit ?? this.sanskrit,
      cognate: cognate ?? this.cognate,
      link: link ?? this.link,
      phonetic: phonetic ?? this.phonetic,
      varPhonetic: varPhonetic ?? this.varPhonetic,
      varText: varText ?? this.varText,
      origin: origin ?? this.origin,
      notes: notes ?? this.notes,
      commentary: commentary ?? this.commentary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lemma1.present) {
      map['lemma_1'] = Variable<String>(lemma1.value);
    }
    if (lemma2.present) {
      map['lemma_2'] = Variable<String>(lemma2.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (grammar.present) {
      map['grammar'] = Variable<String>(grammar.value);
    }
    if (derivedFrom.present) {
      map['derived_from'] = Variable<String>(derivedFrom.value);
    }
    if (neg.present) {
      map['neg'] = Variable<String>(neg.value);
    }
    if (verb.present) {
      map['verb'] = Variable<String>(verb.value);
    }
    if (trans.present) {
      map['trans'] = Variable<String>(trans.value);
    }
    if (plusCase.present) {
      map['plus_case'] = Variable<String>(plusCase.value);
    }
    if (meaning1.present) {
      map['meaning_1'] = Variable<String>(meaning1.value);
    }
    if (meaningLit.present) {
      map['meaning_lit'] = Variable<String>(meaningLit.value);
    }
    if (meaning2.present) {
      map['meaning_2'] = Variable<String>(meaning2.value);
    }
    if (source1.present) {
      map['source_1'] = Variable<String>(source1.value);
    }
    if (sutta1.present) {
      map['sutta_1'] = Variable<String>(sutta1.value);
    }
    if (example1.present) {
      map['example_1'] = Variable<String>(example1.value);
    }
    if (source2.present) {
      map['source_2'] = Variable<String>(source2.value);
    }
    if (sutta2.present) {
      map['sutta_2'] = Variable<String>(sutta2.value);
    }
    if (example2.present) {
      map['example_2'] = Variable<String>(example2.value);
    }
    if (rootKey.present) {
      map['root_key'] = Variable<String>(rootKey.value);
    }
    if (rootSign.present) {
      map['root_sign'] = Variable<String>(rootSign.value);
    }
    if (rootBase.present) {
      map['root_base'] = Variable<String>(rootBase.value);
    }
    if (familyRoot.present) {
      map['family_root'] = Variable<String>(familyRoot.value);
    }
    if (familyWord.present) {
      map['family_word'] = Variable<String>(familyWord.value);
    }
    if (familyCompound.present) {
      map['family_compound'] = Variable<String>(familyCompound.value);
    }
    if (familyIdioms.present) {
      map['family_idioms'] = Variable<String>(familyIdioms.value);
    }
    if (construction.present) {
      map['construction'] = Variable<String>(construction.value);
    }
    if (compoundType.present) {
      map['compound_type'] = Variable<String>(compoundType.value);
    }
    if (antonym.present) {
      map['antonym'] = Variable<String>(antonym.value);
    }
    if (synonym.present) {
      map['synonym'] = Variable<String>(synonym.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (stem.present) {
      map['stem'] = Variable<String>(stem.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (freqData.present) {
      map['freq_data'] = Variable<String>(freqData.value);
    }
    if (lemmaIpa.present) {
      map['lemma_ipa'] = Variable<String>(lemmaIpa.value);
    }
    if (ebtCount.present) {
      map['ebt_count'] = Variable<int>(ebtCount.value);
    }
    if (nonIa.present) {
      map['non_ia'] = Variable<String>(nonIa.value);
    }
    if (sanskrit.present) {
      map['sanskrit'] = Variable<String>(sanskrit.value);
    }
    if (cognate.present) {
      map['cognate'] = Variable<String>(cognate.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (phonetic.present) {
      map['phonetic'] = Variable<String>(phonetic.value);
    }
    if (varPhonetic.present) {
      map['var_phonetic'] = Variable<String>(varPhonetic.value);
    }
    if (varText.present) {
      map['var_text'] = Variable<String>(varText.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (commentary.present) {
      map['commentary'] = Variable<String>(commentary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DpdHeadwordsCompanion(')
          ..write('id: $id, ')
          ..write('lemma1: $lemma1, ')
          ..write('lemma2: $lemma2, ')
          ..write('pos: $pos, ')
          ..write('grammar: $grammar, ')
          ..write('derivedFrom: $derivedFrom, ')
          ..write('neg: $neg, ')
          ..write('verb: $verb, ')
          ..write('trans: $trans, ')
          ..write('plusCase: $plusCase, ')
          ..write('meaning1: $meaning1, ')
          ..write('meaningLit: $meaningLit, ')
          ..write('meaning2: $meaning2, ')
          ..write('source1: $source1, ')
          ..write('sutta1: $sutta1, ')
          ..write('example1: $example1, ')
          ..write('source2: $source2, ')
          ..write('sutta2: $sutta2, ')
          ..write('example2: $example2, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootBase: $rootBase, ')
          ..write('familyRoot: $familyRoot, ')
          ..write('familyWord: $familyWord, ')
          ..write('familyCompound: $familyCompound, ')
          ..write('familyIdioms: $familyIdioms, ')
          ..write('construction: $construction, ')
          ..write('compoundType: $compoundType, ')
          ..write('antonym: $antonym, ')
          ..write('synonym: $synonym, ')
          ..write('variant: $variant, ')
          ..write('stem: $stem, ')
          ..write('pattern: $pattern, ')
          ..write('suffix: $suffix, ')
          ..write('freqData: $freqData, ')
          ..write('lemmaIpa: $lemmaIpa, ')
          ..write('ebtCount: $ebtCount, ')
          ..write('nonIa: $nonIa, ')
          ..write('sanskrit: $sanskrit, ')
          ..write('cognate: $cognate, ')
          ..write('link: $link, ')
          ..write('phonetic: $phonetic, ')
          ..write('varPhonetic: $varPhonetic, ')
          ..write('varText: $varText, ')
          ..write('origin: $origin, ')
          ..write('notes: $notes, ')
          ..write('commentary: $commentary')
          ..write(')'))
        .toString();
  }
}

class $DpdRootsTable extends DpdRoots with TableInfo<$DpdRootsTable, DpdRoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DpdRootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rootMeta = const VerificationMeta('root');
  @override
  late final GeneratedColumn<String> root = GeneratedColumn<String>(
    'root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootInCompsMeta = const VerificationMeta(
    'rootInComps',
  );
  @override
  late final GeneratedColumn<String> rootInComps = GeneratedColumn<String>(
    'root_in_comps',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootHasVerbMeta = const VerificationMeta(
    'rootHasVerb',
  );
  @override
  late final GeneratedColumn<String> rootHasVerb = GeneratedColumn<String>(
    'root_has_verb',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootGroupMeta = const VerificationMeta(
    'rootGroup',
  );
  @override
  late final GeneratedColumn<String> rootGroup = GeneratedColumn<String>(
    'root_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootSignMeta = const VerificationMeta(
    'rootSign',
  );
  @override
  late final GeneratedColumn<String> rootSign = GeneratedColumn<String>(
    'root_sign',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootMeaningMeta = const VerificationMeta(
    'rootMeaning',
  );
  @override
  late final GeneratedColumn<String> rootMeaning = GeneratedColumn<String>(
    'root_meaning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sanskritRootMeta = const VerificationMeta(
    'sanskritRoot',
  );
  @override
  late final GeneratedColumn<String> sanskritRoot = GeneratedColumn<String>(
    'sanskrit_root',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sanskritRootMeaningMeta =
      const VerificationMeta('sanskritRootMeaning');
  @override
  late final GeneratedColumn<String> sanskritRootMeaning =
      GeneratedColumn<String>(
        'sanskrit_root_meaning',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sanskritRootClassMeta = const VerificationMeta(
    'sanskritRootClass',
  );
  @override
  late final GeneratedColumn<String> sanskritRootClass =
      GeneratedColumn<String>(
        'sanskrit_root_class',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rootExampleMeta = const VerificationMeta(
    'rootExample',
  );
  @override
  late final GeneratedColumn<String> rootExample = GeneratedColumn<String>(
    'root_example',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _rootCountMeta = const VerificationMeta(
    'rootCount',
  );
  @override
  late final GeneratedColumn<int> rootCount = GeneratedColumn<int>(
    'root_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    root,
    rootInComps,
    rootHasVerb,
    rootGroup,
    rootSign,
    rootMeaning,
    sanskritRoot,
    sanskritRootMeaning,
    sanskritRootClass,
    rootExample,
    note,
    rootCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dpd_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DpdRoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('root')) {
      context.handle(
        _rootMeta,
        root.isAcceptableOrUnknown(data['root']!, _rootMeta),
      );
    } else if (isInserting) {
      context.missing(_rootMeta);
    }
    if (data.containsKey('root_in_comps')) {
      context.handle(
        _rootInCompsMeta,
        rootInComps.isAcceptableOrUnknown(
          data['root_in_comps']!,
          _rootInCompsMeta,
        ),
      );
    }
    if (data.containsKey('root_has_verb')) {
      context.handle(
        _rootHasVerbMeta,
        rootHasVerb.isAcceptableOrUnknown(
          data['root_has_verb']!,
          _rootHasVerbMeta,
        ),
      );
    }
    if (data.containsKey('root_group')) {
      context.handle(
        _rootGroupMeta,
        rootGroup.isAcceptableOrUnknown(data['root_group']!, _rootGroupMeta),
      );
    }
    if (data.containsKey('root_sign')) {
      context.handle(
        _rootSignMeta,
        rootSign.isAcceptableOrUnknown(data['root_sign']!, _rootSignMeta),
      );
    }
    if (data.containsKey('root_meaning')) {
      context.handle(
        _rootMeaningMeta,
        rootMeaning.isAcceptableOrUnknown(
          data['root_meaning']!,
          _rootMeaningMeta,
        ),
      );
    }
    if (data.containsKey('sanskrit_root')) {
      context.handle(
        _sanskritRootMeta,
        sanskritRoot.isAcceptableOrUnknown(
          data['sanskrit_root']!,
          _sanskritRootMeta,
        ),
      );
    }
    if (data.containsKey('sanskrit_root_meaning')) {
      context.handle(
        _sanskritRootMeaningMeta,
        sanskritRootMeaning.isAcceptableOrUnknown(
          data['sanskrit_root_meaning']!,
          _sanskritRootMeaningMeta,
        ),
      );
    }
    if (data.containsKey('sanskrit_root_class')) {
      context.handle(
        _sanskritRootClassMeta,
        sanskritRootClass.isAcceptableOrUnknown(
          data['sanskrit_root_class']!,
          _sanskritRootClassMeta,
        ),
      );
    }
    if (data.containsKey('root_example')) {
      context.handle(
        _rootExampleMeta,
        rootExample.isAcceptableOrUnknown(
          data['root_example']!,
          _rootExampleMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('root_count')) {
      context.handle(
        _rootCountMeta,
        rootCount.isAcceptableOrUnknown(data['root_count']!, _rootCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {root};
  @override
  DpdRoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DpdRoot(
      root: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root'],
      )!,
      rootInComps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_in_comps'],
      ),
      rootHasVerb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_has_verb'],
      ),
      rootGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_group'],
      ),
      rootSign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_sign'],
      ),
      rootMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_meaning'],
      ),
      sanskritRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root'],
      ),
      sanskritRootMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root_meaning'],
      ),
      sanskritRootClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root_class'],
      ),
      rootExample: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_example'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      rootCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}root_count'],
      ),
    );
  }

  @override
  $DpdRootsTable createAlias(String alias) {
    return $DpdRootsTable(attachedDatabase, alias);
  }
}

class DpdRoot extends DataClass implements Insertable<DpdRoot> {
  final String root;
  final String? rootInComps;
  final String? rootHasVerb;
  final String? rootGroup;
  final String? rootSign;
  final String? rootMeaning;
  final String? sanskritRoot;
  final String? sanskritRootMeaning;
  final String? sanskritRootClass;
  final String? rootExample;
  final String? note;
  final int? rootCount;
  const DpdRoot({
    required this.root,
    this.rootInComps,
    this.rootHasVerb,
    this.rootGroup,
    this.rootSign,
    this.rootMeaning,
    this.sanskritRoot,
    this.sanskritRootMeaning,
    this.sanskritRootClass,
    this.rootExample,
    this.note,
    this.rootCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['root'] = Variable<String>(root);
    if (!nullToAbsent || rootInComps != null) {
      map['root_in_comps'] = Variable<String>(rootInComps);
    }
    if (!nullToAbsent || rootHasVerb != null) {
      map['root_has_verb'] = Variable<String>(rootHasVerb);
    }
    if (!nullToAbsent || rootGroup != null) {
      map['root_group'] = Variable<String>(rootGroup);
    }
    if (!nullToAbsent || rootSign != null) {
      map['root_sign'] = Variable<String>(rootSign);
    }
    if (!nullToAbsent || rootMeaning != null) {
      map['root_meaning'] = Variable<String>(rootMeaning);
    }
    if (!nullToAbsent || sanskritRoot != null) {
      map['sanskrit_root'] = Variable<String>(sanskritRoot);
    }
    if (!nullToAbsent || sanskritRootMeaning != null) {
      map['sanskrit_root_meaning'] = Variable<String>(sanskritRootMeaning);
    }
    if (!nullToAbsent || sanskritRootClass != null) {
      map['sanskrit_root_class'] = Variable<String>(sanskritRootClass);
    }
    if (!nullToAbsent || rootExample != null) {
      map['root_example'] = Variable<String>(rootExample);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || rootCount != null) {
      map['root_count'] = Variable<int>(rootCount);
    }
    return map;
  }

  DpdRootsCompanion toCompanion(bool nullToAbsent) {
    return DpdRootsCompanion(
      root: Value(root),
      rootInComps: rootInComps == null && nullToAbsent
          ? const Value.absent()
          : Value(rootInComps),
      rootHasVerb: rootHasVerb == null && nullToAbsent
          ? const Value.absent()
          : Value(rootHasVerb),
      rootGroup: rootGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(rootGroup),
      rootSign: rootSign == null && nullToAbsent
          ? const Value.absent()
          : Value(rootSign),
      rootMeaning: rootMeaning == null && nullToAbsent
          ? const Value.absent()
          : Value(rootMeaning),
      sanskritRoot: sanskritRoot == null && nullToAbsent
          ? const Value.absent()
          : Value(sanskritRoot),
      sanskritRootMeaning: sanskritRootMeaning == null && nullToAbsent
          ? const Value.absent()
          : Value(sanskritRootMeaning),
      sanskritRootClass: sanskritRootClass == null && nullToAbsent
          ? const Value.absent()
          : Value(sanskritRootClass),
      rootExample: rootExample == null && nullToAbsent
          ? const Value.absent()
          : Value(rootExample),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      rootCount: rootCount == null && nullToAbsent
          ? const Value.absent()
          : Value(rootCount),
    );
  }

  factory DpdRoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DpdRoot(
      root: serializer.fromJson<String>(json['root']),
      rootInComps: serializer.fromJson<String?>(json['rootInComps']),
      rootHasVerb: serializer.fromJson<String?>(json['rootHasVerb']),
      rootGroup: serializer.fromJson<String?>(json['rootGroup']),
      rootSign: serializer.fromJson<String?>(json['rootSign']),
      rootMeaning: serializer.fromJson<String?>(json['rootMeaning']),
      sanskritRoot: serializer.fromJson<String?>(json['sanskritRoot']),
      sanskritRootMeaning: serializer.fromJson<String?>(
        json['sanskritRootMeaning'],
      ),
      sanskritRootClass: serializer.fromJson<String?>(
        json['sanskritRootClass'],
      ),
      rootExample: serializer.fromJson<String?>(json['rootExample']),
      note: serializer.fromJson<String?>(json['note']),
      rootCount: serializer.fromJson<int?>(json['rootCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'root': serializer.toJson<String>(root),
      'rootInComps': serializer.toJson<String?>(rootInComps),
      'rootHasVerb': serializer.toJson<String?>(rootHasVerb),
      'rootGroup': serializer.toJson<String?>(rootGroup),
      'rootSign': serializer.toJson<String?>(rootSign),
      'rootMeaning': serializer.toJson<String?>(rootMeaning),
      'sanskritRoot': serializer.toJson<String?>(sanskritRoot),
      'sanskritRootMeaning': serializer.toJson<String?>(sanskritRootMeaning),
      'sanskritRootClass': serializer.toJson<String?>(sanskritRootClass),
      'rootExample': serializer.toJson<String?>(rootExample),
      'note': serializer.toJson<String?>(note),
      'rootCount': serializer.toJson<int?>(rootCount),
    };
  }

  DpdRoot copyWith({
    String? root,
    Value<String?> rootInComps = const Value.absent(),
    Value<String?> rootHasVerb = const Value.absent(),
    Value<String?> rootGroup = const Value.absent(),
    Value<String?> rootSign = const Value.absent(),
    Value<String?> rootMeaning = const Value.absent(),
    Value<String?> sanskritRoot = const Value.absent(),
    Value<String?> sanskritRootMeaning = const Value.absent(),
    Value<String?> sanskritRootClass = const Value.absent(),
    Value<String?> rootExample = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<int?> rootCount = const Value.absent(),
  }) => DpdRoot(
    root: root ?? this.root,
    rootInComps: rootInComps.present ? rootInComps.value : this.rootInComps,
    rootHasVerb: rootHasVerb.present ? rootHasVerb.value : this.rootHasVerb,
    rootGroup: rootGroup.present ? rootGroup.value : this.rootGroup,
    rootSign: rootSign.present ? rootSign.value : this.rootSign,
    rootMeaning: rootMeaning.present ? rootMeaning.value : this.rootMeaning,
    sanskritRoot: sanskritRoot.present ? sanskritRoot.value : this.sanskritRoot,
    sanskritRootMeaning: sanskritRootMeaning.present
        ? sanskritRootMeaning.value
        : this.sanskritRootMeaning,
    sanskritRootClass: sanskritRootClass.present
        ? sanskritRootClass.value
        : this.sanskritRootClass,
    rootExample: rootExample.present ? rootExample.value : this.rootExample,
    note: note.present ? note.value : this.note,
    rootCount: rootCount.present ? rootCount.value : this.rootCount,
  );
  DpdRoot copyWithCompanion(DpdRootsCompanion data) {
    return DpdRoot(
      root: data.root.present ? data.root.value : this.root,
      rootInComps: data.rootInComps.present
          ? data.rootInComps.value
          : this.rootInComps,
      rootHasVerb: data.rootHasVerb.present
          ? data.rootHasVerb.value
          : this.rootHasVerb,
      rootGroup: data.rootGroup.present ? data.rootGroup.value : this.rootGroup,
      rootSign: data.rootSign.present ? data.rootSign.value : this.rootSign,
      rootMeaning: data.rootMeaning.present
          ? data.rootMeaning.value
          : this.rootMeaning,
      sanskritRoot: data.sanskritRoot.present
          ? data.sanskritRoot.value
          : this.sanskritRoot,
      sanskritRootMeaning: data.sanskritRootMeaning.present
          ? data.sanskritRootMeaning.value
          : this.sanskritRootMeaning,
      sanskritRootClass: data.sanskritRootClass.present
          ? data.sanskritRootClass.value
          : this.sanskritRootClass,
      rootExample: data.rootExample.present
          ? data.rootExample.value
          : this.rootExample,
      note: data.note.present ? data.note.value : this.note,
      rootCount: data.rootCount.present ? data.rootCount.value : this.rootCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DpdRoot(')
          ..write('root: $root, ')
          ..write('rootInComps: $rootInComps, ')
          ..write('rootHasVerb: $rootHasVerb, ')
          ..write('rootGroup: $rootGroup, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootMeaning: $rootMeaning, ')
          ..write('sanskritRoot: $sanskritRoot, ')
          ..write('sanskritRootMeaning: $sanskritRootMeaning, ')
          ..write('sanskritRootClass: $sanskritRootClass, ')
          ..write('rootExample: $rootExample, ')
          ..write('note: $note, ')
          ..write('rootCount: $rootCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    root,
    rootInComps,
    rootHasVerb,
    rootGroup,
    rootSign,
    rootMeaning,
    sanskritRoot,
    sanskritRootMeaning,
    sanskritRootClass,
    rootExample,
    note,
    rootCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DpdRoot &&
          other.root == this.root &&
          other.rootInComps == this.rootInComps &&
          other.rootHasVerb == this.rootHasVerb &&
          other.rootGroup == this.rootGroup &&
          other.rootSign == this.rootSign &&
          other.rootMeaning == this.rootMeaning &&
          other.sanskritRoot == this.sanskritRoot &&
          other.sanskritRootMeaning == this.sanskritRootMeaning &&
          other.sanskritRootClass == this.sanskritRootClass &&
          other.rootExample == this.rootExample &&
          other.note == this.note &&
          other.rootCount == this.rootCount);
}

class DpdRootsCompanion extends UpdateCompanion<DpdRoot> {
  final Value<String> root;
  final Value<String?> rootInComps;
  final Value<String?> rootHasVerb;
  final Value<String?> rootGroup;
  final Value<String?> rootSign;
  final Value<String?> rootMeaning;
  final Value<String?> sanskritRoot;
  final Value<String?> sanskritRootMeaning;
  final Value<String?> sanskritRootClass;
  final Value<String?> rootExample;
  final Value<String?> note;
  final Value<int?> rootCount;
  final Value<int> rowid;
  const DpdRootsCompanion({
    this.root = const Value.absent(),
    this.rootInComps = const Value.absent(),
    this.rootHasVerb = const Value.absent(),
    this.rootGroup = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootMeaning = const Value.absent(),
    this.sanskritRoot = const Value.absent(),
    this.sanskritRootMeaning = const Value.absent(),
    this.sanskritRootClass = const Value.absent(),
    this.rootExample = const Value.absent(),
    this.note = const Value.absent(),
    this.rootCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DpdRootsCompanion.insert({
    required String root,
    this.rootInComps = const Value.absent(),
    this.rootHasVerb = const Value.absent(),
    this.rootGroup = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootMeaning = const Value.absent(),
    this.sanskritRoot = const Value.absent(),
    this.sanskritRootMeaning = const Value.absent(),
    this.sanskritRootClass = const Value.absent(),
    this.rootExample = const Value.absent(),
    this.note = const Value.absent(),
    this.rootCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : root = Value(root);
  static Insertable<DpdRoot> custom({
    Expression<String>? root,
    Expression<String>? rootInComps,
    Expression<String>? rootHasVerb,
    Expression<String>? rootGroup,
    Expression<String>? rootSign,
    Expression<String>? rootMeaning,
    Expression<String>? sanskritRoot,
    Expression<String>? sanskritRootMeaning,
    Expression<String>? sanskritRootClass,
    Expression<String>? rootExample,
    Expression<String>? note,
    Expression<int>? rootCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (root != null) 'root': root,
      if (rootInComps != null) 'root_in_comps': rootInComps,
      if (rootHasVerb != null) 'root_has_verb': rootHasVerb,
      if (rootGroup != null) 'root_group': rootGroup,
      if (rootSign != null) 'root_sign': rootSign,
      if (rootMeaning != null) 'root_meaning': rootMeaning,
      if (sanskritRoot != null) 'sanskrit_root': sanskritRoot,
      if (sanskritRootMeaning != null)
        'sanskrit_root_meaning': sanskritRootMeaning,
      if (sanskritRootClass != null) 'sanskrit_root_class': sanskritRootClass,
      if (rootExample != null) 'root_example': rootExample,
      if (note != null) 'note': note,
      if (rootCount != null) 'root_count': rootCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DpdRootsCompanion copyWith({
    Value<String>? root,
    Value<String?>? rootInComps,
    Value<String?>? rootHasVerb,
    Value<String?>? rootGroup,
    Value<String?>? rootSign,
    Value<String?>? rootMeaning,
    Value<String?>? sanskritRoot,
    Value<String?>? sanskritRootMeaning,
    Value<String?>? sanskritRootClass,
    Value<String?>? rootExample,
    Value<String?>? note,
    Value<int?>? rootCount,
    Value<int>? rowid,
  }) {
    return DpdRootsCompanion(
      root: root ?? this.root,
      rootInComps: rootInComps ?? this.rootInComps,
      rootHasVerb: rootHasVerb ?? this.rootHasVerb,
      rootGroup: rootGroup ?? this.rootGroup,
      rootSign: rootSign ?? this.rootSign,
      rootMeaning: rootMeaning ?? this.rootMeaning,
      sanskritRoot: sanskritRoot ?? this.sanskritRoot,
      sanskritRootMeaning: sanskritRootMeaning ?? this.sanskritRootMeaning,
      sanskritRootClass: sanskritRootClass ?? this.sanskritRootClass,
      rootExample: rootExample ?? this.rootExample,
      note: note ?? this.note,
      rootCount: rootCount ?? this.rootCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (root.present) {
      map['root'] = Variable<String>(root.value);
    }
    if (rootInComps.present) {
      map['root_in_comps'] = Variable<String>(rootInComps.value);
    }
    if (rootHasVerb.present) {
      map['root_has_verb'] = Variable<String>(rootHasVerb.value);
    }
    if (rootGroup.present) {
      map['root_group'] = Variable<String>(rootGroup.value);
    }
    if (rootSign.present) {
      map['root_sign'] = Variable<String>(rootSign.value);
    }
    if (rootMeaning.present) {
      map['root_meaning'] = Variable<String>(rootMeaning.value);
    }
    if (sanskritRoot.present) {
      map['sanskrit_root'] = Variable<String>(sanskritRoot.value);
    }
    if (sanskritRootMeaning.present) {
      map['sanskrit_root_meaning'] = Variable<String>(
        sanskritRootMeaning.value,
      );
    }
    if (sanskritRootClass.present) {
      map['sanskrit_root_class'] = Variable<String>(sanskritRootClass.value);
    }
    if (rootExample.present) {
      map['root_example'] = Variable<String>(rootExample.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rootCount.present) {
      map['root_count'] = Variable<int>(rootCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DpdRootsCompanion(')
          ..write('root: $root, ')
          ..write('rootInComps: $rootInComps, ')
          ..write('rootHasVerb: $rootHasVerb, ')
          ..write('rootGroup: $rootGroup, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootMeaning: $rootMeaning, ')
          ..write('sanskritRoot: $sanskritRoot, ')
          ..write('sanskritRootMeaning: $sanskritRootMeaning, ')
          ..write('sanskritRootClass: $sanskritRootClass, ')
          ..write('rootExample: $rootExample, ')
          ..write('note: $note, ')
          ..write('rootCount: $rootCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LookupTable extends Lookup with TableInfo<$LookupTable, LookupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LookupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lookupKeyMeta = const VerificationMeta(
    'lookupKey',
  );
  @override
  late final GeneratedColumn<String> lookupKey = GeneratedColumn<String>(
    'lookup_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headwordsMeta = const VerificationMeta(
    'headwords',
  );
  @override
  late final GeneratedColumn<String> headwords = GeneratedColumn<String>(
    'headwords',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootsMeta = const VerificationMeta('roots');
  @override
  late final GeneratedColumn<String> roots = GeneratedColumn<String>(
    'roots',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variantMeta = const VerificationMeta(
    'variant',
  );
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spellingMeta = const VerificationMeta(
    'spelling',
  );
  @override
  late final GeneratedColumn<String> spelling = GeneratedColumn<String>(
    'spelling',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grammarMeta = const VerificationMeta(
    'grammar',
  );
  @override
  late final GeneratedColumn<String> grammar = GeneratedColumn<String>(
    'grammar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _helpMeta = const VerificationMeta('help');
  @override
  late final GeneratedColumn<String> help = GeneratedColumn<String>(
    'help',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abbrevMeta = const VerificationMeta('abbrev');
  @override
  late final GeneratedColumn<String> abbrev = GeneratedColumn<String>(
    'abbrev',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deconstructorMeta = const VerificationMeta(
    'deconstructor',
  );
  @override
  late final GeneratedColumn<String> deconstructor = GeneratedColumn<String>(
    'deconstructor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epdMeta = const VerificationMeta('epd');
  @override
  late final GeneratedColumn<String> epd = GeneratedColumn<String>(
    'epd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuzzyKeyMeta = const VerificationMeta(
    'fuzzyKey',
  );
  @override
  late final GeneratedColumn<String> fuzzyKey = GeneratedColumn<String>(
    'fuzzy_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lookupKey,
    headwords,
    roots,
    variant,
    spelling,
    grammar,
    help,
    abbrev,
    deconstructor,
    epd,
    fuzzyKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lookup';
  @override
  VerificationContext validateIntegrity(
    Insertable<LookupData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lookup_key')) {
      context.handle(
        _lookupKeyMeta,
        lookupKey.isAcceptableOrUnknown(data['lookup_key']!, _lookupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_lookupKeyMeta);
    }
    if (data.containsKey('headwords')) {
      context.handle(
        _headwordsMeta,
        headwords.isAcceptableOrUnknown(data['headwords']!, _headwordsMeta),
      );
    }
    if (data.containsKey('roots')) {
      context.handle(
        _rootsMeta,
        roots.isAcceptableOrUnknown(data['roots']!, _rootsMeta),
      );
    }
    if (data.containsKey('variant')) {
      context.handle(
        _variantMeta,
        variant.isAcceptableOrUnknown(data['variant']!, _variantMeta),
      );
    }
    if (data.containsKey('spelling')) {
      context.handle(
        _spellingMeta,
        spelling.isAcceptableOrUnknown(data['spelling']!, _spellingMeta),
      );
    }
    if (data.containsKey('grammar')) {
      context.handle(
        _grammarMeta,
        grammar.isAcceptableOrUnknown(data['grammar']!, _grammarMeta),
      );
    }
    if (data.containsKey('help')) {
      context.handle(
        _helpMeta,
        help.isAcceptableOrUnknown(data['help']!, _helpMeta),
      );
    }
    if (data.containsKey('abbrev')) {
      context.handle(
        _abbrevMeta,
        abbrev.isAcceptableOrUnknown(data['abbrev']!, _abbrevMeta),
      );
    }
    if (data.containsKey('deconstructor')) {
      context.handle(
        _deconstructorMeta,
        deconstructor.isAcceptableOrUnknown(
          data['deconstructor']!,
          _deconstructorMeta,
        ),
      );
    }
    if (data.containsKey('epd')) {
      context.handle(
        _epdMeta,
        epd.isAcceptableOrUnknown(data['epd']!, _epdMeta),
      );
    }
    if (data.containsKey('fuzzy_key')) {
      context.handle(
        _fuzzyKeyMeta,
        fuzzyKey.isAcceptableOrUnknown(data['fuzzy_key']!, _fuzzyKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lookupKey};
  @override
  LookupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookupData(
      lookupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lookup_key'],
      )!,
      headwords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headwords'],
      ),
      roots: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roots'],
      ),
      variant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant'],
      ),
      spelling: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spelling'],
      ),
      grammar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grammar'],
      ),
      help: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}help'],
      ),
      abbrev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbrev'],
      ),
      deconstructor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deconstructor'],
      ),
      epd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epd'],
      ),
      fuzzyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuzzy_key'],
      ),
    );
  }

  @override
  $LookupTable createAlias(String alias) {
    return $LookupTable(attachedDatabase, alias);
  }
}

class LookupData extends DataClass implements Insertable<LookupData> {
  final String lookupKey;
  final String? headwords;
  final String? roots;
  final String? variant;
  final String? spelling;
  final String? grammar;
  final String? help;
  final String? abbrev;
  final String? deconstructor;
  final String? epd;
  final String? fuzzyKey;
  const LookupData({
    required this.lookupKey,
    this.headwords,
    this.roots,
    this.variant,
    this.spelling,
    this.grammar,
    this.help,
    this.abbrev,
    this.deconstructor,
    this.epd,
    this.fuzzyKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lookup_key'] = Variable<String>(lookupKey);
    if (!nullToAbsent || headwords != null) {
      map['headwords'] = Variable<String>(headwords);
    }
    if (!nullToAbsent || roots != null) {
      map['roots'] = Variable<String>(roots);
    }
    if (!nullToAbsent || variant != null) {
      map['variant'] = Variable<String>(variant);
    }
    if (!nullToAbsent || spelling != null) {
      map['spelling'] = Variable<String>(spelling);
    }
    if (!nullToAbsent || grammar != null) {
      map['grammar'] = Variable<String>(grammar);
    }
    if (!nullToAbsent || help != null) {
      map['help'] = Variable<String>(help);
    }
    if (!nullToAbsent || abbrev != null) {
      map['abbrev'] = Variable<String>(abbrev);
    }
    if (!nullToAbsent || deconstructor != null) {
      map['deconstructor'] = Variable<String>(deconstructor);
    }
    if (!nullToAbsent || epd != null) {
      map['epd'] = Variable<String>(epd);
    }
    if (!nullToAbsent || fuzzyKey != null) {
      map['fuzzy_key'] = Variable<String>(fuzzyKey);
    }
    return map;
  }

  LookupCompanion toCompanion(bool nullToAbsent) {
    return LookupCompanion(
      lookupKey: Value(lookupKey),
      headwords: headwords == null && nullToAbsent
          ? const Value.absent()
          : Value(headwords),
      roots: roots == null && nullToAbsent
          ? const Value.absent()
          : Value(roots),
      variant: variant == null && nullToAbsent
          ? const Value.absent()
          : Value(variant),
      spelling: spelling == null && nullToAbsent
          ? const Value.absent()
          : Value(spelling),
      grammar: grammar == null && nullToAbsent
          ? const Value.absent()
          : Value(grammar),
      help: help == null && nullToAbsent ? const Value.absent() : Value(help),
      abbrev: abbrev == null && nullToAbsent
          ? const Value.absent()
          : Value(abbrev),
      deconstructor: deconstructor == null && nullToAbsent
          ? const Value.absent()
          : Value(deconstructor),
      epd: epd == null && nullToAbsent ? const Value.absent() : Value(epd),
      fuzzyKey: fuzzyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(fuzzyKey),
    );
  }

  factory LookupData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookupData(
      lookupKey: serializer.fromJson<String>(json['lookupKey']),
      headwords: serializer.fromJson<String?>(json['headwords']),
      roots: serializer.fromJson<String?>(json['roots']),
      variant: serializer.fromJson<String?>(json['variant']),
      spelling: serializer.fromJson<String?>(json['spelling']),
      grammar: serializer.fromJson<String?>(json['grammar']),
      help: serializer.fromJson<String?>(json['help']),
      abbrev: serializer.fromJson<String?>(json['abbrev']),
      deconstructor: serializer.fromJson<String?>(json['deconstructor']),
      epd: serializer.fromJson<String?>(json['epd']),
      fuzzyKey: serializer.fromJson<String?>(json['fuzzyKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lookupKey': serializer.toJson<String>(lookupKey),
      'headwords': serializer.toJson<String?>(headwords),
      'roots': serializer.toJson<String?>(roots),
      'variant': serializer.toJson<String?>(variant),
      'spelling': serializer.toJson<String?>(spelling),
      'grammar': serializer.toJson<String?>(grammar),
      'help': serializer.toJson<String?>(help),
      'abbrev': serializer.toJson<String?>(abbrev),
      'deconstructor': serializer.toJson<String?>(deconstructor),
      'epd': serializer.toJson<String?>(epd),
      'fuzzyKey': serializer.toJson<String?>(fuzzyKey),
    };
  }

  LookupData copyWith({
    String? lookupKey,
    Value<String?> headwords = const Value.absent(),
    Value<String?> roots = const Value.absent(),
    Value<String?> variant = const Value.absent(),
    Value<String?> spelling = const Value.absent(),
    Value<String?> grammar = const Value.absent(),
    Value<String?> help = const Value.absent(),
    Value<String?> abbrev = const Value.absent(),
    Value<String?> deconstructor = const Value.absent(),
    Value<String?> epd = const Value.absent(),
    Value<String?> fuzzyKey = const Value.absent(),
  }) => LookupData(
    lookupKey: lookupKey ?? this.lookupKey,
    headwords: headwords.present ? headwords.value : this.headwords,
    roots: roots.present ? roots.value : this.roots,
    variant: variant.present ? variant.value : this.variant,
    spelling: spelling.present ? spelling.value : this.spelling,
    grammar: grammar.present ? grammar.value : this.grammar,
    help: help.present ? help.value : this.help,
    abbrev: abbrev.present ? abbrev.value : this.abbrev,
    deconstructor: deconstructor.present
        ? deconstructor.value
        : this.deconstructor,
    epd: epd.present ? epd.value : this.epd,
    fuzzyKey: fuzzyKey.present ? fuzzyKey.value : this.fuzzyKey,
  );
  LookupData copyWithCompanion(LookupCompanion data) {
    return LookupData(
      lookupKey: data.lookupKey.present ? data.lookupKey.value : this.lookupKey,
      headwords: data.headwords.present ? data.headwords.value : this.headwords,
      roots: data.roots.present ? data.roots.value : this.roots,
      variant: data.variant.present ? data.variant.value : this.variant,
      spelling: data.spelling.present ? data.spelling.value : this.spelling,
      grammar: data.grammar.present ? data.grammar.value : this.grammar,
      help: data.help.present ? data.help.value : this.help,
      abbrev: data.abbrev.present ? data.abbrev.value : this.abbrev,
      deconstructor: data.deconstructor.present
          ? data.deconstructor.value
          : this.deconstructor,
      epd: data.epd.present ? data.epd.value : this.epd,
      fuzzyKey: data.fuzzyKey.present ? data.fuzzyKey.value : this.fuzzyKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LookupData(')
          ..write('lookupKey: $lookupKey, ')
          ..write('headwords: $headwords, ')
          ..write('roots: $roots, ')
          ..write('variant: $variant, ')
          ..write('spelling: $spelling, ')
          ..write('grammar: $grammar, ')
          ..write('help: $help, ')
          ..write('abbrev: $abbrev, ')
          ..write('deconstructor: $deconstructor, ')
          ..write('epd: $epd, ')
          ..write('fuzzyKey: $fuzzyKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    lookupKey,
    headwords,
    roots,
    variant,
    spelling,
    grammar,
    help,
    abbrev,
    deconstructor,
    epd,
    fuzzyKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookupData &&
          other.lookupKey == this.lookupKey &&
          other.headwords == this.headwords &&
          other.roots == this.roots &&
          other.variant == this.variant &&
          other.spelling == this.spelling &&
          other.grammar == this.grammar &&
          other.help == this.help &&
          other.abbrev == this.abbrev &&
          other.deconstructor == this.deconstructor &&
          other.epd == this.epd &&
          other.fuzzyKey == this.fuzzyKey);
}

class LookupCompanion extends UpdateCompanion<LookupData> {
  final Value<String> lookupKey;
  final Value<String?> headwords;
  final Value<String?> roots;
  final Value<String?> variant;
  final Value<String?> spelling;
  final Value<String?> grammar;
  final Value<String?> help;
  final Value<String?> abbrev;
  final Value<String?> deconstructor;
  final Value<String?> epd;
  final Value<String?> fuzzyKey;
  final Value<int> rowid;
  const LookupCompanion({
    this.lookupKey = const Value.absent(),
    this.headwords = const Value.absent(),
    this.roots = const Value.absent(),
    this.variant = const Value.absent(),
    this.spelling = const Value.absent(),
    this.grammar = const Value.absent(),
    this.help = const Value.absent(),
    this.abbrev = const Value.absent(),
    this.deconstructor = const Value.absent(),
    this.epd = const Value.absent(),
    this.fuzzyKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LookupCompanion.insert({
    required String lookupKey,
    this.headwords = const Value.absent(),
    this.roots = const Value.absent(),
    this.variant = const Value.absent(),
    this.spelling = const Value.absent(),
    this.grammar = const Value.absent(),
    this.help = const Value.absent(),
    this.abbrev = const Value.absent(),
    this.deconstructor = const Value.absent(),
    this.epd = const Value.absent(),
    this.fuzzyKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lookupKey = Value(lookupKey);
  static Insertable<LookupData> custom({
    Expression<String>? lookupKey,
    Expression<String>? headwords,
    Expression<String>? roots,
    Expression<String>? variant,
    Expression<String>? spelling,
    Expression<String>? grammar,
    Expression<String>? help,
    Expression<String>? abbrev,
    Expression<String>? deconstructor,
    Expression<String>? epd,
    Expression<String>? fuzzyKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lookupKey != null) 'lookup_key': lookupKey,
      if (headwords != null) 'headwords': headwords,
      if (roots != null) 'roots': roots,
      if (variant != null) 'variant': variant,
      if (spelling != null) 'spelling': spelling,
      if (grammar != null) 'grammar': grammar,
      if (help != null) 'help': help,
      if (abbrev != null) 'abbrev': abbrev,
      if (deconstructor != null) 'deconstructor': deconstructor,
      if (epd != null) 'epd': epd,
      if (fuzzyKey != null) 'fuzzy_key': fuzzyKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LookupCompanion copyWith({
    Value<String>? lookupKey,
    Value<String?>? headwords,
    Value<String?>? roots,
    Value<String?>? variant,
    Value<String?>? spelling,
    Value<String?>? grammar,
    Value<String?>? help,
    Value<String?>? abbrev,
    Value<String?>? deconstructor,
    Value<String?>? epd,
    Value<String?>? fuzzyKey,
    Value<int>? rowid,
  }) {
    return LookupCompanion(
      lookupKey: lookupKey ?? this.lookupKey,
      headwords: headwords ?? this.headwords,
      roots: roots ?? this.roots,
      variant: variant ?? this.variant,
      spelling: spelling ?? this.spelling,
      grammar: grammar ?? this.grammar,
      help: help ?? this.help,
      abbrev: abbrev ?? this.abbrev,
      deconstructor: deconstructor ?? this.deconstructor,
      epd: epd ?? this.epd,
      fuzzyKey: fuzzyKey ?? this.fuzzyKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lookupKey.present) {
      map['lookup_key'] = Variable<String>(lookupKey.value);
    }
    if (headwords.present) {
      map['headwords'] = Variable<String>(headwords.value);
    }
    if (roots.present) {
      map['roots'] = Variable<String>(roots.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (spelling.present) {
      map['spelling'] = Variable<String>(spelling.value);
    }
    if (grammar.present) {
      map['grammar'] = Variable<String>(grammar.value);
    }
    if (help.present) {
      map['help'] = Variable<String>(help.value);
    }
    if (abbrev.present) {
      map['abbrev'] = Variable<String>(abbrev.value);
    }
    if (deconstructor.present) {
      map['deconstructor'] = Variable<String>(deconstructor.value);
    }
    if (epd.present) {
      map['epd'] = Variable<String>(epd.value);
    }
    if (fuzzyKey.present) {
      map['fuzzy_key'] = Variable<String>(fuzzyKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LookupCompanion(')
          ..write('lookupKey: $lookupKey, ')
          ..write('headwords: $headwords, ')
          ..write('roots: $roots, ')
          ..write('variant: $variant, ')
          ..write('spelling: $spelling, ')
          ..write('grammar: $grammar, ')
          ..write('help: $help, ')
          ..write('abbrev: $abbrev, ')
          ..write('deconstructor: $deconstructor, ')
          ..write('epd: $epd, ')
          ..write('fuzzyKey: $fuzzyKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DpdDatabase extends GeneratedDatabase {
  _$DpdDatabase(QueryExecutor e) : super(e);
  $DpdDatabaseManager get managers => $DpdDatabaseManager(this);
  late final $DictMetaTable dictMeta = $DictMetaTable(this);
  late final $DictEntriesTable dictEntries = $DictEntriesTable(this);
  late final $DpdHeadwordsTable dpdHeadwords = $DpdHeadwordsTable(this);
  late final $DpdRootsTable dpdRoots = $DpdRootsTable(this);
  late final $LookupTable lookup = $LookupTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dictMeta,
    dictEntries,
    dpdHeadwords,
    dpdRoots,
    lookup,
  ];
}

typedef $$DictMetaTableCreateCompanionBuilder =
    DictMetaCompanion Function({
      required String dictId,
      Value<String?> name,
      Value<String?> author,
      Value<String?> css,
      Value<int?> entryCount,
      Value<int> rowid,
    });
typedef $$DictMetaTableUpdateCompanionBuilder =
    DictMetaCompanion Function({
      Value<String> dictId,
      Value<String?> name,
      Value<String?> author,
      Value<String?> css,
      Value<int?> entryCount,
      Value<int> rowid,
    });

class $$DictMetaTableFilterComposer
    extends Composer<_$DpdDatabase, $DictMetaTable> {
  $$DictMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dictId => $composableBuilder(
    column: $table.dictId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get css => $composableBuilder(
    column: $table.css,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictMetaTableOrderingComposer
    extends Composer<_$DpdDatabase, $DictMetaTable> {
  $$DictMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dictId => $composableBuilder(
    column: $table.dictId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get css => $composableBuilder(
    column: $table.css,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictMetaTableAnnotationComposer
    extends Composer<_$DpdDatabase, $DictMetaTable> {
  $$DictMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dictId =>
      $composableBuilder(column: $table.dictId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get css =>
      $composableBuilder(column: $table.css, builder: (column) => column);

  GeneratedColumn<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => column,
  );
}

class $$DictMetaTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $DictMetaTable,
          DictMetaData,
          $$DictMetaTableFilterComposer,
          $$DictMetaTableOrderingComposer,
          $$DictMetaTableAnnotationComposer,
          $$DictMetaTableCreateCompanionBuilder,
          $$DictMetaTableUpdateCompanionBuilder,
          (
            DictMetaData,
            BaseReferences<_$DpdDatabase, $DictMetaTable, DictMetaData>,
          ),
          DictMetaData,
          PrefetchHooks Function()
        > {
  $$DictMetaTableTableManager(_$DpdDatabase db, $DictMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dictId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> css = const Value.absent(),
                Value<int?> entryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictMetaCompanion(
                dictId: dictId,
                name: name,
                author: author,
                css: css,
                entryCount: entryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dictId,
                Value<String?> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> css = const Value.absent(),
                Value<int?> entryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictMetaCompanion.insert(
                dictId: dictId,
                name: name,
                author: author,
                css: css,
                entryCount: entryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $DictMetaTable,
      DictMetaData,
      $$DictMetaTableFilterComposer,
      $$DictMetaTableOrderingComposer,
      $$DictMetaTableAnnotationComposer,
      $$DictMetaTableCreateCompanionBuilder,
      $$DictMetaTableUpdateCompanionBuilder,
      (
        DictMetaData,
        BaseReferences<_$DpdDatabase, $DictMetaTable, DictMetaData>,
      ),
      DictMetaData,
      PrefetchHooks Function()
    >;
typedef $$DictEntriesTableCreateCompanionBuilder =
    DictEntriesCompanion Function({
      Value<int> id,
      required String dictId,
      required String word,
      Value<String?> wordFuzzy,
      Value<String?> definitionHtml,
      Value<String?> definitionPlain,
    });
typedef $$DictEntriesTableUpdateCompanionBuilder =
    DictEntriesCompanion Function({
      Value<int> id,
      Value<String> dictId,
      Value<String> word,
      Value<String?> wordFuzzy,
      Value<String?> definitionHtml,
      Value<String?> definitionPlain,
    });

class $$DictEntriesTableFilterComposer
    extends Composer<_$DpdDatabase, $DictEntriesTable> {
  $$DictEntriesTableFilterComposer({
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

  ColumnFilters<String> get dictId => $composableBuilder(
    column: $table.dictId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordFuzzy => $composableBuilder(
    column: $table.wordFuzzy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionHtml => $composableBuilder(
    column: $table.definitionHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionPlain => $composableBuilder(
    column: $table.definitionPlain,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictEntriesTableOrderingComposer
    extends Composer<_$DpdDatabase, $DictEntriesTable> {
  $$DictEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get dictId => $composableBuilder(
    column: $table.dictId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordFuzzy => $composableBuilder(
    column: $table.wordFuzzy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionHtml => $composableBuilder(
    column: $table.definitionHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionPlain => $composableBuilder(
    column: $table.definitionPlain,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictEntriesTableAnnotationComposer
    extends Composer<_$DpdDatabase, $DictEntriesTable> {
  $$DictEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dictId =>
      $composableBuilder(column: $table.dictId, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get wordFuzzy =>
      $composableBuilder(column: $table.wordFuzzy, builder: (column) => column);

  GeneratedColumn<String> get definitionHtml => $composableBuilder(
    column: $table.definitionHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionPlain => $composableBuilder(
    column: $table.definitionPlain,
    builder: (column) => column,
  );
}

class $$DictEntriesTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $DictEntriesTable,
          DictEntry,
          $$DictEntriesTableFilterComposer,
          $$DictEntriesTableOrderingComposer,
          $$DictEntriesTableAnnotationComposer,
          $$DictEntriesTableCreateCompanionBuilder,
          $$DictEntriesTableUpdateCompanionBuilder,
          (
            DictEntry,
            BaseReferences<_$DpdDatabase, $DictEntriesTable, DictEntry>,
          ),
          DictEntry,
          PrefetchHooks Function()
        > {
  $$DictEntriesTableTableManager(_$DpdDatabase db, $DictEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dictId = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String?> wordFuzzy = const Value.absent(),
                Value<String?> definitionHtml = const Value.absent(),
                Value<String?> definitionPlain = const Value.absent(),
              }) => DictEntriesCompanion(
                id: id,
                dictId: dictId,
                word: word,
                wordFuzzy: wordFuzzy,
                definitionHtml: definitionHtml,
                definitionPlain: definitionPlain,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dictId,
                required String word,
                Value<String?> wordFuzzy = const Value.absent(),
                Value<String?> definitionHtml = const Value.absent(),
                Value<String?> definitionPlain = const Value.absent(),
              }) => DictEntriesCompanion.insert(
                id: id,
                dictId: dictId,
                word: word,
                wordFuzzy: wordFuzzy,
                definitionHtml: definitionHtml,
                definitionPlain: definitionPlain,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $DictEntriesTable,
      DictEntry,
      $$DictEntriesTableFilterComposer,
      $$DictEntriesTableOrderingComposer,
      $$DictEntriesTableAnnotationComposer,
      $$DictEntriesTableCreateCompanionBuilder,
      $$DictEntriesTableUpdateCompanionBuilder,
      (DictEntry, BaseReferences<_$DpdDatabase, $DictEntriesTable, DictEntry>),
      DictEntry,
      PrefetchHooks Function()
    >;
typedef $$DpdHeadwordsTableCreateCompanionBuilder =
    DpdHeadwordsCompanion Function({
      Value<int> id,
      required String lemma1,
      Value<String?> lemma2,
      Value<String?> pos,
      Value<String?> grammar,
      Value<String?> derivedFrom,
      Value<String?> neg,
      Value<String?> verb,
      Value<String?> trans,
      Value<String?> plusCase,
      Value<String?> meaning1,
      Value<String?> meaningLit,
      Value<String?> meaning2,
      Value<String?> source1,
      Value<String?> sutta1,
      Value<String?> example1,
      Value<String?> source2,
      Value<String?> sutta2,
      Value<String?> example2,
      Value<String?> rootKey,
      Value<String?> rootSign,
      Value<String?> rootBase,
      Value<String?> familyRoot,
      Value<String?> familyWord,
      Value<String?> familyCompound,
      Value<String?> familyIdioms,
      Value<String?> construction,
      Value<String?> compoundType,
      Value<String?> antonym,
      Value<String?> synonym,
      Value<String?> variant,
      Value<String?> stem,
      Value<String?> pattern,
      Value<String?> suffix,
      Value<String?> freqData,
      Value<String?> lemmaIpa,
      Value<int?> ebtCount,
      Value<String?> nonIa,
      Value<String?> sanskrit,
      Value<String?> cognate,
      Value<String?> link,
      Value<String?> phonetic,
      Value<String?> varPhonetic,
      Value<String?> varText,
      Value<String?> origin,
      Value<String?> notes,
      Value<String?> commentary,
    });
typedef $$DpdHeadwordsTableUpdateCompanionBuilder =
    DpdHeadwordsCompanion Function({
      Value<int> id,
      Value<String> lemma1,
      Value<String?> lemma2,
      Value<String?> pos,
      Value<String?> grammar,
      Value<String?> derivedFrom,
      Value<String?> neg,
      Value<String?> verb,
      Value<String?> trans,
      Value<String?> plusCase,
      Value<String?> meaning1,
      Value<String?> meaningLit,
      Value<String?> meaning2,
      Value<String?> source1,
      Value<String?> sutta1,
      Value<String?> example1,
      Value<String?> source2,
      Value<String?> sutta2,
      Value<String?> example2,
      Value<String?> rootKey,
      Value<String?> rootSign,
      Value<String?> rootBase,
      Value<String?> familyRoot,
      Value<String?> familyWord,
      Value<String?> familyCompound,
      Value<String?> familyIdioms,
      Value<String?> construction,
      Value<String?> compoundType,
      Value<String?> antonym,
      Value<String?> synonym,
      Value<String?> variant,
      Value<String?> stem,
      Value<String?> pattern,
      Value<String?> suffix,
      Value<String?> freqData,
      Value<String?> lemmaIpa,
      Value<int?> ebtCount,
      Value<String?> nonIa,
      Value<String?> sanskrit,
      Value<String?> cognate,
      Value<String?> link,
      Value<String?> phonetic,
      Value<String?> varPhonetic,
      Value<String?> varText,
      Value<String?> origin,
      Value<String?> notes,
      Value<String?> commentary,
    });

class $$DpdHeadwordsTableFilterComposer
    extends Composer<_$DpdDatabase, $DpdHeadwordsTable> {
  $$DpdHeadwordsTableFilterComposer({
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

  ColumnFilters<String> get lemma1 => $composableBuilder(
    column: $table.lemma1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lemma2 => $composableBuilder(
    column: $table.lemma2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammar => $composableBuilder(
    column: $table.grammar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derivedFrom => $composableBuilder(
    column: $table.derivedFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get neg => $composableBuilder(
    column: $table.neg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verb => $composableBuilder(
    column: $table.verb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trans => $composableBuilder(
    column: $table.trans,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plusCase => $composableBuilder(
    column: $table.plusCase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning1 => $composableBuilder(
    column: $table.meaning1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaningLit => $composableBuilder(
    column: $table.meaningLit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning2 => $composableBuilder(
    column: $table.meaning2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source1 => $composableBuilder(
    column: $table.source1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sutta1 => $composableBuilder(
    column: $table.sutta1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get example1 => $composableBuilder(
    column: $table.example1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source2 => $composableBuilder(
    column: $table.source2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sutta2 => $composableBuilder(
    column: $table.sutta2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get example2 => $composableBuilder(
    column: $table.example2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootKey => $composableBuilder(
    column: $table.rootKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootSign => $composableBuilder(
    column: $table.rootSign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootBase => $composableBuilder(
    column: $table.rootBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyRoot => $composableBuilder(
    column: $table.familyRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyWord => $composableBuilder(
    column: $table.familyWord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyCompound => $composableBuilder(
    column: $table.familyCompound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyIdioms => $composableBuilder(
    column: $table.familyIdioms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get construction => $composableBuilder(
    column: $table.construction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compoundType => $composableBuilder(
    column: $table.compoundType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get antonym => $composableBuilder(
    column: $table.antonym,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synonym => $composableBuilder(
    column: $table.synonym,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stem => $composableBuilder(
    column: $table.stem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freqData => $composableBuilder(
    column: $table.freqData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lemmaIpa => $composableBuilder(
    column: $table.lemmaIpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ebtCount => $composableBuilder(
    column: $table.ebtCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nonIa => $composableBuilder(
    column: $table.nonIa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanskrit => $composableBuilder(
    column: $table.sanskrit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cognate => $composableBuilder(
    column: $table.cognate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get varPhonetic => $composableBuilder(
    column: $table.varPhonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get varText => $composableBuilder(
    column: $table.varText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentary => $composableBuilder(
    column: $table.commentary,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DpdHeadwordsTableOrderingComposer
    extends Composer<_$DpdDatabase, $DpdHeadwordsTable> {
  $$DpdHeadwordsTableOrderingComposer({
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

  ColumnOrderings<String> get lemma1 => $composableBuilder(
    column: $table.lemma1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lemma2 => $composableBuilder(
    column: $table.lemma2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammar => $composableBuilder(
    column: $table.grammar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derivedFrom => $composableBuilder(
    column: $table.derivedFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get neg => $composableBuilder(
    column: $table.neg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verb => $composableBuilder(
    column: $table.verb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trans => $composableBuilder(
    column: $table.trans,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plusCase => $composableBuilder(
    column: $table.plusCase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning1 => $composableBuilder(
    column: $table.meaning1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaningLit => $composableBuilder(
    column: $table.meaningLit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning2 => $composableBuilder(
    column: $table.meaning2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source1 => $composableBuilder(
    column: $table.source1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sutta1 => $composableBuilder(
    column: $table.sutta1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get example1 => $composableBuilder(
    column: $table.example1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source2 => $composableBuilder(
    column: $table.source2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sutta2 => $composableBuilder(
    column: $table.sutta2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get example2 => $composableBuilder(
    column: $table.example2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootKey => $composableBuilder(
    column: $table.rootKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootSign => $composableBuilder(
    column: $table.rootSign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootBase => $composableBuilder(
    column: $table.rootBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyRoot => $composableBuilder(
    column: $table.familyRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyWord => $composableBuilder(
    column: $table.familyWord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyCompound => $composableBuilder(
    column: $table.familyCompound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyIdioms => $composableBuilder(
    column: $table.familyIdioms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get construction => $composableBuilder(
    column: $table.construction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compoundType => $composableBuilder(
    column: $table.compoundType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get antonym => $composableBuilder(
    column: $table.antonym,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synonym => $composableBuilder(
    column: $table.synonym,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stem => $composableBuilder(
    column: $table.stem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freqData => $composableBuilder(
    column: $table.freqData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lemmaIpa => $composableBuilder(
    column: $table.lemmaIpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ebtCount => $composableBuilder(
    column: $table.ebtCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nonIa => $composableBuilder(
    column: $table.nonIa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanskrit => $composableBuilder(
    column: $table.sanskrit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cognate => $composableBuilder(
    column: $table.cognate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get varPhonetic => $composableBuilder(
    column: $table.varPhonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get varText => $composableBuilder(
    column: $table.varText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentary => $composableBuilder(
    column: $table.commentary,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DpdHeadwordsTableAnnotationComposer
    extends Composer<_$DpdDatabase, $DpdHeadwordsTable> {
  $$DpdHeadwordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lemma1 =>
      $composableBuilder(column: $table.lemma1, builder: (column) => column);

  GeneratedColumn<String> get lemma2 =>
      $composableBuilder(column: $table.lemma2, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get grammar =>
      $composableBuilder(column: $table.grammar, builder: (column) => column);

  GeneratedColumn<String> get derivedFrom => $composableBuilder(
    column: $table.derivedFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get neg =>
      $composableBuilder(column: $table.neg, builder: (column) => column);

  GeneratedColumn<String> get verb =>
      $composableBuilder(column: $table.verb, builder: (column) => column);

  GeneratedColumn<String> get trans =>
      $composableBuilder(column: $table.trans, builder: (column) => column);

  GeneratedColumn<String> get plusCase =>
      $composableBuilder(column: $table.plusCase, builder: (column) => column);

  GeneratedColumn<String> get meaning1 =>
      $composableBuilder(column: $table.meaning1, builder: (column) => column);

  GeneratedColumn<String> get meaningLit => $composableBuilder(
    column: $table.meaningLit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meaning2 =>
      $composableBuilder(column: $table.meaning2, builder: (column) => column);

  GeneratedColumn<String> get source1 =>
      $composableBuilder(column: $table.source1, builder: (column) => column);

  GeneratedColumn<String> get sutta1 =>
      $composableBuilder(column: $table.sutta1, builder: (column) => column);

  GeneratedColumn<String> get example1 =>
      $composableBuilder(column: $table.example1, builder: (column) => column);

  GeneratedColumn<String> get source2 =>
      $composableBuilder(column: $table.source2, builder: (column) => column);

  GeneratedColumn<String> get sutta2 =>
      $composableBuilder(column: $table.sutta2, builder: (column) => column);

  GeneratedColumn<String> get example2 =>
      $composableBuilder(column: $table.example2, builder: (column) => column);

  GeneratedColumn<String> get rootKey =>
      $composableBuilder(column: $table.rootKey, builder: (column) => column);

  GeneratedColumn<String> get rootSign =>
      $composableBuilder(column: $table.rootSign, builder: (column) => column);

  GeneratedColumn<String> get rootBase =>
      $composableBuilder(column: $table.rootBase, builder: (column) => column);

  GeneratedColumn<String> get familyRoot => $composableBuilder(
    column: $table.familyRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyWord => $composableBuilder(
    column: $table.familyWord,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyCompound => $composableBuilder(
    column: $table.familyCompound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyIdioms => $composableBuilder(
    column: $table.familyIdioms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get construction => $composableBuilder(
    column: $table.construction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compoundType => $composableBuilder(
    column: $table.compoundType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get antonym =>
      $composableBuilder(column: $table.antonym, builder: (column) => column);

  GeneratedColumn<String> get synonym =>
      $composableBuilder(column: $table.synonym, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<String> get stem =>
      $composableBuilder(column: $table.stem, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<String> get freqData =>
      $composableBuilder(column: $table.freqData, builder: (column) => column);

  GeneratedColumn<String> get lemmaIpa =>
      $composableBuilder(column: $table.lemmaIpa, builder: (column) => column);

  GeneratedColumn<int> get ebtCount =>
      $composableBuilder(column: $table.ebtCount, builder: (column) => column);

  GeneratedColumn<String> get nonIa =>
      $composableBuilder(column: $table.nonIa, builder: (column) => column);

  GeneratedColumn<String> get sanskrit =>
      $composableBuilder(column: $table.sanskrit, builder: (column) => column);

  GeneratedColumn<String> get cognate =>
      $composableBuilder(column: $table.cognate, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<String> get phonetic =>
      $composableBuilder(column: $table.phonetic, builder: (column) => column);

  GeneratedColumn<String> get varPhonetic => $composableBuilder(
    column: $table.varPhonetic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get varText =>
      $composableBuilder(column: $table.varText, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get commentary => $composableBuilder(
    column: $table.commentary,
    builder: (column) => column,
  );
}

class $$DpdHeadwordsTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $DpdHeadwordsTable,
          DpdHeadword,
          $$DpdHeadwordsTableFilterComposer,
          $$DpdHeadwordsTableOrderingComposer,
          $$DpdHeadwordsTableAnnotationComposer,
          $$DpdHeadwordsTableCreateCompanionBuilder,
          $$DpdHeadwordsTableUpdateCompanionBuilder,
          (
            DpdHeadword,
            BaseReferences<_$DpdDatabase, $DpdHeadwordsTable, DpdHeadword>,
          ),
          DpdHeadword,
          PrefetchHooks Function()
        > {
  $$DpdHeadwordsTableTableManager(_$DpdDatabase db, $DpdHeadwordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DpdHeadwordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DpdHeadwordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DpdHeadwordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> lemma1 = const Value.absent(),
                Value<String?> lemma2 = const Value.absent(),
                Value<String?> pos = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> derivedFrom = const Value.absent(),
                Value<String?> neg = const Value.absent(),
                Value<String?> verb = const Value.absent(),
                Value<String?> trans = const Value.absent(),
                Value<String?> plusCase = const Value.absent(),
                Value<String?> meaning1 = const Value.absent(),
                Value<String?> meaningLit = const Value.absent(),
                Value<String?> meaning2 = const Value.absent(),
                Value<String?> source1 = const Value.absent(),
                Value<String?> sutta1 = const Value.absent(),
                Value<String?> example1 = const Value.absent(),
                Value<String?> source2 = const Value.absent(),
                Value<String?> sutta2 = const Value.absent(),
                Value<String?> example2 = const Value.absent(),
                Value<String?> rootKey = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootBase = const Value.absent(),
                Value<String?> familyRoot = const Value.absent(),
                Value<String?> familyWord = const Value.absent(),
                Value<String?> familyCompound = const Value.absent(),
                Value<String?> familyIdioms = const Value.absent(),
                Value<String?> construction = const Value.absent(),
                Value<String?> compoundType = const Value.absent(),
                Value<String?> antonym = const Value.absent(),
                Value<String?> synonym = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> stem = const Value.absent(),
                Value<String?> pattern = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> freqData = const Value.absent(),
                Value<String?> lemmaIpa = const Value.absent(),
                Value<int?> ebtCount = const Value.absent(),
                Value<String?> nonIa = const Value.absent(),
                Value<String?> sanskrit = const Value.absent(),
                Value<String?> cognate = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<String?> phonetic = const Value.absent(),
                Value<String?> varPhonetic = const Value.absent(),
                Value<String?> varText = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> commentary = const Value.absent(),
              }) => DpdHeadwordsCompanion(
                id: id,
                lemma1: lemma1,
                lemma2: lemma2,
                pos: pos,
                grammar: grammar,
                derivedFrom: derivedFrom,
                neg: neg,
                verb: verb,
                trans: trans,
                plusCase: plusCase,
                meaning1: meaning1,
                meaningLit: meaningLit,
                meaning2: meaning2,
                source1: source1,
                sutta1: sutta1,
                example1: example1,
                source2: source2,
                sutta2: sutta2,
                example2: example2,
                rootKey: rootKey,
                rootSign: rootSign,
                rootBase: rootBase,
                familyRoot: familyRoot,
                familyWord: familyWord,
                familyCompound: familyCompound,
                familyIdioms: familyIdioms,
                construction: construction,
                compoundType: compoundType,
                antonym: antonym,
                synonym: synonym,
                variant: variant,
                stem: stem,
                pattern: pattern,
                suffix: suffix,
                freqData: freqData,
                lemmaIpa: lemmaIpa,
                ebtCount: ebtCount,
                nonIa: nonIa,
                sanskrit: sanskrit,
                cognate: cognate,
                link: link,
                phonetic: phonetic,
                varPhonetic: varPhonetic,
                varText: varText,
                origin: origin,
                notes: notes,
                commentary: commentary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String lemma1,
                Value<String?> lemma2 = const Value.absent(),
                Value<String?> pos = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> derivedFrom = const Value.absent(),
                Value<String?> neg = const Value.absent(),
                Value<String?> verb = const Value.absent(),
                Value<String?> trans = const Value.absent(),
                Value<String?> plusCase = const Value.absent(),
                Value<String?> meaning1 = const Value.absent(),
                Value<String?> meaningLit = const Value.absent(),
                Value<String?> meaning2 = const Value.absent(),
                Value<String?> source1 = const Value.absent(),
                Value<String?> sutta1 = const Value.absent(),
                Value<String?> example1 = const Value.absent(),
                Value<String?> source2 = const Value.absent(),
                Value<String?> sutta2 = const Value.absent(),
                Value<String?> example2 = const Value.absent(),
                Value<String?> rootKey = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootBase = const Value.absent(),
                Value<String?> familyRoot = const Value.absent(),
                Value<String?> familyWord = const Value.absent(),
                Value<String?> familyCompound = const Value.absent(),
                Value<String?> familyIdioms = const Value.absent(),
                Value<String?> construction = const Value.absent(),
                Value<String?> compoundType = const Value.absent(),
                Value<String?> antonym = const Value.absent(),
                Value<String?> synonym = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> stem = const Value.absent(),
                Value<String?> pattern = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> freqData = const Value.absent(),
                Value<String?> lemmaIpa = const Value.absent(),
                Value<int?> ebtCount = const Value.absent(),
                Value<String?> nonIa = const Value.absent(),
                Value<String?> sanskrit = const Value.absent(),
                Value<String?> cognate = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<String?> phonetic = const Value.absent(),
                Value<String?> varPhonetic = const Value.absent(),
                Value<String?> varText = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> commentary = const Value.absent(),
              }) => DpdHeadwordsCompanion.insert(
                id: id,
                lemma1: lemma1,
                lemma2: lemma2,
                pos: pos,
                grammar: grammar,
                derivedFrom: derivedFrom,
                neg: neg,
                verb: verb,
                trans: trans,
                plusCase: plusCase,
                meaning1: meaning1,
                meaningLit: meaningLit,
                meaning2: meaning2,
                source1: source1,
                sutta1: sutta1,
                example1: example1,
                source2: source2,
                sutta2: sutta2,
                example2: example2,
                rootKey: rootKey,
                rootSign: rootSign,
                rootBase: rootBase,
                familyRoot: familyRoot,
                familyWord: familyWord,
                familyCompound: familyCompound,
                familyIdioms: familyIdioms,
                construction: construction,
                compoundType: compoundType,
                antonym: antonym,
                synonym: synonym,
                variant: variant,
                stem: stem,
                pattern: pattern,
                suffix: suffix,
                freqData: freqData,
                lemmaIpa: lemmaIpa,
                ebtCount: ebtCount,
                nonIa: nonIa,
                sanskrit: sanskrit,
                cognate: cognate,
                link: link,
                phonetic: phonetic,
                varPhonetic: varPhonetic,
                varText: varText,
                origin: origin,
                notes: notes,
                commentary: commentary,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DpdHeadwordsTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $DpdHeadwordsTable,
      DpdHeadword,
      $$DpdHeadwordsTableFilterComposer,
      $$DpdHeadwordsTableOrderingComposer,
      $$DpdHeadwordsTableAnnotationComposer,
      $$DpdHeadwordsTableCreateCompanionBuilder,
      $$DpdHeadwordsTableUpdateCompanionBuilder,
      (
        DpdHeadword,
        BaseReferences<_$DpdDatabase, $DpdHeadwordsTable, DpdHeadword>,
      ),
      DpdHeadword,
      PrefetchHooks Function()
    >;
typedef $$DpdRootsTableCreateCompanionBuilder =
    DpdRootsCompanion Function({
      required String root,
      Value<String?> rootInComps,
      Value<String?> rootHasVerb,
      Value<String?> rootGroup,
      Value<String?> rootSign,
      Value<String?> rootMeaning,
      Value<String?> sanskritRoot,
      Value<String?> sanskritRootMeaning,
      Value<String?> sanskritRootClass,
      Value<String?> rootExample,
      Value<String?> note,
      Value<int?> rootCount,
      Value<int> rowid,
    });
typedef $$DpdRootsTableUpdateCompanionBuilder =
    DpdRootsCompanion Function({
      Value<String> root,
      Value<String?> rootInComps,
      Value<String?> rootHasVerb,
      Value<String?> rootGroup,
      Value<String?> rootSign,
      Value<String?> rootMeaning,
      Value<String?> sanskritRoot,
      Value<String?> sanskritRootMeaning,
      Value<String?> sanskritRootClass,
      Value<String?> rootExample,
      Value<String?> note,
      Value<int?> rootCount,
      Value<int> rowid,
    });

class $$DpdRootsTableFilterComposer
    extends Composer<_$DpdDatabase, $DpdRootsTable> {
  $$DpdRootsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get root => $composableBuilder(
    column: $table.root,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootInComps => $composableBuilder(
    column: $table.rootInComps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootHasVerb => $composableBuilder(
    column: $table.rootHasVerb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootGroup => $composableBuilder(
    column: $table.rootGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootSign => $composableBuilder(
    column: $table.rootSign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanskritRoot => $composableBuilder(
    column: $table.sanskritRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanskritRootMeaning => $composableBuilder(
    column: $table.sanskritRootMeaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sanskritRootClass => $composableBuilder(
    column: $table.sanskritRootClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootExample => $composableBuilder(
    column: $table.rootExample,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rootCount => $composableBuilder(
    column: $table.rootCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DpdRootsTableOrderingComposer
    extends Composer<_$DpdDatabase, $DpdRootsTable> {
  $$DpdRootsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get root => $composableBuilder(
    column: $table.root,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootInComps => $composableBuilder(
    column: $table.rootInComps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootHasVerb => $composableBuilder(
    column: $table.rootHasVerb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootGroup => $composableBuilder(
    column: $table.rootGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootSign => $composableBuilder(
    column: $table.rootSign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanskritRoot => $composableBuilder(
    column: $table.sanskritRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanskritRootMeaning => $composableBuilder(
    column: $table.sanskritRootMeaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sanskritRootClass => $composableBuilder(
    column: $table.sanskritRootClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootExample => $composableBuilder(
    column: $table.rootExample,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rootCount => $composableBuilder(
    column: $table.rootCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DpdRootsTableAnnotationComposer
    extends Composer<_$DpdDatabase, $DpdRootsTable> {
  $$DpdRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get root =>
      $composableBuilder(column: $table.root, builder: (column) => column);

  GeneratedColumn<String> get rootInComps => $composableBuilder(
    column: $table.rootInComps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootHasVerb => $composableBuilder(
    column: $table.rootHasVerb,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootGroup =>
      $composableBuilder(column: $table.rootGroup, builder: (column) => column);

  GeneratedColumn<String> get rootSign =>
      $composableBuilder(column: $table.rootSign, builder: (column) => column);

  GeneratedColumn<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanskritRoot => $composableBuilder(
    column: $table.sanskritRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanskritRootMeaning => $composableBuilder(
    column: $table.sanskritRootMeaning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sanskritRootClass => $composableBuilder(
    column: $table.sanskritRootClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootExample => $composableBuilder(
    column: $table.rootExample,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get rootCount =>
      $composableBuilder(column: $table.rootCount, builder: (column) => column);
}

class $$DpdRootsTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $DpdRootsTable,
          DpdRoot,
          $$DpdRootsTableFilterComposer,
          $$DpdRootsTableOrderingComposer,
          $$DpdRootsTableAnnotationComposer,
          $$DpdRootsTableCreateCompanionBuilder,
          $$DpdRootsTableUpdateCompanionBuilder,
          (DpdRoot, BaseReferences<_$DpdDatabase, $DpdRootsTable, DpdRoot>),
          DpdRoot,
          PrefetchHooks Function()
        > {
  $$DpdRootsTableTableManager(_$DpdDatabase db, $DpdRootsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DpdRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DpdRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DpdRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> root = const Value.absent(),
                Value<String?> rootInComps = const Value.absent(),
                Value<String?> rootHasVerb = const Value.absent(),
                Value<String?> rootGroup = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootMeaning = const Value.absent(),
                Value<String?> sanskritRoot = const Value.absent(),
                Value<String?> sanskritRootMeaning = const Value.absent(),
                Value<String?> sanskritRootClass = const Value.absent(),
                Value<String?> rootExample = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> rootCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DpdRootsCompanion(
                root: root,
                rootInComps: rootInComps,
                rootHasVerb: rootHasVerb,
                rootGroup: rootGroup,
                rootSign: rootSign,
                rootMeaning: rootMeaning,
                sanskritRoot: sanskritRoot,
                sanskritRootMeaning: sanskritRootMeaning,
                sanskritRootClass: sanskritRootClass,
                rootExample: rootExample,
                note: note,
                rootCount: rootCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String root,
                Value<String?> rootInComps = const Value.absent(),
                Value<String?> rootHasVerb = const Value.absent(),
                Value<String?> rootGroup = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootMeaning = const Value.absent(),
                Value<String?> sanskritRoot = const Value.absent(),
                Value<String?> sanskritRootMeaning = const Value.absent(),
                Value<String?> sanskritRootClass = const Value.absent(),
                Value<String?> rootExample = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> rootCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DpdRootsCompanion.insert(
                root: root,
                rootInComps: rootInComps,
                rootHasVerb: rootHasVerb,
                rootGroup: rootGroup,
                rootSign: rootSign,
                rootMeaning: rootMeaning,
                sanskritRoot: sanskritRoot,
                sanskritRootMeaning: sanskritRootMeaning,
                sanskritRootClass: sanskritRootClass,
                rootExample: rootExample,
                note: note,
                rootCount: rootCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DpdRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $DpdRootsTable,
      DpdRoot,
      $$DpdRootsTableFilterComposer,
      $$DpdRootsTableOrderingComposer,
      $$DpdRootsTableAnnotationComposer,
      $$DpdRootsTableCreateCompanionBuilder,
      $$DpdRootsTableUpdateCompanionBuilder,
      (DpdRoot, BaseReferences<_$DpdDatabase, $DpdRootsTable, DpdRoot>),
      DpdRoot,
      PrefetchHooks Function()
    >;
typedef $$LookupTableCreateCompanionBuilder =
    LookupCompanion Function({
      required String lookupKey,
      Value<String?> headwords,
      Value<String?> roots,
      Value<String?> variant,
      Value<String?> spelling,
      Value<String?> grammar,
      Value<String?> help,
      Value<String?> abbrev,
      Value<String?> deconstructor,
      Value<String?> epd,
      Value<String?> fuzzyKey,
      Value<int> rowid,
    });
typedef $$LookupTableUpdateCompanionBuilder =
    LookupCompanion Function({
      Value<String> lookupKey,
      Value<String?> headwords,
      Value<String?> roots,
      Value<String?> variant,
      Value<String?> spelling,
      Value<String?> grammar,
      Value<String?> help,
      Value<String?> abbrev,
      Value<String?> deconstructor,
      Value<String?> epd,
      Value<String?> fuzzyKey,
      Value<int> rowid,
    });

class $$LookupTableFilterComposer
    extends Composer<_$DpdDatabase, $LookupTable> {
  $$LookupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lookupKey => $composableBuilder(
    column: $table.lookupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headwords => $composableBuilder(
    column: $table.headwords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roots => $composableBuilder(
    column: $table.roots,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spelling => $composableBuilder(
    column: $table.spelling,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammar => $composableBuilder(
    column: $table.grammar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get help => $composableBuilder(
    column: $table.help,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abbrev => $composableBuilder(
    column: $table.abbrev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deconstructor => $composableBuilder(
    column: $table.deconstructor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epd => $composableBuilder(
    column: $table.epd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuzzyKey => $composableBuilder(
    column: $table.fuzzyKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LookupTableOrderingComposer
    extends Composer<_$DpdDatabase, $LookupTable> {
  $$LookupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lookupKey => $composableBuilder(
    column: $table.lookupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headwords => $composableBuilder(
    column: $table.headwords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roots => $composableBuilder(
    column: $table.roots,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spelling => $composableBuilder(
    column: $table.spelling,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammar => $composableBuilder(
    column: $table.grammar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get help => $composableBuilder(
    column: $table.help,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abbrev => $composableBuilder(
    column: $table.abbrev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deconstructor => $composableBuilder(
    column: $table.deconstructor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epd => $composableBuilder(
    column: $table.epd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuzzyKey => $composableBuilder(
    column: $table.fuzzyKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LookupTableAnnotationComposer
    extends Composer<_$DpdDatabase, $LookupTable> {
  $$LookupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lookupKey =>
      $composableBuilder(column: $table.lookupKey, builder: (column) => column);

  GeneratedColumn<String> get headwords =>
      $composableBuilder(column: $table.headwords, builder: (column) => column);

  GeneratedColumn<String> get roots =>
      $composableBuilder(column: $table.roots, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<String> get spelling =>
      $composableBuilder(column: $table.spelling, builder: (column) => column);

  GeneratedColumn<String> get grammar =>
      $composableBuilder(column: $table.grammar, builder: (column) => column);

  GeneratedColumn<String> get help =>
      $composableBuilder(column: $table.help, builder: (column) => column);

  GeneratedColumn<String> get abbrev =>
      $composableBuilder(column: $table.abbrev, builder: (column) => column);

  GeneratedColumn<String> get deconstructor => $composableBuilder(
    column: $table.deconstructor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epd =>
      $composableBuilder(column: $table.epd, builder: (column) => column);

  GeneratedColumn<String> get fuzzyKey =>
      $composableBuilder(column: $table.fuzzyKey, builder: (column) => column);
}

class $$LookupTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $LookupTable,
          LookupData,
          $$LookupTableFilterComposer,
          $$LookupTableOrderingComposer,
          $$LookupTableAnnotationComposer,
          $$LookupTableCreateCompanionBuilder,
          $$LookupTableUpdateCompanionBuilder,
          (LookupData, BaseReferences<_$DpdDatabase, $LookupTable, LookupData>),
          LookupData,
          PrefetchHooks Function()
        > {
  $$LookupTableTableManager(_$DpdDatabase db, $LookupTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LookupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LookupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LookupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lookupKey = const Value.absent(),
                Value<String?> headwords = const Value.absent(),
                Value<String?> roots = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> spelling = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> help = const Value.absent(),
                Value<String?> abbrev = const Value.absent(),
                Value<String?> deconstructor = const Value.absent(),
                Value<String?> epd = const Value.absent(),
                Value<String?> fuzzyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupCompanion(
                lookupKey: lookupKey,
                headwords: headwords,
                roots: roots,
                variant: variant,
                spelling: spelling,
                grammar: grammar,
                help: help,
                abbrev: abbrev,
                deconstructor: deconstructor,
                epd: epd,
                fuzzyKey: fuzzyKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lookupKey,
                Value<String?> headwords = const Value.absent(),
                Value<String?> roots = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> spelling = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> help = const Value.absent(),
                Value<String?> abbrev = const Value.absent(),
                Value<String?> deconstructor = const Value.absent(),
                Value<String?> epd = const Value.absent(),
                Value<String?> fuzzyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupCompanion.insert(
                lookupKey: lookupKey,
                headwords: headwords,
                roots: roots,
                variant: variant,
                spelling: spelling,
                grammar: grammar,
                help: help,
                abbrev: abbrev,
                deconstructor: deconstructor,
                epd: epd,
                fuzzyKey: fuzzyKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LookupTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $LookupTable,
      LookupData,
      $$LookupTableFilterComposer,
      $$LookupTableOrderingComposer,
      $$LookupTableAnnotationComposer,
      $$LookupTableCreateCompanionBuilder,
      $$LookupTableUpdateCompanionBuilder,
      (LookupData, BaseReferences<_$DpdDatabase, $LookupTable, LookupData>),
      LookupData,
      PrefetchHooks Function()
    >;

class $DpdDatabaseManager {
  final _$DpdDatabase _db;
  $DpdDatabaseManager(this._db);
  $$DictMetaTableTableManager get dictMeta =>
      $$DictMetaTableTableManager(_db, _db.dictMeta);
  $$DictEntriesTableTableManager get dictEntries =>
      $$DictEntriesTableTableManager(_db, _db.dictEntries);
  $$DpdHeadwordsTableTableManager get dpdHeadwords =>
      $$DpdHeadwordsTableTableManager(_db, _db.dpdHeadwords);
  $$DpdRootsTableTableManager get dpdRoots =>
      $$DpdRootsTableTableManager(_db, _db.dpdRoots);
  $$LookupTableTableManager get lookup =>
      $$LookupTableTableManager(_db, _db.lookup);
}
