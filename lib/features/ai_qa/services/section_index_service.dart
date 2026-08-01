/// Service for the Layer 1 "Section Summary Index" ("The Map").
///
/// Builds a navigable outline of the whole canon in `app_data.db`:
///
///  - **`section_summaries`** — one row per *section*. A section is one
///    heading row plus the paragraph span it covers, defined as
///    `[heading.para_id, next_heading.para_id - 1]` where "next heading" is
///    the next heading in the same book at the **same or shallower level**.
///    This gives a clean, hierarchy-consistent partition driven entirely by
///    the existing `headings` table (level, parent, para_id).
///
///  - **`section_summaries_fts`** — FTS5 over titles + summaries so the AI
///    can *search* the map (tool: `search_sections`) and *browse* it
///    (tool: `get_section`, which reads a section + its direct children +
///    its parent from this table).
///
/// Annotation headings are filtered out with the same rule as
/// `mention_index` (`level < 19 AND level != 10`) so aṭṭhakathā/ṭīkā
/// annotation rows (level=10) and structural rows (level>=19) never create
/// spurious span boundaries. Books with no headings become a single section.
///
/// Summaries are **extractive** (first ~1200 chars of the section body,
/// Pāli + English) — cheap, honest navigation hints. They are NEVER quotable
/// content: the answer model must still open the real text via
/// `get_paragraph_content` (orthodox-mode integrity).
///
/// Build runs once lazily on first use (like `mention_service.dart`);
/// ~160k sections for the whole canon, a few seconds on-device.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';

/// Max characters for the extractive Pāli/English summary of a section.
const int kSectionSummaryMaxChars = 1200;

/// Section index table name (raw SQL, no drift codegen needed).
const String kSectionSummariesTable = 'section_summaries';

/// FTS5 virtual table over section titles + summaries.
const String kSectionSummariesFtsTable = 'section_summaries_fts';

/// Service managing the section summary index (Layer 1).
class SectionIndexService {
  final Ref _ref;

  /// Whether the tables have been ensured in this session.
  bool _indexEnsured = false;

  /// Guard against concurrent [buildIndex] calls.
  bool _isBuilding = false;

  SectionIndexService(this._ref);

  // ── Table setup ────────────────────────────────────────────────────────

