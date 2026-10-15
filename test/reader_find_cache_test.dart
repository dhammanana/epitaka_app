/// Find in book must normalize each line once per loaded book and variant
/// setting, not once per query. Before the cache every query normalized every
/// line of the book again (about 1.2 s per query in Pācity-y on a Pixel 8 Pro).
///
/// Drives the REAL [ReaderSearchNotifier] against the REAL
/// [readerDataProvider] loaded from a seeded in-memory database.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_search_notifier.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';

const _bookId = 'dn1';

/// (paraId, lineId, pali). Paragraph 3 holds "dhammo" only inside a variant
/// bracket, so hiding variants must drop it from the matches.
const _lines = [
  (1, 1, 'evaṃ me sutaṃ'),
  (1, 2, 'dhamma desito'),
  (2, 1, 'dhammo ca [dhammo] ca'),
  (2, 2, 'bhikkhave'),
  (3, 1, 'sabbe [dhammo] saṅkhārā'),
  (4, 1, 'dhammaṃ desessāmi'),
  (4, 2, 'atha kho'),
];

Future<EpitakaDatabase> _seedDatabase() async {
  final db = EpitakaDatabase(NativeDatabase.memory());

  await db.customStatement(
    'CREATE TABLE books ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT, category TEXT, nikaya TEXT, sub_nikaya TEXT, '
    'book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT, '
    'tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER, '
    'title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT, '
    'PRIMARY KEY (book_id, para_id))',
  );
  await db.customStatement(
    'CREATE TABLE sentences ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL, '
    'vripara TEXT, thaipage TEXT, vripage TEXT, ptspage TEXT, mypage TEXT, '
    'pali TEXT, PRIMARY KEY (book_id, para_id, line_id))',
  );

  await db
      .into(db.books)
      .insert(
        BooksCompanion.insert(bookId: _bookId, bookName: const Value('DN 1')),
      );
  for (final (para, line, pali) in _lines) {
    await db
        .into(db.sentences)
        .insert(
          SentencesCompanion.insert(
            bookId: _bookId,
            paraId: para,
            lineId: line,
            pali: Value(pali),
          ),
        );
  }
  return db;
}

/// The (paraId, lineId) pairs of the last query's matches.
List<(int, int)> _matches(InBookSearchState s) => [
  for (var i = 0; i < s.matchParaIds.length; i++)
    (s.matchParaIds[i], s.matchLineIds[i]),
];

/// A container with the seeded book open in a tab, loaded, and the find
/// provider kept alive the way the reader screen keeps it.
Future<(ProviderContainer, ReaderDataNotifier, ReaderSearchNotifier)>
_openBook() async {
  final db = await _seedDatabase();
  addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      epitakaDbProvider.overrideWith((ref) async => db),
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = const AppSettings(
          showTranslation: false,
          stripVariantAnnotations: false,
        );
        return notifier;
      }),
    ],
  );
  addTearDown(container.dispose);

  container
      .read(readerTabsProvider.notifier)
      .openTab(const ReaderTabInfo(bookId: _bookId, bookName: 'DN 1'));
  final reader = container.read(readerDataProvider(_bookId).notifier);
  await reader.waitUntilLoaded();

  container.listen(inBookSearchProvider, (_, _) {});
  return (container, reader, container.read(inBookSearchProvider.notifier));
}

/// Waits on the real clock: the background build runs in another isolate.
Future<void> _waitFor(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out after 2 s');
}

void main() {
  // toggleSearchBar focuses the field after the next frame.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a large book normalizes in the background', () {
    setUp(() {
      final saved = ReaderSearchNotifier.backgroundMinLines;
      ReaderSearchNotifier.backgroundMinLines = 0;
      addTearDown(() => ReaderSearchNotifier.backgroundMinLines = saved);
    });

    test('opening the find bar fills the cache with no query typed', () async {
      final (_, _, find) = await _openBook();

      find.toggleSearchBar();
      expect(
        find.cachedLineCount,
        0,
        reason: 'the build must not run on the main isolate',
      );
      await _waitFor(() => find.cachedLineCount == _lines.length);
    });

    test('a query typed at once waits for that build, not a second one', () async {
      final (container, _, find) = await _openBook();

      find.toggleSearchBar();
      find.onSubmitted('dhamma');
      await _waitFor(() => container.read(inBookSearchProvider).query != '');
      expect(find.lastNormalizedCount, 0);
      expect(_matches(container.read(inBookSearchProvider)), [(1, 2), (4, 1)]);

      find.onSubmitted('dhammo');
      await _waitFor(
        () => container.read(inBookSearchProvider).query == 'dhammo',
      );
      expect(_matches(container.read(inBookSearchProvider)), [(2, 1), (3, 1)]);
    });

    // A tab switch closes the bar too, so the old book's matches must never
    // land in it; the reader would jump to them in the new book.
    test('closing the bar drops a query still waiting for the build', () async {
      final (container, _, find) = await _openBook();

      find.toggleSearchBar();
      find.onSubmitted('dhamma');
      find.toggleSearchBar();
      await _waitFor(() => find.cachedLineCount == _lines.length);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(inBookSearchProvider);
      expect(state.showSearchBar, isFalse);
      expect(state.query, '');
      expect(state.matchParaIds, isEmpty);
    });
  });

  test('a repeat query reuses the normalized lines of the loaded book', () async {
    final db = await _seedDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(
            showTranslation: false,
            stripVariantAnnotations: false,
          );
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(readerTabsProvider.notifier)
        .openTab(const ReaderTabInfo(bookId: _bookId, bookName: 'DN 1'));
    final reader = container.read(readerDataProvider(_bookId).notifier);
    await reader.waitUntilLoaded();

    // The reader screen keeps the auto-disposed find provider alive.
    container.listen(inBookSearchProvider, (_, _) {});
    final find = container.read(inBookSearchProvider.notifier);

    find.onSubmitted('dhamma');
    expect(find.lastNormalizedCount, _lines.length);
    expect(_matches(container.read(inBookSearchProvider)), [(1, 2), (4, 1)]);

    find.onSubmitted('dhammo');
    expect(find.lastNormalizedCount, 0, reason: 'same book, same setting');
    expect(_matches(container.read(inBookSearchProvider)), [(2, 1), (3, 1)]);

    // Hiding variants changes what each line contains, so it normalizes
    // again and the variant-only line no longer matches.
    final settings = container.read(settingsProvider.notifier);
    settings.state = settings.state.copyWith(stripVariantAnnotations: true);
    find.onSubmitted('dhammo');
    expect(find.lastNormalizedCount, _lines.length);
    expect(_matches(container.read(inBookSearchProvider)), [(2, 1)]);

    find.onSubmitted('dhammo');
    expect(find.lastNormalizedCount, 0);

    // A reloaded book is a new paragraph list, so it normalizes again.
    final before = container.read(readerDataProvider(_bookId)).paragraphs;
    final reloaded = reader.stream.firstWhere(
      (s) => s.isLoaded && !identical(s.paragraphs, before),
    );
    settings.state = settings.state.copyWith(pageNumberingSystem: 'pts');
    await reloaded;
    find.onSubmitted('dhammo');
    expect(find.lastNormalizedCount, _lines.length);
    expect(_matches(container.read(inBookSearchProvider)), [(2, 1)]);

    // Closing the book's last tab releases its data, so the cache must not
    // keep the book's text alive either.
    expect(find.cachedLineCount, _lines.length);
    container.read(readerTabsProvider.notifier).closeTab(0);
    expect(find.cachedLineCount, 0);
  });
}
