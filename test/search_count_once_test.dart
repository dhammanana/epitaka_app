/// A paragraph that matches in the Pāli and in the translation counts once
/// and shows once, also when its two matches fall on different pages.
///
/// The fixture makes the second page all repeats: the Pāli ranks paragraphs
/// 1–30 first and 31–60 second, the English ranks them the other way round,
/// so page 1 shows 1–60 and page 2 brings nothing new. Paragraphs 61–90 match
/// only in the Pāli and come on page 3. Runs the REAL [SearchNotifier] over
/// real FTS indexes, as `search_open_book_load_test.dart` does.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Equal lengths, so BM25 ranks by how often the word appears.
String _text(String word, int hits) =>
    [...List.filled(hits, word), ...List.filled(8 - hits, 'ca')].join(' ');

int _paliHits(int p) => p <= 30 ? 6 : (p <= 60 ? 3 : 1);

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
  for (var p = 1; p <= 90; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, ?, ?)',
      ['b1', p, 1, _text('dhammaṃ', _paliHits(p))],
    );
  }
  return db;
}

Future<TranslationDatabase> _fixtureTranslationDb() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (var p = 1; p <= 60; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      ['b1', p, 1, _text('dhamma', p <= 30 ? 3 : 6)],
    );
  }
  return db;
}

void main() {
  late EpitakaDatabase epiDb;
  late TranslationDatabase transDb;
  late AppDatabase appDb;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    transDb = await _fixtureTranslationDb();
    appDb = AppDatabase(NativeDatabase.memory());
    await appDb.buildSearchIndex(epiDb);
    await appDb.buildTranslationSearchIndex('en', transDb);
  });

  tearDown(() async {
    await appDb.close();
    await transDb.close();
    await epiDb.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => transDb),
        settingsProvider.overrideWith((ref) {
          final n = SettingsNotifier(null);
          n.state = const AppSettings(
            showTranslation: true,
            enabledTranslations: ['en'],
          );
          return n;
        }),
        readerTabsProvider.overrideWith(
          (ref) => ReaderTabsNotifier(const ReaderTabsState(tabs: [])),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'one "Show more" tap skips a page of repeats and shows the rest',
    () async {
      final container = makeContainer();
      final notifier = container.read(searchProvider.notifier);
      await notifier.search(query: 'dhamma');
      BookResultSummary book() =>
          (container.read(searchProvider) as SearchResults)
              .bookSummaries
              .single;

      expect(book().totalCount, 90, reason: 'paragraphs 1–60 count once');
      await notifier.expandBook(0);
      expect(
        {for (final item in book().loadedPages.single) item.paraId},
        {for (var p = 1; p <= 60; p++) p},
        reason:
            'the fixture must rank 1–30 first in the Pāli, 31–60 first '
            'in the English',
      );
      expect(book().fullyLoaded, isFalse);

      await notifier.loadMoreForBook(0);

      final ids = [
        for (final page in book().loadedPages)
          for (final item in page) item.paraId,
      ];
      expect(ids.length, 90);
      expect(ids.toSet(), {for (var p = 1; p <= 90; p++) p});
      expect(book().fullyLoaded, isTrue);
    },
  );

  test('loading every hit keeps going past a page of repeats', () async {
    final container = makeContainer();
    final notifier = container.read(searchProvider.notifier);
    await notifier.search(query: 'dhamma');
    BookResultSummary book() =>
        (container.read(searchProvider) as SearchResults).bookSummaries.single;

    await notifier.loadAllForBook(0);

    expect([for (final page in book().loadedPages) page.length], [60, 0, 30]);
    final ids = [
      for (final page in book().loadedPages)
        for (final item in page) item.paraId,
    ];
    expect(ids.toSet(), {for (var p = 1; p <= 90; p++) p});
    expect(book().fullyLoaded, isTrue);
  });
}
