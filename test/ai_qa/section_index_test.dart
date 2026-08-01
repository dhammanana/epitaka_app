/// Unit tests for the Layer 1 Section Index (roadmap §5).
///
/// Uses in-memory fixture databases (no real Tipitaka files needed) and
/// overrides the Riverpod providers so [SectionIndexService] and
/// [AiQaToolService] run against the fixture. Verifies the section span
/// algorithm (contiguous, non-overlapping, annotation-filtered), hierarchy
/// paths, whole-book fallback, and the `get_section` browsing contract.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/database/app_database.dart';
import '../../lib/core/database/epitaka_database.dart';
import '../../lib/core/providers/app_db_provider.dart';
import '../../lib/core/providers/database_provider.dart';
import '../../lib/features/ai_qa/services/ai_qa_tool_service.dart';
import '../../lib/features/ai_qa/services/section_index_service.dart';

/// Create an in-memory epitaka fixture with the real tables (the drift
/// `EpitakaDatabase.onCreate` is a no-op because the real DB is bundled).
Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id TEXT NOT NULL,
      book_name TEXT,
      category TEXT,
      nikaya TEXT,
      mula_ref TEXT,
      attha_ref TEXT,
      tika_ref TEXT,
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

  // Books.
  await db.customStatement(
    "INSERT INTO books(book_id, book_name) VALUES ('test1', 'Test Book One')",
  );
  await db.customStatement(
    "INSERT INTO books(book_id, book_name) VALUES ('test2', 'Test Book Two')",
  );

  // Headings: level 1 book → level 2 vagga → level 4 sutta.
  // paras 50 (level 10) and 55 (level 19) must be filtered out.
  final headings = [
    ('test1', 1, 1, 'Book One', -1),
    ('test1', 5, 2, 'Vagga A', 1),
    ('test1', 10, 4, 'Sutta A', 5),
    ('test1', 20, 4, 'Sutta B', 5),
    ('test1', 30, 2, 'Vagga B', 1),
    ('test1', 40, 4, 'Sutta C', 30),
    ('test1', 50, 10, 'ANNOTATION', 40), // excluded (level 10)
    ('test1', 55, 19, 'STRUCTURAL', 40), // excluded (level >= 19)
  ];
  for (final (bid, pid, lvl, title, parent) in headings) {
    await db.customStatement(
      'INSERT INTO headings(book_id, para_id, level, title, parent) '
      'VALUES (?, ?, ?, ?, ?)',
      [bid, pid, lvl, title, parent],
    );
  }

  // Sentences: test1 paras 1..60, test2 (heading-less book) paras 1..7.
  for (int p = 1; p <= 60; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, 1, ?)',
      ['test1', p, 'pali text $p'],
    );
  }
  for (int p = 1; p <= 7; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, 1, ?)',
      ['test2', p, 'other text $p'],
    );
  }
  return db;
}

Future<AppDatabase> _fixtureAppDb() async {
  return AppDatabase(NativeDatabase.memory());
}

/// Load all section rows for a book from the fixture app db.
Future<List<Map<String, dynamic>>> _sectionsFor(
  AppDatabase appDb,
  String bookId,
) async {
  final rows = await appDb.customSelect(
    'SELECT para_start, para_end, level, parent_para, title, path '
    'FROM section_summaries WHERE book_id = ? ORDER BY para_start ASC',
    variables: [Variable.withString(bookId)],
  ).get();
  return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
}

