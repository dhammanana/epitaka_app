/// End-to-end FTS5 search tests.
///
/// These run the REAL pipeline the app ships: an in-memory [EpitakaDatabase]
/// fixture (books, headings, sentences in Roman Pāḷi) is indexed with
/// [AppDatabase.buildSearchIndex], then searches go through the actual query
/// methods ([AppDatabase.searchFts], `searchPaliFtsByBook`,
/// `countPaliResultsByBook`, `getSearchSuggestions`) and the real
/// [SearchNotifier] (for the category/nikāya filter behaviour).
///
/// Coverage:
///   * diacritic-insensitive matching (`katva` ↔ `katvā`, `cakkhunca` ↔
///     `cakkhuñca`, …) — the `remove_diacritics 1` contract
///   * multi-word queries (AND + prefix terms) and NEAR distance
///   * cross-script search — script queries converted to Roman via
///     [velthuis] find Roman-indexed text; raw unconverted script queries
///     match nothing (which is why the UI converts first)
///   * filtered search — per-book scoping, pagination, per-book counts
///     (what powers the category/nikāya filter panel), and the provider
///     filter toggles themselves
///   * the index schema-version stamp introduced for the
///     `remove_diacritics 0 → 1` migration
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/velthuis.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory Tipiṭaka fixture with the real (bundled-DB) table schemas.
///
/// Books span the three piṭakas so the category/nikāya filter tests have
/// something to filter. All Pāḷi text is Roman with diacritics (that is
/// what the bundled DB stores and what `search_fts` indexes).
Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ref_id INTEGER,
      vri_id TEXT,
      book_id TEXT NOT NULL,
      category TEXT,
      nikaya TEXT,
      sub_nikaya TEXT,
      book_name TEXT,
      description TEXT,
      mula_ref TEXT,
      attha_ref TEXT,
      tika_ref TEXT,
      para_id INTEGER,
      chapter_len INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL,
      para_id INTEGER NOT NULL,
      level INTEGER,
      title TEXT,
      chapter_len INTEGER,
      parent INTEGER,
      sc_id TEXT,
      PRIMARY KEY (book_id, para_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE sentences (
      book_id TEXT NOT NULL,
      para_id INTEGER NOT NULL,
      line_id INTEGER NOT NULL,
      vripara TEXT,
      pali TEXT,
      PRIMARY KEY (book_id, para_id, line_id)
    )
  ''');

  await db.customStatement(
    "INSERT INTO books(book_id, category, nikaya, book_name) "
    "VALUES ('dn1', 'Mūla', 'Sutta Piṭaka', 'Dīgha Nikāya')",
  );
  await db.customStatement(
    "INSERT INTO books(book_id, category, nikaya, book_name) "
    "VALUES ('kv', 'Aṭṭhakathā', 'Vinaya Piṭaka', 'Kaṅkhāvitaraṇī')",
  );
  await db.customStatement(
    "INSERT INTO books(book_id, category, nikaya, book_name) "
    "VALUES ('vbh', 'Mūla', 'Abhidhamma Piṭaka', 'Vibhaṅga')",
  );

  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title) "
    "VALUES ('dn1', 1, 1, 'Dīgha Nikāya')",
  );
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title) "
    "VALUES ('kv', 1, 1, 'Kaṅkhāvitaraṇī')",
  );

  // (book_id, para_id, line_id, pali)
  final sentences = <(String, int, int, String)>[
    // Multi-line paragraph — group_concat joins the lines into one row.
    ('dn1', 1, 1, 'cakkhuñca paṭicca rūpe ca'),
    ('dn1', 1, 2, 'uppajjati cakkhuviññāṇaṃ'),
    ('dn1', 2, 1, 'sabbe saṅkhārā aniccā'),
    ('dn1', 3, 1, 'katvā na upeti so paṇḍito'),
    ('dn1', 4, 1, 'dhammaṃ khetta'),
    ('dn1', 5, 1, 'sabbe dhammā anattā'),
    ('dn1', 6, 1, 'katvā katvā yathā'),
    ('dn1', 7, 1, 'namo tassa bhagavato arahato sammāsambuddhassa'),
    ('kv', 10, 1, 'katvāna katvā dhammaṃ'),
    ('vbh', 20, 1, 'katvā rūpaṃ vedanā saññā'),
  ];
  for (final (bookId, paraId, lineId, pali) in sentences) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) '
      'VALUES (?, ?, ?, ?)',
      [bookId, paraId, lineId, pali],
    );
  }
  return db;
}

/// In-memory English-translation fixture (real `sentences` schema) with
/// romanized translation text that carries diacritics.
Future<TranslationDatabase> _fixtureTranslationDb() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  // Drift creates the `sentences` table automatically on first use (the
  // default onCreate), so there is no manual CREATE here — unlike the
  // EpitakaDatabase fixture whose onCreate is a deliberate no-op.
  final rows = <(String, int, int, String)>[
    ('dn1', 1, 1, 'rāga dveṣa moha'),
    ('dn1', 2, 1, 'cittaṃ parisuddhaṃ'),
    ('kv', 10, 1, 'sabbe dhammā'),
  ];
  for (final (bookId, paraId, lineId, translation) in rows) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      [bookId, paraId, lineId, translation],
    );
  }
  return db;
}

Future<AppDatabase> _fixtureAppDb() async {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late EpitakaDatabase epiDb;
  late TranslationDatabase transDb;
  late AppDatabase appDb;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    transDb = await _fixtureTranslationDb();
    appDb = await _fixtureAppDb();
    // Build the real FTS indexes (cleaning, batching, version stamps).
    await appDb.buildSearchIndex(epiDb);
    await appDb.buildTranslationSearchIndex('en', transDb);
  });

  tearDown(() async {
    await appDb.close();
    await transDb.close();
    await epiDb.close();
  });

  /// (bookId, paraId) hits for [query] via the real `searchFts` path.
  Future<Set<(String, int)>> hits(String query, {int distance = 0}) async {
    final rows = await appDb.searchFts(query, distance: distance);
    return {
      for (final r in rows) (r.bookId, r.firstParaId ?? -1),
    };
  }

  group('single word · diacritic-insensitive', () {
    test('`katva` (no diacritics) finds paragraphs indexed as `katvā`', () async {
      expect(
        await hits('katva'),
        {('dn1', 3), ('dn1', 6), ('kv', 10), ('vbh', 20)},
      );
    });

    test('`katvā` (with diacritics) finds the same paragraphs', () async {
      expect(
        await hits('katvā'),
        {('dn1', 3), ('dn1', 6), ('kv', 10), ('vbh', 20)},
      );
    });

    test('`dhamma` matches `dhammaṃ` / `dhammā` (anusvāra + long ā)', () async {
      expect(await hits('dhamma'), {('dn1', 4), ('dn1', 5), ('kv', 10)});
    });

    test('`cakkhunca` matches `cakkhuñca` (ñ → n)', () async {
      expect(await hits('cakkhunca'), {('dn1', 1)});
    });

    test('`sankhara` matches `saṅkhārā` (ṅ → n, ā → a)', () async {
      expect(await hits('sankhara'), {('dn1', 2)});
    });

    test('`rup` is a prefix of both `rūpe` and `rūpaṃ`', () async {
      expect(await hits('rup'), {('dn1', 1), ('vbh', 20)});
    });

    test('a non-word matches nothing', () async {
      expect(await hits('gavaya'), isEmpty);
    });
  });

  group('more than one word', () {
    test('two full words AND-match only the paragraph with both', () async {
      expect(await hits('sabbe saṅkhāra'), {('dn1', 2)});
      // "sabbe dhammā anattā" has sabbe + dhammā → matches; the
      // saṅkhāra paragraph has sabbe but no dhamma word → must not match.
      expect(await hits('sabbe dhamma'), {('dn1', 5)});
    });

    test('two partial words are matched as prefixes (AND)', () async {
      expect(await hits('sab san'), {('dn1', 2)});
    });

    test('a multi-word query with one missing word matches nothing', () async {
      expect(await hits('sabbe gavaya'), isEmpty);
    });

    test('a real phrase spanning multiple tokens', () async {
      expect(await hits('namo tassa'), {('dn1', 7)});
    });

    test('results carry a highlighted snippet', () async {
      final rows = await appDb.searchFts('cakkhu');
      expect(rows, isNotEmpty);
      final snippet = rows.first.snippet;
      expect(snippet, contains('<b>'));
      expect(snippet, contains('cakkhu'));
    });
  });

  group('multi-word with distance (NEAR)', () {
    test('words far apart match with a large-enough window', () async {
      // "katvā na upeti so paṇḍito" → katva … paṇḍito are 4 tokens apart.
      // (paṇḍito strips to `pandito`, hence the `pandit` prefix.)
      expect(await hits('katva pandit', distance: 3), {('dn1', 3)});
    });

    test('words too far apart do not match a small window', () async {
      expect(await hits('katva pandit', distance: 2), isEmpty);
    });

    test('adjacent words match even a window of 2', () async {
      // "katvā katvā yathā" → katva and yathā are within 2 tokens.
      expect(await hits('katva yatha', distance: 2), {('dn1', 6)});
    });
  });

  group('different scripts (cross-script search)', () {
    const scriptQueries = <String, String>{
      'Myanmar': 'ဓမ္မ',
      'Sinhala': 'ධම්ම',
      'Thai': 'ธมฺม',
      'Devanagari': 'धम्म',
      'Tamil': 'த⁴ம்ம',
    };

    for (final entry in scriptQueries.entries) {
      test('${entry.key} query converts to Roman and finds the Pāḷi',
          () async {
        final roman = velthuis(entry.value);
        expect(roman, 'dhamma',
            reason: '${entry.key} "${entry.value}" must convert to "dhamma"');
        expect(await hits(roman), contains(('dn1', 4)));
      });
    }

    test('mixed script + Roman text converts to a multi-word query', () async {
      // Myanmar နမော + Roman tassa → "namo tassa".
      expect(velthuis('နမော tassa'), 'namo tassa');
      // Both converted words together find the namo paragraph.
      expect(await hits(velthuis('နမော tassa')), {('dn1', 7)});
    });

    test('a raw unconverted script query matches nothing (UI converts first)',
        () async {
      expect(await hits('ဓမ္မ'), isEmpty);
    });
  });

  group('filtered search', () {
    test('searchPaliFtsByBook restricts results to one book', () async {
      final dn1Hits = await appDb.searchPaliFtsByBook('dn1', 'katva');
      expect(dn1Hits.every((r) => r.bookId == 'dn1'), isTrue);
      expect({for (final r in dn1Hits) r.firstParaId}, {3, 6});

      final kvHits = await appDb.searchPaliFtsByBook('kv', 'katva');
      expect({for (final r in kvHits) r.firstParaId}, {10});
    });

    test('countPaliResultsByBook groups counts per book (feeds the '
        'filter panel)', () async {
      expect(
        await appDb.countPaliResultsByBook('katva'),
        {'dn1': 2, 'kv': 1, 'vbh': 1},
      );
    });

    test('searchPaliFtsByBook paginates with limit/offset', () async {
      final page1 =
          await appDb.searchPaliFtsByBook('dn1', 'katva', limit: 1, offset: 0);
      final page2 =
          await appDb.searchPaliFtsByBook('dn1', 'katva', limit: 1, offset: 1);
      expect(page1, hasLength(1));
      expect(page2, hasLength(1));
      final ids1 = {for (final r in page1) r.firstParaId};
      final ids2 = {for (final r in page2) r.firstParaId};
      // Order-independent check: pages are disjoint and together cover
      // every match (FTS5 `rank` ordering across matches is an
      // implementation detail). The 2×katvā paragraph does rank first on
      // this build (BM25 term frequency), but we don't assert the order.
      expect(ids1.intersection(ids2), isEmpty, reason: 'pages must not overlap');
      expect(ids1.union(ids2), {3, 6}, reason: 'pages cover all matches');
    });
  });

  group('word suggestions', () {
    test('prefix suggestions start with the typed prefix', () async {
      final suggestions = await appDb.getSearchSuggestions('dhamm');
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.every((s) => s.pali.startsWith('dhamm')),
        isTrue,
      );
    });

    test('diacritic-insensitive (fuzzy) prefix finds both forms', () async {
      final suggestions = await appDb.getSearchSuggestions('dhamma');
      expect(
        suggestions.map((s) => s.pali),
        containsAll(['dhammaṃ', 'dhammā']),
      );
    });
  });

  group('translation index (en)', () {
    test('translation search strips diacritics too (rāga → raga)', () async {
      final rows = await appDb.searchTranslationFts('en', 'raga');
      expect(rows.map((r) => (r.bookId, r.firstParaId)), contains(('dn1', 1)));

      final dvesa = await appDb.searchTranslationFts('en', 'dvesa');
      expect(dvesa.map((r) => (r.bookId, r.firstParaId)), contains(('dn1', 1)));
    });

    test('multi-word translation query (citta parisuddha)', () async {
      final rows = await appDb.searchTranslationFts('en', 'citta parisuddha');
      expect(rows.map((r) => (r.bookId, r.firstParaId)), contains(('dn1', 2)));
    });

    test('translation search filtered by book', () async {
      final rows = await appDb.searchTranslationFtsByBook('en', 'kv', 'dhamma');
      expect(rows.every((r) => r.bookId == 'kv'), isTrue);
      expect({for (final r in rows) r.firstParaId}, {10});
    });
  });

  group('search provider category/nikāya filters', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWith((ref) async => appDb),
          epitakaDbProvider.overrideWith((ref) async => epiDb),
          // No translation DB in the fixture — best-effort skip (the
          // default settings resolve the active language to 'en').
          translationDbProvider('en').overrideWith((ref) async => null),
          settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        ],
      );
      addTearDown(container.dispose);
    });

    Set<String> bookIds(SearchResults s) =>
        {for (final b in s.bookSummaries) b.book.bookId};

    test('category filter removes Aṭṭhakathā books', () async {
      final notifier = container.read(searchProvider.notifier);
      await notifier.search(query: 'katva');

      // Read the current results state with an explicit cast each time
      // (reassigning a `var` from container.read trips Riverpod's generic
      // inference).
      SearchResults current() =>
          container.read(searchProvider) as SearchResults;

      expect(bookIds(current()), {'dn1', 'kv', 'vbh'});

      // kv is Aṭṭhakathā → disable the aṭṭha category layer.
      await notifier.toggleCategory('aṭṭha');
      expect(bookIds(current()), {'dn1', 'vbh'});

      // dn1 is Sutta Piṭaka → disable the sutta nikāya too.
      await notifier.toggleNikaya('sutta');
      expect(bookIds(current()), {'vbh'});
    });
  });

  group('index schema version stamping', () {
    // Each test gets its own freshly built index so the shared `appDb`
    // is never left in a mutated state.
    late AppDatabase stampDb;

    setUp(() async {
      stampDb = AppDatabase(NativeDatabase.memory());
      await stampDb.buildSearchIndex(epiDb);
    });
    tearDown(() => stampDb.close());

    test('a freshly built index is stamped and reported built', () async {
      expect(await stampDb.isSearchIndexBuilt(), isTrue);
      final rows = await stampDb.customSelect(
        "SELECT value FROM index_meta WHERE key = 'search_index_version'",
      ).get();
      expect(rows, hasLength(1));
      expect(rows.first.data['value'], kSearchIndexSchemaVersion.toString());
    });

    test('a missing stamp marks the index as needing a rebuild', () async {
      await stampDb.customStatement(
        "DELETE FROM index_meta WHERE key = 'search_index_version'",
      );
      expect(await stampDb.isSearchIndexBuilt(), isFalse);
    });
  });
}
