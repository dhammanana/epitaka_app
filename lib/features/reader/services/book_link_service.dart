import 'package:drift/drift.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';
import '../data/book_link_data.dart';

/// Service for querying the `book_links` table in epitaka.db.
///
/// Since the `book_links` table is not managed by Drift (it exists in the
/// pre-bundled database), all queries use raw `customSelect`.
class BookLinkService {
  final EpitakaDatabase _db;

  BookLinkService(this._db);

  /// Load all book links where the given [bookId] appears as either
  /// `src_book` or `dst_book`.  Returns a [BookLinksMap] keyed by
  /// paragraph ID then line ID.
  Future<BookLinksMap> getLinksForBook(String bookId) async {
    final srcRowsFuture = _db
        .customSelect(
          '''
  SELECT src_book, src_para, src_line,
         dst_book, dst_para, dst_line, word
  FROM book_links
  WHERE src_book = ?
  ORDER BY src_para, src_line
  ''',
          variables: [Variable.withString(bookId)],
        )
        .get();

    final dstRowsFuture = _db
        .customSelect(
          '''
  SELECT src_book, src_para, src_line,
         dst_book, dst_para, dst_line, word
  FROM book_links
  WHERE dst_book = ?
  ORDER BY dst_para, dst_line
  ''',
          variables: [Variable.withString(bookId)],
        )
        .get();

    final results = await Future.wait([srcRowsFuture, dstRowsFuture]);
    final srcRows = results[0];
    final dstRows = results[1];

    final result = <int, ParaBookLinks>{};

    for (final row in srcRows) {
      _addLink(
        result,
        row.data['src_para'] as int,
        row.data['src_line'] as int,
        BookLinkData(
          word: row.data['word'] as String,
          linkedBookId: row.data['dst_book'] as String,
          linkedParaId: row.data['dst_para'] as int,
          linkedLineId: row.data['dst_line'] as int,
          isSource: true,
        ),
      );
    }

    for (final row in dstRows) {
      _addLink(
        result,
        row.data['dst_para'] as int,
        row.data['dst_line'] as int,
        BookLinkData(
          word: row.data['word'] as String,
          linkedBookId: row.data['src_book'] as String,
          linkedParaId: row.data['src_para'] as int,
          linkedLineId: row.data['src_line'] as int,
          isSource: false,
        ),
      );
    }

    return result;
  }

  void _addLink(
    Map<int, ParaBookLinks> map,
    int paraId,
    int lineId,
    BookLinkData link,
  ) {
    final paraMap = map.putIfAbsent(paraId, () => {});
    final list = paraMap.putIfAbsent(lineId, () => []);
    // Deduplicate — the same word can appear in multiple links but we
    // only need to show one chip per unique word per line.
    final alreadySeen = list.map((l) => l.word).toSet();
    if (!alreadySeen.contains(link.word)) {
      list.add(link);
    }
  }

  /// Lines loaded before the linked line when a section is large.
  static const int previewWindowBefore = 60;

  /// Lines loaded after the linked line when a section is large.
  static const int previewWindowAfter = 60;

