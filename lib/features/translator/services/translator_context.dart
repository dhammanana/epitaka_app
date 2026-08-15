// lib/features/translator/services/translator_context.dart
//
// Prompt-context builders — the on-device port of the server's
// context_builders.py, scoped per the product decision:
//
//   * Parallel references: ENGLISH ONLY (epitaka_en.db). No Thai / Sinhala.
//   * No Nissaya context.
//   * Everything else kept: established glossary (stemmed), commentary /
//     sub-commentary WITH the explicit src→dst link direction, Pāli word
//     definitions, previous-paragraph translation, and translated
//     mūla/aṭṭhakathā/ṭīkā references.
//
// Each builder returns a labelled text block; empty blocks degrade to
// "(no … available)" so the prompt stays well-formed.

import 'package:drift/drift.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';

/// Wraps content with the bar + label decoration used by every block.
String wrapContextBlock(String label, String content) {
  final bar = '═' * 30;
  return '$bar\n$label\n$bar\n$content';
}

// ═══════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════

/// Look up translations for specific (book_id, para_id, line_id) triples in
/// the target DB, then fill gaps from the English reference DB.
Future<Map<(String, int, int), String>> fetchLangTranslationsWithFallback({
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required List<(String, int, int)> triples,
}) async {
  final result = <(String, int, int), String>{};
  if (langDb != null && triples.isNotEmpty) {
    try {
      final rows = await _queryTripleTranslations(langDb, triples);
      for (final r in rows) {
        if (r.translation.trim().isNotEmpty) {
          result[(r.bookId, r.paraId, r.lineId)] = r.translation;
        }
      }
    } catch (_) {
      // Target DB may not have this section — skip silently.
    }
  }

  if (enDb != null && triples.isNotEmpty) {
    final missing = triples
        .where((t) => (result[t] ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      try {
        final rows = await _queryTripleTranslations(enDb, missing);
        for (final r in rows) {
          if (r.translation.trim().isNotEmpty) {
            result[(r.bookId, r.paraId, r.lineId)] = r.translation;
          }
        }
      } catch (_) {
        // English reference missing — skip.
      }
    }
  }
  return result;
}

/// Query translations for (book_id, para_id, line_id) triples in batches of
/// 90 to stay well under SQLite's variable limit (default 999/32766).
Future<List<({String bookId, int paraId, int lineId, String translation})>>
    _queryTripleTranslations(
  TranslationDatabase db,
  List<(String, int, int)> triples,
) async {
  final result = <({String bookId, int paraId, int lineId, String translation})>[];
  const batchSize = 90;
  for (var i = 0; i < triples.length; i += batchSize) {
    final batch = triples.sublist(
      i,
      i + batchSize > triples.length ? triples.length : i + batchSize,
    );
    final rows = await db.customSelect(
      'SELECT book_id, para_id, line_id, translation FROM sentences '
      'WHERE (book_id, para_id, line_id) IN '
      '(VALUES ${List.filled(batch.length, '(?, ?, ?)').join(', ')})',
      variables: [
        for (final (b, p, l) in batch) ...[Variable.withString(b), Variable.withInt(p), Variable.withInt(l)],
      ],
    ).get();
    for (final r in rows) {
      result.add((
        bookId: r.data['book_id'] as String,
        paraId: r.data['para_id'] as int,
        lineId: r.data['line_id'] as int,
        translation: r.data['translation'] as String? ?? '',
      ));
    }
  }
  return result;
}

/// Look up translations for a whole paragraph range in the target DB +
/// English fallback, keyed by (para_id, line_id).
Future<Map<(int, int), String>> fetchLangTranslationsRangeWithFallback({
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required String bookId,
  required int paraLo,
  required int paraHi,
}) async {
  final result = <(int, int), String>{};
  if (langDb != null) {
    try {
      final rows = await langDb.customSelect(
        'SELECT para_id, line_id, translation FROM sentences '
        'WHERE book_id = ? AND para_id BETWEEN ? AND ?',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraLo),
          Variable.withInt(paraHi),
        ],
      ).get();
      for (final r in rows) {
        final text = r.data['translation'] as String? ?? '';
        if (text.trim().isNotEmpty) {
          result[(r.data['para_id'] as int, r.data['line_id'] as int)] = text;
        }
      }
    } catch (_) {}
  }
  if (enDb != null) {
    try {
      final rows = await enDb.customSelect(
        'SELECT para_id, line_id, translation FROM sentences '
        'WHERE book_id = ? AND para_id BETWEEN ? AND ?',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraLo),
          Variable.withInt(paraHi),
        ],
      ).get();
      for (final r in rows) {
        final key = (r.data['para_id'] as int, r.data['line_id'] as int);
        if ((result[key] ?? '').trim().isEmpty) {
          final text = r.data['translation'] as String? ?? '';
          if (text.trim().isNotEmpty) result[key] = text;
        }
      }
    } catch (_) {}
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════════
// 1. Glossary context (stemmed)
// ═══════════════════════════════════════════════════════════════════

