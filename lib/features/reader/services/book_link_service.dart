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

  /// Get the whole section containing [paraId] in a linked book, along with
  /// the nearest `level=10` heading (the section title) and optional
  /// translations.
  ///
  /// A "section" runs from the nearest `level=10` heading at or before
  /// [paraId] up to the next heading of any level. This shows the full
  /// commentary/explanation block rather than a single paragraph.
  ///
  /// [translationDbs] provides translation databases keyed by language code
  /// (e.g. {'en': TranslationDatabase, 'th': TranslationDatabase}).
  Future<LinkedParagraphContent?> getLinkedContent(
    String bookId,
    int paraId, {
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

    final sentenceRows = await _db
        .customSelect(
          'SELECT para_id, line_id, pali FROM sentences '
          'WHERE book_id = ? $rangeSql '
          'ORDER BY para_id, line_id LIMIT 500',
          variables: [Variable.withString(bookId), ...rangeVars],
        )
        .get();

    if (sentenceRows.isEmpty) return null;

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
                  'WHERE book_id = ? $rangeSql '
                  'ORDER BY para_id, line_id',
                  variables: [Variable.withString(bookId), ...rangeVars],
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

  const LinkedParagraphContent({
    required this.bookId,
    required this.bookName,
    required this.paraId,
    required this.lines,
    this.headingTitle,
    this.headingLevel,
    this.translationLangs = const [],
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