  /// Get the section containing [paraId] in a linked book, along with the
  /// nearest `level=10` heading (the section title) and optional
  /// translations.
  ///
  /// A "section" runs from the nearest `level=10` heading at or before
  /// [paraId] up to the next heading of any level. This shows the full
  /// commentary/explanation block rather than a single paragraph.
  ///
  /// Large sections are capped: when the section has more than
  /// [previewWindowBefore] + [previewWindowAfter] lines, only a window of
  /// that many lines around the linked line ([paraId]/[lineId]) is loaded
  /// instead of the whole section — a section can run to 1300+ lines, and
  /// rendering all of them made the sheet slow. [LinkedParagraphContent.totalLines]
  /// still reports the real section size and [LinkedParagraphContent.isTrimmed]
  /// is set when this cap was applied.
  ///
  /// [translationDbs] provides translation databases keyed by language code
  /// (e.g. {'en': TranslationDatabase, 'th': TranslationDatabase}).
  Future<LinkedParagraphContent?> getLinkedContent(
    String bookId,
    int paraId, {
    int? lineId,
    Map<String, TranslationDatabase>? translationDbs,
  }) async {
    // ── Parallelize the independent queries ────────────────────────────
    // The section heading, the book name, and (later) the sentences all
    // touch different tables; running them concurrently cuts the sheet's
    // open latency by roughly one serial query round-trip.
    final sectionRowFuture = _db
        .customSelect(
          'SELECT para_id, title, level FROM headings '
          'WHERE book_id = ? AND para_id <= ? AND level = 10 '
          'ORDER BY para_id DESC LIMIT 1',
          variables: [Variable.withString(bookId), Variable.withInt(paraId)],
        )
        .get();
    final bookRowFuture = _db
        .customSelect(
          'SELECT book_name FROM books WHERE book_id = ? LIMIT 1',
          variables: [Variable.withString(bookId)],
        )
        .get();

    final results = await Future.wait([sectionRowFuture, bookRowFuture]);
    final sectionRow = results[0];
    final bookRow = results[1];

    final int sectionStartParaId;
    String? headingTitle;
    int? headingLevel;
    if (sectionRow.isNotEmpty) {
      sectionStartParaId = sectionRow.first.data['para_id'] as int;
      headingTitle = sectionRow.first.data['title'] as String?;
      headingLevel = sectionRow.first.data['level'] as int?;
    } else {
      // No level=10 section heading — fall back to the single linked paragraph.
      sectionStartParaId = paraId;
    }

    // Find the next heading (any level) after the section start. Paragraphs
    // up to (but not including) that heading belong to this section.
    int? sectionEndParaId;
    if (sectionStartParaId != paraId) {
      final nextHeadingRow = await _db
          .customSelect(
            'SELECT para_id FROM headings '
            'WHERE book_id = ? AND para_id > ? '
            'ORDER BY para_id ASC LIMIT 1',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(sectionStartParaId),
            ],
          )
          .get();
      if (nextHeadingRow.isNotEmpty) {
        sectionEndParaId = nextHeadingRow.first.data['para_id'] as int;
      }
    }

    // Build the paragraph-range WHERE clause.
    final rangeSql = sectionEndParaId != null
        ? 'AND para_id >= ? AND para_id < ?'
        : 'AND para_id >= ?';
    final rangeVars = sectionEndParaId != null
        ? [
            Variable.withInt(sectionStartParaId),
            Variable.withInt(sectionEndParaId),
          ]
        : [Variable.withInt(sectionStartParaId)];

    // ── Section size + linked-line anchor ──────────────────────────────
    // The linked line's 1-based position within the ordered section, and the
    // section's total line count, both from a single ordered pass. This tells
    // us whether the section is large enough to cap, and where the window
    // must be centered.
    //
    // Only runs for genuinely bounded sections (a known next heading). The
    // fallback ranges (`para_id >= start` with no upper bound — a link
    // target without a level-10 heading, or the last section of a book) are
    // left to the whole-section query below, avoiding a full scan of the
    // rest of the book just to count lines.
    int targetRn = 0;
    int sectionTotal = 0;
    if (lineId != null && sectionEndParaId != null) {
      final anchorRows = await _db
          .customSelect(
            'SELECT rn, total FROM ('
            '  SELECT para_id, line_id,'
            '         ROW_NUMBER() OVER (ORDER BY para_id, line_id) AS rn,'
            '         COUNT(*) OVER () AS total'
            '  FROM sentences WHERE book_id = ? $rangeSql'
            ') WHERE para_id = ? AND line_id = ?',
            variables: [
              Variable.withString(bookId),
              ...rangeVars,
              Variable.withInt(paraId),
              Variable.withInt(lineId),
            ],
          )
          .get();
      if (anchorRows.isNotEmpty) {
        targetRn = anchorRows.first.data['rn'] as int;
        sectionTotal = anchorRows.first.data['total'] as int;
      }
    }

    // Large sections are trimmed to a window around the linked line: 60
    // lines before it and 60 after, so the sheet renders at most ~121 lines
    // no matter how big the section is. Small sections load in full.
    final bool trimSection =
        sectionTotal > previewWindowBefore + previewWindowAfter;

    final List<QueryRow> sentenceRows;
    if (trimSection) {
      final windowStart = (targetRn - 1 - previewWindowBefore) < 0
          ? 0
          : targetRn - 1 - previewWindowBefore; // 0-based index of first line
      final windowEnd = targetRn + previewWindowAfter; // inclusive 1-based rn
      sentenceRows = await _db
          .customSelect(
            'SELECT para_id, line_id, pali FROM ('
            '  SELECT para_id, line_id, pali,'
            '         ROW_NUMBER() OVER (ORDER BY para_id, line_id) AS rn'
            '  FROM sentences WHERE book_id = ? $rangeSql'
            ') WHERE rn > ? AND rn <= ? '
            'ORDER BY para_id, line_id',
            variables: [
              Variable.withString(bookId),
              ...rangeVars,
              Variable.withInt(windowStart),
              Variable.withInt(windowEnd),
            ],
          )
          .get();
    } else {
      sentenceRows = await _db
          .customSelect(
            'SELECT para_id, line_id, pali FROM sentences '
            'WHERE book_id = ? $rangeSql '
            'ORDER BY para_id, line_id LIMIT 500',
            variables: [Variable.withString(bookId), ...rangeVars],
          )
          .get();
    }

