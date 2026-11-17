/// Expanding or collapsing a book card keeps the Exact mode. The card's count
/// comes from the exact index; a page fetched in Fuzzy mode would show `assa`
/// and `passasati` under a search for `assā`. Runs the REAL [SearchNotifier]
/// over real FTS indexes, as `search_count_once_test.dart` does.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT,
      book_id TEXT NOT NULL, category TEXT, nikaya TEXT, sub_nikaya TEXT,
      book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT,
      tika_ref TEXT, para_id INTEGER, chapter_len INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER,
      title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT,
      PRIMARY KEY (book_id, para_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE sentences (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL,
      vripara TEXT, pali TEXT, PRIMARY KEY (book_id, para_id, line_id)
    )
  ''');
  await db.customStatement(
    "INSERT INTO books(book_id, category, nikaya, book_name) "
    "VALUES ('b1', 'Mūla', 'Sutta Piṭaka', 'b1')",
  );
  const lines = {
    1: 'so satova assā ca',
    2: 'so satova assa ca',
    3: 'so satova passasati ca',
  };
  for (final e in lines.entries) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, ?, ?)',
      ['b1', e.key, 1, e.value],
    );
  }
  return db;
}

void main() {
  late EpitakaDatabase epiDb;
  late AppDatabase appDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    epiDb = await _fixtureEpitakaDb();
    appDb = AppDatabase(NativeDatabase.memory());
    await appDb.buildSearchIndex(epiDb);
  });

  tearDown(() async {
    await appDb.close();
    await epiDb.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        readerTabsProvider.overrideWith(
          (ref) => ReaderTabsNotifier(const ReaderTabsState(tabs: [])),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Exact: expanding a book shows only the paragraph with assā', () async {
    final container = makeContainer();
    await container.read(searchFuzzyProvider.notifier).set(false);
    final notifier = container.read(searchProvider.notifier);
    await notifier.search(query: 'assā');

    SearchResults results() => container.read(searchProvider) as SearchResults;
    expect(results().bookSummaries.single.totalCount, 1);

    await notifier.expandBook(0);

    expect(results().fuzzy, isFalse, reason: 'expanding keeps Exact');
    expect({
      for (final item in results().bookSummaries.single.loadedPages.single)
        item.paraId,
    }, {1});

    notifier.collapseBook(0);
    expect(results().fuzzy, isFalse, reason: 'collapsing keeps Exact');

    // The next expand reads the mode from the state the collapse left.
    await notifier.expandBook(0);
    expect({
      for (final item in results().bookSummaries.single.loadedPages.single)
        item.paraId,
    }, {1});
  });

  test('the word list follows the switch, also for a prefix seen before', () async {
    final container = makeContainer();
    final notifier = container.read(searchProvider.notifier);

    final fuzzy = await notifier.getSuggestions('assā');
    expect(fuzzy.map((s) => s.pali), contains('assa'));

    await container.read(searchFuzzyProvider.notifier).set(false);
    final exact = await notifier.getSuggestions('assā');
    expect(exact, isNotEmpty);
    expect(exact.every((s) => s.pali.startsWith('assā')), isTrue);

    await container.read(searchFuzzyProvider.notifier).set(true);
    final again = await notifier.getSuggestions('assā');
    expect(again.map((s) => s.pali), contains('assa'));
  });
}
