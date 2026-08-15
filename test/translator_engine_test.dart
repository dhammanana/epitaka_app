// Tests for the on-device Translation Builder engine.
//
// Coverage (pure-logic parts, no network):
//   * heading-based sectioning merges small sections
//   * token-safe chunking splits oversized paragraphs
//   * parseAiTranslationResult parses the AI JSON (incl. truncated output)
//   * script-bleed guard flags Lao/Thai confusion
//   * pending-line discovery skips already-translated lines
//   * glossary stem resolution + skip terms
//   * save translations / remarks / glossary into the target DB
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/utils/pali_search_utils.dart';
import 'package:epitaka/features/translator/services/translator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory Tipiṭaka fixture (same shape as the app's bundled DBs).
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
  return db;
}

/// In-memory target-language translation DB (server schema).
Future<TranslationDatabase> _fixtureLangDb() async {
  return TranslationDatabase(NativeDatabase.memory());
}

void main() {
  group('chunkParagraphs — token-safe chunking', () {
    test('groups paragraphs within the token budget', () {
      final paras = [
        for (var i = 1; i <= 10; i++)
          TParagraph(
            paraId: i,
            sentences: [TLine(lineId: 1, pali: 'a' * 200)],
            pending: [TLine(lineId: 1, pali: 'a' * 200)],
          ),
      ];
      // Each para ≈ 50 tokens; budget 3000 → all in one chunk.
      final chunks = chunkParagraphs(paras, maxTokens: 3000);
      expect(chunks, hasLength(1));
      expect(chunks.first, hasLength(10));
    });

    test('splits a single oversized paragraph at sentence level', () {
      final longPara = TParagraph(
        paraId: 1,
        sentences: [
          for (var i = 1; i <= 100; i++) TLine(lineId: i, pali: 'a' * 200),
        ],
        pending: [
          for (var i = 1; i <= 100; i++) TLine(lineId: i, pali: 'a' * 200),
        ],
      );
      final chunks = chunkParagraphs([longPara], maxTokens: 3000);
      // 100 sentences × 50 tokens = 5000 tokens → must split.
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        final tokens = chunk
            .expand((p) => p.pending)
            .fold<int>(0, (sum, s) => sum + s.pali.length ~/ 4);
        expect(tokens, lessThanOrEqualTo(3000));
      }
    });

    test('chunkParagraphsTokens estimates the chunk token budget', () {
      final chunk = [
        TParagraph(
          paraId: 1,
          sentences: [TLine(lineId: 1, pali: 'abcd' * 4)], // 16 chars = 4 tok
          pending: [TLine(lineId: 1, pali: 'abcd' * 4)],
        ),
        TParagraph(
          paraId: 2,
          sentences: [TLine(lineId: 1, pali: 'efgh' * 8)], // 32 chars = 8 tok
          pending: [TLine(lineId: 1, pali: 'efgh' * 8)],
        ),
      ];
      expect(chunkParagraphsTokens(chunk), 12); // 4 + 8
    });

    test('caps chunks by line count (the main batching knob)', () {
      // 10 paragraphs × 6 sentences each = 60 pending lines; tiny tokens.
      final paras = [
        for (var i = 1; i <= 10; i++)
          TParagraph(
            paraId: i,
            sentences: [
              for (var j = 1; j <= 6; j++) TLine(lineId: j, pali: 'a'),
            ],
            pending: [
              for (var j = 1; j <= 6; j++) TLine(lineId: j, pali: 'a'),
            ],
          ),
      ];
      // Token budget huge so only the line cap matters.
      final chunks = chunkParagraphs(paras, maxTokens: 250000, maxLines: 25);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        final lines = chunk.fold<int>(
          0,
          (sum, p) => sum + p.pending.length,
        );
        expect(lines, lessThanOrEqualTo(25));
      }
    });

    test('splits a single oversized paragraph by line count too', () {
      // One paragraph with 40 sentences; line cap 25 must split it.
      final para = TParagraph(
        paraId: 1,
        sentences: [
          for (var j = 1; j <= 40; j++) TLine(lineId: j, pali: 'aa'),
        ],
        pending: [
          for (var j = 1; j <= 40; j++) TLine(lineId: j, pali: 'aa'),
        ],
      );
      final chunks = chunkParagraphs([para], maxTokens: 250000, maxLines: 25);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        final lines = chunk.fold<int>(
          0,
          (sum, p) => sum + p.pending.length,
        );
        expect(lines, lessThanOrEqualTo(25));
      }
    });
  });

  group('splitChunkInHalf', () {
    test('splits between paragraphs when there are several', () {
      final chunk = [
        for (var i = 1; i <= 4; i++)
          TParagraph(
            paraId: i,
            sentences: [TLine(lineId: 1, pali: 'aa')],
            pending: [TLine(lineId: 1, pali: 'aa')],
          ),
      ];
      final halves = splitChunkInHalf(chunk)!;
      expect(halves, hasLength(2));
      expect(halves[0], hasLength(2));
      expect(halves[1], hasLength(2));
    });

    test('splits a single paragraph at the sentence level', () {
      final chunk = [
        TParagraph(
          paraId: 1,
          sentences: [
            for (var j = 1; j <= 4; j++) TLine(lineId: j, pali: 'aa'),
          ],
          pending: [
            for (var j = 1; j <= 4; j++) TLine(lineId: j, pali: 'aa'),
          ],
        ),
      ];
      final halves = splitChunkInHalf(chunk)!;
      expect(halves, hasLength(2));
      expect(halves[0][0].pending, hasLength(2));
      expect(halves[1][0].pending, hasLength(2));
      expect(halves[0][0].paraId, 1);
    });

    test('returns null for a single sentence (can\'t shrink further)', () {
      final chunk = [
        TParagraph(
          paraId: 1,
          sentences: [TLine(lineId: 1, pali: 'aa')],
          pending: [TLine(lineId: 1, pali: 'aa')],
        ),
      ];
      expect(splitChunkInHalf(chunk), isNull);
    });
  });

  group('mergeSmallSections', () {
    test('merges adjacent sections under both caps', () {
      final sections = [
        [
          TParagraph(
            paraId: 1,
            sentences: [TLine(lineId: 1, pali: 'aaa')],
            pending: [TLine(lineId: 1, pali: 'aaa')],
          ),
        ],
        [
          TParagraph(
            paraId: 2,
            sentences: [TLine(lineId: 1, pali: 'bbb')],
            pending: [TLine(lineId: 1, pali: 'bbb')],
          ),
        ],
      ];
      final merged = mergeSmallSections(sections);
      expect(merged, hasLength(1));
      expect(merged.first, hasLength(2));
    });

    test('does not merge when the line cap would be exceeded', () {
      final big = [
        for (var i = 1; i <= 40; i++)
          TParagraph(
            paraId: i,
            sentences: [TLine(lineId: 1, pali: 'aaa')],
            pending: [TLine(lineId: 1, pali: 'aaa')],
          ),
      ];
      final next = [
        TParagraph(
          paraId: 100,
          sentences: [TLine(lineId: 1, pali: 'bbb')],
          pending: [TLine(lineId: 1, pali: 'bbb')],
        ),
      ];
      final merged = mergeSmallSections([big, next], maxLines: 30);
      expect(merged, hasLength(2));
    });
  });

  group('parseAiTranslationResult', () {
    test('parses a well-formed response', () {
      const raw = '''
{
  "translations": [
    {"para_id": 1, "line_id": 2, "translation": "All things are impermanent",
     "confidence": "high"}
  ],
  "glossary": [
    {"pali": "saṅkhāra", "translation": "conditioned things", "domain": "sutta"}
  ],
  "remarks": [
    {"para_id": 1, "line_id": 2, "pali": "sabbe", "conflict": "x", "note": "y"}
  ]
}
''';
      final r = parseAiTranslationResult(raw);
      expect(r.translations, hasLength(1));
      expect(r.translations.first.paraId, 1);
      expect(r.translations.first.lineId, 2);
      expect(r.translations.first.confidence, 'high');
      expect(r.glossary, hasLength(1));
      expect(r.glossary.first.pali, 'saṅkhāra');
      expect(r.remarks, hasLength(1));
    });

    test('salvages items from truncated output', () {
      // Response cut off mid-array — the complete items must survive.
      const raw = '''
{"translations": [
  {"para_id": 1, "line_id": 1, "translation": "First", "confidence": "high"},
  {"para_id": 1, "line_id": 2, "translation": "Second", "confidence": "low",
   "confidence_note": "ambiguous"},
  {"para_id": 1, "line_id": 3, "translation": "Trunc
''';
      final r = parseAiTranslationResult(raw);
      expect(r.translations, hasLength(2));
      expect(r.translations[1].confidence, 'low');
      expect(r.translations[1].confidenceNote, 'ambiguous');
    });

    test('handles markdown fences', () {
      const raw = '```json\n{"translations": [{"para_id": 1, "line_id": 1, '
          '"translation": "x"}]}\n```';
      final r = parseAiTranslationResult(raw);
      expect(r.translations, hasLength(1));
    });
  });

  group('checkTranslationsForScriptBleed', () {
    test('flags Lao-looking text when translating to Thai', () {
      final translations = [
        const TTranslation(
          paraId: 1,
          lineId: 1,
          text: 'ສັບພະທຳມະມີຄວາມບໍ່ແນ່ນອນ', // Lao script
        ),
        const TTranslation(
          paraId: 1,
          lineId: 2,
          text: 'สิ่งทั้งหลายไม่เที่ยง', // Thai
        ),
      ];
      final flagged = checkTranslationsForScriptBleed('th', translations);
      expect(flagged, hasLength(1));
      expect(flagged.first.confidence, 'low');
      expect(flagged.first.confidenceNote, contains('SCRIPT-BLEED'));
    });

    test('does not flag matching script', () {
      const translations = [
        TTranslation(paraId: 1, lineId: 1, text: 'สิ่งทั้งหลายไม่เที่ยง'),
      ];
      expect(checkTranslationsForScriptBleed('th', translations), isEmpty);
    });
  });

  group('save layer', () {
    test('saveTranslations upserts and skip-blocks already-written lines',
        () async {
      final langDb = await _fixtureLangDb();
      addTearDown(langDb.close);
      await ensureTranslatorTables(langDb);

      final saved = await saveTranslations(langDb, 'dn1', const [
        TTranslation(paraId: 1, lineId: 1, text: 'first', confidence: 'high'),
        TTranslation(paraId: 1, lineId: 2, text: 'second', confidence: 'low'),
      ]);
      expect(saved, 2);

      final rows = await langDb.customSelect(
        'SELECT para_id, line_id, translation, translation_confidence '
        'FROM sentences ORDER BY line_id',
      ).get();
      expect(rows, hasLength(2));
      expect(rows[0].data['translation'], 'first');
      expect(rows[1].data['translation_confidence'], 'low');

      // Upsert on the same key updates, doesn't duplicate.
      await saveTranslations(langDb, 'dn1', const [
        TTranslation(paraId: 1, lineId: 1, text: 'first-updated'),
      ]);
      final after = await langDb.customSelect(
        'SELECT COUNT(*) AS n FROM sentences',
      ).get();
      expect(after.first.data['n'], 2);
    });

    test('saveGlossaryTerms canonicalises stems and skips particles',
        () async {
      final epiDb = await _fixtureEpitakaDb();
      addTearDown(epiDb.close);
      final langDb = await _fixtureLangDb();
      addTearDown(langDb.close);
      await ensureTranslatorTables(langDb);

      // No dictionary tables in the fixture → stems stay as given; particles
      // are dropped.
      final saved = await saveGlossaryTerms(langDb, epiDb, const [
        TGlossaryTerm(pali: 'samādhi', translation: 'concentration'),
        TGlossaryTerm(pali: 'ca', translation: 'and'),
        TGlossaryTerm(pali: 'va', translation: 'like'),
      ]);
      expect(saved, 1);

      final rows = await langDb.customSelect(
        'SELECT pali, translation FROM glossary',
      ).get();
      expect(rows, hasLength(1));
      expect(rows.first.data['pali'], 'samādhi');
    });
  });

  group('diacritic-free book search (book picker)', () {
    test('pācittiya matches pacittiya and vice versa', () {
      // The book picker filters with normalizePaliFuzzy on both sides.
      final query = normalizePaliFuzzy('pacittiya');
      expect(normalizePaliFuzzy('Pācittiya').contains(query), isTrue);
      expect(normalizePaliFuzzy('pācittiyā').contains(query), isTrue);
      expect(normalizePaliFuzzy('Pācittiya Pakiṇṇaka').contains(query),
          isTrue);
      expect(normalizePaliFuzzy('Vinaya Piṭaka').contains(query), isFalse);
    });

    test('saṃyutta/saṅkhāra-type diacritics normalize to base letters', () {
      final query = normalizePaliFuzzy('samyutta');
      expect(normalizePaliFuzzy('Saṃyutta').contains(query), isTrue);
      final q2 = normalizePaliFuzzy('sankhara');
      expect(normalizePaliFuzzy('Saṅkhāra').contains(q2), isTrue);
    });
  });

  group('pending-line discovery', () {
    test('skips lines already translated when overwrite is off', () async {
      final epiDb = await _fixtureEpitakaDb();
      addTearDown(epiDb.close);
      for (var i = 1; i <= 3; i++) {
        await epiDb.customStatement(
          'INSERT INTO sentences(book_id, para_id, line_id, pali) '
          'VALUES (?, ?, ?, ?)',
          ['dn1', i, 1, 'sentence number $i'],
        );
      }
      final langDb = await _fixtureLangDb();
      addTearDown(langDb.close);
      await ensureTranslatorTables(langDb);
      await saveTranslations(langDb, 'dn1', const [
        TTranslation(paraId: 2, lineId: 1, text: 'done'),
      ]);

      final paras = await fetchParagraphsRange(
        epiDb,
        langDb,
        'dn1',
        1,
        3,
        overwrite: false,
      );
      expect(paras, hasLength(2)); // paras 1 and 3 pending; 2 translated.
      expect(paras.map((p) => p.paraId), [1, 3]);
    });

    test('keeps everything when overwrite is on', () async {
      final epiDb = await _fixtureEpitakaDb();
      addTearDown(epiDb.close);
      for (var i = 1; i <= 3; i++) {
        await epiDb.customStatement(
          'INSERT INTO sentences(book_id, para_id, line_id, pali) '
          'VALUES (?, ?, ?, ?)',
          ['dn1', i, 1, 'sentence number $i'],
        );
      }
      final langDb = await _fixtureLangDb();
      addTearDown(langDb.close);
      await ensureTranslatorTables(langDb);
      await saveTranslations(langDb, 'dn1', const [
        TTranslation(paraId: 2, lineId: 1, text: 'done'),
      ]);

      final paras = await fetchParagraphsRange(
        epiDb,
        langDb,
        'dn1',
        1,
        3,
        overwrite: true,
      );
      expect(paras, hasLength(3));
    });

    test('skips bare punctuation / number placeholder lines', () async {
      final epiDb = await _fixtureEpitakaDb();
      addTearDown(epiDb.close);
      await epiDb.customStatement(
        'INSERT INTO sentences(book_id, para_id, line_id, pali) '
        'VALUES (?, ?, ?, ?)',
        ['dn1', 1, 1, '.'],
      );
      await epiDb.customStatement(
        'INSERT INTO sentences(book_id, para_id, line_id, pali) '
        'VALUES (?, ?, ?, ?)',
        ['dn1', 1, 2, '20.'],
      );
      await epiDb.customStatement(
        'INSERT INTO sentences(book_id, para_id, line_id, pali) '
        'VALUES (?, ?, ?, ?)',
        ['dn1', 1, 3, 'evam me sutaṃ'],
      );

      final paras = await fetchParagraphsRange(
        epiDb,
        null,
        'dn1',
        1,
        1,
        overwrite: false,
      );
      expect(paras, hasLength(1));
      // '.' (1 char) is skipped; '20.' (3 chars) and the real sentence are
      // pending — matches the server's `len(pali.strip()) >= 3` rule.
      expect(paras.first.pending.map((s) => s.lineId), [2, 3]);
    });
  });
}