void main() {
  late EpitakaDatabase epiDb;
  late AppDatabase appDb;
  late ProviderContainer container;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    appDb = await _fixtureAppDb();
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        // No English translation DB in the fixture — best-effort skip.
        translationDbProvider('en').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async => appDb.close());
    addTearDown(() async => epiDb.close());
  });

  test('builds sections with correct spans, filtering and paths', () async {
    final service = container.read(sectionIndexServiceProvider);
    final count = await service.buildIndex();
    expect(count, 7, reason: '6 sections for test1 + 1 whole-book for test2');

    // test1: level-10 and level-19 headings must NOT become sections.
    final sections = await _sectionsFor(appDb, 'test1');
    expect(sections, hasLength(6));
    final starts = sections.map((s) => s['para_start'] as int).toSet();
    expect(starts.contains(50), isFalse);
    expect(starts.contains(55), isFalse);

    // Expected spans (next heading at same-or-shallower level − 1).
    final spanOf = {
      for (final s in sections) s['para_start'] as int: s['para_end'] as int,
    };
    expect(spanOf[1], 60, reason: 'top-level heading spans the whole book');
    expect(spanOf[5], 29, reason: 'Vagga A ends before Vagga B (para 30)');
    expect(spanOf[10], 19, reason: 'Sutta A ends before Sutta B (para 20)');
    expect(spanOf[20], 29, reason: 'Sutta B ends at Vagga A boundary');
    expect(spanOf[30], 60, reason: 'Vagga B runs to the end of the book');
    expect(spanOf[40], 60, reason: 'Sutta C runs to the end of the book');

    // Every paragraph of the book is covered by some section.
    for (int p = 1; p <= 60; p++) {
      final covered = sections.any((s) =>
          (s['para_start'] as int) <= p && p <= (s['para_end'] as int));
      expect(covered, isTrue, reason: 'para $p must be covered by a section');
    }

    // Same-level sections never overlap.
    final byLevel = <int, List<(int, int)>>{};
    for (final s in sections) {
      byLevel.putIfAbsent(s['level'] as int, () => []);
      byLevel[s['level'] as int]!.add((
        s['para_start'] as int,
        s['para_end'] as int,
      ));
    }
    for (final entries in byLevel.entries) {
      final ranges = entries.value..sort((a, b) => a.$1.compareTo(b.$1));
      for (int i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, greaterThanOrEqualTo(ranges[i - 1].$2 + 1),
            reason: 'level ${entries.key} sections must not overlap');
      }
    }

    // Hierarchy paths.
    final pathOf = {
      for (final s in sections) s['para_start'] as int: s['path'] as String,
    };
    expect(pathOf[10], 'test1/Book One/Vagga A/Sutta A');
    expect(pathOf[40], 'test1/Book One/Vagga B/Sutta C');
    expect(pathOf[5], 'test1/Book One/Vagga A');
  });

  test('books without headings become a single whole-book section', () async {
    final service = container.read(sectionIndexServiceProvider);
    await service.buildIndex();
    final sections = await _sectionsFor(appDb, 'test2');
    expect(sections, hasLength(1));
    expect(sections.first['para_start'], 1);
    expect(sections.first['para_end'], 7);
    expect(sections.first['title'], 'Test Book Two');
    expect(sections.first['path'], 'test2/Test Book Two');
  });

  test('get_section returns section, children and parent (browse contract)',
      () async {
    final service = container.read(sectionIndexServiceProvider);
    await service.buildIndex();

    // Browse a vagga → its sutta children.
    final vagga = await service.getSection('test1', 5);
    expect(vagga, isNotNull);
    expect(vagga!['section']['title'], 'Vagga A');
    expect(vagga['section']['para_end'], 29);
    final childStarts =
        (vagga['children'] as List).map((c) => c['para_start']).toList();
    expect(childStarts, [10, 20]);
    // The vagga's parent is the level-1 book row (para 1).
    expect(vagga['parent']!['para_start'], 1);
    expect(vagga['parent']!['title'], 'Book One');

    // A sutta's parent is its vagga; a sutta has no children.
    final sutta = await service.getSection('test1', 10);
    expect(sutta, isNotNull);
    expect(sutta!['section']['title'], 'Sutta A');
    expect((sutta['children'] as List), isEmpty);
    expect(sutta['parent']!['para_start'], 5);
    expect(sutta['parent']!['title'], 'Vagga A');

    // A top-level row has no parent (its parent_para is -1 → null).
    final top = await service.getSection('test1', 1);
    expect(top!['parent'], isNull);
    expect((top['children'] as List).length, 2);

    // Unknown section → null.
    expect(await service.getSection('test1', 999), isNull);
  });

  test('search_sections tool finds sections via the FTS index', () async {
    final service = container.read(sectionIndexServiceProvider);
    await service.buildIndex();

    final tool = container.read(aiQaToolServiceProvider);
    final result = await tool.searchSections({'query': 'Sutta'});
    expect(result.success, isTrue);

    final data =
        jsonDecode(result.data) as Map<String, dynamic>;
    final results = data['results'] as List;
    final titles = results.map((r) => r['title']).toList();
    expect(titles, contains('Sutta A'));
    expect(titles, contains('Sutta B'));
    expect(titles, contains('Sutta C'));
    // FTS matches must carry the Layer 1 contract fields.
    final first = results.first as Map<String, dynamic>;
    expect(first.containsKey('para_start'), isTrue);
    expect(first.containsKey('para_end'), isTrue);
    expect(first.containsKey('path'), isTrue);
  });

  test('get_section tool returns the browse contract JSON', () async {
    final service = container.read(sectionIndexServiceProvider);
    await service.buildIndex();

    final tool = container.read(aiQaToolServiceProvider);
    final result = await tool.getSection({'book_id': 'test1', 'para_start': 5});
    expect(result.success, isTrue);
    final data = jsonDecode(result.data) as Map<String, dynamic>;
    expect(data['section']['title'], 'Vagga A');
    expect((data['children'] as List), hasLength(2));
    expect(data['parent']!['para_start'], 1);
    expect(data['parent']!['title'], 'Book One');

    final missing =
        await tool.getSection({'book_id': 'test1', 'para_start': 999});
    expect(missing.success, isTrue);
    expect(jsonDecode(missing.data), contains('error'));
  });
}
