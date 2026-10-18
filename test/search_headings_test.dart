/// The main search's heading list (38,069 titles, each cleaned with
/// [normalizePaliFuzzy]) is built once per session. On a Pixel 8 Pro the
/// warm-up and the first search each built it, 300 ms apart, and both cleaned
/// every title on the main isolate. The list must be built once, and its
/// keys must stay what the main-isolate cleaning gave.
///
/// Runs the REAL [SearchNotifier] against an in-memory headings table.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// (book, para, level, title). Level 10 rows are section numbers and are
/// left out of the list; a NULL title becomes an empty key.
const _headings = <(String, int, int?, String?)>[
  ('dn1', 1, 1, 'Dīgha Nikāya'),
  ('dn1', 2, 2, 'Brahmajālasuttaṃ'),
  ('dn1', 3, 10, '1'),
  ('kv', 1, null, 'Kaṅkhāvitaraṇī'),
  ('kv', 2, 1, null),
  ('vin1', 1, 3, 'Pārājikakaṇḍaṃ (1)'),
  ('vin1', 2, 3, 'Mahāvaggo [pa. 12]'),
];

Future<EpitakaDatabase> _fixtureDb({bool withRows = true}) async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER,
      title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT,
      PRIMARY KEY (book_id, para_id)
    )
  ''');
  if (withRows) {
    for (final (book, para, level, title) in _headings) {
      await db.customStatement(
        'INSERT INTO headings(book_id, para_id, level, title) '
        'VALUES (?, ?, ?, ?)',
        [book, para, level, title],
      );
    }
  }
  return db;
}

SearchNotifier _notifierFor(EpitakaDatabase db) {
  final container = ProviderContainer(
    overrides: [epitakaDbProvider.overrideWith((ref) async => db)],
  );
  addTearDown(container.dispose);
  return container.read(searchProvider.notifier);
}

void main() {
  test(
    'the heading keys are the main-isolate cleaning of each title',
    () async {
      final db = await _fixtureDb();
      addTearDown(db.close);

      final headings = await _notifierFor(db).headingsForTesting();

      // Written out from a run of the code before the change.
      expect(
        [
          for (final h in headings)
            (h.bookId, h.paraId, h.level, h.title, h.key),
        ],
        [
          ('dn1', 1, 1, 'Dīgha Nikāya', 'digha nikaya'),
          ('dn1', 2, 2, 'Brahmajālasuttaṃ', 'brahmajalasuttam'),
          ('kv', 1, null, 'Kaṅkhāvitaraṇī', 'kankhavitarani'),
          ('kv', 2, 1, '', ''),
          ('vin1', 1, 3, 'Pārājikakaṇḍaṃ (1)', 'parajikakandam'),
          ('vin1', 2, 3, 'Mahāvaggo [pa. 12]', 'mahavaggo'),
        ],
      );
    },
  );

  test('a search during the warm-up shares its build', () async {
    final db = await _fixtureDb();
    addTearDown(db.close);
    final notifier = _notifierFor(db);

    final warmUp = notifier.headingsForTesting();
    final firstSearch = notifier.headingsForTesting();
    final lists = await Future.wait([warmUp, firstSearch]);

    expect(notifier.headingsBuildCount, 1);
    expect(identical(lists[0], lists[1]), isTrue);

    await notifier.headingsForTesting();
    expect(notifier.headingsBuildCount, 1, reason: 'cached for the session');
  });

  test(
    'an empty heading list is not kept, so the next search retries',
    () async {
      final db = await _fixtureDb(withRows: false);
      addTearDown(db.close);
      final notifier = _notifierFor(db);

      expect(await notifier.headingsForTesting(), isEmpty);
      expect(await notifier.headingsForTesting(), isEmpty);
      expect(notifier.headingsBuildCount, 2);
    },
  );
}