  /// Ensure `section_summaries` + `section_summaries_fts` exist, dropping
  /// the Layer 0 `headings_fts` stopgap table (its role is fully replaced).
  Future<void> _ensureTables(AppDatabase appDb) async {
    if (_indexEnsured) return;

    await appDb.customStatement('''
      CREATE TABLE IF NOT EXISTS section_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        para_start INTEGER NOT NULL,
        para_end INTEGER NOT NULL,
        level INTEGER NOT NULL DEFAULT 0,
        parent_para INTEGER NOT NULL DEFAULT 0,
        title TEXT NOT NULL,
        title_en TEXT DEFAULT '',
        path TEXT NOT NULL,
        summary TEXT DEFAULT '',
        summary_en TEXT DEFAULT '',
        word_count INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await appDb.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sections_book
      ON section_summaries(book_id, para_start)
    ''');
    await appDb.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS section_summaries_fts USING fts5(
        book_id UNINDEXED,
        para_start UNINDEXED,
        title,
        title_en,
        path,
        summary,
        summary_en,
        tokenize='unicode61 remove_diacritics 1'
      )
    ''');
    // Layer 0 stopgap no longer needed once section_summaries_fts exists.
    await appDb.customStatement('DROP TABLE IF EXISTS headings_fts');

    _indexEnsured = true;

    // Auto-build on first use (empty table).
    final countRows = await appDb
        .customSelect('SELECT COUNT(*) as cnt FROM section_summaries')
        .get();
    final count = countRows.first.data['cnt'] as int? ?? 0;
    if (count == 0) {
      if (_isBuilding) {
        debugPrint('[SECTIONS] Empty during concurrent build — skipping');
        return;
      }
      debugPrint('[SECTIONS] section_summaries empty — auto-building…');
      await buildIndex();
      debugPrint('[SECTIONS] Auto-build complete: ${await getIndexSize()} sections');
    }
  }

  // ── Public entry points ────────────────────────────────────────────────

  /// Ensure the section index tables exist and are populated, building them
  /// lazily on first use (mention_service-style). Safe to call before every
  /// search_sections / get_section tool invocation.
  Future<void> ensureIndex() async {
    final appDb = await _ref.read(appDbProvider.future);
    await _ensureTables(appDb);
  }

  // ── Build index ────────────────────────────────────────────────────────

  /// Build (or rebuild) the section index.
  ///
  /// [onProgress] receives 0.0–1.0 plus a label so the UI can show
  /// progress. Yields to the event loop between books.
  Future<int> buildIndex({
    void Function(double progress, String label)? onProgress,
  }) async {
    if (_isBuilding) {
      debugPrint('[SECTIONS] buildIndex: already building, skipping');
      return 0;
    }
    _isBuilding = true;
    try {
      return await _buildIndexInternal(onProgress: onProgress);
    } finally {
      _isBuilding = false;
    }
  }

  Future<int> _buildIndexInternal({
    void Function(double progress, String label)? onProgress,
  }) async {
    final appDb = await _ref.read(appDbProvider.future);
    final epiDb = await _ref.read(epitakaDbProvider.future);
    // Best-effort English titles/summaries; skipped when unavailable.
    final enDb = await _ref.read(translationDbProvider('en').future);

    await _ensureTables(appDb);

    await appDb.customStatement('DELETE FROM section_summaries');

    debugPrint('[SECTIONS] Building section index…');
    final stopwatch = Stopwatch()..start();

    final books = await epiDb.customSelect(
      'SELECT book_id, book_name FROM books ORDER BY id',
    ).get();
    final totalBooks = books.length;

    int inserted = 0;

    for (int i = 0; i < totalBooks; i++) {
      final book = books[i];
      final bookId = book.data['book_id'] as String;
      final bookName = (book.data['book_name'] as String?) ?? bookId;

      onProgress?.call(
        totalBooks == 0 ? 1.0 : (i + 1) / totalBooks,
        '$bookId — building sections…',
      );

      // Filtered headings for this book (same rule as mention_index).
      final headings = await epiDb.customSelect(
        'SELECT para_id, title, level, parent FROM headings '
        'WHERE book_id = ? AND level < 19 AND level != 10 '
        'ORDER BY para_id ASC',
        variables: [Variable.withString(bookId)],
      ).get();

      if (headings.isEmpty) {
        // Book with no headings → treat the whole book as one section.
        inserted += await _insertWholeBookSection(
          appDb,
          epiDb,
          enDb,
          bookId,
          bookName,
        );
        await Future.delayed(Duration.zero);
        continue;
      }

      final titleMap = <int, String>{};
      final levelMap = <int, int>{};
      final parentMap = <int, int>{};
      for (final h in headings) {
        final pid = h.data['para_id'] as int;
        titleMap[pid] = (h.data['title'] as String?) ?? '';
        levelMap[pid] = (h.data['level'] as int?) ?? 0;
        parentMap[pid] = (h.data['parent'] as int?) ?? 0;
      }

      // Last paragraph of the book (span end for the final section).
      final lastPara = await _lastParaOfBook(epiDb, bookId);

      // Pre-compute all section rows (in memory) so English titles +
      // bodies can be fetched batched per book.
      final sectionRows = <Map<String, dynamic>>[];
      for (int hi = 0; hi < headings.length; hi++) {
        final paraId = headings[hi].data['para_id'] as int;
        final title = titleMap[paraId] ?? '';
        if (title.isEmpty) continue;

        final level = levelMap[paraId] ?? 0;
        final parent = parentMap[paraId] ?? 0;

        // Span end: next heading at same-or-shallower level, minus 1.
        var paraEnd = lastPara;
        for (int j = hi + 1; j < headings.length; j++) {
          final nextPara = headings[j].data['para_id'] as int;
          final nextLevel = levelMap[nextPara] ?? 0;
          if (nextLevel <= level) {
            paraEnd = nextPara - 1;
            break;
          }
        }
        if (paraEnd < paraId) paraEnd = paraId;

        // Hierarchy path via parent chain (same algorithm as mention_index).
        final hierarchy = <String>[title];
        int? currentParent = parent;
        final seen = <int>{paraId};
        while (currentParent != null &&
            currentParent > 0 &&
            !seen.contains(currentParent)) {
          seen.add(currentParent);
          final parentTitle = titleMap[currentParent];
          if (parentTitle != null && parentTitle.isNotEmpty) {
            hierarchy.insert(0, parentTitle);
          }
          currentParent = parentMap[currentParent];
        }

        sectionRows.add({
          'book_id': bookId,
          'para_start': paraId,
          'para_end': paraEnd,
          'level': level,
          'parent_para': parent,
          'title': title,
          'path': '$bookId/${hierarchy.join('/')}',
        });
      }

      if (sectionRows.isEmpty) continue;

      // Batched English titles for the section headings (best-effort).
      final enTitles = await _fetchEnTitles(
        enDb,
        bookId,
        sectionRows.map((r) => r['para_start'] as int).toList(),
      );

      // Batched extractive summaries (Pāli + English), one query per book.
      final paliBodies =
          await _fetchBodyTexts(epiDb, bookId, sectionRows, column: 'pali');
      final enBodies = enDb == null
          ? <int, String>{}
          : await _fetchBodyTexts(
              enDb,
              bookId,
              sectionRows,
              column: 'translation',
            );

      // Insert rows + FTS rows for this book.
      await appDb.transaction(() async {
        for (final row in sectionRows) {
          final paraStart = row['para_start'] as int;
          final titleEn = enTitles[paraStart] ?? '';
          final summary = (paliBodies[paraStart] ?? '').trim();
          final summaryEn = (enBodies[paraStart] ?? '').trim();
          final wordCount = summary.isEmpty
              ? 0
              : summary.split(RegExp(r'\s+')).length;

          final now = DateTime.now().toIso8601String();
          await appDb.customStatement(
            'INSERT INTO section_summaries '
            '(book_id, para_start, para_end, level, parent_para, title, '
            ' title_en, path, summary, summary_en, word_count, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              row['book_id'],
              paraStart,
              row['para_end'],
              row['level'],
              row['parent_para'],
              row['title'],
              titleEn,
              row['path'],
              summary,
              summaryEn,
              wordCount,
              now,
            ],
          );
          await appDb.customStatement(
            'INSERT INTO section_summaries_fts '
            '(book_id, para_start, title, title_en, path, summary, summary_en) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [
              row['book_id'],
              paraStart,
              row['title'],
              titleEn,
              row['path'],
              summary,
              summaryEn,
            ],
          );
          inserted++;
        }
      });
      await Future.delayed(Duration.zero);
    }

    stopwatch.stop();
    debugPrint(
      '[SECTIONS] Index built: $inserted sections in ${stopwatch.elapsed.inSeconds}s',
    );
    return inserted;
  }

  /// Insert a single whole-book section for books with no headings.
  Future<int> _insertWholeBookSection(
    AppDatabase appDb,
    GeneratedDatabase epiDb,
    GeneratedDatabase? enDb,
    String bookId,
    String bookName,
  ) async {
    final lastPara = await _lastParaOfBook(epiDb, bookId);
    if (lastPara <= 0) return 0;

    final titleEn = enDb == null
        ? ''
        : await _firstEnTranslation(enDb, bookId, 1);

    final summary = (await _bodyTextFor(epiDb, bookId, 1, lastPara, 'pali')).trim();
    final summaryEn = enDb == null
        ? ''
        : (await _bodyTextFor(enDb, bookId, 1, lastPara, 'translation')).trim();
    final wordCount = summary.isEmpty ? 0 : summary.split(RegExp(r'\s+')).length;

    final now = DateTime.now().toIso8601String();
    await appDb.transaction(() async {
      await appDb.customStatement(
        'INSERT INTO section_summaries '
        '(book_id, para_start, para_end, level, parent_para, title, '
        ' title_en, path, summary, summary_en, word_count, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          bookId,
          1,
          lastPara,
          0,
          0,
          bookName,
          titleEn,
          '$bookId/$bookName',
          summary,
          summaryEn,
          wordCount,
          now,
        ],
      );
      await appDb.customStatement(
        'INSERT INTO section_summaries_fts '
        '(book_id, para_start, title, title_en, path, summary, summary_en) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [bookId, 1, bookName, titleEn, '$bookId/$bookName', summary, summaryEn],
      );
    });
    return 1;
  }

  // ── Lookup helpers ─────────────────────────────────────────────────────

  Future<int> _lastParaOfBook(GeneratedDatabase epiDb, String bookId) async {
    try {
      final rows = await epiDb.customSelect(
        'SELECT MAX(para_id) as m FROM sentences WHERE book_id = ?',
        variables: [Variable.withString(bookId)],
      ).get();
      return (rows.first.data['m'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _firstEnTranslation(
    GeneratedDatabase enDb,
    String bookId,
    int paraId,
  ) async {
    try {
      final rows = await enDb.customSelect(
        'SELECT translation FROM sentences '
        'WHERE book_id = ? AND para_id = ? AND translation IS NOT NULL '
        "AND translation != '' "
        'ORDER BY line_id ASC LIMIT 1',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraId),
        ],
      ).get();
      return (rows.first.data['translation'] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Fetch the first non-empty English title for each [paraIds] in one
  /// batched query (returns map para_id -> title).
  Future<Map<int, String>> _fetchEnTitles(
    GeneratedDatabase? enDb,
    String bookId,
    List<int> paraIds,
  ) async {
    final result = <int, String>{};
    if (enDb == null || paraIds.isEmpty) return result;
    try {
      final placeholders = paraIds.map((_) => '?').join(',');
      final rows = await enDb.customSelect(
        'SELECT para_id, translation FROM sentences '
        'WHERE book_id = ? AND para_id IN ($placeholders) '
        'AND translation IS NOT NULL AND translation != \'\' '
        'ORDER BY para_id ASC, line_id ASC',
        variables: [
          Variable.withString(bookId),
          ...paraIds.map((i) => Variable.withInt(i)),
        ],
      ).get();
      for (final row in rows) {
        final pid = row.data['para_id'] as int;
        final t = (row.data['translation'] as String? ?? '').trim();
        if (t.isNotEmpty && !result.containsKey(pid)) {
          result[pid] = t;
        }
      }
    } catch (_) {}
    return result;
  }

  /// Fetch the extractive body summary (first ~[kSectionSummaryMaxChars]
  /// chars of the concatenated body) for every section's span, batched per
  /// book. [column] is 'pali' for the root DB and 'translation' for the
  /// English DB.
  Future<Map<int, String>> _fetchBodyTexts(
    GeneratedDatabase db,
    String bookId,
    List<Map<String, dynamic>> sectionRows, {
    required String column,
  }) async {
    final result = <int, String>{};
    if (sectionRows.isEmpty) return result;

    // One query for the whole book's paragraphs, then assemble per section.
    final rows = await db.customSelect(
      'SELECT para_id, $column FROM sentences '
      'WHERE book_id = ? AND $column IS NOT NULL AND $column != \'\' '
      'ORDER BY para_id ASC, line_id ASC',
      variables: [Variable.withString(bookId)],
    ).get();

    // Group lines per para.
    final paras = <int, StringBuffer>{};
    for (final row in rows) {
      final pid = row.data['para_id'] as int;
      final text = (row.data[column] as String? ?? '').trim();
      if (text.isEmpty) continue;
      (paras[pid] ??= StringBuffer()).write(text);
      (paras[pid]!).write(' ');
    }

    for (final row in sectionRows) {
      final start = row['para_start'] as int;
      final end = row['para_end'] as int;
      final buffer = StringBuffer();
      for (int p = start; p <= end; p++) {
        final text = paras[p]?.toString().trim();
        if (text == null || text.isEmpty) continue;
        buffer.write(text);
        buffer.write(' ');
        if (buffer.length >= kSectionSummaryMaxChars) break;
      }
      var summary = buffer.toString().trim();
      if (summary.length > kSectionSummaryMaxChars) {
        summary = summary.substring(0, kSectionSummaryMaxChars).trim();
      }
      result[start] = summary;
    }
    return result;
  }

  Future<String> _bodyTextFor(
    GeneratedDatabase db,
    String bookId,
    int start,
    int end,
    String column,
  ) async {
    try {
      final rows = await db.customSelect(
        'SELECT $column FROM sentences '
        'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
        'AND $column IS NOT NULL AND $column != \'\' '
        'ORDER BY para_id ASC, line_id ASC',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(start),
          Variable.withInt(end),
        ],
      ).get();
      final buffer = StringBuffer();
      for (final row in rows) {
        buffer.write((row.data[column] as String? ?? '').trim());
        buffer.write(' ');
        if (buffer.length >= kSectionSummaryMaxChars) break;
      }
      var s = buffer.toString().trim();
      if (s.length > kSectionSummaryMaxChars) {
        s = s.substring(0, kSectionSummaryMaxChars).trim();
      }
      return s;
    } catch (_) {
      return '';
    }
  }

  // ── Browsing (get_section tool support) ───────────────────────────────

  /// Load one section with its direct child sections and its parent section.
  ///
  /// Returns `{section, children, parent}` where `parent` is null when the
  /// section is a top-level row (parent_para == 0) or its parent is not in
  /// the index. Returns null when the section does not exist.
  Future<Map<String, dynamic>?> getSection(
    String bookId,
    int paraStart,
  ) async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      await _ensureTables(appDb);

      final row = await _selectSection(appDb, bookId, paraStart);
      if (row == null) return null;

      final section = _rowToSection(row);

      // Direct children: headings whose parent_para == this para_start.
      final childrenRows = await appDb.customSelect(
        'SELECT * FROM section_summaries '
        'WHERE book_id = ? AND parent_para = ? '
        'ORDER BY para_start ASC',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraStart),
        ],
      ).get();
      final children = childrenRows
          .map((r) => {
                'book_id': r.data['book_id'] as String,
                'para_start': r.data['para_start'] as int,
                'para_end': r.data['para_end'] as int,
                'title': (r.data['title'] as String?) ?? '',
                'title_en': (r.data['title_en'] as String?) ?? '',
              })
          .toList();

      // Parent section.
      Map<String, dynamic>? parent;
      final parentPara = row.data['parent_para'] as int? ?? 0;
      if (parentPara > 0) {
        final parentRows = await _selectSection(appDb, bookId, parentPara);
        if (parentRows != null) {
          parent = {
            'para_start': parentRows.data['para_start'] as int,
            'title': (parentRows.data['title'] as String?) ?? '',
          };
        }
      }

      return {'section': section, 'children': children, 'parent': parent};
    } catch (e) {
      debugPrint('[SECTIONS] getSection error: $e');
      return null;
    }
  }

  Future<QueryRow?> _selectSection(
    AppDatabase appDb,
    String bookId,
    int paraStart,
  ) async {
    final rows = await appDb.customSelect(
      'SELECT * FROM section_summaries '
      'WHERE book_id = ? AND para_start = ?',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraStart),
      ],
    ).get();
    return rows.isEmpty ? null : rows.first;
  }

  Map<String, dynamic> _rowToSection(QueryRow row) {
    return {
      'book_id': row.data['book_id'] as String,
      'para_start': row.data['para_start'] as int,
      'para_end': row.data['para_end'] as int,
      'level': (row.data['level'] as int?) ?? 0,
      'parent_para': (row.data['parent_para'] as int?) ?? 0,
      'title': (row.data['title'] as String?) ?? '',
      'title_en': (row.data['title_en'] as String?) ?? '',
      'path': (row.data['path'] as String?) ?? '',
      'summary': (row.data['summary'] as String?) ?? '',
      'summary_en': (row.data['summary_en'] as String?) ?? '',
      'word_count': (row.data['word_count'] as int?) ?? 0,
    };
  }

  // ── Status ────────────────────────────────────────────────────────────

  Future<bool> isIndexBuilt() async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final rows = await appDb.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='section_summaries'",
      ).get();
      if (rows.isEmpty) return false;
      final count = await appDb
          .customSelect('SELECT COUNT(*) as cnt FROM section_summaries')
          .get();
      return (count.first.data['cnt'] as int? ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<int> getIndexSize() async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final rows = await appDb
          .customSelect('SELECT COUNT(*) as cnt FROM section_summaries')
          .get();
      return (rows.first.data['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

/// Riverpod provider for the SectionIndexService.
final sectionIndexServiceProvider = Provider<SectionIndexService>((ref) {
  return SectionIndexService(ref);
});