    if (sentenceRows.isEmpty) return null;

    // Scope translations to the paragraphs actually shown (the window or the
    // whole section). Fetching by para range — rather than by the section's
    // line range — keeps the rows keyed by (para_id, line_id) in sync with
    // the Pāli rows even when a translation table is missing some lines, and
    // avoids pulling translations for paragraphs that aren't rendered.
    var paraMin = sentenceRows.first.data['para_id'] as int;
    var paraMax = paraMin;
    for (final r in sentenceRows) {
      final p = r.data['para_id'] as int;
      if (p < paraMin) paraMin = p;
      if (p > paraMax) paraMax = p;
    }

    // Fetch translations for each requested language in parallel.
    // Keyed by language -> paragraph -> line so multiple paragraphs don't
    // collide on shared line_ids.
    final transByLang = <String, Map<int, Map<int, String>>>{};
    if (translationDbs != null && translationDbs.isNotEmpty) {
      await Future.wait(
        translationDbs.entries.map((entry) async {
          final langCode = entry.key;
          final transDb = entry.value;
          try {
            final rows = await transDb
                .customSelect(
                  'SELECT para_id, line_id, translation FROM sentences '
                  'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
                  'ORDER BY para_id, line_id',
                  variables: [
                    Variable.withString(bookId),
                    Variable.withInt(paraMin),
                    Variable.withInt(paraMax),
                  ],
                )
                .get();
            final paraMap = <int, Map<int, String>>{};
            for (final r in rows) {
              final p = r.data['para_id'] as int;
              final l = r.data['line_id'] as int;
              final text = r.data['translation'] as String?;
              if (text != null && text.isNotEmpty) {
                paraMap.putIfAbsent(p, () => {})[l] = text;
              }
            }
            if (paraMap.isNotEmpty) {
              transByLang[langCode] = paraMap;
            }
          } catch (_) {
            // Translation DB may not have this section — skip silently
          }
        }),
      );
    }

    final lines = sentenceRows.map((r) {
      final pId = r.data['para_id'] as int;
      final lineId = r.data['line_id'] as int;
      final translations = <String, String>{};
      for (final langEntry in transByLang.entries) {
        final text = langEntry.value[pId]?[lineId];
        if (text != null) {
          translations[langEntry.key] = text;
        }
      }
      return LinkedLine(
        paraId: pId,
        lineId: lineId,
        paliText: r.data['pali'] as String? ?? '',
        translations: translations,
      );
    }).toList();

    // Book name was fetched concurrently with the section heading above.
    final bookName = bookRow.isNotEmpty
        ? (bookRow.first.data['book_name'] as String? ?? bookId)
        : bookId;

    return LinkedParagraphContent(
      bookId: bookId,
      bookName: bookName,
      paraId: paraId,
      lines: lines,
      headingTitle: headingTitle,
      headingLevel: headingLevel,
      translationLangs: transByLang.keys.toList(),
      totalLines: sectionTotal,
      isTrimmed: trimSection,
    );
  }
}

/// Content of a single linked paragraph for display in the bottom sheet.
class LinkedParagraphContent {
  final String bookId;
  final String bookName;
  final int paraId;
  final List<LinkedLine> lines;
  final String? headingTitle;
  final int? headingLevel;

  /// Language codes for which translations were successfully loaded.
  final List<String> translationLangs;

  /// Total number of lines in the whole section (not just the loaded
  /// window). 0 when the section size couldn't be determined.
  final int totalLines;

  /// True when the section was larger than the preview window, so [lines]
  /// holds only the lines around the linked line instead of the whole
  /// section.
  final bool isTrimmed;

  const LinkedParagraphContent({
    required this.bookId,
    required this.bookName,
    required this.paraId,
    required this.lines,
    this.headingTitle,
    this.headingLevel,
    this.translationLangs = const [],
    this.totalLines = 0,
    this.isTrimmed = false,
  });
}

/// A single line in a linked paragraph.
class LinkedLine {
  final int paraId;
  final int lineId;
  final String paliText;

  /// Translations keyed by language code (e.g. 'en' -> "text...").
  /// The text may contain HTML tags like `<b>`, `<i>`.
  final Map<String, String> translations;

  const LinkedLine({
    required this.paraId,
    required this.lineId,
    required this.paliText,
    this.translations = const {},
  });
}
