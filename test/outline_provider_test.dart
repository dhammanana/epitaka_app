/// Tests for the book outline builder ([outlineProvider]).
///
/// Uses an in-memory epitaka fixture (same harness as the section-index
/// tests) to verify the vagga → sutta grouping — and, as a regression, that
/// books whose sections have no level-2/level-4 ancestor heading build
/// without throwing (they used to crash with a "Null check operator used on
/// a null value" error on the first item).
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/database/epitaka_database.dart';
import '../lib/core/providers/database_provider.dart';
import '../lib/features/outline/providers/outline_provider.dart';

Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
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

  // 'dn1' — normal book: level 1 → vagga (2) → sutta (4) → sections (10).
  // 'flat' — numbered sections whose only ancestor is level 3 (no 2 or 4).
  // 'solo' — a lone numbered section with no parent at all.
  final headings = [
    ('dn1', 1, 1, 'Digha One', -1),
    ('dn1', 5, 2, 'Silakkhandha', 1),
    ('dn1', 10, 4, 'Brahmajala', 5),
    ('dn1', 20, 10, '1.1', 10),
    ('dn1', 30, 10, '1.2', 10),
    ('dn1', 40, 2, 'Mahavagga', 1),
    ('dn1', 50, 10, '2.1', 40),
    ('flat', 1, 1, 'Flat Book', -1),
    ('flat', 10, 3, 'Chapter', 1),
    ('flat', 20, 10, 'Item One', 10),
    ('flat', 30, 10, 'Item Two', 10),
    ('solo', 5, 10, 'Solo Item', -1),
  ];
  for (final (bid, pid, lvl, title, parent) in headings) {
    await db.customStatement(
      'INSERT INTO headings(book_id, para_id, level, title, parent) '
      'VALUES (?, ?, ?, ?, ?)',
      [bid, pid, lvl, title, parent],
    );
  }
  return db;
}

void main() {
  late EpitakaDatabase epiDb;
  late ProviderContainer container;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    container = ProviderContainer(
      overrides: [epitakaDbProvider.overrideWith((ref) async => epiDb)],
    );
    addTearDown(container.dispose);
    addTearDown(() async => epiDb.close());
  });

  test('groups a normal book into vagga → sutta → items', () async {
    final groups = await container.read(outlineProvider('dn1').future);

    expect(groups, hasLength(2));
    expect(groups[0].title, 'Silakkhandha');
    expect(groups[0].suttas, hasLength(1));
    expect(groups[0].suttas[0].title, 'Brahmajala');
    expect(groups[0].suttas[0].items.map((i) => i.title), ['1.1', '1.2']);
    expect(groups[0].itemCount, 2);

    expect(groups[1].title, 'Mahavagga');
    expect(groups[1].itemCount, 1);
    expect(groups[1].suttas.single.items.single.title, '2.1');
  });

  test(
    'builds without crashing when sections have no level-2/4 ancestor',
    () async {
      // Regression: the first item used to hit `sutta!.items.add(item)`
      // with sutta still null when no vagga/sutta title could be resolved
      // from the parent chain, throwing the null-check error on screen.
      final groups = await container.read(outlineProvider('flat').future);

      expect(groups, hasLength(1));
      expect(groups[0].title, isEmpty);
      expect(groups[0].itemCount, 2);
      expect(groups[0].suttas.single.items.map((i) => i.title), [
        'Item One',
        'Item Two',
      ]);

      // A section with no parent chain at all must also build.
      final solo = await container.read(outlineProvider('solo').future);
      expect(solo, hasLength(1));
      expect(solo[0].itemCount, 1);
      expect(solo[0].suttas.single.items.single.title, 'Solo Item');
    },
  );
}