final _glossaryStemCache = <String, String>{};

List<String> _tokenizePali(String text) {
  final parts = text.split(
    RegExp(r"[\s,;.\u2018\u2019'()\[\]]+"),
  );
  return [
    for (final t in parts)
      if (t.length > 1) t.toLowerCase(),
  ];
}

Set<String> _extractPhraseNgrams(List<String> tokens, int maxN) {
  final ngrams = <String>{};
  for (var n = 2; n <= maxN; n++) {
    for (var i = 0; i + n <= tokens.length; i++) {
      ngrams.add(tokens.sublist(i, i + n).join(' '));
    }
  }
  return ngrams;
}

/// Resolve many words to Pāli stems using batched queries + cache.
Future<Map<String, String>> _resolveStemsBatch(
  EpitakaDatabase db,
  List<String> words,
) async {
  final result = <String, String>{};
  final remaining = <String>{};

  for (final w in words) {
    final cached = _glossaryStemCache[w];
    if (cached != null) {
      result[w] = cached;
    } else {
      remaining.add(w);
    }
  }
  if (remaining.isEmpty) return result;

  final remainingList = remaining.toList();
  try {
    // 1) dpd_inflections_to_headwords
    final ph = List.filled(remainingList.length, '?').join(',');
    final rows = await db.customSelect(
      'SELECT inflection, headwords FROM dpd_inflections_to_headwords '
      'WHERE inflection IN ($ph)',
      variables: [for (final w in remainingList) Variable.withString(w)],
    ).get();
    for (final r in rows) {
      final headwords = r.data['headwords'] as String?;
      if (headwords == null || headwords.isEmpty) continue;
      final dpdWord = headwords.split(',')[0].replaceAll(RegExp(r"['\[\]\d\s]"), '');
      if (dpdWord.isEmpty) continue;
      final inf = r.data['inflection'] as String;
      result[inf] = dpdWord;
      _glossaryStemCache[inf] = dpdWord;
      remaining.remove(inf);
    }

    // 2) pali_definition (plain or word -> canonical word)
    if (remaining.isNotEmpty) {
      final rem = remaining.toList();
      final ph2 = List.filled(rem.length, '?').join(',');
      final rows2 = await db.customSelect(
        'SELECT plain, word FROM pali_definition '
        'WHERE plain IN ($ph2) OR word IN ($ph2)',
        variables: [
          for (final w in rem) Variable.withString(w),
          for (final w in rem) Variable.withString(w),
        ],
      ).get();
      for (final r in rows2) {
        final word = r.data['word'] as String?;
        if (word == null || word.isEmpty) continue;
        for (final key in [r.data['plain'] as String?, word]) {
          if (key != null && remaining.contains(key)) {
            result[key] = word;
            _glossaryStemCache[key] = word;
            remaining.remove(key);
          }
        }
      }
    }

    // 3) dpr_stem
    if (remaining.isNotEmpty) {
      final rem = remaining.toList();
      final ph3 = List.filled(rem.length, '?').join(',');
      final rows3 = await db.customSelect(
        'SELECT word, stem FROM dpr_stem WHERE word IN ($ph3)',
        variables: [for (final w in rem) Variable.withString(w)],
      ).get();
      for (final r in rows3) {
        final stem = r.data['stem'] as String?;
        final w = r.data['word'] as String;
        if (stem != null && stem.isNotEmpty && remaining.contains(w)) {
          result[w] = stem;
          _glossaryStemCache[w] = stem;
          remaining.remove(w);
        }
      }
    }

    // Unresolved: fall back to the surface form (not cached).
    for (final w in remaining) {
      result[w] = w;
    }
  } catch (_) {
    for (final w in remaining) {
      result[w] = w;
    }
  }
  return result;
}

