import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'dpd_database.g.dart';

/// Table: external dictionary metadata (name, author, CSS).
class DictMeta extends Table {
  @override
  String get tableName => 'dict_meta';

  TextColumn get dictId => text().named('dict_id')();
  TextColumn get name => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get css => text().nullable()();
  IntColumn get entryCount => integer().named('entry_count').nullable()();

  @override
  Set<Column> get primaryKey => {dictId};
}

/// Table: dictionary entries with word and HTML/plain definitions.
class DictEntries extends Table {
  @override
  String get tableName => 'dict_entries';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get dictId => text().named('dict_id')();
  TextColumn get word => text()();
  TextColumn get wordFuzzy => text().named('word_fuzzy').nullable()();
  TextColumn get definitionHtml =>
      text().named('definition_html').nullable()();
  TextColumn get definitionPlain =>
      text().named('definition_plain').nullable()();
}

/// Table: DPD headwords (primary dictionary).
class DpdHeadwords extends Table {
  @override
  String get tableName => 'dpd_headwords';

  IntColumn get id => integer()();
  TextColumn get lemma1 => text().named('lemma_1')();
  TextColumn get lemma2 => text().named('lemma_2').nullable()();
  TextColumn get pos => text().nullable()();
  TextColumn get grammar => text().nullable()();
  TextColumn get derivedFrom => text().named('derived_from').nullable()();
  TextColumn get neg => text().nullable()();
  TextColumn get verb => text().nullable()();
  TextColumn get trans => text().nullable()();
  TextColumn get plusCase => text().named('plus_case').nullable()();
  TextColumn get meaning1 => text().named('meaning_1').nullable()();
  TextColumn get meaningLit => text().named('meaning_lit').nullable()();
  TextColumn get meaning2 => text().named('meaning_2').nullable()();
  TextColumn get source1 => text().named('source_1').nullable()();
  TextColumn get sutta1 => text().named('sutta_1').nullable()();
  TextColumn get example1 => text().named('example_1').nullable()();
  TextColumn get source2 => text().named('source_2').nullable()();
  TextColumn get sutta2 => text().named('sutta_2').nullable()();
  TextColumn get example2 => text().named('example_2').nullable()();
  TextColumn get rootKey => text().named('root_key').nullable()();
  TextColumn get rootSign => text().named('root_sign').nullable()();
  TextColumn get rootBase => text().named('root_base').nullable()();
  TextColumn get familyRoot => text().named('family_root').nullable()();
  TextColumn get familyWord => text().named('family_word').nullable()();
  TextColumn get familyCompound =>
      text().named('family_compound').nullable()();
  TextColumn get familyIdioms => text().named('family_idioms').nullable()();
  TextColumn get construction => text().nullable()();
  TextColumn get compoundType => text().named('compound_type').nullable()();
  TextColumn get antonym => text().nullable()();
  TextColumn get synonym => text().nullable()();
  TextColumn get variant => text().nullable()();
  TextColumn get stem => text().nullable()();
  TextColumn get pattern => text().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get freqData => text().named('freq_data').nullable()();
  TextColumn get lemmaIpa => text().named('lemma_ipa').nullable()();
  IntColumn get ebtCount => integer().named('ebt_count').nullable()();
  TextColumn get nonIa => text().named('non_ia').nullable()();
  TextColumn get sanskrit => text().nullable()();
  TextColumn get cognate => text().nullable()();
  TextColumn get link => text().nullable()();
  TextColumn get phonetic => text().nullable()();
  TextColumn get varPhonetic => text().named('var_phonetic').nullable()();
  TextColumn get varText => text().named('var_text').nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get commentary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table: DPD roots (root metadata: meaning, group/gaṇa, etc.).
class DpdRoots extends Table {
  @override
  String get tableName => 'dpd_roots';

  TextColumn get root => text()();
  TextColumn get rootInComps => text().named('root_in_comps').nullable()();
  TextColumn get rootHasVerb => text().named('root_has_verb').nullable()();
  TextColumn get rootGroup => text().named('root_group').nullable()();
  TextColumn get rootSign => text().named('root_sign').nullable()();
  TextColumn get rootMeaning => text().named('root_meaning').nullable()();
  TextColumn get sanskritRoot => text().named('sanskrit_root').nullable()();
  TextColumn get sanskritRootMeaning =>
      text().named('sanskrit_root_meaning').nullable()();
  TextColumn get sanskritRootClass =>
      text().named('sanskrit_root_class').nullable()();
  TextColumn get rootExample => text().named('root_example').nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get rootCount => integer().named('root_count').nullable()();

