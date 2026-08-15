// lib/features/translator/services/translator_engine.dart
//
// The on-device port of the server's book_translator.py pipeline, minus the
// server-only bits (nissaya context, th/si parallel references, clearing the
// source columns out of epitaka.db — the app keeps Pāli text there).
//
// Responsibilities:
//   1. discover pending lines (sentences with no translation in the target
//      DB, or everything when overwrite is on),
//   2. group paragraphs into heading-based sections, merged to avoid tiny
//      AI calls,
//   3. split sections into token-safe chunks,
//   4. assemble the chunk prompt (context blocks built by
//      translator_context.dart),
//   5. save translations / remarks / glossary into the target DB.
//
// The AI call itself and the defensive JSON parsing live in
// AiApiClient.callTextModel / parseTranslatorJsonResponse.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';
import '../../../core/utils/pali_search_utils.dart' show normalizePaliFuzzy;
import '../../ai_qa/services/ai_api_client.dart';
import '../translator_constants.dart';

// ═══════════════════════════════════════════════════════════════════
// Data model
// ═══════════════════════════════════════════════════════════════════

/// One Pāli sentence (line) to be translated.
class TLine {
  final int lineId;
  final String pali;

  const TLine({required this.lineId, required this.pali});
}

/// One paragraph: all its lines plus the subset still pending translation.
class TParagraph {
  final int paraId;
  final List<TLine> sentences;
  final List<TLine> pending;

  const TParagraph({
    required this.paraId,
    required this.sentences,
    required this.pending,
  });
}

/// A parsed translation entry from the AI.
class TTranslation {
  final int paraId;
  final int lineId;
  final String text;
  final String confidence; // 'high' | 'low'
  final String? confidenceNote;

  const TTranslation({
    required this.paraId,
    required this.lineId,
    required this.text,
    this.confidence = 'high',
    this.confidenceNote,
  });
}

/// A parsed glossary entry from the AI.
class TGlossaryTerm {
  final String pali;
  final String translation;
  final String domain;
  final String subDomain;
  final String context;
  final String note;

  const TGlossaryTerm({
    required this.pali,
    required this.translation,
    this.domain = '',
    this.subDomain = '',
    this.context = '',
    this.note = '',
  });
}

/// A parsed remark (conflict note) from the AI.
class TRemark {
  final int paraId;
  final int lineId;
  final String pali;
  final String translation;
  final String conflict;
  final String note;

  const TRemark({
    required this.paraId,
    required this.lineId,
    this.pali = '',
    this.translation = '',
    this.conflict = '',
    this.note = '',
  });
}

/// Result of processing one chunk.
class TChunkResult {
  final int translationsSaved;
  final int glossarySaved;
  final int remarksSaved;

