// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dpd_database.dart';

// ignore_for_file: type=lint
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootHasVerbMeta = const VerificationMeta(
    'rootHasVerb',
  );
  @override
  late final GeneratedColumn<String> rootHasVerb = GeneratedColumn<String>(
    'root_has_verb',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootGroupMeta = const VerificationMeta(
    'rootGroup',
  );
  @override
  late final GeneratedColumn<int> rootGroup = GeneratedColumn<int>(
    'root_group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootSignMeta = const VerificationMeta(
    'rootSign',
  );
  @override
  late final GeneratedColumn<String> rootSign = GeneratedColumn<String>(
    'root_sign',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootMeaningMeta = const VerificationMeta(
    'rootMeaning',
  );
  @override
  late final GeneratedColumn<String> rootMeaning = GeneratedColumn<String>(
    'root_meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanskritRootMeta = const VerificationMeta(
    'sanskritRoot',
  );
  @override
  late final GeneratedColumn<String> sanskritRoot = GeneratedColumn<String>(
    'sanskrit_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanskritRootMeaningMeta =
      const VerificationMeta('sanskritRootMeaning');
  @override
  late final GeneratedColumn<String> sanskritRootMeaning =
      GeneratedColumn<String>(
        'sanskrit_root_meaning',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sanskritRootClassMeta = const VerificationMeta(
    'sanskritRootClass',
  );
  @override
  late final GeneratedColumn<String> sanskritRootClass =
      GeneratedColumn<String>(
        'sanskrit_root_class',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _rootExampleMeta = const VerificationMeta(
    'rootExample',
  );
  @override
  late final GeneratedColumn<String> rootExample = GeneratedColumn<String>(
    'root_example',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatupathaNumMeta = const VerificationMeta(
    'dhatupathaNum',
  );
  @override
  late final GeneratedColumn<String> dhatupathaNum = GeneratedColumn<String>(
    'dhatupatha_num',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatupathaRootMeta = const VerificationMeta(
    'dhatupathaRoot',
  );
  @override
  late final GeneratedColumn<String> dhatupathaRoot = GeneratedColumn<String>(
    'dhatupatha_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatupathaPaliMeta = const VerificationMeta(
    'dhatupathaPali',
  );
  @override
  late final GeneratedColumn<String> dhatupathaPali = GeneratedColumn<String>(
    'dhatupatha_pali',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatupathaEnglishMeta = const VerificationMeta(
    'dhatupathaEnglish',
  );
  @override
  late final GeneratedColumn<String> dhatupathaEnglish =
      GeneratedColumn<String>(
        'dhatupatha_english',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dhatumanjusaNumMeta = const VerificationMeta(
    'dhatumanjusaNum',
  );
  @override
  late final GeneratedColumn<String> dhatumanjusaNum = GeneratedColumn<String>(
    'dhatumanjusa_num',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatumanjusaRootMeta = const VerificationMeta(
    'dhatumanjusaRoot',
  );
  @override
  late final GeneratedColumn<String> dhatumanjusaRoot = GeneratedColumn<String>(
    'dhatumanjusa_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatumanjusaPaliMeta = const VerificationMeta(
    'dhatumanjusaPali',
  );
  @override
  late final GeneratedColumn<String> dhatumanjusaPali = GeneratedColumn<String>(
    'dhatumanjusa_pali',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatumanjusaEnglishMeta =
      const VerificationMeta('dhatumanjusaEnglish');
  @override
  late final GeneratedColumn<String> dhatumanjusaEnglish =
      GeneratedColumn<String>(
        'dhatumanjusa_english',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dhatumalaRootMeta = const VerificationMeta(
    'dhatumalaRoot',
  );
  @override
  late final GeneratedColumn<String> dhatumalaRoot = GeneratedColumn<String>(
    'dhatumala_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatumalaPaliMeta = const VerificationMeta(
    'dhatumalaPali',
  );
  @override
  late final GeneratedColumn<String> dhatumalaPali = GeneratedColumn<String>(
    'dhatumala_pali',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhatumalaEnglishMeta = const VerificationMeta(
    'dhatumalaEnglish',
  );
  @override
  late final GeneratedColumn<String> dhatumalaEnglish = GeneratedColumn<String>(
    'dhatumala_english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paniniRootMeta = const VerificationMeta(
    'paniniRoot',
  );
  @override
  late final GeneratedColumn<String> paniniRoot = GeneratedColumn<String>(
    'panini_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paniniSanskritMeta = const VerificationMeta(
    'paniniSanskrit',
  );
  @override
  late final GeneratedColumn<String> paniniSanskrit = GeneratedColumn<String>(
    'panini_sanskrit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paniniEnglishMeta = const VerificationMeta(
    'paniniEnglish',
  );
  @override
  late final GeneratedColumn<String> paniniEnglish = GeneratedColumn<String>(
    'panini_english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    dhatupathaNum,
    dhatupathaRoot,
    dhatupathaPali,
    dhatupathaEnglish,
    dhatumanjusaNum,
    dhatumanjusaRoot,
    dhatumanjusaPali,
    dhatumanjusaEnglish,
    dhatumalaRoot,
    dhatumalaPali,
    dhatumalaEnglish,
    paniniRoot,
    paniniSanskrit,
    paniniEnglish,
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
    } else if (isInserting) {
      context.missing(_rootInCompsMeta);
    }
    if (data.containsKey('root_has_verb')) {
      context.handle(
        _rootHasVerbMeta,
        rootHasVerb.isAcceptableOrUnknown(
          data['root_has_verb']!,
          _rootHasVerbMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootHasVerbMeta);
    }
    if (data.containsKey('root_group')) {
      context.handle(
        _rootGroupMeta,
        rootGroup.isAcceptableOrUnknown(data['root_group']!, _rootGroupMeta),
      );
    } else if (isInserting) {
      context.missing(_rootGroupMeta);
    }
    if (data.containsKey('root_sign')) {
      context.handle(
        _rootSignMeta,
        rootSign.isAcceptableOrUnknown(data['root_sign']!, _rootSignMeta),
      );
    } else if (isInserting) {
      context.missing(_rootSignMeta);
    }
    if (data.containsKey('root_meaning')) {
      context.handle(
        _rootMeaningMeta,
        rootMeaning.isAcceptableOrUnknown(
          data['root_meaning']!,
          _rootMeaningMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootMeaningMeta);
    }
    if (data.containsKey('sanskrit_root')) {
      context.handle(
        _sanskritRootMeta,
        sanskritRoot.isAcceptableOrUnknown(
          data['sanskrit_root']!,
          _sanskritRootMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sanskritRootMeta);
    }
    if (data.containsKey('sanskrit_root_meaning')) {
      context.handle(
        _sanskritRootMeaningMeta,
        sanskritRootMeaning.isAcceptableOrUnknown(
          data['sanskrit_root_meaning']!,
          _sanskritRootMeaningMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sanskritRootMeaningMeta);
    }
    if (data.containsKey('sanskrit_root_class')) {
      context.handle(
        _sanskritRootClassMeta,
        sanskritRootClass.isAcceptableOrUnknown(
          data['sanskrit_root_class']!,
          _sanskritRootClassMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sanskritRootClassMeta);
    }
    if (data.containsKey('root_example')) {
      context.handle(
        _rootExampleMeta,
        rootExample.isAcceptableOrUnknown(
          data['root_example']!,
          _rootExampleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootExampleMeta);
    }
    if (data.containsKey('dhatupatha_num')) {
      context.handle(
        _dhatupathaNumMeta,
        dhatupathaNum.isAcceptableOrUnknown(
          data['dhatupatha_num']!,
          _dhatupathaNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatupathaNumMeta);
    }
    if (data.containsKey('dhatupatha_root')) {
      context.handle(
        _dhatupathaRootMeta,
        dhatupathaRoot.isAcceptableOrUnknown(
          data['dhatupatha_root']!,
          _dhatupathaRootMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatupathaRootMeta);
    }
    if (data.containsKey('dhatupatha_pali')) {
      context.handle(
        _dhatupathaPaliMeta,
        dhatupathaPali.isAcceptableOrUnknown(
          data['dhatupatha_pali']!,
          _dhatupathaPaliMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatupathaPaliMeta);
    }
    if (data.containsKey('dhatupatha_english')) {
      context.handle(
        _dhatupathaEnglishMeta,
        dhatupathaEnglish.isAcceptableOrUnknown(
          data['dhatupatha_english']!,
          _dhatupathaEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatupathaEnglishMeta);
    }
    if (data.containsKey('dhatumanjusa_num')) {
      context.handle(
        _dhatumanjusaNumMeta,
        dhatumanjusaNum.isAcceptableOrUnknown(
          data['dhatumanjusa_num']!,
          _dhatumanjusaNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumanjusaNumMeta);
    }
    if (data.containsKey('dhatumanjusa_root')) {
      context.handle(
        _dhatumanjusaRootMeta,
        dhatumanjusaRoot.isAcceptableOrUnknown(
          data['dhatumanjusa_root']!,
          _dhatumanjusaRootMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumanjusaRootMeta);
    }
    if (data.containsKey('dhatumanjusa_pali')) {
      context.handle(
        _dhatumanjusaPaliMeta,
        dhatumanjusaPali.isAcceptableOrUnknown(
          data['dhatumanjusa_pali']!,
          _dhatumanjusaPaliMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumanjusaPaliMeta);
    }
    if (data.containsKey('dhatumanjusa_english')) {
      context.handle(
        _dhatumanjusaEnglishMeta,
        dhatumanjusaEnglish.isAcceptableOrUnknown(
          data['dhatumanjusa_english']!,
          _dhatumanjusaEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumanjusaEnglishMeta);
    }
    if (data.containsKey('dhatumala_root')) {
      context.handle(
        _dhatumalaRootMeta,
        dhatumalaRoot.isAcceptableOrUnknown(
          data['dhatumala_root']!,
          _dhatumalaRootMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumalaRootMeta);
    }
    if (data.containsKey('dhatumala_pali')) {
      context.handle(
        _dhatumalaPaliMeta,
        dhatumalaPali.isAcceptableOrUnknown(
          data['dhatumala_pali']!,
          _dhatumalaPaliMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumalaPaliMeta);
    }
    if (data.containsKey('dhatumala_english')) {
      context.handle(
        _dhatumalaEnglishMeta,
        dhatumalaEnglish.isAcceptableOrUnknown(
          data['dhatumala_english']!,
          _dhatumalaEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dhatumalaEnglishMeta);
    }
    if (data.containsKey('panini_root')) {
      context.handle(
        _paniniRootMeta,
        paniniRoot.isAcceptableOrUnknown(data['panini_root']!, _paniniRootMeta),
      );
    } else if (isInserting) {
      context.missing(_paniniRootMeta);
    }
    if (data.containsKey('panini_sanskrit')) {
      context.handle(
        _paniniSanskritMeta,
        paniniSanskrit.isAcceptableOrUnknown(
          data['panini_sanskrit']!,
          _paniniSanskritMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paniniSanskritMeta);
    }
    if (data.containsKey('panini_english')) {
      context.handle(
        _paniniEnglishMeta,
        paniniEnglish.isAcceptableOrUnknown(
          data['panini_english']!,
          _paniniEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paniniEnglishMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
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
      )!,
      rootHasVerb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_has_verb'],
      )!,
      rootGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}root_group'],
      )!,
      rootSign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_sign'],
      )!,
      rootMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_meaning'],
      )!,
      sanskritRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root'],
      )!,
      sanskritRootMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root_meaning'],
      )!,
      sanskritRootClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanskrit_root_class'],
      )!,
      rootExample: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_example'],
      )!,
      dhatupathaNum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatupatha_num'],
      )!,
      dhatupathaRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatupatha_root'],
      )!,
      dhatupathaPali: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatupatha_pali'],
      )!,
      dhatupathaEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatupatha_english'],
      )!,
      dhatumanjusaNum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumanjusa_num'],
      )!,
      dhatumanjusaRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumanjusa_root'],
      )!,
      dhatumanjusaPali: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumanjusa_pali'],
      )!,
      dhatumanjusaEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumanjusa_english'],
      )!,
      dhatumalaRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumala_root'],
      )!,
      dhatumalaPali: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumala_pali'],
      )!,
      dhatumalaEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhatumala_english'],
      )!,
      paniniRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}panini_root'],
      )!,
      paniniSanskrit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}panini_sanskrit'],
      )!,
      paniniEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}panini_english'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
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
  final String rootInComps;
  final String rootHasVerb;
  final int rootGroup;
  final String rootSign;
  final String rootMeaning;
  final String sanskritRoot;
  final String sanskritRootMeaning;
  final String sanskritRootClass;
  final String rootExample;
  final String dhatupathaNum;
  final String dhatupathaRoot;
  final String dhatupathaPali;
  final String dhatupathaEnglish;
  final String dhatumanjusaNum;
  final String dhatumanjusaRoot;
  final String dhatumanjusaPali;
  final String dhatumanjusaEnglish;
  final String dhatumalaRoot;
  final String dhatumalaPali;
  final String dhatumalaEnglish;
  final String paniniRoot;
  final String paniniSanskrit;
  final String paniniEnglish;
  final String note;
  final int? rootCount;
  const DpdRoot({
    required this.root,
    required this.rootInComps,
    required this.rootHasVerb,
    required this.rootGroup,
    required this.rootSign,
    required this.rootMeaning,
    required this.sanskritRoot,
    required this.sanskritRootMeaning,
    required this.sanskritRootClass,
    required this.rootExample,
    required this.dhatupathaNum,
    required this.dhatupathaRoot,
    required this.dhatupathaPali,
    required this.dhatupathaEnglish,
    required this.dhatumanjusaNum,
    required this.dhatumanjusaRoot,
    required this.dhatumanjusaPali,
    required this.dhatumanjusaEnglish,
    required this.dhatumalaRoot,
    required this.dhatumalaPali,
    required this.dhatumalaEnglish,
    required this.paniniRoot,
    required this.paniniSanskrit,
    required this.paniniEnglish,
    required this.note,
    this.rootCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['root'] = Variable<String>(root);
    map['root_in_comps'] = Variable<String>(rootInComps);
    map['root_has_verb'] = Variable<String>(rootHasVerb);
    map['root_group'] = Variable<int>(rootGroup);
    map['root_sign'] = Variable<String>(rootSign);
    map['root_meaning'] = Variable<String>(rootMeaning);
    map['sanskrit_root'] = Variable<String>(sanskritRoot);
    map['sanskrit_root_meaning'] = Variable<String>(sanskritRootMeaning);
    map['sanskrit_root_class'] = Variable<String>(sanskritRootClass);
    map['root_example'] = Variable<String>(rootExample);
    map['dhatupatha_num'] = Variable<String>(dhatupathaNum);
    map['dhatupatha_root'] = Variable<String>(dhatupathaRoot);
    map['dhatupatha_pali'] = Variable<String>(dhatupathaPali);
    map['dhatupatha_english'] = Variable<String>(dhatupathaEnglish);
    map['dhatumanjusa_num'] = Variable<String>(dhatumanjusaNum);
    map['dhatumanjusa_root'] = Variable<String>(dhatumanjusaRoot);
    map['dhatumanjusa_pali'] = Variable<String>(dhatumanjusaPali);
    map['dhatumanjusa_english'] = Variable<String>(dhatumanjusaEnglish);
    map['dhatumala_root'] = Variable<String>(dhatumalaRoot);
    map['dhatumala_pali'] = Variable<String>(dhatumalaPali);
    map['dhatumala_english'] = Variable<String>(dhatumalaEnglish);
    map['panini_root'] = Variable<String>(paniniRoot);
    map['panini_sanskrit'] = Variable<String>(paniniSanskrit);
    map['panini_english'] = Variable<String>(paniniEnglish);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || rootCount != null) {
      map['root_count'] = Variable<int>(rootCount);
    }
    return map;
  }

  DpdRootsCompanion toCompanion(bool nullToAbsent) {
    return DpdRootsCompanion(
      root: Value(root),
      rootInComps: Value(rootInComps),
      rootHasVerb: Value(rootHasVerb),
      rootGroup: Value(rootGroup),
      rootSign: Value(rootSign),
      rootMeaning: Value(rootMeaning),
      sanskritRoot: Value(sanskritRoot),
      sanskritRootMeaning: Value(sanskritRootMeaning),
      sanskritRootClass: Value(sanskritRootClass),
      rootExample: Value(rootExample),
      dhatupathaNum: Value(dhatupathaNum),
      dhatupathaRoot: Value(dhatupathaRoot),
      dhatupathaPali: Value(dhatupathaPali),
      dhatupathaEnglish: Value(dhatupathaEnglish),
      dhatumanjusaNum: Value(dhatumanjusaNum),
      dhatumanjusaRoot: Value(dhatumanjusaRoot),
      dhatumanjusaPali: Value(dhatumanjusaPali),
      dhatumanjusaEnglish: Value(dhatumanjusaEnglish),
      dhatumalaRoot: Value(dhatumalaRoot),
      dhatumalaPali: Value(dhatumalaPali),
      dhatumalaEnglish: Value(dhatumalaEnglish),
      paniniRoot: Value(paniniRoot),
      paniniSanskrit: Value(paniniSanskrit),
      paniniEnglish: Value(paniniEnglish),
      note: Value(note),
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
      rootInComps: serializer.fromJson<String>(json['rootInComps']),
      rootHasVerb: serializer.fromJson<String>(json['rootHasVerb']),
      rootGroup: serializer.fromJson<int>(json['rootGroup']),
      rootSign: serializer.fromJson<String>(json['rootSign']),
      rootMeaning: serializer.fromJson<String>(json['rootMeaning']),
      sanskritRoot: serializer.fromJson<String>(json['sanskritRoot']),
      sanskritRootMeaning: serializer.fromJson<String>(
        json['sanskritRootMeaning'],
      ),
      sanskritRootClass: serializer.fromJson<String>(json['sanskritRootClass']),
      rootExample: serializer.fromJson<String>(json['rootExample']),
      dhatupathaNum: serializer.fromJson<String>(json['dhatupathaNum']),
      dhatupathaRoot: serializer.fromJson<String>(json['dhatupathaRoot']),
      dhatupathaPali: serializer.fromJson<String>(json['dhatupathaPali']),
      dhatupathaEnglish: serializer.fromJson<String>(json['dhatupathaEnglish']),
      dhatumanjusaNum: serializer.fromJson<String>(json['dhatumanjusaNum']),
      dhatumanjusaRoot: serializer.fromJson<String>(json['dhatumanjusaRoot']),
      dhatumanjusaPali: serializer.fromJson<String>(json['dhatumanjusaPali']),
      dhatumanjusaEnglish: serializer.fromJson<String>(
        json['dhatumanjusaEnglish'],
      ),
      dhatumalaRoot: serializer.fromJson<String>(json['dhatumalaRoot']),
      dhatumalaPali: serializer.fromJson<String>(json['dhatumalaPali']),
      dhatumalaEnglish: serializer.fromJson<String>(json['dhatumalaEnglish']),
      paniniRoot: serializer.fromJson<String>(json['paniniRoot']),
      paniniSanskrit: serializer.fromJson<String>(json['paniniSanskrit']),
      paniniEnglish: serializer.fromJson<String>(json['paniniEnglish']),
      note: serializer.fromJson<String>(json['note']),
      rootCount: serializer.fromJson<int?>(json['rootCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'root': serializer.toJson<String>(root),
      'rootInComps': serializer.toJson<String>(rootInComps),
      'rootHasVerb': serializer.toJson<String>(rootHasVerb),
      'rootGroup': serializer.toJson<int>(rootGroup),
      'rootSign': serializer.toJson<String>(rootSign),
      'rootMeaning': serializer.toJson<String>(rootMeaning),
      'sanskritRoot': serializer.toJson<String>(sanskritRoot),
      'sanskritRootMeaning': serializer.toJson<String>(sanskritRootMeaning),
      'sanskritRootClass': serializer.toJson<String>(sanskritRootClass),
      'rootExample': serializer.toJson<String>(rootExample),
      'dhatupathaNum': serializer.toJson<String>(dhatupathaNum),
      'dhatupathaRoot': serializer.toJson<String>(dhatupathaRoot),
      'dhatupathaPali': serializer.toJson<String>(dhatupathaPali),
      'dhatupathaEnglish': serializer.toJson<String>(dhatupathaEnglish),
      'dhatumanjusaNum': serializer.toJson<String>(dhatumanjusaNum),
      'dhatumanjusaRoot': serializer.toJson<String>(dhatumanjusaRoot),
      'dhatumanjusaPali': serializer.toJson<String>(dhatumanjusaPali),
      'dhatumanjusaEnglish': serializer.toJson<String>(dhatumanjusaEnglish),
      'dhatumalaRoot': serializer.toJson<String>(dhatumalaRoot),
      'dhatumalaPali': serializer.toJson<String>(dhatumalaPali),
      'dhatumalaEnglish': serializer.toJson<String>(dhatumalaEnglish),
      'paniniRoot': serializer.toJson<String>(paniniRoot),
      'paniniSanskrit': serializer.toJson<String>(paniniSanskrit),
      'paniniEnglish': serializer.toJson<String>(paniniEnglish),
      'note': serializer.toJson<String>(note),
      'rootCount': serializer.toJson<int?>(rootCount),
    };
  }

  DpdRoot copyWith({
    String? root,
    String? rootInComps,
    String? rootHasVerb,
    int? rootGroup,
    String? rootSign,
    String? rootMeaning,
    String? sanskritRoot,
    String? sanskritRootMeaning,
    String? sanskritRootClass,
    String? rootExample,
    String? dhatupathaNum,
    String? dhatupathaRoot,
    String? dhatupathaPali,
    String? dhatupathaEnglish,
    String? dhatumanjusaNum,
    String? dhatumanjusaRoot,
    String? dhatumanjusaPali,
    String? dhatumanjusaEnglish,
    String? dhatumalaRoot,
    String? dhatumalaPali,
    String? dhatumalaEnglish,
    String? paniniRoot,
    String? paniniSanskrit,
    String? paniniEnglish,
    String? note,
    Value<int?> rootCount = const Value.absent(),
  }) => DpdRoot(
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
    dhatupathaNum: dhatupathaNum ?? this.dhatupathaNum,
    dhatupathaRoot: dhatupathaRoot ?? this.dhatupathaRoot,
    dhatupathaPali: dhatupathaPali ?? this.dhatupathaPali,
    dhatupathaEnglish: dhatupathaEnglish ?? this.dhatupathaEnglish,
    dhatumanjusaNum: dhatumanjusaNum ?? this.dhatumanjusaNum,
    dhatumanjusaRoot: dhatumanjusaRoot ?? this.dhatumanjusaRoot,
    dhatumanjusaPali: dhatumanjusaPali ?? this.dhatumanjusaPali,
    dhatumanjusaEnglish: dhatumanjusaEnglish ?? this.dhatumanjusaEnglish,
    dhatumalaRoot: dhatumalaRoot ?? this.dhatumalaRoot,
    dhatumalaPali: dhatumalaPali ?? this.dhatumalaPali,
    dhatumalaEnglish: dhatumalaEnglish ?? this.dhatumalaEnglish,
    paniniRoot: paniniRoot ?? this.paniniRoot,
    paniniSanskrit: paniniSanskrit ?? this.paniniSanskrit,
    paniniEnglish: paniniEnglish ?? this.paniniEnglish,
    note: note ?? this.note,
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
      dhatupathaNum: data.dhatupathaNum.present
          ? data.dhatupathaNum.value
          : this.dhatupathaNum,
      dhatupathaRoot: data.dhatupathaRoot.present
          ? data.dhatupathaRoot.value
          : this.dhatupathaRoot,
      dhatupathaPali: data.dhatupathaPali.present
          ? data.dhatupathaPali.value
          : this.dhatupathaPali,
      dhatupathaEnglish: data.dhatupathaEnglish.present
          ? data.dhatupathaEnglish.value
          : this.dhatupathaEnglish,
      dhatumanjusaNum: data.dhatumanjusaNum.present
          ? data.dhatumanjusaNum.value
          : this.dhatumanjusaNum,
      dhatumanjusaRoot: data.dhatumanjusaRoot.present
          ? data.dhatumanjusaRoot.value
          : this.dhatumanjusaRoot,
      dhatumanjusaPali: data.dhatumanjusaPali.present
          ? data.dhatumanjusaPali.value
          : this.dhatumanjusaPali,
      dhatumanjusaEnglish: data.dhatumanjusaEnglish.present
          ? data.dhatumanjusaEnglish.value
          : this.dhatumanjusaEnglish,
      dhatumalaRoot: data.dhatumalaRoot.present
          ? data.dhatumalaRoot.value
          : this.dhatumalaRoot,
      dhatumalaPali: data.dhatumalaPali.present
          ? data.dhatumalaPali.value
          : this.dhatumalaPali,
      dhatumalaEnglish: data.dhatumalaEnglish.present
          ? data.dhatumalaEnglish.value
          : this.dhatumalaEnglish,
      paniniRoot: data.paniniRoot.present
          ? data.paniniRoot.value
          : this.paniniRoot,
      paniniSanskrit: data.paniniSanskrit.present
          ? data.paniniSanskrit.value
          : this.paniniSanskrit,
      paniniEnglish: data.paniniEnglish.present
          ? data.paniniEnglish.value
          : this.paniniEnglish,
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
          ..write('dhatupathaNum: $dhatupathaNum, ')
          ..write('dhatupathaRoot: $dhatupathaRoot, ')
          ..write('dhatupathaPali: $dhatupathaPali, ')
          ..write('dhatupathaEnglish: $dhatupathaEnglish, ')
          ..write('dhatumanjusaNum: $dhatumanjusaNum, ')
          ..write('dhatumanjusaRoot: $dhatumanjusaRoot, ')
          ..write('dhatumanjusaPali: $dhatumanjusaPali, ')
          ..write('dhatumanjusaEnglish: $dhatumanjusaEnglish, ')
          ..write('dhatumalaRoot: $dhatumalaRoot, ')
          ..write('dhatumalaPali: $dhatumalaPali, ')
          ..write('dhatumalaEnglish: $dhatumalaEnglish, ')
          ..write('paniniRoot: $paniniRoot, ')
          ..write('paniniSanskrit: $paniniSanskrit, ')
          ..write('paniniEnglish: $paniniEnglish, ')
          ..write('note: $note, ')
          ..write('rootCount: $rootCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    dhatupathaNum,
    dhatupathaRoot,
    dhatupathaPali,
    dhatupathaEnglish,
    dhatumanjusaNum,
    dhatumanjusaRoot,
    dhatumanjusaPali,
    dhatumanjusaEnglish,
    dhatumalaRoot,
    dhatumalaPali,
    dhatumalaEnglish,
    paniniRoot,
    paniniSanskrit,
    paniniEnglish,
    note,
    rootCount,
  ]);
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
          other.dhatupathaNum == this.dhatupathaNum &&
          other.dhatupathaRoot == this.dhatupathaRoot &&
          other.dhatupathaPali == this.dhatupathaPali &&
          other.dhatupathaEnglish == this.dhatupathaEnglish &&
          other.dhatumanjusaNum == this.dhatumanjusaNum &&
          other.dhatumanjusaRoot == this.dhatumanjusaRoot &&
          other.dhatumanjusaPali == this.dhatumanjusaPali &&
          other.dhatumanjusaEnglish == this.dhatumanjusaEnglish &&
          other.dhatumalaRoot == this.dhatumalaRoot &&
          other.dhatumalaPali == this.dhatumalaPali &&
          other.dhatumalaEnglish == this.dhatumalaEnglish &&
          other.paniniRoot == this.paniniRoot &&
          other.paniniSanskrit == this.paniniSanskrit &&
          other.paniniEnglish == this.paniniEnglish &&
          other.note == this.note &&
          other.rootCount == this.rootCount);
}

class DpdRootsCompanion extends UpdateCompanion<DpdRoot> {
  final Value<String> root;
  final Value<String> rootInComps;
  final Value<String> rootHasVerb;
  final Value<int> rootGroup;
  final Value<String> rootSign;
  final Value<String> rootMeaning;
  final Value<String> sanskritRoot;
  final Value<String> sanskritRootMeaning;
  final Value<String> sanskritRootClass;
  final Value<String> rootExample;
  final Value<String> dhatupathaNum;
  final Value<String> dhatupathaRoot;
  final Value<String> dhatupathaPali;
  final Value<String> dhatupathaEnglish;
  final Value<String> dhatumanjusaNum;
  final Value<String> dhatumanjusaRoot;
  final Value<String> dhatumanjusaPali;
  final Value<String> dhatumanjusaEnglish;
  final Value<String> dhatumalaRoot;
  final Value<String> dhatumalaPali;
  final Value<String> dhatumalaEnglish;
  final Value<String> paniniRoot;
  final Value<String> paniniSanskrit;
  final Value<String> paniniEnglish;
  final Value<String> note;
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
    this.dhatupathaNum = const Value.absent(),
    this.dhatupathaRoot = const Value.absent(),
    this.dhatupathaPali = const Value.absent(),
    this.dhatupathaEnglish = const Value.absent(),
    this.dhatumanjusaNum = const Value.absent(),
    this.dhatumanjusaRoot = const Value.absent(),
    this.dhatumanjusaPali = const Value.absent(),
    this.dhatumanjusaEnglish = const Value.absent(),
    this.dhatumalaRoot = const Value.absent(),
    this.dhatumalaPali = const Value.absent(),
    this.dhatumalaEnglish = const Value.absent(),
    this.paniniRoot = const Value.absent(),
    this.paniniSanskrit = const Value.absent(),
    this.paniniEnglish = const Value.absent(),
    this.note = const Value.absent(),
    this.rootCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DpdRootsCompanion.insert({
    required String root,
    required String rootInComps,
    required String rootHasVerb,
    required int rootGroup,
    required String rootSign,
    required String rootMeaning,
    required String sanskritRoot,
    required String sanskritRootMeaning,
    required String sanskritRootClass,
    required String rootExample,
    required String dhatupathaNum,
    required String dhatupathaRoot,
    required String dhatupathaPali,
    required String dhatupathaEnglish,
    required String dhatumanjusaNum,
    required String dhatumanjusaRoot,
    required String dhatumanjusaPali,
    required String dhatumanjusaEnglish,
    required String dhatumalaRoot,
    required String dhatumalaPali,
    required String dhatumalaEnglish,
    required String paniniRoot,
    required String paniniSanskrit,
    required String paniniEnglish,
    required String note,
    this.rootCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : root = Value(root),
       rootInComps = Value(rootInComps),
       rootHasVerb = Value(rootHasVerb),
       rootGroup = Value(rootGroup),
       rootSign = Value(rootSign),
       rootMeaning = Value(rootMeaning),
       sanskritRoot = Value(sanskritRoot),
       sanskritRootMeaning = Value(sanskritRootMeaning),
       sanskritRootClass = Value(sanskritRootClass),
       rootExample = Value(rootExample),
       dhatupathaNum = Value(dhatupathaNum),
       dhatupathaRoot = Value(dhatupathaRoot),
       dhatupathaPali = Value(dhatupathaPali),
       dhatupathaEnglish = Value(dhatupathaEnglish),
       dhatumanjusaNum = Value(dhatumanjusaNum),
       dhatumanjusaRoot = Value(dhatumanjusaRoot),
       dhatumanjusaPali = Value(dhatumanjusaPali),
       dhatumanjusaEnglish = Value(dhatumanjusaEnglish),
       dhatumalaRoot = Value(dhatumalaRoot),
       dhatumalaPali = Value(dhatumalaPali),
       dhatumalaEnglish = Value(dhatumalaEnglish),
       paniniRoot = Value(paniniRoot),
       paniniSanskrit = Value(paniniSanskrit),
       paniniEnglish = Value(paniniEnglish),
       note = Value(note);
  static Insertable<DpdRoot> custom({
    Expression<String>? root,
    Expression<String>? rootInComps,
    Expression<String>? rootHasVerb,
    Expression<int>? rootGroup,
    Expression<String>? rootSign,
    Expression<String>? rootMeaning,
    Expression<String>? sanskritRoot,
    Expression<String>? sanskritRootMeaning,
    Expression<String>? sanskritRootClass,
    Expression<String>? rootExample,
    Expression<String>? dhatupathaNum,
    Expression<String>? dhatupathaRoot,
    Expression<String>? dhatupathaPali,
    Expression<String>? dhatupathaEnglish,
    Expression<String>? dhatumanjusaNum,
    Expression<String>? dhatumanjusaRoot,
    Expression<String>? dhatumanjusaPali,
    Expression<String>? dhatumanjusaEnglish,
    Expression<String>? dhatumalaRoot,
    Expression<String>? dhatumalaPali,
    Expression<String>? dhatumalaEnglish,
    Expression<String>? paniniRoot,
    Expression<String>? paniniSanskrit,
    Expression<String>? paniniEnglish,
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
      if (dhatupathaNum != null) 'dhatupatha_num': dhatupathaNum,
      if (dhatupathaRoot != null) 'dhatupatha_root': dhatupathaRoot,
      if (dhatupathaPali != null) 'dhatupatha_pali': dhatupathaPali,
      if (dhatupathaEnglish != null) 'dhatupatha_english': dhatupathaEnglish,
      if (dhatumanjusaNum != null) 'dhatumanjusa_num': dhatumanjusaNum,
      if (dhatumanjusaRoot != null) 'dhatumanjusa_root': dhatumanjusaRoot,
      if (dhatumanjusaPali != null) 'dhatumanjusa_pali': dhatumanjusaPali,
      if (dhatumanjusaEnglish != null)
        'dhatumanjusa_english': dhatumanjusaEnglish,
      if (dhatumalaRoot != null) 'dhatumala_root': dhatumalaRoot,
      if (dhatumalaPali != null) 'dhatumala_pali': dhatumalaPali,
      if (dhatumalaEnglish != null) 'dhatumala_english': dhatumalaEnglish,
      if (paniniRoot != null) 'panini_root': paniniRoot,
      if (paniniSanskrit != null) 'panini_sanskrit': paniniSanskrit,
      if (paniniEnglish != null) 'panini_english': paniniEnglish,
      if (note != null) 'note': note,
      if (rootCount != null) 'root_count': rootCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DpdRootsCompanion copyWith({
    Value<String>? root,
    Value<String>? rootInComps,
    Value<String>? rootHasVerb,
    Value<int>? rootGroup,
    Value<String>? rootSign,
    Value<String>? rootMeaning,
    Value<String>? sanskritRoot,
    Value<String>? sanskritRootMeaning,
    Value<String>? sanskritRootClass,
    Value<String>? rootExample,
    Value<String>? dhatupathaNum,
    Value<String>? dhatupathaRoot,
    Value<String>? dhatupathaPali,
    Value<String>? dhatupathaEnglish,
    Value<String>? dhatumanjusaNum,
    Value<String>? dhatumanjusaRoot,
    Value<String>? dhatumanjusaPali,
    Value<String>? dhatumanjusaEnglish,
    Value<String>? dhatumalaRoot,
    Value<String>? dhatumalaPali,
    Value<String>? dhatumalaEnglish,
    Value<String>? paniniRoot,
    Value<String>? paniniSanskrit,
    Value<String>? paniniEnglish,
    Value<String>? note,
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
      dhatupathaNum: dhatupathaNum ?? this.dhatupathaNum,
      dhatupathaRoot: dhatupathaRoot ?? this.dhatupathaRoot,
      dhatupathaPali: dhatupathaPali ?? this.dhatupathaPali,
      dhatupathaEnglish: dhatupathaEnglish ?? this.dhatupathaEnglish,
      dhatumanjusaNum: dhatumanjusaNum ?? this.dhatumanjusaNum,
      dhatumanjusaRoot: dhatumanjusaRoot ?? this.dhatumanjusaRoot,
      dhatumanjusaPali: dhatumanjusaPali ?? this.dhatumanjusaPali,
      dhatumanjusaEnglish: dhatumanjusaEnglish ?? this.dhatumanjusaEnglish,
      dhatumalaRoot: dhatumalaRoot ?? this.dhatumalaRoot,
      dhatumalaPali: dhatumalaPali ?? this.dhatumalaPali,
      dhatumalaEnglish: dhatumalaEnglish ?? this.dhatumalaEnglish,
      paniniRoot: paniniRoot ?? this.paniniRoot,
      paniniSanskrit: paniniSanskrit ?? this.paniniSanskrit,
      paniniEnglish: paniniEnglish ?? this.paniniEnglish,
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
      map['root_group'] = Variable<int>(rootGroup.value);
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
    if (dhatupathaNum.present) {
      map['dhatupatha_num'] = Variable<String>(dhatupathaNum.value);
    }
    if (dhatupathaRoot.present) {
      map['dhatupatha_root'] = Variable<String>(dhatupathaRoot.value);
    }
    if (dhatupathaPali.present) {
      map['dhatupatha_pali'] = Variable<String>(dhatupathaPali.value);
    }
    if (dhatupathaEnglish.present) {
      map['dhatupatha_english'] = Variable<String>(dhatupathaEnglish.value);
    }
    if (dhatumanjusaNum.present) {
      map['dhatumanjusa_num'] = Variable<String>(dhatumanjusaNum.value);
    }
    if (dhatumanjusaRoot.present) {
      map['dhatumanjusa_root'] = Variable<String>(dhatumanjusaRoot.value);
    }
    if (dhatumanjusaPali.present) {
      map['dhatumanjusa_pali'] = Variable<String>(dhatumanjusaPali.value);
    }
    if (dhatumanjusaEnglish.present) {
      map['dhatumanjusa_english'] = Variable<String>(dhatumanjusaEnglish.value);
    }
    if (dhatumalaRoot.present) {
      map['dhatumala_root'] = Variable<String>(dhatumalaRoot.value);
    }
    if (dhatumalaPali.present) {
      map['dhatumala_pali'] = Variable<String>(dhatumalaPali.value);
    }
    if (dhatumalaEnglish.present) {
      map['dhatumala_english'] = Variable<String>(dhatumalaEnglish.value);
    }
    if (paniniRoot.present) {
      map['panini_root'] = Variable<String>(paniniRoot.value);
    }
    if (paniniSanskrit.present) {
      map['panini_sanskrit'] = Variable<String>(paniniSanskrit.value);
    }
    if (paniniEnglish.present) {
      map['panini_english'] = Variable<String>(paniniEnglish.value);
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
          ..write('dhatupathaNum: $dhatupathaNum, ')
          ..write('dhatupathaRoot: $dhatupathaRoot, ')
          ..write('dhatupathaPali: $dhatupathaPali, ')
          ..write('dhatupathaEnglish: $dhatupathaEnglish, ')
          ..write('dhatumanjusaNum: $dhatumanjusaNum, ')
          ..write('dhatumanjusaRoot: $dhatumanjusaRoot, ')
          ..write('dhatumanjusaPali: $dhatumanjusaPali, ')
          ..write('dhatumanjusaEnglish: $dhatumanjusaEnglish, ')
          ..write('dhatumalaRoot: $dhatumalaRoot, ')
          ..write('dhatumalaPali: $dhatumalaPali, ')
          ..write('dhatumalaEnglish: $dhatumalaEnglish, ')
          ..write('paniniRoot: $paniniRoot, ')
          ..write('paniniSanskrit: $paniniSanskrit, ')
          ..write('paniniEnglish: $paniniEnglish, ')
          ..write('note: $note, ')
          ..write('rootCount: $rootCount, ')
          ..write('rowid: $rowid')
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dpd_roots (root)',
    ),
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
  static const VerificationMeta _familySetMeta = const VerificationMeta(
    'familySet',
  );
  @override
  late final GeneratedColumn<String> familySet = GeneratedColumn<String>(
    'family_set',
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
  static const VerificationMeta _compoundConstructionMeta =
      const VerificationMeta('compoundConstruction');
  @override
  late final GeneratedColumn<String> compoundConstruction =
      GeneratedColumn<String>(
        'compound_construction',
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
  static const VerificationMeta _derivativeMeta = const VerificationMeta(
    'derivative',
  );
  @override
  late final GeneratedColumn<String> derivative = GeneratedColumn<String>(
    'derivative',
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
    rootKey,
    rootSign,
    rootBase,
    familyRoot,
    familyWord,
    familyCompound,
    familyIdioms,
    familySet,
    construction,
    compoundType,
    compoundConstruction,
    source1,
    sutta1,
    example1,
    source2,
    sutta2,
    example2,
    antonym,
    synonym,
    variant,
    stem,
    pattern,
    derivative,
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
    if (data.containsKey('family_set')) {
      context.handle(
        _familySetMeta,
        familySet.isAcceptableOrUnknown(data['family_set']!, _familySetMeta),
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
    if (data.containsKey('compound_construction')) {
      context.handle(
        _compoundConstructionMeta,
        compoundConstruction.isAcceptableOrUnknown(
          data['compound_construction']!,
          _compoundConstructionMeta,
        ),
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
    if (data.containsKey('derivative')) {
      context.handle(
        _derivativeMeta,
        derivative.isAcceptableOrUnknown(data['derivative']!, _derivativeMeta),
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
      familySet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_set'],
      ),
      construction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}construction'],
      ),
      compoundType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_type'],
      ),
      compoundConstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_construction'],
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
      derivative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derivative'],
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
  final String? rootKey;
  final String? rootSign;
  final String? rootBase;
  final String? familyRoot;
  final String? familyWord;
  final String? familyCompound;
  final String? familyIdioms;
  final String? familySet;
  final String? construction;
  final String? compoundType;
  final String? compoundConstruction;
  final String? source1;
  final String? sutta1;
  final String? example1;
  final String? source2;
  final String? sutta2;
  final String? example2;
  final String? antonym;
  final String? synonym;
  final String? variant;
  final String? stem;
  final String? pattern;
  final String? derivative;
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
    this.rootKey,
    this.rootSign,
    this.rootBase,
    this.familyRoot,
    this.familyWord,
    this.familyCompound,
    this.familyIdioms,
    this.familySet,
    this.construction,
    this.compoundType,
    this.compoundConstruction,
    this.source1,
    this.sutta1,
    this.example1,
    this.source2,
    this.sutta2,
    this.example2,
    this.antonym,
    this.synonym,
    this.variant,
    this.stem,
    this.pattern,
    this.derivative,
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
    if (!nullToAbsent || familySet != null) {
      map['family_set'] = Variable<String>(familySet);
    }
    if (!nullToAbsent || construction != null) {
      map['construction'] = Variable<String>(construction);
    }
    if (!nullToAbsent || compoundType != null) {
      map['compound_type'] = Variable<String>(compoundType);
    }
    if (!nullToAbsent || compoundConstruction != null) {
      map['compound_construction'] = Variable<String>(compoundConstruction);
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
    if (!nullToAbsent || derivative != null) {
      map['derivative'] = Variable<String>(derivative);
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
      familySet: familySet == null && nullToAbsent
          ? const Value.absent()
          : Value(familySet),
      construction: construction == null && nullToAbsent
          ? const Value.absent()
          : Value(construction),
      compoundType: compoundType == null && nullToAbsent
          ? const Value.absent()
          : Value(compoundType),
      compoundConstruction: compoundConstruction == null && nullToAbsent
          ? const Value.absent()
          : Value(compoundConstruction),
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
      derivative: derivative == null && nullToAbsent
          ? const Value.absent()
          : Value(derivative),
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
      rootKey: serializer.fromJson<String?>(json['rootKey']),
      rootSign: serializer.fromJson<String?>(json['rootSign']),
      rootBase: serializer.fromJson<String?>(json['rootBase']),
      familyRoot: serializer.fromJson<String?>(json['familyRoot']),
      familyWord: serializer.fromJson<String?>(json['familyWord']),
      familyCompound: serializer.fromJson<String?>(json['familyCompound']),
      familyIdioms: serializer.fromJson<String?>(json['familyIdioms']),
      familySet: serializer.fromJson<String?>(json['familySet']),
      construction: serializer.fromJson<String?>(json['construction']),
      compoundType: serializer.fromJson<String?>(json['compoundType']),
      compoundConstruction: serializer.fromJson<String?>(
        json['compoundConstruction'],
      ),
      source1: serializer.fromJson<String?>(json['source1']),
      sutta1: serializer.fromJson<String?>(json['sutta1']),
      example1: serializer.fromJson<String?>(json['example1']),
      source2: serializer.fromJson<String?>(json['source2']),
      sutta2: serializer.fromJson<String?>(json['sutta2']),
      example2: serializer.fromJson<String?>(json['example2']),
      antonym: serializer.fromJson<String?>(json['antonym']),
      synonym: serializer.fromJson<String?>(json['synonym']),
      variant: serializer.fromJson<String?>(json['variant']),
      stem: serializer.fromJson<String?>(json['stem']),
      pattern: serializer.fromJson<String?>(json['pattern']),
      derivative: serializer.fromJson<String?>(json['derivative']),
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
      'rootKey': serializer.toJson<String?>(rootKey),
      'rootSign': serializer.toJson<String?>(rootSign),
      'rootBase': serializer.toJson<String?>(rootBase),
      'familyRoot': serializer.toJson<String?>(familyRoot),
      'familyWord': serializer.toJson<String?>(familyWord),
      'familyCompound': serializer.toJson<String?>(familyCompound),
      'familyIdioms': serializer.toJson<String?>(familyIdioms),
      'familySet': serializer.toJson<String?>(familySet),
      'construction': serializer.toJson<String?>(construction),
      'compoundType': serializer.toJson<String?>(compoundType),
      'compoundConstruction': serializer.toJson<String?>(compoundConstruction),
      'source1': serializer.toJson<String?>(source1),
      'sutta1': serializer.toJson<String?>(sutta1),
      'example1': serializer.toJson<String?>(example1),
      'source2': serializer.toJson<String?>(source2),
      'sutta2': serializer.toJson<String?>(sutta2),
      'example2': serializer.toJson<String?>(example2),
      'antonym': serializer.toJson<String?>(antonym),
      'synonym': serializer.toJson<String?>(synonym),
      'variant': serializer.toJson<String?>(variant),
      'stem': serializer.toJson<String?>(stem),
      'pattern': serializer.toJson<String?>(pattern),
      'derivative': serializer.toJson<String?>(derivative),
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
    Value<String?> rootKey = const Value.absent(),
    Value<String?> rootSign = const Value.absent(),
    Value<String?> rootBase = const Value.absent(),
    Value<String?> familyRoot = const Value.absent(),
    Value<String?> familyWord = const Value.absent(),
    Value<String?> familyCompound = const Value.absent(),
    Value<String?> familyIdioms = const Value.absent(),
    Value<String?> familySet = const Value.absent(),
    Value<String?> construction = const Value.absent(),
    Value<String?> compoundType = const Value.absent(),
    Value<String?> compoundConstruction = const Value.absent(),
    Value<String?> source1 = const Value.absent(),
    Value<String?> sutta1 = const Value.absent(),
    Value<String?> example1 = const Value.absent(),
    Value<String?> source2 = const Value.absent(),
    Value<String?> sutta2 = const Value.absent(),
    Value<String?> example2 = const Value.absent(),
    Value<String?> antonym = const Value.absent(),
    Value<String?> synonym = const Value.absent(),
    Value<String?> variant = const Value.absent(),
    Value<String?> stem = const Value.absent(),
    Value<String?> pattern = const Value.absent(),
    Value<String?> derivative = const Value.absent(),
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
    rootKey: rootKey.present ? rootKey.value : this.rootKey,
    rootSign: rootSign.present ? rootSign.value : this.rootSign,
    rootBase: rootBase.present ? rootBase.value : this.rootBase,
    familyRoot: familyRoot.present ? familyRoot.value : this.familyRoot,
    familyWord: familyWord.present ? familyWord.value : this.familyWord,
    familyCompound: familyCompound.present
        ? familyCompound.value
        : this.familyCompound,
    familyIdioms: familyIdioms.present ? familyIdioms.value : this.familyIdioms,
    familySet: familySet.present ? familySet.value : this.familySet,
    construction: construction.present ? construction.value : this.construction,
    compoundType: compoundType.present ? compoundType.value : this.compoundType,
    compoundConstruction: compoundConstruction.present
        ? compoundConstruction.value
        : this.compoundConstruction,
    source1: source1.present ? source1.value : this.source1,
    sutta1: sutta1.present ? sutta1.value : this.sutta1,
    example1: example1.present ? example1.value : this.example1,
    source2: source2.present ? source2.value : this.source2,
    sutta2: sutta2.present ? sutta2.value : this.sutta2,
    example2: example2.present ? example2.value : this.example2,
    antonym: antonym.present ? antonym.value : this.antonym,
    synonym: synonym.present ? synonym.value : this.synonym,
    variant: variant.present ? variant.value : this.variant,
    stem: stem.present ? stem.value : this.stem,
    pattern: pattern.present ? pattern.value : this.pattern,
    derivative: derivative.present ? derivative.value : this.derivative,
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
      familySet: data.familySet.present ? data.familySet.value : this.familySet,
      construction: data.construction.present
          ? data.construction.value
          : this.construction,
      compoundType: data.compoundType.present
          ? data.compoundType.value
          : this.compoundType,
      compoundConstruction: data.compoundConstruction.present
          ? data.compoundConstruction.value
          : this.compoundConstruction,
      source1: data.source1.present ? data.source1.value : this.source1,
      sutta1: data.sutta1.present ? data.sutta1.value : this.sutta1,
      example1: data.example1.present ? data.example1.value : this.example1,
      source2: data.source2.present ? data.source2.value : this.source2,
      sutta2: data.sutta2.present ? data.sutta2.value : this.sutta2,
      example2: data.example2.present ? data.example2.value : this.example2,
      antonym: data.antonym.present ? data.antonym.value : this.antonym,
      synonym: data.synonym.present ? data.synonym.value : this.synonym,
      variant: data.variant.present ? data.variant.value : this.variant,
      stem: data.stem.present ? data.stem.value : this.stem,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      derivative: data.derivative.present
          ? data.derivative.value
          : this.derivative,
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
          ..write('rootKey: $rootKey, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootBase: $rootBase, ')
          ..write('familyRoot: $familyRoot, ')
          ..write('familyWord: $familyWord, ')
          ..write('familyCompound: $familyCompound, ')
          ..write('familyIdioms: $familyIdioms, ')
          ..write('familySet: $familySet, ')
          ..write('construction: $construction, ')
          ..write('compoundType: $compoundType, ')
          ..write('compoundConstruction: $compoundConstruction, ')
          ..write('source1: $source1, ')
          ..write('sutta1: $sutta1, ')
          ..write('example1: $example1, ')
          ..write('source2: $source2, ')
          ..write('sutta2: $sutta2, ')
          ..write('example2: $example2, ')
          ..write('antonym: $antonym, ')
          ..write('synonym: $synonym, ')
          ..write('variant: $variant, ')
          ..write('stem: $stem, ')
          ..write('pattern: $pattern, ')
          ..write('derivative: $derivative, ')
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
    rootKey,
    rootSign,
    rootBase,
    familyRoot,
    familyWord,
    familyCompound,
    familyIdioms,
    familySet,
    construction,
    compoundType,
    compoundConstruction,
    source1,
    sutta1,
    example1,
    source2,
    sutta2,
    example2,
    antonym,
    synonym,
    variant,
    stem,
    pattern,
    derivative,
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
          other.rootKey == this.rootKey &&
          other.rootSign == this.rootSign &&
          other.rootBase == this.rootBase &&
          other.familyRoot == this.familyRoot &&
          other.familyWord == this.familyWord &&
          other.familyCompound == this.familyCompound &&
          other.familyIdioms == this.familyIdioms &&
          other.familySet == this.familySet &&
          other.construction == this.construction &&
          other.compoundType == this.compoundType &&
          other.compoundConstruction == this.compoundConstruction &&
          other.source1 == this.source1 &&
          other.sutta1 == this.sutta1 &&
          other.example1 == this.example1 &&
          other.source2 == this.source2 &&
          other.sutta2 == this.sutta2 &&
          other.example2 == this.example2 &&
          other.antonym == this.antonym &&
          other.synonym == this.synonym &&
          other.variant == this.variant &&
          other.stem == this.stem &&
          other.pattern == this.pattern &&
          other.derivative == this.derivative &&
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
  final Value<String?> rootKey;
  final Value<String?> rootSign;
  final Value<String?> rootBase;
  final Value<String?> familyRoot;
  final Value<String?> familyWord;
  final Value<String?> familyCompound;
  final Value<String?> familyIdioms;
  final Value<String?> familySet;
  final Value<String?> construction;
  final Value<String?> compoundType;
  final Value<String?> compoundConstruction;
  final Value<String?> source1;
  final Value<String?> sutta1;
  final Value<String?> example1;
  final Value<String?> source2;
  final Value<String?> sutta2;
  final Value<String?> example2;
  final Value<String?> antonym;
  final Value<String?> synonym;
  final Value<String?> variant;
  final Value<String?> stem;
  final Value<String?> pattern;
  final Value<String?> derivative;
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
    this.rootKey = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootBase = const Value.absent(),
    this.familyRoot = const Value.absent(),
    this.familyWord = const Value.absent(),
    this.familyCompound = const Value.absent(),
    this.familyIdioms = const Value.absent(),
    this.familySet = const Value.absent(),
    this.construction = const Value.absent(),
    this.compoundType = const Value.absent(),
    this.compoundConstruction = const Value.absent(),
    this.source1 = const Value.absent(),
    this.sutta1 = const Value.absent(),
    this.example1 = const Value.absent(),
    this.source2 = const Value.absent(),
    this.sutta2 = const Value.absent(),
    this.example2 = const Value.absent(),
    this.antonym = const Value.absent(),
    this.synonym = const Value.absent(),
    this.variant = const Value.absent(),
    this.stem = const Value.absent(),
    this.pattern = const Value.absent(),
    this.derivative = const Value.absent(),
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
    this.rootKey = const Value.absent(),
    this.rootSign = const Value.absent(),
    this.rootBase = const Value.absent(),
    this.familyRoot = const Value.absent(),
    this.familyWord = const Value.absent(),
    this.familyCompound = const Value.absent(),
    this.familyIdioms = const Value.absent(),
    this.familySet = const Value.absent(),
    this.construction = const Value.absent(),
    this.compoundType = const Value.absent(),
    this.compoundConstruction = const Value.absent(),
    this.source1 = const Value.absent(),
    this.sutta1 = const Value.absent(),
    this.example1 = const Value.absent(),
    this.source2 = const Value.absent(),
    this.sutta2 = const Value.absent(),
    this.example2 = const Value.absent(),
    this.antonym = const Value.absent(),
    this.synonym = const Value.absent(),
    this.variant = const Value.absent(),
    this.stem = const Value.absent(),
    this.pattern = const Value.absent(),
    this.derivative = const Value.absent(),
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
    Expression<String>? rootKey,
    Expression<String>? rootSign,
    Expression<String>? rootBase,
    Expression<String>? familyRoot,
    Expression<String>? familyWord,
    Expression<String>? familyCompound,
    Expression<String>? familyIdioms,
    Expression<String>? familySet,
    Expression<String>? construction,
    Expression<String>? compoundType,
    Expression<String>? compoundConstruction,
    Expression<String>? source1,
    Expression<String>? sutta1,
    Expression<String>? example1,
    Expression<String>? source2,
    Expression<String>? sutta2,
    Expression<String>? example2,
    Expression<String>? antonym,
    Expression<String>? synonym,
    Expression<String>? variant,
    Expression<String>? stem,
    Expression<String>? pattern,
    Expression<String>? derivative,
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
      if (rootKey != null) 'root_key': rootKey,
      if (rootSign != null) 'root_sign': rootSign,
      if (rootBase != null) 'root_base': rootBase,
      if (familyRoot != null) 'family_root': familyRoot,
      if (familyWord != null) 'family_word': familyWord,
      if (familyCompound != null) 'family_compound': familyCompound,
      if (familyIdioms != null) 'family_idioms': familyIdioms,
      if (familySet != null) 'family_set': familySet,
      if (construction != null) 'construction': construction,
      if (compoundType != null) 'compound_type': compoundType,
      if (compoundConstruction != null)
        'compound_construction': compoundConstruction,
      if (source1 != null) 'source_1': source1,
      if (sutta1 != null) 'sutta_1': sutta1,
      if (example1 != null) 'example_1': example1,
      if (source2 != null) 'source_2': source2,
      if (sutta2 != null) 'sutta_2': sutta2,
      if (example2 != null) 'example_2': example2,
      if (antonym != null) 'antonym': antonym,
      if (synonym != null) 'synonym': synonym,
      if (variant != null) 'variant': variant,
      if (stem != null) 'stem': stem,
      if (pattern != null) 'pattern': pattern,
      if (derivative != null) 'derivative': derivative,
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
    Value<String?>? rootKey,
    Value<String?>? rootSign,
    Value<String?>? rootBase,
    Value<String?>? familyRoot,
    Value<String?>? familyWord,
    Value<String?>? familyCompound,
    Value<String?>? familyIdioms,
    Value<String?>? familySet,
    Value<String?>? construction,
    Value<String?>? compoundType,
    Value<String?>? compoundConstruction,
    Value<String?>? source1,
    Value<String?>? sutta1,
    Value<String?>? example1,
    Value<String?>? source2,
    Value<String?>? sutta2,
    Value<String?>? example2,
    Value<String?>? antonym,
    Value<String?>? synonym,
    Value<String?>? variant,
    Value<String?>? stem,
    Value<String?>? pattern,
    Value<String?>? derivative,
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
      rootKey: rootKey ?? this.rootKey,
      rootSign: rootSign ?? this.rootSign,
      rootBase: rootBase ?? this.rootBase,
      familyRoot: familyRoot ?? this.familyRoot,
      familyWord: familyWord ?? this.familyWord,
      familyCompound: familyCompound ?? this.familyCompound,
      familyIdioms: familyIdioms ?? this.familyIdioms,
      familySet: familySet ?? this.familySet,
      construction: construction ?? this.construction,
      compoundType: compoundType ?? this.compoundType,
      compoundConstruction: compoundConstruction ?? this.compoundConstruction,
      source1: source1 ?? this.source1,
      sutta1: sutta1 ?? this.sutta1,
      example1: example1 ?? this.example1,
      source2: source2 ?? this.source2,
      sutta2: sutta2 ?? this.sutta2,
      example2: example2 ?? this.example2,
      antonym: antonym ?? this.antonym,
      synonym: synonym ?? this.synonym,
      variant: variant ?? this.variant,
      stem: stem ?? this.stem,
      pattern: pattern ?? this.pattern,
      derivative: derivative ?? this.derivative,
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
    if (familySet.present) {
      map['family_set'] = Variable<String>(familySet.value);
    }
    if (construction.present) {
      map['construction'] = Variable<String>(construction.value);
    }
    if (compoundType.present) {
      map['compound_type'] = Variable<String>(compoundType.value);
    }
    if (compoundConstruction.present) {
      map['compound_construction'] = Variable<String>(
        compoundConstruction.value,
      );
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
    if (derivative.present) {
      map['derivative'] = Variable<String>(derivative.value);
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
          ..write('rootKey: $rootKey, ')
          ..write('rootSign: $rootSign, ')
          ..write('rootBase: $rootBase, ')
          ..write('familyRoot: $familyRoot, ')
          ..write('familyWord: $familyWord, ')
          ..write('familyCompound: $familyCompound, ')
          ..write('familyIdioms: $familyIdioms, ')
          ..write('familySet: $familySet, ')
          ..write('construction: $construction, ')
          ..write('compoundType: $compoundType, ')
          ..write('compoundConstruction: $compoundConstruction, ')
          ..write('source1: $source1, ')
          ..write('sutta1: $sutta1, ')
          ..write('example1: $example1, ')
          ..write('source2: $source2, ')
          ..write('sutta2: $sutta2, ')
          ..write('example2: $example2, ')
          ..write('antonym: $antonym, ')
          ..write('synonym: $synonym, ')
          ..write('variant: $variant, ')
          ..write('stem: $stem, ')
          ..write('pattern: $pattern, ')
          ..write('derivative: $derivative, ')
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
  static const VerificationMeta _seeMeta = const VerificationMeta('see');
  @override
  late final GeneratedColumn<String> see = GeneratedColumn<String>(
    'see',
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
  static const VerificationMeta _abbrevOtherMeta = const VerificationMeta(
    'abbrevOther',
  );
  @override
  late final GeneratedColumn<String> abbrevOther = GeneratedColumn<String>(
    'abbrev_other',
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
    see,
    spelling,
    grammar,
    help,
    abbrev,
    abbrevOther,
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
    if (data.containsKey('see')) {
      context.handle(
        _seeMeta,
        see.isAcceptableOrUnknown(data['see']!, _seeMeta),
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
    if (data.containsKey('abbrev_other')) {
      context.handle(
        _abbrevOtherMeta,
        abbrevOther.isAcceptableOrUnknown(
          data['abbrev_other']!,
          _abbrevOtherMeta,
        ),
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
      see: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}see'],
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
      abbrevOther: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbrev_other'],
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
  final String? see;
  final String? spelling;
  final String? grammar;
  final String? help;
  final String? abbrev;
  final String? abbrevOther;
  final String? deconstructor;
  final String? epd;
  final String? fuzzyKey;
  const LookupData({
    required this.lookupKey,
    this.headwords,
    this.roots,
    this.variant,
    this.see,
    this.spelling,
    this.grammar,
    this.help,
    this.abbrev,
    this.abbrevOther,
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
    if (!nullToAbsent || see != null) {
      map['see'] = Variable<String>(see);
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
    if (!nullToAbsent || abbrevOther != null) {
      map['abbrev_other'] = Variable<String>(abbrevOther);
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
      see: see == null && nullToAbsent ? const Value.absent() : Value(see),
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
      abbrevOther: abbrevOther == null && nullToAbsent
          ? const Value.absent()
          : Value(abbrevOther),
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
      see: serializer.fromJson<String?>(json['see']),
      spelling: serializer.fromJson<String?>(json['spelling']),
      grammar: serializer.fromJson<String?>(json['grammar']),
      help: serializer.fromJson<String?>(json['help']),
      abbrev: serializer.fromJson<String?>(json['abbrev']),
      abbrevOther: serializer.fromJson<String?>(json['abbrevOther']),
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
      'see': serializer.toJson<String?>(see),
      'spelling': serializer.toJson<String?>(spelling),
      'grammar': serializer.toJson<String?>(grammar),
      'help': serializer.toJson<String?>(help),
      'abbrev': serializer.toJson<String?>(abbrev),
      'abbrevOther': serializer.toJson<String?>(abbrevOther),
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
    Value<String?> see = const Value.absent(),
    Value<String?> spelling = const Value.absent(),
    Value<String?> grammar = const Value.absent(),
    Value<String?> help = const Value.absent(),
    Value<String?> abbrev = const Value.absent(),
    Value<String?> abbrevOther = const Value.absent(),
    Value<String?> deconstructor = const Value.absent(),
    Value<String?> epd = const Value.absent(),
    Value<String?> fuzzyKey = const Value.absent(),
  }) => LookupData(
    lookupKey: lookupKey ?? this.lookupKey,
    headwords: headwords.present ? headwords.value : this.headwords,
    roots: roots.present ? roots.value : this.roots,
    variant: variant.present ? variant.value : this.variant,
    see: see.present ? see.value : this.see,
    spelling: spelling.present ? spelling.value : this.spelling,
    grammar: grammar.present ? grammar.value : this.grammar,
    help: help.present ? help.value : this.help,
    abbrev: abbrev.present ? abbrev.value : this.abbrev,
    abbrevOther: abbrevOther.present ? abbrevOther.value : this.abbrevOther,
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
      see: data.see.present ? data.see.value : this.see,
      spelling: data.spelling.present ? data.spelling.value : this.spelling,
      grammar: data.grammar.present ? data.grammar.value : this.grammar,
      help: data.help.present ? data.help.value : this.help,
      abbrev: data.abbrev.present ? data.abbrev.value : this.abbrev,
      abbrevOther: data.abbrevOther.present
          ? data.abbrevOther.value
          : this.abbrevOther,
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
          ..write('see: $see, ')
          ..write('spelling: $spelling, ')
          ..write('grammar: $grammar, ')
          ..write('help: $help, ')
          ..write('abbrev: $abbrev, ')
          ..write('abbrevOther: $abbrevOther, ')
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
    see,
    spelling,
    grammar,
    help,
    abbrev,
    abbrevOther,
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
          other.see == this.see &&
          other.spelling == this.spelling &&
          other.grammar == this.grammar &&
          other.help == this.help &&
          other.abbrev == this.abbrev &&
          other.abbrevOther == this.abbrevOther &&
          other.deconstructor == this.deconstructor &&
          other.epd == this.epd &&
          other.fuzzyKey == this.fuzzyKey);
}

class LookupCompanion extends UpdateCompanion<LookupData> {
  final Value<String> lookupKey;
  final Value<String?> headwords;
  final Value<String?> roots;
  final Value<String?> variant;
  final Value<String?> see;
  final Value<String?> spelling;
  final Value<String?> grammar;
  final Value<String?> help;
  final Value<String?> abbrev;
  final Value<String?> abbrevOther;
  final Value<String?> deconstructor;
  final Value<String?> epd;
  final Value<String?> fuzzyKey;
  final Value<int> rowid;
  const LookupCompanion({
    this.lookupKey = const Value.absent(),
    this.headwords = const Value.absent(),
    this.roots = const Value.absent(),
    this.variant = const Value.absent(),
    this.see = const Value.absent(),
    this.spelling = const Value.absent(),
    this.grammar = const Value.absent(),
    this.help = const Value.absent(),
    this.abbrev = const Value.absent(),
    this.abbrevOther = const Value.absent(),
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
    this.see = const Value.absent(),
    this.spelling = const Value.absent(),
    this.grammar = const Value.absent(),
    this.help = const Value.absent(),
    this.abbrev = const Value.absent(),
    this.abbrevOther = const Value.absent(),
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
    Expression<String>? see,
    Expression<String>? spelling,
    Expression<String>? grammar,
    Expression<String>? help,
    Expression<String>? abbrev,
    Expression<String>? abbrevOther,
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
      if (see != null) 'see': see,
      if (spelling != null) 'spelling': spelling,
      if (grammar != null) 'grammar': grammar,
      if (help != null) 'help': help,
      if (abbrev != null) 'abbrev': abbrev,
      if (abbrevOther != null) 'abbrev_other': abbrevOther,
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
    Value<String?>? see,
    Value<String?>? spelling,
    Value<String?>? grammar,
    Value<String?>? help,
    Value<String?>? abbrev,
    Value<String?>? abbrevOther,
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
      see: see ?? this.see,
      spelling: spelling ?? this.spelling,
      grammar: grammar ?? this.grammar,
      help: help ?? this.help,
      abbrev: abbrev ?? this.abbrev,
      abbrevOther: abbrevOther ?? this.abbrevOther,
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
    if (see.present) {
      map['see'] = Variable<String>(see.value);
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
    if (abbrevOther.present) {
      map['abbrev_other'] = Variable<String>(abbrevOther.value);
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
          ..write('see: $see, ')
          ..write('spelling: $spelling, ')
          ..write('grammar: $grammar, ')
          ..write('help: $help, ')
          ..write('abbrev: $abbrev, ')
          ..write('abbrevOther: $abbrevOther, ')
          ..write('deconstructor: $deconstructor, ')
          ..write('epd: $epd, ')
          ..write('fuzzyKey: $fuzzyKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbInfoTable extends DbInfo with TableInfo<$DbInfoTable, DbInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbInfoTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'db_info';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbInfoData> instance, {
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
  DbInfoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbInfoData(
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
  $DbInfoTable createAlias(String alias) {
    return $DbInfoTable(attachedDatabase, alias);
  }
}

class DbInfoData extends DataClass implements Insertable<DbInfoData> {
  final String key;
  final String? value;
  const DbInfoData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  DbInfoCompanion toCompanion(bool nullToAbsent) {
    return DbInfoCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory DbInfoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbInfoData(
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

  DbInfoData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => DbInfoData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  DbInfoData copyWithCompanion(DbInfoCompanion data) {
    return DbInfoData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbInfoData(')
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
      (other is DbInfoData &&
          other.key == this.key &&
          other.value == this.value);
}

class DbInfoCompanion extends UpdateCompanion<DbInfoData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const DbInfoCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbInfoCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<DbInfoData> custom({
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

  DbInfoCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return DbInfoCompanion(
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
    return (StringBuffer('DbInfoCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InflectionTemplatesTable extends InflectionTemplates
    with TableInfo<$InflectionTemplatesTable, InflectionTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InflectionTemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _templateLikeMeta = const VerificationMeta(
    'templateLike',
  );
  @override
  late final GeneratedColumn<String> templateLike = GeneratedColumn<String>(
    'like',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pattern, templateLike, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inflection_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<InflectionTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('like')) {
      context.handle(
        _templateLikeMeta,
        templateLike.isAcceptableOrUnknown(data['like']!, _templateLikeMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pattern};
  @override
  InflectionTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InflectionTemplate(
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      templateLike: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}like'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $InflectionTemplatesTable createAlias(String alias) {
    return $InflectionTemplatesTable(attachedDatabase, alias);
  }
}

class InflectionTemplate extends DataClass
    implements Insertable<InflectionTemplate> {
  final String pattern;
  final String? templateLike;
  final String data;
  const InflectionTemplate({
    required this.pattern,
    this.templateLike,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || templateLike != null) {
      map['like'] = Variable<String>(templateLike);
    }
    map['data'] = Variable<String>(data);
    return map;
  }

  InflectionTemplatesCompanion toCompanion(bool nullToAbsent) {
    return InflectionTemplatesCompanion(
      pattern: Value(pattern),
      templateLike: templateLike == null && nullToAbsent
          ? const Value.absent()
          : Value(templateLike),
      data: Value(data),
    );
  }

  factory InflectionTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InflectionTemplate(
      pattern: serializer.fromJson<String>(json['pattern']),
      templateLike: serializer.fromJson<String?>(json['templateLike']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pattern': serializer.toJson<String>(pattern),
      'templateLike': serializer.toJson<String?>(templateLike),
      'data': serializer.toJson<String>(data),
    };
  }

  InflectionTemplate copyWith({
    String? pattern,
    Value<String?> templateLike = const Value.absent(),
    String? data,
  }) => InflectionTemplate(
    pattern: pattern ?? this.pattern,
    templateLike: templateLike.present ? templateLike.value : this.templateLike,
    data: data ?? this.data,
  );
  InflectionTemplate copyWithCompanion(InflectionTemplatesCompanion data) {
    return InflectionTemplate(
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      templateLike: data.templateLike.present
          ? data.templateLike.value
          : this.templateLike,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InflectionTemplate(')
          ..write('pattern: $pattern, ')
          ..write('templateLike: $templateLike, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pattern, templateLike, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InflectionTemplate &&
          other.pattern == this.pattern &&
          other.templateLike == this.templateLike &&
          other.data == this.data);
}

class InflectionTemplatesCompanion extends UpdateCompanion<InflectionTemplate> {
  final Value<String> pattern;
  final Value<String?> templateLike;
  final Value<String> data;
  final Value<int> rowid;
  const InflectionTemplatesCompanion({
    this.pattern = const Value.absent(),
    this.templateLike = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InflectionTemplatesCompanion.insert({
    required String pattern,
    this.templateLike = const Value.absent(),
    required String data,
    this.rowid = const Value.absent(),
  }) : pattern = Value(pattern),
       data = Value(data);
  static Insertable<InflectionTemplate> custom({
    Expression<String>? pattern,
    Expression<String>? templateLike,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pattern != null) 'pattern': pattern,
      if (templateLike != null) 'like': templateLike,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InflectionTemplatesCompanion copyWith({
    Value<String>? pattern,
    Value<String?>? templateLike,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return InflectionTemplatesCompanion(
      pattern: pattern ?? this.pattern,
      templateLike: templateLike ?? this.templateLike,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (templateLike.present) {
      map['like'] = Variable<String>(templateLike.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InflectionTemplatesCompanion(')
          ..write('pattern: $pattern, ')
          ..write('templateLike: $templateLike, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyRootTable extends FamilyRoot
    with TableInfo<$FamilyRootTable, FamilyRootData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyRootTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rootFamilyKeyMeta = const VerificationMeta(
    'rootFamilyKey',
  );
  @override
  late final GeneratedColumn<String> rootFamilyKey = GeneratedColumn<String>(
    'root_family_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootKeyMeta = const VerificationMeta(
    'rootKey',
  );
  @override
  late final GeneratedColumn<String> rootKey = GeneratedColumn<String>(
    'root_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootFamilyMeta = const VerificationMeta(
    'rootFamily',
  );
  @override
  late final GeneratedColumn<String> rootFamily = GeneratedColumn<String>(
    'root_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootMeaningMeta = const VerificationMeta(
    'rootMeaning',
  );
  @override
  late final GeneratedColumn<String> rootMeaning = GeneratedColumn<String>(
    'root_meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _htmlMeta = const VerificationMeta('html');
  @override
  late final GeneratedColumn<String> html = GeneratedColumn<String>(
    'html',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rootFamilyKey,
    rootKey,
    rootFamily,
    rootMeaning,
    html,
    data,
    count,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_root';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyRootData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('root_family_key')) {
      context.handle(
        _rootFamilyKeyMeta,
        rootFamilyKey.isAcceptableOrUnknown(
          data['root_family_key']!,
          _rootFamilyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootFamilyKeyMeta);
    }
    if (data.containsKey('root_key')) {
      context.handle(
        _rootKeyMeta,
        rootKey.isAcceptableOrUnknown(data['root_key']!, _rootKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rootKeyMeta);
    }
    if (data.containsKey('root_family')) {
      context.handle(
        _rootFamilyMeta,
        rootFamily.isAcceptableOrUnknown(data['root_family']!, _rootFamilyMeta),
      );
    } else if (isInserting) {
      context.missing(_rootFamilyMeta);
    }
    if (data.containsKey('root_meaning')) {
      context.handle(
        _rootMeaningMeta,
        rootMeaning.isAcceptableOrUnknown(
          data['root_meaning']!,
          _rootMeaningMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootMeaningMeta);
    }
    if (data.containsKey('html')) {
      context.handle(
        _htmlMeta,
        html.isAcceptableOrUnknown(data['html']!, _htmlMeta),
      );
    } else if (isInserting) {
      context.missing(_htmlMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rootFamilyKey};
  @override
  FamilyRootData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyRootData(
      rootFamilyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_family_key'],
      )!,
      rootKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_key'],
      )!,
      rootFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_family'],
      )!,
      rootMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_meaning'],
      )!,
      html: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $FamilyRootTable createAlias(String alias) {
    return $FamilyRootTable(attachedDatabase, alias);
  }
}

class FamilyRootData extends DataClass implements Insertable<FamilyRootData> {
  final String rootFamilyKey;
  final String rootKey;
  final String rootFamily;
  final String rootMeaning;
  final String html;
  final String data;
  final int count;
  const FamilyRootData({
    required this.rootFamilyKey,
    required this.rootKey,
    required this.rootFamily,
    required this.rootMeaning,
    required this.html,
    required this.data,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['root_family_key'] = Variable<String>(rootFamilyKey);
    map['root_key'] = Variable<String>(rootKey);
    map['root_family'] = Variable<String>(rootFamily);
    map['root_meaning'] = Variable<String>(rootMeaning);
    map['html'] = Variable<String>(html);
    map['data'] = Variable<String>(data);
    map['count'] = Variable<int>(count);
    return map;
  }

  FamilyRootCompanion toCompanion(bool nullToAbsent) {
    return FamilyRootCompanion(
      rootFamilyKey: Value(rootFamilyKey),
      rootKey: Value(rootKey),
      rootFamily: Value(rootFamily),
      rootMeaning: Value(rootMeaning),
      html: Value(html),
      data: Value(data),
      count: Value(count),
    );
  }

  factory FamilyRootData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyRootData(
      rootFamilyKey: serializer.fromJson<String>(json['rootFamilyKey']),
      rootKey: serializer.fromJson<String>(json['rootKey']),
      rootFamily: serializer.fromJson<String>(json['rootFamily']),
      rootMeaning: serializer.fromJson<String>(json['rootMeaning']),
      html: serializer.fromJson<String>(json['html']),
      data: serializer.fromJson<String>(json['data']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rootFamilyKey': serializer.toJson<String>(rootFamilyKey),
      'rootKey': serializer.toJson<String>(rootKey),
      'rootFamily': serializer.toJson<String>(rootFamily),
      'rootMeaning': serializer.toJson<String>(rootMeaning),
      'html': serializer.toJson<String>(html),
      'data': serializer.toJson<String>(data),
      'count': serializer.toJson<int>(count),
    };
  }

  FamilyRootData copyWith({
    String? rootFamilyKey,
    String? rootKey,
    String? rootFamily,
    String? rootMeaning,
    String? html,
    String? data,
    int? count,
  }) => FamilyRootData(
    rootFamilyKey: rootFamilyKey ?? this.rootFamilyKey,
    rootKey: rootKey ?? this.rootKey,
    rootFamily: rootFamily ?? this.rootFamily,
    rootMeaning: rootMeaning ?? this.rootMeaning,
    html: html ?? this.html,
    data: data ?? this.data,
    count: count ?? this.count,
  );
  FamilyRootData copyWithCompanion(FamilyRootCompanion data) {
    return FamilyRootData(
      rootFamilyKey: data.rootFamilyKey.present
          ? data.rootFamilyKey.value
          : this.rootFamilyKey,
      rootKey: data.rootKey.present ? data.rootKey.value : this.rootKey,
      rootFamily: data.rootFamily.present
          ? data.rootFamily.value
          : this.rootFamily,
      rootMeaning: data.rootMeaning.present
          ? data.rootMeaning.value
          : this.rootMeaning,
      html: data.html.present ? data.html.value : this.html,
      data: data.data.present ? data.data.value : this.data,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyRootData(')
          ..write('rootFamilyKey: $rootFamilyKey, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootFamily: $rootFamily, ')
          ..write('rootMeaning: $rootMeaning, ')
          ..write('html: $html, ')
          ..write('data: $data, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rootFamilyKey,
    rootKey,
    rootFamily,
    rootMeaning,
    html,
    data,
    count,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyRootData &&
          other.rootFamilyKey == this.rootFamilyKey &&
          other.rootKey == this.rootKey &&
          other.rootFamily == this.rootFamily &&
          other.rootMeaning == this.rootMeaning &&
          other.html == this.html &&
          other.data == this.data &&
          other.count == this.count);
}

class FamilyRootCompanion extends UpdateCompanion<FamilyRootData> {
  final Value<String> rootFamilyKey;
  final Value<String> rootKey;
  final Value<String> rootFamily;
  final Value<String> rootMeaning;
  final Value<String> html;
  final Value<String> data;
  final Value<int> count;
  final Value<int> rowid;
  const FamilyRootCompanion({
    this.rootFamilyKey = const Value.absent(),
    this.rootKey = const Value.absent(),
    this.rootFamily = const Value.absent(),
    this.rootMeaning = const Value.absent(),
    this.html = const Value.absent(),
    this.data = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyRootCompanion.insert({
    required String rootFamilyKey,
    required String rootKey,
    required String rootFamily,
    required String rootMeaning,
    required String html,
    required String data,
    required int count,
    this.rowid = const Value.absent(),
  }) : rootFamilyKey = Value(rootFamilyKey),
       rootKey = Value(rootKey),
       rootFamily = Value(rootFamily),
       rootMeaning = Value(rootMeaning),
       html = Value(html),
       data = Value(data),
       count = Value(count);
  static Insertable<FamilyRootData> custom({
    Expression<String>? rootFamilyKey,
    Expression<String>? rootKey,
    Expression<String>? rootFamily,
    Expression<String>? rootMeaning,
    Expression<String>? html,
    Expression<String>? data,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rootFamilyKey != null) 'root_family_key': rootFamilyKey,
      if (rootKey != null) 'root_key': rootKey,
      if (rootFamily != null) 'root_family': rootFamily,
      if (rootMeaning != null) 'root_meaning': rootMeaning,
      if (html != null) 'html': html,
      if (data != null) 'data': data,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyRootCompanion copyWith({
    Value<String>? rootFamilyKey,
    Value<String>? rootKey,
    Value<String>? rootFamily,
    Value<String>? rootMeaning,
    Value<String>? html,
    Value<String>? data,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return FamilyRootCompanion(
      rootFamilyKey: rootFamilyKey ?? this.rootFamilyKey,
      rootKey: rootKey ?? this.rootKey,
      rootFamily: rootFamily ?? this.rootFamily,
      rootMeaning: rootMeaning ?? this.rootMeaning,
      html: html ?? this.html,
      data: data ?? this.data,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rootFamilyKey.present) {
      map['root_family_key'] = Variable<String>(rootFamilyKey.value);
    }
    if (rootKey.present) {
      map['root_key'] = Variable<String>(rootKey.value);
    }
    if (rootFamily.present) {
      map['root_family'] = Variable<String>(rootFamily.value);
    }
    if (rootMeaning.present) {
      map['root_meaning'] = Variable<String>(rootMeaning.value);
    }
    if (html.present) {
      map['html'] = Variable<String>(html.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyRootCompanion(')
          ..write('rootFamilyKey: $rootFamilyKey, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootFamily: $rootFamily, ')
          ..write('rootMeaning: $rootMeaning, ')
          ..write('html: $html, ')
          ..write('data: $data, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyWordTable extends FamilyWord
    with TableInfo<$FamilyWordTable, FamilyWordData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyWordTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordFamilyMeta = const VerificationMeta(
    'wordFamily',
  );
  @override
  late final GeneratedColumn<String> wordFamily = GeneratedColumn<String>(
    'word_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [wordFamily, data, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_word';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyWordData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_family')) {
      context.handle(
        _wordFamilyMeta,
        wordFamily.isAcceptableOrUnknown(data['word_family']!, _wordFamilyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordFamilyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordFamily};
  @override
  FamilyWordData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyWordData(
      wordFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_family'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $FamilyWordTable createAlias(String alias) {
    return $FamilyWordTable(attachedDatabase, alias);
  }
}

class FamilyWordData extends DataClass implements Insertable<FamilyWordData> {
  final String wordFamily;
  final String data;
  final int count;
  const FamilyWordData({
    required this.wordFamily,
    required this.data,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_family'] = Variable<String>(wordFamily);
    map['data'] = Variable<String>(data);
    map['count'] = Variable<int>(count);
    return map;
  }

  FamilyWordCompanion toCompanion(bool nullToAbsent) {
    return FamilyWordCompanion(
      wordFamily: Value(wordFamily),
      data: Value(data),
      count: Value(count),
    );
  }

  factory FamilyWordData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyWordData(
      wordFamily: serializer.fromJson<String>(json['wordFamily']),
      data: serializer.fromJson<String>(json['data']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordFamily': serializer.toJson<String>(wordFamily),
      'data': serializer.toJson<String>(data),
      'count': serializer.toJson<int>(count),
    };
  }

  FamilyWordData copyWith({String? wordFamily, String? data, int? count}) =>
      FamilyWordData(
        wordFamily: wordFamily ?? this.wordFamily,
        data: data ?? this.data,
        count: count ?? this.count,
      );
  FamilyWordData copyWithCompanion(FamilyWordCompanion data) {
    return FamilyWordData(
      wordFamily: data.wordFamily.present
          ? data.wordFamily.value
          : this.wordFamily,
      data: data.data.present ? data.data.value : this.data,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyWordData(')
          ..write('wordFamily: $wordFamily, ')
          ..write('data: $data, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordFamily, data, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyWordData &&
          other.wordFamily == this.wordFamily &&
          other.data == this.data &&
          other.count == this.count);
}

class FamilyWordCompanion extends UpdateCompanion<FamilyWordData> {
  final Value<String> wordFamily;
  final Value<String> data;
  final Value<int> count;
  final Value<int> rowid;
  const FamilyWordCompanion({
    this.wordFamily = const Value.absent(),
    this.data = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyWordCompanion.insert({
    required String wordFamily,
    required String data,
    required int count,
    this.rowid = const Value.absent(),
  }) : wordFamily = Value(wordFamily),
       data = Value(data),
       count = Value(count);
  static Insertable<FamilyWordData> custom({
    Expression<String>? wordFamily,
    Expression<String>? data,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordFamily != null) 'word_family': wordFamily,
      if (data != null) 'data': data,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyWordCompanion copyWith({
    Value<String>? wordFamily,
    Value<String>? data,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return FamilyWordCompanion(
      wordFamily: wordFamily ?? this.wordFamily,
      data: data ?? this.data,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordFamily.present) {
      map['word_family'] = Variable<String>(wordFamily.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyWordCompanion(')
          ..write('wordFamily: $wordFamily, ')
          ..write('data: $data, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyCompoundTable extends FamilyCompound
    with TableInfo<$FamilyCompoundTable, FamilyCompoundData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyCompoundTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _compoundFamilyMeta = const VerificationMeta(
    'compoundFamily',
  );
  @override
  late final GeneratedColumn<String> compoundFamily = GeneratedColumn<String>(
    'compound_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [compoundFamily, data, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_compound';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyCompoundData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('compound_family')) {
      context.handle(
        _compoundFamilyMeta,
        compoundFamily.isAcceptableOrUnknown(
          data['compound_family']!,
          _compoundFamilyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compoundFamilyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {compoundFamily};
  @override
  FamilyCompoundData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyCompoundData(
      compoundFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_family'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $FamilyCompoundTable createAlias(String alias) {
    return $FamilyCompoundTable(attachedDatabase, alias);
  }
}

class FamilyCompoundData extends DataClass
    implements Insertable<FamilyCompoundData> {
  final String compoundFamily;
  final String data;
  final int count;
  const FamilyCompoundData({
    required this.compoundFamily,
    required this.data,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['compound_family'] = Variable<String>(compoundFamily);
    map['data'] = Variable<String>(data);
    map['count'] = Variable<int>(count);
    return map;
  }

  FamilyCompoundCompanion toCompanion(bool nullToAbsent) {
    return FamilyCompoundCompanion(
      compoundFamily: Value(compoundFamily),
      data: Value(data),
      count: Value(count),
    );
  }

  factory FamilyCompoundData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyCompoundData(
      compoundFamily: serializer.fromJson<String>(json['compoundFamily']),
      data: serializer.fromJson<String>(json['data']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'compoundFamily': serializer.toJson<String>(compoundFamily),
      'data': serializer.toJson<String>(data),
      'count': serializer.toJson<int>(count),
    };
  }

  FamilyCompoundData copyWith({
    String? compoundFamily,
    String? data,
    int? count,
  }) => FamilyCompoundData(
    compoundFamily: compoundFamily ?? this.compoundFamily,
    data: data ?? this.data,
    count: count ?? this.count,
  );
  FamilyCompoundData copyWithCompanion(FamilyCompoundCompanion data) {
    return FamilyCompoundData(
      compoundFamily: data.compoundFamily.present
          ? data.compoundFamily.value
          : this.compoundFamily,
      data: data.data.present ? data.data.value : this.data,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyCompoundData(')
          ..write('compoundFamily: $compoundFamily, ')
          ..write('data: $data, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(compoundFamily, data, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyCompoundData &&
          other.compoundFamily == this.compoundFamily &&
          other.data == this.data &&
          other.count == this.count);
}

class FamilyCompoundCompanion extends UpdateCompanion<FamilyCompoundData> {
  final Value<String> compoundFamily;
  final Value<String> data;
  final Value<int> count;
  final Value<int> rowid;
  const FamilyCompoundCompanion({
    this.compoundFamily = const Value.absent(),
    this.data = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyCompoundCompanion.insert({
    required String compoundFamily,
    required String data,
    required int count,
    this.rowid = const Value.absent(),
  }) : compoundFamily = Value(compoundFamily),
       data = Value(data),
       count = Value(count);
  static Insertable<FamilyCompoundData> custom({
    Expression<String>? compoundFamily,
    Expression<String>? data,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (compoundFamily != null) 'compound_family': compoundFamily,
      if (data != null) 'data': data,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyCompoundCompanion copyWith({
    Value<String>? compoundFamily,
    Value<String>? data,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return FamilyCompoundCompanion(
      compoundFamily: compoundFamily ?? this.compoundFamily,
      data: data ?? this.data,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (compoundFamily.present) {
      map['compound_family'] = Variable<String>(compoundFamily.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyCompoundCompanion(')
          ..write('compoundFamily: $compoundFamily, ')
          ..write('data: $data, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyIdiomTable extends FamilyIdiom
    with TableInfo<$FamilyIdiomTable, FamilyIdiomData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyIdiomTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idiomMeta = const VerificationMeta('idiom');
  @override
  late final GeneratedColumn<String> idiom = GeneratedColumn<String>(
    'idiom',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [idiom, data, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_idiom';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyIdiomData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idiom')) {
      context.handle(
        _idiomMeta,
        idiom.isAcceptableOrUnknown(data['idiom']!, _idiomMeta),
      );
    } else if (isInserting) {
      context.missing(_idiomMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idiom};
  @override
  FamilyIdiomData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyIdiomData(
      idiom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idiom'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $FamilyIdiomTable createAlias(String alias) {
    return $FamilyIdiomTable(attachedDatabase, alias);
  }
}

class FamilyIdiomData extends DataClass implements Insertable<FamilyIdiomData> {
  final String idiom;
  final String data;
  final int count;
  const FamilyIdiomData({
    required this.idiom,
    required this.data,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idiom'] = Variable<String>(idiom);
    map['data'] = Variable<String>(data);
    map['count'] = Variable<int>(count);
    return map;
  }

  FamilyIdiomCompanion toCompanion(bool nullToAbsent) {
    return FamilyIdiomCompanion(
      idiom: Value(idiom),
      data: Value(data),
      count: Value(count),
    );
  }

  factory FamilyIdiomData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyIdiomData(
      idiom: serializer.fromJson<String>(json['idiom']),
      data: serializer.fromJson<String>(json['data']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idiom': serializer.toJson<String>(idiom),
      'data': serializer.toJson<String>(data),
      'count': serializer.toJson<int>(count),
    };
  }

  FamilyIdiomData copyWith({String? idiom, String? data, int? count}) =>
      FamilyIdiomData(
        idiom: idiom ?? this.idiom,
        data: data ?? this.data,
        count: count ?? this.count,
      );
  FamilyIdiomData copyWithCompanion(FamilyIdiomCompanion data) {
    return FamilyIdiomData(
      idiom: data.idiom.present ? data.idiom.value : this.idiom,
      data: data.data.present ? data.data.value : this.data,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyIdiomData(')
          ..write('idiom: $idiom, ')
          ..write('data: $data, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(idiom, data, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyIdiomData &&
          other.idiom == this.idiom &&
          other.data == this.data &&
          other.count == this.count);
}

class FamilyIdiomCompanion extends UpdateCompanion<FamilyIdiomData> {
  final Value<String> idiom;
  final Value<String> data;
  final Value<int> count;
  final Value<int> rowid;
  const FamilyIdiomCompanion({
    this.idiom = const Value.absent(),
    this.data = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyIdiomCompanion.insert({
    required String idiom,
    required String data,
    required int count,
    this.rowid = const Value.absent(),
  }) : idiom = Value(idiom),
       data = Value(data),
       count = Value(count);
  static Insertable<FamilyIdiomData> custom({
    Expression<String>? idiom,
    Expression<String>? data,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (idiom != null) 'idiom': idiom,
      if (data != null) 'data': data,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyIdiomCompanion copyWith({
    Value<String>? idiom,
    Value<String>? data,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return FamilyIdiomCompanion(
      idiom: idiom ?? this.idiom,
      data: data ?? this.data,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idiom.present) {
      map['idiom'] = Variable<String>(idiom.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyIdiomCompanion(')
          ..write('idiom: $idiom, ')
          ..write('data: $data, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilySetTable extends FamilySet
    with TableInfo<$FamilySetTable, FamilySetData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilySetTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _set_Meta = const VerificationMeta('set_');
  @override
  late final GeneratedColumn<String> set_ = GeneratedColumn<String>(
    'set',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [set_, data, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_set';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilySetData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('set')) {
      context.handle(
        _set_Meta,
        set_.isAcceptableOrUnknown(data['set']!, _set_Meta),
      );
    } else if (isInserting) {
      context.missing(_set_Meta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {set_};
  @override
  FamilySetData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilySetData(
      set_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $FamilySetTable createAlias(String alias) {
    return $FamilySetTable(attachedDatabase, alias);
  }
}

class FamilySetData extends DataClass implements Insertable<FamilySetData> {
  final String set_;
  final String data;
  final int count;
  const FamilySetData({
    required this.set_,
    required this.data,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['set'] = Variable<String>(set_);
    map['data'] = Variable<String>(data);
    map['count'] = Variable<int>(count);
    return map;
  }

  FamilySetCompanion toCompanion(bool nullToAbsent) {
    return FamilySetCompanion(
      set_: Value(set_),
      data: Value(data),
      count: Value(count),
    );
  }

  factory FamilySetData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilySetData(
      set_: serializer.fromJson<String>(json['set_']),
      data: serializer.fromJson<String>(json['data']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'set_': serializer.toJson<String>(set_),
      'data': serializer.toJson<String>(data),
      'count': serializer.toJson<int>(count),
    };
  }

  FamilySetData copyWith({String? set_, String? data, int? count}) =>
      FamilySetData(
        set_: set_ ?? this.set_,
        data: data ?? this.data,
        count: count ?? this.count,
      );
  FamilySetData copyWithCompanion(FamilySetCompanion data) {
    return FamilySetData(
      set_: data.set_.present ? data.set_.value : this.set_,
      data: data.data.present ? data.data.value : this.data,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilySetData(')
          ..write('set_: $set_, ')
          ..write('data: $data, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(set_, data, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilySetData &&
          other.set_ == this.set_ &&
          other.data == this.data &&
          other.count == this.count);
}

class FamilySetCompanion extends UpdateCompanion<FamilySetData> {
  final Value<String> set_;
  final Value<String> data;
  final Value<int> count;
  final Value<int> rowid;
  const FamilySetCompanion({
    this.set_ = const Value.absent(),
    this.data = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilySetCompanion.insert({
    required String set_,
    required String data,
    required int count,
    this.rowid = const Value.absent(),
  }) : set_ = Value(set_),
       data = Value(data),
       count = Value(count);
  static Insertable<FamilySetData> custom({
    Expression<String>? set_,
    Expression<String>? data,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (set_ != null) 'set': set_,
      if (data != null) 'data': data,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilySetCompanion copyWith({
    Value<String>? set_,
    Value<String>? data,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return FamilySetCompanion(
      set_: set_ ?? this.set_,
      data: data ?? this.data,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (set_.present) {
      map['set'] = Variable<String>(set_.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilySetCompanion(')
          ..write('set_: $set_, ')
          ..write('data: $data, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuttaInfoTable extends SuttaInfo
    with TableInfo<$SuttaInfoTable, SuttaInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuttaInfoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookMeta = const VerificationMeta('book');
  @override
  late final GeneratedColumn<String> book = GeneratedColumn<String>(
    'book',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookCodeMeta = const VerificationMeta(
    'bookCode',
  );
  @override
  late final GeneratedColumn<String> bookCode = GeneratedColumn<String>(
    'book_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dpdCodeMeta = const VerificationMeta(
    'dpdCode',
  );
  @override
  late final GeneratedColumn<String> dpdCode = GeneratedColumn<String>(
    'dpd_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dpdSuttaMeta = const VerificationMeta(
    'dpdSutta',
  );
  @override
  late final GeneratedColumn<String> dpdSutta = GeneratedColumn<String>(
    'dpd_sutta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dpdSuttaVarMeta = const VerificationMeta(
    'dpdSuttaVar',
  );
  @override
  late final GeneratedColumn<String> dpdSuttaVar = GeneratedColumn<String>(
    'dpd_sutta_var',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstCodeMeta = const VerificationMeta(
    'cstCode',
  );
  @override
  late final GeneratedColumn<String> cstCode = GeneratedColumn<String>(
    'cst_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstNikayaMeta = const VerificationMeta(
    'cstNikaya',
  );
  @override
  late final GeneratedColumn<String> cstNikaya = GeneratedColumn<String>(
    'cst_nikaya',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstBookMeta = const VerificationMeta(
    'cstBook',
  );
  @override
  late final GeneratedColumn<String> cstBook = GeneratedColumn<String>(
    'cst_book',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstSectionMeta = const VerificationMeta(
    'cstSection',
  );
  @override
  late final GeneratedColumn<String> cstSection = GeneratedColumn<String>(
    'cst_section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstVaggaMeta = const VerificationMeta(
    'cstVagga',
  );
  @override
  late final GeneratedColumn<String> cstVagga = GeneratedColumn<String>(
    'cst_vagga',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstSuttaMeta = const VerificationMeta(
    'cstSutta',
  );
  @override
  late final GeneratedColumn<String> cstSutta = GeneratedColumn<String>(
    'cst_sutta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstParanumMeta = const VerificationMeta(
    'cstParanum',
  );
  @override
  late final GeneratedColumn<String> cstParanum = GeneratedColumn<String>(
    'cst_paranum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstMPageMeta = const VerificationMeta(
    'cstMPage',
  );
  @override
  late final GeneratedColumn<String> cstMPage = GeneratedColumn<String>(
    'cst_m_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstVPageMeta = const VerificationMeta(
    'cstVPage',
  );
  @override
  late final GeneratedColumn<String> cstVPage = GeneratedColumn<String>(
    'cst_v_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstPPageMeta = const VerificationMeta(
    'cstPPage',
  );
  @override
  late final GeneratedColumn<String> cstPPage = GeneratedColumn<String>(
    'cst_p_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstTPageMeta = const VerificationMeta(
    'cstTPage',
  );
  @override
  late final GeneratedColumn<String> cstTPage = GeneratedColumn<String>(
    'cst_t_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cstFileMeta = const VerificationMeta(
    'cstFile',
  );
  @override
  late final GeneratedColumn<String> cstFile = GeneratedColumn<String>(
    'cst_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scCodeMeta = const VerificationMeta('scCode');
  @override
  late final GeneratedColumn<String> scCode = GeneratedColumn<String>(
    'sc_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scBookMeta = const VerificationMeta('scBook');
  @override
  late final GeneratedColumn<String> scBook = GeneratedColumn<String>(
    'sc_book',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scVaggaMeta = const VerificationMeta(
    'scVagga',
  );
  @override
  late final GeneratedColumn<String> scVagga = GeneratedColumn<String>(
    'sc_vagga',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scSuttaMeta = const VerificationMeta(
    'scSutta',
  );
  @override
  late final GeneratedColumn<String> scSutta = GeneratedColumn<String>(
    'sc_sutta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scEngSuttaMeta = const VerificationMeta(
    'scEngSutta',
  );
  @override
  late final GeneratedColumn<String> scEngSutta = GeneratedColumn<String>(
    'sc_eng_sutta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scBlurbMeta = const VerificationMeta(
    'scBlurb',
  );
  @override
  late final GeneratedColumn<String> scBlurb = GeneratedColumn<String>(
    'sc_blurb',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scFilePathMeta = const VerificationMeta(
    'scFilePath',
  );
  @override
  late final GeneratedColumn<String> scFilePath = GeneratedColumn<String>(
    'sc_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dprCodeMeta = const VerificationMeta(
    'dprCode',
  );
  @override
  late final GeneratedColumn<String> dprCode = GeneratedColumn<String>(
    'dpr_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dprLinkMeta = const VerificationMeta(
    'dprLink',
  );
  @override
  late final GeneratedColumn<String> dprLink = GeneratedColumn<String>(
    'dpr_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtSuttaCodeMeta = const VerificationMeta(
    'bjtSuttaCode',
  );
  @override
  late final GeneratedColumn<String> bjtSuttaCode = GeneratedColumn<String>(
    'bjt_sutta_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtWebCodeMeta = const VerificationMeta(
    'bjtWebCode',
  );
  @override
  late final GeneratedColumn<String> bjtWebCode = GeneratedColumn<String>(
    'bjt_web_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtFilenameMeta = const VerificationMeta(
    'bjtFilename',
  );
  @override
  late final GeneratedColumn<String> bjtFilename = GeneratedColumn<String>(
    'bjt_filename',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtBookIdMeta = const VerificationMeta(
    'bjtBookId',
  );
  @override
  late final GeneratedColumn<String> bjtBookId = GeneratedColumn<String>(
    'bjt_book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtPageNumMeta = const VerificationMeta(
    'bjtPageNum',
  );
  @override
  late final GeneratedColumn<String> bjtPageNum = GeneratedColumn<String>(
    'bjt_page_num',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtPageOffsetMeta = const VerificationMeta(
    'bjtPageOffset',
  );
  @override
  late final GeneratedColumn<String> bjtPageOffset = GeneratedColumn<String>(
    'bjt_page_offset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtPitakaMeta = const VerificationMeta(
    'bjtPitaka',
  );
  @override
  late final GeneratedColumn<String> bjtPitaka = GeneratedColumn<String>(
    'bjt_piṭaka',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtNikayaMeta = const VerificationMeta(
    'bjtNikaya',
  );
  @override
  late final GeneratedColumn<String> bjtNikaya = GeneratedColumn<String>(
    'bjt_nikāya',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtMajorSectionMeta = const VerificationMeta(
    'bjtMajorSection',
  );
  @override
  late final GeneratedColumn<String> bjtMajorSection = GeneratedColumn<String>(
    'bjt_major_section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtBookMeta = const VerificationMeta(
    'bjtBook',
  );
  @override
  late final GeneratedColumn<String> bjtBook = GeneratedColumn<String>(
    'bjt_book',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtMinorSectionMeta = const VerificationMeta(
    'bjtMinorSection',
  );
  @override
  late final GeneratedColumn<String> bjtMinorSection = GeneratedColumn<String>(
    'bjt_minor_section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtVaggaMeta = const VerificationMeta(
    'bjtVagga',
  );
  @override
  late final GeneratedColumn<String> bjtVagga = GeneratedColumn<String>(
    'bjt_vagga',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bjtSuttaMeta = const VerificationMeta(
    'bjtSutta',
  );
  @override
  late final GeneratedColumn<String> bjtSutta = GeneratedColumn<String>(
    'bjt_sutta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvPtsMeta = const VerificationMeta('dvPts');
  @override
  late final GeneratedColumn<String> dvPts = GeneratedColumn<String>(
    'dv_pts',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvMainThemeMeta = const VerificationMeta(
    'dvMainTheme',
  );
  @override
  late final GeneratedColumn<String> dvMainTheme = GeneratedColumn<String>(
    'dv_main_theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvSubtopicMeta = const VerificationMeta(
    'dvSubtopic',
  );
  @override
  late final GeneratedColumn<String> dvSubtopic = GeneratedColumn<String>(
    'dv_subtopic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvSummaryMeta = const VerificationMeta(
    'dvSummary',
  );
  @override
  late final GeneratedColumn<String> dvSummary = GeneratedColumn<String>(
    'dv_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvSimilesMeta = const VerificationMeta(
    'dvSimiles',
  );
  @override
  late final GeneratedColumn<String> dvSimiles = GeneratedColumn<String>(
    'dv_similes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvKeyExcerpt1Meta = const VerificationMeta(
    'dvKeyExcerpt1',
  );
  @override
  late final GeneratedColumn<String> dvKeyExcerpt1 = GeneratedColumn<String>(
    'dv_key_excerpt1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvKeyExcerpt2Meta = const VerificationMeta(
    'dvKeyExcerpt2',
  );
  @override
  late final GeneratedColumn<String> dvKeyExcerpt2 = GeneratedColumn<String>(
    'dv_key_excerpt2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvStageMeta = const VerificationMeta(
    'dvStage',
  );
  @override
  late final GeneratedColumn<String> dvStage = GeneratedColumn<String>(
    'dv_stage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvTrainingMeta = const VerificationMeta(
    'dvTraining',
  );
  @override
  late final GeneratedColumn<String> dvTraining = GeneratedColumn<String>(
    'dv_training',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvAspectMeta = const VerificationMeta(
    'dvAspect',
  );
  @override
  late final GeneratedColumn<String> dvAspect = GeneratedColumn<String>(
    'dv_aspect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvTeacherMeta = const VerificationMeta(
    'dvTeacher',
  );
  @override
  late final GeneratedColumn<String> dvTeacher = GeneratedColumn<String>(
    'dv_teacher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvAudienceMeta = const VerificationMeta(
    'dvAudience',
  );
  @override
  late final GeneratedColumn<String> dvAudience = GeneratedColumn<String>(
    'dv_audience',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvMethodMeta = const VerificationMeta(
    'dvMethod',
  );
  @override
  late final GeneratedColumn<String> dvMethod = GeneratedColumn<String>(
    'dv_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvLengthMeta = const VerificationMeta(
    'dvLength',
  );
  @override
  late final GeneratedColumn<String> dvLength = GeneratedColumn<String>(
    'dv_length',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvProminenceMeta = const VerificationMeta(
    'dvProminence',
  );
  @override
  late final GeneratedColumn<String> dvProminence = GeneratedColumn<String>(
    'dv_prominence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dvNikayasParallelsMeta =
      const VerificationMeta('dvNikayasParallels');
  @override
  late final GeneratedColumn<String> dvNikayasParallels =
      GeneratedColumn<String>(
        'dv_nikayas_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvAgamasParallelsMeta = const VerificationMeta(
    'dvAgamasParallels',
  );
  @override
  late final GeneratedColumn<String> dvAgamasParallels =
      GeneratedColumn<String>(
        'dv_āgamas_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvTaishoParallelsMeta = const VerificationMeta(
    'dvTaishoParallels',
  );
  @override
  late final GeneratedColumn<String> dvTaishoParallels =
      GeneratedColumn<String>(
        'dv_taisho_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvSanskritParallelsMeta =
      const VerificationMeta('dvSanskritParallels');
  @override
  late final GeneratedColumn<String> dvSanskritParallels =
      GeneratedColumn<String>(
        'dv_sanskrit_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvVinayaParallelsMeta = const VerificationMeta(
    'dvVinayaParallels',
  );
  @override
  late final GeneratedColumn<String> dvVinayaParallels =
      GeneratedColumn<String>(
        'dv_vinaya_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvOthersParallelsMeta = const VerificationMeta(
    'dvOthersParallels',
  );
  @override
  late final GeneratedColumn<String> dvOthersParallels =
      GeneratedColumn<String>(
        'dv_others_parallels',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvPartialParallelsNaMeta =
      const VerificationMeta('dvPartialParallelsNa');
  @override
  late final GeneratedColumn<String> dvPartialParallelsNa =
      GeneratedColumn<String>(
        'dv_partial_parallels_nā',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvPartialParallelsAllMeta =
      const VerificationMeta('dvPartialParallelsAll');
  @override
  late final GeneratedColumn<String> dvPartialParallelsAll =
      GeneratedColumn<String>(
        'dv_partial_parallels_all',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dvSuggestedSuttasMeta = const VerificationMeta(
    'dvSuggestedSuttas',
  );
  @override
  late final GeneratedColumn<String> dvSuggestedSuttas =
      GeneratedColumn<String>(
        'dv_suggested_suttas',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    book,
    bookCode,
    dpdCode,
    dpdSutta,
    dpdSuttaVar,
    cstCode,
    cstNikaya,
    cstBook,
    cstSection,
    cstVagga,
    cstSutta,
    cstParanum,
    cstMPage,
    cstVPage,
    cstPPage,
    cstTPage,
    cstFile,
    scCode,
    scBook,
    scVagga,
    scSutta,
    scEngSutta,
    scBlurb,
    scFilePath,
    dprCode,
    dprLink,
    bjtSuttaCode,
    bjtWebCode,
    bjtFilename,
    bjtBookId,
    bjtPageNum,
    bjtPageOffset,
    bjtPitaka,
    bjtNikaya,
    bjtMajorSection,
    bjtBook,
    bjtMinorSection,
    bjtVagga,
    bjtSutta,
    dvPts,
    dvMainTheme,
    dvSubtopic,
    dvSummary,
    dvSimiles,
    dvKeyExcerpt1,
    dvKeyExcerpt2,
    dvStage,
    dvTraining,
    dvAspect,
    dvTeacher,
    dvAudience,
    dvMethod,
    dvLength,
    dvProminence,
    dvNikayasParallels,
    dvAgamasParallels,
    dvTaishoParallels,
    dvSanskritParallels,
    dvVinayaParallels,
    dvOthersParallels,
    dvPartialParallelsNa,
    dvPartialParallelsAll,
    dvSuggestedSuttas,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sutta_info';
  @override
  VerificationContext validateIntegrity(
    Insertable<SuttaInfoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book')) {
      context.handle(
        _bookMeta,
        book.isAcceptableOrUnknown(data['book']!, _bookMeta),
      );
    }
    if (data.containsKey('book_code')) {
      context.handle(
        _bookCodeMeta,
        bookCode.isAcceptableOrUnknown(data['book_code']!, _bookCodeMeta),
      );
    }
    if (data.containsKey('dpd_code')) {
      context.handle(
        _dpdCodeMeta,
        dpdCode.isAcceptableOrUnknown(data['dpd_code']!, _dpdCodeMeta),
      );
    }
    if (data.containsKey('dpd_sutta')) {
      context.handle(
        _dpdSuttaMeta,
        dpdSutta.isAcceptableOrUnknown(data['dpd_sutta']!, _dpdSuttaMeta),
      );
    } else if (isInserting) {
      context.missing(_dpdSuttaMeta);
    }
    if (data.containsKey('dpd_sutta_var')) {
      context.handle(
        _dpdSuttaVarMeta,
        dpdSuttaVar.isAcceptableOrUnknown(
          data['dpd_sutta_var']!,
          _dpdSuttaVarMeta,
        ),
      );
    }
    if (data.containsKey('cst_code')) {
      context.handle(
        _cstCodeMeta,
        cstCode.isAcceptableOrUnknown(data['cst_code']!, _cstCodeMeta),
      );
    }
    if (data.containsKey('cst_nikaya')) {
      context.handle(
        _cstNikayaMeta,
        cstNikaya.isAcceptableOrUnknown(data['cst_nikaya']!, _cstNikayaMeta),
      );
    }
    if (data.containsKey('cst_book')) {
      context.handle(
        _cstBookMeta,
        cstBook.isAcceptableOrUnknown(data['cst_book']!, _cstBookMeta),
      );
    }
    if (data.containsKey('cst_section')) {
      context.handle(
        _cstSectionMeta,
        cstSection.isAcceptableOrUnknown(data['cst_section']!, _cstSectionMeta),
      );
    }
    if (data.containsKey('cst_vagga')) {
      context.handle(
        _cstVaggaMeta,
        cstVagga.isAcceptableOrUnknown(data['cst_vagga']!, _cstVaggaMeta),
      );
    }
    if (data.containsKey('cst_sutta')) {
      context.handle(
        _cstSuttaMeta,
        cstSutta.isAcceptableOrUnknown(data['cst_sutta']!, _cstSuttaMeta),
      );
    }
    if (data.containsKey('cst_paranum')) {
      context.handle(
        _cstParanumMeta,
        cstParanum.isAcceptableOrUnknown(data['cst_paranum']!, _cstParanumMeta),
      );
    }
    if (data.containsKey('cst_m_page')) {
      context.handle(
        _cstMPageMeta,
        cstMPage.isAcceptableOrUnknown(data['cst_m_page']!, _cstMPageMeta),
      );
    }
    if (data.containsKey('cst_v_page')) {
      context.handle(
        _cstVPageMeta,
        cstVPage.isAcceptableOrUnknown(data['cst_v_page']!, _cstVPageMeta),
      );
    }
    if (data.containsKey('cst_p_page')) {
      context.handle(
        _cstPPageMeta,
        cstPPage.isAcceptableOrUnknown(data['cst_p_page']!, _cstPPageMeta),
      );
    }
    if (data.containsKey('cst_t_page')) {
      context.handle(
        _cstTPageMeta,
        cstTPage.isAcceptableOrUnknown(data['cst_t_page']!, _cstTPageMeta),
      );
    }
    if (data.containsKey('cst_file')) {
      context.handle(
        _cstFileMeta,
        cstFile.isAcceptableOrUnknown(data['cst_file']!, _cstFileMeta),
      );
    }
    if (data.containsKey('sc_code')) {
      context.handle(
        _scCodeMeta,
        scCode.isAcceptableOrUnknown(data['sc_code']!, _scCodeMeta),
      );
    }
    if (data.containsKey('sc_book')) {
      context.handle(
        _scBookMeta,
        scBook.isAcceptableOrUnknown(data['sc_book']!, _scBookMeta),
      );
    }
    if (data.containsKey('sc_vagga')) {
      context.handle(
        _scVaggaMeta,
        scVagga.isAcceptableOrUnknown(data['sc_vagga']!, _scVaggaMeta),
      );
    }
    if (data.containsKey('sc_sutta')) {
      context.handle(
        _scSuttaMeta,
        scSutta.isAcceptableOrUnknown(data['sc_sutta']!, _scSuttaMeta),
      );
    }
    if (data.containsKey('sc_eng_sutta')) {
      context.handle(
        _scEngSuttaMeta,
        scEngSutta.isAcceptableOrUnknown(
          data['sc_eng_sutta']!,
          _scEngSuttaMeta,
        ),
      );
    }
    if (data.containsKey('sc_blurb')) {
      context.handle(
        _scBlurbMeta,
        scBlurb.isAcceptableOrUnknown(data['sc_blurb']!, _scBlurbMeta),
      );
    }
    if (data.containsKey('sc_file_path')) {
      context.handle(
        _scFilePathMeta,
        scFilePath.isAcceptableOrUnknown(
          data['sc_file_path']!,
          _scFilePathMeta,
        ),
      );
    }
    if (data.containsKey('dpr_code')) {
      context.handle(
        _dprCodeMeta,
        dprCode.isAcceptableOrUnknown(data['dpr_code']!, _dprCodeMeta),
      );
    }
    if (data.containsKey('dpr_link')) {
      context.handle(
        _dprLinkMeta,
        dprLink.isAcceptableOrUnknown(data['dpr_link']!, _dprLinkMeta),
      );
    }
    if (data.containsKey('bjt_sutta_code')) {
      context.handle(
        _bjtSuttaCodeMeta,
        bjtSuttaCode.isAcceptableOrUnknown(
          data['bjt_sutta_code']!,
          _bjtSuttaCodeMeta,
        ),
      );
    }
    if (data.containsKey('bjt_web_code')) {
      context.handle(
        _bjtWebCodeMeta,
        bjtWebCode.isAcceptableOrUnknown(
          data['bjt_web_code']!,
          _bjtWebCodeMeta,
        ),
      );
    }
    if (data.containsKey('bjt_filename')) {
      context.handle(
        _bjtFilenameMeta,
        bjtFilename.isAcceptableOrUnknown(
          data['bjt_filename']!,
          _bjtFilenameMeta,
        ),
      );
    }
    if (data.containsKey('bjt_book_id')) {
      context.handle(
        _bjtBookIdMeta,
        bjtBookId.isAcceptableOrUnknown(data['bjt_book_id']!, _bjtBookIdMeta),
      );
    }
    if (data.containsKey('bjt_page_num')) {
      context.handle(
        _bjtPageNumMeta,
        bjtPageNum.isAcceptableOrUnknown(
          data['bjt_page_num']!,
          _bjtPageNumMeta,
        ),
      );
    }
    if (data.containsKey('bjt_page_offset')) {
      context.handle(
        _bjtPageOffsetMeta,
        bjtPageOffset.isAcceptableOrUnknown(
          data['bjt_page_offset']!,
          _bjtPageOffsetMeta,
        ),
      );
    }
    if (data.containsKey('bjt_piṭaka')) {
      context.handle(
        _bjtPitakaMeta,
        bjtPitaka.isAcceptableOrUnknown(data['bjt_piṭaka']!, _bjtPitakaMeta),
      );
    }
    if (data.containsKey('bjt_nikāya')) {
      context.handle(
        _bjtNikayaMeta,
        bjtNikaya.isAcceptableOrUnknown(data['bjt_nikāya']!, _bjtNikayaMeta),
      );
    }
    if (data.containsKey('bjt_major_section')) {
      context.handle(
        _bjtMajorSectionMeta,
        bjtMajorSection.isAcceptableOrUnknown(
          data['bjt_major_section']!,
          _bjtMajorSectionMeta,
        ),
      );
    }
    if (data.containsKey('bjt_book')) {
      context.handle(
        _bjtBookMeta,
        bjtBook.isAcceptableOrUnknown(data['bjt_book']!, _bjtBookMeta),
      );
    }
    if (data.containsKey('bjt_minor_section')) {
      context.handle(
        _bjtMinorSectionMeta,
        bjtMinorSection.isAcceptableOrUnknown(
          data['bjt_minor_section']!,
          _bjtMinorSectionMeta,
        ),
      );
    }
    if (data.containsKey('bjt_vagga')) {
      context.handle(
        _bjtVaggaMeta,
        bjtVagga.isAcceptableOrUnknown(data['bjt_vagga']!, _bjtVaggaMeta),
      );
    }
    if (data.containsKey('bjt_sutta')) {
      context.handle(
        _bjtSuttaMeta,
        bjtSutta.isAcceptableOrUnknown(data['bjt_sutta']!, _bjtSuttaMeta),
      );
    }
    if (data.containsKey('dv_pts')) {
      context.handle(
        _dvPtsMeta,
        dvPts.isAcceptableOrUnknown(data['dv_pts']!, _dvPtsMeta),
      );
    }
    if (data.containsKey('dv_main_theme')) {
      context.handle(
        _dvMainThemeMeta,
        dvMainTheme.isAcceptableOrUnknown(
          data['dv_main_theme']!,
          _dvMainThemeMeta,
        ),
      );
    }
    if (data.containsKey('dv_subtopic')) {
      context.handle(
        _dvSubtopicMeta,
        dvSubtopic.isAcceptableOrUnknown(data['dv_subtopic']!, _dvSubtopicMeta),
      );
    }
    if (data.containsKey('dv_summary')) {
      context.handle(
        _dvSummaryMeta,
        dvSummary.isAcceptableOrUnknown(data['dv_summary']!, _dvSummaryMeta),
      );
    }
    if (data.containsKey('dv_similes')) {
      context.handle(
        _dvSimilesMeta,
        dvSimiles.isAcceptableOrUnknown(data['dv_similes']!, _dvSimilesMeta),
      );
    }
    if (data.containsKey('dv_key_excerpt1')) {
      context.handle(
        _dvKeyExcerpt1Meta,
        dvKeyExcerpt1.isAcceptableOrUnknown(
          data['dv_key_excerpt1']!,
          _dvKeyExcerpt1Meta,
        ),
      );
    }
    if (data.containsKey('dv_key_excerpt2')) {
      context.handle(
        _dvKeyExcerpt2Meta,
        dvKeyExcerpt2.isAcceptableOrUnknown(
          data['dv_key_excerpt2']!,
          _dvKeyExcerpt2Meta,
        ),
      );
    }
    if (data.containsKey('dv_stage')) {
      context.handle(
        _dvStageMeta,
        dvStage.isAcceptableOrUnknown(data['dv_stage']!, _dvStageMeta),
      );
    }
    if (data.containsKey('dv_training')) {
      context.handle(
        _dvTrainingMeta,
        dvTraining.isAcceptableOrUnknown(data['dv_training']!, _dvTrainingMeta),
      );
    }
    if (data.containsKey('dv_aspect')) {
      context.handle(
        _dvAspectMeta,
        dvAspect.isAcceptableOrUnknown(data['dv_aspect']!, _dvAspectMeta),
      );
    }
    if (data.containsKey('dv_teacher')) {
      context.handle(
        _dvTeacherMeta,
        dvTeacher.isAcceptableOrUnknown(data['dv_teacher']!, _dvTeacherMeta),
      );
    }
    if (data.containsKey('dv_audience')) {
      context.handle(
        _dvAudienceMeta,
        dvAudience.isAcceptableOrUnknown(data['dv_audience']!, _dvAudienceMeta),
      );
    }
    if (data.containsKey('dv_method')) {
      context.handle(
        _dvMethodMeta,
        dvMethod.isAcceptableOrUnknown(data['dv_method']!, _dvMethodMeta),
      );
    }
    if (data.containsKey('dv_length')) {
      context.handle(
        _dvLengthMeta,
        dvLength.isAcceptableOrUnknown(data['dv_length']!, _dvLengthMeta),
      );
    }
    if (data.containsKey('dv_prominence')) {
      context.handle(
        _dvProminenceMeta,
        dvProminence.isAcceptableOrUnknown(
          data['dv_prominence']!,
          _dvProminenceMeta,
        ),
      );
    }
    if (data.containsKey('dv_nikayas_parallels')) {
      context.handle(
        _dvNikayasParallelsMeta,
        dvNikayasParallels.isAcceptableOrUnknown(
          data['dv_nikayas_parallels']!,
          _dvNikayasParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_āgamas_parallels')) {
      context.handle(
        _dvAgamasParallelsMeta,
        dvAgamasParallels.isAcceptableOrUnknown(
          data['dv_āgamas_parallels']!,
          _dvAgamasParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_taisho_parallels')) {
      context.handle(
        _dvTaishoParallelsMeta,
        dvTaishoParallels.isAcceptableOrUnknown(
          data['dv_taisho_parallels']!,
          _dvTaishoParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_sanskrit_parallels')) {
      context.handle(
        _dvSanskritParallelsMeta,
        dvSanskritParallels.isAcceptableOrUnknown(
          data['dv_sanskrit_parallels']!,
          _dvSanskritParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_vinaya_parallels')) {
      context.handle(
        _dvVinayaParallelsMeta,
        dvVinayaParallels.isAcceptableOrUnknown(
          data['dv_vinaya_parallels']!,
          _dvVinayaParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_others_parallels')) {
      context.handle(
        _dvOthersParallelsMeta,
        dvOthersParallels.isAcceptableOrUnknown(
          data['dv_others_parallels']!,
          _dvOthersParallelsMeta,
        ),
      );
    }
    if (data.containsKey('dv_partial_parallels_nā')) {
      context.handle(
        _dvPartialParallelsNaMeta,
        dvPartialParallelsNa.isAcceptableOrUnknown(
          data['dv_partial_parallels_nā']!,
          _dvPartialParallelsNaMeta,
        ),
      );
    }
    if (data.containsKey('dv_partial_parallels_all')) {
      context.handle(
        _dvPartialParallelsAllMeta,
        dvPartialParallelsAll.isAcceptableOrUnknown(
          data['dv_partial_parallels_all']!,
          _dvPartialParallelsAllMeta,
        ),
      );
    }
    if (data.containsKey('dv_suggested_suttas')) {
      context.handle(
        _dvSuggestedSuttasMeta,
        dvSuggestedSuttas.isAcceptableOrUnknown(
          data['dv_suggested_suttas']!,
          _dvSuggestedSuttasMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dpdSutta};
  @override
  SuttaInfoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SuttaInfoData(
      book: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book'],
      ),
      bookCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_code'],
      ),
      dpdCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dpd_code'],
      ),
      dpdSutta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dpd_sutta'],
      )!,
      dpdSuttaVar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dpd_sutta_var'],
      ),
      cstCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_code'],
      ),
      cstNikaya: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_nikaya'],
      ),
      cstBook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_book'],
      ),
      cstSection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_section'],
      ),
      cstVagga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_vagga'],
      ),
      cstSutta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_sutta'],
      ),
      cstParanum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_paranum'],
      ),
      cstMPage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_m_page'],
      ),
      cstVPage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_v_page'],
      ),
      cstPPage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_p_page'],
      ),
      cstTPage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_t_page'],
      ),
      cstFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cst_file'],
      ),
      scCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_code'],
      ),
      scBook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_book'],
      ),
      scVagga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_vagga'],
      ),
      scSutta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_sutta'],
      ),
      scEngSutta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_eng_sutta'],
      ),
      scBlurb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_blurb'],
      ),
      scFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sc_file_path'],
      ),
      dprCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dpr_code'],
      ),
      dprLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dpr_link'],
      ),
      bjtSuttaCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_sutta_code'],
      ),
      bjtWebCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_web_code'],
      ),
      bjtFilename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_filename'],
      ),
      bjtBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_book_id'],
      ),
      bjtPageNum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_page_num'],
      ),
      bjtPageOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_page_offset'],
      ),
      bjtPitaka: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_piṭaka'],
      ),
      bjtNikaya: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_nikāya'],
      ),
      bjtMajorSection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_major_section'],
      ),
      bjtBook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_book'],
      ),
      bjtMinorSection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_minor_section'],
      ),
      bjtVagga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_vagga'],
      ),
      bjtSutta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bjt_sutta'],
      ),
      dvPts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_pts'],
      ),
      dvMainTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_main_theme'],
      ),
      dvSubtopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_subtopic'],
      ),
      dvSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_summary'],
      ),
      dvSimiles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_similes'],
      ),
      dvKeyExcerpt1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_key_excerpt1'],
      ),
      dvKeyExcerpt2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_key_excerpt2'],
      ),
      dvStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_stage'],
      ),
      dvTraining: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_training'],
      ),
      dvAspect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_aspect'],
      ),
      dvTeacher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_teacher'],
      ),
      dvAudience: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_audience'],
      ),
      dvMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_method'],
      ),
      dvLength: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_length'],
      ),
      dvProminence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_prominence'],
      ),
      dvNikayasParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_nikayas_parallels'],
      ),
      dvAgamasParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_āgamas_parallels'],
      ),
      dvTaishoParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_taisho_parallels'],
      ),
      dvSanskritParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_sanskrit_parallels'],
      ),
      dvVinayaParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_vinaya_parallels'],
      ),
      dvOthersParallels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_others_parallels'],
      ),
      dvPartialParallelsNa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_partial_parallels_nā'],
      ),
      dvPartialParallelsAll: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_partial_parallels_all'],
      ),
      dvSuggestedSuttas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dv_suggested_suttas'],
      ),
    );
  }

  @override
  $SuttaInfoTable createAlias(String alias) {
    return $SuttaInfoTable(attachedDatabase, alias);
  }
}

class SuttaInfoData extends DataClass implements Insertable<SuttaInfoData> {
  final String? book;
  final String? bookCode;
  final String? dpdCode;
  final String dpdSutta;
  final String? dpdSuttaVar;
  final String? cstCode;
  final String? cstNikaya;
  final String? cstBook;
  final String? cstSection;
  final String? cstVagga;
  final String? cstSutta;
  final String? cstParanum;
  final String? cstMPage;
  final String? cstVPage;
  final String? cstPPage;
  final String? cstTPage;
  final String? cstFile;
  final String? scCode;
  final String? scBook;
  final String? scVagga;
  final String? scSutta;
  final String? scEngSutta;
  final String? scBlurb;
  final String? scFilePath;
  final String? dprCode;
  final String? dprLink;
  final String? bjtSuttaCode;
  final String? bjtWebCode;
  final String? bjtFilename;
  final String? bjtBookId;
  final String? bjtPageNum;
  final String? bjtPageOffset;
  final String? bjtPitaka;
  final String? bjtNikaya;
  final String? bjtMajorSection;
  final String? bjtBook;
  final String? bjtMinorSection;
  final String? bjtVagga;
  final String? bjtSutta;
  final String? dvPts;
  final String? dvMainTheme;
  final String? dvSubtopic;
  final String? dvSummary;
  final String? dvSimiles;
  final String? dvKeyExcerpt1;
  final String? dvKeyExcerpt2;
  final String? dvStage;
  final String? dvTraining;
  final String? dvAspect;
  final String? dvTeacher;
  final String? dvAudience;
  final String? dvMethod;
  final String? dvLength;
  final String? dvProminence;
  final String? dvNikayasParallels;
  final String? dvAgamasParallels;
  final String? dvTaishoParallels;
  final String? dvSanskritParallels;
  final String? dvVinayaParallels;
  final String? dvOthersParallels;
  final String? dvPartialParallelsNa;
  final String? dvPartialParallelsAll;
  final String? dvSuggestedSuttas;
  const SuttaInfoData({
    this.book,
    this.bookCode,
    this.dpdCode,
    required this.dpdSutta,
    this.dpdSuttaVar,
    this.cstCode,
    this.cstNikaya,
    this.cstBook,
    this.cstSection,
    this.cstVagga,
    this.cstSutta,
    this.cstParanum,
    this.cstMPage,
    this.cstVPage,
    this.cstPPage,
    this.cstTPage,
    this.cstFile,
    this.scCode,
    this.scBook,
    this.scVagga,
    this.scSutta,
    this.scEngSutta,
    this.scBlurb,
    this.scFilePath,
    this.dprCode,
    this.dprLink,
    this.bjtSuttaCode,
    this.bjtWebCode,
    this.bjtFilename,
    this.bjtBookId,
    this.bjtPageNum,
    this.bjtPageOffset,
    this.bjtPitaka,
    this.bjtNikaya,
    this.bjtMajorSection,
    this.bjtBook,
    this.bjtMinorSection,
    this.bjtVagga,
    this.bjtSutta,
    this.dvPts,
    this.dvMainTheme,
    this.dvSubtopic,
    this.dvSummary,
    this.dvSimiles,
    this.dvKeyExcerpt1,
    this.dvKeyExcerpt2,
    this.dvStage,
    this.dvTraining,
    this.dvAspect,
    this.dvTeacher,
    this.dvAudience,
    this.dvMethod,
    this.dvLength,
    this.dvProminence,
    this.dvNikayasParallels,
    this.dvAgamasParallels,
    this.dvTaishoParallels,
    this.dvSanskritParallels,
    this.dvVinayaParallels,
    this.dvOthersParallels,
    this.dvPartialParallelsNa,
    this.dvPartialParallelsAll,
    this.dvSuggestedSuttas,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || book != null) {
      map['book'] = Variable<String>(book);
    }
    if (!nullToAbsent || bookCode != null) {
      map['book_code'] = Variable<String>(bookCode);
    }
    if (!nullToAbsent || dpdCode != null) {
      map['dpd_code'] = Variable<String>(dpdCode);
    }
    map['dpd_sutta'] = Variable<String>(dpdSutta);
    if (!nullToAbsent || dpdSuttaVar != null) {
      map['dpd_sutta_var'] = Variable<String>(dpdSuttaVar);
    }
    if (!nullToAbsent || cstCode != null) {
      map['cst_code'] = Variable<String>(cstCode);
    }
    if (!nullToAbsent || cstNikaya != null) {
      map['cst_nikaya'] = Variable<String>(cstNikaya);
    }
    if (!nullToAbsent || cstBook != null) {
      map['cst_book'] = Variable<String>(cstBook);
    }
    if (!nullToAbsent || cstSection != null) {
      map['cst_section'] = Variable<String>(cstSection);
    }
    if (!nullToAbsent || cstVagga != null) {
      map['cst_vagga'] = Variable<String>(cstVagga);
    }
    if (!nullToAbsent || cstSutta != null) {
      map['cst_sutta'] = Variable<String>(cstSutta);
    }
    if (!nullToAbsent || cstParanum != null) {
      map['cst_paranum'] = Variable<String>(cstParanum);
    }
    if (!nullToAbsent || cstMPage != null) {
      map['cst_m_page'] = Variable<String>(cstMPage);
    }
    if (!nullToAbsent || cstVPage != null) {
      map['cst_v_page'] = Variable<String>(cstVPage);
    }
    if (!nullToAbsent || cstPPage != null) {
      map['cst_p_page'] = Variable<String>(cstPPage);
    }
    if (!nullToAbsent || cstTPage != null) {
      map['cst_t_page'] = Variable<String>(cstTPage);
    }
    if (!nullToAbsent || cstFile != null) {
      map['cst_file'] = Variable<String>(cstFile);
    }
    if (!nullToAbsent || scCode != null) {
      map['sc_code'] = Variable<String>(scCode);
    }
    if (!nullToAbsent || scBook != null) {
      map['sc_book'] = Variable<String>(scBook);
    }
    if (!nullToAbsent || scVagga != null) {
      map['sc_vagga'] = Variable<String>(scVagga);
    }
    if (!nullToAbsent || scSutta != null) {
      map['sc_sutta'] = Variable<String>(scSutta);
    }
    if (!nullToAbsent || scEngSutta != null) {
      map['sc_eng_sutta'] = Variable<String>(scEngSutta);
    }
    if (!nullToAbsent || scBlurb != null) {
      map['sc_blurb'] = Variable<String>(scBlurb);
    }
    if (!nullToAbsent || scFilePath != null) {
      map['sc_file_path'] = Variable<String>(scFilePath);
    }
    if (!nullToAbsent || dprCode != null) {
      map['dpr_code'] = Variable<String>(dprCode);
    }
    if (!nullToAbsent || dprLink != null) {
      map['dpr_link'] = Variable<String>(dprLink);
    }
    if (!nullToAbsent || bjtSuttaCode != null) {
      map['bjt_sutta_code'] = Variable<String>(bjtSuttaCode);
    }
    if (!nullToAbsent || bjtWebCode != null) {
      map['bjt_web_code'] = Variable<String>(bjtWebCode);
    }
    if (!nullToAbsent || bjtFilename != null) {
      map['bjt_filename'] = Variable<String>(bjtFilename);
    }
    if (!nullToAbsent || bjtBookId != null) {
      map['bjt_book_id'] = Variable<String>(bjtBookId);
    }
    if (!nullToAbsent || bjtPageNum != null) {
      map['bjt_page_num'] = Variable<String>(bjtPageNum);
    }
    if (!nullToAbsent || bjtPageOffset != null) {
      map['bjt_page_offset'] = Variable<String>(bjtPageOffset);
    }
    if (!nullToAbsent || bjtPitaka != null) {
      map['bjt_piṭaka'] = Variable<String>(bjtPitaka);
    }
    if (!nullToAbsent || bjtNikaya != null) {
      map['bjt_nikāya'] = Variable<String>(bjtNikaya);
    }
    if (!nullToAbsent || bjtMajorSection != null) {
      map['bjt_major_section'] = Variable<String>(bjtMajorSection);
    }
    if (!nullToAbsent || bjtBook != null) {
      map['bjt_book'] = Variable<String>(bjtBook);
    }
    if (!nullToAbsent || bjtMinorSection != null) {
      map['bjt_minor_section'] = Variable<String>(bjtMinorSection);
    }
    if (!nullToAbsent || bjtVagga != null) {
      map['bjt_vagga'] = Variable<String>(bjtVagga);
    }
    if (!nullToAbsent || bjtSutta != null) {
      map['bjt_sutta'] = Variable<String>(bjtSutta);
    }
    if (!nullToAbsent || dvPts != null) {
      map['dv_pts'] = Variable<String>(dvPts);
    }
    if (!nullToAbsent || dvMainTheme != null) {
      map['dv_main_theme'] = Variable<String>(dvMainTheme);
    }
    if (!nullToAbsent || dvSubtopic != null) {
      map['dv_subtopic'] = Variable<String>(dvSubtopic);
    }
    if (!nullToAbsent || dvSummary != null) {
      map['dv_summary'] = Variable<String>(dvSummary);
    }
    if (!nullToAbsent || dvSimiles != null) {
      map['dv_similes'] = Variable<String>(dvSimiles);
    }
    if (!nullToAbsent || dvKeyExcerpt1 != null) {
      map['dv_key_excerpt1'] = Variable<String>(dvKeyExcerpt1);
    }
    if (!nullToAbsent || dvKeyExcerpt2 != null) {
      map['dv_key_excerpt2'] = Variable<String>(dvKeyExcerpt2);
    }
    if (!nullToAbsent || dvStage != null) {
      map['dv_stage'] = Variable<String>(dvStage);
    }
    if (!nullToAbsent || dvTraining != null) {
      map['dv_training'] = Variable<String>(dvTraining);
    }
    if (!nullToAbsent || dvAspect != null) {
      map['dv_aspect'] = Variable<String>(dvAspect);
    }
    if (!nullToAbsent || dvTeacher != null) {
      map['dv_teacher'] = Variable<String>(dvTeacher);
    }
    if (!nullToAbsent || dvAudience != null) {
      map['dv_audience'] = Variable<String>(dvAudience);
    }
    if (!nullToAbsent || dvMethod != null) {
      map['dv_method'] = Variable<String>(dvMethod);
    }
    if (!nullToAbsent || dvLength != null) {
      map['dv_length'] = Variable<String>(dvLength);
    }
    if (!nullToAbsent || dvProminence != null) {
      map['dv_prominence'] = Variable<String>(dvProminence);
    }
    if (!nullToAbsent || dvNikayasParallels != null) {
      map['dv_nikayas_parallels'] = Variable<String>(dvNikayasParallels);
    }
    if (!nullToAbsent || dvAgamasParallels != null) {
      map['dv_āgamas_parallels'] = Variable<String>(dvAgamasParallels);
    }
    if (!nullToAbsent || dvTaishoParallels != null) {
      map['dv_taisho_parallels'] = Variable<String>(dvTaishoParallels);
    }
    if (!nullToAbsent || dvSanskritParallels != null) {
      map['dv_sanskrit_parallels'] = Variable<String>(dvSanskritParallels);
    }
    if (!nullToAbsent || dvVinayaParallels != null) {
      map['dv_vinaya_parallels'] = Variable<String>(dvVinayaParallels);
    }
    if (!nullToAbsent || dvOthersParallels != null) {
      map['dv_others_parallels'] = Variable<String>(dvOthersParallels);
    }
    if (!nullToAbsent || dvPartialParallelsNa != null) {
      map['dv_partial_parallels_nā'] = Variable<String>(dvPartialParallelsNa);
    }
    if (!nullToAbsent || dvPartialParallelsAll != null) {
      map['dv_partial_parallels_all'] = Variable<String>(dvPartialParallelsAll);
    }
    if (!nullToAbsent || dvSuggestedSuttas != null) {
      map['dv_suggested_suttas'] = Variable<String>(dvSuggestedSuttas);
    }
    return map;
  }

  SuttaInfoCompanion toCompanion(bool nullToAbsent) {
    return SuttaInfoCompanion(
      book: book == null && nullToAbsent ? const Value.absent() : Value(book),
      bookCode: bookCode == null && nullToAbsent
          ? const Value.absent()
          : Value(bookCode),
      dpdCode: dpdCode == null && nullToAbsent
          ? const Value.absent()
          : Value(dpdCode),
      dpdSutta: Value(dpdSutta),
      dpdSuttaVar: dpdSuttaVar == null && nullToAbsent
          ? const Value.absent()
          : Value(dpdSuttaVar),
      cstCode: cstCode == null && nullToAbsent
          ? const Value.absent()
          : Value(cstCode),
      cstNikaya: cstNikaya == null && nullToAbsent
          ? const Value.absent()
          : Value(cstNikaya),
      cstBook: cstBook == null && nullToAbsent
          ? const Value.absent()
          : Value(cstBook),
      cstSection: cstSection == null && nullToAbsent
          ? const Value.absent()
          : Value(cstSection),
      cstVagga: cstVagga == null && nullToAbsent
          ? const Value.absent()
          : Value(cstVagga),
      cstSutta: cstSutta == null && nullToAbsent
          ? const Value.absent()
          : Value(cstSutta),
      cstParanum: cstParanum == null && nullToAbsent
          ? const Value.absent()
          : Value(cstParanum),
      cstMPage: cstMPage == null && nullToAbsent
          ? const Value.absent()
          : Value(cstMPage),
      cstVPage: cstVPage == null && nullToAbsent
          ? const Value.absent()
          : Value(cstVPage),
      cstPPage: cstPPage == null && nullToAbsent
          ? const Value.absent()
          : Value(cstPPage),
      cstTPage: cstTPage == null && nullToAbsent
          ? const Value.absent()
          : Value(cstTPage),
      cstFile: cstFile == null && nullToAbsent
          ? const Value.absent()
          : Value(cstFile),
      scCode: scCode == null && nullToAbsent
          ? const Value.absent()
          : Value(scCode),
      scBook: scBook == null && nullToAbsent
          ? const Value.absent()
          : Value(scBook),
      scVagga: scVagga == null && nullToAbsent
          ? const Value.absent()
          : Value(scVagga),
      scSutta: scSutta == null && nullToAbsent
          ? const Value.absent()
          : Value(scSutta),
      scEngSutta: scEngSutta == null && nullToAbsent
          ? const Value.absent()
          : Value(scEngSutta),
      scBlurb: scBlurb == null && nullToAbsent
          ? const Value.absent()
          : Value(scBlurb),
      scFilePath: scFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(scFilePath),
      dprCode: dprCode == null && nullToAbsent
          ? const Value.absent()
          : Value(dprCode),
      dprLink: dprLink == null && nullToAbsent
          ? const Value.absent()
          : Value(dprLink),
      bjtSuttaCode: bjtSuttaCode == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtSuttaCode),
      bjtWebCode: bjtWebCode == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtWebCode),
      bjtFilename: bjtFilename == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtFilename),
      bjtBookId: bjtBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtBookId),
      bjtPageNum: bjtPageNum == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtPageNum),
      bjtPageOffset: bjtPageOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtPageOffset),
      bjtPitaka: bjtPitaka == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtPitaka),
      bjtNikaya: bjtNikaya == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtNikaya),
      bjtMajorSection: bjtMajorSection == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtMajorSection),
      bjtBook: bjtBook == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtBook),
      bjtMinorSection: bjtMinorSection == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtMinorSection),
      bjtVagga: bjtVagga == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtVagga),
      bjtSutta: bjtSutta == null && nullToAbsent
          ? const Value.absent()
          : Value(bjtSutta),
      dvPts: dvPts == null && nullToAbsent
          ? const Value.absent()
          : Value(dvPts),
      dvMainTheme: dvMainTheme == null && nullToAbsent
          ? const Value.absent()
          : Value(dvMainTheme),
      dvSubtopic: dvSubtopic == null && nullToAbsent
          ? const Value.absent()
          : Value(dvSubtopic),
      dvSummary: dvSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(dvSummary),
      dvSimiles: dvSimiles == null && nullToAbsent
          ? const Value.absent()
          : Value(dvSimiles),
      dvKeyExcerpt1: dvKeyExcerpt1 == null && nullToAbsent
          ? const Value.absent()
          : Value(dvKeyExcerpt1),
      dvKeyExcerpt2: dvKeyExcerpt2 == null && nullToAbsent
          ? const Value.absent()
          : Value(dvKeyExcerpt2),
      dvStage: dvStage == null && nullToAbsent
          ? const Value.absent()
          : Value(dvStage),
      dvTraining: dvTraining == null && nullToAbsent
          ? const Value.absent()
          : Value(dvTraining),
      dvAspect: dvAspect == null && nullToAbsent
          ? const Value.absent()
          : Value(dvAspect),
      dvTeacher: dvTeacher == null && nullToAbsent
          ? const Value.absent()
          : Value(dvTeacher),
      dvAudience: dvAudience == null && nullToAbsent
          ? const Value.absent()
          : Value(dvAudience),
      dvMethod: dvMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(dvMethod),
      dvLength: dvLength == null && nullToAbsent
          ? const Value.absent()
          : Value(dvLength),
      dvProminence: dvProminence == null && nullToAbsent
          ? const Value.absent()
          : Value(dvProminence),
      dvNikayasParallels: dvNikayasParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvNikayasParallels),
      dvAgamasParallels: dvAgamasParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvAgamasParallels),
      dvTaishoParallels: dvTaishoParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvTaishoParallels),
      dvSanskritParallels: dvSanskritParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvSanskritParallels),
      dvVinayaParallels: dvVinayaParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvVinayaParallels),
      dvOthersParallels: dvOthersParallels == null && nullToAbsent
          ? const Value.absent()
          : Value(dvOthersParallels),
      dvPartialParallelsNa: dvPartialParallelsNa == null && nullToAbsent
          ? const Value.absent()
          : Value(dvPartialParallelsNa),
      dvPartialParallelsAll: dvPartialParallelsAll == null && nullToAbsent
          ? const Value.absent()
          : Value(dvPartialParallelsAll),
      dvSuggestedSuttas: dvSuggestedSuttas == null && nullToAbsent
          ? const Value.absent()
          : Value(dvSuggestedSuttas),
    );
  }

  factory SuttaInfoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SuttaInfoData(
      book: serializer.fromJson<String?>(json['book']),
      bookCode: serializer.fromJson<String?>(json['bookCode']),
      dpdCode: serializer.fromJson<String?>(json['dpdCode']),
      dpdSutta: serializer.fromJson<String>(json['dpdSutta']),
      dpdSuttaVar: serializer.fromJson<String?>(json['dpdSuttaVar']),
      cstCode: serializer.fromJson<String?>(json['cstCode']),
      cstNikaya: serializer.fromJson<String?>(json['cstNikaya']),
      cstBook: serializer.fromJson<String?>(json['cstBook']),
      cstSection: serializer.fromJson<String?>(json['cstSection']),
      cstVagga: serializer.fromJson<String?>(json['cstVagga']),
      cstSutta: serializer.fromJson<String?>(json['cstSutta']),
      cstParanum: serializer.fromJson<String?>(json['cstParanum']),
      cstMPage: serializer.fromJson<String?>(json['cstMPage']),
      cstVPage: serializer.fromJson<String?>(json['cstVPage']),
      cstPPage: serializer.fromJson<String?>(json['cstPPage']),
      cstTPage: serializer.fromJson<String?>(json['cstTPage']),
      cstFile: serializer.fromJson<String?>(json['cstFile']),
      scCode: serializer.fromJson<String?>(json['scCode']),
      scBook: serializer.fromJson<String?>(json['scBook']),
      scVagga: serializer.fromJson<String?>(json['scVagga']),
      scSutta: serializer.fromJson<String?>(json['scSutta']),
      scEngSutta: serializer.fromJson<String?>(json['scEngSutta']),
      scBlurb: serializer.fromJson<String?>(json['scBlurb']),
      scFilePath: serializer.fromJson<String?>(json['scFilePath']),
      dprCode: serializer.fromJson<String?>(json['dprCode']),
      dprLink: serializer.fromJson<String?>(json['dprLink']),
      bjtSuttaCode: serializer.fromJson<String?>(json['bjtSuttaCode']),
      bjtWebCode: serializer.fromJson<String?>(json['bjtWebCode']),
      bjtFilename: serializer.fromJson<String?>(json['bjtFilename']),
      bjtBookId: serializer.fromJson<String?>(json['bjtBookId']),
      bjtPageNum: serializer.fromJson<String?>(json['bjtPageNum']),
      bjtPageOffset: serializer.fromJson<String?>(json['bjtPageOffset']),
      bjtPitaka: serializer.fromJson<String?>(json['bjtPitaka']),
      bjtNikaya: serializer.fromJson<String?>(json['bjtNikaya']),
      bjtMajorSection: serializer.fromJson<String?>(json['bjtMajorSection']),
      bjtBook: serializer.fromJson<String?>(json['bjtBook']),
      bjtMinorSection: serializer.fromJson<String?>(json['bjtMinorSection']),
      bjtVagga: serializer.fromJson<String?>(json['bjtVagga']),
      bjtSutta: serializer.fromJson<String?>(json['bjtSutta']),
      dvPts: serializer.fromJson<String?>(json['dvPts']),
      dvMainTheme: serializer.fromJson<String?>(json['dvMainTheme']),
      dvSubtopic: serializer.fromJson<String?>(json['dvSubtopic']),
      dvSummary: serializer.fromJson<String?>(json['dvSummary']),
      dvSimiles: serializer.fromJson<String?>(json['dvSimiles']),
      dvKeyExcerpt1: serializer.fromJson<String?>(json['dvKeyExcerpt1']),
      dvKeyExcerpt2: serializer.fromJson<String?>(json['dvKeyExcerpt2']),
      dvStage: serializer.fromJson<String?>(json['dvStage']),
      dvTraining: serializer.fromJson<String?>(json['dvTraining']),
      dvAspect: serializer.fromJson<String?>(json['dvAspect']),
      dvTeacher: serializer.fromJson<String?>(json['dvTeacher']),
      dvAudience: serializer.fromJson<String?>(json['dvAudience']),
      dvMethod: serializer.fromJson<String?>(json['dvMethod']),
      dvLength: serializer.fromJson<String?>(json['dvLength']),
      dvProminence: serializer.fromJson<String?>(json['dvProminence']),
      dvNikayasParallels: serializer.fromJson<String?>(
        json['dvNikayasParallels'],
      ),
      dvAgamasParallels: serializer.fromJson<String?>(
        json['dvAgamasParallels'],
      ),
      dvTaishoParallels: serializer.fromJson<String?>(
        json['dvTaishoParallels'],
      ),
      dvSanskritParallels: serializer.fromJson<String?>(
        json['dvSanskritParallels'],
      ),
      dvVinayaParallels: serializer.fromJson<String?>(
        json['dvVinayaParallels'],
      ),
      dvOthersParallels: serializer.fromJson<String?>(
        json['dvOthersParallels'],
      ),
      dvPartialParallelsNa: serializer.fromJson<String?>(
        json['dvPartialParallelsNa'],
      ),
      dvPartialParallelsAll: serializer.fromJson<String?>(
        json['dvPartialParallelsAll'],
      ),
      dvSuggestedSuttas: serializer.fromJson<String?>(
        json['dvSuggestedSuttas'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'book': serializer.toJson<String?>(book),
      'bookCode': serializer.toJson<String?>(bookCode),
      'dpdCode': serializer.toJson<String?>(dpdCode),
      'dpdSutta': serializer.toJson<String>(dpdSutta),
      'dpdSuttaVar': serializer.toJson<String?>(dpdSuttaVar),
      'cstCode': serializer.toJson<String?>(cstCode),
      'cstNikaya': serializer.toJson<String?>(cstNikaya),
      'cstBook': serializer.toJson<String?>(cstBook),
      'cstSection': serializer.toJson<String?>(cstSection),
      'cstVagga': serializer.toJson<String?>(cstVagga),
      'cstSutta': serializer.toJson<String?>(cstSutta),
      'cstParanum': serializer.toJson<String?>(cstParanum),
      'cstMPage': serializer.toJson<String?>(cstMPage),
      'cstVPage': serializer.toJson<String?>(cstVPage),
      'cstPPage': serializer.toJson<String?>(cstPPage),
      'cstTPage': serializer.toJson<String?>(cstTPage),
      'cstFile': serializer.toJson<String?>(cstFile),
      'scCode': serializer.toJson<String?>(scCode),
      'scBook': serializer.toJson<String?>(scBook),
      'scVagga': serializer.toJson<String?>(scVagga),
      'scSutta': serializer.toJson<String?>(scSutta),
      'scEngSutta': serializer.toJson<String?>(scEngSutta),
      'scBlurb': serializer.toJson<String?>(scBlurb),
      'scFilePath': serializer.toJson<String?>(scFilePath),
      'dprCode': serializer.toJson<String?>(dprCode),
      'dprLink': serializer.toJson<String?>(dprLink),
      'bjtSuttaCode': serializer.toJson<String?>(bjtSuttaCode),
      'bjtWebCode': serializer.toJson<String?>(bjtWebCode),
      'bjtFilename': serializer.toJson<String?>(bjtFilename),
      'bjtBookId': serializer.toJson<String?>(bjtBookId),
      'bjtPageNum': serializer.toJson<String?>(bjtPageNum),
      'bjtPageOffset': serializer.toJson<String?>(bjtPageOffset),
      'bjtPitaka': serializer.toJson<String?>(bjtPitaka),
      'bjtNikaya': serializer.toJson<String?>(bjtNikaya),
      'bjtMajorSection': serializer.toJson<String?>(bjtMajorSection),
      'bjtBook': serializer.toJson<String?>(bjtBook),
      'bjtMinorSection': serializer.toJson<String?>(bjtMinorSection),
      'bjtVagga': serializer.toJson<String?>(bjtVagga),
      'bjtSutta': serializer.toJson<String?>(bjtSutta),
      'dvPts': serializer.toJson<String?>(dvPts),
      'dvMainTheme': serializer.toJson<String?>(dvMainTheme),
      'dvSubtopic': serializer.toJson<String?>(dvSubtopic),
      'dvSummary': serializer.toJson<String?>(dvSummary),
      'dvSimiles': serializer.toJson<String?>(dvSimiles),
      'dvKeyExcerpt1': serializer.toJson<String?>(dvKeyExcerpt1),
      'dvKeyExcerpt2': serializer.toJson<String?>(dvKeyExcerpt2),
      'dvStage': serializer.toJson<String?>(dvStage),
      'dvTraining': serializer.toJson<String?>(dvTraining),
      'dvAspect': serializer.toJson<String?>(dvAspect),
      'dvTeacher': serializer.toJson<String?>(dvTeacher),
      'dvAudience': serializer.toJson<String?>(dvAudience),
      'dvMethod': serializer.toJson<String?>(dvMethod),
      'dvLength': serializer.toJson<String?>(dvLength),
      'dvProminence': serializer.toJson<String?>(dvProminence),
      'dvNikayasParallels': serializer.toJson<String?>(dvNikayasParallels),
      'dvAgamasParallels': serializer.toJson<String?>(dvAgamasParallels),
      'dvTaishoParallels': serializer.toJson<String?>(dvTaishoParallels),
      'dvSanskritParallels': serializer.toJson<String?>(dvSanskritParallels),
      'dvVinayaParallels': serializer.toJson<String?>(dvVinayaParallels),
      'dvOthersParallels': serializer.toJson<String?>(dvOthersParallels),
      'dvPartialParallelsNa': serializer.toJson<String?>(dvPartialParallelsNa),
      'dvPartialParallelsAll': serializer.toJson<String?>(
        dvPartialParallelsAll,
      ),
      'dvSuggestedSuttas': serializer.toJson<String?>(dvSuggestedSuttas),
    };
  }

  SuttaInfoData copyWith({
    Value<String?> book = const Value.absent(),
    Value<String?> bookCode = const Value.absent(),
    Value<String?> dpdCode = const Value.absent(),
    String? dpdSutta,
    Value<String?> dpdSuttaVar = const Value.absent(),
    Value<String?> cstCode = const Value.absent(),
    Value<String?> cstNikaya = const Value.absent(),
    Value<String?> cstBook = const Value.absent(),
    Value<String?> cstSection = const Value.absent(),
    Value<String?> cstVagga = const Value.absent(),
    Value<String?> cstSutta = const Value.absent(),
    Value<String?> cstParanum = const Value.absent(),
    Value<String?> cstMPage = const Value.absent(),
    Value<String?> cstVPage = const Value.absent(),
    Value<String?> cstPPage = const Value.absent(),
    Value<String?> cstTPage = const Value.absent(),
    Value<String?> cstFile = const Value.absent(),
    Value<String?> scCode = const Value.absent(),
    Value<String?> scBook = const Value.absent(),
    Value<String?> scVagga = const Value.absent(),
    Value<String?> scSutta = const Value.absent(),
    Value<String?> scEngSutta = const Value.absent(),
    Value<String?> scBlurb = const Value.absent(),
    Value<String?> scFilePath = const Value.absent(),
    Value<String?> dprCode = const Value.absent(),
    Value<String?> dprLink = const Value.absent(),
    Value<String?> bjtSuttaCode = const Value.absent(),
    Value<String?> bjtWebCode = const Value.absent(),
    Value<String?> bjtFilename = const Value.absent(),
    Value<String?> bjtBookId = const Value.absent(),
    Value<String?> bjtPageNum = const Value.absent(),
    Value<String?> bjtPageOffset = const Value.absent(),
    Value<String?> bjtPitaka = const Value.absent(),
    Value<String?> bjtNikaya = const Value.absent(),
    Value<String?> bjtMajorSection = const Value.absent(),
    Value<String?> bjtBook = const Value.absent(),
    Value<String?> bjtMinorSection = const Value.absent(),
    Value<String?> bjtVagga = const Value.absent(),
    Value<String?> bjtSutta = const Value.absent(),
    Value<String?> dvPts = const Value.absent(),
    Value<String?> dvMainTheme = const Value.absent(),
    Value<String?> dvSubtopic = const Value.absent(),
    Value<String?> dvSummary = const Value.absent(),
    Value<String?> dvSimiles = const Value.absent(),
    Value<String?> dvKeyExcerpt1 = const Value.absent(),
    Value<String?> dvKeyExcerpt2 = const Value.absent(),
    Value<String?> dvStage = const Value.absent(),
    Value<String?> dvTraining = const Value.absent(),
    Value<String?> dvAspect = const Value.absent(),
    Value<String?> dvTeacher = const Value.absent(),
    Value<String?> dvAudience = const Value.absent(),
    Value<String?> dvMethod = const Value.absent(),
    Value<String?> dvLength = const Value.absent(),
    Value<String?> dvProminence = const Value.absent(),
    Value<String?> dvNikayasParallels = const Value.absent(),
    Value<String?> dvAgamasParallels = const Value.absent(),
    Value<String?> dvTaishoParallels = const Value.absent(),
    Value<String?> dvSanskritParallels = const Value.absent(),
    Value<String?> dvVinayaParallels = const Value.absent(),
    Value<String?> dvOthersParallels = const Value.absent(),
    Value<String?> dvPartialParallelsNa = const Value.absent(),
    Value<String?> dvPartialParallelsAll = const Value.absent(),
    Value<String?> dvSuggestedSuttas = const Value.absent(),
  }) => SuttaInfoData(
    book: book.present ? book.value : this.book,
    bookCode: bookCode.present ? bookCode.value : this.bookCode,
    dpdCode: dpdCode.present ? dpdCode.value : this.dpdCode,
    dpdSutta: dpdSutta ?? this.dpdSutta,
    dpdSuttaVar: dpdSuttaVar.present ? dpdSuttaVar.value : this.dpdSuttaVar,
    cstCode: cstCode.present ? cstCode.value : this.cstCode,
    cstNikaya: cstNikaya.present ? cstNikaya.value : this.cstNikaya,
    cstBook: cstBook.present ? cstBook.value : this.cstBook,
    cstSection: cstSection.present ? cstSection.value : this.cstSection,
    cstVagga: cstVagga.present ? cstVagga.value : this.cstVagga,
    cstSutta: cstSutta.present ? cstSutta.value : this.cstSutta,
    cstParanum: cstParanum.present ? cstParanum.value : this.cstParanum,
    cstMPage: cstMPage.present ? cstMPage.value : this.cstMPage,
    cstVPage: cstVPage.present ? cstVPage.value : this.cstVPage,
    cstPPage: cstPPage.present ? cstPPage.value : this.cstPPage,
    cstTPage: cstTPage.present ? cstTPage.value : this.cstTPage,
    cstFile: cstFile.present ? cstFile.value : this.cstFile,
    scCode: scCode.present ? scCode.value : this.scCode,
    scBook: scBook.present ? scBook.value : this.scBook,
    scVagga: scVagga.present ? scVagga.value : this.scVagga,
    scSutta: scSutta.present ? scSutta.value : this.scSutta,
    scEngSutta: scEngSutta.present ? scEngSutta.value : this.scEngSutta,
    scBlurb: scBlurb.present ? scBlurb.value : this.scBlurb,
    scFilePath: scFilePath.present ? scFilePath.value : this.scFilePath,
    dprCode: dprCode.present ? dprCode.value : this.dprCode,
    dprLink: dprLink.present ? dprLink.value : this.dprLink,
    bjtSuttaCode: bjtSuttaCode.present ? bjtSuttaCode.value : this.bjtSuttaCode,
    bjtWebCode: bjtWebCode.present ? bjtWebCode.value : this.bjtWebCode,
    bjtFilename: bjtFilename.present ? bjtFilename.value : this.bjtFilename,
    bjtBookId: bjtBookId.present ? bjtBookId.value : this.bjtBookId,
    bjtPageNum: bjtPageNum.present ? bjtPageNum.value : this.bjtPageNum,
    bjtPageOffset: bjtPageOffset.present
        ? bjtPageOffset.value
        : this.bjtPageOffset,
    bjtPitaka: bjtPitaka.present ? bjtPitaka.value : this.bjtPitaka,
    bjtNikaya: bjtNikaya.present ? bjtNikaya.value : this.bjtNikaya,
    bjtMajorSection: bjtMajorSection.present
        ? bjtMajorSection.value
        : this.bjtMajorSection,
    bjtBook: bjtBook.present ? bjtBook.value : this.bjtBook,
    bjtMinorSection: bjtMinorSection.present
        ? bjtMinorSection.value
        : this.bjtMinorSection,
    bjtVagga: bjtVagga.present ? bjtVagga.value : this.bjtVagga,
    bjtSutta: bjtSutta.present ? bjtSutta.value : this.bjtSutta,
    dvPts: dvPts.present ? dvPts.value : this.dvPts,
    dvMainTheme: dvMainTheme.present ? dvMainTheme.value : this.dvMainTheme,
    dvSubtopic: dvSubtopic.present ? dvSubtopic.value : this.dvSubtopic,
    dvSummary: dvSummary.present ? dvSummary.value : this.dvSummary,
    dvSimiles: dvSimiles.present ? dvSimiles.value : this.dvSimiles,
    dvKeyExcerpt1: dvKeyExcerpt1.present
        ? dvKeyExcerpt1.value
        : this.dvKeyExcerpt1,
    dvKeyExcerpt2: dvKeyExcerpt2.present
        ? dvKeyExcerpt2.value
        : this.dvKeyExcerpt2,
    dvStage: dvStage.present ? dvStage.value : this.dvStage,
    dvTraining: dvTraining.present ? dvTraining.value : this.dvTraining,
    dvAspect: dvAspect.present ? dvAspect.value : this.dvAspect,
    dvTeacher: dvTeacher.present ? dvTeacher.value : this.dvTeacher,
    dvAudience: dvAudience.present ? dvAudience.value : this.dvAudience,
    dvMethod: dvMethod.present ? dvMethod.value : this.dvMethod,
    dvLength: dvLength.present ? dvLength.value : this.dvLength,
    dvProminence: dvProminence.present ? dvProminence.value : this.dvProminence,
    dvNikayasParallels: dvNikayasParallels.present
        ? dvNikayasParallels.value
        : this.dvNikayasParallels,
    dvAgamasParallels: dvAgamasParallels.present
        ? dvAgamasParallels.value
        : this.dvAgamasParallels,
    dvTaishoParallels: dvTaishoParallels.present
        ? dvTaishoParallels.value
        : this.dvTaishoParallels,
    dvSanskritParallels: dvSanskritParallels.present
        ? dvSanskritParallels.value
        : this.dvSanskritParallels,
    dvVinayaParallels: dvVinayaParallels.present
        ? dvVinayaParallels.value
        : this.dvVinayaParallels,
    dvOthersParallels: dvOthersParallels.present
        ? dvOthersParallels.value
        : this.dvOthersParallels,
    dvPartialParallelsNa: dvPartialParallelsNa.present
        ? dvPartialParallelsNa.value
        : this.dvPartialParallelsNa,
    dvPartialParallelsAll: dvPartialParallelsAll.present
        ? dvPartialParallelsAll.value
        : this.dvPartialParallelsAll,
    dvSuggestedSuttas: dvSuggestedSuttas.present
        ? dvSuggestedSuttas.value
        : this.dvSuggestedSuttas,
  );
  SuttaInfoData copyWithCompanion(SuttaInfoCompanion data) {
    return SuttaInfoData(
      book: data.book.present ? data.book.value : this.book,
      bookCode: data.bookCode.present ? data.bookCode.value : this.bookCode,
      dpdCode: data.dpdCode.present ? data.dpdCode.value : this.dpdCode,
      dpdSutta: data.dpdSutta.present ? data.dpdSutta.value : this.dpdSutta,
      dpdSuttaVar: data.dpdSuttaVar.present
          ? data.dpdSuttaVar.value
          : this.dpdSuttaVar,
      cstCode: data.cstCode.present ? data.cstCode.value : this.cstCode,
      cstNikaya: data.cstNikaya.present ? data.cstNikaya.value : this.cstNikaya,
      cstBook: data.cstBook.present ? data.cstBook.value : this.cstBook,
      cstSection: data.cstSection.present
          ? data.cstSection.value
          : this.cstSection,
      cstVagga: data.cstVagga.present ? data.cstVagga.value : this.cstVagga,
      cstSutta: data.cstSutta.present ? data.cstSutta.value : this.cstSutta,
      cstParanum: data.cstParanum.present
          ? data.cstParanum.value
          : this.cstParanum,
      cstMPage: data.cstMPage.present ? data.cstMPage.value : this.cstMPage,
      cstVPage: data.cstVPage.present ? data.cstVPage.value : this.cstVPage,
      cstPPage: data.cstPPage.present ? data.cstPPage.value : this.cstPPage,
      cstTPage: data.cstTPage.present ? data.cstTPage.value : this.cstTPage,
      cstFile: data.cstFile.present ? data.cstFile.value : this.cstFile,
      scCode: data.scCode.present ? data.scCode.value : this.scCode,
      scBook: data.scBook.present ? data.scBook.value : this.scBook,
      scVagga: data.scVagga.present ? data.scVagga.value : this.scVagga,
      scSutta: data.scSutta.present ? data.scSutta.value : this.scSutta,
      scEngSutta: data.scEngSutta.present
          ? data.scEngSutta.value
          : this.scEngSutta,
      scBlurb: data.scBlurb.present ? data.scBlurb.value : this.scBlurb,
      scFilePath: data.scFilePath.present
          ? data.scFilePath.value
          : this.scFilePath,
      dprCode: data.dprCode.present ? data.dprCode.value : this.dprCode,
      dprLink: data.dprLink.present ? data.dprLink.value : this.dprLink,
      bjtSuttaCode: data.bjtSuttaCode.present
          ? data.bjtSuttaCode.value
          : this.bjtSuttaCode,
      bjtWebCode: data.bjtWebCode.present
          ? data.bjtWebCode.value
          : this.bjtWebCode,
      bjtFilename: data.bjtFilename.present
          ? data.bjtFilename.value
          : this.bjtFilename,
      bjtBookId: data.bjtBookId.present ? data.bjtBookId.value : this.bjtBookId,
      bjtPageNum: data.bjtPageNum.present
          ? data.bjtPageNum.value
          : this.bjtPageNum,
      bjtPageOffset: data.bjtPageOffset.present
          ? data.bjtPageOffset.value
          : this.bjtPageOffset,
      bjtPitaka: data.bjtPitaka.present ? data.bjtPitaka.value : this.bjtPitaka,
      bjtNikaya: data.bjtNikaya.present ? data.bjtNikaya.value : this.bjtNikaya,
      bjtMajorSection: data.bjtMajorSection.present
          ? data.bjtMajorSection.value
          : this.bjtMajorSection,
      bjtBook: data.bjtBook.present ? data.bjtBook.value : this.bjtBook,
      bjtMinorSection: data.bjtMinorSection.present
          ? data.bjtMinorSection.value
          : this.bjtMinorSection,
      bjtVagga: data.bjtVagga.present ? data.bjtVagga.value : this.bjtVagga,
      bjtSutta: data.bjtSutta.present ? data.bjtSutta.value : this.bjtSutta,
      dvPts: data.dvPts.present ? data.dvPts.value : this.dvPts,
      dvMainTheme: data.dvMainTheme.present
          ? data.dvMainTheme.value
          : this.dvMainTheme,
      dvSubtopic: data.dvSubtopic.present
          ? data.dvSubtopic.value
          : this.dvSubtopic,
      dvSummary: data.dvSummary.present ? data.dvSummary.value : this.dvSummary,
      dvSimiles: data.dvSimiles.present ? data.dvSimiles.value : this.dvSimiles,
      dvKeyExcerpt1: data.dvKeyExcerpt1.present
          ? data.dvKeyExcerpt1.value
          : this.dvKeyExcerpt1,
      dvKeyExcerpt2: data.dvKeyExcerpt2.present
          ? data.dvKeyExcerpt2.value
          : this.dvKeyExcerpt2,
      dvStage: data.dvStage.present ? data.dvStage.value : this.dvStage,
      dvTraining: data.dvTraining.present
          ? data.dvTraining.value
          : this.dvTraining,
      dvAspect: data.dvAspect.present ? data.dvAspect.value : this.dvAspect,
      dvTeacher: data.dvTeacher.present ? data.dvTeacher.value : this.dvTeacher,
      dvAudience: data.dvAudience.present
          ? data.dvAudience.value
          : this.dvAudience,
      dvMethod: data.dvMethod.present ? data.dvMethod.value : this.dvMethod,
      dvLength: data.dvLength.present ? data.dvLength.value : this.dvLength,
      dvProminence: data.dvProminence.present
          ? data.dvProminence.value
          : this.dvProminence,
      dvNikayasParallels: data.dvNikayasParallels.present
          ? data.dvNikayasParallels.value
          : this.dvNikayasParallels,
      dvAgamasParallels: data.dvAgamasParallels.present
          ? data.dvAgamasParallels.value
          : this.dvAgamasParallels,
      dvTaishoParallels: data.dvTaishoParallels.present
          ? data.dvTaishoParallels.value
          : this.dvTaishoParallels,
      dvSanskritParallels: data.dvSanskritParallels.present
          ? data.dvSanskritParallels.value
          : this.dvSanskritParallels,
      dvVinayaParallels: data.dvVinayaParallels.present
          ? data.dvVinayaParallels.value
          : this.dvVinayaParallels,
      dvOthersParallels: data.dvOthersParallels.present
          ? data.dvOthersParallels.value
          : this.dvOthersParallels,
      dvPartialParallelsNa: data.dvPartialParallelsNa.present
          ? data.dvPartialParallelsNa.value
          : this.dvPartialParallelsNa,
      dvPartialParallelsAll: data.dvPartialParallelsAll.present
          ? data.dvPartialParallelsAll.value
          : this.dvPartialParallelsAll,
      dvSuggestedSuttas: data.dvSuggestedSuttas.present
          ? data.dvSuggestedSuttas.value
          : this.dvSuggestedSuttas,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SuttaInfoData(')
          ..write('book: $book, ')
          ..write('bookCode: $bookCode, ')
          ..write('dpdCode: $dpdCode, ')
          ..write('dpdSutta: $dpdSutta, ')
          ..write('dpdSuttaVar: $dpdSuttaVar, ')
          ..write('cstCode: $cstCode, ')
          ..write('cstNikaya: $cstNikaya, ')
          ..write('cstBook: $cstBook, ')
          ..write('cstSection: $cstSection, ')
          ..write('cstVagga: $cstVagga, ')
          ..write('cstSutta: $cstSutta, ')
          ..write('cstParanum: $cstParanum, ')
          ..write('cstMPage: $cstMPage, ')
          ..write('cstVPage: $cstVPage, ')
          ..write('cstPPage: $cstPPage, ')
          ..write('cstTPage: $cstTPage, ')
          ..write('cstFile: $cstFile, ')
          ..write('scCode: $scCode, ')
          ..write('scBook: $scBook, ')
          ..write('scVagga: $scVagga, ')
          ..write('scSutta: $scSutta, ')
          ..write('scEngSutta: $scEngSutta, ')
          ..write('scBlurb: $scBlurb, ')
          ..write('scFilePath: $scFilePath, ')
          ..write('dprCode: $dprCode, ')
          ..write('dprLink: $dprLink, ')
          ..write('bjtSuttaCode: $bjtSuttaCode, ')
          ..write('bjtWebCode: $bjtWebCode, ')
          ..write('bjtFilename: $bjtFilename, ')
          ..write('bjtBookId: $bjtBookId, ')
          ..write('bjtPageNum: $bjtPageNum, ')
          ..write('bjtPageOffset: $bjtPageOffset, ')
          ..write('bjtPitaka: $bjtPitaka, ')
          ..write('bjtNikaya: $bjtNikaya, ')
          ..write('bjtMajorSection: $bjtMajorSection, ')
          ..write('bjtBook: $bjtBook, ')
          ..write('bjtMinorSection: $bjtMinorSection, ')
          ..write('bjtVagga: $bjtVagga, ')
          ..write('bjtSutta: $bjtSutta, ')
          ..write('dvPts: $dvPts, ')
          ..write('dvMainTheme: $dvMainTheme, ')
          ..write('dvSubtopic: $dvSubtopic, ')
          ..write('dvSummary: $dvSummary, ')
          ..write('dvSimiles: $dvSimiles, ')
          ..write('dvKeyExcerpt1: $dvKeyExcerpt1, ')
          ..write('dvKeyExcerpt2: $dvKeyExcerpt2, ')
          ..write('dvStage: $dvStage, ')
          ..write('dvTraining: $dvTraining, ')
          ..write('dvAspect: $dvAspect, ')
          ..write('dvTeacher: $dvTeacher, ')
          ..write('dvAudience: $dvAudience, ')
          ..write('dvMethod: $dvMethod, ')
          ..write('dvLength: $dvLength, ')
          ..write('dvProminence: $dvProminence, ')
          ..write('dvNikayasParallels: $dvNikayasParallels, ')
          ..write('dvAgamasParallels: $dvAgamasParallels, ')
          ..write('dvTaishoParallels: $dvTaishoParallels, ')
          ..write('dvSanskritParallels: $dvSanskritParallels, ')
          ..write('dvVinayaParallels: $dvVinayaParallels, ')
          ..write('dvOthersParallels: $dvOthersParallels, ')
          ..write('dvPartialParallelsNa: $dvPartialParallelsNa, ')
          ..write('dvPartialParallelsAll: $dvPartialParallelsAll, ')
          ..write('dvSuggestedSuttas: $dvSuggestedSuttas')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    book,
    bookCode,
    dpdCode,
    dpdSutta,
    dpdSuttaVar,
    cstCode,
    cstNikaya,
    cstBook,
    cstSection,
    cstVagga,
    cstSutta,
    cstParanum,
    cstMPage,
    cstVPage,
    cstPPage,
    cstTPage,
    cstFile,
    scCode,
    scBook,
    scVagga,
    scSutta,
    scEngSutta,
    scBlurb,
    scFilePath,
    dprCode,
    dprLink,
    bjtSuttaCode,
    bjtWebCode,
    bjtFilename,
    bjtBookId,
    bjtPageNum,
    bjtPageOffset,
    bjtPitaka,
    bjtNikaya,
    bjtMajorSection,
    bjtBook,
    bjtMinorSection,
    bjtVagga,
    bjtSutta,
    dvPts,
    dvMainTheme,
    dvSubtopic,
    dvSummary,
    dvSimiles,
    dvKeyExcerpt1,
    dvKeyExcerpt2,
    dvStage,
    dvTraining,
    dvAspect,
    dvTeacher,
    dvAudience,
    dvMethod,
    dvLength,
    dvProminence,
    dvNikayasParallels,
    dvAgamasParallels,
    dvTaishoParallels,
    dvSanskritParallels,
    dvVinayaParallels,
    dvOthersParallels,
    dvPartialParallelsNa,
    dvPartialParallelsAll,
    dvSuggestedSuttas,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SuttaInfoData &&
          other.book == this.book &&
          other.bookCode == this.bookCode &&
          other.dpdCode == this.dpdCode &&
          other.dpdSutta == this.dpdSutta &&
          other.dpdSuttaVar == this.dpdSuttaVar &&
          other.cstCode == this.cstCode &&
          other.cstNikaya == this.cstNikaya &&
          other.cstBook == this.cstBook &&
          other.cstSection == this.cstSection &&
          other.cstVagga == this.cstVagga &&
          other.cstSutta == this.cstSutta &&
          other.cstParanum == this.cstParanum &&
          other.cstMPage == this.cstMPage &&
          other.cstVPage == this.cstVPage &&
          other.cstPPage == this.cstPPage &&
          other.cstTPage == this.cstTPage &&
          other.cstFile == this.cstFile &&
          other.scCode == this.scCode &&
          other.scBook == this.scBook &&
          other.scVagga == this.scVagga &&
          other.scSutta == this.scSutta &&
          other.scEngSutta == this.scEngSutta &&
          other.scBlurb == this.scBlurb &&
          other.scFilePath == this.scFilePath &&
          other.dprCode == this.dprCode &&
          other.dprLink == this.dprLink &&
          other.bjtSuttaCode == this.bjtSuttaCode &&
          other.bjtWebCode == this.bjtWebCode &&
          other.bjtFilename == this.bjtFilename &&
          other.bjtBookId == this.bjtBookId &&
          other.bjtPageNum == this.bjtPageNum &&
          other.bjtPageOffset == this.bjtPageOffset &&
          other.bjtPitaka == this.bjtPitaka &&
          other.bjtNikaya == this.bjtNikaya &&
          other.bjtMajorSection == this.bjtMajorSection &&
          other.bjtBook == this.bjtBook &&
          other.bjtMinorSection == this.bjtMinorSection &&
          other.bjtVagga == this.bjtVagga &&
          other.bjtSutta == this.bjtSutta &&
          other.dvPts == this.dvPts &&
          other.dvMainTheme == this.dvMainTheme &&
          other.dvSubtopic == this.dvSubtopic &&
          other.dvSummary == this.dvSummary &&
          other.dvSimiles == this.dvSimiles &&
          other.dvKeyExcerpt1 == this.dvKeyExcerpt1 &&
          other.dvKeyExcerpt2 == this.dvKeyExcerpt2 &&
          other.dvStage == this.dvStage &&
          other.dvTraining == this.dvTraining &&
          other.dvAspect == this.dvAspect &&
          other.dvTeacher == this.dvTeacher &&
          other.dvAudience == this.dvAudience &&
          other.dvMethod == this.dvMethod &&
          other.dvLength == this.dvLength &&
          other.dvProminence == this.dvProminence &&
          other.dvNikayasParallels == this.dvNikayasParallels &&
          other.dvAgamasParallels == this.dvAgamasParallels &&
          other.dvTaishoParallels == this.dvTaishoParallels &&
          other.dvSanskritParallels == this.dvSanskritParallels &&
          other.dvVinayaParallels == this.dvVinayaParallels &&
          other.dvOthersParallels == this.dvOthersParallels &&
          other.dvPartialParallelsNa == this.dvPartialParallelsNa &&
          other.dvPartialParallelsAll == this.dvPartialParallelsAll &&
          other.dvSuggestedSuttas == this.dvSuggestedSuttas);
}

class SuttaInfoCompanion extends UpdateCompanion<SuttaInfoData> {
  final Value<String?> book;
  final Value<String?> bookCode;
  final Value<String?> dpdCode;
  final Value<String> dpdSutta;
  final Value<String?> dpdSuttaVar;
  final Value<String?> cstCode;
  final Value<String?> cstNikaya;
  final Value<String?> cstBook;
  final Value<String?> cstSection;
  final Value<String?> cstVagga;
  final Value<String?> cstSutta;
  final Value<String?> cstParanum;
  final Value<String?> cstMPage;
  final Value<String?> cstVPage;
  final Value<String?> cstPPage;
  final Value<String?> cstTPage;
  final Value<String?> cstFile;
  final Value<String?> scCode;
  final Value<String?> scBook;
  final Value<String?> scVagga;
  final Value<String?> scSutta;
  final Value<String?> scEngSutta;
  final Value<String?> scBlurb;
  final Value<String?> scFilePath;
  final Value<String?> dprCode;
  final Value<String?> dprLink;
  final Value<String?> bjtSuttaCode;
  final Value<String?> bjtWebCode;
  final Value<String?> bjtFilename;
  final Value<String?> bjtBookId;
  final Value<String?> bjtPageNum;
  final Value<String?> bjtPageOffset;
  final Value<String?> bjtPitaka;
  final Value<String?> bjtNikaya;
  final Value<String?> bjtMajorSection;
  final Value<String?> bjtBook;
  final Value<String?> bjtMinorSection;
  final Value<String?> bjtVagga;
  final Value<String?> bjtSutta;
  final Value<String?> dvPts;
  final Value<String?> dvMainTheme;
  final Value<String?> dvSubtopic;
  final Value<String?> dvSummary;
  final Value<String?> dvSimiles;
  final Value<String?> dvKeyExcerpt1;
  final Value<String?> dvKeyExcerpt2;
  final Value<String?> dvStage;
  final Value<String?> dvTraining;
  final Value<String?> dvAspect;
  final Value<String?> dvTeacher;
  final Value<String?> dvAudience;
  final Value<String?> dvMethod;
  final Value<String?> dvLength;
  final Value<String?> dvProminence;
  final Value<String?> dvNikayasParallels;
  final Value<String?> dvAgamasParallels;
  final Value<String?> dvTaishoParallels;
  final Value<String?> dvSanskritParallels;
  final Value<String?> dvVinayaParallels;
  final Value<String?> dvOthersParallels;
  final Value<String?> dvPartialParallelsNa;
  final Value<String?> dvPartialParallelsAll;
  final Value<String?> dvSuggestedSuttas;
  final Value<int> rowid;
  const SuttaInfoCompanion({
    this.book = const Value.absent(),
    this.bookCode = const Value.absent(),
    this.dpdCode = const Value.absent(),
    this.dpdSutta = const Value.absent(),
    this.dpdSuttaVar = const Value.absent(),
    this.cstCode = const Value.absent(),
    this.cstNikaya = const Value.absent(),
    this.cstBook = const Value.absent(),
    this.cstSection = const Value.absent(),
    this.cstVagga = const Value.absent(),
    this.cstSutta = const Value.absent(),
    this.cstParanum = const Value.absent(),
    this.cstMPage = const Value.absent(),
    this.cstVPage = const Value.absent(),
    this.cstPPage = const Value.absent(),
    this.cstTPage = const Value.absent(),
    this.cstFile = const Value.absent(),
    this.scCode = const Value.absent(),
    this.scBook = const Value.absent(),
    this.scVagga = const Value.absent(),
    this.scSutta = const Value.absent(),
    this.scEngSutta = const Value.absent(),
    this.scBlurb = const Value.absent(),
    this.scFilePath = const Value.absent(),
    this.dprCode = const Value.absent(),
    this.dprLink = const Value.absent(),
    this.bjtSuttaCode = const Value.absent(),
    this.bjtWebCode = const Value.absent(),
    this.bjtFilename = const Value.absent(),
    this.bjtBookId = const Value.absent(),
    this.bjtPageNum = const Value.absent(),
    this.bjtPageOffset = const Value.absent(),
    this.bjtPitaka = const Value.absent(),
    this.bjtNikaya = const Value.absent(),
    this.bjtMajorSection = const Value.absent(),
    this.bjtBook = const Value.absent(),
    this.bjtMinorSection = const Value.absent(),
    this.bjtVagga = const Value.absent(),
    this.bjtSutta = const Value.absent(),
    this.dvPts = const Value.absent(),
    this.dvMainTheme = const Value.absent(),
    this.dvSubtopic = const Value.absent(),
    this.dvSummary = const Value.absent(),
    this.dvSimiles = const Value.absent(),
    this.dvKeyExcerpt1 = const Value.absent(),
    this.dvKeyExcerpt2 = const Value.absent(),
    this.dvStage = const Value.absent(),
    this.dvTraining = const Value.absent(),
    this.dvAspect = const Value.absent(),
    this.dvTeacher = const Value.absent(),
    this.dvAudience = const Value.absent(),
    this.dvMethod = const Value.absent(),
    this.dvLength = const Value.absent(),
    this.dvProminence = const Value.absent(),
    this.dvNikayasParallels = const Value.absent(),
    this.dvAgamasParallels = const Value.absent(),
    this.dvTaishoParallels = const Value.absent(),
    this.dvSanskritParallels = const Value.absent(),
    this.dvVinayaParallels = const Value.absent(),
    this.dvOthersParallels = const Value.absent(),
    this.dvPartialParallelsNa = const Value.absent(),
    this.dvPartialParallelsAll = const Value.absent(),
    this.dvSuggestedSuttas = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuttaInfoCompanion.insert({
    this.book = const Value.absent(),
    this.bookCode = const Value.absent(),
    this.dpdCode = const Value.absent(),
    required String dpdSutta,
    this.dpdSuttaVar = const Value.absent(),
    this.cstCode = const Value.absent(),
    this.cstNikaya = const Value.absent(),
    this.cstBook = const Value.absent(),
    this.cstSection = const Value.absent(),
    this.cstVagga = const Value.absent(),
    this.cstSutta = const Value.absent(),
    this.cstParanum = const Value.absent(),
    this.cstMPage = const Value.absent(),
    this.cstVPage = const Value.absent(),
    this.cstPPage = const Value.absent(),
    this.cstTPage = const Value.absent(),
    this.cstFile = const Value.absent(),
    this.scCode = const Value.absent(),
    this.scBook = const Value.absent(),
    this.scVagga = const Value.absent(),
    this.scSutta = const Value.absent(),
    this.scEngSutta = const Value.absent(),
    this.scBlurb = const Value.absent(),
    this.scFilePath = const Value.absent(),
    this.dprCode = const Value.absent(),
    this.dprLink = const Value.absent(),
    this.bjtSuttaCode = const Value.absent(),
    this.bjtWebCode = const Value.absent(),
    this.bjtFilename = const Value.absent(),
    this.bjtBookId = const Value.absent(),
    this.bjtPageNum = const Value.absent(),
    this.bjtPageOffset = const Value.absent(),
    this.bjtPitaka = const Value.absent(),
    this.bjtNikaya = const Value.absent(),
    this.bjtMajorSection = const Value.absent(),
    this.bjtBook = const Value.absent(),
    this.bjtMinorSection = const Value.absent(),
    this.bjtVagga = const Value.absent(),
    this.bjtSutta = const Value.absent(),
    this.dvPts = const Value.absent(),
    this.dvMainTheme = const Value.absent(),
    this.dvSubtopic = const Value.absent(),
    this.dvSummary = const Value.absent(),
    this.dvSimiles = const Value.absent(),
    this.dvKeyExcerpt1 = const Value.absent(),
    this.dvKeyExcerpt2 = const Value.absent(),
    this.dvStage = const Value.absent(),
    this.dvTraining = const Value.absent(),
    this.dvAspect = const Value.absent(),
    this.dvTeacher = const Value.absent(),
    this.dvAudience = const Value.absent(),
    this.dvMethod = const Value.absent(),
    this.dvLength = const Value.absent(),
    this.dvProminence = const Value.absent(),
    this.dvNikayasParallels = const Value.absent(),
    this.dvAgamasParallels = const Value.absent(),
    this.dvTaishoParallels = const Value.absent(),
    this.dvSanskritParallels = const Value.absent(),
    this.dvVinayaParallels = const Value.absent(),
    this.dvOthersParallels = const Value.absent(),
    this.dvPartialParallelsNa = const Value.absent(),
    this.dvPartialParallelsAll = const Value.absent(),
    this.dvSuggestedSuttas = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dpdSutta = Value(dpdSutta);
  static Insertable<SuttaInfoData> custom({
    Expression<String>? book,
    Expression<String>? bookCode,
    Expression<String>? dpdCode,
    Expression<String>? dpdSutta,
    Expression<String>? dpdSuttaVar,
    Expression<String>? cstCode,
    Expression<String>? cstNikaya,
    Expression<String>? cstBook,
    Expression<String>? cstSection,
    Expression<String>? cstVagga,
    Expression<String>? cstSutta,
    Expression<String>? cstParanum,
    Expression<String>? cstMPage,
    Expression<String>? cstVPage,
    Expression<String>? cstPPage,
    Expression<String>? cstTPage,
    Expression<String>? cstFile,
    Expression<String>? scCode,
    Expression<String>? scBook,
    Expression<String>? scVagga,
    Expression<String>? scSutta,
    Expression<String>? scEngSutta,
    Expression<String>? scBlurb,
    Expression<String>? scFilePath,
    Expression<String>? dprCode,
    Expression<String>? dprLink,
    Expression<String>? bjtSuttaCode,
    Expression<String>? bjtWebCode,
    Expression<String>? bjtFilename,
    Expression<String>? bjtBookId,
    Expression<String>? bjtPageNum,
    Expression<String>? bjtPageOffset,
    Expression<String>? bjtPitaka,
    Expression<String>? bjtNikaya,
    Expression<String>? bjtMajorSection,
    Expression<String>? bjtBook,
    Expression<String>? bjtMinorSection,
    Expression<String>? bjtVagga,
    Expression<String>? bjtSutta,
    Expression<String>? dvPts,
    Expression<String>? dvMainTheme,
    Expression<String>? dvSubtopic,
    Expression<String>? dvSummary,
    Expression<String>? dvSimiles,
    Expression<String>? dvKeyExcerpt1,
    Expression<String>? dvKeyExcerpt2,
    Expression<String>? dvStage,
    Expression<String>? dvTraining,
    Expression<String>? dvAspect,
    Expression<String>? dvTeacher,
    Expression<String>? dvAudience,
    Expression<String>? dvMethod,
    Expression<String>? dvLength,
    Expression<String>? dvProminence,
    Expression<String>? dvNikayasParallels,
    Expression<String>? dvAgamasParallels,
    Expression<String>? dvTaishoParallels,
    Expression<String>? dvSanskritParallels,
    Expression<String>? dvVinayaParallels,
    Expression<String>? dvOthersParallels,
    Expression<String>? dvPartialParallelsNa,
    Expression<String>? dvPartialParallelsAll,
    Expression<String>? dvSuggestedSuttas,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (book != null) 'book': book,
      if (bookCode != null) 'book_code': bookCode,
      if (dpdCode != null) 'dpd_code': dpdCode,
      if (dpdSutta != null) 'dpd_sutta': dpdSutta,
      if (dpdSuttaVar != null) 'dpd_sutta_var': dpdSuttaVar,
      if (cstCode != null) 'cst_code': cstCode,
      if (cstNikaya != null) 'cst_nikaya': cstNikaya,
      if (cstBook != null) 'cst_book': cstBook,
      if (cstSection != null) 'cst_section': cstSection,
      if (cstVagga != null) 'cst_vagga': cstVagga,
      if (cstSutta != null) 'cst_sutta': cstSutta,
      if (cstParanum != null) 'cst_paranum': cstParanum,
      if (cstMPage != null) 'cst_m_page': cstMPage,
      if (cstVPage != null) 'cst_v_page': cstVPage,
      if (cstPPage != null) 'cst_p_page': cstPPage,
      if (cstTPage != null) 'cst_t_page': cstTPage,
      if (cstFile != null) 'cst_file': cstFile,
      if (scCode != null) 'sc_code': scCode,
      if (scBook != null) 'sc_book': scBook,
      if (scVagga != null) 'sc_vagga': scVagga,
      if (scSutta != null) 'sc_sutta': scSutta,
      if (scEngSutta != null) 'sc_eng_sutta': scEngSutta,
      if (scBlurb != null) 'sc_blurb': scBlurb,
      if (scFilePath != null) 'sc_file_path': scFilePath,
      if (dprCode != null) 'dpr_code': dprCode,
      if (dprLink != null) 'dpr_link': dprLink,
      if (bjtSuttaCode != null) 'bjt_sutta_code': bjtSuttaCode,
      if (bjtWebCode != null) 'bjt_web_code': bjtWebCode,
      if (bjtFilename != null) 'bjt_filename': bjtFilename,
      if (bjtBookId != null) 'bjt_book_id': bjtBookId,
      if (bjtPageNum != null) 'bjt_page_num': bjtPageNum,
      if (bjtPageOffset != null) 'bjt_page_offset': bjtPageOffset,
      if (bjtPitaka != null) 'bjt_piṭaka': bjtPitaka,
      if (bjtNikaya != null) 'bjt_nikāya': bjtNikaya,
      if (bjtMajorSection != null) 'bjt_major_section': bjtMajorSection,
      if (bjtBook != null) 'bjt_book': bjtBook,
      if (bjtMinorSection != null) 'bjt_minor_section': bjtMinorSection,
      if (bjtVagga != null) 'bjt_vagga': bjtVagga,
      if (bjtSutta != null) 'bjt_sutta': bjtSutta,
      if (dvPts != null) 'dv_pts': dvPts,
      if (dvMainTheme != null) 'dv_main_theme': dvMainTheme,
      if (dvSubtopic != null) 'dv_subtopic': dvSubtopic,
      if (dvSummary != null) 'dv_summary': dvSummary,
      if (dvSimiles != null) 'dv_similes': dvSimiles,
      if (dvKeyExcerpt1 != null) 'dv_key_excerpt1': dvKeyExcerpt1,
      if (dvKeyExcerpt2 != null) 'dv_key_excerpt2': dvKeyExcerpt2,
      if (dvStage != null) 'dv_stage': dvStage,
      if (dvTraining != null) 'dv_training': dvTraining,
      if (dvAspect != null) 'dv_aspect': dvAspect,
      if (dvTeacher != null) 'dv_teacher': dvTeacher,
      if (dvAudience != null) 'dv_audience': dvAudience,
      if (dvMethod != null) 'dv_method': dvMethod,
      if (dvLength != null) 'dv_length': dvLength,
      if (dvProminence != null) 'dv_prominence': dvProminence,
      if (dvNikayasParallels != null)
        'dv_nikayas_parallels': dvNikayasParallels,
      if (dvAgamasParallels != null) 'dv_āgamas_parallels': dvAgamasParallels,
      if (dvTaishoParallels != null) 'dv_taisho_parallels': dvTaishoParallels,
      if (dvSanskritParallels != null)
        'dv_sanskrit_parallels': dvSanskritParallels,
      if (dvVinayaParallels != null) 'dv_vinaya_parallels': dvVinayaParallels,
      if (dvOthersParallels != null) 'dv_others_parallels': dvOthersParallels,
      if (dvPartialParallelsNa != null)
        'dv_partial_parallels_nā': dvPartialParallelsNa,
      if (dvPartialParallelsAll != null)
        'dv_partial_parallels_all': dvPartialParallelsAll,
      if (dvSuggestedSuttas != null) 'dv_suggested_suttas': dvSuggestedSuttas,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuttaInfoCompanion copyWith({
    Value<String?>? book,
    Value<String?>? bookCode,
    Value<String?>? dpdCode,
    Value<String>? dpdSutta,
    Value<String?>? dpdSuttaVar,
    Value<String?>? cstCode,
    Value<String?>? cstNikaya,
    Value<String?>? cstBook,
    Value<String?>? cstSection,
    Value<String?>? cstVagga,
    Value<String?>? cstSutta,
    Value<String?>? cstParanum,
    Value<String?>? cstMPage,
    Value<String?>? cstVPage,
    Value<String?>? cstPPage,
    Value<String?>? cstTPage,
    Value<String?>? cstFile,
    Value<String?>? scCode,
    Value<String?>? scBook,
    Value<String?>? scVagga,
    Value<String?>? scSutta,
    Value<String?>? scEngSutta,
    Value<String?>? scBlurb,
    Value<String?>? scFilePath,
    Value<String?>? dprCode,
    Value<String?>? dprLink,
    Value<String?>? bjtSuttaCode,
    Value<String?>? bjtWebCode,
    Value<String?>? bjtFilename,
    Value<String?>? bjtBookId,
    Value<String?>? bjtPageNum,
    Value<String?>? bjtPageOffset,
    Value<String?>? bjtPitaka,
    Value<String?>? bjtNikaya,
    Value<String?>? bjtMajorSection,
    Value<String?>? bjtBook,
    Value<String?>? bjtMinorSection,
    Value<String?>? bjtVagga,
    Value<String?>? bjtSutta,
    Value<String?>? dvPts,
    Value<String?>? dvMainTheme,
    Value<String?>? dvSubtopic,
    Value<String?>? dvSummary,
    Value<String?>? dvSimiles,
    Value<String?>? dvKeyExcerpt1,
    Value<String?>? dvKeyExcerpt2,
    Value<String?>? dvStage,
    Value<String?>? dvTraining,
    Value<String?>? dvAspect,
    Value<String?>? dvTeacher,
    Value<String?>? dvAudience,
    Value<String?>? dvMethod,
    Value<String?>? dvLength,
    Value<String?>? dvProminence,
    Value<String?>? dvNikayasParallels,
    Value<String?>? dvAgamasParallels,
    Value<String?>? dvTaishoParallels,
    Value<String?>? dvSanskritParallels,
    Value<String?>? dvVinayaParallels,
    Value<String?>? dvOthersParallels,
    Value<String?>? dvPartialParallelsNa,
    Value<String?>? dvPartialParallelsAll,
    Value<String?>? dvSuggestedSuttas,
    Value<int>? rowid,
  }) {
    return SuttaInfoCompanion(
      book: book ?? this.book,
      bookCode: bookCode ?? this.bookCode,
      dpdCode: dpdCode ?? this.dpdCode,
      dpdSutta: dpdSutta ?? this.dpdSutta,
      dpdSuttaVar: dpdSuttaVar ?? this.dpdSuttaVar,
      cstCode: cstCode ?? this.cstCode,
      cstNikaya: cstNikaya ?? this.cstNikaya,
      cstBook: cstBook ?? this.cstBook,
      cstSection: cstSection ?? this.cstSection,
      cstVagga: cstVagga ?? this.cstVagga,
      cstSutta: cstSutta ?? this.cstSutta,
      cstParanum: cstParanum ?? this.cstParanum,
      cstMPage: cstMPage ?? this.cstMPage,
      cstVPage: cstVPage ?? this.cstVPage,
      cstPPage: cstPPage ?? this.cstPPage,
      cstTPage: cstTPage ?? this.cstTPage,
      cstFile: cstFile ?? this.cstFile,
      scCode: scCode ?? this.scCode,
      scBook: scBook ?? this.scBook,
      scVagga: scVagga ?? this.scVagga,
      scSutta: scSutta ?? this.scSutta,
      scEngSutta: scEngSutta ?? this.scEngSutta,
      scBlurb: scBlurb ?? this.scBlurb,
      scFilePath: scFilePath ?? this.scFilePath,
      dprCode: dprCode ?? this.dprCode,
      dprLink: dprLink ?? this.dprLink,
      bjtSuttaCode: bjtSuttaCode ?? this.bjtSuttaCode,
      bjtWebCode: bjtWebCode ?? this.bjtWebCode,
      bjtFilename: bjtFilename ?? this.bjtFilename,
      bjtBookId: bjtBookId ?? this.bjtBookId,
      bjtPageNum: bjtPageNum ?? this.bjtPageNum,
      bjtPageOffset: bjtPageOffset ?? this.bjtPageOffset,
      bjtPitaka: bjtPitaka ?? this.bjtPitaka,
      bjtNikaya: bjtNikaya ?? this.bjtNikaya,
      bjtMajorSection: bjtMajorSection ?? this.bjtMajorSection,
      bjtBook: bjtBook ?? this.bjtBook,
      bjtMinorSection: bjtMinorSection ?? this.bjtMinorSection,
      bjtVagga: bjtVagga ?? this.bjtVagga,
      bjtSutta: bjtSutta ?? this.bjtSutta,
      dvPts: dvPts ?? this.dvPts,
      dvMainTheme: dvMainTheme ?? this.dvMainTheme,
      dvSubtopic: dvSubtopic ?? this.dvSubtopic,
      dvSummary: dvSummary ?? this.dvSummary,
      dvSimiles: dvSimiles ?? this.dvSimiles,
      dvKeyExcerpt1: dvKeyExcerpt1 ?? this.dvKeyExcerpt1,
      dvKeyExcerpt2: dvKeyExcerpt2 ?? this.dvKeyExcerpt2,
      dvStage: dvStage ?? this.dvStage,
      dvTraining: dvTraining ?? this.dvTraining,
      dvAspect: dvAspect ?? this.dvAspect,
      dvTeacher: dvTeacher ?? this.dvTeacher,
      dvAudience: dvAudience ?? this.dvAudience,
      dvMethod: dvMethod ?? this.dvMethod,
      dvLength: dvLength ?? this.dvLength,
      dvProminence: dvProminence ?? this.dvProminence,
      dvNikayasParallels: dvNikayasParallels ?? this.dvNikayasParallels,
      dvAgamasParallels: dvAgamasParallels ?? this.dvAgamasParallels,
      dvTaishoParallels: dvTaishoParallels ?? this.dvTaishoParallels,
      dvSanskritParallels: dvSanskritParallels ?? this.dvSanskritParallels,
      dvVinayaParallels: dvVinayaParallels ?? this.dvVinayaParallels,
      dvOthersParallels: dvOthersParallels ?? this.dvOthersParallels,
      dvPartialParallelsNa: dvPartialParallelsNa ?? this.dvPartialParallelsNa,
      dvPartialParallelsAll:
          dvPartialParallelsAll ?? this.dvPartialParallelsAll,
      dvSuggestedSuttas: dvSuggestedSuttas ?? this.dvSuggestedSuttas,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (book.present) {
      map['book'] = Variable<String>(book.value);
    }
    if (bookCode.present) {
      map['book_code'] = Variable<String>(bookCode.value);
    }
    if (dpdCode.present) {
      map['dpd_code'] = Variable<String>(dpdCode.value);
    }
    if (dpdSutta.present) {
      map['dpd_sutta'] = Variable<String>(dpdSutta.value);
    }
    if (dpdSuttaVar.present) {
      map['dpd_sutta_var'] = Variable<String>(dpdSuttaVar.value);
    }
    if (cstCode.present) {
      map['cst_code'] = Variable<String>(cstCode.value);
    }
    if (cstNikaya.present) {
      map['cst_nikaya'] = Variable<String>(cstNikaya.value);
    }
    if (cstBook.present) {
      map['cst_book'] = Variable<String>(cstBook.value);
    }
    if (cstSection.present) {
      map['cst_section'] = Variable<String>(cstSection.value);
    }
    if (cstVagga.present) {
      map['cst_vagga'] = Variable<String>(cstVagga.value);
    }
    if (cstSutta.present) {
      map['cst_sutta'] = Variable<String>(cstSutta.value);
    }
    if (cstParanum.present) {
      map['cst_paranum'] = Variable<String>(cstParanum.value);
    }
    if (cstMPage.present) {
      map['cst_m_page'] = Variable<String>(cstMPage.value);
    }
    if (cstVPage.present) {
      map['cst_v_page'] = Variable<String>(cstVPage.value);
    }
    if (cstPPage.present) {
      map['cst_p_page'] = Variable<String>(cstPPage.value);
    }
    if (cstTPage.present) {
      map['cst_t_page'] = Variable<String>(cstTPage.value);
    }
    if (cstFile.present) {
      map['cst_file'] = Variable<String>(cstFile.value);
    }
    if (scCode.present) {
      map['sc_code'] = Variable<String>(scCode.value);
    }
    if (scBook.present) {
      map['sc_book'] = Variable<String>(scBook.value);
    }
    if (scVagga.present) {
      map['sc_vagga'] = Variable<String>(scVagga.value);
    }
    if (scSutta.present) {
      map['sc_sutta'] = Variable<String>(scSutta.value);
    }
    if (scEngSutta.present) {
      map['sc_eng_sutta'] = Variable<String>(scEngSutta.value);
    }
    if (scBlurb.present) {
      map['sc_blurb'] = Variable<String>(scBlurb.value);
    }
    if (scFilePath.present) {
      map['sc_file_path'] = Variable<String>(scFilePath.value);
    }
    if (dprCode.present) {
      map['dpr_code'] = Variable<String>(dprCode.value);
    }
    if (dprLink.present) {
      map['dpr_link'] = Variable<String>(dprLink.value);
    }
    if (bjtSuttaCode.present) {
      map['bjt_sutta_code'] = Variable<String>(bjtSuttaCode.value);
    }
    if (bjtWebCode.present) {
      map['bjt_web_code'] = Variable<String>(bjtWebCode.value);
    }
    if (bjtFilename.present) {
      map['bjt_filename'] = Variable<String>(bjtFilename.value);
    }
    if (bjtBookId.present) {
      map['bjt_book_id'] = Variable<String>(bjtBookId.value);
    }
    if (bjtPageNum.present) {
      map['bjt_page_num'] = Variable<String>(bjtPageNum.value);
    }
    if (bjtPageOffset.present) {
      map['bjt_page_offset'] = Variable<String>(bjtPageOffset.value);
    }
    if (bjtPitaka.present) {
      map['bjt_piṭaka'] = Variable<String>(bjtPitaka.value);
    }
    if (bjtNikaya.present) {
      map['bjt_nikāya'] = Variable<String>(bjtNikaya.value);
    }
    if (bjtMajorSection.present) {
      map['bjt_major_section'] = Variable<String>(bjtMajorSection.value);
    }
    if (bjtBook.present) {
      map['bjt_book'] = Variable<String>(bjtBook.value);
    }
    if (bjtMinorSection.present) {
      map['bjt_minor_section'] = Variable<String>(bjtMinorSection.value);
    }
    if (bjtVagga.present) {
      map['bjt_vagga'] = Variable<String>(bjtVagga.value);
    }
    if (bjtSutta.present) {
      map['bjt_sutta'] = Variable<String>(bjtSutta.value);
    }
    if (dvPts.present) {
      map['dv_pts'] = Variable<String>(dvPts.value);
    }
    if (dvMainTheme.present) {
      map['dv_main_theme'] = Variable<String>(dvMainTheme.value);
    }
    if (dvSubtopic.present) {
      map['dv_subtopic'] = Variable<String>(dvSubtopic.value);
    }
    if (dvSummary.present) {
      map['dv_summary'] = Variable<String>(dvSummary.value);
    }
    if (dvSimiles.present) {
      map['dv_similes'] = Variable<String>(dvSimiles.value);
    }
    if (dvKeyExcerpt1.present) {
      map['dv_key_excerpt1'] = Variable<String>(dvKeyExcerpt1.value);
    }
    if (dvKeyExcerpt2.present) {
      map['dv_key_excerpt2'] = Variable<String>(dvKeyExcerpt2.value);
    }
    if (dvStage.present) {
      map['dv_stage'] = Variable<String>(dvStage.value);
    }
    if (dvTraining.present) {
      map['dv_training'] = Variable<String>(dvTraining.value);
    }
    if (dvAspect.present) {
      map['dv_aspect'] = Variable<String>(dvAspect.value);
    }
    if (dvTeacher.present) {
      map['dv_teacher'] = Variable<String>(dvTeacher.value);
    }
    if (dvAudience.present) {
      map['dv_audience'] = Variable<String>(dvAudience.value);
    }
    if (dvMethod.present) {
      map['dv_method'] = Variable<String>(dvMethod.value);
    }
    if (dvLength.present) {
      map['dv_length'] = Variable<String>(dvLength.value);
    }
    if (dvProminence.present) {
      map['dv_prominence'] = Variable<String>(dvProminence.value);
    }
    if (dvNikayasParallels.present) {
      map['dv_nikayas_parallels'] = Variable<String>(dvNikayasParallels.value);
    }
    if (dvAgamasParallels.present) {
      map['dv_āgamas_parallels'] = Variable<String>(dvAgamasParallels.value);
    }
    if (dvTaishoParallels.present) {
      map['dv_taisho_parallels'] = Variable<String>(dvTaishoParallels.value);
    }
    if (dvSanskritParallels.present) {
      map['dv_sanskrit_parallels'] = Variable<String>(
        dvSanskritParallels.value,
      );
    }
    if (dvVinayaParallels.present) {
      map['dv_vinaya_parallels'] = Variable<String>(dvVinayaParallels.value);
    }
    if (dvOthersParallels.present) {
      map['dv_others_parallels'] = Variable<String>(dvOthersParallels.value);
    }
    if (dvPartialParallelsNa.present) {
      map['dv_partial_parallels_nā'] = Variable<String>(
        dvPartialParallelsNa.value,
      );
    }
    if (dvPartialParallelsAll.present) {
      map['dv_partial_parallels_all'] = Variable<String>(
        dvPartialParallelsAll.value,
      );
    }
    if (dvSuggestedSuttas.present) {
      map['dv_suggested_suttas'] = Variable<String>(dvSuggestedSuttas.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuttaInfoCompanion(')
          ..write('book: $book, ')
          ..write('bookCode: $bookCode, ')
          ..write('dpdCode: $dpdCode, ')
          ..write('dpdSutta: $dpdSutta, ')
          ..write('dpdSuttaVar: $dpdSuttaVar, ')
          ..write('cstCode: $cstCode, ')
          ..write('cstNikaya: $cstNikaya, ')
          ..write('cstBook: $cstBook, ')
          ..write('cstSection: $cstSection, ')
          ..write('cstVagga: $cstVagga, ')
          ..write('cstSutta: $cstSutta, ')
          ..write('cstParanum: $cstParanum, ')
          ..write('cstMPage: $cstMPage, ')
          ..write('cstVPage: $cstVPage, ')
          ..write('cstPPage: $cstPPage, ')
          ..write('cstTPage: $cstTPage, ')
          ..write('cstFile: $cstFile, ')
          ..write('scCode: $scCode, ')
          ..write('scBook: $scBook, ')
          ..write('scVagga: $scVagga, ')
          ..write('scSutta: $scSutta, ')
          ..write('scEngSutta: $scEngSutta, ')
          ..write('scBlurb: $scBlurb, ')
          ..write('scFilePath: $scFilePath, ')
          ..write('dprCode: $dprCode, ')
          ..write('dprLink: $dprLink, ')
          ..write('bjtSuttaCode: $bjtSuttaCode, ')
          ..write('bjtWebCode: $bjtWebCode, ')
          ..write('bjtFilename: $bjtFilename, ')
          ..write('bjtBookId: $bjtBookId, ')
          ..write('bjtPageNum: $bjtPageNum, ')
          ..write('bjtPageOffset: $bjtPageOffset, ')
          ..write('bjtPitaka: $bjtPitaka, ')
          ..write('bjtNikaya: $bjtNikaya, ')
          ..write('bjtMajorSection: $bjtMajorSection, ')
          ..write('bjtBook: $bjtBook, ')
          ..write('bjtMinorSection: $bjtMinorSection, ')
          ..write('bjtVagga: $bjtVagga, ')
          ..write('bjtSutta: $bjtSutta, ')
          ..write('dvPts: $dvPts, ')
          ..write('dvMainTheme: $dvMainTheme, ')
          ..write('dvSubtopic: $dvSubtopic, ')
          ..write('dvSummary: $dvSummary, ')
          ..write('dvSimiles: $dvSimiles, ')
          ..write('dvKeyExcerpt1: $dvKeyExcerpt1, ')
          ..write('dvKeyExcerpt2: $dvKeyExcerpt2, ')
          ..write('dvStage: $dvStage, ')
          ..write('dvTraining: $dvTraining, ')
          ..write('dvAspect: $dvAspect, ')
          ..write('dvTeacher: $dvTeacher, ')
          ..write('dvAudience: $dvAudience, ')
          ..write('dvMethod: $dvMethod, ')
          ..write('dvLength: $dvLength, ')
          ..write('dvProminence: $dvProminence, ')
          ..write('dvNikayasParallels: $dvNikayasParallels, ')
          ..write('dvAgamasParallels: $dvAgamasParallels, ')
          ..write('dvTaishoParallels: $dvTaishoParallels, ')
          ..write('dvSanskritParallels: $dvSanskritParallels, ')
          ..write('dvVinayaParallels: $dvVinayaParallels, ')
          ..write('dvOthersParallels: $dvOthersParallels, ')
          ..write('dvPartialParallelsNa: $dvPartialParallelsNa, ')
          ..write('dvPartialParallelsAll: $dvPartialParallelsAll, ')
          ..write('dvSuggestedSuttas: $dvSuggestedSuttas, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    } else if (isInserting) {
      context.missing(_nameMeta);
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
      )!,
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
  final String name;
  final String? author;
  final String? css;
  final int? entryCount;
  const DictMetaData({
    required this.dictId,
    required this.name,
    this.author,
    this.css,
    this.entryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dict_id'] = Variable<String>(dictId);
    map['name'] = Variable<String>(name);
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
      name: Value(name),
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
      name: serializer.fromJson<String>(json['name']),
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
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String?>(author),
      'css': serializer.toJson<String?>(css),
      'entryCount': serializer.toJson<int?>(entryCount),
    };
  }

  DictMetaData copyWith({
    String? dictId,
    String? name,
    Value<String?> author = const Value.absent(),
    Value<String?> css = const Value.absent(),
    Value<int?> entryCount = const Value.absent(),
  }) => DictMetaData(
    dictId: dictId ?? this.dictId,
    name: name ?? this.name,
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
  final Value<String> name;
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
    required String name,
    this.author = const Value.absent(),
    this.css = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dictId = Value(dictId),
       name = Value(name);
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
    Value<String>? name,
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

abstract class _$DpdDatabase extends GeneratedDatabase {
  _$DpdDatabase(QueryExecutor e) : super(e);
  $DpdDatabaseManager get managers => $DpdDatabaseManager(this);
  late final $DpdRootsTable dpdRoots = $DpdRootsTable(this);
  late final $DpdHeadwordsTable dpdHeadwords = $DpdHeadwordsTable(this);
  late final $LookupTable lookup = $LookupTable(this);
  late final $DbInfoTable dbInfo = $DbInfoTable(this);
  late final $InflectionTemplatesTable inflectionTemplates =
      $InflectionTemplatesTable(this);
  late final $FamilyRootTable familyRoot = $FamilyRootTable(this);
  late final $FamilyWordTable familyWord = $FamilyWordTable(this);
  late final $FamilyCompoundTable familyCompound = $FamilyCompoundTable(this);
  late final $FamilyIdiomTable familyIdiom = $FamilyIdiomTable(this);
  late final $FamilySetTable familySet = $FamilySetTable(this);
  late final $SuttaInfoTable suttaInfo = $SuttaInfoTable(this);
  late final $DictMetaTable dictMeta = $DictMetaTable(this);
  late final $DictEntriesTable dictEntries = $DictEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dpdRoots,
    dpdHeadwords,
    lookup,
    dbInfo,
    inflectionTemplates,
    familyRoot,
    familyWord,
    familyCompound,
    familyIdiom,
    familySet,
    suttaInfo,
    dictMeta,
    dictEntries,
  ];
}

typedef $$DpdRootsTableCreateCompanionBuilder =
    DpdRootsCompanion Function({
      required String root,
      required String rootInComps,
      required String rootHasVerb,
      required int rootGroup,
      required String rootSign,
      required String rootMeaning,
      required String sanskritRoot,
      required String sanskritRootMeaning,
      required String sanskritRootClass,
      required String rootExample,
      required String dhatupathaNum,
      required String dhatupathaRoot,
      required String dhatupathaPali,
      required String dhatupathaEnglish,
      required String dhatumanjusaNum,
      required String dhatumanjusaRoot,
      required String dhatumanjusaPali,
      required String dhatumanjusaEnglish,
      required String dhatumalaRoot,
      required String dhatumalaPali,
      required String dhatumalaEnglish,
      required String paniniRoot,
      required String paniniSanskrit,
      required String paniniEnglish,
      required String note,
      Value<int?> rootCount,
      Value<int> rowid,
    });
typedef $$DpdRootsTableUpdateCompanionBuilder =
    DpdRootsCompanion Function({
      Value<String> root,
      Value<String> rootInComps,
      Value<String> rootHasVerb,
      Value<int> rootGroup,
      Value<String> rootSign,
      Value<String> rootMeaning,
      Value<String> sanskritRoot,
      Value<String> sanskritRootMeaning,
      Value<String> sanskritRootClass,
      Value<String> rootExample,
      Value<String> dhatupathaNum,
      Value<String> dhatupathaRoot,
      Value<String> dhatupathaPali,
      Value<String> dhatupathaEnglish,
      Value<String> dhatumanjusaNum,
      Value<String> dhatumanjusaRoot,
      Value<String> dhatumanjusaPali,
      Value<String> dhatumanjusaEnglish,
      Value<String> dhatumalaRoot,
      Value<String> dhatumalaPali,
      Value<String> dhatumalaEnglish,
      Value<String> paniniRoot,
      Value<String> paniniSanskrit,
      Value<String> paniniEnglish,
      Value<String> note,
      Value<int?> rootCount,
      Value<int> rowid,
    });

final class $$DpdRootsTableReferences
    extends BaseReferences<_$DpdDatabase, $DpdRootsTable, DpdRoot> {
  $$DpdRootsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DpdHeadwordsTable, List<DpdHeadword>>
  _dpdHeadwordsRefsTable(_$DpdDatabase db) => MultiTypedResultKey.fromTable(
    db.dpdHeadwords,
    aliasName: $_aliasNameGenerator(db.dpdRoots.root, db.dpdHeadwords.rootKey),
  );

  $$DpdHeadwordsTableProcessedTableManager get dpdHeadwordsRefs {
    final manager = $$DpdHeadwordsTableTableManager(
      $_db,
      $_db.dpdHeadwords,
    ).filter((f) => f.rootKey.root.sqlEquals($_itemColumn<String>('root')!));

    final cache = $_typedResult.readTableOrNull(_dpdHeadwordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  ColumnFilters<int> get rootGroup => $composableBuilder(
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

  ColumnFilters<String> get dhatupathaNum => $composableBuilder(
    column: $table.dhatupathaNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatupathaRoot => $composableBuilder(
    column: $table.dhatupathaRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatupathaPali => $composableBuilder(
    column: $table.dhatupathaPali,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatupathaEnglish => $composableBuilder(
    column: $table.dhatupathaEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumanjusaNum => $composableBuilder(
    column: $table.dhatumanjusaNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumanjusaRoot => $composableBuilder(
    column: $table.dhatumanjusaRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumanjusaPali => $composableBuilder(
    column: $table.dhatumanjusaPali,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumanjusaEnglish => $composableBuilder(
    column: $table.dhatumanjusaEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumalaRoot => $composableBuilder(
    column: $table.dhatumalaRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumalaPali => $composableBuilder(
    column: $table.dhatumalaPali,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhatumalaEnglish => $composableBuilder(
    column: $table.dhatumalaEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paniniRoot => $composableBuilder(
    column: $table.paniniRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paniniSanskrit => $composableBuilder(
    column: $table.paniniSanskrit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paniniEnglish => $composableBuilder(
    column: $table.paniniEnglish,
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

  Expression<bool> dpdHeadwordsRefs(
    Expression<bool> Function($$DpdHeadwordsTableFilterComposer f) f,
  ) {
    final $$DpdHeadwordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.root,
      referencedTable: $db.dpdHeadwords,
      getReferencedColumn: (t) => t.rootKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DpdHeadwordsTableFilterComposer(
            $db: $db,
            $table: $db.dpdHeadwords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  ColumnOrderings<int> get rootGroup => $composableBuilder(
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

  ColumnOrderings<String> get dhatupathaNum => $composableBuilder(
    column: $table.dhatupathaNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatupathaRoot => $composableBuilder(
    column: $table.dhatupathaRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatupathaPali => $composableBuilder(
    column: $table.dhatupathaPali,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatupathaEnglish => $composableBuilder(
    column: $table.dhatupathaEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumanjusaNum => $composableBuilder(
    column: $table.dhatumanjusaNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumanjusaRoot => $composableBuilder(
    column: $table.dhatumanjusaRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumanjusaPali => $composableBuilder(
    column: $table.dhatumanjusaPali,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumanjusaEnglish => $composableBuilder(
    column: $table.dhatumanjusaEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumalaRoot => $composableBuilder(
    column: $table.dhatumalaRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumalaPali => $composableBuilder(
    column: $table.dhatumalaPali,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhatumalaEnglish => $composableBuilder(
    column: $table.dhatumalaEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paniniRoot => $composableBuilder(
    column: $table.paniniRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paniniSanskrit => $composableBuilder(
    column: $table.paniniSanskrit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paniniEnglish => $composableBuilder(
    column: $table.paniniEnglish,
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

  GeneratedColumn<int> get rootGroup =>
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

  GeneratedColumn<String> get dhatupathaNum => $composableBuilder(
    column: $table.dhatupathaNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatupathaRoot => $composableBuilder(
    column: $table.dhatupathaRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatupathaPali => $composableBuilder(
    column: $table.dhatupathaPali,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatupathaEnglish => $composableBuilder(
    column: $table.dhatupathaEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumanjusaNum => $composableBuilder(
    column: $table.dhatumanjusaNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumanjusaRoot => $composableBuilder(
    column: $table.dhatumanjusaRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumanjusaPali => $composableBuilder(
    column: $table.dhatumanjusaPali,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumanjusaEnglish => $composableBuilder(
    column: $table.dhatumanjusaEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumalaRoot => $composableBuilder(
    column: $table.dhatumalaRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumalaPali => $composableBuilder(
    column: $table.dhatumalaPali,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dhatumalaEnglish => $composableBuilder(
    column: $table.dhatumalaEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paniniRoot => $composableBuilder(
    column: $table.paniniRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paniniSanskrit => $composableBuilder(
    column: $table.paniniSanskrit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paniniEnglish => $composableBuilder(
    column: $table.paniniEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get rootCount =>
      $composableBuilder(column: $table.rootCount, builder: (column) => column);

  Expression<T> dpdHeadwordsRefs<T extends Object>(
    Expression<T> Function($$DpdHeadwordsTableAnnotationComposer a) f,
  ) {
    final $$DpdHeadwordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.root,
      referencedTable: $db.dpdHeadwords,
      getReferencedColumn: (t) => t.rootKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DpdHeadwordsTableAnnotationComposer(
            $db: $db,
            $table: $db.dpdHeadwords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (DpdRoot, $$DpdRootsTableReferences),
          DpdRoot,
          PrefetchHooks Function({bool dpdHeadwordsRefs})
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
                Value<String> rootInComps = const Value.absent(),
                Value<String> rootHasVerb = const Value.absent(),
                Value<int> rootGroup = const Value.absent(),
                Value<String> rootSign = const Value.absent(),
                Value<String> rootMeaning = const Value.absent(),
                Value<String> sanskritRoot = const Value.absent(),
                Value<String> sanskritRootMeaning = const Value.absent(),
                Value<String> sanskritRootClass = const Value.absent(),
                Value<String> rootExample = const Value.absent(),
                Value<String> dhatupathaNum = const Value.absent(),
                Value<String> dhatupathaRoot = const Value.absent(),
                Value<String> dhatupathaPali = const Value.absent(),
                Value<String> dhatupathaEnglish = const Value.absent(),
                Value<String> dhatumanjusaNum = const Value.absent(),
                Value<String> dhatumanjusaRoot = const Value.absent(),
                Value<String> dhatumanjusaPali = const Value.absent(),
                Value<String> dhatumanjusaEnglish = const Value.absent(),
                Value<String> dhatumalaRoot = const Value.absent(),
                Value<String> dhatumalaPali = const Value.absent(),
                Value<String> dhatumalaEnglish = const Value.absent(),
                Value<String> paniniRoot = const Value.absent(),
                Value<String> paniniSanskrit = const Value.absent(),
                Value<String> paniniEnglish = const Value.absent(),
                Value<String> note = const Value.absent(),
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
                dhatupathaNum: dhatupathaNum,
                dhatupathaRoot: dhatupathaRoot,
                dhatupathaPali: dhatupathaPali,
                dhatupathaEnglish: dhatupathaEnglish,
                dhatumanjusaNum: dhatumanjusaNum,
                dhatumanjusaRoot: dhatumanjusaRoot,
                dhatumanjusaPali: dhatumanjusaPali,
                dhatumanjusaEnglish: dhatumanjusaEnglish,
                dhatumalaRoot: dhatumalaRoot,
                dhatumalaPali: dhatumalaPali,
                dhatumalaEnglish: dhatumalaEnglish,
                paniniRoot: paniniRoot,
                paniniSanskrit: paniniSanskrit,
                paniniEnglish: paniniEnglish,
                note: note,
                rootCount: rootCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String root,
                required String rootInComps,
                required String rootHasVerb,
                required int rootGroup,
                required String rootSign,
                required String rootMeaning,
                required String sanskritRoot,
                required String sanskritRootMeaning,
                required String sanskritRootClass,
                required String rootExample,
                required String dhatupathaNum,
                required String dhatupathaRoot,
                required String dhatupathaPali,
                required String dhatupathaEnglish,
                required String dhatumanjusaNum,
                required String dhatumanjusaRoot,
                required String dhatumanjusaPali,
                required String dhatumanjusaEnglish,
                required String dhatumalaRoot,
                required String dhatumalaPali,
                required String dhatumalaEnglish,
                required String paniniRoot,
                required String paniniSanskrit,
                required String paniniEnglish,
                required String note,
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
                dhatupathaNum: dhatupathaNum,
                dhatupathaRoot: dhatupathaRoot,
                dhatupathaPali: dhatupathaPali,
                dhatupathaEnglish: dhatupathaEnglish,
                dhatumanjusaNum: dhatumanjusaNum,
                dhatumanjusaRoot: dhatumanjusaRoot,
                dhatumanjusaPali: dhatumanjusaPali,
                dhatumanjusaEnglish: dhatumanjusaEnglish,
                dhatumalaRoot: dhatumalaRoot,
                dhatumalaPali: dhatumalaPali,
                dhatumalaEnglish: dhatumalaEnglish,
                paniniRoot: paniniRoot,
                paniniSanskrit: paniniSanskrit,
                paniniEnglish: paniniEnglish,
                note: note,
                rootCount: rootCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DpdRootsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dpdHeadwordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (dpdHeadwordsRefs) db.dpdHeadwords],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dpdHeadwordsRefs)
                    await $_getPrefetchedData<
                      DpdRoot,
                      $DpdRootsTable,
                      DpdHeadword
                    >(
                      currentTable: table,
                      referencedTable: $$DpdRootsTableReferences
                          ._dpdHeadwordsRefsTable(db),
                      managerFromTypedResult: (p0) => $$DpdRootsTableReferences(
                        db,
                        table,
                        p0,
                      ).dpdHeadwordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.rootKey == item.root),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
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
      (DpdRoot, $$DpdRootsTableReferences),
      DpdRoot,
      PrefetchHooks Function({bool dpdHeadwordsRefs})
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
      Value<String?> rootKey,
      Value<String?> rootSign,
      Value<String?> rootBase,
      Value<String?> familyRoot,
      Value<String?> familyWord,
      Value<String?> familyCompound,
      Value<String?> familyIdioms,
      Value<String?> familySet,
      Value<String?> construction,
      Value<String?> compoundType,
      Value<String?> compoundConstruction,
      Value<String?> source1,
      Value<String?> sutta1,
      Value<String?> example1,
      Value<String?> source2,
      Value<String?> sutta2,
      Value<String?> example2,
      Value<String?> antonym,
      Value<String?> synonym,
      Value<String?> variant,
      Value<String?> stem,
      Value<String?> pattern,
      Value<String?> derivative,
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
      Value<String?> rootKey,
      Value<String?> rootSign,
      Value<String?> rootBase,
      Value<String?> familyRoot,
      Value<String?> familyWord,
      Value<String?> familyCompound,
      Value<String?> familyIdioms,
      Value<String?> familySet,
      Value<String?> construction,
      Value<String?> compoundType,
      Value<String?> compoundConstruction,
      Value<String?> source1,
      Value<String?> sutta1,
      Value<String?> example1,
      Value<String?> source2,
      Value<String?> sutta2,
      Value<String?> example2,
      Value<String?> antonym,
      Value<String?> synonym,
      Value<String?> variant,
      Value<String?> stem,
      Value<String?> pattern,
      Value<String?> derivative,
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

final class $$DpdHeadwordsTableReferences
    extends BaseReferences<_$DpdDatabase, $DpdHeadwordsTable, DpdHeadword> {
  $$DpdHeadwordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DpdRootsTable _rootKeyTable(_$DpdDatabase db) =>
      db.dpdRoots.createAlias(
        $_aliasNameGenerator(db.dpdHeadwords.rootKey, db.dpdRoots.root),
      );

  $$DpdRootsTableProcessedTableManager? get rootKey {
    final $_column = $_itemColumn<String>('root_key');
    if ($_column == null) return null;
    final manager = $$DpdRootsTableTableManager(
      $_db,
      $_db.dpdRoots,
    ).filter((f) => f.root.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rootKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  ColumnFilters<String> get familySet => $composableBuilder(
    column: $table.familySet,
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

  ColumnFilters<String> get compoundConstruction => $composableBuilder(
    column: $table.compoundConstruction,
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

  ColumnFilters<String> get derivative => $composableBuilder(
    column: $table.derivative,
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

  $$DpdRootsTableFilterComposer get rootKey {
    final $$DpdRootsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootKey,
      referencedTable: $db.dpdRoots,
      getReferencedColumn: (t) => t.root,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DpdRootsTableFilterComposer(
            $db: $db,
            $table: $db.dpdRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  ColumnOrderings<String> get familySet => $composableBuilder(
    column: $table.familySet,
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

  ColumnOrderings<String> get compoundConstruction => $composableBuilder(
    column: $table.compoundConstruction,
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

  ColumnOrderings<String> get derivative => $composableBuilder(
    column: $table.derivative,
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

  $$DpdRootsTableOrderingComposer get rootKey {
    final $$DpdRootsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootKey,
      referencedTable: $db.dpdRoots,
      getReferencedColumn: (t) => t.root,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DpdRootsTableOrderingComposer(
            $db: $db,
            $table: $db.dpdRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<String> get familySet =>
      $composableBuilder(column: $table.familySet, builder: (column) => column);

  GeneratedColumn<String> get construction => $composableBuilder(
    column: $table.construction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compoundType => $composableBuilder(
    column: $table.compoundType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compoundConstruction => $composableBuilder(
    column: $table.compoundConstruction,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get derivative => $composableBuilder(
    column: $table.derivative,
    builder: (column) => column,
  );

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

  $$DpdRootsTableAnnotationComposer get rootKey {
    final $$DpdRootsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rootKey,
      referencedTable: $db.dpdRoots,
      getReferencedColumn: (t) => t.root,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DpdRootsTableAnnotationComposer(
            $db: $db,
            $table: $db.dpdRoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (DpdHeadword, $$DpdHeadwordsTableReferences),
          DpdHeadword,
          PrefetchHooks Function({bool rootKey})
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
                Value<String?> rootKey = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootBase = const Value.absent(),
                Value<String?> familyRoot = const Value.absent(),
                Value<String?> familyWord = const Value.absent(),
                Value<String?> familyCompound = const Value.absent(),
                Value<String?> familyIdioms = const Value.absent(),
                Value<String?> familySet = const Value.absent(),
                Value<String?> construction = const Value.absent(),
                Value<String?> compoundType = const Value.absent(),
                Value<String?> compoundConstruction = const Value.absent(),
                Value<String?> source1 = const Value.absent(),
                Value<String?> sutta1 = const Value.absent(),
                Value<String?> example1 = const Value.absent(),
                Value<String?> source2 = const Value.absent(),
                Value<String?> sutta2 = const Value.absent(),
                Value<String?> example2 = const Value.absent(),
                Value<String?> antonym = const Value.absent(),
                Value<String?> synonym = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> stem = const Value.absent(),
                Value<String?> pattern = const Value.absent(),
                Value<String?> derivative = const Value.absent(),
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
                rootKey: rootKey,
                rootSign: rootSign,
                rootBase: rootBase,
                familyRoot: familyRoot,
                familyWord: familyWord,
                familyCompound: familyCompound,
                familyIdioms: familyIdioms,
                familySet: familySet,
                construction: construction,
                compoundType: compoundType,
                compoundConstruction: compoundConstruction,
                source1: source1,
                sutta1: sutta1,
                example1: example1,
                source2: source2,
                sutta2: sutta2,
                example2: example2,
                antonym: antonym,
                synonym: synonym,
                variant: variant,
                stem: stem,
                pattern: pattern,
                derivative: derivative,
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
                Value<String?> rootKey = const Value.absent(),
                Value<String?> rootSign = const Value.absent(),
                Value<String?> rootBase = const Value.absent(),
                Value<String?> familyRoot = const Value.absent(),
                Value<String?> familyWord = const Value.absent(),
                Value<String?> familyCompound = const Value.absent(),
                Value<String?> familyIdioms = const Value.absent(),
                Value<String?> familySet = const Value.absent(),
                Value<String?> construction = const Value.absent(),
                Value<String?> compoundType = const Value.absent(),
                Value<String?> compoundConstruction = const Value.absent(),
                Value<String?> source1 = const Value.absent(),
                Value<String?> sutta1 = const Value.absent(),
                Value<String?> example1 = const Value.absent(),
                Value<String?> source2 = const Value.absent(),
                Value<String?> sutta2 = const Value.absent(),
                Value<String?> example2 = const Value.absent(),
                Value<String?> antonym = const Value.absent(),
                Value<String?> synonym = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<String?> stem = const Value.absent(),
                Value<String?> pattern = const Value.absent(),
                Value<String?> derivative = const Value.absent(),
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
                rootKey: rootKey,
                rootSign: rootSign,
                rootBase: rootBase,
                familyRoot: familyRoot,
                familyWord: familyWord,
                familyCompound: familyCompound,
                familyIdioms: familyIdioms,
                familySet: familySet,
                construction: construction,
                compoundType: compoundType,
                compoundConstruction: compoundConstruction,
                source1: source1,
                sutta1: sutta1,
                example1: example1,
                source2: source2,
                sutta2: sutta2,
                example2: example2,
                antonym: antonym,
                synonym: synonym,
                variant: variant,
                stem: stem,
                pattern: pattern,
                derivative: derivative,
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
              .map(
                (e) => (
                  e.readTable(table),
                  $$DpdHeadwordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rootKey = false}) {
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
                    if (rootKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.rootKey,
                                referencedTable: $$DpdHeadwordsTableReferences
                                    ._rootKeyTable(db),
                                referencedColumn: $$DpdHeadwordsTableReferences
                                    ._rootKeyTable(db)
                                    .root,
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
      (DpdHeadword, $$DpdHeadwordsTableReferences),
      DpdHeadword,
      PrefetchHooks Function({bool rootKey})
    >;
typedef $$LookupTableCreateCompanionBuilder =
    LookupCompanion Function({
      required String lookupKey,
      Value<String?> headwords,
      Value<String?> roots,
      Value<String?> variant,
      Value<String?> see,
      Value<String?> spelling,
      Value<String?> grammar,
      Value<String?> help,
      Value<String?> abbrev,
      Value<String?> abbrevOther,
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
      Value<String?> see,
      Value<String?> spelling,
      Value<String?> grammar,
      Value<String?> help,
      Value<String?> abbrev,
      Value<String?> abbrevOther,
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

  ColumnFilters<String> get see => $composableBuilder(
    column: $table.see,
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

  ColumnFilters<String> get abbrevOther => $composableBuilder(
    column: $table.abbrevOther,
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

  ColumnOrderings<String> get see => $composableBuilder(
    column: $table.see,
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

  ColumnOrderings<String> get abbrevOther => $composableBuilder(
    column: $table.abbrevOther,
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

  GeneratedColumn<String> get see =>
      $composableBuilder(column: $table.see, builder: (column) => column);

  GeneratedColumn<String> get spelling =>
      $composableBuilder(column: $table.spelling, builder: (column) => column);

  GeneratedColumn<String> get grammar =>
      $composableBuilder(column: $table.grammar, builder: (column) => column);

  GeneratedColumn<String> get help =>
      $composableBuilder(column: $table.help, builder: (column) => column);

  GeneratedColumn<String> get abbrev =>
      $composableBuilder(column: $table.abbrev, builder: (column) => column);

  GeneratedColumn<String> get abbrevOther => $composableBuilder(
    column: $table.abbrevOther,
    builder: (column) => column,
  );

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
                Value<String?> see = const Value.absent(),
                Value<String?> spelling = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> help = const Value.absent(),
                Value<String?> abbrev = const Value.absent(),
                Value<String?> abbrevOther = const Value.absent(),
                Value<String?> deconstructor = const Value.absent(),
                Value<String?> epd = const Value.absent(),
                Value<String?> fuzzyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupCompanion(
                lookupKey: lookupKey,
                headwords: headwords,
                roots: roots,
                variant: variant,
                see: see,
                spelling: spelling,
                grammar: grammar,
                help: help,
                abbrev: abbrev,
                abbrevOther: abbrevOther,
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
                Value<String?> see = const Value.absent(),
                Value<String?> spelling = const Value.absent(),
                Value<String?> grammar = const Value.absent(),
                Value<String?> help = const Value.absent(),
                Value<String?> abbrev = const Value.absent(),
                Value<String?> abbrevOther = const Value.absent(),
                Value<String?> deconstructor = const Value.absent(),
                Value<String?> epd = const Value.absent(),
                Value<String?> fuzzyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookupCompanion.insert(
                lookupKey: lookupKey,
                headwords: headwords,
                roots: roots,
                variant: variant,
                see: see,
                spelling: spelling,
                grammar: grammar,
                help: help,
                abbrev: abbrev,
                abbrevOther: abbrevOther,
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
typedef $$DbInfoTableCreateCompanionBuilder =
    DbInfoCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$DbInfoTableUpdateCompanionBuilder =
    DbInfoCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$DbInfoTableFilterComposer
    extends Composer<_$DpdDatabase, $DbInfoTable> {
  $$DbInfoTableFilterComposer({
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

class $$DbInfoTableOrderingComposer
    extends Composer<_$DpdDatabase, $DbInfoTable> {
  $$DbInfoTableOrderingComposer({
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

class $$DbInfoTableAnnotationComposer
    extends Composer<_$DpdDatabase, $DbInfoTable> {
  $$DbInfoTableAnnotationComposer({
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

class $$DbInfoTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $DbInfoTable,
          DbInfoData,
          $$DbInfoTableFilterComposer,
          $$DbInfoTableOrderingComposer,
          $$DbInfoTableAnnotationComposer,
          $$DbInfoTableCreateCompanionBuilder,
          $$DbInfoTableUpdateCompanionBuilder,
          (DbInfoData, BaseReferences<_$DpdDatabase, $DbInfoTable, DbInfoData>),
          DbInfoData,
          PrefetchHooks Function()
        > {
  $$DbInfoTableTableManager(_$DpdDatabase db, $DbInfoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbInfoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbInfoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbInfoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbInfoCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  DbInfoCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbInfoTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $DbInfoTable,
      DbInfoData,
      $$DbInfoTableFilterComposer,
      $$DbInfoTableOrderingComposer,
      $$DbInfoTableAnnotationComposer,
      $$DbInfoTableCreateCompanionBuilder,
      $$DbInfoTableUpdateCompanionBuilder,
      (DbInfoData, BaseReferences<_$DpdDatabase, $DbInfoTable, DbInfoData>),
      DbInfoData,
      PrefetchHooks Function()
    >;
typedef $$InflectionTemplatesTableCreateCompanionBuilder =
    InflectionTemplatesCompanion Function({
      required String pattern,
      Value<String?> templateLike,
      required String data,
      Value<int> rowid,
    });
typedef $$InflectionTemplatesTableUpdateCompanionBuilder =
    InflectionTemplatesCompanion Function({
      Value<String> pattern,
      Value<String?> templateLike,
      Value<String> data,
      Value<int> rowid,
    });

class $$InflectionTemplatesTableFilterComposer
    extends Composer<_$DpdDatabase, $InflectionTemplatesTable> {
  $$InflectionTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateLike => $composableBuilder(
    column: $table.templateLike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InflectionTemplatesTableOrderingComposer
    extends Composer<_$DpdDatabase, $InflectionTemplatesTable> {
  $$InflectionTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateLike => $composableBuilder(
    column: $table.templateLike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InflectionTemplatesTableAnnotationComposer
    extends Composer<_$DpdDatabase, $InflectionTemplatesTable> {
  $$InflectionTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get templateLike => $composableBuilder(
    column: $table.templateLike,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$InflectionTemplatesTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $InflectionTemplatesTable,
          InflectionTemplate,
          $$InflectionTemplatesTableFilterComposer,
          $$InflectionTemplatesTableOrderingComposer,
          $$InflectionTemplatesTableAnnotationComposer,
          $$InflectionTemplatesTableCreateCompanionBuilder,
          $$InflectionTemplatesTableUpdateCompanionBuilder,
          (
            InflectionTemplate,
            BaseReferences<
              _$DpdDatabase,
              $InflectionTemplatesTable,
              InflectionTemplate
            >,
          ),
          InflectionTemplate,
          PrefetchHooks Function()
        > {
  $$InflectionTemplatesTableTableManager(
    _$DpdDatabase db,
    $InflectionTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InflectionTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InflectionTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InflectionTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pattern = const Value.absent(),
                Value<String?> templateLike = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InflectionTemplatesCompanion(
                pattern: pattern,
                templateLike: templateLike,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pattern,
                Value<String?> templateLike = const Value.absent(),
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => InflectionTemplatesCompanion.insert(
                pattern: pattern,
                templateLike: templateLike,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InflectionTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $InflectionTemplatesTable,
      InflectionTemplate,
      $$InflectionTemplatesTableFilterComposer,
      $$InflectionTemplatesTableOrderingComposer,
      $$InflectionTemplatesTableAnnotationComposer,
      $$InflectionTemplatesTableCreateCompanionBuilder,
      $$InflectionTemplatesTableUpdateCompanionBuilder,
      (
        InflectionTemplate,
        BaseReferences<
          _$DpdDatabase,
          $InflectionTemplatesTable,
          InflectionTemplate
        >,
      ),
      InflectionTemplate,
      PrefetchHooks Function()
    >;
typedef $$FamilyRootTableCreateCompanionBuilder =
    FamilyRootCompanion Function({
      required String rootFamilyKey,
      required String rootKey,
      required String rootFamily,
      required String rootMeaning,
      required String html,
      required String data,
      required int count,
      Value<int> rowid,
    });
typedef $$FamilyRootTableUpdateCompanionBuilder =
    FamilyRootCompanion Function({
      Value<String> rootFamilyKey,
      Value<String> rootKey,
      Value<String> rootFamily,
      Value<String> rootMeaning,
      Value<String> html,
      Value<String> data,
      Value<int> count,
      Value<int> rowid,
    });

class $$FamilyRootTableFilterComposer
    extends Composer<_$DpdDatabase, $FamilyRootTable> {
  $$FamilyRootTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rootFamilyKey => $composableBuilder(
    column: $table.rootFamilyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootKey => $composableBuilder(
    column: $table.rootKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootFamily => $composableBuilder(
    column: $table.rootFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyRootTableOrderingComposer
    extends Composer<_$DpdDatabase, $FamilyRootTable> {
  $$FamilyRootTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rootFamilyKey => $composableBuilder(
    column: $table.rootFamilyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootKey => $composableBuilder(
    column: $table.rootKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootFamily => $composableBuilder(
    column: $table.rootFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get html => $composableBuilder(
    column: $table.html,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyRootTableAnnotationComposer
    extends Composer<_$DpdDatabase, $FamilyRootTable> {
  $$FamilyRootTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rootFamilyKey => $composableBuilder(
    column: $table.rootFamilyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootKey =>
      $composableBuilder(column: $table.rootKey, builder: (column) => column);

  GeneratedColumn<String> get rootFamily => $composableBuilder(
    column: $table.rootFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootMeaning => $composableBuilder(
    column: $table.rootMeaning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get html =>
      $composableBuilder(column: $table.html, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$FamilyRootTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $FamilyRootTable,
          FamilyRootData,
          $$FamilyRootTableFilterComposer,
          $$FamilyRootTableOrderingComposer,
          $$FamilyRootTableAnnotationComposer,
          $$FamilyRootTableCreateCompanionBuilder,
          $$FamilyRootTableUpdateCompanionBuilder,
          (
            FamilyRootData,
            BaseReferences<_$DpdDatabase, $FamilyRootTable, FamilyRootData>,
          ),
          FamilyRootData,
          PrefetchHooks Function()
        > {
  $$FamilyRootTableTableManager(_$DpdDatabase db, $FamilyRootTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyRootTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyRootTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyRootTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rootFamilyKey = const Value.absent(),
                Value<String> rootKey = const Value.absent(),
                Value<String> rootFamily = const Value.absent(),
                Value<String> rootMeaning = const Value.absent(),
                Value<String> html = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyRootCompanion(
                rootFamilyKey: rootFamilyKey,
                rootKey: rootKey,
                rootFamily: rootFamily,
                rootMeaning: rootMeaning,
                html: html,
                data: data,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rootFamilyKey,
                required String rootKey,
                required String rootFamily,
                required String rootMeaning,
                required String html,
                required String data,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => FamilyRootCompanion.insert(
                rootFamilyKey: rootFamilyKey,
                rootKey: rootKey,
                rootFamily: rootFamily,
                rootMeaning: rootMeaning,
                html: html,
                data: data,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyRootTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $FamilyRootTable,
      FamilyRootData,
      $$FamilyRootTableFilterComposer,
      $$FamilyRootTableOrderingComposer,
      $$FamilyRootTableAnnotationComposer,
      $$FamilyRootTableCreateCompanionBuilder,
      $$FamilyRootTableUpdateCompanionBuilder,
      (
        FamilyRootData,
        BaseReferences<_$DpdDatabase, $FamilyRootTable, FamilyRootData>,
      ),
      FamilyRootData,
      PrefetchHooks Function()
    >;
typedef $$FamilyWordTableCreateCompanionBuilder =
    FamilyWordCompanion Function({
      required String wordFamily,
      required String data,
      required int count,
      Value<int> rowid,
    });
typedef $$FamilyWordTableUpdateCompanionBuilder =
    FamilyWordCompanion Function({
      Value<String> wordFamily,
      Value<String> data,
      Value<int> count,
      Value<int> rowid,
    });

class $$FamilyWordTableFilterComposer
    extends Composer<_$DpdDatabase, $FamilyWordTable> {
  $$FamilyWordTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordFamily => $composableBuilder(
    column: $table.wordFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyWordTableOrderingComposer
    extends Composer<_$DpdDatabase, $FamilyWordTable> {
  $$FamilyWordTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordFamily => $composableBuilder(
    column: $table.wordFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyWordTableAnnotationComposer
    extends Composer<_$DpdDatabase, $FamilyWordTable> {
  $$FamilyWordTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordFamily => $composableBuilder(
    column: $table.wordFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$FamilyWordTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $FamilyWordTable,
          FamilyWordData,
          $$FamilyWordTableFilterComposer,
          $$FamilyWordTableOrderingComposer,
          $$FamilyWordTableAnnotationComposer,
          $$FamilyWordTableCreateCompanionBuilder,
          $$FamilyWordTableUpdateCompanionBuilder,
          (
            FamilyWordData,
            BaseReferences<_$DpdDatabase, $FamilyWordTable, FamilyWordData>,
          ),
          FamilyWordData,
          PrefetchHooks Function()
        > {
  $$FamilyWordTableTableManager(_$DpdDatabase db, $FamilyWordTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyWordTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyWordTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyWordTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordFamily = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyWordCompanion(
                wordFamily: wordFamily,
                data: data,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordFamily,
                required String data,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => FamilyWordCompanion.insert(
                wordFamily: wordFamily,
                data: data,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyWordTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $FamilyWordTable,
      FamilyWordData,
      $$FamilyWordTableFilterComposer,
      $$FamilyWordTableOrderingComposer,
      $$FamilyWordTableAnnotationComposer,
      $$FamilyWordTableCreateCompanionBuilder,
      $$FamilyWordTableUpdateCompanionBuilder,
      (
        FamilyWordData,
        BaseReferences<_$DpdDatabase, $FamilyWordTable, FamilyWordData>,
      ),
      FamilyWordData,
      PrefetchHooks Function()
    >;
typedef $$FamilyCompoundTableCreateCompanionBuilder =
    FamilyCompoundCompanion Function({
      required String compoundFamily,
      required String data,
      required int count,
      Value<int> rowid,
    });
typedef $$FamilyCompoundTableUpdateCompanionBuilder =
    FamilyCompoundCompanion Function({
      Value<String> compoundFamily,
      Value<String> data,
      Value<int> count,
      Value<int> rowid,
    });

class $$FamilyCompoundTableFilterComposer
    extends Composer<_$DpdDatabase, $FamilyCompoundTable> {
  $$FamilyCompoundTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get compoundFamily => $composableBuilder(
    column: $table.compoundFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyCompoundTableOrderingComposer
    extends Composer<_$DpdDatabase, $FamilyCompoundTable> {
  $$FamilyCompoundTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get compoundFamily => $composableBuilder(
    column: $table.compoundFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyCompoundTableAnnotationComposer
    extends Composer<_$DpdDatabase, $FamilyCompoundTable> {
  $$FamilyCompoundTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get compoundFamily => $composableBuilder(
    column: $table.compoundFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$FamilyCompoundTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $FamilyCompoundTable,
          FamilyCompoundData,
          $$FamilyCompoundTableFilterComposer,
          $$FamilyCompoundTableOrderingComposer,
          $$FamilyCompoundTableAnnotationComposer,
          $$FamilyCompoundTableCreateCompanionBuilder,
          $$FamilyCompoundTableUpdateCompanionBuilder,
          (
            FamilyCompoundData,
            BaseReferences<
              _$DpdDatabase,
              $FamilyCompoundTable,
              FamilyCompoundData
            >,
          ),
          FamilyCompoundData,
          PrefetchHooks Function()
        > {
  $$FamilyCompoundTableTableManager(
    _$DpdDatabase db,
    $FamilyCompoundTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyCompoundTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyCompoundTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyCompoundTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> compoundFamily = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyCompoundCompanion(
                compoundFamily: compoundFamily,
                data: data,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String compoundFamily,
                required String data,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => FamilyCompoundCompanion.insert(
                compoundFamily: compoundFamily,
                data: data,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyCompoundTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $FamilyCompoundTable,
      FamilyCompoundData,
      $$FamilyCompoundTableFilterComposer,
      $$FamilyCompoundTableOrderingComposer,
      $$FamilyCompoundTableAnnotationComposer,
      $$FamilyCompoundTableCreateCompanionBuilder,
      $$FamilyCompoundTableUpdateCompanionBuilder,
      (
        FamilyCompoundData,
        BaseReferences<_$DpdDatabase, $FamilyCompoundTable, FamilyCompoundData>,
      ),
      FamilyCompoundData,
      PrefetchHooks Function()
    >;
typedef $$FamilyIdiomTableCreateCompanionBuilder =
    FamilyIdiomCompanion Function({
      required String idiom,
      required String data,
      required int count,
      Value<int> rowid,
    });
typedef $$FamilyIdiomTableUpdateCompanionBuilder =
    FamilyIdiomCompanion Function({
      Value<String> idiom,
      Value<String> data,
      Value<int> count,
      Value<int> rowid,
    });

class $$FamilyIdiomTableFilterComposer
    extends Composer<_$DpdDatabase, $FamilyIdiomTable> {
  $$FamilyIdiomTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get idiom => $composableBuilder(
    column: $table.idiom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyIdiomTableOrderingComposer
    extends Composer<_$DpdDatabase, $FamilyIdiomTable> {
  $$FamilyIdiomTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get idiom => $composableBuilder(
    column: $table.idiom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyIdiomTableAnnotationComposer
    extends Composer<_$DpdDatabase, $FamilyIdiomTable> {
  $$FamilyIdiomTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get idiom =>
      $composableBuilder(column: $table.idiom, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$FamilyIdiomTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $FamilyIdiomTable,
          FamilyIdiomData,
          $$FamilyIdiomTableFilterComposer,
          $$FamilyIdiomTableOrderingComposer,
          $$FamilyIdiomTableAnnotationComposer,
          $$FamilyIdiomTableCreateCompanionBuilder,
          $$FamilyIdiomTableUpdateCompanionBuilder,
          (
            FamilyIdiomData,
            BaseReferences<_$DpdDatabase, $FamilyIdiomTable, FamilyIdiomData>,
          ),
          FamilyIdiomData,
          PrefetchHooks Function()
        > {
  $$FamilyIdiomTableTableManager(_$DpdDatabase db, $FamilyIdiomTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyIdiomTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyIdiomTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyIdiomTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> idiom = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyIdiomCompanion(
                idiom: idiom,
                data: data,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String idiom,
                required String data,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => FamilyIdiomCompanion.insert(
                idiom: idiom,
                data: data,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyIdiomTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $FamilyIdiomTable,
      FamilyIdiomData,
      $$FamilyIdiomTableFilterComposer,
      $$FamilyIdiomTableOrderingComposer,
      $$FamilyIdiomTableAnnotationComposer,
      $$FamilyIdiomTableCreateCompanionBuilder,
      $$FamilyIdiomTableUpdateCompanionBuilder,
      (
        FamilyIdiomData,
        BaseReferences<_$DpdDatabase, $FamilyIdiomTable, FamilyIdiomData>,
      ),
      FamilyIdiomData,
      PrefetchHooks Function()
    >;
typedef $$FamilySetTableCreateCompanionBuilder =
    FamilySetCompanion Function({
      required String set_,
      required String data,
      required int count,
      Value<int> rowid,
    });
typedef $$FamilySetTableUpdateCompanionBuilder =
    FamilySetCompanion Function({
      Value<String> set_,
      Value<String> data,
      Value<int> count,
      Value<int> rowid,
    });

class $$FamilySetTableFilterComposer
    extends Composer<_$DpdDatabase, $FamilySetTable> {
  $$FamilySetTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get set_ => $composableBuilder(
    column: $table.set_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilySetTableOrderingComposer
    extends Composer<_$DpdDatabase, $FamilySetTable> {
  $$FamilySetTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get set_ => $composableBuilder(
    column: $table.set_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilySetTableAnnotationComposer
    extends Composer<_$DpdDatabase, $FamilySetTable> {
  $$FamilySetTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get set_ =>
      $composableBuilder(column: $table.set_, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$FamilySetTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $FamilySetTable,
          FamilySetData,
          $$FamilySetTableFilterComposer,
          $$FamilySetTableOrderingComposer,
          $$FamilySetTableAnnotationComposer,
          $$FamilySetTableCreateCompanionBuilder,
          $$FamilySetTableUpdateCompanionBuilder,
          (
            FamilySetData,
            BaseReferences<_$DpdDatabase, $FamilySetTable, FamilySetData>,
          ),
          FamilySetData,
          PrefetchHooks Function()
        > {
  $$FamilySetTableTableManager(_$DpdDatabase db, $FamilySetTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilySetTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilySetTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilySetTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> set_ = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilySetCompanion(
                set_: set_,
                data: data,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String set_,
                required String data,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => FamilySetCompanion.insert(
                set_: set_,
                data: data,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilySetTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $FamilySetTable,
      FamilySetData,
      $$FamilySetTableFilterComposer,
      $$FamilySetTableOrderingComposer,
      $$FamilySetTableAnnotationComposer,
      $$FamilySetTableCreateCompanionBuilder,
      $$FamilySetTableUpdateCompanionBuilder,
      (
        FamilySetData,
        BaseReferences<_$DpdDatabase, $FamilySetTable, FamilySetData>,
      ),
      FamilySetData,
      PrefetchHooks Function()
    >;
typedef $$SuttaInfoTableCreateCompanionBuilder =
    SuttaInfoCompanion Function({
      Value<String?> book,
      Value<String?> bookCode,
      Value<String?> dpdCode,
      required String dpdSutta,
      Value<String?> dpdSuttaVar,
      Value<String?> cstCode,
      Value<String?> cstNikaya,
      Value<String?> cstBook,
      Value<String?> cstSection,
      Value<String?> cstVagga,
      Value<String?> cstSutta,
      Value<String?> cstParanum,
      Value<String?> cstMPage,
      Value<String?> cstVPage,
      Value<String?> cstPPage,
      Value<String?> cstTPage,
      Value<String?> cstFile,
      Value<String?> scCode,
      Value<String?> scBook,
      Value<String?> scVagga,
      Value<String?> scSutta,
      Value<String?> scEngSutta,
      Value<String?> scBlurb,
      Value<String?> scFilePath,
      Value<String?> dprCode,
      Value<String?> dprLink,
      Value<String?> bjtSuttaCode,
      Value<String?> bjtWebCode,
      Value<String?> bjtFilename,
      Value<String?> bjtBookId,
      Value<String?> bjtPageNum,
      Value<String?> bjtPageOffset,
      Value<String?> bjtPitaka,
      Value<String?> bjtNikaya,
      Value<String?> bjtMajorSection,
      Value<String?> bjtBook,
      Value<String?> bjtMinorSection,
      Value<String?> bjtVagga,
      Value<String?> bjtSutta,
      Value<String?> dvPts,
      Value<String?> dvMainTheme,
      Value<String?> dvSubtopic,
      Value<String?> dvSummary,
      Value<String?> dvSimiles,
      Value<String?> dvKeyExcerpt1,
      Value<String?> dvKeyExcerpt2,
      Value<String?> dvStage,
      Value<String?> dvTraining,
      Value<String?> dvAspect,
      Value<String?> dvTeacher,
      Value<String?> dvAudience,
      Value<String?> dvMethod,
      Value<String?> dvLength,
      Value<String?> dvProminence,
      Value<String?> dvNikayasParallels,
      Value<String?> dvAgamasParallels,
      Value<String?> dvTaishoParallels,
      Value<String?> dvSanskritParallels,
      Value<String?> dvVinayaParallels,
      Value<String?> dvOthersParallels,
      Value<String?> dvPartialParallelsNa,
      Value<String?> dvPartialParallelsAll,
      Value<String?> dvSuggestedSuttas,
      Value<int> rowid,
    });
typedef $$SuttaInfoTableUpdateCompanionBuilder =
    SuttaInfoCompanion Function({
      Value<String?> book,
      Value<String?> bookCode,
      Value<String?> dpdCode,
      Value<String> dpdSutta,
      Value<String?> dpdSuttaVar,
      Value<String?> cstCode,
      Value<String?> cstNikaya,
      Value<String?> cstBook,
      Value<String?> cstSection,
      Value<String?> cstVagga,
      Value<String?> cstSutta,
      Value<String?> cstParanum,
      Value<String?> cstMPage,
      Value<String?> cstVPage,
      Value<String?> cstPPage,
      Value<String?> cstTPage,
      Value<String?> cstFile,
      Value<String?> scCode,
      Value<String?> scBook,
      Value<String?> scVagga,
      Value<String?> scSutta,
      Value<String?> scEngSutta,
      Value<String?> scBlurb,
      Value<String?> scFilePath,
      Value<String?> dprCode,
      Value<String?> dprLink,
      Value<String?> bjtSuttaCode,
      Value<String?> bjtWebCode,
      Value<String?> bjtFilename,
      Value<String?> bjtBookId,
      Value<String?> bjtPageNum,
      Value<String?> bjtPageOffset,
      Value<String?> bjtPitaka,
      Value<String?> bjtNikaya,
      Value<String?> bjtMajorSection,
      Value<String?> bjtBook,
      Value<String?> bjtMinorSection,
      Value<String?> bjtVagga,
      Value<String?> bjtSutta,
      Value<String?> dvPts,
      Value<String?> dvMainTheme,
      Value<String?> dvSubtopic,
      Value<String?> dvSummary,
      Value<String?> dvSimiles,
      Value<String?> dvKeyExcerpt1,
      Value<String?> dvKeyExcerpt2,
      Value<String?> dvStage,
      Value<String?> dvTraining,
      Value<String?> dvAspect,
      Value<String?> dvTeacher,
      Value<String?> dvAudience,
      Value<String?> dvMethod,
      Value<String?> dvLength,
      Value<String?> dvProminence,
      Value<String?> dvNikayasParallels,
      Value<String?> dvAgamasParallels,
      Value<String?> dvTaishoParallels,
      Value<String?> dvSanskritParallels,
      Value<String?> dvVinayaParallels,
      Value<String?> dvOthersParallels,
      Value<String?> dvPartialParallelsNa,
      Value<String?> dvPartialParallelsAll,
      Value<String?> dvSuggestedSuttas,
      Value<int> rowid,
    });

class $$SuttaInfoTableFilterComposer
    extends Composer<_$DpdDatabase, $SuttaInfoTable> {
  $$SuttaInfoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get book => $composableBuilder(
    column: $table.book,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookCode => $composableBuilder(
    column: $table.bookCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dpdCode => $composableBuilder(
    column: $table.dpdCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dpdSutta => $composableBuilder(
    column: $table.dpdSutta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dpdSuttaVar => $composableBuilder(
    column: $table.dpdSuttaVar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstCode => $composableBuilder(
    column: $table.cstCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstNikaya => $composableBuilder(
    column: $table.cstNikaya,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstBook => $composableBuilder(
    column: $table.cstBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstSection => $composableBuilder(
    column: $table.cstSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstVagga => $composableBuilder(
    column: $table.cstVagga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstSutta => $composableBuilder(
    column: $table.cstSutta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstParanum => $composableBuilder(
    column: $table.cstParanum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstMPage => $composableBuilder(
    column: $table.cstMPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstVPage => $composableBuilder(
    column: $table.cstVPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstPPage => $composableBuilder(
    column: $table.cstPPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstTPage => $composableBuilder(
    column: $table.cstTPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cstFile => $composableBuilder(
    column: $table.cstFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scCode => $composableBuilder(
    column: $table.scCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scBook => $composableBuilder(
    column: $table.scBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scVagga => $composableBuilder(
    column: $table.scVagga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scSutta => $composableBuilder(
    column: $table.scSutta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scEngSutta => $composableBuilder(
    column: $table.scEngSutta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scBlurb => $composableBuilder(
    column: $table.scBlurb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scFilePath => $composableBuilder(
    column: $table.scFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dprCode => $composableBuilder(
    column: $table.dprCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dprLink => $composableBuilder(
    column: $table.dprLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtSuttaCode => $composableBuilder(
    column: $table.bjtSuttaCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtWebCode => $composableBuilder(
    column: $table.bjtWebCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtFilename => $composableBuilder(
    column: $table.bjtFilename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtBookId => $composableBuilder(
    column: $table.bjtBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtPageNum => $composableBuilder(
    column: $table.bjtPageNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtPageOffset => $composableBuilder(
    column: $table.bjtPageOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtPitaka => $composableBuilder(
    column: $table.bjtPitaka,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtNikaya => $composableBuilder(
    column: $table.bjtNikaya,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtMajorSection => $composableBuilder(
    column: $table.bjtMajorSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtBook => $composableBuilder(
    column: $table.bjtBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtMinorSection => $composableBuilder(
    column: $table.bjtMinorSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtVagga => $composableBuilder(
    column: $table.bjtVagga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bjtSutta => $composableBuilder(
    column: $table.bjtSutta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvPts => $composableBuilder(
    column: $table.dvPts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvMainTheme => $composableBuilder(
    column: $table.dvMainTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvSubtopic => $composableBuilder(
    column: $table.dvSubtopic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvSummary => $composableBuilder(
    column: $table.dvSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvSimiles => $composableBuilder(
    column: $table.dvSimiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvKeyExcerpt1 => $composableBuilder(
    column: $table.dvKeyExcerpt1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvKeyExcerpt2 => $composableBuilder(
    column: $table.dvKeyExcerpt2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvStage => $composableBuilder(
    column: $table.dvStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvTraining => $composableBuilder(
    column: $table.dvTraining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvAspect => $composableBuilder(
    column: $table.dvAspect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvTeacher => $composableBuilder(
    column: $table.dvTeacher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvAudience => $composableBuilder(
    column: $table.dvAudience,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvMethod => $composableBuilder(
    column: $table.dvMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvLength => $composableBuilder(
    column: $table.dvLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvProminence => $composableBuilder(
    column: $table.dvProminence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvNikayasParallels => $composableBuilder(
    column: $table.dvNikayasParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvAgamasParallels => $composableBuilder(
    column: $table.dvAgamasParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvTaishoParallels => $composableBuilder(
    column: $table.dvTaishoParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvSanskritParallels => $composableBuilder(
    column: $table.dvSanskritParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvVinayaParallels => $composableBuilder(
    column: $table.dvVinayaParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvOthersParallels => $composableBuilder(
    column: $table.dvOthersParallels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvPartialParallelsNa => $composableBuilder(
    column: $table.dvPartialParallelsNa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvPartialParallelsAll => $composableBuilder(
    column: $table.dvPartialParallelsAll,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dvSuggestedSuttas => $composableBuilder(
    column: $table.dvSuggestedSuttas,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SuttaInfoTableOrderingComposer
    extends Composer<_$DpdDatabase, $SuttaInfoTable> {
  $$SuttaInfoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get book => $composableBuilder(
    column: $table.book,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookCode => $composableBuilder(
    column: $table.bookCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dpdCode => $composableBuilder(
    column: $table.dpdCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dpdSutta => $composableBuilder(
    column: $table.dpdSutta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dpdSuttaVar => $composableBuilder(
    column: $table.dpdSuttaVar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstCode => $composableBuilder(
    column: $table.cstCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstNikaya => $composableBuilder(
    column: $table.cstNikaya,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstBook => $composableBuilder(
    column: $table.cstBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstSection => $composableBuilder(
    column: $table.cstSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstVagga => $composableBuilder(
    column: $table.cstVagga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstSutta => $composableBuilder(
    column: $table.cstSutta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstParanum => $composableBuilder(
    column: $table.cstParanum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstMPage => $composableBuilder(
    column: $table.cstMPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstVPage => $composableBuilder(
    column: $table.cstVPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstPPage => $composableBuilder(
    column: $table.cstPPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstTPage => $composableBuilder(
    column: $table.cstTPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cstFile => $composableBuilder(
    column: $table.cstFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scCode => $composableBuilder(
    column: $table.scCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scBook => $composableBuilder(
    column: $table.scBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scVagga => $composableBuilder(
    column: $table.scVagga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scSutta => $composableBuilder(
    column: $table.scSutta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scEngSutta => $composableBuilder(
    column: $table.scEngSutta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scBlurb => $composableBuilder(
    column: $table.scBlurb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scFilePath => $composableBuilder(
    column: $table.scFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dprCode => $composableBuilder(
    column: $table.dprCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dprLink => $composableBuilder(
    column: $table.dprLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtSuttaCode => $composableBuilder(
    column: $table.bjtSuttaCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtWebCode => $composableBuilder(
    column: $table.bjtWebCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtFilename => $composableBuilder(
    column: $table.bjtFilename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtBookId => $composableBuilder(
    column: $table.bjtBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtPageNum => $composableBuilder(
    column: $table.bjtPageNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtPageOffset => $composableBuilder(
    column: $table.bjtPageOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtPitaka => $composableBuilder(
    column: $table.bjtPitaka,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtNikaya => $composableBuilder(
    column: $table.bjtNikaya,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtMajorSection => $composableBuilder(
    column: $table.bjtMajorSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtBook => $composableBuilder(
    column: $table.bjtBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtMinorSection => $composableBuilder(
    column: $table.bjtMinorSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtVagga => $composableBuilder(
    column: $table.bjtVagga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bjtSutta => $composableBuilder(
    column: $table.bjtSutta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvPts => $composableBuilder(
    column: $table.dvPts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvMainTheme => $composableBuilder(
    column: $table.dvMainTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvSubtopic => $composableBuilder(
    column: $table.dvSubtopic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvSummary => $composableBuilder(
    column: $table.dvSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvSimiles => $composableBuilder(
    column: $table.dvSimiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvKeyExcerpt1 => $composableBuilder(
    column: $table.dvKeyExcerpt1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvKeyExcerpt2 => $composableBuilder(
    column: $table.dvKeyExcerpt2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvStage => $composableBuilder(
    column: $table.dvStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvTraining => $composableBuilder(
    column: $table.dvTraining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvAspect => $composableBuilder(
    column: $table.dvAspect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvTeacher => $composableBuilder(
    column: $table.dvTeacher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvAudience => $composableBuilder(
    column: $table.dvAudience,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvMethod => $composableBuilder(
    column: $table.dvMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvLength => $composableBuilder(
    column: $table.dvLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvProminence => $composableBuilder(
    column: $table.dvProminence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvNikayasParallels => $composableBuilder(
    column: $table.dvNikayasParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvAgamasParallels => $composableBuilder(
    column: $table.dvAgamasParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvTaishoParallels => $composableBuilder(
    column: $table.dvTaishoParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvSanskritParallels => $composableBuilder(
    column: $table.dvSanskritParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvVinayaParallels => $composableBuilder(
    column: $table.dvVinayaParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvOthersParallels => $composableBuilder(
    column: $table.dvOthersParallels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvPartialParallelsNa => $composableBuilder(
    column: $table.dvPartialParallelsNa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvPartialParallelsAll => $composableBuilder(
    column: $table.dvPartialParallelsAll,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dvSuggestedSuttas => $composableBuilder(
    column: $table.dvSuggestedSuttas,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SuttaInfoTableAnnotationComposer
    extends Composer<_$DpdDatabase, $SuttaInfoTable> {
  $$SuttaInfoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get book =>
      $composableBuilder(column: $table.book, builder: (column) => column);

  GeneratedColumn<String> get bookCode =>
      $composableBuilder(column: $table.bookCode, builder: (column) => column);

  GeneratedColumn<String> get dpdCode =>
      $composableBuilder(column: $table.dpdCode, builder: (column) => column);

  GeneratedColumn<String> get dpdSutta =>
      $composableBuilder(column: $table.dpdSutta, builder: (column) => column);

  GeneratedColumn<String> get dpdSuttaVar => $composableBuilder(
    column: $table.dpdSuttaVar,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cstCode =>
      $composableBuilder(column: $table.cstCode, builder: (column) => column);

  GeneratedColumn<String> get cstNikaya =>
      $composableBuilder(column: $table.cstNikaya, builder: (column) => column);

  GeneratedColumn<String> get cstBook =>
      $composableBuilder(column: $table.cstBook, builder: (column) => column);

  GeneratedColumn<String> get cstSection => $composableBuilder(
    column: $table.cstSection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cstVagga =>
      $composableBuilder(column: $table.cstVagga, builder: (column) => column);

  GeneratedColumn<String> get cstSutta =>
      $composableBuilder(column: $table.cstSutta, builder: (column) => column);

  GeneratedColumn<String> get cstParanum => $composableBuilder(
    column: $table.cstParanum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cstMPage =>
      $composableBuilder(column: $table.cstMPage, builder: (column) => column);

  GeneratedColumn<String> get cstVPage =>
      $composableBuilder(column: $table.cstVPage, builder: (column) => column);

  GeneratedColumn<String> get cstPPage =>
      $composableBuilder(column: $table.cstPPage, builder: (column) => column);

  GeneratedColumn<String> get cstTPage =>
      $composableBuilder(column: $table.cstTPage, builder: (column) => column);

  GeneratedColumn<String> get cstFile =>
      $composableBuilder(column: $table.cstFile, builder: (column) => column);

  GeneratedColumn<String> get scCode =>
      $composableBuilder(column: $table.scCode, builder: (column) => column);

  GeneratedColumn<String> get scBook =>
      $composableBuilder(column: $table.scBook, builder: (column) => column);

  GeneratedColumn<String> get scVagga =>
      $composableBuilder(column: $table.scVagga, builder: (column) => column);

  GeneratedColumn<String> get scSutta =>
      $composableBuilder(column: $table.scSutta, builder: (column) => column);

  GeneratedColumn<String> get scEngSutta => $composableBuilder(
    column: $table.scEngSutta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scBlurb =>
      $composableBuilder(column: $table.scBlurb, builder: (column) => column);

  GeneratedColumn<String> get scFilePath => $composableBuilder(
    column: $table.scFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dprCode =>
      $composableBuilder(column: $table.dprCode, builder: (column) => column);

  GeneratedColumn<String> get dprLink =>
      $composableBuilder(column: $table.dprLink, builder: (column) => column);

  GeneratedColumn<String> get bjtSuttaCode => $composableBuilder(
    column: $table.bjtSuttaCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtWebCode => $composableBuilder(
    column: $table.bjtWebCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtFilename => $composableBuilder(
    column: $table.bjtFilename,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtBookId =>
      $composableBuilder(column: $table.bjtBookId, builder: (column) => column);

  GeneratedColumn<String> get bjtPageNum => $composableBuilder(
    column: $table.bjtPageNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtPageOffset => $composableBuilder(
    column: $table.bjtPageOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtPitaka =>
      $composableBuilder(column: $table.bjtPitaka, builder: (column) => column);

  GeneratedColumn<String> get bjtNikaya =>
      $composableBuilder(column: $table.bjtNikaya, builder: (column) => column);

  GeneratedColumn<String> get bjtMajorSection => $composableBuilder(
    column: $table.bjtMajorSection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtBook =>
      $composableBuilder(column: $table.bjtBook, builder: (column) => column);

  GeneratedColumn<String> get bjtMinorSection => $composableBuilder(
    column: $table.bjtMinorSection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bjtVagga =>
      $composableBuilder(column: $table.bjtVagga, builder: (column) => column);

  GeneratedColumn<String> get bjtSutta =>
      $composableBuilder(column: $table.bjtSutta, builder: (column) => column);

  GeneratedColumn<String> get dvPts =>
      $composableBuilder(column: $table.dvPts, builder: (column) => column);

  GeneratedColumn<String> get dvMainTheme => $composableBuilder(
    column: $table.dvMainTheme,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvSubtopic => $composableBuilder(
    column: $table.dvSubtopic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvSummary =>
      $composableBuilder(column: $table.dvSummary, builder: (column) => column);

  GeneratedColumn<String> get dvSimiles =>
      $composableBuilder(column: $table.dvSimiles, builder: (column) => column);

  GeneratedColumn<String> get dvKeyExcerpt1 => $composableBuilder(
    column: $table.dvKeyExcerpt1,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvKeyExcerpt2 => $composableBuilder(
    column: $table.dvKeyExcerpt2,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvStage =>
      $composableBuilder(column: $table.dvStage, builder: (column) => column);

  GeneratedColumn<String> get dvTraining => $composableBuilder(
    column: $table.dvTraining,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvAspect =>
      $composableBuilder(column: $table.dvAspect, builder: (column) => column);

  GeneratedColumn<String> get dvTeacher =>
      $composableBuilder(column: $table.dvTeacher, builder: (column) => column);

  GeneratedColumn<String> get dvAudience => $composableBuilder(
    column: $table.dvAudience,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvMethod =>
      $composableBuilder(column: $table.dvMethod, builder: (column) => column);

  GeneratedColumn<String> get dvLength =>
      $composableBuilder(column: $table.dvLength, builder: (column) => column);

  GeneratedColumn<String> get dvProminence => $composableBuilder(
    column: $table.dvProminence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvNikayasParallels => $composableBuilder(
    column: $table.dvNikayasParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvAgamasParallels => $composableBuilder(
    column: $table.dvAgamasParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvTaishoParallels => $composableBuilder(
    column: $table.dvTaishoParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvSanskritParallels => $composableBuilder(
    column: $table.dvSanskritParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvVinayaParallels => $composableBuilder(
    column: $table.dvVinayaParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvOthersParallels => $composableBuilder(
    column: $table.dvOthersParallels,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvPartialParallelsNa => $composableBuilder(
    column: $table.dvPartialParallelsNa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvPartialParallelsAll => $composableBuilder(
    column: $table.dvPartialParallelsAll,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dvSuggestedSuttas => $composableBuilder(
    column: $table.dvSuggestedSuttas,
    builder: (column) => column,
  );
}

class $$SuttaInfoTableTableManager
    extends
        RootTableManager<
          _$DpdDatabase,
          $SuttaInfoTable,
          SuttaInfoData,
          $$SuttaInfoTableFilterComposer,
          $$SuttaInfoTableOrderingComposer,
          $$SuttaInfoTableAnnotationComposer,
          $$SuttaInfoTableCreateCompanionBuilder,
          $$SuttaInfoTableUpdateCompanionBuilder,
          (
            SuttaInfoData,
            BaseReferences<_$DpdDatabase, $SuttaInfoTable, SuttaInfoData>,
          ),
          SuttaInfoData,
          PrefetchHooks Function()
        > {
  $$SuttaInfoTableTableManager(_$DpdDatabase db, $SuttaInfoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuttaInfoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuttaInfoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuttaInfoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> book = const Value.absent(),
                Value<String?> bookCode = const Value.absent(),
                Value<String?> dpdCode = const Value.absent(),
                Value<String> dpdSutta = const Value.absent(),
                Value<String?> dpdSuttaVar = const Value.absent(),
                Value<String?> cstCode = const Value.absent(),
                Value<String?> cstNikaya = const Value.absent(),
                Value<String?> cstBook = const Value.absent(),
                Value<String?> cstSection = const Value.absent(),
                Value<String?> cstVagga = const Value.absent(),
                Value<String?> cstSutta = const Value.absent(),
                Value<String?> cstParanum = const Value.absent(),
                Value<String?> cstMPage = const Value.absent(),
                Value<String?> cstVPage = const Value.absent(),
                Value<String?> cstPPage = const Value.absent(),
                Value<String?> cstTPage = const Value.absent(),
                Value<String?> cstFile = const Value.absent(),
                Value<String?> scCode = const Value.absent(),
                Value<String?> scBook = const Value.absent(),
                Value<String?> scVagga = const Value.absent(),
                Value<String?> scSutta = const Value.absent(),
                Value<String?> scEngSutta = const Value.absent(),
                Value<String?> scBlurb = const Value.absent(),
                Value<String?> scFilePath = const Value.absent(),
                Value<String?> dprCode = const Value.absent(),
                Value<String?> dprLink = const Value.absent(),
                Value<String?> bjtSuttaCode = const Value.absent(),
                Value<String?> bjtWebCode = const Value.absent(),
                Value<String?> bjtFilename = const Value.absent(),
                Value<String?> bjtBookId = const Value.absent(),
                Value<String?> bjtPageNum = const Value.absent(),
                Value<String?> bjtPageOffset = const Value.absent(),
                Value<String?> bjtPitaka = const Value.absent(),
                Value<String?> bjtNikaya = const Value.absent(),
                Value<String?> bjtMajorSection = const Value.absent(),
                Value<String?> bjtBook = const Value.absent(),
                Value<String?> bjtMinorSection = const Value.absent(),
                Value<String?> bjtVagga = const Value.absent(),
                Value<String?> bjtSutta = const Value.absent(),
                Value<String?> dvPts = const Value.absent(),
                Value<String?> dvMainTheme = const Value.absent(),
                Value<String?> dvSubtopic = const Value.absent(),
                Value<String?> dvSummary = const Value.absent(),
                Value<String?> dvSimiles = const Value.absent(),
                Value<String?> dvKeyExcerpt1 = const Value.absent(),
                Value<String?> dvKeyExcerpt2 = const Value.absent(),
                Value<String?> dvStage = const Value.absent(),
                Value<String?> dvTraining = const Value.absent(),
                Value<String?> dvAspect = const Value.absent(),
                Value<String?> dvTeacher = const Value.absent(),
                Value<String?> dvAudience = const Value.absent(),
                Value<String?> dvMethod = const Value.absent(),
                Value<String?> dvLength = const Value.absent(),
                Value<String?> dvProminence = const Value.absent(),
                Value<String?> dvNikayasParallels = const Value.absent(),
                Value<String?> dvAgamasParallels = const Value.absent(),
                Value<String?> dvTaishoParallels = const Value.absent(),
                Value<String?> dvSanskritParallels = const Value.absent(),
                Value<String?> dvVinayaParallels = const Value.absent(),
                Value<String?> dvOthersParallels = const Value.absent(),
                Value<String?> dvPartialParallelsNa = const Value.absent(),
                Value<String?> dvPartialParallelsAll = const Value.absent(),
                Value<String?> dvSuggestedSuttas = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuttaInfoCompanion(
                book: book,
                bookCode: bookCode,
                dpdCode: dpdCode,
                dpdSutta: dpdSutta,
                dpdSuttaVar: dpdSuttaVar,
                cstCode: cstCode,
                cstNikaya: cstNikaya,
                cstBook: cstBook,
                cstSection: cstSection,
                cstVagga: cstVagga,
                cstSutta: cstSutta,
                cstParanum: cstParanum,
                cstMPage: cstMPage,
                cstVPage: cstVPage,
                cstPPage: cstPPage,
                cstTPage: cstTPage,
                cstFile: cstFile,
                scCode: scCode,
                scBook: scBook,
                scVagga: scVagga,
                scSutta: scSutta,
                scEngSutta: scEngSutta,
                scBlurb: scBlurb,
                scFilePath: scFilePath,
                dprCode: dprCode,
                dprLink: dprLink,
                bjtSuttaCode: bjtSuttaCode,
                bjtWebCode: bjtWebCode,
                bjtFilename: bjtFilename,
                bjtBookId: bjtBookId,
                bjtPageNum: bjtPageNum,
                bjtPageOffset: bjtPageOffset,
                bjtPitaka: bjtPitaka,
                bjtNikaya: bjtNikaya,
                bjtMajorSection: bjtMajorSection,
                bjtBook: bjtBook,
                bjtMinorSection: bjtMinorSection,
                bjtVagga: bjtVagga,
                bjtSutta: bjtSutta,
                dvPts: dvPts,
                dvMainTheme: dvMainTheme,
                dvSubtopic: dvSubtopic,
                dvSummary: dvSummary,
                dvSimiles: dvSimiles,
                dvKeyExcerpt1: dvKeyExcerpt1,
                dvKeyExcerpt2: dvKeyExcerpt2,
                dvStage: dvStage,
                dvTraining: dvTraining,
                dvAspect: dvAspect,
                dvTeacher: dvTeacher,
                dvAudience: dvAudience,
                dvMethod: dvMethod,
                dvLength: dvLength,
                dvProminence: dvProminence,
                dvNikayasParallels: dvNikayasParallels,
                dvAgamasParallels: dvAgamasParallels,
                dvTaishoParallels: dvTaishoParallels,
                dvSanskritParallels: dvSanskritParallels,
                dvVinayaParallels: dvVinayaParallels,
                dvOthersParallels: dvOthersParallels,
                dvPartialParallelsNa: dvPartialParallelsNa,
                dvPartialParallelsAll: dvPartialParallelsAll,
                dvSuggestedSuttas: dvSuggestedSuttas,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> book = const Value.absent(),
                Value<String?> bookCode = const Value.absent(),
                Value<String?> dpdCode = const Value.absent(),
                required String dpdSutta,
                Value<String?> dpdSuttaVar = const Value.absent(),
                Value<String?> cstCode = const Value.absent(),
                Value<String?> cstNikaya = const Value.absent(),
                Value<String?> cstBook = const Value.absent(),
                Value<String?> cstSection = const Value.absent(),
                Value<String?> cstVagga = const Value.absent(),
                Value<String?> cstSutta = const Value.absent(),
                Value<String?> cstParanum = const Value.absent(),
                Value<String?> cstMPage = const Value.absent(),
                Value<String?> cstVPage = const Value.absent(),
                Value<String?> cstPPage = const Value.absent(),
                Value<String?> cstTPage = const Value.absent(),
                Value<String?> cstFile = const Value.absent(),
                Value<String?> scCode = const Value.absent(),
                Value<String?> scBook = const Value.absent(),
                Value<String?> scVagga = const Value.absent(),
                Value<String?> scSutta = const Value.absent(),
                Value<String?> scEngSutta = const Value.absent(),
                Value<String?> scBlurb = const Value.absent(),
                Value<String?> scFilePath = const Value.absent(),
                Value<String?> dprCode = const Value.absent(),
                Value<String?> dprLink = const Value.absent(),
                Value<String?> bjtSuttaCode = const Value.absent(),
                Value<String?> bjtWebCode = const Value.absent(),
                Value<String?> bjtFilename = const Value.absent(),
                Value<String?> bjtBookId = const Value.absent(),
                Value<String?> bjtPageNum = const Value.absent(),
                Value<String?> bjtPageOffset = const Value.absent(),
                Value<String?> bjtPitaka = const Value.absent(),
                Value<String?> bjtNikaya = const Value.absent(),
                Value<String?> bjtMajorSection = const Value.absent(),
                Value<String?> bjtBook = const Value.absent(),
                Value<String?> bjtMinorSection = const Value.absent(),
                Value<String?> bjtVagga = const Value.absent(),
                Value<String?> bjtSutta = const Value.absent(),
                Value<String?> dvPts = const Value.absent(),
                Value<String?> dvMainTheme = const Value.absent(),
                Value<String?> dvSubtopic = const Value.absent(),
                Value<String?> dvSummary = const Value.absent(),
                Value<String?> dvSimiles = const Value.absent(),
                Value<String?> dvKeyExcerpt1 = const Value.absent(),
                Value<String?> dvKeyExcerpt2 = const Value.absent(),
                Value<String?> dvStage = const Value.absent(),
                Value<String?> dvTraining = const Value.absent(),
                Value<String?> dvAspect = const Value.absent(),
                Value<String?> dvTeacher = const Value.absent(),
                Value<String?> dvAudience = const Value.absent(),
                Value<String?> dvMethod = const Value.absent(),
                Value<String?> dvLength = const Value.absent(),
                Value<String?> dvProminence = const Value.absent(),
                Value<String?> dvNikayasParallels = const Value.absent(),
                Value<String?> dvAgamasParallels = const Value.absent(),
                Value<String?> dvTaishoParallels = const Value.absent(),
                Value<String?> dvSanskritParallels = const Value.absent(),
                Value<String?> dvVinayaParallels = const Value.absent(),
                Value<String?> dvOthersParallels = const Value.absent(),
                Value<String?> dvPartialParallelsNa = const Value.absent(),
                Value<String?> dvPartialParallelsAll = const Value.absent(),
                Value<String?> dvSuggestedSuttas = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuttaInfoCompanion.insert(
                book: book,
                bookCode: bookCode,
                dpdCode: dpdCode,
                dpdSutta: dpdSutta,
                dpdSuttaVar: dpdSuttaVar,
                cstCode: cstCode,
                cstNikaya: cstNikaya,
                cstBook: cstBook,
                cstSection: cstSection,
                cstVagga: cstVagga,
                cstSutta: cstSutta,
                cstParanum: cstParanum,
                cstMPage: cstMPage,
                cstVPage: cstVPage,
                cstPPage: cstPPage,
                cstTPage: cstTPage,
                cstFile: cstFile,
                scCode: scCode,
                scBook: scBook,
                scVagga: scVagga,
                scSutta: scSutta,
                scEngSutta: scEngSutta,
                scBlurb: scBlurb,
                scFilePath: scFilePath,
                dprCode: dprCode,
                dprLink: dprLink,
                bjtSuttaCode: bjtSuttaCode,
                bjtWebCode: bjtWebCode,
                bjtFilename: bjtFilename,
                bjtBookId: bjtBookId,
                bjtPageNum: bjtPageNum,
                bjtPageOffset: bjtPageOffset,
                bjtPitaka: bjtPitaka,
                bjtNikaya: bjtNikaya,
                bjtMajorSection: bjtMajorSection,
                bjtBook: bjtBook,
                bjtMinorSection: bjtMinorSection,
                bjtVagga: bjtVagga,
                bjtSutta: bjtSutta,
                dvPts: dvPts,
                dvMainTheme: dvMainTheme,
                dvSubtopic: dvSubtopic,
                dvSummary: dvSummary,
                dvSimiles: dvSimiles,
                dvKeyExcerpt1: dvKeyExcerpt1,
                dvKeyExcerpt2: dvKeyExcerpt2,
                dvStage: dvStage,
                dvTraining: dvTraining,
                dvAspect: dvAspect,
                dvTeacher: dvTeacher,
                dvAudience: dvAudience,
                dvMethod: dvMethod,
                dvLength: dvLength,
                dvProminence: dvProminence,
                dvNikayasParallels: dvNikayasParallels,
                dvAgamasParallels: dvAgamasParallels,
                dvTaishoParallels: dvTaishoParallels,
                dvSanskritParallels: dvSanskritParallels,
                dvVinayaParallels: dvVinayaParallels,
                dvOthersParallels: dvOthersParallels,
                dvPartialParallelsNa: dvPartialParallelsNa,
                dvPartialParallelsAll: dvPartialParallelsAll,
                dvSuggestedSuttas: dvSuggestedSuttas,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SuttaInfoTableProcessedTableManager =
    ProcessedTableManager<
      _$DpdDatabase,
      $SuttaInfoTable,
      SuttaInfoData,
      $$SuttaInfoTableFilterComposer,
      $$SuttaInfoTableOrderingComposer,
      $$SuttaInfoTableAnnotationComposer,
      $$SuttaInfoTableCreateCompanionBuilder,
      $$SuttaInfoTableUpdateCompanionBuilder,
      (
        SuttaInfoData,
        BaseReferences<_$DpdDatabase, $SuttaInfoTable, SuttaInfoData>,
      ),
      SuttaInfoData,
      PrefetchHooks Function()
    >;
typedef $$DictMetaTableCreateCompanionBuilder =
    DictMetaCompanion Function({
      required String dictId,
      required String name,
      Value<String?> author,
      Value<String?> css,
      Value<int?> entryCount,
      Value<int> rowid,
    });
typedef $$DictMetaTableUpdateCompanionBuilder =
    DictMetaCompanion Function({
      Value<String> dictId,
      Value<String> name,
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
                Value<String> name = const Value.absent(),
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
                required String name,
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

class $DpdDatabaseManager {
  final _$DpdDatabase _db;
  $DpdDatabaseManager(this._db);
  $$DpdRootsTableTableManager get dpdRoots =>
      $$DpdRootsTableTableManager(_db, _db.dpdRoots);
  $$DpdHeadwordsTableTableManager get dpdHeadwords =>
      $$DpdHeadwordsTableTableManager(_db, _db.dpdHeadwords);
  $$LookupTableTableManager get lookup =>
      $$LookupTableTableManager(_db, _db.lookup);
  $$DbInfoTableTableManager get dbInfo =>
      $$DbInfoTableTableManager(_db, _db.dbInfo);
  $$InflectionTemplatesTableTableManager get inflectionTemplates =>
      $$InflectionTemplatesTableTableManager(_db, _db.inflectionTemplates);
  $$FamilyRootTableTableManager get familyRoot =>
      $$FamilyRootTableTableManager(_db, _db.familyRoot);
  $$FamilyWordTableTableManager get familyWord =>
      $$FamilyWordTableTableManager(_db, _db.familyWord);
  $$FamilyCompoundTableTableManager get familyCompound =>
      $$FamilyCompoundTableTableManager(_db, _db.familyCompound);
  $$FamilyIdiomTableTableManager get familyIdiom =>
      $$FamilyIdiomTableTableManager(_db, _db.familyIdiom);
  $$FamilySetTableTableManager get familySet =>
      $$FamilySetTableTableManager(_db, _db.familySet);
  $$SuttaInfoTableTableManager get suttaInfo =>
      $$SuttaInfoTableTableManager(_db, _db.suttaInfo);
  $$DictMetaTableTableManager get dictMeta =>
      $$DictMetaTableTableManager(_db, _db.dictMeta);
  $$DictEntriesTableTableManager get dictEntries =>
      $$DictEntriesTableTableManager(_db, _db.dictEntries);
}