  @override
  Set<Column> get primaryKey => {root};
}

/// Table: DPD lookup index (maps normalized keys to headword IDs).
class Lookup extends Table {
  @override
  String get tableName => 'lookup';

  TextColumn get lookupKey => text().named('lookup_key')();
  TextColumn get headwords => text().nullable()();
  TextColumn get roots => text().nullable()();
  TextColumn get variant => text().nullable()();
  TextColumn get spelling => text().nullable()();
  TextColumn get grammar => text().nullable()();
  TextColumn get help => text().nullable()();
  TextColumn get abbrev => text().nullable()();
  TextColumn get deconstructor => text().nullable()();
  TextColumn get epd => text().nullable()();
  TextColumn get fuzzyKey => text().named('fuzzy_key').nullable()();

  @override
  Set<Column> get primaryKey => {lookupKey};
}

/// Database for the DPD mobile dictionary.
@DriftDatabase(
  tables: [DictMeta, DictEntries, DpdHeadwords, DpdRoots, Lookup],
)
class DpdDatabase extends _$DpdDatabase {
  DpdDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Pre-built read-only database — tables already exist.
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Pre-built read-only database — no migration needed.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );

  static Future<DpdDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('DPD database not found at $dbPath');
    }
    return DpdDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA foreign_keys=ON');
        },
        logStatements: false,
      ),
    );
  }

  /// Access data access methods.
  DpdDao get dao => DpdDao(this);
}

/// Data Access Object for DPD queries.
class DpdDao {
  final DpdDatabase _db;
  DpdDao(this._db);

  // ── Lookup / Search ─────────────────────────────────────────────────

  /// Prefix search on the lookup table. Returns rows sorted by Pāli-relevant
  /// order (prefix-match closeness).
  Future<List<LookupData>> searchLookup(String prefix, {int limit = 20}) async {
    final pattern = '${prefix.trim().toLowerCase()}%';
    return (_db.select(_db.lookup)
          ..where((t) => t.lookupKey.like(pattern))
          ..limit(limit))
        .get();
  }

  /// Exact lookup by key.
  Future<LookupData?> getLookup(String key) async {
    return (_db.select(_db.lookup)
          ..where((t) => t.lookupKey.equals(key.toLowerCase())))
        .getSingleOrNull();
  }

  /// Batch get lookups by keys.
  Future<List<LookupData>> getLookups(List<String> keys) async {
    if (keys.isEmpty) return [];
    final normalized = keys.map((k) => k.toLowerCase()).toList();
    return (_db.select(_db.lookup)
          ..where((t) => t.lookupKey.isIn(normalized)))
        .get();
  }

  // ── Headwords ───────────────────────────────────────────────────────

  /// Get a single headword by ID.
  Future<DpdHeadword?> getHeadword(int id) async {
    return (_db.select(_db.dpdHeadwords)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get multiple headwords by IDs.
  Future<List<DpdHeadword>> getHeadwordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    return (_db.select(_db.dpdHeadwords)
          ..where((t) => t.id.isIn(ids)))
        .get();
  }

  // ── Roots ───────────────────────────────────────────────────────────

  /// Get a root by its key.
  Future<DpdRoot?> getRoot(String rootKey) async {
    return (_db.select(_db.dpdRoots)
          ..where((t) => t.root.equals(rootKey)))
        .getSingleOrNull();
  }

  /// Get multiple roots by keys.
  Future<List<DpdRoot>> getRoots(List<String> rootKeys) async {
    if (rootKeys.isEmpty) return [];
    return (_db.select(_db.dpdRoots)
          ..where((t) => t.root.isIn(rootKeys)))
        .get();
  }

  // ── Deconstructor ───────────────────────────────────────────────────

  /// Parse deconstructor JSON from a lookup entry.
  /// Returns a list of candidate breakup strings, e.g.
  /// ["kamma + paṭippassaddhiṃ + attā + pekkha + tāya", ...]
  List<String> parseDeconstructor(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      // JSON is a string that contains a JSON array of strings
      final decoded = jsonDecode(json);
      final parsed = decoded as List<dynamic>;
      return parsed.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Get deconstruction candidates for a word.
  Future<List<String>> getDeconstructions(String word) async {
    final lookup = await getLookup(word);
    final raw = lookup?.deconstructor;
    return parseDeconstructor(raw);
  }

  /// Check if a word has deconstructor data available.
  Future<bool> hasDeconstructor(String word) async {
    final decons = await getDeconstructions(word);
    return decons.isNotEmpty;
  }
}
