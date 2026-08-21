/// Regression: page numbers stored sparsely in the DB must be carried
/// forward to every paragraph at load time.
///
/// The DB only writes page numbers on the sentence that opens a page
/// (e.g. `vripage` is empty for most sentence rows). When the reader builds
/// `ParagraphData.pageNumbers` by merging only that paragraph's own lines,
/// paragraphs that don't contain a page-break line end up with an empty map —
/// so the Excerpt/Share citation rendered an empty `{vri_page}`. This test
/// pins the carry-forward behavior so the bug can't silently come back.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/database/epitaka_database.dart';
import '../lib/core/providers/database_provider.dart';
import '../lib/core/providers/settings_provider.dart';
import '../lib/features/reader/providers/reader_provider.dart';

/// 10 paragraphs; only the sentence that opens a page carries `vripage`
/// (pages start at paragraphs 1, 4 and 7) — mirroring the real DB layout.
const _pageStarts = {1: '1', 4: '2', 7: '3'};
const _paraCount = 10;

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
        BooksCompanion.insert(
          bookId: 'dn1',
          bookName: const Value('Dīgha Nikāya 1'),
        ),
      );

  for (var i = 1; i <= _paraCount; i++) {
    await db
        .into(db.sentences)
        .insert(
          SentencesCompanion.insert(
            bookId: 'dn1',
            paraId: i,
            lineId: 1,
            pali: Value('pāli text paragraph $i'),
            vripage: Value(_pageStarts[i]),
          ),
        );
  }
  return db;
}

void main() {
  test('page numbers are carried forward to every paragraph', () async {
    final db = await _seedDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(showTranslation: false);
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(readerDataProvider('dn1').notifier);
    await notifier.waitUntilLoaded();

    final paragraphs = container.read(readerDataProvider('dn1')).paragraphs;
    expect(paragraphs.length, _paraCount);

    // Every paragraph must know which page it is on — the value carried
    // forward from the last page-break sentence. Before the fix only
    // paragraphs 1, 4 and 7 had a page number, so {vri_page} came out empty.
    for (var i = 0; i < paragraphs.length; i++) {
      final expectedPage = switch (i) {
        0 || 1 || 2 => '1',
        3 || 4 || 5 => '2',
        _ => '3',
      };
      final p = paragraphs[i];
      expect(
        p.pageNumbers['vri'],
        expectedPage,
        reason: 'paragraph ${p.paraId} pageNumbers',
      );
      expect(
        p.pageNumber,
        expectedPage,
        reason: 'paragraph ${p.paraId} pageNumber',
      );
    }

    // Line-level page numbers stay sparse: only the page-opening line carries
    // a value (the page badge rendering depends on this).
    for (final p in paragraphs) {
      if (p.lines.isNotEmpty) {
        expect(
          p.lines.first.pageNumbers['vri'],
          _pageStarts[p.paraId],
          reason: 'line pageNumbers of paragraph ${p.paraId} must stay raw',
        );
      }
    }

    // isPageStart stays true only at real page boundaries (4 and 7; the
    // first paragraph is the implicit start of page 1 and predates the
    // carry-forward logic).
    final starts = [
      for (final p in paragraphs)
        if (p.isPageStart) p.paraId,
    ];
    expect(starts, [4, 7]);
  });
}
