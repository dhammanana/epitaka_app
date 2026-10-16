/// A book loads into exactly the same paragraphs, lines, page numbers and
/// translations after the loader's queries were trimmed to the columns it
/// uses (task 6.2). The expected dump below was printed from the loader
/// before the change.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// (para, line, pali, vri, pts, thai, my).
const _pali = <(int, int, String?, String?, String?, String?, String?)>[
  (1, 1, 'evaṃ me sutaṃ', '1', 'p1', null, null),
  (1, 2, 'ekaṃ samayaṃ', null, null, null, null),
  (2, 1, null, '2', null, 't2', null),
  (2, 2, null, null, null, null, null),
  (3, 1, '  ', null, null, null, 'm3'),
  (4, 1, 'dhammaṃ desessāmi', null, 'p4', null, null),
  (10, 1, 'bhikkhave', '3', null, null, null),
];

/// (para, line, English). Para 99 is not in the book.
const _english = <(int, int, String?)>[
  (1, 1, 'Thus have I heard.'),
  (1, 2, null),
  (4, 1, 'I will teach the dhamma.'),
  (10, 1, 'monks'),
  (99, 1, 'stray'),
];

Future<EpitakaDatabase> _canon() async {
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
        BooksCompanion.insert(bookId: 'b1', bookName: const Value('Book 1')),
      );
  for (final (para, line, pali, vri, pts, thai, my) in _pali) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, vripara, pali, '
      'vripage, ptspage, thaipage, mypage) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ['b1', para, line, 'vp$para', pali, vri, pts, thai, my],
    );
  }
  // Another book's lines must not leak in.
  await db.customStatement(
    "INSERT INTO sentences(book_id, para_id, line_id, pali) "
    "VALUES ('b2', 1, 1, 'other')",
  );
  return db;
}

Future<TranslationDatabase> _translation() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (final (para, line, text) in _english) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      ['b1', para, line, text],
    );
  }
  return db;
}

String _dump(List<ParagraphData> paragraphs) => [
  for (final p in paragraphs) ...[
    'P${p.paraId} page=${p.pageNumber} pages=${p.pageNumbers} '
        'start=${p.isPageStart} heading=${p.heading?.title}',
    for (final l in p.lines)
      '  L${l.lineId} pali=${l.paliText} pages=${l.pageNumbers} '
          'trans=${l.translations} norm=${l.normalizedText}',
  ],
].join('\n');

void main() {
  test('the loaded book is unchanged', _loadAndCompare);
}

Future<void> _loadAndCompare() async {
  final canon = await _canon();
  final english = await _translation();
  addTearDown(() async {
    await english.close();
    await canon.close();
  });

  final container = ProviderContainer(
    overrides: [
      epitakaDbProvider.overrideWith((ref) async => canon),
      translationDbProvider('en').overrideWith((ref) async => english),
      settingsProvider.overrideWith((ref) {
        final n = SettingsNotifier(null);
        n.state = const AppSettings(
          showTranslation: true,
          enabledTranslations: ['en'],
        );
        return n;
      }),
    ],
  );
  addTearDown(container.dispose);

  final reader = container.read(readerDataProvider('b1').notifier);
  await reader.waitUntilLoaded();
  final dump = _dump(container.read(readerDataProvider('b1')).paragraphs);
  expect(dump, _expected);
}

const _expected = '''
P1 page=1 pages={vri: 1, pts: p1} start=false heading=null
  L1 pali=evaṃ me sutaṃ pages={vri: 1, pts: p1} trans={en: Thus have I heard.} norm=
  L2 pali=ekaṃ samayaṃ pages={} trans={} norm=
P2 page=2 pages={vri: 2, pts: p1, thai: t2} start=true heading=null
  L1 pali=null pages={vri: 2, thai: t2} trans={} norm=
P3 page=2 pages={vri: 2, pts: p1, thai: t2} start=false heading=null
P4 page=2 pages={vri: 2, pts: p4, thai: t2} start=false heading=null
  L1 pali=dhammaṃ desessāmi pages={pts: p4} trans={en: I will teach the dhamma.} norm=
P10 page=3 pages={vri: 3, pts: p4, thai: t2} start=true heading=null
  L1 pali=bhikkhave pages={vri: 3} trans={en: monks} norm=''';