List<String> _formatGlossaryGrouped(
  List<({String pali, String translation, String context})> entries,
) {
  final grouped = <String, List<({String pali, String translation, String context})>>{};
  for (final e in entries) {
    grouped.putIfAbsent(e.pali, () => []).add(e);
  }
  final lines = <String>[];
  for (final entry in grouped.entries) {
    final shown = entry.value.take(3).toList();
    final extra = entry.value.length - shown.length;
    for (final r in shown) {
      var line = '  ${r.pali} → ${r.translation}';
      if (r.context.isNotEmpty) line += '  [${r.context}]';
      lines.add(line);
    }
    if (extra > 0) {
      lines.add(
        "  ($extra more existing variant(s) for '${entry.key}' omitted — "
        'reuse one of the above rather than adding another)',
      );
    }
  }
  return lines;
}

/// Established glossary block: resolve chunk tokens to stems, look up the
/// glossary table in the target DB.
Future<String> buildGlossaryBlock({
  required EpitakaDatabase epitakaDb,
  required TranslationDatabase? langDb,
  required String paliText,
  int maxN = 5,
}) async {
  final cleaned = paliText.replaceAll("’ ’ ti", 'ti').replaceAll('‘‘ ', '');
  final tokens = _tokenizePali(cleaned);
  if (tokens.isEmpty) {
    return wrapContextBlock(
      'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
      '(no existing glossary entries)',
    );
  }

  final distinct = tokens.toSet().toList();
  final wordToStem = await _resolveStemsBatch(epitakaDb, distinct);
  final stems = wordToStem.values.toSet();
  final phrases = _extractPhraseNgrams(tokens, maxN);
  final lookupTerms = {...stems, ...phrases};
  if (lookupTerms.isEmpty) {
    return wrapContextBlock(
      'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
      '(no existing glossary entries)',
    );
  }

  if (langDb == null) {
    return wrapContextBlock(
      'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
      '(no matching glossary entries yet)',
    );
  }

  try {
    final termList = lookupTerms.toList();
    final ph = List.filled(termList.length, '?').join(',');
    final rows = await langDb.customSelect(
      'SELECT pali, translation, context FROM glossary WHERE pali IN ($ph)',
      variables: [for (final t in termList) Variable.withString(t)],
    ).get();
    final entries = [
      for (final r in rows)
        (
          pali: r.data['pali'] as String,
          translation: r.data['translation'] as String? ?? '',
          context: r.data['context'] as String? ?? '',
        ),
    ];
    if (entries.isEmpty) {
      return wrapContextBlock(
        'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
        '(no matching glossary entries yet)',
      );
    }
    final lines = _formatGlossaryGrouped(entries);
    return wrapContextBlock(
      'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
      lines.join('\n'),
    );
  } catch (_) {
    return wrapContextBlock(
      'ESTABLISHED GLOSSARY (apply exactly, including multi-word phrases)',
      '(glossary unavailable)',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. Commentary context (with explicit src→dst link direction)
// ═══════════════════════════════════════════════════════════════════

Future<List<({String bookId, int paraId, int lineId, String pali})>>
    _fetchParagraphRows(
  EpitakaDatabase db,
  List<(String, int)> pairs,
) async {
  if (pairs.isEmpty) return [];
  final rows = await db.customSelect(
    'SELECT book_id, para_id, line_id, pali FROM sentences '
    'WHERE (book_id, para_id) IN '
    '(VALUES ${List.filled(pairs.length, '(?, ?)').join(', ')}) '
    'ORDER BY book_id, para_id, line_id',
    variables: [
      for (final (b, p) in pairs) ...[
        Variable.withString(b),
        Variable.withInt(p),
      ],
    ],
  ).get();
  return [
    for (final r in rows)
      (
        bookId: r.data['book_id'] as String,
        paraId: r.data['para_id'] as int,
        lineId: r.data['line_id'] as int,
        pali: r.data['pali'] as String? ?? '',
      ),
  ];
}

Future<List<({String bookId, int paraId, int lineId, String pali})>>
    _fetchExactLines(
  EpitakaDatabase db,
  List<(String, int, int)> triples,
) async {
  if (triples.isEmpty) return [];
  final rows = await db.customSelect(
    'SELECT book_id, para_id, line_id, pali FROM sentences '
    'WHERE (book_id, para_id, line_id) IN '
    '(VALUES ${List.filled(triples.length, '(?, ?, ?)').join(', ')}) '
    'ORDER BY book_id, para_id, line_id',
    variables: [
      for (final (b, p, l) in triples) ...[
        Variable.withString(b),
        Variable.withInt(p),
        Variable.withInt(l),
      ],
    ],
  ).get();
  return [
    for (final r in rows)
      (
        bookId: r.data['book_id'] as String,
        paraId: r.data['para_id'] as int,
        lineId: r.data['line_id'] as int,
        pali: r.data['pali'] as String? ?? '',
      ),
  ];
}

String _renderRows(
  List<({String bookId, int paraId, int lineId, String pali})> rows,
  Map<(String, int, int), String> langMap,
  String label,
) {
  if (rows.isEmpty) return '';
  final sections = <String, List<String>>{};
  for (final r in rows) {
    final en = (langMap[(r.bookId, r.paraId, r.lineId)] ?? '').trim();
    var line = '  [${r.lineId}] ${r.pali}';
    if (en.isNotEmpty) line += '\n          EN: $en';
    sections.putIfAbsent('${r.bookId}|${r.paraId}', () => []).add(line);
  }
  final parts = <String>[label];
  for (final entry in sections.entries) {
    final keyParts = entry.key.split('|');
    final book = keyParts[0];
    final para = keyParts[1];
    parts.add('\n[$book §$para]');
    parts.addAll(entry.value);
  }
  return parts.join('\n');
}

/// Commentary + sub-commentary block: forward (src→dst), reverse (mūla),
/// and sibling commentary, each with the link direction made explicit and
/// English translations overlaid where available.
Future<String> buildCommentaryBlock({
  required EpitakaDatabase db,
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required String bookId,
  required int paraStart,
  required int paraEnd,
  int maxChars = 6000,
}) async {
  const label = 'PALI COMMENTARY & SUB-COMMENTARY';
  try {
    final hasLinks = await db.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='book_links' LIMIT 1",
    ).get();
    if (hasLinks.isEmpty) {
      return wrapContextBlock(label, '(no commentary available)');
    }

    // A. Forward: this book/para is the src → find dst (commentary).
    var forwardResult = '';
    {
      final fwdRows = await db.customSelect(
        'SELECT dst_book, dst_para, dst_line FROM book_links '
        'WHERE src_book = ? AND src_para BETWEEN ? AND ? '
        'ORDER BY dst_book, dst_para, dst_line',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraStart),
          Variable.withInt(paraEnd),
        ],
      ).get();

      if (fwdRows.isNotEmpty) {
        final seen = <(String, int, int)>{};
        for (final r in fwdRows) {
          seen.add((
            r.data['dst_book'] as String,
            r.data['dst_para'] as int,
            r.data['dst_line'] as int,
          ));
        }
        final targets = seen.toList();
        final uniqueParas = <(String, int)>[];
        for (final (b, p, _) in targets) {
          if (!uniqueParas.contains((b, p))) uniqueParas.add((b, p));
        }
        final rows = await _fetchParagraphRows(db, uniqueParas);
        final triplesForLang = [
          for (final r in rows) (r.bookId, r.paraId, r.lineId),
        ];
        final langMap = await fetchLangTranslationsWithFallback(
          langDb: langDb,
          enDb: enDb,
          triples: triplesForLang,
        );
        forwardResult = _renderRows(
          rows,
          langMap,
          '[Commentary / Sub-commentary — full paragraphs] '
          '(MŪLA §para → AṬṬHAKATHĀ §para)',
        );

        if (forwardResult.length > maxChars) {
          // 3-line window fallback.
          final window = <(String, int, int)>{};
          for (final (b, p, l) in targets) {
            for (final off in [-1, 0, 1]) {
              window.add((b, p, l + off));
            }
          }
          final winRows = await _fetchExactLines(db, window.toList());
          final winLang = await fetchLangTranslationsWithFallback(
            langDb: langDb,
            enDb: enDb,
            triples: [for (final r in winRows) (r.bookId, r.paraId, r.lineId)],
          );
          forwardResult = _renderRows(
            winRows,
            winLang,
            '[Commentary / Sub-commentary — 3-line window]',
          );
        }
        if (forwardResult.length > maxChars) {
          final exactRows = await _fetchExactLines(db, targets);
          final exactLang = await fetchLangTranslationsWithFallback(
            langDb: langDb,
            enDb: enDb,
            triples: [for (final r in exactRows) (r.bookId, r.paraId, r.lineId)],
          );
          forwardResult = _renderRows(
            exactRows,
            exactLang,
            '[Commentary / Sub-commentary — linked lines only]',
          );
        }
      }
    }

    // B. Reverse: this book/para is the dst → find the mūla source.
    final revRows = await db.customSelect(
      'SELECT DISTINCT src_book, src_para FROM book_links '
      'WHERE dst_book = ? AND dst_para BETWEEN ? AND ? '
      'ORDER BY src_book, src_para',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
        Variable.withInt(paraEnd),
      ],
    ).get();

    var mulaResult = '';
    final revPairs = <(String, int)>[];
    if (revRows.isNotEmpty) {
      for (final r in revRows) {
        revPairs.add((r.data['src_book'] as String, r.data['src_para'] as int));
      }
      final mulaRows = await _fetchParagraphRows(db, revPairs);
      final mulaLang = await fetchLangTranslationsWithFallback(
        langDb: langDb,
        enDb: enDb,
        triples: [for (final r in mulaRows) (r.bookId, r.paraId, r.lineId)],
      );
      mulaResult = _renderRows(
        mulaRows,
        mulaLang,
        '[Mūla / Source Text — for translation consistency] '
        '(the mūla defines the term this commentary explains)',
      );
      if (mulaResult.length > maxChars) {
        mulaResult =
            '${mulaResult.substring(0, maxChars)}\n[... truncated for length ...]';
      }
    }

    // C. Sibling: from the mūla src paragraphs, resolve their forward links.
    var siblingResult = '';
    if (revPairs.isNotEmpty) {
      final sibRows = await db.customSelect(
        'SELECT DISTINCT dst_book, dst_para FROM book_links '
        'WHERE (src_book, src_para) IN '
        '(VALUES ${List.filled(revPairs.length, '(?, ?)').join(', ')}) '
        'AND dst_book != ? '
        'ORDER BY dst_book, dst_para',
        variables: [
          for (final (b, p) in revPairs) ...[
            Variable.withString(b),
            Variable.withInt(p),
          ],
          Variable.withString(bookId),
        ],
      ).get();
      if (sibRows.isNotEmpty) {
        final sibPairs = [
          for (final r in sibRows)
            (r.data['dst_book'] as String, r.data['dst_para'] as int),
        ];
        final sibRows2 = await _fetchParagraphRows(db, sibPairs);
        final sibLang = await fetchLangTranslationsWithFallback(
          langDb: langDb,
          enDb: enDb,
          triples: [for (final r in sibRows2) (r.bookId, r.paraId, r.lineId)],
        );
        siblingResult = _renderRows(
          sibRows2,
          sibLang,
          '[Sibling Commentary — shares the same mūla source]',
        );
        if (siblingResult.length > maxChars ~/ 2) {
          siblingResult =
              '${siblingResult.substring(0, maxChars ~/ 2)}\n[... truncated for length ...]';
        }
      }
    }

    final sections = [
      for (final s in [forwardResult, mulaResult, siblingResult])
        if (s.trim().isNotEmpty) s,
    ];
    if (sections.isEmpty) {
      return wrapContextBlock(label, '(no commentary available)');
    }
    return wrapContextBlock(label, sections.join('\n\n'));
  } catch (_) {
    return wrapContextBlock(label, '(no commentary available)');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. Pāli word definitions (rarest words in the chunk)
// ═══════════════════════════════════════════════════════════════════

final _paliWordListCache = <String, List<String>>{};

Future<List<String>> _loadWordList(EpitakaDatabase db) async {
  final cached = _paliWordListCache['default'];
  if (cached != null) return cached;
  final rows = await db.customSelect(
    "SELECT DISTINCT word FROM pali_definition "
    "WHERE word IS NOT NULL AND word != ''",
  ).get();
  final words = rows.map((r) => r.data['word'] as String).toSet().toList()..sort();
  _paliWordListCache['default'] = words;
  return words;
}

List<String> _prefixMatches(List<String> sorted, String prefix) {
  if (prefix.isEmpty) return [];
  final lo = _lowerBound(sorted, prefix);
  final hi = _upperBound(sorted, '$prefix\uffff');
  if (lo >= hi) return [];
  return sorted.sublist(lo, hi);
}

int _lowerBound(List<String> list, String value) {
  var lo = 0, hi = list.length;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (list[mid].compareTo(value) < 0) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

int _upperBound(List<String> list, String value) {
  var lo = 0, hi = list.length;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (list[mid].compareTo(value) <= 0) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

const _paliVowels = 'aāiīuūeo';

String _searchPrefix(String word) {
  if (word.length >= 2 && word.endsWith('ṃ') && _paliVowels.contains(word[word.length - 2])) {
    return word.substring(0, word.length - 2);
  }
  if (word.isNotEmpty && _paliVowels.contains(word[word.length - 1])) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Pāli word definitions block: pick the rarest words in the chunk and look
/// up their headword definitions (with surrounding sentence context).
Future<String> buildPaliDefsBlock({
  required EpitakaDatabase db,
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required String paliText,
  int maxWords = 50,
}) async {
  const label = 'PALI WORD DEFINITIONS (reference for difficult/rare terms)';
  try {
    final hasDefs = await db.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='pali_definition' LIMIT 1",
    ).get();
    if (hasDefs.isEmpty) {
      return wrapContextBlock(label, '(no word definitions available)');
    }

    final cleaned = paliText.replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('*', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    final words = RegExp(r'\b[\w\u0900-\u097F]{5,}\b')
        .allMatches(cleaned)
        .map((m) => m.group(0)!.toLowerCase())
        .toSet()
        .toList();
    if (words.isEmpty) {
      return wrapContextBlock(label, '(no word definitions available)');
    }

    final wordList = await _loadWordList(db);
    if (wordList.isEmpty) {
      return wrapContextBlock(label, '(no word definitions available)');
    }

    // Rank by rarity: unknown/short words first (we don't have the server's
    // global frequency DB on-device, so approximate rarity by word length —
    // longer Pāli words are typically rarer).
    words.sort((a, b) => a.length.compareTo(b.length));
    final ranked = words.take(maxWords).toList();

    final wordToStems = <String, List<String>>{};
    for (final word in ranked) {
      var matches = _prefixMatches(wordList, _searchPrefix(word));
      if (matches.isEmpty) continue;
      if (matches.length > 1) {
        matches.sort((a, b) => a.length.compareTo(b.length));
        matches = matches.take(3).toList();
      }
      wordToStems[word] = matches;
    }
    if (wordToStems.isEmpty) {
      return wrapContextBlock(label, '(no word definitions found)');
    }

    final stems = wordToStems.values.expand((s) => s).toSet().toList();
    final ph = List.filled(stems.length, '?').join(',');
    final locRows = await db.customSelect(
      'SELECT word AS stem, book_id, para_id, line_id FROM pali_definition '
      'WHERE word IN ($ph) GROUP BY word',
      variables: [for (final s in stems) Variable.withString(s)],
    ).get();
    final stemToLoc = <String, (String, int, int)>{};
    for (final r in locRows) {
      stemToLoc[r.data['stem'] as String] = (
        r.data['book_id'] as String,
        r.data['para_id'] as int,
        r.data['line_id'] as int,
      );
    }

    // Batch fetch context sentences (±1 line around each location).
    final ctxTriples = <(String, int, int)>[];
    final ctxStemByTriple = <(String, int, int), String>{};
    for (final entry in stemToLoc.entries) {
      final (book, para, line) = entry.value;
      for (final l in [line - 1, line, line + 1]) {
        final triple = (book, para, l);
        ctxTriples.add(triple);
        ctxStemByTriple[triple] = entry.key;
      }
    }
    final ctxRows = await _fetchExactLines(db, ctxTriples);
    final langMap = await fetchLangTranslationsWithFallback(
      langDb: langDb,
      enDb: enDb,
      triples: [for (final r in ctxRows) (r.bookId, r.paraId, r.lineId)],
    );

    final stemCtx = <String, List<String>>{};
    for (final r in ctxRows) {
      final en = (langMap[(r.bookId, r.paraId, r.lineId)] ?? '').trim();
      var entry = r.pali;
      if (en.isNotEmpty) entry += ' [$en]';
      stemCtx.putIfAbsent(ctxStemByTriple[(r.bookId, r.paraId, r.lineId)] ?? '', () => []).add(entry);
    }

    final defs = <String>[];
    for (final word in ranked) {
      final matches = wordToStems[word];
      if (matches == null) continue;
      final lines = <String>[];
      for (final stem in matches) {
        final usages = stemCtx[stem];
        if (usages == null || usages.isEmpty) continue;
        lines.add('    - $stem: ${usages.join(' … ')}');
      }
      if (lines.isNotEmpty) {
        defs.add('  $word:');
        defs.addAll(lines);
      }
    }
    if (defs.isEmpty) {
      return wrapContextBlock(label, '(no word definitions found)');
    }
    return wrapContextBlock(label, 'Pali Word Definitions:\n${defs.join('\n')}');
  } catch (_) {
    return wrapContextBlock(label, '(word definitions unavailable)');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. Previous paragraph translation
// ═══════════════════════════════════════════════════════════════════

/// Previous paragraph block: walk back from [paraStart] collecting translated
/// paragraphs until [minLength] chars of translation are gathered.
Future<String> buildPreviousParagraphBlock({
  required EpitakaDatabase db,
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required String bookId,
  required int paraStart,
  int minLength = 600,
  int maxLookback = 1500,
}) async {
  const label = 'PREVIOUS PARAGRAPH (for style consistency)';
  if (paraStart <= 1) {
    return wrapContextBlock(label, '(no previous paragraph translated)');
  }

  try {
    final candidateRows = await db.customSelect(
      'SELECT para_id, line_id, pali FROM sentences '
      'WHERE book_id = ? AND para_id < ? '
      'ORDER BY para_id DESC, line_id DESC LIMIT ?',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
        Variable.withInt(maxLookback),
      ],
    ).get();

    final langMap = await fetchLangTranslationsRangeWithFallback(
      langDb: langDb,
      enDb: enDb,
      bookId: bookId,
      paraLo: paraStart - maxLookback < 1 ? 1 : paraStart - maxLookback,
      paraHi: paraStart - 1,
    );

    final paraMap = <int, List<({int lineId, String pali, String translation})>>{};
    for (final r in candidateRows) {
      final pid = r.data['para_id'] as int;
      final lid = r.data['line_id'] as int;
      final pali = r.data['pali'] as String? ?? '';
      paraMap.putIfAbsent(pid, () => []).add((
        lineId: lid,
        pali: pali,
        translation: langMap[(pid, lid)] ?? '',
      ));
    }
    for (final rows in paraMap.values) {
      rows.sort((a, b) => a.lineId.compareTo(b.lineId));
    }

    final collected = <(int, List<({int lineId, String pali, String translation})>)>[];
    var translatedChars = 0;

    for (final pid in (paraMap.keys.toList()..sort((a, b) => b.compareTo(a)))) {
      final rows = paraMap[pid]!;
      final paraChars = rows.fold<int>(
        0,
        (sum, r) => sum + r.translation.trim().length,
      );
      if (paraChars == 0) continue;
      collected.insert(0, (pid, rows));
      translatedChars += paraChars;
      if (translatedChars >= minLength) break;
    }

    if (collected.isEmpty) {
      return wrapContextBlock(label, '(no previous paragraph translated)');
    }

    final parts = <String>[];
    for (final (pid, rows) in collected) {
      final lines = <String>['[Para $pid]'];
      for (final r in rows) {
        var line = '  [line_id=${r.lineId}] Pali: ${r.pali}';
        if (r.translation.trim().isNotEmpty) {
          line += '\n                   EN:   ${r.translation}';
        }
        lines.add(line);
      }
      parts.add(lines.join('\n'));
    }
    return wrapContextBlock(label, parts.join('\n\n'));
  } catch (_) {
    return wrapContextBlock(label, '(no previous paragraph translated)');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 5. Translated mūla / aṭṭhakathā / ṭīkā references
// ═══════════════════════════════════════════════════════════════════

Future<String> buildMulaAtthaBlock({
  required EpitakaDatabase db,
  required TranslationDatabase? langDb,
  required TranslationDatabase? enDb,
  required String bookId,
  required int paraStart,
  required int paraEnd,
}) async {
  const label = 'TRANSLATED MŪLA / AṬṬHAKATHĀ / ṬĪKĀ REFERENCES';
  try {
    final hasLinks = await db.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='book_links' LIMIT 1",
    ).get();
    if (hasLinks.isEmpty) {
      return wrapContextBlock(label, '(no linked translations available)');
    }

    final linkRows = await db.customSelect(
      'SELECT DISTINCT dst_book, dst_para FROM book_links '
      'WHERE src_book = ? AND src_para BETWEEN ? AND ? '
      'ORDER BY dst_book, dst_para',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
        Variable.withInt(paraEnd),
      ],
    ).get();
    if (linkRows.isEmpty) {
      return wrapContextBlock(label, '(no linked translations available)');
    }

    final blocks = <String>[];
    for (final r in linkRows) {
      final dstBook = r.data['dst_book'] as String;
      final dstPara = r.data['dst_para'] as int;
      final sentRows = await db.customSelect(
        'SELECT line_id, pali FROM sentences '
        'WHERE book_id = ? AND para_id = ? ORDER BY line_id',
        variables: [Variable.withString(dstBook), Variable.withInt(dstPara)],
      ).get();
      if (sentRows.isEmpty) continue;

      final langMap = await fetchLangTranslationsRangeWithFallback(
        langDb: langDb,
        enDb: enDb,
        bookId: dstBook,
        paraLo: dstPara,
        paraHi: dstPara,
      );

      final lines = <String>['[$dstBook §$dstPara]'];
      var anyTranslated = false;
      for (final sr in sentRows) {
        final lid = sr.data['line_id'] as int;
        final en = (langMap[(dstPara, lid)] ?? '').trim();
        if (en.isEmpty) continue;
        anyTranslated = true;
        lines.add(
          '  [$lid] Pāli: ${sr.data['pali'] as String? ?? ''}\n'
          '          EN:   $en',
        );
      }
      if (!anyTranslated) continue;
      blocks.add(lines.join('\n'));
    }

    if (blocks.isEmpty) {
      return wrapContextBlock(label, '(no linked translations available)');
    }
    return wrapContextBlock(label, blocks.join('\n\n'));
  } catch (_) {
    return wrapContextBlock(label, '(no linked translations available)');
  }
}

// ═══════════════════════════════════════════════════════════════════
// 6. Parallel human translation (English only)
// ═══════════════════════════════════════════════════════════════════

Future<String> buildParallelBlock({
  required TranslationDatabase? enDb,
  required String bookId,
  required int paraStart,
  required int paraEnd,
}) async {
  const label = 'PARALLEL HUMAN TRANSLATIONS (for reference)';
  if (enDb == null) {
    return wrapContextBlock(label, '(no parallel translations found)');
  }
  try {
    final rows = await enDb.customSelect(
      'SELECT para_id, line_id, translation FROM sentences '
      'WHERE book_id = ? AND para_id BETWEEN ? AND ? '
      "AND translation IS NOT NULL AND translation != '' "
      'ORDER BY para_id, line_id',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
        Variable.withInt(paraEnd),
      ],
    ).get();
    if (rows.isEmpty) {
      return wrapContextBlock(label, '(no parallel translations found)');
    }

    final paraGroups = <int, List<({int lineId, String translation})>>{};
    for (final r in rows) {
      paraGroups.putIfAbsent(r.data['para_id'] as int, () => []).add((
        lineId: r.data['line_id'] as int,
        translation: r.data['translation'] as String? ?? '',
      ));
    }

    final sectionLines = <String>['[English translation]'];
    for (final pid in (paraGroups.keys.toList()..sort())) {
      sectionLines.add('  --- para_id=$pid ---');
      for (final r in paraGroups[pid]!) {
        sectionLines.add("    [line_id=${r.lineId}] ${r.translation}");
      }
    }
    return wrapContextBlock(label, sectionLines.join('\n'));
  } catch (_) {
    return wrapContextBlock(label, '(no parallel translations found)');
  }
}