  const TChunkResult({
    this.translationsSaved = 0,
    this.glossarySaved = 0,
    this.remarksSaved = 0,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Token estimation / chunking
// ═══════════════════════════════════════════════════════════════════

int _estimateTokens(String text) => text.length ~/ 4;

int _paraTokens(TParagraph para) {
  return _estimateTokens(
    para.pending.map((s) => s.pali).join('\n'),
  );
}

/// Estimated token count of a chunk's pending Pāli text (chars/4 ≈ tokens,
/// same heuristic the chunker uses). Exposed for run progress stats.
int chunkParagraphsTokens(List<TParagraph> chunk) {
  return chunk.fold<int>(
    0,
    (sum, para) => sum + _paraTokens(para),
  );
}

/// Split one oversized paragraph into sentence-level pieces, each within
/// [maxTokens]. Keeps the same paraId and full sentence list on each piece.
List<TParagraph> _splitOversizedPara(TParagraph para, int maxTokens) {
  final pieces = <TParagraph>[];
  var pieceLines = <TLine>[];
  var pieceTokens = 0;

  for (final s in para.pending) {
    final sTokens = _estimateTokens(s.pali);
    if (pieceLines.isNotEmpty && pieceTokens + sTokens > maxTokens) {
      pieces.add(TParagraph(
        paraId: para.paraId,
        sentences: para.sentences,
        pending: pieceLines,
      ));
      pieceLines = [];
      pieceTokens = 0;
    }
    pieceLines.add(s);
    pieceTokens += sTokens;
  }
  if (pieceLines.isNotEmpty) {
    pieces.add(TParagraph(
      paraId: para.paraId,
      sentences: para.sentences,
      pending: pieceLines,
    ));
  }
  return pieces;
}

/// Group paragraphs into token-budgeted chunks, splitting oversized ones.
List<List<TParagraph>> chunkParagraphs(
  List<TParagraph> paragraphs, {
  int maxTokens = kTranslatorChunkMaxTokens,
}) {
  final chunks = <List<TParagraph>>[];
  var current = <TParagraph>[];
  var currentTokens = 0;

  for (final para in paragraphs) {
    final paraTokens = _paraTokens(para);
    if (paraTokens > maxTokens) {
      if (current.isNotEmpty) {
        chunks.add(current);
        current = [];
        currentTokens = 0;
      }
      for (final piece in _splitOversizedPara(para, maxTokens)) {
        chunks.add([piece]);
      }
      continue;
    }
    if (current.isNotEmpty && currentTokens + paraTokens > maxTokens) {
      chunks.add(current);
      current = [];
      currentTokens = 0;
    }
    current.add(para);
    currentTokens += paraTokens;
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

// ═══════════════════════════════════════════════════════════════════
// Sectioning (heading-based, with small-section merging)
// ═══════════════════════════════════════════════════════════════════

/// All headings for a book in document order (paraId, level).
Future<List<({int paraId, int? level, String? title})>> fetchHeadings(
  EpitakaDatabase db,
  String bookId,
) async {
  final rows = await db.customSelect(
    'SELECT para_id, level, title FROM headings '
    'WHERE book_id = ? ORDER BY para_id',
    variables: [Variable.withString(bookId)],
  ).get();
  return [
    for (final r in rows)
      (
        paraId: r.data['para_id'] as int,
        level: r.data['level'] as int?,
        title: r.data['title'] as String?,
      ),
  ];
}

/// Load paragraphs in [paraStart, paraEnd], annotated with pending lines.
///
/// A line is pending when overwrite is on, or when it has no non-empty
/// translation in [langDb] yet AND its Pāli is at least 3 characters
/// (skips bare punctuation/number placeholders). Paragraphs with zero
/// pending lines are dropped.
Future<List<TParagraph>> fetchParagraphsRange(
  EpitakaDatabase db,
  TranslationDatabase? langDb,
  String bookId,
  int paraStart,
  int paraEnd, {
  required bool overwrite,
}) async {
  final already = <(int, int)>{};
  if (langDb != null && !overwrite) {
    final rows = await langDb.customSelect(
      'SELECT para_id, line_id FROM sentences '
      'WHERE book_id = ? AND para_id BETWEEN ? AND ? '
      "AND translation IS NOT NULL AND translation != ''",
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
        Variable.withInt(paraEnd),
      ],
    ).get();
    for (final r in rows) {
      already.add((r.data['para_id'] as int, r.data['line_id'] as int));
    }
  }

  final rows = await db.customSelect(
    'SELECT para_id, line_id, pali FROM sentences '
    'WHERE book_id = ? AND para_id BETWEEN ? AND ? '
    'ORDER BY para_id, line_id',
    variables: [
      Variable.withString(bookId),
      Variable.withInt(paraStart),
      Variable.withInt(paraEnd),
    ],
  ).get();

  final byPara = <int, List<TLine>>{};
  for (final r in rows) {
    final paraId = r.data['para_id'] as int;
    final lineId = r.data['line_id'] as int;
    final pali = r.data['pali'] as String? ?? '';
    byPara.putIfAbsent(paraId, () => []).add(TLine(lineId: lineId, pali: pali));
  }

  final result = <TParagraph>[];
  final sortedKeys = byPara.keys.toList()..sort();
  for (final paraId in sortedKeys) {
    final sentences = byPara[paraId]!;
    final pending = overwrite
        ? sentences
        : [
            for (final s in sentences)
              if (!already.contains((paraId, s.lineId)) &&
                  s.pali.trim().length >= 3)
                s,
          ];
    if (pending.isEmpty) continue;
    result.add(TParagraph(
      paraId: paraId,
      sentences: sentences,
      pending: pending,
    ));
  }
  return result;
}

Future<int> _countLinesRange(
  EpitakaDatabase db,
  String bookId,
  int start,
  int end,
) async {
  final rows = await db.customSelect(
    'SELECT COUNT(*) AS n FROM sentences '
    'WHERE book_id = ? AND para_id BETWEEN ? AND ?',
    variables: [
      Variable.withString(bookId),
      Variable.withInt(start),
      Variable.withInt(end),
    ],
  ).get();
  if (rows.isEmpty) return 0;
  return (rows.first.data['n'] as num).toInt();
}

/// Split [paraStart..paraEnd] into sections aligned to heading boundaries,
/// merging consecutive headings until each section has at least [minLines]
/// total sentences.
Future<List<List<TParagraph>>> buildSectionsFromHeadings({
  required EpitakaDatabase db,
  required TranslationDatabase? langDb,
  required String bookId,
  required int paraStart,
  required int paraEnd,
  required int minLines,
  required bool overwrite,
}) async {
  final headings = await fetchHeadings(db, bookId);

  final maxRow = await db.customSelect(
    'SELECT MAX(para_id) AS m FROM sentences WHERE book_id = ?',
    variables: [Variable.withString(bookId)],
  ).get();
  final bookMax = maxRow.isEmpty
      ? paraStart
      : (maxRow.first.data['m'] as num?)?.toInt() ?? paraStart;

  final effectiveEnd = paraEnd == -1 ? bookMax : paraEnd;

  var boundaries = [
    for (final h in headings)
      if (h.paraId >= paraStart && h.paraId <= effectiveEnd) h.paraId,
  ];
  if (boundaries.isEmpty || boundaries.first > paraStart) {
    boundaries.insert(0, paraStart);
  }
  boundaries.add(effectiveEnd + 1);
  boundaries = boundaries.toSet().toList()..sort();

  final mergedRanges = <(int, int)>[];
  int? pendingStart;
  var pendingLines = 0;

  for (var i = 0; i < boundaries.length - 1; i++) {
    final secStart = boundaries[i];
    final secEnd = boundaries[i + 1] - 1;
    pendingStart ??= secStart;

    pendingLines += await _countLinesRange(db, bookId, secStart, secEnd);

    final isLast = i == boundaries.length - 2;
    if (pendingLines >= minLines || isLast) {
      mergedRanges.add((pendingStart, secEnd));
      pendingStart = null;
      pendingLines = 0;
    }
  }

  final sections = <List<TParagraph>>[];
  for (final (start, end) in mergedRanges) {
    final paras = await fetchParagraphsRange(
      db,
      langDb,
      bookId,
      start,
      end,
      overwrite: overwrite,
    );
    if (paras.isNotEmpty) sections.add(paras);
  }
  return sections;
}

/// Merge consecutive sections while the batch stays under both caps.
List<List<TParagraph>> mergeSmallSections(
  List<List<TParagraph>> sections, {
  int maxBytes = kTranslatorSectionMergeMaxBytes,
  int maxLines = kTranslatorSectionMergeMaxLines,
}) {
  if (sections.isEmpty) return sections;

  final merged = <List<TParagraph>>[];
  var current = <TParagraph>[];
  var currentBytes = 0;
  var currentLines = 0;

  for (final section in sections) {
    var secBytes = 0;
    var secLines = 0;
    for (final para in section) {
      for (final s in para.pending) {
        secBytes += utf8.encode(s.pali).length;
        secLines++;
      }
    }

    if (current.isNotEmpty &&
        (currentBytes + secBytes > maxBytes ||
            currentLines + secLines > maxLines)) {
      merged.add(current);
      current = [];
      currentBytes = 0;
      currentLines = 0;
    }
    current.addAll(section);
    currentBytes += secBytes;
    currentLines += secLines;
  }
  if (current.isNotEmpty) merged.add(current);
  return merged;
}

// ═══════════════════════════════════════════════════════════════════
// Script-bleed guard (Lao <-> Thai and friends)
// ═══════════════════════════════════════════════════════════════════

const _scriptRanges = <String, List<(int, int)>>{
  'lo': [(0x0E80, 0x0EFF)], // Lao
  'th': [(0x0E00, 0x0E7F)], // Thai
  'km': [(0x1780, 0x17FF)], // Khmer
  'my': [(0x1000, 0x109F)], // Myanmar
  'si': [(0x0D80, 0x0DFF)], // Sinhala
};

const _confusableWith = <String, List<String>>{
  'lo': ['th'],
  'th': ['lo'],
};

int _countInRanges(String s, List<(int, int)> ranges) {
  var count = 0;
  for (final ch in s.runes) {
    for (final (lo, hi) in ranges) {
      if (ch >= lo && ch <= hi) {
        count++;
        break;
      }
    }
  }
  return count;
}

String? _scriptMismatch(String lang, String text) {
  final ownRanges = _scriptRanges[lang];
  final confusables = _confusableWith[lang];
  if (ownRanges == null || confusables == null || text.isEmpty) return null;

  final ownCount = _countInRanges(text, ownRanges);
  for (final other in confusables) {
    final otherRanges = _scriptRanges[other];
    if (otherRanges == null) continue;
    final otherCount = _countInRanges(text, otherRanges);
    if (otherCount >= 5 && otherCount > ownCount) {
      return "looks like '$other' script, not '$lang'";
    }
  }
  return null;
}

/// Flag translations whose script doesn't match the target language,
/// forcing them to low confidence.
List<TTranslation> checkTranslationsForScriptBleed(
  String lang,
  List<TTranslation> translations,
) {
  final flagged = <TTranslation>[];
  for (final t in translations) {
    if (t.text.isEmpty || t.text == '~') continue;
    final reason = _scriptMismatch(lang, t.text);
    if (reason != null) {
      final note = t.confidenceNote == null || t.confidenceNote!.isEmpty
          ? '[SCRIPT-BLEED] $reason'
          : '[SCRIPT-BLEED] $reason; ${t.confidenceNote}';
      flagged.add(TTranslation(
        paraId: t.paraId,
        lineId: t.lineId,
        text: t.text,
        confidence: 'low',
        confidenceNote: note,
      ));
    }
  }
  return flagged;
}

// ═══════════════════════════════════════════════════════════════════
// Prompt assembly
// ═══════════════════════════════════════════════════════════════════

/// Flatten a chunk into the sentences-array JSON the AI expects.
String buildSentencesJson(List<TParagraph> chunk) {
  final flat = <Map<String, dynamic>>[];
  for (final para in chunk) {
    for (final s in para.pending) {
      flat.add({'para_id': para.paraId, 'line_id': s.lineId, 'pali': s.pali});
    }
  }
  return jsonEncode(flat);
}

/// Assemble the user prompt for one chunk from its context blocks.
String buildChunkPrompt({
  required String bookId,
  required int paraStart,
  required int paraEnd,
  required List<TParagraph> chunk,
  required String glossaryBlock,
  required String commentaryBlock,
  required String paliDefsBlock,
  required String prevParaBlock,
  required String mulaBlock,
  required String parallelBlock,
}) {
  final buf = StringBuffer()
    ..writeln('Book: $bookId  —  paragraphs $paraStart–$paraEnd')
    ..writeln()
    ..writeln(glossaryBlock)
    ..writeln()
    ..writeln(commentaryBlock)
    ..writeln()
    ..writeln(paliDefsBlock)
    ..writeln()
    ..writeln(prevParaBlock)
    ..writeln()
    ..writeln(mulaBlock)
    ..writeln()
    ..writeln(parallelBlock)
    ..writeln()
    ..writeln('═' * 30)
    ..writeln('SENTENCES TO TRANSLATE (JSON array)')
    ..writeln('═' * 30)
    ..write(buildSentencesJson(chunk));
  return buf.toString();
}

// ═══════════════════════════════════════════════════════════════════
// Parsing AI output
// ═══════════════════════════════════════════════════════════════════

/// Parse the AI's raw JSON reply into translations / glossary / remarks.
({List<TTranslation> translations, List<TGlossaryTerm> glossary, List<TRemark> remarks})
parseAiTranslationResult(String raw) {
  final obj = AiApiClient.parseTranslatorJsonResponse(
    raw,
    ['translations', 'glossary', 'remarks'],
  );

  final translations = <TTranslation>[];
  for (final item in (obj['translations'] as List<dynamic>? ?? [])) {
    if (item is! Map<String, dynamic>) continue;
    final paraId = item['para_id'];
    final lineId = item['line_id'];
    if (paraId is! num || lineId is! num) continue;
    final text = (item['translation'] as String? ?? '').trim();
    final confidence = (item['confidence'] as String? ?? 'high').trim();
    final note = item['confidence_note'] as String?;
    translations.add(TTranslation(
      paraId: paraId.toInt(),
      lineId: lineId.toInt(),
      text: text,
      confidence: confidence == 'low' ? 'low' : 'high',
      confidenceNote: (note == null || note.trim().isEmpty) ? null : note.trim(),
    ));
  }

  final glossary = <TGlossaryTerm>[];
  for (final item in (obj['glossary'] as List<dynamic>? ?? [])) {
    if (item is! Map<String, dynamic>) continue;
    final pali = (item['pali'] as String? ?? '').trim();
    final translation =
        (item['translation'] as String? ?? item['english'] as String? ?? '')
            .trim();
    if (pali.isEmpty || translation.isEmpty) continue;
    glossary.add(TGlossaryTerm(
      pali: pali,
      translation: translation,
      domain: (item['domain'] as String? ?? '').trim(),
      subDomain: (item['sub_domain'] as String? ?? '').trim(),
      context: (item['context'] as String? ?? '').trim(),
      note: (item['note'] as String? ?? '').trim(),
    ));
  }

  final remarks = <TRemark>[];
  for (final item in (obj['remarks'] as List<dynamic>? ?? [])) {
    if (item is! Map<String, dynamic>) continue;
    final paraId = item['para_id'];
    final lineId = item['line_id'];
    if (paraId is! num || lineId is! num) continue;
    remarks.add(TRemark(
      paraId: paraId.toInt(),
      lineId: lineId.toInt(),
      pali: (item['pali'] as String? ?? '').trim(),
      translation: (item['translation'] as String? ?? '').trim(),
      conflict: (item['conflict'] as String? ?? '').trim(),
      note: (item['note'] as String? ?? '').trim(),
    ));
  }

  return (translations: translations, glossary: glossary, remarks: remarks);
}

// ═══════════════════════════════════════════════════════════════════
// Saving
// ═══════════════════════════════════════════════════════════════════

/// Ensure the target DB has the extra tables the translator writes:
/// `translation_remarks` (already read by the reader) and `glossary`
/// (translation memory). The `sentences` table exists by definition
/// (the reader reads from it).
Future<void> ensureTranslatorTables(TranslationDatabase db) async {
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS translation_remarks ('
    ' id INTEGER PRIMARY KEY AUTOINCREMENT,'
    ' book_id TEXT NOT NULL,'
    ' para_id INTEGER NOT NULL,'
    ' line_id INTEGER NOT NULL,'
    ' pali TEXT,'
    ' translation TEXT,'
    ' conflict TEXT,'
    ' note TEXT,'
    ' source_id TEXT,'
    " created_at TEXT DEFAULT (datetime('now'))"
    ')',
  );
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS glossary ('
    ' id INTEGER PRIMARY KEY AUTOINCREMENT,'
    ' pali TEXT NOT NULL,'
    ' translation TEXT NOT NULL,'
    ' domain TEXT,'
    ' sub_domain TEXT,'
    ' context TEXT,'
    ' note TEXT,'
    ' source_id TEXT,'
    ' para_id_start INTEGER,'
    ' para_id_end INTEGER,'
    " created_at TEXT DEFAULT (datetime('now')),"
    ' UNIQUE (pali, translation)'
    ')',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_glossary_pali ON glossary(pali)',
  );
}

/// Upsert translated sentences into the target DB.
Future<int> saveTranslations(
  TranslationDatabase db,
  String bookId,
  List<TTranslation> translations,
) async {
  if (translations.isEmpty) return 0;
  var saved = 0;
  for (final t in translations) {
    if (t.paraId <= 0) continue;
    final res = await db.customInsert(
      'INSERT INTO sentences '
      '(book_id, para_id, line_id, translation, translation_confidence, confidence_note) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(book_id, para_id, line_id) DO UPDATE SET '
      ' translation = excluded.translation,'
      ' translation_confidence = excluded.translation_confidence,'
      ' confidence_note = excluded.confidence_note',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(t.paraId),
        Variable.withInt(t.lineId),
        Variable.withString(t.text),
        Variable.withString(t.confidence),
        Variable.withString(t.confidenceNote ?? ''),
      ],
    );
    if (res > 0) saved++;
  }
  return saved;
}

/// Insert remarks into the target DB.
Future<int> saveRemarks(
  TranslationDatabase db,
  String bookId,
  List<TRemark> remarks,
) async {
  if (remarks.isEmpty) return 0;
  var saved = 0;
  for (final r in remarks) {
    if (r.paraId <= 0) continue;
    await db.customInsert(
      'INSERT INTO translation_remarks '
      '(book_id, para_id, line_id, pali, translation, conflict, note, source_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(r.paraId),
        Variable.withInt(r.lineId),
        Variable.withString(r.pali),
        Variable.withString(r.translation),
        Variable.withString(r.conflict),
        Variable.withString(r.note),
        Variable.withString(bookId),
      ],
    );
    saved++;
  }
  return saved;
}

// ═══════════════════════════════════════════════════════════════════
// Pāli stem resolution (for glossary canonicalisation)
// ═══════════════════════════════════════════════════════════════════

final _stemCache = <String, String>{};

/// Resolve a Pāli word to its dictionary stem, mirroring the server's
/// `resolve_pali_stem` (dpd_inflections_to_headwords → pali_definition →
/// dpr_stem). Falls back to the surface form.
Future<String> resolvePaliStem(EpitakaDatabase db, String word) async {
  final cached = _stemCache[word];
  if (cached != null) return cached;

  try {
    final rows = await db.customSelect(
      'SELECT headwords FROM dpd_inflections_to_headwords WHERE inflection = ? '
      'LIMIT 1',
      variables: [Variable.withString(word)],
    ).get();
    if (rows.isNotEmpty) {
      final headwords = rows.first.data['headwords'] as String?;
      if (headwords != null && headwords.isNotEmpty) {
        final first = headwords.split(',')[0];
        final cleaned = first.replaceAll(RegExp(r"['\[\]\d\s]"), '');
        if (cleaned.isNotEmpty) {
          _stemCache[word] = cleaned;
          return cleaned;
        }
      }
    }

    final rows2 = await db.customSelect(
      'SELECT word FROM pali_definition WHERE plain = ? OR word = ? LIMIT 1',
      variables: [Variable.withString(word), Variable.withString(word)],
    ).get();
    if (rows2.isNotEmpty) {
      final w = rows2.first.data['word'] as String?;
      if (w != null && w.isNotEmpty) {
        _stemCache[word] = w;
        return w;
      }
    }

    final rows3 = await db.customSelect(
      'SELECT stem FROM dpr_stem WHERE word = ? LIMIT 1',
      variables: [Variable.withString(word)],
    ).get();
    if (rows3.isNotEmpty) {
      final stem = rows3.first.data['stem'] as String?;
      if (stem != null && stem.isNotEmpty) {
        _stemCache[word] = stem;
        return stem;
      }
    }
  } catch (_) {
    // Dictionary tables may be missing — fall back to surface form.
  }
  return word;
}

/// Save AI-extracted glossary terms, canonicalising the Pāli stem and
/// dropping grammar-only particles.
Future<int> saveGlossaryTerms(
  TranslationDatabase db,
  EpitakaDatabase epitakaDb,
  List<TGlossaryTerm> terms, {
  String sourceId = '',
  int? paraIdStart,
  int? paraIdEnd,
}) async {
  if (terms.isEmpty) return 0;
  var saved = 0;
  for (final term in terms) {
    var pali = term.pali.trim().toLowerCase();
    final translation = term.translation.trim();
    if (pali.isEmpty || translation.isEmpty) continue;
    if (kTranslatorGlossarySkipTerms.contains(pali)) continue;
    pali = await resolvePaliStem(epitakaDb, pali);

    final res = await db.customInsert(
      'INSERT INTO glossary '
      '(pali, translation, domain, sub_domain, context, note, source_id, para_id_start, para_id_end) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(pali, translation) DO UPDATE SET '
      ' domain = excluded.domain,'
      ' sub_domain = excluded.sub_domain,'
      ' context = excluded.context,'
      ' note = excluded.note,'
      ' source_id = excluded.source_id,'
      ' para_id_start = COALESCE(glossary.para_id_start, excluded.para_id_start),'
      ' para_id_end = COALESCE(excluded.para_id_end, glossary.para_id_end)',
      variables: [
        Variable.withString(pali),
        Variable.withString(translation),
        Variable.withString(term.domain),
        Variable.withString(term.subDomain),
        Variable.withString(term.context),
        Variable.withString(term.note),
        Variable.withString(sourceId),
        Variable.withInt(paraIdStart ?? 0),
        Variable.withInt(paraIdEnd ?? 0),
      ],
    );
    if (res > 0) saved++;
  }
  return saved;
}

/// Normalize Pāli for glossary prefix matching (reuses the app's existing
/// fuzzy normalizer so 'saṅkhāra' and 'sankhara' compare equal).
String normalizeGlossaryPali(String s) => normalizePaliFuzzy(s);
