// Tests for the shared AI tool search used by Gavesana and Vimaṃsa.
//
// Coverage:
//   * `search_tipitaka` finds passages via the ENGLISH TRANSLATION when the
//     term never appears in the Pāli (the "I couldn't get what I need"
//     case — previously the LIKE search only covered `s.pali`)
//   * diacritic-insensitive LIKE matching: "sankhara" ↔ "saṅkhāra" ↔
//     "saṅkhārā" all pool and score the same paragraph
//   * `search_tipitaka_batch` merges hits from several terms
//   * `extractSearchTerms` surfaces the exact terms the AI queried, in
//     order and deduplicated, so the Gavesana results header can render
//     them as tappable chips
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/models/ai_qa_models.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/ai_qa/services/ai_qa_tool_service.dart';
import 'package:epitaka/features/gavesana/providers/ai_search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory Tipiṭaka fixture (real bundled-DB schemas, Roman Pāḷi with
/// diacritics) — same shape as `search_fts_test.dart`.
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
    "INSERT INTO headings(book_id, para_id, level, title) "
    "VALUES ('dn1', 1, 1, 'Dīgha Nikāya')",
  );

  final sentences = <(String, int, int, String)>[
    ('dn1', 1, 1, 'cakkhuñca paṭicca rūpe ca'),
    ('dn1', 2, 1, 'sabbe saṅkhārā aniccā'),
    ('dn1', 3, 1, 'dānaṃ dadāti saṃghassa'),
    ('dn1', 4, 1, 'namo tassa bhagavato'),
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

/// In-memory English-translation fixture (real `sentences` schema). The
/// translations are ENGLISH so terms like "generosity" that never appear
/// in the Pāli can still be found.
Future<TranslationDatabase> _fixtureTranslationDb() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  final rows = <(String, int, int, String)>[
    ('dn1', 1, 1, 'dependent on the eye and forms'),
    ('dn1', 2, 1, 'all conditioned things are impermanent'),
    ('dn1', 3, 1, 'he gives a gift to the sangha'),
    ('dn1', 4, 1, 'homage to the blessed one'),
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

void main() {
  late EpitakaDatabase epiDb;
  late TranslationDatabase transDb;
  late ProviderContainer container;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    transDb = await _fixtureTranslationDb();
    container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => transDb),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await transDb.close();
    await epiDb.close();
  });

  final service = AiQaToolService(container);

  /// (bookId, paraId) hits parsed out of a search tool result.
  Set<(String, int)> hits(ToolResult result) {
    final parsed = jsonDecode(result.data);
    if (parsed is! List) return {};
    return {
      for (final item in parsed)
        if (item is Map)
          ((item['book_id'] as String?) ?? '', (item['para_id'] as num?)?.toInt() ?? -1),
    };
  }

  group('search_tipitaka — translation-aware', () {
    test('an English term matches the translation even when the Pāli has no '
        'verbatim match', () async {
      // "gift" appears only in the translation (para 3: 'he gives a gift').
      final result =
          await service.searchTipitaka({'query': 'gives a gift'});
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(hits(result), contains(('dn1', 3)));
    });

    test('English-only query returns translation hits', () async {
      final result = await service.searchTipitaka({'query': 'impermanent'});
      expect(result.success, isTrue);
      expect(hits(result), contains(('dn1', 2)));
    });

    test('Pāli term with diacritics finds the paragraph', () async {
      final result = await service.searchTipitaka({'query': 'saṅkhāra'});
      expect(hits(result), contains(('dn1', 2)));
    });

    test('ASCII Pāli term finds the diacritic text (diacritic-insensitive)',
        () async {
      final result = await service.searchTipitaka({'query': 'sankhara'});
      expect(hits(result), contains(('dn1', 2)));
    });
  });

  group('search_tipitaka_batch — merged results', () {
    test('hits from several terms are merged and deduplicated', () async {
      final result = await service.searchTipitakaBatch({
        'queries': ['impermanent', 'gift', 'impermanent'],
      });
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(hits(result), contains(('dn1', 2)));
      expect(hits(result), contains(('dn1', 3)));
    });
  });

  group('extractSearchTerms — chips data', () {
    test('pulls query terms in order, deduplicated case-insensitively',
        () async {
      final logs = [
        const ToolCallLog(
          toolName: 'search_tipitaka_batch',
          arguments: {'queries': ['dāna', 'giving', 'DĀNA']},
          resultSummary: '',
        ),
        const ToolCallLog(
          toolName: 'search_by_category',
          arguments: {
            'queries': ['dukkara dāna'],
            'categories': ['sutta'],
          },
          resultSummary: '',
        ),
        const ToolCallLog(
          toolName: 'get_dictionary',
          arguments: {'term': 'dāna'},
          resultSummary: '',
        ),
        const ToolCallLog(
          toolName: 'search_tipitaka',
          arguments: {'query': 'supreme offering'},
          resultSummary: '',
        ),
      ];
      expect(
        extractSearchTerms(logs),
        ['dāna', 'giving', 'dukkara dāna', 'supreme offering'],
      );
    });

    test('non-search tools contribute nothing', () async {
      const logs = [
        ToolCallLog(
          toolName: 'get_paragraph_content',
          arguments: {'book_id': 'dn1', 'para_start': 1, 'para_end': 5},
          resultSummary: '',
        ),
      ];
      expect(extractSearchTerms(logs), isEmpty);
    });
  });
}
